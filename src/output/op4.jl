"""
    readop4(filename::String)
    readop4(filename::String, matname::String)

Read Nastran binary op4 file into sparse matrices. Either find matrix names (no matname) or find specific matrix.
"""
function readop4(filename::String)
    mat_out = readop4(filename, MAT_NAMES)

    matname = Vector{String}(undef, 0)
    for i in mat_out
        push!(matname, i[1])
    end

    return matname
end

function readop4(filename::String, matname::String)
    file = FortranFiles.FortranFile(filename)

    mat_out = Dict()

    while !eof(file.io)
        (ncol, nrow, mform, mtype, mname) = FortranFiles.read(file,
        Int32, Int32, Int32, Int32, FortranFiles.FString{8})
        mname = FortranFiles.trimstring(mname)

        colptr = zeros(Int32, ncol + 1)#Vector{Int32}(ncol + 1)
        rowind = Vector{Int32}(undef, 0)
        data = Vector{Float64}(undef, 0)

        # pre allocate and then resize!, maybe not worth the effort
        sizehint!(rowind, 2ncol)
        sizehint!(data, 2ncol)

        readop4!(file, matname, mat_out, data, colptr, rowind, ncol, nrow, mname)
    end

    return mat_out
end

"""
    readop4!(file::FortranFiles.FortranFile, matname::String, mat_out::Dict,
    data::Vector, colptr::Vector, rowind::Vector, ncol::Int32, nrow::Int32, mname::String)

Read Nastran binary op4 file and populate sparse matrix.
"""
function readop4!(file::FortranFiles.FortranFile, matname::String, mat_out::Dict,
    data::Vector, colptr::Vector, rowind::Vector, ncol::Int32, nrow::Int32, mname::String)

    icol_count::Int32 = 1
    if mname == matname || matname == "ALL"
        while true
            @fread file icol::Int32 irow::Int32 nword::Int32 iline::Array{Int32}(undef, nword)

            p::Int32 = 1
            m::Int32 = 1

            if icol > ncol
                # read one extra line after end to terminate matrix
                colptr[ncol+1] = length(rowind) + 1
                fillcolptr!(colptr, icol, icol_count)
                mat_out[mname] = SparseMatrixCSC(nrow, ncol, convert(Vector{Int}, colptr), convert(Vector{Int}, rowind), data)
                break
            end

            if ncol < COL #|| nrow > 0 # small matrix, comment for now version diff.
                while p <= nword
                    if p == 1
                        colptr[icol] = length(rowind) + 1
                    end
                    slength = getlength(iline[p])
                    wsize = Int32(slength/2)
                    irow = getirow(iline[p])
                    #println("p: ", p, ", irow: ", irow, ", slength: ", slength, ", wsize: ", wsize, ", nword: ", nword)

                    append!(rowind, irow:(irow + wsize - 1))
                    append!(data, reinterpret(Float64, iline[(p + 1):(p + slength)]))

                    p = p + slength + 1
                end
            else # big matrix
                line = reinterpret(Float64, iline)
                while p <= nword
                    if p == 1
                        colptr[icol] = length(rowind) + 1
                    end
                    slength = iline[p] - 1
                    irow = iline[p+1]
                    wsize = Int32(slength/2)
                    #println("p: ", p, ", m: " , m, ", irow: ", irow, ", slength: ", slength, ", wsize: ", wsize)

                    append!(rowind, irow:(irow + wsize - 1))
                    append!(data, line[(m + 1):(m + wsize)])

                    p = p + slength + 2
                    m = m + wsize + 1
                end
            end

            # correct col_ptr
            fillcolptr!(colptr, icol, icol_count)
            icol_count = icol + 1

        end
    else
        # not sough matrix, keep looking
        icol2::Int32 = 1
        while icol2 < ncol+1
            # spool forward
            icol2 = FortranFiles.read(file, Int32)
        end

        if matname == "NAMES"
            mat_out[mname] = sparse([0])
        end
    end

    nothing
end

getlength(head) = trunc(Int32, head*iCOL) - 1
getirow(head) = head - COL*(getlength(head) + 1)

function fillcolptr!(colptr, icol, icol_count)
    while icol_count < icol
        colptr[icol_count] = colptr[icol]
        icol_count = icol_count + 1
    end
end

# 0.7 beta fix for now
# function append2!(x, y)
#     for yi in y
#         push!(x, yi)
#     end
# end
