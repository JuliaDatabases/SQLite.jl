module SQLite

using Random, Serialization
using WeakRefStrings, DBInterface

export DBInterface, SQLiteException

include("capi.jl")
import .C
struct SQLiteException <: Exception
    msg::AbstractString
end

# SQLite3 DB connection handle
const DBHandle = Ptr{C.sqlite3}
# SQLite3 statement handle
const StmtHandle = Ptr{C.sqlite3_stmt}

const StmtWrapper = Ref{StmtHandle}

# Normal constructor from filename
function sqliteexception(handle::DBHandle)
    isopen(handle) || throw(SQLiteException("DB is closed"))
    SQLiteException(unsafe_string(C.sqlite3_errmsg(handle)))
end
function sqliteexception(handle::DBHandle, stmt::StmtHandle)
    isopen(handle) || throw(SQLiteException("DB is closed"))
    errstr = unsafe_string(C.sqlite3_errmsg(handle))
    stmt_text_handle = C.sqlite3_expanded_sql(stmt)
    stmt_text = unsafe_string(stmt_text_handle)
    msg = "$errstr on statement \"$stmt_text\""
    C.sqlite3_free(stmt_text_handle)
    return SQLiteException(msg)
end

sqliteerror(args...) = throw(sqliteexception(args...))

include("base.jl")

"""
    `SQLite.DB()` => in-memory SQLite database
    `SQLite.DB(file)` => file-based SQLite database

Constructors for a representation of an sqlite database, either backed by an on-disk file or in-memory.

`SQLite.DB` requires the `file` string argument in the 2nd definition
as the name of either a pre-defined SQLite database to be opened,
or if the file doesn't exist, a database will be created.
Note that only sqlite 3.x version files are supported.

The `SQLite.DB` object represents a single connection to an SQLite database.
All other SQLite.jl functions take an `SQLite.DB` as the first argument as context.

To create an in-memory temporary database, call `SQLite.DB()`.

The `SQLite.DB` will be automatically closed/shutdown when it goes out of scope
(i.e. the end of the Julia session, end of a function call wherein it was created, etc.)
"""
mutable struct DB <: DBInterface.Connection
    file::String
    handle::DBHandle
    stmt_wrappers::WeakKeyDict{StmtWrapper,Nothing} # opened prepared statements
    registered_UDF_data::Vector{Any} # keep registered UDFs alive and not garbage collected

    function DB(f::AbstractString)
        handle_ptr = Ref{DBHandle}()
        f = String(isempty(f) ? f : expanduser(f))
        if @OK C.sqlite3_open(f, handle_ptr)
            db = new(f, handle_ptr[], WeakKeyDict{StmtWrapper,Nothing}(), Any[])
            finalizer(_close_db!, db)
            return db
        else # error
            sqliteerror(handle_ptr[])
        end
    end
end
DB() = DB(":memory:")
DBInterface.connect(::Type{DB}) = DB()
DBInterface.connect(::Type{DB}, f::AbstractString) = DB(f)
DBInterface.close!(db::DB) = _close_db!(db)
Base.close(db::DB) = _close_db!(db)
Base.isopen(db::DB) = isopen(db.handle)
Base.isopen(handle::DBHandle) = handle != C_NULL

function finalize_statements!(db::DB)
    # close stmts
    for stmt_wrapper in keys(db.stmt_wrappers)
        C.sqlite3_finalize(stmt_wrapper[])
        stmt_wrapper[] = C_NULL
    end
    empty!(db.stmt_wrappers)
end

function _close_db!(db::DB)
    finalize_statements!(db)

    # close DB
    C.sqlite3_close_v2(db.handle)
    db.handle = C_NULL

    return
end

sqliteexception(db::DB) = sqliteexception(db.handle)

function Base.show(io::IO, db::DB)
    print(io, string("SQLite.DB(", "\"$(db.file)\"", ")"))
end

# prepare given sql statement
function prepare_stmt_wrapper(db::DB, sql::AbstractString)
    handle_ptr = Ref{StmtHandle}()
    @CHECK db C.sqlite3_prepare_v2(
        db.handle,
        sql,
        sizeof(sql),
        handle_ptr,
        C_NULL,
    )
    return handle_ptr
