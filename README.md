# SDNastran

[![Build Status](https://travis-ci.org/mgcth/SDNastran.jl.svg?branch=master)](https://travis-ci.org/mgcth/SDNastran.jl)
[![Coverage Status](https://coveralls.io/repos/mgcth/SDNastran.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/mgcth/SDNastran.jl?branch=master)
[![codecov.io](http://codecov.io/github/mgcth/SDNastran.jl/coverage.svg?branch=master)](http://codecov.io/github/mgcth/SDNastran.jl?branch=master)

A Nastran file loader for Julia with support for op4 output data loading.

## Installation
To install, write in the Julia REPL

```julia
julia> ] add https://github.com/mgcth/SDNastran.jl.git
```

## Documentation
Support for input and output data loading.

### Input
A full model loader, as implemented by [drewkett/Nastran.jl](https://github.com/drewkett/Nastran.jl) can be used.

### Output
Currently only an op4 (OUTPUT4) loader is implemented supporting real double precision binary sparse non-BIGMAT and BIGMAT matrices and a SOL103 punch reader.

### Usage
Example of usage

```julia
julia> import SDNastran
julia> const nl = SDNastran

# find matrices in file, output vector of strings
julia> mnames = nl.readop4("filename.op4");
julia> mnames[1]
"KAA"

# load specific matrix
julia> mat = nl.readop4("filename.op4", "KAA");

# load all matrices in a vector of tuples (name, matrix))
julia> mat = nl.readop4("filename.op4", "ALL");

# read punchfile
julia> mat = nl.readpunch("filename.pch");
```

## Roadmap
- Improve performance of op4 loader
- Reading punch files (possibly skip this and use HDF5 instead)
- Reading HDF5 result files
- Add testing
