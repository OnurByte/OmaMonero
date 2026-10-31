"""User-only installation. All subprocess arguments are arrays; no shell/elevation."""
from __future__ import annotations
from dataclasses import dataclass
from contextlib import contextmanager
from functools import wraps
import fcntl
import inspect
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import stat
import subprocess
import tempfile
import time
import tomllib

PLUGIN_ID = 'io.github.onurbyte.omamonero'
OFFICIAL_PLUGIN_ORIGIN = 'https://github.com/OnurByte/OmaMonero.git'
PRIVILEGE_POLICY = 'Never elevate GUI/service; get(e)uid must be non-root. Future system dependency installation may use pkexec once.'
class InstallError(Exception): pass

def machine():
    return {'amd64':'x86_64','arm64':'aarch64'}.get(platform.machine().lower(), platform.machine().lower())
def verify_bundle(folder: Path):
    folder=Path(folder)
    try:
        metadata=json.loads((folder/'bundle.json').read_text())
        if metadata.get('architecture')!=machine():raise InstallError('This download is for another processor architecture.')
        files=metadata['files']
        required={'payload/omamonero-core','payload/plugin/manifest.json','payload/omamonero.service'}
        if not isinstance(files,dict) or not required.issubset(files):raise InstallError('Incomplete installation bundle.')
        if any(p.is_symlink() for p in folder.rglob('*')):raise InstallError('Installation bundle contains a symbolic link.')
        actual={p.relative_to(folder).as_posix() for p in (folder/'payload').rglob('*') if p.is_file()}
        expected={p for p in files if p.startswith('payload/')}
        if actual!=expected:raise InstallError('Installation bundle has missing or unexpected files.')
        for name,digest in files.items():
            path=Path(name)
            if path.is_absolute() or '..' in path.parts or not re.fullmatch('[0-9a-f]{64}',digest):raise InstallError('Invalid integrity manifest.')
            if hashlib.sha256((folder/path).read_bytes()).hexdigest()!=digest:raise InstallError('Download integrity check failed. Download the release again.')
        manifest=json.loads((folder/'payload/plugin/manifest.json').read_text())
        if manifest.get('id')!=PLUGIN_ID or manifest.get('schemaVersion')!=1 or manifest.get('version')!=metadata.get('version'):raise InstallError('Plugin and backend versions do not agree.')
        return metadata
    except (KeyError,ValueError,OSError,TypeError) as error:
        raise InstallError('The installation bundle could not be verified.') from error

def reject_symlinks(path:Path):
    for part in (path,*path.parents):
        if part.is_symlink():raise InstallError('Installation paths must not be symbolic links.')
        if part.exists() and part.stat().st_uid!=os.geteuid() and part==path:
            raise InstallError('An installation destination belongs to another user.')

def atomic_write(path:Path,data:bytes,mode:int):
    reject_symlinks(path)
    path.parent.mkdir(parents=True,exist_ok=True)
    fd,name=tempfile.mkstemp(prefix='.omamonero-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as file:
            os.fchmod(file.fileno(),mode);file.write(data);file.flush();os.fsync(file.fileno())
        os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)

class FileTransaction:
    def __init__(self):self.old={};self.committed=False
    def __enter__(self):return self
    def write(self,path:Path,data:bytes,mode:int=0o600):
        reject_symlinks(path)
        if path not in self.old:
            self.old[path]=(path.read_bytes(),stat.S_IMODE(path.stat().st_mode)) if path.exists() else None
        atomic_write(path,data,mode)
    def delete(self,path:Path):
        reject_symlinks(path)
        if path not in self.old:self.old[path]=(path.read_bytes(),stat.S_IMODE(path.stat().st_mode)) if path.exists() else None
        path.unlink(missing_ok=True)
    def commit(self):self.committed=True
    def __exit__(self,kind,value,traceback):
        if not self.committed:
            for path,old in reversed(list(self.old.items())):
                if old is None:path.unlink(missing_ok=True)
                else:atomic_write(path,*old)

