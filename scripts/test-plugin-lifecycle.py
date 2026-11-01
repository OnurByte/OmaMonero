#!/usr/bin/env python3
"""Official manager + actual Omarchy registry in an isolated non-visual Wayland engine."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

parser=argparse.ArgumentParser()
parser.add_argument('--working-frontend',action='store_true',help='Test uncommitted frontend files after official installation')
parser.add_argument('--upgrade-from',default='7cad7ce',help='Previous commit for the migration case')
parser.add_argument('--source-url',help='Use this published source for the fresh-install case')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
id='io.github.onurbyte.omamonero'
omarchy=Path(os.environ.get('OMARCHY_PATH','/usr/share/omarchy'))
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
legacy=subprocess.check_output(['git','rev-parse',args.upgrade_from],cwd=root,text=True).strip()
with tempfile.TemporaryDirectory(prefix='omamonero-manager-') as folder:
    base=Path(folder);upstream=base/'upstream.git'
    subprocess.run(['git','clone','--quiet','--bare',str(root),str(upstream)],check=True)
    subprocess.run(['git','--git-dir',str(upstream),'symbolic-ref','HEAD','refs/heads/release-test'],check=True)
    for migration in ((False,) if args.working_frontend else (False,True)):
        subprocess.run(['git','--git-dir',str(upstream),'update-ref','refs/heads/release-test',legacy if migration else head],check=True)
        case=base/('upgrade' if migration else 'fresh');case.mkdir();home=case/'home';home.mkdir();session=case/'runtime';session.mkdir(mode=0o700);shell=case/'host/shell';shell.mkdir(parents=True)
        for name in ('Commons','Ui'):shutil.copytree(omarchy/'shell'/name,shell/name)
        (shell/'services').mkdir();(shell/'plugins').mkdir();shutil.copy(omarchy/'shell/services/PluginRegistry.qml',shell/'services/PluginRegistry.qml');shutil.copy(root/'tests/qml/lifecycle.qml',shell/'shell.qml')
        config=home/'.config/omamonero';config.mkdir(parents=True,mode=0o700)
        if migration:(config/'config.toml').write_text('endpoint="http://127.0.0.1:1"\nmarket_enabled=false\nnetwork="stagenet"\ntransport="local"\n')
        else:(config/'config.json').write_text(json.dumps(dict(endpoint='http://127.0.0.1:1')))
        display=os.environ.get('WAYLAND_DISPLAY','wayland-1')
        if not display.startswith('/'):display=str(Path(os.environ['XDG_RUNTIME_DIR'])/display)
        env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'),XDG_RUNTIME_DIR=str(session),OMARCHY_PATH=str(shell.parent),WAYLAND_DISPLAY=display,QT_QPA_PLATFORM='wayland',QT_LOGGING_RULES='qt.qml.usedbeforedeclared=false',PATH=str(omarchy/'bin')+':/usr/bin:/bin')
        log=(case/'engine.log').open('w+')
        engine=subprocess.Popen(['qs','--no-color','-p',str(shell/'shell.qml')],env=env,stdout=log,stderr=subprocess.STDOUT)
        def run(*args):
            p=subprocess.run(args,env=env,capture_output=True,text=True,timeout=35)
            if p.returncode:raise AssertionError(' '.join(args)+'\n'+p.stdout+p.stderr)
            return p.stdout.strip()
        def eventually(callback):
            deadline=time.monotonic()+15
            while time.monotonic()<deadline:
                assert engine.poll() is None,'Qt engine exited'
                try:
                    result=callback()
                    if result:return result
                except (AssertionError,ValueError):pass
                time.sleep(.1)
            log.flush();log.seek(0);raise AssertionError('Lifecycle observation timed out\n'+log.read())
        def widget_ready():
            data=json.loads(run('omarchy-shell','shell','widgetInfo'))
            return data if data.get('ready') and data.get('view') and data['view'].get('privacy') and '/v0_4_1/' in data.get('source','') else None
        try:
            eventually(lambda:run('omarchy-shell','shell','ping')=='ok')
            run('omarchy','plugin','add',str(upstream) if migration or not args.source_url else args.source_url,*([] if args.working_frontend else ['--enable']),'--yes')
            installed=home/'.config/omarchy/plugins'/id
            if args.working_frontend and not migration:
                shutil.copytree(root/'qml',installed/'qml',dirs_exist_ok=True)
                shutil.copy(root/'manifest.json',installed/'manifest.json')
                run('omarchy-shell','shell','rescanPlugins')
                eventually(lambda:json.loads(run('omarchy','plugin','list','--json')))
                run('omarchy','plugin','enable',id)
            eventually(lambda:json.loads(run('omarchy','plugin','list','--json'))[0]['enabled'])
            if migration:
                subprocess.run(['git','--git-dir',str(upstream),'update-ref','refs/heads/release-test',head],check=True)
                run('omarchy','plugin','update',id,'--yes')
            view=eventually(widget_ready)['view']
            assert view['market']['state']=='disabled' and view['privacy']['transport']=='local'
            assert run('git','-C',str(installed),'rev-parse','HEAD')==head
            assert not (home/'.local/bin/omamonero-core').exists()
            assert not (home/'.config/systemd/user/omamonero.service').exists()
            if migration:assert 'stagenet' in (config/'config.toml').read_text()
            run('omarchy','plugin','disable',id)
            eventually(lambda:not json.loads(run('omarchy','plugin','list','--json'))[0]['enabled'])
            run('omarchy','plugin','enable',id)
            eventually(widget_ready)
            run('omarchy','plugin','remove',id,'--yes')
            assert not installed.exists() and config.exists()
            eventually(lambda:json.loads(run('omarchy','plugin','list','--json'))==[])
            print(('UPGRADE' if migration else 'FRESH')+'_MANAGER_PASS: official add/enable/update/disable/remove, real registry/widget, no backend install',flush=True)
        finally:
            engine.terminate()
            try:engine.wait(timeout=5)
            except subprocess.TimeoutExpired:engine.kill();engine.wait()
            log.close()
