import Pkg

cd(@__DIR__)
Pkg.activate(@__DIR__)
Pkg.develop(path="..")
Pkg.instantiate()

using Documenter, SQLite, DBInterface

DocMeta.setdocmeta!(SQLite, :DocTestSetup, :(using SQLite, DBInterface); recursive=true)

makedocs(;
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == true,
    ),
    pages = ["Home" => "index.md"],
    repo = Remotes.GitHub("JuliaDatabases", "SQLite.jl"),
    sitename = "SQLite.jl",
    authors = "Jacob Quinn",
)

deploydocs(
    repo = "github.com/JuliaDatabases/SQLite.jl.git",
)
