using SQLite
using Test, Dates, Random, WeakRefStrings, Tables, DBInterface, Distributed

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

triple(x) = 3x
function add4(q)
    q+4
end
mult(args...) = *(args...)
str2arr(s) = Vector{UInt8}(s)
doublesum_step(persist, current) = persist + current
doublesum_final(persist) = 2 * persist
mycount(p, c) = p + 1
bigsum(p, c) = p + big(c)
sumpoint(p::Point3D, x, y, z) = p + Point3D(x, y, z)

dbfile = joinpath(dirname(pathof(SQLite)), "../test/Chinook_Sqlite.sqlite")
dbfile2 = joinpath(tempdir(), "test.sqlite")
cp(dbfile, dbfile2; force=true)
chmod(dbfile2, 0o777)

@testset "basics" begin

db = SQLite.DB(dbfile2)
db = DBInterface.connect(SQLite.DB, dbfile2)
# regular SQLite tests
ds = DBInterface.execute(db, "SELECT name FROM sqlite_master WHERE type='table';") |> columntable
@test length(ds) == 1
@test keys(ds) == (:name,)
@test length(ds.name) == 11

results1 = SQLite.tables(db)
@test isequal(ds, results1)

results = DBInterface.execute(db, "SELECT * FROM Employee;") |> columntable
@test length(results) == 15
@test length(results[1]) == 8

DBInterface.execute(db, "create table temp as select * from album")
DBInterface.execute(db, "alter table temp add column colyear int")
DBInterface.execute(db, "update temp set colyear = 2014")
r = DBInterface.execute(db, "select * from temp limit 10") |> columntable
@test length(r) == 4 && length(r[1]) == 10
@test all(Bool[x == 2014 for x in r[4]])

DBInterface.execute(db, "alter table temp add column dates blob")
stmt = DBInterface.prepare(db, "update temp set dates = ?")
DBInterface.execute(stmt, (Date(2014,1,1),))

r = DBInterface.execute(db, "select * from temp limit 10") |> columntable
@test length(r) == 5 && length(r[1]) == 10
@test typeof(r[5][1]) == Date
@test all(Bool[x == Date(2014,1,1) for x in r[5]])
DBInterface.execute(db, "drop table temp")

rng = Dates.Date(2013):Dates.Day(1):Dates.Date(2013,1,5)
dt = (i=collect(rng), j=collect(rng))
tablename = dt |> SQLite.load!(db, "temp")
r = DBInterface.execute(db, "select * from $tablename") |> columntable
@test length(r) == 2 && length(r[1]) == 5
@test all([i for i in r[1]] .== collect(rng))
@test all([typeof(i) for i in r[1]] .== Dates.Date)
SQLite.drop!(db, "$tablename")

DBInterface.execute(db, "CREATE TABLE temp AS SELECT * FROM Album")
r = DBInterface.execute(db, "SELECT * FROM temp LIMIT ?", [3]) |> columntable
@test length(r) == 3 && length(r[1]) == 3
r = DBInterface.execute(db, "SELECT * FROM temp WHERE Title LIKE ?", ["%time%"]) |> columntable
@test r[1] == [76, 111, 187]
DBInterface.execute(db, "INSERT INTO temp VALUES (?1, ?3, ?2)", [0,0, "Test Album"])
r = DBInterface.execute(db, "SELECT * FROM temp WHERE AlbumId = 0") |> columntable
@test r[1][1] === 0
@test r[2][1] == "Test Album"
@test r[3][1] === 0
SQLite.drop!(db, "temp")

DBInterface.execute(db, "CREATE TABLE temp AS SELECT * FROM Album")
r = DBInterface.execute(db, "SELECT * FROM temp LIMIT :a", (a=3,)) |> columntable
@test length(r) == 3 && length(r[1]) == 3
r = DBInterface.execute(db, "SELECT * FROM temp WHERE Title LIKE @word", (word="%time%",)) |> columntable
@test r[1] == [76, 111, 187]
DBInterface.execute(db, "INSERT INTO temp VALUES (@lid, :title, \$rid)", (rid=0, lid=0, title="Test Album"))
r = DBInterface.execute(db, "SELECT * FROM temp WHERE AlbumId = 0") |> columntable
@test r[1][1] === 0
@test r[2][1] == "Test Album"
@test r[3][1] === 0
SQLite.drop!(db, "temp")

