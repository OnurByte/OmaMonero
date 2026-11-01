import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from runtime_contract import validate_qml_commands, validate_helper_actions

class RuntimeContractTests(unittest.TestCase):
    def test_only_reviewed_launch_shapes_are_allowed(self):
        self.assertEqual(validate_qml_commands('command:["/bin/bash",root.helper,"init"]'),1)
        self.assertEqual(validate_qml_commands('Quickshell.execDetached(["notify-send","-a","OmaMonero","title","message"])'),1)
        for code in ['command:["unreviewed-program"]','command:customCommand','command:["/bin/bash","-c","unreviewed-program"]','Quickshell.execDetached([launcher,"argument"])']:
            with self.assertRaises(AssertionError):validate_qml_commands(code)
    def test_transport_binding_is_only_allowed_at_its_boundary(self):
        with self.assertRaises(AssertionError):validate_qml_commands('worker.command=current.spec.argv')
        self.assertEqual(validate_qml_commands('worker.command=current.spec.argv',http=True),1)
    def test_native_helper_action_set_is_closed(self):
        source='\n'.join(name+')' for name in ['init','p2pool','wallet','register-uri','remove','*'])
        validate_helper_actions(source)
        with self.assertRaises(AssertionError):validate_helper_actions(source+'\nunreviewed-action)')
