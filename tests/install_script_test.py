import hashlib
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "install.sh"
ASSET = "omamonero-linux-x86_64.tar.gz"


class SingleCommandInstallerTests(unittest.TestCase):
    def make_fixture(self, folder: Path, tamper_checksum: bool = False):
        bundle = folder / "omamonero-0.3.6-linux-x86_64"
        bundle.mkdir()
        install = bundle / "Install OmaMonero"
        install.write_text(
            "#!/usr/bin/python3\n"
            "import os\n"
            "from pathlib import Path\n"
            "Path(os.environ['OMAMONERO_TEST_MARKER']).write_text('opened')\n"
        )
        install.chmod(0o755)
        (bundle / "bundle.json").write_text('{"version":"0.3.6"}\n')
        archive = folder / ASSET
        with tarfile.open(archive, "w:gz") as output:
            output.add(install, arcname=f"{bundle.name}/{install.name}")
            output.add(bundle / "bundle.json", arcname=f"{bundle.name}/bundle.json")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        checksum = folder / f"{ASSET}.sha256"
        if tamper_checksum:
            digest = "0" * 64
        checksum.write_text(f"{digest}  {ASSET}\n")

        bin_dir = folder / "bin"
        bin_dir.mkdir()
        curl = bin_dir / "curl"
        curl.write_text(
            "#!/usr/bin/python3\n"
            "import shutil,sys\n"
            "from pathlib import Path\n"
            "a=sys.argv; i=a.index('--output') if '--output' in a else a.index('-o'); out=Path(a[i+1]); url=a[-1]\n"
            "src=Path(__file__).parent.parent/(" 
            "'omamonero-linux-x86_64.tar.gz.sha256' if url.endswith('.sha256') "
            "else 'omamonero-linux-x86_64.tar.gz')\n"
            "shutil.copyfile(src,out)\n"
        )
        curl.chmod(0o755)
        return bin_dir

    def run_installer(self, folder: Path, tamper_checksum: bool = False):
        bin_dir = self.make_fixture(folder, tamper_checksum)
        home = folder / "home"
        home.mkdir()
        marker = folder / "launched"
        env = dict(
            os.environ,
            HOME=str(home),
            OMAMONERO_TEST_MARKER=str(marker),
            PATH=f"{bin_dir}:{os.environ['PATH']}",
        )
        return subprocess.run(
            ["bash", str(INSTALLER)], cwd=folder, env=env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=15,
        ), marker

    def test_one_command_downloads_verifies_extracts_and_opens_native_installer(self):
        with tempfile.TemporaryDirectory() as temp:
            result, marker = self.run_installer(Path(temp))
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(marker.read_text(), "opened")

    def test_bad_release_checksum_stops_before_opening_installer(self):
        with tempfile.TemporaryDirectory() as temp:
            result, marker = self.run_installer(Path(temp), tamper_checksum=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
