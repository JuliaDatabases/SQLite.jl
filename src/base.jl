struct SQLiteException <: Exception
    msg::AbstractString
end

# SQLite3 DB connection handle
const DBHandle = Ptr{C.sqlite3}
# SQLite3 statement handle
const StmtHandle = Ptr{C.sqlite3_stmt}

const StmtWrapper = Ref{StmtHandle}

sqliteexception(handle::DBHandle) = SQLiteException(unsafe_string(C.sqlite3_errmsg(handle)))
function sqliteexception(handle::DBHandle, stmt::StmtHandle)
    errstr = unsafe_string(C.sqlite3_errmsg(handle))
    stmt_text_handle = C.sqlite3_expanded_sql(stmt)
    stmt_text = unsafe_string(stmt_text_handle)
    msg = "$errstr on statement \"$stmt_text\""
    C.sqlite3_free(stmt_text_handle)
    return SQLiteException(msg)
end

sqliteerror(args...) = throw(sqliteexception(args...))

# macros

macro OK(func)
    :($(esc(func)) == C.SQLITE_OK)
end

macro CHECK(db, ex)
    esc(quote
        if !(@OK $ex)
            sqliteerror($db)
        end
        C.SQLITE_OK
    end)
end

const SQLNullPtrError = SQLiteException("Cannot operate on null pointer")
macro NULLCHECK(ptr)
    esc(quote
        if $ptr == C_NULL
            throw(SQLNullPtrError)
        end
    end)
end

"""
    sr"..."

This string literal is used to escape all special characters in the string,
useful for using regex in a query.
"""
macro sr_str(s)
    s
end
