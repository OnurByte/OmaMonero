# 0.4.3 verification

This release removes retired TOML configuration migration, the smol-toml dependency, previous-service cleanup controls and obsolete migration documentation. Current JSON settings and optional native tools remain supported. Previous release evidence remains in git history.

All application/presentation sources and build/compatibility scripts are TypeScript. The only committed JavaScript is the generated minified QML runtime bundle. Its size dropped from 153,509 to 50,448 bytes (67% smaller); no QR/address-validation functionality was removed. The approved banner and icon are unchanged.

Passed locally:
- Strict TypeScript checking, including contributor scripts and presentation tests.
- 56 core/transport/QR/chart tests and 8 presentation regressions.
- Generated bundle compatibility with BigInt, Object.hasOwn and String.replaceAll absent; it contains no old configuration parser.
- Six native integration tests, including rejection of the removed service-cleanup action.
- Eight real JSON FileView cases with a no-network HTTP boundary: directories, unreadable/malformed/null settings and invalid proxy fail closed; paused prices, Tor policy and new-install defaults work.
- Actual QML runtime integration for UI, node/wallet/mining, u64 precision, QR/proof and incoming-preview persistence; HTTP cancellation.
- QML lint, offscreen chart rendering, official Omarchy archive validation and fresh manager lifecycle using the working frontend.

Official manager lifecycle and publication are checked separately before delivery. Marketplace approval remains external and is never inferred from these checks. README captures are actual 0.4.2 desktop captures; branding and primary layout are unchanged.
