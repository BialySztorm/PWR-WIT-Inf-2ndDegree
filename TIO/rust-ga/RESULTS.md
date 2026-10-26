# Task 2 — extended GA results

Port of task 1's decoder/cost (`../go-ga`) to Rust, extended with elitism,
2 more selection methods, 2 more crossovers, 1 more mutation operator.
Same instances as task 1 (`../data/flat.json`, `../data/hilly.json`), loaded
directly — no duplicated terrain generation.

- **Selection:** tournament (k=3, from task 1), roulette (fitness = cost_max
  − cost + ε), linear ranking — each with and without elitism (top 2 of 20
  carried over unchanged).
- **Crossover:** one-point (from task 1), two-point, uniform.
- **Mutation:** reset (from task 1, per-gene p_m=0.01), inversion (new:
  reverse a random segment of the decoded visiting order, re-encode keys;
  applied per-individual with p=0.3 since it's a structural move, not a
  per-gene one).
- 36 combinations × 10 seeds × 2 instances, pop 20, ≤150 generations.

Run: `cargo run --release -- run && cargo run --release -- summarize && cargo run --release -- plots`

## Results

Full ranking: `results/task2_rust_ga.csv`, plots: `plots/task2-rust/`
(`final_cost_*.png` + matching `*_legend.txt` for the rank → config_id
mapping, `convergence_*.png` for best-reset vs best-inversion).

Top 3 on both instances (consistent ranking):

| rank | config | flat avg_best | hilly avg_best |
|---|---|---|---|
| 1 | `tournament+elite / uniform / reset` | 69013.3 | 77157.0 |
| 2 | `ranking+elite / uniform / reset` (flat) / `tournament / uniform / reset` (hilly) | 69737.2 | 77487.6 |
| 3 | `tournament / uniform / reset` (flat) / `roulette+elite / uniform / reset` (hilly) | 69768.1 | 77786.6 |

**Best combo overall: tournament selection + elitism + uniform crossover +
reset mutation**, on both instances.

## Findings

- **Elitism helps but modestly** (~1-2% better than the same selection
  without it) — expected, since it only guards against losing the current
  best, it doesn't add exploration.
- **Uniform crossover beats one-point and two-point** here, consistently.
  On a 1200-gene random-keys chromosome, uniform crossover mixes genetic
  material from both parents far more thoroughly per offspring than a
  single or double cut point, which matters when the signal (which key
  ordering is "good") is spread diffusely across the whole chromosome
  rather than localized in contiguous blocks.
- **Reset mutation beats inversion mutation in every top-15 slot.** This is
  the most informative negative result: the inversion operator here reverses
  a *uniformly random* segment of the tour (not a greedy/best-improvement
  2-opt move), so most reversals don't improve the cost — it's a blind
  structural perturbation, not local search. Reset mutation's smaller,
  uncorrelated per-gene nudges turn out to be a better match for the
  selection pressure in this setup. A proper 2-opt (evaluate all/several
  candidate reversals, keep only improving ones) would likely flip this
  result, at a higher cost per mutation call — worth trying as a follow-up.
- Tournament and roulette+elitism are close; plain roulette/ranking without
  elitism are consistently the weakest selection methods on both instances,
  consistent with higher-variance parent choice early in the run when the
  population hasn't converged.
- Ranking across configs is the same shape on `flat` and `hilly` — the
  extra climb-cost term shifts costs up uniformly but doesn't change which
  operators work best.

## Real-world instances

Best config (tournament+elite / uniform / reset) re-run on `real_canyon` and
`real_silesia`, 10 seeds, via `cargo run --release -- run-real`. See
`plots/task2-rust/convergence_real_{canyon,silesia}.png`.

| instance | baseline total (s) | GA best avg total (s) | feasible |
|---|---|---|---|
| real_canyon | 16,081,212.5 | 16,294,886.5 | **false** (both) |
| real_silesia | 9,928.2 | 91,394.8 | true (both) |

- `real_canyon` is infeasible for every method (baseline included) — the
  terrain pushes the drone's AGL-relative altitude over
  `drone_max_rel_takeoff_m` on ~300k seconds' worth of accumulated violation,
  which dominates the total cost regardless of visiting order. See
  `go-ga/RESULTS.md` for the detailed explanation; the finding is identical
  here since both GAs share the same decoder/cost logic.
- `real_silesia` is feasible and shows the same ~9x gap vs baseline as on
  `flat`/`hilly`, consistent with the random-keys-encoding limitation
  discussed above.
- The rust and go numbers for both real instances agree within noise
  (`real_canyon`: 16,294,886.5 vs 16,300,012.3; `real_silesia`: 91,394.8 vs
  93,129.1) — this cross-checks that the two GA ports and their decoders are
  behaviorally equivalent.
