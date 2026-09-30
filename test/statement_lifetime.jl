module StatementLifetimeTests
using SQLite, Test
using SQLite: DBInterface

const HOLD = Ref{Any}(nothing)

function database(path)
    db = SQLite.DB(path)
    SQLite.execute(db, "CREATE TABLE data (x INTEGER)")
    SQLite.execute(db, "INSERT INTO data VALUES (0)")
    return db
end

function stored(path)
    db = SQLite.DB(path)
    rows = DBInterface.execute(db, "SELECT x FROM data")
    try
        return first(rows).x
    finally
        DBInterface.close!(rows)
        close(db)
    end
end

@noinline function abandon(db, sql)
    stmt = SQLite.Stmt(db, sql)
    @assert SQLite.execute(stmt) == SQLite.C.SQLITE_ROW
    HOLD[] = stmt
    return WeakRef(stmt)
end

@noinline function abandoned_binding(db)
    data = collect(codeunits("bound bytes"))
    stmt = SQLite.Stmt(db, "SELECT ?")
    SQLite.bind!(stmt, (data,))
    HOLD[] = stmt
    return WeakRef(stmt), WeakRef(data)
end

@noinline function populate!(live, db, i)
    stmt = SQLite.Stmt(db, "SELECT ?")
    SQLite.bind!(stmt, (i,))
    if i % 3 == 0
        push!(live, stmt)
    else
        HOLD[] = stmt
        HOLD[] = nothing
    end
    return nothing
end

mutable struct FinalizeState
    db::SQLite.DB
    stmt::Union{Nothing,SQLite.Stmt}
    calls::Int
    cleared::Bool
    errors::Vector{Any}
    created::Vector{SQLite.Stmt}
    on_destroy::Union{Nothing,Function}
end

struct FinalizeResult
    state::FinalizeState
end

function destroy_aux(ptr::Ptr{Cvoid})::Cvoid
    state = unsafe_pointer_to_objref(ptr)::FinalizeState
    try
        state.calls += 1
        state.on_destroy === nothing || state.on_destroy()
        state.cleared = !SQLite.isready(state.stmt)
        state.cleared && DBInterface.close!(state.stmt)
        for _ in 1:2048
            temporary = SQLite.Stmt(state.db, "SELECT 2")
            DBInterface.close!(temporary)
        end
        GC.gc(true)
        push!(state.created, SQLite.Stmt(state.db, "SELECT 3"))
    catch err
        push!(state.errors, err)
    end
    return
end

function callback_finalizer_overlap(mode)
    db = SQLite.DB()
    entered = Threads.Atomic{Bool}(false)
    finished = Threads.Atomic{Bool}(false)
    stopped = Threads.Atomic{Bool}(false)
    discarded = SQLite.Stmt(db, "SELECT 1")
    callback = function (x)
        if !entered[]
            entered[] = true
            deadline = time() + 5
            while !finished[]
                time() < deadline || error("statement finalizer blocked during a callback")
                GC.safepoint()
            end
            temporary = SQLite.Stmt(db, "SELECT 2")
            DBInterface.close!(temporary)
        end
        return x
    end
    SQLite.register(db, callback; name="callback_overlap", nargs=1)
    worker = Threads.@spawn begin
        while !entered[] && !stopped[]
            GC.safepoint()
        end
        if entered[]
            finalize(discarded)
            finished[] = true
        end
    end
    try
        if mode == :execute
            stmt = SQLite.Stmt(db, "SELECT callback_overlap(1)")
            @test SQLite.execute(stmt) == SQLite.C.SQLITE_ROW
        elseif mode == :iterate
            rows = DBInterface.execute(db, "SELECT 0 UNION ALL SELECT callback_overlap(1)")
            @test length(collect(rows)) == 2
        elseif mode == :schema
            rows = DBInterface.execute(db, "SELECT NULL UNION ALL SELECT callback_overlap(1)"; strict=true)
            @test length(collect(rows)) == 2
        elseif mode == :load
            SQLite.execute(db, "CREATE TABLE data (x INTEGER)")
            SQLite.execute(db, "CREATE TRIGGER on_insert AFTER INSERT ON data BEGIN SELECT callback_overlap(NEW.x); END")
            @test SQLite.load!((x=[1],), db, "data") == "data"
        elseif mode == :reset
            state = FinalizeState(db, nothing, 0, false, Any[], SQLite.Stmt[], () -> callback(1))
            SQLite.register(db, x -> FinalizeResult(state); name="reset_overlap", nargs=1)
            stmt = SQLite.Stmt(db, "SELECT reset_overlap(1)")
            state.stmt = stmt
            rows = DBInterface.execute(stmt)
            DBInterface.close!(rows)
            @test state.calls == 1
            @test isempty(state.errors)
        end
        @test entered[]
        @test finished[]
        @test SQLite.isready(discarded)
        finalize(discarded)
        @test !SQLite.isready(discarded)
    finally
        stopped[] = true
        fetch(worker)
        close(db)
    end
end

function SQLite.sqlreturn(context, result::FinalizeResult)
    callback = @cfunction(destroy_aux, Cvoid, (Ptr{Cvoid},))
    SQLite.C.sqlite3_set_auxdata(context, 0, pointer_from_objref(result.state), callback)
    SQLite.C.sqlite3_result_int(context, 1)
    return nothing
end

