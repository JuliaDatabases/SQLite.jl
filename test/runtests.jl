reload("SQLite")
using Base.Test, Compat, DataStreams, NullableArrays

import Base: +, ==

a = SQLite.DB()

temp = tempname()
SQLite.DB(temp)

# db = SQLite.DB("/Users/jacobquinn/.julia/v0.4/SQLite/test/Chinook_Sqlite.sqlite")
db = SQLite.DB(joinpath(dirname(@__FILE__),"Chinook_Sqlite.sqlite"))

so = SQLite.Source(db,"SELECT name FROM sqlite_master WHERE type='table';")
ds = Data.stream!(so,Data.Table)
@test length(ds.data) == 1
@test Data.header(ds)[1] == "name"
@test size(ds) == (11,1)

results1 = SQLite.tables(db)
@test ds.schema == results1.schema
@test ds.data[1].values == results1.data[1].values

results = SQLite.query(db,"SELECT * FROM Employee;")
@test length(results.data) == 15
@test size(results) == (8,15)
@test typeof(results[1,1]) == Nullable{Int}
@test typeof(results[1,2]) == Nullable{Compat.UTF8String}
@test isnull(results[1,5])

SQLite.query(db,"SELECT * FROM Album;")
SQLite.query(db,"SELECT a.*, b.AlbumId
	FROM Artist a
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId
	ORDER BY name;")

r = SQLite.query(db,"create table temp as select * from album")
@test length(r.data) == 0
r = SQLite.query(db,"select * from temp limit 10")
@test length(r.data) == 3
@test size(r) == (10,3)
@test length(SQLite.query(db,"alter table temp add column colyear int").data) == 0
@test length(SQLite.query(db,"update temp set colyear = 2014").data) == 0
r = SQLite.query(db,"select * from temp limit 10")
@test length(r.data) == 4
@test size(r) == (10,4)
@test all(Bool[get(x) == 2014 for x in r[:,4]])
@test length(SQLite.query(db,"alter table temp add column dates blob").data) == 0
stmt = SQLite.Stmt(db,"update temp set dates = ?")
SQLite.bind!(stmt,1,Date(2014,1,1))
SQLite.execute!(stmt)
r = SQLite.query(db,"select * from temp limit 10")
@test length(r.data) == 5
@test size(r) == (10,5)
@test typeof(r[1,5]) == Nullable{Date}
@test all(Bool[get(x) == Date(2014,1,1) for x in r[:,5]])
@test length(SQLite.query(db,"drop table temp").data) == 0

dt = Data.Table(Data.Schema([Float64,Float64,Float64,Float64,Float64],5))
sink = SQLite.Sink(dt,db)
Data.stream!(dt,sink)
r = SQLite.query(db,"select * from $(sink.tablename)")
@test size(r) == (5,5)
@test all(map(isnull,r.data))
@test all([typeof(i[1]) for i in r.data] .== Nullable{Any})
@test Data.header(r) == ["Column1","Column2","Column3","Column4","Column5"]
SQLite.drop!(db,"$(sink.tablename)")

dt = Data.Table(zeros(5,5))
sink = SQLite.Sink(dt,db)
Data.stream!(dt,sink)
r = SQLite.query(db,"select * from $(sink.tablename)")
@test size(r) == (5,5)
@test all([get(i) for i in r.data[1]] .== 0.0)
@test all([eltype(i) for i in r.data[1]] .== Float64)
SQLite.drop!(db,"$(sink.tablename)")

dt = Data.Table(zeros(Int,5,5))
sink = SQLite.Sink(dt,db)
Data.stream!(dt,sink)
r = SQLite.query(db,"select * from $(sink.tablename)")
@test size(r) == (5,5)
@test all([get(i) for i in r.data[1]] .== 0)
@test all([eltype(i) for i in r.data[1]] .== Int)

dt = Data.Table(ones(Int,5,5))
Data.stream!(dt,sink) # stream to an existing Sink
r = SQLite.query(db,"select * from $(sink.tablename)")
@test size(r) == (10,5)
@test [get(i) for i in r.data[1]] == [0,0,0,0,0,1,1,1,1,1]
@test all([eltype(i) for i in r.data[1]] .== Int)
SQLite.drop!(db,"$(sink.tablename)")

rng = Date(2013):Date(2013,1,5)
dt = Data.Table([i for i = rng, j = rng])
sink = SQLite.Sink(dt,db)
Data.stream!(dt,sink)
r = SQLite.query(db,"select * from $(sink.tablename)")
@test size(r) == (5,5)
@test all([get(i) for i in r.data[1]] .== rng)
@test all([eltype(i) for i in r.data[1]] .== Date)
SQLite.drop!(db,"$(sink.tablename)")

SQLite.query(db,"CREATE TABLE temp AS SELECT * FROM Album")
r = SQLite.query(db, "SELECT * FROM temp LIMIT ?", [3])
@test size(r) == (3,3)
r = SQLite.query(db, "SELECT * FROM temp WHERE Title LIKE ?", ["%time%"])
@test [get(i) for i in r.data[1]] == [76, 111, 187]
SQLite.query(db, "INSERT INTO temp VALUES (?1, ?3, ?2)", [0,0,"Test Album"])
r = SQLite.query(db, "SELECT * FROM temp WHERE AlbumId = 0")
@test r[1,1] === Nullable(0)
@test get(r[1,2]) == "Test Album"
@test r[1,3] === Nullable(0)
SQLite.drop!(db, "temp")

binddb = SQLite.DB()
SQLite.query(binddb, "CREATE TABLE temp (n NULL, i6 INT, f REAL, s TEXT, a BLOB)")
SQLite.query(binddb, "INSERT INTO temp VALUES (?1, ?2, ?3, ?4, ?5)", Any[SQLite.NULL, convert(Int64,6), 6.4, "some text", b"bytearray"])
r = SQLite.query(binddb, "SELECT * FROM temp")
@test isa(get(r.data[1][1],SQLite.NULL),SQLite.NullType)
@test isa(get(r.data[2][1]),Int)
@test isa(get(r.data[3][1]),Float64)
@test isa(get(r.data[4][1]),AbstractString)
@test isa(get(r.data[5][1]),Vector{UInt8})
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
r = SQLite.query(binddb, "SELECT * FROM blobtest";stricttypes=false)
for v in r.data[1]
    @test get(v) == b"a"
end
for (v1, v2) in zip(r.data[2], Any[b"b", BigInt(2), p1, p2])
    @test get(v1) == v2
end
############################################

SQLite.query(db,"CREATE TABLE temp AS SELECT * FROM Album")
r = SQLite.query(db, "SELECT * FROM temp LIMIT :a", Dict(:a => 3))
@test size(r) == (3,3)
r = SQLite.query(db, "SELECT * FROM temp WHERE Title LIKE @word", Dict(:word => "%time%"))
@test [get(i) for i in r.data[1]] == [76, 111, 187]
SQLite.query(db, "INSERT INTO temp VALUES (@lid, :title, \$rid)", Dict(:rid => 0, :lid => 0, :title => "Test Album"))
r = SQLite.query(db, "SELECT * FROM temp WHERE AlbumId = 0")
@test r[1,1] === Nullable(0)
@test get(r[1,2]) == "Test Album"
@test r[1,3] === Nullable(0)
SQLite.drop!(db, "temp")

r = SQLite.query(db, SQLite.@sr_str("SELECT LastName FROM Employee WHERE BirthDate REGEXP '^\\d{4}-08'"))
@test get(r.data[1][1]) == "Peacock"

triple(x) = 3x
@test_throws AssertionError SQLite.register(db, triple, nargs=186)
SQLite.register(db, triple, nargs=1)
r = SQLite.query(db, "SELECT triple(Total) FROM Invoice ORDER BY InvoiceId LIMIT 5")
s = SQLite.query(db, "SELECT Total FROM Invoice ORDER BY InvoiceId LIMIT 5")
for (i, j) in zip(r.data[1], s.data[1])
    @test_approx_eq get(i) 3*get(j)
end

SQLite.@register db function add4(q)
    q+4
end
r = SQLite.query(db, "SELECT add4(AlbumId) FROM Album")
s = SQLite.query(db, "SELECT AlbumId FROM Album")
@test get(r[1,1]) == get(s[1,1])+4

SQLite.@register db mult(args...) = *(args...)
r = SQLite.query(db, "SELECT Milliseconds, Bytes FROM Track")
s = SQLite.query(db, "SELECT mult(Milliseconds, Bytes) FROM Track")
@test (get(r[1,1]) * get(r[1,2])) == get(s[1,1])
t = SQLite.query(db, "SELECT mult(Milliseconds, Bytes, 3, 4) FROM Track")
@test (get(r[1,1]) * get(r[1,2]) * 3 * 4) == get(t[1,1])

SQLite.@register db sin
u = SQLite.query(db, "select sin(milliseconds) from track limit 5")
@test all(-1 .< convert(Vector{Float64},u[:,1]) .< 1)

SQLite.register(db, hypot; nargs=2, name="hypotenuse")
v = SQLite.query(db, "select hypotenuse(Milliseconds,bytes) from track limit 5")
@test [@compat round(Int,get(i)) for i in v.data[1]] == [11175621,5521062,3997652,4339106,6301714]

SQLite.@register db str2arr(s) = convert(Array{UInt8}, s)
r = SQLite.query(db, "SELECT str2arr(LastName) FROM Employee LIMIT 2")
@test [get(i) for i in r.data[1]] == Any[UInt8[0x41,0x64,0x61,0x6d,0x73],UInt8[0x45,0x64,0x77,0x61,0x72,0x64,0x73]]

SQLite.@register db big
r = SQLite.query(db, "SELECT big(5)")
@test get(r[1,1]) == big(5)

doublesum_step(persist, current) = persist + current
doublesum_final(persist) = 2 * persist
SQLite.register(db, 0, doublesum_step, doublesum_final, name="doublesum")
r = SQLite.query(db, "SELECT doublesum(UnitPrice) FROM Track")
s = SQLite.query(db, "SELECT UnitPrice FROM Track")
@test_approx_eq get(r[1,1]) 2*sum(convert(Vector{Float64},s.data[1]))

mycount(p, c) = p + 1
SQLite.register(db, 0, mycount)
r = SQLite.query(db, "SELECT mycount(TrackId) FROM PlaylistTrack")
s = SQLite.query(db, "SELECT count(TrackId) FROM PlaylistTrack")
@test get(r[1,1]) == get(s[1,1])

bigsum(p, c) = p + big(c)
SQLite.register(db, big(0), bigsum)
r = SQLite.query(db, "SELECT bigsum(TrackId) FROM PlaylistTrack")
s = SQLite.query(db, "SELECT TrackId FROM PlaylistTrack")
@test get(r[1,1]) == big(sum(convert(Vector{Int},s.data[1])))

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
@test get(r[1,1]) == Point3D(12, 15, 18)
SQLite.drop!(db, "points")

db2 = SQLite.DB()
SQLite.query(db2, "CREATE TABLE tab1 (r REAL, s INT)")

@test_throws SQLite.SQLiteException SQLite.drop!(db2, "nonexistant")
# should not throw anything
SQLite.drop!(db2, "nonexistant", ifexists=true)
# should drop "tab2"
SQLite.drop!(db2, "tab2", ifexists=true)
@test !in("tab2", SQLite.tables(db2).data[1])

SQLite.drop!(db, "sqlite_stat1")
@test size(SQLite.tables(db)) == (11,1)

source = SQLite.Source(db,"select * from album")
temp = tempname()
sink = CSV.Sink(temp)
Data.stream!(source,sink)
dt = Data.stream!(CSV.Source(sink),Data.Table)
@test get(dt[1,1]) == 1
@test get(dt[1,2]) == "For Those About To Rock We Salute You"
@test get(dt[1,3]) == 1

db = nothing; gc(); gc();

db = SQLite.DB()
source = CSV.Source(temp)
sink = SQLite.Sink(source,db,"temp")
Data.stream!(source,sink)
source2 = SQLite.Source(sink)
dt = Data.stream!(source2,Data.Table)
@test get(dt[1,1]) == 1
@test string(get(dt[1,2])) == "For Those About To Rock We Salute You"
@test get(dt[1,3]) == 1

sink = SQLite.Sink(Data.schema(dt), db, "temp2")
Data.stream!(dt,sink)
source3 = SQLite.Source(sink)
dt = Data.stream!(source3,Data.Table)
@test get(dt[1,1]) == 1
@test string(get(dt[1,2])) == "For Those About To Rock We Salute You"
@test get(dt[1,3]) == 1

#Make sure we handle undefined values
db = SQLite.DB() #In case the order of tests is changed
arr = Array(Compat.UTF8String,2) 
arr[1] = "1" #Now an array with the second value undefined
nv = NullableArrays.NullableArray(arr, [false, true])
schema = DataStreams.Data.Schema(["nv"], [Compat.UTF8String],2)
d = NullableArrays.NullableVector[nv]
dt = DataStreams.Data.Table(schema, d,0)
SQLite.drop!(db, "temp", ifexists=true)
sink = SQLite.Sink(dt, db, "temp")
Data.stream!(dt, sink)
dt2 = SQLite.query(db, "Select * from temp")
#There might be a better way to check this
@test dt.data[1][1].value==dt2.data[1][1].value
@test dt.data[1][2].isnull==dt2.data[1][2].isnull

#Test removeduplicates!
db = SQLite.DB() #In case the order of tests is changed
ints = Int64[1,1,2,2,3]
strs = Compat.UTF8String["A", "A", "B", "C", "C"]
nvInts = NullableArrays.NullableArray(ints)
nvStrs = NullableArrays.NullableArray(strs)
schema = DataStreams.Data.Schema(["ints", "strs"], [Int64, Compat.UTF8String],5)
d = NullableArrays.NullableVector[nvInts, nvStrs]
dt = DataStreams.Data.Table(schema, d,0)
SQLite.drop!(db, "temp", ifexists=true)
sink = SQLite.Sink(dt, db, "temp")
Data.stream!(dt, sink)
SQLite.removeduplicates!(db, "temp", ["ints","strs"]) #New format
dt3 = SQLite.query(db, "Select * from temp")
@test get(dt3[1,1]) == 1
@test get(dt3[1,2]) == "A"
@test get(dt3[2,1]) == 2
@test get(dt3[2,2]) == "B"
@test get(dt3[3,1]) == 2
@test get(dt3[3,2]) == "C"
