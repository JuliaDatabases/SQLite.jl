function sqlite3_open(path::String,
                      dbptr::Vector{Ptr{Void}})
    @windows_only return ccall((:sqlite3_open, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Uint8}, Ptr{Void}),
                               path,
                               dbptr)
    @unix_only return ccall((:sqlite3_open, sqlite3_lib),
                             Cint,
                             (Ptr{Uint8}, Ptr{Void}),
                             path,
                             dbptr)
end

function sqlite3_open16(path::String,
                        dbptr::Vector{Ptr{Void}})
    @windows_only return ccall((:sqlite3_open16, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Uint8}, Ptr{Void}),
                               path,
                               dbptr)
    @unix_only return ccall((:sqlite3_open16, sqlite3_lib),
                            Cint,
                            (Ptr{Uint8}, Ptr{Void}),
                            path,
                            dbptr)
end

function sqlite3_open_v2(path::String,
                         dbptr::Vector{Ptr{Void}},
                         flags::Cint,
                         vfs::Ptr{Void})
    @windows_only return ccall((:sqlite3_open_v2, sqlite3_lib), stdcall,
                               Cint,
                               (Ptr{Uint8}, Ptr{Void}, Cint, Ptr{Uint8}),
                               path,
                               dbptr,
                               flags,
                               vfs)
    @unix_only return ccall((:sqlite3_open_v2, sqlite3_lib),
                            Cint,
                            (Ptr{Uint8}, Ptr{Void}, Cint, Ptr{Uint8}),
                            path,
                            dbptr,
                            flags,
                            vfs)
end
