mod baseline;
mod decoder;
mod experiment;
mod ga;
mod instance;
mod operators;
mod plots;

use std::collections::HashMap;
use std::error::Error;

use ga::Config;
use instance::Instance;
use operators::{CrossoverMethod, MutationMethod, SelectionMethod};
use serde::{Deserialize, Serialize};

const DATA_DIR: &str = "../data";
const RESULTS_PATH: &str = "../results/task2_rust_ga.csv";
const PLOTS_DIR: &str = "../plots/task2-rust";
const ROUTES_DIR: &str = "../results/routes";

#[derive(Deserialize)]
struct RegistryEntry {
    slug: String,
    #[serde(rename = "type")]
    kind: String,
}

#[derive(Deserialize)]
struct Registry {
    #[serde(default)]
    instances: Vec<RegistryEntry>,
}

/// Reads the shared data/instances.json manifest (see
/// scripts/fetch_terrain.py and go-ga/cmd/dronega/main.go), which lists
/// which instance files exist across all 3 solver pipelines.
fn slugs_by_type(types: &[&str]) -> Vec<String> {
    let path = format!("{}/instances.json", DATA_DIR);
    let data = match std::fs::read_to_string(&path) {
        Ok(d) => d,
        Err(_) => return Vec::new(),
    };
    let registry: Registry = serde_json::from_str(&data).expect("invalid instances.json");
    registry
        .instances
        .into_iter()
        .filter(|e| types.contains(&e.kind.as_str()))
        .map(|e| e.slug)
        .collect()
}

// Documented task2 winner (see rust-ga/RESULTS.md): tournament + elitism,
// uniform crossover, reset mutation.
fn best_ga_config(seed: u64) -> Config {
    Config {
        pop_size: 20,
        max_generations: 150,
        stall_generations: 30,
        pc: 0.8,
        pm: 0.01,
        tournament_k: 3,
        elitism: true,
        elite_count: 2,
        selection: SelectionMethod::Tournament,
        crossover: CrossoverMethod::Uniform,
        mutation: MutationMethod::Reset,
        seed,
    }
}

fn best_ga_config_id() -> String {
    "sel=tournament+elite_cx=uniform_mut=reset".to_string()
}

#[derive(Serialize)]
struct CostJson {
    flight_time_s: f64,
    turn_penalty: f64,
    climb_cost: f64,
    battery_swaps: u32,
    swap_before_step: Vec<usize>,
    violations: f64,
    total: f64,
    feasible: bool,
}

impl From<&decoder::CostBreakdown> for CostJson {
    fn from(cb: &decoder::CostBreakdown) -> Self {
        CostJson {
            flight_time_s: cb.flight_time_s,
            turn_penalty: cb.turn_penalty,
            climb_cost: cb.climb_cost,
            battery_swaps: cb.battery_swaps,
            swap_before_step: cb.swap_before_step.clone(),
            violations: cb.violations,
            total: cb.total,
            feasible: cb.feasible,
        }
    }
}

#[derive(Serialize)]
struct RouteFile {
    instance: String,
    method: String,
    config_id: String,
    order: Vec<(i64, i64)>,
    cost: CostJson,
}

fn write_route_file(
    instance_name: &str,
    method: &str,
    config_id: &str,
    order: &[(i64, i64)],
    cost: &decoder::CostBreakdown,
) -> Result<(), Box<dyn Error>> {
    let rf = RouteFile {
        instance: instance_name.to_string(),
        method: method.to_string(),
        config_id: config_id.to_string(),
        order: order.to_vec(),
        cost: cost.into(),
    };
    let path = format!("{}/{}_{}.json", ROUTES_DIR, instance_name, method);
    std::fs::write(&path, serde_json::to_string_pretty(&rf)?)?;
    println!("wrote {}", path);
    Ok(())
}

fn gen_routes() -> Result<(), Box<dyn Error>> {
    std::fs::create_dir_all(ROUTES_DIR)?;
    for name in slugs_by_type(&["synthetic", "real"]) {
        let name = name.as_str();
        let inst = Instance::load(format!("{}/{}.json", DATA_DIR, name))?;
        let cells = inst.included_cells();

        let base_order = baseline::boustrophedon(&inst);
        let base_cost = decoder::decode_order(&base_order, &inst);
        write_route_file(name, "baseline", "boustrophedon", &base_order, &base_cost)?;

        let cfg = best_ga_config(0);
        let res = ga::run(&cfg, &cells, &inst);
        let order = decoder::sorted_order(&res.best_chromosome, &cells);
        write_route_file(name, "ga_best_rust", &best_ga_config_id(), &order, &res.best_cost)?;
    }
    Ok(())
}

