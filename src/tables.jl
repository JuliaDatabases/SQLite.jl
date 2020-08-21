using Tables

sym(ptr) = ccall(:jl_symbol, Ref{Symbol}, (Ptr{UInt8},), ptr)

struct Query
    stmt::Stmt
    status::Base.RefValue{Cint}
    names::Vector{Symbol}
    types::Vector{Type}
    lookup::Dict{Symbol, Int}
end

struct Row <: Tables.AbstractRow
    q::Query
end

getquery(r::Row) = getfield(r, :q)

Tables.isrowtable(::Type{Query}) = true

Base.IteratorSize(::Type{Query}) = Base.SizeUnknown()
Base.eltype(q::Query) = Row

function reset!(q::Query)
    sqlite3_reset(q.stmt.handle)
    q.status[] = execute(q.stmt)
    return
end

function done(q::Query)
    st = q.status[]
    if st == SQLITE_DONE
        sqlite3_reset(q.stmt.handle)
        return true
    end
    st == SQLITE_ROW || sqliteerror(q.stmt.db)
    return false
end

function getvalue(q::Query, col::Int, ::Type{T}) where {T}
    handle = q.stmt.handle
    t = sqlite3_column_type(handle, col)
    if t == SQLITE_NULL
        return missing
    else
        TT = juliatype(t) # native SQLite Int, Float, and Text types
        return sqlitevalue(ifelse(TT === Any && !isbitstype(T), T, TT), handle, col)
    end
end

Tables.getcolumn(r::Row, ::Type{T}, i::Int, nm::Symbol) where {T} = getvalue(getquery(r), i, T)

Tables.getcolumn(r::Row, i::Int) = Tables.getcolumn(r, getquery(r).types[i], i, getquery(r).names[i])
Tables.getcolumn(r::Row, nm::Symbol) = Tables.getcolumn(r, getquery(r).lookup[nm])
Tables.columnnames(r::Row) = getquery(r).names

function Base.iterate(q::Query)
    done(q) && return nothing
    return Row(q), nothing
end

function Base.iterate(q::Query, ::Nothing)
    q.status[] = sqlite3_step(q.stmt.handle)
    done(q) && return nothing
    return Row(q), nothing
end

"Return the last row insert id from the executed statement"
DBInterface.lastrowid(q::Query) = last_insert_rowid(q.stmt.db)

"""
    DBInterface.prepare(db::SQLite.DB, sql::AbstractString)

Prepare an SQL statement given as a string in the sqlite database; returns an `SQLite.Stmt` compiled object.
See `DBInterface.execute`(@ref) for information on executing a prepared statement and passing parameters to bind.
A `SQLite.Stmt` object can be closed (resources freed) using `DBInterface.close!`(@ref).
"""
DBInterface.prepare(db::DB, sql::AbstractString) = Stmt(db, sql)

"""
    DBInterface.execute(db::SQLite.DB, sql::String, [params])
    DBInterface.execute(stmt::SQLite.Stmt, [params])

Bind any positional (`params` as `Vector` or `Tuple`) or named (`params` as `NamedTuple` or `Dict`) parameters to an SQL statement, given by `db` and `sql` or
as an already prepared statement `stmt`, execute the query and return an iterator of result rows.

Note that the returned result row iterator only supports a single-pass, forward-only iteration of the result rows.
Calling `SQLite.reset!(result)` will re-execute the query and reset the iterator back to the beginning.

The resultset iterator supports the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface, so results can be collected in any Tables.jl-compatible sink,
like `DataFrame(results)`, `CSV.write("results.csv", results)`, etc.
"""
function DBInterface.execute(stmt::Stmt, params=())
    status = execute(stmt, params)
    cols = sqlite3_column_count(stmt.handle)
    header = Vector{Symbol}(undef, cols)
    types = Vector{Type}(undef, cols)
    for i = 1:cols
        header[i] = sym(sqlite3_column_name(stmt.handle, i))
        types[i] = Union{juliatype(stmt.handle, i), Missing}
    end
    return Query(stmt, Ref(status), header, types, Dict(x=>i for (i, x) in enumerate(header)))
end

"""
    SQLite.createtable!(db::SQLite.DB, table_name, schema::Tables.Schema; temp=false, ifnotexists=true)

Create a table in `db` with name `table_name`, according to `schema`, which is a set of column names and types, constructed like `Tables.Schema(names, types)`
where `names` can be a vector or tuple of String/Symbol column names, and `types` is a vector or tuple of sqlite-compatible types (`Int`, `Float64`, `String`, or unions of `Missing`).

If `temp=true`, the table will be created temporarily, which means it will be deleted when the `db` is closed.
If `ifnotexists=true`, no error will be thrown if the table already exists.
"""
function createtable!(db::DB, nm::AbstractString, ::Tables.Schema{names, types}; temp::Bool=false, ifnotexists::Bool=true) where {names, types}
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    typs = [types === nothing ? "BLOB" : sqlitetype(fieldtype(types, i)) for i = 1:length(names)]
    columns = [string(esc_id(String(names[i])), ' ', typs[i]) for i = 1:length(names)]
    return execute(db, "CREATE $temp TABLE $ifnotexists $nm ($(join(columns, ',')))")
