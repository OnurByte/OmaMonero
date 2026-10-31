import hashlib
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "install.sh"
README = ROOT / "README.md"
ASSET = "omamonero-linux-x86_64.tar.gz"
RELEASE_TAG = "v0.3.2"
RELEASE_DIGEST = "b1ea936ff1a0edb254f615f2dc02d3fb9ac61722e40c7a053100d87dba3fff3b"


class PinnedInstallerTests(unittest.TestCase):
    def make_fixture(self, folder: Path, tamper_archive: bool = False):
        bundle = folder / "omamonero-0.3.2-linux-x86_64"
        bundle.mkdir()
        launcher = bundle / "Install OmaMonero"
        launcher.write_text(
            "#!/usr/bin/python3\n"
            "import os\n"
            "from pathlib import Path\n"
            "Path(os.environ['OMAMONERO_TEST_MARKER']).write_text('opened')\n"
        )
        launcher.chmod(0o755)
        (bundle / "bundle.json").write_text('{"version":"0.3.2"}\n')
        archive = folder / ASSET
        with tarfile.open(archive, "w:gz") as output:
            output.add(launcher, arcname=f"{bundle.name}/{launcher.name}")
            output.add(bundle / "bundle.json", arcname=f"{bundle.name}/bundle.json")
        expected_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        if tamper_archive:
            with archive.open("ab") as output:
                output.write(b"malicious changes after digest approval")

        bin_dir = folder / "bin"
        bin_dir.mkdir()
        curl = bin_dir / "curl"
        curl.write_text(
            "#!/usr/bin/python3\n"
            "import shutil,sys\n"
            "from pathlib import Path\n"
            "a=sys.argv; out=Path(a[a.index('--output')+1]); url=a[-1]\n"
            f"expected='https://github.com/OnurByte/OmaMonero/releases/download/{RELEASE_TAG}/{ASSET}'\n"
            "if url!=expected: raise SystemExit('unexpected or moving release URL: '+url)\n"
            f"shutil.copyfile(Path(__file__).parent.parent/'{ASSET}',out)\n"
        )
        curl.chmod(0o755)
        return bin_dir, expected_digest

    def run_installer(self, folder: Path, tamper_archive: bool = False):
        bin_dir, digest = self.make_fixture(folder, tamper_archive)
        source = INSTALLER.read_text()
        pinned = f'EXPECTED_SHA256="{RELEASE_DIGEST}"'
        self.assertIn(pinned, source)
        test_script = folder / "install-under-test.sh"
        test_script.write_text(source.replace(pinned, f'EXPECTED_SHA256="{digest}"'))
        home = folder / "home"
        home.mkdir()
        marker = folder / "launched"
        env = dict(
            os.environ,
            HOME=str(home),
            OMAMONERO_TEST_MARKER=str(marker),
            PATH=f"{bin_dir}:{os.environ['PATH']}",
        )
        result = subprocess.run(
            ["bash", str(test_script)], cwd=folder, env=env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15,
        )
        return result, marker

    def test_pinned_archive_verifies_then_opens_native_installer(self):
        with tempfile.TemporaryDirectory() as temp:
            result, marker = self.run_installer(Path(temp))
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(marker.read_text(), "opened")

    def test_tampered_archive_cannot_execute_companion(self):
        with tempfile.TemporaryDirectory() as temp:
            result, marker = self.run_installer(Path(temp), tamper_archive=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("pinned release digest did not match", result.stdout)
            self.assertFalse(marker.exists())

    def test_release_is_pinned_and_no_remote_checksum_is_trusted(self):
        source = INSTALLER.read_text()
        self.assertIn(f'RELEASE_TAG="{RELEASE_TAG}"', source)
        self.assertIn(f'EXPECTED_SHA256="{RELEASE_DIGEST}"', source)
        self.assertNotIn("releases/latest/download", source)
        self.assertNotIn('$ASSET.sha256', source)
        subprocess.run(["bash", "-n", str(INSTALLER)], check=True)

    def test_readme_verifies_bootstrap_before_execution(self):
        text = README.read_text()
        digest = hashlib.sha256(INSTALLER.read_bytes()).hexdigest()
        self.assertIn(digest, text)
        self.assertNotIn("curl -fsSL https://raw.githubusercontent.com/OnurByte/OmaMonero/main/install.sh | bash", text)
        self.assertIn("sha256sum --check --status", text)
        self.assertLess(text.index("sha256sum --check --status"), text.index('bash "$installer"'))
        # The user-facing one-liner must remain a complete, parseable shell command.
        import re
        match = re.search(r"```bash\n(bash -euo pipefail -c [^\n]+)\n```", text)
        self.assertIsNotNone(match, "One-line setup command is missing")
        subprocess.run(["bash", "-n", "-c", match.group(1)], check=True)


if __name__ == "__main__":
    unittest.main()
