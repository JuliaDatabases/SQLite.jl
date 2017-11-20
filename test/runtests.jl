using SQLite
using Base.Test, Missings, WeakRefStrings, DataStreams, DataFrames

import Base: +, ==

dbfile = joinpath(dirname(@__FILE__),"Chinook_Sqlite.sqlite")
dbfile2 = joinpath(dirname(@__FILE__),"test.sqlite")
dbfile = joinpath(Pkg.dir("SQLite"),"test/Chinook_Sqlite.sqlite")
dbfile2 = joinpath(Pkg.dir("SQLite"),"test/test.sqlite")
cp(dbfile, dbfile2; remove_destination=true)
db = SQLite.DB(dbfile2)

# regular SQLite tests
so = SQLite.Source(db, "SELECT name FROM sqlite_master WHERE type='table';")
ds = SQLite.query(so)
@test length(ds) == 1
@test Data.header(Data.schema(ds))[1] == "name"
@test size(Data.schema(ds)) == (11,1)

results1 = SQLite.tables(db)
@test Data.types(Data.schema(ds)) == Data.types(Data.schema(results1)) && Data.header(Data.schema(ds)) == Data.header(Data.schema(results1))
@test ds == results1

results = SQLite.query(db,"SELECT * FROM Employee;")
@test length(results) == 15
@test size(Data.schema(results)) == (8,15)
@test ismissing(results[5][1])

