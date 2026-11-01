#!/usr/bin/env python3
"""Real FileView errors + production config orchestration, with a no-network transport boundary."""
import json,os,re,shutil,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
front=root/Path(json.loads((root/'manifest.json').read_text())['entryPoints']['barWidget']).parent
for case in ['json-directory','json-permission','toml-directory','toml-permission','malformed','paused-with-legacy-on','tor-legacy','missing']:
 with tempfile.TemporaryDirectory(prefix='omamonero-config-io-') as folder:
  p=Path(folder);stage=p/'shell';stage.mkdir();home=p/'home';config=home/'.config/omamonero';config.mkdir(parents=True,mode=0o700);runtime=p/'runtime';runtime.mkdir(mode=0o700)
  shutil.copytree(front,stage/'Plugin')
  (stage/'Plugin/Http.qml').write_text('''import QtQuick
QtObject {
 property bool publicDirect:false
 property int requests:0
 function cancel() {}
 function send(spec,callback) {requests++;if(spec.stdin.indexOf("api.kraken.com")>=0 && /^proxy = ""$/m.test(spec.stdin))publicDirect=true;callback(null)}
}''')
  (stage/'shell.qml').write_text('''import QtQuick
import Quickshell
import "Plugin" as Oma
QtObject {property bool started:Oma.StatusStore.ready
property Timer check:Timer {property int ticks:0;interval:100;running:true;repeat:true;onTriggered:{const s=Oma.StatusStore;ticks++;if(!s.configLoaded && ticks<30)return;console.log("CONFIG_IO_STATE",JSON.stringify({error:s.configError,loaded:s.configLoaded,direct:s.http.publicDirect,enabled:s.config.market_enabled,transport:s.config.transport}));Qt.quit()}}}''')
  if case=='json-directory':(config/'config.json').mkdir()
  if case=='toml-directory':(config/'config.toml').mkdir()
  if case=='json-permission':(config/'config.json').write_text('{"market_enabled":false}');(config/'config.json').chmod(0)
  if case=='toml-permission':(config/'config.toml').write_text('market_enabled=false\n');(config/'config.toml').chmod(0)
  if case=='malformed':(config/'config.json').write_text('{broken')
  if case=='paused-with-legacy-on':(config/'config.json').write_text('{"market_enabled":false}');(config/'config.toml').write_text('market_enabled=true\n')
  if case=='tor-legacy':(config/'config.toml').write_text('endpoint="http://node.onion:18081"\ntransport="tor"\nproxy="socks5h://127.0.0.1:9050"\nmarket_enabled=true\n')
  env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'),XDG_RUNTIME_DIR=str(runtime),QT_QPA_PLATFORM='offscreen',QT_LOGGING_RULES='qt.qml.usedbeforedeclared=false');env.pop('WAYLAND_DISPLAY',None)
  result=subprocess.run(['qs','--no-color','-p',str(stage/'shell.qml')],env=env,capture_output=True,text=True,timeout=6)
  output=result.stdout+result.stderr;match=re.search(r'CONFIG_IO_STATE (\{[^\n]+\})',output);assert match,(case,output)
  state=json.loads(match[1]);assert state['loaded'],(case,state)
  if case in ['json-directory','json-permission','toml-directory','toml-permission','malformed']:assert state['error'] and not state['direct'],(case,state)
  elif case=='paused-with-legacy-on':assert not state['error'] and not state['direct'] and not state['enabled'],(case,state)
  elif case=='tor-legacy':assert not state['error'] and not state['direct'] and state['transport']=='tor',(case,state)
  else:assert not state['error'] and state['direct'] and state['enabled'],(case,state)
  print('CONFIG_IO_PASS',case)
