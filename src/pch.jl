struct Component{T <: Number}
    x::T
    y::T
    z::T
    rx::T
    ry::T
    rz::T
end



"""
    PunchType

Abstract supertype of PunchModalData and PunchFrequencyData
"""
abstract type PunchType end


"""
    PunchModalData

Nastran punch file modal data format.
"""
mutable struct PunchModalData{T <: Real} <: PunchType
    title::String
    subtitle::String
    label::String
    datatype::String
    outputtype::String
    subcaseid::Int
    eigenvalue::Float64
    mode::Int
    eigenvector::Vector{Component{T}} # only support for real modes so far
    PunchModalData{T}() where T = (x = new(); x.eigenvector = Vector{Component{T}}(undef, 0); x)
end


"""
    PunchFrequencyData

Nastran punch file modal data format.
"""
mutable struct PunchFrequencyData{T <: Real} <: PunchType
    title::String
    subtitle::String
    label::String
    datatype::String
    outputtype::String
    subcaseid::Int
    point::Int
    response::Vector{Component{Complex{T}}}
    PunchFrequencyData{T}() where T = (x = new(); x.response = Vector{Component{T}}(undef, 0); x)
end


"""
    PMData

Nastran punch file modal data load format.
"""
struct PMData{T <: Real}
    modal::Vector{PunchModalData{T}}
    node::Vector{Int}
end


"""
    PData

Nastran punch file response data load format.
"""
struct PFData{T <: Real}
    response::Vector{PunchFrequencyData{T}}
    frequency::Vector{T}
end

"""
    PunchData

Punch data union holding all other punch data types.
"""
PunchData{T} = Union{PunchModalData{T}, PunchFrequencyData{T}}


"""
    readpch(file::String, type::PunchData)

Read punch file.
"""
readpch(file::String, type::PunchData{T}) where T <: Real


"""
    readpch(file::String, ::Type{PunchModalData})

Read SOL103 real modal data from Nastran punch file according to SORT2.

This should be avoided, in favour of HDF5, but is included for existing result files.

# Reference
MSC Nastran 2017.1 Reference Manual
"""
function readpch(file::String, type::Type{PunchModalData{T}}) where T <: Real
    data_modal = Vector{type}(undef, 0)
    node = Vector{Int}(undef, 0)

    #try
        lines = readlines(file)
    #catch e
    #    println("Error $e. Can't read file")
    #end

    cnew = false
    data = PunchModalData{T}()

    next = iterate(lines)
    while next !== nothing
        (line, state) = next

        line = line[1:PCHLL]
        isdollar = line[1] == DOLLAR

        if isdollar && cnew
            push!(data_modal, data)
            data = PunchModalData{T}()
            cnew = false
        end

        if isdollar
            readmeta!(data, line)
        else
            state = readcomponents!(data, node, line, lines, state)
            cnew = true
        end

        next = iterate(lines, state)
    end
    push!(data_modal, data)

    return PMData(data_modal, node)
end


"""
    readpch(file::String, ::Type{PunchFrequencyData})

Read SOL111/108 frequency response data from Nastran punch file according to SORT2 and IMAG.

This should be avoided, in favour of HDF5, but is included for existing result files.

# Reference
MSC Nastran 2017.1 Reference Manual
"""
function readpch(file::String, type::Type{PunchFrequencyData{T}}) where T <: Real
    data_frequency = Vector{type}(undef, 0)
    frequency = Vector{T}(undef, 0)

    #try
        lines = readlines(file)
    #catch e
    #    println("Error $e. Can't read file")
    #end

    cnew = false
    data = PunchFrequencyData{T}()

    next = iterate(lines)
    while next !== nothing
        (line, state) = next

        line = length(line) < PCHLL ? line[:] : line[1:PCHLL]
        isdollar = line[1] == DOLLAR

        # can this be more general?
        if length(line) > 8
            if contains(line[1:8], "SET") || line[1:8] == "        "
                next = iterate(lines, state)
                continue
            end
        end
        
        if isdollar && cnew
            push!(data_frequency, data)
            data = PunchFrequencyData{T}()
            cnew = false
        end

        if isdollar
            readmeta!(data, line)
        else
            state = readcomponents!(data, frequency, line, lines, state)
            cnew = true
        end

        next = iterate(lines, state)
    end
    push!(data_frequency, data)

    return PFData(data_frequency, frequency)
end


"""
    readmeta!(data::PunchModalData, line)

Read modal metadata.
"""
function readmeta!(data::PunchModalData{T}, line) where T <: Real
    meta = split(line[2:end], EQUAL)
    meta1 = rstrip(meta[1])
    meta2 = length(meta) == 1 ? rstrip(lstrip(meta[1])) : rstrip(lstrip(meta[2]))
    #meta2 = meta2 === nothing ? "" : meta

    if meta1 == TITLE
        data.title = meta2
    elseif meta1 == SUBTITLE
        data.subtitle = meta2
    elseif meta1 == LABEL
        data.label = meta2
    elseif meta1 == SUBCASE_ID
        data.subcaseid = parse(Int64, meta2)
    elseif meta1 == EIGENVALUE
        data.eigenvalue = parse(Float64, split(meta2)[1])
        data.mode = parse(Int64, strip(meta[3]))
    else
        if !isdefined(data, :datatype)
            data.datatype = meta2
        else
            data.outputtype = meta2
        end
    end

    return nothing
