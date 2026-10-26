package ga

import (
	"math/rand"

	"dronepath/internal/instance"
)

type Config struct {
	PopSize       int
	MaxGenerations int
	StallGenerations int // stop if no improvement for this many generations
	Pc            float64
	Pm            float64
	TournamentK   int
	Seed          int64
}

type GenStat struct {
	Generation int
	BestCost   float64
	AvgCost    float64
}

type Result struct {
	BestChromosome Chromosome
	BestCost       CostBreakdown
	History        []GenStat
	Evaluations    int
}

// Run executes the basic genetic algorithm (task 1): random-keys chromosome,
// tournament selection, one-point crossover, reset mutation, stopping on
// MaxGenerations or StallGenerations without improvement.
func Run(cfg Config, cells [][2]int, inst *instance.Instance) Result {
	rng := rand.New(rand.NewSource(cfg.Seed))
	n := len(cells)

	pop := make([]Chromosome, cfg.PopSize)
	costs := make([]float64, cfg.PopSize)
	breakdowns := make([]CostBreakdown, cfg.PopSize)
	evals := 0

	for i := range pop {
		pop[i] = RandomChromosome(n, rng)
		breakdowns[i] = Decode(pop[i], cells, inst)
		costs[i] = breakdowns[i].Total
		evals++
	}

	bestIdx := argmin(costs)
	best := pop[bestIdx]
	bestCB := breakdowns[bestIdx]
	stall := 0

	history := make([]GenStat, 0, cfg.MaxGenerations)
	history = append(history, snapshot(0, costs))

	for gen := 1; gen <= cfg.MaxGenerations; gen++ {
		newPop := make([]Chromosome, 0, cfg.PopSize)
		for len(newPop) < cfg.PopSize {
			p1 := TournamentSelect(pop, costs, cfg.TournamentK, rng)
			p2 := TournamentSelect(pop, costs, cfg.TournamentK, rng)

			var c1, c2 Chromosome
			if rng.Float64() < cfg.Pc {
				c1, c2 = OnePointCrossover(p1, p2, rng)
			} else {
				c1, c2 = cloneChrom(p1), cloneChrom(p2)
			}
			ResetMutate(c1, cfg.Pm, rng)
			ResetMutate(c2, cfg.Pm, rng)
			newPop = append(newPop, c1, c2)
		}
		newPop = newPop[:cfg.PopSize]

		newCosts := make([]float64, cfg.PopSize)
		newBreakdowns := make([]CostBreakdown, cfg.PopSize)
		for i, c := range newPop {
			newBreakdowns[i] = Decode(c, cells, inst)
			newCosts[i] = newBreakdowns[i].Total
			evals++
		}
		pop, costs, breakdowns = newPop, newCosts, newBreakdowns

		genBestIdx := argmin(costs)
		if costs[genBestIdx] < bestCB.Total {
			best = pop[genBestIdx]
			bestCB = breakdowns[genBestIdx]
			stall = 0
		} else {
			stall++
		}
		history = append(history, snapshot(gen, costs))
		if stall >= cfg.StallGenerations {
			break
		}
	}

	return Result{BestChromosome: best, BestCost: bestCB, History: history, Evaluations: evals}
}

func snapshot(gen int, costs []float64) GenStat {
	sum := 0.0
	best := costs[0]
	for _, c := range costs {
		sum += c
		if c < best {
			best = c
		}
	}
	return GenStat{Generation: gen, BestCost: best, AvgCost: sum / float64(len(costs))}
}

func argmin(xs []float64) int {
	best := 0
	for i, x := range xs {
		if x < xs[best] {
			best = i
		}
	}
	return best
}

func cloneChrom(c Chromosome) Chromosome {
	out := make(Chromosome, len(c))
	copy(out, c)
	return out
}
