# OmaMonero 0.4.0 local candidate verification

Date: 2026-11-01. Branch: `codex/typescript-native-0.4`.

Passed locally:

- Strict TypeScript compilation and 42 Vitest cases, including Monero standard/integrated/subaddress vectors, checksum/network rejection, unsafe URL rejection, proxy policy, real curl dead-proxy/no-proxy/redirect/size-bound behavior, trailing-day interpolation, u64 precision, modules and an independent QR decoder.
- Six display/settings regressions, including flat-price green and copied source settings.
- Six isolated native integration tests: handler restoration order, restoration failure retention, user-only confirmed cleanup, bounded private inbox, P2Pool symlink/size rejection and private-directory checks.
- Real Wayland Quickshell engine, with a QtObject root and existing Omarchy components. The temporary home/session fixture exercised native widget/panel loading, local node/wallet/miner APIs, atomic balances above JS precision, bounded incoming history, P2Pool, receive QR, proof verification, configuration save and URI inbox loading. No live plugin installation or configuration changes were made.
- Quickshell HTTP cancellation test verifies that active/queued old work cannot run the queued action after cancellation.
- QML lint without warnings. The Wayland fixture emits a host portal registration warning in this shared desktop session; assertions pass and no standalone window is opened.
- Official installed Omarchy validator against the exact packaged plugin archive.
- Official manager add/enable/disable/remove on a fresh candidate checkout and a 0.3.x→0.4 update using the real Omarchy PluginRegistry and widget in an isolated native Wayland engine. Temporary HOME, configuration and IPC paths prevent changes to the active desktop. No Rust binary/service/installer is installed.
- Deterministic archive generation and matching SHA-256 on repeated builds.
- npm dependency audit: zero reported vulnerabilities.
- Whitespace and backend-free version/packaging contract checks.

Regression sensitivity: removing the old-result clearing reproduced stale successful QR/proof displays, and restoring the old wallet-launch behavior reproduced the UI lock. The fixed implementation passes the same harness. HTTP cancellation was first tested absent (failure), then with queue/active-process cancellation (pass).

Not claimed:

- Remote CI execution, a published release, an installation/update from the published commit in a clean official-manager session, or a marketplace approval/Manual setup label change.
- An independent P2P routing audit, spendable-balance guarantee or official verification badge.

The old user service is never disabled automatically. Existing TOML settings and the original receiving address remain intact; saving writes the new private JSON configuration. Optional URI integration preserves a restoration receipt and fails removal safely if restoration cannot be verified.
