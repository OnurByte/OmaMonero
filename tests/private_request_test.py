import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'installer'))
import control
import engine


class PrivateRequestTests(unittest.TestCase):
    REQUEST_ID = 'a' * 32

    def make_request(self, runtime, content=None, mode=0o600):
        data = content if content is not None else {
            'endpoint': 'http://127.0.0.1:18081',
            'market_enabled': False,
            'payload': {'address': 'private-address', 'label': 'private-label',
                        'amount': '1.25', 'message': 'private-proof-message'},
        }
        path = runtime / ('omamonero-request-' + self.REQUEST_ID + '.json')
        path.write_text(json.dumps(data))
        path.chmod(mode)
        return path

    def test_sensitive_data_is_consumed_without_argv_and_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(runtime)}):
                path = self.make_request(runtime, mode=0o644)
                request = control.take_request(self.REQUEST_ID)
                self.assertEqual(request['payload']['label'], 'private-label')
                self.assertEqual(request['payload']['message'], 'private-proof-message')
                self.assertFalse(path.exists())
                with self.assertRaisesRegex(engine.InstallError, 'unavailable'):
                    control.take_request(self.REQUEST_ID)

    def test_rejects_traversal_and_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            target = runtime / 'target'
            target.write_text('do not read')
            link = runtime / ('omamonero-request-' + self.REQUEST_ID + '.json')
            link.symlink_to(target)
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(runtime)}):
                for identifier in ('../target', '/tmp/target', 'not-a-hash'):
                    with self.assertRaisesRegex(engine.InstallError, 'identifier'):
                        control.take_request(identifier)
                with self.assertRaisesRegex(engine.InstallError, 'unavailable'):
                    control.take_request(self.REQUEST_ID)
            self.assertEqual(target.read_text(), 'do not read')

    def test_rejects_unsafe_mode_and_hardlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(runtime)}):
                path = self.make_request(runtime, mode=0o666)
                with self.assertRaisesRegex(engine.InstallError, 'Unsafe'):
                    control.take_request(self.REQUEST_ID)
                path.unlink()
                target = runtime / 'linked-data'
                target.write_text('{}')
                os.link(target,path)
                with self.assertRaisesRegex(engine.InstallError, 'Unsafe'):
                    control.take_request(self.REQUEST_ID)

    def test_rejects_oversized_or_malformed_requests(self):
        with tempfile.TemporaryDirectory() as directory:
            runtime = Path(directory)
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(runtime)}):
                path = self.make_request(runtime)
                path.write_bytes(b'x' * (control.MAX_REQUEST_BYTES + 1))
                with self.assertRaisesRegex(engine.InstallError, 'too large'):
                    control.take_request(self.REQUEST_ID)
                self.assertFalse(path.exists())
                path = self.make_request(runtime, {'endpoint': None, 'market_enabled': False,
                                                   'payload': 'not an object'})
                with self.assertRaisesRegex(engine.InstallError, 'Invalid'):
                    control.take_request(self.REQUEST_ID)
                self.assertFalse(path.exists())

    def test_panel_never_places_sensitive_payload_in_process_arguments(self):
        panel = (Path(__file__).resolve().parents[1] /
                 'qml/v0_3_6/StatusStore.qml').read_text()
        helper = (Path(__file__).resolve().parents[1] /
                  'installer/control.py').read_text()
        self.assertNotIn('--payload', panel)
        self.assertNotIn('--payload', helper)
        self.assertIn('requestFile.setText(request)', panel)
        self.assertIn('"--request-id", id', panel)
        self.assertTrue({'receive', 'preview-uri', 'proof'} <= control.PRIVATE_ACTIONS)


if __name__ == '__main__':
    unittest.main()
