# Native end-user candidate 0.3.1 — 2026-10-30

This record covers the locally built x86_64 bundle installed in the current
Omarchy 4.0.6-1 session. It is evidence of local compatibility checks; it is not
an official Omarchy marketplace verification or security certification.

## Shipped behavior

- A click-ready widget lives in the existing Omarchy top bar. It uses the
  supplied orange Monero artwork, keeps the `XMR` label white, and colors the
  price, percentage and chart red on a decline and green at zero or above.
- The existing `qs.Ui` panel contains a 6/12/24-hour chart, range high/low,
  price scale, local-time axis, hover inspection, node status, Receive, Modules,
  Settings and Diagnostics pages. No standalone Quickshell window or GNOME/GTK
  dialog is included. The Diagnostics tab is shortened to “Diag” so the full
  navigation row fits, with “Diagnostics” retained as its tooltip.
- Receive QR codes are generated locally from a validated public address,
  optional amount and label. URI preview and explicit `monero:` registration
  never submit a payment. Feather/Monero GUI buttons copy the URI to the
  clipboard and launch the selected installed wallet without a send argument.
- Incoming links are stored in a private, bounded session queue independently
  from setup-job state. Opening one while setup is locked cannot replace install
  progress. Link selection, delayed FileView reads, and handler restoration are
  covered by tests.
- Watch-only wallet, XMRig and P2Pool integrations are opt-in and read-only.
  Wallet RPC requires explicit watch-only confirmation; only a bounded recent
  720-block transfer window is requested. The UI states history limits and
  unavailable data. These endpoints are disabled until the user configures
  local services.

## Evidence collected

- Rust: 35 integration tests pass (14 backend, 5 market, 13 modules, 3 payments).
- Python installer/control: 24 tests pass, including lock contention, 20-item
  queue retention, `monero:` request persistence, prior-handler restoration,
  and failed-uninstall recovery.
- JavaScript state/chart/UI tests: 11 pass. They cover the compact Diagnostics
  label and tooltip, stale data, trend colors,
  bounded five-minute candles and exact XMR amount formatting.
- `cargo fmt --check`, clippy with warnings denied, `cargo-audit --deny warnings`,
  native QML lint, `omarchy plugin validate .`, and the manifest/version contract
  check pass.
- The Qt runtime harness loads the native widget through a non-window `QtObject`,
  exercises late/atomic `FileView` changes, validates five chart-axis labels and
  their reserved width, measures the five native navigation buttons against the
  430 px panel content width, and covers corrupt/deleted snapshots. It passes
  without a standalone window.
- After the compact Diagnostics-label fix, the Rust suite (35), Python suite
  (24), JavaScript/UI suite (11), native QML lint/runtime, plugin validator,
  version contract and regenerated-bundle integrity checks passed. This follow-up
  changed QML only. `cargo fmt`, clippy and `cargo-audit` could not be rerun in
  this environment because `rustfmt`, `cargo-clippy`, `cargo-audit` and `rustup`
  are unavailable here; the earlier 0.3.1 candidate record contains their prior
  successful results.
- The release bundle matches the local SHA-256 file and passes the installer's
  integrity verifier. The prebuilt release binary reports `0.3.1`. A mainnet
  receive URI/QR using a public test fixture rendered to a 280×280 PNG; no user
  address or private key was used.
- Version 0.3.1 is installed through the existing Omarchy plugin lifecycle.
  The service is active as the desktop user, the prior explicit public-price
  choice was preserved, and the live bar/panel were visually inspected after an
  Omarchy shell reload. XMR/USD data is live; the local Monero node is offline,
  so the panel reports that accurately.

## Limits and publication

The bundle and checksums are local artifacts; there is no signed public release
or marketplace record bound to this build. The marketplace's official `Verified`
status has not been obtained. Do not display or describe this candidate as
officially verified. Completing that step requires publishing the source and
release artifacts to the owner's repository and submitting the exact commit
through the marketplace process.

Only x86_64 on the installed Omarchy version has been exercised. Fresh-machine
installation, other processor architectures/themes/scales, real node and
watch-only wallet services, authenticated wallet RPC, and actual mining setups
need separate acceptance coverage. No transfer was sent and no wallet keys were
used.
