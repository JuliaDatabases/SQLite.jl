function registerfunc(db, name, nargs, func, step, final, isdeterm)
    #= 
     Create a function in the database connection db.
    =#
    if func != C_NULL
        if !(step == final == C_NULL)
            msg = "step and final can not be defined for scalar functions"
            throw(SQLiteException(msg))
        end
    else
        if step == C_NULL || final == C_NULL
            msg = "both step and final must be defined for aggregate functions"
            throw(SQLiteException(msg))
        end
        if func != C_NULL
            msg = "func must not be defined for aggregate functions"
            throw(SQLiteException(msg))
        end
    end

    @assert (-1 <= nargs <= 127) "nargs must follow the inequality -1 <= nargs <= 127"

    cfunc = func == C_NULL ? C_NULL : cfunction(
        func, Nothing, (Ptr{Void}, Cint, Ptr{Ptr{Void}})
    )
    cstep = step == C_NULL ? C_NULL : cfunction(
        step, Nothing, (Ptr{Void}, Cint, Ptr{Ptr{Void}})
    )
    cfinal = final == C_NULL ? C_NULL : cfunction(
        step, Nothing, (Ptr{Void}, Cint, Ptr{Ptr{Void}})
    )

    # TODO: allow the other encodings
    enc = SQLITE_UTF8
    enc = isdeterm ? enc | SQLITE_DETERMINISTIC : enc

    @CHECK db sqlite3_create_function_v2(
        db.handle, name, nargs, enc, C_NULL, cfunc, cstep, cfinal, C_NULL
    )
end

# scalar functions
function registerfunc(db::SQLiteDB, nargs::Integer, func::Function,
                      isdeterm::Bool=true; name="")
    name = isempty(name) ? string(func) : name::String
    registerfunc(db, name, nargs, func, C_NULL, C_NULL, isdeterm)
end

# aggregate functions
function registerfunc(db::SQLiteDB, nargs::Integer, step::Function,
                      final::Function, isdeterm::Bool=true; name="")
    name = isempty(name) ? string(step) : name::String
    registerfunc(db, name, nargs, C_NULL, step, final, isdeterm)
end

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

sqlreturn(context, ::NullType)        = sqlite3_result_null(context)
sqlreturn(context, val::Int32)        = sqlite3_result_int(context, val)
sqlreturn(context, val::Int64)        = sqlite3_result_int64(context, val)
sqlreturn(context, val::Float64)      = sqlite3_result_double(context, val)
sqlreturn(context, val::String)       = sqlite3_result_text(context, val)
sqlreturn(context, val::UTF16String)  = sqlite3_result_text16(context, val)
sqlreturn(context, val)               = sqlite3_result_blob(context, sqlserialize(val))

sqlreturn(context, val::Bool) = sqlreturn(context, int(val))

sqludferror(context, msg::String)      = sqlite3_result_error(context, msg)
sqludferror(context, msg::UTF16String) = sqlite3_result_error16(context, msg)

function funcname(expr)
    if length(expr) == 2
        func = expr[2]
        name = expr[1]
    else
        func = expr[1]
        name = func.args[1].args[1]
    end
    name, func
end

macro scalarfunc(args...)
    name, func = funcname(args)
    return quote
        function $(esc(name))(context::Ptr{Void}, nargs::Cint, values::Ptr{Ptr{Void}})
            args = [sqlvalue(values, i) for i in 1:nargs]
            ret = $(func)(args...)
            sqlreturn(context, ret)
            nothing
        end
    end
end


# annotate types because the MethodError makes more sense that way
@scalarfunc regexp(r::String, s::String) = ismatch(Regex(r), s)
# macro for preserving the special characters in a string
macro sr_str(s) s end
