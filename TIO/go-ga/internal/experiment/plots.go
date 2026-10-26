package experiment

import (
	"encoding/csv"
	"fmt"
	"os"
	"sort"

	"gonum.org/v1/plot"
	"gonum.org/v1/plot/plotter"
	"gonum.org/v1/plot/plotutil"
	"gonum.org/v1/plot/vg"
)

type Row struct {
	Instance   string
	Config     string
	Seed       int
	Generation int
	BestCost   float64
	AvgCost    float64
}

func LoadRows(path string) ([]Row, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	recs, err := csv.NewReader(f).ReadAll()
	if err != nil {
		return nil, err
	}
	rows := make([]Row, 0, len(recs)-1)
	for _, rec := range recs[1:] {
		var r Row
		r.Instance, r.Config = rec[0], rec[2]
		fmt.Sscanf(rec[3], "%d", &r.Seed)
		fmt.Sscanf(rec[4], "%d", &r.Generation)
		fmt.Sscanf(rec[6], "%f", &r.BestCost)
		fmt.Sscanf(rec[7], "%f", &r.AvgCost)
		rows = append(rows, r)
	}
	return rows, nil
}

// ConvergencePlot draws, for one instance, the mean-over-seeds best_cost per
// generation for each of the given configs, one line per config.
func ConvergencePlot(rows []Row, instanceName string, configs []string, outPath string) error {
	p := plot.New()
	p.Title.Text = fmt.Sprintf("GA convergence — %s", instanceName)
	p.X.Label.Text = "generation"
	p.Y.Label.Text = "best cost (s)"

	type genKey struct {
		config string
		gen    int
	}
	sums := map[genKey]float64{}
	counts := map[genKey]int{}
	for _, r := range rows {
		if r.Instance != instanceName {
			continue
		}
		k := genKey{r.Config, r.Generation}
		sums[k] += r.BestCost
		counts[k]++
	}

	var plotArgs []interface{}
	for _, cfg := range configs {
		maxGen := 0
		for k := range counts {
			if k.config == cfg && k.gen > maxGen {
				maxGen = k.gen
			}
		}
		pts := make(plotter.XYs, 0, maxGen+1)
		for g := 0; g <= maxGen; g++ {
			k := genKey{cfg, g}
			if counts[k] == 0 {
				continue
			}
			pts = append(pts, plotter.XY{X: float64(g), Y: sums[k] / float64(counts[k])})
		}
		plotArgs = append(plotArgs, cfg, pts)
	}
	if err := plotutil.AddLines(p, plotArgs...); err != nil {
		return err
	}
	return p.Save(6*vg.Inch, 4*vg.Inch, outPath)
}

// FinalCostBarChart draws one bar per config (final-generation mean best
// cost across seeds) for the given instance.
func FinalCostBarChart(rows []Row, instanceName string, outPath string) error {
	type agg struct {
		sum   float64
		count int
	}
	finalByConfigSeed := map[string]map[int]float64{} // config -> seed -> last-seen best_cost
	for _, r := range rows {
		if r.Instance != instanceName {
			continue
		}
		if finalByConfigSeed[r.Config] == nil {
			finalByConfigSeed[r.Config] = map[int]float64{}
		}
		finalByConfigSeed[r.Config][r.Seed] = r.BestCost
	}

	configs := make([]string, 0, len(finalByConfigSeed))
	for c := range finalByConfigSeed {
		configs = append(configs, c)
	}
	sort.Strings(configs)

	values := make(plotter.Values, len(configs))
	for i, c := range configs {
		a := agg{}
		for _, v := range finalByConfigSeed[c] {
			a.sum += v
			a.count++
		}
		values[i] = a.sum / float64(a.count)
	}

	p := plot.New()
	p.Title.Text = fmt.Sprintf("Final best cost by config — %s", instanceName)
	p.Y.Label.Text = "mean best cost (s)"

	bars, err := plotter.NewBarChart(values, vg.Points(20))
	if err != nil {
		return err
	}
	p.Add(bars)
	p.NominalX(configs...)
	p.X.Tick.Label.Rotation = -0.5
	p.X.Tick.Label.YAlign = -0.5
	p.X.Tick.Label.XAlign = -0.3

	return p.Save(10*vg.Inch, 6*vg.Inch, outPath)
}
