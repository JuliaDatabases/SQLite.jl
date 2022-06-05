"""
    SQLite.dropindex!(db, index; ifexists::Bool=true)

drop the SQLite index `index` from the database `db`; `ifexists=true` will not return an error if `index` doesn't exist
"""
function dropindex!(db::DB, index::AbstractString; ifexists::Bool=false)
    exists = ifexists ? "IF EXISTS" : ""
    transaction(db) do
        direct_execute(db, "DROP INDEX $exists $(esc_id(index))")
    end
    return
end

"""
    SQLite.createindex!(db, table, index, cols; unique=true, ifnotexists=false)

create the SQLite index `index` on the table `table` using `cols`,
which may be a single column or vector of columns.
`unique` specifies whether the index will be unique or not.
`ifnotexists=true` will not throw an error if the index already exists
"""
function createindex!(db::DB, table::AbstractString, index::AbstractString, cols::Union{S, AbstractVector{S}};
                      unique::Bool=true, ifnotexists::Bool=false) where {S <: AbstractString}
    u = unique ? "UNIQUE" : ""
    exists = ifnotexists ? "IF NOT EXISTS" : ""
    transaction(db) do
        direct_execute(db, "CREATE $u INDEX $exists $(esc_id(index)) ON $(esc_id(table)) ($(esc_id(cols)))")
    end
    direct_execute(db, "ANALYZE $index")
    return
end
