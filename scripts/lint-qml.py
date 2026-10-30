#!/usr/bin/env python3
"""Expose Quickshell's virtual qs.* imports to Qt's standalone linter."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
shell = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell'
qml_lint = shutil.which('qmllint') or '/usr/lib/qt6/bin/qmllint'
with tempfile.TemporaryDirectory(prefix='omamonero-lint-') as directory:
    qs = Path(directory) / 'qs'
    qs.mkdir()
    for name in ('Commons', 'Ui'):
        shutil.copytree(shell / name, qs / name)
    result = subprocess.run([qml_lint, '-I', directory, *map(str, sorted((root / 'qml').rglob('*.qml')))], cwd=root)
    raise SystemExit(result.returncode)
