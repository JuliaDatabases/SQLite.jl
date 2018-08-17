using BinDeps

@BinDeps.setup

sqlite3_lib = library_dependency("sqlite3_lib", aliases = ["sqlite3","sqlite3-64","libsqlite3","libsqlite3-0"])

@static if Sys.iswindows()
    using WinRPM
    provides(WinRPM.RPM, "libsqlite3-0",sqlite3_lib, os = :Windows)
elseif Sys.isapple()
    using Homebrew
    provides(Homebrew.HB, "sqlite", sqlite3_lib, os = :Darwin)
else
    provides(Yum, Dict("sqlite3-devel" => sqlite3_lib))
    provides(AptGet, Dict("sqlite3" => sqlite3_lib))
end

@BinDeps.install Dict(:sqlite3_lib => :sqlite3_lib)