SQLite.register(db, SQLite.regexp, nargs=2, name="regexp")
r = DBInterface.execute(db, SQLite.@sr_str("SELECT LastName FROM Employee WHERE BirthDate REGEXP '^\\d{4}-08'")) |> columntable
@test r[1][1] == "Peacock"

@test_throws AssertionError SQLite.register(db, triple, nargs=186)
SQLite.register(db, triple, nargs=1)
r = DBInterface.execute(db, "SELECT triple(Total) FROM Invoice ORDER BY InvoiceId LIMIT 5") |> columntable
s = DBInterface.execute(db, "SELECT Total FROM Invoice ORDER BY InvoiceId LIMIT 5") |> columntable
for (i, j) in zip(r[1], s[1])
    @test abs(i - 3*j) < 0.02
end

SQLite.@register db add4
r = DBInterface.execute(db, "SELECT add4(AlbumId) FROM Album") |> columntable
s = DBInterface.execute(db, "SELECT AlbumId FROM Album") |> columntable
@test r[1][1] == s[1][1] + 4

SQLite.@register db mult
r = DBInterface.execute(db, "SELECT Milliseconds, Bytes FROM Track") |> columntable
s = DBInterface.execute(db, "SELECT mult(Milliseconds, Bytes) FROM Track") |> columntable
@test (r[1][1] * r[2][1]) == s[1][1]
t = DBInterface.execute(db, "SELECT mult(Milliseconds, Bytes, 3, 4) FROM Track") |> columntable
@test (r[1][1] * r[2][1] * 3 * 4) == t[1][1]

SQLite.@register db sin
u = DBInterface.execute(db, "select sin(milliseconds) from track limit 5") |> columntable
@test all(-1 .< convert(Vector{Float64},u[1]) .< 1)

SQLite.register(db, hypot; nargs=2, name="hypotenuse")
v = DBInterface.execute(db, "select hypotenuse(Milliseconds,bytes) from track limit 5") |> columntable
@test [round(Int,i) for i in v[1]] == [11175621,5521062,3997652,4339106,6301714]

SQLite.@register db str2arr
r = DBInterface.execute(db, "SELECT str2arr(LastName) FROM Employee LIMIT 2") |> columntable
@test r[1][2] == UInt8[0x45,0x64,0x77,0x61,0x72,0x64,0x73]

SQLite.@register db big
r = DBInterface.execute(db, "SELECT big(5)") |> columntable
@test r[1][1] == big(5)
@test typeof(r[1][1]) == BigInt

SQLite.register(db, 0, doublesum_step, doublesum_final, name="doublesum")
r = DBInterface.execute(db, "SELECT doublesum(UnitPrice) FROM Track") |> columntable
s = DBInterface.execute(db, "SELECT UnitPrice FROM Track") |> columntable
@test abs(r[1][1] - 2*sum(convert(Vector{Float64},s[1]))) < 0.02


SQLite.register(db, 0, mycount)
r = DBInterface.execute(db, "SELECT mycount(TrackId) FROM PlaylistTrack") |> columntable
s = DBInterface.execute(db, "SELECT count(TrackId) FROM PlaylistTrack") |> columntable
@test r[1][1] == s[1][1]

SQLite.register(db, big(0), bigsum)
r = DBInterface.execute(db, "SELECT bigsum(TrackId) FROM PlaylistTrack") |> columntable
s = DBInterface.execute(db, "SELECT TrackId FROM PlaylistTrack") |> columntable
@test r[1][1] == big(sum(convert(Vector{Int},s[1])))

DBInterface.execute(db, "CREATE TABLE points (x INT, y INT, z INT)")
DBInterface.execute(db, "INSERT INTO points VALUES (?, ?, ?)", (1, 2, 3))
DBInterface.execute(db, "INSERT INTO points VALUES (?, ?, ?)", (4, 5, 6))
DBInterface.execute(db, "INSERT INTO points VALUES (?, ?, ?)", (7, 8, 9))

