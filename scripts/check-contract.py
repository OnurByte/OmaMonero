#!/usr/bin/env python3
"""Check the shipped backend-free plugin, version and runtime contract."""
import json
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'manifest.json').read_text());p=json.loads((root/'package.json').read_text())
assert m['version']==p['version']=='0.4.1'
assert m['id']=='io.github.onurbyte.omamonero' and m['schemaVersion']==1 and m['kinds']==['bar-widget']
assert m['entryPoints']=={'barWidget':'qml/v0_4_1/BarWidget.qml'}
frontend=root/Path(m['entryPoints']['barWidget']).parent
for path in frontend.rglob('*'):
 assert not path.is_symlink(),path
 if path.suffix=='.qml':
  text=path.read_text()
  assert not re.search(r'\b(?:ShellRoot|Window)\s*\{',text),path
  assert not re.search(r'python3|omamonero-core|execDetached\(.*sudo',text),path
assert (frontend/'generated/Core.js').stat().st_size>10000
assert not (root/'Cargo.toml').exists() and not (root/'installer').exists()
print('0.4.1 native TypeScript/QML contract passes; no Rust/Python installer or service')
