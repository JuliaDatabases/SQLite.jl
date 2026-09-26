function sqlvalue(values, i)
    temp_val_ptr = unsafe_load(values, i)
    valuetype = C.sqlite3_value_type(temp_val_ptr)

    if valuetype == C.SQLITE_INTEGER
        if Sys.WORD_SIZE == 64
            return C.sqlite3_value_int64(temp_val_ptr)
        else
            return C.sqlite3_value_int(temp_val_ptr)
        end
    elseif valuetype == C.SQLITE_FLOAT
        return C.sqlite3_value_double(temp_val_ptr)
    elseif valuetype == C.SQLITE_TEXT
        return unsafe_string(C.sqlite3_value_text(temp_val_ptr))
    elseif valuetype == C.SQLITE_BLOB
        nbytes = C.sqlite3_value_bytes(temp_val_ptr)
        blob = C.sqlite3_value_blob(temp_val_ptr)
        buf = zeros(UInt8, nbytes)
        unsafe_copyto!(pointer(buf), convert(Ptr{UInt8}, blob), nbytes)
        return sqldeserialize(buf)
    else
        return missing
    end
end

"""
This function should never be called explicitly.
Instead it is exported so that it can be overloaded when necessary,
see [below](@ref regex).
"""
function sqlreturn end

sqlreturn(context, ::Missing) = C.sqlite3_result_null(context)
sqlreturn(context, val::Int32) = C.sqlite3_result_int(context, val)
sqlreturn(context, val::Int64) = C.sqlite3_result_int64(context, val)
sqlreturn(context, val::Float64) = C.sqlite3_result_double(context, val)
function sqlreturn(context, val::AbstractString)
    C.sqlite3_result_text(context, val, sizeof(val), C.SQLITE_TRANSIENT)
end
function sqlreturn(context, val::Vector{UInt8})
    C.sqlite3_result_blob(context, val, sizeof(val), C.SQLITE_TRANSIENT)
end

sqlreturn(context, val::Bool) = sqlreturn(context, Int(val))
sqlreturn(context, val) = sqlreturn(context, sqlserialize(val))

mutable struct ScalarUDFData
    func::Function
end

mutable struct AggregateState
    value::Any
    serialized::Bool # first snapshot, decoded by the next step or final callback
end

mutable struct AggregateUDFData
    init::Any
    step::Function
    final::Function
    states::IdDict{AggregateState,Nothing} # roots only active aggregate contexts
end

# A callback must report errors to SQLite, not unwind through its C caller.
function udf_error(context, err)
    try
        if err isa OutOfMemoryError
            C.sqlite3_result_error_nomem(context)
        else
            message = sprint(showerror, err)
            C.sqlite3_result_error(context, message, sizeof(message))
        end
    catch
        # Error formatting can itself invoke user-defined methods.
        C.sqlite3_result_error(
            context,
            "Julia exception in SQLite callback",
            -1,
        )
    end
    nothing
end

function wrap_scalarfunc(
    context::Ptr{Cvoid},
    nargs::Cint,
    values::Ptr{Ptr{Cvoid}},
)
    try
        udf_data = unsafe_pointer_to_objref(
            C.sqlite3_user_data(context),
        )::ScalarUDFData
        args = [sqlvalue(values, i) for i in 1:nargs]
        sqlreturn(context, udf_data.func(args...))
    catch err
        udf_error(context, err)
    end
    nothing
end

function wrap_stepfunc(
    context::Ptr{Cvoid},
    nargs::Cint,
    values::Ptr{Ptr{Cvoid}},
)
    acptr = Ptr{Ptr{Cvoid}}(C_NULL)
    state = nothing
    udf_data = nothing
    try
        udf_data = unsafe_pointer_to_objref(
            C.sqlite3_user_data(context),
        )::AggregateUDFData
        acptr = convert(
            Ptr{Ptr{Cvoid}},
            C.sqlite3_aggregate_context(context, sizeof(Ptr{Cvoid})),
        )
        acptr == C_NULL && throw(OutOfMemoryError())
        stateptr = unsafe_load(acptr)
        if stateptr != C_NULL
            state = unsafe_pointer_to_objref(stateptr)::AggregateState
        end
        args = [sqlvalue(values, i) for i in 1:nargs]
        if state === nothing
            # Snapshot the first return, not init: the first callback may consume
            # a seed that cannot itself be copied or serialized.
            value = sqlserialize(udf_data.step(udf_data.init, args...))
            # A custom serializer may retain its output buffer.
            state = AggregateState(copy(value), true)
            udf_data.states[state] = nothing
            unsafe_store!(acptr, pointer_from_objref(state))
        else
            acval = state.serialized ? sqldeserialize(state.value) : state.value
            state.value = udf_data.step(acval, args...)
            state.serialized = false
        end
    catch err
        # Release roots before error formatting can invoke another Julia callback.
        # A cleared context tells xFinal to preserve the failed step's error.
        acptr != C_NULL && unsafe_store!(acptr, Ptr{Cvoid}(C_NULL))
        state !== nothing && delete!(udf_data.states, state)
        udf_error(context, err)
    end
    nothing
