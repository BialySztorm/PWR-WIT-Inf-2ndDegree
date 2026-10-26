# TIO Lab — planowanie trasy drona do fotogrametrii

Techniki inteligencji obliczeniowej, laboratorium, PWr WIT, semestr zimowy 2026/27.
Temat i języki zatwierdzone przez prowadzącego.

---

## 1. Kontekst przedmiotu

| Zadanie | Termin | Zakres | Język |
|---|---|---|---|
| 1 | 27.10.2026 | Podstawowy GA | Go |
| 2 | 10.11.2026 | Rozszerzenie GA (selekcje, krzyżowania, mutacje, elitarność) | Rust |
| 3 | 01.12.2026 | Inna metoda IO + porównanie z GA | Julia |
| 4 | 05.01.2027 | MLP (w parze) | Python |
| 5 | 26.01.2027 | DNN (w parze) | Python |

**Zasady, które wpływają na projekt:**
- Rdzeń algorytmów IO pisany samodzielnie, bez zewnętrznych bibliotek. Biblioteki wolno użyć do interfejsu, wczytywania danych i badań (wykresy, statystyka). Analiza i wykresy robione natywnie w Go, Ruście i Julii, bez Pythona (patrz sekcja 3).
- Kluczowe w ocenie są **badania**: porównania, wiele przebiegów, wnioski.
- Terminy są nieprzekraczalne. Zadania prezentowane na zajęciach, trzeba umieć wyjaśnić każdą decyzję.
- AI dozwolone zgodnie z wytycznymi WIT. Prowadzący może weryfikować zrozumienie w rozmowie.
- Zaliczenie: min. 50% punktów (max 10 pkt za zadanie).

---

## 2. Problem

**Coverage Path Planning dla drona:** zaplanować trasę drona wykonującego zdjęcia do fotogrametrii zadanego obszaru tak, aby:
- pokryć cały obszar zdjęciami z wymaganym zakładkowaniem,
- zminimalizować całkowity czas misji,
- spełnić ograniczenia prawne, sprzętowe i terenowe.

### 2.1. Obszar i siatka
- Obszar: wielokąt z przeszkodami i strefami zakazanymi.
- Obszar dzielony na siatkę komórek. Środek komórki to **kandydat na punkt wykonania zdjęcia**.
- Rozmiar komórki wynika z:
    - wysokości lotu nad terenem (AGL),
    - pola widzenia i proporcji kadru kamery,
    - wymaganego zakładkowania (np. 70% wzdłuż / 60% w poprzek).
- Komórki z przeszkodami i strefami zakazanymi są wyłączone.

### 2.2. Teren
- **NMT** (numeryczny model terenu): wysokość gruntu, źródło: Geoportal.
- **NMPT** (numeryczny model pokrycia terenu): grunt + budynki i drzewa.
- **Wysokość przeszkód = NMPT − NMT.**
- Instancje syntetyczne: teren generowany szumem (np. Perlin), teren płaski = same zera.

### 2.3. Tryby lotu (parametr instancji)

| | AGL (śledzenie terenu) | AMSL (stała wysokość) |
|---|---|---|
| Wysokość lotu | teren + `h_agl` | stała `A` |
| Ślad zdjęcia | stały | zmienny (zależy od AGL w danym punkcie) |
| Koszt pionowy | wznoszenie/opadanie | brak |
| Siatka | dla `h_agl` | dla **najmniejszej** AGL (nad najwyższym punktem) |

### 2.4. Ograniczenia

**Prawne (kategoria otwarta, UE 2019/947):**
- Maks. **120 m od najbliższego punktu powierzchni ziemi**, a nie od miejsca startu.
- W modelu: wysokość pionowa nad terenem ≤ 120 m. To podejście konserwatywne, bo odległość pionowa ≥ odległość do najbliższego punktu.

**Sprzętowe:**
- Limit wysokości drona liczony **względem punktu startu** (`drone_max_rel_takeoff_m`).
- Pojemność baterii: misja dzielona na loty (sorties), każdy zaczyna się i kończy w bazie.
- Wymiana baterii kosztuje czas.

**Terenowe:**
- Minimalny prześwit nad terenem i przeszkodami (`min_clearance_m`), sprawdzany **także na odcinkach między punktami** (przeloty nad grzbietami).
- Nad doliną po drodze nie wolno przekroczyć 120 m AGL.

**Opcjonalne:**
- VLOS: maks. odległość od operatora, przesłanianie przez teren.
- Maksymalne GSD (wymagana rozdzielczość) → górne ograniczenie AGL.

