"""
    SQLite.clear!(stmt::SQLite.Stmt)

Clears any bound values to a prepared SQL statement
"""
function clear!(stmt::Stmt)
    C.sqlite3_clear_bindings(_get_stmt_handle(stmt))
    empty!(stmt.params)
    return
end

"""
    SQLite.bind!(stmt::SQLite.Stmt, values)

bind `values` to parameters in a prepared [`SQLite.Stmt`](@ref). Values can be:

* `Vector` or `Tuple`: where each element will be bound to an SQL parameter by index order
* `Dict` or `NamedTuple`; where values will be bound to named SQL parameters by the `Dict`/`NamedTuple` key

Additional methods exist for working individual SQL parameters:

* `SQLite.bind!(stmt, name, val)`: bind a single value to a named SQL parameter
* `SQLite.bind!(stmt, index, val)`: bind a single value to a SQL parameter by index number

From the [SQLite documentation](https://www3.sqlite.org/cintro.html):

> Usually, though,
> it is not useful to evaluate exactly the same SQL statement more than once.
> More often, one wants to evaluate similar statements.
> For example, you might want to evaluate an INSERT statement
> multiple times though with different values to insert.
> To accommodate this kind of flexibility,
> SQLite allows SQL statements to contain parameters
> which are "bound" to values prior to being evaluated.
> These values can later be changed and the same prepared statement
> can be evaluated a second time using the new values.
>
> In SQLite,
> wherever it is valid to include a string literal,
> one can use a parameter in one of the following forms:
>
> - `?`
> - `?NNN`
> - `:AAA`
> - `\$AAA`
> - `@AAA`
>
> In the examples above,
> `NNN` is an integer value and `AAA` is an identifier.
> A parameter initially has a value of `NULL`.
> Prior to calling `sqlite3_step()` for the first time
> or immediately after `sqlite3_reset()``,
> the application can invoke one of the `sqlite3_bind()` interfaces
> to attach values to the parameters.
> Each call to `sqlite3_bind()` overrides prior bindings on the same parameter.

"""
function bind! end

function bind!(stmt::Stmt, params::DBInterface.NamedStatementParams)
    handle = _get_stmt_handle(stmt)
    nparams = C.sqlite3_bind_parameter_count(handle)
    (nparams <= length(params)) ||
        throw(SQLiteException("values should be provided for all query placeholders"))
    for i = 1:nparams
        name = unsafe_string(C.sqlite3_bind_parameter_name(handle, i))
        isempty(name) && throw(SQLiteException("nameless parameters should be passed as a Vector"))
        # name is returned with the ':', '@' or '$' at the start
        sym = Symbol(name[2:end])
        haskey(params, sym) || throw(
            SQLiteException(
                "`$name` not found in values keyword arguments to bind to sql statement",
            ),
        )
        bind!(stmt, i, params[sym])
    end
end

function bind!(stmt::Stmt, values::DBInterface.PositionalStatementParams)
    nparams = C.sqlite3_bind_parameter_count(_get_stmt_handle(stmt))
    (nparams == length(values)) ||
        throw(SQLiteException("values should be provided for all query placeholders"))
    for i = 1:nparams
        @inbounds bind!(stmt, i, values[i])
    end
end

bind!(stmt::Stmt; kwargs...) = bind!(stmt, kwargs.data)

# Binding parameters to SQL statements
function bind!(stmt::Stmt, name::AbstractString, val::Any)
    i::Int = C.sqlite3_bind_parameter_index(_get_stmt_handle(stmt), name)
    if i == 0
        throw(SQLiteException("SQL parameter $name not found in $stmt"))
    end
    return bind!(stmt, i, val)
end

# binding method for internal _Stmt class
bind!(stmt::Stmt, i::Integer, val::AbstractFloat) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_double(
        _get_stmt_handle(stmt),
        i,
        Float64(val),
    ); return nothing
)
bind!(stmt::Stmt, i::Integer, val::Int32) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_int(_get_stmt_handle(stmt), i, val); return nothing
)
bind!(stmt::Stmt, i::Integer, val::Int64) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_int64(_get_stmt_handle(stmt), i, val); return nothing
)
bind!(stmt::Stmt, i::Integer, val::Missing) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_null(_get_stmt_handle(stmt), i); return nothing
)
bind!(stmt::Stmt, i::Integer, val::Nothing) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_null(_get_stmt_handle(stmt), i); return nothing
)
bind!(stmt::Stmt, i::Integer, val::AbstractString) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_text(
        _get_stmt_handle(stmt),
        i,
        val,
        sizeof(val),
        C_NULL,
    ); return nothing
)
bind!(stmt::Stmt, i::Integer, val::WeakRefString{UInt8}) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_text(
        _get_stmt_handle(stmt),
        i,
        val.ptr,
        val.len,
        C_NULL,
    ); return nothing
)
bind!(stmt::Stmt, i::Integer, val::WeakRefString{UInt16}) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_text16(
        _get_stmt_handle(stmt),
        i,
        val.ptr,
        val.len * 2,
        C_NULL,
    ); return nothing
)
bind!(stmt::Stmt, i::Integer, val::Bool) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_int(_get_stmt_handle(stmt), i, Int32(val)); return nothing
)
bind!(stmt::Stmt, i::Integer, val::Vector{UInt8}) = (
    stmt.params[i] = val; @CHECK stmt.db C.sqlite3_bind_blob(
        _get_stmt_handle(stmt),
        i,
        val,
        sizeof(val),
        C.SQLITE_STATIC,
    ); return nothing
)
# Fallback is BLOB and defaults to serializing the julia value

# internal wrapper mutable struct to, in-effect, mark something which has been serialized
struct Serialized
    object::Any
end

function sqlserialize(x)
    buffer = IOBuffer()
    # deserialize will sometimes return a random object when called on an array
    # which has not been previously serialized, we can use this mutable struct to check
    # that the array has been serialized
    s = Serialized(x)
    Serialization.serialize(buffer, s)
    return take!(buffer)
end
# fallback method to bind arbitrary julia `val` to the parameter at index `i` (object is serialized)
bind!(stmt::Stmt, i::Integer, val::Any) = bind!(stmt, i, sqlserialize(val))

struct SerializeError <: Exception
    msg::String
end

# magic bytes that indicate that a value is in fact a serialized julia value, instead of just a byte vector
# these bytes depend on the julia version and other things, so they are determined using an actual serialization
const SERIALIZATION = sqlserialize(0)[1:18]

function sqldeserialize(r)
    if sizeof(r) < sizeof(SERIALIZATION)
        return r
    end
    ret = ccall(
        :memcmp,
        Int32,
        (Ptr{UInt8}, Ptr{UInt8}, UInt),
        SERIALIZATION,
        r,
        min(sizeof(SERIALIZATION), sizeof(r)),
    )
    if ret == 0
        try
            v = Serialization.deserialize(IOBuffer(r))
            return v.object
        catch e
            throw(
                SerializeError(
                    "Error deserializing non-primitive value out of database; this is probably due to using SQLite.jl with a different Julia version than was used to originally serialize the database values. The same Julia version that was used to serialize should be used to extract the database values into a different format (csv file, feather file, etc.) and then loaded back into the sqlite database with the current Julia version.",
                ),
            )
        end
    else
        return r
    end
end
#TODO:
#int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
#int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);
