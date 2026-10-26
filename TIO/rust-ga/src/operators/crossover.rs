use rand::Rng;

use super::CrossoverMethod;
use crate::decoder::Chromosome;

pub fn cross(
    method: CrossoverMethod,
    p1: &Chromosome,
    p2: &Chromosome,
    rng: &mut impl Rng,
) -> (Chromosome, Chromosome) {
    match method {
        CrossoverMethod::OnePoint => one_point(p1, p2, rng),
        CrossoverMethod::TwoPoint => two_point(p1, p2, rng),
        CrossoverMethod::Uniform => uniform(p1, p2, rng),
    }
}

/// Any cut yields two valid random-keys chromosomes, no repair needed.
fn one_point(p1: &Chromosome, p2: &Chromosome, rng: &mut impl Rng) -> (Chromosome, Chromosome) {
    let n = p1.len();
    let cut = rng.gen_range(1..n);
    let mut c1 = p1.clone();
    let mut c2 = p2.clone();
    c1[cut..].clone_from_slice(&p2[cut..]);
    c2[cut..].clone_from_slice(&p1[cut..]);
    (c1, c2)
}

fn two_point(p1: &Chromosome, p2: &Chromosome, rng: &mut impl Rng) -> (Chromosome, Chromosome) {
    let n = p1.len();
    let mut a = rng.gen_range(1..n);
    let mut b = rng.gen_range(1..n);
    if a > b {
        std::mem::swap(&mut a, &mut b);
    }
    if a == b {
        b = (a + 1).min(n);
    }
    let mut c1 = p1.clone();
    let mut c2 = p2.clone();
    c1[a..b].clone_from_slice(&p2[a..b]);
    c2[a..b].clone_from_slice(&p1[a..b]);
    (c1, c2)
}

fn uniform(p1: &Chromosome, p2: &Chromosome, rng: &mut impl Rng) -> (Chromosome, Chromosome) {
    let n = p1.len();
    let mut c1 = Vec::with_capacity(n);
    let mut c2 = Vec::with_capacity(n);
    for i in 0..n {
        if rng.gen_bool(0.5) {
            c1.push(p1[i]);
            c2.push(p2[i]);
        } else {
            c1.push(p2[i]);
            c2.push(p1[i]);
        }
    }
    (c1, c2)
}
