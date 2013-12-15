using SQLite
co = SQLite.connect(Pkg.dir() * "/SQLite/test/Chinook_Sqlite.sqlite")

df = query("SELECT * FROM Employee;")
createtable(df; name="test")
query("select * from test")
droptable("test")

query("SELECT * FROM sqlite_master WHERE type='table' ORDER BY name;")
query("SELECT * FROM Album;")
query("SELECT a.*, b.AlbumId 
	FROM Artist a 
	LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId 
	ORDER BY name;")

using DataFrames
df2 = DataFrame(ones(1000000,5))
@time createtable(df2;name="test2")
@time query("SELECT * FROM test2;")
droptable("test2")

df3 = DataFrame(ones(1000,5))
@time sqldf("select * from df3")


@time readdlmsql(Pkg.dir() * "/SQLite/test/sales.csv";sql="select * from sales",name="sales")
@time query("select typeof(f_year), typeof(base_lines), typeof(dollars) from sales")
droptable("sales")