using BinDeps

@BinDeps.setup

deps = [sqlite3_lib = library_dependency("sqlite3_lib", aliases=["sqlite3","sqlite3-64","libsqlite3"])]

@BinDeps.if_install begin

provides(HomeBrew, {"sqlite" => sqlite3_lib})
provides(Yum, {"sqlite3-devel" => sqlite3_lib})
provides(AptGet, {"sqlite3" => sqlite3_lib})

provides(Binaries, {URI("http://drive.google.com/uc?export=download&id=0B6x_qYLl89S0TnAxS1Jtd3g3QkU") => sqlite3_lib}, os = :Windows)

@BinDeps.install

end