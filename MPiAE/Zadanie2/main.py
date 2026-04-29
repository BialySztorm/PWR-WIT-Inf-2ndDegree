# %%
import pandas as pd
import numpy as np
from scipy import stats
import matplotlib.pyplot as plt
import seaborn as sns
from statsmodels.stats.multicomp import pairwise_tukeyhsd
import os

# %% [markdown]
# # 1. WCZYTANIE DANYCH
# %%
df = pd.read_csv('2015.csv', encoding='utf-8')

print("=" * 80)
print("ANALIZA STATYSTYCZNA - WORLD HAPPINESS REPORT 2015")
print("=" * 80)
print(f"\nRozmiar próby: {len(df)} krajów")
print(f"Liczba regionów: {df['Region'].nunique()}")
print(f"Regiony: {sorted(df['Region'].unique())}\n")

# %% [markdown]
# # 2. STATYSTYKA OPISOWA (ESTYMACJA PUNKTOWA)
# %%
variables = ['Happiness Score', 'Economy (GDP per Capita)', 'Family',
             'Health (Life Expectancy)', 'Freedom', 'Trust (Government Corruption)']

descriptive_stats = df[variables].describe().T
print("\nWskaźniki opisowe:")
print(descriptive_stats[['mean', 'std', 'min', '50%', 'max']].round(4))

# Estymacja punktowa - szczegółowo
print("\n--- SZCZEGÓŁOWE ESTYMATORY PUNKTOWE ---")
for var in variables:
    mean = df[var].mean()
    median = df[var].median()
    std = df[var].std(ddof=1)  # n-1 dla próby
    print(f"\n{var}:")
    print(f"  Średnia (μ):        {mean:.4f}")
    print(f"  Mediana:            {median:.4f}")
    print(f"  Odch. stand. (s):   {std:.4f}")

# %% [markdown]
# # 3. PRZEDZIAŁY UFNOŚCI (95%)
# %%
confidence_level = 0.95
alpha = 1 - confidence_level
n = len(df)
t_critical = stats.t.ppf(1 - alpha/2, df=n-1)

print("\nPrzedziały ufności dla średnich (poziom ufności 95%):")
print("Wzór: x̄ ± t(α/2, n-1) * (s / √n)\n")

for var in variables:
    mean = df[var].mean()
    std = df[var].std(ddof=1)
    error = t_critical * (std / np.sqrt(n))
    ci_lower = mean - error
    ci_upper = mean + error

    print(f"{var}:")
    print(f"  Średnia:  {mean:.4f}")
    print(f"  [PU 95%]: [{ci_lower:.4f}; {ci_upper:.4f}]")
    print(f"  Błąd:     ±{error:.4f}\n")

# %% [markdown]
# # 4. ANALIZA WARIANCJI - ANOVA
# %%
print("\n--- TEST ANOVA: Szczęście między regionami ---")
print("Hipoteza H0: μ₁ = μ₂ = ... = μₖ (brak różnic między regionami)")
print("Hipoteza H1: Przynajmniej dwa regiony różnią się średnią\n")

# Statystyka opisowa dla każdego regionu
print("Statystyka opisowa dla Happiness Score po regionach:\n")
region_stats = df.groupby('Region')['Happiness Score'].agg([
    ('n', 'count'),
    ('Średnia', 'mean'),
    ('Std. Dev', 'std'),
    ('Min', 'min'),
    ('Max', 'max')
]).round(4)
print(region_stats)

# ANOVA
groups = [group['Happiness Score'].values for name, group in df.groupby('Region')]
f_stat, p_value_anova = stats.f_oneway(*groups)

print(f"\n--- WYNIKI ANOVA ---")
print(f"Liczba grup (regionów): {len(groups)}")
print(f"Statystyka F:           {f_stat:.3f}")
print(f"p-value:                {p_value_anova:.3e}")
print(f"Poziom istotności:      α = 0.05")

if p_value_anova < 0.05:
    print(f"\n✓ WNIOSEK: Odrzucamy H0.")
    print(f"  Szczęście RÓŻNI się statystycznie między regionami (p < 0.05)")
else:
    print(f"\n✗ WNIOSEK: Nie ma podstaw do odrzucenia H0.")
    print(f"  Brak istotnych różnic między regionami (p >= 0.05)")

# %% [markdown]
# # 5. TEST POST-HOC: TUKEY HSD
# %%
print("\nPorównania parami między regionami (jeśli ANOVA istotna):\n")

