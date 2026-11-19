using Tables

sym(ptr) = ccall(:jl_symbol, Ref{Symbol}, (Ptr{UInt8},), ptr)

struct Query{strict} <: DBInterface.Cursor
    stmt::Stmt
    status::Base.RefValue{Cint}
    names::Vector{Symbol}
    types::Vector{Type}
    lookup::Dict{Symbol,Int}
    current_rownumber::Base.RefValue{Int} # -1 once the run ended or another query reran `stmt`
    params::DBInterface.StatementParams
end

# check if the query has no (more) rows
Base.isempty(q::Query) = q.status[] == C.SQLITE_DONE

struct Row{strict} <: Tables.AbstractRow
    q::Query{strict}
    rownumber::Int
end

getquery(r::Row) = getfield(r, :q)

Tables.isrowtable(::Type{<:Query}) = true
Tables.columnnames(q::Query) = q.names

struct DBTable
    name::String
    schema::Union{Tables.Schema,Nothing}
end

DBTable(name::String) = DBTable(name, nothing)

const DBTables = AbstractVector{DBTable}

Tables.istable(::Type{<:DBTables}) = true
Tables.rowaccess(::Type{<:DBTables}) = true
Tables.rows(dbtbl::DBTables) = dbtbl

function Tables.schema(q::Query{strict}) where {strict}
    if isempty(q) || strict
        # when the query is empty or types are strict, return the types provided by SQLite
        # by default SQLite.jl assumes all columns can have missing values
        Tables.Schema(Tables.columnnames(q), q.types)
    else
        return nothing # fallback to the actual column types of the result
    end
end

Base.IteratorSize(::Type{<:Query}) = Base.SizeUnknown()
Base.eltype(q::Query) = Row

function reset!(q::Query)
    q.status[] = execute(q.stmt, q.params)
    q.current_rownumber[] = 0
    q.stmt.cursor = q.current_rownumber
    return q.status[]
end

function DBInterface.close!(q::Query)
    # Once the run has ended, the statement may belong to a newer query.
    q.current_rownumber[] < 0 && return
    q.current_rownumber[] = -1
    Base.@lock q.stmt.db.lock C.sqlite3_reset(_get_stmt_handle(q.stmt))
    return
end

function done(q::Query)
    st = q.status[]
    if st == C.SQLITE_DONE
        DBInterface.close!(q)
        return true
    end
    st == C.SQLITE_ROW || sqliteerror(q.stmt.db)
    return false
end

@noinline function wrongrow(i)
    throw(
        ArgumentError(
            "row $i is no longer valid; sqlite query results are forward-only iterators where each row is only valid when iterated; re-execute the query, convert rows to NamedTuples, or stream the results to a sink to save results",
        ),
    )
end

@noinline function wrongquery()
    throw(
        ArgumentError(
            "query results are no longer valid; the query was closed or its statement was closed or executed again; re-execute the query",
        ),
    )
end

# The statement handle, if row `rownumber` is still the current row of `q`.
@inline function rowhandle(q::Query, rownumber::Int)
    handle = _get_stmt_handle(q.stmt)
    # Closing the database finalizes the handle without visiting its queries.
    (rownumber == q.current_rownumber[] && handle != C_NULL) || wrongrow(rownumber)
    return handle
end

function getvalue(
    q::Query{true},
    col::Int,
    rownumber::Int,
    ::Type{T},
)::Union{Missing,nonmissingtype(T)} where {T}
    handle = rowhandle(q, rownumber)
    t = C.sqlite3_column_type(handle, col - 1)
    if t == C.SQLITE_NULL
        return missing
    end
    S = nonmissingtype(T)
    # An `Any` column holds values of several storage classes; read each by its own.
    S === Any && return sqlitevalue(juliatype(t), handle, col)
    t == storageclass(S) && return sqlitevalue(S, handle, col)
    return convertexact(S, sqlitevalue(juliatype(t), handle, col), q, col, rownumber)
end

# The storage class of the values `sqlitevalue(T, ...)` reads without conversion
storageclass(::Type{Int64}) = C.SQLITE_INTEGER
storageclass(::Type{Float64}) = C.SQLITE_FLOAT
storageclass(::Type{String}) = C.SQLITE_TEXT
storageclass(::Type) = C.SQLITE_BLOB