end

struct TableInfo
    exists::Bool
    names::Vector{String}
end
function tableinfo(db::DB, name::AbstractString)
    table_info = Tables.columntable(DBInterface.execute(db, "pragma table_info($name)"))
    exists = table_info !== NamedTuple()
    if exists
        return TableInfo(exists, table_info.name)
    else
        return TableInfo(exists, String[])
    end
end

"""
    source |> SQLite.load!(db::SQLite.DB, tablename::String; temp::Bool=false, ifnotexists::Bool=false, analyze::Bool=false)
    SQLite.load!(source, db, tablename; temp=false, ifnotexists=false, analyze::Bool=false)

Load a Tables.jl input `source` into an SQLite table that will be named `tablename` (will be auto-generated if not specified).

`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `tablename` already exists in `db`
`analyze=true` will execute `ANALYZE` at the end of the insert
"""
function load! end

load!(db::DB, table::AbstractString="sqlitejl_"*Random.randstring(5); kwargs...) = x->load!(x, db, table; kwargs...)

function load!(itr, db::DB, name::AbstractString="sqlitejl_"*Random.randstring(5); kwargs...)
    # check if table exists
    nm = esc_id(name)
    db_tableinfo = tableinfo(db, nm)
    rows = Tables.rows(itr)
    sch = Tables.schema(rows)
    return load!(sch, rows, db, nm, name, db_tableinfo; kwargs...)
end

checkdupnames(names) = length(unique(map(x->lowercase(String(x)), names))) == length(names) || error("duplicate case-insensitive column names detected; sqlite doesn't allow duplicate column names and treats them case insensitive")

function checknames(::Tables.Schema{names}, db_names::Vector{String}) where {names}
    table_names = Set(string.(names))
    db_names = Set(db_names)

    if table_names != db_names
        error("Error loading, column names from table $(collect(table_names)) do not match database names $(collect(db_names))")
    end
end

function load!(sch::Tables.Schema, rows, db::DB, nm::AbstractString, name, db_tableinfo::TableInfo; temp::Bool=false, ifnotexists::Bool=false, analyze::Bool=false)
    # check for case-insensitive duplicate column names (sqlite doesn't allow)
    checkdupnames(sch.names)
    # create table if needed
    if db_tableinfo.exists
        checknames(sch, db_tableinfo.names)
    else
        createtable!(db, nm, sch; temp=temp, ifnotexists=ifnotexists)
    end
    # build insert statement
    columns = join(sch.names, ",")
    params = chop(repeat("?,", length(sch.names)))
    stmt = Stmt(db, "INSERT INTO $nm ($columns) VALUES ($params)")
    # start a transaction for inserting rows
    transaction(db) do
        for row in rows
            Tables.eachcolumn(sch, row) do val, col, _
                bind!(stmt, col, val)
            end
            sqlite3_step(stmt.handle)
            sqlite3_reset(stmt.handle)
        end
    end
    analyze && execute(db, "ANALYZE $nm")
    return name
end

# unknown schema case
function load!(::Nothing, rows, db::DB, nm::AbstractString, name, db_tableinfo::TableInfo; temp::Bool=false, ifnotexists::Bool=false, analyze::Bool=false)
    state = iterate(rows)
    state === nothing && return nm
    row, st = state
    names = propertynames(row)
    sch = Tables.Schema(names, nothing)
    checkdupnames(sch.names)
    # create table if needed
    if db_tableinfo.exists
        checknames(sch, db_tableinfo.names)
    else
        createtable!(db, nm, sch; temp=temp, ifnotexists=ifnotexists)
    end
    # build insert statement
    params = chop(repeat("?,", length(names)))
    columns = join(sch.names, ",")
    stmt = Stmt(db, "INSERT INTO $nm ($columns) VALUES ($params)")
    # start a transaction for inserting rows
    transaction(db) do
        while true
            Tables.eachcolumn(sch, row) do val, col, _
                bind!(stmt, col, val)
            end
            sqlite3_step(stmt.handle)
            sqlite3_reset(stmt.handle)
            state = iterate(rows, st)
            state === nothing && break
            row, st = state
        end
    end
    analyze && execute(db, "ANALYZE $nm")

    return name
end
