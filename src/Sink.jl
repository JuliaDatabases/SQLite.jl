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
function Sink(db::DB, schema::Data.Schema; name::AbstractString="julia_"*randstring(), temp::Bool=false, ifnotexists::Bool=true)
    rows, cols = size(schema)
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    columns = [string(esc_id(schema.header[i]),' ',sqlitetype(schema.types[i])) for i = 1:cols]
    SQLite.execute!(db,"CREATE $temp TABLE $ifnotexists $(esc_id(name)) ($(join(columns,',')))")
    params = chop(repeat("?,",cols))
    stmt = SQLite.Stmt(db,"INSERT INTO $(esc_id(name)) VALUES ($params)")
    return Sink(schema,db,name,stmt)
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
function Data.stream!(source, ::Type{Data.Field}, sink::SQLite.Sink)
    rows, cols = size(source)
    types = Data.types(source)
    handle = sink.stmt.handle
    transaction(sink.db) do
        row = 0
        while !Data.isdone(source, row, cols)
            row += 1
            for col = 1:cols
                @inbounds T = types[col]
                @inbounds getfield!(source, T, sink.stmt, row, col)
            end
            SQLite.sqlite3_step(handle)
            SQLite.sqlite3_reset(handle)
        end
        Data.setrows!(source, rows)
    end
    SQLite.execute!(sink.db,"ANALYZE $(esc_id(sink.tablename))")
    return sink
end

# function getfield!{T}(source, dest::NullableVector{T}, row, col)
#     @inbounds dest[row] = Data.getfield(source, T, row, col)
#     return
# end
#
# function Data.stream!(source::Data.Source, ::Type{Data.Field}, sink::DataFrame)
#     Data.types(source) == Data.types(sink) || throw(ArgumentError("schema mismatch: \n$(Data.schema(source))\nvs.\n$(Data.schema(sink))"))
#     rows, cols = size(source)
#     columns = sink.columns
#     if rows == 0
#         row = 0
#         while !Data.isdone(source, row, cols)
#             for col = 1:cols
#                 Data.pushfield!(source, columns[col], row, col)
#             end
#             row += 1
#         end
#         source.schema.rows = row
#     else
#         for row = 1:rows, col = 1:cols
#             Data.getfield!(source, columns[col], row, col)
#         end
#     end
#     return sink
# end

# CSV.Source
# function getbind!{T}(io,::Type{T},opts,row,col,stmt)
#     val, isnull = CSV.parsefield(io,T,opts,row,col)
#     if isnull
#         SQLite.bind!(stmt,col,NULL)
#     else
#         SQLite.bind!(stmt,col,val)
#     end
#     return
# end
# # stream the data in `source` CSV file to the SQLite table represented by `sink`
# function Data.stream!(source::CSV.Source,sink::SQLite.Sink)
#     rows, cols = size(source)
#     types = Data.types(source)
#     io = source.data
#     opts = source.options
#     stmt = sink.stmt
#     handle = stmt.handle
#     transaction(sink.db) do
#         if rows*cols != 0
#             for row = 1:rows
#                 for col = 1:cols
#                     @inbounds SQLite.getbind!(io, types[col], opts, row, col, stmt)
#                 end
#                 SQLite.sqlite3_step(handle)
#                 SQLite.sqlite3_reset(handle)
#             end
#         end
#     end
#     SQLite.execute!(sink.db,"ANALYZE $(esc_id(sink.tablename))")
#     return sink
# end

"""
`SQLite.load(db, source; name="julia_" * randstring(); temp::Bool=false, ifnotexists::Bool=true)`

Load a Data.Source `source` into an SQLite table that will be named `tablename` (will be auto-generated if not specified).

`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `tablename` already exists in `db`
"""
function load(db::DB, source; name::AbstractString="julia_" * randstring(), temp::Bool=false, ifnotexists::Bool=true)
    sink = SQLite.Sink(db, source; name=name, temp=temp, ifnotexists=ifnotexists)
    return Data.stream!(source, sink)
end
