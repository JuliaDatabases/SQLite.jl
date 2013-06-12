# include("C:/Users/karbarcca/Google Drive/Dropbox/Dropbox/GitHub/Sqlite.jl/src/Sqlite.jl")
co = Sqlite.connect(Pkg.dir() * "\\Sqlite\\test\\Chinook_Sqlite.sqlite")

df = Sqlite.query("SELECT * FROM Employee;")
Sqlite.createtable(df; name="test")
Sqlite.query("select * from test")
Sqlite.query("drop table test")

Sqlite.query("SELECT * FROM sqlite_master WHERE type='table' ORDER BY name;")
Sqlite.query("SELECT * FROM Album;")
Sqlite.query("SELECT *
	FROM Artist a 
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId 
	ORDER BY name;")

using DataFrames
df2 = DataFrame(ones(1000000,5))
@time Sqlite.createtable(df2;name="test2")
Sqlite.query("drop table test2")

using DataFrames
using Sqlite
df3 = DataFrame(ones(1000,5))
sqldf("select * from df3")