end

"""
    SQLite.Stmt(db, sql; register = true) => SQL.Stmt

Prepares an optimized internal representation of SQL statement in
the context of the provided SQLite3 `db` and constructs the `SQLite.Stmt`
Julia object that holds a reference to the prepared statement.

*Note*: the `sql` statement is not actually executed, but only compiled
(mainly for usage where the same statement is executed multiple times
with different parameters bound as values).

The `SQLite.Stmt` will be automatically closed/shutdown when it goes out of scope
(i.e. the end of the Julia session, end of a function call wherein it was created, etc.).
One can also call `DBInterface.close!(stmt)` to immediately close it.

The keyword argument `register` controls whether the created `Stmt` is registered in the
provided SQLite3 database `db`. All registered and unclosed statements of a given DB
connection are automatically closed when the DB is garbage collected or closed explicitly
after calling `close(db)` or `DBInterface.close!(db)`.
"""
mutable struct Stmt <: DBInterface.Statement
    db::DB
    stmt_wrapper::StmtWrapper
    # used for holding references to bound statement values via bind!
    params::Dict{Int,Any}

    function Stmt(db::DB, sql::AbstractString; register::Bool = true)
        stmt_wrapper = prepare_stmt_wrapper(db, sql)
        if register
            db.stmt_wrappers[stmt_wrapper] = nothing
        end
        stmt = new(db, stmt_wrapper, Dict{Int,Any}())
        finalizer(_close_stmt!, stmt)
        return stmt
    end
end

_get_stmt_handle(stmt::Stmt) = stmt.stmt_wrapper[]
function _set_stmt_handle(stmt::Stmt, handle)
    stmt.stmt_wrapper[] = handle
end

# check if the statement is ready (not finalized due to _close_stmt!(Stmt) called)
isready(stmt::Stmt) = _get_stmt_handle(stmt) != C_NULL

function _close_stmt!(stmt::Stmt)
    C.sqlite3_finalize(_get_stmt_handle(stmt))
    _set_stmt_handle(stmt, C_NULL)
end

function sqliteexception(db::DB, stmt::Stmt)
    sqliteexception(db.handle, _get_stmt_handle(stmt))
end

"""
    DBInterface.prepare(db::SQLite.DB, sql::AbstractString)

Prepare an SQL statement given as a string in the sqlite database; returns an `SQLite.Stmt` compiled object.
See `DBInterface.execute`(@ref) for information on executing a prepared statement and passing parameters to bind.
A `SQLite.Stmt` object can be closed (resources freed) using `DBInterface.close!`(@ref).
"""
DBInterface.prepare(db::DB, sql::AbstractString) = Stmt(db, sql)
DBInterface.getconnection(stmt::Stmt) = stmt.db
DBInterface.close!(stmt::Stmt) = _close_stmt!(stmt)

include("UDF.jl")
export @sr_str

"""
    SQLite.clear!(stmt::SQLite.Stmt)

Clears any bound values to a prepared SQL statement
"""
function clear!(stmt::Stmt)
    C.sqlite3_clear_bindings(_get_stmt_handle(stmt))
    empty!(stmt.params)
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
    (nparams <= length(params)) || throw(
        SQLiteException("values should be provided for all query placeholders"),
    )
    for i in 1:nparams
        name = unsafe_string(C.sqlite3_bind_parameter_name(handle, i))
        isempty(name) && throw(
            SQLiteException("nameless parameters should be passed as a Vector"),
        )
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
    (nparams == length(values)) || throw(
        SQLiteException("values should be provided for all query placeholders"),
    )
    for i in 1:nparams
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
    bind!(stmt, i, val)
end

# binding method for internal _Stmt class
function bind!(stmt::Stmt, i::Integer, val::AbstractFloat)
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_double(
        _get_stmt_handle(stmt),
        i,
        Float64(val),
    )
