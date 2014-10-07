function sqlite3_errmsg()
    return ccall( (:sqlite3_errmsg, sqlite3_lib),
        Ptr{Uint8}, ()
        )
end
function sqlite3_errmsg(db::Ptr{Void})
    return ccall( (:sqlite3_errmsg, sqlite3_lib),
        Ptr{Uint8}, (Ptr{Void},),
        db)
end
function sqlite3_open(file::String,handle::Array{Ptr{Void},1})
    return ccall( (:sqlite3_open, sqlite3_lib),
        Cint, (Ptr{Uint8},Ptr{Void}),
        file,handle)
end
function sqlite3_open16(file::UTF16String,handle::Array{Ptr{Void},1})
    return ccall( (:sqlite3_open16, sqlite3_lib),
        Cint, (Ptr{Uint16},Ptr{Void}),
        file,handle)
end
function sqlite3_close(handle::Ptr{Void})
    return ccall( (:sqlite3_close, sqlite3_lib),
        Cint, (Ptr{Void},),
        handle)
end
function sqlite3_next_stmt(db::Ptr{Void},stmt::Ptr{Void})
    return ccall( (:sqlite3_next_stmt, sqlite3_lib),
        Ptr{Void}, (Ptr{Void},Ptr{Void}),
        db, stmt)
end
function sqlite3_prepare_v2(handle::Ptr{Void},query::String,stmt::Array{Ptr{Void},1},unused::Array{Ptr{Void},1})
    return ccall( (:sqlite3_prepare_v2, sqlite3_lib),
        Cint, (Ptr{Void},Ptr{Uint8},Cint,Ptr{Void},Ptr{Void}),
            handle,query,sizeof(query),stmt,unused)
end
function sqlite3_prepare16_v2(handle::Ptr{Void},query::String,stmt::Array{Ptr{Void},1},unused::Array{Ptr{Void},1})
    return ccall( (:sqlite3_prepare16_v2, sqlite3_lib),
        Cint, (Ptr{Void},Ptr{Uint16},Cint,Ptr{Void},Ptr{Void}),
        handle,query,sizeof(query),stmt,unused)
end
function sqlite3_finalize(stmt::Ptr{Void})
    return ccall( (:sqlite3_finalize, sqlite3_lib),
        Cint, (Ptr{Void},),
        stmt)
end
# SQLITE_API int sqlite3_bind_parameter_index(sqlite3_stmt*, const char *zName);
function sqlite3_bind_parameter_index(stmt::Ptr{Void},value::String)
    return ccall( (:sqlite3_bind_parameter_index, sqlite3_lib),
        Cint, (Ptr{Void},Ptr{Uint8}),
        stmt,utf8(value))
end
# SQLITE_API int sqlite3_bind_double(sqlite3_stmt*, int, double);
function sqlite3_bind_double(stmt::Ptr{Void},col::Int,value::Float64)
    return ccall( (:sqlite3_bind_double, sqlite3_lib),
        Cint, (Ptr{Void},Cint,Float64),
        stmt,col,value)
end
# SQLITE_API int sqlite3_bind_int(sqlite3_stmt*, int, int);
function sqlite3_bind_int(stmt::Ptr{Void},col::Int,value::Int32)
    return ccall( (:sqlite3_bind_int, sqlite3_lib),
        Cint, (Ptr{Void},Cint,Int32),
        stmt,col,value)
end
# SQLITE_API int sqlite3_bind_int64(sqlite3_stmt*, int, sqlite3_int64);
function sqlite3_bind_int64(stmt::Ptr{Void},col::Int,value::Int64)
    return ccall( (:sqlite3_bind_int64, sqlite3_lib),
        Cint, (Ptr{Void},Cint,Int64),
        stmt,col,value)
end
# SQLITE_API int sqlite3_bind_null(sqlite3_stmt*, int);
function sqlite3_bind_null(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_bind_null, sqlite3_lib),
        Cint, (Ptr{Void},Cint),
        stmt,col)
end
# SQLITE_API int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
function sqlite3_bind_text(stmt::Ptr{Void},col::Int,value::String)
    return ccall( (:sqlite3_bind_text, sqlite3_lib),
        Cint, (Ptr{Void},Cint,Ptr{Uint8},Cint,Ptr{Void}),
        stmt,col,value,sizeof(value),C_NULL)
