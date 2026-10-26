use std::collections::HashMap;
use std::error::Error;

use plotters::prelude::*;

pub struct Row {
    pub instance: String,
    pub config: String,
    pub seed: String,
    pub generation: usize,
    pub best_cost: f64,
}

pub fn load_rows(path: &str) -> Result<Vec<Row>, Box<dyn Error>> {
    let mut reader = csv::Reader::from_path(path)?;
    let mut rows = Vec::new();
    for rec in reader.records() {
        let rec = rec?;
        rows.push(Row {
            instance: rec[0].to_string(),
            config: rec[2].to_string(),
            seed: rec[3].to_string(),
            generation: rec[4].parse()?,
            best_cost: rec[6].parse()?,
        });
    }
    Ok(rows)
}

/// mean final (last-generation) best_cost across seeds, per config, for one instance.
fn final_means(rows: &[Row], instance_name: &str) -> Vec<(String, f64)> {
    let mut final_by_config_seed: HashMap<String, HashMap<String, f64>> = HashMap::new();
    for r in rows {
        if r.instance != instance_name {
            continue;
        }
        final_by_config_seed
            .entry(r.config.clone())
            .or_default()
            .insert(r.seed.clone(), r.best_cost);
    }
    let mut means: Vec<(String, f64)> = final_by_config_seed
        .into_iter()
        .map(|(config, by_seed)| {
            let sum: f64 = by_seed.values().sum();
            (config, sum / by_seed.len() as f64)
        })
        .collect();
    means.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());
    means
}

pub fn top_configs_bar_chart(rows: &[Row], instance_name: &str, top_n: usize, out_path: &str) -> Result<(), Box<dyn Error>> {
    let means = final_means(rows, instance_name);
    let top: Vec<(String, f64)> = means.into_iter().take(top_n).collect();

    let root = BitMapBackend::new(out_path, (1100, 650)).into_drawing_area();
    root.fill(&WHITE)?;

    let max_y = top.iter().map(|(_, v)| *v).fold(f64::MIN, f64::max) * 1.1;

    let mut chart = ChartBuilder::on(&root)
        .caption(format!("Top {} configs by final best cost — {} (rank 1 = best)", top.len(), instance_name), ("sans-serif", 20))
        .margin(20)
        .x_label_area_size(40)
        .y_label_area_size(70)
        .build_cartesian_2d(0..top.len(), 0.0..max_y)?;

    chart
        .configure_mesh()
        .x_labels(top.len())
        .x_label_formatter(&|i| format!("#{}", i + 1))
        .y_desc("mean best cost (s)")
        .x_desc("rank (see RESULTS.md for config_id of each rank)")
        .draw()?;

    chart.draw_series(top.iter().enumerate().map(|(i, (_, v))| {
        let x0 = i;
        let x1 = i + 1;
        let mut bar = Rectangle::new([(x0, 0.0), (x1, *v)], BLUE.filled());
        bar.set_margin(0, 0, 5, 5);
        bar
    }))?;

    root.present()?;

    // Companion text legend: rank -> full config_id, since rotated labels
    // don't render legibly at this bar width.
    let legend_path = out_path.replace(".png", "_legend.txt");
    let legend = top
        .iter()
        .enumerate()
        .map(|(i, (c, v))| format!("#{}: {} (mean best cost = {:.1}s)", i + 1, c, v))
        .collect::<Vec<_>>()
        .join("\n");
    std::fs::write(legend_path, legend)?;

    Ok(())
}