end


"""
    reameta!(data::PunchFrequencyData, frequency, line, lines, state)

Read frequency metadata.
"""
function readmeta!(data::PunchFrequencyData{T}, line) where T <: Real
    meta = split(line[2:end], EQUAL)
    meta1 = rstrip(meta[1])
    meta2 = length(meta) == 1 ? rstrip(lstrip(meta[1])) : rstrip(lstrip(meta[2]))
    #meta2 = meta2 === nothing ? "" : meta

    if meta1 == TITLE
        data.title = meta2
    elseif meta1 == SUBTITLE
        data.subtitle = meta2
    elseif meta1 == LABEL
        data.label = meta2
    elseif meta1 == SUBCASE_ID
        data.subcaseid = parse(Int64, meta2)
    elseif meta1 == POINT
        data.point = parse(Int64, strip(split(meta[2])[1]))
    else
        if !isdefined(data, :datatype)
            data.datatype = meta2
        else
            data.outputtype = meta2
        end
    end

    return nothing
end


"""
    readcomponents!(data::PunchModalData, node, line, lines, state)

Read modal components.
"""
function readcomponents!(data::PunchModalData{T}, node, line, lines, state) where T <: Real
    c1 = strip(line[1:PCHL - 1]) # skip last character
    cmp(c1, CONT) == 0 ? nothing : push!(node, parse(Int, c1))

    x = parse(T, strip(line[PCHL + 1:2PCHL]))
    y = parse(T, strip(line[2PCHL + 1:3PCHL]))
    z = parse(T, strip(line[3PCHL + 1:4PCHL]))

    (line, state) = iterate(lines, state)
    rx = parse(T, strip(line[PCHL + 1:2PCHL]))
    ry = parse(T, strip(line[2PCHL + 1:3PCHL]))
    rz = parse(T, strip(line[3PCHL + 1:4PCHL]))

    push!(data.eigenvector, Component{T}(x, y, z, rx, ry, rz))

    return state
end


"""
    readcomponents!(data::PunchFrequencyData, frequency, line, lines, state)

Read real/imaginary translation and rotation components.
"""
function readcomponents!(data::PunchFrequencyData{T}, frequency, line, lines, state) where T <: Real
    # for now I think this is clearest
    c1 = strip(line[1:PCHL - 1]) # skip last character
    cmp(c1, CONT) == 0 ? nothing : push!(frequency, parse(Float64, c1))

    x = parse(T, strip(line[PCHL + 1:2PCHL]))
    y = parse(T, strip(line[2PCHL + 1:3PCHL]))
    z = parse(T, strip(line[3PCHL + 1:4PCHL]))

    (line, state) = iterate(lines, state)
    rx = parse(T, strip(line[PCHL + 1:2PCHL]))
    ry = parse(T, strip(line[2PCHL + 1:3PCHL]))
    rz = parse(T, strip(line[3PCHL + 1:4PCHL]))

    (line, state) = iterate(lines, state)
    x = x + im*parse(T, strip(line[PCHL + 1:2PCHL]))
    y = y + im*parse(T, strip(line[2PCHL + 1:3PCHL]))
    z = z + im*parse(T, strip(line[3PCHL + 1:4PCHL]))

    (line, state) = iterate(lines, state)
    rx = rx + im*parse(T, strip(line[PCHL + 1:2PCHL]))
    ry = ry + im*parse(T, strip(line[2PCHL + 1:3PCHL]))
    rz = rz + im*parse(T, strip(line[3PCHL + 1:4PCHL]))

    push!(data.response, Component{Complex{T}}(x, y, z, rx, ry, rz))

    return state
end


"""
    collect(data::PMData)

Collect all modal data into a matrix .
"""
function collect(data::PMData{T}) where T <: Real
    n, m = length(data.modal[1].eigenvector), length(data.modal)
    d = Matrix{Float64}(undef, n*DOF, m)
    for i in 1:m
        d[:, i] = collect(data.modal[i].eigenvector)
    end

    return d
end


"""
    collect(data::PFData)

Collect all response data into a matrix.
"""
function collect(data::PFData{T}) where T <: Real
    n, m = length(data.response[1].response), length(data.response)
    d = Matrix{Complex{T}}(undef, n*DOF, m)
    for i in 1:m
        d[:, i] = collect(data.response[i].response)
    end

    return d
end


"""
    collect(data::Component)

Collect components in x, y, z, rx, ry, and rz order
"""
function collect(data::Component{T}) where T <: Number
    return [data.x, data.y, data.z, data.rx, data.ry, data.rz]
end


"""
    collect(data::Vector{Component})

Collect components in x, y, z, rx, ry, and rz order
"""
function collect(data::Vector{Component{T}}) where T <: Number
    return collect(Iterators.flatten([collect(x) for x in data]))
end