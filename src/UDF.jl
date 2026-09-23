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

mutable struct ScalarUDFData
    func::Function
end

mutable struct AggregateUDFData
    init::Any
    step::Function
    final::Function
end

# A callback must report errors to SQLite, not unwind through its C caller.
function udf_error(context, err)
    try
        if err isa OutOfMemoryError
            C.sqlite3_result_error_nomem(context)
        else
            message = sprint(showerror, err)
            C.sqlite3_result_error(context, message, sizeof(message))
        end
    catch
        # Error formatting can itself invoke user-defined methods.
        C.sqlite3_result_error(
            context,
            "Julia exception in SQLite callback",
            -1,
        )
    end
    nothing
end

function wrap_scalarfunc(
    context::Ptr{Cvoid},
    nargs::Cint,
    values::Ptr{Ptr{Cvoid}},
)
    try
        udf_data = unsafe_pointer_to_objref(
            C.sqlite3_user_data(context),
        )::ScalarUDFData
        args = [sqlvalue(values, i) for i in 1:nargs]
        sqlreturn(context, udf_data.func(args...))
    catch err
        udf_error(context, err)
    end
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

# Transfer ownership to the callback before any operation that may throw.
# A cleared context also tells xFinal that a failed step has no state to finalize.
function take_aggregate_buffer!(acptr)
    valsize = bytestoint(acptr, 1, sizeof(Int))
    valptr =
        reinterpret(Ptr{UInt8}, bytestoint(acptr, sizeof(Int) + 1, sizeof(Ptr)))
    unsafe_store!(Ptr{Int}(acptr), 0)
    unsafe_store!(Ptr{Ptr{UInt8}}(acptr + sizeof(Int)), C_NULL)
    return valsize, valptr
end

function wrap_stepfunc(
    context::Ptr{Cvoid},
    nargs::Cint,
    values::Ptr{Ptr{Cvoid}},
)
    valptr = Ptr{UInt8}(C_NULL)
    try
        acptr = convert(
            Ptr{UInt8},
            C.sqlite3_aggregate_context(context, sizeof(Int) + sizeof(Ptr)),
        )
        acptr == C_NULL && throw(OutOfMemoryError())
        valsize, valptr = take_aggregate_buffer!(acptr)

        udf_data = unsafe_pointer_to_objref(
            C.sqlite3_user_data(context),
        )::AggregateUDFData
        args = [sqlvalue(values, i) for i in 1:nargs]
        if valptr == C_NULL
            acval = udf_data.init
            valsize = 256
            valptr = convert(Ptr{UInt8}, Libc.malloc(valsize))
            valptr == C_NULL && throw(OutOfMemoryError())
        else
            acvalbuf = zeros(UInt8, valsize)
            unsafe_copyto!(pointer(acvalbuf), valptr, valsize)
            acval = sqldeserialize(acvalbuf)
        end

        funcret = sqlserialize(udf_data.step(acval, args...))
        newsize = sizeof(funcret)
        if newsize > valsize
            tmp = convert(Ptr{UInt8}, Libc.realloc(valptr, newsize))
            tmp == C_NULL && throw(OutOfMemoryError())
            valptr = tmp
        end
        GC.@preserve funcret unsafe_copyto!(valptr, pointer(funcret), newsize)

        # Publish the new state only after the step and serialization succeed.
        unsafe_store!(Ptr{Int}(acptr), newsize)
        unsafe_store!(Ptr{Ptr{UInt8}}(acptr + sizeof(Int)), valptr)
        valptr = Ptr{UInt8}(C_NULL)
    catch err
        udf_error(context, err)
    finally
        Libc.free(valptr)
    end
    nothing
end

function wrap_finalfunc(context::Ptr{Cvoid})
    valptr = Ptr{UInt8}(C_NULL)
    try
        acptr = convert(Ptr{UInt8}, C.sqlite3_aggregate_context(context, 0))
        if acptr != C_NULL
            valsize, valptr = take_aggregate_buffer!(acptr)
            # SQLite still calls xFinal after a failed xStep. Preserve that error.
            valptr == C_NULL && return nothing
        end
        udf_data = unsafe_pointer_to_objref(
            C.sqlite3_user_data(context),
        )::AggregateUDFData
        if acptr == C_NULL
            # Preserve the initial value when no rows reached xStep.
            sqlreturn(context, udf_data.init)
        else
            acvalbuf = zeros(UInt8, valsize)
            unsafe_copyto!(pointer(acvalbuf), valptr, valsize)
            acval = sqldeserialize(acvalbuf)
            sqlreturn(context, udf_data.final(acval))
        end
    catch err
        udf_error(context, err)
    finally
        Libc.free(valptr)
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
with a [`SQLite.DB`](@ref). Callback errors, including value conversion errors,
are reported as `SQLiteException`s by the query that invokes the function.
"""
function register(
    db::DB,
    func::Function;
    nargs::Int = -1,
    name::AbstractString = string(func),
    isdeterm::Bool = true,
)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    # assume any negative number means a varargs function
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255"

    udf_data = ScalarUDFData(func)
    push!(db.registered_UDF_data, udf_data)
    udf_data_ptr = pointer_from_objref(udf_data)

    cfunc =
        @cfunction(wrap_scalarfunc, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Ptr{Cvoid}}))

    # TODO: allow the other encodings
    enc = C.SQLITE_UTF8
    enc = isdeterm ? enc | C.SQLITE_DETERMINISTIC : enc

    @CHECK db C.sqlite3_create_function_v2(
        db.handle,
        name,
        nargs,
        enc,
        udf_data_ptr,
        cfunc,
        C_NULL,
        C_NULL,
        C_NULL,
    )
end

# as above but for aggregate functions
function register(
    db::DB,
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

    udf_data = AggregateUDFData(init, step, final)
    push!(db.registered_UDF_data, udf_data)
    udf_data_ptr = pointer_from_objref(udf_data)

    cs = @cfunction(wrap_stepfunc, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Ptr{Cvoid}}))
    cf = @cfunction(wrap_finalfunc, Cvoid, (Ptr{Cvoid},))

    enc = C.SQLITE_UTF8
    enc = isdeterm ? enc | C.SQLITE_DETERMINISTIC : enc

    @CHECK db C.sqlite3_create_function_v2(
        db.handle,
        name,
        nargs,
        enc,
        udf_data_ptr,
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
