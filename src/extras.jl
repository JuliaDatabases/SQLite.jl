function sql(stmt::SQLiteStatementHandle)
    chrptr = SQLite.sqlite3_sql(stmt.ptr)
    return bytestring(chrptr)
end

function last_insert_rowid(db::SQLiteDatabaseHandle)
    return sqlite3_last_insert_rowid(db.ptr)
end
