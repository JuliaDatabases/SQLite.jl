
# internal wrapper type to, in-effect, mark something which has been serialized
immutable Serialization
    object
end

function sqlserialize(x)
    t = IOBuffer()
    # deserialize will sometimes return a random object when called on an array
    # which has not been previously serialized, we can use this type to check
    # that the array has been serialized
    s = Serialization(x)
    serialize(t,s)
    return takebuf_array(t)
end

const SERIALIZATION = UInt8[0x11,0x01,0x02,0x0d,0x53,0x65,0x72,0x69,0x61,0x6c,0x69,0x7a,0x61,0x74,0x69,0x6f,0x6e,0x23]
function sqldeserialize(r)
    ret = ccall(:memcmp, Int32, (Ptr{UInt8},Ptr{UInt8}, UInt),
            SERIALIZATION, r, min(18,length(r)))

    if ret == 0
        v = deserialize(IOBuffer(r))
        return v.object
    else
        return r
    end
end

