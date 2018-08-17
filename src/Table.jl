using Tables

sym(ptr) = ccall(:jl_symbol, Ref{Symbol}, (Ptr{UInt8},), ptr)

struct Row{T}
    table::T
end

struct Query{NT}
    stmt::Stmt
    status::Base.RefValue{Cint}
    transaction::String
end

Base.eltype(f::T) where {T <: Query} = Row{T}
Tables.schema(f::Query{NT}) where {NT} = NT
Base.IteratorSize(::Type{T}) where {T <: Query} = Base.SizeUnknown()

function Base.iterate(t::Query{NT}) where {NT}
    st = t.status[]
    st == SQLITE_DONE && return nothing
    st == SQLITE_ROW || sqliteerror(t.stmt.db)
    return Row(t), nothing
end

function Base.iterate(t::Query{NT}, ::Nothing) where {NT}
    st = sqlite3_step(t.stmt.handle)
    st == SQLITE_DONE && return nothing
    st == SQLITE_ROW || sqliteerror(t.stmt.db)
    return Row(t), nothing
end

@inline function Base.getproperty(row::Row{Query{NT}}, name::Symbol) where {NT}
    table = getfield(row, 1)
    handle = table.stmt.handle
    col, T = Tables.columnindextype(NT, name)
    t = sqlite3_column_type(handle, col)
    if t == SQLITE_NULL
        return missing
    else
        TT = juliatype(t) # native SQLite Int, Float, and Text types
        return sqlitevalue(ifelse(TT === Any && !isbitstype(T), T, TT), handle, col)
    end
end

# as a source
function Query(db::DB, sql::AbstractString, values=[]; stricttypes::Bool=true, nullable::Bool=true)
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
    return Query{NamedTuple{Tuple(header), Tuple{types...}}}(stmt, Ref(status), "")
end

# as a sink
function createtable!(db::DB, nm::AbstractString, ::Type{NamedTuple{names, types}}; temp::Bool=false, ifnotexists::Bool=true) where {names, types}
    temp = temp ? "TEMP" : ""
    ifnotexists = ifnotexists ? "IF NOT EXISTS" : ""
    columns = [string(esc_id(String(names[i])), ' ', sqlitetype(types.parameters[i])) for i = 1:length(names)]
    return execute!(db, "CREATE $temp TABLE $ifnotexists $nm ($(join(columns, ',')))")
end

load!(db::DB, table::AbstractString="sqlitejl_"*Random.randstring(5); kwargs...) = x->load!(x, db, table; kwargs...)

function load!(itr, db::DB, name::AbstractString, temp::Bool=false, ifnotexists::Bool=false)
    # check if table exists
    nm = esc_id(name)
    checkstmt = Stmt(db, "pragma table_info($nm)")
    execute!(checkstmt)
    sch = Tables.schema(itr)
    # create table if needed
    sqlite3_column_count(checkstmt.handle) == 0 && createtable!(db, nm, sch; temp=temp, ifnotexists=ifnotexists)
    # build insert statement
    params = chop(repeat("?,", length(Tables.names(sch))))
    stmt = Stmt(db, "INSERT INTO $nm VALUES ($params)")
    # start a transaction for inserting rows
    transaction(db) do
        for row in Tables.rows(itr)
            Tables.unroll(sch, row) do col, val
                bind!(stmt, col, val)
            end
            sqlite3_step(stmt.handle)
            sqlite3_reset(stmt.handle)
        end
    end
    execute!(db, "ANALYZE $nm")
    return
end

