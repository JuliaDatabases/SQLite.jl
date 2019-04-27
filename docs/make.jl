using Documenter, SQLite

makedocs(
    modules = [SQLite],
    sitename = "SQLite.jl",
    pages = ["Home" => "index.md"]
)

deploydocs(
    repo = "github.com/JuliaDatabases/SQLite.jl.git",
    target = "build",
)