class Runner:
    def run(self,args,check=True,timeout=45):
        try:
            result=subprocess.run(list(map(str,args)),capture_output=True,text=True,timeout=timeout,
                env=dict(os.environ,GIT_TERMINAL_PROMPT='0',GIT_SSH_COMMAND='ssh -oBatchMode=yes'))
        except (OSError,subprocess.TimeoutExpired) as error:raise InstallError('An installation step could not complete. Nothing requires a terminal; try again from the installer.') from error
        if check and result.returncode:raise InstallError(f'The {args[0]} {args[1] if len(args)>1 else ""} step failed. Previous settings will be restored.')
        return result

@dataclass
class Paths:
    home:Path
    config_home:Path|None = None
    @property
    def data(self):return self.home/'.local/share/omamonero'
    @property
    def binary(self):return self.data/'bin/omamonero-core'
    @property
    def source(self):return self.data/'frontend-source'
    @property
    def plugin(self):return self.home/'.config/omarchy/plugins'/PLUGIN_ID
    @property
    def config(self):
        base=self.config_home or Path(os.environ.get('XDG_CONFIG_HOME',str(self.home/'.config')))
        if not base.is_absolute():base=self.home/'.config'
        return base/'omamonero/config.toml'
    @property
    def unit(self):return self.config.parent.parent/'systemd/user/omamonero.service'
    @property
    def desktop(self):return self.home/'.local/share/applications/omamonero.desktop'
    @property
    def receipt(self):return self.data/'installation.json'

def configure(text:str,market_enabled:bool,endpoint:str|None,market_source:dict|None=None):
    try:current=tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:raise InstallError('Existing settings are invalid. They have been preserved.') from error
    changes={'market_enabled':'true' if market_enabled else 'false'}
    if endpoint is not None:
        changes['endpoint']=json.dumps(endpoint)
        # Preserve explicit proxy routes. Direct HTTPS is an explicit GUI choice.
        if current.get('transport','local') not in ('tor','i2p'):
            from urllib.parse import urlsplit
            try:host=urlsplit(endpoint).hostname
            except ValueError:raise InstallError('Node address is invalid.')
            import ipaddress
            try:local=ipaddress.ip_address(host).is_loopback
            except (ValueError,TypeError):local=False
            changes['transport']='"local"' if local else '"direct"'
    if market_source is not None:
        source=market_source
        name=source.get('name','')
        url=source.get('url','')
        pointers={key:source.get(key,default) for key,default in (
            ('price_pointer','/price'),('points_pointer','/points'),
            ('timestamp_pointer','/timestamp'),('point_price_pointer','/price'))}
        interval=source.get('interval_secs',3600)
        if not isinstance(name,str) or not name.strip() or len(name.strip())>48 or not isinstance(url,str) or len(url)>2048:
            raise InstallError('Enter a source name (up to 48 characters) and a valid HTTPS address.')
        if url:
            from urllib.parse import urlsplit
            parsed=urlsplit(url)
            if parsed.scheme!='https' or not parsed.hostname or parsed.username or parsed.password or parsed.fragment:
                raise InstallError('Market data sources must use a public HTTPS address without embedded credentials or a fragment.')
        else:
            name='Kraken'
        if not isinstance(interval,int) or isinstance(interval,bool) or interval not in (300,900,1800,3600):
            raise InstallError('Choose a sample interval of 5, 15, 30 or 60 minutes.')
        if any(not isinstance(pointer,str) or not pointer.startswith('/') or len(pointer)>256 for pointer in pointers.values()):
            raise InstallError('Each JSON field must be a JSON Pointer beginning with /.')
        custom={'name':json.dumps(name.strip()),'url':json.dumps(url),
            'price_pointer':json.dumps(pointers['price_pointer']),
            'points_pointer':json.dumps(pointers['points_pointer']),
            'timestamp_pointer':json.dumps(pointers['timestamp_pointer']),
            'point_price_pointer':json.dumps(pointers['point_price_pointer']),
            'interval_secs':str(interval)}
        # Replace the existing source table, keeping it ahead of all other tables.
        text=re.sub(r'(?ms)^\[market_source\]\s*\n.*?(?=^\[|\Z)','',text)
        tail_start=re.search(r'(?m)^\s*\[',text)
        tail=text[tail_start.start():] if tail_start else ''
        text=text[:tail_start.start()] if tail_start else text
        text=text.rstrip()+'\n\n[market_source]\n'+'\n'.join(f'{key} = {value}' for key,value in custom.items())+'\n'
        text+=tail
    split=re.search(r'(?m)^\s*\[',text)
    tail=text[split.start():] if split else ''
    text=text[:split.start()] if split else text
    for key,value in changes.items():
        line=f'{key} = {value}'
        pattern=rf'(?m)^{key}\s*=.*$'
        if re.search(pattern,text):text=re.sub(pattern,lambda _:line,text)
        else:text=text.rstrip()+'\n'+line+'\n'
    return text.rstrip()+"\n"+tail

