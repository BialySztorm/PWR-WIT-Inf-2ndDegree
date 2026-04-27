import os
import sys
from openpyxl import load_workbook
from xlrd import open_workbook
import pandas as pd


def xls_to_arff(xls_file, output_file):
    """
    Konwertuje plik XLS na format ARFF

    Args:
        xls_file: ścieżka do pliku XLS
        output_file: ścieżka do wyjściowego pliku ARFF
    """
    try:
        # Spróbuj wczytać plik jako XLS (stary format)
        df = pd.read_excel(xls_file, engine='xlrd')
    except:
        try:
            # W razie błędu, spróbuj jako XLSX
            df = pd.read_excel(xls_file, engine='openpyxl')
        except Exception as e:
            print(f"Błąd przy wczytywaniu pliku {xls_file}: {e}")
            return False

    # Usuń puste wiersze
    df = df.dropna(how='all')

    if df.empty:
        print(f"Plik {xls_file} jest pusty")
        return False

    # Napisz plik ARFF
    with open(output_file, 'w', encoding='utf-8') as f:
        # Nagłówek
        f.write("% Relation generated from " + os.path.basename(xls_file) + "\n")
        f.write("@relation " + os.path.splitext(os.path.basename(xls_file))[0] + "\n\n")

        # Atrybuty
        f.write("@attribute ID numeric\n")
        for col in df.columns:
            col_name = str(col).replace(" ", "_").replace("'", "")
            # Autodetekt typu danych
            if df[col].dtype == 'object':
                unique_vals = df[col].dropna().unique()
                if len(unique_vals) <= 20:  # Jeśli mało unikalnych wartości = nominalne
                    vals = ','.join([f"'{str(v).strip()}'" for v in unique_vals if pd.notna(v)])
                    f.write(f"@attribute {col_name} {{{vals}}}\n")
                else:
                    f.write(f"@attribute {col_name} string\n")
            else:
                f.write(f"@attribute {col_name} numeric\n")

        f.write("\n@data\n")

        # Dane
        for idx, row in df.iterrows():
            values = [str(idx + 1)]  # ID
            for val in row:
                if pd.isna(val):
                    values.append("?")
                else:
                    values.append(f"'{str(val).strip()}'")
            f.write(",".join(values) + "\n")

    return True


def batch_convert(source_dir, output_dir):
    """
    Konwertuje wszystkie pliki XLS w katalogu
    """
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    for filename in os.listdir(source_dir):
        if filename.lower().endswith('.xls') or filename.lower().endswith('.xlsx'):
            xls_path = os.path.join(source_dir, filename)
            arff_name = os.path.splitext(filename)[0] + '.arff'
            arff_path = os.path.join(output_dir, arff_name)

            print(f"Konwertowanie: {filename}...", end=" ")
            if xls_to_arff(xls_path, arff_path):
                print("OK")
            else:
                print("BŁĄD")


if __name__ == "__main__":
    # Konfiguracja
    source_file = r"XXXXXXL1 2.xls"
    output_file = r"XXXXXXL2 2.arff"

    # Konwersja pojedynczego pliku
    if len(sys.argv) > 1:
        xls_to_arff(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else sys.argv[1].replace('.xls', '.arff'))
    else:
        # Konwersja pojedynczego pliku
        print(f"Konwertowanie: {source_file}...", end=" ")
        if xls_to_arff(source_file, output_file):
            print("OK")
        else:
            print("BŁĄD")
        print(f"Plik ARFF zapisany jako: {output_file}")