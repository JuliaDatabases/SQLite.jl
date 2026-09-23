struct UDFReturnError end
SQLite.sqlreturn(context, ::UDFReturnError) = error("return fixture")

struct UDFSerializeError end
function SQLite.Serialization.serialize(
    ::SQLite.Serialization.AbstractSerializer,
    ::UDFSerializeError,
)
    error("serialize fixture")
end

struct UDFDeserializeError
    value::Int
end
function SQLite.Serialization.deserialize(
    ::SQLite.Serialization.AbstractSerializer,
    ::Type{UDFDeserializeError},
)
    error("deserialize fixture")
end

struct UDFShowError <: Exception end
Base.showerror(::IO, ::UDFShowError) = error("showerror fixture")

@testset "UDF error boundaries" begin
    db = SQLite.DB()
    SQLite.execute(db, "CREATE TABLE input(x INTEGER)")
    SQLite.execute(db, "INSERT INTO input VALUES (1), (2)")
    function value(sql, params = ())
        q = DBInterface.execute(db, sql, params)
        try
            return first(q)[1]
        finally
            DBInterface.close!(q)
            DBInterface.close!(q.stmt)
        end
    end
    function fails(sql, message, params = ())
        stmt = DBInterface.prepare(db, sql)
        try
            err = try
                DBInterface.execute(stmt, params)
                nothing
            catch e
                e
            end
            @test err isa SQLite.SQLiteException
            @test err isa SQLite.SQLiteException && occursin(message, err.msg)
        finally
            # Finalization must be safe even after a partially computed aggregate.
            DBInterface.close!(stmt)
        end
        @test value("SELECT 7") == 7
    end
    try
        @testset "scalar function and result conversion" begin
            SQLite.register(
                db,
                x -> error("scalar é🦆 fixture");
                nargs = 1,
                name = "scalar_error",
            )
            fails("SELECT scalar_error(x) FROM input", "scalar é🦆 fixture")
            SQLite.register(
                db,
                x -> UDFReturnError();
                nargs = 1,
                name = "return_error",
            )
            fails("SELECT return_error(1)", "return fixture")
            SQLite.register(
                db,
                x -> UDFSerializeError();
                nargs = 1,
                name = "serialize_error",
            )
            fails("SELECT serialize_error(1)", "serialize fixture")
            SQLite.register(
                db,
                x -> throw(UDFShowError());
                nargs = 1,
                name = "show_error",
            )
            fails("SELECT show_error(1)", "Julia exception in SQLite callback")
        end
        @testset "argument conversion" begin
            calls = Ref(0)
            SQLite.register(
                db,
                x -> (calls[] += 1; x);
                nargs = 1,
                name = "argument_error",
            )
            fails(
                "SELECT argument_error(?)",
                "Error deserializing",
                (UDFDeserializeError(1),),
            )
            @test calls[] == 0
        end
        @testset "aggregate step and state conversion" begin
            for failing_row in (1, 2)
                final_calls = Ref(0)
                SQLite.register(
                    db,
                    0,
                    (state, x) ->
                        x == failing_row ? error("step fixture") : state + x,
                    state -> (final_calls[] += 1; state);
                    nargs = 1,
                    name = "step_error",
                )
                fails("SELECT step_error(x) FROM input", "step fixture")
                @test final_calls[] == 0
            end
            SQLite.register(
                db,
                0,
                (state, x) -> x == 2 ? UDFSerializeError() : state + x;
                nargs = 1,
                name = "state_serialize_error",
            )
            fails(
                "SELECT state_serialize_error(x) FROM input",
                "serialize fixture",
            )
            SQLite.register(
                db,
                0,
                (state, x) -> UDFDeserializeError(x);
                nargs = 1,
                name = "state_deserialize_error",
            )
            fails(
                "SELECT state_deserialize_error(x) FROM input",
                "Error deserializing",
            )
            # Deserialization also occurs in xFinal when there was only one row.
            fails(
                "SELECT state_deserialize_error(x) FROM input WHERE x=1",
                "Error deserializing",
            )
            final_calls = Ref(0)
            SQLite.register(
                db,
                0,
                (state, x) -> state + 1,
                state -> (final_calls[] += 1; state);
                nargs = 1,
                name = "aggregate_argument_error",
            )
            fails(
                "SELECT aggregate_argument_error(?)",
                "Error deserializing",
                (UDFDeserializeError(1),),
            )
            @test final_calls[] == 0
        end
        @testset "aggregate final and empty input" begin
            SQLite.register(
                db,
                0,
                +,
                state -> error("final fixture");
                nargs = 1,
                name = "final_error",
            )
            fails("SELECT final_error(x) FROM input", "final fixture")
            @test value("SELECT final_error(x) FROM input WHERE 0") == 0
            SQLite.register(
                db,
                0,
                +,
                state -> UDFReturnError();
                nargs = 1,
                name = "final_return_error",
            )
            fails("SELECT final_return_error(x) FROM input", "return fixture")
            SQLite.register(
                db,
                0,
                +,
                state -> UDFSerializeError();
                nargs = 1,
                name = "final_serialize_error",
            )
            fails(
                "SELECT final_serialize_error(x) FROM input",
                "serialize fixture",
            )
            SQLite.register(
                db,
                UDFReturnError(),
                (state, x) -> state;
                nargs = 1,
                name = "empty_return_error",
            )
            fails(
                "SELECT empty_return_error(x) FROM input WHERE 0",
                "return fixture",
            )
        end
        @testset "successful state growth and statement reuse" begin
            SQLite.register(
                db,
                "",
                (state, x) -> state * repeat(string(x), 1024);
                nargs = 1,
                name = "grow_state",
            )
            @test value("SELECT grow_state(x) FROM input") ==
                  repeat("1", 1024) * repeat("2", 1024)
            fail = Ref(true)
            SQLite.register(
                db,
                0,
                (state, x) ->
                    fail[] && x == 2 ? error("reuse fixture") : state + x;
                nargs = 1,
                name = "reusable",
            )
            stmt = DBInterface.prepare(db, "SELECT reusable(x) FROM input")
            try
                @test_throws SQLite.SQLiteException DBInterface.execute(stmt)
                fail[] = false
                q = DBInterface.execute(stmt)
                @test first(q)[1] == 3
                DBInterface.close!(q)
            finally
                DBInterface.close!(stmt)
            end
        end
    finally
        close(db)
    end
    @test !isopen(db)

    # Keep the failed prepared statement registered until the DB itself closes.
    db = SQLite.DB()
    stmt = nothing
    try
        SQLite.register(
            db,
            0,
            (state, x) -> x == 2 ? error("close fixture") : state + x;
            nargs = 1,
            name = "close_error",
        )
        stmt = DBInterface.prepare(
            db,
            "SELECT close_error(x) FROM (SELECT 1 AS x UNION ALL SELECT 2)",
        )
        @test_throws SQLite.SQLiteException DBInterface.execute(stmt)
        @test SQLite.isready(stmt)
    finally
        close(db)
    end
    @test !isopen(db)
    @test !SQLite.isready(stmt)
end
