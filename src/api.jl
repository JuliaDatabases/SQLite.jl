function sqlite3_errmsg()
    return ccall( (:sqlite3_errmsg, libsqlite),
        Ptr{UInt8}, ()
        )
end
function sqlite3_errmsg(db::Ptr{Cvoid})
    @NULLCHECK db
    return ccall( (:sqlite3_errmsg, libsqlite),
        Ptr{UInt8}, (Ptr{Cvoid},),
        db)
end
function sqlite3_open(file::AbstractString, handle)
    return ccall( (:sqlite3_open, libsqlite),
        Cint, (Ptr{UInt8}, Ptr{Cvoid}),
        file, handle)
end
function sqlite3_open16(file::UTF16String, handle)
    return ccall( (:sqlite3_open16, libsqlite),
        Cint, (Ptr{UInt16}, Ptr{Cvoid}),
        file, handle)
end
function sqlite3_close(handle::Ptr{Cvoid})
    @NULLCHECK handle
    return ccall( (:sqlite3_close, libsqlite),
        Cint, (Ptr{Cvoid},),
        handle)
end
function sqlite3_next_stmt(db::Ptr{Cvoid}, stmt::Ptr{Cvoid})
    @NULLCHECK db
    return ccall( (:sqlite3_next_stmt, libsqlite),
        Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}),
        db, stmt)
end
function sqlite3_prepare_v2(handle::Ptr{Cvoid}, query::AbstractString, stmt, unused)
    @NULLCHECK handle
    return ccall( (:sqlite3_prepare_v2, libsqlite),
        Cint, (Ptr{Cvoid}, Ptr{UInt8}, Cint, Ptr{Cvoid}, Ptr{Cvoid}),
            handle, query, sizeof(query), stmt, unused)
end
function sqlite3_prepare16_v2(handle::Ptr{Cvoid}, query::AbstractString, stmt, unused)
    @NULLCHECK handle
    return ccall( (:sqlite3_prepare16_v2, libsqlite),
        Cint, (Ptr{Cvoid}, Ptr{UInt16}, Cint, Ptr{Cvoid}, Ptr{Cvoid}),
        handle, query, sizeof(query), stmt, unused)
end
function sqlite3_finalize(stmt::Ptr{Cvoid})
    @NULLCHECK stmt
    return ccall( (:sqlite3_finalize, libsqlite),
        Cint, (Ptr{Cvoid},),
        stmt)
end

# SQLITE_API int sqlite3_bind_paramter_count(sqlite3_stmt*)
function sqlite3_bind_parameter_count(stmt::Ptr{Cvoid})
    return ccall( (:sqlite3_bind_parameter_count, libsqlite),
        Cint, (Ptr{Cvoid},),
        stmt)
end
#SQLITE_API const char* sqlite3_bind_parameter_name(sqlite3_stmt*, int)
function sqlite3_bind_parameter_name(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_bind_parameter_name, libsqlite),
        Ptr{UInt8}, (Ptr{Cvoid}, Cint),
        stmt, col)
end
# SQLITE_API int sqlite3_bind_parameter_index(sqlite3_stmt*, const char *zName);
function sqlite3_bind_parameter_index(stmt::Ptr{Cvoid}, value::AbstractString)
    return ccall( (:sqlite3_bind_parameter_index, libsqlite),
        Cint, (Ptr{Cvoid}, Ptr{UInt8}),
        stmt, value)
end
# SQLITE_API int sqlite3_bind_double(sqlite3_stmt*, int, double);
function sqlite3_bind_double(stmt::Ptr{Cvoid}, col::Int, value::Float64)
    return ccall( (:sqlite3_bind_double, libsqlite),
        Cint, (Ptr{Cvoid}, Cint, Float64),
        stmt, col, value)
end
# SQLITE_API int sqlite3_bind_int(sqlite3_stmt*, int, int);
function sqlite3_bind_int(stmt::Ptr{Cvoid}, col::Int, value::Int32)
    return ccall( (:sqlite3_bind_int, libsqlite),
        Cint, (Ptr{Cvoid}, Cint, Int32),
        stmt, col, value)
end
# SQLITE_API int sqlite3_bind_int64(sqlite3_stmt*, int, sqlite3_int64);
function sqlite3_bind_int64(stmt::Ptr{Cvoid}, col::Int, value::Int64)
    return ccall( (:sqlite3_bind_int64, libsqlite),
        Cint, (Ptr{Cvoid}, Cint, Int64),
        stmt, col, value)
