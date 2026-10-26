# Task 3 — ACO (Julia) results

## Baseline sanity check

Boustrophedon baseline cost matches the Go/Rust runs exactly, confirming the
Julia decoder/instance loader is a faithful port:

| instance | baseline total (s) |
|---|---|
| flat  | 4757.2 |
| hilly | 6472.8 |

## Parameter tuning

Grid: `alpha ∈ {1, 2}`, `beta ∈ {2, 5}`, `rho ∈ {0.1, 0.3}` (8 combos), 5 seeds
each, `ants=15`, `iterations<=60`, `stall_iterations=20`, `k_neighbors=16`.
Results in `../results/task3_julia_aco_tuning.csv`.

Best combo on both instances: **alpha=1.0, beta=5.0, rho=0.3** — a strong
heuristic weight (beta=5) dominating a weak pheromone trail (alpha=1), with
fast evaporation (rho=0.3) so the colony doesn't get stuck reinforcing an
early, mediocre tour. This matches expectations for a 1200-node instance with
a geometrically meaningful heuristic (distance + climb-penalized nearest
neighbor): the η term alone is already a good greedy signal, so letting it
dominate works better than trusting slowly-built pheromone trails.

Re-run with the winning combo, 10 seeds, in `../results/task3_julia_aco_final.csv`.

## ACO vs GA comparison (by evaluations, not wall-clock time)

Per `lab-objectives.md` §6, the comparison uses evaluation count since task 2
(Rust) and task 3 (Julia) run in different languages and wall-clock time
would not be a fair metric.

| instance | GA best avg_best_cost | GA evaluations | ACO best avg_best_cost | ACO evaluations | winner |
|---|---|---|---|---|---|
| flat  | 69013.3 | ≤3020 | **8522.6**  | ≤900 | ACO |
| hilly | 77157.0 | ≤3020 | **10184.2** | ≤900 | ACO |

ACO wins by roughly 8x on both instances, using less than a third of the
evaluation budget GA used. See `../plots/task3-julia/ga_vs_aco_{flat,hilly}.png`.

### Why ACO wins here

This coverage-path problem is close to a geometric TSP: cost is dominated by
flight distance, turning, and climbing between *spatially local* cells. ACO's
candidate-list + heuristic (η = 1/(distance + climb_penalty)) bakes that
locality directly into tour construction — every step is a locally-informed
greedy-ish choice. The GA from tasks 1–2, by contrast, only has random-keys
crossover/mutation acting on an arbitrary permutation encoding with no
notion of geometric adjacency; it has to *discover* locality purely through
selection pressure over generations, which is far slower for a ~1200-node
problem. This is consistent with the task 1/2 finding that a basic GA
without local-search-style operators struggles to approach the boustrophedon
baseline at all, while ACO (with its local heuristic) gets much closer in
far fewer evaluations.

### Terrain irregularity (flat vs hilly)

The GA/ACO cost ratio is 8.10x on flat vs 7.58x on hilly — ACO's relative
advantage shrinks slightly, not grows, with terrain irregularity. This is
the opposite of the naive hypothesis ("ACO's local heuristic should matter
more when terrain is harder"). A likely explanation: the climb penalty is
already folded into ACO's η for every candidate edge regardless of terrain,
so ACO exploits it equally well on both instances; the GA, meanwhile, has no
terrain-aware operator at all, so its relative handicap is roughly constant
and terrain-independent. The gap would likely behave differently with a
terrain-aware GA operator (e.g. a hill-avoiding greedy crossover), which is
out of scope for the base GA implemented in tasks 1–2.

## Real-world instances

Best ACO combo (`alpha=1.0, beta=5.0, rho=0.3`) and the best GA config
re-run on `real_canyon`/`real_silesia`, 10 seeds each
(`julia --project=. src/run.jl final-real`, `rust-ga -- run-real`). See
`../plots/task3-julia/ga_vs_aco_real_{canyon,silesia}.png`.

| instance | baseline total (s) | GA avg total (s) | ACO avg total (s) | feasible |
|---|---|---|---|---|
| real_canyon | 16,081,212.5 | ~16,297,000 | 16,081,012.3 | **false** (all) |
| real_silesia | 9,928.2 | ~92,300 | 12,366.9 | true (all) |

Unlike `flat`/`hilly`, baseline is not beaten here — this is a different,
distinct finding from the "ACO wins by ~8x" result above, not a
continuation of it:

- **`real_canyon` is infeasible for every method, including the baseline.**
  The canyon terrain pushes the drone's AGL-relative altitude above
  `drone_max_rel_takeoff_m` by a large, order-independent amount (≈300k s of
  accumulated violation, weighted ×50), which dominates every method's total
  almost identically. ACO essentially ties the baseline here (16,081,012 vs
  16,081,212) because the dominant term doesn't depend on tour order; GA is
  measurably worse, for the same reason it underperforms on `flat`/`hilly` —
  no local-search operator.
- **`real_silesia` is feasible, and here the deterministic boustrophedon
  baseline wins outright** (9,928 s vs ACO's 12,367 s vs GA's ~92,300 s).
  ACO still clearly beats GA (its candidate-list heuristic captures spatial
  locality that the GA's unconstrained permutation encoding can't), but it
  no longer beats the baseline the way it did on `flat`/`hilly`. The most
  likely explanation is instance-specific: `real_silesia`'s terrain/grid
  shape may favor a simple raster sweep (few turns, low swap count — 8 for
  baseline vs 9 for ACO) more than the synthetic flat/hilly grids did,
  narrowing ACO's advantage to the point baseline edges ahead.

## Caveat

The `evaluations` column in both the task 2 (Rust) and task 3 (Julia) CSVs
stores each run's *final total* evaluations repeated on every row, not a
per-generation/per-iteration cumulative count. The comparison plots instead
compute cumulative evaluations analytically from the known constant batch
size (`pop_size=20` per GA generation, `ants=15` per ACO iteration), which is
exact since both batch sizes are fixed for the whole run.
