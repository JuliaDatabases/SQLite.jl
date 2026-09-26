# Native statement core

This workload compiles database creation, prepared execution, parameter binding,
error recovery, and statement/database cleanup with JuliaC safe trimming. It uses
raw SQLite column reads to check the returned values. It does not cover
`DBInterface` query materialization, Tables integration, or all SQLite APIs.

With Julia 1.13, run these commands from the repository root:

```sh
julia --project=test/trim -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
julia --project=test/trim -e 'using JuliaC; JuliaC.main(ARGS)' -- --output-exe sqlite_core --project=test/trim --experimental --trim=safe test/trim/statement_core.jl
JULIA_LOAD_CODEGEN_LIB=0 ./sqlite_core 'runtime input'
```

The native CI job uses Julia 1.13 with a ten-minute timeout. The runtime argument
keeps text and BLOB roundtrips dependent on input provided after compilation.
