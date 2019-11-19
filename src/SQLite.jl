module SQLite

using Random, Serialization
using WeakRefStrings, DataFrames

struct SQLiteException <: Exception
    msg::AbstractString
end

include("consts.jl")
include("api.jl")

# Normal constructor from filename
sqliteopen(file, handle) = sqlite3_open(file, handle)
sqliteerror(db) = throw(SQLiteException(unsafe_string(sqlite3_errmsg(db.handle))))
sqliteexception(db) = SQLiteException(unsafe_string(sqlite3_errmsg(db.handle)))

"""
represents an SQLite database, either backed by an on-disk file or in-memory

Constructors:

* `SQLite.DB()` => in-memory SQLite database
* `SQLite.DB(file)` => file-based SQLite database
"""
mutable struct DB
    file::String
    handle::Ptr{Cvoid}
    changes::Int

    function DB(f::AbstractString)
        handle = Ref{Ptr{Cvoid}}()
        f = isempty(f) ? f : expanduser(f)
        if @OK sqliteopen(f, handle)
            db = new(f, handle[], 0)
            finalizer(_close, db)
            return db
        else # error
            db = new(f, handle[], 0)
            finalizer(_close, db)
            sqliteerror(db)
        end
    end
end
DB() = DB(":memory:")

function _close(db::DB)
    db.handle == C_NULL || sqlite3_close_v2(db.handle)
    db.handle = C_NULL
    return
end

Base.show(io::IO, db::SQLite.DB) = print(io, string("SQLite.DB(", db.file == ":memory:" ? "in-memory" : "\"$(db.file)\"", ")"))

"""
`SQLite.Stmt(db::DB, sql::AbstractString)` creates and prepares an SQLite statement
"""
mutable struct Stmt
    db::DB
    handle::Ptr{Cvoid}
    params::Dict{Int, Any}

    function Stmt(db::DB,sql::AbstractString)
        handle = Ref{Ptr{Cvoid}}()
        sqliteprepare(db, sql, handle, Ref{Ptr{Cvoid}}())
        stmt = new(db, handle[], Dict{Int, Any}())
        finalizer(_close, stmt)
        return stmt
    end
end

function _close(stmt::Stmt)
    stmt.handle == C_NULL || sqlite3_finalize(stmt.handle)
    stmt.handle = C_NULL
    return
end

sqliteprepare(db, sql, stmt, null) = @CHECK db sqlite3_prepare_v2(db.handle, sql, stmt, null)

include("UDF.jl")
export @sr_str, @register, register

"""
`SQLite.clear!(stmt::SQLite.Stmt)`

clears any bound values to a prepared SQL statement.
"""
function clear!(stmt::Stmt)
    sqlite3_clear_bindings(stmt.handle)
    empty!(stmt.params)
    return
end

"""
`SQLite.bind!(stmt::SQLite.Stmt, values)`

bind `values` to parameters in a prepared SQL statement. Values can be:

* `Vector`; where each element will be bound to an SQL parameter by index order
* `Dict`; where dict values will be bound to named SQL parameters by the dict key

Additional methods exist for working individual SQL parameters:

* `SQLite.bind!(stmt, name, val)`: bind a single value to a named SQL parameter
* `SQLite.bind!(stmt, index, val)`: bind a single value to a SQL parameter by index number
"""
function bind! end

bind!(stmt::Stmt, ::Nothing) = nothing

function bind!(stmt::Stmt, values::Tuple)
    nparams = sqlite3_bind_parameter_count(stmt.handle)
    @assert nparams == length(values) "you must provide values for all query placeholders"
    for i in 1:nparams
        @inbounds bind!(stmt, i, values[i])
    end
end
function bind!(stmt::Stmt, values::Vector)
    nparams = sqlite3_bind_parameter_count(stmt.handle)
    @assert nparams == length(values) "you must provide values for all query placeholders"
    for i in 1:nparams
        @inbounds bind!(stmt, i, values[i])
    end
end
function bind!(stmt::Stmt, values::Dict{Symbol, V}) where {V}
    nparams = sqlite3_bind_parameter_count(stmt.handle)
    for i in 1:nparams
        name = unsafe_string(sqlite3_bind_parameter_name(stmt.handle, i))
        @assert !isempty(name) "nameless parameters should be passed as a Vector"
        # name is returned with the ':', '@' or '$' at the start
        name = name[2:end]
        haskey(values, name) || throw(SQLiteException("`$name` not found in values Dict to bind to sql statement"))
        bind!(stmt, i, values[Symbol(name)])
    end
