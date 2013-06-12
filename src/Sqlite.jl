module Sqlite
 
using DataFrames

export sqlitedb #, sqlite3_column_int64, sqlite3_column_text, sqlite3_column_double, FUNCS, SQL2Julia, sqlite3_column_name, sqlite3_column_type, sqlite3_prepare_v2, sqlite3_step, sqlite3_column_count, SQLITE_NULL, sqlite3_column_int, SQLITE_ROW, SQLITE_DONE, sqlite3_reset, sqlite3_finalize

include("sqlite_consts.jl")
include("sqlite_api.jl")

type SqliteDB
	file::String
	handle::Ptr{Void}
	resultset::Any
end
function show(io::IO,db::SqliteDB)
    if db == null_SqliteDB
        print(io,"Null sqlite connection")
    else
        println(io,"sqlite connection")
        println(io,"-----------------")
        println(io,"File: $(db.file)")
        println(io,"Connection Handle: $(db.handle)")
        if isequal(db.resultset,null_resultset)
			print("Contains resultset? No")
		else
			print("Contains resultset(s)? Yes (access by referencing the resultset field (e.g. db.resultset))")
		end
    end 
end

const null_resultset = DataFrame(0)
const null_SqliteDB = SqliteDB("",C_NULL,null_resultset)
sqlitedb = null_SqliteDB #Create default connection = null
ret = "" #For returning readable error codes

#Core Functions
function connect(file::String)
	global sqlitedb
	handle = Array(Ptr{Void},1)
	if @FAILED sqlite3_open(file,handle)
		error("[sqlite]: $ret; Error opening $file")
	else
		return (sqlitedb = SqliteDB(file,handle[1],null_resultset))
	end
end
function query(conn::SqliteDB=sqlitedb,q::String)
	if conn == null_SqliteDB
		error("[sqlite]: A valid SqliteDB was not specified (and no valid default SqliteDB exists)")
	end
	stmt = Array(Ptr{Void},1)
	# unused = Array(Ptr{Void},1)
	if @FAILED sqlite3_prepare_v2(conn.handle,utf8(q),stmt,[C_NULL])
		println("$ret: $(bytestring(sqlite3_errmsg(conn.handle)))")
		error("[sqlite]: Error preparing query")
	end	
	stmt = stmt[1]
	sqlite3_step(stmt) == SQLITE_DONE && return
	cols = sqlite3_column_count(stmt)
	funcs = Array(Function,cols)
	colnames = Array(ASCIIString,cols)
	resultset = Array(Any,cols)
	check = zeros(Int,cols)
	while sum(check) <= cols
		for i = 1:cols
			if check[i] == 0
				t = sqlite3_column_type(stmt,i-1)
				if t != SQLITE_NULL	
					coltype = get(SQL2Julia,t,String)			# Retrieves the Julia mapped type
					resultset[i] = DataArray(coltype,0)
					func = get(FUNCS,t,sqlite3_column_text) 	# Retrieves the type-correct retrieval function
					func == sqlite3_column_int && WORD_SIZE == 64 && (func = sqlite3_column_int64)
					funcs[i] = func
					colnames[i] = bytestring(sqlite3_column_name(stmt,i-1))
					check[i] = 1
				end
			end
		end
		sqlite3_step(stmt) != SQLITE_ROW && break
	end
	sqlite3_reset(stmt)
	while sqlite3_step(stmt) != SQLITE_DONE
		for i = 1:cols
			if sqlite3_column_type(stmt,i-1) == SQLITE_NULL
				r = NA
			else
				r = invoke(funcs[i],(Ptr{Void},Int),stmt,i-1)
				if typeof(r) == Ptr{Uint8} 
					r = bytestring(r)
				end
			end
			push!(resultset[i],r)
		end
	end
	sqlite3_finalize(stmt)
	return (conn.resultset = DataFrame(resultset,Index(colnames)))
