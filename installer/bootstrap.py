#!/usr/bin/env python3
"""Open setup inside the running Omarchy bar; never opens a separate GUI toolkit."""
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
import engine
if __name__=='__main__':
    try:engine.bootstrap(Path(__file__).resolve().parent.parent,engine.Paths(Path.home()))
    except Exception as error:
        text=str(error) if isinstance(error,engine.InstallError) else 'The native setup panel could not be opened. Existing settings were preserved.'
        # Existing Omarchy notification service renders this; no GNOME dialog.
        subprocess.run(['notify-send','OmaMonero',text],check=False)
        raise SystemExit(1)