end

function wrap_finalfunc(context::Ptr{Cvoid})
    try
        acptr = convert(Ptr{Ptr{Cvoid}}, C.sqlite3_aggregate_context(context, 0))
        if acptr != C_NULL
            stateptr = unsafe_load(acptr)
            unsafe_store!(acptr, Ptr{Cvoid}(C_NULL))
            # SQLite still calls xFinal after a failed xStep. Preserve that error.
            stateptr == C_NULL && return nothing
        end
        udf_data = unsafe_pointer_to_objref(
            C.sqlite3_user_data(context),
        )::AggregateUDFData
        if acptr == C_NULL
            # Preserve the initial value when no rows reached xStep.
            sqlreturn(context, udf_data.init)
        else
            state = unsafe_pointer_to_objref(stateptr)::AggregateState
            delete!(udf_data.states, state)
            acval = state.serialized ? sqldeserialize(state.value) : state.value
            sqlreturn(context, udf_data.final(acval))
        end
    catch err
        udf_error(context, err)
    end
    nothing
end

"""
    SQLite.@register db function

User-facing macro for convenience in registering a simple function
with no configurations needed
"""
macro register(db, func)
    :(register($(esc(db)), $(esc(func))))
end

UDF_keep_alive_list = []

"""
    SQLite.register(db, func)
    SQLite.register(db, init, step_func, final_func; nargs=-1, name=string(step), isdeterm=true)

Register a scalar (first method) or aggregate (second method) function
with a [`SQLite.DB`](@ref). Callback errors, including value conversion errors,
are reported as `SQLiteException`s by the query that invokes the function.
"""
function register(
    db::DB,
    func::Function;
    nargs::Int = -1,
    name::AbstractString = string(func),
    isdeterm::Bool = true,
)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    # assume any negative number means a varargs function
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255"

    udf_data = ScalarUDFData(func)
    push!(db.registered_UDF_data, udf_data)
    udf_data_ptr = pointer_from_objref(udf_data)

    cfunc =
        @cfunction(wrap_scalarfunc, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Ptr{Cvoid}}))

    # TODO: allow the other encodings
    enc = C.SQLITE_UTF8
    enc = isdeterm ? enc | C.SQLITE_DETERMINISTIC : enc

    @CHECK db C.sqlite3_create_function_v2(
        db.handle,
        name,
        nargs,
        enc,
        udf_data_ptr,
        cfunc,
        C_NULL,
        C_NULL,
        C_NULL,
    )
end

# as above but for aggregate functions
function register(
    db::DB,
    init,
    step::Function,
    final::Function = identity;
    nargs::Int = -1,
    name::AbstractString = string(step),
    isdeterm::Bool = true,
)
    @assert nargs <= 127 "use -1 if > 127 arguments are needed"
    nargs < -1 && (nargs = -1)
    @assert sizeof(name) <= 255 "size of function name must be <= 255 chars"

    udf_data = AggregateUDFData(init, step, final, IdDict{AggregateState,Nothing}())
    push!(db.registered_UDF_data, udf_data)
    udf_data_ptr = pointer_from_objref(udf_data)

    cs = @cfunction(wrap_stepfunc, Cvoid, (Ptr{Cvoid}, Cint, Ptr{Ptr{Cvoid}}))
    cf = @cfunction(wrap_finalfunc, Cvoid, (Ptr{Cvoid},))

    enc = C.SQLITE_UTF8
    enc = isdeterm ? enc | C.SQLITE_DETERMINISTIC : enc

    @CHECK db C.sqlite3_create_function_v2(
        db.handle,
        name,
        nargs,
        enc,
        udf_data_ptr,
        C_NULL,
        cs,
        cf,
        C_NULL,
    )
end

# annotate types because the MethodError makes more sense that way
regexp(r::AbstractString, s::AbstractString) = occursin(Regex(r), s)

"""
    sr"..."

This string literal is used to escape all special characters in the string,
useful for using regex in a query.

This literal is deprecated and users should switch to `Base.@raw_str` instead.
"""
macro sr_str(s)
    s
end