end
# Binding parameters to SQL statements
function bind!(stmt::Stmt,name::AbstractString, val)
    i::Int = sqlite3_bind_parameter_index(stmt.handle, name)
    if i == 0
        throw(SQLiteException("SQL parameter $name not found in $stmt"))
    end
    return bind!(stmt, i, val)
end
bind!(stmt::Stmt, i::Int, val::AbstractFloat)  = (stmt.params[i] = val; @CHECK stmt.db sqlite3_bind_double(stmt.handle, i ,Float64(val)); return nothing)
bind!(stmt::Stmt, i::Int, val::Int32)          = (stmt.params[i] = val; @CHECK stmt.db sqlite3_bind_int(stmt.handle, i ,val); return nothing)
bind!(stmt::Stmt, i::Int, val::Int64)          = (stmt.params[i] = val; @CHECK stmt.db sqlite3_bind_int64(stmt.handle, i ,val); return nothing)
bind!(stmt::Stmt, i::Int, val::Missing)        = (stmt.params[i] = val; @CHECK stmt.db sqlite3_bind_null(stmt.handle, i ); return nothing)
bind!(stmt::Stmt, i::Int, val::AbstractString) = (stmt.params[i] = val; @CHECK stmt.db sqlite3_bind_text(stmt.handle, i ,val); return nothing)
bind!(stmt::Stmt, i::Int, val::WeakRefString{UInt8})   = (stmt.params[i] = val; @CHECK stmt.db sqlite3_bind_text(stmt.handle, i, val.ptr, val.len); return nothing)
bind!(stmt::Stmt, i::Int, val::WeakRefString{UInt16})  = (stmt.params[i] = val; @CHECK stmt.db sqlite3_bind_text16(stmt.handle, i, val.ptr, val.len*2); return nothing)
bind!(stmt::Stmt, i::Int, val::Vector{UInt8})  = (stmt.params[i] = val; @CHECK stmt.db sqlite3_bind_blob(stmt.handle, i, val); return nothing)
# Fallback is BLOB and defaults to serializing the julia value

# internal wrapper mutable struct to, in-effect, mark something which has been serialized
struct Serialized
    object
end

const GLOBAL_BUF = IOBuffer()
function sqlserialize(x)
    seekstart(GLOBAL_BUF)
    # deserialize will sometimes return a random object when called on an array
    # which has not been previously serialized, we can use this mutable struct to check
    # that the array has been serialized
    s = Serialized(x)
    Serialization.serialize(GLOBAL_BUF, s)
    return take!(GLOBAL_BUF)
end
# fallback method to bind arbitrary julia `val` to the parameter at index `i` (object is serialized)
bind!(stmt::Stmt, i::Int, val) = bind!(stmt, i, sqlserialize(val))

struct SerializeError <: Exception
    msg::String
end

# magic bytes that indicate that a value is in fact a serialized julia value, instead of just a byte vector
# these bytes depend on the julia version and other things, so they are determined using an actual serialization
const SERIALIZATION = sqlserialize(0)[1:18]

function sqldeserialize(r)
    ret = ccall(:memcmp, Int32, (Ptr{UInt8}, Ptr{UInt8}, UInt),
            SERIALIZATION, r, min(sizeof(SERIALIZATION), sizeof(r)))
    if ret == 0
        try
            v = Serialization.deserialize(IOBuffer(r))
            return v.object
        catch e
            throw(SerializeError("Error deserializing non-primitive value out of database; this is probably due to using SQLite.jl with a different Julia version than was used to originally serialize the database values. The same Julia version that was used to serialize should be used to extract the database values into a different format (csv file, feather file, etc.) and then loaded back into the sqlite database with the current Julia version."))
        end
    else
        return r
    end
end
#TODO:
 #int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
 #int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);

function juliatype(handle, col)
    t = SQLite.sqlite3_column_decltype(handle, col)
    if t != C_NULL
        T = juliatype(unsafe_string(t))
        T !== Any && return T
    end
    x = SQLite.sqlite3_column_type(handle, col)
    if x == SQLite.SQLITE_BLOB
        val = SQLite.sqlitevalue(Any, handle, col)
        return typeof(val)
    else
        return juliatype(x)
    end
end

juliatype(x::Integer) = x == SQLITE_INTEGER ? Int : x == SQLITE_FLOAT ? Float64 : x == SQLITE_TEXT ? String : Any
juliatype(x::String) = x == "INTEGER" ? Int : x in ("NUMERIC","REAL") ? Float64 : x == "TEXT" ? String : Any

