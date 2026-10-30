# OmaMonero End-user Release Plan

**Goal:** Clickable user-only installer and USD/24h price sparkline in the native bar.
**Authority:** PRODUCT_REQUIREMENTS.md, user confirmation of USD/24h, earlier instruction to finish without further process gates.
**Architecture:** Bundle a prebuilt Rust binary, frontend snapshot, a Python/Zenity GUI and checksums. Install inside the user's home and enable the user service only after an explicit graphical Install action. Keep the frontend under the official Omarchy manager. Add opt-in market polling to the single backend; render graphs from its snapshot in QML.

## Decisions
- Prefer a user-only install: no sudo, no pkexec needed in the normal path. Any
  future privileged dependency step must be a single narrow pkexec invocation.
- Zenity is present in the target Omarchy installation. Preflight missing tools
  graphically rather than invoking an automatic package manager as root.
- Market source: Kraken public OHLC, XMR/USD, hourly samples. Compute trailing
  24-hour change with a linearly interpolated 24-hour anchor and label the
  source and sampling explicitly. No global-market average claim.
- Price sharing is opt-in in the installer; no network requests by a default
  source install. Market requests use the selected Tor/I2P proxy or explicit
  direct HTTPS, never node credentials. Independent 120s schedule and stale/error
  state; no RPC request per monitor.
- Verification is local checks and integrity, not an official Verified badge.

## Tasks
- [x] Test and implement bounded market parsing, USD change, invalid/stale data,
  opt-in and proxy handling; preserve old snapshot compatibility.
- [x] Test and implement small native Canvas sparkline and full panel chart,
  including independent market state when the local node is offline.
- [x] Test and implement non-root installer preflight, payload hashes, official
  plugin lifecycle, transactional file/service rollback, GUI consent, desktop
  entry and no-command end-user bundle.
- [x] Build 0.2.0, verify Rust/JS/Python/native QML, exercise installation in an
  isolated home, inspect GUI and actual native panel, audit and document limits.
- [x] Update README, release artifacts and verification evidence. Keep local
  validation distinct from marketplace approval; prepare publication checklist.

User correction implemented: no Zenity/GTK/desktop settings app. Native-only bootstrap, setup/management pages, detached private job state and supplied SVG branding, red/green trends, windowless tests. See verification-0.2.2.md for evidence and the explicit marketplace-verification limit.
