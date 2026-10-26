// Package ga implements the basic genetic algorithm (task 1): random-keys
// chromosome, one-point crossover, reset mutation, tournament selection.
package ga

import (
	"math"
	"sort"

	"dronepath/internal/instance"
)

// Weights for the non-time cost terms (see lab-objectives.md section 2.8).
const (
	wTurn = 2.0  // seconds of penalty per radian of heading change
	wClimb = 3.0 // seconds of penalty per meter of climb
	wSwap  = 1.0 // weight on battery_swaps (on top of swap_time_s already counted as time)
	wViol  = 50.0 // seconds of penalty per meter of height-limit violation
)

// Chromosome is the random-keys representation: one key in [0,1) per
// eligible cell. Sorting the keys yields the visiting order.
type Chromosome []float64

// CostBreakdown holds the decoded mission cost and its components, useful for
// diagnostics and reporting.
type CostBreakdown struct {
	FlightTimeS    float64
	TurnPenalty    float64
	ClimbCost      float64
	BatterySwaps   int
	SwapBeforeStep []int
	Violations     float64
	Total          float64
	Feasible       bool
}

// Decode turns a chromosome into visiting order, splits it into battery-
// limited flights (sorties), and computes the mission cost.
func Decode(chrom Chromosome, cells [][2]int, inst *instance.Instance) CostBreakdown {
	return DecodeOrder(SortedOrder(chrom, cells), inst)
}

// DecodeOrder computes the mission cost for an explicit visiting order
// (e.g. decoded from a chromosome, or a baseline boustrophedon sweep).
func DecodeOrder(order [][2]int, inst *instance.Instance) CostBreakdown {
	startX, startY := inst.StartXY()
	startH := inst.HeightAt(inst.Takeoff.Candidates[0].X, inst.Takeoff.Candidates[0].Y)

	var cb CostBreakdown
	curX, curY := startX, startY
	curH := startH
	havePrevHeading := false
	var prevHX, prevHY float64
	flightElapsed := 0.0

	segmentCost := func(x1, y1, h1, x2, y2, h2 float64, havePrevH bool, phx, phy float64) (timeS, turn, climb float64, hx, hy float64) {
		dx, dy := x2-x1, y2-y1
		dist := math.Hypot(dx, dy)
		timeS = dist / inst.Flight.SpeedMps
		if dist > 1e-9 {
			hx, hy = dx/dist, dy/dist
		} else {
			hx, hy = phx, phy
		}
		if havePrevH && dist > 1e-9 {
			cosA := phx*hx + phy*hy
			cosA = math.Max(-1, math.Min(1, cosA))
			turn = math.Acos(cosA)
		}
		climb = math.Max(0, h2-h1)
		return
	}

	returnTimeFrom := func(x, y float64) float64 {
		return math.Hypot(startX-x, startY-y) / inst.Flight.SpeedMps
	}

	closeFlight := func() {
		t := returnTimeFrom(curX, curY)
		cb.FlightTimeS += t
		cb.BatterySwaps++
		curX, curY, curH = startX, startY, startH
		havePrevHeading = false
		flightElapsed = 0
	}

	for i, c := range order {
		x := float64(c[0]) * inst.Grid.CellSizeM
		y := float64(c[1]) * inst.Grid.CellSizeM
		h := inst.HeightAt(c[0], c[1])

		t, turn, climb, hx, hy := segmentCost(curX, curY, curH, x, y, h, havePrevHeading, prevHX, prevHY)
		neededIfStopHere := flightElapsed + t + wTurnSeconds(turn) + wClimbSeconds(climb) + returnTimeFrom(x, y)

		if neededIfStopHere > inst.Battery.UsableFlightS && flightElapsed > 0 {
			closeFlight()
			cb.SwapBeforeStep = append(cb.SwapBeforeStep, i)
			t, turn, climb, hx, hy = segmentCost(curX, curY, curH, x, y, h, false, 0, 0)
		}

		relHeight := (h + inst.Flight.AGLTargetM) - startH
		if relHeight > inst.Flight.DroneMaxRelTakeoffM {
			cb.Violations += relHeight - inst.Flight.DroneMaxRelTakeoffM
		}

		segTime := t + wTurnSeconds(turn) + wClimbSeconds(climb)
		cb.FlightTimeS += t
		cb.TurnPenalty += turn
		cb.ClimbCost += climb
		flightElapsed += segTime

		curX, curY, curH = x, y, h
		prevHX, prevHY, havePrevHeading = hx, hy, true
	}
	// Final return to base.
	cb.FlightTimeS += returnTimeFrom(curX, curY)

	cb.Total = cb.FlightTimeS +
		wTurn*cb.TurnPenalty +
		wClimb*cb.ClimbCost +
		wSwap*float64(cb.BatterySwaps) +
		wViol*cb.Violations
	cb.Feasible = cb.Violations == 0
	return cb
}

func wTurnSeconds(turnRad float64) float64  { return wTurn * turnRad }
func wClimbSeconds(climbM float64) float64 { return wClimb * climbM }

// SortedOrder returns the cells sorted by ascending key value, which is the
// visiting order encoded by the chromosome.
func SortedOrder(chrom Chromosome, cells [][2]int) [][2]int {
	idx := make([]int, len(chrom))
	for i := range idx {
		idx[i] = i
	}
	sort.Slice(idx, func(a, b int) bool { return chrom[idx[a]] < chrom[idx[b]] })
	out := make([][2]int, len(idx))
	for i, id := range idx {
		out[i] = cells[id]
	}
	return out
}
