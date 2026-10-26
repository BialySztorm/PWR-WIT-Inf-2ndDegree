# Task 3 CLI: tune ACO parameters, compare with task 2's best GA result.
# Usage: julia --project=. src/run.jl <tune|compare|plots>

include("Instance.jl")
include("Decoder.jl")
include("Baseline.jl")
include("ACO.jl")

using .InstanceMod
using .DecoderMod
using .BaselineMod
using .ACOMod

using CSV
using Plots
using JSON3

const DATA_DIR = joinpath("..", "data")
const RESULTS_DIR = joinpath("..", "results")
const ROUTES_DIR = joinpath(RESULTS_DIR, "routes")
const PLOTS_DIR = joinpath("..", "plots", "task3-julia")
const TUNING_CSV = joinpath(RESULTS_DIR, "task3_julia_aco_tuning.csv")
const FINAL_CSV = joinpath(RESULTS_DIR, "task3_julia_aco_final.csv")
const GA_CSV = joinpath(RESULTS_DIR, "task2_rust_ga.csv")

const ANTS = 15
const K_NEIGHBORS = 16
const ITERATIONS = 60
const STALL = 20

# Documented task3 winner (see julia-aco/RESULTS.md): alpha=1.0, beta=5.0, rho=0.3.
const BEST_ACO = (alpha = 1.0, beta = 5.0, rho = 0.3)
best_aco_config_id() = "alpha=$(BEST_ACO.alpha)_beta=$(BEST_ACO.beta)_rho=$(BEST_ACO.rho)"

# Reads the shared data/instances.json manifest (see scripts/fetch_terrain.py
# and go-ga/cmd/dronega/main.go), which lists which instance files exist
# across all 3 solver pipelines.
function slugs_by_type(types...)
    path = joinpath(DATA_DIR, "instances.json")
    if !isfile(path)
        return String[]
    end
    registry = JSON3.read(path)
    [string(e.slug) for e in registry.instances if string(e.type) in types]
end

struct TuneCombo
    alpha::Float64
    beta::Float64
    rho::Float64
end

tuning_grid() = [
    TuneCombo(a, b, r)
    for a in (1.0, 2.0), b in (2.0, 5.0), r in (0.1, 0.3)
][:]

config_id(c::TuneCombo) = "alpha=$(c.alpha)_beta=$(c.beta)_rho=$(c.rho)"

function write_header(io)
    println(io, "instance,method,config_id,seed,generation,evaluations,best_cost,avg_cost,feasible")
end

function write_run_rows(io, instance_name, method, cfg_id, seed, result::ACOResult)
    for h in result.history
        println(io, "$instance_name,$method,$cfg_id,$seed,$(h.iteration),$(result.evaluations),$(h.best_cost),$(h.avg_cost),$(result.best_cost.feasible)")
    end
end

function tune()
    mkpath(RESULTS_DIR)
    open(TUNING_CSV, "w") do io
        write_header(io)
        for name in slugs_by_type("synthetic")
            inst = load_instance(joinpath(DATA_DIR, "$name.json"))
            cells = included_cells(inst)

            base_order = boustrophedon(inst)
            base_cost = decode_order(base_order, inst)
            println("[$name] baseline (boustrophedon): total=$(round(base_cost.total, digits=1))s feasible=$(base_cost.feasible)")

            combos = tuning_grid()
            println("[$name] tuning $(length(combos)) combos x 10 seeds...")
            for c in combos
                cfg_id = config_id(c)
                for seed in 0:9
                    cfg = ACOConfig(ANTS, ITERATIONS, STALL, c.alpha, c.beta, c.rho, K_NEIGHBORS, seed)
                    res = run_aco(inst, cells, cfg)
                    write_run_rows(io, name, "aco_tuning", cfg_id, seed, res)
                end
            end
            flush(io)
        end
    end
    println("wrote $TUNING_CSV")
end

