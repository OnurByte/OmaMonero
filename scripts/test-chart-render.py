#!/usr/bin/env python3
"""Render real chart components with labelled fixture data offscreen, for visual QA only."""
import json,os,shutil,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
frontend=root/Path(json.loads((root/'manifest.json').read_text())['entryPoints']['barWidget']).parent
with tempfile.TemporaryDirectory(prefix='omamonero-chart-render-') as folder:
 p=Path(folder);stage=p/'harness';stage.mkdir();session=p/'session';session.mkdir(mode=0o700)
 shutil.copytree(frontend,stage/'Plugin')
 for name in ('Commons','Ui'):shutil.copytree(Path(os.environ.get('OMARCHY_PATH','/usr/share/omarchy'))/'shell'/name,stage/name)
 shutil.copy(root/'tests/qml/chart-render.qml',stage/'shell.qml')
 output=os.environ.get('OMAMONERO_QA_OUTPUT','/tmp/omamonero-chart-qa.png')
 env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QT_LOGGING_RULES='qt.qml.usedbeforedeclared=false',XDG_RUNTIME_DIR=str(session),OMAMONERO_QA_OUTPUT=output)
 env.pop('WAYLAND_DISPLAY',None)
 r=subprocess.run(['qs','--no-color','-p',str(stage/'shell.qml')],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=12)
 print(r.stdout)
 assert r.returncode==0 and 'CHART_RENDER_PASS' in r.stdout and 'CHART_RENDER_FAIL' not in r.stdout
 print(output)
