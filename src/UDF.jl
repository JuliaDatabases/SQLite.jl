function sqlvalue(values, i)
    temp_val_ptr = unsafe_load(values, i)
    valuetype = C.sqlite3_value_type(temp_val_ptr)

    if valuetype == C.SQLITE_INTEGER
        if Sys.WORD_SIZE == 64
            return C.sqlite3_value_int64(temp_val_ptr)
        else
            return C.sqlite3_value_int(temp_val_ptr)
        end
    elseif valuetype == C.SQLITE_FLOAT
        return C.sqlite3_value_double(temp_val_ptr)
    elseif valuetype == C.SQLITE_TEXT
        return unsafe_string(C.sqlite3_value_text(temp_val_ptr))
    elseif valuetype == C.SQLITE_BLOB
        nbytes = C.sqlite3_value_bytes(temp_val_ptr)
        blob = C.sqlite3_value_blob(temp_val_ptr)
        buf = zeros(UInt8, nbytes)
        unsafe_copyto!(pointer(buf), convert(Ptr{UInt8}, blob), nbytes)
        return sqldeserialize(buf)
    else
        return missing
    end
end

"""
This function should never be called explicitly.
Instead it is exported so that it can be overloaded when necessary,
see [below](@ref regex).
"""
function sqlreturn end

sqlreturn(context, ::Missing) = C.sqlite3_result_null(context)
sqlreturn(context, val::Int32) = C.sqlite3_result_int(context, val)
sqlreturn(context, val::Int64) = C.sqlite3_result_int64(context, val)
sqlreturn(context, val::Float64) = C.sqlite3_result_double(context, val)
function sqlreturn(context, val::AbstractString)
    C.sqlite3_result_text(context, val, sizeof(val), C.SQLITE_TRANSIENT)
end
function sqlreturn(context, val::Vector{UInt8})
    C.sqlite3_result_blob(context, val, sizeof(val), C.SQLITE_TRANSIENT)
end

sqlreturn(context, val::Bool) = sqlreturn(context, Int(val))
sqlreturn(context, val) = sqlreturn(context, sqlserialize(val))

function wrap_scalarfunc(
    func,
    context::Ptr{Cvoid},
    nargs::Cint,
    values::Ptr{Ptr{Cvoid}},
)
    args = [sqlvalue(values, i) for i in 1:nargs]
    ret = func(args...)
    sqlreturn(context, ret)
    nothing
end

# convert a byteptr to an int, assumes little-endian
function bytestoint(ptr::Ptr{UInt8}, start::Int, len::Int)
    s = 0
    for i in start:start+len-1
        v = unsafe_load(ptr, i)
        s += v * 256^(i - start)
    end

    # swap byte-order on big-endian machines
    # TODO: this desperately needs testing on a big-endian machine!!!!!
    return htol(s)
end

function wrap_stepfunc(
    init,
    func,
    context::Ptr{Cvoid},
    nargs::Cint,
    values::Ptr{Ptr{Cvoid}},
)
    args = [sqlvalue(values, i) for i in 1:nargs]

    intsize = sizeof(Int)
    ptrsize = sizeof(Ptr)
    acsize = intsize + ptrsize
    acptr = convert(Ptr{UInt8}, C.sqlite3_aggregate_context(context, acsize))

    # acptr will be zeroed-out if this is the first iteration
    ret = ccall(
        :memcmp,
        Cint,
        (Ptr{UInt8}, Ptr{UInt8}, Cuint),
        zeros(UInt8, acsize),
        acptr,
        acsize,
    )
    if ret == 0
        acval = init
        valsize = 256
        # avoid the garbage collector using malloc
        valptr = convert(Ptr{UInt8}, Libc.malloc(valsize))
        valptr == C_NULL && throw(SQLiteException("memory error"))
    else
        # size of serialized value is first sizeof(Int) bytes
        valsize = bytestoint(acptr, 1, intsize)
        # ptr to serialized value is last sizeof(Ptr) bytes
        valptr =
            reinterpret(Ptr{UInt8}, bytestoint(acptr, intsize + 1, ptrsize))
        # deserialize the value pointed to by valptr
        acvalbuf = zeros(UInt8, valsize)
        unsafe_copyto!(pointer(acvalbuf), valptr, valsize)
        acval = sqldeserialize(acvalbuf)
    end

    local funcret
    try
        funcret = sqlserialize(func(acval, args...))
    catch
        Libc.free(valptr)
        rethrow()
    end

    newsize = sizeof(funcret)
    if newsize > valsize
        # TODO: increase this in a cleverer way?
        tmp = convert(Ptr{UInt8}, Libc.realloc(valptr, newsize))
        if tmp == C_NULL
            Libc.free(valptr)
            throw(SQLiteException("memory error"))
        else
            valptr = tmp
        end
    end
    # copy serialized return value
    unsafe_copyto!(valptr, pointer(funcret), newsize)

    # copy the size of the serialized value
    unsafe_copyto!(acptr, pointer(reinterpret(UInt8, [newsize])), intsize)
    # copy the address of the pointer to the serialized value
    valarr = reinterpret(UInt8, [valptr])
    for i in 1:length(valarr)
        unsafe_store!(acptr, valarr[i], intsize + i)
    end
    nothing