SQLite.register(db, Point3D(0, 0, 0), sumpoint)
r = DBInterface.execute(db, "SELECT sumpoint(x, y, z) FROM points") |> columntable
@test r[1][1] == Point3D(12, 15, 18)
SQLite.drop!(db, "points")

db2 = DBInterface.connect(SQLite.DB)
DBInterface.execute(db2, "CREATE TABLE tab1 (r REAL, s INT)")

@test_throws SQLite.SQLiteException SQLite.drop!(db2, "nonexistant")
# should not throw anything
SQLite.drop!(db2, "nonexistant", ifexists=true)
# should drop "tab2"
SQLite.drop!(db2, "tab2", ifexists=true)
@test !in("tab2", SQLite.tables(db2)[1])

SQLite.drop!(db, "sqlite_stat1", ifexists=true)
tables = SQLite.tables(db)
@test length(tables[1]) == 11

#Test removeduplicates!
db = SQLite.DB() #In case the order of tests is changed
dt = (ints=Int64[1,1,2,2,3], strs=["A", "A", "B", "C", "C"])
tablename = dt |> SQLite.load!(db, "temp")
SQLite.removeduplicates!(db, "temp", ["ints", "strs"]) #New format
dt3 = DBInterface.execute(db, "Select * from temp") |> columntable
@test dt3[1][1] == 1
@test dt3[2][1] == "A"
@test dt3[1][2] == 2
@test dt3[2][2] == "B"
@test dt3[1][3] == 2
@test dt3[2][3] == "C"

# issue #104
db = SQLite.DB() #In case the order of tests is changed
DBInterface.execute(db, "CREATE TABLE IF NOT EXISTS tbl(a  INTEGER);")
stmt = DBInterface.prepare(db, "INSERT INTO tbl (a) VALUES (@a);")
SQLite.bind!(stmt, "@a", 1)
SQLite.clear!(stmt)

binddb = SQLite.DB()
DBInterface.execute(binddb, "CREATE TABLE temp (n NULL, i6 INT, f REAL, s TEXT, a BLOB)")
DBInterface.execute(binddb, "INSERT INTO temp VALUES (?1, ?2, ?3, ?4, ?5)", [missing, Int64(6), 6.4, "some text", b"bytearray"])
r = DBInterface.execute(binddb, "SELECT * FROM temp") |> columntable
@test isa(r[1][1], Missing)
@test isa(r[2][1], Int)
@test isa(r[3][1], Float64)
@test isa(r[4][1], AbstractString)
@test isa(r[5][1], Base.CodeUnits)

############################################

#test for #158
@test_throws SQLite.SQLiteException SQLite.DB("nonexistentdir/not_there.db")

#test for #180 (Query)
param = "Hello!"
query = DBInterface.execute(SQLite.DB(), "SELECT ?1 UNION ALL SELECT ?1", [param])
param = "x"
for row in query
    @test row[1] == "Hello!"
    GC.gc() # this must NOT garbage collect the "Hello!" bound value
end

db = SQLite.DB()
DBInterface.execute(db, "CREATE TABLE T (a TEXT, PRIMARY KEY (a))")

q = DBInterface.prepare(db, "INSERT INTO T VALUES(?)")
DBInterface.execute(q, ["a"])

SQLite.bind!(q, 1, "a")
@test_throws AssertionError DBInterface.execute(q)

@test SQLite.@OK SQLite.enable_load_extension(db)
show(db)
DBInterface.close!(db)

db = SQLite.DB()
DBInterface.execute(db, "CREATE TABLE T (x INT UNIQUE)")

q = DBInterface.prepare(db, "INSERT INTO T VALUES(?)")
SQLite.execute(q, (1,))
r = DBInterface.execute(db, "SELECT * FROM T") |> columntable
@test r[1][1] == 1

SQLite.execute(q, [2])
r = DBInterface.execute(db, "SELECT * FROM T") |> columntable
@test r[1][1] == 1
@test r[1][2] == 2

q = DBInterface.prepare(db, "INSERT INTO T VALUES(:x)")
SQLite.execute(q, Dict(:x => 3))
r = DBInterface.execute(db, "SELECT * FROM T") |> columntable
@test r[1][1] == 1
@test r[1][2] == 2
@test r[1][3] == 3


