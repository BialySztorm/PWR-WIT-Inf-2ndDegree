# TIO Lab — planowanie trasy drona do fotogrametrii

Techniki Inteligencji Obliczeniowej, laboratorium, PWr WIT, semestr zimowy 2026/27.
Pełny opis problemu, zakresu zadań i badań: [`lab-objectives.md`](lab-objectives.md).

## Struktura repozytorium

```
TIO/
├── data/            # wspólne instancje (JSON) + kafle NMT/NMPT
│   └── dem/
├── results/         # CSV z przebiegów wszystkich metod (wspólny schemat, patrz lab-objectives.md §3.2)
├── plots/           # wygenerowane wykresy, jeden podkatalog na zadanie
│   ├── task1-go/
│   ├── task2-rust/
│   └── task3-julia/
├── go-ga/           # Zadanie 1: podstawowy GA (Go)
├── rust-ga/         # Zadanie 2: rozszerzony GA (Rust)
└── julia-aco/       # Zadanie 3: ACO + porównanie z GA (Julia)
```

## Zadania

| Zadanie | Termin | Zakres | Język | Katalog |
|---|---|---|---|---|
| 1 | 27.10.2026 | Podstawowy GA | Go | `go-ga/` |
| 2 | 10.11.2026 | Rozszerzony GA (selekcje, krzyżowania, mutacje, elitarność) | Rust | `rust-ga/` |
| 3 | 01.12.2026 | ACO + porównanie z GA | Julia | `julia-aco/` |

## Toolchainy

| Język | Moduł/pakiet | Build | Run |
|---|---|---|---|
| Go | `dronepath` (`go-ga/go.mod`) | `go build ./...` | `go run .` |
| Rust | `dronepath` (`rust-ga/Cargo.toml`) | `cargo build` | `cargo run` |
| Julia | `DronePath` (`julia-aco/Project.toml`) | `julia --project=. -e "using Pkg; Pkg.instantiate()"` | `julia --project=.` |

Rdzeń algorytmów pisany bez zewnętrznych bibliotek. Biblioteki (wykresy, statystyka, I/O) — patrz `lab-objectives.md` §3.

## Zasady

- Rdzeń algorytmów IO samodzielny, bez zewnętrznych bibliotek.
- Każdy program zapisuje wyniki do `results/` (CSV) i generuje własne wykresy do `plots/`.
- Porównania między metodami: po liczbie wywołań funkcji celu, nie po czasie.
