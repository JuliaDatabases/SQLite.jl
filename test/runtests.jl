using Base.Test
using Compat 
if !isdefined(:SQLite)
    using SQLite
else
    reload("SQLite")
end

# test open memory DB and finalizer
db = SQLite.DB()
finalize(a)

# test create new file DB and closing
temp = tempname()
db = SQLite.DB(temp)
close(db)
@test isfile(temp)

# test construction of new statement
db = SQLite.DB()
stmt = SQLite.Stmt(db,"SELECT 1+1;")
finalize(stmt)

stmt = SQLite.Stmt(db,"SELECT 2+2;")
close(stmt)

# test construction of statement with error
@test_throws SQLite.SQLiteException stmt = SQLite.Stmt(db,"SAYLEKT 3+3;")

#db = SQLite.DB("/Users/jacobquinn/.julia/v0.4/SQLite/test/Chinook_Sqlite.sqlite")
db = SQLite.DB(joinpath(dirname(@__FILE__),"Chinook_Sqlite.sqlite"))

results = SQLite.query(db,"SELECT name FROM sqlite_master WHERE type='table';")
@test length(results.colnames) == 1
@test results.colnames[1] == "name"
@test size(results) == (11,1)

results1 = SQLite.tables(db)
@test results.colnames == results1.colnames
@test results.values == results1.values

results = SQLite.query(db,"SELECT * FROM Employee;")
@test length(results.colnames) == 15
@test size(results) == (8,15)
@test typeof(results[1,1]) == Int64
@test typeof(results[1,2]) <: AbstractString
@test results[1,5] == SQLite.NULL

SQLite.query(db,"SELECT * FROM Album;")
SQLite.query(db,"SELECT a.*, b.AlbumId
	FROM Artist a
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId
	ORDER BY name;")

EMPTY_RESULTSET = SQLite.ResultSet(["Rows Affected"],Any[Any[0]])
SQLite.ResultSet(x) = SQLite.ResultSet(["Rows Affected"],Any[Any[x]])
r = SQLite.query(db,"create table temp as select * from album")
@test r == EMPTY_RESULTSET
r = SQLite.query(db,"select * from temp limit 10")
@test length(r.colnames) == 3
@test size(r) == (10,3)
@test SQLite.query(db,"alter table temp add column colyear int") == EMPTY_RESULTSET
@test SQLite.query(db,"update temp set colyear = 2014") == SQLite.ResultSet(347)
r = SQLite.query(db,"select * from temp limit 10")
@test length(r.colnames) == 4
@test size(r) == (10,4)
@test all(r[:,4] .== 2014)
if VERSION > v"0.4.0-"
    @test SQLite.query(db,"alter table temp add column dates blob") == EMPTY_RESULTSET
    stmt = SQLite.Stmt(db,"update temp set dates = ?")
    SQLite.bind!(stmt,1,Date(2014,1,1))
    SQLite.execute!(stmt)
    r = SQLite.query(db,"select * from temp limit 10")
    @test length(r.colnames) == 5
    @test size(r) == (10,5)
    @test typeof(r[1,5]) == Date
    @test all(r[:,5] .== Date(2014,1,1))
    finalize(stmt)
end
@test SQLite.query(db,"drop table temp") == EMPTY_RESULTSET

SQLite.create(db,"temp",zeros(5,5),["col1","col2","col3","col4","col5"],[Float64 for i=1:5])
r = SQLite.query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r.values[1] .== 0.0)
@test all([typeof(i) for i in r.values[1]] .== Float64)
@test r.colnames == ["col1","col2","col3","col4","col5"]
@test SQLite.drop!(db,"temp") == EMPTY_RESULTSET

SQLite.create(db,"temp",zeros(5,5))
r = SQLite.query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r.values[1] .== 0.0)
@test all([typeof(i) for i in r.values[1]] .== Float64)
@test r.colnames == ["x1","x2","x3","x4","x5"]
@test SQLite.drop!(db,"temp") == EMPTY_RESULTSET

SQLite.create(db,"temp",zeros(Int,5,5))
r = SQLite.query(db,"select * from temp")
@test size(r) == (5,5)
@test all(r.values[1] .== 0)
@test all([typeof(i) for i in r.values[1]] .== Int64)
@test r.colnames == ["x1","x2","x3","x4","x5"]
SQLite.append!(db,"temp",ones(Int,5,5))
r = SQLite.query(db,"select * from temp")
@test size(r) == (10,5)
@test r.values[1] == Any[0,0,0,0,0,1,1,1,1,1]
@test typeof(r[1,1]) == Int64
@test r.colnames == ["x1","x2","x3","x4","x5"]
@test SQLite.drop!(db,"temp") == EMPTY_RESULTSET