### 2.5. Wstępna walidacja wykonalności (przed uruchomieniem algorytmu)

Tryb AMSL, oznaczenia:
- `S_max`: najwyższy punkt powierzchni (NMPT) w obszarze i na przelotach,
- `T_min`: najniższy punkt terenu (NMT),
- `c`: minimalny prześwit,
- `H_start`: wysokość punktu startu.

Warunki:
```
A >= S_max + c
A <= T_min + 120
A - H_start <= drone_max_rel_takeoff_m
```
Misja wykonalna ⇔ przedział dla `A` jest niepusty (w uproszczeniu: deniwelacja `S_max − T_min < 120 − c`).
Program zwraca dopuszczalny zakres `A` albo informację, który warunek jest łamany i o ile metrów.

Tryb AGL: sprawdzenie `h_agl + c` względem przeszkód, `h_agl ≤ 120`, wysokości względem startu w skrajnych punktach.
Warunki zależne od kolejności (przeloty) trafiają jako kary do funkcji przystosowania.

### 2.6. Miejsce startu
- Użytkownik podaje **listę kandydatów** (albo jeden stały punkt).
- Automatyczne odrzucenie kandydatów:
    - `NMPT − NMT > 0.5 m` → dach, drzewo, przeszkoda,
    - nachylenie > `max_slope_deg`,
    - misja niewykonalna z tego punktu (wysokość, VLOS).
- Raport dla każdego kandydata: dopuszczalny / odrzucony + powód + najlepszy czas misji.

### 2.7. Pokrycie
- Komórka = **punkt wykonania zdjęcia**, a nie „obszar pokryty”.
- Rzeczywisty ślad zdjęcia: rzutowanie 4 narożników kadru na NMT (ray casting).
- Na stoku ślad jest zniekształcony. Dla połowy kąta widzenia θ, wysokości h, nachylenia α poziomy zasięg krawędzi:
    - płasko: `h·tanθ`
    - pod górę: `h·tanθ / (1 + tanθ·tanα)`
    - w dół: `h·tanθ / (1 − tanθ·tanα)`
- Ocena pokrycia na rastrze terenu (np. 1 m): ile zdjęć widzi każdy piksel, wymóg ≥ N.
- Ślad zależy tylko od pozycji i wysokości punktu, **nie od kolejności** → liczony raz (precompute).

### 2.8. Funkcja celu (minimalizacja)

```
cost = flight_time
     + w_turn  * turn_penalty
     + w_climb * climb_cost
     + w_swap  * battery_swaps
     + w_cov   * uncovered_penalty
     + w_viol  * constraint_violations
```

- `flight_time`: długość trasy / prędkość.
- `turn_penalty`: dron zwalnia na zmianach kierunku.
- `climb_cost`: wznoszenie zużywa więcej energii niż lot poziomy.
- Wagi kar dobrane tak, żeby rozwiązanie niedopuszczalne było zawsze gorsze od dopuszczalnego.

### 2.9. Punkt odniesienia (baseline)
Klasyczny plan „kosiarką” (boustrophedon). Każdy wynik algorytmów porównywany z baseline'em.

---

## 3. Rozkład języków i narzędzia

| Część | Język | IDE | Uzasadnienie |
|---|---|---|---|
| Zad. 1 | Go | IntelliJ IDEA Ultimate (wtyczka Go) | szybki rozbieg, krótki termin; goroutines do równoległych przebiegów |
| Zad. 2 | Rust | IntelliJ IDEA Ultimate (wtyczka Rust) | port + rozszerzenie; traity/enumy dla wielu operatorów; `rayon` do setek przebiegów |
| Zad. 3 | Julia | VS Code (rozszerzenie Julia) / Pluto.jl | nowa metoda od zera; obliczenia wektorowe; wykresy natywnie |
| Zad. 4–5 | Python | — | praca w parze |

**Analiza i wykresy robione natywnie w języku danego zadania.** Biblioteki są dozwolone do badań, ale nie do rdzenia algorytmu.

| Język | Wykresy | Dane / statystyka |
|---|---|---|
| Go | `gonum/plot` (linie, boxploty, heatmapy) | `encoding/csv`, `encoding/json` (stdlib), `gonum/stat` |
| Rust | `plotters` (linie, boxploty, heatmapy; PNG/SVG) | `csv`, `serde` / `serde_json`, `statrs` |
| Julia | `Plots.jl` lub `Makie.jl` | `CSV.jl`, `DataFrames.jl`, `JSON3.jl`, `Statistics` (stdlib) |

