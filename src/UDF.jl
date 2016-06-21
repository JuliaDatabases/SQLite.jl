function sqlvalue(values, i)
    temp_val_ptr = unsafe_load(values, i)
    valuetype = sqlite3_value_type(temp_val_ptr)

    if valuetype == SQLITE_INTEGER
        if Sys.WORD_SIZE == 64
            return sqlite3_value_int64(temp_val_ptr)
        else
            return sqlite3_value_int(temp_val_ptr)
        end
    elseif valuetype == SQLITE_FLOAT
        return sqlite3_value_double(temp_val_ptr)
    elseif valuetype == SQLITE_TEXT
        # TODO: have a way to return UTF16
        return unsafe_string(sqlite3_value_text(temp_val_ptr))
    elseif valuetype == SQLITE_BLOB
        nbytes = sqlite3_value_bytes(temp_val_ptr)
        blob = sqlite3_value_blob(temp_val_ptr)
        buf = zeros(UInt8, nbytes)
        unsafe_copy!(pointer(buf), convert(Ptr{UInt8}, blob), nbytes)
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

sqlreturn(context, val::Bool) = sqlreturn(context, Int(val))
sqlreturn(context, val) = sqlreturn(context, sqlserialize(val))

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
        return $(nm)
    end
end
function scalarfunc(expr::Expr)
    f = eval(expr)
    return scalarfunc(f)
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

function stepfunc(init, func, fsym=symbol(string(func)*"_step"))
    nm = isdefined(Base,fsym) ? :(Base.$fsym) : fsym
    return quote
        function $(nm)(context::Ptr{Void}, nargs::Cint, values::Ptr{Ptr{Void}})
            args = [sqlvalue(values, i) for i in 1:nargs]

            intsize = sizeof(Int)
            ptrsize = sizeof(Ptr)
            acsize = intsize + ptrsize
            acptr = convert(Ptr{UInt8}, sqlite3_aggregate_context(context, acsize))

            # acptr will be zeroed-out if this is the first iteration
            ret = ccall(
                :memcmp, Cint, (Ptr{UInt8}, Ptr{UInt8}, Cuint),
                zeros(UInt8, acsize), acptr, acsize,
            )
            if ret == 0
                acval = $(init)
                valsize = 256
                # avoid the garbage collector using malloc
                valptr = convert(Ptr{UInt8}, Libc.malloc(valsize))
                valptr == C_NULL && throw(SQLiteException("memory error"))
            else
                # size of serialized value is first sizeof(Int) bytes
                valsize = bytestoint(acptr, 1, intsize)
                # ptr to serialized value is last sizeof(Ptr) bytes
                valptr = reinterpret(
                    Ptr{UInt8}, bytestoint(acptr, intsize+1, ptrsize)
                )
                # deserialize the value pointed to by valptr
                acvalbuf = zeros(UInt8, valsize)
                unsafe_copy!(pointer(acvalbuf), valptr, valsize)
                acval = sqldeserialize(acvalbuf)
            end

            local funcret
            try
                funcret = sqlserialize($(func)(acval, args...))
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
            unsafe_copy!(valptr, pointer(funcret), newsize)

            # copy the size of the serialized value
            unsafe_copy!(
                acptr,
                pointer(reinterpret(UInt8, [newsize])),
                intsize
            )
            # copy the address of the pointer to the serialized value
            valarr = reinterpret(UInt8, [valptr])
            for i in 1:length(valarr)
                unsafe_store!(acptr, valarr[i], intsize+i)
            end
            nothing
        end
        return $(nm)
    end
end

function finalfunc(init, func, fsym=symbol(string(func)*"_final"))
    nm = isdefined(Base,fsym) ? :(Base.$fsym) : fsym
    return quote
        function $(nm)(context::Ptr{Void}, nargs::Cint, values::Ptr{Ptr{Void}})
            acptr = convert(Ptr{UInt8}, sqlite3_aggregate_context(context, 0))

            # step function wasn't run
            if acptr == C_NULL
                sqlreturn(context, $(init))
            else
                intsize = sizeof(Int)
                ptrsize = sizeof(Ptr)
                acsize = intsize + ptrsize

                # load size
                valsize = bytestoint(acptr, 1, intsize)
                # load ptr
                valptr = reinterpret(
                    Ptr{UInt8}, bytestoint(acptr, intsize+1, ptrsize)
                )

                # load value
                acvalbuf = zeros(UInt8, valsize)
                unsafe_copy!(pointer(acvalbuf), valptr, valsize)
                acval = sqldeserialize(acvalbuf)

                local ret
                try
                    ret = $(func)(acval)
                finally
                    Libc.free(valptr)
                end
                sqlreturn(context, ret)
            end
            nothing
        end
        return $(nm)
    end
end

# User-facing macro for convenience in registering a simple function
# with no configurations needed
macro register(db, func)
    :(register($(esc(db)), $(esc(func))))
end

# User-facing method for registering a Julia function to be used within SQLite
function register(db, func::Function; nargs::Int=-1, name::AbstractString=string(func), isdeterm::Bool=true)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    # assume any negative number means a varargs function
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255"

    f = eval(scalarfunc(func,Symbol(name)))

    cfunc = cfunction(f, Void, (Ptr{Void}, Cint, Ptr{Ptr{Void}}))
    # TODO: allow the other encodings
    enc = SQLITE_UTF8
    enc = isdeterm ? enc | SQLITE_DETERMINISTIC : enc

    @CHECK db sqlite3_create_function_v2(
        db.handle, name, nargs, enc, C_NULL, cfunc, C_NULL, C_NULL, C_NULL
    )
end

# as above but for aggregate functions
function register(
    db, init, step::Function, final::Function=identity;
    nargs::Int=-1, name::AbstractString=string(step), isdeterm::Bool=true
)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255 chars"

    s = eval(stepfunc(init, step, Base.function_name(step)))
    cs = cfunction(s, Void, (Ptr{Void}, Cint, Ptr{Ptr{Void}}))
    f = eval(finalfunc(init, final, Base.function_name(final)))
    cf = cfunction(f, Void, (Ptr{Void}, Cint, Ptr{Ptr{Void}}))

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
