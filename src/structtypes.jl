Base.@pure function symbolin(names::Tuple{Vararg{Symbol}}, name::Symbol)
    for nm in names
        nm === name && return true
    end
    return false
end

select(db::DB, sql::AbstractString, ::Type{T}; kw...) where {T} = select(Stmt(db, sql), T; kw...)

function select(stmt::Stmt, ::Type{T}; kw...) where {T}
    status = execute!(stmt)
    return select(StructTypes.StructType(T), stmt, status, 1, T; kw...)
end

function select(stmt::Stmt, ::Type{A}; kw...) where {A <: AbstractVector{T}} where {T}
    status = execute!(stmt)
    a = A(undef, 0)
    while status == SQLITE_ROW
        push!(a, select(StructTypes.StructType(T), stmt, status, 1, T; kw...))
        status = sqlite3_step(stmt.handle)
    end
    return a
end

# aggregate handlers (don't take a `col` argument)
function select(::StructTypes.Struct, stmt, status, col, ::Type{T}; kw...) where {T}
    status == SQLITE_DONE && return T()
    N = fieldcount(T)
    Base.@nexprs 32 i -> begin
        T_i = fieldtype(T, i)
        x_i = select(StructTypes.StructType(T_i), stmt, status, i, T_i; kw...)
        if N == i
            return Base.@ncall i T x
        end
    end
    # TODO: > 32 fields in T
end

# function select(::StructTypes.Mutable, stmt, status, ::Type{T}, kw...) where {T}
#     x = T()
#     status == SQLITE_DONE && return x
#     handle = stmt.handle
#     N = fieldcount(T)
#     nms = names(T)
#     excl = excludes(T)
#     kwargs = keywordargs(T)
#     Base.@nexprs 32 i -> begin
#         T_i = fieldtype(T, i)
#         n_i = julianame(nms, sym(sqlite3_column_name(handle, i)))
#         if !symbolin(excl, n_i)
#             if isempty(kwargs)
#                 x_i = select(StructTypes.StructType(T_i), stmt, status, i, T_i; kw...)
#             else
#                 x_i = select(StructTypes.StructType(T_i), stmt, status, i, T_i; kwargs[fieldname(T, i)]...)
#             end
#             setfield!(x, i, x_i)
#         end
#         if N == i
#             return x
#         end
#     end
# end

@inline select(::StructTypes.DictType, stmt, status, col, ::Type{T}; kw...) where {T} = select(StructTypes.DictType(), stmt, status, col, T, Symbol, Any; kw...)
@inline select(::StructTypes.DictType, stmt, status, col, ::Type{T}; kw...) where {T <: NamedTuple} = select(StructTypes.DictType(), stmt, status, col, T, Symbol, Any; kw...)
@inline select(::StructTypes.DictType, stmt, status, col, ::Type{Dict}; kw...) = select(StructTypes.DictType(), stmt, status, col, Dict, String, Any; kw...)
@inline select(::StructTypes.DictType, stmt, status, col, ::Type{T}; kw...) where {T <: AbstractDict} = select(StructTypes.DictType(), stmt, status, col, T, keytype(T), valtype(T); kw...)

function select(::StructTypes.DictType, stmt, status, col, ::Type{T}, ::Type{K}, ::Type{V}; kw...) where {T, K, V}
    x = Dict{K, V}()
    status == SQLITE_DONE && return StructTypes.construct(T, x; kw...)
    handle = stmt.handle
    for i = 1:sqlite3_column_count(handle)
        ptr = sqlite3_column_name(handle, i)
        if K == Symbol
            x[sym(ptr)] = select(StructTypes.StructType(V), stmt, status, i, V; kw...)
        else
            x[StructTypes.construct(K, unsafe_string(ptr))] = select(StructTypes.StructType(V), stmt, status, i, V; kw...)
        end
    end
    return StructTypes.construct(T, x; kw...)
end

@inline select(::StructTypes.ArrayType, stmt, status, col, ::Type{T}; kw...) where {T} = select(StructTypes.ArrayType(), stmt, status, col, T, Base.IteratorEltype(T) == Base.HasEltype() ? eltype(T) : Any; kw...)
@inline select(::StructTypes.ArrayType, stmt, status, col, ::Type{T}, ::Type{eT}; kw...) where {T, eT} = selectarray(stmt, status, col, T, eT; kw...)
select(::StructTypes.ArrayType, stmt, status, col, ::Type{Tuple}, ::Type{eT}; kw...) where {eT} = selectarray(stmt, status, col, Tuple, eT; kw...)

function selectarray(stmt, status, col, ::Type{T}, ::Type{eT}; kw...) where {T, eT}
    handle = stmt.handle
    N = sqlite3_column_count(handle)
    x = Vector{eT}(undef, N)
    status == SQLITE_DONE && return StructTypes.construct(T, x; kw...)
    for i = 1:N
        x[i] = select(StructTypes.StructType(eT), stmt, status, i, eT; kw...)
    end
    return StructTypes.construct(T, x; kw...)
end

# scalar handlers (take a `col` argument)
function select(::StructTypes.StringType, stmt, status, col, ::Type{T}; kw...) where {T}
    status == SQLITE_DONE && return StructTypes.construct(T, ""; kw...)
    ptr = sqlite3_column_text(stmt.handle, col)
    len = sqlite3_column_bytes(stmt.handle, col)
    return StructTypes.construct(T, ptr, len; kw...)
end

function select(::StructTypes.BoolType, stmt, status, col, ::Type{T}; kw...) where {T}
    status == SQLITE_DONE && return StructTypes.construct(T, false; kw...)
    x = sqlite3_column_int64(stmt.handle, col)
    return StructTypes.construct(T, x == 1; kw...)
end

select(::StructTypes.NullType, stmt, status, col, ::Type{T}; kw...) where {T} = StructTypes.construct(T, nothing; kw...)

function select(::StructTypes.NumberType, stmt, status, col, ::Type{T}; kw...) where {T}
    NT = StructTypes.numbertype(T)
    status == SQLITE_DONE && return StructTypes(T, NT(0); kw...)
    if NT == Int32
        int32 = sqlite3_column_int(stmt.handle, col)
        return StructTypes.construct(T, int32; kw...)
    elseif NT == Int64
        int64 = sqlite3_column_int64(stmt.handle, col)
        return StructTypes.construct(T, int64; kw...)
    else
        x = sqlite3_column_double(stmt.handle, col)
        return StructTypes.construct(T, NT(x); kw...)
    end
end
