#!/usr/bin/env python3
"""Run the official validator on the exact shipped archive, excluding dev dependencies."""
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
root=Path(__file__).resolve().parents[1]
subprocess.run([sys.executable,str(root/'scripts/package.py')],check=True)
validator=sys.argv[1] if len(sys.argv)>1 else 'omarchy-plugin-validate'
with tempfile.TemporaryDirectory(prefix='omamonero-validator-') as directory:
 with tarfile.open(root/'dist/omamonero-plugin-0.4.0.tar.gz') as tar:tar.extractall(directory,filter='data')
 subprocess.run(['bash',validator,str(Path(directory)/'io.github.onurbyte.omamonero')],check=True)
print('Official Omarchy validator passed for shipped 0.4.0 archive')
