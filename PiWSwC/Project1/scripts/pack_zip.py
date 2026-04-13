"""
Pack directories/files into a zip with POSIX (forward-slash) separators for archive entries.
Usage:
  python scripts/pack_zip.py <src_dir_or_file1> [<src2> ...] -o deploy/backend-src.zip
Examples:
  python scripts/pack_zip.py backend/manage.py backend/api backend/Dockerfile -o deploy/backend-src.zip
  python scripts/pack_zip.py frontend/dist frontend/Dockerfile -o deploy/frontend-src.zip

This script ensures arcname uses '/' so Linux unzip won't complain about backslashes and writes file data in binary mode to avoid truncation on Windows.
"""
import sys
import zipfile
import os
from pathlib import Path

def usage():
    print("Usage: python scripts/pack_zip.py <src...> -o <output.zip>")

if __name__ == '__main__':
    if '-o' not in sys.argv:
        usage()
        sys.exit(1)
    oidx = sys.argv.index('-o')
    srcs = sys.argv[1:oidx]
    out = sys.argv[oidx+1]
    if not srcs:
        usage(); sys.exit(1)
    outp = Path(out)
    outp.parent.mkdir(parents=True, exist_ok=True)

    # Use ZIP_DEFLATED where available
    compression = zipfile.ZIP_DEFLATED if hasattr(zipfile, 'ZIP_DEFLATED') else zipfile.ZIP_STORED

    with zipfile.ZipFile(str(outp), 'w', compression=compression) as zf:
        # If exactly one source and it's a directory, we will archive its contents at root
        single_dir_no_prefix = (len(srcs) == 1 and Path(srcs[0]).is_dir())
        for s in srcs:
            p = Path(s)
            if not p.exists():
                print(f"Warning: {s} does not exist, skipping")
                continue
            if p.is_file():
                # For a file, store it at top-level using its basename
                arcname = p.name.replace('\\', '/')
                with p.open('rb') as fh:
                    data = fh.read()
                zf.writestr(arcname, data)
            else:
                # For a directory, walk and store files relative to the directory root
                prefix = '' if single_dir_no_prefix else p.name
                for root, dirs, files in os.walk(p):
                    root_path = Path(root)
                    for f in files:
                        fp = root_path / f
                        # arcname relative to the source directory p, using POSIX separators
                        rel = fp.relative_to(p)
                        arc = (prefix + '/' + rel.as_posix()).lstrip('/')
                        with fp.open('rb') as fh:
                            data = fh.read()
                        zf.writestr(arc, data)
    print(f"Created {out}")
