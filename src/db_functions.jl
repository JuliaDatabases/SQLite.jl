struct DBTable
    name::String
    schema::Union{Tables.Schema, Nothing}
end

DBTable(name::String) = DBTable(name, nothing)

const DBTables = AbstractVector{DBTable}

Tables.istable(::Type{<:DBTables}) = true
Tables.rowaccess(::Type{<:DBTables}) = true
Tables.rows(dbtbl::DBTables) = dbtbl

"""
    SQLite.tables(db, sink=columntable)

returns a list of tables in `db`
"""
function tables(db::DB, sink=columntable)
    tblnames = DBInterface.execute(sink, db, "SELECT name FROM sqlite_master WHERE type='table';")
    return [DBTable(tbl, Tables.schema(DBInterface.execute(db,"SELECT * FROM $(tbl) LIMIT 0"))) for tbl in tblnames.name]
end

"""
    SQLite.indices(db, sink=columntable)

returns a list of indices in `db`
"""
indices(db::DB, sink=columntable) = DBInterface.execute(sink, db, "SELECT name FROM sqlite_master WHERE type='index';")

"""
    SQLite.columns(db, table, sink=columntable)

returns a list of columns in `table`
"""
columns(db::DB, table::AbstractString, sink=columntable) = DBInterface.execute(sink, db, "PRAGMA table_info($(esc_id(table)))")

"""
    SQLite.last_insert_rowid(db)

returns the auto increment id of the last row
"""
last_insert_rowid(db::DB) = C.sqlite3_last_insert_rowid(db.handle)

"""
    SQLite.enable_load_extension(db, enable::Bool=true)

Enables extension loading (off by default) on the sqlite database `db`. Pass `false` as the second argument to disable.
"""
enable_load_extension(db::DB, enable::Bool=true) = C.sqlite3_enable_load_extension(db.handle, enable)

"""
    SQLite.busy_timeout(db, ms::Integer=0)

Set a busy handler that sleeps for a specified amount of milliseconds  when a table is locked. After at least ms milliseconds of sleeping, the handler will return 0, causing sqlite to return SQLITE_BUSY.
"""
busy_timeout(db::DB, ms::Integer=0) = C.sqlite3_busy_timeout(db.handle, ms)
