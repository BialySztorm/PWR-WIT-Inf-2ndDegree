module ACOMod

using Random

using ..InstanceMod: Instance
using ..DecoderMod: decode_order, CostBreakdown

export ACOConfig, IterStat, ACOResult, run_aco

struct ACOConfig
    ants::Int
    iterations::Int
    stall_iterations::Int
    alpha::Float64
    beta::Float64
    rho::Float64
    k_neighbors::Int
    seed::Int
end

struct IterStat
    iteration::Int
    best_cost::Float64
    avg_cost::Float64
end

struct ACOResult
    best_order::Vector{Tuple{Int,Int}}
    best_cost::CostBreakdown
    history::Vector{IterStat}
    evaluations::Int
end

"""
    candidate_lists(cells, cell_size_m, k)

For each cell, the indices (into `cells`) of its k nearest neighbours by
Euclidean grid distance. Needed so ant tour construction is O(n*k) instead of
O(n^2) per ant — standard "candidate list" restriction for ACO on larger
TSP-like instances.
"""
function candidate_lists(cells::Vector{Tuple{Int,Int}}, cell_size_m::Float64, k::Int)
    n = length(cells)
    xs = [c[1] * cell_size_m for c in cells]
    ys = [c[2] * cell_size_m for c in cells]
    lists = Vector{Vector{Int}}(undef, n)
    for i in 1:n
        dists = [hypot(xs[i] - xs[j], ys[i] - ys[j]) for j in 1:n]
        dists[i] = Inf
        order = partialsortperm(dists, 1:min(k, n - 1))
        lists[i] = collect(order)
    end
    lists
end

function heuristic_weights(cells::Vector{Tuple{Int,Int}}, heights::Vector{Float64}, cell_size_m::Float64, lists::Vector{Vector{Int}})
    n = length(cells)
    eta = Vector{Vector{Float64}}(undef, n)
    for i in 1:n
        xi, yi = cells[i][1] * cell_size_m, cells[i][2] * cell_size_m
        hi = heights[i]
        eta[i] = map(lists[i]) do j
            xj, yj = cells[j][1] * cell_size_m, cells[j][2] * cell_size_m
            dist = hypot(xi - xj, yi - yj)
            climb = max(0.0, heights[j] - hi)
            1.0 / (dist + 3.0 * climb + 1e-6)
        end
    end
    eta
end

function build_tour(rng, n, lists, tau, eta, alpha, beta, start::Int)
    order = Vector{Int}(undef, n)
    visited = falses(n)
    order[1] = start
    visited[start] = true
    cur = start

    weights = Float64[]
    idxs = Int[]
    for step in 2:n
        empty!(weights)
        empty!(idxs)
        for (pos, j) in enumerate(lists[cur])
            if !visited[j]
                w = tau[cur][pos]^alpha * eta[cur][pos]^beta
                push!(weights, w)
                push!(idxs, j)
            end
        end
        local next
        if isempty(idxs)
            # Candidate list exhausted: fall back to nearest unvisited cell.
            next = 0
            for j in 1:n
                if !visited[j]
                    next = j
                    break
                end
            end
        else
            total = sum(weights)
            if total <= 0
                next = idxs[rand(rng, 1:length(idxs))]
            else
                pick = rand(rng) * total
                acc = 0.0
                next = idxs[end]
                for (w, j) in zip(weights, idxs)
                    acc += w
                    if pick <= acc
                        next = j
                        break
                    end
                end
            end
        end
        order[step] = next
        visited[next] = true
        cur = next
    end
    order
end

function run_aco(inst::Instance, cells::Vector{Tuple{Int,Int}}, cfg::ACOConfig)
    rng = MersenneTwister(cfg.seed)
    n = length(cells)
    heights = [begin
        x, y = c
        inst.terrain[y * inst.width + x + 1]
    end for c in cells]

    lists = candidate_lists(cells, inst.cell_size_m, cfg.k_neighbors)
    eta = heuristic_weights(cells, heights, inst.cell_size_m, lists)

    avg_nn_dist = sum(1.0 / e for row in eta for e in row) / sum(length(row) for row in eta)
    tau0 = 1.0 / (n * max(avg_nn_dist, 1e-6))
    tau = [fill(tau0, length(lists[i])) for i in 1:n]

    evaluations = 0
    best_order_idx = Int[]
    best_cost = CostBreakdown(0, 0, 0, 0, Int[], 0, Inf, false)
    history = IterStat[]
    stall = 0

    for iter in 1:cfg.iterations
        iter_orders = Vector{Vector{Int}}(undef, cfg.ants)
        iter_costs = Vector{Float64}(undef, cfg.ants)
        iter_breakdowns = Vector{CostBreakdown}(undef, cfg.ants)

        for a in 1:cfg.ants
            start = rand(rng, 1:n)
            tour_idx = build_tour(rng, n, lists, tau, eta, cfg.alpha, cfg.beta, start)
            tour_cells = [cells[i] for i in tour_idx]
            cb = decode_order(tour_cells, inst)
            iter_orders[a] = tour_idx
            iter_costs[a] = cb.total
            iter_breakdowns[a] = cb
            evaluations += 1
        end

        # Evaporate, then deposit from the iteration-best ant only (elitist,
        # ACS-style — keeps pheromone contrast high with few ants).
        for i in 1:n
            tau[i] .*= (1 - cfg.rho)
        end
        best_a = argmin(iter_costs)
        deposit = 1.0 / iter_costs[best_a]
        tour_idx = iter_orders[best_a]
        for step in 1:n-1
            i, j = tour_idx[step], tour_idx[step+1]
            pos = findfirst(==(j), lists[i])
            if pos !== nothing
                tau[i][pos] += deposit
            end
        end

        if iter_costs[best_a] < best_cost.total
            best_cost = iter_breakdowns[best_a]
            best_order_idx = tour_idx
            stall = 0
        else
            stall += 1
        end
        push!(history, IterStat(iter, minimum(iter_costs), sum(iter_costs) / length(iter_costs)))
        if stall >= cfg.stall_iterations
            break
        end
    end

    best_order = [cells[i] for i in best_order_idx]
    ACOResult(best_order, best_cost, history, evaluations)
end

end # module