# Outside STRICT tables any column can hold any storage class. A strict result converts
# such a value to the column type only when nothing changes, e.g. integer 3 in a NUMERIC column.
@noinline function convertexact(::Type{S}, v, q::Query, col::Int, rownumber::Int) where {S}
    v isa S && return v
    x = try
        convert(S, v)
    catch
        nothing
    end
    x !== nothing && x == v && return x
    throw(ArgumentError(
        "strict query column $(q.names[col]) has type $S, but row $rownumber holds a $(typeof(v)); use strict=false to read each value with its own type",
    ))
end

function getvalue(
    q::Query{false},
    col::Int,
    rownumber::Int,
    ::Type{T},
) where {T}
    handle = rowhandle(q, rownumber)
    t = C.sqlite3_column_type(handle, col - 1)
    # branch on the storage class so each read is a static call
    t == C.SQLITE_NULL && return missing
    t == C.SQLITE_INTEGER && return C.sqlite3_column_int64(handle, col - 1)
    t == C.SQLITE_FLOAT && return C.sqlite3_column_double(handle, col - 1)
    t == C.SQLITE_TEXT && return sqlitevalue(String, handle, col)
    return sqlitevalue(isbitstype(T) ? Any : T, handle, col)
end

function Tables.getcolumn(r::Row, ::Type{T}, i::Int, nm::Symbol) where {T}
    getvalue(getquery(r), i, getfield(r, :rownumber), T)
end

function Tables.getcolumn(r::Row, i::Int)
    q = getquery(r)
    T = q.types[i]
    n = getfield(r, :rownumber)
    # A call that dispatches on a runtime `Union` type searches the method cache for every value,
    # so the column types that declared types and raw BLOBs give get static calls.
    T === Union{Missing,Int64} && return getvalue(q, i, n, Union{Missing,Int64})
    T === Union{Missing,Float64} && return getvalue(q, i, n, Union{Missing,Float64})
    T === Union{Missing,String} && return getvalue(q, i, n, Union{Missing,String})
    T === Union{Missing,Vector{UInt8}} && return getvalue(q, i, n, Union{Missing,Vector{UInt8}})
    T === Any && return getvalue(q, i, n, Any)
    return getvalue(q, i, n, T)
end
# non-strict values don't depend on the column type; skip dispatching on it
Tables.getcolumn(r::Row{false}, i::Int) = getvalue(getquery(r), i, getfield(r, :rownumber), Any)
function Tables.getcolumn(r::Row, nm::Symbol)
    Tables.getcolumn(r, getquery(r).lookup[nm])
end
Tables.columnnames(r::Row) = Tables.columnnames(getquery(r))

function Base.iterate(q::Query)
    done(q) && return nothing
    q.current_rownumber[] < 0 && wrongquery()
    q.current_rownumber[] = 1
    return Row(q, 1), 2
end

@inline function Base.iterate(q::Query, rownumber)
    q.current_rownumber[] < 0 && wrongquery()
    q.status[] = Base.@lock q.stmt.db.lock C.sqlite3_step(_get_stmt_handle(q.stmt))
    done(q) && return nothing
    q.current_rownumber[] = rownumber
    return Row(q, rownumber), rownumber + 1
end

"Return the last row insert id from the executed statement"
DBInterface.lastrowid(q::Query) = C.sqlite3_last_insert_rowid(q.stmt.db.handle)

