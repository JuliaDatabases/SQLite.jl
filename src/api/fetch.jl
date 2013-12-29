function sqlite3_data_count(stmtptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_data_count, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               stmtptr)
    @unix_only return ccall((:sqlite3_data_count, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            stmtptr)
end

function sqlite3_column_count(stmtptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_column_count, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               stmtptr)
    @unix_only return ccall((:sqlite3_column_count, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            stmtptr)
end

function sqlite3_column_blob(stmtptr::Ptr{Void}, colindex::Int)
    @windows_only return ccall((:sqlite3_column_blob, sqlite3_lib),
                               stdcall,
                               Ptr{Void},
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_blob, sqlite3_lib),
                            Ptr{Void},
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_bytes(stmtptr::Ptr{Void}, colindex::Int)
    @windows_only return ccall((:sqlite3_column_bytes, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_bytes, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_bytes16(stmtptr::Ptr{Void}, colindex::Int)
    @windows_only return ccall((:sqlite3_column_bytes16, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_bytes16, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_double(stmtptr::Ptr{Void}, colindex::Int)
    @windows_only return ccall((:sqlite3_column_double, sqlite3_lib),
                               stdcall,
                               Cdouble,
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_double, sqlite3_lib),
                            Cdouble,
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_int(stmtptr::Ptr{Void}, colindex::Int)
    @windows_only return ccall((:sqlite3_column_int, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_int, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_int64(stmtptr::Ptr{Void}, colindex::Int)
    @windows_only return ccall((:sqlite3_column_int64, sqlite3_lib),
                               stdcall,
                               Clonglong,
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_int64, sqlite3_lib),
                            Clonglong,
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_text(stmtptr::Ptr{Void},colindex::Int)
    @windows_only return ccall((:sqlite3_column_text, sqlite3_lib),
                               stdcall,
                               Ptr{Uint8},
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_text, sqlite3_lib),
                            Ptr{Uint8},
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_text16(stmtptr::Ptr{Void}, colindex::Int)
    @windows_only return ccall((:sqlite3_column_text16, sqlite3_lib),
                               stdcall,
                               Ptr{Void},
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_text16, sqlite3_lib),
                            Ptr{Void},
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_type(stmtptr::Ptr{Void}, colindex::Int)
    @windows_only return ccall((:sqlite3_column_type, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint),
                               stmtptr,
                               colindex)
    @unix_only return ccall((:sqlite3_column_type, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint),
                            stmtptr,
                            colindex)
end

function sqlite3_column_name(stmtptr::Ptr{Void}, n::Int)
    @windows_only return ccall((:sqlite3_column_name, sqlite3_lib),
                               stdcall,
                               Ptr{Uint8},
                               (Ptr{Void}, Cint),
                               stmtptr,
                               n)
    @unix_only return ccall((:sqlite3_column_name, sqlite3_lib),
                            Ptr{Uint8},
                            (Ptr{Void}, Cint),
                            stmtptr,
                            n)
end

# TODO: Remove these
# const FUNCS = [
#                SQLITE_INTEGER => sqlite3_column_int,
#                SQLITE_FLOAT => sqlite3_column_double,
#                SQLITE3_TEXT => sqlite3_column_text,
#                SQLITE_BLOB => sqlite3_column_blob,
#                SQLITE_NULL => sqlite3_column_text
#               ]
