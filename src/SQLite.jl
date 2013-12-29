module SQLite
    using DBI
    using DataArrays
    using DataFrames

    export SQLite3

    include("types.jl")
    include("consts.jl")
    # include(joinpath("api", "utils.jl"))
    include(joinpath("api", "connect.jl"))
    include(joinpath("api", "disconnect.jl"))
    include(joinpath("api", "errors.jl"))
    include(joinpath("api", "execute.jl"))
    include(joinpath("api", "fetch.jl"))
    include(joinpath("api", "finish.jl"))
    include(joinpath("api", "metadata.jl"))
    include(joinpath("api", "misc.jl"))
    include(joinpath("api", "prepare.jl"))
    include("dbi.jl")
    include("extras.jl")
end
