module C

using SQLite_jll
export SQLite_jll

# typedef void ( * sqlite3_destructor_type ) ( void * )
const sqlite3_destructor_type = Ptr{Cvoid}

function sqlite3_libversion()
    @ccall libsqlite.sqlite3_libversion()::Ptr{Cchar}
end

function sqlite3_sourceid()
    @ccall libsqlite.sqlite3_sourceid()::Ptr{Cchar}
end

function sqlite3_libversion_number()
    @ccall libsqlite.sqlite3_libversion_number()::Cint
end

function sqlite3_compileoption_used(zOptName)
    @ccall libsqlite.sqlite3_compileoption_used(zOptName::Ptr{Cchar})::Cint
end

function sqlite3_compileoption_get(N)
    @ccall libsqlite.sqlite3_compileoption_get(N::Cint)::Ptr{Cchar}
end

function sqlite3_threadsafe()
    @ccall libsqlite.sqlite3_threadsafe()::Cint
end

mutable struct sqlite3 end

const sqlite_int64 = Clonglong

const sqlite_uint64 = Culonglong

const sqlite3_int64 = sqlite_int64

const sqlite3_uint64 = sqlite_uint64

function sqlite3_close(arg1)
    @ccall libsqlite.sqlite3_close(arg1::Ptr{sqlite3})::Cint
end

function sqlite3_close_v2(arg1)
    @ccall libsqlite.sqlite3_close_v2(arg1::Ptr{sqlite3})::Cint
end

# typedef int ( * sqlite3_callback ) ( void * , int , char * * , char * * )
const sqlite3_callback = Ptr{Cvoid}

function sqlite3_exec(arg1, sql, callback, arg4, errmsg)
    @ccall libsqlite.sqlite3_exec(
        arg1::Ptr{sqlite3},
        sql::Ptr{Cchar},
        callback::Ptr{Cvoid},
        arg4::Ptr{Cvoid},
        errmsg::Ptr{Ptr{Cchar}},
    )::Cint
end

struct sqlite3_io_methods
    iVersion::Cint
    xClose::Ptr{Cvoid}
    xRead::Ptr{Cvoid}
    xWrite::Ptr{Cvoid}
    xTruncate::Ptr{Cvoid}
    xSync::Ptr{Cvoid}
    xFileSize::Ptr{Cvoid}
    xLock::Ptr{Cvoid}
    xUnlock::Ptr{Cvoid}
    xCheckReservedLock::Ptr{Cvoid}
    xFileControl::Ptr{Cvoid}
    xSectorSize::Ptr{Cvoid}
    xDeviceCharacteristics::Ptr{Cvoid}
    xShmMap::Ptr{Cvoid}
    xShmLock::Ptr{Cvoid}
    xShmBarrier::Ptr{Cvoid}
    xShmUnmap::Ptr{Cvoid}
    xFetch::Ptr{Cvoid}
    xUnfetch::Ptr{Cvoid}
end

struct sqlite3_file
    pMethods::Ptr{sqlite3_io_methods}
end

mutable struct sqlite3_mutex end

mutable struct sqlite3_api_routines end

const sqlite3_filename = Ptr{Cchar}

struct sqlite3_vfs
    iVersion::Cint
    szOsFile::Cint
    mxPathname::Cint
    pNext::Ptr{sqlite3_vfs}
    zName::Ptr{Cchar}
    pAppData::Ptr{Cvoid}
    xOpen::Ptr{Cvoid}
    xDelete::Ptr{Cvoid}
    xAccess::Ptr{Cvoid}
    xFullPathname::Ptr{Cvoid}
    xDlOpen::Ptr{Cvoid}
    xDlError::Ptr{Cvoid}
    xDlSym::Ptr{Cvoid}
    xDlClose::Ptr{Cvoid}
    xRandomness::Ptr{Cvoid}
    xSleep::Ptr{Cvoid}
    xCurrentTime::Ptr{Cvoid}
    xGetLastError::Ptr{Cvoid}
    xCurrentTimeInt64::Ptr{Cvoid}
    xSetSystemCall::Ptr{Cvoid}
    xGetSystemCall::Ptr{Cvoid}
    xNextSystemCall::Ptr{Cvoid}
end

# typedef void ( * sqlite3_syscall_ptr ) ( void )
const sqlite3_syscall_ptr = Ptr{Cvoid}

function sqlite3_initialize()
    @ccall libsqlite.sqlite3_initialize()::Cint
end

function sqlite3_shutdown()
    @ccall libsqlite.sqlite3_shutdown()::Cint
end

function sqlite3_os_init()
    @ccall libsqlite.sqlite3_os_init()::Cint
end

function sqlite3_os_end()
    @ccall libsqlite.sqlite3_os_end()::Cint
end

struct sqlite3_mem_methods
    xMalloc::Ptr{Cvoid}
    xFree::Ptr{Cvoid}
    xRealloc::Ptr{Cvoid}
    xSize::Ptr{Cvoid}
    xRoundup::Ptr{Cvoid}
    xInit::Ptr{Cvoid}
    xShutdown::Ptr{Cvoid}
    pAppData::Ptr{Cvoid}
end

function sqlite3_extended_result_codes(arg1, onoff)
    @ccall libsqlite.sqlite3_extended_result_codes(
        arg1::Ptr{sqlite3},
        onoff::Cint,
    )::Cint
end

function sqlite3_last_insert_rowid(arg1)
    @ccall libsqlite.sqlite3_last_insert_rowid(
        arg1::Ptr{sqlite3},
    )::sqlite3_int64
end

function sqlite3_set_last_insert_rowid(arg1, arg2)
    @ccall libsqlite.sqlite3_set_last_insert_rowid(
        arg1::Ptr{sqlite3},
        arg2::sqlite3_int64,
    )::Cvoid
end

function sqlite3_changes(arg1)
    @ccall libsqlite.sqlite3_changes(arg1::Ptr{sqlite3})::Cint
end

function sqlite3_changes64(arg1)
    @ccall libsqlite.sqlite3_changes64(arg1::Ptr{sqlite3})::sqlite3_int64
end

function sqlite3_total_changes(arg1)
    @ccall libsqlite.sqlite3_total_changes(arg1::Ptr{sqlite3})::Cint
end

function sqlite3_total_changes64(arg1)
    @ccall libsqlite.sqlite3_total_changes64(arg1::Ptr{sqlite3})::sqlite3_int64
end

function sqlite3_interrupt(arg1)
    @ccall libsqlite.sqlite3_interrupt(arg1::Ptr{sqlite3})::Cvoid
end

function sqlite3_complete(sql)
    @ccall libsqlite.sqlite3_complete(sql::Ptr{Cchar})::Cint
end

function sqlite3_complete16(sql)
    @ccall libsqlite.sqlite3_complete16(sql::Ptr{Cvoid})::Cint
end

