"""
    SQLite.esc_id(x::Union{AbstractString,Vector{AbstractString}})

Escape SQLite identifiers
(e.g. column, table or index names).
Can be either a string or a vector of strings
(note does not check for null characters).
A vector of identifiers will be separated by commas.

Example:

```julia
julia> using SQLite, DataFrames

julia> df = DataFrame(label=string.(rand("abcdefg", 10)), value=rand(10));

julia> db = SQLite.DB(mktemp()[1]);

julia> tbl |> SQLite.load!(db, "temp");

julia> DBInterface.execute(db,"SELECT * FROM temp WHERE label IN ('a','b','c')") |> DataFrame
4×2 DataFrame
│ Row │ label   │ value    │
│     │ String⍰ │ Float64⍰ │
├─────┼─────────┼──────────┤
│ 1   │ c       │ 0.603739 │
│ 2   │ c       │ 0.429831 │
│ 3   │ b       │ 0.799696 │
│ 4   │ a       │ 0.603586 │

julia> q = ['a','b','c'];

julia> DBInterface.execute(db,"SELECT * FROM temp WHERE label IN (\$(SQLite.esc_id(q)))") |> DataFrame
4×2 DataFrame
│ Row │ label   │ value    │
│     │ String⍰ │ Float64⍰ │
├─────┼─────────┼──────────┤
│ 1   │ c       │ 0.603739 │
│ 2   │ c       │ 0.429831 │
│ 3   │ b       │ 0.799696 │
│ 4   │ a       │ 0.603586 │
```
"""
function esc_id end

esc_id(x::AbstractString) = "\"" * replace(x, "\"" => "\"\"") * "\""
esc_id(X::AbstractVector{S}) where {S<:AbstractString} = join(map(esc_id, X), ',')

"""
    SQLite.drop!(db, table; ifexists::Bool=true)

drop the SQLite table `table` from the database `db`; `ifexists=true` will prevent an error being thrown if `table` doesn't exist
"""
function drop!(db::DB, table::AbstractString; ifexists::Bool=false)
    exists = ifexists ? "IF EXISTS" : ""
    transaction(db) do
        direct_execute(db, "DROP TABLE $exists $(esc_id(table))")
    end
    direct_execute(db, "VACUUM")
    return
end

"""
    SQLite.removeduplicates!(db, table, cols)

Removes duplicate rows from `table` based on the values in `cols`, which is an array of column names.

A convenience method for the common task of removing duplicate
rows in a dataset according to some subset of columns that make up a "primary key".
"""
function removeduplicates!(db::DB, table::AbstractString, cols::AbstractArray{T}) where {T<:AbstractString}
    colsstr = ""
    for c in cols
        colsstr = colsstr * esc_id(c) * ","
    end
    colsstr = chop(colsstr)
    transaction(db) do
        direct_execute(db, "DELETE FROM $(esc_id(table)) WHERE _ROWID_ NOT IN (SELECT max(_ROWID_) from $(esc_id(table)) GROUP BY $(colsstr));")
    end
    direct_execute(db, "ANALYZE $table")
    return
end

"""
    SQLite.createtable!(db::SQLite.DB, table_name, schema::Tables.Schema; temp=false, ifnotexists=true)

Create a table in `db` with name `table_name`, according to `schema`, which is a set of column names and types, constructed like `Tables.Schema(names, types)`
where `names` can be a vector or tuple of String/Symbol column names, and `types` is a vector or tuple of sqlite-compatible types (`Int`, `Float64`, `String`, or unions of `Missing`).

If `temp=true`, the table will be created temporarily, which means it will be deleted when the `db` is closed.
If `ifnotexists=true`, no error will be thrown if the table already exists.
"""
function createtable!(db::DB, name::AbstractString, ::Tables.Schema{names,types};
    temp::Bool=false, ifnotexists::Bool=true) where {names,types}
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    columns = [string(esc_id(String(names[i])), ' ',
        sqlitetype(types !== nothing ? fieldtype(types, i) : Any))
               for i in eachindex(names)]
    sql = "CREATE $temp TABLE $ifnotexists $(esc_id(string(name))) ($(join(columns, ',')))"
    return direct_execute(db, sql)
end