r = DBInterface.execute(db, strip("   SELECT * FROM T  ")) |> columntable
@test r[1][1] == 1
@test r[1][2] == 2
@test r[1][3] == 3

@test SQLite.esc_id(["1", "2", "3"]) == "\"1\",\"2\",\"3\""

SQLite.createindex!(db, "T", "x", "x_index"; unique=false)
inds = SQLite.indices(db)
@test inds.name[2] == "x"
SQLite.dropindex!(db, "x")
@test length(SQLite.indices(db).name) == 1

cols = SQLite.columns(db, "T")
@test cols.name[1] == "x"

@test SQLite.last_insert_rowid(db) == 3

r = DBInterface.execute(db, "SELECT * FROM T")
@test Tables.istable(r)
@test Tables.rowaccess(r)
@test Tables.rows(r) === r
@test Base.IteratorSize(typeof(r)) ==  Base.SizeUnknown()
@test eltype(r) == SQLite.Row
row = first(r)
SQLite.reset!(r)
row2 = first(r)
@test row[:x] == row2[:x]
@test propertynames(row) == [:x]
@test DBInterface.lastrowid(r) == 3

r = DBInterface.execute(db, "SELECT * FROM T") |> columntable
SQLite.load!(nothing, Tables.rows(r), db, "T2", "T2", true)
r2 = DBInterface.execute(db, "SELECT * FROM T2") |> columntable
@test r == r2

# throw informative error on duplicate column names #193
@test_throws ErrorException SQLite.load!((a=[1,2,3], A=[1,2,3]), db)

end # basics @testset


# Test set for lockretry macro
@testset "lockretry" begin

addprocs(2)

@everywhere using SQLite
@everywhere LOCKDBFILE = joinpath(tempdir(), "lockretry.sqlite")

# Initialise the database used for lock testing
function initlockdb()
  local db::SQLite.DB = SQLite.DB(LOCKDBFILE)
  local createtablesql::String = "CREATE TABLE 'numbers' ('value' INTEGER)"
  DBInterface.execute(db, createtablesql)

  DBInterface.execute(db, "BEGIN TRANSACTION")

  local numbersql::String = "INSERT INTO numbers (value) VALUES ($(rand(1:10000)))"
  for i in 1:1000000
    DBInterface.execute(db, numbersql)
  end

  DBInterface.execute(db, "COMMIT")
end

# Perform a long-running transaction
@everywhere function longupdate()
  local db::SQLite.DB = SQLite.DB(LOCKDBFILE)

  DBInterface.execute(db, "BEGIN TRANSACTION")

  for i in 1:50
    DBInterface.execute(db, "UPDATE numbers SET value = $(rand(1:10000))")
  end

  DBInterface.execute(db, "COMMIT")
end

# Perform a short transaction that can time out if the
# database is locked for too long
#
# Returns true if the update succeeded, or false if it timed out
@everywhere function shortupdate(timeout::Number)::Bool
  local result::Bool = true

  local db::SQLite.DB = SQLite.DB(LOCKDBFILE)

  try
    @SQLite.lockretry timeout DBInterface.execute(db, "UPDATE numbers SET value = $(rand(1:10000))")
  catch e
    result = false
  end

  return result
end

# Run a lock test with a given timeout.
function runlocktest(timeout::Number)::Bool

  # Kick off the long update
  longfuture = @spawnat 2 longupdate()
  sleep(0.5)

  # Attempt to run the short update
  shortfuture = @spawnat 3 shortupdate(timeout)

  # Get the result of the short update
  local testresult::Bool = fetch(shortfuture)

  # Wait for the long update to finish
  fetch(longfuture)

  return testresult
end

# Delete the DB file if it exists
if isfile(LOCKDBFILE)
  rm(LOCKDBFILE)
end

# Initialise the test database
initlockdb()

@test runlocktest(1) === false # Will time out
@test runlocktest(0.75) === false # Decimal number (will time out)
@test runlocktest(60) === true # Long timeout passes
@test runlocktest(0) === true # Indefinite timeout passes
@test runlocktest(-1) === true # Negative (indefinite) timeout passes

# Clean up
if isfile(LOCKDBFILE)
  rm(LOCKDBFILE)
end

end # lockretry @testset
