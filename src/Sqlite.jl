module Sqlite
 
using DataFrames

export sqlitedb 

include("Sqlite_consts.jl")
include("Sqlite_api.jl")

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

typealias TableInput Union(DataFrame,String)

const null_resultset = DataFrame(0)
const null_SqliteDB = SqliteDB("",C_NULL,null_resultset)
sqlitedb = null_SqliteDB #Create default connection = null

#Core Functions
function connect(file::String)
	global sqlitedb
	handle = Array(Ptr{Void},1)
	if @FAILED sqlite3_open(file,handle)
		error("[sqlite]: Error opening $file; $(bytestring(sqlite3_errmsg(conn.handle)))")
	else
		return (sqlitedb = SqliteDB(file,handle[1],null_resultset))
	end
end
function internal_query(conn::SqliteDB,q::String,finalize::Bool=true,stepped::Bool=true)
	stmt = Array(Ptr{Void},1)
	if @FAILED sqlite3_prepare_v2(conn.handle,utf8(q),stmt,[C_NULL])
        ret = bytestring(sqlite3_errmsg(conn.handle))
        internal_query(conn,"COMMIT")
        internal_query(conn,"PRAGMA synchronous = ON")
		error("[sqlite]: $ret")
	end	
	stmt = stmt[1]
    r = 0
    if stepped
	   r = sqlite3_step(stmt)
    end
	if finalize
		sqlite3_finalize(stmt)
		return C_NULL, 0
	else
		return stmt, r
	end
end
function query(q::String,conn::SqliteDB=sqlitedb)
	conn == null_SqliteDB && error("[sqlite]: A valid SqliteDB was not specified (and no valid default SqliteDB exists)")
	stmt, r = Sqlite.internal_query(conn,q,false)
	r == SQLITE_DONE && return DataFrame("No Rows Returned")
	#get resultset metadata: column count, column types, and column names
	ncols = Sqlite.sqlite3_column_count(stmt)
	colnames = Array(ASCIIString,ncols)
	resultset = Array(Any,ncols)
	check = 0
	for i = 1:ncols
		colnames[i] = bytestring(Sqlite.sqlite3_column_name(stmt,i-1))
		t = Sqlite.sqlite3_column_type(stmt,i-1)
		if t == Sqlite.SQLITE3_TEXT
			resultset[i] = DataArray(String,0)
			check += 1
		elseif t == Sqlite.SQLITE_FLOAT
			resultset[i] = DataArray(Float64,0)
			check += 1
		elseif t == Sqlite.SQLITE_INTEGER
			resultset[i] = DataArray(WORD_SIZE == 64 ? Int64 : Int32,0)
			check += 1
		else
			resultset[i] = DataArray(Any,0)
		end
	end
	#retrieve resultset
	while true
		for i = 1:ncols
			t = sqlite3_column_type(stmt,i-1) 
			if t == SQLITE3_TEXT
				r = bytestring( sqlite3_column_text(stmt,i-1) )
			elseif t == SQLITE_FLOAT
				r = sqlite3_column_double(stmt,i-1)
			elseif t == SQLITE_INTEGER
				r = WORD_SIZE == 64 ? sqlite3_column_int64(stmt,i-1) : sqlite3_column_int(stmt,i-1)
			else
				r = NA
			end
			push!(resultset[i],r)
		end
		sqlite3_step(stmt) == SQLITE_DONE && break
	end
    #this is for columns we couldn't get the type for earlier (NULL in row 1); should be the exception
	if check != ncols
        nrows = length(resultset[1])
		for i = 1:ncols
			if isna(resultset[i][1])
                d = resultset[i]
				for j = 2:nrows
                    if !isna(d[j])
                        t = typeof(d[j])
                        da = DataArray(t,nrows)
                        for k = 1:nrows
                            da[k] = d[k]
                        end
                        resultset[i] = da
                        break
                    end
                end
			end
		end
	end
	sqlite3_finalize(stmt)
	return (conn.resultset = DataFrame(resultset,Index(colnames)))
end
function createtable(input::TableInput,conn::SqliteDB=sqlitedb;name::String="")
	conn == null_SqliteDB && error("[sqlite]: A valid SqliteDB was not specified (and no valid default SqliteDB exists)")
    #these 2 calls are for performance
    internal_query(conn,"PRAGMA synchronous = OFF")
    
    if typeof(input) == DataFrame
        r = df2table(input,conn,name)
    else
        r = 0 # dlm2table(input,conn,name)
    end
    internal_query(conn,"PRAGMA synchronous = ON")
    return r
end
function df2table(df::DataFrame,conn::SqliteDB,name::String)
	#get column names and types
	ncols = length(df)
	colnames = join(df.colindex.names,',')
    #get df name for table name if not provided
    dfname = name
    if dfname == ""
        for sym in names(Main)
            if string(:(df)) == string(sym)
                dfname = string(sym)
            end
        end
    end
    #should we loop through column types to specify in create table statement?
    internal_query(conn,"create table $dfname ($colnames)")
    internal_query(conn,"BEGIN TRANSACTION")
	#prepare insert table with parameters for column values
	params = chop(repeat("?,",ncols))
	stmt, r = internal_query(conn,"insert into $dfname values ($params)",false,false)
    sqlite3_reset(stmt)
	#bind, step, reset loop for inserting values
	for row = 1:nrow(df)
		for col = 1:ncols
            d = df[row,col]
            t = typeof(d)
            if t <: FloatingPoint
                Sqlite.sqlite3_bind_double(stmt,col,d)
            elseif t <: Integer
                WORD_SIZE == 64 ? sqlite3_bind_int64(stmt,col,d) : sqlite3_bind_int(stmt,col,d)
            elseif <: NAtype
                sqlite3_bind_null(stmt,col)
            else
                sqlite3_bind_text(stmt,col,string(d),length(string(d)),C_NULL)
            end
		end
		sqlite3_step(stmt)
		sqlite3_reset(stmt)
	end
	sqlite3_finalize(stmt)
    internal_query(conn,"COMMIT")
	return
end
function droptable(table::String,conn::SqliteDB=sqlitedb)
	conn == null_SqliteDB && error("[sqlite]: A valid SqliteDB was not specified (and no valid default SqliteDB exists)")
	internal_query(conn,"DROP TABLE $table")
	internal_query(conn,"VACUUM")
	return
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