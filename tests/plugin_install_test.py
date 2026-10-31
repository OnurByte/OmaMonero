"""Native Omarchy plugin-manager first-run installation tests."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "installer"))
import engine


class PluginManagedInstallTests(unittest.TestCase):
    def test_official_github_clone_is_an_accepted_install_source(self):
        with tempfile.TemporaryDirectory() as location:
            home = Path(location) / "home"
            home.mkdir()
            paths = engine.Paths(home)
            paths.plugin.mkdir(parents=True)
            runner = engine.Runner()
            engine.git(runner, paths.plugin, "init", "--quiet", "--template=")
            engine.git(runner, paths.plugin, "remote", "add", "origin", "https://github.com/OnurByte/OmaMonero.git")
            (paths.plugin / "manifest.json").write_text(json.dumps({"schemaVersion": 1, "id": engine.PLUGIN_ID, "version": "0.3.6"}))
            engine.git(runner, paths.plugin, "add", "--all")
            engine.git(runner, paths.plugin, "commit", "--quiet", "-m", "fixture")

            class Session(engine.Runner):
                def run(self, args, check=True, timeout=45):
                    if list(args)[:4] == ["omarchy", "shell", "shell", "ping"]:
                        from subprocess import CompletedProcess
                        return CompletedProcess(args, 0, "ok\n", "")
                    if list(args)[:3] == ["systemctl", "--user", "show-environment"]:
                        from subprocess import CompletedProcess
                        return CompletedProcess(args, 0, "", "")
                    return super().run(args, check, timeout)

            with patch("engine.shutil.which", return_value="/fixture/tool"), patch("engine.os.geteuid", return_value=1000), patch("engine.reject_symlinks"):
                engine.preflight(paths, Session())


if __name__ == "__main__":
    unittest.main()
