// Package experiment runs parameter sweeps of the GA over multiple seeds and
// writes raw results to CSV (results/*.csv), following the shared schema
// from lab-objectives.md section 3.2.
package experiment

import (
	"encoding/csv"
	"fmt"
	"os"

	"dronepath/internal/ga"
	"dronepath/internal/instance"
)

type SweepPoint struct {
	Pc float64
	Pm float64
}

// RunSweep runs cfg (with Pc/Pm overridden per sweep point) over `seeds`
// random seeds for each sweep point, against the given instance, and
// appends one row per generation of every run to w.
func RunSweep(w *csv.Writer, instanceName string, methodLabel string, cfg ga.Config, points []SweepPoint, seeds []int64, cells [][2]int, inst *instance.Instance) error {
	for _, p := range points {
		configID := fmt.Sprintf("pc=%.3f_pm=%.3f", p.Pc, p.Pm)
		for _, seed := range seeds {
			runCfg := cfg
			runCfg.Pc = p.Pc
			runCfg.Pm = p.Pm
			runCfg.Seed = seed

			res := ga.Run(runCfg, cells, inst)
			for _, h := range res.History {
				row := []string{
					instanceName,
					methodLabel,
					configID,
					fmt.Sprintf("%d", seed),
					fmt.Sprintf("%d", h.Generation),
					fmt.Sprintf("%d", res.Evaluations),
					fmt.Sprintf("%.6f", h.BestCost),
					fmt.Sprintf("%.6f", h.AvgCost),
					fmt.Sprintf("%t", res.BestCost.Feasible),
				}
				if err := w.Write(row); err != nil {
					return err
				}
			}
		}
	}
	return nil
}

func WriteHeader(w *csv.Writer) error {
	return w.Write([]string{"instance", "method", "config_id", "seed", "generation", "evaluations", "best_cost", "avg_cost", "feasible"})
}

func OpenCSV(path string) (*os.File, *csv.Writer, error) {
	f, err := os.Create(path)
	if err != nil {
		return nil, nil, err
	}
	w := csv.NewWriter(f)
	return f, w, nil
}

// OpenCSVAppend opens an existing CSV for appending more rows (no header
// rewrite), used when adding real-terrain instance runs to an
// already-written results file.
func OpenCSVAppend(path string) (*os.File, *csv.Writer, error) {
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, nil, err
	}
	w := csv.NewWriter(f)
	return f, w, nil
}