sqlitevalue(::Type{T}, handle, col) where {T <: Union{Base.BitSigned, Base.BitUnsigned}} = convert(T, sqlite3_column_int64(handle, col))
const FLOAT_TYPES = Union{Float16, Float32, Float64} # exclude BigFloat
sqlitevalue(::Type{T}, handle, col) where {T <: FLOAT_TYPES} = convert(T, sqlite3_column_double(handle, col))
#TODO: test returning a WeakRefString instead of calling `unsafe_string`
sqlitevalue(::Type{T}, handle, col) where {T <: AbstractString} = convert(T, unsafe_string(sqlite3_column_text(handle, col)))
function sqlitevalue(::Type{T}, handle, col) where {T}
    blob = convert(Ptr{UInt8}, sqlite3_column_blob(handle, col))
    b = sqlite3_column_bytes(handle, col)
    buf = zeros(UInt8, b) # global const?
    unsafe_copyto!(pointer(buf), blob, b)
    r = sqldeserialize(buf)::T
    return r
end

sqlitetype(::Type{T}) where {T<:Integer} = "INT NOT NULL"
sqlitetype(::Type{T}) where {T<:Union{Missing, Integer}} = "INT"
sqlitetype(::Type{T}) where {T<:AbstractFloat} = "REAL NOT NULL"
sqlitetype(::Type{T}) where {T<:Union{Missing, AbstractFloat}} = "REAL"
sqlitetype(::Type{T}) where {T<:AbstractString} = "TEXT NOT NULL"
sqlitetype(::Type{T}) where {T<:Union{Missing, AbstractString}} = "TEXT"
sqlitetype(::Type{Missing}) = "NULL"
sqlitetype(x) = "BLOB"

"""
  `SQLite.execute!(stmt::SQLite.Stmt; values=[])` => `nothing`
  `SQLite.execute!(db::DB, sql::String)` => `nothing`

Execute a prepared SQLite statement, not checking for or returning any results.
Will bind `values` to any parameters in `stmt`.
"""
function execute! end

function execute!(stmt::Stmt; values=nothing)
    bind!(stmt, values)
    r = sqlite3_step(stmt.handle)
    if r == SQLITE_DONE
        sqlite3_reset(stmt.handle)
    elseif r != SQLITE_ROW
        e = sqliteexception(stmt.db)
        sqlite3_reset(stmt.handle)
        throw(e)
    end
    return r
end

function execute!(db::DB, sql::AbstractString; values=nothing)
    stmt = Stmt(db, sql)
    bind!(stmt, values)
    r = execute!(stmt)
    finalize(stmt)
    return r
end

"""
`SQLite.esc_id(x::Union{String,Vector{String}})`

Escape SQLite identifiers (e.g. column, table or index names). Can be either
a string, or a vector of strings (note does not check for null characters).
A vector of identifiers will be separated by commas.
"""
function esc_id end

esc_id(x::AbstractString) = "\"" * replace(x, "\""=>"\"\"") * "\""
esc_id(X::AbstractVector{S}) where {S <: AbstractString} = join(map(esc_id, X), ',')

# Transaction-based commands
"""
`SQLite.transaction(db, mode="DEFERRED")`

`SQLite.transaction(func, db)`


Begin a transaction in the specified `mode`, default = "DEFERRED".

If `mode` is one of "", "DEFERRED", "IMMEDIATE" or "EXCLUSIVE" then a
transaction of that (or the default) mutable struct is started. Otherwise a savepoint
is created whose name is `mode` converted to AbstractString.

In the second method, `func` is executed within a transaction (the transaction being committed upon successful execution)
"""
function transaction end

function transaction(db, mode="DEFERRED")
    execute!(db, "PRAGMA temp_store=MEMORY;")
    if uppercase(mode) in ["", "DEFERRED", "IMMEDIATE", "EXCLUSIVE"]
        execute!(db, "BEGIN $(mode) TRANSACTION;")
    else
        execute!(db, "SAVEPOINT $(mode);")
    end
end

@inline function transaction(f::Function, db)
    # generate a random name for the savepoint
    name = string("SQLITE", Random.randstring(10))
    execute!(db, "PRAGMA synchronous = OFF;")
    transaction(db, name)
    try
        f()
    catch
        rollback(db, name)
        rethrow()
    finally
        # savepoints are not released on rollback
        commit(db, name)
        execute!(db, "PRAGMA synchronous = ON;")
    end
