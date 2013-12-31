function Base.connect(::Type{SQLite3},
                      path::String,
                      accessmode = convert(Cint, SQLITE_OPEN_READWRITE),
                      vfs::Ptr{Void} = C_NULL)
    dbptrptr = Array(Ptr{Void}, 1)
    # TODO: Check whether path should be UTF8
    status = sqlite3_open_v2(utf8(path), dbptrptr, accessmode, vfs)
    db = SQLiteDatabaseHandle(dbptrptr[1], status)
    db.status = status
    if @failed status
        sqlmsg = bytestring(sqlite3_errmsg(db.ptr))
        msg1 = @sprintf "Failed to access path: '%s'\n" path
        msg2 = @sprintf "SQLite3 error message: '%s'\n" sqlmsg
        error(string(msg1, msg2))
    end
    return db
end

function DBI.disconnect(db::SQLiteDatabaseHandle)
    status = sqlite3_close_v2(db.ptr)
    db.status = status
    if @failed status
        sqlmsg = bytestring(sqlite3_errmsg(db.ptr))
        msg = @sprintf "SQLite3 error message: '%s'\n" sqlmsg
        error(msg)
    end
    return
end

function DBI.prepare(db::SQLiteDatabaseHandle, sql::String)
    stmtptrptr = Array(Ptr{Void}, 1)
    status = sqlite3_prepare_v2(db.ptr, utf8(sql), stmtptrptr, [C_NULL])
    db.status = status
    if @failed status
        sqlmsg = bytestring(sqlite3_errmsg(db.ptr))
        msg1 = @sprintf "Failed to prepare SQL: `%s`\n" sql
        msg2 = @sprintf "SQLite3 error message: '%s'\n" sqlmsg
        error(string(msg1, msg2))
    end
    return SQLiteStatementHandle(db, stmtptrptr[1])
end

function DBI.execute(stmt::SQLiteStatementHandle)
    status = sqlite3_step(stmt.ptr)
    stmt.db.status = status
    if @failed status
        sqlmsg = bytestring(sqlite3_errmsg(stmt.db.ptr))
        msg = @sprintf "SQLite3 error message: '%s'\n" sqlmsg
        error(msg)
    end
    return
end

# Bind parameters, then step and reset
function DBI.execute(stmt::SQLiteStatementHandle, parameters::Vector)
    index = 0
    for parameter in parameters
        index += 1
        if isa(parameter, FloatingPoint)
            sqlite3_bind_double(stmt.ptr, index, parameter)
        elseif isa(parameter, Integer)
            if WORD_SIZE == 64
                sqlite3_bind_int64(stmt.ptr, index, parameter)
            else
                sqlite3_bind_int(stmt.ptr, index, parameter)
            end
        elseif isa(parameter, NAtype)
            sqlite3_bind_null(stmt.ptr, index)
        # TODO: Blob
        else
            s = utf8(parameter)
            sqlite3_bind_text(stmt.ptr, index, s, length(s), C_NULL)
        end
    end
    status = sqlite3_step(stmt.ptr)
    # TODO: Check status of reset call?
    sqlite3_reset(stmt.ptr)
    stmt.db.status = status
    if @failed status
        sqlmsg = bytestring(sqlite3_errmsg(stmt.db.ptr))
        msg = @sprintf "SQLite3 error message: '%s'\n" sqlmsg
        error(msg)
    end
    return
end

function DBI.finish(stmt::SQLiteStatementHandle)
    status = sqlite3_finalize(stmt.ptr)
    stmt.db.status = status
    if @failed status
        sqlmsg = bytestring(sqlite3_errmsg(stmt.db.ptr))
        msg = @sprintf "SQLite3 error message: '%s'\n" sqlmsg
        error(msg)
    end
    return
end

# Assumes statement has been executed once already
function DBI.fetchrow(stmt::SQLiteStatementHandle)
    ncols = SQLite.sqlite3_data_count(stmt.ptr)
    row = Array(Any, ncols)
    if ncols == 0
        return row
    end
    for i = 1:ncols
        t = sqlite3_column_type(stmt.ptr, i - 1)
        if t == SQLITE_INTEGER
            if WORD_SIZE == 64
                row[i] = sqlite3_column_int64(stmt.ptr, i - 1)
            else
                row[i] = sqlite3_column_int(stmt.ptr, i - 1)
            end
        elseif t == SQLITE_FLOAT
            row[i] = sqlite3_column_double(stmt.ptr, i - 1)
        elseif t == SQLITE3_TEXT
            row[i] = bytestring(sqlite3_column_text(stmt.ptr, i - 1))
        # TODO: Support blobs
        else
            row[i] = NA
        end
    end
    status = sqlite3_step(stmt.ptr)
    stmt.db.status = status
    if @failed status
        sqlmsg = bytestring(sqlite3_errmsg(stmt.db.ptr))
        msg = @sprintf "SQLite3 error message: '%s'\n" sqlmsg
        error(msg)
    end
    return row
