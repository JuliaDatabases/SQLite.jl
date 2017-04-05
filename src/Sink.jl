sqlitetype{T<:Integer}(::Type{T}) = "INT"
sqlitetype{T<:AbstractFloat}(::Type{T}) = "REAL"
sqlitetype{T<:AbstractString}(::Type{T}) = "TEXT"
sqlitetype(::Type{NullType}) = "NULL"
sqlitetype(x) = "BLOB"

function createtable!(db::DB, name::AbstractString, schema::Data.Schema; temp::Bool=false, ifnotexists::Bool=true)
    rows, cols = size(schema)
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    header, types = Data.header(schema), Data.types(schema)
    columns = [string(esc_id(header[i]), ' ', sqlitetype(types[i])) for i = 1:cols]
    SQLite.execute!(db, "CREATE $temp TABLE $ifnotexists $(esc_id(name)) ($(join(columns, ',')))")
    return name
end

"""
independent SQLite.Sink constructor to create a new or wrap an existing SQLite table with name `name`.
must provide a `Data.Schema` through the `schema` argument
can optionally provide an existing SQLite table name or new name that a created SQLite table will be called through the `name` argument
`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `name` already exists in `db`
"""
function Sink(db::DB, name::AbstractString, schema::Data.Schema=Data.Schema(); temp::Bool=false, ifnotexists::Bool=true, append::Bool=false)
    cols = size(SQLite.query(db, "pragma table_info($name)"), 1)
    if cols == 0
        createtable!(db, name, schema)
        cols = size(SQLite.query(db, "pragma table_info($name)"), 1)
    else
        !append && execute!(db, "delete from $(esc_id(name))")
    end
    params = chop(repeat("?,", cols))
    stmt = SQLite.Stmt(db, "INSERT INTO $(esc_id(name)) VALUES ($params)")
    return Sink(db, name, stmt, "")
end

# DataStreams interface
Data.streamtypes{T<:SQLite.Sink}(::Type{T}) = [Data.Field]

function Sink{T}(sch::Data.Schema, ::Type{T}, append::Bool, ref::Vector{UInt8}, db::DB, name::AbstractString; kwargs...)
    sink = Sink(db, name, sch; append=append, kwargs...)
    execute!(sink.db, "PRAGMA synchronous = OFF;")
    sink.transaction = string("SQLITE",randstring(10))
    transaction(sink.db, sink.transaction)
    return sink
end
function Sink{T}(sink, sch::Data.Schema, ::Type{T}, append::Bool, ref::Vector{UInt8})
    execute!(sink.db, "PRAGMA synchronous = OFF;")
    sink.transaction = string("SQLITE", randstring(10))
    transaction(sink.db, sink.transaction)
    !append && execute!(sink.db, "delete from $(esc_id(sink.tablename))")
    return sink
end

function getbind!{T}(val::Nullable{T}, col, stmt)
    if isnull(val)
        SQLite.bind!(stmt, col, NULL)
    else
        SQLite.bind!(stmt, col, get(val))
    end
    return
end
if isdefined(:isna)
    function getbind!{T}(val::T, col, stmt)
        if isna(val)
            SQLite.bind!(stmt, col, NULL)
        else
            SQLite.bind!(stmt, col, val)
        end
        return
    end
else
    getbind!{T}(val::T, col, stmt) = SQLite.bind!(stmt, col, val)
end

function Data.streamto!{T}(sink::SQLite.Sink, ::Type{Data.Field}, val::T, row, col, sch)
    getbind!(val, col, sink.stmt)
    if col == size(sch, 2)
        SQLite.sqlite3_step(sink.stmt.handle)
        SQLite.sqlite3_reset(sink.stmt.handle)
    end
    return nothing
end

function Data.cleanup!(sink::SQLite.Sink)
    rollback(sink.db, sink.transaction)
    commit(sink.db, sink.transaction)
    execute!(sink.db, "PRAGMA synchronous = ON;")
    return nothing
end

function Data.close!(sink::SQLite.Sink)
    commit(sink.db, sink.transaction)
    execute!(sink.db, "PRAGMA synchronous = ON;")
    SQLite.execute!(sink.db, "ANALYZE $(esc_id(sink.tablename))")
    return nothing
end

"""
Load a Data.Source `source` into an SQLite table that will be named `tablename` (will be auto-generated if not specified).

`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `tablename` already exists in `db`
"""
function load{T}(db::SQLite.DB, name, ::Type{T}, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}(), kwargs...)
    sink = Data.stream!(T(args...), SQLite.Sink, append, transforms, db, name; kwargs...)
    Data.close!(sink)
    return sink
end
function load{T}(db::SQLite.DB, name, source::T; append::Bool=false, transforms::Dict=Dict{Int,Function}(), kwargs...)
    sink = Data.stream!(source, SQLite.Sink, append, transforms, db, name; kwargs...)
    Data.close!(sink)
    return sink
end

load{T}(sink::Sink, ::Type{T}, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}()) = (sink = Data.stream!(T(args...), sink, append, transforms); Data.close!(sink); return sink)
load(sink::Sink, source; append::Bool=false, transforms::Dict=Dict{Int,Function}()) = (sink = Data.stream!(source, sink, append, transforms); Data.close!(sink); return sink)
