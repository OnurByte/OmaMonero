# OmaMonero product requirements

Current user preferences, consolidated 2026-11-01. These supersede older installer, migration and default-off plans in git history.

- Use the official graphical Omarchy plugin manager for installation, updates, enable/disable and removal. Users do not type commands or build the project.
- Run inside the existing native Omarchy bar and qs.Ui panel. No standalone settings application, second shell, GTK or Zenity dialogs.
- Author application logic in strict TypeScript, compiled into committed QML-compatible JavaScript. Quickshell supplies the native interface. Users need no Node, npm, Python installer, Rust binary, OmaMonero backend or service.
- Remove retired TOML configuration migration, compatibility code and old service cleanup controls. Support current JSON settings. Do not delete or manage a user's previous installation files or services as part of this code cleanup.
- Public XMR/USD prices and the trailing 24-hour chart are enabled by default, explicitly requested by the user. Retain existing JSON pauses, proxy choices and module settings; provide a simple pause control. An absent optional node must not make the default bar appear Offline.
- Keep the hierarchy comfortable: Price, Receive, More. Technical settings use progressive disclosure. The chart supports readable axes, real OHLC/volume, candle/line views, crosshair, zoom, pan and expanded view. Do not fabricate data or freshness.
- Keep the approved banner and user-supplied orange Monero artwork. The path-flattened SVG preserves its appearance for Qt. XMR stays white; negative market movement is red and zero/positive green. The About header hit target covers only logo/title.
- Keep node, watch-only wallet, incoming payment notifications, XMRig, P2Pool, receive QR, URI previews and proof verification. These optional tools remain inside the native panel. No automatic node or wallet startup; shell-off notifications have no daemon.
- Respect selected Tor/I2P SOCKS5h proxies with remote DNS. Never fall back to direct access. Invalid/unreadable current settings stop requests. Wallet/miner RPC uses numeric loopback. Preserve atomic Monero amount precision.
- Never request seeds or private spend keys and never send payments. Validate public addresses, checksum and network locally. Receive QR generation is local.
- Preview incoming monero links in a bounded private session inbox; retain previews across panel reloads/settings saves. Do not put private URI/proof contents in process arguments, logs or notifications. Wallet launch is explicit and receives no auto-send URI.
- Restore and verify a previous OS URI handler before removing owned integration files. If restoration fails, retain files/receipt and allow retry.
- Prefer user-only operations. Never elevate the GUI/plugin or routine actions. Any unavoidable privileged installation action must be narrow and use pkexec, never sudo.
- Marketplace Verified requires an actual record for the exact shipped commit. Local tests and checksums do not confer it; Manual setup removal remains a maintainer decision.
- README should include attractive actual bar/panel screenshots alongside the unchanged approved banner/icon. Never present fixture data as a live product screenshot.
- Native test engines use a QtObject root and must not create blank desktop windows.