"""
    DBInterface.execute(db::SQLite.DB, sql::String, [params]; allowduplicates=false, strict=false)
    DBInterface.execute(stmt::SQLite.Stmt, [params]; allowduplicates=false, strict=false)

Bind any positional (`params` as `Vector` or `Tuple`) or named (`params` as `NamedTuple` or `Dict`) parameters to an SQL statement, given by `db` and `sql` or
as an already prepared statement `stmt`, execute the query and return an iterator of result rows.
Without `params`, keywords other than `allowduplicates` and `strict` are bound as named parameters.
The callback forms `DBInterface.execute(f, db, sql, ...)` and `DBInterface.execute(f, stmt, ...)` take the same keywords.

By default, a repeated column name gets a suffix (`a`, `a_1`, `a_2`); `allowduplicates=true` keeps the names as SQLite reports them.

Note that the returned result row iterator only supports a single-pass, forward-only iteration of the result rows.
A row is readable only while it is the current row: reading a row after the iterator moves past it, after the results
are closed, or after `stmt` is executed again or closed throws an `ArgumentError`.
Calling `SQLite.reset!(result)` will re-execute the query with its parameters and reset the iterator back to the beginning.

The resultset iterator supports the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface, so results can be collected in any Tables.jl-compatible sink,
like `DataFrame(results)`, `CSV.write("results.csv", results)`, etc.

Passing `strict=true` to `DBInterface.execute` will cause the resultset iterator to return values of the exact type specified by SQLite.
Outside STRICT tables a column can hold values of any type; such a value converts to the column type only when
the conversion is exact, like integer `3` in a `NUMERIC` column read as `3.0`, and otherwise reading it throws an `ArgumentError`.
While more type-stable, determining the exact types of the results can be more expensive as it will iterate through each column to find the first non-NULL value to determine the type.
"""
function DBInterface.execute(
    stmt::Stmt,
    params::DBInterface.StatementParams;
    allowduplicates::Bool = false,
    strict::Bool = false,
)
    status = execute(stmt, params)
    handle = _get_stmt_handle(stmt)
    cols = C.sqlite3_column_count(handle)
    header = Vector{Symbol}(undef, cols)
    types = Vector{Type}(undef, cols)
    for i in 1:cols
        nm = sym(C.sqlite3_column_name(handle, i - 1))
        if !allowduplicates && nm in view(header, 1:(i-1))
            j = 1
            newnm = Symbol(nm, :_, j)
            while newnm in view(header, 1:(i-1))
                j += 1
                newnm = Symbol(nm, :_, j)
            end
            nm = newnm
        end
        header[i] = nm
        type = Base.@lock stmt.db.lock juliatype(handle, i, strict && status == C.SQLITE_ROW)
        types[i] = Union{type,Missing}
    end
    stmt.cursor = Ref(0)
    return Query{strict}(
        stmt,
        Ref(status),
        header,
        types,
        Dict(x => i for (i, x) in enumerate(header)),
        stmt.cursor,
        params,
    )
end

# DBInterface's own connection and callback forms take no keywords, and its keyword-only
# forms bind every keyword as a parameter, so `strict` and `allowduplicates` need these.
function DBInterface.execute(db::DB, sql::AbstractString, params::DBInterface.StatementParams; kw...)
    stmt = DBInterface.prepare(db, sql)
    try
        return DBInterface.execute(stmt, params; kw...)
    catch
        DBInterface.close!(stmt)
        rethrow()
    end
end

function DBInterface.execute(f::Base.Callable, stmt::Stmt, params::DBInterface.StatementParams; kw...)
    q = DBInterface.execute(stmt, params; kw...)
    try
        return f(q)
    finally
        DBInterface.close!(q)
    end
end

function DBInterface.execute(f::Base.Callable, db::DB, sql::AbstractString, params::DBInterface.StatementParams; kw...)
    stmt = DBInterface.prepare(db, sql)
    try
        return DBInterface.execute(f, stmt, params; kw...)
    finally
        DBInterface.close!(stmt)
    end
end

DBInterface.execute(stmt::Stmt; allowduplicates::Bool = false, strict::Bool = false, params...) =
    DBInterface.execute(stmt, values(params); allowduplicates, strict)
DBInterface.execute(db::DB, sql::AbstractString; allowduplicates::Bool = false, strict::Bool = false, params...) =
    DBInterface.execute(db, sql, values(params); allowduplicates, strict)
DBInterface.execute(f::Base.Callable, stmt::Stmt; allowduplicates::Bool = false, strict::Bool = false, params...) =
    DBInterface.execute(f, stmt, values(params); allowduplicates, strict)
DBInterface.execute(f::Base.Callable, db::DB, sql::AbstractString; allowduplicates::Bool = false, strict::Bool = false, params...) =
    DBInterface.execute(f, db, sql, values(params); allowduplicates, strict)

