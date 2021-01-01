using Test
using SDNastran

# need to implement this soon
function unit_test_readop4_nofile()
    @test true
end

function unit_test_readop4_names()
    @test true
end

function unit_test_readop4_nomatrix()
    @test true
end

function unit_test_readop4_MAA()
    @test true
end

function unit_test_readop4_KAA()
    @test true
end

function unit_test_readop4_ALL()
    @test true
end

function unit_test_readop4_correct()
    @test true
end

function unit_test_readpch_nofile()
    @test true
end

# these tests look more like integration tests but ok for now 
@testset "Test OP4  " begin
    unit_test_readop4_nofile()
    # need small test file
    #unit_test_readop4_nonames()
    #unit_test_readop4_nomatrix()
    #unit_test_readop4_MAA()
    #unit_test_readop4_KAA()
    #unit_test_readop4_ALL()
    #unit_test_readop4_correct()
end

@testset "Test PUNCH" begin
unit_test_readpch_nofile()  
end

#@testset "Test HDF5 " begin
#    @test true
#end