import zipfile
from pathlib import Path
import sys
proj = Path(__file__).resolve().parents[1]
src = proj / 'frontend' / 'dist'
out = proj / 'deploy' / 'frontend-src.zip'
out.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED) as zf:
    for p in src.rglob('*'):
        if p.is_file():
            arc = p.relative_to(src).as_posix()
            with p.open('rb') as fh:
                data = fh.read()
            zf.writestr(arc, data)
print('created', out)
with zipfile.ZipFile(out) as zf:
    with open(out.parent / 'frontend_contents_after.txt','w',encoding='utf-8') as f:
        for e in zf.infolist():
            f.write(f"{e.filename}\t{e.file_size}\n")
print('wrote listing')

