"""
    PunchModalData
    PunchData

Nastran punch file modal data load format.
"""
struct PunchModalData
    mode::Int
    eigenvalue::Float64
    eigenvector::Array{Float64}
end

struct PunchData
    modal::Vector{PunchModalData}
    node::Vector{Int}
end

"""
    readpunch(filename::String)

Read MSC Nastran punch file. Return data object. This should be avoided, in favour of HDF5.

Only supports SOL103 and modal data, i.e. not M and K matrices. Should consider the columns, instead of relying on split(). Not very elegant, nor efficient. Use HDF5 instead.

# Reference
[MSC Nastran 2017.1 Reference Manual](https://simcompanion.mscsoftware.com/infocenter/index?page=content&id=DOC11313&cat=MSC_NASTRAN_DOCUMENTATION_2017.1&actp=LIST)(visited on 2017-10-14)
"""
function readpunch(filename::String)
    data_modal = Vector{PunchModalData}(undef, 0)
    node = Vector{Int}(undef, 0)

    open(filename) do f
        line = 1
        index = 1

        mode = 0
        eigenvalue = 0.0
        eigenvector = Matrix{Float64}(undef, 0, 6)

        tmp = Array{Float64}(undef, 1,3)
        tmp2 = Array{Float64}(undef, 1,3)
        while !eof(f)
            line_data = readline(f)
            x = split(line_data)

            if line_data[1] == '\$'
                # header section
                # save mode and eigenvalues
                if x[1] == "\$EIGENVALUE"
                    # push to data, from previous set
                    if index != 1
                        push!(data_modal, PunchModalData(mode, eigenvalue, eigenvector))

                        # flush variable
                        eigenvector = Matrix{Float64}(undef, 0, 6)
                    end

                    mode = parse(Int, x[6])
                    eigenvalue = parse(Float64, x[3])

                    index += 1;
                end

            elseif line_data[1] == ' '
                # data section
                # node ids must be same for every mode, only do once
                if index == 2
                    push!(node, parse(Int, x[1]))
                end

                tmp = [parse(Float64, x[3]) parse(Float64, x[4]) parse(Float64, x[5])]
            else
                # continuation of data line
                tmp2 = [parse(Float64, x[2]) parse(Float64, x[3]) parse(Float64, x[4])]
                eigenvector = vcat(eigenvector, [tmp tmp2])
            end

            line += 1

        end

        # last push to data
        push!(data_modal, PunchModalData(mode, eigenvalue, eigenvector))

    end

    # put into data
    data = PunchData(data_modal,node)

    return data

end