"""
    SQLite.createtable!(db::SQLite.DB, table_name, schema::Tables.Schema; temp=false, ifnotexists=true, strict=false, primarykey=nothing)

Create a table in `db` with name `table_name`, according to `schema`, which is a set of column names and types, constructed like `Tables.Schema(names, types)`
where `names` can be a vector or tuple of String/Symbol column names, and `types` is a vector or tuple of sqlite-compatible types (`Int`, `Float64`, `String`, or unions of `Missing`).

If `temp=true`, the table will be created temporarily, which means it will be deleted when the `db` is closed.
If `ifnotexists=true`, no error will be thrown if the table already exists.
`primarykey` names the primary key column as a `Symbol` or `String`, or takes a vector of names for a composite key.
Names match columns ignoring case, as in SQLite, and a name that isn't in `schema` throws an `ArgumentError`.
Integer columns are declared `INTEGER`, so a single integer primary key column is SQLite's [rowid alias](https://www.sqlite.org/lang_createtable.html#rowid).
`strict=true` creates a [STRICT table](https://www.sqlite.org/stricttables.html); there, columns that would be declared `BLOB`, or that hold only `missing`, are declared `ANY`, so they keep each value's type.
"""
function createtable!(
    db::DB,
    name::AbstractString,
    ::Tables.Schema{names,types};
    temp::Bool = false,
    ifnotexists::Bool = true,
    strict::Bool = false,
    primarykey::Union{Nothing,Symbol,AbstractString,AbstractVector} = nothing,
) where {names,types}
    pk = primarykeynames(primarykey, names)
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    columns = [
        string(
            esc_id(String(names[i])),
            ' ',
            columntype(types !== nothing ? fieldtype(types, i) : Any, strict),
        ) for i in eachindex(names)
    ]
    isempty(pk) || push!(columns, "PRIMARY KEY ($(esc_id(pk)))")
    sql = "CREATE $temp TABLE $ifnotexists $(esc_id(string(name))) ($(join(columns, ','))) $(strict ? "STRICT" : "")"
    return execute(db, sql)
end

# STRICT tables have no NULL type, and a STRICT BLOB column rejects the numbers and text that
# `Missing`, `Any`, and `Union` columns hold; ANY stores each value as given, as BLOB affinity does.
columntype(T, strict::Bool) = strict ? replace(sqlitetype(T), r"^(BLOB|NULL)" => "ANY") : sqlitetype(T)

# `primarykey` as a vector of column names, each checked against the schema `names`
function primarykeynames(primarykey, names)
    primarykey === nothing && return String[]
    pk = primarykey isa Union{Symbol,AbstractString} ? [string(primarykey)] : string.(primarykey)
    lcnames = lowercase.(string.(names))
    for col in pk
        lowercase(col) in lcnames || throw(
            ArgumentError("primary key column $col is not in the table columns $(collect(string.(names)))"),
        )
    end
    return pk
end

# table info for load!():
# returns NamedTuple with columns information,
# or nothing if table does not exist
function tableinfo(db::DB, name::AbstractString)
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
end

"""
    source |> SQLite.load!(db::SQLite.DB, tablename::String; temp::Bool=false, ifnotexists::Bool=false, replace::Bool=false, on_conflict::Union{String, Nothing} = nothing, analyze::Bool=false, primarykey=nothing)
    SQLite.load!(source, db, tablename; temp=false, ifnotexists=false, replace::Bool=false, on_conflict::Union{String, Nothing} = nothing, analyze::Bool=false, primarykey=nothing)

Load a Tables.jl input `source` into an SQLite table that will be named `tablename` (will be auto-generated if not specified).
By default, rows are appended to an existing table. The source column names must
match the existing table, but their order may differ. Table constraints and the
selected conflict resolution algorithm still apply.
SQLite stores `NaN` as `NULL`, so a `NaN` reads back as `missing` from a nullable column.
In a `NOT NULL` column, such as the one `load!` creates for a float column whose type excludes
`Missing`, a `NaN` makes `load!` throw, unless a conflict resolution handles the `NULL`:
`on_conflict="IGNORE"` skips the row, and `"REPLACE"` stores the column's `DEFAULT` if it has one.

  * `temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
  * `ifnotexists` is passed to `createtable!` when creating a table. It does not prevent appending to an existing table.
  * `on_conflict=nothing` allows to specify an alternative [constraint conflict resolution algorithm](https://sqlite.org/lang_conflict.html): "ABORT", "FAIL", "IGNORE", "REPLACE", or "ROLLBACK".
  * `replace=false` controls whether an `INSERT INTO ...` statement is generated or a `REPLACE INTO ...`. This keyword argument exists for backward compatibility, and is overridden if an algorithm is selected using the `on_conflict` keyword.
  * `analyze=true` will execute `ANALYZE` at the end of the insert
  * `primarykey` is passed to `createtable!` when creating a table. If the table exists, it must name the table's primary key columns, in any order, or `load!` throws an `ArgumentError` before inserting any rows.

```jldoctest
julia> db = SQLite.DB();

julia> SQLite.load!((id = [1, 2],), db, "items");

julia> SQLite.load!((id = [3],), db, "items");

julia> Tuple(row.id for row in DBInterface.execute(db, "SELECT id FROM items ORDER BY id"))
(1, 2, 3)

julia> DBInterface.close!(db)
```
"""
function load! end

function load!(
    db::DB,
    name::AbstractString = "sqlitejl_" * Random.randstring(5);
    kwargs...,
)
    x -> load!(x, db, name; kwargs...)
