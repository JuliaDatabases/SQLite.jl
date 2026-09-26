module BlobTests
using SQLite, Test
using SQLite: DBInterface

function database(path = ":memory:", n = 32)
    db = SQLite.DB(path)
    SQLite.execute(db, "CREATE TABLE files (id INTEGER PRIMARY KEY, data BLOB, note TEXT)")
    SQLite.execute(db, "INSERT INTO files VALUES (1, zeroblob(?), 'original')", (n,))
    return db
end

function scalar(db, sql)
    result = DBInterface.execute(db, sql)
    try
        return first(result)[1]
    finally
        DBInterface.close!(result)
    end
end

function stored(path)
    db = SQLite.DB(path)
    try
        return scalar(db, "SELECT hex(data) FROM files WHERE id=1")
    finally
        close(db)
    end
end

const ABANDONED = Ref{Any}(nothing)
@noinline function abandon(db; writable = false)
    blob = SQLite.Blob(db, "files", "data", 1; writable)
    writable && write(blob, UInt8(0xaa))
    ABANDONED[] = blob
    return WeakRef(blob)
end

@noinline function owned_blob()
    db = database()
    return SQLite.Blob(db, "files", "data", 1), WeakRef(db)
end

@testset "Incremental BLOB IO" begin
    @testset "Base IO, positions, and buffer ownership" begin
        db = database()
        expected = UInt8.(0:31)
        SQLite.execute(db, "UPDATE files SET data=? WHERE id=1", (expected,))
        blob = SQLite.Blob(db, "files", "data", 1)
        try
            @test blob isa IO
            @test isopen(blob) && isreadable(blob) && !iswritable(blob)
            @test position(blob) == 0
            @test bytesavailable(blob) == length(expected)
            @test !eof(blob)
            @test read(blob, UInt8) == expected[1]
            @test read(blob, UInt32) == read(IOBuffer(expected[2:5]), UInt32)
            @test position(blob) == 5
            @test seekstart(blob) === blob
            @test read(blob, 4) == expected[1:4]
            @test skip(blob, 2) === blob
            @test position(blob) == 6
            @test skip(blob, -2) === blob
            @test position(blob) == 4
            target = fill(0xff, 10)
            @test read!(blob, view(target, 3:6)) == expected[5:8]
            @test target == vcat(fill(0xff, 2), expected[5:8], fill(0xff, 4))
            @test position(blob) == 8
            resized = UInt8[]
            @test readbytes!(blob, resized, 4) == 4
            @test resized == expected[9:12]
            seek(blob, 30)
            target = fill(0xff, 8)
            @test readbytes!(blob, target) == 2
            @test target == vcat(expected[31:32], fill(0xff, 6))
            @test length(target) == 8
            @test eof(blob) && bytesavailable(blob) == 0
            @test readbytes!(blob, target) == 0
            @test isempty(read(blob))
            @test read!(blob, UInt8[]) == UInt8[]
            @test_throws EOFError read(blob, UInt8)
            seek(blob, 31)
            @test_throws EOFError read!(blob, zeros(UInt8, 2))
            @test position(blob) == 31
            @test read(blob, typemax(UInt128)) == expected[32:32]
            @test seekstart(blob) === blob
            @test readavailable(blob) == expected
            @test seekend(blob) === blob
            @test position(blob) == 32
            @test flush(blob) === nothing
            for offset in (-1, 33, typemax(UInt), big(typemax(Int)) + 1)
                @test_throws ArgumentError seek(blob, offset)
                @test position(blob) == 32
            end
            for delta in (1, typemax(UInt), typemin(Int))
                @test_throws ArgumentError skip(blob, delta)
                @test position(blob) == 32
            end
            @test_throws ArgumentError read(blob, -1)
            @test_throws ArgumentError readbytes!(blob, target, -1)
            @test_throws ArgumentError write(blob, UInt8(1))
            @test_throws ArgumentError write(blob, UInt8[])
        finally
            close(blob)
        end
        @test !isopen(blob) && !isreadable(blob) && !iswritable(blob)
        @test close(blob) === nothing
        @test_throws ArgumentError position(blob)
        @test_throws ArgumentError seekstart(blob)
        @test_throws ArgumentError read(blob, 0)
        @test_throws ArgumentError write(blob, UInt8[])
        @test isempty(db.blob_handles)
        close(db)
    end

    @testset "Fixed-size writes and raw stored bytes" begin
        db = database()
        try
            SQLite.Blob(db, "files", "data", 1; writable = true) do blob
                @test isreadable(blob) && iswritable(blob)
                seek(blob, 3)
                @test write(blob, view(UInt8[0xff, 1, 2, 3, 0xff], 2:4)) == 3
                @test position(blob) == 6
                seekend(blob)
                @test write(blob, UInt8[]) == 0
                seek(blob, 31)
                @test_throws ArgumentError write(blob, UInt8[4, 5])
                @test position(blob) == 31
                @test write(blob, UInt8(9)) == 1
                seekstart(blob)
                @test read(blob) == vcat(zeros(UInt8, 3), UInt8[1, 2, 3], zeros(UInt8, 25), UInt8[9])
            end
            @test scalar(db, "SELECT hex(data) FROM files") == "000000010203" * "00"^25 * "09"
            SQLite.execute(db, "INSERT INTO files VALUES (2, zeroblob(0), ''), (3, 'é', ''), (4, NULL, ''), (5, 42, '')")
            SQLite.Blob(db, "files", "data", 2; writable = true) do blob
                @test eof(blob) && position(blob) == 0
                @test write(blob, UInt8[]) == 0
                @test isempty(read(blob))
                @test_throws ArgumentError write(blob, UInt8(1))
            end
            @test SQLite.Blob(read, db, "files", "data", 3) == collect(codeunits("é"))
            for id in (4, 5, 99)
                @test_throws SQLiteException SQLite.Blob(db, "files", "data", id)
            end
            value = (x = 42, y = "stored Julia value")
            SQLite.execute(db, "INSERT INTO files VALUES (6, ?, '')", (value,))
            @test scalar(db, "SELECT data FROM files WHERE id=6") == value
            @test SQLite.Blob(read, db, "files", "data", 6) == SQLite.sqlserialize(value)
        finally
            close(db)
        end
    end

    @testset "Names, schemas, and native restrictions" begin
        db = database()
        try
            for bad in ("missing", "files\0ignored")
                expected = occursin('\0', bad) ? ArgumentError : SQLiteException
                @test_throws expected SQLite.Blob(db, bad, "data", 1)
                @test_throws expected SQLite.Blob(db, "files", bad, 1)
                @test_throws expected SQLite.Blob(db, "files", "data", 1; schema = bad)
            end
            @test_throws InexactError SQLite.Blob(db, "files", "data", typemax(UInt64))
            @test isempty(db.blob_handles)
            SQLite.execute(db, "CREATE TEMP TABLE \"odd table\" (\"blob column\" BLOB)")
            SQLite.execute(db, "INSERT INTO temp.\"odd table\" VALUES (x'1234')")
            @test SQLite.Blob(read, db, "odd table", "blob column", 1; schema = "temp") == UInt8[0x12, 0x34]
            SQLite.execute(db, "ATTACH ':memory:' AS attached")
            SQLite.execute(db, "CREATE TABLE attached.other (b BLOB)")
            SQLite.execute(db, "INSERT INTO attached.other VALUES (x'56')")
            @test SQLite.Blob(read, db, "other", "b", 1; schema = "attached") == UInt8[0x56]
            SQLite.execute(db, "CREATE TABLE no_rowid (id INTEGER PRIMARY KEY, b BLOB) WITHOUT ROWID")
            SQLite.execute(db, "INSERT INTO no_rowid VALUES (1, zeroblob(1))")
            @test_throws SQLiteException SQLite.Blob(db, "no_rowid", "b", 1)
            SQLite.execute(db, "CREATE INDEX data_index ON files(data)")
            @test_throws SQLiteException SQLite.Blob(db, "files", "data", 1; writable = true)
            @test length(SQLite.Blob(read, db, "files", "data", 1)) == 32
            SQLite.execute(db, "PRAGMA foreign_keys=ON")
            SQLite.execute(db, "CREATE TABLE parent (b BLOB PRIMARY KEY)")
            SQLite.execute(db, "CREATE TABLE child (b BLOB REFERENCES parent(b))")
            SQLite.execute(db, "INSERT INTO parent VALUES (x'01')")
            SQLite.execute(db, "INSERT INTO child VALUES (x'01')")
            @test_throws SQLiteException SQLite.Blob(db, "child", "b", 1; writable = true)
            @test SQLite.Blob(read, db, "child", "b", 1) == UInt8[1]
        finally
            close(db)
        end
        @test_throws SQLiteException SQLite.Blob(db, "files", "data", 1)
    end

    @testset "Expired row and explicit transaction behavior" begin
        db = database()
        try
            blob = SQLite.Blob(db, "files", "data", 1; writable = true)
            write(blob, UInt8(0xaa))
            SQLite.execute(db, "UPDATE files SET note='changed' WHERE id=1")
            @test isopen(blob)
            @test_throws SQLiteException read(blob, UInt8)
            @test_throws SQLiteException read(blob, 0)
            @test_throws SQLiteException write(blob, UInt8(0xbb))
            @test position(blob) == 1
            close(blob)
            @test scalar(db, "SELECT hex(substr(data,1,1)) FROM files") == "AA"
            failure = ErrorException("cancel changes")
            caught = try
                SQLite.transaction(db) do
                    SQLite.Blob(db, "files", "data", 1; writable = true) do stream
                        write(stream, UInt8(0xbb))
                        throw(failure)
                    end
                end
            catch err
                err
            end
            @test caught === failure
            @test scalar(db, "SELECT hex(substr(data,1,1)) FROM files") == "AA"
            SQLite.transaction(db) do
                SQLite.Blob(db, "files", "data", 1; writable = true) do stream
                    write(stream, UInt8(0xcc))
                end
            end
            @test scalar(db, "SELECT hex(substr(data,1,1)) FROM files") == "CC"
        finally
            close(db)
        end
    end

    @testset "Connection close owns pending finalizers" begin
        mktempdir() do dir
            for explicit_transaction in (false, true)
                path = joinpath(dir, "owner-$explicit_transaction.sqlite")
                db = database(path, 1)
                explicit_transaction && SQLite.execute(db, "BEGIN")
                blob = SQLite.Blob(db, "files", "data", 1; writable = true)
                write(blob, UInt8(0xaa))
                close(db)
                @test !isopen(db) && !isopen(blob)
                @test close(blob) === nothing
                @test stored(path) == (explicit_transaction ? "00" : "AA")
                @test close(db) === nothing
            end
            path = joinpath(dir, "deferred.sqlite")
            db = database(path, 1)
            GC.enable_finalizers(false)
            try
                weak = abandon(db; writable = true)
                ABANDONED[] = nothing
                GC.gc(true)
                GC.gc(true)
                @test weak.value === nothing
                @test length(db.blob_handles) == 1
                close(db)
                @test isempty(db.blob_handles)
                @test stored(path) == "AA"
            finally
                GC.enable_finalizers(true)
            end
            @test stored(path) == "AA"
        end
        blob, owner = owned_blob()
        GC.gc(true)
        @test owner.value === blob.db
        @test read(blob, UInt8) == 0
        close(blob)
        close(blob.db)
        db = database()
        weak = abandon(db)
        ABANDONED[] = nothing
        GC.gc(true)
        GC.gc(true)
        @test weak.value === nothing
        @test isempty(db.blob_handles)
        close(db)
    end

    @testset "Close errors consume handles and preserve callback failures" begin
        mktempdir() do dir
            for mode in (:blob, :database, :callback)
                path = joinpath(dir, "$mode.sqlite")
                writer = database(path, 1)
                reader = SQLite.DB(path)
                SQLite.execute(reader, "BEGIN")
                @test scalar(reader, "SELECT length(data) FROM files") == 1
                streams = SQLite.Blob[]
                failure = ErrorException("callback failed")
                caught = try
                    if mode === :callback
                        SQLite.Blob(writer, "files", "data", 1; writable = true) do blob
                            push!(streams, blob)
                            write(blob, UInt8(0xff))
                            throw(failure)
                        end
                    else
                        push!(streams, SQLite.Blob(writer, "files", "data", 1; writable = true))
                        write(streams[1], UInt8(0xff))
                        if mode === :database
                            push!(streams, SQLite.Blob(writer, "files", "data", 1; writable = true))
                            DBInterface.close!(writer)
                        else
                            close(streams[1])
                        end
                    end
                catch err
                    err
                end
                if mode === :callback
                    @test caught isa CompositeException
                    @test length(caught.exceptions) == 2
                    @test caught.exceptions[1].ex === failure
                    @test caught.exceptions[2].ex isa SQLiteException
                    @test !isempty(caught.exceptions[1].processed_bt)
                    @test !isempty(caught.exceptions[2].processed_bt)
                else
                    @test caught isa SQLiteException
                end
                @test all(stream -> !isopen(stream), streams)
                @test isempty(writer.blob_handles)
                @test isopen(writer) == (mode !== :database)
                for stream in streams
                    @test close(stream) === nothing
                    @test_throws ArgumentError write(stream, UInt8(1))
                end
                SQLite.execute(reader, "ROLLBACK")
                @test stored(path) == "00"
                close(reader)
                close(writer)
            end
        end
    end
end
end
