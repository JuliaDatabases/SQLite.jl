module SQLite

import Random
import DBInterface
using Serialization
using WeakRefStrings
using Tables

include("capi.jl")
import .C as C

include("base.jl")
include("db_and_stmt.jl")
include("bind.jl")
include("type_conversion.jl")
include("query.jl")
include("transaction.jl")
include("table.jl")
include("index.jl")
include("db_functions.jl")
include("UDF.jl")

export SQLiteException, @sr_str

end # module