end
# SQLITE_API int sqlite3_bind_null(sqlite3_stmt*, int);
function sqlite3_bind_null(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_bind_null, libsqlite),
        Cint, (Ptr{Cvoid}, Cint),
        stmt, col)
end
# SQLITE_API int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
function sqlite3_bind_text(stmt::Ptr{Cvoid}, col::Int, value::AbstractString)
    return ccall( (:sqlite3_bind_text, libsqlite),
        Cint, (Ptr{Cvoid}, Cint, Ptr{UInt8}, Cint, Ptr{Cvoid}),
        stmt, col, value, sizeof(value), C_NULL)
end
function sqlite3_bind_text(stmt::Ptr{Cvoid}, col::Int, ptr::Ptr{UInt8}, len::Int)
    return ccall( (:sqlite3_bind_text, libsqlite),
        Cint, (Ptr{Cvoid}, Cint, Ptr{UInt8}, Cint, Ptr{Cvoid}),
        stmt, col, ptr, len, C_NULL)
end
# SQLITE_API int sqlite3_bind_text16(sqlite3_stmt*, int, const void*, int, void(*)(void*));
function sqlite3_bind_text16(stmt::Ptr{Cvoid}, col::Int, value::UTF16String)
    return ccall( (:sqlite3_bind_text16, libsqlite),
        Cint, (Ptr{Cvoid}, Cint, Ptr{UInt16}, Cint, Ptr{Cvoid}),
        stmt, col, value, sizeof(value), C_NULL)
end
function sqlite3_bind_text16(stmt::Ptr{Cvoid}, col::Int, ptr::Ptr{UInt16}, len::Int)
    return ccall( (:sqlite3_bind_text16, libsqlite),
        Cint, (Ptr{Cvoid}, Cint, Ptr{UInt16}, Cint, Ptr{Cvoid}),
        stmt, col, ptr, len, C_NULL)
end

# SQLITE_API int sqlite3_bind_blob(sqlite3_stmt*, int, const void*, int n, void(*)(void*));
function sqlite3_bind_blob(stmt::Ptr{Cvoid}, col::Int, value)
    return ccall( (:sqlite3_bind_blob, libsqlite),
        Cint, (Ptr{Cvoid}, Cint, Ptr{UInt8}, Cint, Ptr{Cvoid}),
        stmt, col, value, sizeof(value), SQLITE_STATIC)
end
# SQLITE_API int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
# SQLITE_API int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);

function sqlite3_clear_bindings(stmt::Ptr{Cvoid})
    return ccall( (:sqlite3_clear_bindings, libsqlite),
        Cint, (Ptr{Cvoid},),
        stmt)
end

function sqlite3_step(stmt::Ptr{Cvoid})
    return ccall( (:sqlite3_step, libsqlite),
        Cint, (Ptr{Cvoid},),
        stmt)
end
function sqlite3_column_count(stmt::Ptr{Cvoid})
    return ccall( (:sqlite3_column_count, libsqlite),
        Cint, (Ptr{Cvoid},),
        stmt)
end
function sqlite3_column_type(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_type, libsqlite),
        Cint, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_blob(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_blob, libsqlite),
        Ptr{Cvoid}, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_bytes(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_bytes, libsqlite),
        Cint, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_bytes16(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_bytes16, libsqlite),
        Cint, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_double(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_double, libsqlite),
        Cdouble, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_int(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_int, libsqlite),
        Cint, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_int64(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_int64, libsqlite),
        Clonglong, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_text(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_text, libsqlite),
        Ptr{UInt8}, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_text16(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_text16, libsqlite),
        Ptr{Cvoid}, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
# function sqlite3_column_value(stmt::Ptr{Cvoid}, col::Cint)
#     return ccall( (:sqlite3_column_value, libsqlite),
#             Ptr{Cvoid}, (Ptr{Cvoid}, Cint),
#             stmt, col-1)
# end
# SQLITE_API sqlite3_value *sqlite3_column_value(sqlite3_stmt*, int iCol);
function sqlite3_reset(stmt::Ptr{Cvoid})
    return ccall( (:sqlite3_reset, libsqlite),
        Cint, (Ptr{Cvoid},),
        stmt)
end