if p_value_anova < 0.05:
    tukey_result = pairwise_tukeyhsd(endog=df['Happiness Score'],
                                     groups=df['Region'],
                                     alpha=0.05)
    print(tukey_result)
    print("\nInterpretacja: reject=True → znacząca różnica między grupami")
else:
    print("ANOVA nie istotna, test Tukey'a nie stosowany.")

# %% [markdown]
# # 6. ANOVA DLA INNYCH ZMIENNYCH
# %%
for var in ['Economy (GDP per Capita)', 'Health (Life Expectancy)', 'Freedom']:
    print(f"\n--- ANOVA dla: {var} ---")
    groups_var = [group[var].values for name, group in df.groupby('Region')]
    f_stat_var, p_value_var = stats.f_oneway(*groups_var)

    print(f"Statystyka F: {f_stat_var:.4f}")
    print(f"p-value:      {p_value_var:.6f}")

    if p_value_var < 0.05:
        print(f"✓ Istotne różnice między regionami (p < 0.05)")
    else:
        print(f"✗ Brak istotnych różnic (p >= 0.05)")

# %% [markdown]
# # 7. KORELACJE
# %%
print("\n--- Korelacja: GDP - Szczęście ---")
corr_gdp, p_corr_gdp = stats.pearsonr(df['Economy (GDP per Capita)'],
                                       df['Happiness Score'])
print(f"r = {corr_gdp:.4f}, p-value = {p_corr_gdp:.6f}")
if p_corr_gdp < 0.05:
    print("✓ Istotna pozytywna korelacja (p < 0.05)")
else:
    print("✗ Brak istotnej korelacji")

print("\n--- Korelacja: Zdrowie - Szczęście ---")
corr_health, p_corr_health = stats.pearsonr(df['Health (Life Expectancy)'],
                                             df['Happiness Score'])
print(f"r = {corr_health:.4f}, p-value = {p_corr_health:.6f}")
if p_corr_health < 0.05:
    print("✓ Istotna pozytywna korelacja (p < 0.05)")
else:
    print("✗ Brak istotnej korelacji")

print("\n--- Korelacja: Freedom - Szczęście ---")
corr_freedom, p_corr_freedom = stats.pearsonr(df['Freedom'],
                                              df['Happiness Score'])
print(f"r = {corr_freedom:.4f}, p-value = {p_corr_freedom:.6f}")
if p_corr_freedom < 0.05:
    print("✓ Istotna pozytywna korelacja (p < 0.05)")
else:
    print("✗ Brak istotnej korelacji")

# %% [markdown]
# # 8. TEST NORMALNOŚCI
# %%
stat_shapiro, p_shapiro = stats.shapiro(df['Happiness Score'])
print(f"\nZmienna: Happiness Score")
print(f"Statystyka: {stat_shapiro:.4f}")
print(f"p-value:    {p_shapiro:.6f}")

if p_shapiro < 0.05:
    print(f"✗ Rozkład NIE jest normalny (p < 0.05)")
else:
    print(f"✓ Możemy założyć rozkład normalny (p >= 0.05)")

# %% [markdown]
# # 9. WIZUALIZACJA
# %%
print("\n" + "=" * 80)
print("GENEROWANIE I ZAPIS WYKRESÓW (OSOBNE PLIKI)...")
print("=" * 80)

# Folder na wykresy
plots_dir = "plots"
os.makedirs(plots_dir, exist_ok=True)

# -----------------------------
# 1) Histogram szczęścia
# -----------------------------
plt.figure(figsize=(8, 5))
plt.hist(df['Happiness Score'], bins=20, color='skyblue', edgecolor='black', alpha=0.8)
plt.axvline(df['Happiness Score'].mean(), color='red', linestyle='--', linewidth=2,
            label=f"Średnia: {df['Happiness Score'].mean():.2f}")
plt.title('Rozkład wskaźnika szczęścia')
plt.xlabel('Happiness Score')
plt.ylabel('Liczba krajów')
plt.grid(alpha=0.3)
plt.legend()
plt.tight_layout()
plt.savefig(os.path.join(plots_dir, '01_hist_happiness.png'), dpi=300, bbox_inches='tight')
plt.close()

# -----------------------------
# 2) Boxplot szczęścia po regionach
# -----------------------------
region_order = df.groupby('Region')['Happiness Score'].median().sort_values(ascending=False).index