def desktop_quote(value):return '"'+str(value).replace('\\','\\\\').replace('"','\\"').replace('`','\\`').replace('$','\\$').replace('%','%%')+'"'
def desktop_entry(gui:Path):
    return '[Desktop Entry]\nType=Application\nName=OmaMonero\nComment=Monero settings and installation\nExec=/usr/bin/python3 '+desktop_quote(gui)+'\nIcon=omamonero\nTerminal=false\nCategories=Utility;Finance;\nStartupNotify=false\n'
def service_unit(template:str,binary:Path,config:Path|None=None):
    quoted='"'+str(binary).replace('\\','\\\\').replace('"','\\"').replace('%','%%')+'"'
    config_arg=''
    if config is not None:
        config_arg=' --config "'+str(config).replace('\\','\\\\').replace('"','\\"').replace('%','%%')+'"'
    return template.replace('ExecStart=/usr/bin/omamonero-core daemon','ExecStart='+quoted+config_arg+' daemon')

def git(runner:Runner,path:Path,*args,check=True):
    return runner.run(['git','-c','core.hooksPath=/dev/null','-c','commit.gpgsign=false','-c','user.name=OmaMonero installer','-c','user.email=installer@localhost','-C',path,*args],check=check)
def managed_files(paths:Paths):
    return (paths.binary,paths.unit,paths.data/'installer/engine.py',paths.data/'installer/control.py',paths.data/'installer/release_fetch.py')

def legacy_files(paths:Paths):
    return (paths.desktop,paths.home/'.local/share/icons/hicolor/scalable/apps/omamonero.svg',paths.data/'installer/gui.py')

def bootstrap_owned(paths:Paths):
    marker=paths.data/'bootstrap.json'
    if not marker.is_file() or marker.is_symlink():return False
    try:return json.loads(marker.read_text()).get('source')==str(paths.source)
    except (ValueError,OSError):return False

def github_managed_plugin(paths:Paths,runner:Runner):
    """True only for the official Omarchy-managed upstream checkout."""
    if not (paths.plugin/'.git').is_dir():return False
    origin=git(runner,paths.plugin,'remote','get-url','origin',check=False)
    if origin.returncode or origin.stdout.strip()!=OFFICIAL_PLUGIN_ORIGIN:return False
    try:manifest=json.loads((paths.plugin/'manifest.json').read_text())
    except (OSError,ValueError):return False
    return manifest.get('id')==PLUGIN_ID and manifest.get('schemaVersion')==1

