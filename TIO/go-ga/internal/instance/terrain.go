package instance

import "math/rand"

// GenerateFlat builds a Width x Height instance with terrain = 0 everywhere
// (baseline, no elevation cost at all).
func GenerateFlat(width, height int, cellSizeM float64) []float64 {
	return make([]float64, width*height)
}

// GenerateHilly builds a synthetic terrain using value noise (coarse random
// grid + bilinear interpolation, summed over a couple of octaves). amplitudeM
// is the approximate peak-to-peak relief; ~15-25 m matches typical moraine
// hill country relief in the Polish Lowlands (no steep slopes, just rolling
// terrain), which is the target profile for the "hilly" synthetic instance.
func GenerateHilly(width, height int, amplitudeM float64, seed int64) []float64 {
	rng := rand.New(rand.NewSource(seed))
	terrain := make([]float64, width*height)

	octaves := []struct {
		cells float64 // coarse-grid cell size, in fine cells
		weight float64
	}{
		{cells: 10, weight: 0.65},
		{cells: 4, weight: 0.35},
	}

	for _, oct := range octaves {
		coarseW := int(float64(width)/oct.cells) + 2
		coarseH := int(float64(height)/oct.cells) + 2
		coarse := make([][]float64, coarseH)
		for j := range coarse {
			coarse[j] = make([]float64, coarseW)
			for i := range coarse[j] {
				coarse[j][i] = rng.Float64()*2 - 1
			}
		}

		for y := 0; y < height; y++ {
			fy := float64(y) / oct.cells
			j0 := int(fy)
			ty := fy - float64(j0)
			for x := 0; x < width; x++ {
				fx := float64(x) / oct.cells
				i0 := int(fx)
				tx := fx - float64(i0)

				v00 := coarse[j0][i0]
				v10 := coarse[j0][i0+1]
				v01 := coarse[j0+1][i0]
				v11 := coarse[j0+1][i0+1]
				v0 := v00*(1-tx) + v10*tx
				v1 := v01*(1-tx) + v11*tx
				v := v0*(1-ty) + v1*ty

				terrain[y*width+x] += v * oct.weight
			}
		}
	}

	// Normalize to [0, amplitudeM].
	min, max := terrain[0], terrain[0]
	for _, v := range terrain {
		if v < min {
			min = v
		}
		if v > max {
			max = v
		}
	}
	span := max - min
	if span == 0 {
		span = 1
	}
	for i, v := range terrain {
		terrain[i] = (v - min) / span * amplitudeM
	}
	return terrain
}
