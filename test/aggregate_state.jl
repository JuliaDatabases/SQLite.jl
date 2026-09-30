module AggregateStateTests

using SQLite, Test
const DBI = SQLite.DBInterface
const Serialization = SQLite.Serialization

function rows(db, sql)
    stmt = DBI.prepare(db, sql)
    try
        return [Tuple(row) for row in DBI.execute(stmt)]
    finally
        DBI.close!(stmt)
    end
end

function rootcount(db)
    sum(
        (
            length(data.states) for
            data in db.registered_UDF_data if data isa SQLite.AggregateUDFData
        );
        init = 0,
    )
end

const serialized = Ref(0)
const deserialized = Ref(0)
struct SnapshotState
    value::Int
end
function Serialization.serialize(
    s::Serialization.AbstractSerializer,
    state::SnapshotState,
)
    serialized[] += 1
    Serialization.serialize_type(s, SnapshotState)
    Serialization.serialize(s, state.value)
end
function Serialization.deserialize(
    s::Serialization.AbstractSerializer,
    ::Type{SnapshotState},
)
    deserialized[] += 1
    SnapshotState(Serialization.deserialize(s))
end

const exposed_bytes = Ref{Any}(nothing)
struct ExposedState
    value::Int
end
function Serialization.serialize(
    s::Serialization.AbstractSerializer,
    state::ExposedState,
)
    Serialization.serialize_type(s, ExposedState)
    Serialization.serialize(s, state.value)
    exposed_bytes[] = s.io.data
end

mutable struct NoncopyableState end
function Base.deepcopy_internal(::NoncopyableState, ::IdDict)
    error("cannot copy state")
end
function Serialization.serialize(
    ::Serialization.AbstractSerializer,
    ::NoncopyableState,
)
    error("cannot serialize state")
end

struct InvalidSnapshot
    value::Int
end
function Serialization.deserialize(
    ::Serialization.AbstractSerializer,
    ::Type{InvalidSnapshot},
)
    error("cannot deserialize snapshot")
end

struct CallbackError <: Exception
    check::Function
end
function Base.showerror(io::IO, err::CallbackError)
    err.check(err)
    print(io, "aggregate callback fixture")
end

struct CheckedResult
    value::Int
    check::Function
end
function SQLite.sqlreturn(context, result::CheckedResult)
    result.check()
    SQLite.sqlreturn(context, result.value)
end

