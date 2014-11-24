using Base.Test, SQLite

if VERSION < v"0.4.0-dev"
    const AbstractString = String
    const UInt8 = Uint8
    const UInt16 = Uint16
    const UInt32 = Uint32
    const UInt64 = Uint64
    const UInt128 = Uint128
    const UInt = Uint
end

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
@test typeof(results[1,2]) <: AbstractString
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
r = query(db, "SELECT * FROM temp LIMIT ?", [3])
@test size(r) == (3,3)
r = query(db, "SELECT * FROM temp WHERE Title LIKE ?", ["%time%"])
@test r.values[1] == [76, 111, 187]
query(db, "INSERT INTO temp VALUES (?1, ?3, ?2)", [0,0,"Test Album"])
r = query(db, "SELECT * FROM temp WHERE AlbumId = 0")
@test r == ResultSet(Any["AlbumId", "Title", "ArtistId"], Any[Any[0], Any["Test Album"], Any[0]])
drop(db, "temp")

binddb = SQLiteDB()
query(binddb, "CREATE TABLE temp (n NULL, i6 INT, f REAL, s TEXT, a BLOB)")
query(binddb, "INSERT INTO temp VALUES (?1, ?2, ?3, ?4, ?5)", Any[NULL, int64(6), 6.4, "some text", b"bytearray"])
r = query(binddb, "SELECT * FROM temp")
for (v, t) in zip(r.values, [SQLite.NullType, Int64, Float64, AbstractString, Vector{UInt8}])
    @test isa(v[1], t)
end
query(binddb, "CREATE TABLE blobtest (a BLOB, b BLOB)")
query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)", Any[b"a", b"b"])
query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)", Any[b"a", BigInt(2)])
type Point{T}
    x::T
    y::T
end
==(a::Point, b::Point) = a.x == b.x && a.y == b.y
p1 = Point(1, 2)
p2 = Point(1.3, 2.4)
query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)", Any[b"a", p1])
query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)", Any[b"a", p2])
r = query(binddb, "SELECT * FROM blobtest")
for v in r.values[1]
    @test v == b"a"
end
for (v1, v2) in zip(r.values[2], Any[b"b", BigInt(2), p1, p2])
    @test v1 == v2
end
close(binddb)

# I can't be arsed to create a new one using old dictionary syntax
if VERSION > v"0.4.0-"
    query(db,"CREATE TABLE temp AS SELECT * FROM Album")
    r = query(db, "SELECT * FROM temp LIMIT :a", Dict(:a => 3))
    @test size(r) == (3,3)
    r = query(db, "SELECT * FROM temp WHERE Title LIKE @word", Dict(:word => "%time%"))
    @test r.values[1] == [76, 111, 187]
    query(db, "INSERT INTO temp VALUES (@lid, :title, \$rid)", Dict(:rid => 0, :lid => 0, :title => "Test Album"))
    r = query(db, "SELECT * FROM temp WHERE AlbumId = 0")
    @test r == ResultSet(Any["AlbumId", "Title", "ArtistId"], Any[Any[0], Any["Test Album"], Any[0]])
    drop(db, "temp")
end

r = query(db, sr"SELECT LastName FROM Employee WHERE BirthDate REGEXP '^\d{4}-08'")
@test r.values[1][1] == "Peacock"

triple(x) = x * 3
@test_throws ErrorException SQLite.register(db, triple, nargs=186)
SQLite.register(db, triple, nargs=1)
r = query(db, "SELECT triple(Total) FROM Invoice ORDER BY InvoiceId LIMIT 5")
s = query(db, "SELECT Total FROM Invoice ORDER BY InvoiceId LIMIT 5")
for (i, j) in zip(r.values[1], s.values[1])
    @test_approx_eq i j*3
end

SQLite.@register db function add4(q)
    q+4
end
r = query(db, "SELECT add4(AlbumId) FROM Album")
s = query(db, "SELECT AlbumId FROM Album")
@test r[1] == s[1]+4

SQLite.@register db mult(args...) = *(args...)
r = query(db, "SELECT Milliseconds, Bytes FROM Track")
s = query(db, "SELECT mult(Milliseconds, Bytes) FROM Track")
@test r[1].*r[2] == s[1]
t = query(db, "SELECT mult(Milliseconds, Bytes, 3, 4) FROM Track")
@test r[1].*r[2]*3*4 == t[1]

SQLite.@register db sin
u = query(db, "select sin(milliseconds) from track limit 5")
@test all(-1 .< u[1] .< 1)

SQLite.register(db, hypot; nargs=2, name="hypotenuse")
v = query(db, "select hypotenuse(Milliseconds,bytes) from track limit 5")
@test [int(i) for i in v[1]] == [11175621,5521062,3997652,4339106,6301714]

SQLite.@register db str2arr(s) = convert(Array{UInt8}, s)
r = query(db, "SELECT str2arr(LastName) FROM Employee LIMIT 2")
@test r[1] == Any[UInt8[0x41,0x64,0x61,0x6d,0x73],UInt8[0x45,0x64,0x77,0x61,0x72,0x64,0x73]]

SQLite.@register db big
r = query(db, "SELECT big(5)")
@test r[1][1] == big(5)

@test size(tables(db)) == (11,1)

close(db)
close(db) # repeatedly trying to close db
