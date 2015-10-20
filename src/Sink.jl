sqlitetype{T<:Integer}(::Type{T}) = "INT"
sqlitetype{T<:AbstractFloat}(::Type{T}) = "REAL"
sqlitetype{T<:AbstractString}(::Type{T}) = "TEXT"
sqlitetype(::Type{NullType}) = "NULL"
sqlitetype(x) = "BLOB"
"SQLite.Sink implements the `Sink` interface in the `DataStreams` framework"
type Sink <: Data.Sink # <: IO
    schema::Data.Schema
    db::DB
    tablename::UTF8String
    stmt::Stmt
end
"constructs an SQLite.Source from an SQLite.Sink; selects all rows/columns from the underlying Sink table by default"
function Source(sink::SQLite.Sink,sql::AbstractString="select * from $(sink.tablename)")
    stmt = SQLite.Stmt(sink.db,sql)
    status = SQLite.execute!(stmt)
    return SQLite.Source(sink.schema, stmt, status)
end

"""
independent SQLite.Sink constructor to create a new or wrap an existing SQLite table with name `tablename`.
can optionally provide a `Data.Schema` through the `schema` argument.
`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `tablename` already exists in `db`
"""
function Sink(db::DB,tablename::AbstractString="julia_"*randstring(),schema::Data.Schema=Data.EMPTYSCHEMA;temp::Bool=false,ifnotexists::Bool=true)
    rows, cols = size(schema)
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "if not exists" : ""
    columns = [string(schema.header[i],' ',sqlitetype(schema.types[i])) for i = 1:cols]
    SQLite.execute!(db,"CREATE $temp TABLE $ifnotexists $tablename ($(join(columns,',')))")
    params = chop(repeat("?,",cols))
    stmt = SQLite.Stmt(db,"insert into $tablename values ($params)")
    return Sink(schema,db,utf8(tablename),stmt)
end
"constructs a new SQLite.Sink from the given `Data.Source`; uses `source` schema to create the SQLite table"
function Sink(source::Data.Source, db::DB, tablename::AbstractString="julia_"*randstring();temp::Bool=false,ifnotexists::Bool=true)
    sink = Sink(db, tablename, source.schema; temp=temp, ifnotexists=ifnotexists)
    return Data.stream!(source,sink)
end

# create a new SQLite table
# Data.Table
function getbind!{T}(dt::NullableVector{T},row,col,stmt)
    @inbounds val, isnull = dt.values[row]::T, dt.isnull[row]
    if isnull
        SQLite.bind!(stmt,col,NULL)
    else
        SQLite.bind!(stmt,col,val)
    end
    return
end
"stream the data in `dt` into the SQLite table represented by `sink`"
function Data.stream!(dt::Data.Table,sink::SQLite.Sink)
    rows, cols = size(dt)
    types = Data.types(dt)
    handle = sink.stmt.handle
    transaction(sink.db) do
        if rows*cols != 0
            for row = 1:rows
                for col = 1:cols
                    @inbounds SQLite.getbind!(Data.column(dt,col,types[col]),row,col,sink.stmt)
                end
                SQLite.sqlite3_step(handle)
                SQLite.sqlite3_reset(handle)
            end
        end
    end
    SQLite.execute!(sink.db,"analyze $(sink.tablename)")
    return sink
end
# CSV.Source
function getbind!{T}(io,::Type{T},opts,row,col,stmt)
    val, isnull = CSV.getfield(io,T,opts,row,col)
    if isnull
        SQLite.bind!(stmt,col,NULL)
    else
        SQLite.bind!(stmt,col,val)
    end
    return
end
"stream the data in `source` CSV file to the SQLite table represented by `sink`"
function Data.stream!(source::CSV.Source,sink::SQLite.Sink)
    rows, cols = size(source)
    types = Data.types(source)
    io = source.data
    opts = source.options
    stmt = sink.stmt
    handle = stmt.handle
    transaction(sink.db) do
        if rows*cols != 0
            for row = 1:rows
                for col = 1:cols
                    @inbounds SQLite.getbind!(io, types[col], opts, row, col, stmt)
                end
                SQLite.sqlite3_step(handle)
                SQLite.sqlite3_reset(handle)
            end
        end
    end
    SQLite.execute!(sink.db,"analyze $(sink.tablename)")
    return sink
end
