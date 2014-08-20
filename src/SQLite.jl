module SQLite
 
using DataFrames
using DataArrays

export sqlitedb, readdlmsql, query, createtable, droptable

import Base: show, close

include("SQLite_consts.jl")
include("SQLite_api.jl")

type SQLiteDB
	file::String
	handle::Ptr{Void}
	resultset::Any
end
function show(io::IO,db::SQLiteDB)
    if db.handle == C_NULL
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

const null_resultset = DataFrame({})
const null_SQLiteDB = SQLiteDB("",C_NULL,null_resultset)
sqlitedb = null_SQLiteDB #Create default connection = null
const INTrx = r"^\d+$"
const STRINGrx = r"[^eE0-9\.\-\+]"i
const FLOATrx = r"^[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][+-]?[0-9]+)?$"

#Core Functions
function connect(file::String)
	global sqlitedb
	handle = Array(Ptr{Void},1)
	if @FAILED sqlite3_open(file,handle)
		error("[sqlite]: Error opening $file; $(bytestring(sqlite3_errmsg(sqlitedb.handle)))")
	else
		return (sqlitedb = SQLiteDB(file,handle[1],null_resultset))
	end
end
function close(conn::SQLiteDB)
	# if is fine to close when conn.handle is NULL (as stated in sqlite3's document)
	if @FAILED sqlite3_close(conn.handle)
		error("[sqlite]: Error closing $(conn.file); $(bytestring(sqlite3_errmsg(conn.handle)))")
	else
		conn.file = ""
		conn.handle = C_NULL
		conn.resultset = null_resultset
	end
end
function internal_query(conn::SQLiteDB,q::String,finalize::Bool=true,stepped::Bool=true)
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
function query(q::String,conn::SQLiteDB=sqlitedb)
	conn == null_SQLiteDB && error("[sqlite]: A valid SQLiteDB was not specified (and no valid default SQLiteDB exists)")
	stmt, status = SQLite.internal_query(conn,q,false)
	#get resultset metadata: column count, column types, and column names
	ncols = SQLite.sqlite3_column_count(stmt)
	colnames = Array(Symbol,ncols)
	resultset = Array(Any,ncols)
	check = 0
	for i = 1:ncols
		colnames[i] = DataFrames.identifier(bytestring(SQLite.sqlite3_column_name(stmt,i-1)))
		t = SQLite.sqlite3_column_type(stmt,i-1)
		if t == SQLite.SQLITE3_TEXT # Either a blob or text See issue #28
			resultset[i] = DataArray(String,0)
			check += 1
		elseif t == SQLite.SQLITE_FLOAT
			resultset[i] = DataArray(Float64,0)
			check += 1
		elseif t == SQLite.SQLITE_INTEGER
			resultset[i] = DataArray(WORD_SIZE == 64 ? Int64 : Int32,0)
			check += 1
		else
			resultset[i] = DataArray(Any,0)
		end
	end
	#retrieve resultset
	while status != SQLITE_DONE
		for i = 1:ncols
			t = SQLite.sqlite3_column_type(stmt,i-1) 
			if t == SQLITE3_TEXT
				len = sqlite3_column_bytes(stmt,i-1)
				if eltype(resultset[i]) == String # Try interpreting as string
				    r = bytestring( sqlite3_column_text(stmt,i-1) )
				    if length(r) != len # Convert and try again
					resultset[i] = convert(Vector{Vector{Uint8}}, resultset[i])
				    end
				end
				if eltype(resultset[i]) == Vector{Uint8}
				    p = convert(Ptr{Uint8}, sqlite3_column_blob(stmt,i-1))
				    r = copy(pointer_to_array(p,len))
				end
			elseif t == SQLITE_FLOAT
				r = sqlite3_column_double(stmt,i-1)
			elseif t == SQLITE_INTEGER
				r = WORD_SIZE == 64 ? sqlite3_column_int64(stmt,i-1) : sqlite3_column_int(stmt,i-1)
			else
				r = NA
			end
			push!(resultset[i],r)
		end
		status = sqlite3_step(stmt)
	end
    #this is for columns we couldn't get the type for earlier (NULL in row 1); should be the exception
	if check != ncols
        nrows = length(resultset[1])
		for i = 1:ncols
			if nrows > 0 && isna(resultset[i][1])
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
	return (conn.resultset = DataFrame(resultset,colnames))
