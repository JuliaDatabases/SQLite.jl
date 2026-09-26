# SQLite.jl Documentation

```@contents
```

## High-level interface
```@docs
DBInterface.execute(::SQLite.Stmt, ::DBInterface.StatementParams)
SQLite.load!
```

## Types/Functions

```@docs
SQLite.DB
SQLite.Stmt
SQLite.Blob
SQLite.bind!
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
SQLite.transaction
SQLite.commit
SQLite.rollback
SQLite.backup
```

## Incremental BLOB IO

Use `SQLite.Blob` to read or overwrite part of a stored value without copying the
whole value into a Julia array. It implements the usual Julia IO operations.
The value must already exist, and its size is fixed while open. Use SQL
`zeroblob(n)` to reserve space:

```jldoctest
julia> using SQLite

julia> db = SQLite.DB();

julia> SQLite.execute(db, "CREATE TABLE files (id INTEGER PRIMARY KEY, data BLOB)");

julia> SQLite.execute(db, "INSERT INTO files VALUES (1, zeroblob(8192))");

julia> chunk = fill(UInt8(0x2a), 4096);

julia> SQLite.Blob(db, "files", "data", 1; writable=true) do blob
           seek(blob, 4096)
           write(blob, chunk)
       end
4096

julia> SQLite.Blob(db, "files", "data", 1) do blob
           seek(blob, 4096)
           read!(blob, chunk)
           all(==(0x2a), chunk)
       end
true

julia> close(db);
```

Positions are zero-based byte offsets. Streams are read-only by default;
`writable=true` allows reading and overwriting existing bytes. `schema` selects
`"main"`, `"temp"`, or an attached database name. BLOB and TEXT values are exposed
as raw bytes, including serialized Julia values; ordinary query results keep
their existing conversion behavior. Updating or deleting the row expires an
open stream, even if the changed column is different.

For bounded memory use, reuse a buffer. For example, with an existing output
stream `output`:

```julia
SQLite.Blob(db, "files", "data", 1) do blob
    buffer = Vector{UInt8}(undef, 64 * 1024)
    while !eof(blob)
        n = readbytes!(blob, buffer)
        write(output, view(buffer, 1:n))
    end
end
```

`read(blob)` and `readavailable(blob)` allocate all remaining bytes. Incremental
IO still copies bytes between SQLite and the caller's buffer.

Close writable streams explicitly, since closing can commit an implicit
transaction and report a failure. The stream is closed even if `close` throws.
Closing the database first closes its tracked BLOB streams, reports their close
errors, and invalidates them; a later stream close does no additional work.
`flush` does not commit. Finalizers are best-effort cleanup and cannot report
commit failures.

A do-block ensures closure, but does not roll back earlier writes when the body
throws. Composed writes can also leave a written prefix when a later write
fails. For atomic changes, use an explicit transaction and close the BLOB inside
it before committing. Operations on the same stream or connection require
caller synchronization.

## User Defined Functions

### [SQLite Regular Expressions](@id regex)

