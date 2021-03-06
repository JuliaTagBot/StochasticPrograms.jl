"""
    SAA

Default `SampledSolver`. Generates a `StochasticSolution` using the sample average approximation (SAA) method, to the desired confidence level.
"""
struct SAA{S <: SPSolverType} <: AbstractSampledSolver
    internal_solver::S

    function SAA(solver::SPSolverType)
        if isa(solver, JuMP.UnsetSolver)
            error("Cannot solve emerging SAA problems without functional solver.")
        end
        S = typeof(solver)
        return new{S}(solver)
    end
end
"""
    SAA(; solver::SPSolverType = JuMP.UnsetSolver())

Return an SAA where the emerging SAA problems are solved using `solver`.
"""
function SAA(; solver::SPSolverType = JuMP.UnsetSolver())
    return SAA(solver)
end

mutable struct SAAModel{M <: StochasticModel, S <: SPSolverType} <: AbstractSampledModel
    stochasticmodel::M
    solver::S
    solution::StochasticSolution
    saa::StochasticProgram

    function SAAModel(stochasticmodel::StochasticModel, solver::SPSolverType)
        M = typeof(stochasticmodel)
        S = typeof(solver)
        return new{M, S}(stochasticmodel, solver, EmptySolution())
    end
end

function SampledModel(stochasticmodel::StochasticModel, solver::SAA)
    return SAAModel(stochasticmodel, solver.internal_solver)
end

function optimize_sampled!(saamodel::SAAModel, sampler::AbstractSampler, confidence::AbstractFloat; M::Integer = 10, T::Integer = 10, Ñ::Integer = 1000, tol::AbstractFloat = 1e-2, Ninit::Int = 16, Nmax::Integer = 5000, solver_config::Function = (solver,N)->nothing, log = true)
    sm = saamodel.stochasticmodel
    solver = saamodel.solver
    N = Ninit
    α = 1-confidence
    progress = ProgressThresh(tol, 0.0, "SAA gap")
    log && ProgressMeter.update!(progress, Inf,
                                 showvalues = [
                                     ("Confidence interval", NaN),
                                     ("Relative error", Inf),
                                     ("Sample size", NaN),
                                     ("Current sample size", N)
                                 ])
    while true
        CI = confidence_interval(sm, sampler; solver = solver, confidence = 1-α, N = N, M = M, Ñ = max(N, Ñ), T = T, log = log, keep = false, offset = 6, indent = 4)
        Q = (upper(CI) + lower(CI))/2
        gap = length(CI)/abs(Q+1e-10)
        log && ProgressMeter.update!(progress, gap,
                                     showvalues = [
                                         ("Confidence interval", CI),
                                         ("Relative error", gap),
                                         ("Sample size", N),
                                         ("Current sample size", 2*N)
                                     ])
        if gap <= tol
            sp = sample(sm, sampler, N)
            optimize!(sp, solver = solver)
            Q = optimal_value(sp)
            while !(Q ∈ CI)
                sp = sample(sm, sampler, N)
                optimize!(sp, solver = solver)
                Q = optimal_value(sp)
            end
            saamodel.solution = StochasticSolution(optimal_decision(sp), Q, N, CI)
            saamodel.saa = sp
            return :Optimal
        end
        N = N * 2
        if N > Nmax
            return :LimitReached
        end
        solver_config(solver, N)
    end
end

function internal_solver(solver::SAA)
    return internal_solver(solver.internal_solver)
end

function stochastic_solution(saamodel::SAAModel)
    return saamodel.solution
end
