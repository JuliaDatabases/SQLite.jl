type Source <: IOSource # <: IO
    schema::Schema
    stmt::Stmt
    status::Cint
    function Source(db::DB,sql::AbstractString, values=[])
        stmt = SQLite.Stmt(db,sql)
        bind!(stmt, values)
        status = SQLite.execute!(stmt)
        #TODO: build Schema
        cols = sqlite3_column_count(stmt.handle)
        header = Array(UTF8String,cols)
        types = Array(DataType,cols)
        for i = 1:cols
            header[i] = bytestring(sqlite3_column_name(stmt.handle,i-1))
            types[i] = juliatype(sqlite3_column_type(stmt.handle,i-1))
        end
        return Source(DataStreams.Schema(header,types,rows,cols),stmt,status)
    end
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

default{T}(::Type{T}) = zero(T) # default fallback for all other types
default{T<:AbstractString}(::Type{T}) = convert(T,"")::T
default(::Type{Date}) = Date()
default(::Type{DateTime}) = DateTime()

sqlitetype{T<:Integer}(::Type{T}) = SQLITE_INTEGER
sqlitetype{T<:AbstractFloat}(::Type{T}) = SQLITE_FLOAT
sqlitetype{T<:AbstractString}(::Type{T}) = SQLITE_TEXT
sqlitetype(x) = SQLITE_BLOB
juliatype(x) = x == SQLITE_INTEGER ? Int : x == SQLITE_FLOAT ? Float64 : x == SQLITE_TEXT ? UTF8String : Any

sqlitevalue{T<:Integer}(::Type{T},handle,col) = sqlite3_column_int64(handle,col)
sqlitevalue{T<:AbstractFloat}(::Type{T},handle,col) = sqlite3_column_double(handle,col)
sqlitevalue{T<:AbstractString}(::Type{T},handle,col) = bytestring(sqlite3_column_text(handle,col))
function sqlitevalue{T}(::Type{T},handle,col)
    blob = convert(Ptr{UInt8},sqlite3_column_blob(handle,col))
    b = sqlite3_column_bytes(handle,col)
    buf = zeros(UInt8,b) # global const?
    unsafe_copy!(pointer(buf), blob, b)
    r = sqldeserialize(buf)
end

function getfield{T}(source::SQLite.Source, ::Type{T}, row, col)
    val::T = default(T)
    eof(source) && return val, true
    handle = source.stmt.handle
    t = sqlite3_column_type(handle,col-1)
    if t == sqlitetype(T)
        val = sqlitevalue(T,handle,col-1)
        null = false
    elseif t == SQLITE_NULL
        null = true
    else
        throw(SQLiteException("strict type error trying to retrieve type `$T` on row: $row, col: $col; SQLite reports a type of $(sqlitetype(T))"))
    end
    col == source.schema.cols && (source.status = sqlite3_step(handle))
    return val, null
end

function getfield!{T}(source::SQLite.Source, dest::NullableVector{T}, ::Type{T}, row, col)
    @inbounds val, null = SQLite.getfield(source, T, row, col) # row + datarow
    @inbounds dest.values[row], dest.isnull[row] = val, null
    return
end

function DataStreams.stream!(source::SQLite.Source,sink::DataStream)
    rows, cols = size(source)
    types = source.schema.types
    data = sink.data
    for row = 1:rows, col = 1:cols
        SQLite.getfield!(source, data[col], types[col], row, col) # row + datarow
    end
    return sink
end

Base.start(s::Stream) = 1
Base.done(s::Stream,col) = eof(s)
function Base.next(s::Stream,i)
    t = sqlite3_column_type(s.stmt.handle,i-1)
    r::Any
    if t == SQLITE_INTEGER
        r = sqlite3_column_int64(s.stmt.handle,i-1)
    elseif t == SQLITE_FLOAT
        r = sqlite3_column_double(s.stmt.handle,i-1)
    elseif t == SQLITE_TEXT
        #TODO: have a way to return text16?
        r = bytestring( sqlite3_column_text(s.stmt.handle,i-1) )
    elseif t == SQLITE_BLOB
        blob = sqlite3_column_blob(s.stmt.handle,i-1)
        b = sqlite3_column_bytes(s.stmt.handle,i-1)
        buf = zeros(UInt8,b)
        unsafe_copy!(pointer(buf), convert(Ptr{UInt8},blob), b)
        r = sqldeserialize(buf)
    else
        r = NULL
    end
    if i == s.cols
        s.status = sqlite3_step(s.stmt.handle)
        i = 1
    else
        i += 1
    end
    return r, i
