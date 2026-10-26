// Command dronega is the task-1 CLI: generate synthetic instances, run the
// p_c x p_m parameter sweep, and print a summary comparison table.
package main

import (
	"encoding/csv"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"dronepath/internal/baseline"
	"dronepath/internal/experiment"
	"dronepath/internal/ga"
	"dronepath/internal/instance"
)

// Config reused for route export and real-terrain runs: near-best per
// task1_go_ga.csv findings (see go-ga/RESULTS.md).
var bestGAConfig = ga.Config{
	PopSize:          20,
	MaxGenerations:   150,
	StallGenerations: 30,
	TournamentK:      3,
	Pc:               0.95,
	Pm:               0.005,
}

type registryEntry struct {
	Slug  string `json:"slug"`
	Type  string `json:"type"`
	Label string `json:"label"`
}

type registry struct {
	Instances []registryEntry `json:"instances"`
}

// loadRegistry reads the shared data/instances.json manifest (see
// scripts/fetch_terrain.py), which lists which instance files exist across
// all 3 solver pipelines. Missing file is treated as an empty registry.
func loadRegistry(dataDir string) registry {
	path := filepath.Join(dataDir, "instances.json")
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return registry{}
	}
	if err != nil {
		log.Fatal(err)
	}
	var r registry
	if err := json.Unmarshal(data, &r); err != nil {
		log.Fatal(err)
	}
	return r
}

// upsertRegistry adds or replaces (by slug) an entry in data/instances.json.
func upsertRegistry(dataDir string, entry registryEntry) {
	r := loadRegistry(dataDir)
	kept := make([]registryEntry, 0, len(r.Instances)+1)
	for _, e := range r.Instances {
		if e.Slug != entry.Slug {
			kept = append(kept, e)
		}
	}
	r.Instances = append(kept, entry)

	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		log.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dataDir, "instances.json"), data, 0o644); err != nil {
		log.Fatal(err)
	}
}

func slugsByType(dataDir string, types ...string) []string {
	r := loadRegistry(dataDir)
	want := map[string]bool{}
	for _, t := range types {
		want[t] = true
	}
	var out []string
	for _, e := range r.Instances {
		if want[e.Type] {
			out = append(out, e.Slug)
		}
	}
	return out
}

type costJSON struct {
	FlightTimeS    float64 `json:"flight_time_s"`
	TurnPenalty    float64 `json:"turn_penalty"`
	ClimbCost      float64 `json:"climb_cost"`
	BatterySwaps   int     `json:"battery_swaps"`
	SwapBeforeStep []int   `json:"swap_before_step"`
	Violations     float64 `json:"violations"`
	Total          float64 `json:"total"`
	Feasible       bool    `json:"feasible"`
}

func toCostJSON(cb ga.CostBreakdown) costJSON {
	return costJSON{
		FlightTimeS:    cb.FlightTimeS,
		TurnPenalty:    cb.TurnPenalty,
		ClimbCost:      cb.ClimbCost,
		BatterySwaps:   cb.BatterySwaps,
		SwapBeforeStep: cb.SwapBeforeStep,
		Violations:     cb.Violations,
		Total:          cb.Total,
		Feasible:       cb.Feasible,
	}
}

type routeFile struct {
	Instance string   `json:"instance"`
	Method   string   `json:"method"`
	ConfigID string   `json:"config_id"`
	Order    [][2]int `json:"order"`
	Cost     costJSON `json:"cost"`
}

func writeRouteFile(routesDir, instanceName, method, configID string, order [][2]int, cost ga.CostBreakdown) error {
	rf := routeFile{Instance: instanceName, Method: method, ConfigID: configID, Order: order, Cost: toCostJSON(cost)}
	data, err := json.MarshalIndent(rf, "", "  ")
	if err != nil {
		return err
	}
	path := filepath.Join(routesDir, fmt.Sprintf("%s_%s.json", instanceName, method))
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return err
	}
	fmt.Printf("wrote %s\n", path)
	return nil
}

func genRoutes(dataDir, routesDir string) {
	if err := os.MkdirAll(routesDir, 0o755); err != nil {
		log.Fatal(err)
	}
	for _, name := range slugsByType(dataDir, "synthetic", "real") {
		inst, err := instance.Load(filepath.Join(dataDir, name+".json"))
		if err != nil {
			log.Fatalf("load %s: %v", name, err)
		}
		cells := inst.IncludedCells()

		base := baseline.Boustrophedon(inst)
		baseCost := ga.DecodeOrder(base, inst)
		if err := writeRouteFile(routesDir, name, "baseline", "boustrophedon", base, baseCost); err != nil {
			log.Fatal(err)
		}

		cfg := bestGAConfig
		cfg.Seed = 0
		res := ga.Run(cfg, cells, inst)
		order := ga.SortedOrder(res.BestChromosome, cells)
		configID := fmt.Sprintf("pc=%.3f_pm=%.3f", cfg.Pc, cfg.Pm)
		if err := writeRouteFile(routesDir, name, "ga_best_go", configID, order, res.BestCost); err != nil {
			log.Fatal(err)
		}
	}
}

