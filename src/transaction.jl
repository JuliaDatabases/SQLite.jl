# Transaction-based commands
"""
    SQLite.transaction(db, mode="DEFERRED")
    SQLite.transaction(func, db)

Begin a transaction in the specified `mode`, default = "DEFERRED".

If `mode` is one of "", "DEFERRED", "IMMEDIATE" or "EXCLUSIVE" then a
transaction of that (or the default) mutable struct is started. Otherwise a savepoint
is created whose name is `mode` converted to AbstractString.

In the second method, `func` is executed within a transaction (the transaction being committed upon successful execution)
"""
function transaction end

function transaction(db::DB, mode="DEFERRED")
    direct_execute(db, "PRAGMA temp_store=MEMORY;")
    if uppercase(mode) in ["", "DEFERRED", "IMMEDIATE", "EXCLUSIVE"]
        direct_execute(db, "BEGIN $(mode) TRANSACTION;")
    else
        direct_execute(db, "SAVEPOINT $(mode);")
    end
end

DBInterface.transaction(f, db::DB) = transaction(f, db)

@inline function transaction(f::Function, db::DB)
    # generate a random name for the savepoint
    name = string("SQLITE", Random.randstring(10))
    direct_execute(db, "PRAGMA synchronous = OFF;")
    transaction(db, name)
    try
        f()
    catch
        rollback(db, name)
        rethrow()
    finally
        # savepoints are not released on rollback
        commit(db, name)
        direct_execute(db, "PRAGMA synchronous = ON;")
    end
end

"""
    SQLite.commit(db)
    SQLite.commit(db, name)

commit a transaction or named savepoint
"""
function commit end

commit(db::DB) = direct_execute(db, "COMMIT TRANSACTION;")
commit(db::DB, name::AbstractString) = direct_execute(db, "RELEASE SAVEPOINT $(name);")

"""
    SQLite.rollback(db)
    SQLite.rollback(db, name)

rollback transaction or named savepoint
"""
function rollback end

rollback(db::DB) = direct_execute(db, "ROLLBACK TRANSACTION;")
rollback(db::DB, name::AbstractString) = direct_execute(db, "ROLLBACK TRANSACTION TO SAVEPOINT $(name);")