function final_means(path, instance_filter)
    by_config_seed = Dict{String,Dict{String,Float64}}()
    for row in CSV.File(path)
        if row.instance != instance_filter
            continue
        end
        d = get!(by_config_seed, row.config_id, Dict{String,Float64}())
        d[string(row.seed)] = row.best_cost # later (higher generation/iteration) rows overwrite earlier ones
    end
    means = [(cfg, sum(values(seeds)) / length(seeds)) for (cfg, seeds) in by_config_seed]
    sort!(means, by = x -> x[2])
    means
end

function best_combo_for(instance_name)
    means = final_means(TUNING_CSV, instance_name)
    cfg_str, _ = means[1]
    m = match(r"alpha=([\d.]+)_beta=([\d.]+)_rho=([\d.]+)", cfg_str)
    TuneCombo(parse(Float64, m[1]), parse(Float64, m[2]), parse(Float64, m[3]))
end

function run_final()
    mkpath(RESULTS_DIR)
    open(FINAL_CSV, "w") do io
        write_header(io)
        for name in slugs_by_type("synthetic")
            inst = load_instance(joinpath(DATA_DIR, "$name.json"))
            cells = included_cells(inst)
            best = best_combo_for(name)
            cfg_id = "best_" * config_id(best)
            println("[$name] best ACO combo from tuning: $cfg_id")
            for seed in 0:9
                cfg = ACOConfig(ANTS, ITERATIONS, STALL, best.alpha, best.beta, best.rho, K_NEIGHBORS, seed)
                res = run_aco(inst, cells, cfg)
                write_run_rows(io, name, "aco_best", cfg_id, seed, res)
            end
            flush(io)
        end
    end
    println("wrote $FINAL_CSV")
end

function compare()
    println("\n=== ACO (task 3) vs GA (task 2) — final comparison ===")
    for name in slugs_by_type("synthetic", "real")
        aco_means = final_means(FINAL_CSV, name)
        aco_cfg, aco_cost = aco_means[1]

        ga_means = final_means(GA_CSV, name)
        ga_cfg, ga_cost = ga_means[1]

        aco_evals = ANTS * ITERATIONS
        ga_evals = 20 * (150 + 1) # pop_size * (max_generations + 1), see go-ga/rust-ga configs

        println("\n[$name]")
        println("  GA  best: $ga_cfg  avg_best_cost=$(round(ga_cost, digits=1))  evaluations<=$ga_evals")
        println("  ACO best: $aco_cfg  avg_best_cost=$(round(aco_cost, digits=1))  evaluations<=$aco_evals")
        winner = ga_cost < aco_cost ? "GA" : "ACO"
        println("  Winner by cost: $winner")
    end
end

function make_plots()
    mkpath(PLOTS_DIR)
    for name in slugs_by_type("synthetic", "real")
        aco_means = final_means(FINAL_CSV, name)
        aco_cfg, _ = aco_means[1]
        ga_means = final_means(GA_CSV, name)
        ga_cfg, _ = ga_means[1]

        # ACO: mean best_cost per iteration, across seeds, for the winning config.
        aco_sum = Dict{Int,Tuple{Float64,Int}}()
        for row in CSV.File(FINAL_CSV)
            if row.instance == name && row.config_id == aco_cfg
                s, n = get(aco_sum, row.generation, (0.0, 0))
                aco_sum[row.generation] = (s + row.best_cost, n + 1)
            end
        end
        aco_points = sort([(it, s / n) for (it, (s, n)) in aco_sum])
        aco_x = [ANTS * it for (it, _) in aco_points]
        aco_y = [v for (_, v) in aco_points]

        # GA: mean best_cost per generation, across seeds, for the winning config.
        ga_sum = Dict{Int,Tuple{Float64,Int}}()
        for row in CSV.File(GA_CSV)
            if row.instance == name && row.config_id == ga_cfg
                s, n = get(ga_sum, row.generation, (0.0, 0))
                ga_sum[row.generation] = (s + row.best_cost, n + 1)
            end
        end
        ga_points = sort([(g, s / n) for (g, (s, n)) in ga_sum])
        ga_x = [20 * (g + 1) for (g, _) in ga_points]
        ga_y = [v for (_, v) in ga_points]

        p = plot(ga_x, ga_y, label = "GA best ($ga_cfg)", xlabel = "objective function evaluations", ylabel = "best cost (s)",
            title = "GA vs ACO — $name", legend = :topright, size = (900, 600))
        plot!(p, aco_x, aco_y, label = "ACO best ($aco_cfg)")
        outpath = joinpath(PLOTS_DIR, "ga_vs_aco_$name.png")
        savefig(p, outpath)
        println("wrote $outpath")
    end
