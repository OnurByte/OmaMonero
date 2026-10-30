#!/usr/bin/env python3
"""Create deterministic local source and frontend archives; never installs anything."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile

root = Path(__file__).resolve().parents[1]
version = json.loads((root / 'manifest.json').read_text())['version']
dist = root / 'dist'
dist.mkdir(exist_ok=True)

def archive(name, prefix, files):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode='w', format=tarfile.PAX_FORMAT) as tar:
        for path in sorted(files):
            if path.is_symlink():
                raise SystemExit(f'Symlinks are not allowed: {path}')
            if not path.is_file():
                continue
            data = path.read_bytes()
            info = tarfile.TarInfo(str(Path(prefix) / path.relative_to(root)))
            info.size = len(data)
            info.mode = 0o644
            info.mtime = 0
            info.uid = info.gid = 0
            info.uname = info.gname = ''
            tar.addfile(info, io.BytesIO(data))
    output = dist / name
    with output.open('wb') as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as compressed:
            compressed.write(buffer.getvalue())
    return hashlib.sha256(output.read_bytes()).hexdigest()

excluded = {'target', 'dist', '.git', '.superpowers', '__pycache__'}
files = [p for p in root.rglob('*') if not excluded.intersection(p.relative_to(root).parts)]
source = f'omamonero-core-{version}.tar.gz'
source_hash = archive(source, f'omamonero-core-{version}', files)
frontend = f'omamonero-plugin-{version}.tar.gz'
plugin_files = [root / name for name in ('manifest.json', 'LICENSE', 'README.md')]
plugin_files += list((root / 'qml').rglob('*'))
frontend_hash = archive(frontend, 'io.github.onurbyte.omamonero', plugin_files)
recipe = (root / 'packaging/PKGBUILD').read_text()
recipe = re.sub(r"sha256sums=\('SKIP'\)", f"sha256sums=('{source_hash}')", recipe)
(dist / 'PKGBUILD').write_text(recipe)
(dist / 'SHA256SUMS').write_text(f'{source_hash}  {source}\n{frontend_hash}  {frontend}\n')
print(f'Created {source} and {frontend}; checksums and local PKGBUILD in {dist}')