end

function load!(
    itr,
    db::DB,
    name::AbstractString = "sqlitejl_" * Random.randstring(5);
    kwargs...,
)
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
            throw(
                SQLiteException(
                    "Duplicate case-insensitive column name $lcname detected. SQLite doesn't allow duplicate column names and treats them case insensitive",
                ),
            )
        end
        push!(checkednames, lcname)
    end
    return true
end

# check if schema names match column names in DB; SQLite compares column names ignoring case
function checknames(
    ::Tables.Schema{names},
    db_names::AbstractVector{String},
) where {names}
    if Set(lowercase.(string.(names))) != Set(lowercase.(db_names))
        throw(
            SQLiteException(
                "Error loading, column names from table $(collect(string.(names))) do not match database names $(db_names)",
            ),
        )
    end
    return true
end

# check that `pk` names the existing table's primary key columns, ignoring order and case
function checkprimarykey(pk::Vector{String}, db_tableinfo::NamedTuple)
    existing = [col for (col, k) in zip(db_tableinfo.name, db_tableinfo.pk) if k > 0]
    Set(lowercase.(pk)) == Set(lowercase.(existing)) || throw(
        ArgumentError("primarykey $pk doesn't match the existing table's primary key $existing"),
    )
    return true
end

function load!(
    sch::Tables.Schema,
    rows,
    db::DB,
    name::AbstractString,
    db_tableinfo::Union{NamedTuple,Nothing},
    row = nothing,
    st = nothing;
    temp::Bool = false,
    ifnotexists::Bool = false,
    strict::Bool = false,
    on_conflict::Union{String,Nothing} = nothing,
    replace::Bool = false,
    analyze::Bool = false,
    primarykey::Union{Nothing,Symbol,AbstractString,AbstractVector} = nothing,
)
    # check for case-insensitive duplicate column names (sqlite doesn't allow)
    checkdupnames(sch.names)
    pk = primarykeynames(primarykey, sch.names)
    # check if `rows` column names match the existing table, or create the new one
    if db_tableinfo !== nothing
        checknames(sch, db_tableinfo.name)
        isempty(pk) || checkprimarykey(pk, db_tableinfo)
    else
        createtable!(db, name, sch; temp = temp, ifnotexists = ifnotexists, strict = strict, primarykey = pk)
    end
    # build insert statement
    columns = join(esc_id.(string.(sch.names)), ",")
    params = chop(repeat("?,", length(sch.names)))
    kind =
        isnothing(on_conflict) ? (replace ? "REPLACE" : "INSERT") :
        "INSERT OR $on_conflict"
    stmt = Stmt(
        db,
        "$kind INTO $(esc_id(string(name))) ($columns) VALUES ($params)";
        register = false,
    )
    # start a transaction for inserting rows
    try
        DBInterface.transaction(db) do
            insertrows!(stmt, sch, rows, row, st)
        end
    finally
        _close_stmt!(stmt)
    end
    analyze && execute(db, "ANALYZE $(esc_id(name))")
    return name
end

# Insert each row of `rows` with `stmt`, starting at `row` and iteration state `st` if given.
# The loop sits outside the transaction closure, because a closure that reassigns `row` and `st` boxes them.
function insertrows!(stmt::Stmt, sch::Tables.Schema, rows, row, st)
    if row === nothing
        state = iterate(rows)
        state === nothing && return
        row, st = state
    end
    db = stmt.db
    handle = _get_stmt_handle(stmt)
    while true
        Tables.eachcolumn(sch, row) do val, col, _
            bind!(stmt, col, val)
        end
        r = Base.@lock db.lock GC.@preserve row C.sqlite3_step(handle)
        if r == C.SQLITE_DONE
            Base.@lock db.lock C.sqlite3_reset(handle)
        elseif r != C.SQLITE_ROW
            e = sqliteexception(db, stmt)
            Base.@lock db.lock C.sqlite3_reset(handle)
            throw(e)
        end
        state = iterate(rows, st)
        state === nothing && return
        row, st = state
    end
end

# unknown schema case
function load!(
    ::Nothing,
    rows,
    db::DB,
    name::AbstractString,
    db_tableinfo::Union{NamedTuple,Nothing};
    kwargs...,
)
    state = iterate(rows)
    state === nothing && return name
    row, st = state
    names = propertynames(row)
    sch = Tables.Schema(names, nothing)
    return load!(sch, rows, db, name, db_tableinfo, row, st; kwargs...)
end
