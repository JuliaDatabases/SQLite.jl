
using SQLite
co = SQLite.connect(Pkg.dir() * "/SQLite/test/Chinook_SQLite.sqlite")

df = SQLite.query("SELECT * FROM Employee;")
SQLite.createtable(df; name="test")
SQLite.query("select * from test")
SQLite.query("drop table test")

SQLite.query("SELECT * FROM sqlite_master WHERE type='table' ORDER BY name;")
SQLite.query("SELECT * FROM Album;")
SQLite.query("SELECT * 
	FROM Artist a 
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId 
	ORDER BY name;")

using DataFrames
df2 = DataFrame(ones(1000000,5))
@time SQLite.createtable(df2;name="test2")
@time SQLite.query("SELECT * FROM test2;")
SQLite.droptable("test2")

using DataFrames
df3 = DataFrame(ones(1000,5))
sqldf("select * from df3")

# SQLite.droptable("sales")
@time SQLite.readdlmsql(Pkg.dir() * "/SQLite/test/sales.csv";sql="select * from sales",name="sales")

@time SQLite.query("select typeof(f_year), typeof(base_lines), typeof(dollars) from sales")