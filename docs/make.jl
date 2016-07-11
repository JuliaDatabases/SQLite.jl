using Documenter, SQLite

makedocs(
    modules = [SQLite],
)

deploydocs(
    deps = Deps.pip("mkdocs", "python-markdown-math"),
    repo = "github.com/JuliaDB/SQLite.jl.git"
)
