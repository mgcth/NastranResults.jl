module SDNastran

# Load packages
# [Julia]
#using Nastran
using SparseArrays

# [Community]
using FortranFiles

# Include constants
include("misc.jl")

# Include input files
#include("input/input_file.jl")

# Include output files
include("output/op4.jl")
include("output/hdf5.jl")
include("output/punch.jl")

# Package code goes here

end # module
