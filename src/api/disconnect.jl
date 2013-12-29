function sqlite3_close(dbptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_close, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               dbptr)
    @unix_only return ccall((:sqlite3_close, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            dbptr)
end

function sqlite3_close_v2(dbptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_close_v2, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               dbptr)
    @unix_only return ccall((:sqlite3_close_v2, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            dbptr)
end
