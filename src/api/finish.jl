function sqlite3_finalize(stmtptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_finalize, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               stmtptr)
    @unix_only return ccall((:sqlite3_finalize, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            stmtptr)
end
