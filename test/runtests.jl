using SQLite
using Test, Dates, Random, WeakRefStrings, Tables

import Base: +, ==
mutable struct Point{T}
    x::T
    y::T
end
==(a::Point, b::Point) = a.x == b.x && a.y == b.y

mutable struct Point3D{T<:Number}
    x::T
    y::T
    z::T
end
==(a::Point3D, b::Point3D) = a.x == b.x && a.y == b.y && a.z == b.z
+(a::Point3D, b::Point3D) = Point3D(a.x + b.x, a.y + b.y, a.z + b.z)


dbfile = joinpath(dirname(pathof(SQLite)),"../test/Chinook_Sqlite.sqlite")
dbfile2 = joinpath(tempdir(), "test.sqlite")
cp(dbfile, dbfile2; force=true)
chmod(dbfile2, 0o777)
db = SQLite.DB(dbfile2)

# regular SQLite tests
ds = SQLite.Query(db, "SELECT name FROM sqlite_master WHERE type='table';") |> columntable
@test length(ds) == 1
@test keys(ds) == (:name,)
@test length(ds.name) == 11

results1 = SQLite.tables(db, columntable)
@test isequal(ds, results1)

results = SQLite.Query(db,"SELECT * FROM Employee;") |> DataFrame
@test size(results) == (8, 15)

