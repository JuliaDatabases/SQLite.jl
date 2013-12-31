module TestDBI
    using DBI
    using SQLite

    # User database
    db = connect(SQLite3, "test/db/users.sqlite3")

    stmt = prepare(db, "CREATE TABLE users (id INT NOT NULL, name VARCHAR(255))")
    executed(stmt)
    execute(stmt)
    executed(stmt)
    finish(stmt)

    try
        stmt = prepare(db, "CREATE TABLE users (id INT NOT NULL, name VARCHAR(255))")
    end
    errcode(db)
    errstring(db)

    stmt = prepare(db, "INSERT INTO users VALUES (1, 'Jeff Bezanson')")
    execute(stmt)
    finish(stmt)

    stmt = prepare(db, "INSERT INTO users VALUES (2, 'Viral Shah')")
    execute(stmt)
    finish(stmt)

    run(db, "INSERT INTO users VALUES (3, 'Stefan Karpinski')")

    stmt = prepare(db, "INSERT INTO users VALUES (?, ?)")
    execute(stmt, {4, "Jameson Nash"})
    execute(stmt, {5, "Keno Fisher"})
    finish(stmt)

    stmt = prepare(db, "SELECT * FROM users")
    execute(stmt)
    row = fetchrow(stmt)
    row = fetchrow(stmt)
    row = fetchrow(stmt)
    row = fetchrow(stmt)
    row = fetchrow(stmt)
    row = fetchrow(stmt)
    finish(stmt)

    stmt = prepare(db, "SELECT * FROM users")
    execute(stmt)
    rows = fetchall(stmt)
    finish(stmt)

    stmt = prepare(db, "SELECT * FROM users")
    execute(stmt)
    rows = fetchdf(stmt)
    finish(stmt)

    rows = select(db, "SELECT * FROM users")

    tabledata = tableinfo(db, "users")

    columndata = columninfo(db, "users", "id")
    columndata = columninfo(db, "users", "name")

    stmt = prepare(db, "DROP TABLE users")
    execute(stmt)
    finish(stmt)

    disconnect(db)

    # China OK database
    db = connect(SQLite3,
                 Pkg.dir("SQLite", "test", "db", "chinook.sqlite3"))

    stmt = prepare(db, "SELECT * FROM Employee")
    execute(stmt)
    df = fetchdf(stmt)
    finish(stmt)

    df = select(db,
                "SELECT * FROM sqlite_master WHERE type = 'table' ORDER BY name")
    df = select(db,
                "SELECT * FROM Album")
    df = select(db,
                "SELECT a.*, b.AlbumId
                 FROM Artist a
                 LEFT OUTER JOIN Album b ON b.ArtistId = a.ArtistId
                 ORDER BY name")

    disconnect(db)
end
