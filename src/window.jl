addrange(i::Integer, r::UnitRange) = (i + r.start):(i + r.stop)
addrange(i::Integer, r::StepRange) = (i + r.start):r.step:(i + r.stop)

function fetchrow(stmt::SQLiteStmt, ncols::Integer)
    row = Any[]
    for col in 1:ncols
        t = sqlite3_column_type(stmt.handle,col-1)
        if t == SQLITE_INTEGER
            r = sqlite3_column_int64(stmt.handle,col-1)
        elseif t == SQLITE_FLOAT
            r = sqlite3_column_double(stmt.handle,col-1)
        elseif t == SQLITE_TEXT
            #TODO: have a way to return text16?
            r = bytestring(sqlite3_column_text(stmt.handle,col-1))
        elseif t == SQLITE_BLOB
            blob = sqlite3_column_blob(stmt.handle,col-1)
            b = sqlite3_column_bytes(stmt.handle,col-1)
            buf = zeros(UInt8,b)
            unsafe_copy!(pointer(buf), convert(Ptr{UInt8},blob), b)
            r = sqldeserialize(buf)
        else
            r = NULL
        end
        push!(row, r)
    end
    status = sqlite3_step(stmt.handle)
    status, row
end

# TODO: wrapping this in a macro would avoid the slowness of first-class functions
function window{S<:AbstractString}(
    db::SQLiteDB, cb::Base.Callable, range::OrdinalRange,
    table::AbstractString, columns::Vector{S}, data...,
)
    @assert !isempty(columns) "you must specifiy at least one column"
    nrows = query(db, string("SELECT COUNT(*) FROM ", table))[1][1]
    stmt = SQLiteStmt(db, string("SELECT ", join(columns, ", "), " FROM ", table))
    status = execute(stmt)
    ncols = sqlite3_column_count(stmt.handle)
    # TODO: don't keep rows that are no longer needed
    tablerows = [Array(Any, ncols) for _ in 1:nrows]
    results = Any[]
    latest_row = 0
    for start_row in 1:(nrows + range.start - range.stop)
        # TODO: with work we can do this in place aswell
        curwindow = Any[]
        # find relevent rows for window
        for row in addrange(start_row-1, range)
            # only load rows as they are needed
            while row > latest_row && status == SQLITE_ROW
                status, row_results = fetchrow(stmt, ncols)
                latest_row += 1
                copy!(tablerows[latest_row], row_results)
            end
            status == SQLITE_ROW || status == SQLITE_DONE || sqliteerror(stmt.db)
            push!(curwindow, tablerows[row])
        end
        push!(results, cb(curwindow, range, data))
    end
    results
end