Uwagi:
- Każdy program zapisuje surowe wyniki do `results/` (CSV) **oraz** generuje własne wykresy. Dzięki temu wykresy są powtarzalne jednym poleceniem.
- Wykresy porównawcze między metodami (GA vs ACO) robione w Julii w zad. 3, na podstawie CSV z Go i Rusta.
- Spójny wygląd wykresów (kolory, opisy osi, jednostki) ustalony na początku, żeby sprawozdania wyglądały jednolicie.

### 3.1. Struktura repozytorium

```
tio-lab/
├── data/            # shared instances (JSON) + DEM tiles
├── results/         # CSV from all runs
├── plots/           # generated figures, one subfolder per task
├── go-ga/           # task 1 (algorithm + Go plotting)
├── rust-ga/         # task 2 (algorithm + Rust plotting)
└── julia-aco/       # task 3 (algorithm + cross-method comparison plots)
```

### 3.2. Wspólne formaty (ustalone od pierwszego dnia)

**Instancja (JSON)** czytana przez wszystkie trzy programy:

```json
{
  "name": "example_hilly_01",
  "grid": { "cell_size_m": 25.0, "width": 40, "height": 30 },
  "terrain": { "dtm": "dem/example_dtm.tif", "dsm": "dem/example_dsm.tif" },
  "excluded_cells": [[3, 4], [3, 5]],
  "flight": {
    "mode": "agl",
    "agl_target_m": 80,
    "amsl_m": 0,
    "min_clearance_m": 15,
    "legal_max_agl_m": 120,
    "drone_max_rel_takeoff_m": 120,
    "speed_mps": 10
  },
  "camera": { "hfov_deg": 0, "aspect": "4:3", "overlap_front": 0.7, "overlap_side": 0.6 },
  "battery": { "usable_flight_s": 0, "swap_time_s": 120 },
  "takeoff": {
    "mode": "choose",
    "max_slope_deg": 10,
    "max_obstacle_height_m": 0.5,
    "candidates": [{ "label": "driveway", "x": 0, "y": 0 }]
  }
}
```

Wartości `0` do uzupełnienia rzeczywistymi parametrami drona i kamery.

**Wyniki (CSV)** jednakowe dla wszystkich metod:

```
instance,method,config_id,seed,generation,evaluations,best_cost,avg_cost,feasible
```

Kolumna `evaluations` (liczba wywołań funkcji celu) jest podstawą uczciwego porównania metod (patrz zad. 3).

---

## 4. Zadanie 1: podstawowy GA (Go, 27.10.2026)

### Wymagania prowadzącego
- Chromosom adekwatny do problemu, własna funkcja przystosowania.
- Tylko krzyżowanie jednopunktowe + mutacja, jedna metoda selekcji, warunek stopu.
- Kilka uruchomień na tych samych danych, mała populacja, różne `p_c` i `p_m`.
- Proste badania porównawcze.

### Projekt
- **Chromosom:** wektor kluczy losowych (random keys), jedna liczba z [0, 1) na komórkę.
    - Sortowanie kluczy → kolejność odwiedzin komórek.
    - **Krzyżowanie jednopunktowe zawsze daje poprawną permutację**, więc naprawa nie jest potrzebna.
- **Dekoder:**
    1. klucze → kolejność komórek (jedna długa trasa),
    2. zachłanny podział na loty według pojemności baterii (powrót do bazy, wymiana),
    3. wyliczenie wysokości w punktach i na przelotach (tryb AGL),
    4. obliczenie kosztu i kar.
- **Mutacja:** perturbacja gaussowska pojedynczego klucza albo wylosowanie go od nowa.
- **Selekcja:** turniejowa (ruletka i ranking zostają na zad. 2).
- **Warunek stopu:** maks. liczba generacji LUB brak poprawy przez K generacji.

### Zakres modelu w zad. 1
- Teren z NMT, tryb AGL, stały punkt startu.
- Bateria i podział na loty, kary za zakręty i wznoszenie.
- Pokrycie uproszczone: odwiedzona komórka = pokryta.

### Badania
- Siatka parametrów: `p_c` × `p_m` (np. `p_c ∈ {0.6, 0.8, 0.95}`, `p_m ∈ {0.005, 0.01, 0.05}`).
- Każda konfiguracja: ≥ 10 przebiegów z różnymi ziarnami.
- Raportowane: najlepszy / średni / odchylenie standardowe kosztu, wykresy zbieżności, porównanie z baseline'em.
- Instancje: jedna rzeczywista + kilka syntetycznych (płaska, pagórkowata).
- Wykresy i tabele w Go (`gonum/plot`, `gonum/stat`).

