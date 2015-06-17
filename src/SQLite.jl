module SQLite

using Compat
reload("CSV")
import CSV

export NULL, ResultSet,
       execute!, query, tables, indices, columns, drop!, dropindex!,
       create, createindex, append!, deleteduplicates!

type SQLiteException <: Exception
    msg::AbstractString
end

# export SQLiteStmt, SQLiteDB
# @deprecate SQLiteStmt SQLite.Stmt
# @deprecate SQLiteDB SQLite.DB

include("consts.jl")
include("api.jl")
include("utils.jl")

# Custom NULL type
immutable NullType end
const NULL = NullType()
Base.show(io::IO,::NullType) = print(io,"NULL")

# internal wrapper type to, in-effect, mark something which has been serialized
immutable Serialization
    object
end

type ResultSet
    colnames
    values::Vector{Any}
end
==(a::ResultSet,b::ResultSet) = a.colnames == b.colnames && a.values == b.values
include("show.jl")
Base.convert(::Type{Matrix},a::ResultSet) = [a[i,j] for i=1:size(a,1), j=1:size(a,2)]

#TODO: Support sqlite3_open_v2
# Normal constructor from filename
sqliteopen(file::UTF8String,handle) = sqlite3_open(file,handle)
# sqliteopen(file::UTF16String,handle) = sqlite3_open16(file,handle)
sqliteerror() = throw(SQLiteException(bytestring(sqlite3_errmsg())))
sqliteerror(db) = throw(SQLiteException(bytestring(sqlite3_errmsg(db.handle))))

type DB
    file::UTF8String
    handle::Ptr{Void}
    changes::Int

    function DB(f::UTF8String)
        handle = [C_NULL]
        f = isempty(f) ? f : expanduser(f)
        if @OK sqliteopen(f,handle)
            db = new(f,handle[1],0)
            register(db, regexp, nargs=2)
            finalizer(db, x->sqlite3_close(handle[1]))
            return db
        else # error
            sqlite3_close(handle[1])
            sqliteerror()
        end
    end
end
DB(f::AbstractString) = DB(utf8(f))
DB() = DB(":memory:")

Base.show(io::IO, db::SQLite.DB) = print(io, string("SQLite.DB(",db.file == ":memory:" ? "in-memory" : "\"$(db.file)\"",")"))

function changes(db::DB)
    new_tot = sqlite3_total_changes(db.handle)
    diff = new_tot - db.changes
    db.changes = new_tot
    return ResultSet(["Rows Affected"],Any[Any[diff]])
end

type Stmt
    db::DB
    handle::Ptr{Void}

    function Stmt(db::DB,sql::AbstractString)
        handle = [C_NULL]
        sqliteprepare(db,sql,handle,[C_NULL])
        stmt = new(db,handle[1])
        finalizer(stmt, x->sqlite3_finalize(handle[1]))
        return stmt
    end
end

sqliteprepare(db,sql,stmt,null) = @CHECK db sqlite3_prepare_v2(db.handle,utf8(sql),stmt,null)
# sqliteprepare(db::DB{UTF16String},sql,stmt,null) = @CHECK db sqlite3_prepare16_v2(db.handle,utf16(sql),stmt,null)

type Table
    db::DB
    name::AbstractString
end

include("UDF.jl")
export @sr_str, @register, register

# bind a row to nameless parameters
function bind!(stmt::Stmt, values::Vector)
    nparams = sqlite3_bind_parameter_count(stmt.handle)
    @assert nparams == length(values) "you must provide values for all placeholders"
    for i in 1:nparams
        @inbounds bind!(stmt, i, values[i])
    end
end
# bind a row to named parameters
function bind!{V}(stmt::Stmt, values::Dict{Symbol, V})
    nparams = sqlite3_bind_parameter_count(stmt.handle)
    @assert nparams == length(values) "you must provide values for all placeholders"
    for i in 1:nparams
        name = bytestring(sqlite3_bind_parameter_name(stmt.handle, i))
        @assert !isempty(name) "nameless parameters should be passed as a Vector"
        # name is returned with the ':', '@' or '$' at the start
        name = name[2:end]
        bind!(stmt, i, values[symbol(name)])
    end
end
# Binding parameters to SQL statements
function bind!(stmt::Stmt,name::AbstractString,val)
    i = sqlite3_bind_parameter_index(stmt.handle,name)
    if i == 0
        throw(SQLiteException("SQL parameter $name not found in $stmt"))
    end
    return bind!(stmt,i,val)
