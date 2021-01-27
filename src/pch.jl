abstract type PunchType end


"""
    PunchModalData

Nastran punch file modal data format.
"""
mutable struct PunchModalData <: PunchType
    title::String
    subtitle::String
    label::String
    datatype::String
    outputtype::String
    subcaseid::Int64
    eigenvalue::Float64
    mode::Int64
    eigenvector::Vector{Float64}
    PunchModalData() = (x = new(); x.eigenvector = Vector{Float64}(undef, 0); x)
end


"""
    PunchFrequencyData

Nastran punch file modal data format.
"""
mutable struct PunchFrequencyData <: PunchType
    title::String
    subtitle::String
    label::String
    datatype::String
    outputtype::String
    subcaseid::Int64
    point::Int64
    response::Vector{Complex{Float64}}
    PunchFrequencyData() = (x = new(); x.response = Vector{Complex{Float64}}(undef, 0); x)
end


"""
    PMData

Nastran punch file modal data load format.
"""
struct PMData
    modal::Vector{PunchModalData}
    node::Vector{Int}
end


"""
    PData

Nastran punch file response data load format.
"""
struct PFData
    response::Vector{PunchFrequencyData}
    frequency::Vector{Float64}
end

"""
    PunchData

Punch data union holding all other punch data types.
"""
PunchData = Union{PunchModalData, PunchFrequencyData}


"""
    readpch(file::String, type::PunchData)

Read punch file.
"""
readpch(file::String, type::PunchData)


"""
    readpch(file::String, ::Type{PunchModalData})

Read SOL103 real modal data from Nastran punch file according to SORT2.

This should be avoided, in favour of HDF5, but is included for existing result files.

# Reference
MSC Nastran 2017.1 Reference Manual
"""
function readpch(file::String, type::Type{PunchModalData})
    data_modal = Vector{type}(undef, 0)
    node = Vector{Int}(undef, 0)

    #try
        lines = readlines(file)
    #catch e
    #    println("Error $e. Can't read file")
    #end

    cnew = false
    data = PunchModalData()
    for line in lines
        line = line[1:PCHLL]
        isdollar = line[1] == DOLLAR

        if isdollar && cnew
            push!(data_modal, data)
            data = PunchModalData()
            cnew = false
        end

        if isdollar
            readmeta!(data, line)
        else
            readcomponents!(data, node, line)
            cnew = true
        end
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
function readpch(file::String, type::Type{PunchFrequencyData})
    data_frequency = Vector{type}(undef, 0)
    frequency = Vector{Float64}(undef, 0)

    #try
        lines = readlines(file)
    #catch e
    #    println("Error $e. Can't read file")
    #end

    cnew = false
    data = PunchFrequencyData()

    next = iterate(lines)
    while next !== nothing
        (line, state) = next

        # can this be more general?
        if length(line) < PCHLL || contains(line[1:8], "SET") || line[1:8] == "        "
            next = iterate(lines, state)
            continue
        end
        line = line[1:PCHLL]
        isdollar = line[1] == DOLLAR

        if isdollar && cnew
            push!(data_frequency, data)
            data = PunchFrequencyData()
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
function readmeta!(data::PunchModalData, line)
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
function readmeta!(data::PunchFrequencyData, line)
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
    readcomponents!(data::PunchModalData, node, line)

Read modal components.
"""
function readcomponents!(data::PunchModalData, node, line)
    c1 = strip(line[1:PCHL - 1]) # skip last character
    cmp(c1, CONT) == 0 ? nothing : push!(node, parse(Int64, c1))

    push!(data.eigenvector, parse(Float64, strip(line[PCHL + 1:2PCHL])))
    push!(data.eigenvector, parse(Float64, strip(line[2PCHL + 1:3PCHL])))
    push!(data.eigenvector, parse(Float64, strip(line[3PCHL + 1:4PCHL])))

    return nothing
end


"""
    readcomponents!(data::PunchFrequencyData, frequency, line, lines, state)

Read real/imaginary translation and rotation components.
"""
function readcomponents!(data::PunchFrequencyData, frequency, line, lines, state)
    # for now I think this is clearest
    c1 = strip(line[1:PCHL - 1]) # skip last character
    cmp(c1, CONT) == 0 ? nothing : push!(frequency, parse(Float64, c1))

    x = parse(Float64, strip(line[PCHL + 1:2PCHL]))
    y = parse(Float64, strip(line[2PCHL + 1:3PCHL]))
    z = parse(Float64, strip(line[3PCHL + 1:4PCHL]))

    (line, state) = iterate(lines, state)
    rx = parse(Float64, strip(line[PCHL + 1:2PCHL]))
    ry = parse(Float64, strip(line[2PCHL + 1:3PCHL]))
    rz = parse(Float64, strip(line[3PCHL + 1:4PCHL]))

    (line, state) = iterate(lines, state)
    x = x + im*parse(Float64, strip(line[PCHL + 1:2PCHL]))
    y = y + im*parse(Float64, strip(line[2PCHL + 1:3PCHL]))
    z = z + im*parse(Float64, strip(line[3PCHL + 1:4PCHL]))

    (line, state) = iterate(lines, state)
    rx = rx + im*parse(Float64, strip(line[PCHL + 1:2PCHL]))
    ry = ry + im*parse(Float64, strip(line[2PCHL + 1:3PCHL]))
    rz = rz + im*parse(Float64, strip(line[3PCHL + 1:4PCHL]))

    push!(data.response, x)
    push!(data.response, y)
    push!(data.response, z)
    push!(data.response, rx)
    push!(data.response, ry)
    push!(data.response, rz)

    return state
end


"""
    collect(data::PMData)

Collect all modal data into a matrix.
"""
function collect(data::PMData)
    n, m = length(data.modal[1].eigenvector), length(data.modal)
    d = Matrix{Float64}(undef, n, m)
    for i in 1:m
        d[:, i] = data.modal[i].eigenvector
    end

    return d
end


"""
    collect(data::PFData)

Collect all response data into a matrix.
"""
function collect(data::PFData)
    n, m = length(data.response[1].response), length(data.response)
    d = Matrix{Complex}(undef, n, m)
    for i in 1:m
        d[:, i] = data.response[i].response
    end

    return d
end
