function sql(stmt::SQLiteStatementHandle)
    return bytestring(SQLite.sqlite3_sql(stmt.ptr))
end

function last_insert_rowid(db::SQLiteDatabaseHandle)
    return sqlite3_last_insert_rowid(db.ptr)
end
