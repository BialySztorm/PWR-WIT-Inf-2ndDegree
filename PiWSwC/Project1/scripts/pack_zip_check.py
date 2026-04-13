import zipfile, os
from pathlib import Path
proj = Path(__file__).resolve().parents[1]
src = proj / 'frontend' / 'dist'
zipf = proj / 'deploy' / 'frontend-src.zip'
out = proj / 'deploy' / 'pack_check.txt'
if not zipf.exists():
    with open(out, 'w', encoding='utf-8') as f:
        f.write(f'MISSING_ZIP: {zipf}\n')
    print('WROTE', out)
    raise SystemExit(1)

z = zipfile.ZipFile(zipf)
# build map of zip entries sizes
zip_map = {e.filename: e.file_size for e in z.infolist()}
# walk src
lines = []
count_ok = 0
count_diff = 0
count_missing_zip = 0
count_missing_fs = 0
for p in src.rglob('*'):
    if p.is_file():
        rel = p.relative_to(src).as_posix()
        fs_size = p.stat().st_size
        if rel in zip_map:
            zip_size = zip_map[rel]
            if zip_size == fs_size:
                lines.append(f'OK\t{rel}\tzip={zip_size}\tfs={fs_size}')
                count_ok += 1
            else:
                lines.append(f'DIFF\t{rel}\tzip={zip_size}\tfs={fs_size}')
                count_diff += 1
        else:
            lines.append(f'MISSING_IN_ZIP\t{rel}\tfs={fs_size}')
            count_missing_zip += 1
# check for entries in zip not in fs
for entry,size in zip_map.items():
    fs_path = src / Path(entry)
    if not fs_path.exists():
        lines.append(f'EXTRA_IN_ZIP\t{entry}\tzip={size}')
        count_missing_fs += 1

with open(out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
    f.write('\n\nSUMMARY:\n')
    f.write(f'OK={count_ok} DIFF={count_diff} MISSING_IN_ZIP={count_missing_zip} EXTRA_IN_ZIP={count_missing_fs}\n')
print('WROTE', out)

