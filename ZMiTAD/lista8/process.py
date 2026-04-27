import arff

# === Wczytanie danych ===
with open("XXXXXXL2 2.arff", "r", encoding="utf-8") as f:
    data = arff.load(f)

attributes = data["attributes"]
records = data["data"]

# indeksy kolumn (zakładamy kolejność jak u Ciebie)
status_idx = 1   # status_pozyczki
kwota_idx = 2    # kwota_kredytu

# === Filtrowanie rekordów ===
filtered = []

for row in records:
    status = row[status_idx]
    kwota = float(row[kwota_idx])

    # usuń: status = odmowa
    if status == "odmowa":
        continue

    # usuń: kwota > 900
    if kwota > 900:
        continue

    filtered.append(row)

# === Usunięcie kolumny status ===
status_idx = next(i for i, attr in enumerate(attributes) if attr[0] == "status_pozyczki")
new_attributes = [attr for i, attr in enumerate(attributes) if i != status_idx]
new_data = []
for row in filtered:
    new_row = [val for i, val in enumerate(row) if i != status_idx]
    new_data.append(new_row)

# === Zapis ===
output = {
    "relation": data["relation"],
    "attributes": new_attributes,
    "data": new_data
}

with open("XXXXXXL3 2.arff", "w", encoding="utf-8") as f:
    arff.dump(output, f)