end

function cost_to_dict(cb::CostBreakdown)
    Dict(
        "flight_time_s" => cb.flight_time_s,
        "turn_penalty" => cb.turn_penalty,
        "climb_cost" => cb.climb_cost,
        "battery_swaps" => cb.battery_swaps,
        "swap_before_step" => cb.swap_before_step,
        "violations" => cb.violations,
        "total" => cb.total,
        "feasible" => cb.feasible,
    )
end

function write_route_file(instance_name, method, cfg_id, order::Vector{Tuple{Int,Int}}, cost::CostBreakdown)
    rf = Dict(
        "instance" => instance_name,
        "method" => method,
        "config_id" => cfg_id,
        "order" => [[c[1], c[2]] for c in order],
        "cost" => cost_to_dict(cost),
    )
    path = joinpath(ROUTES_DIR, "$(instance_name)_$(method).json")
    open(path, "w") do io
        JSON3.write(io, rf)
    end
    println("wrote $path")
end

function gen_routes()
    mkpath(ROUTES_DIR)
    for name in slugs_by_type("synthetic", "real")
        inst = load_instance(joinpath(DATA_DIR, "$name.json"))
        cells = included_cells(inst)

        base_order = boustrophedon(inst)
        base_cost = decode_order(base_order, inst)
        write_route_file(name, "baseline", "boustrophedon", base_order, base_cost)

        cfg = ACOConfig(ANTS, ITERATIONS, STALL, BEST_ACO.alpha, BEST_ACO.beta, BEST_ACO.rho, K_NEIGHBORS, 0)
        res = run_aco(inst, cells, cfg)
        write_route_file(name, "aco_best", best_aco_config_id(), res.best_order, res.best_cost)
    end
end

function run_final_real()
    mkpath(RESULTS_DIR)
    cfg_id = best_aco_config_id()
    open(FINAL_CSV, "a") do io
        for name in slugs_by_type("real")
            inst = load_instance(joinpath(DATA_DIR, "$name.json"))
            cells = included_cells(inst)

            base_order = boustrophedon(inst)
            base_cost = decode_order(base_order, inst)
            println("[$name] baseline (boustrophedon): total=$(round(base_cost.total, digits=1))s feasible=$(base_cost.feasible)")

            println("[$name] running best ACO combo x 10 seeds...")
            for seed in 0:9
                cfg = ACOConfig(ANTS, ITERATIONS, STALL, BEST_ACO.alpha, BEST_ACO.beta, BEST_ACO.rho, K_NEIGHBORS, seed)
                res = run_aco(inst, cells, cfg)
                write_run_rows(io, name, "aco_real_best", cfg_id, seed, res)
            end
            flush(io)
        end
    end
    println("appended real-instance runs to $FINAL_CSV")
end

function main()
    if length(ARGS) < 1
        println("usage: julia --project=. src/run.jl <tune|final|compare|plots|routes|final-real>")
        exit(1)
    end
    cmd = ARGS[1]
    if cmd == "tune"
        tune()
    elseif cmd == "final"
        run_final()
    elseif cmd == "compare"
        compare()
    elseif cmd == "plots"
        make_plots()
    elseif cmd == "routes"
        gen_routes()
    elseif cmd == "final-real"
        run_final_real()
    else
        println("unknown command: $cmd")
        exit(1)
    end
end

main()
