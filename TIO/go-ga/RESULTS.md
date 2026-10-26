# Task 1 — basic GA results

Problem: drone coverage-path-planning (see `../lab-objectives.md`). Grid 40x30
(1200 cells), cell size 25 m, AGL mode. Instances: `flat` (terrain = 0),
`hilly` (value-noise terrain, ~20 m relief, typical of Polish moraine hill
country).

Operators: random-keys chromosome, one-point crossover, reset mutation,
tournament selection (k=3). Population 20, max 150 generations, stop after
30 generations without improvement.

Run: `go run ./cmd/dronega gen-instances && go run ./cmd/dronega run && go run ./cmd/dronega summarize && go run ./cmd/dronega plots`

## Baseline (boustrophedon sweep)

| instance | total cost (s) |
|---|---|
| flat | 4757.2 |
| hilly | 6472.8 |

## GA sweep (p_c x p_m, 10 seeds each, mean final best cost)

See `plots/task1-go/final_cost_{flat,hilly}.png` and
`plots/task1-go/convergence_{flat,hilly}.png`, raw data in
`results/task1_go_ga.csv`.

## Findings

- The GA never beats the boustrophedon baseline (best ~69k s vs 4.8k s on
  `flat`). Expected: the chromosome is an unconstrained permutation over
  1200 cells — essentially a large TSP-like instance — and a basic GA with
  only one-point crossover + uniform reset mutation has no local-search
  pressure (no 2-opt, no spatial bias) to escape near-random tour quality
  within 150 generations at population 20. This motivates the inversion
  mutation (2-opt-like) added in task 2.
- `p_m = 0.05` is consistently the worst setting at every `p_c`, on both
  instances: too much per-generation disruption prevents the population
  from consolidating gains from crossover. `p_m ∈ {0.005, 0.01}` perform
  similarly, with `p_m = 0.005` slightly ahead late in the run.
- `p_c` has a smaller effect than `p_m` in this setup; `0.8`–`0.95` are
  marginally better than `0.6`, consistent with one-point crossover
  propagating good orderings more often at higher crossover probability.
- `hilly` costs run higher than `flat` across the board (extra climb-cost
  term), but the relative ranking of configs is the same on both instances.

## Real-world instances

Best config (`pc=0.950, pm=0.005`) re-run on the two real-terrain instances
(`real_canyon`, `real_silesia`), 10 seeds, via `go run ./cmd/dronega run-real`.
See `plots/task1-go/convergence_real_{canyon,silesia}.png`.

| instance | baseline total (s) | GA best avg total (s) | feasible |
|---|---|---|---|
| real_canyon | 16,081,212.5 | 16,300,012.3 | **false** (both) |
| real_silesia | 9,928.2 | 93,129.1 | true (both) |

- `real_canyon` is **infeasible for every method**, baseline included: the
  terrain forces the drone's AGL-relative altitude above
  `drone_max_rel_takeoff_m` on ~300k seconds' worth of accumulated violation,
  which dwarfs the rest of the cost (`W_VIOL=50` on top of it) regardless of
  visiting order — no reordering of cells can route around terrain that's
  simply too tall relative to the fixed takeoff point. This is a property of
  the instance/constraint combination, not a solver bug.
- `real_silesia` is feasible and reproduces the same gap seen on `flat`/
  `hilly`: the GA (~93.1k s) is roughly 9x worse than the deterministic
  boustrophedon baseline (~9.9k s), for the same reason — no local-search
  operator to escape near-random tour quality on a ~1200-cell permutation.
