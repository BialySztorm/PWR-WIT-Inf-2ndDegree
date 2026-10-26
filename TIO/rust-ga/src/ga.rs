// Extended GA (task 2): pluggable selection / crossover / mutation, with an
// optional elitist wrapper around any selection method.

use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};

use crate::decoder::{decode, Chromosome, CostBreakdown};
use crate::instance::Instance;
use crate::operators::{crossover, mutation, selection, CrossoverMethod, MutationMethod, SelectionMethod};

#[derive(Clone, Copy)]
pub struct Config {
    pub pop_size: usize,
    pub max_generations: usize,
    pub stall_generations: usize,
    pub pc: f64,
    pub pm: f64,
    pub tournament_k: usize,
    pub elitism: bool,
    pub elite_count: usize,
    pub selection: SelectionMethod,
    pub crossover: CrossoverMethod,
    pub mutation: MutationMethod,
    pub seed: u64,
}

pub struct GenStat {
    pub generation: usize,
    pub best_cost: f64,
    pub avg_cost: f64,
}

pub struct RunResult {
    pub best_chromosome: Chromosome,
    pub best_cost: CostBreakdown,
    pub history: Vec<GenStat>,
    pub evaluations: usize,
}

pub fn run(cfg: &Config, cells: &[(i64, i64)], inst: &Instance) -> RunResult {
    let mut rng = StdRng::seed_from_u64(cfg.seed);
    let n = cells.len();

    let random_chrom = |rng: &mut StdRng| -> Chromosome {
        (0..n).map(|_| rng.gen_range(0.0..1.0)).collect()
    };

    let mut pop: Vec<Chromosome> = (0..cfg.pop_size).map(|_| random_chrom(&mut rng)).collect();
    let mut breakdowns: Vec<CostBreakdown> = pop.iter().map(|c| decode(c, cells, inst)).collect();
    let mut costs: Vec<f64> = breakdowns.iter().map(|b| b.total).collect();
    let mut evaluations = pop.len();

    let mut best_idx = argmin(&costs);
    let mut best_cb = breakdowns[best_idx].clone();
    let mut best_chrom = pop[best_idx].clone();
    let mut stall = 0usize;

    let mut history = Vec::with_capacity(cfg.max_generations + 1);
    history.push(snapshot(0, &costs));

    for generation in 1..=cfg.max_generations {
        let mut new_pop: Vec<Chromosome> = Vec::with_capacity(cfg.pop_size);

        if cfg.elitism {
            let mut idx: Vec<usize> = (0..pop.len()).collect();
            idx.sort_by(|&a, &b| costs[a].partial_cmp(&costs[b]).unwrap());
            for &i in idx.iter().take(cfg.elite_count.min(cfg.pop_size)) {
                new_pop.push(pop[i].clone());
            }
        }

        while new_pop.len() < cfg.pop_size {
            let i1 = selection::select(cfg.selection, &costs, cfg.tournament_k, &mut rng);
            let i2 = selection::select(cfg.selection, &costs, cfg.tournament_k, &mut rng);

            let (mut c1, mut c2) = if rng.gen_bool(cfg.pc) {
                crossover::cross(cfg.crossover, &pop[i1], &pop[i2], &mut rng)
            } else {
                (pop[i1].clone(), pop[i2].clone())
            };
            mutation::mutate(cfg.mutation, &mut c1, cfg.pm, &mut rng);
            mutation::mutate(cfg.mutation, &mut c2, cfg.pm, &mut rng);
            new_pop.push(c1);
            if new_pop.len() < cfg.pop_size {
                new_pop.push(c2);
            }
        }

        breakdowns = new_pop.iter().map(|c| decode(c, cells, inst)).collect();
        costs = breakdowns.iter().map(|b| b.total).collect();
        evaluations += new_pop.len();
        pop = new_pop;

        best_idx = argmin(&costs);
        if costs[best_idx] < best_cb.total {
            best_cb = breakdowns[best_idx].clone();
            best_chrom = pop[best_idx].clone();
            stall = 0;
        } else {
            stall += 1;
        }
        history.push(snapshot(generation, &costs));
        if stall >= cfg.stall_generations {
            break;
        }
    }

    RunResult { best_chromosome: best_chrom, best_cost: best_cb, history, evaluations }
}

fn snapshot(generation: usize, costs: &[f64]) -> GenStat {
    let sum: f64 = costs.iter().sum();
    let best = costs.iter().cloned().fold(f64::MAX, f64::min);
    GenStat { generation, best_cost: best, avg_cost: sum / costs.len() as f64 }
}

fn argmin(xs: &[f64]) -> usize {
    let mut best = 0;
    for (i, &x) in xs.iter().enumerate() {
        if x < xs[best] {
            best = i;
        }
    }
    best
}