# SQLITE_API const char *sqlite3_column_name(sqlite3_stmt*, int N);
function sqlite3_column_name(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_name, libsqlite),
        Ptr{UInt8}, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
function sqlite3_column_name16(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_name16, libsqlite),
        Ptr{UInt8}, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end

function sqlite3_changes(db::Ptr{Cvoid})
    @NULLCHECK db
   return ccall( (:sqlite3_changes, libsqlite),
        Cint, (Ptr{Cvoid},),
        db)
end
function sqlite3_total_changes(db::Ptr{Cvoid})
    @NULLCHECK db
   return ccall( (:sqlite3_changes, libsqlite),
        Cint, (Ptr{Cvoid},),
        db)
end
# SQLITE_API const void *sqlite3_column_name16(sqlite3_stmt*, int N);

# SQLITE_API const char *sqlite3_column_database_name(sqlite3_stmt*, int);
# SQLITE_API const void *sqlite3_column_database_name16(sqlite3_stmt*, int);
# SQLITE_API const char *sqlite3_column_table_name(sqlite3_stmt*, int);
# SQLITE_API const void *sqlite3_column_table_name16(sqlite3_stmt*, int);
# SQLITE_API const char *sqlite3_column_origin_name(sqlite3_stmt*, int);
# SQLITE_API const void *sqlite3_column_origin_name16(sqlite3_stmt*, int);

function sqlite3_column_decltype(stmt::Ptr{Cvoid}, col::Int)
    return ccall( (:sqlite3_column_decltype, libsqlite),
        Ptr{UInt8}, (Ptr{Cvoid}, Cint),
        stmt, col-1)
end
# SQLITE_API const char *sqlite3_column_decltype(sqlite3_stmt*, int);
# SQLITE_API const void *sqlite3_column_decltype16(sqlite3_stmt*, int);

# SQLITE_API int sqlite3_data_count(sqlite3_stmt *pStmt);

# SQLITE_API void sqlite3_result_double(sqlite3_context*, double);
function sqlite3_result_double(context::Ptr{Cvoid}, value::Float64)
    return ccall( (:sqlite3_result_double, libsqlite),
        Cvoid, (Ptr{Cvoid}, Float64),
        context, value)
end
# SQLITE_API void sqlite3_result_error(sqlite3_context*, const char*, int)
function sqlite3_result_error(context::Ptr{Cvoid}, msg::AbstractString)
    return ccall( (:sqlite3_result_error, libsqlite),
        Cvoid, (Ptr{Cvoid}, Ptr{UInt8}, Cint),
        context, value, sizeof(msg)+1)
end
# SQLITE_API void sqlite3_result_error16(sqlite3_context*, const void*, int)
function sqlite3_result_error(context::Ptr{Cvoid}, msg::UTF16String)
    return ccall( (:sqlite3_result_error16, libsqlite),
        Cvoid, (Ptr{Cvoid}, Ptr{UInt16}, Cint),
        context, value, sizeof(msg)+1)
end
# SQLITE_API void sqlite3_result_int(sqlite3_context*, int);
function sqlite3_result_int(context::Ptr{Cvoid}, value::Int32)
    return ccall( (:sqlite3_result_int, libsqlite),
        Cvoid, (Ptr{Cvoid}, Int32),
        context, value)
end
# SQLITE_API void sqlite3_result_int64(sqlite3_context*, sqlite3_int64);
function sqlite3_result_int64(context::Ptr{Cvoid}, value::Int64)
    return ccall( (:sqlite3_result_int64, libsqlite),
        Cvoid, (Ptr{Cvoid}, Int64),
        context, value)
end
# SQLITE_API void sqlite3_result_null(sqlite3_context*);
function sqlite3_result_null(context::Ptr{Cvoid})
    return ccall( (:sqlite3_result_null, libsqlite),
        Cvoid, (Ptr{Cvoid},),
        context)
end
# SQLITE_API void sqlite3_result_text(sqlite3_context*, const char*, int n, void(*)(void*));
function sqlite3_result_text(context::Ptr{Cvoid}, value::AbstractString)
    return ccall( (:sqlite3_result_text, libsqlite),
        Cvoid, (Ptr{Cvoid}, Ptr{UInt8}, Cint, Ptr{Cvoid}),
        context, value, sizeof(value)+1, SQLITE_TRANSIENT)
