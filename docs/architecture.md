# 0.4 architecture

Omarchy loads `qml/v0_4_3/BarWidget.qml`, the existing qs.Ui panel and one `StatusStore` singleton per engine. `src/core` contains strict TypeScript modules for privacy/configuration, transport, market, node, wallet/mining and payments. esbuild emits the committed `generated/Core.js` bundle as a QML library. End users do not build it.

`Http.qml` starts a short-lived system curl process for each queued request. Configuration and RPC bodies travel over stdin, never argv. curlrc and ambient proxies are bypassed; explicit SOCKS5h has remote DNS and an empty no-proxy list. Redirects and non-2xx responses fail. Responses have a time/size limit. There is no listener, daemon, installed backend binary or background systemd unit.

Wallet RPC exposes only read-only balance/address/height/history/proof methods. Account 0 history is bounded by height and the displayed list by count. Large atomic JSON numbers are preserved as decimal strings before native JSON parsing. External API failures never become invented prices or successful states.

Private configuration and session directories have mode 0700. QML FileView performs atomic writes. Payment URIs enter via an optional small desktop handler, are written atomically under a lock to a mode-0600 bounded session inbox and are validated locally before display. No URI or proof is forwarded into helper process arguments or notifications. Wallet opening has fixed executable choices and no payment argument.

`native.sh` provides narrow desktop integrations: private-directory preparation, bounded local P2Pool file reading, explicit wallet opening, optional URI registration/restoration and official plugin removal. It contains no price, node, wallet, payment or cryptographic implementation. Removal runs detached so plugin reload cannot kill its own action.

Public XMR/USD requests default on by the user’s 2026-11-01 correction; existing explicit pauses are retained. Source for the former Rust backend and Python installer was removed; prior versions remain in git history. Prior source and release records remain in git history.
