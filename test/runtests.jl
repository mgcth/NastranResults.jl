using Test
using SDNastran

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

# these tests look more like integration tests but ok for now 
@testset "Test OP4  " begin
    unit_test_readop4_nofile()
    unit_test_readop4_nonames()
    unit_test_readop4_nomatrix()
    unit_test_readop4_MAA()
    unit_test_readop4_KAA()
    unit_test_readop4_ALL()
    unit_test_readop4_correct()
end

@testset "Test PUNCH" begin
    @test true    
end

@testset "Test HDF5 " begin
    @test true
end