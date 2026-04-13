import zipfile
import sys

if len(sys.argv) < 2:
    print('Usage: python inspect_zip.py <zipfile>')
    sys.exit(1)

zf = sys.argv[1]
with zipfile.ZipFile(zf) as z:
    for name in z.namelist():
        print(name)
print('Done')

