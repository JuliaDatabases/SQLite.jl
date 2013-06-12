Sqlite.jl
=======

A Julia interface to the Sqlite library and support for operations on DataFrames

Installation through the Julia package manager:
```julia
julia> Pkg.init()        # Creates julia package repository (only runs once for all packages)
julia> Pkg.add("Sqlite")   # Creates the Sqlite repo folder and downloads the Sqlite package + dependancy (if needed)
julia> using Sqlite        # Loads the Sqlite module for use (needs to be run with each new Julia instance)
```
## Package Documentation

#### Functions
* `Sqlite.connect(file::String)`

  `connect` requires the `file` string argument as the name of either a pre-defined Sqlite database to be opened, or if the database doesn't exist, one will be created.

  `connect` returns a `SqliteDB` type which contains basic information
about the connection and Sqlite handle pointers.

  `connect` can be used by storing the `Connection` type in
a variable to be able to close or facilitate handling multiple
databases like so:
  ```julia
  co = Sqlite.connect("mydatasource")
  ```
  But it's unneccesary to store the `SqliteDB`, as an exported
`sqlitedb` variable holds the most recently created `SqliteDB` type and other
Sqlite functions (i.e. `query`) will use it by default in the absence of a specified connection.

* `Sqlite.query(conn::SqliteDB=sqlitedb, querystring::String)`
  
  If a connection type isn't specified as the first positional argument, the query will be executed against
the default connection (stored in the exported variable `sqlitedb` if you'd like to
inspect).

  Once the query is executed, the resultset is stored in a
`DataFrame` by default.

  For the general user, a simple `Sqlite.query(querystring)` is enough to return a single resultset in a DataFrame. Results are stored in the passed SqliteDB type's resultset field. (i.e. `sqlitedb.resultset`). Results are stored by default to avoid immediate garbarge collection and provide access for the user even if the resultset returned by query isn't stored in a variable.

* `createtable(conn::SqliteDB=sqlitedb,df::DataFrame;name::String="")`
 
  `createtable` takes its `DataFrame` argument and converts it to an Sqlite table in the specified `SqliteDB`. By default, the resulting table will have the same name as the DataFrame variable, unless specifically passed with the `name` keyword argument.

* `droptable(conn::SqliteDB=sqlitedb,table::String)`

  `droptable` is pretty self-explanatory. It's really just a convenience wrapper around `query` to execute a DROP TABLE command.

* `sqldf(q::String)`

  `sqldf` mirrors the function of the same name in R, allowing common SQL operations on Julia DataFrames. The passed query string is parsed and the DataFrames named in the FROM and JOIN statements are first converted to Sqlite tables and then the SELECT statement is run on them. The tables are dropped after the query is run and the result is returned as a DataFrame. 

* Planned Functions

  `createtable` specifying a delimted (CSV,TSV,etc.) file for the table to be created from. `readdlmsql` will then be possible, allowing a raw file to be read and a DataFrame to be returned according to a given SQL statement.

#### Types
* `SqliteDB`

  Stores information about an Sqlite database connection. Names include `file` for the Sqlite database filename, `handle` as the internal connection handle pointer, and `resultset` which
stores the last resultset returned from a `Sqlite.query` call. 

#### Variables
* `sqlitedb`
  Global, exported variable that initially holds a null `SqliteDB` type until a connection is successfully made by `Sqlite.connect`. Is used by `query` as the default datasource `SqliteDB` if none is explicitly specified. 

### Known Issues
* We've had limited Sqlite testing between various platforms, so it may happen that `Sqlite.jl` doesn't recognize your Sqlite shared library. The current approach, since Sqlite doesn't come standard on many platforms, is to provide the shared library in the `Sqlite.jl/lib` folder. If this doesn't work on your machine, you'll need to manually locate your Sqlite shared library (searching for something along the lines of
  `libsqlite3` or `sqlite3`, or compiling/installing it yourself) and then run the following:
  ```julia
  const sqlite3_lib = "path/to/library/sqlite3.so" (or .dylib on OSX)
  ```

  That said, if you end up doing this, open an issue on GitHub to let me know if the library is on your platform by default and I can add it is as one of the defaults to check for.

### TODO
* Overload `createtable` to take a delimted filename
* Function `readdlmsql` similar to `read.csv.sql` in R
* Additional benchmarking: I've only tested `createtable` so far, as I was initially having performance issues with it, but now we're even with the RSQLite package in R (whose functions are all implemented in C).
