import importlib.util
import json
import hashlib
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'installer'))
import engine
import control

class InstallerTests(unittest.TestCase):
 def make_bundle(self,root):
  folder=root/'bundle';(folder/'payload/plugin/qml').mkdir(parents=True)
  files={'payload/omamonero-core':b'core','payload/plugin/manifest.json':json.dumps({'schemaVersion':1,'id':'io.github.onurbyte.omamonero','version':'0.3.1','entryPoints':{'barWidget':'qml/BarWidget.qml'}}).encode(),'payload/plugin/qml/BarWidget.qml':b'import QtQuick\nItem {}','payload/omamonero.service':b'[Service]\nExecStart=/usr/bin/omamonero-core daemon\n'}
  for name,data in files.items():(folder/name).write_bytes(data)
  (folder/'bundle.json').write_text(json.dumps({'version':'0.3.1','architecture':engine.machine(),'files':{k:hashlib.sha256(v).hexdigest() for k,v in files.items()}}))
  return folder
 def test_integrity_refuses_tampered_or_symlink_payload(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);bundle=self.make_bundle(root);self.assertEqual(engine.verify_bundle(bundle)['version'],'0.3.1')
   (bundle/'payload/omamonero-core').write_bytes(b'changed')
   with self.assertRaises(engine.InstallError):engine.verify_bundle(bundle)
   (bundle/'payload/omamonero-core').unlink();(bundle/'payload/omamonero-core').symlink_to('/bin/true')
   with self.assertRaises(engine.InstallError):engine.verify_bundle(bundle)
 def test_integrity_refuses_traversal_and_unlisted_files(self):
  with tempfile.TemporaryDirectory() as d:
   bundle=self.make_bundle(Path(d));(bundle/'payload/extra').write_text('x')
   with self.assertRaises(engine.InstallError):engine.verify_bundle(bundle)
   (bundle/'payload/extra').unlink();m=json.loads((bundle/'bundle.json').read_text());m['files']['../secret']='0'*64;(bundle/'bundle.json').write_text(json.dumps(m))
   with self.assertRaises(engine.InstallError):engine.verify_bundle(bundle)
 def test_transaction_restores_content_modes_and_new_files(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);old=root/'old';old.write_text('before');old.chmod(0o600)
   try:
    with engine.FileTransaction() as tx:
     tx.write(old,b'after',0o755);tx.write(root/'new',b'new',0o600);raise RuntimeError('fixture')
   except RuntimeError:pass
   self.assertEqual(old.read_text(),'before');self.assertEqual(old.stat().st_mode&0o777,0o600);self.assertFalse((root/'new').exists())
 def test_config_edits_preserve_node_policy_and_enable_only_consented_market(self):
  text='transport = "tor"\nproxy = "socks5h://127.0.0.1:9050"\n# user comment\n'
  result=engine.configure(text,False,None)
  self.assertIn('market_enabled = false',result);self.assertIn('transport = "tor"',result);self.assertIn('# user comment',result)
  self.assertIn('market_enabled = true',engine.configure(result,True,None))

 def test_custom_public_market_source_and_json_pointers_are_saved(self):
  source={'name':'Example Exchange','url':'https://api.example/market.json','price_pointer':'/data/price','points_pointer':'/data/history','timestamp_pointer':'/time','point_price_pointer':'/close','interval_secs':900}
  result=engine.configure('',True,None,source)
  self.assertIn('[market_source]',result)
  self.assertIn('name = "Example Exchange"',result)
  self.assertIn('url = "https://api.example/market.json"',result)
  self.assertIn('points_pointer = "/data/history"',result)
  updated=engine.configure(result,True,None,{**source,'name':'Edited Exchange'})
  self.assertEqual(updated.count('[market_source]'),1)
  self.assertIn('name = "Edited Exchange"',updated)

 def test_custom_market_source_rejects_insecure_or_malformed_configuration(self):
  for changes in (
   {'url':'http://api.example/market.json'},
   {'url':'https://user:pass@api.example/market.json'},
   {'url':'https://api.example/market.json#fragment'},
   {'price_pointer':'price'},
   {'interval_secs':600},
  ):
   source={'name':'Example','url':'https://api.example/data','price_pointer':'/price','points_pointer':'/points','timestamp_pointer':'/timestamp','point_price_pointer':'/price','interval_secs':3600}
   source.update(changes)
   with self.assertRaises(engine.InstallError):engine.configure('',True,None,source)
 def test_installer_never_elevates_or_uses_sudo(self):
  source=(Path(engine.__file__).parent/'control.py').read_text()+Path(engine.__file__).read_text()
  self.assertNotIn('["sudo"',source);self.assertNotIn('["pkexec"',source)
  self.assertIn('get(e)uid',engine.PRIVILEGE_POLICY)
 def test_desktop_arguments_escape_special_paths(self):
  text=engine.desktop_entry(Path('/home/a b/100%/gui.py'))
  self.assertIn('100%%',text);self.assertIn('Terminal=false',text)
 def test_service_path_is_quoted_and_percent_is_literal(self):
  text=engine.service_unit('[Service]\nExecStart=/usr/bin/omamonero-core daemon\n',Path('/home/a b/100%/core'))
  self.assertIn('ExecStart="/home/a b/100%%/core" daemon',text)



