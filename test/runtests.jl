using DBI
using SQLite

for testfile in ["dbi.jl"]
	include(testfile)
end
