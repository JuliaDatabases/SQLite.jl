sqlitetype{T<:Integer}(::Type{T}) = "INT"
sqlitetype{T<:AbstractFloat}(::Type{T}) = "REAL"
sqlitetype{T<:AbstractString}(::Type{T}) = "TEXT"
sqlitetype(x) = "BLOB"

type Sink <: Data.Sink # <: IO
    schema::Data.Schema
    db::DB
    tablename::UTF8String
    stmt::Stmt
end

function Source(sink::SQLite.Sink)
    stmt = SQLite.Stmt(sink.db,"select * from $(sink.tablename)")
    status = SQLite.execute!(stmt)
    return SQLite.Source(sink.schema, stmt, status)
end

# independent Sink constructor for new or existing SQLite tables
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

# create a new SQLite table
# Data.Table
function getbind!{T}(dt::NullableVector{T},row,col,stmt)
    @inbounds SQLite.bind!(stmt,col,ifelse(dt.isnull[row], NULL, dt.values[row]::T))
    return
end

function Data.stream!(dt::Data.Table,sink::SQLite.Sink)
    rows, cols = size(dt)
    types = Data.types(dt)
    transaction(sink.db) do
        if rows*cols != 0
            for row = 1:rows
                for col = 1:cols
                    @inbounds SQLite.getbind!(Data.column(dt,col,types[col]),row,col,sink.stmt)
                end
                SQLite.execute!(sink.stmt)
            end
        end
    end
    SQLite.execute!(sink.db,"analyze $(sink.tablename)")
    return sink
end
function Sink(dt::Data.Table,db::DB,tablename::AbstractString="julia_"*randstring();temp::Bool=false,ifnotexists::Bool=false)
    sink = Sink(db,tablename,dt.schema;temp=temp,ifnotexists=ifnotexists)
    return Data.stream!(dt,sink)
end
# CSV.Source
function getbind!{T}(io,::Type{T},opts,row,col,stmt)
    val, isnull = CSV.getfield(io,T,opts,row,col)
    SQLite.bind!(stmt,col,ifelse(isnull,NULL,val))
    return
end
function Data.stream!(source::CSV.Source,sink::SQLite.Sink)
    rows, cols = size(source)
    types = Data.types(source)
    io = source.data
    opts = source.options
    transaction(sink.db) do
        if rows*cols != 0
            for row = 1:rows
                for col = 1:cols
                    @inbounds SQLite.getbind!(io, types[col], opts, row, col, sink.stmt)
                end
                SQLite.execute!(sink.stmt)
            end
        end
    end
    SQLite.execute!(sink.db,"analyze $(sink.tablename)")
    return sink
end
function Sink(csv::CSV.Source,db::DB,tablename::AbstractString="julia_"*randstring();temp::Bool=false,ifnotexists::Bool=false)
    sink = Sink(db,tablename,csv.schema;temp=temp,ifnotexists=ifnotexists)
    return Data.stream!(csv,sink)
end