end
function bind!(stmt::Stmt, i::Integer, val::Int32)
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_int(_get_stmt_handle(stmt), i, val)
end
function bind!(stmt::Stmt, i::Integer, val::Int64)
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_int64(_get_stmt_handle(stmt), i, val)
end
function bind!(stmt::Stmt, i::Integer, val::Missing)
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_null(_get_stmt_handle(stmt), i)
end
function bind!(stmt::Stmt, i::Integer, val::Nothing)
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_null(_get_stmt_handle(stmt), i)
end
function bind!(stmt::Stmt, i::Integer, val::AbstractString)
    cval = Base.cconvert(Ptr{Cchar}, val)
    stmt.params[i] = cval
    @CHECK stmt.db C.sqlite3_bind_text(
        _get_stmt_handle(stmt),
        i,
        cval,
        sizeof(val),
        C_NULL,
    )
end
function bind!(stmt::Stmt, i::Integer, val::WeakRefString{UInt8})
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_text(
        _get_stmt_handle(stmt),
        i,
        val.ptr,
        val.len,
        C_NULL,
    )
end
function bind!(stmt::Stmt, i::Integer, val::WeakRefString{UInt16})
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_text16(
        _get_stmt_handle(stmt),
        i,
        val.ptr,
        val.len * 2,
        C_NULL,
    )
end
function bind!(stmt::Stmt, i::Integer, val::Bool)
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_int(_get_stmt_handle(stmt), i, Int32(val))
end
function bind!(stmt::Stmt, i::Integer, val::Vector{UInt8})
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_blob(
        _get_stmt_handle(stmt),
        i,
        val,
        sizeof(val),
        C.SQLITE_STATIC,
    )
end
function bind!(stmt::Stmt, i::Integer, val::Base.ReinterpretArray{UInt8, 1, T, <:DenseVector{T}, false}) where T
    stmt.params[i] = val
    @CHECK stmt.db C.sqlite3_bind_blob(
        _get_stmt_handle(stmt),
        i,
        Ref(val, 1),
        sizeof(eltype(val)) * length(val),
        C.SQLITE_STATIC,
    )
end
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

# get julia type for given column of the given statement
function juliatype(handle, col)
    stored_typeid = C.sqlite3_column_type(handle, col - 1)
    if stored_typeid == C.SQLITE_BLOB
        # blobs are serialized julia types, so just try to deserialize it
        deser_val = sqlitevalue(Any, handle, col)
        # FIXME deserialized type have priority over declared type, is it fine?
        return typeof(deser_val)
    else
        stored_type = juliatype(stored_typeid)
    end
    decl_typestr = C.sqlite3_column_decltype(handle, col - 1)
    if decl_typestr != C_NULL
        return juliatype(unsafe_string(decl_typestr), stored_type)
    else
        return stored_type
    end
end

# convert SQLite stored type into Julia equivalent
function juliatype(x::Integer)
    x == C.SQLITE_INTEGER ? Int64 :
    x == C.SQLITE_FLOAT ? Float64 :
    x == C.SQLITE_TEXT ? String : x == C.SQLITE_NULL ? Missing : Any
end

# convert SQLite declared type into Julia equivalent,
# fall back to default (stored type), if no good match
function juliatype(decl_typestr::AbstractString, default::Type = Any)
    typeuc = uppercase(decl_typestr)
    # try to match the type affinities described in the "Affinity Name Examples" section
    # of https://www.sqlite.org/datatype3.html
    if typeuc in (
        "INTEGER",
        "INT",
        "TINYINT",
        "SMALLINT",
        "MEDIUMINT",
        "BIGINT",
        "UNSIGNED BIG INT",
        "INT2",
        "INT8",
    )
        return Int64
    elseif typeuc in ("NUMERIC", "REAL", "FLOAT", "DOUBLE", "DOUBLE PRECISION")
        return Float64
    elseif typeuc == "TEXT"
        return String
    elseif typeuc == "BLOB"
        return Any
    elseif typeuc == "DATETIME"
        return default # FIXME
    elseif typeuc == "TIMESTAMP"
        return default # FIXME
    elseif occursin(
        r"^N?V?A?R?Y?I?N?G?\s*CHARA?C?T?E?R?T?E?X?T?\s*\(?\d*\)?$"i,
        typeuc,
    )
        return String
    elseif occursin(r"^NUMERIC\(\d+,\d+\)$", typeuc)
        return Float64
    else
        return default
    end
