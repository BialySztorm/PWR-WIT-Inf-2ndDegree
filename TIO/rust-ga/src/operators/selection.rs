use rand::Rng;

use super::SelectionMethod;

pub fn select(method: SelectionMethod, costs: &[f64], tournament_k: usize, rng: &mut impl Rng) -> usize {
    match method {
        SelectionMethod::Tournament => tournament(costs, tournament_k, rng),
        SelectionMethod::Roulette => roulette(costs, rng),
        SelectionMethod::Ranking => ranking(costs, rng),
    }
}

fn tournament(costs: &[f64], k: usize, rng: &mut impl Rng) -> usize {
    let mut best = rng.gen_range(0..costs.len());
    for _ in 1..k {
        let c = rng.gen_range(0..costs.len());
        if costs[c] < costs[best] {
            best = c;
        }
    }
    best
}

/// Fitness-proportional (roulette-wheel) selection. The problem is a
/// minimization, so cost is inverted around the population's worst value:
/// fitness_i = cost_max - cost_i + eps, giving the best individual the
/// highest selection weight.
fn roulette(costs: &[f64], rng: &mut impl Rng) -> usize {
    let cost_max = costs.iter().cloned().fold(f64::MIN, f64::max);
    let eps = 1e-6;
    let weights: Vec<f64> = costs.iter().map(|&c| cost_max - c + eps).collect();
    let total: f64 = weights.iter().sum();
    let mut pick = rng.gen_range(0.0..total);
    for (i, w) in weights.iter().enumerate() {
        if pick < *w {
            return i;
        }
        pick -= w;
    }
    weights.len() - 1
}

/// Linear-rank selection: sort by cost ascending, weight(rank) = n - rank,
/// so the best individual (rank 0) is n times more likely than the worst.
fn ranking(costs: &[f64], rng: &mut impl Rng) -> usize {
    let n = costs.len();
    let mut idx: Vec<usize> = (0..n).collect();
    idx.sort_by(|&a, &b| costs[a].partial_cmp(&costs[b]).unwrap());

    let total: f64 = (1..=n).map(|r| r as f64).sum();
    let mut pick = rng.gen_range(0.0..total);
    for (rank, &i) in idx.iter().enumerate() {
        let w = (n - rank) as f64;
        if pick < w {
            return i;
        }
        pick -= w;
    }
    idx[n - 1]
}
