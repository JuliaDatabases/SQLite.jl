module SQLite

using Compat
using CSV
using Libz
using DataStreams

importall Base.Operators

type SQLiteException <: Exception
    msg::AbstractString
end

# export SQLiteStmt, SQLiteDB
# @deprecate SQLiteStmt SQLite.Stmt
# @deprecate SQLiteDB SQLite.DB

include("consts.jl")
include("api.jl")
include("utils.jl")
include("serialize.jl")

# Custom NULL type
immutable NullType end
const NULL = NullType()
Base.show(io::IO,::NullType) = print(io,"#NULL")

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

import Base.close

type DB
    file::UTF8String
    handle::Ptr{Void}
    changes::Int

    function DB(f::UTF8String)
        handlemem = Ptr{Void}[C_NULL]
        f = isempty(f) ? f : expanduser(f)
        if @OK sqliteopen(f,handlemem)
            db = new(f,handlemem[1],0)
            finalizer(db, close)
            return db
        else # error
            sqlite3_close(handlemem[1])
            sqliteerror()
        end
    end
end
DB(f::AbstractString) = DB(utf8(f))
DB() = DB(":memory:")

Base.show(io::IO, db::SQLite.DB) = print(io, string("SQLite.DB(",db.file == ":memory:" ? "in-memory" : "\"$(db.file)\"",")"))

function Base.close(db::DB)
    db.handle==C_NULL || @CHECK db sqlite3_close(db.handle)
    db.handle = C_NULL # make sure released handle not reused
    nothing
end

function changes(db::DB)
    new_tot = sqlite3_total_changes(db.handle)
    diff = new_tot - db.changes
    db.changes = new_tot
    return ResultSet(["Rows Affected"],Any[Any[diff]])
end

type Stmt
    db::DB
    handle::Ptr{Void}

    function Stmt(db::DB,sql::UTF8String)
        handlemem = [C_NULL]
        @CHECK db sqlite3_prepare_v2(db.handle,sql,handlemem,[C_NULL])
        stmt = new(db,handlemem[1])
        finalizer(stmt, close)
        return stmt
    end
end
Stmt(db::DB, sql::AbstractString) = Stmt(db,utf8(sql))

function Base.close(stmt::Stmt)
    stmt.handle==C_NULL || @CHECK stmt.db sqlite3_finalize(stmt.handle)
    stmt.handle = C_NULL # make sure released handle not reused
    nothing
end

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
        name = name[1]=='@' ? name : name[2:end]
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
bind!(stmt::Stmt,i::Int,val::AbstractFloat)  = @CHECK stmt.db sqlite3_bind_double(stmt.handle,i,Float64(val))
bind!(stmt::Stmt,i::Int,val::Int32)          = @CHECK stmt.db sqlite3_bind_int(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::Int64)          = @CHECK stmt.db sqlite3_bind_int64(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::NullType)       = @CHECK stmt.db sqlite3_bind_null(stmt.handle,i)
bind!(stmt::Stmt,i::Int,val::ASCIIString)    = @CHECK stmt.db sqlite3_bind_text(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::UTF8String)     = @CHECK stmt.db sqlite3_bind_text(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::AbstractString) = @CHECK stmt.db sqlite3_bind_text(stmt.handle,i,utf8(val))
# We may want to track the new ByteVec type proposed at https://github.com/JuliaLang/julia/pull/8964
# as the "official" bytes type instead of Vector{UInt8}
bind!(stmt::Stmt,i::Int,val::Vector{UInt8})  = @CHECK stmt.db sqlite3_bind_blob(stmt.handle,i,val)
# Fallback is BLOB and defaults to serializing the julia value
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
    close(stmt)
    return changes(db)
end

type Source <: Data.Source # <: IO
    schema::Data.Schema
    stmt::Stmt
    status::Cint
    function Source(db::DB,sql::AbstractString, values=[])
        stmt = SQLite.Stmt(db,sql)
        bind!(stmt, values)
        status = SQLite.execute!(stmt)
        #TODO: build Schema
        cols = sqlite3_column_count(stmt.handle)
        types = DataType[]
        for i=1:cols
            t = sqlite3_column_type(stmt.handle,i-1)
            if t == SQLITE_INTEGER   push!(types,Integer)
            elseif t == SQLITE_FLOAT push!(types,AbstractFloat)
            elseif t == SQLITE_TEXT  push!(types,AbstractString)
            elseif t == SQLITE_BLOB  push!(types,Any)
            else                     push!(types,Any)
            end
        end
        schema = Data.Schema(types)
        new(schema,stmt,status)
        # source = new(schema,stmt,status)
        # finalizer(source, close)    # do we need a finalizer here?
    end
end

function Base.close(s::Source)
    close(s.stmt)
end

include("UDF.jl")
export @sr_str, @register, register

type Table
    db::DB
    name::AbstractString
end

# function Base.open(table::Table)
#     return open(table.db,"select * from $(table.name)")
# end

function Base.eof(s::Source)
    (s.status == SQLITE_DONE || s.status == SQLITE_ROW) || sqliteerror(s.stmt.db)
    return s.status == SQLITE_DONE
