function sqlvalue(values, i)
    temp_val_ptr = unsafe_load(values, i)
    valuetype = sqlite3_value_type(temp_val_ptr)

    if valuetype == SQLITE_INTEGER
        if WORD_SIZE == 64
            return sqlite3_value_int64(temp_val_ptr)
        else
            return sqlite3_value_int(temp_val_ptr)
        end
    elseif valuetype == SQLITE_FLOAT
        return sqlite3_value_double(temp_val_ptr)
    elseif valuetype == SQLITE_TEXT
        # TODO: have a way to return UTF16
        return bytestring(sqlite3_value_text(temp_val_ptr))
    elseif valuetype == SQLITE_BLOB
        nbytes = sqlite3_value_bytes(temp_val_ptr)
        blob = sqlite3_value_blob(temp_val_ptr)
        buf = zeros(Uint8, nbytes)
        unsafe_copy!(pointer(buf), convert(Ptr{Uint8}, blob), nbytes)
        return sqldeserialize(buf)
    else
        return NULL
    end
end

sqlreturn(context, ::NullType)          = sqlite3_result_null(context)
sqlreturn(context, val::Int32)          = sqlite3_result_int(context, val)
sqlreturn(context, val::Int64)          = sqlite3_result_int64(context, val)
sqlreturn(context, val::Float64)        = sqlite3_result_double(context, val)
sqlreturn(context, val::UTF16String)    = sqlite3_result_text16(context, val)
sqlreturn(context, val::AbstractString) = sqlite3_result_text(context, val)
sqlreturn(context, val::Vector{UInt8})  = sqlite3_result_blob(context, val)

sqlreturn(context, val::Bool) = sqlreturn(context, int(val))
sqlreturn(context, val) = sqlreturn(context, sqlserialize(val))

# convert a bytearray to an int arr[1] is 256^0, arr[2] is 256^1...
# TODO: would making this a method of convert needlessly pollute the Base namespace?
function bytestoint(arr::Vector{UInt8})
    l = length(arr)
    s = 0
    for (i, v) in enumerate(arr)
        s += v * 256^(i - 1)
    end
    s
end

function stepfunc(init, func, fsym=symbol(string(func)*"_step"))
    nm = isdefined(Base,fsym) ? :(Base.$fsym) : fsym
    return quote
        function $(nm)(context::Ptr{Void}, nargs::Cint, values::Ptr{Ptr{Void}})
            args = [sqlvalue(values, i) for i in 1:nargs]
            intsize = sizeof(Int)
            ptrsize = sizeof(Ptr)
            acsize = intsize + ptrsize
            acarr = pointer_to_array(
                convert(Ptr{UInt8}, sqlite3_aggregate_context(context, acsize)),
                acsize,
                false,
            )
            # acarr will be zeroed-out if this is the first iteration
            ret = ccall(
                :memcmp, Cint, (Ptr{UInt8}, Ptr{UInt8}, Cuint),
                zeros(UInt8, acsize), acarr, acsize,
            )
            try
                if ret == 0
                    acval = $(init)
                    # TODO: i'm sure there's a better way
                    valsize = sizeof(sqlserialize(acval))
                    valptr = convert(Ptr{UInt8}, c_malloc(valsize))
                else
                    # retrieve the size of the serialized value (first sizeof(Int) bytes)
                    sizebuf = zeros(UInt8, intsize)
                    unsafe_copy!(sizebuf, 1, acarr, 1, intsize)
                    valsize = bytestoint(sizebuf)
                    # retrieve the ptr to the serialized value (last sizeof(Ptr) bytes)
                    ptrbuf = zeros(UInt8, ptrsize)
                    unsafe_copy!(ptrbuf, 1, acarr, intsize+1, ptrsize)
                    valptr = reinterpret(Ptr{UInt8}, bytestoint(ptrbuf))
                    # deserialize the value pointed to by valptr
                    acvalbuf = zeros(UInt8, valsize)
                    unsafe_copy!(pointer(acvalbuf), valptr, valsize)
                    acval = sqldeserialize(acvalbuf)
                end
                funcret = sqlserialize($(func)(acval, args...))
                newsize = length(funcret)
                # TODO: increase this in a cleverer way?
                newsize > valsize && (valptr = convert(Ptr{UInt8}, c_realloc(valptr, newsize)))
                # copy serialized return value
                unsafe_copy!(valptr, pointer(funcret), newsize)
                # copy the size of the serialized value
                unsafe_copy!(
                    acarr, 1,
                    reinterpret(UInt8, [newsize]), 1,
                    intsize,
                )
                # copy the value of the pointer to the serialized value
                # TODO: can we just use ptrbuf here?
                unsafe_copy!(
                    acarr, intsize+1,
                    reinterpret(UInt8, [valptr]), 1,
                    ptrsize,
                )
            catch
                # TODO: this won't catch all memory leaks so add an else clause
                if isdefined(:valptr)
                    c_free(valptr)
                end
                rethrow()
            end
            nothing
        end
    end