end

function sqlitevalue(
    ::Type{T},
    handle,
    col,
) where {T<:Union{Base.BitSigned,Base.BitUnsigned}}
    convert(T, C.sqlite3_column_int64(handle, col - 1))
end
const FLOAT_TYPES = Union{Float16,Float32,Float64} # exclude BigFloat
function sqlitevalue(::Type{T}, handle, col) where {T<:FLOAT_TYPES}
    convert(T, C.sqlite3_column_double(handle, col - 1))
end
#TODO: test returning a WeakRefString instead of calling `unsafe_string`
function sqlitevalue(::Type{T}, handle, col) where {T<:AbstractString}
    convert(T, unsafe_string(C.sqlite3_column_text(handle, col - 1)))
end
function sqlitevalue(::Type{T}, handle, col) where {T}
    blob = convert(Ptr{UInt8}, C.sqlite3_column_blob(handle, col - 1))
    b = C.sqlite3_column_bytes(handle, col - 1)
    buf = zeros(UInt8, b) # global const?
    unsafe_copyto!(pointer(buf), blob, b)
    r = sqldeserialize(buf)
    return r
end

# conversion from Julia to SQLite3 types
sqlitetype_(::Type{<:Integer}) = "INT"
sqlitetype_(::Type{<:AbstractFloat}) = "REAL"
sqlitetype_(::Type{<:AbstractString}) = "TEXT"
sqlitetype_(::Type{Bool}) = "INT"
sqlitetype_(::Type) = "BLOB" # fallback

sqlitetype(::Type{Missing}) = "NULL"
sqlitetype(::Type{Nothing}) = "NULL"
sqlitetype(::Type{Union{T,Missing}}) where {T} = sqlitetype_(T)
sqlitetype(::Type{T}) where {T} = string(sqlitetype_(T), " NOT NULL")

"""
    SQLite.execute(db::SQLite.DB, sql::AbstractString, [params]) -> Int
    SQLite.execute(stmt::SQLite.Stmt, [params]) -> Int

An internal method that executes the SQL statement (provided either as a `db` connection and `sql` command,
or as an already prepared `stmt` (see [`SQLite.Stmt`](@ref))) with given `params` parameters
(either positional (`Vector` or `Tuple`), named (`Dict` or `NamedTuple`), or specified as keyword arguments).

Returns the SQLite status code of operation.

*Note*: this is a low-level method that just executes the SQL statement,
but does not retrieve any data from `db`.
To get the results of a SQL query, it is recommended to use [`DBInterface.execute`](@ref).
"""
function execute end

function execute(db::DB, stmt::Stmt, params::DBInterface.StatementParams = ())
    handle = _get_stmt_handle(stmt)
    C.sqlite3_reset(handle)
    bind!(stmt, params)
    r = C.sqlite3_step(handle)
    if r == C.SQLITE_DONE
        C.sqlite3_reset(handle)
    elseif r != C.SQLITE_ROW
        e = sqliteexception(db)
        C.sqlite3_reset(handle)
        throw(e)
    end
    return r
end

function execute(stmt::Stmt, params::DBInterface.StatementParams)
    execute(stmt.db, stmt, params)
end

execute(stmt::Stmt; kwargs...) = execute(stmt.db, stmt, NamedTuple(kwargs))

function execute(
    db::DB,
    sql::AbstractString,
    params::DBInterface.StatementParams,
)
    # prepare without registering Stmt in DB
    stmt = Stmt(db, sql; register = false)
    try
        return execute(db, stmt, params)
    finally
        _close_stmt!(stmt) # immediately close, don't wait for GC
    end
end

function execute(db::DB, sql::AbstractString; kwargs...)
    execute(db, sql, NamedTuple(kwargs))
end

