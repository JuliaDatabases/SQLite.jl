# indicates whether the `SQLite.Source` has finished returning results
function Data.isdone(s::Source, row, col)
    (s.status == SQLITE_DONE || s.status == SQLITE_ROW) || sqliteerror(s.stmt.db)
    return s.status == SQLITE_DONE
end
# resets an SQLite.Source, ready to read data from at the start of the resultset
Data.reset!(io::SQLite.Source) = (sqlite3_reset(io.stmt.handle); execute!(io.stmt))

Data.streamtype{T<:SQLite.Source}(::Type{T}, ::Type{Data.Field}) = true

"""
`SQLite.Source(db, sql, values=[]; rows::Int=0, stricttypes::Bool=true)`

Independently constructs an `SQLite.Source` in `db` with the SQL statement `sql`.
Will bind `values` to any parameters in `sql`.
`rows` is used to indicate how many rows to return in the query result if known beforehand. `rows=0` (the default) will return all possible rows.
`stricttypes=false` will remove strict column typing in the result set, making each column effectively `Vector{Any}`

Note that no results are returned; `sql` is executed, and results are ready to be returned (i.e. streamed to an appropriate `Data.Sink` type)
"""
function Source(db::DB, sql::AbstractString, values=[]; rows::Int=-1, stricttypes::Bool=true)
    stmt = SQLite.Stmt(db,sql)
    bind!(stmt, values)
    status = SQLite.execute!(stmt)
    cols = SQLite.sqlite3_column_count(stmt.handle)
    header = Array(String,cols)
    types = Array(DataType,cols)
    for i = 1:cols
        header[i] = unsafe_string(SQLite.sqlite3_column_name(stmt.handle,i))
        # do better column type inference; query what the column was created for?
        types[i] = stricttypes ? SQLite.juliatype(stmt.handle,i) : Any
    end
    return SQLite.Source(Data.Schema(header,types,rows),stmt,status)
end

"""
`SQLite.Source(sink::SQLite.Sink, sql="select * from \$(sink.tablename)")`

constructs an SQLite.Source from an SQLite.Sink; selects all rows/columns from the underlying Sink table by default
"""
Source(sink::SQLite.Sink,sql::AbstractString="select * from $(sink.tablename)") = Source(sink.db, sql::AbstractString)

function juliatype(handle,col)
    x = SQLite.sqlite3_column_type(handle,col)
    if x == SQLITE_BLOB
        val = sqlitevalue(Any,handle,col)
        return typeof(val)
    else
        return juliatype(x)
    end
end
juliatype(x) = x == SQLITE_INTEGER ? Int : x == SQLITE_FLOAT ? Float64 : x == SQLITE_TEXT ? String : Any

sqlitevalue{T<:Union{Signed,Unsigned}}(::Type{T},handle,col) = convert(T, sqlite3_column_int64(handle,col))
const FLOAT_TYPES = Union{Float16,Float32,Float64} # exclude BigFloat
sqlitevalue{T<:FLOAT_TYPES}(::Type{T},handle,col) = convert(T, sqlite3_column_double(handle,col))
#TODO: test returning a WeakRefString instead of calling `bytestring`
sqlitevalue{T<:AbstractString}(::Type{T},handle,col) = convert(T,unsafe_string(sqlite3_column_text(handle,col)))
function sqlitevalue{T}(::Type{T},handle,col)
    blob = convert(Ptr{UInt8},sqlite3_column_blob(handle,col))
    b = sqlite3_column_bytes(handle,col)
    buf = zeros(UInt8,b) # global const?
    unsafe_copy!(pointer(buf), blob, b)
    r = sqldeserialize(buf)::T
    return r
end

# `T` might be Int, Float64, String, WeakRefString, any Julia type, Any, NullType
# `t` (the actual type of the value we're returning), might be SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, SQLITE_NULL
# `SQLite.getfield` returns the next `Nullable{T}` value from the `SQLite.Source`
function Data.getfield{T}(source::SQLite.Source, ::Type{T}, row, col)
    handle = source.stmt.handle
    t = SQLite.sqlite3_column_type(handle,col)
    if t == SQLite.SQLITE_NULL
        val = Nullable{T}()
    else
        TT = SQLite.juliatype(t) # native SQLite Int, Float, and Text types
        val = Nullable{T}(sqlitevalue(ifelse(TT===Any&&!isbits(T),T,TT),handle,col))
    end
    col == source.schema.cols && (source.status = sqlite3_step(handle))
    return val
end

# function getfield!{T}(source::SQLite.Source, dest::NullableVector{T}, row, col)
#     @inbounds dest[row] = SQLite.getfield(source, T, row, col)
#     return
# end
# function pushfield!{T}(source::SQLite.Source, dest::NullableVector{T}, row, col)
#     push!(dest, SQLite.getfield(source, T, row, col))
#     return
# end
# "streams data from the SQLite.Source to a DataFrame"
# function Data.stream!(source::SQLite.Source,sink::DataFrame)
#     rows, cols = size(source)
#     types = Data.types(source)
#     if rows == 0
#         row = 0
#         while !Data.isdone(source)
#             for col = 1:cols
#                 @inbounds T = types[col]
#                 SQLite.pushfield!(source, sink.columns[col], row, col)
#             end
#             row += 1
#         end
#         source.schema.rows = row
#     else
#         for row = 1:rows, col = 1:cols
#             @inbounds T = types[col]
#             SQLite.getfield!(source, sink.columns[col], row, col)
#         end
#     end
#     return sink
# end
# "streams data from an SQLite.Source to a CSV.Sink file; `header=false` will not write the column names to the file"
# function Data.stream!(source::SQLite.Source,sink::CSV.Sink;header::Bool=true)
#     header && CSV.writeheaders(source,sink)
#     rows, cols = size(source)
#     types = Data.types(source)
#     row = 0
#     while !Data.isdone(source)
#         for col = 1:cols
#             val = SQLite.getfield(source, types[col], row, col)
#             CSV.writefield(sink, isnull(val) ? sink.null : get(val), col, cols)
#         end
#         row += 1
#     end
#     source.schema.rows = row
#     sink.schema = source.schema
#     close(sink)
#     return sink
# end

"""
`SQLite.query(db, sql::String, sink=DataFrame, values=[]; rows::Int=0, stricttypes::Bool=true)`

convenience method for executing an SQL statement and streaming the results back in a `Data.Sink` (DataFrame by default)

Will bind `values` to any parameters in `sql`.
`rows` is used to indicate how many rows to return in the query result if known beforehand. `rows=0` (the default) will return all possible rows.
`stricttypes=false` will remove strict column typing in the result set, making each column effectively `Vector{Any}`
"""
function query(db::DB, sql::AbstractString, sink=DataFrame; values=[], rows::Int=-1, stricttypes::Bool=true)
    source = Source(db, sql, values; rows=rows, stricttypes=stricttypes)
    return Data.stream!(source, sink)
end

"""
`SQLite.tables(db, sink=DataFrame)`

returns a list of tables in `db`
"""
tables(db::DB, sink=DataFrame) = query(db, "SELECT name FROM sqlite_master WHERE type='table';", sink)

"""
`SQLite.indices(db, sink=DataFrame)`

returns a list of indices in `db`
"""
indices(db::DB, sink=DataFrame) = query(db, "SELECT name FROM sqlite_master WHERE type='index';", sink)

"""
`SQLite.columns(db, table, sink=DataFrame)`

returns a list of columns in `table`
"""
columns(db::DB,table::AbstractString, sink=DataFrame) = query(db, "PRAGMA table_info($(esc_id(table)))", sink)