end
# SQLITE_API int sqlite3_bind_text16(sqlite3_stmt*, int, const void*, int, void(*)(void*));
function sqlite3_bind_text16(stmt::Ptr{Void},col::Int,value::UTF16String)
    return ccall( (:sqlite3_bind_text, sqlite3_lib),
        Cint, (Ptr{Void},Cint,Ptr{Uint16},Cint,Ptr{Void}),
        stmt,col,value,sizeof(value),C_NULL)
end
# SQLITE_API int sqlite3_bind_blob(sqlite3_stmt*, int, const void*, int n, void(*)(void*));
function sqlite3_bind_blob(stmt::Ptr{Void},col::Int,value)
    return ccall( (:sqlite3_bind_blob, sqlite3_lib),
        Cint, (Ptr{Void},Cint,Ptr{Uint8},Cint,Ptr{Void}),
        stmt,col,value,sizeof(value),SQLITE_STATIC)
end
# SQLITE_API int sqlite3_bind_zeroblob(sqlite3_stmt*, int, int n);
# SQLITE_API int sqlite3_bind_value(sqlite3_stmt*, int, const sqlite3_value*);

# SQLITE_API int sqlite3_bind_parameter_count(sqlite3_stmt*);
# SQLITE_API const char *sqlite3_bind_parameter_name(sqlite3_stmt*, int);
# SQLITE_API int sqlite3_clear_bindings(sqlite3_stmt*);

function sqlite3_step(stmt::Ptr{Void})
    return ccall( (:sqlite3_step, sqlite3_lib),
        Cint, (Ptr{Void},),
        stmt)
end
function sqlite3_column_count(stmt::Ptr{Void})
    return ccall( (:sqlite3_column_count, sqlite3_lib),
        Cint, (Ptr{Void},),
        stmt)
end
function sqlite3_column_type(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_type, sqlite3_lib),
        Cint, (Ptr{Void},Cint),
        stmt,col)
end

function sqlite3_column_blob(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_blob, sqlite3_lib),
        Ptr{Void}, (Ptr{Void},Cint),
        stmt,col)
end

function sqlite3_column_bytes(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_bytes, sqlite3_lib),
        Cint, (Ptr{Void},Cint),
        stmt,col)
end
function sqlite3_column_bytes16(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_bytes16, sqlite3_lib),
        Cint, (Ptr{Void},Cint),
        stmt,col)
end
function sqlite3_column_double(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_double, sqlite3_lib),
        Cdouble, (Ptr{Void},Cint),
        stmt,col)
end
function sqlite3_column_int(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_int, sqlite3_lib),
        Cint, (Ptr{Void},Cint),
        stmt,col)
end
function sqlite3_column_int64(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_int64, sqlite3_lib),
        Clonglong, (Ptr{Void},Cint),
        stmt,col)
end
function sqlite3_column_text(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_text, sqlite3_lib),
        Ptr{Uint8}, (Ptr{Void},Cint),
        stmt,col)
end
function sqlite3_column_text16(stmt::Ptr{Void},col::Int)
    return ccall( (:sqlite3_column_text16, sqlite3_lib),
        Ptr{Void}, (Ptr{Void},Cint),
        stmt,col)
end
const FUNCS = [SQLITE_INTEGER=>sqlite3_column_int,SQLITE_FLOAT=>sqlite3_column_double,SQLITE3_TEXT=>sqlite3_column_text,SQLITE_BLOB=>sqlite3_column_blob,SQLITE_NULL=>sqlite3_column_text]
# function sqlite3_column_value(stmt::Ptr{Void},col::Cint)
#     return ccall( (:sqlite3_column_value, sqlite3_lib),
#             Ptr{Void}, (Ptr{Void},Cint),
#             stmt,col)
# end
# SQLITE_API sqlite3_value *sqlite3_column_value(sqlite3_stmt*, int iCol);
function sqlite3_reset(stmt::Ptr{Void})
    return ccall( (:sqlite3_reset, sqlite3_lib),
        Cint, (Ptr{Void},),
        stmt)
end

# SQLITE_API const char *sqlite3_column_name(sqlite3_stmt*, int N);
function sqlite3_column_name(stmt::Ptr{Void},n::Int)
    return ccall( (:sqlite3_column_name, sqlite3_lib),
        Ptr{Uint8}, (Ptr{Void},Cint),
        stmt,n)
end
function sqlite3_column_name16(stmt::Ptr{Void},n::Int)
    return ccall( (:sqlite3_column_name16, sqlite3_lib),
        Ptr{Uint8}, (Ptr{Void},Cint),
        stmt,n)
end

