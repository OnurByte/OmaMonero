#!/usr/bin/env python3
"""Explicit bar actions. Jobs survive a panel/plugin reload and publish private state."""
from pathlib import Path
import argparse
import fcntl
import json
import os
import re
import shutil
import stat
import subprocess
import hashlib
import sys
import tempfile
import time
import tomllib
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import engine
import release_fetch

PRIVATE_ACTIONS = frozenset({'install','save','receive','preview-uri','wallet','module-config','proof'})
MAX_REQUEST_BYTES = 16384

def take_request(request_id):
    """Consume a one-time request from the owner's private session directory."""
    if not re.fullmatch(r'[0-9a-f]{32}',request_id):
        raise engine.InstallError('Invalid private request identifier.')
    # XDG_RUNTIME_DIR is verified as owner-only by state_path(). It always exists
    # before the panel starts, unlike the plugin's own state subdirectory.
    runtime=state_path().parent.parent
    path=runtime/('omamonero-request-'+request_id+'.json')
    try:
        fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_CLOEXEC)
    except OSError as error:
        raise engine.InstallError('Private request is unavailable.') from error
    try:
        metadata=os.fstat(fd)
        if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid!=os.geteuid()
                or metadata.st_nlink!=1 or metadata.st_mode&0o022):
            raise engine.InstallError('Unsafe private request file.')
        # Qt's QSaveFile can create a new file with mode 0644. The containing
        # runtime directory is 0700; tighten the file before consuming it.
        os.fchmod(fd,0o600)
        path.unlink()
        raw=os.read(fd,MAX_REQUEST_BYTES+1)
    except OSError as error:
        raise engine.InstallError('Private request is unavailable.') from error
    finally:
        os.close(fd)
    if len(raw)>MAX_REQUEST_BYTES:
        raise engine.InstallError('Private request is too large.')
    try:
        request=json.loads(raw)
    except (ValueError,UnicodeError) as error:
        raise engine.InstallError('Invalid private request data.') from error
    if (not isinstance(request,dict) or set(request)!={'endpoint','market_enabled','payload'}
            or not (request['endpoint'] is None or isinstance(request['endpoint'],str))
            or not isinstance(request['market_enabled'],bool)
            or not isinstance(request['payload'],dict)):
        raise engine.InstallError('Invalid private request data.')
    return request

def info(paths):
    config=tomllib.loads(paths.config.read_text()) if paths.config.exists() else {}
    pending=paths.data/'pending'
    version=None
    if (pending/'bundle.json').is_file():version=engine.verify_bundle(pending)['version']
    receipt=json.loads(paths.receipt.read_text()) if paths.receipt.exists() else {}
    return {'installed':paths.receipt.exists(),'version':receipt.get('version'),
        'pending_version':version,'endpoint':config.get('endpoint','http://127.0.0.1:18081'),
        'market_enabled':config.get('market_enabled',False),'transport':config.get('transport','local'),
        'market_source':config.get('market_source',{'name':'Kraken','url':'','price_pointer':'/price','points_pointer':'/points','timestamp_pointer':'/timestamp','point_price_pointer':'/price','interval_secs':3600}),
        'modules':config.get('modules',{}),
        'receive_address':json.loads((paths.config.parent/'receive.json').read_text()).get('address','') if (paths.config.parent/'receive.json').is_file() else '',
        'wallets':{'feather':bool(shutil.which('feather')),'monero_gui':bool(shutil.which('monero-wallet-gui'))},
        'uri_handler':receipt.get('uri_handler_owned',False)}

def state_path():
    parent=Path(os.environ.get('XDG_RUNTIME_DIR',''))
    if not parent.is_absolute() or parent.is_symlink() or parent.stat().st_uid!=os.geteuid() or parent.stat().st_mode&0o077:raise engine.InstallError('The private session directory is unavailable.')
    folder=parent/'omamonero';engine.reject_symlinks(folder)
    folder.mkdir(mode=0o700,exist_ok=True)
    if folder.stat().st_mode&0o077:raise engine.InstallError('The private setup directory has unsafe permissions.')
    return folder/'setup.json'

