export NULL, SQLiteDB, SQLiteStmt, ResultSet,
       execute, query, tables, indices, columns, droptable, dropindex,
       create, createindex, append, deleteduplicates

gettype{T<:Integer}(::Type{T}) = " INT"
gettype{T<:AbstractFloat}(::Type{T}) = " REAL"
gettype{T<:AbstractString}(::Type{T}) = " TEXT"
gettype(::Type) = " BLOB"
gettype(::Type{NullType}) = " NULL"

type ResultSet
   colnames
   values::Vector{Any}
end
import Base.==
==(a::ResultSet,b::ResultSet) = a.colnames == b.colnames && a.values == b.values
include("show.jl")
Base.convert(::Type{Matrix},a::ResultSet) = [a[i,j] for i=1:size(a,1), j=1:size(a,2)]

function SQLiteDB(file::AbstractString="";UTF16::Bool=false)
    Base.depwarn("`SQLiteDB` is deprecated; please use `SQLite.DB` instead",:SQLiteDB)
    handle = [C_NULL]
    utf = UTF16 ? utf16 : utf8
    file = isempty(file) ? file : expanduser(file)
    if @OK sqliteopen(utf(file),handle)
        db = SQLiteDB(utf(file),handle[1])
        register(db, regexp, nargs=2, name="regexp")
        finalizer(db,close)
        return db
    else # error
        sqlite3_close(handle[1])
        sqliteerror()
    end
end

function changes(db::SQLiteDB)
    new_tot = sqlite3_total_changes(db.handle)
    diff = new_tot - db.changes
    db.changes = new_tot
    return ResultSet(["Rows Affected"],Any[Any[diff]])
end

function Base.close{T}(db::SQLiteDB{T})
    db.handle == C_NULL && return
    # ensure SQLiteStmts are finalised
    gc()
    @CHECK db sqlite3_close(db.handle)
    db.handle = C_NULL
    return
end

type SQLiteStmt{T}
    db::SQLiteDB{T}
    handle::Ptr{Void}
    sql::T
end

# sqliteprepare(db,sql,stmt,null) =
#     @CHECK db sqlite3_prepare_v2(db.handle,utf8(sql),stmt,null)
sqliteprepare(db::SQLiteDB{UTF16String},sql,stmt,null) =
    @CHECK db sqlite3_prepare16_v2(db.handle,utf16(sql),stmt,null)

function SQLiteStmt{T}(db::SQLiteDB{T},sql::AbstractString)
    Base.depwarn("`SQLiteStmt` is deprecated; please use `SQLite.Stmt` instead",:SQLiteStmt)
    handle = [C_NULL]
    sqliteprepare(db,sql,handle,[C_NULL])
    stmt = SQLiteStmt(db,handle[1],convert(T,sql))
    finalizer(stmt, close)
    return stmt
end

function Base.close(stmt::SQLiteStmt)
    stmt.handle == C_NULL && return
    @CHECK stmt.db sqlite3_finalize(stmt.handle)
    stmt.handle = C_NULL
    return
end

# bind a row to nameless parameters
function bind(stmt, values::Vector)
    nparams = sqlite3_bind_parameter_count(stmt.handle)
    @assert nparams == length(values) "you must provide values for all placeholders"
    for i in 1:nparams
        @inbounds bind(stmt, i, values[i])
    end
end
# bind a row to named parameters
function bind{V}(stmt, values::Dict{Symbol, V})
    nparams = sqlite3_bind_parameter_count(stmt.handle)
    @assert nparams == length(values) "you must provide values for all placeholders"
    for i in 1:nparams
        name = bytestring(sqlite3_bind_parameter_name(stmt.handle, i))
        @assert !isempty(name) "nameless parameters should be passed as a Vector"
        # name is returned with the ':', '@' or '$' at the start
        name = name[2:end]
        bind(stmt, i, values[symbol(name)])
    end
end
# Binding parameters to SQL statements
function bind(stmt,name::AbstractString,val)
    i = sqlite3_bind_parameter_index(stmt.handle,name)
    if i == 0
        throw(SQLiteException("SQL parameter $name not found in $stmt"))
    end
    return bind(stmt,i,val)
end
bind(stmt,i::Int,val::AbstractFloat)  = @CHECK stmt.db sqlite3_bind_double(stmt.handle,i,@compat Float64(val))
bind(stmt,i::Int,val::Int32)          = @CHECK stmt.db sqlite3_bind_int(stmt.handle,i,val)
bind(stmt,i::Int,val::Int64)          = @CHECK stmt.db sqlite3_bind_int64(stmt.handle,i,val)
bind(stmt,i::Int,val::NullType)       = @CHECK stmt.db sqlite3_bind_null(stmt.handle,i)
bind(stmt,i::Int,val::AbstractString) = @CHECK stmt.db sqlite3_bind_text(stmt.handle,i,val)
bind(stmt,i::Int,val::UTF16String)    = @CHECK stmt.db sqlite3_bind_text16(stmt.handle,i,val)
# We may want to track the new ByteVec type proposed at https://github.com/JuliaLang/julia/pull/8964
# as the "official" bytes type instead of Vector{UInt8}
bind(stmt,i::Int,val::Vector{UInt8})  = @CHECK stmt.db sqlite3_bind_blob(stmt.handle,i,val)
bind(stmt,i::Int,val) = bind(stmt,i,sqlserialize(val))

