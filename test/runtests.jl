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

r = query(db, sr"SELECT LastName FROM Employee WHERE BirthDate REGEXP '^\d{4}-08'")
@test r.values[1][1] == "Peacock"

@scalarfunc function triple(x)
    x * 3
end
@test_throws ErrorException registerfunc(db, 186, triple)
registerfunc(db, 1, triple)
r = query(db, "SELECT triple(Total) FROM Invoice ORDER BY InvoiceId LIMIT 5")
s = query(db, "SELECT Total FROM Invoice ORDER BY InvoiceId LIMIT 5")
for (i, j) in zip(r.values[1], s.values[1])
    @test_approx_eq i j*3
end

@scalarfunc mult (*)
registerfunc(db, -1, mult)
r = query(db, "SELECT Milliseconds, Bytes FROM Track")
s = query(db, "SELECT mult(Milliseconds, Bytes) FROM Track")
@test r[1].*r[2] == s[1]
t = query(db, "SELECT mult(Milliseconds, Bytes, 3, 4) FROM Track")
@test r[1].*r[2]*3*4 == t[1]

@test size(tables(db)) == (11,1)

close(db)
close(db) # repeatedly trying to close db