def preflight(paths:Paths,runner:Runner):
    if os.geteuid()==0:raise InstallError('Open this installer from your normal desktop account. Administrator access is not needed.')
    for command in ('omarchy','git','systemctl'):
        if not shutil.which(command):raise InstallError(f'This Omarchy installation is missing {command}. The installer does not change system packages automatically.')
    for path in (paths.data,paths.config,paths.unit,paths.desktop,paths.plugin):reject_symlinks(path)
    receipt=None
    if paths.receipt.exists():
        try:receipt=json.loads(paths.receipt.read_text())
        except (OSError,ValueError) as error:raise InstallError('The saved installation record is invalid. Existing files have been preserved.') from error
        if not isinstance(receipt.get('installed_files'),dict):raise InstallError('The saved installation record is incomplete. Existing files have been preserved.')
    for target in (*managed_files(paths),*legacy_files(paths),paths.home/'.local/share/applications/omamonero-link.desktop'):
        reject_symlinks(target)
        if target.exists():
            if receipt is None or receipt['installed_files'].get(str(target))!=hashlib.sha256(target.read_bytes()).hexdigest():
                raise InstallError('An installation file already exists or has local changes. It has been preserved; no replacement was made.')
    if paths.source.exists() and receipt is None and not bootstrap_owned(paths):raise InstallError('An unmanaged frontend source already exists. It has been preserved.')
    if runner.run(['omarchy','shell','shell','ping']).stdout.strip()!='ok':raise InstallError('Sign in to an Omarchy Quattro desktop before installing.')
    runner.run(['systemctl','--user','show-environment'])
    if paths.plugin.exists():
        github_managed=github_managed_plugin(paths,runner)
        if (not paths.receipt.exists() and not bootstrap_owned(paths) and not github_managed) or not (paths.plugin/'.git').is_dir():raise InstallError('A separate OmaMonero installation already exists. It has been preserved.')
        if git(runner,paths.plugin,'status','--porcelain').stdout.strip():raise InstallError('Your plugin contains local changes. They have been preserved.')
        origin=git(runner,paths.plugin,'remote','get-url','origin').stdout.strip()
        if origin!=str(paths.source) and not github_managed:raise InstallError('This plugin is managed by another source. It has been preserved.')
    if paths.source.exists() and git(runner,paths.source,'status','--porcelain').stdout.strip():raise InstallError('The saved release has local changes. They have been preserved.')

