#!/usr/bin/env python3
"""Build deterministic, ready-to-install native plugin archive; no runtime build step."""
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'manifest.json').read_text());version=m['version'];dist=root/'dist';dist.mkdir(exist_ok=True)
frontend=root/Path(m['entryPoints']['barWidget']).parent
files=[root/n for n in ['manifest.json','LICENSE','README.md','THIRD_PARTY_NOTICES.md']]+list(frontend.rglob('*'))
buffer=io.BytesIO()
with tarfile.open(fileobj=buffer,mode='w',format=tarfile.PAX_FORMAT) as tar:
 for path in sorted(files):
  assert not path.is_symlink(),path
  if not path.is_file():continue
  data=path.read_bytes();info=tarfile.TarInfo(str(Path(m['id'])/path.relative_to(root)));info.size=len(data);info.mode=0o755 if path.suffix=='.sh' else 0o644;info.mtime=0;info.uid=info.gid=0;info.uname=info.gname='';tar.addfile(info,io.BytesIO(data))
name=f'omamonero-plugin-{version}.tar.gz';output=dist/name
with output.open('wb') as raw:
 with gzip.GzipFile(filename='',mode='wb',fileobj=raw,mtime=0) as compressed:compressed.write(buffer.getvalue())
checksum=hashlib.sha256(output.read_bytes()).hexdigest();(dist/'SHA256SUMS').write_text(f'{checksum}  {name}\n')
print(f'Created {name}; ready-to-use QML and generated JS, no backend')
