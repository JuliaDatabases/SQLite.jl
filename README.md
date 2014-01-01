SQLite.jl
=========

A Julia interface to the SQLite library that implements the [DBI.jl protocol](https://github.com/johnmyleswhite/DBI.jl).

# Installation

```julia
julia> Pkg.init()          # Creates julia package repository (only runs once for all packages)
julia> Pkg.add("SQLite")   # Creates the SQLite repo folder and downloads the SQLite package + dependancy (if needed)
julia> using SQLite        # Loads the SQLite module for use (needs to be run with each new Julia instance)
```

Testing status: [![Build Status](https://travis-ci.org/karbarcca/SQLite.jl.png)](https://travis-ci.org/karbarcca/SQLite.jl)

# Package Documentation

This package implements the interface described in the [DBI.jl docs](https://github.com/johnmyleswhite/DBI.jl).

# SQLDF

The tight DataFrame integration previously found in this package, including the `sqldf` function, has been moved to the [SQLDF.jl package](https://github.com/johnmyleswhite/SQLDF.jl).

# Known Issues

We've had limited SQLite testing between various platforms, so it may happen that `SQLite.jl` doesn't recognize your SQLite shared library. The current approach, since SQLite doesn't come standard on many platforms, is to provide the shared library in the `SQLite.jl/lib` folder. If this doesn't work on your machine, you'll need to manually locate your SQLite shared library (searching for something along the lines of `libsqlite3` or `sqlite3`, or compiling/installing it yourself) and then run the following:

```julia
const SQLite.sqlite3_lib = "path/to/library/sqlite3.so" (or .dylib on OSX)
```

That said, if you end up doing this, open an issue on GitHub to let me know if the library is on your platform by default and I can add it is as one of the defaults to check for.