end

Base.start(s::Source) = 1
Base.done(s::Source,col) = eof(s)
function Base.next(s::Source,i)
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
    if i == size(s.schema,2)
        s.status = sqlite3_step(s.stmt.handle)
        i = 1
    else
        i += 1
    end
    return r, i
end

function Base.readline(s::Source,delim::Char=',',buf::IOBuffer=IOBuffer())
    eof(s) && return ""
    for i = 1:size(s.schema,2)
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
    source = Source(db,sql,values)
    ncols = size(source.schema,2) 
    if (eof(source) || ncols == 0)
        close(source)
        return changes(db)
    end
    colnames = Array(AbstractString,ncols)
    results = Array(Any,ncols)
    for i = 1:ncols
        colnames[i] = bytestring(sqlite3_column_name(source.stmt.handle,i-1))
        results[i] = Any[]
    end
    col = 1
    while !eof(source)
        c = col
        r, col = next(source,col)
        push!(results[c],r)
    end
    close(source)
    return ResultSet(colnames, results)
end

function tables(db::DB)
    query(db,"SELECT name FROM sqlite_master WHERE type='table';")
end

function indices(db::DB)
    query(db,"SELECT name FROM sqlite_master WHERE type='index';")
end

columns(db::DB,table::AbstractString) = query(db,"pragma table_info($table)")

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
            close(stmt)
        end
    end
    execute!(db,"analyze $name")
    return ResultSet(["Rows Loaded"],Any[Any[N]])
end

# function readbind!{T<:Union{Integer,Float64}}(io,::Type{T},row,col,stmt)
#     val, isnull = CSV.readfield(io,T,row,col)
#     bind!(stmt,col,ifelse(isnull,NULL,val))
#     return
# end
# function readbind!(io, ::Type{Date}, row, col, stmt)
#     bind!(stmt,col,CSV.readfield(io,Date,row,col)[1])
#     return
# end
# function readbind!{T<:AbstractString}(io,::Type{T},row,col,stmt)
#     str, isnull = CSV.readfield(io,T,row,col)
#     if isnull
#         bind!(stmt,col,NULL)
#     else
#         sqlite3_bind_text(stmt.handle,col,str.ptr,str.len)
#     end
#     return
# end
# 
# function create(db::DB,file::CSV.Source,name::AbstractString=splitext(basename(file.fullpath))[1]
#                 ;temp::Bool=false,ifnotexists::Bool=false)
#     names = SQLite.make_unique([SQLite.identifier(i) for i in file.schema.header])
#     sqltypes = [string(names[i]) * SQLite.gettype(file.schema.types[i]) for i = 1:file.schema.cols]
#     N = transaction(db) do
#         # create table statement
#         t = temp ? "TEMP " : ""
#         exists = ifnotexists ? "if not exists" : ""
#         SQLite.execute!(db,"CREATE $(t)TABLE $exists $name ($(join(sqltypes,',')))")
#         # insert statements
#         params = chop(repeat("?,",file.schema.cols))
#         stmt = SQLite.Stmt(db,"insert into $name values ($params)")
#         #bind, step, reset loop for inserting values
#         # io = CSV.open(file)
#         seek(file,file.datapos+1)
#         N = 0
#         while !eof(file)
#             for col = 1:file.schema.cols
#                 SQLite.readbind!(file,file.schema.types[col],N,col,stmt)
#             end
#             SQLite.execute!(stmt)
#             N += 1
#             b = CSV.peek(file)
#             empty = b == CSV.NEWLINE || b == CSV.RETURN
#             if empty
#                 file.skipblankrows && CSV.skipn!(file,1,file.quotechar,file.escapechar)
#             end
#         end
#         close(stmt)
#         return N
#     end
#     execute!(db,"analyze $name")
#     return ResultSet(["Rows Loaded"],Any[Any[N]])
# end
# 
# function createindex(db::DB,table::AbstractString,index::AbstractString,cols
#                     ;unique::Bool=true,ifnotexists::Bool=false)
#     u = unique ? "unique" : ""
#     exists = ifnotexists ? "if not exists" : ""
#     transaction(db) do
#         execute!(db,"create $u index $exists $index on $table ($cols)")
#     end
#     execute!(db,"analyze $index")
#     return changes(db)
# end
# 
# function append!(db::DB,name::AbstractString,file::CSV.Source)
#     N = transaction(db) do
#         # insert statements
#         params = chop(repeat("?,",file.cols))
#         stmt = SQLite.Stmt(db,"insert into $name values ($params)")
#         #bind, step, reset loop for inserting values
#         io = CSV.open(file)
#         seek(io,file.datapos)
#         N = 0
#         while !eof(io)
#             for col = 1:file.cols
#                 SQLite.readbind!(io,file.types[col],N,col,stmt)
#             end
#             execute!(stmt)
#             N += 1
#         end
#         close(stmt)
#         return N
#     end
#     execute!(db,"analyze $name")
#     return ResultSet(["Rows Loaded"],Any[Any[N]])
# end
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
        close(stmt)
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
