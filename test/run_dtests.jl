using Base.Test
include(joinpath(Base.JULIA_HOME, "..", "share", "julia", "test", "testenv.jl"))
addprocs_with_testenv(3)
@test nworkers() == 3

@everywhere using StochasticPrograms
using JuMP
using GLPKMathProgInterface

@everywhere import StochasticPrograms: probability, expected

struct SPResult
    x̄::Vector{Float64}
    VRP::Float64
    EWS::Float64
    EVPI::Float64
    VSS::Float64
    EV::Float64
    EEV::Float64
end

problems = Vector{Tuple{JuMP.Model,SPResult,String}}()
info("Loading test problems...")
info("Loading simple...")
include("simple.jl")
info("Loading farmer...")
include("farmer.jl")
info("Preparing simple sampler...")
include("sampling.jl")
info("Test problems loaded. Starting test sequence.")
@testset "Distributed Stochastic Programs" begin
    @testset "Distributed Sanity Check: $name" for (sp,res,name) in problems
        solve(sp)
        sp_nondist = StochasticProgram(first_stage_data(sp),second_stage_data(sp),scenarios(sp),procs=[1])
        transfer_model!(stochastic(sp_nondist),stochastic(sp))
        generate!(sp_nondist)
        solve(sp_nondist,solver=GLPKSolverLP())
        @test scenariotype(sp) == scenariotype(sp_nondist)
        @test abs(probability(sp)-probability(sp_nondist)) <= 1e-6
        @test nscenarios(sp) == nscenarios(sp)
        @test nsubproblems(sp) == nsubproblems(sp_nondist)
        @test norm(optimal_decision(sp)-optimal_decision(sp_nondist)) <= 1e-6
        @test abs(optimal_value(sp)-optimal_value(sp_nondist)) <= 1e-6
    end
    @testset "Distributed SP Constructs: $name" for (sp,res,name) in problems
        solve(sp)
        @test norm(optimal_decision(sp)-res.x̄) <= 1e-2
        @test abs(optimal_value(sp)-res.VRP) <= 1e-2
        @test abs(EWS(sp)-res.EWS) <= 1e-2
        @test abs(EVPI(sp)-res.EVPI) <= 1e-2
        @test abs(VSS(sp)-res.VSS) <= 1e-2
        @test abs(EV(sp)-res.EV) <= 1e-2
        @test abs(EEV(sp)-res.EEV) <= 1e-2
    end
    @testset "Distributed Inequalities: $name" for (sp,res,name) in problems
        @test EWS(sp) <= VRP(sp)
        @test VRP(sp) <= EEV(sp)
        @test VSS(sp) >= 0
        @test EVPI(sp) >= 0
        @test VSS(sp) <= EEV(sp)-EV(sp)
        @test EVPI(sp) <= EEV(sp)-EV(sp)
    end
    @testset "Distributed Sampling" begin
        @test nscenarios(sampled_sp) == 0
        @test nsubproblems(sampled_sp) == 0
        sample!(sampled_sp,100)
        @test nscenarios(sampled_sp) == 100
        @test nsubproblems(sampled_sp) == 100
        @test abs(probability(sampled_sp)-1.0) <= 1e-6
        sample!(sampled_sp,100)
        @test nscenarios(sampled_sp) == 200
        @test nsubproblems(sampled_sp) == 200
        @test abs(probability(sampled_sp)-1.0) <= 1e-6
    end
end
