using Documenter, SQLite

makedocs(
    modules = [SQLite],
)

deploydocs(
    deps = Deps.pip("mkdocs", "mkdocs-material", "python-markdown-math"),
    repo = "github.com/JuliaDB/SQLite.jl.git"
)