fn run_real() -> Result<(), Box<dyn Error>> {
    let file = std::fs::OpenOptions::new().append(true).open(RESULTS_PATH)?;
    let mut writer = csv::Writer::from_writer(file);

    let seeds: Vec<u64> = (0..10).collect();
    let cfg_id = best_ga_config_id();

    for name in slugs_by_type(&["real"]) {
        let name = name.as_str();
        let inst = Instance::load(format!("{}/{}.json", DATA_DIR, name))?;
        let cells = inst.included_cells();

        let base_order = baseline::boustrophedon(&inst);
        let base_cost = decoder::decode_order(&base_order, &inst);
        println!(
            "[{}] baseline (boustrophedon): total={:.1}s feasible={}",
            name, base_cost.total, base_cost.feasible
        );

        println!("[{}] running best config x {} seeds...", name, seeds.len());
        for &seed in &seeds {
            let cfg = best_ga_config(seed);
            let res = ga::run(&cfg, &cells, &inst);
            for h in &res.history {
                writer.write_record(&[
                    name,
                    "ga_real_best",
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
        writer.flush()?;
    }
    println!("appended real-instance runs to {}", RESULTS_PATH);
    Ok(())
}

fn run_sweep() -> Result<(), Box<dyn Error>> {
    let file = std::fs::File::create(RESULTS_PATH)?;
    let mut writer = csv::Writer::from_writer(file);
    experiment::write_header(&mut writer)?;

    let seeds: Vec<u64> = (0..10).collect();

    for name in slugs_by_type(&["synthetic"]) {
        let name = name.as_str();
        let inst = Instance::load(format!("{}/{}.json", DATA_DIR, name))?;
        let cells = inst.included_cells();

        let base_order = baseline::boustrophedon(&inst);
        let base_cost = decoder::decode_order(&base_order, &inst);
        println!(
            "[{}] baseline (boustrophedon): total={:.1}s feasible={}",
            name, base_cost.total, base_cost.feasible
        );

        let combos = experiment::all_combos();
        println!("[{}] running {} combos x {} seeds...", name, combos.len(), seeds.len());
        experiment::run_sweep(&mut writer, name, &cells, &inst, &seeds)?;
        writer.flush()?;
    }
    println!("wrote {}", RESULTS_PATH);
    Ok(())
}

fn summarize() -> Result<(), Box<dyn Error>> {
    let mut reader = csv::Reader::from_path(RESULTS_PATH)?;
    // key: (instance, config) -> seed -> last-seen best_cost
    let mut final_by_run: HashMap<(String, String), HashMap<String, f64>> = HashMap::new();

    for rec in reader.records() {
        let rec = rec?;
        let inst = rec[0].to_string();
        let config = rec[2].to_string();
        let seed = rec[3].to_string();
        let best_cost: f64 = rec[6].parse()?;
        final_by_run.entry((inst, config)).or_default().insert(seed, best_cost);
    }

    let mut rows: Vec<((String, String), f64, f64, f64, usize)> = final_by_run
        .iter()
        .map(|(k, by_seed)| {
            let vals: Vec<f64> = by_seed.values().cloned().collect();
            let sum: f64 = vals.iter().sum();
            let min = vals.iter().cloned().fold(f64::MAX, f64::min);
            let max = vals.iter().cloned().fold(f64::MIN, f64::max);
            (k.clone(), sum / vals.len() as f64, min, max, vals.len())
        })
        .collect();
    rows.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

    println!(
        "\n{:<8} {:<40} {:>12} {:>12} {:>12} {:>8}",
        "instance", "config", "avg_best", "min_best", "max_best", "n_seeds"
    );
    for (k, avg, min, max, n) in &rows {
        println!("{:<8} {:<40} {:>12.1} {:>12.1} {:>12.1} {:>8}", k.0, k.1, avg, min, max, n);
    }
    if let Some(best) = rows.first() {
        println!("\nBest combo overall: {} / {} (avg_best={:.1})", best.0 .0, best.0 .1, best.1);
    }
    Ok(())
}

fn make_plots() -> Result<(), Box<dyn Error>> {
    let rows = plots::load_rows(RESULTS_PATH)?;
    std::fs::create_dir_all(PLOTS_DIR)?;
    for inst_name in slugs_by_type(&["synthetic"]) {
        let inst_name = inst_name.as_str();
        let bar_path = format!("{}/final_cost_{}.png", PLOTS_DIR, inst_name);
        plots::top_configs_bar_chart(&rows, inst_name, 10, &bar_path)?;
        println!("wrote {}", bar_path);

        let conv_path = format!("{}/convergence_{}.png", PLOTS_DIR, inst_name);
        plots::convergence_plot_best_per_mutation(&rows, inst_name, &conv_path)?;
        println!("wrote {}", conv_path);
    }

    // Real instances only ever ran the single best_ga_config (via
    // run_real), no hyperparameter sweep, so a "top configs" bar chart
    // would be meaningless with n=1 — only a convergence plot makes sense.
    let real_config = best_ga_config_id();
    for inst_name in slugs_by_type(&["real"]) {
        let inst_name = inst_name.as_str();
        let conv_path = format!("{}/convergence_{}.png", PLOTS_DIR, inst_name);
        plots::convergence_plot_single_config(&rows, inst_name, &real_config, &conv_path)?;
        println!("wrote {}", conv_path);
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: dronepath <run|summarize|plots|routes|run-real>");
        std::process::exit(1);
    }
    match args[1].as_str() {
        "run" => run_sweep(),
        "summarize" => summarize(),
        "plots" => make_plots(),
        "routes" => gen_routes(),
        "run-real" => run_real(),
        other => {
            eprintln!("unknown command: {}", other);
            std::process::exit(1);
        }
    }
}
