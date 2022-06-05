"""
    SQLite.direct_execute(db::SQLite.DB, sql::AbstractString, [params]) -> Int
    SQLite.direct_execute(stmt::SQLite.Stmt, [params]) -> Int

An internal method that executes the SQL statement (provided either as a `db` connection and `sql` command,
or as an already prepared `stmt` (see [`SQLite.Stmt`](@ref))) with given `params` parameters
(either positional (`Vector` or `Tuple`), named (`Dict` or `NamedTuple`), or specified as keyword arguments).

Returns the SQLite status code of operation.

*Note*: this is a low-level method that just executes the SQL statement,
but does not retrieve any data from `db`.
To get the results of a SQL query, it is recommended to use [`DBInterface.execute`](@ref).
"""
function direct_execute end

function direct_execute(db::DB, stmt::Stmt, params::DBInterface.StatementParams=())
    handle = _get_stmt_handle(stmt)
    C.sqlite3_reset(handle)
    bind!(stmt, params)
    r = C.sqlite3_step(handle)
    if r == C.SQLITE_DONE
        C.sqlite3_reset(handle)
    elseif r != C.SQLITE_ROW
        e = sqliteexception(db)
        C.sqlite3_reset(handle)
        throw(e)
    end
    return r
end

direct_execute(stmt::Stmt, params::DBInterface.StatementParams=()) = direct_execute(stmt.db, stmt, params)

direct_execute(stmt::Stmt; kwargs...) = direct_execute(stmt.db, stmt, NamedTuple(kwargs))

function direct_execute(db::DB, sql::AbstractString, params::DBInterface.StatementParams=())
    # prepare without registering Stmt in DB
    stmt = Stmt(db, sql; register = false)
    try
        return direct_execute(db, stmt, params)
    finally
        _close_stmt!(stmt) # immediately close, don't wait for GC
    end
end

direct_execute(db::DB, sql::AbstractString; kwargs...) = direct_execute(db, sql, NamedTuple(kwargs))

"""
APIs to acquire data from the database.
"""

sym(ptr) = ccall(:jl_symbol, Ref{Symbol}, (Ptr{UInt8},), ptr)

struct Query
    stmt::Stmt
    status::Base.RefValue{Cint}
    names::Vector{Symbol}
    types::Vector{Type}
    lookup::Dict{Symbol,Int}
    current_rownumber::Base.RefValue{Int}
end

# check if the query has no (more) rows
Base.isempty(q::Query) = q.status[] == C.SQLITE_DONE

struct Row <: Tables.AbstractRow
    q::Query
    rownumber::Int
end

getquery(r::Row) = getfield(r, :q)

Tables.isrowtable(::Type{Query}) = true
Tables.columnnames(q::Query) = q.names

function Tables.schema(q::Query)
    if isempty(q)
        # when the query is empty, return the types provided by SQLite
        # by default SQLite.jl assumes all columns can have missing values
        Tables.Schema(Tables.columnnames(q), q.types)
    else
        return nothing # fallback to the actual column types of the result
    end
end

Base.IteratorSize(::Type{Query}) = Base.SizeUnknown()
Base.eltype(::Query) = Row

function reset!(q::Query)
    C.sqlite3_reset(_get_stmt_handle(q.stmt))
    q.status[] = direct_execute(q.stmt)
    return
end

function DBInterface.close!(q::Query)
   C.sqlite3_reset(_get_stmt_handle(q.stmt))
end

function done(q::Query)
    st = q.status[]
    if st == C.SQLITE_DONE
        C.sqlite3_reset(_get_stmt_handle(q.stmt))
        return true
    end
    st == C.SQLITE_ROW || sqliteerror(q.stmt.db)
    return false
end

@noinline wrongrow(i) = throw(
    ArgumentError(
        "row $i is no longer valid; sqlite query results are forward-only iterators where each row is only valid when iterated; re-execute the query, convert rows to NamedTuples, or stream the results to a sink to save results",
    ),
)

function getvalue(q::Query, col::Int, rownumber::Int, ::Type{T}) where {T}
    rownumber == q.current_rownumber[] || wrongrow(rownumber)
    handle = _get_stmt_handle(q.stmt)
    t = C.sqlite3_column_type(handle, col-1)
    if t == C.SQLITE_NULL
        return missing
    else
        TT = juliatype(t) # native SQLite Int, Float, and Text types
        return sqlitevalue(ifelse(TT === Any && !isbitstype(T), T, TT), handle, col)
    end
end

Tables.getcolumn(r::Row, ::Type{T}, i::Int, nm::Symbol) where {T} =
    getvalue(getquery(r), i, getfield(r, :rownumber), T)

Tables.getcolumn(r::Row, i::Int) =
    Tables.getcolumn(r, getquery(r).types[i], i, getquery(r).names[i])
Tables.getcolumn(r::Row, nm::Symbol) = Tables.getcolumn(r, getquery(r).lookup[nm])
Tables.columnnames(r::Row) = Tables.columnnames(getquery(r))

function Base.iterate(q::Query)
    done(q) && return nothing
    q.current_rownumber[] = 1
    return Row(q, 1), 2
end

function Base.iterate(q::Query, rownumber)
    q.status[] = C.sqlite3_step(_get_stmt_handle(q.stmt))
    done(q) && return nothing
    q.current_rownumber[] = rownumber
    return Row(q, rownumber), rownumber + 1
end

"Return the last row insert id from the executed statement"
DBInterface.lastrowid(q::Query) = C.sqlite3_last_insert_rowid(q.stmt.db.handle)

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
function DBInterface.execute(
    stmt::Stmt,
    params::DBInterface.StatementParams;
    allowduplicates::Bool = false,
)
    status = direct_execute(stmt, params)
    handle = _get_stmt_handle(stmt)
    cols = C.sqlite3_column_count(handle)
    header = Vector{Symbol}(undef, cols)
    types = Vector{Type}(undef, cols)
    for i = 1:cols
        nm = sym(C.sqlite3_column_name(handle, i-1))
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
        types[i] = Union{juliatype(handle, i),Missing}
    end
    return Query(
        stmt,
        Ref(status),
        header,
        types,
        Dict(x => i for (i, x) in enumerate(header)),
        Ref(0),
    )
end
