include("C:/Users/karbarcca/Google Drive/Dropbox/Dropbox/GitHub/sqlite.jl/sqlite.jl")
co = sqlite.connect("test/Chinook_Sqlite.sqlite")

df = sqlite.query("SELECT * FROM Employee;")
sqlite.createtable(df; name="test")
sqlite.query("select * from test")
sqlite.query("drop table test")

sqlite.query("SELECT * FROM sqlite_master WHERE type='table' ORDER BY name;")
sqlite.query("SELECT * FROM Album;")
sqlite.query("SELECT *
	FROM Artist a 
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId 
	ORDER BY name;")

using DataFrames
df2 = DataFrame(ones(1000000,5))
@time sqlite.createtable(df2;name="test2")
sqlite.query("drop table test2")

using DataFrames
using sqlite
df3 = DataFrame(ones(1000,5))
sqldf("select * from df3")
#To Do:
 #finish other functions, csv2table is beefiest (others are just combo functions)
 #create repo/package