plt.figure(figsize=(12, 6))
sns.boxplot(
    data=df,
    x='Region',
    y='Happiness Score',
    order=region_order,
    hue='Region',
    palette='Set2',
    legend=False
)
plt.title('Szczęście po regionach (ANOVA)')
plt.xlabel('')
plt.ylabel('Happiness Score')
plt.xticks(rotation=45, ha='right')
plt.grid(alpha=0.3, axis='y')
plt.tight_layout()
plt.savefig(os.path.join(plots_dir, '02_boxplot_happiness_by_region.png'), dpi=300, bbox_inches='tight')
plt.close()

# -----------------------------
# 3) Średnie szczęścia po regionach + 95% CI
# -----------------------------
region_means = df.groupby('Region')['Happiness Score'].mean().sort_values(ascending=False)
region_std = df.groupby('Region')['Happiness Score'].std()
region_n = df.groupby('Region').size()
region_ci = 1.96 * region_std / np.sqrt(region_n)

plt.figure(figsize=(10, 6))
plt.barh(range(len(region_means)), region_means.values, xerr=region_ci.values,
         color='coral', edgecolor='black', alpha=0.8, capsize=5)
plt.yticks(range(len(region_means)), region_means.index, fontsize=9)
plt.gca().invert_yaxis()
plt.xlabel('Happiness Score')
plt.title('Średnie szczęścia po regionach (95% CI)')
plt.grid(alpha=0.3, axis='x')
plt.tight_layout()
plt.savefig(os.path.join(plots_dir, '03_mean_happiness_by_region_ci95.png'), dpi=300, bbox_inches='tight')
plt.close()

# -----------------------------
# Funkcja: scatter X vs Happiness
# -----------------------------
def save_scatter_vs_happiness(x_col, file_name, color='steelblue'):
    valid = df[[x_col, 'Happiness Score']].dropna()
    r, p = stats.pearsonr(valid[x_col], valid['Happiness Score'])

    plt.figure(figsize=(7.5, 5.5))
    plt.scatter(valid[x_col], valid['Happiness Score'], alpha=0.65, s=45, color=color)

    # Linia trendu
    z = np.polyfit(valid[x_col], valid['Happiness Score'], 1)
    p_line = np.poly1d(z)
    x_sorted = np.sort(valid[x_col].values)
    plt.plot(x_sorted, p_line(x_sorted), 'r--', linewidth=2, alpha=0.85)

    plt.title(f"{x_col} vs Happiness Score\n(r={r:.3f}, p={p:.4g})")
    plt.xlabel(x_col)
    plt.ylabel('Happiness Score')
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.savefig(os.path.join(plots_dir, file_name), dpi=300, bbox_inches='tight')
    plt.close()

# -----------------------------
# 4..N) Wszystkie wybrane "vs Happiness"
# -----------------------------
save_scatter_vs_happiness('Economy (GDP per Capita)', '04_gdp_vs_happiness.png', color='tab:blue')
save_scatter_vs_happiness('Health (Life Expectancy)', '05_health_vs_happiness.png', color='tab:green')
save_scatter_vs_happiness('Freedom', '06_freedom_vs_happiness.png', color='tab:orange')
save_scatter_vs_happiness('Family', '07_family_vs_happiness.png', color='tab:purple')
save_scatter_vs_happiness('Trust (Government Corruption)', '08_trust_vs_happiness.png', color='tab:brown')

# Opcjonalnie (jeśli też chcesz pokazać wszystkie kolumny z pliku 2015)
save_scatter_vs_happiness('Generosity', '09_generosity_vs_happiness.png', color='tab:pink')
save_scatter_vs_happiness('Dystopia Residual', '10_dystopia_vs_happiness.png', color='tab:gray')

# -----------------------------
# 11) Q-Q plot normalności
# -----------------------------
plt.figure(figsize=(7, 5))
stats.probplot(df['Happiness Score'], dist="norm", plot=plt)
plt.title('Q-Q plot dla Happiness Score')
plt.grid(alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(plots_dir, '11_qqplot_happiness.png'), dpi=300, bbox_inches='tight')
plt.close()

print(f"✓ Zapisano wykresy do folderu: {plots_dir}")
print("✓ Lista plików:")
for f in sorted(os.listdir(plots_dir)):
    print("  -", f)