end

function scalarquery(db::DB,sql)
    stream = SQLite.open(db,sql)
    return next(stream,1)[1]
end

function Base.writecsv(db,table,file;compressed::Bool=false)
    out = compressed ? GZip.open(file,"w") : open(file,"w")
    s = SQLite.open(SQLite.Table(db,table))
    for i = 1:s.cols
        write(out,bytestring(sqlite3_column_name(s.stmt.handle,i-1)))
        write(out,ifelse(i == s.cols,'\n',','))
    end
    while !eof(s)
        for i = 1:s.cols
            val = sqlite3_column_text(s.stmt.handle,i-1)
            val != C_NULL && write(out,bytestring(val))
            write(out,ifelse(i == s.cols,'\n',','))
        end
        s.status = sqlite3_step(s.stmt.handle)
    end
    close(out)
    return file
end

function query(db::DB,sql::AbstractString, values=[])
    stream = SQLite.open(db,sql,values)
    ncols = stream.cols
    (eof(stream) || ncols == 0) && return changes(db)
    colnames = Array(AbstractString,ncols)
    results = Array(Any,ncols)
    for i = 1:ncols
        colnames[i] = bytestring(sqlite3_column_name(stream.stmt.handle,i-1))
        results[i] = Any[]
    end
    col = 1
    while !eof(stream)
        c = col
        r, col = next(stream,col)
        push!(results[c],r)
    end
    return ResultSet(colnames, results)
end

function tables(db::DB)
    query(db,"SELECT name FROM sqlite_master WHERE type='table';")
end

function indices(db::DB)
    query(db,"SELECT name FROM sqlite_master WHERE type='index';")
end

columns(db::DB,table::AbstractString) = query(db,"pragma table_info($table)")

function drop!(db::DB,table::AbstractString;ifexists::Bool=false)
    exists = ifexists ? "if exists" : ""
    transaction(db) do
        execute!(db,"drop table $exists $table")
    end
    execute!(db,"vacuum")
    return changes(db)
end

function dropindex!(db::DB,index::AbstractString;ifexists::Bool=false)
    exists = ifexists ? "if exists" : ""
    transaction(db) do
        execute!(db,"drop index $exists $index")
    end
    return changes(db)
end

function create(db::DB,name::AbstractString,table::AbstractVector,
            colnames=AbstractString[],coltypes=DataType[]
            ;temp::Bool=false,ifnotexists::Bool=false)
    table = reshape(table,(length(table),1))
    return create(db,name,table,colnames,coltypes;temp=temp,ifnotexists=ifnotexists)
end
function create(db::DB,name::AbstractString,table,
            colnames=AbstractString[],
            coltypes=DataType[]
            ;temp::Bool=false,ifnotexists::Bool=false)
    N, M = size(table)
    colnames = isempty(colnames) ? ["x$i" for i=1:M] : colnames
    coltypes = isempty(coltypes) ? [typeof(table[1,i]) for i=1:M] : coltypes
    length(colnames) == length(coltypes) || throw(SQLiteException("colnames and coltypes must have same length"))
    cols = [colnames[i] * SQLite.gettype(coltypes[i]) for i = 1:length(colnames)]
    transaction(db) do
        # create table statement
        t = temp ? "TEMP " : ""
        exists = ifnotexists ? "if not exists" : ""
        SQLite.execute!(db,"CREATE $(t)TABLE $exists $name ($(join(cols,',')))")
        # insert statements
        if N*M != 0
            params = chop(repeat("?,",M))
            stmt = SQLite.Stmt(db,"insert into $name values ($params)")
            #bind, step, reset loop for inserting values
            for row = 1:N
                for col = 1:M
                    @inbounds v = table[row,col]
                    bind!(stmt,col,v)
                end
                execute!(stmt)
            end
        end
    end
    execute!(db,"analyze $name")
    return ResultSet(["Rows Loaded"],Any[Any[N]])