SQLite.query(db,"SELECT * FROM Album;")
SQLite.query(db,"SELECT a.*, b.AlbumId
	FROM Artist a
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId
	ORDER BY name;")

r = SQLite.query(db,"create table temp as select * from album")
@test length(r) == 0
r = SQLite.query(db,"select * from temp limit 10")
@test length(r) == 3
@test size(Data.schema(r)) == (10,3)
@test length(SQLite.query(db,"alter table temp add column colyear int")) == 0
@test length(SQLite.query(db,"update temp set colyear = 2014")) == 0
r = SQLite.query(db,"select * from temp limit 10")
@test length(r) == 4
@test size(Data.schema(r)) == (10,4)
@test all(Bool[x == 2014 for x in r[4]])
@test length(SQLite.query(db,"alter table temp add column dates blob")) == 0
stmt = SQLite.Stmt(db,"update temp set dates = ?")
SQLite.bind!(stmt,1,Date(2014,1,1))
SQLite.execute!(stmt)
finalize(stmt); stmt = nothing; gc()
r = SQLite.query(db,"select * from temp limit 10")
@test length(r) == 5
@test size(Data.schema(r)) == (10,5)
@test typeof(r[5][1]) == Date
@test all(Bool[x == Date(2014,1,1) for x in r[5]])
@test length(SQLite.query(db,"drop table temp")) == 0

dt = DataFrame(eye(5))
sink = SQLite.Sink(db, "temp", Data.schema(dt))
SQLite.load(sink, dt)
r = SQLite.query(db,"select * from $(sink.tablename)")
@test size(Data.schema(r)) == (5,5)
@test Data.header(Data.schema(r)) == ["x1","x2","x3","x4","x5"]
SQLite.drop!(db,"$(sink.tablename)")

dt = DataFrame(zeros(5, 5))
# dt = (; (Symbol("_$i")=>zeros(5) for i = 1:5)...)
sink = SQLite.Sink(db, "temp", Data.schema(dt))
SQLite.load(sink, dt)
r = SQLite.query(db, "select * from $(sink.tablename)")
@test size(Data.schema(r)) == (5,5)
@test all([i for i in r[1]] .== 0.0)
@test all([typeof(i) for i in r[1]] .== Float64)
SQLite.drop!(db, "$(sink.tablename)")

dt = DataFrame(zeros(5, 5))
# dt = (; (Symbol("_$i")=>zeros(Int, 5) for i = 1:5)...)
sink = SQLite.Sink(db, "temp", Data.schema(dt))
SQLite.load(sink, dt)
r = SQLite.query(db, "select * from $(sink.tablename)")
@test size(Data.schema(r)) == (5,5)
@test all([i for i in r[1]] .== 0)
@test all([typeof(i) for i in r[1]] .== Float64)

dt = DataFrame(ones(Int, 5, 5))
# dt = (; (Symbol("_$i")=>ones(Int, 5) for i = 1:5)...)
Data.stream!(dt, sink; append=true) # stream to an existing Sink
Data.close!(sink)
r = SQLite.query(db, "select * from $(sink.tablename)")
@test size(Data.schema(r)) == (10,5)
@test r[1] == [0,0,0,0,0,1,1,1,1,1]
@test all([typeof(i) for i in r[1]] .== Float64)
SQLite.drop!(db, "$(sink.tablename)")

rng = Date(2013):Dates.Day(1):Date(2013,1,5)
dt = DataFrame(i=collect(rng), j=collect(rng))
sink = SQLite.Sink(db, "temp", Data.schema(dt))
SQLite.load(sink, dt)
r = SQLite.query(db, "select * from $(sink.tablename)")
@test size(Data.schema(r)) == (5,2)
@test all([i for i in r[1]] .== rng)
@test all([typeof(i) for i in r[1]] .== Date)
SQLite.drop!(db, "$(sink.tablename)")

SQLite.query(db, "CREATE TABLE temp AS SELECT * FROM Album")
r = SQLite.query(db, "SELECT * FROM temp LIMIT ?"; values=[3])
@test size(Data.schema(r)) == (3,3)
r = SQLite.query(db, "SELECT * FROM temp WHERE Title LIKE ?"; values=["%time%"])
@test r[1] == [76, 111, 187]
SQLite.query(db, "INSERT INTO temp VALUES (?1, ?3, ?2)"; values=[0,0,"Test Album"])
r = SQLite.query(db, "SELECT * FROM temp WHERE AlbumId = 0")
@test r[1][1] === 0
@test r[2][1] == "Test Album"
@test r[3][1] === 0
SQLite.drop!(db, "temp")

SQLite.query(db, "CREATE TABLE temp AS SELECT * FROM Album")
r = SQLite.query(db, "SELECT * FROM temp LIMIT :a"; values=Dict(:a => 3))
@test size(Data.schema(r)) == (3,3)
r = SQLite.query(db, "SELECT * FROM temp WHERE Title LIKE @word"; values=Dict(:word => "%time%"))
@test r[1] == [76, 111, 187]
SQLite.query(db, "INSERT INTO temp VALUES (@lid, :title, \$rid)"; values=Dict(:rid => 0, :lid => 0, :title => "Test Album"))
r = SQLite.query(db, "SELECT * FROM temp WHERE AlbumId = 0")
@test r[1][1] === 0
@test r[2][1] == "Test Album"
@test r[3][1] === 0
SQLite.drop!(db, "temp")

register(db, SQLite.regexp, nargs=2, name="regexp")
r = SQLite.query(db, SQLite.@sr_str("SELECT LastName FROM Employee WHERE BirthDate REGEXP '^\\d{4}-08'"))
@test r[1][1] == "Peacock"

triple(x) = 3x
@test_throws AssertionError SQLite.register(db, triple, nargs=186)
SQLite.register(db, triple, nargs=1)
r = SQLite.query(db, "SELECT triple(Total) FROM Invoice ORDER BY InvoiceId LIMIT 5")
s = SQLite.query(db, "SELECT Total FROM Invoice ORDER BY InvoiceId LIMIT 5")
for (i, j) in zip(r[1], s[1])
    @test abs(i - 3*j) < 0.02
end

SQLite.@register db function add4(q)
    q+4
end
r = SQLite.query(db, "SELECT add4(AlbumId) FROM Album")
s = SQLite.query(db, "SELECT AlbumId FROM Album")
@test r[1][1] == s[1][1] + 4

SQLite.@register db mult(args...) = *(args...)
r = SQLite.query(db, "SELECT Milliseconds, Bytes FROM Track")
s = SQLite.query(db, "SELECT mult(Milliseconds, Bytes) FROM Track")
@test (r[1][1] * r[2][1]) == s[1][1]
t = SQLite.query(db, "SELECT mult(Milliseconds, Bytes, 3, 4) FROM Track")
@test (r[1][1] * r[2][1] * 3 * 4) == t[1][1]

SQLite.@register db sin
u = SQLite.query(db, "select sin(milliseconds) from track limit 5")
@test all(-1 .< convert(Vector{Float64},u[1]) .< 1)

SQLite.register(db, hypot; nargs=2, name="hypotenuse")
v = SQLite.query(db, "select hypotenuse(Milliseconds,bytes) from track limit 5")
@test [round(Int,i) for i in v[1]] == [11175621,5521062,3997652,4339106,6301714]

SQLite.@register db str2arr(s) = Vector{UInt8}(s)
r = SQLite.query(db, "SELECT str2arr(LastName) FROM Employee LIMIT 2")
@test r[1][2] == UInt8[0x45,0x64,0x77,0x61,0x72,0x64,0x73]

SQLite.@register db big
r = SQLite.query(db, "SELECT big(5)")
@test r[1][1] == big(5)

doublesum_step(persist, current) = persist + current
doublesum_final(persist) = 2 * persist
SQLite.register(db, 0, doublesum_step, doublesum_final, name="doublesum")
r = SQLite.query(db, "SELECT doublesum(UnitPrice) FROM Track")
s = SQLite.query(db, "SELECT UnitPrice FROM Track")
@test abs(r[1][1] - 2*sum(convert(Vector{Float64},s[1]))) < 0.02

mycount(p, c) = p + 1
SQLite.register(db, 0, mycount)
r = SQLite.query(db, "SELECT mycount(TrackId) FROM PlaylistTrack")
s = SQLite.query(db, "SELECT count(TrackId) FROM PlaylistTrack")
@test r[1][1] == s[1][1]

bigsum(p, c) = p + big(c)
SQLite.register(db, big(0), bigsum)
r = SQLite.query(db, "SELECT bigsum(TrackId) FROM PlaylistTrack")
s = SQLite.query(db, "SELECT TrackId FROM PlaylistTrack")
# @test r[1][1] == big(sum(convert(Vector{Int},s[1])))

SQLite.query(db, "CREATE TABLE points (x INT, y INT, z INT)")
SQLite.query(db, "INSERT INTO points VALUES (?, ?, ?)"; values=[1, 2, 3])
SQLite.query(db, "INSERT INTO points VALUES (?, ?, ?)"; values=[4, 5, 6])
SQLite.query(db, "INSERT INTO points VALUES (?, ?, ?)"; values=[7, 8, 9])
mutable struct Point3D{T<:Number}
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

@test_throws SQLite.SQLiteException SQLite.drop!(db2, "nonexistant")
# should not throw anything
SQLite.drop!(db2, "nonexistant", ifexists=true)
# should drop "tab2"
SQLite.drop!(db2, "tab2", ifexists=true)
@test !in("tab2", SQLite.tables(db2)[1])

SQLite.drop!(db, "sqlite_stat1")
@test size(Data.schema(SQLite.tables(db))) == (11,1)

finalize(db); db = nothing; gc(); gc();

#Test removeduplicates!
db = SQLite.DB() #In case the order of tests is changed
ints = Int64[1,1,2,2,3]
strs = String["A", "A", "B", "C", "C"]
dt = DataFrame(ints=ints, strs=strs)
sink = SQLite.Sink(db, "temp", Data.schema(dt))
SQLite.load(sink, dt)
SQLite.removeduplicates!(db, "temp", ["ints", "strs"]) #New format
dt3 = SQLite.query(db, "Select * from temp")
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
SQLite.query(binddb, "CREATE TABLE temp (n NULL, i6 INT, f REAL, s TEXT, a BLOB)")
SQLite.query(binddb, "INSERT INTO temp VALUES (?1, ?2, ?3, ?4, ?5)"; values=Any[missing, convert(Int64,6), 6.4, "some text", b"bytearray"])
r = SQLite.query(binddb, "SELECT * FROM temp")
@test isa(r[1][1], Missing)
@test isa(r[2][1], Int)
@test isa(r[3][1], Float64)
@test isa(r[4][1], AbstractString)
@test isa(r[5][1], Vector{UInt8})
SQLite.query(binddb, "CREATE TABLE blobtest (a BLOB, b BLOB)")
SQLite.query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)"; values=Any[b"a", b"b"])
SQLite.query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)"; values=Any[b"a", BigInt(2)])
mutable struct Point{T}
    x::T
    y::T
end
==(a::Point, b::Point) = a.x == b.x && a.y == b.y
p1 = Point(1, 2)
p2 = Point(1.3, 2.4)
SQLite.query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)"; values=Any[b"a", p1])
SQLite.query(binddb, "INSERT INTO blobtest VALUES (?1, ?2)"; values=Any[b"a", p2])
r = SQLite.query(binddb, "SELECT * FROM blobtest"; stricttypes=false)
for value in r[1]
    @test value == b"a"
end
@test r[2][3] == p1
@test r[2][4] == p2
############################################
