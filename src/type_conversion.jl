# get julia type for given column of the given statement
function juliatype(handle, col)
    stored_typeid = C.sqlite3_column_type(handle, col-1)
    if stored_typeid == C.SQLITE_BLOB
        # blobs are serialized julia types, so just try to deserialize it
        deser_val = sqlitevalue(Any, handle, col)
        # FIXME deserialized type have priority over declared type, is it fine?
        return typeof(deser_val)
    else
        stored_type = juliatype(stored_typeid)
    end
    decl_typestr = C.sqlite3_column_decltype(handle, col-1)
    if decl_typestr != C_NULL
        return juliatype(unsafe_string(decl_typestr), stored_type)
    else
        return stored_type
    end
end

# convert SQLite stored type into Julia equivalent
juliatype(x::Integer) =
    x == C.SQLITE_INTEGER ? Int64 :
    x == C.SQLITE_FLOAT ? Float64 : x == C.SQLITE_TEXT ? String : x == C.SQLITE_NULL ? Missing : Any

# convert SQLite declared type into Julia equivalent,
# fall back to default (stored type), if no good match
function juliatype(decl_typestr::AbstractString, default::Type = Any)
    typeuc = uppercase(decl_typestr)
    # try to match the type affinities described in the "Affinity Name Examples" section
    # of https://www.sqlite.org/datatype3.html
    if typeuc in (
        "INTEGER",
        "INT",
        "TINYINT",
        "SMALLINT",
        "MEDIUMINT",
        "BIGINT",
        "UNSIGNED BIG INT",
        "INT2",
        "INT8",
    )
        return Int64
    elseif typeuc in ("NUMERIC", "REAL", "FLOAT", "DOUBLE", "DOUBLE PRECISION")
        return Float64
    elseif typeuc == "TEXT"
        return String
    elseif typeuc == "BLOB"
        return Any
    elseif typeuc == "DATETIME"
        return default # FIXME
    elseif typeuc == "TIMESTAMP"
        return default # FIXME
    elseif occursin(r"^N?V?A?R?Y?I?N?G?\s*CHARA?C?T?E?R?T?E?X?T?\s*\(?\d*\)?$"i, typeuc)
        return String
    elseif occursin(r"^NUMERIC\(\d+,\d+\)$", typeuc)
        return Float64
    else
        return default
    end
end

sqlitevalue(::Type{T}, handle, col) where {T<:Union{Base.BitSigned,Base.BitUnsigned}} =
    convert(T, C.sqlite3_column_int64(handle, col-1))
const FLOAT_TYPES = Union{Float16,Float32,Float64} # exclude BigFloat
sqlitevalue(::Type{T}, handle, col) where {T<:FLOAT_TYPES} =
    convert(T, C.sqlite3_column_double(handle, col-1))
#TODO: test returning a WeakRefString instead of calling `unsafe_string`
sqlitevalue(::Type{T}, handle, col) where {T<:AbstractString} =
    convert(T, unsafe_string(C.sqlite3_column_text(handle, col-1)))
function sqlitevalue(::Type{T}, handle, col) where {T}
    blob = convert(Ptr{UInt8}, C.sqlite3_column_blob(handle, col-1))
    b = C.sqlite3_column_bytes(handle, col-1)
    buf = zeros(UInt8, b) # global const?
    unsafe_copyto!(pointer(buf), blob, b)
    r = sqldeserialize(buf)
    return r
end

# conversion from Julia to SQLite3 types
sqlitetype_(::Type{<:Integer}) = "INT"
sqlitetype_(::Type{<:AbstractFloat}) = "REAL"
sqlitetype_(::Type{<:AbstractString}) = "TEXT"
sqlitetype_(::Type{Bool}) = "INT"
sqlitetype_(::Type) = "BLOB" # fallback

sqlitetype(::Type{Missing}) = "NULL"
sqlitetype(::Type{Nothing}) = "NULL"
sqlitetype(::Type{Union{T,Missing}}) where {T} = sqlitetype_(T)
sqlitetype(::Type{T}) where {T} = string(sqlitetype_(T), " NOT NULL")
