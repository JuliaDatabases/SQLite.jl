# Native statement and BLOB core

This workload compiles database creation, prepared execution, parameter binding,
error recovery, and statement/database cleanup with JuliaC safe trimming. Prepared
query results use raw SQLite column reads for their value checks. The workload
also opens a public `SQLite.Blob`, writes and reads a reusable byte buffer, seeks,
and checks both explicit stream close and database-owned stream close. It does not cover
`DBInterface` query materialization, Tables integration, or all SQLite APIs.

With Julia 1.13, run these commands from the repository root:

```sh
julia --project=test/trim -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
julia --project=test/trim -e 'using JuliaC; JuliaC.main(ARGS)' -- --output-exe sqlite_core --project=test/trim --experimental --trim=safe test/trim/statement_core.jl
JULIA_LOAD_CODEGEN_LIB=0 ./sqlite_core 'runtime input'
```

The native CI job uses Julia 1.13 with a ten-minute timeout. The runtime argument
keeps text and BLOB roundtrips dependent on input provided after compilation.
