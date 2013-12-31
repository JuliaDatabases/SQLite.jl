abstract SQLite3 <: DBI.DatabaseSystem

type SQLiteDatabaseHandle <: DBI.DatabaseHandle
    ptr::Ptr{Void}
    status::Cint
end

type SQLiteStatementHandle <: DBI.StatementHandle
    db::SQLiteDatabaseHandle
    ptr::Ptr{Void}
    executed::Int

    function SQLiteStatementHandle(db::SQLiteDatabaseHandle,
                                   ptr::Ptr{Void})
        new(db, ptr, 0)
    end
end
