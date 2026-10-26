// Combinatorial sweep over selection x crossover x mutation x elitism,
// writing one row per generation per run to CSV (shared schema, see
// lab-objectives.md section 3.2).

use std::error::Error;
use std::fs::File;

use crate::ga::{self, Config};
use crate::instance::Instance;
use crate::operators::{CrossoverMethod, MutationMethod, SelectionMethod};

pub struct Combo {
    pub selection: SelectionMethod,
    pub elitism: bool,
    pub crossover: CrossoverMethod,
    pub mutation: MutationMethod,
}

pub fn all_combos() -> Vec<Combo> {
    let mut combos = Vec::new();
    for &selection in &[SelectionMethod::Tournament, SelectionMethod::Roulette, SelectionMethod::Ranking] {
        for &elitism in &[false, true] {
            for &crossover in &[CrossoverMethod::OnePoint, CrossoverMethod::TwoPoint, CrossoverMethod::Uniform] {
                for &mutation in &[MutationMethod::Reset, MutationMethod::Inversion] {
                    combos.push(Combo { selection, elitism, crossover, mutation });
                }
            }
        }
    }
    combos
}

fn pm_for(method: MutationMethod) -> f64 {
    match method {
        // Per-gene probability (task 1 finding: 0.005-0.01 works best).
        MutationMethod::Reset => 0.01,
        // Per-individual probability of one inversion move.
        MutationMethod::Inversion => 0.3,
    }
}

pub fn config_id(combo: &Combo) -> String {
    format!(
        "sel={}{}_cx={}_mut={}",
        combo.selection.label(),
        if combo.elitism { "+elite" } else { "" },
        combo.crossover.label(),
        combo.mutation.label(),
    )
}

pub fn run_sweep(
    writer: &mut csv::Writer<File>,
    instance_name: &str,
    cells: &[(i64, i64)],
    inst: &Instance,
    seeds: &[u64],
) -> Result<(), Box<dyn Error>> {
    for combo in all_combos() {
        let cfg_id = config_id(&combo);
        for &seed in seeds {
            let cfg = Config {
                pop_size: 20,
                max_generations: 150,
                stall_generations: 30,
                pc: 0.8,
                pm: pm_for(combo.mutation),
                tournament_k: 3,
                elitism: combo.elitism,
                elite_count: 2,
                selection: combo.selection,
                crossover: combo.crossover,
                mutation: combo.mutation,
                seed,
            };
            let res = ga::run(&cfg, cells, inst);
            for h in &res.history {
                writer.write_record(&[
                    instance_name,
                    "rust_ga_extended",
                    &cfg_id,
                    &seed.to_string(),
                    &h.generation.to_string(),
                    &res.evaluations.to_string(),
                    &format!("{:.6}", h.best_cost),
                    &format!("{:.6}", h.avg_cost),
                    &res.best_cost.feasible.to_string(),
                ])?;
            }
        }
    }
    Ok(())
}

pub fn write_header(writer: &mut csv::Writer<File>) -> Result<(), Box<dyn Error>> {
    writer.write_record(&[
        "instance", "method", "config_id", "seed", "generation", "evaluations", "best_cost", "avg_cost", "feasible",
    ])?;
    Ok(())
}
