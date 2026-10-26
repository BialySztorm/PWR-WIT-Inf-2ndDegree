// Problem instance (grid, terrain, flight/camera/battery parameters) and its
// JSON (de)serialization — mirrors go-ga/internal/instance.

use serde::{Deserialize, Deserializer, Serialize};
use std::fs;
use std::path::Path;

/// Treats a JSON `null` the same as a missing field (Go's encoding/json
/// serializes a nil slice as `null`, not `[]`).
fn null_as_default<'de, D, T>(deserializer: D) -> Result<T, D::Error>
where
    D: Deserializer<'de>,
    T: Default + Deserialize<'de>,
{
    Ok(Option::deserialize(deserializer)?.unwrap_or_default())
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Grid {
    pub cell_size_m: f64,
    pub width: i64,
    pub height: i64,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Flight {
    pub mode: String,
    pub agl_target_m: f64,
    #[serde(default)]
    pub amsl_m: f64,
    pub min_clearance_m: f64,
    pub legal_max_agl_m: f64,
    pub drone_max_rel_takeoff_m: f64,
    pub speed_mps: f64,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Camera {
    pub hfov_deg: f64,
    pub aspect: String,
    pub overlap_front: f64,
    pub overlap_side: f64,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Battery {
    pub usable_flight_s: f64,
    pub swap_time_s: f64,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Candidate {
    pub label: String,
    pub x: i64,
    pub y: i64,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Takeoff {
    pub mode: String,
    pub candidates: Vec<Candidate>,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct Instance {
    pub name: String,
    pub grid: Grid,
    pub terrain: Vec<f64>,
    #[serde(default, deserialize_with = "null_as_default")]
    pub excluded_cells: Vec<[i64; 2]>,
    pub flight: Flight,
    pub camera: Camera,
    pub battery: Battery,
    pub takeoff: Takeoff,
}

impl Instance {
    pub fn cell_count(&self) -> usize {
        (self.grid.width * self.grid.height) as usize
    }

    pub fn idx(&self, x: i64, y: i64) -> usize {
        (y * self.grid.width + x) as usize
    }

    pub fn height_at(&self, x: i64, y: i64) -> f64 {
        self.terrain[self.idx(x, y)]
    }

    pub fn included_cells(&self) -> Vec<(i64, i64)> {
        let excluded: std::collections::HashSet<(i64, i64)> = self
            .excluded_cells
            .iter()
            .map(|c| (c[0], c[1]))
            .collect();
        let mut cells = Vec::with_capacity(self.cell_count());
        for y in 0..self.grid.height {
            for x in 0..self.grid.width {
                if !excluded.contains(&(x, y)) {
                    cells.push((x, y));
                }
            }
        }
        cells
    }

    pub fn start_xy(&self) -> (f64, f64) {
        let c = &self.takeoff.candidates[0];
        (c.x as f64 * self.grid.cell_size_m, c.y as f64 * self.grid.cell_size_m)
    }

    pub fn start_height(&self) -> f64 {
        let c = &self.takeoff.candidates[0];
        self.height_at(c.x, c.y)
    }

    pub fn load<P: AsRef<Path>>(path: P) -> Result<Instance, Box<dyn std::error::Error>> {
        let data = fs::read_to_string(path)?;
        Ok(serde_json::from_str(&data)?)
    }
}
