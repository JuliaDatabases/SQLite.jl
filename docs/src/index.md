# SQLite.jl Documentation

```@contents
```

## High-level interface
```@docs
DBInterface.execute!
SQLite.load!
```

## Types/Functions

```@docs
SQLite.DB
SQLite.Stmt
SQLite.bind!
SQLite.execute!
SQLite.createtable!
SQLite.drop!
SQLite.dropindex!
SQLite.createindex!
SQLite.removeduplicates!
SQLite.tables
SQLite.columns
SQLite.indices
SQLite.enable_load_extension
SQLite.register
SQLite.@register
SQLite.@sr_str
SQLite.sqlreturn
```

* `SQLite.sqlreturn(contex, val)`

  This function should never be called explicitly. Instead it is exported so that it can be overloaded when necessary, see below.


## User Defined Functions

### [SQLite Regular Expressions](@id regex)

SQLite provides syntax for calling
the [`regexp` function](http://sqlite.org/lang_expr.html#regexp)
from inside `WHERE` clauses.
Unfortunately, however,
SQLite does not provide a default implementation of the `regexp` function,
so SQLite.jl creates one automatically when you open a database.
The function can be called in the following ways
(examples using the [Chinook Database](http://chinookdatabase.codeplex.com/))

```julia
julia> using SQLite

julia> db = SQLite.DB("Chinook_Sqlite.sqlite")

julia> # using SQLite's in-built syntax

julia> SQLite.Query(db, "SELECT FirstName, LastName FROM Employee WHERE LastName REGEXP 'e(?=a)'") |> DataFrame
1x2 ResultSet
| Row | "FirstName" | "LastName" |
|-----|-------------|------------|
| 1   | "Jane"      | "Peacock"  |

julia> # explicitly calling the regexp() function

julia> SQLite.Query(db, "SELECT * FROM Genre WHERE regexp('e[trs]', Name)") |> DataFrame
6x2 ResultSet
| Row | "GenreId" | "Name"               |
|-----|-----------|----------------------|
| 1   | 3         | "Metal"              |
| 2   | 4         | "Alternative & Punk" |
| 3   | 6         | "Blues"              |
| 4   | 13        | "Heavy Metal"        |
| 5   | 23        | "Alternative"        |
| 6   | 25        | "Opera"              |

julia> # you can even do strange things like this if you really want

julia> SQLite.Query(db, "SELECT * FROM Genre ORDER BY GenreId LIMIT 2") |> DataFrame
2x2 ResultSet
| Row | "GenreId" | "Name" |
|-----|-----------|--------|
| 1   | 1         | "Rock" |
| 2   | 2         | "Jazz" |

julia> SQLite.Query(db, "INSERT INTO Genre VALUES (regexp('^word', 'this is a string'), 'My Genre')") |> DataFrame
1x1 ResultSet
| Row | "Rows Affected" |
|-----|-----------------|
| 1   | 0               |

julia> SQLite.Query(db, "SELECT * FROM Genre ORDER BY GenreId LIMIT 2") |> DataFrame
2x2 ResultSet
| Row | "GenreId" | "Name"     |
|-----|-----------|------------|
| 1   | 0         | "My Genre" |
| 2   | 1         | "Rock"     |
```

Due to the heavy use of escape characters,
you may run into problems where julia parses out some backslashes in your query,
for example `"\y"` simply becomes `"y"`.
For example, the following two queries are identical:

```julia
julia> SQLite.Query(db, "SELECT * FROM MediaType WHERE Name REGEXP '-\d'") |> DataFrame
1x1 ResultSet
| Row | "Rows Affected" |
|-----|-----------------|
| 1   | 0               |

julia> SQLite.Query(db, "SELECT * FROM MediaType WHERE Name REGEXP '-d'") |> DataFrame
1x1 ResultSet
| Row | "Rows Affected" |
|-----|-----------------|
| 1   | 0               |
```

This can be avoided in two ways.
You can either escape each backslash yourself
or you can use the sr"..." string literal that SQLite.jl exports.
The previous query can then successfully be run like so:

```julia
julia> # manually escaping backslashes

julia> SQLite.Query(db, "SELECT * FROM MediaType WHERE Name REGEXP '-\\d'") |> DataFrame
1x2 ResultSet
| Row | "MediaTypeId" | "Name"                        |
|-----|---------------|-------------------------------|
| 1   | 3             | "Protected MPEG-4 video file" |

julia> # using sr"..."

julia> SQLite.Query(db, sr"SELECT * FROM MediaType WHERE Name REGEXP '-\d'") |> DataFrame
1x2 ResultSet
| Row | "MediaTypeId" | "Name"                        |
|-----|---------------|-------------------------------|
| 1   | 3             | "Protected MPEG-4 video file" |
```

The `sr"..."` currently escapes all special characters in a string
but it may be changed in the future to escape only characters which are part of a regex.


### Custom Scalar Functions

SQLite.jl also provides a way
that you can implement your own [Scalar Functions](https://www.sqlite.org/lang_corefunc.html).
This is done using the [`register`](@ref) function and  macro.

[`@register`](@ref) takes a [`SQLite.DB`](@ref) and a function.
The function can be in block syntax:

```julia
julia> @register db function add3(x)
       x + 3
       end
```

inline function syntax:

```julia
julia> @register db mult3(x) = 3 * x
```

and previously defined functions:

```julia
julia> @register db sin
```

The [`SQLite.register`](@ref) function takes optional arguments;
`nargs` which defaults to `-1`,
`name` which defaults to the name of the function,
`isdeterm` which defaults to `true`.
In practice these rarely need to be used.

The [`SQLite.register`](@ref) function uses the [`SQLite.sqlreturn`](@ref) function
to return your function's return value to SQLite.
By default, `sqlreturn` maps the returned value
to a [native SQLite type](http://sqlite.org/c3ref/result_blob.html)
or, failing that, serializes the julia value and stores it as a `BLOB`.
To change this behaviour simply define a new method for `sqlreturn`
which then calls a previously defined method for `sqlreturn`.
Methods which map to native SQLite types are

```julia
sqlreturn(context, ::NullType)
sqlreturn(context, val::Int32)
sqlreturn(context, val::Int64)
sqlreturn(context, val::Float64)
sqlreturn(context, val::UTF16String)
sqlreturn(context, val::String)
sqlreturn(context, val::Any)
```

As an example,
say you would like `BigInt`s to be stored as `TEXT` rather than a `BLOB`.
You would simply need to define the following method:

```julia
sqlreturn(context, val::BigInt) = sqlreturn(context, string(val))
```

Another example is the [`SQLite.sqlreturn`](@ref) used by the `regexp` function.
For `regexp` to work correctly,
it must return it must return an `Int` (more specifically a `0` or `1`)
but `occursin` (used by `regexp`) returns a `Bool`.
For this reason the following method was defined:

```julia
sqlreturn(context, val::Bool) = sqlreturn(context, int(val))
```

Any new method defined for `sqlreturn`
must take two arguments
and must pass the first argument straight through as the first argument.

### Custom Aggregate Functions

Using the [`SQLite.register`](@ref) function,
you can also define your own aggregate functions with largely the same semantics.

The `SQLite.register` function for aggregates must take a `SQLite.DB`,
an initial value, a step function and a final function.
The first argument to the step function
will be the return value of the previous function
(or the initial value if it is the first iteration).
The final function must take a single argument
which will be the return value of the last step function.

```julia
julia> dsum(prev, cur) = prev + cur

julia> dsum(prev) = 2 * prev

julia> SQLite.register(db, 0, dsum, dsum)
```

If no name is given,
the name of the first (step) function is used (in this case "dsum").
You can also use lambdas; the following does the same as the previous code snippet

```julia
julia> SQLite.register(db, 0, (p,c) -> p+c, p -> 2p, name="dsum")
```