@contextmanager
def operation_lock(paths:Paths):
    path=paths.home/'.cache/omamonero-installer.lock'
    reject_symlinks(path)
    path.parent.mkdir(parents=True,exist_ok=True)
    try:fd=os.open(path,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    except OSError as error:raise InstallError('The installer lock could not be opened safely.') from error
    try:
        meta=os.fstat(fd)
        if not stat.S_ISREG(meta.st_mode) or meta.st_uid!=os.geteuid() or stat.S_IMODE(meta.st_mode)!=0o600 or meta.st_nlink!=1:
            raise InstallError('The installer lock has unsafe ownership or permissions.')
        try:fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError as error:raise InstallError('Another OmaMonero install or settings action is already running.') from error
        yield
    finally:os.close(fd)

def serialized(function):
    @wraps(function)
    def wrapped(*args,**kwargs):
        paths=inspect.signature(function).bind(*args,**kwargs).arguments['paths']
        with operation_lock(paths):return function(*args,**kwargs)
    return wrapped

@serialized
def install(bundle:Path,paths:Paths,market_enabled:bool,endpoint:str|None=None,runner:Runner|None=None,market_source:dict|None=None):
    runner=runner or Runner();metadata=verify_bundle(bundle);preflight(paths,runner)
    payload=bundle/'payload'
    external_plugin=github_managed_plugin(paths,runner)
    if external_plugin:
        current=json.loads((paths.plugin/'manifest.json').read_text())
        if current.get('version')!=metadata['version']:
            raise InstallError('The installed plugin and prebuilt backend versions differ. Update the plugin or use a matching release.')
        for name in ('engine.py','control.py','release_fetch.py'):
            helper=paths.plugin/'installer'/name
            reject_symlinks(helper)
            if not helper.is_file():raise InstallError('The Omarchy plugin is missing its native setup helper.')
    runner.run(['omarchy','plugin','validate',payload/'plugin'])
    version=runner.run([payload/'omamonero-core','--version']).stdout.strip()
    if version!='omamonero-core '+metadata['version']:raise InstallError('Bundled binary version mismatch.')
    old_config=paths.config.read_text() if paths.config.exists() else ''
    new_config=configure(old_config,market_enabled,endpoint,market_source)
    # Validate before stopping or changing anything; this command performs no I/O beyond config read.
    with tempfile.TemporaryDirectory(prefix='omamonero-config-') as folder:
        candidate=Path(folder)/'config.toml';candidate.write_text(new_config);candidate.chmod(0o600)
        runner.run([payload/'omamonero-core','--config',candidate,'check-config'])
    was_active=runner.run(['systemctl','--user','is-active','--quiet','omamonero.service'],check=False).returncode==0
    was_enabled=runner.run(['systemctl','--user','is-enabled','--quiet','omamonero.service'],check=False).returncode==0
    source_existed=paths.source.exists();plugin_existed=paths.plugin.exists()
    source_head=git(runner,paths.source,'rev-parse','HEAD').stdout.strip() if source_existed else None
    plugin_head=git(runner,paths.plugin,'rev-parse','HEAD').stdout.strip() if plugin_existed else None
    plugin_listing=json.loads(runner.run(['omarchy','shell','shell','listPlugins']).stdout)
    plugin_was_enabled=any(p.get('id')==PLUGIN_ID and p.get('enabled') for p in plugin_listing)
    runner.run(['systemctl','--user','stop','omamonero.service'],check=False)
    try:
        with FileTransaction() as tx:
            tx.write(paths.binary,(payload/'omamonero-core').read_bytes(),0o755)
            tx.write(paths.config,new_config.encode())
            tx.write(paths.unit,service_unit((payload/'omamonero.service').read_text(),paths.binary,paths.config).encode(),0o644)
            for name in ('engine.py','control.py','release_fetch.py'):
                helper=(paths.plugin/'installer'/name) if external_plugin else (bundle/'installer'/name)
                tx.write(paths.data/'installer'/name,helper.read_bytes(),0o644)
            for legacy in legacy_files(paths):
                if legacy.exists():tx.delete(legacy)
            previous=json.loads(paths.receipt.read_text()) if paths.receipt.exists() else {}
            tx.write(paths.receipt,json.dumps({**previous,'version':metadata['version'],'architecture':metadata['architecture'],'market_enabled':market_enabled,'market_source':(market_source or {}).get('name','Kraken') if market_enabled else None,'marketplace_verified':False,'installed_files':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in (*managed_files(paths),paths.home/'.local/share/applications/omamonero-link.desktop') if p.is_file()}}).encode())
            if not external_plugin:
                paths.source.mkdir(parents=True,exist_ok=True)
                if not source_existed:git(runner,paths.source,'init','--quiet','--template=')
                # Snapshot only plugin files; keep the local Git origin stable across updates.
                for p in list(paths.source.iterdir()):
                    if p.name=='.git':continue
                    if p.is_dir():shutil.rmtree(p)
                    else:p.unlink()
                for p in (payload/'plugin').iterdir():
                    if p.is_dir():shutil.copytree(p,paths.source/p.name)
                    else:shutil.copy2(p,paths.source/p.name)
                git(runner,paths.source,'add','--all')
                git(runner,paths.source,'commit','--quiet','--allow-empty','-m','Install OmaMonero '+metadata['version'])
                if plugin_existed:runner.run(['omarchy','plugin','update',PLUGIN_ID,'--yes'])
                else:runner.run(['omarchy','plugin','add',paths.source,'--yes'])
            deadline=time.monotonic()+8
            while True:
                listing=json.loads(runner.run(['omarchy','shell','shell','listPlugins']).stdout)
                if any(p.get('id')==PLUGIN_ID for p in listing):break
                if time.monotonic()>deadline:raise InstallError('Omarchy did not discover the plugin. Previous settings will be restored.')
                time.sleep(0.1)
            runner.run(['systemctl','--user','daemon-reload'])
            started=int(time.time())
            runner.run(['systemctl','--user','enable','--now','omamonero.service'])
            deadline=time.monotonic()+8
            while True:
                runner.run(['systemctl','--user','is-active','--quiet','omamonero.service'])
                state=runner.run([paths.binary,'status'],check=False)
                try:
                    snapshot=json.loads(state.stdout)
                    ready=snapshot.get('backend_version')==metadata['version'] and snapshot.get('generated_at',0)>=started and snapshot.get('node',{}).get('state') not in (None,'stopped')
                except (ValueError,TypeError):ready=False
                if ready:break
                if time.monotonic()>deadline:raise InstallError('The background service did not publish a fresh status. Previous settings will be restored.')
                time.sleep(0.15)
            if external_plugin:
                if not plugin_was_enabled:runner.run(['omarchy','plugin','enable',PLUGIN_ID])
            else:runner.run(['omarchy','plugin','enable',PLUGIN_ID,'--section','right'])
            tx.commit()
    except BaseException:
        runner.run(['systemctl','--user','stop','omamonero.service'],check=False)
        if plugin_existed:
            if plugin_head and not external_plugin:git(runner,paths.plugin,'reset','--hard',plugin_head,check=False)
            runner.run(['omarchy','plugin','enable' if plugin_was_enabled else 'disable',PLUGIN_ID],check=False)
        elif paths.plugin.exists():runner.run(['omarchy','plugin','remove',PLUGIN_ID,'--yes'],check=False)
        if source_existed and source_head:git(runner,paths.source,'reset','--hard',source_head,check=False)
        elif not source_existed and paths.source.exists():shutil.rmtree(paths.source)
        runner.run(['systemctl','--user','daemon-reload'],check=False)
        runner.run(['systemctl','--user','enable' if was_enabled else 'disable','omamonero.service'],check=False)
        if was_active:runner.run(['systemctl','--user','start','omamonero.service'],check=False)
        raise
    return metadata