end

# Assumes statement has been executed once already
function DBI.fetchall(stmt::SQLiteStatementHandle)
    rows = Array(Any, 0)
    allfetched = false
    while !allfetched
        row = fetchrow(stmt)
        if !isempty(row)
            push!(rows, row)
        else
            allfetched = true
        end
    end
    return rows
end

# Assumes statement has been executed once already
function DBI.fetchdf(stmt::SQLiteStatementHandle)
    ncols = sqlite3_column_count(stmt.ptr)

    cols = Array(Any, ncols)

    colnames = Array(UTF8String, ncols)
    ntypedcols = 0
    for i in 1:ncols
        colnames[i] = bytestring(sqlite3_column_name(stmt.ptr, i - 1))
        t = sqlite3_column_type(stmt.ptr, i - 1)
        if t == SQLITE3_TEXT
            cols[i] = DataArray(UTF8String, 0)
            ntypedcols += 1
        elseif t == SQLITE_FLOAT
            cols[i] = DataArray(Float64, 0)
            ntypedcols += 1
        elseif t == SQLITE_INTEGER
            cols[i] = DataArray(Int, 0)
            ntypedcols += 1
        else
            cols[i] = DataArray(Any, 0)
        end
    end

    while stmt.db.status != SQLITE_DONE
        for i = 1:ncols
            t = sqlite3_column_type(stmt.ptr, i - 1)
            if t == SQLITE3_TEXT
                # TODO: Make this more like raw API
                val = bytestring(sqlite3_column_text(stmt.ptr, i - 1))
            elseif t == SQLITE_FLOAT
                val = sqlite3_column_double(stmt.ptr, i - 1)
            elseif t == SQLITE_INTEGER
                if WORD_SIZE == 64
                    val = sqlite3_column_int64(stmt.ptr, i - 1)
                else
                    val = sqlite3_column_int(stmt.ptr, i - 1)
                end
            else
                val = NA
            end
            push!(cols[i], val)
        end
        execute(stmt)
    end

    # If the type of any column was not determined by its first row,
    # we tighten the type here by finding the first non-NA value
    # and using its type
    if ntypedcols != ncols
        nrows = length(cols[1])
        for j in 1:ncols
            if nrows > 0 && isna(cols[j][1])
                da = cols[j]
                i = 2
                while i <= nrows && isna(da[j])
                    i += 1
                end
                if i <= nrows
                    T = typeof(da[i])
                    cols[j] = convert(DataVector{T}, da)
                end
            end
        end
    end

    return DataFrame(cols, Index(colnames))
end

function DBI.columninfo(db::SQLiteDatabaseHandle,
                        table::String,
                        column::String)
    datatype = Array(Ptr{Uint8}, 1)
    collseq = Array(Ptr{Uint8}, 1)
    notnull = Cint[0]
    primarykey = Cint[0]
    autoinc = Cint[0]

    status = sqlite3_table_column_metadata(db.ptr,
                                           table,
                                           column,
                                           datatype,
                                           collseq,
                                           notnull,
                                           primarykey,
                                           autoinc)

    db.status = status
    datatype, length = sql2jltype(bytestring(datatype[1]))
    return DBI.DatabaseColumn(column,
                              datatype,
                              length,
                              bytestring(collseq[1]),
                              bool(1 - notnull[1]),
                              bool(primarykey[1]),
                              bool(autoinc[1]))
end

function DBI.tableinfo(db::SQLiteDatabaseHandle, table::String)
    stmt = prepare(db, "PRAGMA table_info($table)")
    execute(stmt)
    columnlist = fetchall(stmt)
    ncols = size(columnlist, 1)
    finish(stmt)
    cols = Array(DBI.DatabaseColumn, ncols)
    # NB: We are discarding information about default values
    #     provided by PRAGMA table_info().
    for i in 1:ncols
        column = columnlist[i][2]
        cols[i] = columninfo(db, table, column)
    end
    return DBI.DatabaseTable(table, cols)
end
