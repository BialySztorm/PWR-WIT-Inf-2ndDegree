// Package instance defines the drone coverage-path-planning problem instance
// (grid, terrain, flight/camera/battery parameters) and its JSON (de)serialization.
package instance

import (
	"encoding/json"
	"os"
)

type Grid struct {
	CellSizeM float64 `json:"cell_size_m"`
	Width     int     `json:"width"`
	Height    int     `json:"height"`
}

type Flight struct {
	Mode                 string  `json:"mode"` // "agl" or "amsl"
	AGLTargetM           float64 `json:"agl_target_m"`
	AMSLM                float64 `json:"amsl_m"`
	MinClearanceM        float64 `json:"min_clearance_m"`
	LegalMaxAGLM         float64 `json:"legal_max_agl_m"`
	DroneMaxRelTakeoffM  float64 `json:"drone_max_rel_takeoff_m"`
	SpeedMps             float64 `json:"speed_mps"`
}

type Camera struct {
	HFOVDeg     float64 `json:"hfov_deg"`
	Aspect      string  `json:"aspect"`
	OverlapFront float64 `json:"overlap_front"`
	OverlapSide  float64 `json:"overlap_side"`
}

type Battery struct {
	UsableFlightS float64 `json:"usable_flight_s"`
	SwapTimeS     float64 `json:"swap_time_s"`
}

type Candidate struct {
	Label string  `json:"label"`
	X     int     `json:"x"`
	Y     int     `json:"y"`
}

type Takeoff struct {
	Mode       string      `json:"mode"` // "fixed" for task 1
	Candidates []Candidate `json:"candidates"`
}

// Instance is the full problem instance consumed by the GA.
// Terrain is a flattened row-major height map (meters, ground level), size Width*Height.
type Instance struct {
	Name          string    `json:"name"`
	Grid          Grid      `json:"grid"`
	Terrain       []float64 `json:"terrain"`
	ExcludedCells [][2]int  `json:"excluded_cells"`
	Flight        Flight    `json:"flight"`
	Camera        Camera    `json:"camera"`
	Battery       Battery   `json:"battery"`
	Takeoff       Takeoff   `json:"takeoff"`
}

func (inst *Instance) CellCount() int { return inst.Grid.Width * inst.Grid.Height }

func (inst *Instance) Idx(x, y int) int { return y*inst.Grid.Width + x }

func (inst *Instance) HeightAt(x, y int) float64 { return inst.Terrain[inst.Idx(x, y)] }

func (inst *Instance) excludedSet() map[[2]int]bool {
	m := make(map[[2]int]bool, len(inst.ExcludedCells))
	for _, c := range inst.ExcludedCells {
		m[c] = true
	}
	return m
}

// IncludedCells returns the list of (x, y) grid coordinates eligible for a photo shot,
// i.e. all cells minus excluded_cells.
func (inst *Instance) IncludedCells() [][2]int {
	excl := inst.excludedSet()
	cells := make([][2]int, 0, inst.CellCount())
	for y := 0; y < inst.Grid.Height; y++ {
		for x := 0; x < inst.Grid.Width; x++ {
			if !excl[[2]int{x, y}] {
				cells = append(cells, [2]int{x, y})
			}
		}
	}
	return cells
}

func (inst *Instance) StartXY() (float64, float64) {
	c := inst.Takeoff.Candidates[0]
	return float64(c.X) * inst.Grid.CellSizeM, float64(c.Y) * inst.Grid.CellSizeM
}

func Load(path string) (*Instance, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var inst Instance
	if err := json.Unmarshal(data, &inst); err != nil {
		return nil, err
	}
	return &inst, nil
}

func (inst *Instance) Save(path string) error {
	data, err := json.MarshalIndent(inst, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0o644)
}
