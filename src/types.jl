abstract SQLite3 <: DBI.DatabaseSystem

type SQLiteDatabaseHandle <: DBI.DatabaseHandle
    ptr::Ptr{Void}
    status::Cint
end

immutable SQLiteStatementHandle <: DBI.StatementHandle
    db::SQLiteDatabaseHandle
    ptr::Ptr{Void}
end