end
# SQLITE_API void sqlite3_result_text16(sqlite3_context*, const void*, int, void(*)(void*));
function sqlite3_result_text16(context::Ptr{Cvoid}, value::UTF16String)
    return ccall( (:sqlite3_result_text, libsqlite),
        Cvoid, (Ptr{Cvoid}, Ptr{UInt16}, Cint, Ptr{Cvoid}),
        context, value, sizeof(value)+1, SQLITE_TRANSIENT)
end
# SQLITE_API void sqlite3_result_blob(sqlite3_context*, const void*, int n, void(*)(void*));
function sqlite3_result_blob(context::Ptr{Cvoid}, value)
    return ccall( (:sqlite3_result_blob, libsqlite),
        Cvoid, (Ptr{Cvoid}, Ptr{UInt8}, Cint, Ptr{Cvoid}),
        context, value, sizeof(value), SQLITE_TRANSIENT)
end
# SQLITE_API void sqlite3_result_zeroblob(sqlite3_context*, int n);
# SQLITE_API void sqlite3_result_value(sqlite3_context*, const sqlite3_value*);
# SQLITE_API void sqlite3_result_error_toobig(sqlite3_context*)
# SQLITE_API void sqlite3_result_error_nomem(sqlite3_context*)
# SQLITE_API void sqlite3_result_error_code(sqlite3_context*, int)


function sqlite3_create_function_v2(db::Ptr{Cvoid}, name::AbstractString, nargs::Integer,
                                    enc::Integer, data::Ptr{Cvoid}, func,
                                    step, final,
                                    destructor::Ptr{Cvoid})
    @NULLCHECK db
    return ccall(
        (:sqlite3_create_function_v2, libsqlite),
        Cint,
        (Ptr{Cvoid}, Ptr{UInt8}, Cint, Cint, Ptr{Cvoid},
         Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
        db, name, nargs, enc, data, func, step, final, destructor)
end

# SQLITE_API void* sqlite3_aggregate_context(sqlite3_context*, int nBytes)
function sqlite3_aggregate_context(context::Ptr{Cvoid}, nbytes::Integer)
    return ccall( (:sqlite3_aggregate_context, libsqlite),
        Ptr{Cvoid}, (Ptr{Cvoid}, Cint),
        context, nbytes)
end

# SQLITE_API int sqlite3_value_type(sqlite3_value*)
function sqlite3_value_type(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_type, libsqlite),
        Cint, (Ptr{Cvoid},),
        value)
end

# SQLITE_API const void* sqlite3_value_blob(sqlite3_value*)
function sqlite3_value_blob(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_blob, libsqlite),
        Ptr{Cvoid}, (Ptr{Cvoid},),
        value)
end
# SQLITE_API int sqlite3_value_bytes(sqlite3_value*)
function sqlite3_value_bytes(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_bytes, libsqlite),
        Cint, (Ptr{Cvoid},),
        value)
end
# SQLITE_API int sqlite3_value_bytes16(sqlite3_value*)
function sqlite3_value_bytes16(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_bytes16, libsqlite),
        Cint, (Ptr{Cvoid},),
        value)
end
# SQLITE_API double sqlite3_value_double(sqlite3_value*)
function sqlite3_value_double(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_double, libsqlite),
        Cdouble, (Ptr{Cvoid},),
        value)
end
# SQLITE_API int sqlite3_value_int(sqlite3_value*)
function sqlite3_value_int(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_int, libsqlite),
        Cint, (Ptr{Cvoid},),
        value)
end
# SQLITE_API sqlite_int64 sqlite3_value_int64(sqlite3_value*)
function sqlite3_value_int64(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_int64, libsqlite),
        Clonglong, (Ptr{Cvoid},),
        value)
end
# SQLITE_API const unsigned char* sqlite3_value_text(sqlite3_value*)
function sqlite3_value_text(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_text, libsqlite),
        Ptr{UInt8}, (Ptr{Cvoid},),
        value)
end
# SQLITE_API const void* sqlite3_value_text16(sqlite3_value*)
function sqlite3_value_text16(value::Ptr{Cvoid})
    return ccall( (:sqlite3_value_text16, libsqlite),
        Ptr{Cvoid}, (Ptr{Cvoid},),
        value)
end
# SQLITE_API int sqlite3_value_numeric_type(sqlite3_value*)


function sqlite3_initialize()
    return ccall( (:sqlite3_initialize, libsqlite),
        Cint, (),
        )
