package ga

import "math/rand"

// TournamentSelect picks the best (lowest cost) of k individuals drawn
// uniformly at random (with replacement) from the population.
func TournamentSelect(pop []Chromosome, costs []float64, k int, rng *rand.Rand) Chromosome {
	bestIdx := rng.Intn(len(pop))
	for i := 1; i < k; i++ {
		c := rng.Intn(len(pop))
		if costs[c] < costs[bestIdx] {
			bestIdx = c
		}
	}
	return pop[bestIdx]
}

// OnePointCrossover swaps the tails of two parents after a random cut point.
// Any cut point yields two valid random-keys chromosomes (no repair needed).
func OnePointCrossover(p1, p2 Chromosome, rng *rand.Rand) (Chromosome, Chromosome) {
	n := len(p1)
	cut := 1 + rng.Intn(n-1)
	c1 := make(Chromosome, n)
	c2 := make(Chromosome, n)
	copy(c1[:cut], p1[:cut])
	copy(c1[cut:], p2[cut:])
	copy(c2[:cut], p2[:cut])
	copy(c2[cut:], p1[cut:])
	return c1, c2
}

// ResetMutate replaces each gene with a fresh random key with probability pm.
func ResetMutate(c Chromosome, pm float64, rng *rand.Rand) {
	for i := range c {
		if rng.Float64() < pm {
			c[i] = rng.Float64()
		}
	}
}

func RandomChromosome(n int, rng *rand.Rand) Chromosome {
	c := make(Chromosome, n)
	for i := range c {
		c[i] = rng.Float64()
	}
	return c
}
