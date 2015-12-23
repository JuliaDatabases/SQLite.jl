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
function Sink(schema::Data.Schema,db::DB,tablename::AbstractString="julia_"*randstring();temp::Bool=false,ifnotexists::Bool=true)
    rows, cols = size(schema)
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    columns = [string(esc_id(schema.header[i]),' ',sqlitetype(schema.types[i])) for i = 1:cols]
    SQLite.execute!(db,"CREATE $temp TABLE $ifnotexists $(esc_id(tablename)) ($(join(columns,',')))")
    params = chop(repeat("?,",cols))
    stmt = SQLite.Stmt(db,"INSERT INTO $(esc_id(tablename)) VALUES ($params)")
    return Sink(schema,db,utf8(tablename),stmt)
end

"constructs a new SQLite.Sink from the given `SQLite.Source`; uses `source` schema to create the SQLite table"
function Sink(source::SQLite.Source, tablename::AbstractString="julia_"*randstring();temp::Bool=false,ifnotexists::Bool=true)
    return Sink(source.schema, source.db, tablename; temp=temp, ifnotexists=ifnotexists)
end
"constructs a new SQLite.Sink from the given `Data.Source`; uses `source` schema to create the SQLite table"
function Sink(source::Data.Source, db::DB, tablename::AbstractString="julia_"*randstring();temp::Bool=false,ifnotexists::Bool=true)
    return Sink(source.schema, db, tablename; temp=temp, ifnotexists=ifnotexists)
end

# create a new SQLite table
# Data.Table
function getbind!{T}(dt::NullableVector{T},row,col,stmt)
    @inbounds isnull = dt.isnull[row]
    if isnull
        SQLite.bind!(stmt,col,NULL)
    else
        @inbounds val = dt.values[row]::T
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
                    @inbounds SQLite.getbind!(Data.unsafe_column(dt,col,types[col]),row,col,sink.stmt)
                end
                SQLite.sqlite3_step(handle)
                SQLite.sqlite3_reset(handle)
            end
        end
    end
    SQLite.execute!(sink.db,"ANALYZE $(esc_id(sink.tablename))")
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
    SQLite.execute!(sink.db,"ANALYZE $(esc_id(sink.tablename))")
    return sink
end