@serialized
def settings(paths:Paths,market_enabled:bool,endpoint:str,runner:Runner|None=None,market_source:dict|None=None):
    runner=runner or Runner();preflight(paths,runner)
    text=paths.config.read_text() if paths.config.exists() else ''
    updated=configure(text,market_enabled,endpoint,market_source)
    try:
        with FileTransaction() as tx:
            tx.write(paths.config,updated.encode())
            runner.run([paths.binary,'--config',paths.config,'check-config'])
            runner.run(['systemctl','--user','restart','omamonero.service'])
            runner.run(['systemctl','--user','is-active','--quiet','omamonero.service'])
            receipt=json.loads(paths.receipt.read_text())
            receipt['market_enabled']=market_enabled
            receipt['market_source']=(market_source or {}).get('name','Kraken') if market_enabled else None
            tx.write(paths.receipt,json.dumps(receipt).encode())
            tx.commit()
    except Exception:
        runner.run(['systemctl','--user','restart','omamonero.service'],check=False)
        raise

@serialized
def uninstall(paths:Paths,runner:Runner|None=None):
    runner=runner or Runner();preflight(paths,runner)
    installed=paths.receipt.is_file()
    if not installed and not bootstrap_owned(paths):raise InstallError('No user-only OmaMonero installation was found.')
    if installed:
        # Restore external URL ownership before touching the service. If a
        # desktop database refuses, the still-installed app remains usable and
        # the user can retry without repairing a half-removed setup.
        restore_monero_handler(paths,runner)
        runner.run(['systemctl','--user','disable','--now','omamonero.service'])
    if paths.plugin.exists():runner.run(['omarchy','plugin','remove',PLUGIN_ID,'--yes'])
    for path in (*managed_files(paths),*legacy_files(paths)):
        if installed:path.unlink(missing_ok=True)
    # Source changes were checked before removal; unknown user files are retained.
    if paths.source.exists():shutil.rmtree(paths.source)
    paths.receipt.unlink(missing_ok=True)
    (paths.data/'bootstrap.json').unlink(missing_ok=True)
    pending=paths.data/'pending'
    if pending.exists():
        verify_bundle(pending)
        shutil.rmtree(pending)
    for path in sorted(paths.data.rglob('*'),key=lambda p:len(p.parts),reverse=True):
        if path.is_dir():
            try:path.rmdir()
            except OSError:pass
    try:paths.data.rmdir()
    except OSError:pass
    runner.run(['systemctl','--user','daemon-reload'])


