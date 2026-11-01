#!/usr/bin/env python3
"""Check the shipped backend-free plugin, version and runtime contract."""
import json
from pathlib import Path
import re
from runtime_contract import validate_qml_commands, validate_helper_actions
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'manifest.json').read_text());p=json.loads((root/'package.json').read_text())
assert m['version']==p['version']=='0.4.3'
assert m['id']=='io.github.onurbyte.omamonero' and m['schemaVersion']==1 and m['kinds']==['bar-widget']
assert m['entryPoints']=={'barWidget':'qml/v0_4_3/BarWidget.qml'}
frontend=root/Path(m['entryPoints']['barWidget']).parent
for path in frontend.rglob('*'):
 assert not path.is_symlink(),path
 if path.suffix=='.qml':
  text=path.read_text()
  assert not re.search(r'\b(?:ShellRoot|Window)\s*\{',text),path
  validate_qml_commands(text,http=path==frontend/'Http.qml')
assert 10000 < (frontend/'generated/Core.js').stat().st_size < 60000
assert list(frontend.rglob('*.js')) == [frontend/'generated/Core.js']
assert 'smol-toml' not in p.get('dependencies', {})
assert not (root/'src/core/migration.ts').exists()
assert 'config.toml' not in (frontend/'StatusStore.qml').read_text()
validate_helper_actions((frontend/'native.sh').read_text())
transport=(root/'src/core/privacy.ts').read_text()
assert re.findall(r'argv:\s*(\[[^\]]+\])',transport)==["['/usr/bin/curl','-q','--config','-']"]
assert not (root/'Cargo.toml').exists() and not (root/'installer').exists()
print('0.4.3 native TypeScript/QML contract passes; no Rust/Python installer or service')