@testset "Registered statement lifetime" begin
    @testset "DB close consumes pending finalizers" begin
        mktempdir() do dir
            for explicit in (false, true)
                path = joinpath(dir, "write-$explicit.sqlite")
                db = database(path)
                explicit && SQLite.execute(db, "BEGIN")
                GC.enable_finalizers(false)
                try
                    weak = abandon(db, "UPDATE data SET x=1 RETURNING x")
                    HOLD[] = nothing
                    GC.gc(true)
                    GC.gc(true)
                    @test weak.value === nothing
                    close(db)
                    @test !isopen(db)
                    @test stored(path) == (explicit ? 0 : 1)
                finally
                    GC.enable_finalizers(true)
                end
                @test stored(path) == (explicit ? 0 : 1)
                @test isempty(db.stmt_wrappers)
                @test close(db) === nothing
            end

            path = joinpath(dir, "read.sqlite")
            db = database(path)
            writer = SQLite.DB(path)
            GC.enable_finalizers(false)
            try
                weak = abandon(db, "SELECT x FROM data")
                HOLD[] = nothing
                GC.gc(true)
                GC.gc(true)
                @test weak.value === nothing
                @test_throws SQLiteException SQLite.execute(writer, "UPDATE data SET x=77")
                close(db)
                @test SQLite.execute(writer, "UPDATE data SET x=77") == SQLite.C.SQLITE_DONE
            finally
                GC.enable_finalizers(true)
                close(writer)
            end
            @test stored(path) == 77

            path = joinpath(dir, "unregistered.sqlite")
            db = database(path)
            stmt = SQLite.Stmt(db, "UPDATE data SET x=1 RETURNING x"; register=false)
            @test SQLite.execute(stmt) == SQLite.C.SQLITE_ROW
            @test isempty(db.stmt_wrappers)
            close(db)
            @test SQLite.isready(stmt)
            @test stored(path) == 0
            DBInterface.close!(stmt)
            @test !SQLite.isready(stmt)
            @test stored(path) == 1
        end
    end

    @testset "Handle cleanup does not retain statements or bindings" begin
        db = SQLite.DB()
        stmt = SQLite.Stmt(db, "SELECT 1")
        @test length(db.stmt_wrappers) == 1
        @test DBInterface.close!(stmt) === C_NULL
        @test isempty(db.stmt_wrappers)
        @test DBInterface.close!(stmt) === C_NULL
        weak, bound = abandoned_binding(db)
        HOLD[] = nothing
        GC.gc(true)
        GC.gc(true)
        @test weak.value === nothing
        @test bound.value === nothing
        @test isempty(db.stmt_wrappers)

        # Exercise registry growth and finalizer cleanup while other statements live.
        live = SQLite.Stmt[]
        for i in 1:512
            populate!(live, db, i)
            i % 32 == 0 && GC.gc(true)
        end
        GC.gc(true)
        GC.gc(true)
        @test length(db.stmt_wrappers) == length(live)
        @test all(SQLite.isready, live)
        SQLite.finalize_statements!(db)
        @test isempty(db.stmt_wrappers)
        @test all(stmt -> !SQLite.isready(stmt), live)
        foreach(DBInterface.close!, live)
        @test isempty(db.stmt_wrappers)
        close(db)
    end

    @testset "Native finalization can reenter statement cleanup" begin
        for _ in 1:4
            db = SQLite.DB()
            state = FinalizeState(db, nothing, 0, false, Any[], SQLite.Stmt[], nothing)
            SQLite.register(db, x -> FinalizeResult(state); name="retain_aux", nargs=1, isdeterm=false)
            siblings = [SQLite.Stmt(db, "SELECT 1") for _ in 1:64]
            stmt = SQLite.Stmt(db, "SELECT retain_aux(1)")
            state.stmt = stmt
            @test SQLite.execute(stmt) == SQLite.C.SQLITE_ROW
            @test state.calls == 0
            SQLite.finalize_statements!(db)
            @test state.calls == 1
            @test state.cleared
            @test isempty(state.errors)
            @test all(stmt -> !SQLite.isready(stmt), siblings)
            @test all(stmt -> !SQLite.isready(stmt), state.created)
            @test isempty(db.stmt_wrappers)
            foreach(DBInterface.close!, siblings)
            foreach(DBInterface.close!, state.created)
            close(db)
        end
    end

    @testset "Finalizers defer while handle cleanup is locked" begin
        db = SQLite.DB()
        stmt = SQLite.Stmt(db, "SELECT 1")
        lock(db.lock)
        try
            finalize(stmt)
            @test SQLite.isready(stmt)
            worker = Threads.@spawn finalize(stmt)
            @test timedwait(() -> istaskdone(worker), 5) == :ok
            finalize(db)
            @test isopen(db)
        finally
            unlock(db.lock)
        end
        finalize(stmt)
        @test !SQLite.isready(stmt)
        finalize(db)
        @test !isopen(db)
    end

    @testset "Registry updates during concurrent GC" begin
        db = SQLite.DB()
        live = SQLite.Stmt[]
        finished = Threads.Atomic{Bool}(false)
        collector = Threads.@spawn begin
            for _ in 1:32
                finished[] && break
                GC.gc(false)
                yield()
            end
        end
        try
            for i in 1:4096
                populate!(live, db, i)
                i % 64 == 0 && yield()
            end
        finally
            finished[] = true
            fetch(collector)
        end
        GC.gc(true)
        GC.gc(true)
        @test length(db.stmt_wrappers) == length(live)
        @test length(collect(keys(db.stmt_wrappers))) == length(live)
        close(db)
        @test all(stmt -> !SQLite.isready(stmt), live)
    end

    @testset "Native callbacks cannot invert finalizer locks" begin
        if Threads.nthreads() < 2
            @test_skip Threads.nthreads() >= 2
        else
            for mode in (:execute, :iterate, :schema, :load, :reset)
                @testset "$mode" begin
                    callback_finalizer_overlap(mode)
                end
            end
        end
    end
end
end