@serialized
def bootstrap(bundle:Path,paths:Paths,runner:Runner|None=None):
    runner=runner or Runner();metadata=verify_bundle(bundle);preflight(paths,runner)
    if github_managed_plugin(paths,runner):
        raise InstallError('This plugin is already managed by Omarchy. Open XMR Settings to install the matching backend.')
    runner.run(['omarchy','plugin','validate',bundle/'payload/plugin'])
    paths.data.mkdir(parents=True,exist_ok=True)
    pending=paths.data/'pending'
    source_existed=paths.source.exists();plugin_existed=paths.plugin.exists()
    source_head=git(runner,paths.source,'rev-parse','HEAD').stdout.strip() if source_existed else None
    plugin_head=git(runner,paths.plugin,'rev-parse','HEAD').stdout.strip() if plugin_existed else None
    listing=json.loads(runner.run(['omarchy','shell','shell','listPlugins']).stdout)
    was_enabled=any(p.get('id')==PLUGIN_ID and p.get('enabled') for p in listing)
    marker=paths.data/'bootstrap.json'
    old_marker=marker.read_bytes() if marker.exists() else None
    old_pending=None
    if pending.exists():
        verify_bundle(pending)
        old_pending=Path(tempfile.mkdtemp(prefix='.pending-backup-',dir=paths.data))
        old_pending.rmdir()
        os.replace(pending,old_pending)
    try:
        shutil.copytree(bundle,pending,ignore=shutil.ignore_patterns('__pycache__'))
        paths.source.mkdir(parents=True,exist_ok=True)
        if not source_existed:git(runner,paths.source,'init','--quiet','--template=')
        for path in list(paths.source.iterdir()):
            if path.name=='.git':continue
            if path.is_dir():shutil.rmtree(path)
            else:path.unlink()
        for path in (pending/'payload/plugin').iterdir():
            if path.is_dir():shutil.copytree(path,paths.source/path.name)
            else:shutil.copy2(path,paths.source/path.name)
        git(runner,paths.source,'add','--all')
        git(runner,paths.source,'commit','--quiet','--allow-empty','-m','Stage native setup '+metadata['version'])
        atomic_write(paths.data/'bootstrap.json',json.dumps({'source':str(paths.source),'version':metadata['version']}).encode(),0o600)
        if plugin_existed:runner.run(['omarchy','plugin','update',PLUGIN_ID,'--yes'])
        else:runner.run(['omarchy','plugin','add',paths.source,'--yes'])
        deadline=time.monotonic()+8
        while True:
            listing=json.loads(runner.run(['omarchy','shell','shell','listPlugins']).stdout)
            if any(p.get('id')==PLUGIN_ID for p in listing):break
            if time.monotonic()>deadline:raise InstallError('Omarchy did not discover the native setup panel.')
            time.sleep(0.1)
        runner.run(['omarchy','plugin','enable',PLUGIN_ID,'--section','right'])
        runner.run(['omarchy','shell','shell','summon',PLUGIN_ID])
    except Exception:
        if source_existed and source_head:git(runner,paths.source,'reset','--hard',source_head,check=False)
        elif not source_existed and paths.source.exists():shutil.rmtree(paths.source)
        if plugin_existed:
            if plugin_head:git(runner,paths.plugin,'reset','--hard',plugin_head,check=False)
            runner.run(['omarchy','plugin','enable' if was_enabled else 'disable',PLUGIN_ID],check=False)
            runner.run(['omarchy','shell','shell','rescanPlugins'],check=False)
        elif paths.plugin.exists():runner.run(['omarchy','plugin','remove',PLUGIN_ID,'--yes'],check=False)
        if pending.exists():shutil.rmtree(pending)
        if old_pending is not None:os.replace(old_pending,pending)
        if old_marker is None:marker.unlink(missing_ok=True)
        else:atomic_write(marker,old_marker,0o600)
        raise
    if old_pending is not None:shutil.rmtree(old_pending)
    return metadata


