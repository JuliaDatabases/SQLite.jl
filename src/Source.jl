type Source <: Data.Source # <: IO
    schema::Data.Schema
    stmt::Stmt
    status::Cint
end

function Source(db::DB,sql::AbstractString, values=[];rows::Int=0,stricttypes::Bool=true)
    stmt = SQLite.Stmt(db,sql)
    bind!(stmt, values)
    status = SQLite.execute!(stmt)
    cols = SQLite.sqlite3_column_count(stmt.handle)
    header = Array(UTF8String,cols)
    types = Array(DataType,cols)
    for i = 1:cols
        header[i] = bytestring(SQLite.sqlite3_column_name(stmt.handle,i-1))
        # do better column type inference; query what the column was created for?
        types[i] = stricttypes ? SQLite.juliatype(stmt.handle,i) : Any
    end
    # rows == -1 && count(*)?
    return SQLite.Source(Data.Schema(header,types,rows),stmt,status)
end

function Base.eof(s::Source)
    (s.status == SQLITE_DONE || s.status == SQLITE_ROW) || sqliteerror(s.stmt.db)
    return s.status == SQLITE_DONE
end

function Base.readline(s::Source,delim::Char=',',buf::IOBuffer=IOBuffer())
    eof(s) && return ""
    cols = s.schema.cols
    for i = 1:cols
        val = sqlite3_column_text(s.stmt.handle,i-1)
        val != C_NULL && write(buf,bytestring(val))
        write(buf,ifelse(i == cols,'\n',delim))
    end
    s.status = sqlite3_step(s.stmt.handle)
    return takebuf_string(buf)
end

function readsplitline(s::Source)
    eof(s) && return UTF8String[]
    cols = s.schema.cols
    vals = Array(UTF8String, cols)
    for i = 1:cols
        val = sqlite3_column_text(s.stmt.handle,i-1)
        valsl[i] = val == C_NULL ? "" : bytestring(val)
    end
    s.status = sqlite3_step(s.stmt.handle)
    return vals
end

reset!(io::SQLite.Source) = (sqlite3_reset(io.stmt.handle); execute!(io.stmt))

sqlitetypecode{T<:Integer}(::Type{T}) = SQLITE_INTEGER
sqlitetypecode{T<:AbstractFloat}(::Type{T}) = SQLITE_FLOAT
sqlitetypecode{T<:AbstractString}(::Type{T}) = SQLITE_TEXT
sqlitetypecode(::Type{BigInt}) = SQLITE_BLOB
sqlitetypecode(::Type{BigFloat}) = SQLITE_BLOB
sqlitetypecode(x) = SQLITE_BLOB
function juliatype(handle,col)
    x = SQLite.sqlite3_column_type(handle,col-1)
    if x == SQLITE_BLOB
        val = sqlitevalue(Any,handle,col)
        return typeof(val)
    else
        return juliatype(x)
    end
end
juliatype(x) = x == SQLITE_INTEGER ? Int : x == SQLITE_FLOAT ? Float64 : x == SQLITE_TEXT ? UTF8String : Any

sqlitevalue{T<:Integer}(::Type{T},handle,col) = sqlite3_column_int64(handle,col-1)
sqlitevalue{T<:AbstractFloat}(::Type{T},handle,col) = sqlite3_column_double(handle,col-1)
#TODO: test returning a PointerString instead of calling `bytestring`
sqlitevalue{T<:AbstractString}(::Type{T},handle,col) = convert(T,bytestring(sqlite3_column_text(handle,col-1)))
sqlitevalue(::Type{PointerString},handle,col) = bytestring(sqlite3_column_text(handle,col-1))
sqlitevalue(::Type{BigInt},handle,col) = sqlitevalue(Any,handle,col)
sqlitevalue(::Type{BigFloat},handle,col) = sqlitevalue(Any,handle,col)
function sqlitevalue{T}(::Type{T},handle,col)
    blob = convert(Ptr{UInt8},SQLite.sqlite3_column_blob(handle,col-1))
    b = SQLite.sqlite3_column_bytes(handle,col-1)
    buf = zeros(UInt8,b) # global const?
    unsafe_copy!(pointer(buf), blob, b)
    r = SQLite.sqldeserialize(buf)::T
    return r
end

function getfield{T}(source::SQLite.Source, ::Type{T}, row, col)
    handle = source.stmt.handle
    t = sqlite3_column_type(handle,col-1)
    if t == SQLite.SQLITE_NULL
        val = Nullable{T}()
    elseif t == SQLite.sqlitetypecode(T)
        val = Nullable(sqlitevalue(T,handle,col))
    elseif T === Any
        val = Nullable(sqlitevalue(juliatype(t),handle,col))
    else
        throw(SQLiteException("strict type error trying to retrieve type `$T` on row: $(row+1), col: $col; SQLite reports a type of $(sqlitetypecode(T))"))
    end
    col == source.schema.cols && (source.status = sqlite3_step(handle))
    return val
end

function getfield!{T}(source::SQLite.Source, dest::NullableVector{T}, ::Type{T}, row, col)
    @inbounds dest[row] = SQLite.getfield(source, T, row, col)
    return
end
function pushfield!{T}(source::SQLite.Source, dest::NullableVector{T}, ::Type{T}, row, col)
    push!(dest, SQLite.getfield(source, T, row, col))
    return
end

function Data.stream!(source::SQLite.Source,sink::Data.Table)
    rows, cols = size(source)
    types = Data.types(source)
    if rows == 0
        row = 0
        while !eof(source)
            for col = 1:cols
                @inbounds T = types[col]
                SQLite.pushfield!(source, Data.unsafe_column(sink,col,T), T, row, col) # row + datarow
            end
            row += 1
        end
        source.schema.rows = row
    else
        for row = 1:rows, col = 1:cols
            @inbounds T = types[col]
            SQLite.getfield!(source, Data.unsafe_column(sink,col,T), T, row, col) # row + datarow
        end
    end
    sink.schema = source.schema
    return sink
end
# creates a new DataTable according to `source` schema and streams `Source` data into it
function Data.Table(source::SQLite.Source)
    sink = Data.Table(source.schema)
    return Data.stream!(source,sink)
end

function Data.stream!(source::SQLite.Source,sink::CSV.Sink;header::Bool=true)
    header && CSV.writeheaders(source,sink)
    rows, cols = size(source)
    types = Data.types(source)
    row = 0
    while !eof(source)
        for col = 1:cols
            val = SQLite.getfield(source, types[col], row, col)
            CSV.writefield(sink, isnull(val) ? sink.null : get(val), col, cols)
        end
        row += 1
    end
    source.schema.rows = row
    sink.schema = source.schema
    close(sink)
    return sink
end

function query(db::DB,sql::AbstractString, values=[];rows::Int=0,stricttypes::Bool=true)
    so = Source(db,sql,values;rows=rows,stricttypes=stricttypes)
    return Data.Table(so)
end

tables(db::DB) = query(db,"SELECT name FROM sqlite_master WHERE type='table';")
indices(db::DB) = query(db,"SELECT name FROM sqlite_master WHERE type='index';")
columns(db::DB,table::AbstractString) = query(db,"pragma table_info($table)")
