import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
FRONT=ROOT/'qml/v0_4_3'
class NativeTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.base=Path(self.tmp.name);self.home=self.base/'home';self.home.mkdir();self.runtime=self.base/'runtime';self.runtime.mkdir(mode=0o700);self.bin=self.base/'bin';self.bin.mkdir()
        self.env=dict(os.environ,HOME=str(self.home),XDG_CONFIG_HOME=str(self.home/'.config'),XDG_DATA_HOME=str(self.home/'.local/share'),XDG_RUNTIME_DIR=str(self.runtime),PATH=str(self.bin)+':/usr/bin:/bin',TEST_ROOT=str(self.base),BASH_ENV=str(ROOT/'tests/fixtures/command-allowlist.sh'))
        self.stub('xdg-mime','''case "$1 $2" in
"query default") cat "$TEST_ROOT/default" 2>/dev/null || true ;;
"default "*) [[ ! -f "$TEST_ROOT/fail-restore" || $2 == omamonero-native-uri.desktop ]] || exit 1; printf '%s' "$2" > "$TEST_ROOT/default" ;;
esac''')
        self.stub('omarchy','printf "%s\\n" "$*" >> "$TEST_ROOT/manager"')
        self.stub('notify-send','printf "%s\\n" "$*" >> "$TEST_ROOT/notifications"')
    def tearDown(self):self.tmp.cleanup()
    def stub(self,name,body):
        p=self.bin/name;p.write_text('#!/bin/bash\nset -e\n'+body+'\n');p.chmod(0o700)
    def run_action(self,action,*args):return subprocess.run(['bash',str(FRONT/'native.sh'),action,*args],env=self.env,capture_output=True,text=True)
    @property
    def data(self):return self.home/'.local/share/omamonero/native'
    def register(self):
        (self.base/'default').write_text('old-wallet.desktop')
        self.assertEqual(self.run_action('register-uri').returncode,0)
    def test_restore_failure_keeps_handler_and_receipt_and_does_not_remove_plugin(self):
        self.register();(self.base/'fail-restore').touch()
        self.assertNotEqual(self.run_action('remove').returncode,0)
        self.assertTrue((self.data/'uri-handler.sh').exists());self.assertTrue((self.data/'uri-owned').exists());self.assertFalse((self.base/'manager').exists())
        state=json.loads((self.runtime/'omamonero-native/native-job.json').read_text());self.assertEqual(state['state'],'error')
    def test_remove_restores_and_verifies_then_uses_official_manager(self):
        self.register();self.assertEqual(self.run_action('remove').returncode,0)
        self.assertEqual((self.base/'default').read_text(),'old-wallet.desktop');self.assertFalse((self.data/'uri-owned').exists());self.assertIn('plugin remove io.github.onurbyte.omamonero --yes',(self.base/'manager').read_text())
    def test_retired_service_cleanup_is_not_an_available_action(self):
        self.assertEqual(self.run_action('init').returncode,0);self.assertNotEqual(self.run_action('legacy-cleanup').returncode,0)
    def test_command_allowlist_rejects_unreviewed_builtins(self):
        for tail in [':','OMA_TEST=1 :','exec :']:
            helper=self.base/'helper.sh';helper.write_text((FRONT/'native.sh').read_text()+'\n'+tail+'\n')
            result=subprocess.run(['bash',str(helper),'init'],env=self.env,capture_output=True,text=True)
            self.assertEqual(result.returncode,97)
            self.assertIn('Unreviewed command',result.stderr)
    def test_wallet_choices_launch_only_the_selected_program_without_payment_arguments(self):
        for choice,program in [('feather','feather'),('monero_gui','monero-wallet-gui')]:
            self.stub(program,'printf "wallet:%s" "$*"')
            result=self.run_action('wallet',choice,'monero:PRIVATE_ADDRESS')
            self.assertEqual(result.returncode,0)
            self.assertEqual(result.stdout,'wallet:')
    def test_uri_inbox_is_bounded_private_and_never_forwarded_to_notifications(self):
        for i in range(23):subprocess.run(['bash',str(FRONT/'uri-handler.sh'),f'monero:PRIVATE_ADDRESS?tx_amount={i+1}'],env=self.env,check=True)
        inbox=self.runtime/'omamonero-native/inbox';self.assertEqual(len(inbox.read_text().splitlines()),20);self.assertEqual(inbox.stat().st_mode&0o077,0);self.assertNotIn('PRIVATE_ADDRESS',(self.base/'notifications').read_text())
    def test_p2pool_refuses_final_symlinks_and_oversize(self):
        pool=self.base/'pool/local';pool.mkdir(parents=True);target=self.base/'secret';target.write_text('{}');(pool/'stratum').symlink_to(target)
        self.assertNotEqual(self.run_action('p2pool',str(pool.parent)).returncode,0)
        (pool/'stratum').unlink();(pool/'stratum').write_bytes(b'x'*524289)
        self.assertNotEqual(self.run_action('p2pool',str(pool.parent)).returncode,0)
    def test_symlink_private_directory_is_rejected(self):
        (self.runtime/'omamonero-native').symlink_to(self.home,target_is_directory=True);self.assertNotEqual(self.run_action('init').returncode,0)