@testset "Aggregate state ownership" begin
    db = SQLite.DB()
    try
        SQLite.execute(db, "CREATE TABLE input(g INTEGER, x INTEGER)")
        SQLite.execute(
            db,
            "INSERT INTO input VALUES (1,1), (1,2), (2,3), (2,4)",
        )

        @testset "First snapshot and retained later objects" begin
            seen = Vector{Int}[]
            finished = Ref{Any}(nothing)
            SQLite.register(
                db,
                nothing,
                (state, x) -> begin
                    state === nothing && return Int[x]
                    push!(seen, state)
                    push!(state, x)
                end,
                state -> (finished[] = state; sum(state));
                name = "retained",
                nargs = 1,
            )
            @test rows(db, "SELECT retained(x) FROM input") == [(10,)]
            @test length(seen) == 3
            @test all(state -> state === seen[1], seen)
            @test finished[] === seen[1]
            @test seen[1] == [1, 2, 3, 4]
            @test rootcount(db) == 0

            SQLite.register(
                db,
                SnapshotState(0),
                (s, x) -> SnapshotState(s.value + x),
                s -> s.value;
                name = "snapshot",
                nargs = 1,
            )
            for n in (1, 2, 4)
                serialized[] = deserialized[] = 0
                @test rows(db, "SELECT snapshot(x) FROM input WHERE x<=$n") ==
                      [(sum(1:n),)]
                @test serialized[] == 1
                @test deserialized[] == 1
                @test rootcount(db) == 0
            end
        end

        @testset "First-step seed identity is preserved" begin
            seed = NoncopyableState()
            called = Ref(false)
            SQLite.register(
                db,
                seed,
                (s, x) -> begin
                    if s isa NoncopyableState
                        @test s === seed
                        called[] = true
                        return x
                    end
                    s + x
                end;
                name = "consume_seed",
                nargs = 1,
            )
            @test rows(db, "SELECT consume_seed(x) FROM input") == [(10,)]
            @test called[]

            # The registered seed remains shared; a callback must not mutate it
            # if separate groups and executions need independent initial state.
            mutable_seed = Int[]
            SQLite.register(
                db,
                mutable_seed,
                (s, x) -> push!(s, x),
                sum;
                name = "shared_seed",
                nargs = 1,
            )
            @test rows(
                db,
                "SELECT g, shared_seed(x) FROM input GROUP BY g ORDER BY g",
            ) == [(1, 3), (2, 8)]
            @test mutable_seed == [1, 3]
            @test rows(
                db,
                "SELECT g, shared_seed(x) FROM input GROUP BY g ORDER BY g",
            ) == [(1, 7), (2, 12)]
            @test mutable_seed == [1, 3, 1, 3]
            @test rootcount(db) == 0
        end

        @testset "The first snapshot owns its bytes" begin
            SQLite.register(
                db,
                ExposedState(0),
                (s, x) -> ExposedState(s.value + x),
                s -> s.value;
                name = "owned_snapshot",
                nargs = 1,
            )
            SQLite.register(
                db,
                x -> begin
                    x == 1 && fill!(exposed_bytes[], 0x00)
                    0
                end;
                name = "change_serializer_buffer",
                nargs = 1,
                isdeterm = false,
            )
            @test rows(
                db,
                "SELECT owned_snapshot(x), sum(change_serializer_buffer(x)) FROM input WHERE x<=2",
            ) == [(3, 0)]
            @test rootcount(db) == 0
        end

        @testset "State types and zero-argument aggregates" begin
            encoded = SQLite.sqlserialize(123)
            SQLite.register(
                db,
                0,
                (s, x) -> begin
                    if x == 1
                        @test s === 0
                        return 1
                    elseif x == 2
                        @test s === 1
                        return copy(encoded)
                    elseif x == 3
                        @test s isa Vector{UInt8}
                        @test s == encoded
                        return nothing
                    end
                    @test s === nothing
                    (answer = 10,)
                end,
                s -> s isa Vector{UInt8} ? 2 : s === nothing ? 3 : s.answer;
                name = "changing_state",
                nargs = 1,
            )
            @test rows(db, "SELECT changing_state(x) FROM input WHERE x<=2") ==
                  [(2,)]
            @test rows(db, "SELECT changing_state(x) FROM input WHERE x<=3") ==
                  [(3,)]
            @test rows(db, "SELECT changing_state(x) FROM input") == [(10,)]

            SQLite.register(
                db,
                0,
                (s, x) -> x == 1 ? 1 : NoncopyableState(),
                _ -> 7;
                name = "live_state",
                nargs = 1,
            )
            @test rows(db, "SELECT live_state(x) FROM input") == [(7,)]
            SQLite.register(
                db,
                0,
                (s, x) -> NoncopyableState(),
                _ -> 7;
                name = "invalid_snapshot",
                nargs = 1,
            )
            @test_throws SQLite.SQLiteException rows(
                db,
                "SELECT invalid_snapshot(x) FROM input",
            )
            @test rootcount(db) == 0
            SQLite.register(
                db,
                0,
                (s, x) -> InvalidSnapshot(x),
                _ -> 7;
                name = "invalid_decode",
                nargs = 1,
            )
            for n in (1, 4)
                @test_throws SQLite.SQLiteException rows(
                    db,
                    "SELECT invalid_decode(x) FROM input WHERE x<=$n",
                )
                @test rootcount(db) == 0
            end

            final_calls = Ref(0)
            SQLite.register(
                db,
                0,
                s -> s + 1,
                s -> (final_calls[] += 1; s);
                name = "zero_args",
                nargs = 0,
            )
            @test rows(db, "SELECT zero_args() FROM input") == [(4,)]
            @test final_calls[] == 1
            @test rows(db, "SELECT zero_args() FROM input WHERE 0") == [(0,)]
            @test final_calls[] == 1
            @test rootcount(db) == 0
        end

        @testset "Groups and nested statements share only the registration" begin
            depth = Ref(0)
            nested = Int[]
            counts = Int[]
            SQLite.register(
                db,
                nothing,
                (s, x) -> begin
                    push!(counts, rootcount(db))
                    if x == 2 && depth[] == 0
                        depth[] = 1
                        try
                            push!(
                                nested,
                                only(
                                    only(
                                        rows(
                                            db,
                                            "SELECT nested_state(x) FROM input WHERE x<=2",
                                        ),
                                    ),
                                ),
                            )
                        finally
                            depth[] = 0
                        end
                    end
                    GC.gc(false)
                    s === nothing ? Int[x] : push!(s, x)
                end,
                s -> begin
                    if depth[] == 0 && length(s) > 2 && first(s) > 0
                        depth[] = 1
                        try
                            push!(
                                nested,
                                only(
                                    only(
                                        rows(
                                            db,
                                            "SELECT nested_state(x) FROM input WHERE x<=2",
                                        ),
                                    ),
                                ),
                            )
                        finally
                            depth[] = 0
                        end
                    end
                    sum(s)
                end;
                name = "nested_state",
                nargs = 1,
            )
            @test rows(
                db,
                "SELECT nested_state(x), nested_state(-x) FROM input",
            ) == [(10, -10)]
            @test nested == [3, 3]
            @test maximum(counts) >= 3
            @test rootcount(db) == 0
            empty!(nested)
            @test rows(
                db,
                "SELECT g, nested_state(x) FROM input GROUP BY g ORDER BY g",
            ) == [(1, 3), (2, 7)]
            @test nested == [3]
            @test rootcount(db) == 0
        end

        @testset "Release before final, result, and error callbacks" begin
            weak = Ref(WeakRef(nothing))
            mode = Ref(:success)
            error_seen = Ref(false)
            exact_error = Ref{Any}(nothing)
            check_error = function (err)
                @test err === exact_error[]
                @test rootcount(db) == 0
                saved = mode[]
                mode[] = :success
                try
                    @test rows(
                        db,
                        "SELECT release_state(x) FROM input WHERE x<=2",
                    ) == [(3,)]
                finally
                    mode[] = saved
                end
                error_seen[] = true
            end
            exact_error[] = CallbackError(check_error)
            SQLite.register(
                db,
                nothing,
                (s, x) -> begin
                    mode[] == :first_error && throw(exact_error[])
                    s === nothing && return Int[x]
                    weak[] = WeakRef(s)
                    GC.gc(false)
                    @test weak[].value === s
                    mode[] == :step_error && x == 3 && throw(exact_error[])
                    push!(s, x)
                end,
                s -> begin
                    @test rootcount(db) == 0
                    GC.gc(false)
                    @test weak[].value === s
                    mode[] == :final_error && throw(exact_error[])
                    CheckedResult(
                        sum(s),
                        () -> begin
                            @test rootcount(db) == 0
                            mode[] == :result_error && throw(exact_error[])
                            @test rows(db, "SELECT 7") == [(7,)]
                        end,
                    )
                end;
                name = "release_state",
                nargs = 1,
            )

            for selected in (
                :success,
                :first_error,
                :step_error,
                :final_error,
                :result_error,
            )
                mode[] = selected
                error_seen[] = false
                if selected == :success
                    @test rows(db, "SELECT release_state(x) FROM input") ==
                          [(10,)]
                else
                    @test_throws SQLite.SQLiteException rows(
                        db,
                        "SELECT release_state(x) FROM input",
                    )
                    @test error_seen[]
                end
                @test rootcount(db) == 0
                GC.gc(true)
                GC.gc(true)
                @test weak[].value === nothing
            end
        end

        @testset "GC finalizers defer during aggregate callbacks" begin
            discarded = SQLite.Stmt(db, "SELECT 1")
            deferred = Ref(false)
            SQLite.register(
                db,
                0,
                (s, x) -> begin
                    if x == 2
                        @test rootcount(db) == 1
                        GC.gc(true)
                        finalize(discarded)
                        @test SQLite.isready(discarded)
                        @test rootcount(db) == 1
                        deferred[] = true
                    end
                    s + x
                end;
                name = "gc_state",
                nargs = 1,
            )
            @test rows(db, "SELECT gc_state(x) FROM input") == [(10,)]
            @test deferred[]
            @test rootcount(db) == 0
            finalize(discarded)
            @test !SQLite.isready(discarded)
        end

        @testset "Interrupted and partially consumed queries" begin
            finals = Ref(0)
            weak = Ref(WeakRef(nothing))
            SQLite.register(
                db,
                nothing,
                (s, x) -> begin
                    s === nothing && return Int[x]
                    weak[] = WeakRef(s)
                    x == 3 && SQLite.C.sqlite3_interrupt(db.handle)
                    push!(s, x)
                end,
                s -> begin
                    @test rootcount(db) == 0
                    finals[] += 1
                    sum(s)
                end;
                name = "interrupt_state",
                nargs = 1,
            )
            @test_throws SQLite.SQLiteException rows(
                db,
                "SELECT interrupt_state(x) FROM input",
            )
            @test finals[] == 1
            @test rootcount(db) == 0
            @test rows(db, "SELECT 7") == [(7,)]
            GC.gc(true)
            GC.gc(true)
            @test weak[].value === nothing

            SQLite.register(
                db,
                nothing,
                (s, x) -> s === nothing ? Int[x] : push!(s, x),
                sum;
                name = "groups",
                nargs = 1,
            )
            for close_mode in (:reset, :stmt, :db)
                stmt = DBI.prepare(
                    db,
                    "SELECT g, groups(x) FROM input GROUP BY g ORDER BY g",
                )
                q = DBI.execute(stmt)
                @test Tuple(first(q)) == (1, 3)
                if close_mode == :reset
                    DBI.close!(q)
                    @test [Tuple(row) for row in DBI.execute(stmt)] == [(1, 3), (2, 7)]
                    DBI.close!(stmt)
                elseif close_mode == :stmt
                    DBI.close!(stmt)
                else
                    close(db)
                    @test !SQLite.isready(stmt)
                end
                @test rootcount(db) == 0
            end
        end
    finally
        close(db)
    end
end

end
