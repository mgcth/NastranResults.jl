"""
    readop4(filename::String)

Searc file and find matrix names (no matname) in Nastran binary OP4 file.
"""
function readop4(filename::String)
    matrices = readop4(filename, MAT_NAMES)

    return collect(keys(matrices))
end

"""
    readop4(filename::String, matname::String)

Read specified matrix `matname` from Nastran binary OP4 file into sparse matrices. 
"""
function readop4(filename::String, matname::String)
    file = FortranFiles.FortranFile(filename)

    matrices = Dict{String, Union{SparseMatrixCSC, Nothing}}()

    while !eof(file.io)
        (ncol, nrow, mform, mtype, mname) = FortranFiles.read(file, Int32, Int32, Int32, Int32, FortranFiles.FString{8})
        mname = FortranFiles.trimstring(mname)

        colptr = zeros(Int32, ncol + 1)#Vector{Int32}(ncol + 1)
        rowind = Vector{Int32}(undef, 0)
        data = Vector{Float64}(undef, 0)

        # pre allocate and then resize!, maybe not worth the effort
        sizehint!(rowind, 2ncol)
        sizehint!(data, 2ncol)

        icol_count::Int32 = 1
        if mname == matname || matname == MAT_ALL
            icol_count, matrices[mname] = readop4!(file, data, icol_count, colptr, rowind, ncol, nrow)
        else
            # not sough matrix, keep looking
            spool!(file, ncol)
    
            if matname == MAT_NAMES
                matrices[mname] = nothing
            end
        end
    end

    if isempty(matrices)
        println("No matrices found, try searching the file for available matrices.")
    end


    return matrices
end

"""
    readop4!(
        file::FortranFiles.FortranFile,
        data::Vector,
        icol_count::Int32,
        colptr::Vector,
        rowind::Vector,
        ncol::Int32,
        nrow::Int32,
    )

Read Nastran binary OP4 file and populate sparse matrix.
"""
function readop4!(
    file::FortranFiles.FortranFile,
    data::Vector,
    icol_count::Int32,
    colptr::Vector,
    rowind::Vector,
    ncol::Int32,
    nrow::Int32,
)
    while true
        @fread file icol::Int32 irow::Int32 nword::Int32 iline::Array{Int32}(undef, nword)

        p::Int32 = 1
        m::Int32 = 1

        if icol > ncol
            # read one extra line after end to terminate matrix
            colptr[ncol + 1] = length(rowind) + 1
            fillcolptr!(colptr, icol, icol_count)
            return icol_count, SparseMatrixCSC(nrow, ncol, convert(Vector{Int}, colptr), convert(Vector{Int}, rowind), data)
        end

        if ncol < COL #|| nrow > 0 # small matrix, comment for now version diff.
            p = readsmallop4!(data, iline, p, nword, colptr, icol, rowind)
        else # big matrix
            p, m = readbigop4!(data, iline, p, nword, colptr, icol, rowind)
        end

        # correct col_ptr
        fillcolptr!(colptr, icol, icol_count)
        icol_count = icol + 1
    end
end

"""
    spool(file::FortranFiles.FortranFile, ncol::Int32)

If nothing found, keep looking for data.
"""
function spool!(file::FortranFiles.FortranFile, ncol::Int32)
    icol2::Int32 = 1
    while icol2 < ncol + 1
        # spool forward
        icol2 = FortranFiles.read(file, Int32)
    end

    return nothing
end

"""
    readsmallop4!(data, iline, p, nword, colptr, icol, rowind)

Read small OP4 matrix.
"""
function readsmallop4!(data, iline, p, nword, colptr, icol, rowind)
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

    return p
end

"""
    readbigop4!(data, iline, p, nword, colptr, icol, rowind)

Read big OP4 matrix.
"""
function readbigop4!(data, iline, p, nword, colptr, icol, rowind)
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

    return p, m
end

"""
    getlength(head::Int32)

Get record length, see Nastran documentation.
"""
getlength(head::Int32) = trunc(Int32, head*iCOL) - 1

"""
    getirow(head::Int32)

Get row index, see Nastran documentation.
"""
getirow(head::Int32) = head - COL*(getlength(head) + 1)

"""
    fillcolptr!(colptr, icol, icol_count)

Fill column pointer, see Nastran documentation.
"""
function fillcolptr!(colptr, icol, icol_count)
    while icol_count < icol
        colptr[icol_count] = colptr[icol]
        icol_count = icol_count + 1
    end
    
    return nothing
end