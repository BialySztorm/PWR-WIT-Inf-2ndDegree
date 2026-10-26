// Package baseline implements the boustrophedon ("mowing") reference sweep
// that every GA/ACO result is compared against.
package baseline

import "dronepath/internal/instance"

// Boustrophedon visits cells column by column (fixed x), alternating the y
// direction on each column, which is the classic lawnmower coverage pattern.
func Boustrophedon(inst *instance.Instance) [][2]int {
	cells := inst.IncludedCells()
	byColumn := make(map[int][]int) // x -> sorted y's
	for _, c := range cells {
		byColumn[c[0]] = append(byColumn[c[0]], c[1])
	}

	order := make([][2]int, 0, len(cells))
	forward := true
	for x := 0; x < inst.Grid.Width; x++ {
		ys, ok := byColumn[x]
		if !ok {
			continue
		}
		if forward {
			for _, y := range ys {
				order = append(order, [2]int{x, y})
			}
		} else {
			for i := len(ys) - 1; i >= 0; i-- {
				order = append(order, [2]int{x, ys[i]})
			}
		}
		forward = !forward
	}
	return order
}