"""
    SQLite.esc_id(x::Union{AbstractString,Vector{AbstractString}})

Escape SQLite identifiers
(e.g. column, table or index names).
Can be either a string or a vector of strings
(note does not check for null characters).
A vector of identifiers will be separated by commas.

Example:

```julia
julia> using SQLite, DataFrames

julia> df = DataFrame(label=string.(rand("abcdefg", 10)), value=rand(10));

julia> db = SQLite.DB(mktemp()[1]);

julia> tbl |> SQLite.load!(db, "temp");

julia> DBInterface.execute(db,"SELECT * FROM temp WHERE label IN ('a','b','c')") |> DataFrame
4×2 DataFrame
│ Row │ label   │ value    │
│     │ String⍰ │ Float64⍰ │
├─────┼─────────┼──────────┤
│ 1   │ c       │ 0.603739 │
│ 2   │ c       │ 0.429831 │
│ 3   │ b       │ 0.799696 │
│ 4   │ a       │ 0.603586 │

julia> q = ['a','b','c'];

julia> DBInterface.execute(db,"SELECT * FROM temp WHERE label IN (\$(SQLite.esc_id(q)))") |> DataFrame
4×2 DataFrame
│ Row │ label   │ value    │
│     │ String⍰ │ Float64⍰ │
├─────┼─────────┼──────────┤
│ 1   │ c       │ 0.603739 │
│ 2   │ c       │ 0.429831 │
│ 3   │ b       │ 0.799696 │
│ 4   │ a       │ 0.603586 │
```
"""
function esc_id end

esc_id(x::AbstractString) = "\"" * replace(x, "\"" => "\"\"") * "\""
function esc_id(X::AbstractVector{S}) where {S<:AbstractString}
    join(map(esc_id, X), ',')
end

# Transaction-based commands
"""
    SQLite.transaction(db, mode="DEFERRED")
    SQLite.transaction(func, db)

Begin a transaction in the specified `mode`, default = "DEFERRED".

If `mode` is one of "", "DEFERRED", "IMMEDIATE" or "EXCLUSIVE" then a
transaction of that (or the default) mutable struct is started. Otherwise a savepoint
is created whose name is `mode` converted to AbstractString.

In the second method, `func` is executed within a transaction (the transaction being committed upon successful execution)
"""
function transaction end

function transaction(db::DB, mode = "DEFERRED")
    execute(db, "PRAGMA temp_store=MEMORY;")
    if uppercase(mode) in ["", "DEFERRED", "IMMEDIATE", "EXCLUSIVE"]
        execute(db, "BEGIN $(mode) TRANSACTION;")
    else
        execute(db, "SAVEPOINT $(mode);")
    end
end

DBInterface.transaction(f, db::DB) = transaction(f, db)

@inline function transaction(f::Function, db::DB)
    # generate a random name for the savepoint
    name = string("SQLITE", Random.randstring(10))
    execute(db, "PRAGMA synchronous = OFF;")
    transaction(db, name)
    try
        f()
    catch
        rollback(db, name)
        rethrow()
    finally
        # savepoints are not released on rollback
        commit(db, name)
        execute(db, "PRAGMA synchronous = ON;")
    end
end

"""
    SQLite.commit(db)
    SQLite.commit(db, name)

commit a transaction or named savepoint
"""
function commit end

commit(db::DB) = execute(db, "COMMIT TRANSACTION;")
commit(db::DB, name::AbstractString) = execute(db, "RELEASE SAVEPOINT $(name);")

"""
    SQLite.rollback(db)
    SQLite.rollback(db, name)

rollback transaction or named savepoint
"""
function rollback end

rollback(db::DB) = execute(db, "ROLLBACK TRANSACTION;")
function rollback(db::DB, name::AbstractString)
    execute(db, "ROLLBACK TRANSACTION TO SAVEPOINT $(name);")
end

"""
    SQLite.drop!(db, table; ifexists::Bool=false)

drop the SQLite table `table` from the database `db`; `ifexists=true` will prevent an error being thrown if `table` doesn't exist
"""
function drop!(db::DB, table::AbstractString; ifexists::Bool = false)
    exists = ifexists ? "IF EXISTS" : ""
    transaction(db) do
        execute(db, "DROP TABLE $exists $(esc_id(table))")
    end
    execute(db, "VACUUM")
end