end
function createtable(conn::SqliteDB=sqlitedb,df::DataFrame;name::String="")
	if conn == null_SqliteDB
		error("[sqlite]: A valid SqliteDB was not specified (and no valid default SqliteDB exists)")
	end
	sqlite3_prepare_v2(conn.handle,utf8("PRAGMA synchronous = OFF"),Array(Ptr{Void},1),[C_NULL])
	stmt = Array(Ptr{Void},1)
	sqlite3_prepare_v2(conn.handle,utf8("BEGIN TRANSACTION"),stmt,[C_NULL])
	sqlite3_step(stmt[1])
	sqlite3_finalize(stmt[1])
	#get column names and types
	ncols = length(df)
	columns = df.colindex.names
	bindfuncs = ref(Function)
	bindtype = ref(DataType)
	for i = 1:ncols
		jultype = eltype(df[i])
		if jultype <: FloatingPoint
			sqlitetype = "REAL"
			push!(bindfuncs,sqlite3_bind_double)
			push!(bindtype,Float64)
		elseif jultype <: Integer
			sqlitetype = "INTEGER"
			if WORD_SIZE == 64
				push!(bindfuncs,sqlite3_bind_int64)
				push!(bindtype,Int64)
			else
				push!(bindfuncs,sqlite3_bind_int)
				push!(bindtype,Int32)
			end
		else
			sqlitetype = "TEXT"
			push!(bindfuncs,sqlite3_bind_text)
			push!(bindtype,String)
		end
	end
	columns = join(columns,',')
	#get df name for table name if not provided
	dfname = name
	if dfname == ""
		for sym in names(Main)
			if is(eval(sym),df)
				dfname = string(sym)
			end
		end
	end
	q = "create table $dfname ($columns)"
	stmt = Array(Ptr{Void},1)
	# unused = Array(Ptr{Void},1)
	if @FAILED sqlite3_prepare_v2(conn.handle,utf8(q),stmt,[C_NULL])
		println("$ret: $(bytestring(sqlite3_errmsg(conn.handle)))")
		error("[sqlite]: Error preparing 'create table' statement")
	end	
	stmt = stmt[1]
	sqlite3_step(stmt)
	#prepare insert table with parameters for column values
	params = chop(repeat("?,",ncols))
	q = "insert into $dfname values ($params)"
	stmt = Array(Ptr{Void},1)
	# unused = Array(Ptr{Void},1)
	if @FAILED sqlite3_prepare_v2(conn.handle,utf8(q),stmt,[C_NULL])
		println("$ret: $(bytestring(sqlite3_errmsg(conn.handle)))")
		error("[sqlite]: Error preparing 'create table' statement")
	end	
	stmt = stmt[1]
	#bind, step, reset loop for inserting values
	for row = 1:nrow(df)
		for col = 1:ncols
			if isna(df[row,col])
				sqlite3_bind_null(stmt,col-1)
			elseif bindfuncs[col] == sqlite3_bind_text
				value = df[row,col]
				invoke(bindfuncs[col],(Ptr{Void},Int,String,Int,Ptr{Void}),stmt,col,value,length(value),C_NULL)
			else
				invoke(bindfuncs[col],(Ptr{Void},Int,bindtype[col]),stmt,col,df[row,col])
			end
		end
		sqlite3_step(stmt)
		sqlite3_reset(stmt)
	end
	sqlite3_finalize(stmt)
	stmt = Array(Ptr{Void},1)
	sqlite3_prepare_v2(conn.handle,utf8("COMMIT"),stmt,[C_NULL])
	sqlite3_step(stmt[1])
	sqlite3_finalize(stmt[1])
	sqlite3_prepare_v2(conn.handle,utf8("PRAGMA synchronous = ON"),Array(Ptr{Void},1),[C_NULL])
	return println("Table '$dfname' created.")
end
function droptable(conn::SqliteDB=sqlitedb,table::String)
	if conn == null_SqliteDB
		error("[sqlite]: A valid SqliteDB was not specified (and no valid default SqliteDB exists)")
	end
	stmt = Array(Ptr{Void},1)
	sqlite3_prepare_v2(conn.handle,utf8("DROP TABLE $table"),stmt,[C_NULL])
	sqlite3_step(stmt[1])
	sqlite3_finalize(stmt[1])
	return 0
end
#read raw file direct to sqlite table
# function csv2table()

# end
#read raw file to sqlite table (call csv2table), then run sql statement on table to return df (call to query)
# function readcsvsql()

# end
end #sqlite module

function sqldf(q::String)
	handle = Array(Ptr{Void},1)
	file = "__temp__"
	Sqlite.sqlite3_open(file,handle)
	conn = Sqlite.SqliteDB(file,handle[1],Sqlite.null_resultset)
	#todo: do we need to change column names at all?
	tables = ref(String)
	#find tablenames
	for i in eachmatch(r"(?<=\bfrom\b\s)\w+",q)
		push!(tables,i.match)
	end
	#find join tables, if any
	for i in eachmatch(r"(?<=\bjoin\b\s)\w+",q)
		push!(tables,i.match)
	end
	#make sure all dfs exist
	check = 0
	for df in tables, sym in names(Main)
		if string(sym) == df
			check += 1
		end
	end
	check != length(tables) && error("[sqlite]: DataFrames specified in query were not found")
	for df in tables
		d = eval(symbol(df))
		Sqlite.createtable(d,conn;name=df)
	end
	result = Sqlite.query(q,conn)
	for df in tables
		Sqlite.droptable(df,conn)
	end
	Sqlite.sqlite3_close_v2(conn.handle)
	return result
end