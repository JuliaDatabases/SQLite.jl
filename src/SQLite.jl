module SQLite

export NULL, SQLiteDB, SQLiteStmt, 
       execute!, query, tables, drop, create

include("consts.jl")
include("api.jl")

type SQLiteException <: Exception
    msg::String
end

# Custom NULL type
immutable NullType end
const NULL = NullType()
Base.show(io::IO,::NullType) = print(io,"NULL")

type SQLiteDB{T<:String}
    file::T
    handle::Ptr{Void}
end
#TODO: Support sqlite3_open_v2
# Normal constructor from filename
sqliteopen!(file,handle) = sqlite3_open(file,handle)
sqliteopen!(file::UTF16String,handle) = sqlite3_open16(file,handle)
sqliteerror() = throw(SQLiteException(bytestring(sqlite3_errmsg())))
sqliteerror(db) = throw(SQLiteException(bytestring(sqlite3_errmsg(db.handle))))

function SQLiteDB(file::String)
    handle = [C_NULL]
    if @OK sqliteopen!(file,handle)
        db = SQLiteDB(file,handle[1])
        finalizer(db,close)
        return db
    else # error
        sqlite3_close(handle[1])
        sqliteerror()
    end
end
# For creating new temporary connection; will be deleted when connection is closed
# if memory == true, then the temporary connection will be held in memory
SQLiteDB(;memory=false,UTF16=false) = UTF16 ? SQLiteDB(memory ? utf16(":memory:") : utf16("")) :
                                              SQLiteDB(memory ? ":memory:" : "")
function Base.close{T}(db::SQLiteDB{T})
    # Close all prepared statements with db
    stmt = C_NULL
    while true
        stmt = sqlite3_next_stmt(db.handle,stmt)
        stmt == C_NULL && break
        @CHECK db sqlite3_finalize(stmt)
    end
    @CHECK db sqlite3_close(db.handle)
end

type SQLiteStmt{T}
    db::SQLiteDB{T}
    handle::Ptr{Void}
    sql::T
end

sqliteprepare!(db,sql,stmt,null) = 
    @CHECK db sqlite3_prepare_v2(db.handle,utf8(sql),stmt,null)
sqliteprepare!(db::SQLiteDB{UTF16String},sql,stmt,null) = 
    @CHECK db sqlite3_prepare16_v2(db.handle,utf16(sql),stmt,null)

function SQLiteStmt{T}(db::SQLiteDB{T},sql::String)
    handle = [C_NULL]
    sqliteprepare!(db,sql,handle,[C_NULL])
    stmt = SQLiteStmt(db,handle[1],convert(T,sql))
    finalizer(stmt, close)
    return stmt
end

Base.close(stmt::SQLiteStmt) = @CHECK stmt.db sqlite3_finalize(stmt.handle)

# Binding parameters to SQL statements
function bind!(stmt::SQLiteStmt,name::String,val)
    i = sqlite3_bind_parameter_index(stmt.handle,name)
    if i == 0
        throw(SQLiteException("SQL parameter $name not found in $stmt"))
    end
    return bind!(stmt,i,val)
end
bind!(stmt::SQLiteStmt,i::Int,val::FloatingPoint) = @CHECK stmt.db sqlite3_bind_double(stmt.handle,i,float64(val))
bind!(stmt::SQLiteStmt,i::Int,val::Int32)         = @CHECK stmt.db sqlite3_bind_int(stmt.handle,i,val)
bind!(stmt::SQLiteStmt,i::Int,val::Int64)         = @CHECK stmt.db sqlite3_bind_int64(stmt.handle,i,val)
bind!(stmt::SQLiteStmt,i::Int,val::NullType)      = @CHECK stmt.db sqlite3_bind_null(stmt.handle,i)
bind!(stmt::SQLiteStmt,i::Int,val::String)        = @CHECK stmt.db sqlite3_bind_text(stmt.handle,i,val)
bind!(stmt::SQLiteStmt,i::Int,val::UTF16String)   = @CHECK stmt.db sqlite3_bind_text16(stmt.handle,i,val)
# Fallback is BLOB and defaults to serializing the julia value
function sqlserialize(x)
    t = IOBuffer()
    serialize(t,x)
    return takebuf_array(t)
end
bind!(stmt::SQLiteStmt,i::Int,val) = @CHECK stmt.db sqlite3_bind_blob(stmt.handle,i,sqlserialize(val))
#TODO:
 #int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
 #int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);

# Execute SQL statements
function execute!(stmt::SQLiteStmt)
    r = sqlite3_step(stmt.handle)
    if r == SQLITE_DONE || r == SQLITE_ROW
        return r
    elseif r == SQLITE_BUSY
        throw(SQLiteException("Unable to acquire database lock to execute! $stmt"))
    elseif r == SQLITE_ERROR
        sqliteerror(stmt.db)
    elseif r == SQLITE_MISUSE
        sqliteerror(stmt.db)
    end
end
execute!(db::SQLiteDB,sql::String) = (execute!(SQLiteStmt(db,sql)); nothing)

sqldeserialize(r) = deserialize(IOBuffer(r))

function query(db::SQLiteDB,sql::String)
    stmt = SQLiteStmt(db,sql)
    status = execute!(stmt)
    ncols = sqlite3_column_count(stmt.handle)
    if status == SQLITE_DONE || ncols == 0
        sqlite3_reset(stmt.handle)
        return String[], Any[]
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
    if status == SQLITE_DONE
        return colnames, hcat(results...)
    elseif status == SQLITE_BUSY
        throw(SQLiteException("Unable to acquire database lock to execute! $stmt"))
    elseif status == SQLITE_ERROR
        sqliteerror(stmt.db)
    elseif status == SQLITE_MISUSE
        sqliteerror(stmt.db)
    end
end

function tables(db::SQLiteDB)
    query(db,"SELECT name FROM sqlite_master WHERE type='table';")
end

function drop(db::SQLiteDB,table::String)
    execute!(db,"drop table $table")
    execute!(db,"vacuum")
end

gettype{T<:Integer}(::Type{T}) = " INT"
gettype{T<:Real}(::Type{T}) = " REAL"
gettype{T<:String}(::Type{T}) = " TEXT"
gettype(::Type) = " BLOB"
gettype(::Type{NullType}) = " NULL"

function create(db::SQLiteDB,name::String,table::AbstractMatrix,
            colnames=String[],coltypes=DataType[];temp::Bool=false)
    N, M = size(table)
    colnames = isempty(colnames) ? ["x$i" for i=1:M] : colnames
    coltypes = isempty(coltypes) ? [typeof(table[1,i]) for i=1:M] : coltypes
    length(colnames) == length(coltypes) || throw(SQLiteException("colnames and coltypes must have same length"))
    cols = [colnames[i] * gettype(coltypes[i]) for i = 1:M]
    execute!(db,"PRAGMA synchronous = OFF")
    execute!(db,"BEGIN")
    # create table statement
    t = temp ? "TEMP " : ""
    execute!(db,"CREATE $(t)TABLE $name ($(join(cols,',')))")
    # insert statements
    params = chop(repeat("?,",M))
    stmt = SQLiteStmt(db,"insert into $name values ($params)")
    #bind, step, reset loop for inserting values
    for row = 1:N
        for col = 1:M
            v = table[row,col]
            SQLite.bind!(stmt,col,v)
        end
        execute!(stmt)
        sqlite3_reset(stmt.handle)
    end
    execute!(db,"COMMIT")
    execute!(db,"PRAGMA synchronous = ON")
end

end #SQLite module