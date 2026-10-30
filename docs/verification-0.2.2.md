# Native-only release 0.2.2 — 2026-10-30

This supersedes the rejected Zenity/desktop-settings candidate. The product now
has no GTK/Zenity settings window, standalone settings application or fabricated
icon. All setup, settings, price consent, diagnostics and two-step removal are
inside the existing Omarchy bar panel using qs.Ui components.

## Confirmed

- 18 Rust integration/parser tests, 18 Python installer/control tests and 8 JS
  classifier/color tests pass. Formatting, clippy, native QML lint, the official
  plugin validator and the version contract pass.
- The supplied OmaMonero-logo.svg was inspected for active/external SVG content,
  copied unchanged and byte-hash compared with the original. It is used in the
  native bar and panel header. The supplied banner is kept as a brand reference.
- Market colors are explicit red (#ef4444) for a fall and green (#22c55e) for zero
  or positive change. Tests pin those semantics independently of theme accent.
- The native FileView integration harness passes late creation, repeated atomic
  replacement, invalid JSON, deletion and abandoned-job info dispatch. Its root
  is now QtObject, with no top-level Item auto-wrapped in a floating window.
  While the test engine ran, the compositor reported **zero visible windows**
  belonging to that engine. No deprecated ProxyFloatingWindow sizing warnings
  appear in this corrected harness.
- A real native-only 0.2.2 installation is active on the tested Omarchy4.0.6-1
  session. The service runs as the desktop user; no elevation was requested.
  The bar displays live Kraken XMR/USD data, percentage and sparkline. The full
  chart and native Settings form (address, market toggle, Save, Remove) were
  visually inspected. No local monerod is running; the node is honestly offline.
- Owned legacy GUI code, standalone desktop settings entry and invented SVG icon
  are removed transactionally during upgrade. The user-supplied brand SVG stays
  inside the native frontend, not a separate settings app.

## Lifecycle and recovery

The clicked download launcher only stages the official-manager frontend and
opens the native bar setup page. It does not install/start the backend until the
user clicks Install in that panel. Optional public market requests require the
native toggle choice. The user-only path requires no root/sudo/pkexec.

Explicit control jobs are detached, so the panel being reloaded or removed cannot
kill its own installation/removal task. Private setup.json plus FileView carries
progress. No process polling is added. Opening the panel permits an info request
to check the actual setup lock: it recovers an abandoned running record and never
interrupts a genuinely live job. Both cases are tested.

Bootstrap rollback restores source and installed plugin revisions, prior enabled
state, marker and pending payload. Tests cover failure after a successful update.
Installation refuses unmanaged/modified destinations, restores files and service
state after failure, honors the effective config home and requires a fresh
backend heartbeat. Removal retains configuration and additional user files.
An independent reviewer reran the Python18/JS8 suites and found no further
important issue after these fixes.

## Honest limits

Local checks and integrity hashes are not official marketplace verification,
signatures or certification. No public listing/submission was created. See the
publication gate. Fresh-machine deployment, extra monitors/scales, theme changes,
suspend/resume, real monerod and real Tor/I2P routes still need broader acceptance
coverage. Only x86_64 has a tested end-user bundle. Native host shutdown/portal
warnings in isolated test engines are not claimed to be product guarantees.
