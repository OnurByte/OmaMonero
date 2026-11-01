#!/usr/bin/env python3
"""Backend-free integration against local HTTP fixtures in an isolated home/session."""
import http.server
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import time

root=Path(__file__).resolve().parents[1]
address='44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A'
methods=[]
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def do_POST(self):
        request=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        method=request['method'];methods.append(method)
        values={
            'get_info':dict(status='OK',height=300,target_height=300,synchronized=True,busy_syncing=False,nettype='mainnet',incoming_connections_count=2,outgoing_connections_count=8,version='0.18.4.0',untrusted=False),
            'get_balance':dict(balance=18446744073709551615,unlocked_balance=123),
            'get_address':dict(address=address),'get_height':dict(height=1000),
            'get_transfers':{'in':[dict(txid='b'*64,amount=1000000000000,confirmations=3,timestamp=int(time.time()))]},
            'check_tx_proof':dict(good=True,received=1000000000000,confirmations=5,in_pool=False)}
        if method=='get_transfers':
            assert request['params']['filter_by_height'] and request['params']['min_height']==280
            assert request['params']['out'] is False
        body=json.dumps(dict(jsonrpc='2.0',id='omamonero',result=values[method])).encode()
        self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    def do_GET(self):
        assert self.path=='/2/summary'
        body=json.dumps(dict(hashrate=dict(total=[123]),results=dict(shares_good=2,shares_total=3))).encode()
        self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix='omamonero-runtime-') as folder:
        base=Path(folder);stage=base/'harness';stage.mkdir();home=base/'home';home.mkdir();session=base/'session';session.mkdir(mode=0o700)
        frontend=root/Path(json.loads((root/'manifest.json').read_text())['entryPoints']['barWidget']).parent
        shutil.copytree(frontend,stage/'Plugin');shutil.copy(root/'tests/qml/runtime.qml',stage/'shell.qml')
        shell=Path(os.environ.get('OMARCHY_PATH','/usr/share/omarchy'))/'shell'
        for name in ('Commons','Ui'): shutil.copytree(shell/name,stage/name)
        config=home/'.config/omamonero';config.mkdir(parents=True,mode=0o700)
        pool=base/'pool/local';pool.mkdir(parents=True)
        (pool/'stratum').write_text(json.dumps(dict(hashrate_15m=1,hashrate_1h=2,hashrate_24h=3,shares_found=4,connections=5)))
        url=f'http://127.0.0.1:{server.server_port}'
        (config/'config.json').write_text(json.dumps(dict(endpoint=url,modules=dict(wallet_rpc=url,watch_only_confirmed=True,xmrig_url=url,p2pool_directory=str(pool.parent)))))
        display=os.environ.get('WAYLAND_DISPLAY','wayland-1')
        if not display.startswith('/'): display=str(Path(os.environ['XDG_RUNTIME_DIR'])/display)
        env=dict(os.environ,WAYLAND_DISPLAY=display,QT_LOGGING_RULES='qt.qml.usedbeforedeclared=false',QT_QPA_PLATFORM='wayland',HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_DATA_HOME=str(home/'.local/share'),XDG_RUNTIME_DIR=str(session))
        # Exercise the real URI launcher without contacting the desktop notification bus.
        bins=base/'bin';bins.mkdir();(bins/'notify-send').write_text('#!/bin/sh\nexit 0\n');(bins/'notify-send').chmod(0o700)
        (bins/'feather').write_text('#!/bin/sh\nsleep 2\n');(bins/'feather').chmod(0o700)
        env['PATH']=str(bins)+':/usr/bin:/bin'
        uri_env=env
        subprocess.run(['bash',str(frontend/'uri-handler.sh'),'monero:'+address+'?tx_amount=0.1'],env=uri_env,check=True)
        result=subprocess.run([shutil.which('qs') or 'quickshell','--no-color','-p',str(stage/'shell.qml')],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=30)
        print(result.stdout)
        assert result.returncode==0 and 'OMAMONERO_RUNTIME_PASS:' in result.stdout and 'OMAMONERO_RUNTIME_FAIL' not in result.stdout
        saved=json.loads((config/'config.json').read_text());assert saved['market_enabled'] is False
        assert (config.stat().st_mode&0o077)==0
        assert ((session/'omamonero-native/inbox').stat().st_mode&0o077)==0
        assert set(methods)=={'get_info','get_balance','get_address','get_height','get_transfers','check_tx_proof'}
finally: server.shutdown()