# table info for load!():
# returns NamedTuple with columns information,
# or nothing if table does not exist
tableinfo(db::DB, name::AbstractString) =
    DBInterface.execute(db, "pragma table_info($(esc_id(name)))") do query
        st = query.status[]
        if st == C.SQLITE_ROW
            return Tables.columntable(query)
        elseif st == C.SQLITE_DONE
            return nothing
        else
            sqliteerror(query.stmt.db)
        end
    end

"""
    source |> SQLite.load!(db::SQLite.DB, tablename::String; temp::Bool=false, ifnotexists::Bool=false, replace::Bool=false, analyze::Bool=false)
    SQLite.load!(source, db, tablename; temp=false, ifnotexists=false, replace::Bool=false, analyze::Bool=false)

Load a Tables.jl input `source` into an SQLite table that will be named `tablename` (will be auto-generated if not specified).

  * `temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
  * `ifnotexists=false` will throw an error if `tablename` already exists in `db`
  * `replace=false` controls whether an `INSERT INTO ...` statement is generated or a `REPLACE INTO ...`
  * `analyze=true` will execute `ANALYZE` at the end of the insert
"""
function load! end

load!(db::DB, name::AbstractString="sqlitejl_" * Random.randstring(5); kwargs...) =
    x -> load!(x, db, name; kwargs...)

function load!(itr, db::DB, name::AbstractString="sqlitejl_" * Random.randstring(5); kwargs...)
    # check if table exists
    db_tableinfo = tableinfo(db, name)
    rows = Tables.rows(itr)
    sch = Tables.schema(rows)
    return load!(sch, rows, db, name, db_tableinfo; kwargs...)
end

# case-insensitive check for duplicate column names
function checkdupnames(names::Union{AbstractVector,Tuple})
    checkednames = Set{String}()
    for name in names
        lcname = lowercase(string(name))
        if lcname in checkednames
            throw(SQLiteException("Duplicate case-insensitive column name $lcname detected. SQLite doesn't allow duplicate column names and treats them case insensitive"))
        end
        push!(checkednames, lcname)
    end
    return true
end

# check if schema names match column names in DB
function checknames(::Tables.Schema{names}, db_names::AbstractVector{String}) where {names}
    table_names = Set(string.(names))
    db_names = Set(db_names)

    if table_names != db_names
        throw(SQLiteException("Error loading, column names from table $(collect(table_names)) do not match database names $(collect(db_names))"))
    end
    return true
end

function load!(sch::Tables.Schema, rows, db::DB, name::AbstractString, db_tableinfo::Union{NamedTuple,Nothing}, row=nothing, st=nothing;
    temp::Bool=false, ifnotexists::Bool=false, replace::Bool=false, analyze::Bool=false)
    # check for case-insensitive duplicate column names (sqlite doesn't allow)
    checkdupnames(sch.names)
    # check if `rows` column names match the existing table, or create the new one
    if db_tableinfo !== nothing
        checknames(sch, db_tableinfo.name)
    else
        createtable!(db, name, sch; temp=temp, ifnotexists=ifnotexists)
    end
    # build insert statement
    columns = join(esc_id.(string.(sch.names)), ",")
    params = chop(repeat("?,", length(sch.names)))
    kind = replace ? "REPLACE" : "INSERT"
    stmt = Stmt(db, "$kind INTO $(esc_id(string(name))) ($columns) VALUES ($params)"; register=false)
    handle = _get_stmt_handle(stmt)
    # start a transaction for inserting rows
    DBInterface.transaction(db) do
        if row === nothing
            state = iterate(rows)
            state === nothing && return
            row, st = state
        end
        while true
            Tables.eachcolumn(sch, row) do val, col, _
                bind!(stmt, col, val)
            end
            r = C.sqlite3_step(handle)
            if r == C.SQLITE_DONE
                C.sqlite3_reset(handle)
            elseif r != C.SQLITE_ROW
                e = sqliteexception(db, stmt)
                C.sqlite3_reset(handle)
                throw(e)
            end
            state = iterate(rows, st)
            state === nothing && break
            row, st = state
        end
    end
    _close_stmt!(stmt)
    analyze && direct_execute(db, "ANALYZE $name")
    return name
end

# unknown schema case
function load!(::Nothing, rows, db::DB, name::AbstractString,
    db_tableinfo::Union{NamedTuple,Nothing}; kwargs...)
    state = iterate(rows)
    state === nothing && return name
    row, st = state
    names = propertynames(row)
    sch = Tables.Schema(names, nothing)
    return load!(sch, rows, db, name, db_tableinfo, row, st; kwargs...)
end
