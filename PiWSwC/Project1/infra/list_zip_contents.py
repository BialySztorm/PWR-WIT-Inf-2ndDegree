import zipfile
import sys
paths = [r"..\deploy\frontend-src.zip", r"..\deploy\backend-src.zip"]
for p in paths:
    print('\n== Listing', p)
    try:
        with zipfile.ZipFile(p, 'r') as z:
            for name in z.namelist():
                print(name)
    except Exception as e:
        print('ERROR reading', p, e)
        sys.exit(1)

