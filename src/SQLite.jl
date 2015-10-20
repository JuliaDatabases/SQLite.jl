module SQLite

using Compat, NullableArrays, CSV, Libz, DataStreams
import CSV.PointerString

#TODO
 # create old_ui.jl file w/ deprecations
   # make all function renames
   # make new types SQLite.DB/Stmt, get code from jq/updates
   # deprecate all old function names/types
 # create Source.jl, Sink.jl files
   # pull Source code from jq/updates
   # stream!(SQLite.Source,DataStream)
   # stream!(SQLite.Source,CSV.Sink)
   # stream!(DataStream,SQLite.Sink)
   # stream!(CSV.Source,SQLite.Sink)
 # rewrite tests
 # add new tests file for Source/Sink

export NULL, SQLiteDB, SQLiteStmt, ResultSet,
       execute, query, tables, indices, columns, droptable, dropindex,
       create, createindex, append, deleteduplicates

import Base: ==, show, convert, bind, close

type SQLiteException <: Exception
    msg::AbstractString
end

include("consts.jl")
include("api.jl")

# Custom NULL type
immutable NullType end
const NULL = NullType()
show(io::IO,::NullType) = print(io,"#NULL")

# internal wrapper type to, in-effect, mark something which has been serialized
immutable Serialization
    object
end

#TODO: Support sqlite3_open_v2
# Normal constructor from filename
sqliteopen(file,handle) = sqlite3_open(file,handle)
sqliteopen(file::UTF16String,handle) = sqlite3_open16(file,handle)
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
            register(db, regexp, nargs=2, name="regexp")
            finalizer(db, _close)
            return db
        else # error
            sqlite3_close(handle[1])
            sqliteerror()
        end
    end
end
DB(f::AbstractString) = DB(utf8(f))
DB() = DB(":memory:")

function _close(db::DB)
    sqlite3_close_v2(db.handle)
    db.handle = C_NULL
    return
end

Base.show(io::IO, db::SQLite.DB) = print(io, string("SQLite.DB(",db.file == ":memory:" ? "in-memory" : "\"$(db.file)\"",")"))

type Stmt
    db::DB
    handle::Ptr{Void}

    function Stmt(db::DB,sql::AbstractString)
        handle = [C_NULL]
        sqliteprepare(db,sql,handle,[C_NULL])
        stmt = new(db,handle[1])
        finalizer(stmt, _close)
        return stmt
    end
end

function _close(stmt::Stmt)
    sqlite3_finalize(stmt.handle)
    stmt.handle = C_NULL
    return
end

sqliteprepare(db,sql,stmt,null) =
    @CHECK db sqlite3_prepare_v2(db.handle,utf8(sql),stmt,null)

# TO DEPRECATE
type SQLiteDB{T<:AbstractString}
   file::T
   handle::Ptr{Void}
   changes::Int
end
SQLiteDB(file,handle) = SQLiteDB(file,handle,0)
include("UDF.jl")
include("old_ui.jl")
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
bind!(stmt::Stmt,i::Int,val::AbstractFloat)  = sqlite3_bind_double(stmt.handle,i,Float64(val))
bind!(stmt::Stmt,i::Int,val::Int32)          = sqlite3_bind_int(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::Int64)          = sqlite3_bind_int64(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::NullType)       = sqlite3_bind_null(stmt.handle,i)
bind!(stmt::Stmt,i::Int,val::AbstractString) = sqlite3_bind_text(stmt.handle,i,val)
bind!(stmt::Stmt,i::Int,val::PointerString)  = sqlite3_bind_text(stmt.handle,i,val.ptr,val.len)
bind!(stmt::Stmt,i::Int,val::UTF16String)    = sqlite3_bind_text16(stmt.handle,i,val)
# We may want to track the new ByteVec type proposed at https://github.com/JuliaLang/julia/pull/8964
# as the "official" bytes type instead of Vector{UInt8}
bind!(stmt::Stmt,i::Int,val::Vector{UInt8})  = sqlite3_bind_blob(stmt.handle,i,val)
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
    return execute!(stmt)
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

# Transaction-based commands
function transaction(db, mode="DEFERRED")
    #=
     Begin a transaction in the spedified mode, default "DEFERRED".

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
    return
end

function dropindex!(db::DB,index::AbstractString;ifexists::Bool=false)
    exists = ifexists ? "if exists" : ""
    transaction(db) do
        execute!(db,"drop index $exists $index")
    end
    return
end

function createindex!(db::DB,table::AbstractString,index::AbstractString,cols
                    ;unique::Bool=true,ifnotexists::Bool=false)
    u = unique ? "unique" : ""
    exists = ifnotexists ? "if not exists" : ""
    transaction(db) do
        execute!(db,"create $u index $exists $index on $table ($cols)")
    end
    execute!(db,"analyze $index")
    return
end

function deleteduplicates!(db,table::AbstractString,cols::AbstractString)
    transaction(db) do
        execute!(db,"delete from $table where rowid not in (select max(rowid) from $table group by $cols);")
    end
    execute!(db,"analyze $table")
    return
end

include("Source.jl")
include("Sink.jl")

end #SQLite module
