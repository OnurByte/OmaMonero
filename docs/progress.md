# Delivery status — 0.4.0 candidate

The Rust/Python companion architecture has been replaced with native TypeScript and QML. The committed JS bundle runs in the existing Omarchy bar/panel. Build tools are contributor-only. All old runtime sources were removed from the active project; prior versions remain in git history.

The candidate retains market/node data, watch-only wallet and incoming transfers, XMRig, P2Pool, offline address/QR/payment previews, local proof verification and optional OS URI integration. Native setup/removal no longer depends on an installed OmaMonero daemon. Existing settings are imported without rewriting the original TOML. Legacy user-service shutdown requires explicit confirmation.

Evidence and acceptance limits: [verification-0.4.0.md](verification-0.4.0.md). Publication and marketplace review remain external steps: [publication.md](publication.md).
