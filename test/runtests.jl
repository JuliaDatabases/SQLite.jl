using Base.Test, SQLite

a = SQLiteDB()
b = SQLiteDB(UTF16=true)
c = SQLiteDB(":memory:",UTF16=true)

close(a)
close(b)
close(c)

temp = tempname()
SQLiteDB(temp)

#db = SQLiteDB("C:/Users/karbarcca/.julia/v0.4/SQLite/test/Chinook_Sqlite.sqlite")
db = SQLiteDB(joinpath(dirname(@__FILE__),"Chinook_Sqlite.sqlite"))

results = query(db,"SELECT name FROM sqlite_master WHERE type='table';")
@test length(results.colnames) == 1
@test results.colnames[1] == "name"
@test size(results) == (11,1)

results1 = tables(db)
@test results.colnames == results1.colnames
@test results.values == results1.values

results = query(db,"SELECT * FROM Employee;")
@test length(results.colnames) == 15
@test size(results) == (8,15)
@test typeof(results[1,1]) == Int64
@test typeof(results[1,2]) <: String
@test results[1,5] == NULL

query(db,"SELECT * FROM Album;")
query(db,"SELECT a.*, b.AlbumId 
	FROM Artist a 
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId 
	ORDER BY name;")

EMPTY_RESULTSET = ResultSet(["Rows Affected"],Any[Any[0]])
SQLite.ResultSet(x) = ResultSet(["Rows Affected"],Any[Any[x]])
r = query(db,"create table temp as select * from album")
@test r == EMPTY_RESULTSET
r = query(db,"select * from temp limit 10")
@test length(r.colnames) == 3
@test size(r) == (10,3)
@test query(db,"alter table temp add column colyear int") == EMPTY_RESULTSET
@test query(db,"update temp set colyear = 2014") == ResultSet(347)
r = query(db,"select * from temp limit 10")
@test length(r.colnames) == 4
@test size(r) == (10,4)
@test all(r[:,4] .== 2014)
if VERSION > v"0.4.0-"
    @test query(db,"alter table temp add column dates blob") == EMPTY_RESULTSET
    stmt = SQLiteStmt(db,"update temp set dates = ?")
    bind(stmt,1,Date(2014,1,1))
    execute(stmt)
    r = query(db,"select * from temp limit 10")
    @test length(r.colnames) == 5
    @test size(r) == (10,5)
    @test typeof(r[1,5]) == Date
    @test all(r[:,5] .== Date(2014,1,1))
    close(stmt)
end
@test query(db,"drop table temp") == EMPTY_RESULTSET

create(db,"temp",zeros(5,5),["col1","col2","col3","col4","col5"],[Float64 for i=1:5])
r = query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r.values[1] .== 0.0)
@test all([typeof(i) for i in r.values[1]] .== Float64)
@test r.colnames == ["col1","col2","col3","col4","col5"]
@test drop(db,"temp") == EMPTY_RESULTSET

create(db,"temp",zeros(5,5))
r = query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r.values[1] .== 0.0)
@test all([typeof(i) for i in r.values[1]] .== Float64)
@test r.colnames == ["x1","x2","x3","x4","x5"]
@test drop(db,"temp") == EMPTY_RESULTSET

create(db,"temp",zeros(Int,5,5))
r = query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r.values[1] .== 0)
@test all([typeof(i) for i in r.values[1]] .== Int64)
@test r.colnames == ["x1","x2","x3","x4","x5"]
SQLite.append(db,"temp",ones(Int,5,5))
r = query(db,"select * from temp")
@test size(r) == (10,5)
@test r.values[1] == Any[0,0,0,0,0,1,1,1,1,1]
@test typeof(r[1,1]) == Int64
@test r.colnames == ["x1","x2","x3","x4","x5"]
@test drop(db,"temp") == EMPTY_RESULTSET

if VERSION > v"0.4.0-"
    rng = Date(2013):Date(2013,1,5)
    create(db,"temp",[i for i = rng, j = rng])
    r = query(db,"select * from temp")
    @test size(r) == (5,5)
    @test all(r[:,1] .== rng)
    @test all([typeof(i) for i in r.values[1]] .== Date)
    @test r.colnames == ["x1","x2","x3","x4","x5"]
    @test drop(db,"temp") == EMPTY_RESULTSET
end

query(db,"CREATE TABLE temp AS SELECT * FROM Album")
r = query(db, "SELECT * FROM temp LIMIT ?", (3,))
@test size(r) == (3,3)
r = query(db, "SELECT * FROM temp WHERE Title LIKE ?", ("%time%",))
@test r.values[1] == [76, 111, 187]
query(db, "INSERT INTO temp VALUES (?1, ?3, ?2)", (0,0,"Test Album"))
r = query(db, "SELECT * FROM temp WHERE AlbumId = 0")
@test r == ResultSet(Any["AlbumId", "Title", "ArtistId"], Any[Any[0], Any["Test Album"], Any[0]])
drop(db, "temp")

@test size(tables(db)) == (11,1)

close(db)
close(db) # repeatedly trying to close db
