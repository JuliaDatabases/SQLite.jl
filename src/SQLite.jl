module SQLite

export NULL, SQLiteDB, SQLiteStmt, ResultSet,
       execute, query, tables, drop, create, append

type SQLiteException <: Exception
    msg::String
end

include("consts.jl")
include("api.jl")


# Custom NULL type
immutable NullType end
const NULL = NullType()
Base.show(io::IO,::NullType) = print(io,"NULL")

type ResultSet
    colnames
    values::Vector{Any}
end
==(a::ResultSet,b::ResultSet) = a.colnames == b.colnames && a.values == b.values
include("show.jl")

type SQLiteDB{T<:String}
    file::T
    handle::Ptr{Void}
    changes::Int
end
SQLiteDB(file,handle) = SQLiteDB(file,handle,0)

function changes(db::SQLiteDB)
    new_tot = sqlite3_total_changes(db.handle)
    diff = new_tot - db.changes
    db.changes = new_tot
    return ResultSet(["Rows Affected"],Any[Any[diff]])
end

#TODO: Support sqlite3_open_v2
# Normal constructor from filename
sqliteopen(file,handle) = sqlite3_open(file,handle)
sqliteopen(file::UTF16String,handle) = sqlite3_open16(file,handle)
sqliteerror() = throw(SQLiteException(bytestring(sqlite3_errmsg())))
sqliteerror(db) = throw(SQLiteException(bytestring(sqlite3_errmsg(db.handle))))

function SQLiteDB(file::String="";UTF16::Bool=false)
    handle = [C_NULL]
    utf = UTF16 ? utf16 : utf8
    file = isempty(file) ? file : expanduser(file)
    if @OK sqliteopen(utf(file),handle)
        db = SQLiteDB(utf(file),handle[1])
        finalizer(db,close)
        return db
    else # error
        sqlite3_close(handle[1])
        sqliteerror()
    end
end

function Base.close{T}(db::SQLiteDB{T})
    db.handle == C_NULL && return
    @CHECK db sqlite3_close(db.handle)
    db.handle = C_NULL
    return
end

type SQLiteStmt{T}
    db::SQLiteDB{T}
    handle::Ptr{Void}
    sql::T
end

sqliteprepare(db,sql,stmt,null) = 
    @CHECK db sqlite3_prepare_v2(db.handle,utf8(sql),stmt,null)
sqliteprepare(db::SQLiteDB{UTF16String},sql,stmt,null) = 
    @CHECK db sqlite3_prepare16_v2(db.handle,utf16(sql),stmt,null)

function SQLiteStmt{T}(db::SQLiteDB{T},sql::String)
    handle = [C_NULL]
    sqliteprepare(db,sql,handle,[C_NULL])
    stmt = SQLiteStmt(db,handle[1],convert(T,sql))
    return stmt
end

function Base.close(stmt::SQLiteStmt)
    stmt.handle == C_NULL && return
    @CHECK stmt.db sqlite3_finalize(stmt.handle)
    stmt.handle = C_NULL
    return
end

# Binding parameters to SQL statements
function Base.bind(stmt::SQLiteStmt,name::String,val)
    i = sqlite3_bind_parameter_index(stmt.handle,name)
    if i == 0
        throw(SQLiteException("SQL parameter $name not found in $stmt"))
    end
    return bind(stmt,i,val)
end
Base.bind(stmt::SQLiteStmt,i::Int,val::FloatingPoint) = @CHECK stmt.db sqlite3_bind_double(stmt.handle,i,float64(val))
Base.bind(stmt::SQLiteStmt,i::Int,val::Int32)         = @CHECK stmt.db sqlite3_bind_int(stmt.handle,i,val)
Base.bind(stmt::SQLiteStmt,i::Int,val::Int64)         = @CHECK stmt.db sqlite3_bind_int64(stmt.handle,i,val)
Base.bind(stmt::SQLiteStmt,i::Int,val::NullType)      = @CHECK stmt.db sqlite3_bind_null(stmt.handle,i)
Base.bind(stmt::SQLiteStmt,i::Int,val::String)        = @CHECK stmt.db sqlite3_bind_text(stmt.handle,i,val)
Base.bind(stmt::SQLiteStmt,i::Int,val::UTF16String)   = @CHECK stmt.db sqlite3_bind_text16(stmt.handle,i,val)
# Fallback is BLOB and defaults to serializing the julia value
function sqlserialize(x)
    t = IOBuffer()
    serialize(t,x)
    return takebuf_array(t)
end
Base.bind(stmt::SQLiteStmt,i::Int,val) = @CHECK stmt.db sqlite3_bind_blob(stmt.handle,i,sqlserialize(val))
#TODO:
 #int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
 #int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);

# Execute SQL statements
function execute(stmt::SQLiteStmt)
    r = sqlite3_step(stmt.handle)
    if r == SQLITE_DONE
        sqlite3_reset(stmt.handle)
    elseif r != SQLITE_ROW
        sqliteerror(stmt.db)
    end
    return r
end
function execute(db::SQLiteDB,sql::String)
    stmt = SQLiteStmt(db,sql)
    execute(stmt)
    close(stmt)
    return changes(db)
end

sqldeserialize(r) = deserialize(IOBuffer(r))