function sqlite3_busy_handler(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_busy_handler(
        arg1::Ptr{sqlite3},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Cint
end

function sqlite3_busy_timeout(arg1, ms)
    @ccall libsqlite.sqlite3_busy_timeout(arg1::Ptr{sqlite3}, ms::Cint)::Cint
end

function sqlite3_get_table(db, zSql, pazResult, pnRow, pnColumn, pzErrmsg)
    @ccall libsqlite.sqlite3_get_table(
        db::Ptr{sqlite3},
        zSql::Ptr{Cchar},
        pazResult::Ptr{Ptr{Ptr{Cchar}}},
        pnRow::Ptr{Cint},
        pnColumn::Ptr{Cint},
        pzErrmsg::Ptr{Ptr{Cchar}},
    )::Cint
end

function sqlite3_free_table(result)
    @ccall libsqlite.sqlite3_free_table(result::Ptr{Ptr{Cchar}})::Cvoid
end

function sqlite3_malloc(arg1)
    @ccall libsqlite.sqlite3_malloc(arg1::Cint)::Ptr{Cvoid}
end

function sqlite3_malloc64(arg1)
    @ccall libsqlite.sqlite3_malloc64(arg1::sqlite3_uint64)::Ptr{Cvoid}
end

function sqlite3_realloc(arg1, arg2)
    @ccall libsqlite.sqlite3_realloc(arg1::Ptr{Cvoid}, arg2::Cint)::Ptr{Cvoid}
end

function sqlite3_realloc64(arg1, arg2)
    @ccall libsqlite.sqlite3_realloc64(
        arg1::Ptr{Cvoid},
        arg2::sqlite3_uint64,
    )::Ptr{Cvoid}
end

function sqlite3_free(arg1)
    @ccall libsqlite.sqlite3_free(arg1::Ptr{Cvoid})::Cvoid
end

function sqlite3_msize(arg1)
    @ccall libsqlite.sqlite3_msize(arg1::Ptr{Cvoid})::sqlite3_uint64
end

function sqlite3_memory_used()
    @ccall libsqlite.sqlite3_memory_used()::sqlite3_int64
end

function sqlite3_memory_highwater(resetFlag)
    @ccall libsqlite.sqlite3_memory_highwater(resetFlag::Cint)::sqlite3_int64
end

function sqlite3_randomness(N, P)
    @ccall libsqlite.sqlite3_randomness(N::Cint, P::Ptr{Cvoid})::Cvoid
end

function sqlite3_set_authorizer(arg1, xAuth, pUserData)
    @ccall libsqlite.sqlite3_set_authorizer(
        arg1::Ptr{sqlite3},
        xAuth::Ptr{Cvoid},
        pUserData::Ptr{Cvoid},
    )::Cint
end

function sqlite3_trace(arg1, xTrace, arg3)
    @ccall libsqlite.sqlite3_trace(
        arg1::Ptr{sqlite3},
        xTrace::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Ptr{Cvoid}
end

function sqlite3_profile(arg1, xProfile, arg3)
    @ccall libsqlite.sqlite3_profile(
        arg1::Ptr{sqlite3},
        xProfile::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Ptr{Cvoid}
end

function sqlite3_trace_v2(arg1, uMask, xCallback, pCtx)
    @ccall libsqlite.sqlite3_trace_v2(
        arg1::Ptr{sqlite3},
        uMask::Cuint,
        xCallback::Ptr{Cvoid},
        pCtx::Ptr{Cvoid},
    )::Cint
end

function sqlite3_progress_handler(arg1, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_progress_handler(
        arg1::Ptr{sqlite3},
        arg2::Cint,
        arg3::Ptr{Cvoid},
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_open(filename, ppDb)
    @ccall libsqlite.sqlite3_open(
        filename::Ptr{Cchar},
        ppDb::Ptr{Ptr{sqlite3}},
    )::Cint
end

function sqlite3_open16(filename, ppDb)
    @ccall libsqlite.sqlite3_open16(
        filename::Ptr{Cvoid},
        ppDb::Ptr{Ptr{sqlite3}},
    )::Cint
end

function sqlite3_open_v2(filename, ppDb, flags, zVfs)
    @ccall libsqlite.sqlite3_open_v2(
        filename::Ptr{Cchar},
        ppDb::Ptr{Ptr{sqlite3}},
        flags::Cint,
        zVfs::Ptr{Cchar},
    )::Cint
end

function sqlite3_uri_parameter(z, zParam)
    @ccall libsqlite.sqlite3_uri_parameter(
        z::sqlite3_filename,
        zParam::Ptr{Cchar},
    )::Ptr{Cchar}
end

function sqlite3_uri_boolean(z, zParam, bDefault)
    @ccall libsqlite.sqlite3_uri_boolean(
        z::sqlite3_filename,
        zParam::Ptr{Cchar},
        bDefault::Cint,
    )::Cint
end

function sqlite3_uri_int64(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_uri_int64(
        arg1::sqlite3_filename,
        arg2::Ptr{Cchar},
        arg3::sqlite3_int64,
    )::sqlite3_int64
end

function sqlite3_uri_key(z, N)
    @ccall libsqlite.sqlite3_uri_key(z::sqlite3_filename, N::Cint)::Ptr{Cchar}
end

function sqlite3_filename_database(arg1)
    @ccall libsqlite.sqlite3_filename_database(
        arg1::sqlite3_filename,
    )::Ptr{Cchar}
end

function sqlite3_filename_journal(arg1)
    @ccall libsqlite.sqlite3_filename_journal(
        arg1::sqlite3_filename,
    )::Ptr{Cchar}
end

function sqlite3_filename_wal(arg1)
    @ccall libsqlite.sqlite3_filename_wal(arg1::sqlite3_filename)::Ptr{Cchar}
end

function sqlite3_database_file_object(arg1)
    @ccall libsqlite.sqlite3_database_file_object(
        arg1::Ptr{Cchar},
    )::Ptr{sqlite3_file}
end

function sqlite3_create_filename(zDatabase, zJournal, zWal, nParam, azParam)
    @ccall libsqlite.sqlite3_create_filename(
        zDatabase::Ptr{Cchar},
        zJournal::Ptr{Cchar},
        zWal::Ptr{Cchar},
        nParam::Cint,
        azParam::Ptr{Ptr{Cchar}},
    )::sqlite3_filename
end

function sqlite3_free_filename(arg1)
    @ccall libsqlite.sqlite3_free_filename(arg1::sqlite3_filename)::Cvoid
end

function sqlite3_errcode(db)
    @ccall libsqlite.sqlite3_errcode(db::Ptr{sqlite3})::Cint
end

function sqlite3_extended_errcode(db)
    @ccall libsqlite.sqlite3_extended_errcode(db::Ptr{sqlite3})::Cint
end

function sqlite3_errmsg(arg1)
    @ccall libsqlite.sqlite3_errmsg(arg1::Ptr{sqlite3})::Ptr{Cchar}
end

function sqlite3_errmsg16(arg1)
    @ccall libsqlite.sqlite3_errmsg16(arg1::Ptr{sqlite3})::Ptr{Cvoid}
end

function sqlite3_errstr(arg1)
    @ccall libsqlite.sqlite3_errstr(arg1::Cint)::Ptr{Cchar}
end

function sqlite3_error_offset(db)
    @ccall libsqlite.sqlite3_error_offset(db::Ptr{sqlite3})::Cint
end

mutable struct sqlite3_stmt end

function sqlite3_limit(arg1, id, newVal)
    @ccall libsqlite.sqlite3_limit(
        arg1::Ptr{sqlite3},
        id::Cint,
        newVal::Cint,
    )::Cint
end

function sqlite3_prepare(db, zSql, nByte, ppStmt, pzTail)
    @ccall libsqlite.sqlite3_prepare(
        db::Ptr{sqlite3},
        zSql::Ptr{Cchar},
        nByte::Cint,
        ppStmt::Ptr{Ptr{sqlite3_stmt}},
        pzTail::Ptr{Ptr{Cchar}},
    )::Cint
end

function sqlite3_prepare_v2(db, zSql, nByte, ppStmt, pzTail)
    @ccall libsqlite.sqlite3_prepare_v2(
        db::Ptr{sqlite3},
        zSql::Ptr{Cchar},
        nByte::Cint,
        ppStmt::Ptr{Ptr{sqlite3_stmt}},
        pzTail::Ptr{Ptr{Cchar}},
    )::Cint
end

function sqlite3_prepare_v3(db, zSql, nByte, prepFlags, ppStmt, pzTail)
    @ccall libsqlite.sqlite3_prepare_v3(
        db::Ptr{sqlite3},
        zSql::Ptr{Cchar},
        nByte::Cint,
        prepFlags::Cuint,
        ppStmt::Ptr{Ptr{sqlite3_stmt}},
        pzTail::Ptr{Ptr{Cchar}},
    )::Cint
end

function sqlite3_prepare16(db, zSql, nByte, ppStmt, pzTail)
    @ccall libsqlite.sqlite3_prepare16(
        db::Ptr{sqlite3},
        zSql::Ptr{Cvoid},
        nByte::Cint,
        ppStmt::Ptr{Ptr{sqlite3_stmt}},
        pzTail::Ptr{Ptr{Cvoid}},
    )::Cint
end

function sqlite3_prepare16_v2(db, zSql, nByte, ppStmt, pzTail)
    @ccall libsqlite.sqlite3_prepare16_v2(
        db::Ptr{sqlite3},
        zSql::Ptr{Cvoid},
        nByte::Cint,
        ppStmt::Ptr{Ptr{sqlite3_stmt}},
        pzTail::Ptr{Ptr{Cvoid}},
    )::Cint
end

function sqlite3_prepare16_v3(db, zSql, nByte, prepFlags, ppStmt, pzTail)
    @ccall libsqlite.sqlite3_prepare16_v3(
        db::Ptr{sqlite3},
        zSql::Ptr{Cvoid},
        nByte::Cint,
        prepFlags::Cuint,
        ppStmt::Ptr{Ptr{sqlite3_stmt}},
        pzTail::Ptr{Ptr{Cvoid}},
    )::Cint
end

function sqlite3_sql(pStmt)
    @ccall libsqlite.sqlite3_sql(pStmt::Ptr{sqlite3_stmt})::Ptr{Cchar}
end

function sqlite3_expanded_sql(pStmt)
    @ccall libsqlite.sqlite3_expanded_sql(pStmt::Ptr{sqlite3_stmt})::Ptr{Cchar}
end

function sqlite3_stmt_readonly(pStmt)
    @ccall libsqlite.sqlite3_stmt_readonly(pStmt::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_stmt_isexplain(pStmt)
    @ccall libsqlite.sqlite3_stmt_isexplain(pStmt::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_stmt_busy(arg1)
    @ccall libsqlite.sqlite3_stmt_busy(arg1::Ptr{sqlite3_stmt})::Cint
end

mutable struct sqlite3_value end

mutable struct sqlite3_context end

function sqlite3_bind_blob(arg1, arg2, arg3, n, arg5)
    @ccall libsqlite.sqlite3_bind_blob(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Ptr{Cvoid},
        n::Cint,
        arg5::Ptr{Cvoid},
    )::Cint
end

function sqlite3_bind_blob64(arg1, arg2, arg3, arg4, arg5)
    @ccall libsqlite.sqlite3_bind_blob64(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Ptr{Cvoid},
        arg4::sqlite3_uint64,
        arg5::Ptr{Cvoid},
    )::Cint
end

function sqlite3_bind_double(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_bind_double(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Cdouble,
    )::Cint
end

function sqlite3_bind_int(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_bind_int(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Cint,
    )::Cint
end

function sqlite3_bind_int64(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_bind_int64(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::sqlite3_int64,
    )::Cint
end

function sqlite3_bind_null(arg1, arg2)
    @ccall libsqlite.sqlite3_bind_null(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Cint
end

function sqlite3_bind_text(arg1, arg2, arg3, arg4, arg5)
    @ccall libsqlite.sqlite3_bind_text(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Ptr{Cchar},
        arg4::Cint,
        arg5::Ptr{Cvoid},
    )::Cint
end

function sqlite3_bind_text16(arg1, arg2, arg3, arg4, arg5)
    @ccall libsqlite.sqlite3_bind_text16(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Ptr{Cvoid},
        arg4::Cint,
        arg5::Ptr{Cvoid},
    )::Cint
end

function sqlite3_bind_text64(arg1, arg2, arg3, arg4, arg5, encoding)
    @ccall libsqlite.sqlite3_bind_text64(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Ptr{Cchar},
        arg4::sqlite3_uint64,
        arg5::Ptr{Cvoid},
        encoding::Cuchar,
    )::Cint
end

function sqlite3_bind_value(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_bind_value(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Ptr{sqlite3_value},
    )::Cint
end

function sqlite3_bind_pointer(arg1, arg2, arg3, arg4, arg5)
    @ccall libsqlite.sqlite3_bind_pointer(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::Ptr{Cvoid},
        arg4::Ptr{Cchar},
        arg5::Ptr{Cvoid},
    )::Cint
end

function sqlite3_bind_zeroblob(arg1, arg2, n)
    @ccall libsqlite.sqlite3_bind_zeroblob(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        n::Cint,
    )::Cint
end

function sqlite3_bind_zeroblob64(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_bind_zeroblob64(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
        arg3::sqlite3_uint64,
    )::Cint
end

function sqlite3_bind_parameter_count(arg1)
    @ccall libsqlite.sqlite3_bind_parameter_count(arg1::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_bind_parameter_name(arg1, arg2)
    @ccall libsqlite.sqlite3_bind_parameter_name(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cchar}
end

function sqlite3_bind_parameter_index(arg1, zName)
    @ccall libsqlite.sqlite3_bind_parameter_index(
        arg1::Ptr{sqlite3_stmt},
        zName::Ptr{Cchar},
    )::Cint
end

function sqlite3_clear_bindings(arg1)
    @ccall libsqlite.sqlite3_clear_bindings(arg1::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_column_count(pStmt)
    @ccall libsqlite.sqlite3_column_count(pStmt::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_column_name(arg1, N)
    @ccall libsqlite.sqlite3_column_name(
        arg1::Ptr{sqlite3_stmt},
        N::Cint,
    )::Ptr{Cchar}
end

function sqlite3_column_name16(arg1, N)
    @ccall libsqlite.sqlite3_column_name16(
        arg1::Ptr{sqlite3_stmt},
        N::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_column_database_name(arg1, arg2)
    @ccall libsqlite.sqlite3_column_database_name(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cchar}
end

function sqlite3_column_database_name16(arg1, arg2)
    @ccall libsqlite.sqlite3_column_database_name16(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_column_table_name(arg1, arg2)
    @ccall libsqlite.sqlite3_column_table_name(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cchar}
end

function sqlite3_column_table_name16(arg1, arg2)
    @ccall libsqlite.sqlite3_column_table_name16(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_column_origin_name(arg1, arg2)
    @ccall libsqlite.sqlite3_column_origin_name(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cchar}
end

function sqlite3_column_origin_name16(arg1, arg2)
    @ccall libsqlite.sqlite3_column_origin_name16(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_column_decltype(arg1, arg2)
    @ccall libsqlite.sqlite3_column_decltype(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cchar}
end

function sqlite3_column_decltype16(arg1, arg2)
    @ccall libsqlite.sqlite3_column_decltype16(
        arg1::Ptr{sqlite3_stmt},
        arg2::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_step(arg1)
    @ccall libsqlite.sqlite3_step(arg1::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_data_count(pStmt)
    @ccall libsqlite.sqlite3_data_count(pStmt::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_column_blob(arg1, iCol)
    @ccall libsqlite.sqlite3_column_blob(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_column_double(arg1, iCol)
    @ccall libsqlite.sqlite3_column_double(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Cdouble
end

function sqlite3_column_int(arg1, iCol)
    @ccall libsqlite.sqlite3_column_int(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Cint
end

function sqlite3_column_int64(arg1, iCol)
    @ccall libsqlite.sqlite3_column_int64(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::sqlite3_int64
end

function sqlite3_column_text(arg1, iCol)
    @ccall libsqlite.sqlite3_column_text(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Ptr{Cuchar}
end

function sqlite3_column_text16(arg1, iCol)
    @ccall libsqlite.sqlite3_column_text16(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_column_value(arg1, iCol)
    @ccall libsqlite.sqlite3_column_value(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Ptr{sqlite3_value}
end

function sqlite3_column_bytes(arg1, iCol)
    @ccall libsqlite.sqlite3_column_bytes(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Cint
end

function sqlite3_column_bytes16(arg1, iCol)
    @ccall libsqlite.sqlite3_column_bytes16(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Cint
end

function sqlite3_column_type(arg1, iCol)
    @ccall libsqlite.sqlite3_column_type(
        arg1::Ptr{sqlite3_stmt},
        iCol::Cint,
    )::Cint
end

function sqlite3_finalize(pStmt)
    @ccall libsqlite.sqlite3_finalize(pStmt::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_reset(pStmt)
    @ccall libsqlite.sqlite3_reset(pStmt::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_create_function(
    db,
    zFunctionName,
    nArg,
    eTextRep,
    pApp,
    xFunc,
    xStep,
    xFinal,
)
    @ccall libsqlite.sqlite3_create_function(
        db::Ptr{sqlite3},
        zFunctionName::Ptr{Cchar},
        nArg::Cint,
        eTextRep::Cint,
        pApp::Ptr{Cvoid},
        xFunc::Ptr{Cvoid},
        xStep::Ptr{Cvoid},
        xFinal::Ptr{Cvoid},
    )::Cint
end

function sqlite3_create_function16(
    db,
    zFunctionName,
    nArg,
    eTextRep,
    pApp,
    xFunc,
    xStep,
    xFinal,
)
    @ccall libsqlite.sqlite3_create_function16(
        db::Ptr{sqlite3},
        zFunctionName::Ptr{Cvoid},
        nArg::Cint,
        eTextRep::Cint,
        pApp::Ptr{Cvoid},
        xFunc::Ptr{Cvoid},
        xStep::Ptr{Cvoid},
        xFinal::Ptr{Cvoid},
    )::Cint
end

function sqlite3_create_function_v2(
    db,
    zFunctionName,
    nArg,
    eTextRep,
    pApp,
    xFunc,
    xStep,
    xFinal,
    xDestroy,
)
    @ccall libsqlite.sqlite3_create_function_v2(
        db::Ptr{sqlite3},
        zFunctionName::Ptr{Cchar},
        nArg::Cint,
        eTextRep::Cint,
        pApp::Ptr{Cvoid},
        xFunc::Ptr{Cvoid},
        xStep::Ptr{Cvoid},
        xFinal::Ptr{Cvoid},
        xDestroy::Ptr{Cvoid},
    )::Cint
end

function sqlite3_create_window_function(
    db,
    zFunctionName,
    nArg,
    eTextRep,
    pApp,
    xStep,
    xFinal,
    xValue,
    xInverse,
    xDestroy,
)
    @ccall libsqlite.sqlite3_create_window_function(
        db::Ptr{sqlite3},
        zFunctionName::Ptr{Cchar},
        nArg::Cint,
        eTextRep::Cint,
        pApp::Ptr{Cvoid},
        xStep::Ptr{Cvoid},
        xFinal::Ptr{Cvoid},
        xValue::Ptr{Cvoid},
        xInverse::Ptr{Cvoid},
        xDestroy::Ptr{Cvoid},
    )::Cint
end

function sqlite3_aggregate_count(arg1)
    @ccall libsqlite.sqlite3_aggregate_count(arg1::Ptr{sqlite3_context})::Cint
end

function sqlite3_expired(arg1)
    @ccall libsqlite.sqlite3_expired(arg1::Ptr{sqlite3_stmt})::Cint
end

function sqlite3_transfer_bindings(arg1, arg2)
    @ccall libsqlite.sqlite3_transfer_bindings(
        arg1::Ptr{sqlite3_stmt},
        arg2::Ptr{sqlite3_stmt},
    )::Cint
end

function sqlite3_global_recover()
    @ccall libsqlite.sqlite3_global_recover()::Cint
end

function sqlite3_thread_cleanup()
    @ccall libsqlite.sqlite3_thread_cleanup()::Cvoid
end

function sqlite3_memory_alarm(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_memory_alarm(
        arg1::Ptr{Cvoid},
        arg2::Ptr{Cvoid},
        arg3::sqlite3_int64,
    )::Cint
end

function sqlite3_value_blob(arg1)
    @ccall libsqlite.sqlite3_value_blob(arg1::Ptr{sqlite3_value})::Ptr{Cvoid}
end

function sqlite3_value_double(arg1)
    @ccall libsqlite.sqlite3_value_double(arg1::Ptr{sqlite3_value})::Cdouble
end

function sqlite3_value_int(arg1)
    @ccall libsqlite.sqlite3_value_int(arg1::Ptr{sqlite3_value})::Cint
end

function sqlite3_value_int64(arg1)
    @ccall libsqlite.sqlite3_value_int64(
        arg1::Ptr{sqlite3_value},
    )::sqlite3_int64
end

function sqlite3_value_pointer(arg1, arg2)
    @ccall libsqlite.sqlite3_value_pointer(
        arg1::Ptr{sqlite3_value},
        arg2::Ptr{Cchar},
    )::Ptr{Cvoid}
end

function sqlite3_value_text(arg1)
    @ccall libsqlite.sqlite3_value_text(arg1::Ptr{sqlite3_value})::Ptr{Cuchar}
end

function sqlite3_value_text16(arg1)
    @ccall libsqlite.sqlite3_value_text16(arg1::Ptr{sqlite3_value})::Ptr{Cvoid}
end

function sqlite3_value_text16le(arg1)
    @ccall libsqlite.sqlite3_value_text16le(
        arg1::Ptr{sqlite3_value},
    )::Ptr{Cvoid}
end

function sqlite3_value_text16be(arg1)
    @ccall libsqlite.sqlite3_value_text16be(
        arg1::Ptr{sqlite3_value},
    )::Ptr{Cvoid}
end

function sqlite3_value_bytes(arg1)
    @ccall libsqlite.sqlite3_value_bytes(arg1::Ptr{sqlite3_value})::Cint
end

function sqlite3_value_bytes16(arg1)
    @ccall libsqlite.sqlite3_value_bytes16(arg1::Ptr{sqlite3_value})::Cint
end

function sqlite3_value_type(arg1)
    @ccall libsqlite.sqlite3_value_type(arg1::Ptr{sqlite3_value})::Cint
end

function sqlite3_value_numeric_type(arg1)
    @ccall libsqlite.sqlite3_value_numeric_type(arg1::Ptr{sqlite3_value})::Cint
end

function sqlite3_value_nochange(arg1)
    @ccall libsqlite.sqlite3_value_nochange(arg1::Ptr{sqlite3_value})::Cint
end

function sqlite3_value_frombind(arg1)
    @ccall libsqlite.sqlite3_value_frombind(arg1::Ptr{sqlite3_value})::Cint
end

function sqlite3_value_encoding(arg1)
    @ccall libsqlite.sqlite3_value_encoding(arg1::Ptr{sqlite3_value})::Cint
end

function sqlite3_value_subtype(arg1)
    @ccall libsqlite.sqlite3_value_subtype(arg1::Ptr{sqlite3_value})::Cuint
end

function sqlite3_value_dup(arg1)
    @ccall libsqlite.sqlite3_value_dup(
        arg1::Ptr{sqlite3_value},
    )::Ptr{sqlite3_value}
end

function sqlite3_value_free(arg1)
    @ccall libsqlite.sqlite3_value_free(arg1::Ptr{sqlite3_value})::Cvoid
end

function sqlite3_aggregate_context(arg1, nBytes)
    @ccall libsqlite.sqlite3_aggregate_context(
        arg1::Ptr{sqlite3_context},
        nBytes::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_user_data(arg1)
    @ccall libsqlite.sqlite3_user_data(arg1::Ptr{sqlite3_context})::Ptr{Cvoid}
end

function sqlite3_context_db_handle(arg1)
    @ccall libsqlite.sqlite3_context_db_handle(
        arg1::Ptr{sqlite3_context},
    )::Ptr{sqlite3}
end

function sqlite3_get_auxdata(arg1, N)
    @ccall libsqlite.sqlite3_get_auxdata(
        arg1::Ptr{sqlite3_context},
        N::Cint,
    )::Ptr{Cvoid}
end

function sqlite3_set_auxdata(arg1, N, arg3, arg4)
    @ccall libsqlite.sqlite3_set_auxdata(
        arg1::Ptr{sqlite3_context},
        N::Cint,
        arg3::Ptr{Cvoid},
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_result_blob(arg1, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_result_blob(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cvoid},
        arg3::Cint,
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_result_blob64(arg1, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_result_blob64(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cvoid},
        arg3::sqlite3_uint64,
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_result_double(arg1, arg2)
    @ccall libsqlite.sqlite3_result_double(
        arg1::Ptr{sqlite3_context},
        arg2::Cdouble,
    )::Cvoid
end

function sqlite3_result_error(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_result_error(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cchar},
        arg3::Cint,
    )::Cvoid
end

function sqlite3_result_error16(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_result_error16(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cvoid},
        arg3::Cint,
    )::Cvoid
end

function sqlite3_result_error_toobig(arg1)
    @ccall libsqlite.sqlite3_result_error_toobig(
        arg1::Ptr{sqlite3_context},
    )::Cvoid
end

function sqlite3_result_error_nomem(arg1)
    @ccall libsqlite.sqlite3_result_error_nomem(
        arg1::Ptr{sqlite3_context},
    )::Cvoid
end

function sqlite3_result_error_code(arg1, arg2)
    @ccall libsqlite.sqlite3_result_error_code(
        arg1::Ptr{sqlite3_context},
        arg2::Cint,
    )::Cvoid
end

function sqlite3_result_int(arg1, arg2)
    @ccall libsqlite.sqlite3_result_int(
        arg1::Ptr{sqlite3_context},
        arg2::Cint,
    )::Cvoid
end

function sqlite3_result_int64(arg1, arg2)
    @ccall libsqlite.sqlite3_result_int64(
        arg1::Ptr{sqlite3_context},
        arg2::sqlite3_int64,
    )::Cvoid
end

function sqlite3_result_null(arg1)
    @ccall libsqlite.sqlite3_result_null(arg1::Ptr{sqlite3_context})::Cvoid
end

function sqlite3_result_text(arg1, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_result_text(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cchar},
        arg3::Cint,
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_result_text64(arg1, arg2, arg3, arg4, encoding)
    @ccall libsqlite.sqlite3_result_text64(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cchar},
        arg3::sqlite3_uint64,
        arg4::Ptr{Cvoid},
        encoding::Cuchar,
    )::Cvoid
end

function sqlite3_result_text16(arg1, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_result_text16(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cvoid},
        arg3::Cint,
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_result_text16le(arg1, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_result_text16le(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cvoid},
        arg3::Cint,
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_result_text16be(arg1, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_result_text16be(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cvoid},
        arg3::Cint,
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_result_value(arg1, arg2)
    @ccall libsqlite.sqlite3_result_value(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{sqlite3_value},
    )::Cvoid
end

function sqlite3_result_pointer(arg1, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_result_pointer(
        arg1::Ptr{sqlite3_context},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cchar},
        arg4::Ptr{Cvoid},
    )::Cvoid
end

function sqlite3_result_zeroblob(arg1, n)
    @ccall libsqlite.sqlite3_result_zeroblob(
        arg1::Ptr{sqlite3_context},
        n::Cint,
    )::Cvoid
end

function sqlite3_result_zeroblob64(arg1, n)
    @ccall libsqlite.sqlite3_result_zeroblob64(
        arg1::Ptr{sqlite3_context},
        n::sqlite3_uint64,
    )::Cint
end

function sqlite3_result_subtype(arg1, arg2)
    @ccall libsqlite.sqlite3_result_subtype(
        arg1::Ptr{sqlite3_context},
        arg2::Cuint,
    )::Cvoid
end

function sqlite3_create_collation(arg1, zName, eTextRep, pArg, xCompare)
    @ccall libsqlite.sqlite3_create_collation(
        arg1::Ptr{sqlite3},
        zName::Ptr{Cchar},
        eTextRep::Cint,
        pArg::Ptr{Cvoid},
        xCompare::Ptr{Cvoid},
    )::Cint
end

function sqlite3_create_collation_v2(
    arg1,
    zName,
    eTextRep,
    pArg,
    xCompare,
    xDestroy,
)
    @ccall libsqlite.sqlite3_create_collation_v2(
        arg1::Ptr{sqlite3},
        zName::Ptr{Cchar},
        eTextRep::Cint,
        pArg::Ptr{Cvoid},
        xCompare::Ptr{Cvoid},
        xDestroy::Ptr{Cvoid},
    )::Cint
end

function sqlite3_create_collation16(arg1, zName, eTextRep, pArg, xCompare)
    @ccall libsqlite.sqlite3_create_collation16(
        arg1::Ptr{sqlite3},
        zName::Ptr{Cvoid},
        eTextRep::Cint,
        pArg::Ptr{Cvoid},
        xCompare::Ptr{Cvoid},
    )::Cint
end

function sqlite3_collation_needed(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_collation_needed(
        arg1::Ptr{sqlite3},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Cint
end

function sqlite3_collation_needed16(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_collation_needed16(
        arg1::Ptr{sqlite3},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Cint
end

function sqlite3_sleep(arg1)
    @ccall libsqlite.sqlite3_sleep(arg1::Cint)::Cint
end

function sqlite3_win32_set_directory(type, zValue)
    @ccall libsqlite.sqlite3_win32_set_directory(
        type::Culong,
        zValue::Ptr{Cvoid},
    )::Cint
end

function sqlite3_win32_set_directory8(type, zValue)
    @ccall libsqlite.sqlite3_win32_set_directory8(
        type::Culong,
        zValue::Ptr{Cchar},
    )::Cint
end

function sqlite3_win32_set_directory16(type, zValue)
    @ccall libsqlite.sqlite3_win32_set_directory16(
        type::Culong,
        zValue::Ptr{Cvoid},
    )::Cint
end

function sqlite3_get_autocommit(arg1)
    @ccall libsqlite.sqlite3_get_autocommit(arg1::Ptr{sqlite3})::Cint
end

function sqlite3_db_handle(arg1)
    @ccall libsqlite.sqlite3_db_handle(arg1::Ptr{sqlite3_stmt})::Ptr{sqlite3}
end

function sqlite3_db_name(db, N)
    @ccall libsqlite.sqlite3_db_name(db::Ptr{sqlite3}, N::Cint)::Ptr{Cchar}
end

function sqlite3_db_filename(db, zDbName)
    @ccall libsqlite.sqlite3_db_filename(
        db::Ptr{sqlite3},
        zDbName::Ptr{Cchar},
    )::sqlite3_filename
end

function sqlite3_db_readonly(db, zDbName)
    @ccall libsqlite.sqlite3_db_readonly(
        db::Ptr{sqlite3},
        zDbName::Ptr{Cchar},
    )::Cint
end

function sqlite3_txn_state(arg1, zSchema)
    @ccall libsqlite.sqlite3_txn_state(
        arg1::Ptr{sqlite3},
        zSchema::Ptr{Cchar},
    )::Cint
end

function sqlite3_next_stmt(pDb, pStmt)
    @ccall libsqlite.sqlite3_next_stmt(
        pDb::Ptr{sqlite3},
        pStmt::Ptr{sqlite3_stmt},
    )::Ptr{sqlite3_stmt}
end

function sqlite3_commit_hook(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_commit_hook(
        arg1::Ptr{sqlite3},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Ptr{Cvoid}
end

function sqlite3_rollback_hook(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_rollback_hook(
        arg1::Ptr{sqlite3},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Ptr{Cvoid}
end

function sqlite3_autovacuum_pages(db, arg2, arg3, arg4)
    @ccall libsqlite.sqlite3_autovacuum_pages(
        db::Ptr{sqlite3},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
        arg4::Ptr{Cvoid},
    )::Cint
end

function sqlite3_update_hook(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_update_hook(
        arg1::Ptr{sqlite3},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Ptr{Cvoid}
end

function sqlite3_enable_shared_cache(arg1)
    @ccall libsqlite.sqlite3_enable_shared_cache(arg1::Cint)::Cint
end

function sqlite3_release_memory(arg1)
    @ccall libsqlite.sqlite3_release_memory(arg1::Cint)::Cint
end

function sqlite3_db_release_memory(arg1)
    @ccall libsqlite.sqlite3_db_release_memory(arg1::Ptr{sqlite3})::Cint
end

function sqlite3_soft_heap_limit64(N)
    @ccall libsqlite.sqlite3_soft_heap_limit64(N::sqlite3_int64)::sqlite3_int64
end

function sqlite3_hard_heap_limit64(N)
    @ccall libsqlite.sqlite3_hard_heap_limit64(N::sqlite3_int64)::sqlite3_int64
end

function sqlite3_soft_heap_limit(N)
    @ccall libsqlite.sqlite3_soft_heap_limit(N::Cint)::Cvoid
end

function sqlite3_table_column_metadata(
    db,
    zDbName,
    zTableName,
    zColumnName,
    pzDataType,
    pzCollSeq,
    pNotNull,
    pPrimaryKey,
    pAutoinc,
)
    @ccall libsqlite.sqlite3_table_column_metadata(
        db::Ptr{sqlite3},
        zDbName::Ptr{Cchar},
        zTableName::Ptr{Cchar},
        zColumnName::Ptr{Cchar},
        pzDataType::Ptr{Ptr{Cchar}},
        pzCollSeq::Ptr{Ptr{Cchar}},
        pNotNull::Ptr{Cint},
        pPrimaryKey::Ptr{Cint},
        pAutoinc::Ptr{Cint},
    )::Cint
end

function sqlite3_load_extension(db, zFile, zProc, pzErrMsg)
    @ccall libsqlite.sqlite3_load_extension(
        db::Ptr{sqlite3},
        zFile::Ptr{Cchar},
        zProc::Ptr{Cchar},
        pzErrMsg::Ptr{Ptr{Cchar}},
    )::Cint
end

function sqlite3_enable_load_extension(db, onoff)
    @ccall libsqlite.sqlite3_enable_load_extension(
        db::Ptr{sqlite3},
        onoff::Cint,
    )::Cint
end

function sqlite3_auto_extension(xEntryPoint)
    @ccall libsqlite.sqlite3_auto_extension(xEntryPoint::Ptr{Cvoid})::Cint
end

function sqlite3_cancel_auto_extension(xEntryPoint)
    @ccall libsqlite.sqlite3_cancel_auto_extension(
        xEntryPoint::Ptr{Cvoid},
    )::Cint
end

function sqlite3_reset_auto_extension()
    @ccall libsqlite.sqlite3_reset_auto_extension()::Cvoid
end

struct sqlite3_module
    iVersion::Cint
    xCreate::Ptr{Cvoid}
    xConnect::Ptr{Cvoid}
    xBestIndex::Ptr{Cvoid}
    xDisconnect::Ptr{Cvoid}
    xDestroy::Ptr{Cvoid}
    xOpen::Ptr{Cvoid}
    xClose::Ptr{Cvoid}
    xFilter::Ptr{Cvoid}
    xNext::Ptr{Cvoid}
    xEof::Ptr{Cvoid}
    xColumn::Ptr{Cvoid}
    xRowid::Ptr{Cvoid}
    xUpdate::Ptr{Cvoid}
    xBegin::Ptr{Cvoid}
    xSync::Ptr{Cvoid}
    xCommit::Ptr{Cvoid}
    xRollback::Ptr{Cvoid}
    xFindFunction::Ptr{Cvoid}
    xRename::Ptr{Cvoid}
    xSavepoint::Ptr{Cvoid}
    xRelease::Ptr{Cvoid}
    xRollbackTo::Ptr{Cvoid}
    xShadowName::Ptr{Cvoid}
end

struct sqlite3_vtab
    pModule::Ptr{sqlite3_module}
    nRef::Cint
    zErrMsg::Ptr{Cchar}
end

struct sqlite3_index_constraint
    iColumn::Cint
    op::Cuchar
    usable::Cuchar
    iTermOffset::Cint
end

struct sqlite3_index_orderby
    iColumn::Cint
    desc::Cuchar
end

struct sqlite3_index_constraint_usage
    argvIndex::Cint
    omit::Cuchar
end

struct sqlite3_index_info
    nConstraint::Cint
    aConstraint::Ptr{sqlite3_index_constraint}
    nOrderBy::Cint
    aOrderBy::Ptr{sqlite3_index_orderby}
    aConstraintUsage::Ptr{sqlite3_index_constraint_usage}
    idxNum::Cint
    idxStr::Ptr{Cchar}
    needToFreeIdxStr::Cint
    orderByConsumed::Cint
    estimatedCost::Cdouble
    estimatedRows::sqlite3_int64
    idxFlags::Cint
    colUsed::sqlite3_uint64
end

struct sqlite3_vtab_cursor
    pVtab::Ptr{sqlite3_vtab}
end

function sqlite3_create_module(db, zName, p, pClientData)
    @ccall libsqlite.sqlite3_create_module(
        db::Ptr{sqlite3},
        zName::Ptr{Cchar},
        p::Ptr{sqlite3_module},
        pClientData::Ptr{Cvoid},
    )::Cint
end

function sqlite3_create_module_v2(db, zName, p, pClientData, xDestroy)
    @ccall libsqlite.sqlite3_create_module_v2(
        db::Ptr{sqlite3},
        zName::Ptr{Cchar},
        p::Ptr{sqlite3_module},
        pClientData::Ptr{Cvoid},
        xDestroy::Ptr{Cvoid},
    )::Cint
end

function sqlite3_drop_modules(db, azKeep)
    @ccall libsqlite.sqlite3_drop_modules(
        db::Ptr{sqlite3},
        azKeep::Ptr{Ptr{Cchar}},
    )::Cint
end

function sqlite3_declare_vtab(arg1, zSQL)
    @ccall libsqlite.sqlite3_declare_vtab(
        arg1::Ptr{sqlite3},
        zSQL::Ptr{Cchar},
    )::Cint
end

function sqlite3_overload_function(arg1, zFuncName, nArg)
    @ccall libsqlite.sqlite3_overload_function(
        arg1::Ptr{sqlite3},
        zFuncName::Ptr{Cchar},
        nArg::Cint,
    )::Cint
end

mutable struct sqlite3_blob end

function sqlite3_blob_open(arg1, zDb, zTable, zColumn, iRow, flags, ppBlob)
    @ccall libsqlite.sqlite3_blob_open(
        arg1::Ptr{sqlite3},
        zDb::Ptr{Cchar},
        zTable::Ptr{Cchar},
        zColumn::Ptr{Cchar},
        iRow::sqlite3_int64,
        flags::Cint,
        ppBlob::Ptr{Ptr{sqlite3_blob}},
    )::Cint
end

function sqlite3_blob_reopen(arg1, arg2)
    @ccall libsqlite.sqlite3_blob_reopen(
        arg1::Ptr{sqlite3_blob},
        arg2::sqlite3_int64,
    )::Cint
end

function sqlite3_blob_close(arg1)
    @ccall libsqlite.sqlite3_blob_close(arg1::Ptr{sqlite3_blob})::Cint
end

function sqlite3_blob_bytes(arg1)
    @ccall libsqlite.sqlite3_blob_bytes(arg1::Ptr{sqlite3_blob})::Cint
end

function sqlite3_blob_read(arg1, Z, N, iOffset)
    @ccall libsqlite.sqlite3_blob_read(
        arg1::Ptr{sqlite3_blob},
        Z::Ptr{Cvoid},
        N::Cint,
        iOffset::Cint,
    )::Cint
end

function sqlite3_blob_write(arg1, z, n, iOffset)
    @ccall libsqlite.sqlite3_blob_write(
        arg1::Ptr{sqlite3_blob},
        z::Ptr{Cvoid},
        n::Cint,
        iOffset::Cint,
    )::Cint
end

function sqlite3_vfs_find(zVfsName)
    @ccall libsqlite.sqlite3_vfs_find(zVfsName::Ptr{Cchar})::Ptr{sqlite3_vfs}
end

function sqlite3_vfs_register(arg1, makeDflt)
    @ccall libsqlite.sqlite3_vfs_register(
        arg1::Ptr{sqlite3_vfs},
        makeDflt::Cint,
    )::Cint
end

function sqlite3_vfs_unregister(arg1)
    @ccall libsqlite.sqlite3_vfs_unregister(arg1::Ptr{sqlite3_vfs})::Cint
end

function sqlite3_mutex_alloc(arg1)
    @ccall libsqlite.sqlite3_mutex_alloc(arg1::Cint)::Ptr{sqlite3_mutex}
end

function sqlite3_mutex_free(arg1)
    @ccall libsqlite.sqlite3_mutex_free(arg1::Ptr{sqlite3_mutex})::Cvoid
end

function sqlite3_mutex_enter(arg1)
    @ccall libsqlite.sqlite3_mutex_enter(arg1::Ptr{sqlite3_mutex})::Cvoid
end

function sqlite3_mutex_try(arg1)
    @ccall libsqlite.sqlite3_mutex_try(arg1::Ptr{sqlite3_mutex})::Cint
end

function sqlite3_mutex_leave(arg1)
    @ccall libsqlite.sqlite3_mutex_leave(arg1::Ptr{sqlite3_mutex})::Cvoid
end

struct sqlite3_mutex_methods
    xMutexInit::Ptr{Cvoid}
    xMutexEnd::Ptr{Cvoid}
    xMutexAlloc::Ptr{Cvoid}
    xMutexFree::Ptr{Cvoid}
    xMutexEnter::Ptr{Cvoid}
    xMutexTry::Ptr{Cvoid}
    xMutexLeave::Ptr{Cvoid}
    xMutexHeld::Ptr{Cvoid}
    xMutexNotheld::Ptr{Cvoid}
end

function sqlite3_mutex_held(arg1)
    @ccall libsqlite.sqlite3_mutex_held(arg1::Ptr{sqlite3_mutex})::Cint
end

function sqlite3_mutex_notheld(arg1)
    @ccall libsqlite.sqlite3_mutex_notheld(arg1::Ptr{sqlite3_mutex})::Cint
end

function sqlite3_db_mutex(arg1)
    @ccall libsqlite.sqlite3_db_mutex(arg1::Ptr{sqlite3})::Ptr{sqlite3_mutex}
end

function sqlite3_file_control(arg1, zDbName, op, arg4)
    @ccall libsqlite.sqlite3_file_control(
        arg1::Ptr{sqlite3},
        zDbName::Ptr{Cchar},
        op::Cint,
        arg4::Ptr{Cvoid},
    )::Cint
end

function sqlite3_keyword_count()
    @ccall libsqlite.sqlite3_keyword_count()::Cint
end

function sqlite3_keyword_name(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_keyword_name(
        arg1::Cint,
        arg2::Ptr{Ptr{Cchar}},
        arg3::Ptr{Cint},
    )::Cint
end

function sqlite3_keyword_check(arg1, arg2)
    @ccall libsqlite.sqlite3_keyword_check(arg1::Ptr{Cchar}, arg2::Cint)::Cint
end

mutable struct sqlite3_str end

function sqlite3_str_new(arg1)
    @ccall libsqlite.sqlite3_str_new(arg1::Ptr{sqlite3})::Ptr{sqlite3_str}
end

function sqlite3_str_finish(arg1)
    @ccall libsqlite.sqlite3_str_finish(arg1::Ptr{sqlite3_str})::Ptr{Cchar}
end

function sqlite3_str_append(arg1, zIn, N)
    @ccall libsqlite.sqlite3_str_append(
        arg1::Ptr{sqlite3_str},
        zIn::Ptr{Cchar},
        N::Cint,
    )::Cvoid
end

function sqlite3_str_appendall(arg1, zIn)
    @ccall libsqlite.sqlite3_str_appendall(
        arg1::Ptr{sqlite3_str},
        zIn::Ptr{Cchar},
    )::Cvoid
end

function sqlite3_str_appendchar(arg1, N, C)
    @ccall libsqlite.sqlite3_str_appendchar(
        arg1::Ptr{sqlite3_str},
        N::Cint,
        C::Cchar,
    )::Cvoid
end

function sqlite3_str_reset(arg1)
    @ccall libsqlite.sqlite3_str_reset(arg1::Ptr{sqlite3_str})::Cvoid
end

function sqlite3_str_errcode(arg1)
    @ccall libsqlite.sqlite3_str_errcode(arg1::Ptr{sqlite3_str})::Cint
end

function sqlite3_str_length(arg1)
    @ccall libsqlite.sqlite3_str_length(arg1::Ptr{sqlite3_str})::Cint
end

function sqlite3_str_value(arg1)
    @ccall libsqlite.sqlite3_str_value(arg1::Ptr{sqlite3_str})::Ptr{Cchar}
end

function sqlite3_status(op, pCurrent, pHighwater, resetFlag)
    @ccall libsqlite.sqlite3_status(
        op::Cint,
        pCurrent::Ptr{Cint},
        pHighwater::Ptr{Cint},
        resetFlag::Cint,
    )::Cint
end

function sqlite3_status64(op, pCurrent, pHighwater, resetFlag)
    @ccall libsqlite.sqlite3_status64(
        op::Cint,
        pCurrent::Ptr{sqlite3_int64},
        pHighwater::Ptr{sqlite3_int64},
        resetFlag::Cint,
    )::Cint
end

function sqlite3_db_status(arg1, op, pCur, pHiwtr, resetFlg)
    @ccall libsqlite.sqlite3_db_status(
        arg1::Ptr{sqlite3},
        op::Cint,
        pCur::Ptr{Cint},
        pHiwtr::Ptr{Cint},
        resetFlg::Cint,
    )::Cint
end

function sqlite3_stmt_status(arg1, op, resetFlg)
    @ccall libsqlite.sqlite3_stmt_status(
        arg1::Ptr{sqlite3_stmt},
        op::Cint,
        resetFlg::Cint,
    )::Cint
end

mutable struct sqlite3_pcache end

struct sqlite3_pcache_page
    pBuf::Ptr{Cvoid}
    pExtra::Ptr{Cvoid}
end

struct sqlite3_pcache_methods2
    iVersion::Cint
    pArg::Ptr{Cvoid}
    xInit::Ptr{Cvoid}
    xShutdown::Ptr{Cvoid}
    xCreate::Ptr{Cvoid}
    xCachesize::Ptr{Cvoid}
    xPagecount::Ptr{Cvoid}
    xFetch::Ptr{Cvoid}
    xUnpin::Ptr{Cvoid}
    xRekey::Ptr{Cvoid}
    xTruncate::Ptr{Cvoid}
    xDestroy::Ptr{Cvoid}
    xShrink::Ptr{Cvoid}
end

struct sqlite3_pcache_methods
    pArg::Ptr{Cvoid}
    xInit::Ptr{Cvoid}
    xShutdown::Ptr{Cvoid}
    xCreate::Ptr{Cvoid}
    xCachesize::Ptr{Cvoid}
    xPagecount::Ptr{Cvoid}
    xFetch::Ptr{Cvoid}
    xUnpin::Ptr{Cvoid}
    xRekey::Ptr{Cvoid}
    xTruncate::Ptr{Cvoid}
    xDestroy::Ptr{Cvoid}
end

mutable struct sqlite3_backup end

function sqlite3_backup_init(pDest, zDestName, pSource, zSourceName)
    @ccall libsqlite.sqlite3_backup_init(
        pDest::Ptr{sqlite3},
        zDestName::Ptr{Cchar},
        pSource::Ptr{sqlite3},
        zSourceName::Ptr{Cchar},
    )::Ptr{sqlite3_backup}
end

function sqlite3_backup_step(p, nPage)
    @ccall libsqlite.sqlite3_backup_step(
        p::Ptr{sqlite3_backup},
        nPage::Cint,
    )::Cint
end

function sqlite3_backup_finish(p)
    @ccall libsqlite.sqlite3_backup_finish(p::Ptr{sqlite3_backup})::Cint
end

function sqlite3_backup_remaining(p)
    @ccall libsqlite.sqlite3_backup_remaining(p::Ptr{sqlite3_backup})::Cint
end

function sqlite3_backup_pagecount(p)
    @ccall libsqlite.sqlite3_backup_pagecount(p::Ptr{sqlite3_backup})::Cint
end

function sqlite3_unlock_notify(pBlocked, xNotify, pNotifyArg)
    @ccall libsqlite.sqlite3_unlock_notify(
        pBlocked::Ptr{sqlite3},
        xNotify::Ptr{Cvoid},
        pNotifyArg::Ptr{Cvoid},
    )::Cint
end

function sqlite3_stricmp(arg1, arg2)
    @ccall libsqlite.sqlite3_stricmp(arg1::Ptr{Cchar}, arg2::Ptr{Cchar})::Cint
end

function sqlite3_strnicmp(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_strnicmp(
        arg1::Ptr{Cchar},
        arg2::Ptr{Cchar},
        arg3::Cint,
    )::Cint
end

function sqlite3_strglob(zGlob, zStr)
    @ccall libsqlite.sqlite3_strglob(zGlob::Ptr{Cchar}, zStr::Ptr{Cchar})::Cint
end

function sqlite3_strlike(zGlob, zStr, cEsc)
    @ccall libsqlite.sqlite3_strlike(
        zGlob::Ptr{Cchar},
        zStr::Ptr{Cchar},
        cEsc::Cuint,
    )::Cint
end

function sqlite3_wal_hook(arg1, arg2, arg3)
    @ccall libsqlite.sqlite3_wal_hook(
        arg1::Ptr{sqlite3},
        arg2::Ptr{Cvoid},
        arg3::Ptr{Cvoid},
    )::Ptr{Cvoid}
end

function sqlite3_wal_autocheckpoint(db, N)
    @ccall libsqlite.sqlite3_wal_autocheckpoint(db::Ptr{sqlite3}, N::Cint)::Cint
end

function sqlite3_wal_checkpoint(db, zDb)
    @ccall libsqlite.sqlite3_wal_checkpoint(
        db::Ptr{sqlite3},
        zDb::Ptr{Cchar},
    )::Cint
end

function sqlite3_wal_checkpoint_v2(db, zDb, eMode, pnLog, pnCkpt)
    @ccall libsqlite.sqlite3_wal_checkpoint_v2(
        db::Ptr{sqlite3},
        zDb::Ptr{Cchar},
        eMode::Cint,
        pnLog::Ptr{Cint},
        pnCkpt::Ptr{Cint},
    )::Cint
end

function sqlite3_vtab_on_conflict(arg1)
    @ccall libsqlite.sqlite3_vtab_on_conflict(arg1::Ptr{sqlite3})::Cint
end

function sqlite3_vtab_nochange(arg1)
    @ccall libsqlite.sqlite3_vtab_nochange(arg1::Ptr{sqlite3_context})::Cint
end

function sqlite3_vtab_collation(arg1, arg2)
    @ccall libsqlite.sqlite3_vtab_collation(
        arg1::Ptr{sqlite3_index_info},
        arg2::Cint,
    )::Ptr{Cchar}
end

function sqlite3_vtab_distinct(arg1)
    @ccall libsqlite.sqlite3_vtab_distinct(arg1::Ptr{sqlite3_index_info})::Cint
end

function sqlite3_vtab_in(arg1, iCons, bHandle)
    @ccall libsqlite.sqlite3_vtab_in(
        arg1::Ptr{sqlite3_index_info},
        iCons::Cint,
        bHandle::Cint,
    )::Cint
end

function sqlite3_vtab_in_first(pVal, ppOut)
    @ccall libsqlite.sqlite3_vtab_in_first(
        pVal::Ptr{sqlite3_value},
        ppOut::Ptr{Ptr{sqlite3_value}},
    )::Cint
end

function sqlite3_vtab_in_next(pVal, ppOut)
    @ccall libsqlite.sqlite3_vtab_in_next(
        pVal::Ptr{sqlite3_value},
        ppOut::Ptr{Ptr{sqlite3_value}},
    )::Cint
end

function sqlite3_vtab_rhs_value(arg1, arg2, ppVal)
    @ccall libsqlite.sqlite3_vtab_rhs_value(
        arg1::Ptr{sqlite3_index_info},
        arg2::Cint,
        ppVal::Ptr{Ptr{sqlite3_value}},
    )::Cint
end

function sqlite3_stmt_scanstatus(pStmt, idx, iScanStatusOp, pOut)
    @ccall libsqlite.sqlite3_stmt_scanstatus(
        pStmt::Ptr{sqlite3_stmt},
        idx::Cint,
        iScanStatusOp::Cint,
        pOut::Ptr{Cvoid},
    )::Cint
end

function sqlite3_stmt_scanstatus_reset(arg1)
    @ccall libsqlite.sqlite3_stmt_scanstatus_reset(
        arg1::Ptr{sqlite3_stmt},
    )::Cvoid
end

function sqlite3_db_cacheflush(arg1)
    @ccall libsqlite.sqlite3_db_cacheflush(arg1::Ptr{sqlite3})::Cint
end

function sqlite3_system_errno(arg1)
    @ccall libsqlite.sqlite3_system_errno(arg1::Ptr{sqlite3})::Cint
end

struct sqlite3_snapshot
    hidden::NTuple{48,Cuchar}
end

function sqlite3_snapshot_get(db, zSchema, ppSnapshot)
    @ccall libsqlite.sqlite3_snapshot_get(
        db::Ptr{sqlite3},
        zSchema::Ptr{Cchar},
        ppSnapshot::Ptr{Ptr{sqlite3_snapshot}},
    )::Cint
end

function sqlite3_snapshot_open(db, zSchema, pSnapshot)
    @ccall libsqlite.sqlite3_snapshot_open(
        db::Ptr{sqlite3},
        zSchema::Ptr{Cchar},
        pSnapshot::Ptr{sqlite3_snapshot},
    )::Cint
end

function sqlite3_snapshot_free(arg1)
    @ccall libsqlite.sqlite3_snapshot_free(arg1::Ptr{sqlite3_snapshot})::Cvoid
end

function sqlite3_snapshot_cmp(p1, p2)
    @ccall libsqlite.sqlite3_snapshot_cmp(
        p1::Ptr{sqlite3_snapshot},
        p2::Ptr{sqlite3_snapshot},
    )::Cint
end

function sqlite3_snapshot_recover(db, zDb)
    @ccall libsqlite.sqlite3_snapshot_recover(
        db::Ptr{sqlite3},
        zDb::Ptr{Cchar},
    )::Cint
end

function sqlite3_serialize(db, zSchema, piSize, mFlags)
    @ccall libsqlite.sqlite3_serialize(
        db::Ptr{sqlite3},
        zSchema::Ptr{Cchar},
        piSize::Ptr{sqlite3_int64},
        mFlags::Cuint,
    )::Ptr{Cuchar}
end

function sqlite3_deserialize(db, zSchema, pData, szDb, szBuf, mFlags)
    @ccall libsqlite.sqlite3_deserialize(
        db::Ptr{sqlite3},
        zSchema::Ptr{Cchar},
        pData::Ptr{Cuchar},
        szDb::sqlite3_int64,
        szBuf::sqlite3_int64,
        mFlags::Cuint,
    )::Cint
end

const sqlite3_rtree_dbl = Cdouble

struct sqlite3_rtree_geometry
    pContext::Ptr{Cvoid}
    nParam::Cint
    aParam::Ptr{sqlite3_rtree_dbl}
    pUser::Ptr{Cvoid}
    xDelUser::Ptr{Cvoid}
end

struct sqlite3_rtree_query_info
    pContext::Ptr{Cvoid}
    nParam::Cint
    aParam::Ptr{sqlite3_rtree_dbl}
    pUser::Ptr{Cvoid}
    xDelUser::Ptr{Cvoid}
    aCoord::Ptr{sqlite3_rtree_dbl}
    anQueue::Ptr{Cuint}
    nCoord::Cint
    iLevel::Cint
    mxLevel::Cint
    iRowid::sqlite3_int64
    rParentScore::sqlite3_rtree_dbl
    eParentWithin::Cint
    eWithin::Cint
    rScore::sqlite3_rtree_dbl
    apSqlParam::Ptr{Ptr{sqlite3_value}}
end

function sqlite3_rtree_geometry_callback(db, zGeom, xGeom, pContext)
    @ccall libsqlite.sqlite3_rtree_geometry_callback(
        db::Ptr{sqlite3},
        zGeom::Ptr{Cchar},
        xGeom::Ptr{Cvoid},
        pContext::Ptr{Cvoid},
    )::Cint
end

function sqlite3_rtree_query_callback(
    db,
    zQueryFunc,
    xQueryFunc,
    pContext,
    xDestructor,
)
    @ccall libsqlite.sqlite3_rtree_query_callback(
        db::Ptr{sqlite3},
        zQueryFunc::Ptr{Cchar},
        xQueryFunc::Ptr{Cvoid},
        pContext::Ptr{Cvoid},
        xDestructor::Ptr{Cvoid},
    )::Cint
end

struct Fts5ExtensionApi
    iVersion::Cint
    xUserData::Ptr{Cvoid}
    xColumnCount::Ptr{Cvoid}
    xRowCount::Ptr{Cvoid}
    xColumnTotalSize::Ptr{Cvoid}
    xTokenize::Ptr{Cvoid}
    xPhraseCount::Ptr{Cvoid}
    xPhraseSize::Ptr{Cvoid}
    xInstCount::Ptr{Cvoid}
    xInst::Ptr{Cvoid}
    xRowid::Ptr{Cvoid}
    xColumnText::Ptr{Cvoid}
    xColumnSize::Ptr{Cvoid}
    xQueryPhrase::Ptr{Cvoid}
    xSetAuxdata::Ptr{Cvoid}
    xGetAuxdata::Ptr{Cvoid}
    xPhraseFirst::Ptr{Cvoid}
    xPhraseNext::Ptr{Cvoid}
    xPhraseFirstColumn::Ptr{Cvoid}
    xPhraseNextColumn::Ptr{Cvoid}
end

mutable struct Fts5Context end

struct Fts5PhraseIter
    a::Ptr{Cuchar}
    b::Ptr{Cuchar}
end

# typedef void ( * fts5_extension_function ) ( const Fts5ExtensionApi * pApi , /* API offered by current FTS version */ Fts5Context * pFts , /* First arg to pass to pApi functions */ sqlite3_context * pCtx , /* Context for returning result/error */ int nVal , /* Number of values in apVal[] array */ sqlite3_value * * apVal /* Array of trailing arguments */ )
const fts5_extension_function = Ptr{Cvoid}

mutable struct Fts5Tokenizer end

struct fts5_tokenizer
    xCreate::Ptr{Cvoid}
    xDelete::Ptr{Cvoid}
    xTokenize::Ptr{Cvoid}
end

struct fts5_api
    iVersion::Cint
    xCreateTokenizer::Ptr{Cvoid}
    xFindTokenizer::Ptr{Cvoid}
    xCreateFunction::Ptr{Cvoid}
end

# Skipping MacroDefinition: SQLITE_EXTERN extern

const SQLITE_VERSION = "3.40.0"

const SQLITE_VERSION_NUMBER = 3040000

const SQLITE_SOURCE_ID = "2022-11-16 12:10:08 89c459e766ea7e9165d0beeb124708b955a4950d0f4792f457465d71b158d318"

const SQLITE_OK = 0

const SQLITE_ERROR = 1

const SQLITE_INTERNAL = 2

const SQLITE_PERM = 3

const SQLITE_ABORT = 4

const SQLITE_BUSY = 5

const SQLITE_LOCKED = 6

const SQLITE_NOMEM = 7

const SQLITE_READONLY = 8

const SQLITE_INTERRUPT = 9

const SQLITE_IOERR = 10

const SQLITE_CORRUPT = 11

const SQLITE_NOTFOUND = 12

const SQLITE_FULL = 13

const SQLITE_CANTOPEN = 14

const SQLITE_PROTOCOL = 15

const SQLITE_EMPTY = 16

const SQLITE_SCHEMA = 17

const SQLITE_TOOBIG = 18

const SQLITE_CONSTRAINT = 19

const SQLITE_MISMATCH = 20

const SQLITE_MISUSE = 21

const SQLITE_NOLFS = 22

const SQLITE_AUTH = 23

const SQLITE_FORMAT = 24

const SQLITE_RANGE = 25

const SQLITE_NOTADB = 26

const SQLITE_NOTICE = 27

const SQLITE_WARNING = 28

const SQLITE_ROW = 100

const SQLITE_DONE = 101

const SQLITE_ERROR_MISSING_COLLSEQ = SQLITE_ERROR | 1 << 8

const SQLITE_ERROR_RETRY = SQLITE_ERROR | 2 << 8

const SQLITE_ERROR_SNAPSHOT = SQLITE_ERROR | 3 << 8

const SQLITE_IOERR_READ = SQLITE_IOERR | 1 << 8

const SQLITE_IOERR_SHORT_READ = SQLITE_IOERR | 2 << 8

const SQLITE_IOERR_WRITE = SQLITE_IOERR | 3 << 8

const SQLITE_IOERR_FSYNC = SQLITE_IOERR | 4 << 8

const SQLITE_IOERR_DIR_FSYNC = SQLITE_IOERR | 5 << 8

const SQLITE_IOERR_TRUNCATE = SQLITE_IOERR | 6 << 8

const SQLITE_IOERR_FSTAT = SQLITE_IOERR | 7 << 8

const SQLITE_IOERR_UNLOCK = SQLITE_IOERR | 8 << 8

const SQLITE_IOERR_RDLOCK = SQLITE_IOERR | 9 << 8

const SQLITE_IOERR_DELETE = SQLITE_IOERR | 10 << 8

const SQLITE_IOERR_BLOCKED = SQLITE_IOERR | 11 << 8

const SQLITE_IOERR_NOMEM = SQLITE_IOERR | 12 << 8

const SQLITE_IOERR_ACCESS = SQLITE_IOERR | 13 << 8

const SQLITE_IOERR_CHECKRESERVEDLOCK = SQLITE_IOERR | 14 << 8

const SQLITE_IOERR_LOCK = SQLITE_IOERR | 15 << 8

const SQLITE_IOERR_CLOSE = SQLITE_IOERR | 16 << 8

const SQLITE_IOERR_DIR_CLOSE = SQLITE_IOERR | 17 << 8

const SQLITE_IOERR_SHMOPEN = SQLITE_IOERR | 18 << 8

const SQLITE_IOERR_SHMSIZE = SQLITE_IOERR | 19 << 8

const SQLITE_IOERR_SHMLOCK = SQLITE_IOERR | 20 << 8

const SQLITE_IOERR_SHMMAP = SQLITE_IOERR | 21 << 8

const SQLITE_IOERR_SEEK = SQLITE_IOERR | 22 << 8

const SQLITE_IOERR_DELETE_NOENT = SQLITE_IOERR | 23 << 8

const SQLITE_IOERR_MMAP = SQLITE_IOERR | 24 << 8

const SQLITE_IOERR_GETTEMPPATH = SQLITE_IOERR | 25 << 8

const SQLITE_IOERR_CONVPATH = SQLITE_IOERR | 26 << 8

const SQLITE_IOERR_VNODE = SQLITE_IOERR | 27 << 8

const SQLITE_IOERR_AUTH = SQLITE_IOERR | 28 << 8

const SQLITE_IOERR_BEGIN_ATOMIC = SQLITE_IOERR | 29 << 8

const SQLITE_IOERR_COMMIT_ATOMIC = SQLITE_IOERR | 30 << 8

const SQLITE_IOERR_ROLLBACK_ATOMIC = SQLITE_IOERR | 31 << 8

const SQLITE_IOERR_DATA = SQLITE_IOERR | 32 << 8

const SQLITE_IOERR_CORRUPTFS = SQLITE_IOERR | 33 << 8

const SQLITE_LOCKED_SHAREDCACHE = SQLITE_LOCKED | 1 << 8

const SQLITE_LOCKED_VTAB = SQLITE_LOCKED | 2 << 8

const SQLITE_BUSY_RECOVERY = SQLITE_BUSY | 1 << 8

const SQLITE_BUSY_SNAPSHOT = SQLITE_BUSY | 2 << 8

const SQLITE_BUSY_TIMEOUT = SQLITE_BUSY | 3 << 8

const SQLITE_CANTOPEN_NOTEMPDIR = SQLITE_CANTOPEN | 1 << 8

const SQLITE_CANTOPEN_ISDIR = SQLITE_CANTOPEN | 2 << 8

const SQLITE_CANTOPEN_FULLPATH = SQLITE_CANTOPEN | 3 << 8

const SQLITE_CANTOPEN_CONVPATH = SQLITE_CANTOPEN | 4 << 8

const SQLITE_CANTOPEN_DIRTYWAL = SQLITE_CANTOPEN | 5 << 8

const SQLITE_CANTOPEN_SYMLINK = SQLITE_CANTOPEN | 6 << 8

const SQLITE_CORRUPT_VTAB = SQLITE_CORRUPT | 1 << 8

const SQLITE_CORRUPT_SEQUENCE = SQLITE_CORRUPT | 2 << 8

const SQLITE_CORRUPT_INDEX = SQLITE_CORRUPT | 3 << 8

const SQLITE_READONLY_RECOVERY = SQLITE_READONLY | 1 << 8

const SQLITE_READONLY_CANTLOCK = SQLITE_READONLY | 2 << 8

const SQLITE_READONLY_ROLLBACK = SQLITE_READONLY | 3 << 8

const SQLITE_READONLY_DBMOVED = SQLITE_READONLY | 4 << 8

const SQLITE_READONLY_CANTINIT = SQLITE_READONLY | 5 << 8

const SQLITE_READONLY_DIRECTORY = SQLITE_READONLY | 6 << 8

const SQLITE_ABORT_ROLLBACK = SQLITE_ABORT | 2 << 8

const SQLITE_CONSTRAINT_CHECK = SQLITE_CONSTRAINT | 1 << 8

const SQLITE_CONSTRAINT_COMMITHOOK = SQLITE_CONSTRAINT | 2 << 8

const SQLITE_CONSTRAINT_FOREIGNKEY = SQLITE_CONSTRAINT | 3 << 8

const SQLITE_CONSTRAINT_FUNCTION = SQLITE_CONSTRAINT | 4 << 8

const SQLITE_CONSTRAINT_NOTNULL = SQLITE_CONSTRAINT | 5 << 8

const SQLITE_CONSTRAINT_PRIMARYKEY = SQLITE_CONSTRAINT | 6 << 8

const SQLITE_CONSTRAINT_TRIGGER = SQLITE_CONSTRAINT | 7 << 8

const SQLITE_CONSTRAINT_UNIQUE = SQLITE_CONSTRAINT | 8 << 8

const SQLITE_CONSTRAINT_VTAB = SQLITE_CONSTRAINT | 9 << 8

const SQLITE_CONSTRAINT_ROWID = SQLITE_CONSTRAINT | 10 << 8

const SQLITE_CONSTRAINT_PINNED = SQLITE_CONSTRAINT | 11 << 8

const SQLITE_CONSTRAINT_DATATYPE = SQLITE_CONSTRAINT | 12 << 8

const SQLITE_NOTICE_RECOVER_WAL = SQLITE_NOTICE | 1 << 8

const SQLITE_NOTICE_RECOVER_ROLLBACK = SQLITE_NOTICE | 2 << 8

const SQLITE_WARNING_AUTOINDEX = SQLITE_WARNING | 1 << 8

const SQLITE_AUTH_USER = SQLITE_AUTH | 1 << 8

const SQLITE_OK_LOAD_PERMANENTLY = SQLITE_OK | 1 << 8

const SQLITE_OK_SYMLINK = SQLITE_OK | 2 << 8

const SQLITE_OPEN_READONLY = 0x00000001

const SQLITE_OPEN_READWRITE = 0x00000002

const SQLITE_OPEN_CREATE = 0x00000004

const SQLITE_OPEN_DELETEONCLOSE = 0x00000008

const SQLITE_OPEN_EXCLUSIVE = 0x00000010

const SQLITE_OPEN_AUTOPROXY = 0x00000020

const SQLITE_OPEN_URI = 0x00000040

const SQLITE_OPEN_MEMORY = 0x00000080

const SQLITE_OPEN_MAIN_DB = 0x00000100

const SQLITE_OPEN_TEMP_DB = 0x00000200

const SQLITE_OPEN_TRANSIENT_DB = 0x00000400

const SQLITE_OPEN_MAIN_JOURNAL = 0x00000800

const SQLITE_OPEN_TEMP_JOURNAL = 0x00001000

const SQLITE_OPEN_SUBJOURNAL = 0x00002000

const SQLITE_OPEN_SUPER_JOURNAL = 0x00004000

const SQLITE_OPEN_NOMUTEX = 0x00008000

const SQLITE_OPEN_FULLMUTEX = 0x00010000

const SQLITE_OPEN_SHAREDCACHE = 0x00020000

const SQLITE_OPEN_PRIVATECACHE = 0x00040000

const SQLITE_OPEN_WAL = 0x00080000

const SQLITE_OPEN_NOFOLLOW = 0x01000000

const SQLITE_OPEN_EXRESCODE = 0x02000000

const SQLITE_OPEN_MASTER_JOURNAL = 0x00004000

const SQLITE_IOCAP_ATOMIC = 0x00000001

const SQLITE_IOCAP_ATOMIC512 = 0x00000002

const SQLITE_IOCAP_ATOMIC1K = 0x00000004

const SQLITE_IOCAP_ATOMIC2K = 0x00000008

const SQLITE_IOCAP_ATOMIC4K = 0x00000010

const SQLITE_IOCAP_ATOMIC8K = 0x00000020

const SQLITE_IOCAP_ATOMIC16K = 0x00000040

const SQLITE_IOCAP_ATOMIC32K = 0x00000080

const SQLITE_IOCAP_ATOMIC64K = 0x00000100

const SQLITE_IOCAP_SAFE_APPEND = 0x00000200

const SQLITE_IOCAP_SEQUENTIAL = 0x00000400

const SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN = 0x00000800

const SQLITE_IOCAP_POWERSAFE_OVERWRITE = 0x00001000

const SQLITE_IOCAP_IMMUTABLE = 0x00002000

const SQLITE_IOCAP_BATCH_ATOMIC = 0x00004000

const SQLITE_LOCK_NONE = 0

const SQLITE_LOCK_SHARED = 1

const SQLITE_LOCK_RESERVED = 2

const SQLITE_LOCK_PENDING = 3

const SQLITE_LOCK_EXCLUSIVE = 4

const SQLITE_SYNC_NORMAL = 0x00000002

const SQLITE_SYNC_FULL = 0x00000003

const SQLITE_SYNC_DATAONLY = 0x00000010

const SQLITE_FCNTL_LOCKSTATE = 1

const SQLITE_FCNTL_GET_LOCKPROXYFILE = 2

const SQLITE_FCNTL_SET_LOCKPROXYFILE = 3

const SQLITE_FCNTL_LAST_ERRNO = 4

const SQLITE_FCNTL_SIZE_HINT = 5

const SQLITE_FCNTL_CHUNK_SIZE = 6

const SQLITE_FCNTL_FILE_POINTER = 7

const SQLITE_FCNTL_SYNC_OMITTED = 8

const SQLITE_FCNTL_WIN32_AV_RETRY = 9

const SQLITE_FCNTL_PERSIST_WAL = 10

const SQLITE_FCNTL_OVERWRITE = 11

const SQLITE_FCNTL_VFSNAME = 12

const SQLITE_FCNTL_POWERSAFE_OVERWRITE = 13

const SQLITE_FCNTL_PRAGMA = 14

const SQLITE_FCNTL_BUSYHANDLER = 15

const SQLITE_FCNTL_TEMPFILENAME = 16

const SQLITE_FCNTL_MMAP_SIZE = 18

const SQLITE_FCNTL_TRACE = 19

const SQLITE_FCNTL_HAS_MOVED = 20

const SQLITE_FCNTL_SYNC = 21

const SQLITE_FCNTL_COMMIT_PHASETWO = 22

const SQLITE_FCNTL_WIN32_SET_HANDLE = 23

const SQLITE_FCNTL_WAL_BLOCK = 24

const SQLITE_FCNTL_ZIPVFS = 25

const SQLITE_FCNTL_RBU = 26

const SQLITE_FCNTL_VFS_POINTER = 27

const SQLITE_FCNTL_JOURNAL_POINTER = 28

const SQLITE_FCNTL_WIN32_GET_HANDLE = 29

const SQLITE_FCNTL_PDB = 30

const SQLITE_FCNTL_BEGIN_ATOMIC_WRITE = 31

const SQLITE_FCNTL_COMMIT_ATOMIC_WRITE = 32

const SQLITE_FCNTL_ROLLBACK_ATOMIC_WRITE = 33

const SQLITE_FCNTL_LOCK_TIMEOUT = 34

const SQLITE_FCNTL_DATA_VERSION = 35

const SQLITE_FCNTL_SIZE_LIMIT = 36

const SQLITE_FCNTL_CKPT_DONE = 37

const SQLITE_FCNTL_RESERVE_BYTES = 38

const SQLITE_FCNTL_CKPT_START = 39

const SQLITE_FCNTL_EXTERNAL_READER = 40

const SQLITE_FCNTL_CKSM_FILE = 41

const SQLITE_GET_LOCKPROXYFILE = SQLITE_FCNTL_GET_LOCKPROXYFILE

const SQLITE_SET_LOCKPROXYFILE = SQLITE_FCNTL_SET_LOCKPROXYFILE

const SQLITE_LAST_ERRNO = SQLITE_FCNTL_LAST_ERRNO

const SQLITE_ACCESS_EXISTS = 0

const SQLITE_ACCESS_READWRITE = 1

const SQLITE_ACCESS_READ = 2

const SQLITE_SHM_UNLOCK = 1

const SQLITE_SHM_LOCK = 2

const SQLITE_SHM_SHARED = 4

const SQLITE_SHM_EXCLUSIVE = 8

const SQLITE_SHM_NLOCK = 8

const SQLITE_CONFIG_SINGLETHREAD = 1

const SQLITE_CONFIG_MULTITHREAD = 2

const SQLITE_CONFIG_SERIALIZED = 3

const SQLITE_CONFIG_MALLOC = 4

const SQLITE_CONFIG_GETMALLOC = 5

const SQLITE_CONFIG_SCRATCH = 6

const SQLITE_CONFIG_PAGECACHE = 7

const SQLITE_CONFIG_HEAP = 8

const SQLITE_CONFIG_MEMSTATUS = 9

const SQLITE_CONFIG_MUTEX = 10

const SQLITE_CONFIG_GETMUTEX = 11

const SQLITE_CONFIG_LOOKASIDE = 13

const SQLITE_CONFIG_PCACHE = 14

const SQLITE_CONFIG_GETPCACHE = 15

const SQLITE_CONFIG_LOG = 16

const SQLITE_CONFIG_URI = 17

const SQLITE_CONFIG_PCACHE2 = 18

const SQLITE_CONFIG_GETPCACHE2 = 19

const SQLITE_CONFIG_COVERING_INDEX_SCAN = 20

const SQLITE_CONFIG_SQLLOG = 21

const SQLITE_CONFIG_MMAP_SIZE = 22

const SQLITE_CONFIG_WIN32_HEAPSIZE = 23

const SQLITE_CONFIG_PCACHE_HDRSZ = 24

const SQLITE_CONFIG_PMASZ = 25

const SQLITE_CONFIG_STMTJRNL_SPILL = 26

const SQLITE_CONFIG_SMALL_MALLOC = 27

const SQLITE_CONFIG_SORTERREF_SIZE = 28

const SQLITE_CONFIG_MEMDB_MAXSIZE = 29

const SQLITE_DBCONFIG_MAINDBNAME = 1000

const SQLITE_DBCONFIG_LOOKASIDE = 1001

const SQLITE_DBCONFIG_ENABLE_FKEY = 1002

const SQLITE_DBCONFIG_ENABLE_TRIGGER = 1003

const SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER = 1004

const SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION = 1005

const SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE = 1006

const SQLITE_DBCONFIG_ENABLE_QPSG = 1007

const SQLITE_DBCONFIG_TRIGGER_EQP = 1008

const SQLITE_DBCONFIG_RESET_DATABASE = 1009

const SQLITE_DBCONFIG_DEFENSIVE = 1010

const SQLITE_DBCONFIG_WRITABLE_SCHEMA = 1011

const SQLITE_DBCONFIG_LEGACY_ALTER_TABLE = 1012

const SQLITE_DBCONFIG_DQS_DML = 1013

const SQLITE_DBCONFIG_DQS_DDL = 1014

const SQLITE_DBCONFIG_ENABLE_VIEW = 1015

const SQLITE_DBCONFIG_LEGACY_FILE_FORMAT = 1016

const SQLITE_DBCONFIG_TRUSTED_SCHEMA = 1017

const SQLITE_DBCONFIG_MAX = 1017

const SQLITE_DENY = 1

const SQLITE_IGNORE = 2

const SQLITE_CREATE_INDEX = 1

const SQLITE_CREATE_TABLE = 2

const SQLITE_CREATE_TEMP_INDEX = 3

const SQLITE_CREATE_TEMP_TABLE = 4

const SQLITE_CREATE_TEMP_TRIGGER = 5

const SQLITE_CREATE_TEMP_VIEW = 6

const SQLITE_CREATE_TRIGGER = 7

const SQLITE_CREATE_VIEW = 8

const SQLITE_DELETE = 9

const SQLITE_DROP_INDEX = 10

const SQLITE_DROP_TABLE = 11

const SQLITE_DROP_TEMP_INDEX = 12

const SQLITE_DROP_TEMP_TABLE = 13

const SQLITE_DROP_TEMP_TRIGGER = 14

const SQLITE_DROP_TEMP_VIEW = 15

const SQLITE_DROP_TRIGGER = 16

const SQLITE_DROP_VIEW = 17

const SQLITE_INSERT = 18

const SQLITE_PRAGMA = 19

const SQLITE_READ = 20

const SQLITE_SELECT = 21

const SQLITE_TRANSACTION = 22

const SQLITE_UPDATE = 23

const SQLITE_ATTACH = 24

const SQLITE_DETACH = 25

const SQLITE_ALTER_TABLE = 26

const SQLITE_REINDEX = 27

const SQLITE_ANALYZE = 28

const SQLITE_CREATE_VTABLE = 29

const SQLITE_DROP_VTABLE = 30

const SQLITE_FUNCTION = 31

const SQLITE_SAVEPOINT = 32

const SQLITE_COPY = 0

const SQLITE_RECURSIVE = 33

const SQLITE_TRACE_STMT = 0x01

const SQLITE_TRACE_PROFILE = 0x02

const SQLITE_TRACE_ROW = 0x04

const SQLITE_TRACE_CLOSE = 0x08

const SQLITE_LIMIT_LENGTH = 0

const SQLITE_LIMIT_SQL_LENGTH = 1

const SQLITE_LIMIT_COLUMN = 2

const SQLITE_LIMIT_EXPR_DEPTH = 3

const SQLITE_LIMIT_COMPOUND_SELECT = 4

const SQLITE_LIMIT_VDBE_OP = 5

const SQLITE_LIMIT_FUNCTION_ARG = 6

const SQLITE_LIMIT_ATTACHED = 7

const SQLITE_LIMIT_LIKE_PATTERN_LENGTH = 8

const SQLITE_LIMIT_VARIABLE_NUMBER = 9

const SQLITE_LIMIT_TRIGGER_DEPTH = 10

const SQLITE_LIMIT_WORKER_THREADS = 11

const SQLITE_PREPARE_PERSISTENT = 0x01

const SQLITE_PREPARE_NORMALIZE = 0x02

const SQLITE_PREPARE_NO_VTAB = 0x04

const SQLITE_INTEGER = 1

const SQLITE_FLOAT = 2

const SQLITE_BLOB = 4

const SQLITE_NULL = 5

const SQLITE_TEXT = 3

const SQLITE3_TEXT = 3

const SQLITE_UTF8 = 1

const SQLITE_UTF16LE = 2

const SQLITE_UTF16BE = 3

const SQLITE_UTF16 = 4

const SQLITE_ANY = 5

const SQLITE_UTF16_ALIGNED = 8

const SQLITE_DETERMINISTIC = 0x0000000000000800

const SQLITE_DIRECTONLY = 0x0000000000080000

const SQLITE_SUBTYPE = 0x0000000000100000

const SQLITE_INNOCUOUS = 0x0000000000200000

const SQLITE_STATIC = sqlite3_destructor_type(0)

const SQLITE_TRANSIENT = sqlite3_destructor_type(-1)

const SQLITE_WIN32_DATA_DIRECTORY_TYPE = 1

const SQLITE_WIN32_TEMP_DIRECTORY_TYPE = 2

const SQLITE_TXN_NONE = 0

const SQLITE_TXN_READ = 1

const SQLITE_TXN_WRITE = 2

const SQLITE_INDEX_SCAN_UNIQUE = 1

const SQLITE_INDEX_CONSTRAINT_EQ = 2

const SQLITE_INDEX_CONSTRAINT_GT = 4

const SQLITE_INDEX_CONSTRAINT_LE = 8

const SQLITE_INDEX_CONSTRAINT_LT = 16

const SQLITE_INDEX_CONSTRAINT_GE = 32

const SQLITE_INDEX_CONSTRAINT_MATCH = 64

const SQLITE_INDEX_CONSTRAINT_LIKE = 65

const SQLITE_INDEX_CONSTRAINT_GLOB = 66

const SQLITE_INDEX_CONSTRAINT_REGEXP = 67

const SQLITE_INDEX_CONSTRAINT_NE = 68

const SQLITE_INDEX_CONSTRAINT_ISNOT = 69

const SQLITE_INDEX_CONSTRAINT_ISNOTNULL = 70

const SQLITE_INDEX_CONSTRAINT_ISNULL = 71

const SQLITE_INDEX_CONSTRAINT_IS = 72

const SQLITE_INDEX_CONSTRAINT_LIMIT = 73

const SQLITE_INDEX_CONSTRAINT_OFFSET = 74

const SQLITE_INDEX_CONSTRAINT_FUNCTION = 150

const SQLITE_MUTEX_FAST = 0

const SQLITE_MUTEX_RECURSIVE = 1

const SQLITE_MUTEX_STATIC_MAIN = 2

const SQLITE_MUTEX_STATIC_MEM = 3

const SQLITE_MUTEX_STATIC_MEM2 = 4

const SQLITE_MUTEX_STATIC_OPEN = 4

const SQLITE_MUTEX_STATIC_PRNG = 5

const SQLITE_MUTEX_STATIC_LRU = 6

const SQLITE_MUTEX_STATIC_LRU2 = 7

const SQLITE_MUTEX_STATIC_PMEM = 7

const SQLITE_MUTEX_STATIC_APP1 = 8

const SQLITE_MUTEX_STATIC_APP2 = 9

const SQLITE_MUTEX_STATIC_APP3 = 10

const SQLITE_MUTEX_STATIC_VFS1 = 11

const SQLITE_MUTEX_STATIC_VFS2 = 12

const SQLITE_MUTEX_STATIC_VFS3 = 13

const SQLITE_MUTEX_STATIC_MASTER = 2

const SQLITE_TESTCTRL_FIRST = 5

const SQLITE_TESTCTRL_PRNG_SAVE = 5

const SQLITE_TESTCTRL_PRNG_RESTORE = 6

const SQLITE_TESTCTRL_PRNG_RESET = 7

const SQLITE_TESTCTRL_BITVEC_TEST = 8

const SQLITE_TESTCTRL_FAULT_INSTALL = 9

const SQLITE_TESTCTRL_BENIGN_MALLOC_HOOKS = 10

const SQLITE_TESTCTRL_PENDING_BYTE = 11

const SQLITE_TESTCTRL_ASSERT = 12

const SQLITE_TESTCTRL_ALWAYS = 13

const SQLITE_TESTCTRL_RESERVE = 14

const SQLITE_TESTCTRL_OPTIMIZATIONS = 15

const SQLITE_TESTCTRL_ISKEYWORD = 16

const SQLITE_TESTCTRL_SCRATCHMALLOC = 17

const SQLITE_TESTCTRL_INTERNAL_FUNCTIONS = 17

const SQLITE_TESTCTRL_LOCALTIME_FAULT = 18

const SQLITE_TESTCTRL_EXPLAIN_STMT = 19

const SQLITE_TESTCTRL_ONCE_RESET_THRESHOLD = 19

const SQLITE_TESTCTRL_NEVER_CORRUPT = 20

const SQLITE_TESTCTRL_VDBE_COVERAGE = 21

const SQLITE_TESTCTRL_BYTEORDER = 22

const SQLITE_TESTCTRL_ISINIT = 23

const SQLITE_TESTCTRL_SORTER_MMAP = 24

const SQLITE_TESTCTRL_IMPOSTER = 25

const SQLITE_TESTCTRL_PARSER_COVERAGE = 26

const SQLITE_TESTCTRL_RESULT_INTREAL = 27

const SQLITE_TESTCTRL_PRNG_SEED = 28

const SQLITE_TESTCTRL_EXTRA_SCHEMA_CHECKS = 29

const SQLITE_TESTCTRL_SEEK_COUNT = 30

const SQLITE_TESTCTRL_TRACEFLAGS = 31

const SQLITE_TESTCTRL_TUNE = 32

const SQLITE_TESTCTRL_LOGEST = 33

const SQLITE_TESTCTRL_LAST = 33

const SQLITE_STATUS_MEMORY_USED = 0

const SQLITE_STATUS_PAGECACHE_USED = 1

const SQLITE_STATUS_PAGECACHE_OVERFLOW = 2

const SQLITE_STATUS_SCRATCH_USED = 3

const SQLITE_STATUS_SCRATCH_OVERFLOW = 4

const SQLITE_STATUS_MALLOC_SIZE = 5

const SQLITE_STATUS_PARSER_STACK = 6

const SQLITE_STATUS_PAGECACHE_SIZE = 7

const SQLITE_STATUS_SCRATCH_SIZE = 8

const SQLITE_STATUS_MALLOC_COUNT = 9

const SQLITE_DBSTATUS_LOOKASIDE_USED = 0

const SQLITE_DBSTATUS_CACHE_USED = 1

const SQLITE_DBSTATUS_SCHEMA_USED = 2

const SQLITE_DBSTATUS_STMT_USED = 3

const SQLITE_DBSTATUS_LOOKASIDE_HIT = 4

const SQLITE_DBSTATUS_LOOKASIDE_MISS_SIZE = 5

const SQLITE_DBSTATUS_LOOKASIDE_MISS_FULL = 6

const SQLITE_DBSTATUS_CACHE_HIT = 7

const SQLITE_DBSTATUS_CACHE_MISS = 8

const SQLITE_DBSTATUS_CACHE_WRITE = 9

const SQLITE_DBSTATUS_DEFERRED_FKS = 10

const SQLITE_DBSTATUS_CACHE_USED_SHARED = 11

const SQLITE_DBSTATUS_CACHE_SPILL = 12

const SQLITE_DBSTATUS_MAX = 12

const SQLITE_STMTSTATUS_FULLSCAN_STEP = 1

const SQLITE_STMTSTATUS_SORT = 2

const SQLITE_STMTSTATUS_AUTOINDEX = 3

const SQLITE_STMTSTATUS_VM_STEP = 4

const SQLITE_STMTSTATUS_REPREPARE = 5

const SQLITE_STMTSTATUS_RUN = 6

const SQLITE_STMTSTATUS_FILTER_MISS = 7

const SQLITE_STMTSTATUS_FILTER_HIT = 8

const SQLITE_STMTSTATUS_MEMUSED = 99

const SQLITE_CHECKPOINT_PASSIVE = 0

const SQLITE_CHECKPOINT_FULL = 1

const SQLITE_CHECKPOINT_RESTART = 2

const SQLITE_CHECKPOINT_TRUNCATE = 3

const SQLITE_VTAB_CONSTRAINT_SUPPORT = 1

const SQLITE_VTAB_INNOCUOUS = 2

const SQLITE_VTAB_DIRECTONLY = 3

const SQLITE_ROLLBACK = 1

const SQLITE_FAIL = 3

const SQLITE_REPLACE = 5

const SQLITE_SCANSTAT_NLOOP = 0

const SQLITE_SCANSTAT_NVISIT = 1

const SQLITE_SCANSTAT_EST = 2

const SQLITE_SCANSTAT_NAME = 3

const SQLITE_SCANSTAT_EXPLAIN = 4

const SQLITE_SCANSTAT_SELECTID = 5

const SQLITE_SERIALIZE_NOCOPY = 0x0001

const SQLITE_DESERIALIZE_FREEONCLOSE = 1

const SQLITE_DESERIALIZE_RESIZEABLE = 2

const SQLITE_DESERIALIZE_READONLY = 4

const NOT_WITHIN = 0

const PARTLY_WITHIN = 1

const FULLY_WITHIN = 2

const FTS5_TOKENIZE_QUERY = 0x0001

const FTS5_TOKENIZE_PREFIX = 0x0002

const FTS5_TOKENIZE_DOCUMENT = 0x0004

const FTS5_TOKENIZE_AUX = 0x0008

const FTS5_TOKEN_COLOCATED = 0x0001

end # module
