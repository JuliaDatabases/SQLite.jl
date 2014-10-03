using BinDeps

@BinDeps.setup

deps = [sqlite3_lib = library_dependency("sqlite3_lib", aliases=["sqlite3","sqlite3-64","libsqlite3","libsqlite3-0"])]

@osx_only begin
  using Homebrew
  provides(Homebrew.HB, {"sqlite" => sqlite3_lib})
end
@unix_only begin
  provides(Yum, {"sqlite3-devel" => sqlite3_lib})
  provides(AptGet, {"sqlite3" => sqlite3_lib})
end

@windows_only begin
  using WinRPM
  provides(WinRPM.RPM,"libsqlite",sqlite3_lib, os = :Windows)
end

@BinDeps.install [:sqlite3_lib => :sqlite3_lib ]

#const sqlite3_lib = joinpath(dirname(@__FILE__),"../lib/sqlite3-64.dll")