end
bind!(stmt::Stmt,i::Int,val::FloatingPoint)  = @CHECK stmt.db sqlite3_bind_double(stmt.handle,i,Float64(val))
bind!(stmt::Stmt,i::Int,val::Int32)          = @CHECK stmt.db sqlite3_bind_int(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::Int64)          = @CHECK stmt.db sqlite3_bind_int64(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::NullType)       = @CHECK stmt.db sqlite3_bind_null(stmt.handle,i)
bind!(stmt::Stmt,i::Int,val::AbstractString) = @CHECK stmt.db sqlite3_bind_text(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::UTF16String)    = @CHECK stmt.db sqlite3_bind_text16(stmt.handle,i,val)
# We may want to track the new ByteVec type proposed at https://github.com/JuliaLang/julia/pull/8964
# as the "official" bytes type instead of Vector{UInt8}
bind!(stmt::Stmt,i::Int,val::Vector{UInt8})  = @CHECK stmt.db sqlite3_bind_blob(stmt.handle,i,val)
# Fallback is BLOB and defaults to serializing the julia value
function sqlserialize(x)
    t = IOBuffer()
    # deserialize will sometimes return a random object when called on an array
    # which has not been previously serialized, we can use this type to check
    # that the array has been serialized
    s = Serialization(x)
    serialize(t,s)
    return takebuf_array(t)
end
bind!(stmt::Stmt,i::Int,val) = bind!(stmt,i,sqlserialize(val))
#TODO:
 #int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
 #int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);

# Execute SQL statements
function execute!(stmt::Stmt)
    r = sqlite3_step(stmt.handle)
    if r == SQLITE_DONE
        sqlite3_reset(stmt.handle)
    elseif r != SQLITE_ROW
        sqliteerror(stmt.db)
    end
    return r
end
function execute!(db::DB,sql::AbstractString)
    stmt = Stmt(db,sql)
    execute!(stmt)
    return changes(db)
end

const SERIALIZATION = UInt8[0x11,0x01,0x02,0x0d,0x53,0x65,0x72,0x69,0x61,0x6c,0x69,0x7a,0x61,0x74,0x69,0x6f,0x6e,0x23]
function sqldeserialize(r)
    ret = ccall(:memcmp, Int32, (Ptr{UInt8},Ptr{UInt8}, UInt),
            SERIALIZATION, r, min(18,length(r)))
    
    if ret == 0
        v = deserialize(IOBuffer(r))
        return v.object
    else
        return r
    end
end

type Stream <: IO
    stmt::Stmt
    cols::Int
    status::Cint
end

function Base.open(db::DB,sql::AbstractString, values=[])
    stmt = SQLite.Stmt(db,sql)
    bind!(stmt, values)
    status = SQLite.execute!(stmt)
    cols = sqlite3_column_count(stmt.handle)
    return Stream(stmt,cols,status)
end

function Base.open(table::Table)
    return open(table.db,"select * from $(table.name)")
end

function Base.eof(s::Stream)
    (s.status == SQLITE_DONE || s.status == SQLITE_ROW) || sqliteerror(s.stmt.db)
    return s.status == SQLITE_DONE
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

function Base.readline(s::Stream,delim::Char=',',buf::IOBuffer=IOBuffer())
    eof(s) && return ""
    for i = 1:s.cols
        val = sqlite3_column_text(s.stmt.handle,i-1)
        val != C_NULL && write(buf,bytestring(val))
        write(buf,ifelse(i == s.cols,'\n',delim))
    end
    s.status = sqlite3_step(s.stmt.handle)
    return takebuf_string(buf)
end

function scalarquery(db::DB,sql)
    stream = SQLite.open(db,sql)
    return next(stream,1)[1]
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

columns(db::DB,table::String) = query(db,"pragma table_info($table)")

# Transaction-based commands
function transaction(db, mode="DEFERRED")
    #=
     Begin a transaction in the specified mode, default "DEFERRED".

     If mode is one of "", "DEFERRED", "IMMEDIATE" or "EXCLUSIVE" then a
     transaction of that (or the default) type is started. Otherwise a savepoint
     is created whose name is mode converted to AbstractString.
    =#
    if uppercase(mode) in ["", "DEFERRED", "IMMEDIATE", "EXCLUSIVE"]
        execute!(db, "BEGIN $(mode) TRANSACTION;")
    else
        execute!(db, "SAVEPOINT $(mode);")
    end
end