end

function readbind!{T<:Union{Integer,Float64}}(io,::Type{T},row,col,stmt)
    val, isnull = CSV.readfield(io,T,row,col)
    bind!(stmt,col,ifelse(isnull,NULL,val))
    return
end
function readbind!(io, ::Type{Date}, row, col, stmt)
    bind!(stmt,col,CSV.readfield(io,Date,row,col)[1])
    return
end
function readbind!{T<:AbstractString}(io,::Type{T},row,col,stmt)
    str, isnull = CSV.readfield(io,T,row,col)
    if isnull
        bind!(stmt,col,NULL)
    else
        sqlite3_bind_text(stmt.handle,col,str.ptr,str.len)
    end
    return
end

function create(db::DB,file::CSV.File,name::AbstractString=splitext(basename(file.fullpath))[1]
                ;temp::Bool=false,ifnotexists::Bool=false)
    names = SQLite.make_unique([SQLite.identifier(i) for i in file.header])
    sqltypes = [string(names[i]) * SQLite.gettype(file.types[i]) for i = 1:file.cols]
    N = transaction(db) do
        # create table statement
        t = temp ? "TEMP " : ""
        exists = ifnotexists ? "if not exists" : ""
        SQLite.execute!(db,"CREATE $(t)TABLE $exists $name ($(join(sqltypes,',')))")
        # insert statements
        params = chop(repeat("?,",file.cols))
        stmt = SQLite.Stmt(db,"insert into $name values ($params)")
        #bind, step, reset loop for inserting values
        io = CSV.open(file)
        seek(io,file.datapos+1)
        N = file.datarow
        while !eof(io)
            for col = 1:file.cols
                SQLite.readbind!(io,file.types[col],N,col,stmt)
            end
            SQLite.execute!(stmt)
            N += 1
            b = CSV.peek(io)
            empty = b == CSV.NEWLINE || b == CSV.RETURN
            if empty
                file.skipblankrows && CSV.skipn!(io,1,file.quotechar,file.escapechar)
            end
        end
        return N - file.datarow
    end
    execute!(db,"analyze $name")
    return ResultSet(["Rows Loaded"],Any[Any[N]])
end

function createindex(db::DB,table::AbstractString,index::AbstractString,cols
                    ;unique::Bool=true,ifnotexists::Bool=false)
    u = unique ? "unique" : ""
    exists = ifnotexists ? "if not exists" : ""
    transaction(db) do
        execute!(db,"create $u index $exists $index on $table ($cols)")
    end
    execute!(db,"analyze $index")
    return changes(db)
end

function append!(db::DB,name::AbstractString,file::CSV.File)
    N = transaction(db) do
        # insert statements
        params = chop(repeat("?,",file.cols))
        stmt = SQLite.Stmt(db,"insert into $name values ($params)")
        #bind, step, reset loop for inserting values
        io = CSV.open(file)
        seek(io,file.datapos)
        N = 0
        while !eof(io)
            for col = 1:file.cols
                SQLite.readbind!(io,file.types[col],N,col,stmt)
            end
            execute!(stmt)
            N += 1
        end
        return N
    end
    execute!(db,"analyze $name")
    return ResultSet(["Rows Loaded"],Any[Any[N]])
end
function append!(db::DB,name::AbstractString,table)
    N, M = size(table)
    transaction(db) do
        # insert statements
        params = chop(repeat("?,",M))
        stmt = Stmt(db,"insert into $name values ($params)")
        #bind, step, reset loop for inserting values
        for row = 1:N
            for col = 1:M
                @inbounds v = table[row,col]
                bind!(stmt,col,v)
            end
            execute!(stmt)
        end
    end
    execute!(db,"analyze $name")
    return ResultSet(["Rows Loaded"],Any[Any[N]])
end

function deleteduplicates!(db,table::AbstractString,cols::AbstractString)
    transaction(db) do
        execute!(db,"delete from $table where rowid not in (select max(rowid) from $table group by $cols);")
    end
    execute!(db,"analyze $table")
    return changes(db)
end