class FakeSession(engine.Runner):
 def __init__(self,paths,fail_start=False):self.paths=paths;self.calls=[];self.active=False;self.enabled=False;self.plugin_enabled=False;self.fail_start=fail_start;self.mime_default='';self.fail_mime_default=False
 def run(self,args,check=True,timeout=45):
  import subprocess,time
  args=list(map(str,args));self.calls.append(args)
  def answer(code=0,text=''):
   if check and code:raise engine.InstallError('Fixture failure')
   return subprocess.CompletedProcess(args,code,text,'')
  if args[0]=='git':return super().run(args,check,timeout)
  if args[0]=='xdg-mime':
   if args[1]=='query':return answer(text=self.mime_default+'\n')
   if args[1]=='default':
    if self.fail_mime_default:return answer(1)
    self.mime_default=args[2];return answer()
  if args[0]=='systemctl':
   if 'is-active' in args:return answer(0 if self.active else 3)
   if 'is-enabled' in args:return answer(0 if self.enabled else 1)
   if 'stop' in args:self.active=False
   if 'enable' in args:
    if self.fail_start and '--now' in args:return answer(1)
    self.enabled=True;self.active='--now' in args
   if 'disable' in args:self.enabled=False;self.active=False
   if 'start' in args or 'restart' in args:self.active=True
   return answer()
  if args[:4]==['omarchy','shell','shell','ping']:return answer(text='ok\n')
  if args[:4]==['omarchy','shell','shell','summon']:return answer(text='ok\n')
  if args[:4]==['omarchy','shell','shell','rescanPlugins']:return answer()
  if args[:4]==['omarchy','shell','shell','listPlugins']:
   return answer(text=json.dumps([{'id':engine.PLUGIN_ID,'enabled':self.plugin_enabled}] if self.paths.plugin.exists() else []))
  if args[:3]==['omarchy','plugin','add']:
   self.paths.plugin.parent.mkdir(parents=True,exist_ok=True)
   super().run(['git','clone','--quiet',args[3],self.paths.plugin]);return answer()
  if args[:3]==['omarchy','plugin','update']:
   super().run(['git','-C',self.paths.plugin,'pull','--ff-only','--quiet']);return answer()
  if args[:3]==['omarchy','plugin','enable']:self.plugin_enabled=True;return answer()
  if args[:3]==['omarchy','plugin','disable']:self.plugin_enabled=False;return answer()
  if args[:3]==['omarchy','plugin','remove']:
   import shutil
   shutil.rmtree(self.paths.plugin);self.plugin_enabled=False;return answer()
  if args[:3]==['omarchy','plugin','validate']:return answer()
  if args[-1]=='--version':return answer(text='omamonero-core 0.3.1\n')
  if args[-1]=='check-config':return answer(text='{"valid":true}\n')
  if args[-1]=='status':return answer(2,json.dumps({'backend_version':'0.3.1','generated_at':int(time.time()),'node':{'state':'offline'}}))
  raise AssertionError(args)

