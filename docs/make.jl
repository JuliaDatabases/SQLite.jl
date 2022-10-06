using Documenter, SQLite

makedocs(;
    modules = [SQLite],
    format = Documenter.HTML(),
    pages = ["Home" => "index.md"],
    repo = "https://github.com/JuliaDatabases/SQLite.jl/blob/{commit}{path}#L{line}",
    sitename = "SQLite.jl",
    authors = "Jacob Quinn",
    assets = String[],
)

deploydocs(; repo = "github.com/JuliaDatabases/SQLite.jl")
