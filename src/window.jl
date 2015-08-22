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
function window{S<:String}(
    db::SQLiteDB, cb::Base.Callable, range::OrdinalRange,
    table::String, columns::Vector{S}, data...,
)
    @assert !isempty(columns) "you must specifiy at least one column"
    # TODO: should this be robust against injection attacks? how?
    nrows = query(db, string("SELECT COUNT(*) FROM ", table))[1][1]
    stmt = SQLiteStmt(db, string("SELECT ", join(columns, ", "), " FROM ", table))
    status = execute(stmt)
    ncols = Int64(sqlite3_column_count(stmt.handle))
    # TODO: we alread know the size of this so do everything in place
    # TODO: this is the table elements not the results
    # TODO: would it be less confusing to use a Vector of Vectors rather than a Matrix
    results = Array(Any, (0, ncols))
    actual_results = Any[]
    latest_row = 0
    for start_row in 1:(nrows + range.start - range.stop)
        window_results = Array(Any, (0, ncols))
        # find relevent rows for window
        for row in addrange(start_row-1, range)
            # only load rows as they are needed
            # TODO: is this really an optimisation?
            while row > latest_row && status == SQLITE_ROW
                status, row_results = fetchrow(stmt, ncols)
                results = vcat(results, row_results')
                latest_row += 1
            end
            status == SQLITE_ROW || status == SQLITE_DONE || sqliteerror(stmt.db)
            window_results = vcat(window_results, results[row, :])
        end
        push!(actual_results, cb(window_results, range, data))
    end
    actual_results
end