class InstallationFlowTests(unittest.TestCase):
 def setUp(self):
  self.tool_patch=patch("engine.shutil.which",return_value="/fixture/tool");self.tool_patch.start();self.addCleanup(self.tool_patch.stop)
 make_bundle=InstallerTests.make_bundle
 def full_bundle(self,root):
  bundle=self.make_bundle(root)
  extra={'installer/engine.py':Path(engine.__file__).read_bytes(),'installer/control.py':(Path(engine.__file__).parent/'control.py').read_bytes()}
  m=json.loads((bundle/'bundle.json').read_text())
  for name,data in extra.items():
   p=bundle/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);m['files'][name]=hashlib.sha256(data).hexdigest()
  (bundle/'bundle.json').write_text(json.dumps(m));return bundle
 def test_complete_install_update_and_remove_preserve_user_config(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);home=root/'home';home.mkdir();paths=engine.Paths(home,home/'.config');bundle=self.full_bundle(root);runner=FakeSession(paths)
   engine.install(bundle,paths,True,runner=runner)
   self.assertTrue(paths.plugin.is_dir());self.assertFalse(paths.desktop.exists());self.assertTrue(runner.active);self.assertTrue(runner.enabled)
   self.assertIn('market_enabled = true',paths.config.read_text());self.assertEqual(paths.binary.stat().st_mode&0o777,0o755)
   self.assertFalse(json.loads(paths.receipt.read_text())['marketplace_verified'])
   engine.install(bundle,paths,False,runner=runner)
   self.assertIn(['omarchy','plugin','update',engine.PLUGIN_ID,'--yes'],runner.calls)
   engine.uninstall(paths,runner=runner)
   self.assertFalse(paths.plugin.exists());self.assertFalse(paths.binary.exists());self.assertFalse(paths.unit.exists());self.assertFalse(runner.active)
   self.assertTrue(paths.config.exists());self.assertIn('market_enabled = false',paths.config.read_text())
 def test_failed_service_start_rolls_back_files_and_plugin(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);home=root/'home';home.mkdir();paths=engine.Paths(home,home/'.config');bundle=self.full_bundle(root);runner=FakeSession(paths,True)
   paths.config.parent.mkdir(parents=True);paths.config.write_text('# untouched\n');paths.config.chmod(0o600)
   with self.assertRaises(engine.InstallError):engine.install(bundle,paths,True,runner=runner)
   self.assertEqual(paths.config.read_text(),'# untouched\n');self.assertFalse(paths.binary.exists());self.assertFalse(paths.plugin.exists());self.assertFalse(paths.unit.exists());self.assertFalse(runner.enabled)
 def test_concurrent_install_actions_are_refused(self):
  with tempfile.TemporaryDirectory() as d:
   paths=engine.Paths(Path(d))
   with engine.operation_lock(paths):
    with self.assertRaises(engine.InstallError):
     with engine.operation_lock(paths):pass

class OwnershipTests(unittest.TestCase):
 def setUp(self):
  self.tool_patch=patch("engine.shutil.which",return_value="/fixture/tool");self.tool_patch.start();self.addCleanup(self.tool_patch.stop)
 def test_unmanaged_service_is_never_overwritten(self):
  with tempfile.TemporaryDirectory() as d:
   home=Path(d);paths=engine.Paths(home,home/'.config');paths.unit.parent.mkdir(parents=True);paths.unit.write_text('MY CUSTOM SERVICE')
   with self.assertRaises(engine.InstallError):engine.preflight(paths,FakeSession(paths))
   self.assertEqual(paths.unit.read_text(),'MY CUSTOM SERVICE')
 def test_custom_xdg_config_home_is_used_for_user_unit(self):
  with tempfile.TemporaryDirectory() as d:
   home=Path(d)/'home';config=Path(d)/'custom config';paths=engine.Paths(home,config)
   self.assertEqual(paths.unit,config/'systemd/user/omamonero.service')