function query(db::SQLiteDB,sql::String)
    stmt = SQLiteStmt(db,sql)
    status = execute(stmt)
    ncols = sqlite3_column_count(stmt.handle)
    if status == SQLITE_DONE || ncols == 0
        close(stmt)
        return changes(db)
    end
    colnames = Array(String,ncols)
    results = Array(Any,ncols)
    for i = 1:ncols
        colnames[i] = bytestring(sqlite3_column_name(stmt.handle,i-1))
        results[i] = Any[]
    end
    while status == SQLITE_ROW
        for i = 1:ncols
            t = sqlite3_column_type(stmt.handle,i-1) 
            if t == SQLITE_INTEGER
                r = sqlite3_column_int64(stmt.handle,i-1)
            elseif t == SQLITE_FLOAT
                r = sqlite3_column_double(stmt.handle,i-1)
            elseif t == SQLITE_TEXT
                #TODO: have a way to return text16?
                r = bytestring( sqlite3_column_text(stmt.handle,i-1) )
            elseif t == SQLITE_BLOB
                blob = sqlite3_column_blob(stmt.handle,i-1)
                b = sqlite3_column_bytes(stmt.handle,i-1)
                buf = zeros(Uint8,b)
                unsafe_copy!(pointer(buf), convert(Ptr{Uint8},blob), b)
                r = sqldeserialize(buf)
            else
                r = NULL
            end
            push!(results[i],r)
        end
        status = sqlite3_step(stmt.handle)
    end
    close(stmt)
    if status == SQLITE_DONE
        return ResultSet(colnames, results)
    else
        sqliteerror(stmt.db)
    end
end

function tables(db::SQLiteDB)
    query(db,"SELECT name FROM sqlite_master WHERE type='table';")
end

function indices(db::SQLiteDB)
    query(db,"SELECT name FROM sqlite_master WHERE type='index';")
end

# Transaction-based commands
function transaction(db, mode="DEFERRED")
    #=
     Begin a transaction in the spedified mode, default "DEFERRED".

     If mode is one of "", "DEFERRED", "IMMEDIATE" or "EXCLUSIVE" then a
     transaction of that (or the default) type is started. Otherwise a savepoint
     is created whose name is mode converted to String.
    =#
    if uppercase(mode) in ["", "DEFERRED", "IMMEDIATE", "EXCLUSIVE"]
        execute(db, "BEGIN $(mode) TRANSACTION;")
    else
        execute(db, "SAVEPOINT $(mode);")
    end
end

function transaction(f::Function, db)
    #=
     Execute the function f within a transaction.
    =#
    # generate a random name for the savepoint
    name = string("SQLITE",randstring(10))
    execute(db,"PRAGMA synchronous = OFF")
    transaction(db, name)
    try
        f()
    catch
        rollback(db, name)
        rethrow()
    finally
        # savepoints are not released on rollback
        commit(db, name)
        execute(db,"PRAGMA synchronous = ON")
    end
end

# commit a transaction or savepoint (if name is given)
commit(db) = execute(db, "COMMIT TRANSACTION;")
commit(db, name) = execute(db, "RELEASE SAVEPOINT $(name);")

# rollback transaction or savepoint (if name is given)
rollback(db) = execute(db, "ROLLBACK TRANSACTION;")
rollback(db, name) = execute(db, "ROLLBACK TRANSACTION TO SAVEPOINT $(name);")

function drop(db::SQLiteDB,table::String)
    transaction(db) do
        execute(db,"drop table $table")
    end
    execute(db,"vacuum")
    return changes(db)
end

function dropindex(db::SQLiteDB,index::String)
    transaction(db) do
        execute(db,"drop index $index")
    end
    return changes(db)
end

gettype{T<:Integer}(::Type{T}) = " INT"
gettype{T<:Real}(::Type{T}) = " REAL"
gettype{T<:String}(::Type{T}) = " TEXT"
gettype(::Type) = " BLOB"
gettype(::Type{NullType}) = " NULL"

function create(db::SQLiteDB,name::String,table,
            colnames=String[],coltypes=DataType[];temp::Bool=false)
    N, M = size(table)
    colnames = isempty(colnames) ? ["x$i" for i=1:M] : colnames
    coltypes = isempty(coltypes) ? [typeof(table[1,i]) for i=1:M] : coltypes
    length(colnames) == length(coltypes) || throw(SQLiteException("colnames and coltypes must have same length"))
    cols = [colnames[i] * gettype(coltypes[i]) for i = 1:M]
    transaction(db) do
        # create table statement
        t = temp ? "TEMP " : ""
        execute(db,"CREATE $(t)TABLE $name ($(join(cols,',')))")
        # insert statements
        params = chop(repeat("?,",M))
        stmt = SQLiteStmt(db,"insert into $name values ($params)")
        #bind, step, reset loop for inserting values
        for row = 1:N
            for col = 1:M
                @inbounds v = table[row,col]
                bind(stmt,col,v)
            end
            execute(stmt)
        end
        close(stmt)
    end
    execute(db,"analyze $name")
    return changes(db)
end

function createindex(db::SQLiteDB,table::String,index::String,cols;unique::Bool=true)
    u = unique ? "unique" : ""
    transaction(db) do
        execute(db,"create $u index $index on $table ($cols)")
    end
    execute(db,"analyze $index")
    return changes(db)
end

function append(db::SQLiteDB,name::String,table)
    N, M = size(table)
    transaction(db) do
        # insert statements
        params = chop(repeat("?,",M))
        stmt = SQLiteStmt(db,"insert into $name values ($params)")
        #bind, step, reset loop for inserting values
        for row = 1:N
            for col = 1:M
                @inbounds v = table[row,col]
                bind(stmt,col,v)
            end
            execute(stmt)
        end
        close(stmt)
    end
    execute(db,"analyze $name")
    return return changes(db)
end

function deleteduplicates(db,table::String,cols::String)
    transaction(db) do
        execute(db,"delete from $table where rowid not in (select max(rowid) from $table group by $cols);")
    end
    execute(db,"analyze $table")
    return changes(db)
end

end #SQLite module

#TODO
 #create julia functions (https://docs.python.org/2/library/sqlite3.html#sqlite3.Connection.create_function)