if VERSION > v"0.4.0-"
    rng = Date(2013):Date(2013,1,5)
    SQLite.create(db,"temp",[i for i = rng, j = rng])
    r = SQLite.query(db,"select * from temp")
    @test size(r) == (5,5)
    @test all(r[:,1] .== rng)
    @test all([typeof(i) for i in r.values[1]] .== Date)
    @test r.colnames == ["x1","x2","x3","x4","x5"]
    @test SQLite.drop!(db,"temp") == EMPTY_RESULTSET
end

SQLite.query(db,"CREATE TABLE temp AS SELECT * FROM Album")
r = SQLite.query(db, "SELECT * FROM temp LIMIT ?", [3])
@test size(r) == (3,3)
r = SQLite.query(db, "SELECT * FROM temp WHERE Title LIKE ?", ["%time%"])
@test r.values[1] == [76, 111, 187]
SQLite.query(db, "INSERT INTO temp VALUES (?1, ?3, ?2)", [0,0,"Test Album"])
r = SQLite.query(db, "SELECT * FROM temp WHERE AlbumId = 0")
@test r == SQLite.ResultSet(Any["AlbumId", "Title", "ArtistId"], Any[Any[0], Any["Test Album"], Any[0]])
SQLite.drop!(db, "temp")

binddb = SQLite.DB()
SQLite.query(binddb, "CREATE TABLE temp (n NULL, i6 INT, f REAL, s TEXT, a BLOB)")
SQLite.query(binddb, "INSERT INTO temp VALUES (?1, ?2, ?3, ?4, ?5)", Any[SQLite.NULL, Int64(6), 6.4, "some text", b"bytearray"])
r = SQLite.query(binddb, "SELECT * FROM temp")
for (v, t) in zip(r.values, [SQLite.NullType, Int64, Float64, AbstractString, Vector{UInt8}])
    @test isa(v[1], t)
end
SQLite.query(binddb, "CREATE TABLE blobtest (a BLOB, b BLOB)")
SQLite.query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)", Any[b"a", b"b"])
SQLite.query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)", Any[b"a", BigInt(2)])
type Point{T}
    x::T
    y::T
end
==(a::Point, b::Point) = a.x == b.x && a.y == b.y
p1 = Point(1, 2)
p2 = Point(1.3, 2.4)
SQLite.query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)", Any[b"a", p1])
SQLite.query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)", Any[b"a", p2])
r = SQLite.query(binddb, "SELECT * FROM blobtest")
for v in r.values[1]
    @test v == b"a"
end
for (v1, v2) in zip(r.values[2], Any[b"b", BigInt(2), p1, p2])
    @test v1 == v2
end
finalize(binddb)

# I can't be arsed to create a new one using old dictionary syntax
if VERSION > v"0.4.0-"
    SQLite.query(db,"CREATE TABLE temp AS SELECT * FROM Album")
    r = SQLite.query(db, "SELECT * FROM temp LIMIT :a", Dict(:a => 3))
    @test size(r) == (3,3)
    r = SQLite.query(db, "SELECT * FROM temp WHERE Title LIKE @word", Dict(:word => "%time%"))
    @test r.values[1] == [76, 111, 187]
    SQLite.query(db, "INSERT INTO temp VALUES (@lid, :title, \$rid)", Dict(:rid => 0, :lid => 0, :title => "Test Album"))
    r = SQLite.query(db, "SELECT * FROM temp WHERE AlbumId = 0")
    @test r == SQLite.ResultSet(Any["AlbumId", "Title", "ArtistId"], Any[Any[0], Any["Test Album"], Any[0]])
    SQLite.drop!(db, "temp")
end

r = SQLite.query(db, sr"SELECT LastName FROM Employee WHERE BirthDate REGEXP '^\d{4}-08'")
@test r.values[1][1] == "Peacock"

triple(x) = 3x
@test_throws AssertionError SQLite.register(db, triple, nargs=186)
SQLite.register(db, triple, nargs=1)
r = SQLite.query(db, "SELECT triple(Total) FROM Invoice ORDER BY InvoiceId LIMIT 5")
s = SQLite.query(db, "SELECT Total FROM Invoice ORDER BY InvoiceId LIMIT 5")
for (i, j) in zip(r.values[1], s.values[1])
    @test_approx_eq i 3j
end

SQLite.@register db function add4(q)
    q+4
end
r = SQLite.query(db, "SELECT add4(AlbumId) FROM Album")
s = SQLite.query(db, "SELECT AlbumId FROM Album")
@test r[1] == s[1]+4

