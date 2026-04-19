# remove_bom.py
import sys

path = sys.argv[1]
with open(path, 'rb') as f:
    content = f.read()
# UTF-8 BOM to b'\xef\xbb\xbf'
if content.startswith(b'\xef\xbb\xbf'):
    content = content[3:]
    with open(path, 'wb') as f:
        f.write(content)
