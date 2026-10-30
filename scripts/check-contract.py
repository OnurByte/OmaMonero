#!/usr/bin/env python3
import json
from pathlib import Path
import re
import tomllib

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'manifest.json').read_text())
cargo = tomllib.loads((root/'Cargo.toml').read_text())
lock = tomllib.loads((root/'Cargo.lock').read_text())
version = cargo['package']['version']
assert manifest['version'] == version
assert next(p['version'] for p in lock['package'] if p['name'] == 'omamonero-core') == version
assert re.search(r'^pkgver=(.+)$',(root/'packaging/PKGBUILD').read_text(),re.M)[1] == version
assert manifest['id'] == 'io.github.onurbyte.omamonero'
assert manifest['schemaVersion'] == 1
assert manifest['kinds'] == ['bar-widget']
assert manifest['entryPoints'] == {'barWidget':'qml/v'+version.replace('.', '_')+'/BarWidget.qml'}
for path in (root/'qml').rglob('*'):
    assert not path.is_symlink(), path
    if path.suffix == '.qml':
        text = path.read_text()
        assert not re.search(r'\bShellRoot\s*\{',text), path
        assert not re.search(r'\bProcess\s*\{',text), path
assert 'Restart=on-failure' in (root/'packaging/omamonero.service').read_text()
print(f'Plugin, Cargo, lockfile and package contract agree at {version}')
