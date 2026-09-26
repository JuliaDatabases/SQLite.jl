"""
    SQLite.Blob(db, table, column, rowid; schema="main", writable=false)
    SQLite.Blob(f, db, table, column, rowid; kwargs...)

Open an existing BLOB or TEXT value as a seekable byte stream. The default is
read-only; `writable=true` permits reading and overwriting its existing bytes.
Use SQL `zeroblob(n)` to allocate a value before opening it. The stream cannot
resize the value and does not deserialize stored Julia objects.

Positions are zero-based byte offsets between zero and the fixed value length.
Use `read!` or `readbytes!` with a reusable buffer to read incrementally. `read(io)`
and `readavailable(io)` allocate the whole remaining value. Updating or deleting
the row expires the stream, including updates to other columns; subsequent
native reads and writes throw `SQLiteException`.

Call `close(io)` to release the stream. Closing a writable stream can commit an
implicit transaction and can throw, even though the stream is then closed.
Closing its database also closes all its BLOB streams and reports close errors.
A finalizer provides best-effort cleanup, but cannot report commit failures.
Handle cleanup shares the database's lifecycle lock with prepared statements;
finalizers defer when that lock is busy.
`flush` does not commit. A do-block closes the stream even if `f` throws, but does
not roll back prior writes. Use an explicit transaction for atomic changes and
close the stream before committing that transaction.

`schema` is `"main"`, `"temp"`, or an attached database name. The native SQLite
restrictions on rowid tables and writable indexed/foreign-key columns apply.
Synchronize concurrent operations on the same stream or connection.
"""
mutable struct Blob <: IO
    db::DB
    handle::BlobWrapper
    pos::Int
    len::Int
    writable::Bool

    function Blob(db::DB, table::AbstractString, column::AbstractString, rowid::Integer;
                  schema::AbstractString = "main", writable::Bool = false)
        isopen(db) || throw(SQLiteException("DB is closed"))
        for name in (schema, table, column)
            occursin('\0', name) && throw(ArgumentError("BLOB names cannot contain NUL"))
        end
        id = Int64(rowid)
        Base.@lock db.lock begin
            handle = Ref{BlobHandle}(C_NULL)
            @CHECK db C.sqlite3_blob_open(db.handle, schema, table, column, id, writable, handle)
            blob = new(db, handle, 0, Int(C.sqlite3_blob_bytes(handle[])), writable)
            finalizer(_finalize_blob!, blob)
            db.blob_handles[handle] = nothing
            return blob
        end
    end
end

function Blob(f::Function, db::DB, table::AbstractString, column::AbstractString,
              rowid::Integer; kwargs...)
    blob = Blob(db, table, column, rowid; kwargs...)
    result = try
        f(blob)
    catch err
        original = CapturedException(err, catch_backtrace())
        try
            close(blob)
        catch close_error
            throw(CompositeException(Any[original, CapturedException(close_error, catch_backtrace())]))
        end
        rethrow()
    end
    close(blob)
    return result
end

function _close_blob_handle!(db::DB, handle::BlobWrapper, report_errors::Bool)
    ptr = handle[]
    ptr == C_NULL && return nothing
    # The caller holds db.lock. SQLite consumes the handle even when commit fails.
    handle[] = C_NULL
    delete!(db.blob_handles, handle)
    rc = C.sqlite3_blob_close(ptr)
    if report_errors && rc != C.SQLITE_OK
        return isopen(db) ? sqliteexception(db) : SQLiteException(unsafe_string(C.sqlite3_errstr(rc)))
    end
    return nothing
end

function Base.close(blob::Blob)
    Base.@lock blob.db.lock begin
        err = _close_blob_handle!(blob.db, blob.handle, true)
        err === nothing || throw(err)
    end
    return nothing
end

function _finalize_blob!(blob::Blob)
    if islocked(blob.db.lock) || !trylock(blob.db.lock)
        finalizer(_finalize_blob!, blob)
        return nothing
    end
    try
        _close_blob_handle!(blob.db, blob.handle, false)
    finally
        unlock(blob.db.lock)
    end
    return nothing
end

Base.isopen(blob::Blob) = blob.handle[] != C_NULL && isopen(blob.db)
Base.isreadable(blob::Blob) = isopen(blob)
Base.iswritable(blob::Blob) = isopen(blob) && blob.writable

function _check_blob_open(blob::Blob)
    isopen(blob) || throw(ArgumentError("BLOB is closed"))
    return nothing
end

Base.position(blob::Blob) = (_check_blob_open(blob); blob.pos)
Base.bytesavailable(blob::Blob) = (_check_blob_open(blob); blob.len - blob.pos)
Base.eof(blob::Blob) = bytesavailable(blob) == 0
Base.flush(blob::Blob) = _check_blob_open(blob)

function Base.seek(blob::Blob, pos::Integer)
    _check_blob_open(blob)
    0 <= pos <= blob.len || throw(ArgumentError("BLOB position is out of bounds"))
    blob.pos = Int(pos)
    return blob
end

Base.seekstart(blob::Blob) = seek(blob, 0)
Base.seekend(blob::Blob) = seek(blob, blob.len)
function Base.skip(blob::Blob, offset::Integer)
    _check_blob_open(blob)
    -blob.pos <= offset <= blob.len - blob.pos || throw(ArgumentError("BLOB position is out of bounds"))
    return seek(blob, blob.pos + Int(offset))
end

function Base.unsafe_read(blob::Blob, ptr::Ptr{UInt8}, n::UInt)
    n <= UInt(bytesavailable(blob)) || throw(EOFError())
    GC.@preserve blob begin
        @CHECK blob.db C.sqlite3_blob_read(blob.handle[], ptr, Cint(n), Cint(blob.pos))
    end
    blob.pos += Int(n)
    return nothing
end

function Base.unsafe_write(blob::Blob, ptr::Ptr{UInt8}, n::UInt)
    _check_blob_open(blob)
    blob.writable || throw(ArgumentError("BLOB is read-only"))
    n <= UInt(blob.len - blob.pos) || throw(ArgumentError("write exceeds BLOB length"))
    GC.@preserve blob begin
        @CHECK blob.db C.sqlite3_blob_write(blob.handle[], ptr, Cint(n), Cint(blob.pos))
    end
    blob.pos += Int(n)
    return Int(n)
end

function Base.read(blob::Blob, ::Type{UInt8})
    value = Ref{UInt8}(0)
    unsafe_read(blob, value, 1)
    return value[]
end

Base.write(blob::Blob, value::UInt8) = unsafe_write(blob, Ref(value), 1)

function Base.readbytes!(blob::Blob, data::Vector{UInt8}, n::Integer = length(data))
    n >= 0 || throw(ArgumentError("byte count must be nonnegative"))
    count = Int(min(n, bytesavailable(blob)))
    length(data) < count && resize!(data, count)
    GC.@preserve data unsafe_read(blob, pointer(data), UInt(count))
    return count
end

function Base.read(blob::Blob, n::Integer = typemax(Int))
    n >= 0 || throw(ArgumentError("byte count must be nonnegative"))
    data = Vector{UInt8}(undef, Int(min(n, bytesavailable(blob))))
    return read!(blob, data)
end

Base.readavailable(blob::Blob) = read(blob)
