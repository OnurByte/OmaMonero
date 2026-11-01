# OmaMonero 0.4 migration ledger

Source: user-approved TypeScript + QML migration plan, 2026-11-01.

1. Characterize price, node, wallet, mining, payments and privacy behavior.
2. Strict TypeScript core, committed QML-compatible bundle and native store.
3. Migrate advanced modules, QR, proof, incoming notifications and URI integration.
4. Replace default installer/service lifecycle; preserve legacy settings and offer explicit cleanup.
5. Verify core, QML, official validator, packaging and native session; prepare marketplace submission.

Ruling: Work on codex/typescript-native-0.4 in the existing checkout, preserving all pre-existing modifications; avoid relocating unfinished work.
Ruling: The latest approved plan supersedes the old mandatory prebuilt-binary installer requirement. Plugin-manager graphical installation is the default. Keep legacy source only for migration/reference.
Ruling: Follow AGENTS.md for branding and flat-price green, which supersedes older product text.
Ruling: Use system curl >=8.4 with stdin configuration for bounded, redirect-free HTTP and SOCKS5h. No new runtime binary, daemon, npm or Python dependency.
Ruling: Marketplace approval is an external acceptance criterion; never fabricate it or remove registry labels locally.

Implementation complete locally:
- Strict TS core and committed QML bundle; market/node/wallet/mining/payment/proof functionality connected to native components.
- Legacy Rust/Python runtime, service packaging, bootstrap and old QML copies removed from the active project.
- Previous settings import, native configuration/removal, optional private URI inbox and explicit old user-service shutdown implemented.
- 42 core/transport/QR tests, 6 display tests, 6 native lifecycle tests, native Qt engine checks, clean QML lint, official validator and deterministic packaging pass. Dependency audit reports zero vulnerabilities.
- One fresh whole-branch reviewer identified queued-request policy invalidation, detached wallet launch, stale QR/proof results, source-form aliasing and outdated publication documentation. All important findings were addressed and checked. No minor findings were deferred.

Ruling: Do not modify the user's active plugin/service to simulate a clean installation. Use an isolated real Qt/Wayland engine and the exact packaged archive; actual published-commit manager installation remains a release acceptance check. Cost if wrong: a lifecycle problem may only surface in that final clean installation test.

External remaining work: publish the reviewed commit, clean official-manager installation/update against it, submit for marketplace review and record its real decision. No marketplace status was invented. See publication.md and verification-0.4.0.md.