end

"""
`SQLite.commit(db)`

`SQLite.commit(db, name)`


commit a transaction or named savepoint
"""
function commit end

commit(db) = execute!(db, "COMMIT TRANSACTION;")
commit(db, name) = execute!(db, "RELEASE SAVEPOINT $(name);")

"""
`SQLite.rollback(db)`

`SQLite.rollback(db, name)`


rollback transaction or named savepoint
"""
function rollback end

rollback(db) = execute!(db, "ROLLBACK TRANSACTION;")
rollback(db, name) = execute!(db, "ROLLBACK TRANSACTION TO SAVEPOINT $(name);")

"""
`SQLite.drop!(db, table; ifexists::Bool=true)`

drop the SQLite table `table` from the database `db`; `ifexists=true` will prevent an error being thrown if `table` doesn't exist
"""
function drop!(db::DB, table::AbstractString; ifexists::Bool=false)
    exists = ifexists ? "IF EXISTS" : ""
    transaction(db) do
        execute!(db, "DROP TABLE $exists $(esc_id(table))")
    end
    execute!(db, "VACUUM")
    return
end

"""
`SQLite.dropindex!(db, index; ifexists::Bool=true)`

drop the SQLite index `index` from the database `db`; `ifexists=true` will not return an error if `index` doesn't exist
"""
function dropindex!(db::DB, index::AbstractString; ifexists::Bool=false)
    exists = ifexists ? "IF EXISTS" : ""
    transaction(db) do
        execute!(db, "DROP INDEX $exists $(esc_id(index))")
    end
    return
end

"""
`SQLite.createindex!(db, table, index, cols; unique::Bool=true, ifnotexists::Bool=false)`

create the SQLite index `index` on the table `table` using `cols`, which may be a single column or vector of columns.
`unique` specifies whether the index will be unique or not.
`ifnotexists=true` will not throw an error if the index already exists
"""
function createindex!(db::DB, table::AbstractString, index::AbstractString, cols::Union{S, AbstractVector{S}};
                      unique::Bool=true, ifnotexists::Bool=false) where {S <: AbstractString}
    u = unique ? "UNIQUE" : ""
    exists = ifnotexists ? "IF NOT EXISTS" : ""
    transaction(db) do
        execute!(db, "CREATE $u INDEX $exists $(esc_id(index)) ON $(esc_id(table)) ($(esc_id(cols)))")
    end
    execute!(db, "ANALYZE $index")
    return
end

"""
`SQLite.removeduplicates!(db, table, cols::Vector)`

removes duplicate rows from `table` based on the values in `cols` which is an array of column names
"""
function removeduplicates!(db, table::AbstractString, cols::AbstractArray{T}) where {T <: AbstractString}
    colsstr = ""
    for c in cols
       colsstr = colsstr * esc_id(c) * ","
    end
    colsstr = chop(colsstr)
    transaction(db) do
        execute!(db, "DELETE FROM $(esc_id(table)) WHERE _ROWID_ NOT IN (SELECT max(_ROWID_) from $(esc_id(table)) GROUP BY $(colsstr));")
    end
    execute!(db, "ANALYZE $table")
    return
 end

include("tables.jl")

"""
`SQLite.tables(db, sink=DataFrame)`

returns a list of tables in `db`
"""
tables(db::DB, sink=DataFrame) = Query(db, "SELECT name FROM sqlite_master WHERE type='table';") |> sink

"""
`SQLite.indices(db, sink=DataFrame)`

returns a list of indices in `db`
"""
indices(db::DB, sink=DataFrame) = Query(db, "SELECT name FROM sqlite_master WHERE type='index';") |> sink

"""
`SQLite.columns(db, table, sink=DataFrame)`

returns a list of columns in `table`
"""
columns(db::DB, table::AbstractString, sink=DataFrame) = Query(db, "PRAGMA table_info($(esc_id(table)))") |> sink

"""
`SQLite.last_insert_rowid(db)`

returns the auto increment id of the last row
"""
last_insert_rowid(db::DB) = sqlite3_last_insert_rowid(db.handle)

"""
`SQLite.enable_load_extension(db, enable::Bool=true)`

Enables extension loading (off by default) on the sqlite database `db`. Pass `false` as the second argument to disable.
"""
function enable_load_extension(db, enable::Bool=true)
   ccall((:sqlite3_enable_load_extension, SQLite.libsqlite), Cint, (Ptr{Cvoid}, Cint), db.handle, enable)
end

end # module