end
function createtable(input::TableInput,conn::SQLiteDB=sqlitedb;name::String="",delim::Char='\0',header::Bool=true,types::Array{DataType,1}=DataType[],infer::Bool=true)
	conn == null_SQLiteDB && error("[sqlite]: A valid SQLiteDB was not specified (and no valid default SQLiteDB exists)")
    #these 2 calls are for performance
    internal_query(conn,"PRAGMA synchronous = OFF")
    
    if typeof(input) == DataFrame
        r = df2table(input,conn,name)
    else
        r = dlm2table(input,conn,name,delim,header,types,infer)
    end
    internal_query(conn,"PRAGMA synchronous = ON")
    return r
end
function df2table(df::DataFrame,conn::SQLiteDB,name::String)
    #get df name for table name if not provided
    dfname = name
    if dfname == ""
        for sym in names(Main)
            if string(:(df)) == string(sym)
                dfname = string(sym)
            end
        end
    end
    # build column specifications
    ncols = length(df)
    colnames = map(string, df.colindex.names)
    for col = 1 : ncols
        t = eltype(df[col])
        if t <: FloatingPoint
            colnames[col] *= " REAL"
        elseif t <: Integer
            colnames[col] *= " INT"
        elseif t <: String
            colnames[col] *= " TEXT"
        end
    end
    colspec = join(colnames, ",")
    # create table
    internal_query(conn,"create table $dfname ($colspec)")
    internal_query(conn,"BEGIN TRANSACTION")
	#prepare insert table with parameters for column values
	params = chop(repeat("?,",ncols))
	stmt, r = internal_query(conn,"insert into $dfname values ($params)",false,false)
	#bind, step, reset loop for inserting values
	for row = 1:nrow(df)
		for col = 1:ncols
            d = df[row,col]
            t = typeof(d)
            if t <: FloatingPoint
                SQLite.sqlite3_bind_double(stmt,col,d)
            elseif t <: Integer
                WORD_SIZE == 64 ? sqlite3_bind_int64(stmt,col,d) : sqlite3_bind_int(stmt,col,d)
            elseif t <: NAtype
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
function droptable(table::String,conn::SQLiteDB=sqlitedb)
	conn == null_SQLiteDB && error("[sqlite]: A valid SQLiteDB was not specified (and no valid default SQLiteDB exists)")
	internal_query(conn,"DROP TABLE $table")
	internal_query(conn,"VACUUM")
	return
end
#read raw file direct to sqlite table
function dlm2table(file::String,conn::SQLiteDB,name::String,delim::Char,header::Bool,types::Array{DataType,1},infer::Bool)
    #determine tablename and delimiter
    tablename = name
    if tablename == ""
        tablename = match(r"\w+(?=\.)",file).match
    end
    delimiter = delim
    if delimiter == '\0'
        delimiter = ismatch(r"csv$", file) ? ',' : ismatch(r"tsv$", file) ? '\t' : ismatch(r"wsv$", file) ? ' ' : error("Unable to determine separator used in $file")
    end
    #get column names/types: colnames, ncols, coltypes
    f = open(file)
    firstrow = split(chomp(readline(f)),delimiter)
    ncols = length(firstrow)
    if header
        colnames = firstrow
    else
        colnames = String["x$i" for i = 1:ncols]
        seekstart(f)
    end
    if infer
	    coltypes = Array(DataType,ncols)
	    check = falses(ncols)
	    for r in eachline(f)
			row = split_quoted(chomp(r),delimiter)
	        for i = 1:ncols
	        	if !check[i]
		        	if row[i] == "" #null/missing value
		        		continue
		        	elseif ismatch(INTrx,row[i]) #match a plain integer first
		        		colnames[i] *= " INT"; check[i] = true
		        	elseif ismatch(STRINGrx,row[i]) #then check if it's stringy
						colnames[i] *= " TEXT"; check[i] = true
		        	elseif ismatch(FLOATrx,row[i]) #if it's not integer or string, check if it's a float
						colnames[i] *= " REAL"; check[i] = true
		        	else #if it's still not a float, just make it a string
						colnames[i] *= " TEXT"; check[i] = true
		        	end
		        end
	    	end
	    	sum(check) == ncols && break
	    end
	    if sum(check) < ncols
	    	for i = 1:ncols
	    		if !coltypes[i]
	    			coltypes[i] = String
	    		end
	    	end
    	end
    	seekstart(f)
    	header && readline(f)
	elseif length(types) > 0
		if eltype(types) <: String
			for i = 1:ncols
				colnames[i] *= " " * types[i]
			end
		else
			for i = 1:ncols
				colnames[i] *= types[i] <: Integer ? " INT" : types[i] <: FloatingPoint ? " REAL" : " TEXT"
			end
		end
	end
	colnames = join(colnames,',')
    internal_query(conn,"create table $tablename ($colnames)")
    internal_query(conn,"BEGIN TRANSACTION")
    #prepare insert table with parameters for column values
    params = chop(repeat("?,",ncols))
    stmt, r = internal_query(conn,"insert into $tablename values ($params)",false,false)
    #bind, step, reset loop for inserting values
    for r in eachline(f)
		row = SQLite.split_quoted(chomp(r),delimiter)
	    for col = 1:ncols
	    	d = row[col]
			SQLite.sqlite3_bind_text(stmt,col,d,length(d),C_NULL)
	    end
    	SQLite.sqlite3_step(stmt)
    	SQLite.sqlite3_reset(stmt)
	end
    sqlite3_finalize(stmt)
    internal_query(conn,"COMMIT")
    close(f)
    return
