SQLite.jl
=======

A Julia interface to the SQLite library and support for operations on DataFrames

Installation through the Julia package manager:
```julia
julia> Pkg.init()        # Creates julia package repository (only runs once for all packages)
julia> Pkg.add("SQLite")   # Creates the SQLite repo folder and downloads the SQLite package + dependancy (if needed)
julia> using SQLite        # Loads the SQLite module for use (needs to be run with each new Julia instance)
```

Testing status: [![Build Status](https://travis-ci.org/quinnj/SQLite.jl.png)](https://travis-ci.org/quinnj/SQLite.jl)


## Package Documentation

#### Functions
* `SQLite.connect(file::String)`

  `SQLite.connect` requires the `file` string argument as the name of either a pre-defined SQLite database to be opened, or if the database doesn't exist, one will be created.

  `SQLite.connect` returns a `SQLiteDB` type which contains basic information
about the connection and SQLite handle pointers.

  `SQLite.connect` can be used by storing the `Connection` type in
a variable to be able to close or facilitate handling multiple
databases like so:
  ```julia
  co = SQLite.connect("mydatasource")
  ```
  But it's unneccesary to store the `SQLiteDB`, as an exported
`sqlitedb` variable holds the most recently created `SQLiteDB` type and other
SQLite functions (i.e. `query`) will use it by default in the absence of a specified connection.

* `query(querystring::String,conn::SQLiteDB=sqlitedb)`
  
  If a connection type isn't specified as the first positional argument, the query will be executed against
the default connection (stored in the exported variable `sqlitedb` if you'd like to
inspect).

  Once the query is executed, the resultset is stored in a
`DataFrame` by default.

  For the general user, a simple `query(querystring)` is enough to return a single resultset in a DataFrame. Results are stored in the passed SQLiteDB type's resultset field. (i.e. `sqlitedb.resultset`). Results are stored by default to avoid immediate garbarge collection and provide access for the user even if the resultset returned by query isn't stored in a variable.

* `createtable(input::TableInput,conn::SQLiteDB=sqlitedb;name::String="",delim::Char='\0',header::Bool=true,types::Array{DataType,1}=DataType[],infer::Bool=true)`
 
  `createtable` takes either a `DataFrame` argument or file name string. The DataFrame or file is converted to an SQLite table in the specified `SQLiteDB`. By default, the resulting table will have the same name as the DataFrame variable or file name, unless specifically passed with the `name` keyword argument. The `delim`, `header`, `types`, and `infer` keyword arguments are for use with files. `delime` specifies the file delimiter, (comma ',', tab '\t', etc.). `header` specifies whether the file has a header or not and generates column names if needed. `types` allows the user to specify the column types to be read in, while `infer` allows an algorithm to figure out each columns type before commiting to the SQLite table. Note that if the `types` argument is empty and `infer=false`, then all values will be passed as Strings/text, which ends up being very fast, but obviously without any resulting type information.

* `readdlmsql(input::String,conn::SQLiteDB=sqlitedb;sql::String="select * from file",name::String="file",delim::Char='\0',header::Bool=true,types::Array{DataType,1}=DataType[],infer::Bool=true)`

  `readdlmsql` is pretty simple, and is really just a wrapper around a `createtable` call + `query` call. Arguments are specified similar to `createtable`, with an additional `sql::String` keyword argument where a user can specify a query string to run on the created table to return in a DataFrame. Cousin function to `sqldf` R package's `read.csv.sql` function.

* `droptable(conn::SQLiteDB=sqlitedb,table::String)`

  `droptable` is pretty self-explanatory. It's really just a convenience wrapper around `query` to execute a DROP TABLE command.

* `sqldf(q::String)`

  `sqldf` mirrors the function of the same name in R, allowing common SQL operations on Julia DataFrames. The passed query string is parsed and the DataFrames named in the FROM and JOIN statements are first converted to SQLite tables and then the SELECT statement is run on them. The tables are dropped after the query is run and the result is returned as a DataFrame. 



#### Types
* `SQLiteDB`

  Stores information about an SQLite database connection. Names include `file` for the SQLite database filename, `handle` as the internal connection handle pointer, and `resultset` which
stores the last resultset returned from a `query` call. 

* `typealias TableInput Union(DataFrame,String)`

#### Variables
* `sqlitedb`
  Global, exported variable that initially holds a null `SQLiteDB` type until a connection is successfully made by `SQLite.connect`. Is used by `query` as the default datasource `SQLiteDB` if none is explicitly specified. 

### Known Issues
* We've had limited SQLite testing between various platforms, so it may happen that `SQLite.jl` doesn't recognize your SQLite shared library. The current approach, since SQLite doesn't come standard on many platforms, is to provide the shared library in the `SQLite.jl/lib` folder. If this doesn't work on your machine, you'll need to manually locate your SQLite shared library (searching for something along the lines of
  `libsqlite3` or `sqlite3`, or compiling/installing it yourself) and then run the following:
  ```julia
  const SQLite.sqlite3_lib = "path/to/library/sqlite3.so" (or .dylib on OSX)
  ```

  That said, if you end up doing this, open an issue on GitHub to let me know if the library is on your platform by default and I can add it is as one of the defaults to check for.

### TODO
* Additional benchmarking: I've only tested `createtable` so far, as I was initially having performance issues with it, but now we're even with the RSQLite package in R (whose functions are all implemented in C).