def payment_path():
    return state_path().with_name('payment.json')

def queue_incoming(payment):
    """Keep a bounded, private queue so a later FileView refresh cannot lose links."""
    queue=payment_path().with_name('incoming.json')
    try:
        content=json.loads(queue.read_text()) if queue.is_file() else {'requests':[]}
        requests=content.get('requests',[])
        if not isinstance(requests,list):requests=[]
    except (OSError,ValueError):requests=[]
    request_id=str(time.time_ns())+'-'+hashlib.sha256(payment['uri'].encode()).hexdigest()[:12]
    requests.append({'id':request_id,'created_at':int(time.time()),'payment':payment})
    engine.atomic_write(queue,json.dumps({'requests':requests[-20:]},separators=(',',':')).encode(),0o600)
    payment['request_id']=request_id
    engine.atomic_write(payment_path(),json.dumps({'state':'ready','payment':payment},separators=(',',':')).encode(),0o600)
    return payment

def public_request(paths,request):
    result=subprocess.run([str(paths.binary),'--config',str(paths.config),'payment'],input=json.dumps(request),capture_output=True,text=True,timeout=10)
    if result.returncode:raise engine.InstallError('Invalid public address, checksum, network or amount. No request was created.')
    payment=json.loads(result.stdout)
    svg=payment.pop('qr_svg')
    path=state_path().parent/('receive-'+hashlib.sha256(payment['uri'].encode()).hexdigest()[:16]+'.svg')
    engine.atomic_write(path,svg.encode(),0o600)
    payment['qr_path']=str(path)
    return payment

