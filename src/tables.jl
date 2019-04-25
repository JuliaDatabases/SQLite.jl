using Tables

sym(ptr) = ccall(:jl_symbol, Ref{Symbol}, (Ptr{UInt8},), ptr)

struct Query{NT}
    stmt::Stmt
    status::Base.RefValue{Cint}
end

Tables.istable(::Type{<:Query}) = true
Tables.rowaccess(::Type{<:Query}) = true
Tables.rows(q::Query) = q
Tables.schema(q::Query{NamedTuple{names, types}}) where {names, types} = Tables.Schema(names, types)

Base.IteratorSize(::Type{<:Query}) = Base.SizeUnknown()
Base.eltype(q::Query{NT}) where {NT} = NT

function reset!(q::Query)
    sqlite3_reset(q.stmt.handle)
    q.status[] = execute!(q.stmt)
    return
end

function done(q::Query)
    st = q.status[]
    st == SQLITE_DONE && return true
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

function generate_namedtuple(::Type{NamedTuple{names, types}}, q) where {names, types}
    if @generated
        vals = Tuple(:(getvalue(q, $i, $(fieldtype(types, i)))) for i = 1:fieldcount(types))
        return :(NamedTuple{names, types}(($(vals...),)))
    else
        return NamedTuple{names, types}(Tuple(getvalue(q, i, fieldtype(types, i)) for i = 1:fieldcount(types)))
    end
end

function Base.iterate(q::Query{NT}) where {NT}
    done(q) && return nothing
    nt = generate_namedtuple(NT, q)
    return nt, nothing
end

function Base.iterate(q::Query{NT}, ::Nothing) where {NT}
    q.status[] = sqlite3_step(q.stmt.handle)
    done(q) && return nothing
    nt = generate_namedtuple(NT, q)
    return nt, nothing
end

"""
`SQLite.Query(db, sql::String; values=[]; stricttypes::Bool=true, nullable::Bool=true)`

Constructs a `SQLite.Query` object by executing the SQL query `sql` against the sqlite database `db` and querying
the columns names and types of the result set, if any.

Will bind `values` to any parameters in `sql`.
`stricttypes=false` will remove strict column typing in the result set, making each column effectively `Vector{Any}`; in sqlite, individual
column values are only loosely associated with declared column types, and instead each carry their own type information. This can lead to
type errors when trying to query columns when a single type is expected.
`nullable` controls whether `null` (`missing` in Julia) values are expected in a column.

An `SQLite.Query` object will iterate NamedTuple rows by default, and also supports the Tables.jl interface for integrating with
any other Tables.jl implementation. Due note however that iterating an sqlite result set is a forward-once-only operation. If you need
to iterate over an `SQLite.Query` multiple times, but can't store the iterated NamedTuples, call `SQLite.reset!(q::SQLite.Query)` to
re-execute the query and position the iterator back at the begining of the result set.
"""
function Query(db::DB, sql::AbstractString; values=[], stricttypes::Bool=true, nullable::Bool=true)
    stmt = Stmt(db, sql)
    bind!(stmt, values)
    status = execute!(stmt)
    cols = sqlite3_column_count(stmt.handle)
    header = Vector{Symbol}(undef, cols)
    types = Vector{Type}(undef, cols)
    for i = 1:cols
        header[i] = sym(sqlite3_column_name(stmt.handle, i))
        if nullable
            types[i] = stricttypes ? Union{juliatype(stmt.handle, i), Missing} : Any
        else
            types[i] = stricttypes ? juliatype(stmt.handle, i) : Any
        end
    end
    return Query{NamedTuple{Tuple(header), Tuple{types...}}}(stmt, Ref(status))
end

# as a sink
function createtable!(db::DB, nm::AbstractString, ::Tables.Schema{names, types}; temp::Bool=false, ifnotexists::Bool=true) where {names, types}
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    typs = [types === nothing ? "BLOB" : sqlitetype(fieldtype(types, i)) for i = 1:length(names)]
    columns = [string(esc_id(String(names[i])), ' ', typs[i]) for i = 1:length(names)]
    return execute!(db, "CREATE $temp TABLE $ifnotexists $nm ($(join(columns, ',')))")
end

"""
    source |> SQLite.load!(db::SQLite.DB, tablename::String; temp::Bool=false, ifnotexists::Bool=false)
    SQLite.load!(source, db, tablename; temp=false, ifnotexists=false)

Load a Tables.jl input `source` into an SQLite table that will be named `tablename` (will be auto-generated if not specified).

`temp=true` will create a temporary SQLite table that will be destroyed automatically when the database is closed
`ifnotexists=false` will throw an error if `tablename` already exists in `db`
"""
function load! end

load!(db::DB, table::AbstractString="sqlitejl_"*Random.randstring(5); kwargs...) = x->load!(x, db, table; kwargs...)

function load!(itr, db::DB, name::AbstractString="sqlitejl_"*Random.randstring(5); kwargs...)
    # check if table exists
    nm = esc_id(name)
    checkstmt = Stmt(db, "pragma table_info($nm)")
    status = execute!(checkstmt)
    rows = Tables.rows(itr)
    sch = Tables.schema(rows)
    return load!(sch, rows, db, nm, name, status == SQLITE_DONE; kwargs...)
end

function load!(sch::Tables.Schema, rows, db::DB, nm::AbstractString, name, shouldcreate; temp::Bool=false, ifnotexists::Bool=false)
    # create table if needed
    shouldcreate && createtable!(db, nm, sch; temp=temp, ifnotexists=ifnotexists)
    # build insert statement
    params = chop(repeat("?,", length(sch.names)))
    stmt = Stmt(db, "INSERT INTO $nm VALUES ($params)")
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
    execute!(db, "ANALYZE $nm")
    return name
end

# unknown schema case
function load!(::Nothing, rows, db::DB, nm::AbstractString, name, shouldcreate; temp::Bool=false, ifnotexists::Bool=false)
    state = iterate(rows)
    state === nothing && return nm
    row, st = state
    names = propertynames(row)
    sch = Tables.Schema(names, nothing)
    # create table if needed
    shouldcreate && createtable!(db, nm, sch; temp=temp, ifnotexists=ifnotexists)
    # build insert statement
    params = chop(repeat("?,", length(names)))
    stmt = Stmt(db, "INSERT INTO $nm VALUES ($params)")
    # start a transaction for inserting rows
    transaction(db) do
        while true
            Tables.eachcolumn(sch, row) do val, col, _
                bind!(stmt, col, val)
            end
            sqlite3_step(stmt.handle)
            sqlite3_reset(stmt.handle)
            state = iterate(rows)
            state === nothing && break
            row, st = state
        end
    end
    execute!(db, "ANALYZE $nm")
    return name
end