function transaction(f::Function, db)
    #=
     Execute the function f within a transaction.
    =#
    # generate a random name for the savepoint
    name = string("SQLITE",randstring(10))
    execute!(db,"PRAGMA synchronous = OFF")
    transaction(db, name)
    try
        f()
    catch
        rollback(db, name)
        rethrow()
    finally
        # savepoints are not released on rollback
        commit(db, name)
        execute!(db,"PRAGMA synchronous = ON")
    end
end

# commit a transaction or savepoint (if name is given)
commit(db) = execute!(db, "COMMIT TRANSACTION;")
commit(db, name) = execute!(db, "RELEASE SAVEPOINT $(name);")

# rollback transaction or savepoint (if name is given)
rollback(db) = execute!(db, "ROLLBACK TRANSACTION;")
rollback(db, name) = execute!(db, "ROLLBACK TRANSACTION TO SAVEPOINT $(name);")

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

gettype{T<:Integer}(::Type{T}) = " INT"
gettype{T<:Real}(::Type{T}) = " REAL"
gettype{T<:AbstractString}(::Type{T}) = " TEXT"
gettype(::Type) = " BLOB"
gettype(::Type{NullType}) = " NULL"

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

# const SPACE = UInt8(' ')
# const TAB = UInt8('\t')
# const MINUS = UInt8('-')
# const PLUS = UInt8('+')
# const NEG_ONE = UInt8('0')-UInt8(1)
# const ZERO = UInt8('0')
# const TEN = UInt8('9')+UInt8(1)

# # io = Mmap.Array, pos = current parsing position, eof = length(io) + 1
# @inline function readbind{T<:Integer}(io,pos,eof,::Type{T}, row, col, stmt,q,e,d,n)
#     @inbounds begin
#     b = io[pos]; pos += 1
#     while pos < eof && (b == SPACE || b == TAB || b == q)
#         b = io[pos]; pos += 1
#     end
#     if pos == eof || b == d || b == n
#         bind!(stmt,col,NULL)
#         return pos
#     end
#     negative = false
#     if b == MINUS
#         negative = true
#         b = io[pos]; pos += 1
#     elseif b == PLUS
#         b = io[pos]; pos += 1
#     end
#     v = zero(T)
#     while pos < eof && NEG_ONE < b < TEN
#         # process digits
#         v *= 10
#         v += b - ZERO
#         b = io[pos]; pos += 1
#     end
#     end # @inbounds
#     if b == d || b == n || pos == eof
#         bind!(stmt,col,negative ? -v : v)
#         return pos
#     else
#         throw(CSV.CSVError("error parsing $T on column $col, row $row; parsed $v before encountering $(Char(b)) character"))
#     end
# end

# @inline function readbind{T<:AbstractString}(io,pos,eof,::Type{T}, row, col, stmt,q,e,d,n)
#     orig_pos = pos
#     @inbounds while pos < eof
#         b = io[pos]; pos += 1
#         if b == q
#             while pos < eof
#                 b = io[pos]; pos += 1
#                 if b == e
#                     b = io[pos]; pos += 2
#                 elseif b == q
#                     break
#                 end
#             end
#         elseif b == d || b == n
#             break
#         end
#     end
#     if orig_pos == pos-1
#         bind!(stmt,col,NULL)
#     else
#         ccall( (:sqlite3_bind_text, sqlite3_lib),
#             Cint, (Ptr{Void},Cint,Ptr{Uint8},Cint,Ptr{Void}),
#             stmt.handle,col,pointer(io.array)+Uint(orig_pos-1),pos-orig_pos-1,C_NULL)
#     end
#     return pos
# end

function readbind!{T<:Integer}(io,::Type{T},row,col,stmt)
    val, isnull = CSV.readfield(io,T,row,col)
    bind!(stmt,col,ifelse(isnull,NULL,val))
    return
end
function readbind!{T<:AbstractString}(io,::Type{T},row,col,stmt)
    ptr, len, isnull = CSV.readfield(io,T,row,col)
    if isnull
        bind!(stmt,col,NULL)
    else
        sqlite3_bind_text(stmt.handle,col,ptr,len)
    end
    return
end

function create(db::DB,file::CSV.File,name::AbstractString=basename(file.fullpath)
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
        seek(io,file.datapos)
        N = 0
        while !eof(io)
            for col = 1:file.cols
                SQLite.readbind!(io,file.types[col],N,col,stmt)
            end
            SQLite.execute!(stmt)
            N += 1
        end
        return N
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

end #SQLite module