end

# TODO: free valptr on error
function finalfunc(init, func, fsym=symbol(string(func)*"_final"))
    nm = isdefined(Base,fsym) ? :(Base.$fsym) : fsym
    return quote
        function $(nm)(context::Ptr{Void}, nargs::Cint, values::Ptr{Ptr{Void}})
            # TODO: I don't think arguments are ever passed to this function,
            # should we leave them in anyway?
            args = [sqlvalue(context, i) for i in 1:nargs]
            acptr = sqlite3_aggregate_context(context, 0)
            # step function wasn't run
            if acptr === C_NULL
                sqlreturn(context, $(init))
            else
                intsize = sizeof(Int)
                ptrsize = sizeof(Ptr)
                acsize = intsize + ptrsize
                acarr = pointer_to_array(convert(Ptr{UInt8}, acptr), acsize, false)
                # load size
                sizebuf = zeros(UInt8, intsize)
                unsafe_copy!(sizebuf, 1, acarr, 1, intsize)
                valsize = bytestoint(sizebuf)
                # load ptr
                ptrbuf = zeros(UInt8, ptrsize)
                unsafe_copy!(ptrbuf, 1, acarr, intsize+1, ptrsize)
                valptr = reinterpret(Ptr{UInt8}, bytestoint(ptrbuf))
                # load value
                acvalbuf = zeros(UInt8, valsize)
                unsafe_copy!(pointer(acvalbuf), valptr, valsize)

                acval = sqldeserialize(acvalbuf)
                ret = $(func)(acval, args...)
                c_free(valptr)
                sqlreturn(context, ret)
            end
            nothing
        end
    end
end

# Internal method for generating an SQLite scalar function from
# a Julia function name
function scalarfunc(func,fsym=symbol(string(func)))
    # check if name defined in Base so we don't clobber Base methods
    nm = isdefined(Base,fsym) ? :(Base.$fsym) : fsym
    return quote
        #nm needs to be a symbol or expr, i.e. :sin or :(Base.sin)
        function $(nm)(context::Ptr{Void}, nargs::Cint, values::Ptr{Ptr{Void}})
            args = [SQLite.sqlvalue(values, i) for i in 1:nargs]
            ret = $(func)(args...)
            SQLite.sqlreturn(context, ret)
            nothing
        end
    end
end
function scalarfunc(expr::Expr)
    f = eval(expr)
    return scalarfunc(f)
end

# User-facing macro for convenience in registering a simple function
# with no configurations needed
macro register(db, func)
    :(register($(esc(db)), $(esc(func))))
end

# User-facing method for registering a Julia function to be used within SQLite
function register(db::SQLiteDB, func::Function; nargs::Int=-1, name::AbstractString=string(func), isdeterm::Bool=true)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    # assume any negative number means a varargs function
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255"

    f = eval(scalarfunc(func,symbol(name)))

    cfunc = cfunction(f, Nothing, (Ptr{Void}, Cint, Ptr{Ptr{Void}}))
    # TODO: allow the other encodings
    enc = SQLITE_UTF8
    enc = isdeterm ? enc | SQLITE_DETERMINISTIC : enc

    @CHECK db sqlite3_create_function_v2(
        db.handle, name, nargs, enc, C_NULL, cfunc, C_NULL, C_NULL, C_NULL
    )    
end

# as above but for aggregate functions
function register(
    db::SQLiteDB, init, step::Function, final::Function;
    nargs::Int=-1, name::AbstractString=string(final), isdeterm::Bool=true
)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255 chars"

    s = eval(stepfunc(init, step, Base.function_name(step)))
    cs = cfunction(s, Nothing, (Ptr{Void}, Cint, Ptr{Ptr{Void}}))
    f = eval(finalfunc(init, final, Base.function_name(final)))
    cf = cfunction(f, Nothing, (Ptr{Void}, Cint, Ptr{Ptr{Void}}))

    enc = SQLITE_UTF8
    enc = isdeterm ? enc | SQLITE_DETERMINISTIC : enc

    @CHECK db sqlite3_create_function_v2(
        db.handle, name, nargs, enc, C_NULL, C_NULL, cs, cf, C_NULL
    )
end

# annotate types because the MethodError makes more sense that way
regexp(r::AbstractString, s::AbstractString) = ismatch(Regex(r), s)
# macro for preserving the special characters in a string
macro sr_str(s) s end
