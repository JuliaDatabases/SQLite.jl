"""
`SQLite.Source(db, sql, values=[]; rows::Int=0, stricttypes::Bool=true)`

Independently constructs an `SQLite.Source` in `db` with the SQL statement `sql`.
Will bind `values` to any parameters in `sql`.
`rows` is used to indicate how many rows to return in the query result if known beforehand. `rows=0` (the default) will return all possible rows.
`stricttypes=false` will remove strict column typing in the result set, making each column effectively `Vector{Any}`. `nullable::Bool=true` indicates
whether to allow missing values when fetching results; if set to `false` and a missing value is encountered, a `NullException` will be thrown.

Note that no results are returned; `sql` is executed, and results are ready to be returned (i.e. streamed to an appropriate `Data.Sink` type)
"""
function Source(db::DB, sql::AbstractString, values=[]; rows::Union{Int, Missing}=missing, stricttypes::Bool=true, nullable::Bool=true)
    Base.depwarn("`SQLite.Source(db, sql)` is deprecated in favor of `SQLite.Query(db, sql)` which executes a query and returns a row iterator", nothing)
    stmt = SQLite.Stmt(db, sql)
    bind!(stmt, values)
    status = SQLite.execute!(stmt)
    cols = SQLite.sqlite3_column_count(stmt.handle)
    header = Vector{String}(undef, cols)
    types = Vector{Type}(undef, cols)
    for i = 1:cols
        header[i] = unsafe_string(SQLite.sqlite3_column_name(stmt.handle, i))
        if nullable
            types[i] = stricttypes ? Union{SQLite.juliatype(stmt.handle, i), Missing} : Any
        else
            types[i] = stricttypes ? SQLite.juliatype(stmt.handle, i) : Any
        end
    end
    return SQLite.Source(Data.Schema(types, header, rows), stmt, status)
end

"""
`SQLite.Source(sink::SQLite.Sink, sql="select * from \$(sink.tablename)")`

constructs an SQLite.Source from an SQLite.Sink; selects all rows/columns from the underlying Sink table by default
"""
Source(sink::SQLite.Sink, sql::AbstractString="select * from $(sink.tablename)") = Source(sink.db, sql::AbstractString)

# DataStreams interface
Data.schema(source::SQLite.Source) = source.schema
function Data.isdone(s::Source, row, col)
    (s.status == SQLITE_DONE || s.status == SQLITE_ROW) || sqliteerror(s.stmt.db)
    return s.status == SQLITE_DONE
end
# resets an SQLite.Source, ready to read data from at the start of the resultset
Data.reset!(io::SQLite.Source) = (sqlite3_reset(io.stmt.handle); execute!(io.stmt))
Data.streamtype(::Type{SQLite.Source}, ::Type{Data.Field}) = true

# `T` might be Int, Float64, String, WeakRefString, any Julia type, Any, Missing
# `t` (the actual type of the value we're returning), might be SQLITE_INTEGER, SQLITE_FLOAT, SQLITE_TEXT, SQLITE_BLOB, SQLITE_NULL
# `SQLite.streamfrom` returns the next `Union{T, Missing}` value from the `SQLite.Source`
function Data.streamfrom(source::SQLite.Source, ::Type{Data.Field}, ::Type{Union{T, Missing}}, row, col) where {T}
    handle = source.stmt.handle
    t = SQLite.sqlite3_column_type(handle, col)
    if t == SQLite.SQLITE_NULL
        val = missing
    else
        TT = SQLite.juliatype(t) # native SQLite Int, Float, and Text types
        val = SQLite.sqlitevalue(ifelse(TT === Any && !isbitstype(T), T, TT), handle, col)
    end
    col == source.schema.cols && (source.status = sqlite3_step(handle))
    return val::Union{T, Missing}
end
function Data.streamfrom(source::SQLite.Source, ::Type{Data.Field}, ::Type{T}, row, col) where {T}
    handle = source.stmt.handle
    t = SQLite.sqlite3_column_type(handle, col)
    if t == SQLite.SQLITE_NULL
        throw(Data.NullException("encountered missing value in non-missing typed column: row = $row, col = $col"))
    else
        TT = SQLite.juliatype(t) # native SQLite Int, Float, and Text types
        val::T = sqlitevalue(ifelse(TT === Any && !isbitstype(T), T, TT), handle, col)
    end
    col == source.schema.cols && (source.status = sqlite3_step(handle))
    return val
end

"""
`SQLite.query(db, sql::String, sink=DataFrame, values=[]; rows::Int=0, stricttypes::Bool=true)`

convenience method for executing an SQL statement and streaming the results back in a `Data.Sink` (DataFrame by default)

Will bind `values` to any parameters in `sql`.
`rows` is used to indicate how many rows to return in the query result if known beforehand. `rows=0` (the default) will return all possible rows.
`stricttypes=false` will remove strict column typing in the result set, making each column effectively `Vector{Any}`
"""
function query(db::DB, sql::AbstractString, sink::Union{Type, Nothing}=nothing, args...; values=[], append::Bool=false, transforms::Dict=Dict{Int,Function}(), kwargs...)
    if sink === nothing
        Base.depwarn("`SQLite.query(db, sql)` will return an `SQLite.Query` object in the future; to materialize a resultset, do `DataFrame(SQLite.query(db, sql))` instead", nothing)
        sink = DataFrame
    else
        Base.depwarn("`SQLite.query(db, sql, $sink, args...)` is deprecated; use `SQLite.query(db, sql) |> $sink(args...)` instead", nothing)
    end
    if append
        Base.depwarn("`append=true` is deprecated in favor of sink-specific append support; for a DataFrame, for example, one can do `append!(existing_df, SQLite.query(db, sql))`", nothing)
    end
    source = Source(db, sql, values; kwargs...)
    sink = Data.stream!(source, sink; append=append, transforms=transforms, args...)
    return Data.close!(sink)
end

function query(db::DB, sql::AbstractString, sink::T; values=[], append::Bool=false, transforms::Dict=Dict{Int,Function}(), kwargs...) where {T}
    Base.depwarn("`SQLite.query(db, sql, ::$T)` is deprecated; use `SQLite.query(db, sql) |> $T` instead", nothing)
    if append
        Base.depwarn("`append=true` is deprecated in favor of sink-specific append support; for a DataFrame, for example, one can do `append!(existing_df, SQLite.query(db, sql))`", nothing)
    end
    source = Source(db, sql, values; kwargs...)
    sink = Data.stream!(source, sink; append=append, transforms=transforms)
    return Data.close!(sink)
end
function query(source::SQLite.Source, sink=DataFrame, args...; append::Bool=false, transforms::Dict=Dict{Int,Function}())
    Base.depwarn("`SQLite.query(s::SQLite.Source, args...)` is deprecated; use `SQLite.query(db, sql) |> sink` instead", nothing)
    sink = Data.stream!(source, sink; append=append, transforms=transforms, args...)
    return Data.close!(sink)
end
function query(source::SQLite.Source, sink::T; append::Bool=false, transforms::Dict=Dict{Int,Function}()) where {T}
    Base.depwarn("`SQLite.query(s::SQLite.Source, args...)` is deprecated; use `SQLite.query(db, sql) |> sink` instead", nothing)
    sink = Data.stream!(source, sink; append=append, transforms=transforms)
    return Data.close!(sink)
end
