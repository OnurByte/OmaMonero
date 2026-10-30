# Architecture and API 1

`omamonero-core daemon` owns the only RPC polling loop. It performs one bounded
`get_info` request, publishes a snapshot, then waits the configured poll interval.
There is no catch-up burst after sleep and no timer in a per-monitor widget.
SIGTERM and SIGINT interrupt both requests and waiting. An advisory lock prevents
parallel writers, including overlapping `once` commands. systemd restarts crashes
at most three times in a minute, independently of the frontend.

`Config` is strict TOML with defaults. Unknown fields fail before network access.
Only an origin URL is accepted: no paths, credentials, fragments or queries.
Transport validation happens before client creation, and reqwest does not read
system proxy settings or follow redirects. Requests time out, and response bodies
are capped at 1 MiB before JSON parsing. Status, JSON-RPC identity, data types,
node network and bounded version text are checked. Dynamic upstream error text
is never copied to snapshots or logs. Disk figures are node-reported, not a local
filesystem scan; missing restricted-RPC metrics remain unavailable.

A successful snapshot has this shape (illustrative values):

```json
{
  "api_version": 1,
  "backend_version": "0.1.0",
  "generated_at": 1793369100,
  "stale_after_secs": 18,
  "node": {
    "state": "online",
    "height": 3200000,
    "target_height": 3200000,
    "sync_percent": 100.0,
    "incoming_peers": 3,
    "outgoing_peers": 8,
    "network": "mainnet",
    "version": "0.18.4.0",
    "database_bytes": 123456789,
    "free_bytes": 456789,
    "latency_ms": 5,
    "untrusted": false
  },
  "privacy": { "transport": "local", "p2p_verified": false }
}
```

`generated_at` is a Unix timestamp in seconds. Staleness is three configured poll
intervals plus the rounded-up request timeout, with a minimum of 15 seconds.
The frontend checks its own clock every second, rejects timestamps more than
five seconds in the future, and accepts staleness thresholds of 1..1000 seconds.
Clock changes can therefore invalidate a snapshot until the next poll.

Node state is a tagged union:

- `online` has metrics and means monerod reports synchronized and not busy.
- `syncing` has metrics; unknown target gives `sync_percent: null`.
- `offline` has only `error`, one of `connection`, `timeout`, `http_error`,
  `invalid_response`, `rpc_error`, `network_mismatch`, `response_too_large`.
- `stopped` has no metrics and is written on clean termination.

There is no retained last-good data in an offline snapshot. API mismatch,
invalid JSON, invalid fields, missing files and stale heartbeats are frontend
states independent of the node state. Unknown/stale values never drive healthy
colors or numeric formatting.

The writer checks runtime ownership and permissions, rejects symlink paths,
creates a same-directory 0600 temporary file, serializes and fsyncs it, atomically
renames it to `status.json`, then fsyncs the directory. `backend.lock` remains
present but unlocked after shutdown; its mere existence does not mean a daemon
is running. A hostile process running as the same Unix user is outside this
boundary. No TCP or Unix listener is opened.

`StatusStore.qml` is one singleton per QML engine. `FileView` reloads on file
change and reparses on load completion; a shared five-second file-only recovery
timer handles missed rename events and creation after an absent directory.
Each monitor renders the same classified snapshot and owns its own native popup.
Panel construction uses `qs.Ui.Panel`, `KeyboardPanel`, `PanelKeyCatcher`,
`PanelActionButton`, theme and spacing tokens from installed Omarchy.

The plugin manager owns QML install/enable/update/disable/remove. The binary and
user service are separately installed and activated explicitly. Neither lifecycle
silently changes the other. Compatibility is API 1, not guessed from version text.


## 0.2.0: market and end-user installation

API1 adds an optional `market` tagged union. Old snapshots default to `disabled`.
Ready state includes a source name, currency USD, fetch time, 360-second freshness,
300-second sampling, price, percentage and at most400 timestamp/price points.
Errors publish `unavailable` without old prices. The UI checks market freshness
independently from the node and rejects stale backend heartbeats globally.

Market requests are disabled by default. An affirmative graphical choice enables
the independent 120-second worker. It uses fixed public HTTPS, no environment
proxy, no redirects, bounded response/timeouts and the explicitly configured SOCKS
proxy when present. A custom source uses an HTTPS endpoint with user-selected
JSON Pointers and bounded Unix-second history; it never receives a wallet or
node credential. Redirects, credentials in URLs and oversized responses are
rejected.

The user-only bundle installs the prebuilt binary, GUI and user unit, then uses
the official plugin manager against a stable user-owned local Git source. It
checks hashes, ownership/collisions, active session and config before mutations;
file/service state is restored on failure. A fresh backend heartbeat is required
before success. Settings/diagnostics/removal remain graphical. No root operation
is needed on the tested target. Checksums are integrity, not authenticity.

The runtime QML lives under a versioned directory (`qml/v0_2_0`) because changing
only file contents at an already-loaded third-party URL can retain cached types
in the host engine. Future releases must change the directory and manifest URL.
This keeps updates in the existing Omarchy shell without a global restart.

## 0.3.1: payments and local modules

The optional `modules` snapshot contains read-only watch-only wallet, XMRig and
P2Pool status. The wallet adapter requires a numeric loopback HTTP origin and an
explicit watch-only confirmation; it calls a fixed RPC allowlist with bounded
responses and requests transfers only within a recent 720-block window. History
errors do not erase valid balance/address data. Notifications are opt-in and
start after an initial baseline scan. Authentication and unverified remote RPC
are unsupported.

Payment requests validate Monero address checksum/network and decimal amount in
Rust, then render a local QR SVG. Incoming `monero:` requests are persisted to
private `payment.json` and a bounded 20-item `incoming.json` session queue, not to
setup-job progress. The optional URI-handler registration is user initiated;
removal verifies restoration of the previous default before deleting the
handler. Wallet launch takes no URI argument and never sends a transaction.

QML uses a versioned `qml/v0_3_x` directory; change this path for each released
version so Quickshell does not retain old component types after a hot update.


## Native-only correction (0.2.2)

The user rejected the initial Zenity/desktop settings flow. That GUI and custom
icon are removed. The download launcher now bootstraps the official bar frontend
and opens its native setup page before any backend service is installed/started.
Settings, market consent, diagnostics and two-step removal use qs.Ui controls
inside the existing KeyboardPanel. There is no separate settings application.

Explicit actions start a detached Python control job, because install/update or
remove may unload the very panel that requested the action. Progress/results are
atomically written as private setup.json and observed through FileView. The
shared file recovery timer launches no commands. Opening the panel sends an
explicit info action: its real lock recovers an abandoned running record while
leaving a live install untouched, without guessing timeouts.

Bootstrap failures restore source and installed plugin commits, prior enablement,
previous staging metadata and pending payload. Owned legacy GUI/desktop/icon
files are transactionally removed on upgrade. Runtime URLs are versioned as
qml/v0_2_2 to avoid retained Qt types from older releases.