---

## 5. Zadanie 2: rozszerzony GA (Rust, 10.11.2026)

### Wymagania prowadzącego
- Elitarność (selekcja elitarna).
- Dwie inne metody selekcji (+ warianty z elitarnością).
- Dwa inne krzyżowania.
- Jeden inny operator mutacji (np. inwersja).
- Badanie jakości kombinacji, wybór najlepszej kombinacji metod i parametrów, wyniki w czytelnej formie.

### Projekt
- Port GA z Go do Rusta. Operatory jako traity, kombinacje składane z konfiguracji.
- **Selekcje:** turniej (z zad. 1), **ruletka**, **ranking**, każda z elitarnością i bez.
    - Problem jest minimalizacyjny, więc dla ruletki potrzebna transformacja kosztu (np. `f = 1 / (1 + cost)` albo `f = cost_max − cost`).
- **Krzyżowania:** jednopunktowe (z zad. 1), **dwupunktowe**, **jednorodne** (na kluczach).
- **Mutacje:** gaussowska (z zad. 1), **inwersja na zdekodowanej trasie**: odwrócenie fragmentu trasy (ruch 2-opt), potem ponowne zakodowanie kluczy.
- Równoległe przebiegi: `rayon`.

### Rozszerzenia modelu (jeśli starczy czasu)
- Rzeczywista ocena pokrycia (ray casting na NMT, precompute śladów).
- Tryb AMSL + wstępna walidacja wykonalności.
- Wybór miejsca startu jako dodatkowy gen (indeks kandydata).
- Gen „zdjęcie / pomiń” per komórka, czyli kompromis pokrycie vs czas lotu.

### Badania
- Pełna lub częściowa siatka kombinacji: selekcja × krzyżowanie × mutacja × elitarność.
- ≥ 10 przebiegów na kombinację.
- Tabele zbiorcze + boxploty + wykresy zbieżności, wybór najlepszej kombinacji.
- Wykresy w Ruście (`plotters`), statystyki (`statrs`).
- Weryfikacja: czy wynik Rusta z konfiguracją z zad. 1 odpowiada wynikom z Go.

---

## 6. Zadanie 3: algorytm mrówkowy (Julia, 01.12.2026)

### Wymagania prowadzącego
- Ten sam problem rozwiązany inną metodą IO.
- Dobór parametrów.
- Porównanie z GA: która metoda lepsza i dlaczego.

### Projekt
- **ACO**: mrówki budują trasę krok po kroku, komórka po komórce.
    - Feromon `τ_ij` na przejściach między komórkami.
    - Heurystyka `η_ij = 1 / cost_ij`, gdzie koszt uwzględnia odległość, zakręt i wznoszenie.
    - Podział na loty i funkcja celu: **ten sam dekoder i ta sama funkcja kosztu co w GA**.
- Parametry do strojenia: `α`, `β`, `ρ` (parowanie), liczba mrówek, strategia aktualizacji (np. tylko najlepsza mrówka / elitarna).
- Wyniki GA wczytywane z `results/` (CSV z Rusta), porównanie i wykresy w Julii (`CSV.jl`, `DataFrames.jl`, `Plots.jl`/`Makie.jl`).

### Badania
- Strojenie parametrów ACO (≥ 10 przebiegów na konfigurację).
- Porównanie z najlepszą konfiguracją GA z zad. 2 na tych samych instancjach.
- **Porównanie po liczbie wywołań funkcji celu, nie po czasie.** Czas mierzyłby różnice języków, nie algorytmów.
- Oś porównania: instancje płaskie vs pagórkowate, tryb AGL vs AMSL.

### Hipotezy do wyjaśnienia
- ACO buduje trasę konstrukcyjnie i korzysta z lokalnej heurystyki (sąsiedztwo, zakręty), więc może szybciej znajdować dobre trasy.
- GA operuje na pełnych rozwiązaniach, przez co może lepiej radzić sobie z globalnym kompromisem (podział na loty, pokrycie).
- Na płaskim terenie baseline „kosiarką” powinien być trudny do pobicia, a zysk metod IO powinien rosnąć wraz z nieregularnością obszaru i terenu.

---

## 7. Literatura

- E. Galceran, M. Carreras, *A survey on coverage path planning for robotics*, Robotics and Autonomous Systems, 2013.
- T. M. Cabreira, L. B. Brisolara, P. R. Ferreira Jr., *Survey on Coverage Path Planning with Unmanned Aerial Vehicles*, Drones, 2019.

(Dane bibliograficzne do zweryfikowania przed sprawozdaniem.)