class RetentionTests(unittest.TestCase):
 setUp=InstallationFlowTests.setUp
 make_bundle=InstallerTests.make_bundle
 full_bundle=InstallationFlowTests.full_bundle
 def test_uninstall_preserves_extra_user_data(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);home=root/'home';home.mkdir();paths=engine.Paths(home,home/'.config');bundle=self.full_bundle(root);runner=FakeSession(paths)
   engine.install(bundle,paths,False,runner=runner)
   extra=paths.data/'my-notes.txt';extra.write_text('keep this')
   engine.uninstall(paths,runner=runner)
   self.assertEqual(extra.read_text(),'keep this')


class NativeBootstrapTests(unittest.TestCase):
 setUp=InstallationFlowTests.setUp
 make_bundle=InstallerTests.make_bundle
 full_bundle=InstallationFlowTests.full_bundle
 def test_bootstrap_adds_native_panel_without_starting_backend(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);home=root/'home';home.mkdir();paths=engine.Paths(home,home/'.config');bundle=self.full_bundle(root);runner=FakeSession(paths)
   engine.bootstrap(bundle,paths,runner)
   self.assertTrue(paths.plugin.exists());self.assertTrue(engine.bootstrap_owned(paths));self.assertFalse(paths.binary.exists());self.assertFalse(runner.active)
   self.assertIn(['omarchy','shell','shell','summon',engine.PLUGIN_ID],runner.calls)
   engine.install(paths.data/'pending',paths,True,runner=runner)
   self.assertTrue(paths.binary.exists());self.assertTrue(runner.active)
 def test_only_native_controls_are_shipped(self):
  root=Path(engine.__file__).parent
  self.assertFalse((root/'gui.py').exists())
  for name in ('bootstrap.py','control.py'):
   text=(root/name).read_text()
   self.assertNotIn("['zenity'",text)
   self.assertNotIn('gtk-launch',text)

if __name__=='__main__':unittest.main()

class NativeRecoveryTests(unittest.TestCase):
 setUp=InstallationFlowTests.setUp
 make_bundle=InstallerTests.make_bundle
 full_bundle=InstallationFlowTests.full_bundle
 def test_failed_bootstrap_restores_existing_plugin_source_and_enablement(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);home=root/'home';home.mkdir();paths=engine.Paths(home,home/'.config');bundle=self.full_bundle(root);runner=FakeSession(paths)
   engine.install(bundle,paths,False,runner=runner)
   old_plugin=engine.git(runner,paths.plugin,'rev-parse','HEAD').stdout.strip();old_source=engine.git(runner,paths.source,'rev-parse','HEAD').stdout.strip()
   runner.plugin_enabled=False
   original=runner.run
   def failing(args,check=True,timeout=45):
    if list(map(str,args))[:4]==['omarchy','shell','shell','summon']:raise engine.InstallError('fixture summon failure')
    return original(args,check,timeout)
   runner.run=failing
   with self.assertRaises(engine.InstallError):engine.bootstrap(bundle,paths,runner)
   self.assertEqual(engine.git(runner,paths.plugin,'rev-parse','HEAD').stdout.strip(),old_plugin)
   self.assertEqual(engine.git(runner,paths.source,'rev-parse','HEAD').stdout.strip(),old_source)
   self.assertFalse(runner.plugin_enabled);self.assertFalse((paths.data/'bootstrap.json').exists());self.assertFalse((paths.data/'pending').exists())
 def test_abandoned_running_job_recovers_from_actual_lock_on_info(self):
  import subprocess
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);home=root/'home';home.mkdir();runtime=root/'runtime';runtime.mkdir(mode=0o700);folder=runtime/'omamonero';folder.mkdir(mode=0o700)
   (folder/'setup.json').write_text(json.dumps({'state':'running','action':'save'}));(folder/'setup.json').chmod(0o600)
   env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_RUNTIME_DIR=str(runtime))
   result=subprocess.run([sys.executable,str(Path(engine.__file__).parent/'control.py'),'info'],env=env,capture_output=True,text=True)
   self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(json.loads((folder/'setup.json').read_text())['state'],'done')