def restore_monero_handler(paths:Paths,runner:Runner):
    handler=paths.home/'.local/share/applications/omamonero-link.desktop'
    receipt=json.loads(paths.receipt.read_text()) if paths.receipt.exists() else {}
    if not receipt.get('uri_handler_owned'):return
    current=runner.run(['xdg-mime','query','default','x-scheme-handler/monero'],check=False).stdout.strip()
    previous=receipt.get('previous_monero_handler','')
    if current=='omamonero-link.desktop' and previous:
        runner.run(['xdg-mime','default',previous,'x-scheme-handler/monero'])
        restored=runner.run(['xdg-mime','query','default','x-scheme-handler/monero'],check=False).stdout.strip()
        if restored!=previous:raise InstallError('The previous Monero link handler could not be restored; OmaMonero was kept so this can be retried.')
    # Keep file contents/modes available for rollback if the association still
    # points at us or a desktop database refuses the restore.
    candidates={paths.config.parent.parent/'mimeapps.list',paths.home/'.local/share/applications/mimeapps.list'}
    originals={}
    for file in candidates:
        if file.is_file() and not file.is_symlink():
            originals[file]=(file.read_bytes(),stat.S_IMODE(file.stat().st_mode))
    try:
        # Remove only our ID from Monero entries; retain every other association/comment.
        for file,(content,mode) in originals.items():
            lines=[]
            for line in content.decode().splitlines(keepends=True):
                if line.startswith('x-scheme-handler/monero='):
                    values=[v for v in line.split('=',1)[1].strip().split(';') if v and v!='omamonero-link.desktop']
                    if not values:continue
                    line='x-scheme-handler/monero='+';'.join(values)+';\n'
                lines.append(line)
            atomic_write(file,''.join(lines).encode(),mode)
        current=runner.run(['xdg-mime','query','default','x-scheme-handler/monero'],check=False).stdout.strip()
        if current=='omamonero-link.desktop':
            raise InstallError('The Monero link handler is still active; OmaMonero was kept so removal can be retried.')
    except Exception:
        for file,(content,mode) in originals.items():atomic_write(file,content,mode)
        raise
    handler.unlink(missing_ok=True)

@serialized
def register_monero_handler(paths:Paths,runner:Runner|None=None):
    runner=runner or Runner();preflight(paths,runner)
    if not paths.receipt.exists():raise InstallError('Finish installation first.')
    handler=paths.home/'.local/share/applications/omamonero-link.desktop'
    previous=runner.run(['xdg-mime','query','default','x-scheme-handler/monero'],check=False).stdout.strip()
    if previous and not re.fullmatch(r'[A-Za-z0-9._-]+\.desktop',previous):raise InstallError('Existing link-handler name is unsupported; it was preserved.')
    receipt=json.loads(paths.receipt.read_text())
    text='[Desktop Entry]\nType=Application\nName=OmaMonero payment links\nNoDisplay=true\nTerminal=false\nMimeType=x-scheme-handler/monero;\nExec=/usr/bin/python3 '+desktop_quote(paths.data/'installer/control.py')+' open-uri --uri %u\n'
    with FileTransaction() as tx:
        tx.write(handler,text.encode(),0o644)
        if not receipt.get('uri_handler_owned'):receipt['previous_monero_handler']=previous
        receipt['uri_handler_owned']=True
        receipt['installed_files'][str(handler)]=hashlib.sha256(text.encode()).hexdigest()
        tx.write(paths.receipt,json.dumps(receipt).encode())
        runner.run(['xdg-mime','default','omamonero-link.desktop','x-scheme-handler/monero'])
        tx.commit()

@serialized
def module_settings(paths:Paths,values:dict,runner:Runner|None=None):
    runner=runner or Runner();preflight(paths,runner)
    allowed={'wallet_rpc','watch_only_confirmed','notify_payments','xmrig_url','p2pool_directory'}
    if not isinstance(values,dict) or set(values)-allowed:raise InstallError('Invalid module settings.')
    for key,value in values.items():
        if key in ('watch_only_confirmed','notify_payments'):
            if type(value) is not bool:raise InstallError('Confirm watch-only mode explicitly.')
        elif not isinstance(value,str) or len(value)>2048:raise InstallError('Invalid module setting.')
    text=paths.config.read_text() if paths.config.exists() else ''
    text=re.sub(r'(?ms)^\[modules\][^\n]*\n.*?(?=^\[|\Z)','',text)
    body='\n[modules]\n'
    for key,value in values.items():
        if value=='':continue
        body+=key+' = '+('true' if value is True else 'false' if value is False else json.dumps(value))+'\n'
    try:
        with FileTransaction() as tx:
            tx.write(paths.config,(text.rstrip()+body).encode())
            runner.run([paths.binary,'--config',paths.config,'check-config'])
            runner.run(['systemctl','--user','restart','omamonero.service'])
            runner.run(['systemctl','--user','is-active','--quiet','omamonero.service'])
            tx.commit()
    except Exception:
        runner.run(['systemctl','--user','restart','omamonero.service'],check=False)
        raise
