@info "Running functionality tests..."
@testset "Stochastic Programs: Functionality" begin
    @testset "SP Constructs: $name" for (sp,res,name) in problems
        tol = 1e-2
        @test optimize!(sp) == :Optimal
        @test isapprox(optimal_decision(sp), res.x̄, rtol = tol)
        @test isapprox(optimal_value(sp), res.VRP, rtol = tol)
        @test isapprox(EWS(sp), res.EWS, rtol = tol)
        @test isapprox(EVPI(sp), res.EVPI, rtol = tol)
        @test isapprox(VSS(sp), res.VSS, rtol = tol)
        @test isapprox(EV(sp), res.EV, rtol = tol)
        @test isapprox(EEV(sp), res.EEV, rtol = tol)
    end
    @testset "Inequalities: $name" for (sp,res,name) in problems
        @test EWS(sp) <= VRP(sp)
        @test VRP(sp) <= EEV(sp)
        @test VSS(sp) >= 0
        @test EVPI(sp) >= 0
        @test VSS(sp) <= EEV(sp)-EV(sp)
        @test EVPI(sp) <= EEV(sp)-EV(sp)
    end
    @testset "Deferred model creation" begin
        @test decision_length(deferred) == 0
        @test nscenarios(deferred) == 2
        @test nsubproblems(deferred) == 0
        @test optimize!(deferred) == :Optimal
        @test decision_length(deferred) == 2
        @test nscenarios(deferred) == 2
        @test nsubproblems(deferred) == 2
        @test isapprox(optimal_value(deferred), -855.83, rtol = 1e-2)
    end
    @testset "Copying: $name" for (sp,res,name) in problems
        tol = 1e-2
        sp_copy = copy(sp)
        add_scenarios!(sp_copy, scenarios(sp))
        @test nscenarios(sp_copy) == nscenarios(sp)
        generate!(sp_copy)
        @test nsubproblems(sp_copy) == nsubproblems(sp)
        @test optimize!(sp_copy) == :Optimal
        optimize!(sp)
        @test isapprox(optimal_decision(sp_copy), optimal_decision(sp), rtol = tol)
        @test isapprox(optimal_value(sp_copy), optimal_value(sp), rtol = tol)
        @test isapprox(EWS(sp_copy), EWS(sp), rtol = tol)
        @test isapprox(EVPI(sp_copy), EVPI(sp), rtol = tol)
        @test isapprox(VSS(sp_copy), VSS(sp), rtol = tol)
        @test isapprox(EV(sp_copy), EV(sp), rtol = tol)
        @test isapprox(EEV(sp_copy), EEV(sp), rtol = tol)
    end
    @testset "Sampling" begin
        sampled_sp = sample(simple_model, sampler, 100, solver=GLPKSolverLP())
        @test nscenarios(sampled_sp) == 100
        @test nsubproblems(sampled_sp) == 100
        @test isapprox(stage_probability(sampled_sp), 1.0)
        sample!(sampled_sp, sampler, 100)
        @test nscenarios(sampled_sp) == 200
        @test nsubproblems(sampled_sp) == 200
        @test isapprox(stage_probability(sampled_sp), 1.0)
    end
    @testset "Confidence intervals" begin
        glpk = GLPKSolverLP()
        try
            CI = confidence_interval(simple_model, sampler, solver = glpk, N = 200, log = false)
            @test lower(CI) <= upper(CI)
        catch end
        sol = optimize!(simple_model, sampler, solver = glpk, confidence = 0.95, tol = 1e-1, log = false)
        @test lower(confidence_interval(sol)) <= upper(confidence_interval(sol))
    end
end
