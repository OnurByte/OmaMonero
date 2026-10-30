# Developer reference (not the end-user installation flow)

Use the graphical installer described in the root README for end users.

# OmaMonero

A native **Omarchy Quattro** bar widget backed by a separate, read-only Rust
Monero node monitor. Version **0.2.0** monitors node health, synchronization,
network, peers, RPC latency, daemon version and disk figures reported by monerod.

The frontend never launches services or sends RPC requests. One backend publishes
`$XDG_RUNTIME_DIR/omamonero/status.json`; one QML singleton shares it across
monitors. Missing, offline, stopped, stale, malformed and incompatible states
remain visible without bringing down the shell.

## Requirements

- Linux, an active Omarchy Quattro session with its native `qs.Ui` components.
- Rust/Cargo 1.85+ to build (or the separately packaged backend binary).
- A monerod JSON RPC endpoint. Default: `http://127.0.0.1:18081` on mainnet.
- No wallet, keys, elevated privileges, Tor or mining software is required.

## Build and try the backend

From this directory:

```bash
cargo build --release --locked
./target/release/omamonero-core once
./target/release/omamonero-core doctor
./target/release/omamonero-core status
```

`once` polls and publishes; `doctor` reads cached state and separately checks
live RPC without writing or starting anything; `status` reads only the cache.
Exit codes: **0** healthy, **2** unhealthy/offline/missing/stale, **1** setup or
file error. A syncing node counts as reachable/healthy, not fully synchronized.
`daemon` monitors until SIGINT/SIGTERM and publishes `stopped` on clean shutdown.

Omitting a config file uses `$XDG_CONFIG_HOME/omamonero/config.toml`, or
`~/.config/omamonero/config.toml`, if present; otherwise the documented defaults.
An explicitly supplied missing config is an error. Configure a different endpoint:

```bash
install -d -m700 ~/.config/omamonero
install -m600 config.example.toml ~/.config/omamonero/config.toml
# Edit that file, then run doctor. Config changes require a backend restart.
```

`--config /absolute/config.toml` and `--runtime-dir /absolute/private-directory`
are available on all commands. The runtime override names the parent of the
`omamonero` directory. The QML frontend always reads the real `XDG_RUNTIME_DIR`;
use overrides for isolated tests, not an installed frontend.

## Install the backend separately

The source install is entirely user-owned and does not activate the service:

```bash
cargo install --path . --locked --root ~/.local
install -d ~/.config/systemd/user
sed 's|ExecStart=/usr/bin/omamonero-core|ExecStart=%h/.local/bin/omamonero-core|' \
  packaging/omamonero.service > ~/.config/systemd/user/omamonero.service
systemctl --user daemon-reload
```

Start it explicitly when ready:

```bash
systemctl --user enable --now omamonero.service
~/.local/bin/omamonero-core doctor
```

Alternatively, prepare a checksummed local Arch package:

```bash
python3 scripts/package.py
cd dist
makepkg -s
# Review and install the resulting package with your usual package manager.
```

This recipe installs `/usr/bin/omamonero-core` and the user service unit, with no
install hooks. It is an AUR-ready local source recipe, **not a published AUR
package**. Its staged `PKGBUILD` contains the generated source checksum.

## Install the frontend

The root `manifest.json` uses `io.github.onurbyte.omamonero`, declares only
`bar-widget`, and points to `qml/v0_2_0/BarWidget.qml`. The popup is internal to the
widget. There is no separate Quickshell process or `ShellRoot` in the frontend.

If this folder is in a Git repository, use the official manager with that
repository's actual URL or absolute local checkout path:

```bash
omarchy plugin validate /absolute/path/to/OmaMonero
omarchy plugin add /absolute/path/to/OmaMonero --yes --enable
```

`plugin add` requires a Git repository; this delivered source folder may not be
one yet. A standalone frontend archive is also produced by `scripts/package.py`.
Extract it into `~/.config/omarchy/plugins/` (it contains its namespaced root
folder), then let the official manager discover and enable it:

```bash
install -d ~/.config/omarchy/plugins
tar -xzf dist/omamonero-plugin-0.2.0.tar.gz -C ~/.config/omarchy/plugins
omarchy shell shell rescanPlugins
omarchy plugin enable io.github.onurbyte.omamonero --section right
```

Avoid extracting
over a different existing version; use the manager to update a Git installation.

Left click opens the native panel; right click reloads the local snapshot.
Inside the panel, Tab or arrows select reload/close; Enter activates, R reloads,
and Escape dismisses. Reload reads the cache, not a fresh RPC request; the daemon
polls independently. Native theme, scale, panel positioning and popout handling
come from Omarchy. No wallet balance option appears in v0.1.

## Disable, remove, troubleshoot

```bash
omarchy plugin disable io.github.onurbyte.omamonero
omarchy plugin remove io.github.onurbyte.omamonero --yes
```

Frontend removal does not stop or uninstall the backend, erase configuration,
or delete runtime data. Stop the backend separately:

```bash
systemctl --user disable --now omamonero.service
journalctl --user -u omamonero.service -n 50
```

For the user-owned source installation, remove `~/.local/bin/omamonero-core` and
`~/.config/systemd/user/omamonero.service`, then run `systemctl --user daemon-reload`.
For a package installation, remove the backend through the package manager.
Runtime files disappear at logout; a clean stop marks the cache as stopped.
User configuration is retained for the user to remove explicitly.

If the widget says “Backend not installed / inactive”, install/start the backend
or run `doctor`. A missing file alone cannot distinguish an uninstalled binary
from an inactive service. API mismatch means the frontend and backend need
matching updates. Stale means no valid heartbeat arrived within the advertised
window. A current offline snapshot deliberately contains no old metrics.

## v0.1 node-only privacy scope (historical)

The initial v0.1 backend called only read-only `get_info`. Release 0.3.1 adds
separate, opt-in watch-only wallet/mining adapters; no private key storage or
spending operation is included. The node backend still opens no listener and
QML still owns no subprocess.
`status.json` and the daemon lock are 0600 inside a 0700, owner-checked runtime
directory. Atomic replacement prevents partial JSON; unsafe paths are refused.
Config parse errors, request failures and RPC errors omit endpoints, proxy URLs,
credentials and response bodies from logs and status.

`local` permits numeric loopback endpoints only. `direct` is an explicit opt-in
to remote RPC and requires HTTPS for non-loopback endpoints. `tor` and `i2p`
require a loopback `socks5h://` proxy configured separately. Remote DNS is sent
over SOCKS; redirects and environment proxies are disabled, and there is no
direct retry on proxy failure. An I2P SOCKS tunnel must be supplied by the user;
an I2P HTTP proxy is not supported in v0.1. These policies cover **RPC transport
only**. They do not verify the node's P2P routing or make self-reported node data
trustworthy; the panel always says P2P privacy is unverified.

## Checks and scope

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace --locked
node --test tests/status.test.cjs
python3 scripts/check-contract.py
omarchy plugin validate .
python3 scripts/lint-qml.py
python3 scripts/test-qml-runtime.py
```

The last two need installed Omarchy; runtime tests need an active Wayland
session. The test harness creates an isolated, non-visual test engine, **not** a
second desktop shell; it does not alter the user's shell or start services.

See [verification](verification.md) for actual evidence and remaining
interactive checks, and [architecture](architecture.md) for the snapshot
contract. CI checks locked builds, formatting, lints, Rust/JS tests, official
manifest validation, versions, dependency review/audit and deterministic builds.
The optional Omarchy session workflow runs native QML checks on a matching host.

The early v0.1/v0.2 roadmap notes above are historical. Release 0.3.1 includes
local receive QR/payment links, a bounded watch-only payment view and proof
checks, plus optional read-only XMRig/P2Pool status. See
[the current release evidence](verification-0.3.1.md) for exact limits; no
private keys or spending operations are used.

Reference contracts: [Omarchy shell](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md),
[Omarchy shell development](https://github.com/omacom/omarchy/blob/quattro/agents/skills/shell-dev.md),
[monerod RPC](https://docs.getmonero.org/rpc-library/monerod-rpc/).
