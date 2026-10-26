use rand::Rng;

use super::MutationMethod;
use crate::decoder::Chromosome;

pub fn mutate(method: MutationMethod, chrom: &mut Chromosome, pm: f64, rng: &mut impl Rng) {
    match method {
        MutationMethod::Reset => reset(chrom, pm, rng),
        MutationMethod::Inversion => inversion(chrom, pm, rng),
    }
}

/// Reset mutation (task 1): each gene independently gets a fresh random key
/// with probability pm.
fn reset(chrom: &mut Chromosome, pm: f64, rng: &mut impl Rng) {
    for gene in chrom.iter_mut() {
        if rng.gen_bool(pm) {
            *gene = rng.gen_range(0.0..1.0);
        }
    }
}

/// Inversion mutation (2-opt-like): decode the chromosome to its visiting
/// order, reverse a random contiguous segment of that order, then re-encode
/// new ascending keys consistent with the new order. Applied once per
/// individual with probability pm (it is a structural move, not a per-gene
/// one).
fn inversion(chrom: &mut Chromosome, pm: f64, rng: &mut impl Rng) {
    if !rng.gen_bool(pm) {
        return;
    }
    let n = chrom.len();
    if n < 2 {
        return;
    }
    let mut idx: Vec<usize> = (0..n).collect();
    idx.sort_by(|&a, &b| chrom[a].partial_cmp(&chrom[b]).unwrap());

    let mut a = rng.gen_range(0..n);
    let mut b = rng.gen_range(0..n);
    if a > b {
        std::mem::swap(&mut a, &mut b);
    }
    idx[a..=b].reverse();

    for (rank, &gene_idx) in idx.iter().enumerate() {
        chrom[gene_idx] = rank as f64 / n as f64;
    }
}