func runReal(dataDir, resultsPath string) {
	seeds := make([]int64, 10)
	for i := range seeds {
		seeds[i] = int64(i)
	}
	points := []experiment.SweepPoint{{Pc: bestGAConfig.Pc, Pm: bestGAConfig.Pm}}

	f, w, err := experiment.OpenCSVAppend(resultsPath)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	for _, name := range slugsByType(dataDir, "real") {
		inst, err := instance.Load(filepath.Join(dataDir, name+".json"))
		if err != nil {
			log.Fatalf("load %s: %v", name, err)
		}
		cells := inst.IncludedCells()

		base := baseline.Boustrophedon(inst)
		baseCost := ga.DecodeOrder(base, inst)
		fmt.Printf("[%s] baseline (boustrophedon): total=%.1fs feasible=%t\n", name, baseCost.Total, baseCost.Feasible)

		fmt.Printf("[%s] running best config x %d seeds...\n", name, len(seeds))
		if err := experiment.RunSweep(w, name, "ga_real_best", bestGAConfig, points, seeds, cells, inst); err != nil {
			log.Fatal(err)
		}
		w.Flush()
	}
	fmt.Printf("appended real-instance runs to %s\n", resultsPath)
}

const (
	gridWidth  = 40
	gridHeight = 30
	cellSizeM  = 25.0
)

func baseFlight() instance.Flight {
	return instance.Flight{
		Mode:                "agl",
		AGLTargetM:          60,
		MinClearanceM:       10,
		LegalMaxAGLM:        120,
		DroneMaxRelTakeoffM: 120,
		SpeedMps:            8,
	}
}

func baseCamera() instance.Camera {
	return instance.Camera{HFOVDeg: 70, Aspect: "4:3", OverlapFront: 0.7, OverlapSide: 0.6}
}

func baseBattery() instance.Battery {
	return instance.Battery{UsableFlightS: 1200, SwapTimeS: 120}
}

func startCandidate() instance.Takeoff {
	return instance.Takeoff{Mode: "fixed", Candidates: []instance.Candidate{{Label: "base", X: 0, Y: 0}}}
}

func buildInstance(name string, terrain []float64) *instance.Instance {
	return &instance.Instance{
		Name:    name,
		Grid:    instance.Grid{CellSizeM: cellSizeM, Width: gridWidth, Height: gridHeight},
		Terrain: terrain,
		Flight:  baseFlight(),
		Camera:  baseCamera(),
		Battery: baseBattery(),
		Takeoff: startCandidate(),
	}
}

func genInstances(dataDir string) {
	flat := buildInstance("flat", instance.GenerateFlat(gridWidth, gridHeight, cellSizeM))
	hilly := buildInstance("hilly", instance.GenerateHilly(gridWidth, gridHeight, 20.0, 42))

	for _, inst := range []*instance.Instance{flat, hilly} {
		path := filepath.Join(dataDir, inst.Name+".json")
		if err := inst.Save(path); err != nil {
			log.Fatalf("save %s: %v", path, err)
		}
		fmt.Printf("wrote %s (%d cells)\n", path, inst.CellCount())
		upsertRegistry(dataDir, registryEntry{Slug: inst.Name, Type: "synthetic", Label: inst.Name + " (synthetic)"})
	}
}

func runSweep(dataDir, resultsPath string) {
	instances := slugsByType(dataDir, "synthetic")
	points := []experiment.SweepPoint{
		{Pc: 0.6, Pm: 0.005}, {Pc: 0.6, Pm: 0.01}, {Pc: 0.6, Pm: 0.05},
		{Pc: 0.8, Pm: 0.005}, {Pc: 0.8, Pm: 0.01}, {Pc: 0.8, Pm: 0.05},
		{Pc: 0.95, Pm: 0.005}, {Pc: 0.95, Pm: 0.01}, {Pc: 0.95, Pm: 0.05},
	}
	seeds := make([]int64, 10)
	for i := range seeds {
		seeds[i] = int64(i)
	}

	cfg := ga.Config{
		PopSize:          20,
		MaxGenerations:   150,
		StallGenerations: 30,
		TournamentK:      3,
	}

	f, w, err := experiment.OpenCSV(resultsPath)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	if err := experiment.WriteHeader(w); err != nil {
		log.Fatal(err)
	}

	for _, name := range instances {
		inst, err := instance.Load(filepath.Join(dataDir, name+".json"))
		if err != nil {
			log.Fatalf("load %s: %v", name, err)
		}
		cells := inst.IncludedCells()

		base := baseline.Boustrophedon(inst)
		baseCost := ga.DecodeOrder(base, inst)
		fmt.Printf("[%s] baseline (boustrophedon): total=%.1fs feasible=%t\n", name, baseCost.Total, baseCost.Feasible)

		fmt.Printf("[%s] running %d configs x %d seeds...\n", name, len(points), len(seeds))
		if err := experiment.RunSweep(w, name, "ga_tournament_onepoint_reset", cfg, points, seeds, cells, inst); err != nil {
			log.Fatal(err)
		}
		w.Flush()
	}
	fmt.Printf("wrote %s\n", resultsPath)
}

