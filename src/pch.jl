abstract type PunchType end

"""
    PunchModalData

Nastran punch file modal data load format.
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

Nastran punch file modal data load format.
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
    readpch(file::String, ::Type{PunchModalData})

Read SOL103 real modal data from Nastran punch file according to SORT2.

Not very elegant, nor efficient. This should be avoided, in favour of HDF5, but is included for existing result files.

# Reference
[MSC Nastran 2017.1 Reference Manual](https://simcompanion.mscsoftware.com/infocenter/index?page=content&id=DOC11313&cat=MSC_NASTRAN_DOCUMENTATION_2017.1&actp=LIST)(visited on 2017-10-14)
"""
function readpch(file::String, ::Type{PunchModalData})
    data_modal = Vector{PunchModalData}(undef, 0)
    node = Vector{Int}(undef, 0)

    lines = readlines(file)

    cnew = false
    index = 1
    tmp = PunchModalData()
    for line in lines
        line = line[1:PCHLL]
        isdollar = line[1] == DOLLAR

        if isdollar && cnew
            push!(data_modal, tmp)
            tmp = PunchModalData()
            cnew = false
            index = 2
        end

        if isdollar
            meta = split(line[2:end], '=')
            meta1 = rstrip(meta[1])
            meta2 = length(meta) == 1 ? rstrip(lstrip(meta[1])) : rstrip(lstrip(meta[2]))
            #meta2 = meta2 === nothing ? "" : meta

            if meta1 == TITLE
                tmp.title = meta2
            elseif meta1 == SUBTITLE
                tmp.subtitle = meta2
            elseif meta1 == LABEL
                tmp.label = meta2
            elseif meta1 == SUBCASE_ID
                tmp.subcaseid = parse(Int64, meta2)
            elseif meta1 == EIGENVALUE
                tmp.eigenvalue = parse(Float64, split(meta2)[1])
                tmp.mode = parse(Int64, strip(meta[3]))
            else
                if !isdefined(tmp, :datatype)
                    tmp.datatype = meta2
                else
                    tmp.outputtype = meta2
                end
            end
        else
            c1 = strip(line[1:PCHL - 1]) # skip last character
            if index == 1
                cmp(c1, "-CONT-") == 0 ? nothing : push!(node, parse(Int64, c1))
            end
            push!(tmp.eigenvector, parse(Float64, strip(line[PCHL + 1:2PCHL])))
            push!(tmp.eigenvector, parse(Float64, strip(line[2PCHL + 1:3PCHL])))
            push!(tmp.eigenvector, parse(Float64, strip(line[3PCHL + 1:4PCHL])))
            cnew = true
        end
    end
    push!(data_modal, tmp)

    return PMData(data_modal, node)
end

"""
    readpch(file::String, ::Type{PunchFrequencyData})

Read SOL111/108 frequency response data from Nastran punch file according to SORT2 and IMAG.

Not very elegant, nor efficient. This should be avoided, in favour of HDF5, but is included for existing result files.

# Reference
[MSC Nastran 2017.1 Reference Manual](https://simcompanion.mscsoftware.com/infocenter/index?page=content&id=DOC11313&cat=MSC_NASTRAN_DOCUMENTATION_2017.1&actp=LIST)(visited on 2017-10-14)
"""
function readpch(file::String, ::Type{PunchFrequencyData})
    data_frequency = Vector{PunchFrequencyData}(undef, 0)
    frequency = Vector{Float64}(undef, 0)

    lines = readlines(file)

    cnew = false
    index = 1
    tmp = PunchFrequencyData()

    next = iterate(lines)
    while next !== nothing
        (line, state) = next
        # body

        line = line[1:PCHLL]
        isdollar = line[1] == DOLLAR

        if isdollar && cnew
            push!(data_frequency, tmp)
            tmp = PunchFrequencyData()
            cnew = false
            index = 2
        end

        if isdollar
            meta = split(line[2:end], '=')
            meta1 = rstrip(meta[1])
            meta2 = length(meta) == 1 ? rstrip(lstrip(meta[1])) : rstrip(lstrip(meta[2]))
            #meta2 = meta2 === nothing ? "" : meta

            if meta1 == TITLE
                tmp.title = meta2
            elseif meta1 == SUBTITLE
                tmp.subtitle = meta2
            elseif meta1 == LABEL
                tmp.label = meta2
            elseif meta1 == SUBCASE_ID
                tmp.subcaseid = parse(Int64, meta2)
            elseif meta1 == EIGENVALUE
                tmp.point = parse(Int64, strip(split(meta[2])[1]))
            else
                if !isdefined(tmp, :datatype)
                    tmp.datatype = meta2
                else
                    tmp.outputtype = meta2
                end
            end
        else
            c1 = strip(line[1:PCHL - 1]) # skip last character
            if index == 1
                cmp(c1, "-CONT-") == 0 ? nothing : push!(frequency, parse(Float64, c1))
            end
            # will clean up this mess a bit later
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
            z = y + im*parse(Float64, strip(line[3PCHL + 1:4PCHL]))
            (line, state) = iterate(lines, state)
            rx = rx + im*parse(Float64, strip(line[PCHL + 1:2PCHL]))
            ry = ry + im*parse(Float64, strip(line[2PCHL + 1:3PCHL]))
            rz = rz + im*parse(Float64, strip(line[3PCHL + 1:4PCHL]))

            push!(tmp.response, x)
            push!(tmp.response, y)
            push!(tmp.response, z)
            push!(tmp.response, rx)
            push!(tmp.response, ry)
            push!(tmp.response, rz)
            cnew = true
        end

        next = iterate(lines, state)
    end
    push!(data_frequency, tmp)

    return PFData(data_frequency, frequency)
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
    d = Matrix{Float64}(undef, n, m)
    for i in 1:m
        d[:, i] = data.response[1].response
    end

    return d
end