"""
    SQLite.dropindex!(db, index; ifexists::Bool=false)

drop the SQLite index `index` from the database `db`; `ifexists=true` will not return an error if `index` doesn't exist
"""
function dropindex!(db::DB, index::AbstractString; ifexists::Bool = false)
    exists = ifexists ? "IF EXISTS" : ""
    transaction(db) do
        execute(db, "DROP INDEX $exists $(esc_id(index))")
    end
end

"""
    SQLite.createindex!(db, table, index, cols; unique=true, ifnotexists=false)

create the SQLite index `index` on the table `table` using `cols`,
which may be a single column or vector of columns.
`unique` specifies whether the index will be unique or not.
`ifnotexists=true` will not throw an error if the index already exists
"""
function createindex!(
    db::DB,
    table::AbstractString,
    index::AbstractString,
    cols::Union{S,AbstractVector{S}};
    unique::Bool = true,
    ifnotexists::Bool = false,
) where {S<:AbstractString}
    u = unique ? "UNIQUE" : ""
    exists = ifnotexists ? "IF NOT EXISTS" : ""
    transaction(db) do
        execute(
            db,
            "CREATE $u INDEX $exists $(esc_id(index)) ON $(esc_id(table)) ($(esc_id(cols)))",
        )
    end
    execute(db, "ANALYZE $index")
    return
end

"""
    SQLite.removeduplicates!(db, table, cols)

Removes duplicate rows from `table` based on the values in `cols`, which is an array of column names.

A convenience method for the common task of removing duplicate
rows in a dataset according to some subset of columns that make up a "primary key".
"""
function removeduplicates!(
    db::DB,
    table::AbstractString,
    cols::AbstractArray{T},
) where {T<:AbstractString}
    colsstr = ""
    for c in cols
        colsstr = colsstr * esc_id(c) * ","
    end
    colsstr = chop(colsstr)
    transaction(db) do
        execute(
            db,
            "DELETE FROM $(esc_id(table)) WHERE _ROWID_ NOT IN (SELECT max(_ROWID_) from $(esc_id(table)) GROUP BY $(colsstr));",
        )
    end
    execute(db, "ANALYZE $table")
end

include("tables.jl")

"""
    SQLite.tables(db, sink=columntable)

returns a list of tables in `db`
"""
function tables(db::DB, sink = columntable)
    tblnames = DBInterface.execute(
        sink,
        db,
        "SELECT name FROM sqlite_master WHERE type='table';",
    )
    return [
        DBTable(
            tbl,
            Tables.schema(
                DBInterface.execute(db, "SELECT * FROM $(esc_id(tbl)) LIMIT 0"),
            ),
        ) for tbl in tblnames.name
    ]
end

"""
    SQLite.indices(db, sink=columntable)

returns a list of indices in `db`
"""
function indices(db::DB, sink = columntable)
    DBInterface.execute(
        sink,
        db,
        "SELECT name FROM sqlite_master WHERE type='index';",
    )
end

"""
    SQLite.columns(db, table, sink=columntable)

returns a list of columns in `table`
"""
function columns(db::DB, table::AbstractString, sink = columntable)
    DBInterface.execute(sink, db, "PRAGMA table_info($(esc_id(table)))")
end

"""
    SQLite.last_insert_rowid(db)

returns the auto increment id of the last row
"""
last_insert_rowid(db::DB) = C.sqlite3_last_insert_rowid(db.handle)

"""
    SQLite.enable_load_extension(db, enable::Bool=true)

Enables extension loading (off by default) on the sqlite database `db`. Pass `false` as the second argument to disable.
"""
function enable_load_extension(db::DB, enable::Bool = true)
    C.sqlite3_enable_load_extension(db.handle, enable)
end

"""
    SQLite.busy_timeout(db, ms::Integer=0)

Set a busy handler that sleeps for a specified amount of milliseconds  when a table is locked. After at least ms milliseconds of sleeping, the handler will return 0, causing sqlite to return SQLITE_BUSY.
"""
busy_timeout(db::DB, ms::Integer = 0) = C.sqlite3_busy_timeout(db.handle, ms)

end # module
