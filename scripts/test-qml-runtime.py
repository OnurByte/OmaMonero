#!/usr/bin/env python3
"""Non-visual Quickshell test engine; no ShellRoot, desktop, or shell configuration changes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import time

root = Path(__file__).resolve().parents[1]
shell = Path(os.environ.get('OMARCHY_PATH', '/usr/share/omarchy')) / 'shell'
runner = shutil.which('qs') or 'quickshell'
with tempfile.TemporaryDirectory(prefix='omamonero-runtime-') as folder:
    runtime = Path(folder)
    stage = runtime / 'harness'
    stage.mkdir()
    imports = stage
    frontend = root / Path(json.loads((root/'manifest.json').read_text())['entryPoints']['barWidget']).parent
    shutil.copytree(frontend, stage / 'Plugin')
    shutil.copy(root / 'tests/qml/runtime.qml', stage / 'shell.qml')
    for name in ('Commons', 'Ui'):
        shutil.copytree(shell / name, imports / name)
    home = runtime / 'home'
    control = home / '.local/share/omamonero/installer/control.py'
    control.parent.mkdir(parents=True)
    control.write_text("import os,sys\nfrom pathlib import Path\nwith open(Path(os.environ['XDG_RUNTIME_DIR'])/'control-calls','a') as f:f.write(sys.argv[1]+'\\n')\n")
    (control.parent.parent/'installation.json').write_text(json.dumps({'installed_files':{str(control):'fixture'}}))
    def publish():
        time.sleep(2)
        state = runtime / 'omamonero'
        state.mkdir(mode=0o700)
        for height in range(100, 301, 10):
            snapshot = {'api_version':1,'generated_at':int(time.time()),'stale_after_secs':15,
                'node': {'state':'online','height':height,'target_height':300,'sync_percent':100,
                    'incoming_peers':2,'outgoing_peers':8,'latency_ms':2,'network':'mainnet',
                    'version':'0.18.4.0','untrusted':False},
                'privacy': {'transport':'local','p2p_verified':False}}
            temp = state / '.status-test'
            temp.write_text(json.dumps(snapshot))
            temp.chmod(0o600)
            temp.replace(state / 'status.json')
            time.sleep(0.25)
        time.sleep(6)
        temp = state / '.status-test'
        temp.write_text('{broken')
        temp.chmod(0o600)
        temp.replace(state / 'status.json')
        time.sleep(6)
        (state / 'status.json').unlink()
    worker = threading.Thread(target=publish, daemon=True)
    display = os.environ.get('WAYLAND_DISPLAY', 'wayland-1')
    if not display.startswith('/'):
        display = str(Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / display)
    env = dict(os.environ, QT_QPA_PLATFORM='wayland', WAYLAND_DISPLAY=display, XDG_RUNTIME_DIR=folder, HOME=str(home))
    process = subprocess.Popen([runner,'--no-color','-p',str(stage / 'shell.qml')],
        cwd=root,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    worker.start()
    try:
        output = process.communicate(timeout=45)[0]
    except subprocess.TimeoutExpired:
        process.kill()
        output = process.communicate()[0]
        print(output)
        raise SystemExit('Qt runtime test timed out')
    print(output)
    raise SystemExit(0 if process.returncode == 0 and 'OMAMONERO_RUNTIME_PASS:' in output and 'OMAMONERO_RUNTIME_FAIL:' not in output else 1)
