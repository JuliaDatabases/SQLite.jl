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

colnames, results = query(db,"SELECT name FROM sqlite_master WHERE type='table';")
@test length(colnames) == 1
@test colnames[1] == "name"
@test size(results) == (11,1)

colnames1, results1 = SQLite.tables(db)
@test colnames == colnames1
@test results == results1

colnames, results = query(db,"SELECT * FROM Employee;")
@test length(colnames) == 15
@test size(results) == (8,15)
@test typeof(results[1,1]) == Int64
@test typeof(results[1,2]) <: String
@test results[1,5] == NULL

query(db,"SELECT * FROM Album;")
query(db,"SELECT a.*, b.AlbumId 
	FROM Artist a 
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId 
	ORDER BY name;")

c, r = query(db,"create table temp as select * from album")
@test c == String[]
@test r == Any[]
c, r = query(db,"select * from temp limit 10")
@test length(c) == 3
@test size(r) == (10,3)
@test query(db,"alter table temp add column colyear int") == (String[],Any[])
@test query(db,"update temp set colyear = 2014") == (String[],Any[])
c, r = query(db,"select * from temp limit 10")
@test length(c) == 4
@test size(r) == (10,4)
@test all(r[:,4] .== 2014)
@test query(db,"alter table temp add column dates blob") == (String[],Any[])
stmt = SQLiteStmt(db,"update temp set dates = ?")
SQLite.bind!(stmt,1,Date(2014,1,1))
SQLite.execute!(stmt)
c, r = query(db,"select * from temp limit 10")
@test length(c) == 5
@test size(r) == (10,5)
@test typeof(r[1,5]) == Date
@test all(r[:,5] .== Date(2014,1,1))
@test query(db,"drop table temp") == (String[],Any[])

create(db,"temp",zeros(5,5),["col1","col2","col3","col4","col5"],[Float64 for i=1:5])
c, r = query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r .== 0.0)
@test all([typeof(i) for i in r] .== Float64)
@test c == ["col1","col2","col3","col4","col5"]
@test drop(db,"temp") == nothing

create(db,"temp",zeros(5,5))
c, r = query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r .== 0.0)
@test all([typeof(i) for i in r] .== Float64)
@test c == ["x1","x2","x3","x4","x5"]
@test drop(db,"temp") == nothing

create(db,"temp",zeros(Int,5,5))
c, r = query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r .== 0)
@test all([typeof(i) for i in r] .== Int64)
@test c == ["x1","x2","x3","x4","x5"]
@test drop(db,"temp") == nothing

if VERSION > v"0.4.0-"
    rng = Date(2013):Date(2013,1,5)
    create(db,"temp",[i for i = rng, j = rng])
    c, r = query(db,"select * from temp")
    @test size(r) == (5,5)
    @test all(r[:,1] .== rng)
    @test all([typeof(i) for i in r] .== Date)
    @test c == ["x1","x2","x3","x4","x5"]
    @test drop(db,"temp") == nothing
end

@test length(tables(db)[2]) == 11

close(db)