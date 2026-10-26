// Mission decoder: visiting order -> battery-limited flights -> cost.
// Mirrors go-ga/internal/ga/decoder.go.

use crate::instance::Instance;

pub const W_TURN: f64 = 2.0; // s penalty per radian of heading change
pub const W_CLIMB: f64 = 3.0; // s penalty per meter of climb
pub const W_SWAP: f64 = 1.0; // weight on battery_swaps count
pub const W_VIOL: f64 = 50.0; // s penalty per meter of height-limit violation

#[derive(Clone, Debug)]
pub struct CostBreakdown {
    pub flight_time_s: f64,
    pub turn_penalty: f64,
    pub climb_cost: f64,
    pub battery_swaps: u32,
    pub swap_before_step: Vec<usize>,
    pub violations: f64,
    pub total: f64,
    pub feasible: bool,
}

pub type Chromosome = Vec<f64>;

/// Sorts `cells` by ascending chromosome key, yielding the visiting order.
pub fn sorted_order(chrom: &[f64], cells: &[(i64, i64)]) -> Vec<(i64, i64)> {
    let mut idx: Vec<usize> = (0..chrom.len()).collect();
    idx.sort_by(|&a, &b| chrom[a].partial_cmp(&chrom[b]).unwrap());
    idx.into_iter().map(|i| cells[i]).collect()
}

pub fn decode(chrom: &[f64], cells: &[(i64, i64)], inst: &Instance) -> CostBreakdown {
    decode_order(&sorted_order(chrom, cells), inst)
}

pub fn decode_order(order: &[(i64, i64)], inst: &Instance) -> CostBreakdown {
    let (start_x, start_y) = inst.start_xy();
    let start_h = inst.start_height();

    let mut cb = CostBreakdown {
        flight_time_s: 0.0,
        turn_penalty: 0.0,
        climb_cost: 0.0,
        battery_swaps: 0,
        swap_before_step: Vec::new(),
        violations: 0.0,
        total: 0.0,
        feasible: true,
    };

    let mut cur_x = start_x;
    let mut cur_y = start_y;
    let mut cur_h = start_h;
    let mut have_prev_heading = false;
    let mut prev_hx = 0.0;
    let mut prev_hy = 0.0;
    let mut flight_elapsed = 0.0_f64;

    let segment_cost = |x1: f64, y1: f64, h1: f64, x2: f64, y2: f64, h2: f64,
                         have_prev_h: bool, phx: f64, phy: f64, speed: f64|
     -> (f64, f64, f64, f64, f64) {
        let dx = x2 - x1;
        let dy = y2 - y1;
        let dist = dx.hypot(dy);
        let time_s = dist / speed;
        let (hx, hy) = if dist > 1e-9 { (dx / dist, dy / dist) } else { (phx, phy) };
        let mut turn = 0.0;
        if have_prev_h && dist > 1e-9 {
            let cos_a = (phx * hx + phy * hy).clamp(-1.0, 1.0);
            turn = cos_a.acos();
        }
        let climb = (h2 - h1).max(0.0);
        (time_s, turn, climb, hx, hy)
    };

    let return_time_from = |x: f64, y: f64, speed: f64| -> f64 {
        (start_x - x).hypot(start_y - y) / speed
    };

    let speed = inst.flight.speed_mps;

    for (i, &(cx, cy)) in order.iter().enumerate() {
        let x = cx as f64 * inst.grid.cell_size_m;
        let y = cy as f64 * inst.grid.cell_size_m;
        let h = inst.height_at(cx, cy);

        let (mut t, mut turn, mut climb, mut hx, mut hy) =
            segment_cost(cur_x, cur_y, cur_h, x, y, h, have_prev_heading, prev_hx, prev_hy, speed);
        let needed_if_stop_here =
            flight_elapsed + t + W_TURN * turn + W_CLIMB * climb + return_time_from(x, y, speed);

        if needed_if_stop_here > inst.battery.usable_flight_s && flight_elapsed > 0.0 {
            // Close current flight: return to base, pay swap cost, restart from base.
            let ret = return_time_from(cur_x, cur_y, speed);
            cb.flight_time_s += ret;
            cb.battery_swaps += 1;
            cb.swap_before_step.push(i);
            cur_x = start_x;
            cur_y = start_y;
            cur_h = start_h;
            flight_elapsed = 0.0;

            let r = segment_cost(cur_x, cur_y, cur_h, x, y, h, false, 0.0, 0.0, speed);
            t = r.0;
            turn = r.1;
            climb = r.2;
            hx = r.3;
            hy = r.4;
        }

        let rel_height = (h + inst.flight.agl_target_m) - start_h;
        if rel_height > inst.flight.drone_max_rel_takeoff_m {
            cb.violations += rel_height - inst.flight.drone_max_rel_takeoff_m;
        }

        let seg_time = t + W_TURN * turn + W_CLIMB * climb;
        cb.flight_time_s += t;
        cb.turn_penalty += turn;
        cb.climb_cost += climb;
        flight_elapsed += seg_time;

        cur_x = x;
        cur_y = y;
        cur_h = h;
        prev_hx = hx;
        prev_hy = hy;
        have_prev_heading = true;
    }

    cb.flight_time_s += return_time_from(cur_x, cur_y, speed);

    cb.total = cb.flight_time_s
        + W_TURN * cb.turn_penalty
        + W_CLIMB * cb.climb_cost
        + W_SWAP * cb.battery_swaps as f64
        + W_VIOL * cb.violations;
    cb.feasible = cb.violations == 0.0;
    cb
}
