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
