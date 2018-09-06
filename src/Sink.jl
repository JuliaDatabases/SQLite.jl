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
    Base.depwarn("`SQLite.Sink(db, name)` is deprecated in favor of calling `SQLite.load!(table, db, name)` where `table` can be any Tables.jl interface implementation", nothing)
    cols = size(Data.schema(SQLite.query(db, "pragma table_info($name)")), 1)
    if cols == 0
        createtable!(db, name, schema)
        cols = size(Data.schema(SQLite.query(db, "pragma table_info($name)")), 1)
    else
        !append && execute!(db, "delete from $(esc_id(name))")
    end
    params = chop(repeat("?,", cols))
    stmt = SQLite.Stmt(db, "INSERT INTO $(esc_id(name)) VALUES ($params)")
    return Sink(db, name, stmt, "", cols)
end

# DataStreams interface
Data.streamtypes(::Type{Sink}) = [Data.Field]
Data.weakrefstrings(::Type{Sink}) = true

function Sink(sch::Data.Schema, T, append::Bool, db::DB, name::AbstractString; reference::Vector{UInt8}=UInt8[], kwargs...)
    sink = Sink(db, name, sch; append=append, kwargs...)
    execute!(sink.db, "PRAGMA synchronous = OFF;")
    sink.transaction = string("SQLITE", Random.randstring(10))
    transaction(sink.db, sink.transaction)
    return sink
end
function Sink(sink, sch::Data.Schema, T, append::Bool; reference::Vector{UInt8}=UInt8[])
    execute!(sink.db, "PRAGMA synchronous = OFF;")
    sink.transaction = string("SQLITE", Random.randstring(10))
    transaction(sink.db, sink.transaction)
    !append && execute!(sink.db, "delete from $(esc_id(sink.tablename))")
    return sink
end

function Data.streamto!(sink::SQLite.Sink, ::Type{Data.Field}, val, row, col)
    SQLite.bind!(sink.stmt, col, val)
    if col == sink.cols
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
    return sink
end

"""
Load a Data.Source `source` into an SQLite table that will be named `tablename` (will be auto-generated if not specified).

`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `tablename` already exists in `db`
"""
function load(db::SQLite.DB, name, ::Type{T}, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}(), kwargs...) where {T}
    Base.depwarn("`SQLite.load(db, name, args...)` is deprecated in favor of calling `SQLite.load!(table, db, name)` where `table` can be any Tables.jl interface implementation", nothing)
    sink = Data.stream!(T(args...), SQLite.Sink, db, name; append=append, transforms=transforms, kwargs...)
    return Data.close!(sink)
end
function load(db::SQLite.DB, name, source::T; append::Bool=false, transforms::Dict=Dict{Int,Function}(), kwargs...) where {T}
    Base.depwarn("`SQLite.load(db, name, args...)` is deprecated in favor of calling `SQLite.load!(table, db, name)` where `table` can be any Tables.jl interface implementation", nothing)
    sink = Data.stream!(source, SQLite.Sink, db, name; append=append, transforms=transforms, kwargs...)
    return Data.close!(sink)
end

function load(sink::Sink, ::Type{T}, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}()) where {T}
    Base.depwarn("`SQLite.load(sink::SQLite.Sink, args...)` is deprecated in favor of calling `SQLite.load!(table, db, name)` where `table` can be any Tables.jl interface implementation", nothing)
    (sink = Data.stream!(T(args...), sink; append=append, transforms=transforms); return Data.close!(sink))
end

function load(sink::Sink, source; append::Bool=false, transforms::Dict=Dict{Int,Function}())
    Base.depwarn("`SQLite.load(sink::SQLite.Sink, args...)` is deprecated in favor of calling `SQLite.load!(table, db, name)` where `table` can be any Tables.jl interface implementation", nothing)
    (sink = Data.stream!(source, sink; append=append, transforms=transforms); return Data.close!(sink))
end
