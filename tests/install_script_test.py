import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "install.sh"
README = ROOT / "README.md"
INSTALL_COMMAND = "omarchy plugin add https://github.com/OnurByte/OmaMonero.git --enable"


class RetiredBootstrapTests(unittest.TestCase):
    def test_standalone_bootstrap_fails_closed_without_downloading_or_executing(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            bin_dir = folder / "bin"
            bin_dir.mkdir()
            marker = folder / "called-external-command"

            # Any reintroduced old installer would trip this test before reaching
            # a network operation, archive extraction, or downloaded executable.
            for name in ("curl", "wget", "python3", "sha256sum", "tar", "find"):
                tool = bin_dir / name
                tool.write_text(
                    "#!/bin/sh\n"
                    "printf '%s\\n' invoked >> \"$OMAMONERO_TEST_MARKER\"\n"
                    "exit 99\n"
                )
                tool.chmod(0o755)

            result = subprocess.run(
                ["/bin/bash", str(INSTALLER)],
                cwd=folder,
                env=dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}",
                         OMAMONERO_TEST_MARKER=str(marker)),
                capture_output=True,
                text=True,
                timeout=15,
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("disabled for privacy reasons", result.stderr)
            self.assertIn(INSTALL_COMMAND, result.stderr)
            self.assertFalse(marker.exists(), "Retired bootstrap invoked an external command.")

    def test_legacy_installer_contains_no_release_execution_path(self):
        source = INSTALLER.read_text()
        for obsolete in ("RELEASE_TAG=", "EXPECTED_SHA256=", "releases/download/",
                         "releases/latest/download", "curl ", "wget ", "python3 "):
            self.assertNotIn(obsolete, source)
        self.assertIn("exit 1", source)
        subprocess.run(["bash", "-n", str(INSTALLER)], check=True)

    def test_readme_documents_only_current_omarchy_install_command(self):
        text = README.read_text()
        self.assertIn(INSTALL_COMMAND, text)
        self.assertIn("old standalone `install.sh`", text)
        self.assertNotIn("curl -fsSL", text)
        self.assertNotIn("bash -euo pipefail -c", text)
        self.assertLess(len(text.splitlines()), 65)


if __name__ == "__main__":
    unittest.main()