end
#read raw file to sqlite table (call dlm2table), then run sql statement on table to return df (call to query)
function readdlmsql(input::String,conn::SQLiteDB=sqlitedb;sql::String="select * from file",name::String="file",delim::Char='\0',header::Bool=true,types::Array{DataType,1}=DataType[],infer::Bool=true)
	if conn == null_SQLiteDB
		handle = Array(Ptr{Void},1)
		file = tempname()
		SQLite.sqlite3_open(file,handle)
		conn = SQLite.SQLiteDB(file,handle[1],SQLite.null_resultset)
	end
	createtable(input,conn;name=name,delim=delim,header=header,types=types,infer=infer)
	return query(sql,conn)
end
function search_quoted(s::String, c::Char, i::Integer)
    if isempty(c)
        return 1 <= i <= endof(s)+1 ? i :
               i == endof(s)+2      ? 0 :
               error(BoundsError)
    end
    if i < 1 error(BoundsError) end
    i = nextind(s,i-1)
    while !done(s,i)
        d, j = next(s,i)
        if d == '"'
        	i = j
        	d, j = next(s,i)
        	while d != '"'
				i = j
        		d, j = next(s,i)
        	end
        end
        if d in c
            return i
        end
        i = j
    end
    return 0
end
search_quoted(s::String, c::Char) = search_quoted(s,c,start(s))
function split_quoted(str::String, splitter, limit::Integer, keep_empty::Bool)
    strs = String[]
    i = start(str)
    n = endof(str)
    r = search_quoted(str,splitter,i)
    j, k = first(r), last(r)+1
    while 0 < j <= n && length(strs) != limit-1
        if i < k
            if keep_empty || i < j
                push!(strs, str[i:j-1])
            end
            i = k
        end
        if k <= j; k = nextind(str,j) end
        r = search_quoted(str,splitter,k)
        j, k = first(r), last(r)+1
    end
    if keep_empty || !done(str,i)
	push!(strs, str[i:end])
    end
    return strs
end
split_quoted(s::String, spl, n::Integer) = split_quoted(s, spl, n, true)
split_quoted(s::String, spl, keep::Bool) = split_quoted(s, spl, 0, keep)
split_quoted(s::String, spl)             = split_quoted(s, spl, 0, true)
end #sqlite module

function sqldf(q::String)
	handle = Array(Ptr{Void},1)
	file = tempname()
	SQLite.sqlite3_open(file,handle)
	conn = SQLite.SQLiteDB(file,handle[1],SQLite.null_resultset)
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
		SQLite.createtable(d,conn;name=df)
	end
	result = SQLite.query(q,conn)
	for df in tables
		SQLite.droptable(df,conn)
	end
	SQLite.sqlite3_close_v2(conn.handle)
	return result
end