SQLite.@register db mult(args...) = *(args...)
r = SQLite.query(db, "SELECT Milliseconds, Bytes FROM Track")
s = SQLite.query(db, "SELECT mult(Milliseconds, Bytes) FROM Track")
@test r[1].*r[2] == s[1]
t = SQLite.query(db, "SELECT mult(Milliseconds, Bytes, 3, 4) FROM Track")
@test r[1].*r[2]*3*4 == t[1]

SQLite.@register db sin
u = SQLite.query(db, "select sin(milliseconds) from track limit 5")
@test all(-1 .< u[1] .< 1)

SQLite.register(db, hypot; nargs=2, name="hypotenuse")
v = SQLite.query(db, "select hypotenuse(Milliseconds,bytes) from track limit 5")
@test [round(Int,i) for i in v[1]] == [11175621,5521062,3997652,4339106,6301714]

SQLite.@register db str2arr(s) = convert(Array{UInt8}, s)
r = SQLite.query(db, "SELECT str2arr(LastName) FROM Employee LIMIT 2")
@test r[1] == Any[UInt8[0x41,0x64,0x61,0x6d,0x73],UInt8[0x45,0x64,0x77,0x61,0x72,0x64,0x73]]

SQLite.@register db big
r = SQLite.query(db, "SELECT big(5)")
@test r[1][1] == big(5)

doublesum_step(persist, current) = persist + current
doublesum_final(persist) = 2 * persist
SQLite.register(db, 0, doublesum_step, doublesum_final, name="doublesum")
r = SQLite.query(db, "SELECT doublesum(UnitPrice) FROM Track")
s = SQLite.query(db, "SELECT UnitPrice FROM Track")
@test_approx_eq r[1][1] 2*sum(s[1])

mycount(p, c) = p + 1
SQLite.register(db, 0, mycount)
r = SQLite.query(db, "SELECT mycount(TrackId) FROM PlaylistTrack")
s = SQLite.query(db, "SELECT count(TrackId) FROM PlaylistTrack")
@test r[1] == s[1]

bigsum(p, c) = p + big(c)
SQLite.register(db, big(0), bigsum)
r = SQLite.query(db, "SELECT bigsum(TrackId) FROM PlaylistTrack")
s = SQLite.query(db, "SELECT TrackId FROM PlaylistTrack")
@test r[1][1] == big(sum(s[1]))

SQLite.query(db, "CREATE TABLE points (x INT, y INT, z INT)")
SQLite.query(db, "INSERT INTO points VALUES (?, ?, ?)", [1, 2, 3])
SQLite.query(db, "INSERT INTO points VALUES (?, ?, ?)", [4, 5, 6])
SQLite.query(db, "INSERT INTO points VALUES (?, ?, ?)", [7, 8, 9])
type Point3D{T<:Number}
    x::T
    y::T
    z::T
end
==(a::Point3D, b::Point3D) = a.x == b.x && a.y == b.y && a.z == b.z
+(a::Point3D, b::Point3D) = Point3D(a.x + b.x, a.y + b.y, a.z + b.z)
sumpoint(p::Point3D, x, y, z) = p + Point3D(x, y, z)
SQLite.register(db, Point3D(0, 0, 0), sumpoint)
r = SQLite.query(db, "SELECT sumpoint(x, y, z) FROM points")
@test r[1][1] == Point3D(12, 15, 18)
SQLite.drop!(db, "points")

db2 = SQLite.DB()
SQLite.query(db2, "CREATE TABLE tab1 (r REAL, s INT)")

@test_throws SQLite.SQLiteException SQLite.create(db2, "tab1", [2.1 3; 3.4 8])
# should not throw any exceptions
SQLite.create(db2, "tab1", [2.1 3; 3.4 8], ifnotexists=true)
SQLite.create(db2, "tab2", [2.1 3; 3.4 8])

@test_throws SQLite.SQLiteException SQLite.drop!(db2, "nonexistant")
# should not throw anything
SQLite.drop!(db2, "nonexistant", ifexists=true)
# should SQLite.drop! "tab2"
SQLite.drop!(db2, "tab2", ifexists=true)
@test !in("tab2", SQLite.tables(db2)[1])

finalize(db2)

@test size(SQLite.tables(db)) == (11,1)

# # cd("/Users/jacobquinn/.julia/v0.4/SQLite/test")
# f = CSV.File(joinpath(dirname(@__FILE__),"csv.csv"))
# SQLite.create(a,f,"temp")
# f = CSV.File("/Users/jacobquinn/Downloads/bids.csv")
# @time lines = SQLite.create(a, f,"temp2")

finalize(db)
finalize(db) # repeatedly trying to close db
