function sqlite3_step(stmtptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_step, sqlite3_lib),
    	                         stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               stmtptr)
    @unix_only return ccall((:sqlite3_step, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            stmtptr)
end

function sqlite3_reset(stmtptr::Ptr{Void})
    @windows_only return ccall((:sqlite3_reset, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, ),
                               stmtptr)
    @unix_only return ccall((:sqlite3_reset, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, ),
                            stmtptr)
end

# TODO: Create all of the bind functions in a macro loop
function sqlite3_bind_double(stmtptr::Ptr{Void},
                             index::Int,
                             value::Float64)
    @windows_only return ccall((:sqlite3_bind_double, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint, Float64),
                               stmtptr,
                               index,
                               value)
    @unix_only return ccall((:sqlite3_bind_double, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint, Float64),
                            stmtptr,
                            index,
                            value)
end

function sqlite3_bind_int(stmtptr::Ptr{Void},
                          index::Int,
                          value::Int32)
    @windows_only return ccall((:sqlite3_bind_int, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint, Int32),
                               stmtptr,
                               index,
                               value)
    @unix_only return ccall((:sqlite3_bind_int, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint, Int32),
                            stmtptr,
                            index,
                            value)
end

function sqlite3_bind_int64(stmtptr::Ptr{Void},
                            index::Int,
                            value::Int64)
    @windows_only return ccall((:sqlite3_bind_int64, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint, Int64),
                               stmtptr,
                               index,
                               value)
    @unix_only return ccall((:sqlite3_bind_int64, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint, Int64),
                            stmtptr,
                            index,
                            value)
end

function sqlite3_bind_null(stmtptr::Ptr{Void},
                           index::Int)
    @windows_only return ccall((:sqlite3_bind_null, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint),
                               stmtptr,
                               index)
    @unix_only return ccall((:sqlite3_bind_null, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint),
                            stmtptr,
                            index)
end

function sqlite3_bind_text(stmtptr::Ptr{Void},
                           index::Int,
                           value::String,
                           len::Int,
                           cb::Ptr{Void})
    @windows_only return ccall((:sqlite3_bind_text, sqlite3_lib),
                               stdcall,
                               Cint,
                               (Ptr{Void}, Cint, Ptr{Uint8}, Cint, Ptr{Void}),
                               stmtptr,
                               index,
                               value,
                               len,
                               cb)
    @unix_only return ccall((:sqlite3_bind_text, sqlite3_lib),
                            Cint,
                            (Ptr{Void}, Cint, Ptr{Uint8}, Cint, Ptr{Void}),
                            stmtptr,
                            index,
                            value,
                            len,
                            cb)
end
