using SQLite
using SQLite: DBInterface
const C = SQLite.C

function @main(args::Vector{String})::Cint
    input = isempty(args) ? "runtime statement" : args[1]
    bytes = Vector{UInt8}(input)
    append!(bytes, UInt8[0, 0xff])
    db = SQLite.DB()
    SQLite.execute(db, "CREATE TABLE data (id INTEGER PRIMARY KEY, real REAL, text TEXT, bytes BLOB)")
    insert = SQLite.Stmt(db, "INSERT INTO data VALUES (?, ?, ?, ?)")
    SQLite.execute(insert, (7, 3.5, input, bytes)) == C.SQLITE_DONE || return 1
    try
        SQLite.execute(insert, (7, 4.0, "duplicate", UInt8[1]))
        return 2
    catch err
        err isa SQLiteException || return 3
    end
    SQLite.execute(insert, (8, -1.25, input, bytes)) == C.SQLITE_DONE || return 4
    select = SQLite.Stmt(db, "SELECT id, real, text, bytes FROM data WHERE id=?")
    SQLite.execute(select, (7,)) == C.SQLITE_ROW || return 5
    handle = SQLite._get_stmt_handle(select)
    C.sqlite3_column_int64(handle, 0) == 7 || return 6
    C.sqlite3_column_double(handle, 1) == 3.5 || return 7
    unsafe_string(C.sqlite3_column_text(handle, 2)) == input || return 8
    n = Int(C.sqlite3_column_bytes(handle, 3))
    output = Vector{UInt8}(undef, n)
    GC.@preserve select output unsafe_copyto!(pointer(output), Ptr{UInt8}(C.sqlite3_column_blob(handle, 3)), n)
    output == bytes || return 9
    DBInterface.close!(select)
    isempty(db.stmt_wrappers) && return 10
    close(db)
    SQLite.isready(insert) && return 11
    DBInterface.close!(insert)
    isempty(db.stmt_wrappers) || return 12
    GC.gc()
    return 0
end

Base.Experimental.entrypoint(main, (Vector{String},))
