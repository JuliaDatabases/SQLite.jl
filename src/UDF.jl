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
sqlreturn(context, val)                 = sqlite3_result_blob(context, sqlserialize(val))

sqlreturn(context, val::Bool) = sqlreturn(context, int(val))

sqludferror(context, msg::AbstractString)      = sqlite3_result_error(context, msg)
sqludferror(context, msg::UTF16String) = sqlite3_result_error16(context, msg)

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

# annotate types because the MethodError makes more sense that way
regexp(r::AbstractString, s::AbstractString) = ismatch(Regex(r), s)
# macro for preserving the special characters in a string
macro sr_str(s) s end
