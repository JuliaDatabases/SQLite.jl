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

function window{S<:AbstractString}(
    db::SQLiteDB, cb::Base.Callable, range::OrdinalRange,
    table::AbstractString, columns::Vector{S}, data=nothing,
)
    @assert !isempty(columns) "you must specifiy at least one column"
    nrows = query(db, string("SELECT COUNT(*) FROM ", table))[1][1]
    stmt = SQLiteStmt(db, string("SELECT ", join(columns, ", "), " FROM ", table))
    status = execute(stmt)
    ncols = sqlite3_column_count(stmt.handle)
    # TODO: we can calculate how many rows we need and do this in place
    tablerows = Array{Any,1}[]
    results = Any[]
    latest_row = 0
    for start_row in 1:(nrows + range.start - range.stop)
        # TODO: we can do this in place aswell
        curwindow = Array{Any,1}[]
        # find relevent rows for window
        for row in range
            # only load rows as they are needed
            while latest_row < row + start_row - 1 && status == SQLITE_ROW
                status, row_values = fetchrow(stmt, ncols)
                latest_row += 1
                push!(tablerows, row_values)
            end
            status == SQLITE_ROW || status == SQLITE_DONE || sqliteerror(stmt.db)
            push!(curwindow, tablerows[row])
        end
        push!(results, cb(curwindow, range, data))
        # get rid of rows we no longer need
        shift!(tablerows)
    end
    results
end
