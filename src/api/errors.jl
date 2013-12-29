function sqlite3_errcode(dbptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_errcode, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               dbptr)
    @unix_only return ccall((:sqlite3_errcode, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            dbptr)
end

function sqlite3_extended_errcode(dbptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_extended_errcode, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               dbptr)
    @unix_only return ccall((:sqlite3_extended_errcode, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            dbptr)
end

function sqlite3_errmsg(dbptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_errmsg, sqlite3_lib),
                               stdcall,
                               Ptr{Uint8},
                               (Ptr{Void}, ),
                               dbptr)
    @unix_only return ccall((:sqlite3_errmsg, sqlite3_lib),
                            Ptr{Uint8},
                            (Ptr{Void}, ),
                            dbptr)
end

function sqlite3_errstr(errcode::Cint)
    @windows_only return ccall((:sqlite3_errstr, sqlite3_lib),
                               stdcall,
                               Ptr{Uint8},
                               (Cint, ),
                               errcode)
    @unix_only return ccall((:sqlite3_errstr, sqlite3_lib),
                            Ptr{Uint8},
                            (Cint, ),
                            errcode)
end
