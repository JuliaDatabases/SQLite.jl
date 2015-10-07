import Base: isidentifier, is_id_start_char, is_id_char

const RESERVED_WORDS = Set(["begin", "while", "if", "for", "try",
    "return", "break", "continue", "function", "macro", "quote", "let",
    "local", "global", "const", "abstract", "typealias", "type", "bitstype",
    "immutable", "ccall", "do", "module", "baremodule", "using", "import",
    "export", "importall", "end", "else", "elseif", "catch", "finally"])
if VERSION >= v"0.4.0-dev+757"
    push!(RESERVED_WORDS, "stagedfunction")
end

function identifier(s::AbstractString)
    s = normalize_string(s)
    if !isidentifier(s)
        s = makeidentifier(s)
    end
    symbol(in(s, RESERVED_WORDS) ? "_"*s : s)
end

function makeidentifier(s::AbstractString)
    i = start(s)
    done(s, i) && return "x"

    res = IOBuffer(sizeof(s) + 1)

    (c, i) = next(s, i)
    under = if is_id_start_char(c)
        write(res, c)
        c == '_'
    elseif is_id_char(c)
        write(res, 'x', c)
        false
    else
        write(res, '_')
        true
    end

    while !done(s, i)
        (c, i) = next(s, i)
        if c != '_' && is_id_char(c)
            write(res, c)
            under = false
        elseif !under
            write(res, '_')
            under = true
        end
    end

    return takebuf_string(res)
end

function make_unique(names::Vector{Symbol})
    seen = Set{Symbol}()
    names = copy(names)
    dups = Int[]
    for i in 1:length(names)
        name = names[i]
        in(name, seen) ? push!(dups, i) : push!(seen, name)
    end
    for i in dups
        nm = names[i]
        k = 1
        while true
            newnm = symbol("$(nm)_$k")
            if !in(newnm, seen)
                names[i] = newnm
                push!(seen, newnm)
                break
            end
            k += 1
        end
    end

    return names
end
