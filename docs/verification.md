> Historical record, superseded by the native-only 0.2.2 release. Correction: the initial Item-root test harness could create a white floating window; the current QtObject-root harness is verified windowless. Do not use the removed Zenity/desktop-settings candidate.

# Verification record — 2026-10-30

## Passed locally

Environment: Linux x86_64, Omarchy **4.0.6-1**, Qt **6.12.0**, Rust/Cargo
**1.99.1**. The live session has one eDP-1 display at 1920×1200 and scale 1.5.

- `cargo test --workspace --locked`: **14 integration tests passed**. Tests use
  real local HTTP fixtures and subprocesses of the actual binary, not mocked
  client methods. Coverage: healthy node/permissions, loss of a previously healthy
  node, busy/invalid/slow/oversized/HTTP error responses, JSON-RPC identity,
  network mismatch, config validation/redaction, no direct proxy fallback,
  missing explicit config, unknown sync target, untrusted bootstrap status,
  read-only/stale cache handling, unsafe runtime paths, competing writers and
  clean SIGTERM shutdown.
- `cargo fmt --all -- --check` and `cargo clippy --workspace --all-targets --locked
  -- -D warnings`: passed using the distribution's `/usr/bin/cargo-fmt` and
  `/usr/bin/cargo-clippy`. A separate pre-existing rustup installation lacks
  these components, so Cargo's normal subcommand discovery was bypassed locally.
- `node --test tests/status.test.cjs`: **5 tests passed**, covering missing,
  malformed, incompatible, future, stale, bad nested fields, offline/stopped,
  healthy and syncing snapshots.
- `python3 scripts/check-contract.py`: manifest, Cargo manifest, Cargo lock and
  package version agree at **0.1.0**; frontend has no ShellRoot or Process.
- `omarchy plugin validate .`: passed against the installed official validator.
- `python3 scripts/lint-qml.py`: passed with **no diagnostics**. The script
  stages native qs imports because standalone qmllint does not resolve
  Quickshell's virtual `qs.*` prefix directly.
- `python3 scripts/test-qml-runtime.py`: passed in an isolated, non-visual
  Quickshell test engine against the installed native UI kit. It instantiates
  the actual widget/panel, then exercises late directory/file creation, **21
  atomic replacements**, observation of at least five distinct updates, corrupt
  JSON and deletion. The shared five-second recovery path is present for missed
  watches. No production shell configuration is modified by this harness.
- `cargo build --release --locked`: passed; executable at
  `target/release/omamonero-core`.
- `systemd-analyze --user verify`: passed with the service's executable path
  replaced by that staged release binary. The distributed `/usr/bin` path is
  resolved only when the backend package is installed; no service was activated.
- `makepkg --verifysource --noconfirm` in `dist`: generated source checksum passed.
- Two consecutive source/frontend archive generations also produced identical
  checksums; archive timestamps, ownership and modes are normalized.
- `cargo audit --deny warnings` (cargo-audit 0.22.2): **passed**, scanning **179
  locked dependencies** against **1,395 RustSec advisories**; no vulnerability
  or warning reported. Advisory database revision:
  `2295466c4e9df26647fd67d8fa1c705ac2fc7f81`.
- Two independent release target directories produced byte-identical binaries:
  SHA-256 `e1bda3053001d4903dcdf889bad47f15981f8c4cf48f7ecdb162eb5685b0786e`.
  This was tested with the same source and compiler on this host.

## Real Omarchy plugin lifecycle

The frontend was staged in a temporary local Git repository and installed using
`omarchy plugin add <local-repo> --yes --enable`. The running Omarchy shell
reported the correct third-party ID and `enabled: true`.

The native popup was summoned through shell IPC and visually inspected. It
showed the honest “Backend not installed / inactive” state, diagnostics guidance,
and unverified P2P status. Escape dismissed it. Tab/Enter were exercised on the
two native actions. Shell summon/hide and toggle returned successfully.

The official disable, enable and remove commands all succeeded. The shell
responded to `ping` afterward. Both `~/.config/omarchy/shell.json` and
`~/.config/omarchy/shell.toml` were byte-identical to their pre-test contents, and
the temporary plugin installation was removed. The backend was not installed or
activated as a system service, and no user configuration or node data was erased.

The host logged its existing third-party-module scanner warning and duplicate
IPC warnings from other installed plugins during registry reload. No OmaMonero
load failure, binding loop or recursive layout warning appeared in that live
session. The isolated harness emits native Quickshell/Omarchy initialization and
shutdown warnings (including deprecated floating-window sizing and singleton
teardown bindings); these are recorded as host warnings, not claimed to be a
warning-free full desktop session.

## Independent review

A separate reviewer inspected the Rust/QML implementation against the design and
installed native interfaces and independently reran the Rust and JS tests. No
critical or important implementation finding was identified. Locked dependency
metadata reports no MSRV above the declared Rust 1.85, but a build on Rust 1.85
itself was not run.

## Boundaries still requiring broader acceptance testing

- No running production monerod was available for end-to-end telemetry; the
  documented JSON-RPC contract is exercised against controlled HTTP fixtures.
- Multiple monitors, additional display scales, theme switching, suspend/resume,
  and full shell restart were not exercised on the user's desktop. No such
  desktop changes are performed automatically for testing.
- Tor/I2P route verification, real proxy integration and node P2P privacy are
  outside v0.1; only the RPC proxy policy and failure behavior are tested.
- CI workflows are supplied but have not run on GitHub; no repository was
  published, AUR package submitted, or release uploaded.
- Binary reproducibility is defined for identical source, toolchain, target and
  build environment; it does not claim identical output across compiler versions.