func summarize(resultsPath string) {
	f, err := os.Open(resultsPath)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	r := csv.NewReader(f)
	rows, err := r.ReadAll()
	if err != nil {
		log.Fatal(err)
	}
	if len(rows) < 2 {
		fmt.Println("no data")
		return
	}

	type key struct{ instance, config string }
	finalByRun := map[key]map[string]float64{} // key -> seed -> best_cost (last generation seen)
	for _, row := range rows[1:] {
		inst, config, seed, bestCostStr := row[0], row[2], row[3], row[6]
		var bestCost float64
		fmt.Sscanf(bestCostStr, "%f", &bestCost)
		k := key{inst, config}
		if finalByRun[k] == nil {
			finalByRun[k] = map[string]float64{}
		}
		finalByRun[k][seed] = bestCost // later rows (higher generation) overwrite earlier ones
	}

	fmt.Println("\ninstance        config                avg_best    min_best    max_best    n_seeds")
	for k, bySeed := range finalByRun {
		sum, min, max := 0.0, mapFirst(bySeed), mapFirst(bySeed)
		for _, v := range bySeed {
			sum += v
			if v < min {
				min = v
			}
			if v > max {
				max = v
			}
		}
		n := len(bySeed)
		fmt.Printf("%-15s %-22s %10.1f %10.1f %10.1f %10d\n", k.instance, k.config, sum/float64(n), min, max, n)
	}
}

func mapFirst(m map[string]float64) float64 {
	for _, v := range m {
		return v
	}
	return 0
}

func makePlots(dataDir, resultsPath, plotsDir string) {
	rows, err := experiment.LoadRows(resultsPath)
	if err != nil {
		log.Fatal(err)
	}
	pmSweepAtPc95 := []string{"pc=0.950_pm=0.005", "pc=0.950_pm=0.010", "pc=0.950_pm=0.050"}
	for _, instName := range slugsByType(dataDir, "synthetic") {
		convPath := filepath.Join(plotsDir, "convergence_"+instName+".png")
		if err := experiment.ConvergencePlot(rows, instName, pmSweepAtPc95, convPath); err != nil {
			log.Fatal(err)
		}
		fmt.Println("wrote", convPath)

		barPath := filepath.Join(plotsDir, "final_cost_"+instName+".png")
		if err := experiment.FinalCostBarChart(rows, instName, barPath); err != nil {
			log.Fatal(err)
		}
		fmt.Println("wrote", barPath)
	}

	// Real instances only ever ran the single bestGAConfig (via runReal), no
	// hyperparameter sweep, so a "top configs" bar chart would be meaningless
	// with n=1 — only a convergence plot for that one config makes sense.
	realConfig := []string{fmt.Sprintf("pc=%.3f_pm=%.3f", bestGAConfig.Pc, bestGAConfig.Pm)}
	for _, instName := range slugsByType(dataDir, "real") {
		convPath := filepath.Join(plotsDir, "convergence_"+instName+".png")
		if err := experiment.ConvergencePlot(rows, instName, realConfig, convPath); err != nil {
			log.Fatal(err)
		}
		fmt.Println("wrote", convPath)
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: dronega <gen-instances|run|summarize|plots|routes|run-real>")
		os.Exit(1)
	}

	dataDir := filepath.Join("..", "data")
	resultsPath := filepath.Join("..", "results", "task1_go_ga.csv")
	plotsDir := filepath.Join("..", "plots", "task1-go")
	routesDir := filepath.Join("..", "results", "routes")

	switch os.Args[1] {
	case "gen-instances":
		genInstances(dataDir)
	case "run":
		runSweep(dataDir, resultsPath)
	case "summarize":
		summarize(resultsPath)
	case "plots":
		makePlots(dataDir, resultsPath, plotsDir)
	case "routes":
		genRoutes(dataDir, routesDir)
	case "run-real":
		runReal(dataDir, resultsPath)
	default:
		fmt.Println("unknown command:", os.Args[1])
		os.Exit(1)
	}
}