# Execute SQL statements
function execute(stmt)
    r = sqlite3_step(stmt.handle)
    if r == SQLITE_DONE
        sqlite3_reset(stmt.handle)
    elseif r != SQLITE_ROW
        sqliteerror(stmt.db)
    end
    return r
end
function execute(db::SQLiteDB,sql::AbstractString)
    stmt = SQLiteStmt(db,sql)
    execute(stmt)
    return changes(db)
end


function query(db::SQLiteDB,sql::AbstractString, values=[])
    stmt = SQLiteStmt(db,sql)
    bind(stmt, values)
    status = execute(stmt)
    ncols = sqlite3_column_count(stmt.handle)
    if status == SQLITE_DONE || ncols == 0
        return changes(db)
    end
    colnames = Array(AbstractString,ncols)
    results = Array(Any,ncols)
    for i = 1:ncols
        colnames[i] = bytestring(sqlite3_column_name(stmt.handle,i))
        results[i] = Any[]
    end
    while status == SQLITE_ROW
        for i = 1:ncols
            t = sqlite3_column_type(stmt.handle,i)
            if t == SQLITE_INTEGER
                r = sqlite3_column_int64(stmt.handle,i)
            elseif t == SQLITE_FLOAT
                r = sqlite3_column_double(stmt.handle,i)
            elseif t == SQLITE_TEXT
                #TODO: have a way to return text16?
                r = bytestring( sqlite3_column_text(stmt.handle,i) )
            elseif t == SQLITE_BLOB
                blob = sqlite3_column_blob(stmt.handle,i)
                b = sqlite3_column_bytes(stmt.handle,i)
                buf = zeros(UInt8,b)
                unsafe_copy!(pointer(buf), convert(Ptr{UInt8},blob), b)
                r = sqldeserialize(buf)
            else
                r = NULL
            end
            push!(results[i],r)
        end
        status = sqlite3_step(stmt.handle)
    end
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

columns(db::SQLiteDB,table::AbstractString) = query(db,"pragma table_info($table)")

function droptable(db::SQLiteDB,table::AbstractString;ifexists::Bool=false)
    exists = ifexists ? "if exists" : ""
    transaction(db) do
        execute(db,"drop table $exists $table")
    end
    execute(db,"vacuum")
    return changes(db)
end

function dropindex(db::SQLiteDB,index::AbstractString;ifexists::Bool=false)
    exists = ifexists ? "if exists" : ""
    transaction(db) do
        execute(db,"drop index $exists $index")
    end
    return changes(db)
end

function create(db::SQLiteDB,name::AbstractString,table,
            colnames=AbstractString[],
            coltypes=DataType[]
            ;temp::Bool=false,ifnotexists::Bool=false)
    N, M = size(table)
    colnames = isempty(colnames) ? ["x$i" for i=1:M] : colnames
    coltypes = isempty(coltypes) ? [typeof(table[1,i]) for i=1:M] : coltypes
    length(colnames) == length(coltypes) || throw(SQLiteException("colnames and coltypes must have same length"))
    cols = [colnames[i] * gettype(coltypes[i]) for i = 1:M]
    transaction(db) do
        # create table statement
        t = temp ? "TEMP " : ""
        exists = ifnotexists ? "if not exists" : ""
        execute(db,"CREATE $(t)TABLE $exists $name ($(join(cols,',')))")
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
    end
    execute(db,"analyze $name")
    return changes(db)
end

function createindex(db::SQLiteDB,table::AbstractString,index::AbstractString,cols
                    ;unique::Bool=true,ifnotexists::Bool=false)
    u = unique ? "unique" : ""
    exists = ifnotexists ? "if not exists" : ""
    transaction(db) do
        execute(db,"create $u index $exists $index on $table ($cols)")
    end
    execute(db,"analyze $index")
    return changes(db)
end

function append(db::SQLiteDB,name::AbstractString,table)
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
    end
    execute(db,"analyze $name")
    return return changes(db)
end

function deleteduplicates(db,table::AbstractString,cols::AbstractString)
    transaction(db) do
        execute(db,"delete from $table where rowid not in (select max(rowid) from $table group by $cols);")
    end
    execute(db,"analyze $table")
    return changes(db)
end

execute!(db::SQLiteDB, sql) = execute(db, sql)