class ActiveJobTests(unittest.TestCase):
 def test_info_does_not_interrupt_a_genuinely_locked_job(self):
  import fcntl,subprocess
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);home=root/'home';home.mkdir();runtime=root/'runtime';runtime.mkdir(mode=0o700);folder=runtime/'omamonero';folder.mkdir(mode=0o700)
   state=folder/'setup.json';state.write_text(json.dumps({'state':'running','action':'install'}));state.chmod(0o600)
   fd=os.open(folder/'setup.lock',os.O_CREAT|os.O_RDWR,0o600)
   try:
    fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
    env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_RUNTIME_DIR=str(runtime))
    result=subprocess.run([sys.executable,str(Path(engine.__file__).parent/'control.py'),'info'],env=env,capture_output=True,text=True)
    self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(json.loads(state.read_text())['action'],'install');self.assertEqual(json.loads(state.read_text())['state'],'running')
   finally:os.close(fd)

class PaymentLinkPersistenceTests(unittest.TestCase):
 def test_queue_is_private_bounded_and_keeps_latest_payment_separate(self):
  with tempfile.TemporaryDirectory() as d:
   runtime=Path(d);runtime.chmod(0o700)
   with patch.dict(os.environ,{'XDG_RUNTIME_DIR':str(runtime)}):
    for n in range(21):control.queue_incoming({'uri':f'monero:request-{n}','amount':str(n)})
   folder=runtime/'omamonero';queued=json.loads((folder/'incoming.json').read_text());latest=json.loads((folder/'payment.json').read_text())
   self.assertEqual(len(queued['requests']),20);self.assertEqual(queued['requests'][0]['payment']['amount'],'1')
   self.assertEqual(latest['state'],'ready');self.assertEqual(latest['payment']['amount'],'20')
   self.assertEqual((folder/'incoming.json').stat().st_mode&0o777,0o600)

 def test_monero_link_is_persisted_while_setup_lock_is_busy_and_survives_info(self):
  import fcntl,shutil,subprocess
  address='44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A'
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);home=root/'home';home.mkdir();runtime=root/'runtime';runtime.mkdir(mode=0o700)
   paths=engine.Paths(home,home/'.config');paths.config.parent.mkdir(parents=True);paths.config.write_text('network = "mainnet"\n')
   paths.binary.parent.mkdir(parents=True);shutil.copy2(Path(__file__).resolve().parents[1]/'target/debug/omamonero-core',paths.binary);paths.binary.chmod(0o755)
   fakebin=root/'bin';fakebin.mkdir();omarchy=fakebin/'omarchy';omarchy.write_text('#!/bin/sh\nexit 0\n');omarchy.chmod(0o755)
   folder=runtime/'omamonero';folder.mkdir(mode=0o700);state=folder/'setup.json';state.write_text(json.dumps({'state':'running','action':'install'}));state.chmod(0o600)
   lock=folder/'setup.lock';fd=os.open(lock,os.O_CREAT|os.O_RDWR,0o600);os.fchmod(fd,0o600)
   env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'.config'),XDG_RUNTIME_DIR=str(runtime),PATH=str(fakebin)+os.pathsep+os.environ['PATH'])
   try:
    fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
    uri=f'monero:{address}?tx_amount=1.25'
    result=subprocess.run([sys.executable,str(Path(engine.__file__).parent/'control.py'),'open-uri','--uri',uri],env=env,capture_output=True,text=True)
    self.assertEqual(result.returncode,0,result.stderr)
    self.assertEqual(json.loads(state.read_text()),{'state':'running','action':'install'})
    payment=json.loads((folder/'payment.json').read_text())
    self.assertEqual(payment['state'],'ready');self.assertTrue(payment['payment']['incoming_request']);self.assertEqual(payment['payment']['request_id'],json.loads((folder/'incoming.json').read_text())['requests'][0]['id'])
   finally:
    os.close(fd)
   result=subprocess.run([sys.executable,str(Path(engine.__file__).parent/'control.py'),'info'],env=env,capture_output=True,text=True)
   self.assertEqual(result.returncode,0,result.stderr)
   self.assertEqual(json.loads((folder/'payment.json').read_text()),payment)

