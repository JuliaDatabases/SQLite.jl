function sqlite3_prepare(dbptr::Ptr{Void},
                         sql::String,
                         stmtptrptr::Vector{Ptr{Void}},
                         unusedptrptr::Vector{Ptr{Void}})
    @windows_only return ccall((:sqlite3_prepare, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}, Ptr{Void}),
                               dbptr,
                               sql,
                               length(sql),
                               stmtptrptr,
                               unusedptrptr)
    @unix_only return ccall((:sqlite3_prepare, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}, Ptr{Void}),
                            dbptr,
                            sql,
                            length(sql),
                            stmtptrptr,
                            unusedptrptr)
end

function sqlite3_prepare16(dbptr::Ptr{Void},
                           sql::String,
                           stmtptrptr::Vector{Ptr{Void}},
                           unusedptrptr::Vector{Ptr{Void}})
    @windows_only return ccall((:sqlite3_prepare16, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}, Ptr{Void}),
                               dbptr,
                               sql,
                               length(sql),
                               stmtptrptr,
                               unusedptrptr)
    @unix_only return ccall((:sqlite3_prepare16, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}, Ptr{Void}),
                            dbptr,
                            sql,
                            length(sql),
                            stmtptrptr,
                            unusedptrptr)
end

function sqlite3_prepare_v2(dbptr::Ptr{Void},
                            sql::String,
                            stmtptrptr::Vector{Ptr{Void}},
                            unusedptrptr::Vector{Ptr{Void}})
    @windows_only return ccall((:sqlite3_prepare_v2, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}, Ptr{Void}),
                               dbptr,
                               sql,
                               length(sql),
                               stmtptrptr,
                               unusedptrptr)
    @unix_only return ccall((:sqlite3_prepare_v2, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}, Ptr{Void}),
                            dbptr,
                            sql,
                            length(sql),
                            stmtptrptr,
                            unusedptrptr)
end

function sqlite3_prepare16_v2(dbptr::Ptr{Void},
                              sql::String,
                              stmtptrptr::Vector{Ptr{Void}},
                              unusedptrptr::Vector{Ptr{Void}})
    @windows_only return ccall((:sqlite3_prepare16_v2, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}, Ptr{Void}),
                               dbptr,
                               sql,
                               length(sql),
                               stmtptrptr,
                               unusedptrptr)
    @unix_only return ccall((:sqlite3_prepare16_v2, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Ptr{Uint8}, Cint, Ptr{Void}, Ptr{Void}),
                            dbptr,
                            sql,
                            length(sql),
                            stmtptrptr,
                            unusedptrptr)
end
