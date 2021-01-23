# NastranResults

Load MSC Nastran OP4, PCH and HDF5 results into Julia.

## Installation
To install, write in the Julia REPL

```julia
julia> ]
pkg> add https://github.com/mgcth/NastranResults.jl.git
```

## Documentation
Support for output data loading, only. Currently supports:
* OP4 (OUTPUT4):
    * Supports real double precision binary sparse non-BIGMAT and BIGMAT matrices
* PCH (PUNCH, SORT2):
    * SOL103, real valued modal data
    * SOL108/111 complex frequency response data

### Usage
Example of usage

```julia
julia> using NastranResults

# find matrices in file, output vector of strings
julia> mnames = readop4("filename.op4");
julia> mnames[1]
"KAA"

# load specific matrix
julia> mat = readop4("filename.op4", "KAA");

# load all matrices in a vector of tuples (name, matrix))
julia> mat = readop4("filename.op4", "ALL");

# read SOL103 punchfile
julia> mat = readpch("filename.pch", PunchModalData);

# read SOL108/111 punchfile
julia> mat = readpch("filename.pch", PunchFrequencyData);
```

## Roadmap
- Add testing
- Improve performance of op4 loader
- Read more PCH types 
- Read HDF5 result, have code but needs structuring
