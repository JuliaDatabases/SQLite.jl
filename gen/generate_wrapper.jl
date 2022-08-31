using Clang.Generators
using SQLite_jll

cd(@__DIR__)

include_dir = normpath(SQLite_jll.artifact_dir, "include")

options = load_options(joinpath(@__DIR__, "generator.toml"))

args = get_default_args()

headers = [joinpath(include_dir, "sqlite3.h")]

# create context
ctx = create_context(headers, args, options)

# run generator
build!(ctx)