/// Convergence curve for a single, already-known config (no best-of
/// selection) — used for real instances, which only ever ran one config
/// (via `run_real`), so there's nothing to pick a "best" among.
pub fn convergence_plot_single_config(rows: &[Row], instance_name: &str, config: &str, out_path: &str) -> Result<(), Box<dyn Error>> {
    let mut sums: HashMap<usize, (f64, usize)> = HashMap::new();
    for r in rows {
        if r.instance != instance_name || r.config != config {
            continue;
        }
        let e = sums.entry(r.generation).or_insert((0.0, 0));
        e.0 += r.best_cost;
        e.1 += 1;
    }
    let mut pts: Vec<(usize, f64)> = sums.into_iter().map(|(g, (s, n))| (g, s / n as f64)).collect();
    pts.sort_by_key(|(g, _)| *g);

    let root = BitMapBackend::new(out_path, (900, 600)).into_drawing_area();
    root.fill(&WHITE)?;

    let max_gen = pts.iter().map(|(g, _)| *g).max().unwrap_or(1);
    let max_y = pts.iter().map(|(_, v)| *v).fold(f64::MIN, f64::max) * 1.05;
    let min_y = pts.iter().map(|(_, v)| *v).fold(f64::MAX, f64::min) * 0.95;

    let mut chart = ChartBuilder::on(&root)
        .caption(format!("Convergence — {} — {}", config, instance_name), ("sans-serif", 22))
        .margin(20)
        .x_label_area_size(40)
        .y_label_area_size(70)
        .build_cartesian_2d(0..max_gen, min_y..max_y)?;

    chart.configure_mesh().x_desc("generation").y_desc("best cost (s)").draw()?;

    chart
        .draw_series(LineSeries::new(pts.iter().map(|(g, v)| (*g, *v)), RED))?
        .label(config.to_string())
        .legend(|(x, y)| PathElement::new(vec![(x, y), (x + 20, y)], RED));
    chart.configure_series_labels().background_style(WHITE.mix(0.8)).border_style(BLACK).draw()?;

    root.present()?;
    Ok(())
}

/// Convergence curves for the best Reset-mutation config vs. the best
/// Inversion-mutation config (by mean final cost), showing the impact of
/// the new (task 2) mutation operator.
pub fn convergence_plot_best_per_mutation(rows: &[Row], instance_name: &str, out_path: &str) -> Result<(), Box<dyn Error>> {
    let means = final_means(rows, instance_name);
    let best_reset = means.iter().find(|(c, _)| c.contains("_mut=reset")).cloned();
    let best_inversion = means.iter().find(|(c, _)| c.contains("_mut=inversion")).cloned();

    let mut series: Vec<(String, Vec<(usize, f64)>)> = Vec::new();
    for (config, _) in [best_reset, best_inversion].into_iter().flatten() {
        let mut sums: HashMap<usize, (f64, usize)> = HashMap::new();
        for r in rows {
            if r.instance != instance_name || r.config != config {
                continue;
            }
            let e = sums.entry(r.generation).or_insert((0.0, 0));
            e.0 += r.best_cost;
            e.1 += 1;
        }
        let mut pts: Vec<(usize, f64)> = sums.into_iter().map(|(g, (s, n))| (g, s / n as f64)).collect();
        pts.sort_by_key(|(g, _)| *g);
        series.push((config, pts));
    }

    let root = BitMapBackend::new(out_path, (900, 600)).into_drawing_area();
    root.fill(&WHITE)?;

    let max_gen = series.iter().flat_map(|(_, pts)| pts.iter().map(|(g, _)| *g)).max().unwrap_or(1);
    let max_y = series
        .iter()
        .flat_map(|(_, pts)| pts.iter().map(|(_, v)| *v))
        .fold(f64::MIN, f64::max)
        * 1.05;
    let min_y = series
        .iter()
        .flat_map(|(_, pts)| pts.iter().map(|(_, v)| *v))
        .fold(f64::MAX, f64::min)
        * 0.95;

    let mut chart = ChartBuilder::on(&root)
        .caption(format!("Best Reset vs best Inversion mutation — {}", instance_name), ("sans-serif", 22))
        .margin(20)
        .x_label_area_size(40)
        .y_label_area_size(70)
        .build_cartesian_2d(0..max_gen, min_y..max_y)?;

    chart.configure_mesh().x_desc("generation").y_desc("best cost (s)").draw()?;

    let colors = [RED, BLUE];
    for (i, (config, pts)) in series.iter().enumerate() {
        let color = colors[i % colors.len()];
        chart
            .draw_series(LineSeries::new(pts.iter().map(|(g, v)| (*g, *v)), color))?
            .label(config.clone())
            .legend(move |(x, y)| PathElement::new(vec![(x, y), (x + 20, y)], color));
    }
    chart.configure_series_labels().background_style(WHITE.mix(0.8)).border_style(BLACK).draw()?;

    root.present()?;
    Ok(())
}