class UriHandlerRestoreTests(unittest.TestCase):
 def test_failed_restore_keeps_handler_and_receipt_for_retry(self):
  with tempfile.TemporaryDirectory() as d:
   home=Path(d);paths=engine.Paths(home,home/'.config');paths.receipt.parent.mkdir(parents=True);handler=home/'.local/share/applications/omamonero-link.desktop';handler.parent.mkdir(parents=True);handler.write_text('owned')
   receipt={'uri_handler_owned':True,'previous_monero_handler':'feather.desktop'};paths.receipt.write_text(json.dumps(receipt))
   runner=FakeSession(paths);runner.mime_default='omamonero-link.desktop';runner.fail_mime_default=True
   with self.assertRaises(engine.InstallError):engine.restore_monero_handler(paths,runner)
   self.assertTrue(handler.is_file());self.assertEqual(json.loads(paths.receipt.read_text()),receipt)
   self.assertEqual(runner.mime_default,'omamonero-link.desktop')

 def test_successful_restore_verifies_previous_default_before_deleting_handler(self):
  with tempfile.TemporaryDirectory() as d:
   home=Path(d);paths=engine.Paths(home,home/'.config');paths.receipt.parent.mkdir(parents=True);handler=home/'.local/share/applications/omamonero-link.desktop';handler.parent.mkdir(parents=True);handler.write_text('owned')
   paths.receipt.write_text(json.dumps({'uri_handler_owned':True,'previous_monero_handler':'feather.desktop'}))
   runner=FakeSession(paths);runner.mime_default='omamonero-link.desktop'
   engine.restore_monero_handler(paths,runner)
   self.assertEqual(runner.mime_default,'feather.desktop');self.assertFalse(handler.exists())

 def test_uninstall_restore_failure_keeps_service_plugin_and_retry_receipt(self):
  with tempfile.TemporaryDirectory() as d:
   import subprocess
   home=Path(d);paths=engine.Paths(home,home/'.config');runner=FakeSession(paths)
   paths.config.parent.mkdir(parents=True);paths.config.write_text('market_enabled = false\n')
   for file,data in ((paths.binary,b'core'),(paths.unit,b'[Service]\n'),(paths.data/'installer/engine.py',b'engine'),(paths.data/'installer/control.py',b'control')):
    file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(data)
   paths.source.mkdir(parents=True);engine.git(runner,paths.source,'init','--quiet','--template=');(paths.source/'README').write_text('source');engine.git(runner,paths.source,'add','--all');engine.git(runner,paths.source,'commit','--quiet','-m','fixture')
   runner.run(['omarchy','plugin','add',paths.source,'--yes']);runner.active=True;runner.enabled=True;runner.plugin_enabled=True
   handler=home/'.local/share/applications/omamonero-link.desktop';handler.parent.mkdir(parents=True);handler.write_text('owned')
   files={str(path):hashlib.sha256(path.read_bytes()).hexdigest() for path in (*engine.managed_files(paths),handler)}
   paths.receipt.parent.mkdir(parents=True,exist_ok=True);paths.receipt.write_text(json.dumps({'version':'0.3.1','installed_files':files,'uri_handler_owned':True,'previous_monero_handler':'feather.desktop'}))
   runner.mime_default='omamonero-link.desktop';runner.fail_mime_default=True
   with self.assertRaises(engine.InstallError):engine.uninstall(paths,runner)
   self.assertTrue(runner.active);self.assertTrue(runner.enabled);self.assertTrue(paths.plugin.exists());self.assertTrue(handler.exists());self.assertTrue(paths.receipt.exists())

class ModuleConfigTests(unittest.TestCase):
 def test_top_level_settings_stay_outside_modules_table(self):
  text='endpoint = "http://127.0.0.1:18081"\n[modules]\nwatch_only_confirmed = true\nwallet_rpc = "http://127.0.0.1:18083"\n'
  result=engine.configure(text,True,'http://127.0.0.1:18081')
  import tomllib
  config=tomllib.loads(result)
  self.assertTrue(config['market_enabled']);self.assertNotIn('market_enabled',config['modules']);self.assertTrue(config['modules']['watch_only_confirmed'])
