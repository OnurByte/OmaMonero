#!/usr/bin/env python3
from pathlib import Path
import os,shutil,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='omamonero-cancel-') as folder:
 p=Path(folder);(p/'Plugin').mkdir();shutil.copy(root/'qml/v0_4_0/Http.qml',p/'Plugin/Http.qml');(p/'Plugin/qmldir').write_text('Http 1.0 Http.qml\n');shutil.copy(root/'tests/qml/http-cancel.qml',p/'shell.qml')
 try:r=subprocess.run(['qs','--no-color','-p',str(p/'shell.qml')],env=dict(os.environ,QT_QPA_PLATFORM='offscreen',XDG_RUNTIME_DIR=folder),capture_output=True,text=True,timeout=5)
 except subprocess.TimeoutExpired:raise SystemExit('FAIL: HTTP cancellation API not implemented')
 print(r.stdout+r.stderr)
 assert 'CANCEL_PASS' in r.stdout+r.stderr and not (p/'must-not-run').exists()