SQLite provides syntax for calling
the [`regexp` function](http://sqlite.org/lang_expr.html#regexp)
from inside `WHERE` clauses. Unfortunately, however, sqlite does not provide
a default implementation of the `regexp` function. It can be easily added,
however, by calling `SQLite.@register db SQLite.regexp`

The function can be called in the following ways
(examples using the [Chinook Database](http://chinookdatabase.codeplex.com/))

```julia
julia> using SQLite

julia> db = SQLite.DB("Chinook_Sqlite.sqlite")

julia> # using SQLite's in-built syntax

julia> DBInterface.execute(db, "SELECT FirstName, LastName FROM Employee WHERE LastName REGEXP 'e(?=a)'") |> DataFrame
1x2 ResultSet
| Row | "FirstName" | "LastName" |
|-----|-------------|------------|
| 1   | "Jane"      | "Peacock"  |

julia> # explicitly calling the regexp() function

julia> DBInterface.execute(db, "SELECT * FROM Genre WHERE regexp('e[trs]', Name)") |> DataFrame
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

julia> DBInterface.execute(db, "SELECT * FROM Genre ORDER BY GenreId LIMIT 2") |> DataFrame
2x2 ResultSet
| Row | "GenreId" | "Name" |
|-----|-----------|--------|
| 1   | 1         | "Rock" |
| 2   | 2         | "Jazz" |

julia> DBInterface.execute(db, "INSERT INTO Genre VALUES (regexp('^word', 'this is a string'), 'My Genre')") |> DataFrame
1x1 ResultSet
| Row | "Rows Affected" |
|-----|-----------------|
| 1   | 0               |

julia> DBInterface.execute(db, "SELECT * FROM Genre ORDER BY GenreId LIMIT 2") |> DataFrame
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
julia> DBInterface.execute(db, "SELECT * FROM MediaType WHERE Name REGEXP '-\d'") |> DataFrame
1x1 ResultSet
| Row | "Rows Affected" |
|-----|-----------------|
| 1   | 0               |

julia> DBInterface.execute(db, "SELECT * FROM MediaType WHERE Name REGEXP '-d'") |> DataFrame
1x1 ResultSet
| Row | "Rows Affected" |
|-----|-----------------|
| 1   | 0               |
```

This can be avoided in two ways.
You can either escape each backslash yourself
or you can use the raw"..." string literal.
The previous query can then successfully be run like so:

```julia
julia> # manually escaping backslashes

julia> DBInterface.execute(db, "SELECT * FROM MediaType WHERE Name REGEXP '-\\d'") |> DataFrame
1x2 ResultSet
| Row | "MediaTypeId" | "Name"                        |
|-----|---------------|-------------------------------|
| 1   | 3             | "Protected MPEG-4 video file" |


julia> DBInterface.execute(db, raw"SELECT * FROM MediaType WHERE Name REGEXP '-\d'") |> DataFrame
1x2 ResultSet
| Row | "MediaTypeId" | "Name"                        |
|-----|---------------|-------------------------------|
| 1   | 3             | "Protected MPEG-4 video file" |
```


### Custom Scalar Functions

SQLite.jl also provides a way
that you can implement your own [Scalar Functions](https://www.sqlite.org/lang_corefunc.html).
This is done using the [`SQLite.register`](@ref) function and  macro.

[`SQLite.@register`](@ref) takes a [`SQLite.DB`](@ref) and a function.
The function can be in block syntax:

```julia
julia> SQLite.@register db function add3(x)
       x + 3
       end
```

inline function syntax:

```julia
julia> SQLite.@register db mult3(x) = 3 * x
```

and previously defined functions:

```julia
julia> SQLite.@register db sin
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

Any new method defined for `sqlreturn` must take two arguments
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

## Saving an in-memory database to a file

An in-memory database (`SQLite.DB()` with no path) lives only for the
lifetime of the connection. To persist it, use [`SQLite.backup`](@ref),
which copies the database to `path` via the SQLite backup API:

```julia
julia> db = SQLite.DB();  # in-memory database

julia> DBInterface.execute(db, "CREATE TABLE t (id INTEGER, name TEXT)");

julia> DBInterface.execute(db, "INSERT INTO t VALUES (1, 'alice'), (2, 'bob')");

julia> SQLite.backup(db, "snapshot.sqlite")
"snapshot.sqlite"
```

The file can then be reopened as an ordinary on-disk database:

```julia
julia> db2 = SQLite.DB("snapshot.sqlite");

julia> DBInterface.execute(db2, "SELECT * FROM t") |> DataFrame
2×2 DataFrame
 Row │ id     name
     │ Int64  String
─────┼───────────────
   1 │     1  alice
   2 │     2  bob
```

The same call works for any open `SQLite.DB`, not just in-memory ones —
for example, snapshotting an on-disk database to a separate file.
If `path` already holds a database, `SQLite.backup` replaces its contents.