# %% [markdown]
# # 10. PODSUMOWANIE I WNIOSKI
# %%
print("\n1. OGÓLNE STATYSTYKI")
print("-" * 80)
print(f"Liczba krajów w analizie: {len(df)}")
print(f"Liczba regionów: {df['Region'].nunique()}")
print(f"\nŚrednie wskaźniki na świecie:")
print(f"  • Szczęście: {df['Happiness Score'].mean():.2f}/10")
print(f"  • GDP per capita: {df['Economy (GDP per Capita)'].mean():.2f}")
print(f"  • Długość życia: {df['Health (Life Expectancy)'].mean():.2f} lat")
print(f"  • Wolność: {df['Freedom'].mean():.2f}")

print("\n2. PRZEDZIAŁY UFNOŚCI (95%)")
print("-" * 80)
mean_happiness = df['Happiness Score'].mean()
error_happiness = t_critical * (df['Happiness Score'].std(ddof=1) / np.sqrt(n))
print(f"Szczęście na świecie:")
print(f"  Średnia: {mean_happiness:.2f}")
print(f"  Możemy być 95% pewni, że średnia szczęścia w populacji")
print(f"  wynosi między {mean_happiness - error_happiness:.2f} a {mean_happiness + error_happiness:.2f}")

print("\n3. RÓŻNICE MIĘDZY REGIONAMI (ANOVA)")
print("-" * 80)
print(f"Test: Czy szczęście różni się między regionami?")
print(f"Statystyka F: {f_stat:.2f}")
print(f"Wynik testu: p-value = {p_value_anova:.6f}")

if p_value_anova < 0.05:
    print(f"\n✓ TAK - Szczęście ISTOTNIE różni się między regionami!")
    print(f"  To znaczy, że ta różnica nie jest przypadkowa (p < 0.05)")
    print(f"\nRanking szczęścia po regionach:")
    region_ranking = df.groupby('Region')['Happiness Score'].mean().sort_values(ascending=False)
    for i, (region, score) in enumerate(region_ranking.items(), 1):
        print(f"  {i}. {region}: {score:.2f}")
else:
    print(f"\n✗ NIE - Brak istotnych różnic między regionami")

print("\n4. ZWIĄZEK MIĘDZY GDP A SZCZĘŚCIEM")
print("-" * 80)
print(f"Korelacja: r = {corr_gdp:.3f}")
print(f"Wynik testu: p-value = {p_corr_gdp:.6f}")

if p_corr_gdp < 0.05:
    print(f"\n✓ TAK - Bogatsze kraje SĄ bardziej szczęśliwe!")
    print(f"  Związek jest dodatni i statystycznie istotny.")
    print(f"  Im wyższy GDP, tym wyższe szczęście.")
else:
    print(f"\n✗ Brak istotnego związku między GDP a szczęściem")

print("\n5. ZWIĄZEK MIĘDZY ZDROWIEM A SZCZĘŚCIEM")
print("-" * 80)
print(f"Korelacja: r = {corr_health:.3f}")
print(f"Wynik testu: p-value = {p_corr_health:.6f}")

if p_corr_health < 0.05:
    print(f"\n✓ TAK - Dłuższa długość życia WIĄŻE się ze szczęściem!")
    print(f"  To ma sens - zdrowsi ludzie są szczęśliwsi.")
else:
    print(f"\n✗ Brak istotnego związku między zdrowiem a szczęściem")

print("\n6. ZWIĄZEK MIĘDZY WOLNOŚCIĄ A SZCZĘŚCIEM")
print("-" * 80)
print(f"Korelacja: r = {corr_freedom:.3f}")
print(f"Wynik testu: p-value = {p_corr_freedom:.6f}")

if p_corr_freedom < 0.05:
    print(f"\n✓ TAK - Wolność ma wpływ na szczęście!")
    print(f"  Ludzie z większą wolnością wyboru są szczęśliwsi.")
else:
    print(f"\n✗ Brak istotnego związku między wolnością a szczęściem")

print("\n7. ROZKŁAD SZCZĘŚCIA - CZY NORMALNY?")
print("-" * 80)
print(f"Test Shapiro-Wilk: p-value = {p_shapiro:.6f}")

if p_shapiro >= 0.05:
    print(f"✓ Szczęście rozkłada się normalnie")
    print(f"  To dobrze - nasze testy statystyczne są wiarygodne")
else:
    print(f"✗ Szczęście NIE rozkłada się całkowicie normalnie")
    print(f"  Ale nasza analiza ANOVA jest na tyle odporna, że wyniki są wiarygodne")
