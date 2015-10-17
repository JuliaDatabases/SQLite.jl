using BinDeps

@BinDeps.setup

sqlite3_lib = library_dependency("sqlite3_lib", aliases = ["sqlite3","sqlite3-64","libsqlite3","libsqlite3-0"])

@windows_only begin
    using WinRPM
    provides(WinRPM.RPM, "libsqlite3-0",sqlite3_lib, os = :Windows)
end

@osx_only begin
  using Homebrew
  provides(Homebrew.HB, "sqlite", sqlite3_lib, os = :Darwin)
end
@unix_only begin
  provides(Yum, {"sqlite3-devel" => sqlite3_lib})
  provides(AptGet, {"sqlite3" => sqlite3_lib})
end

@BinDeps.install [:sqlite3_lib => :sqlite3_lib ]

haskey(Pkg.installed(),"DataStreams") || Pkg.clone("https://github.com/quinnj/DataStreams.jl")
# haskey(Pkg.installed(),"CSV") || Pkg.clone("https://github.com/quinnj/CSV.jl")
