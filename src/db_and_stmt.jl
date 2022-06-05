"""
    `SQLite.DB()` => in-memory SQLite database
    `SQLite.DB(file)` => file-based SQLite database

Constructors for a representation of an sqlite database, either backed by an on-disk file or in-memory.

`SQLite.DB` requires the `file` string argument in the 2nd definition
as the name of either a pre-defined SQLite database to be opened,
or if the file doesn't exist, a database will be created.
Note that only sqlite 3.x version files are supported.

The `SQLite.DB` object represents a single connection to an SQLite database.
All other SQLite.jl functions take an `SQLite.DB` as the first argument as context.

To create an in-memory temporary database, call `SQLite.DB()`.

The `SQLite.DB` will be automatically closed/shutdown when it goes out of scope
(i.e. the end of the Julia session, end of a function call wherein it was created, etc.)
"""
mutable struct DB <: DBInterface.Connection
    file::String
    handle::DBHandle
    stmt_wrappers::WeakKeyDict{StmtWrapper,Nothing} # opened prepared statements

    function DB(f::AbstractString)
        handle_ptr = Ref{DBHandle}()
        f = String(isempty(f) ? f : expanduser(f))
        if @OK C.sqlite3_open(f, handle_ptr)
            db = new(f, handle_ptr[], WeakKeyDict{StmtWrapper,Nothing}())
            finalizer(_close_db!, db)
            return db
        else # error
            sqliteerror(handle_ptr[])
        end
    end
end
DB() = DB(":memory:")
DBInterface.connect(::Type{DB}) = DB()
DBInterface.connect(::Type{DB}, f::AbstractString) = DB(f)
DBInterface.close!(db::DB) = _close_db!(db)
Base.close(db::DB) = _close_db!(db)
Base.isopen(db::DB) = db.handle != C_NULL

function finalize_statements!(db::DB)
    # close stmts
    for stmt_wrapper in keys(db.stmt_wrappers)
        C.sqlite3_finalize(stmt_wrapper[])
        stmt_wrapper[] = C_NULL
    end
    empty!(db.stmt_wrappers)
end

function _close_db!(db::DB)
    finalize_statements!(db)

    # close DB
    C.sqlite3_close_v2(db.handle)
    db.handle = C_NULL

    return
end

sqliteexception(db::DB) = sqliteexception(db.handle)

Base.show(io::IO, db::DB) = print(io, string("SQLite.DB(", "\"$(db.file)\"", ")"))

# prepare given sql statement
function prepare_stmt_wrapper(db::DB, sql::AbstractString)
    handle_ptr = Ref{StmtHandle}()
    C.sqlite3_prepare_v2(db.handle, sql, sizeof(sql), handle_ptr, C_NULL)
    return handle_ptr
end

"""
    SQLite.Stmt(db, sql) => SQL.Stmt

Prepares an optimized internal representation of SQL statement in
the context of the provided SQLite3 `db` and constructs the `SQLite.Stmt`
Julia object that holds a reference to the prepared statement.

*Note*: the `sql` statement is not actually executed, but only compiled
(mainly for usage where the same statement is executed multiple times
with different parameters bound as values).

Internally `SQLite.Stmt` constructor creates the [`SQLite._Stmt`](@ref) object that is managed by `db`.
`SQLite.Stmt` references the `SQLite._Stmt` by its unique id.

The `SQLite.Stmt` will be automatically closed/shutdown when it goes out of scope
(i.e. the end of the Julia session, end of a function call wherein it was created, etc.).
One can also call `DBInterface.close!(stmt)` to immediately close it.

All prepared statements of a given DB connection are also automatically closed when the
DB is disconnected or when [`SQLite.finalize_statements!`](@ref) is explicitly called.
"""
mutable struct Stmt <: DBInterface.Statement
    db::DB
    stmt_wrapper::StmtWrapper
    params::Dict{Int,Any}

    function Stmt(db::DB, sql::AbstractString; register::Bool = true)
        stmt_wrapper = prepare_stmt_wrapper(db, sql)
        if register
            db.stmt_wrappers[stmt_wrapper] = nothing
        end
        stmt = new(db, stmt_wrapper, Dict{Int,Any}())
        finalizer(_close_stmt!, stmt)
        return stmt
    end
end

"""
    DBInterface.prepare(db::SQLite.DB, sql::AbstractString)

Prepare an SQL statement given as a string in the sqlite database; returns an `SQLite.Stmt` compiled object.
See `DBInterface.execute`(@ref) for information on executing a prepared statement and passing parameters to bind.
A `SQLite.Stmt` object can be closed (resources freed) using `DBInterface.close!`(@ref).
"""
DBInterface.prepare(db::DB, sql::AbstractString) = Stmt(db, sql)
DBInterface.getconnection(stmt::Stmt) = stmt.db
DBInterface.close!(stmt::Stmt) = _close_stmt!(stmt)

_get_stmt_handle(stmt::Stmt) = stmt.stmt_wrapper[]
function _set_stmt_handle(stmt::Stmt, handle)
    stmt.stmt_wrapper[] = handle
    return
end

function _close_stmt!(stmt::Stmt)
    C.sqlite3_finalize(_get_stmt_handle(stmt))
    _set_stmt_handle(stmt, C_NULL)

    return
end

sqliteexception(db::DB, stmt::Stmt) = sqliteexception(db.handle, _get_stmt_handle(stmt))