end

function wrap_finalfunc(
    init,
    func,
    context::Ptr{Cvoid},
    nargs::Cint,
    values::Ptr{Ptr{Cvoid}},
)
    acptr = convert(Ptr{UInt8}, C.sqlite3_aggregate_context(context, 0))

    # step function wasn't run
    if acptr == C_NULL
        sqlreturn(context, init)
    else
        intsize = sizeof(Int)
        ptrsize = sizeof(Ptr)
        acsize = intsize + ptrsize

        # load size
        valsize = bytestoint(acptr, 1, intsize)
        # load ptr
        valptr =
            reinterpret(Ptr{UInt8}, bytestoint(acptr, intsize + 1, ptrsize))

        # load value
        acvalbuf = zeros(UInt8, valsize)
        unsafe_copyto!(pointer(acvalbuf), valptr, valsize)
        acval = sqldeserialize(acvalbuf)

        local ret
        try
            ret = func(acval)
        finally
            Libc.free(valptr)
        end
        sqlreturn(context, ret)
    end
    nothing
end

"""
    SQLite.@register db function

User-facing macro for convenience in registering a simple function
with no configurations needed
"""
macro register(db, func)
    :(register($(esc(db)), $(esc(func))))
end

UDF_keep_alive_list = []

"""
    SQLite.register(db, func)
    SQLite.register(db, init, step_func, final_func; nargs=-1, name=string(step), isdeterm=true)

Register a scalar (first method) or aggregate (second method) function
with a [`SQLite.DB`](@ref).
"""
function register(
    db,
    func::Function;
    nargs::Int = -1,
    name::AbstractString = string(func),
    isdeterm::Bool = true,
)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    # assume any negative number means a varargs function
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255"

    f =
        (context, nargs, values) ->
            wrap_scalarfunc(func, context, nargs, values)
    cfunc = @cfunction($f, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Ptr{Cvoid}}))
    push!(db.registered_UDFs, cfunc)

    # TODO: allow the other encodings
    enc = C.SQLITE_UTF8
    enc = isdeterm ? enc | C.SQLITE_DETERMINISTIC : enc

    @CHECK db C.sqlite3_create_function_v2(
        db.handle,
        name,
        nargs,
        enc,
        C_NULL,
        cfunc,
        C_NULL,
        C_NULL,
        C_NULL,
    )
end

# as above but for aggregate functions
function register(
    db,
    init,
    step::Function,
    final::Function = identity;
    nargs::Int = -1,
    name::AbstractString = string(step),
    isdeterm::Bool = true,
)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255 chars"

    s =
        (context, nargs, values) ->
            wrap_stepfunc(init, step, context, nargs, values)
    cs = @cfunction($s, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Ptr{Cvoid}}))
    f =
        (context, nargs, values) ->
            wrap_finalfunc(init, final, context, nargs, values)
    cf = @cfunction($f, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Ptr{Cvoid}}))
    push!(db.registered_UDFs, cs)
    push!(db.registered_UDFs, cf)

    enc = C.SQLITE_UTF8
    enc = isdeterm ? enc | C.SQLITE_DETERMINISTIC : enc

    @CHECK db C.sqlite3_create_function_v2(
        db.handle,
        name,
        nargs,
        enc,
        C_NULL,
        C_NULL,
        cs,
        cf,
        C_NULL,
    )
end

# annotate types because the MethodError makes more sense that way
regexp(r::AbstractString, s::AbstractString) = occursin(Regex(r), s)

"""
    sr"..."

This string literal is used to escape all special characters in the string,
useful for using regex in a query.

This literal is deprecated and users should switch to `Base.@raw_str` instead.
"""
macro sr_str(s)
    s
end