SQLite.Query(db,"SELECT * FROM Album;")
SQLite.Query(db,"SELECT a.*, b.AlbumId
	FROM Artist a
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId
	ORDER BY name;")

r = SQLite.execute!(db,"create table temp as select * from album")
r = SQLite.Query(db,"select * from temp limit 10") |> DataFrame
@test size(r) == (10,3)
SQLite.execute!(db,"alter table temp add column colyear int")
SQLite.execute!(db,"update temp set colyear = 2014")
r = SQLite.Query(db,"select * from temp limit 10") |> DataFrame
@test size(r) == (10,4)
@test all(Bool[x == 2014 for x in r[4]])
SQLite.execute!(db,"alter table temp add column dates blob")
stmt = SQLite.Stmt(db,"update temp set dates = ?")
SQLite.bind!(stmt,1,Dates.Date(2014,1,1))
SQLite.execute!(stmt)
finalize(stmt); stmt = nothing; GC.gc()
r = SQLite.Query(db,"select * from temp limit 10") |> DataFrame
@test size(r) == (10,5)
@test typeof(r[5][1]) == Date
@test all(Bool[x == Date(2014,1,1) for x in r[5]])
SQLite.execute!(db,"drop table temp")

dt = DataFrame([1.0 0.0 0.0 0.0 0.0; 0.0 1.0 0.0 0.0 0.0; 0.0 0.0 1.0 0.0 0.0; 0.0 0.0 0.0 1.0 0.0; 0.0 0.0 0.0 0.0 1.0])
tablename = dt |> SQLite.load!(db, "temp")
r = SQLite.Query(db,"select * from $tablename") |> DataFrame
@test size(r) == (5, 5)
@test names(r) == [:x1, :x2, :x3, :x4, :x5]
SQLite.drop!(db,"$tablename")

dt = DataFrame(zeros(5, 5))
tablename = dt |> SQLite.load!(db, "temp")
r = SQLite.Query(db, "select * from $tablename") |> DataFrame
@test size(r) == (5,5)
@test all([i for i in r[1]] .== 0.0)
@test all([typeof(i) for i in r[1]] .== Float64)
SQLite.drop!(db, "$tablename")

dt = DataFrame(zeros(5, 5))
tablename = dt |> SQLite.load!(db, "temp")
r = SQLite.Query(db, "select * from $tablename") |> DataFrame
@test size(r) == (5,5)
@test all([i for i in r[1]] .== 0)
@test all([typeof(i) for i in r[1]] .== Float64)

dt = DataFrame(ones(Int, 5, 5))
tablename = dt |> SQLite.load!(db, "temp")
r = SQLite.Query(db, "select * from $tablename") |> DataFrame
@test size(r) == (10,5)
@test r[1] == [0,0,0,0,0,1,1,1,1,1]
@test all([typeof(i) for i in r[1]] .== Float64)
SQLite.drop!(db, "$tablename")

rng = Dates.Date(2013):Dates.Day(1):Dates.Date(2013,1,5)
dt = DataFrame(i=collect(rng), j=collect(rng))
tablename = dt |> SQLite.load!(db, "temp")
r = SQLite.Query(db, "select * from $tablename") |> DataFrame
@test size(r) == (5,2)
@test all([i for i in r[1]] .== collect(rng))
@test all([typeof(i) for i in r[1]] .== Dates.Date)
SQLite.drop!(db, "$tablename")

SQLite.execute!(db, "CREATE TABLE temp AS SELECT * FROM Album")
r = SQLite.Query(db, "SELECT * FROM temp LIMIT ?"; values=[3]) |> DataFrame
@test size(r) == (3,3)
r = SQLite.Query(db, "SELECT * FROM temp WHERE Title LIKE ?"; values=["%time%"]) |> DataFrame
@test r[1] == [76, 111, 187]
SQLite.execute!(db, "INSERT INTO temp VALUES (?1, ?3, ?2)"; values=[0,0,"Test Album"])
r = SQLite.Query(db, "SELECT * FROM temp WHERE AlbumId = 0") |> DataFrame
@test r[1][1] === 0
@test r[2][1] == "Test Album"
@test r[3][1] === 0
SQLite.drop!(db, "temp")

SQLite.execute!(db, "CREATE TABLE temp AS SELECT * FROM Album")
r = SQLite.Query(db, "SELECT * FROM temp LIMIT :a"; values=Dict(:a => 3)) |> DataFrame
@test size(r) == (3,3)
r = SQLite.Query(db, "SELECT * FROM temp WHERE Title LIKE @word"; values=Dict(:word => "%time%")) |> DataFrame
@test r[1] == [76, 111, 187]
SQLite.execute!(db, "INSERT INTO temp VALUES (@lid, :title, \$rid)"; values=Dict(:rid => 0, :lid => 0, :title => "Test Album"))
r = SQLite.Query(db, "SELECT * FROM temp WHERE AlbumId = 0") |> DataFrame
@test r[1][1] === 0
@test r[2][1] == "Test Album"
@test r[3][1] === 0
SQLite.drop!(db, "temp")

register(db, SQLite.regexp, nargs=2, name="regexp")
r = SQLite.Query(db, SQLite.@sr_str("SELECT LastName FROM Employee WHERE BirthDate REGEXP '^\\d{4}-08'")) |> DataFrame
@test r[1][1] == "Peacock"

triple(x) = 3x
@test_throws AssertionError SQLite.register(db, triple, nargs=186)
SQLite.register(db, triple, nargs=1)
r = SQLite.Query(db, "SELECT triple(Total) FROM Invoice ORDER BY InvoiceId LIMIT 5") |> DataFrame
s = SQLite.Query(db, "SELECT Total FROM Invoice ORDER BY InvoiceId LIMIT 5") |> DataFrame
for (i, j) in zip(r[1], s[1])
    @test abs(i - 3*j) < 0.02
end

SQLite.@register db function add4(q)
    q+4
end
r = SQLite.Query(db, "SELECT add4(AlbumId) FROM Album") |> DataFrame
s = SQLite.Query(db, "SELECT AlbumId FROM Album") |> DataFrame
@test r[1][1] == s[1][1] + 4

SQLite.@register db mult(args...) = *(args...)
r = SQLite.Query(db, "SELECT Milliseconds, Bytes FROM Track") |> DataFrame
s = SQLite.Query(db, "SELECT mult(Milliseconds, Bytes) FROM Track") |> DataFrame
@test (r[1][1] * r[2][1]) == s[1][1]
t = SQLite.Query(db, "SELECT mult(Milliseconds, Bytes, 3, 4) FROM Track") |> DataFrame
@test (r[1][1] * r[2][1] * 3 * 4) == t[1][1]

SQLite.@register db sin
u = SQLite.Query(db, "select sin(milliseconds) from track limit 5") |> DataFrame
@test all(-1 .< convert(Vector{Float64},u[1]) .< 1)

SQLite.register(db, hypot; nargs=2, name="hypotenuse")
v = SQLite.Query(db, "select hypotenuse(Milliseconds,bytes) from track limit 5") |> DataFrame
@test [round(Int,i) for i in v[1]] == [11175621,5521062,3997652,4339106,6301714]

SQLite.@register db str2arr(s) = Vector{UInt8}(s)
r = SQLite.Query(db, "SELECT str2arr(LastName) FROM Employee LIMIT 2") |> DataFrame
@test r[1][2] == UInt8[0x45,0x64,0x77,0x61,0x72,0x64,0x73]

SQLite.@register db big
r = SQLite.Query(db, "SELECT big(5)") |> DataFrame
@test r[1][1] == big(5)

doublesum_step(persist, current) = persist + current
doublesum_final(persist) = 2 * persist
SQLite.register(db, 0, doublesum_step, doublesum_final, name="doublesum")
r = SQLite.Query(db, "SELECT doublesum(UnitPrice) FROM Track") |> DataFrame
s = SQLite.Query(db, "SELECT UnitPrice FROM Track") |> DataFrame
@test abs(r[1][1] - 2*sum(convert(Vector{Float64},s[1]))) < 0.02

mycount(p, c) = p + 1
SQLite.register(db, 0, mycount)
r = SQLite.Query(db, "SELECT mycount(TrackId) FROM PlaylistTrack") |> DataFrame
s = SQLite.Query(db, "SELECT count(TrackId) FROM PlaylistTrack") |> DataFrame
@test r[1][1] == s[1][1]

bigsum(p, c) = p + big(c)
SQLite.register(db, big(0), bigsum)
r = SQLite.Query(db, "SELECT bigsum(TrackId) FROM PlaylistTrack") |> DataFrame
s = SQLite.Query(db, "SELECT TrackId FROM PlaylistTrack") |> DataFrame
# @test r[1][1] == big(sum(convert(Vector{Int},s[1])))

SQLite.execute!(db, "CREATE TABLE points (x INT, y INT, z INT)")
SQLite.execute!(db, "INSERT INTO points VALUES (?, ?, ?)"; values=[1, 2, 3])
SQLite.execute!(db, "INSERT INTO points VALUES (?, ?, ?)"; values=[4, 5, 6])
SQLite.execute!(db, "INSERT INTO points VALUES (?, ?, ?)"; values=[7, 8, 9])

sumpoint(p::Point3D, x, y, z) = p + Point3D(x, y, z)
SQLite.register(db, Point3D(0, 0, 0), sumpoint)
r = SQLite.Query(db, "SELECT sumpoint(x, y, z) FROM points") |> DataFrame
@test r[1][1] == Point3D(12, 15, 18)
SQLite.drop!(db, "points")

db2 = SQLite.DB()
SQLite.execute!(db2, "CREATE TABLE tab1 (r REAL, s INT)")

@test_throws SQLite.SQLiteException SQLite.drop!(db2, "nonexistant")
# should not throw anything
SQLite.drop!(db2, "nonexistant", ifexists=true)
# should drop "tab2"
SQLite.drop!(db2, "tab2", ifexists=true)
@test !in("tab2", SQLite.tables(db2)[1])

SQLite.drop!(db, "sqlite_stat1")
@test size(SQLite.tables(db)) == (11,1)

finalize(db); db = nothing; GC.gc(); GC.gc();

#Test removeduplicates!
db = SQLite.DB() #In case the order of tests is changed
ints = Int64[1,1,2,2,3]
strs = String["A", "A", "B", "C", "C"]
dt = DataFrame(ints=ints, strs=strs)
tablename = dt |> SQLite.load!(db, "temp")
SQLite.removeduplicates!(db, "temp", ["ints", "strs"]) #New format
dt3 = SQLite.Query(db, "Select * from temp") |> DataFrame
@test dt3[1][1] == 1
@test dt3[2][1] == "A"
@test dt3[1][2] == 2
@test dt3[2][2] == "B"
@test dt3[1][3] == 2
@test dt3[2][3] == "C"

# issue #104
db = SQLite.DB() #In case the order of tests is changed
SQLite.execute!(db, "CREATE TABLE IF NOT EXISTS tbl(a  INTEGER);")
stmt = SQLite.Stmt(db, "INSERT INTO tbl (a) VALUES (@a);")
SQLite.bind!(stmt, "@a", 1)

binddb = SQLite.DB()
SQLite.execute!(binddb, "CREATE TABLE temp (n NULL, i6 INT, f REAL, s TEXT, a BLOB)")
SQLite.execute!(binddb, "INSERT INTO temp VALUES (?1, ?2, ?3, ?4, ?5)"; values=Any[missing, convert(Int64,6), 6.4, "some text", b"bytearray"])
r = SQLite.Query(binddb, "SELECT * FROM temp") |> DataFrame
@test isa(r[1][1], Missing)
@test isa(r[2][1], Int)
@test isa(r[3][1], Float64)
@test isa(r[4][1], AbstractString)
@test isa(r[5][1], Base.CodeUnits)
SQLite.execute!(binddb, "CREATE TABLE blobtest (a BLOB, b BLOB)")
SQLite.execute!(binddb, "INSERT INTO blobtest VALUES (?1, ?2)"; values=Any[b"a", b"b"])
SQLite.execute!(binddb, "INSERT INTO blobtest VALUES (?1, ?2)"; values=Any[b"a", BigInt(2)])

p1 = Point(1, 2)
p2 = Point(1.3, 2.4)
SQLite.execute!(binddb, "INSERT INTO blobtest VALUES (?1, ?2)"; values=Any[b"a", p1])
SQLite.execute!(binddb, "INSERT INTO blobtest VALUES (?1, ?2)"; values=Any[b"a", p2])
r = SQLite.Query(binddb, "SELECT * FROM blobtest"; stricttypes=false) |> DataFrame
for value in r[1]
    @test value == b"a"
end
@test r[2][3] == p1
@test r[2][4] == p2
############################################

#test for #158
@test_throws SQLite.SQLiteException SQLite.DB("nonexistentdir/not_there.db")

#test for #180 (Query)
param = "Hello!"
query = SQLite.Query(SQLite.DB(), "SELECT ?1 UNION ALL SELECT ?1", values = Any[param])
param = "x"
for row in query
    @test row[1] == "Hello!"
    GC.gc() # this must NOT garbage collect the "Hello!" bound value
end

#test for #180 (bind! and clear!)
params = tuple("string", UInt8[1, 2, 3]) # parameter types that can be finalized
wkdict = WeakKeyDict{Any, Any}(param => 1 for param in params)
stmt = SQLite.Stmt(SQLite.DB(), "SELECT ?, ?")
SQLite.bind!(stmt, params)
params = "x"
GC.gc() # this MUST NOT garbage collect any of the bound values
@test length(wkdict) == 2
SQLite.clear!(stmt)
GC.gc() # this will garbage collect the no longer bound values
@test isempty(wkdict)

db = SQLite.DB()
SQLite.execute!(db, "CREATE TABLE T (a TEXT, PRIMARY KEY (a))")

q = SQLite.Stmt(db, "INSERT INTO T VALUES(?)")
SQLite.bind!(q, 1, "a")
SQLite.execute!(q)

SQLite.bind!(q, 1, "a")
@test_throws SQLite.SQLiteException SQLite.execute!(q)

@test SQLite.@OK SQLite.enable_load_extension(db)
