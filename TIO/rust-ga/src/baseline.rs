// Boustrophedon ("mowing") reference sweep — mirrors go-ga/internal/baseline.

use std::collections::BTreeMap;

use crate::instance::Instance;

pub fn boustrophedon(inst: &Instance) -> Vec<(i64, i64)> {
    let cells = inst.included_cells();
    let mut by_column: BTreeMap<i64, Vec<i64>> = BTreeMap::new();
    for (x, y) in cells {
        by_column.entry(x).or_default().push(y);
    }

    let mut order = Vec::new();
    let mut forward = true;
    for x in 0..inst.grid.width {
        if let Some(ys) = by_column.get(&x) {
            if forward {
                for &y in ys {
                    order.push((x, y));
                }
            } else {
                for &y in ys.iter().rev() {
                    order.push((x, y));
                }
            }
            forward = !forward;
        }
    }
    order
}
