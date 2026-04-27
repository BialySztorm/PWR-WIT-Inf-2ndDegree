import arff
import numpy as np
import pandas as pd
from collections import Counter

# =========================
# 1. Wczytanie ARFF
# =========================
with open("XXXXXXL3 1.arff", "r", encoding="utf-8") as f:
    data = arff.load(f)

relation = data["relation"]
attributes = [attr[0] for attr in data["attributes"]]
# Oryginalne definicje atrybutow z naglowka ARFF (np. lista nominalna albo "numeric").
attribute_defs = {name: definition for name, definition in data["attributes"]}
rows = np.array(data["data"], dtype=object)

df = pd.DataFrame(rows, columns=attributes)

# =========================
# 2. Ustawienie klasy
# =========================
class_col = "status_pozyczki"

# =========================
# 3. Entropia
# =========================
def entropy(y):
    counts = Counter(y)
    total = len(y)
    ent = 0
    for c in counts.values():
        p = c / total
        ent -= p * np.log2(p)
    return ent

# =========================
# 4. Information Gain
# =========================
def info_gain(df, attr, target):
    base_entropy = entropy(df[target])

    values = df[attr].unique()
    weighted_entropy = 0

    for v in values:
        subset = df[df[attr] == v][target]
        weighted_entropy += (len(subset) / len(df)) * entropy(subset)

    return base_entropy - weighted_entropy

# =========================
# 5. SplitInfo
# =========================
def split_info(df, attr):
    counts = df[attr].value_counts()
    total = len(df)

    si = 0
    for c in counts:
        p = c / total
        si -= p * np.log2(p)

    return si

# =========================
# 6. Gain Ratio
# =========================
def gain_ratio(df, attr, target):
    ig = info_gain(df, attr, target)
    si = split_info(df, attr)

    if si == 0:
        return 0

    return ig / si

# =========================
# 7. Obliczenia dla wszystkich cech
# =========================
results = []

for attr in df.columns:
    if attr == class_col:
        continue

    if attr == "ID":
        continue  # usuwamy ID

    gr = gain_ratio(df, attr, class_col)
    ig = info_gain(df, attr, class_col)

    if gr > 0.001 and ig > 0.001:
        results.append((attr, gr, ig))

# =========================
# 8. Sortowanie po Gain Ratio (rosnąco)
# =========================
results_sorted = sorted(results, key=lambda x: x[1])

selected_attrs = [r[0] for r in results_sorted]
selected_attrs.append(class_col)

# =========================
# 9. Nowy dataframe
# =========================
df_new = df[selected_attrs]

# =========================
# 10. Zapis ARFF
# =========================
def save_arff(df, filename, attr_defs, relation="filtered"):
    with open(filename, "w", encoding="utf-8") as f:
        f.write("@relation " + relation + "\n\n")

        for col in df.columns:
            definition = attr_defs.get(col)

            if isinstance(definition, list):
                vals_str = "{" + ",".join(str(v) for v in definition) + "}"
                f.write(f"@attribute {col} {vals_str}\n")
            elif isinstance(definition, str):
                f.write(f"@attribute {col} {definition}\n")
            else:
                # Fallback, gdyby brakowalo metadanych dla kolumny.
                if pd.api.types.is_numeric_dtype(df[col]):
                    f.write(f"@attribute {col} numeric\n")
                else:
                    vals = sorted(str(v) for v in df[col].dropna().unique())
                    f.write(f"@attribute {col} {{{','.join(vals)}}}\n")

        f.write("\n@data\n")

        for _, row in df.iterrows():
            f.write(",".join(str(v) for v in row.values) + "\n")

selected_attr_defs = {col: attribute_defs[col] for col in selected_attrs if col in attribute_defs}
save_arff(df_new, "XXXXXXL4 2.arff", selected_attr_defs, relation="filtered")