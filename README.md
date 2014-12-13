SQLite.jl
=========

[![Build Status](https://travis-ci.org/quinnj/SQLite.jl.png)](https://travis-ci.org/quinnj/SQLite.jl)
[![Coverage Status](https://img.shields.io/coveralls/quinnj/SQLite.jl.svg)](https://coveralls.io/r/quinnj/SQLite.jl)
[![SQLite](http://pkg.julialang.org/badges/SQLite_release.svg)](http://pkg.julialang.org/?pkg=SQLite&ver=release)

A Julia interface to the SQLite library and support for operations on DataFrames

**Installation**: `julia> Pkg.add("SQLite")`

## Package Documentation

#### Types/Functions
* `SQLiteDB(file::String; UTF16::Bool=false)`

  `SQLiteDB` requires the `file` string argument as the name of either a pre-defined SQLite database to be opened, or if the file doesn't exist, a database will be created.

  The `SQLiteDB` object represents a single connection to an SQLite database. All other SQLite.jl functions take an `SQLiteDB` as the first argument as context.

  The keyword argument `UTF16` can be set to true to force the creation of a database with UTF16-encoded strings.

  To create an in-memory temporary database, one can also call `SQLiteDB(":memory:")`.

* `close(db::SQLiteDB)`

  Closes an open database connection.

* `SQLiteStmt(db::SQLiteDB, sql::String)`

  Constructs and prepares (compiled by SQLite library) an SQL statement in the context of the provided `db`. Note the SQL statement is not actually executed, but only compiled (mainly for usage where the same statement is repeated with different parameters bound as values. See `bind` below).

* `close(stmt::SQLiteStmt)`

  Closes or finalizes an SQLiteStmt. A closed `SQLiteStmt` can no longer be executed.

* `bind(stmt::SQLiteStmt,index,value)`

  Used to bind values to parameter placeholders in an prepared `SQLiteStmt`. From the SQLite documentation:

  > Usually, though, it is not useful to evaluate exactly the same SQL statement more than once. More often, one wants to evaluate similar statements. For example, you might want to evaluate an INSERT statement multiple times though with different values to insert. To accommodate this kind of flexibility, SQLite allows SQL statements to contain parameters which are "bound" to values prior to being evaluated. These values can later be changed and the same prepared statement can be evaluated a second time using the new values.

  > In SQLite, wherever it is valid to include a string literal, one can use a parameter in one of the following forms:

  > ?
  > ?NNN
  > :AAA
  > $AAA
  > @AAA

  > In the examples above, NNN is an integer value and AAA is an identifier. A parameter initially has a value of NULL. Prior to calling sqlite3_step() for the first time or immediately after sqlite3_reset(), the application can invoke one of the sqlite3_bind() interfaces to attach values to the parameters. Each call to sqlite3_bind() overrides prior bindings on the same parameter.

* `execute(stmt::SQLiteStmt)`
  `execute(db::SQLiteDB, sql::String)`

  Used to execute prepared `SQLiteStmt`. The 2nd method is a convenience method to pass in an SQL statement as a string which gets prepared and executed in one call. This method does not check for or return any results, hence it is only useful for database manipulation methods (i.e. ALTER, CREATE, UPDATE, DROP). To return results, see `query` below. Also consider the `create`, `drop`, and `append` methods for manipulation statements as further SQLite performance tricks are incorporated automatically.

* `query(db::SQLiteDB, sql::String, values=[])`
  
  An SQL statement `sql` is prepared, executed in the context of `db`, and results, if any, are returned. The return values are a `(String[],Any[])` tuple representing `(column names, result values)`.

  The values in `values` are used in parameter binding (see `bind` above). If your statement uses nameless parameters `values` must be a `Vector` of the values you wish to bind to your statment. If your statement uses named parameters `values` must be a Dict where the keys are of type `Symbol`. The key must match an identifier name in the statement (the name **does not** include the ':', '@' or '$' prefix).

* `create(db::SQLiteDB,name::String,table::AbstractMatrix,
            colnames=String[],coltypes=DataType[];temp::Bool=false)`

  Convenience method for "CREATE TABLE" and "INSERT" statements to insert `table` as an SQLite table in the `db` database. `name` will be the name of the SQLite table. `table` can be any AbstractMatrix that supports the `table[i,j]` getindex method. `colnames` is an optional vector to be used as the names of the columns for the SQLite table. `coltypes` is also an optional vector to specify the Julia types of the columns in `table`. The optional keyword `temp` can be set to `true` to specify the creation of a temporary table that will be destroyed when the database connection is closed.

  This method automatically takes care of SQLite transaction handling and other performance enhancements.

* `append(db::SQLiteDB,name::String,table::AbstractMatrix)`

  Takes the values in `table` and appends (by repeated inserts) to the SQLite table `name`. No column checking is done to ensure correct types, so care should be taken as SQLite is "typeless" in that it allows items of any type to be stored in columns. Transaction handling is automatic as well as performance enhancements.

* `drop(db::SQLiteDB,table::String)`

  `drop` is pretty self-explanatory. It's really just a convenience wrapper around `query` to execute a DROP TABLE command, while also calling "VACUUM" to clean out freed memory from the database.

* `@register database function`
  `register(db::SQLiteDB, func::Function; nargs::Integer=-1, name::AbstractString=string(symbol(func)), isdeterm::Bool=true)`

  Register an arbitrary julia function `func` with the SQLite database connection `db`. The macro roughly expands to `register(database, function)` and can be placed before a block- or inline-style function definition. `nargs` is the number of arguments that your julia function takes but this should be left at the default unless you need to do something exceptionally weird. `name` is the name under which the function will be registered and defaults to the name of the julia function. If your julia function has an element of randomness to it then you should set `isdeterm` to `false`.

  For more information see SQLite's [function creation documentation](http://sqlite.org/c3ref/create_function.html) or the IJulia Notebook.

* `sr"..."`

  This string literal is used to escape all special characters in the string, useful for using regex in a query.

* `sqlreturn(contex, val)`

  This function should never be called explicitly. Instead it is exported so that it can be overloaded when necessary.
