function sqlite3_sql(stmtptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_sql, sqlite3_lib),
                               stdcall,
                               Ptr{Uint8},
                               (Ptr{Void}, ),
                               stmtptr)
    @unix_only return ccall((:sqlite3_sql, sqlite3_lib),
                            Ptr{Uint8},
                            (Ptr{Void}, ),
                            stmtptr)
end

function sqlite3_last_insert_rowid(dbptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_last_insert_rowid, sqlite3_lib),
                               stdcall,
                               Int64,
                               (Ptr{Void}, ),
                               dbptr)
    @unix_only return ccall((:sqlite3_last_insert_rowid, sqlite3_lib),
                             Int64,
                             (Ptr{Void}, ),
                             dbptr)
end
