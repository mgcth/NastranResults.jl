"""
    PunchModalData

Nastran punch file modal data load format.
"""
mutable struct PunchModalData
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
    PunchData

Nastran punch file modal data load format.
"""
struct PunchData
    modal::Vector{PunchModalData}
    node::Vector{Int}
end

"""
    readpch(file::String)

Read Nastran punch file. Return data object. This should be avoided, in favour of HDF5, but is included for existing result files.

Only supports real modal data from SOL103. Not very elegant, nor efficient. Use HDF5 instead.

# Reference
[MSC Nastran 2017.1 Reference Manual](https://simcompanion.mscsoftware.com/infocenter/index?page=content&id=DOC11313&cat=MSC_NASTRAN_DOCUMENTATION_2017.1&actp=LIST)(visited on 2017-10-14)
"""
function readpch(file::String)
    data_modal = Vector{PunchModalData}(undef, 0)
    node = Vector{Int}(undef, 0)

    lines = readlines(file)

    cnew = false
    index = 1
    tmp = PunchModalData()
    for line in lines
        line = line[1:PCHLL]
        isdollar = line[1] == '\$'

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

    return PunchData(data_modal, node)
end

"""
    collect(data::PunchData)

Collect all modal data into a matrix.
"""
function collect(data::PunchData)
    n, m = length(data.modal[1].eigenvector), length(data.modal)
    d = Matrix{Float64}(undef, n, m)
    for i in 1:m
        d[:, i] = data.modal[i].eigenvector
    end

    return d
end