function sqlite3_changes(db::Ptr{Void})
   return ccall( (:sqlite3_changes, sqlite3_lib),
        Cint, (Ptr{Void},),
        db)
end
function sqlite3_total_changes(db::Ptr{Void})
   return ccall( (:sqlite3_changes, sqlite3_lib),
        Cint, (Ptr{Void},),
        db)
end
# SQLITE_API const void *sqlite3_column_name16(sqlite3_stmt*, int N);

# SQLITE_API const char *sqlite3_column_database_name(sqlite3_stmt*,int);
# SQLITE_API const void *sqlite3_column_database_name16(sqlite3_stmt*,int);
# SQLITE_API const char *sqlite3_column_table_name(sqlite3_stmt*,int);
# SQLITE_API const void *sqlite3_column_table_name16(sqlite3_stmt*,int);
# SQLITE_API const char *sqlite3_column_origin_name(sqlite3_stmt*,int);
# SQLITE_API const void *sqlite3_column_origin_name16(sqlite3_stmt*,int);

# SQLITE_API const char *sqlite3_column_decltype(sqlite3_stmt*,int);
# SQLITE_API const void *sqlite3_column_decltype16(sqlite3_stmt*,int);

# SQLITE_API int sqlite3_data_count(sqlite3_stmt *pStmt);

function sqlite3_initialize()
    return ccall( (:sqlite3_initialize, sqlite3_lib),
        Cint, (),
        )
end
function sqlite3_shutdown()
    return ccall( (:sqlite3_shutdown, sqlite3_lib),
        Cint, (),
        )
end
function sqlite3_os_init()
    return ccall( (:sqlite3_os_init, sqlite3_lib),
        Cint, (),
        )
end
function sqlite3_os_end()
    return ccall( (:sqlite3_os_end, sqlite3_lib),
        Cint, (),
        )
end
function sqlite3_free_table(result::Array{String,1})
    return ccall( (:sqlite3_free_table, sqlite_lib),
        Void, (Ptr{Ptr{Void}},),
        result)
end

# SQLITE_API const char *sqlite3_uri_parameter(const char *zFilename, const char *zParam);
# SQLITE_API int sqlite3_uri_boolean(const char *zFile, const char *zParam, int bDefault);
# SQLITE_API sqlite3_int64 sqlite3_uri_int64(const char*, const char*, sqlite3_int64);
function sqlite3_errcode(db::Ptr{Void})
    return ccall( (:sqlite3_errcode, sqlite3_lib),
        Cint, (Ptr{Void},),
        db)
end
function sqlite3_extended_errcode(db::Ptr{Void})
    return ccall( (:sqlite3_extended_errcode, sqlite3_lib),
        Cint, (Ptr{Void},),
        db)
end
# SQLITE_API int sqlite3_errcode(sqlite3 *db);
# SQLITE_API int sqlite3_extended_errcode(sqlite3 *db);
function sqlite3_errstr(ret::Cint)
    return ccall( (:sqlite3_errstr, sqlite3_lib),
        Ptr{Uint8}, (Cint,),
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
function sqlite3_open_v2(file::String,handle::Array{Ptr{Void},1},flags::Cint,vfs::String)
    return ccall( (:sqlite3_open_v2, sqlite3_lib),
            Cint, (Ptr{Uint8},Ptr{Void},Cint,Ptr{Uint8}),
            file,handle,flags,vfs)
end
function sqlite3_prepare(handle::Ptr{Void},query::String,stmt::Array{Ptr{Void},1},unused::Array{Ptr{Void},1})
    return ccall( (:sqlite3_prepare, sqlite3_lib),
        Cint, (Ptr{Void},Ptr{Uint8},Cint,Ptr{Void},Ptr{Void}),
            handle,query,sizeof(query),stmt,unused)
end
function sqlite3_prepare16(handle::Ptr{Void},query::String,stmt::Array{Ptr{Void},1},unused::Array{Ptr{Void},1})
    return ccall( (:sqlite3_prepare16, sqlite3_lib),
        Cint, (Ptr{Void},Ptr{Uint8},Cint,Ptr{Void},Ptr{Void}),
            handle,query,sizeof(query),stmt,unused)
end
function sqlite3_close_v2(handle::Ptr{Void})
    try
        return ccall( (:sqlite3_close_v2, sqlite3_lib),
            Cint, (Ptr{Void},),
            handle)
    catch
        # Older versions of the library don't have this, abort to other close
        warn("sqlite3_close_v2 not available.")
        sqlite3_close(handle)
    end
end