def run(action,paths,enabled=False,endpoint=None,payload=None):
    if action=='info':return info(paths)
    if action=='install':
        pending=paths.data/'pending'
        if (pending/'bundle.json').is_file():
            result=engine.install(pending,paths,enabled,endpoint,market_source=payload.get('market_source'))
            shutil.rmtree(pending)
            (paths.data/'bootstrap.json').unlink(missing_ok=True)
        else:
            if not engine.github_managed_plugin(paths,engine.Runner()):
                raise engine.InstallError('Install the official OmaMonero plugin through Omarchy first.')
            try:version=json.loads((paths.plugin/'manifest.json').read_text())['version']
            except (OSError,ValueError,KeyError) as error:raise engine.InstallError('The plugin manifest is invalid.') from error
            with tempfile.TemporaryDirectory(prefix='omamonero-release-') as directory:
                bundle=release_fetch.download_verified_release(version,Path(directory))
                result=engine.install(bundle,paths,enabled,endpoint,market_source=payload.get('market_source'))
        return dict(info(paths),message='Installation complete. Everything is available in the bar.',version=result['version'])
    if action=='save':engine.settings(paths,enabled,endpoint,market_source=payload.get('market_source'));return dict(info(paths),message='Settings saved.')
    if action=='diagnostics':
        report=engine.Runner().run([paths.binary,'doctor'],check=False)
        try:return dict(info(paths),diagnostics=json.loads(report.stdout))
        except ValueError:return dict(info(paths),message='The backend could not be checked.')
    if action=='receive':
        engine.atomic_write(payment_path(),b'{"state":"pending"}',0o600)
        payment=public_request(paths,payload)
        engine.atomic_write(paths.config.parent/'receive.json',json.dumps({'address':payment['address']}).encode(),0o600)
        engine.atomic_write(payment_path(),json.dumps({'state':'ready','payment':payment},separators=(',',':')).encode(),0o600)
        return dict(info(paths),payment=payment,message='Receive request generated locally. No private keys were used.')
    if action=='preview-uri':
        engine.atomic_write(payment_path(),b'{"state":"pending"}',0o600)
        payment=public_request(paths,{'uri':payload.get('uri')})
        payment['incoming_request']=True
        queue_incoming(payment)
        return dict(info(paths),payment=payment,message='Payment request preview. Nothing has been sent.')
    if action=='wallet':
        name=payload.get('wallet','feather')
        executable={'feather':'feather','monero_gui':'monero-wallet-gui'}.get(name)
        if not executable or not shutil.which(executable):raise engine.InstallError('This wallet is not installed. Existing wallets are never installed or started automatically.')
        subprocess.Popen([shutil.which(executable)],stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
        return dict(info(paths),message='Wallet opened. Paste the copied request into its payment field; confirm all details in the wallet.')
    if action=='register-uri':engine.register_monero_handler(paths);return dict(info(paths),message='monero: links now open a preview in this native bar. No payment is sent automatically.')
    if action=='module-config':engine.module_settings(paths,payload);return dict(info(paths),message='Read-only module settings saved.')
    if action=='proof':
        result=subprocess.run([str(paths.binary),'--config',str(paths.config),'proof'],input=json.dumps(payload),capture_output=True,text=True,timeout=15)
        if result.returncode:raise engine.InstallError('Proof check failed. Check the proof, address, network and your configured watch-only RPC.')
        return dict(info(paths),proof=json.loads(result.stdout),message='Proof check complete; no spending or key access occurred.')
    if action=='remove':engine.uninstall(paths);return {'message':'OmaMonero removed. Your configuration was preserved.'}
    raise engine.InstallError('Unsupported action.')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['info','install','save','diagnostics','remove','receive','preview-uri','open-uri','wallet','register-uri','module-config','proof']);parser.add_argument('--request-id');parser.add_argument('--uri');args=parser.parse_args()
    paths=engine.Paths(Path.home());state=state_path()
    if args.action=='open-uri':
        # Link opens are read-only and independent of the install/settings lock.
        # Persist before asking the shell to show the panel; a busy setup job is
        # never overwritten and a delayed FileView still sees the request.
        try:
            if not args.uri or len(args.uri)>16384:raise engine.InstallError('Payment link is empty or too large.')
            payment=run('preview-uri',paths,payload={'uri':args.uri})['payment']
            engine.Runner().run(['omarchy','shell','shell','summon',engine.PLUGIN_ID],check=False)
        except Exception as error:
            message=str(error) if isinstance(error,engine.InstallError) else 'This payment link could not be opened.'
            engine.atomic_write(payment_path(),json.dumps({'state':'error','message':message},separators=(',',':')).encode(),0o600)
        return
    # Consume even if a previous job holds the lock, so discarded requests
    # cannot linger on disk when the panel is busy.
    request_error=None
    request={'endpoint':None,'market_enabled':False,'payload':{}}
    try:
        if args.request_id:
            if args.action not in PRIVATE_ACTIONS:raise engine.InstallError('Unexpected private request.')
            request=take_request(args.request_id)
        elif args.action in PRIVATE_ACTIONS:
            raise engine.InstallError('This action requires a private request.')
    except engine.InstallError as error:
        request_error=error
    # A second mutating action must not overwrite a currently running job's progress.
    lock_path=state.with_name('setup.lock');engine.reject_symlinks(lock_path)
    fd=os.open(lock_path,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    try:
        metadata=os.fstat(fd)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid!=os.geteuid() or stat.S_IMODE(metadata.st_mode)!=0o600 or metadata.st_nlink!=1:raise engine.InstallError('Unsafe setup lock.')
        try:fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:return
        def publish(status,**values):engine.atomic_write(state,json.dumps(dict(action=args.action,state=status,updated_at=int(time.time()),**values)).encode(),0o600)
        publish('running')
        try:
            if request_error:raise request_error
            data=run(args.action,paths,request['market_enabled'],request['endpoint'],request['payload'])
            publish('done',data=data)
            if args.action in ('install','save'):engine.Runner().run(['omarchy','shell','shell','summon',engine.PLUGIN_ID],check=False)
        except Exception as error:
            message=str(error) if isinstance(error,engine.InstallError) else 'This action could not complete. Existing settings were preserved.'
            publish('error',message=message)
    finally:os.close(fd)
if __name__=='__main__':main()