end
function sqlite3_shutdown()
    return ccall( (:sqlite3_shutdown, libsqlite),
        Cint, (),
        )
end
function sqlite3_os_init()
    return ccall( (:sqlite3_os_init, libsqlite),
        Cint, (),
        )
end
function sqlite3_os_end()
    return ccall( (:sqlite3_os_end, libsqlite),
        Cint, (),
        )
end
function sqlite3_free_table(result::Array{AbstractString, 1})
    return ccall( (:sqlite3_free_table, libsqlite),
        Cvoid, (Ptr{Ptr{Cvoid}},),
        result)
end

# SQLITE_API const char *sqlite3_uri_parameter(const char *zFilename, const char *zParam);
# SQLITE_API int sqlite3_uri_boolean(const char *zFile, const char *zParam, int bDefault);
# SQLITE_API sqlite3_int64 sqlite3_uri_int64(const char*, const char*, sqlite3_int64);
function sqlite3_errcode(db::Ptr{Cvoid})
    @NULLCHECK db
    return ccall( (:sqlite3_errcode, libsqlite),
        Cint, (Ptr{Cvoid},),
        db)
end
function sqlite3_extended_errcode(db::Ptr{Cvoid})
    @NULLCHECK db
    return ccall( (:sqlite3_extended_errcode, libsqlite),
        Cint, (Ptr{Cvoid},),
        db)
end
# SQLITE_API int sqlite3_errcode(sqlite3 *db);
# SQLITE_API int sqlite3_extended_errcode(sqlite3 *db);
function sqlite3_errstr(ret::Cint)
    return ccall( (:sqlite3_errstr, libsqlite),
        Ptr{UInt8}, (Cint,),
        ret)
end
# SQLITE_API const char *sqlite3_errstr(int);

# SQLITE_API int sqlite3_limit(sqlite3*, int id, int newVal);

# SQLITE_API int sqlite3_stmt_readonly(sqlite3_stmt *pStmt);

# SQLITE_API int sqlite3_stmt_busy(sqlite3_stmt*);

# SQLITE_API int sqlite3_table_column_metadata(
#   sqlite3 *db,                /* Connection handle */
#   const char *zDbName,        /* Database name or NULL */
#   const char *zTableName,     /* Table name */
#   const char *zColumnName,    /* Column name */
#   char const **pzDataType,    /* OUTPUT: Declared data type */
#   char const **pzCollSeq,     /* OUTPUT: Collation sequence name */
#   int *pNotNull,              /* OUTPUT: True if NOT NULL constraint exists */
#   int *pPrimaryKey,           /* OUTPUT: True if column part of PK */
#   int *pAutoinc               /* OUTPUT: True if column is auto-increment */
# );

# SQLITE_API int sqlite3_db_status(sqlite3*, int op, int *pCur, int *pHiwtr, int resetFlg);

# Not directly used
function sqlite3_open_v2(file::AbstractString, handle, flags::Cint, vfs::AbstractString)
    return ccall( (:sqlite3_open_v2, libsqlite),
            Cint, (Ptr{UInt8}, Ptr{Cvoid}, Cint, Ptr{UInt8}),
            file, handle, flags, vfs)
end
function sqlite3_prepare(handle::Ptr{Cvoid}, query::AbstractString, stmt, unused)
    @NULLCHECK handle
    return ccall( (:sqlite3_prepare, libsqlite),
        Cint, (Ptr{Cvoid}, Ptr{UInt8}, Cint, Ptr{Cvoid}, Ptr{Cvoid}),
            handle, query, sizeof(query), stmt, unused)
end
function sqlite3_prepare16(handle::Ptr{Cvoid}, query::AbstractString, stmt, unused)
    @NULLCHECK handle
    return ccall( (:sqlite3_prepare16, libsqlite),
        Cint, (Ptr{Cvoid}, Ptr{UInt8}, Cint, Ptr{Cvoid}, Ptr{Cvoid}),
            handle, query, sizeof(query), stmt, unused)
end
function sqlite3_close_v2(handle::Ptr{Cvoid})
    @NULLCHECK handle
    try
        return ccall( (:sqlite3_close_v2, libsqlite),
            Cint, (Ptr{Cvoid},),
            handle)
    catch
        # Older versions of the library don't have this, abort to other close
        warn("sqlite3_close_v2 not available.")
        sqlite3_close(handle)
    end
end
