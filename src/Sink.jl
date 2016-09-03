sqlitetype{T<:Integer}(::Type{T}) = "INT"
sqlitetype{T<:AbstractFloat}(::Type{T}) = "REAL"
sqlitetype{T<:AbstractString}(::Type{T}) = "TEXT"
sqlitetype(::Type{NullType}) = "NULL"
sqlitetype(x) = "BLOB"

"""
independent SQLite.Sink constructor to create a new or wrap an existing SQLite table with name `tablename`.
must provide a `Data.Schema` through the `schema` argument
can optionally provide an existing SQLite table name or new name that a created SQLite table will be called through the `tablename` argument
`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `tablename` already exists in `db`
"""
function Sink(db::DB, schema::Data.Schema; name::AbstractString="julia_"*randstring(), temp::Bool=false, ifnotexists::Bool=true, append::Bool=false)
    rows, cols = size(schema)
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    columns = [string(esc_id(schema.header[i]), ' ', sqlitetype(schema.types[i])) for i = 1:cols]
    SQLite.execute!(db, "CREATE $temp TABLE $ifnotexists $(esc_id(name)) ($(join(columns, ',')))")
    params = chop(repeat("?,", cols))
    stmt = SQLite.Stmt(db, "INSERT INTO $(esc_id(name)) VALUES ($params)")
    return Sink(schema, db, name, stmt)
end

"constructs a new SQLite.Sink from the given `SQLite.Source`; uses `source` schema to create the SQLite table"
function Sink(source::SQLite.Source; name::AbstractString="julia_"*randstring(), temp::Bool=false, ifnotexists::Bool=true)
    return Sink(source.db, source.schema; name=name, temp=temp, ifnotexists=ifnotexists)
end
"constructs a new SQLite.Sink from the given `Data.Source`; uses `source` schema to create the SQLite table"
function Sink(db::DB, source; name::AbstractString="julia_"*randstring(), temp::Bool=false, ifnotexists::Bool=true)
    return Sink(db, Data.schema(source); name=name, temp=temp, ifnotexists=ifnotexists)
end

# DataStreams interface
Data.streamtypes{T<:SQLite.Sink}(::Type{T}) = [Data.Field]

function Sink{T}(source, ::Type{T}, append::Bool, db::DB, name::AbstractString="julia_" * randstring())
    sink = Sink(db, Data.schema(source); name=name)
    !append && execute!(db, "delete from $name")
    return sink
end
function Sink{T}(sink, source, ::Type{T}, append::Bool)
    !append && execute!(sink.db, "delete from $(sink.tablename)")
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
function getfield!{T}(source, ::Type{T}, stmt, row, col)
    val = Data.getfield(source, T, row, col)
    getbind!(val, col, stmt)
end
# stream the data in `dt` into the SQLite table represented by `sink`
function Data.stream!(source, ::Type{Data.Field}, sink::SQLite.Sink, append::Bool)
    !append && execute!(sink.db, "delete from $(sink.tablename)")
    rows, cols = size(source)
    Data.isdone(source, 1, 1) && return sink
    types = Data.types(source)
    handle = sink.stmt.handle
    transaction(sink.db) do
        row = 1
        while true
            for col = 1:cols
                @inbounds T = types[col]
                @inbounds getfield!(source, T, sink.stmt, row, col)
            end
            SQLite.sqlite3_step(handle)
            SQLite.sqlite3_reset(handle)
            row += 1
            Data.isdone(source, row, cols) && break
        end
        Data.setrows!(source, row - 1)
    end
    SQLite.execute!(sink.db,"ANALYZE $(esc_id(sink.tablename))")
    return sink
end

"""
Load a Data.Source `source` into an SQLite table that will be named `tablename` (will be auto-generated if not specified).

`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `tablename` already exists in `db`
"""
function load{T}(db, name, ::Type{T}, args...;
              temp::Bool=false,
              ifnotexists::Bool=true,
              append::Bool=false)
    source = T(args...)
    schema = Data.schema(source)
    sink = Sink(db, schema; name=name, temp=temp, ifnotexists=ifnotexists)
    return Data.stream!(source, sink, append)
end
function load{T}(db, name, source::T;
              temp::Bool=false,
              ifnotexists::Bool=true,
              append::Bool=false)
    schema = Data.schema(source)
    sink = Sink(db, schema; name=name, temp=temp, ifnotexists=ifnotexists)
    return Data.stream!(source, sink, append)
end

load{T}(sink::Sink, ::Type{T}, args...; append::Bool=false) = Data.stream!(T(args...), sink, append)
load(sink::Sink, source; append::Bool=false) = Data.stream!(source, sink, append)
