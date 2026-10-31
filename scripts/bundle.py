#!/usr/bin/env python3
"""Build the clickable end-user release from a verified local release executable."""
from pathlib import Path
import gzip
import hashlib
import io
import json
import platform
import shutil
import subprocess
import tarfile
import tempfile

root=Path(__file__).resolve().parents[1]
version=json.loads((root/'manifest.json').read_text())['version']
binary=root/'target/release/omamonero-core'
if subprocess.check_output([str(binary),'--version'],text=True).strip()!='omamonero-core '+version:
    raise SystemExit('Build the matching release binary first.')
architecture={'amd64':'x86_64','arm64':'aarch64'}.get(platform.machine().lower(),platform.machine().lower())
name=f'omamonero-{version}-linux-{architecture}'
dist=root/'dist';dist.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='omamonero-bundle-') as folder:
    stage=Path(folder)/name
    plugin=stage/'payload/plugin'
    plugin.mkdir(parents=True)
    for entry in ('manifest.json','LICENSE','README.md'):shutil.copy2(root/entry,plugin/entry)
    shutil.copytree(root/'qml',plugin/'qml',ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copy2(binary,stage/'payload/omamonero-core')
    shutil.copy2(root/'packaging/omamonero.service',stage/'payload/omamonero.service')
    (stage/'installer').mkdir()
    for entry in ('engine.py','control.py','bootstrap.py','release_fetch.py'):shutil.copy2(root/'installer'/entry,stage/'installer'/entry)
    launcher='''[Desktop Entry]
Version=1.0
Type=Application
Name=Install OmaMonero
Comment=Install the native Monero bar companion for this user
Exec=/usr/bin/python3 -c "import pathlib,runpy,sys,urllib.parse;runpy.run_path(str(pathlib.Path(urllib.parse.unquote(urllib.parse.urlsplit(sys.argv[1]).path)).parent/'installer'/'bootstrap.py'),run_name='__main__')" %k
Terminal=false
Categories=Utility;
StartupNotify=false
'''
    (stage/'Install OmaMonero.desktop').write_text(launcher)
    (stage/'Install OmaMonero').write_text('#!/usr/bin/python3\nimport runpy\nfrom pathlib import Path\nrunpy.run_path(str(Path(__file__).resolve().parent/"installer/bootstrap.py"),run_name="__main__")\n')
    (stage/'START HERE.txt').write_text('OmaMonero '+version+'\n\nExtract this folder, then open Install OmaMonero.\nIf your file manager asks, choose Allow Launching / Run.\nClick Install and choose whether to enable public prices.\nSetup opens inside your existing Omarchy bar. No separate settings application.\nNo terminal, compiler or administrator password is needed.\nSettings, diagnostics and removal: click XMR in your bar.\n\nThis build passes local compatibility tests. It is NOT officially marketplace-verified.\nChecksums detect damaged downloads; they do not replace a trusted release source.\n')
    files={}
    for path in sorted(stage.rglob('*')):
        if path.is_symlink():raise SystemExit('No symlinks are allowed in a release.')
        if path.is_file():files[path.relative_to(stage).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    (stage/'bundle.json').write_text(json.dumps({'version':version,'architecture':architecture,'marketplace_verified':False,'files':files},sort_keys=True,indent=2)+'\n')
    output=io.BytesIO()
    with tarfile.open(fileobj=output,mode='w',format=tarfile.PAX_FORMAT) as archive:
        for path in sorted(stage.rglob('*')):
            if not path.is_file():continue
            data=path.read_bytes();entry=tarfile.TarInfo(name+'/'+path.relative_to(stage).as_posix())
            entry.size=len(data);entry.mtime=0;entry.uid=entry.gid=0
            entry.mode=0o755 if path.name in ('omamonero-core','Install OmaMonero','Install OmaMonero.desktop') else 0o644
            archive.addfile(entry,io.BytesIO(data))
    archive_path=dist/(name+'.tar.gz')
    with archive_path.open('wb') as raw:
        with gzip.GzipFile(filename='',fileobj=raw,mode='wb',mtime=0) as compressed:compressed.write(output.getvalue())
    digest=hashlib.sha256(archive_path.read_bytes()).hexdigest()
    (dist/(name+'.sha256')).write_text(digest+'  '+archive_path.name+'\n')
    print(archive_path)
