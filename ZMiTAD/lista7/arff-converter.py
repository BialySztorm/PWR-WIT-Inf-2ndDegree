import os
import sys
import pandas as pd
import arff


def xls_to_arff(xls_file, output_file):
    """
    Konwertuje plik XLS na format ARFF używając liac-arff

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

    # Przygotuj dane dla arff
    data = []
    attributes = []

    # Dodaj ID
    attributes.append(('ID', 'NUMERIC'))

    # Analizuj kolumny
    for col in df.columns:
        col_name = str(col).replace(" ", "_").replace("'", "")

        # Sprawdź typ danych kolumny
        col_data = df[col].dropna()

        if len(col_data) == 0:
            # Kolumna pusta
            attributes.append((col_name, 'STRING'))
        elif df[col].dtype in ['int64', 'int32', 'float64', 'float32']:
            # Typ numeryczny
            attributes.append((col_name, 'NUMERIC'))
        else:
            # Typ tekstowy - sprawdź czy nominalne czy string
            unique_vals = col_data.unique()
            if len(unique_vals) <= 20:
                # Mało unikalnych wartości = nominalne
                nominal_vals = sorted([str(v).strip() for v in unique_vals])
                attributes.append((col_name, nominal_vals))
            else:
                # Dużo unikalnych wartości = string
                attributes.append((col_name, 'STRING'))

    # Przygotuj wiersze danych
    for idx, row in df.iterrows():
        values = [idx + 1]  # ID
        for i, val in enumerate(row):
            if pd.isna(val):
                values.append(None)
            else:
                # Jeśli atrybut jest numeryczny, zwróć liczbę
                if attributes[i + 1][1] == 'NUMERIC':
                    try:
                        values.append(float(val))
                    except:
                        values.append(None)
                else:
                    values.append(str(val).strip())
        data.append(values)

    # Stwórz obiekt ARFF i zapisz
    arff_dict = {
        'description': f'Relation generated from {os.path.basename(xls_file)}',
        'relation': os.path.splitext(os.path.basename(xls_file))[0],
        'attributes': attributes,
        'data': data
    }

    with open(output_file, 'w', encoding='utf-8') as f:
        arff.dump(arff_dict, f)

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