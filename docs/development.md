# Development

Users install with the graphical Omarchy plugin manager. The commands here are only for contributors.

- `npm ci --ignore-scripts`: install pinned build/test dependencies.
- `npm run check`: strict TypeScript check, Vitest tests and QML-compatible bundle.
- `npm run test:presentation`: display-format and market-state regressions.
- `python3 -m unittest discover -s tests -p '*_test.py'`: isolated native lifecycle tests.
- `python3 scripts/check-contract.py`: version and backend-free packaging contract.
- `python3 scripts/lint-qml.py`: native QML lint against installed Omarchy.
- `python3 scripts/test-plugin-lifecycle.py`: official add/enable/update/disable/remove commands with the real Omarchy registry/widget in an isolated Wayland engine; no second desktop bar or live user configuration changes.
- `python3 scripts/test-config-io.py`: real FileView privacy regression cases with a no-network transport boundary.
- `python3 scripts/test-chart-render.py`: offscreen chart rendering with labelled fixture data for visual QA; no desktop surface.
- `python3 scripts/test-http-cancel.py`: verifies active/queued HTTP cancellation with a QtObject-root engine.
- `python3 scripts/test-qml-runtime.py`: non-visual QtObject-root engine in a Wayland session, with fixture node/wallet/miner APIs, P2Pool data, proof and receive QR. Uses a temporary home and session directory, never installs or changes the live plugin.
- `python3 scripts/validate-plugin.py`: official local validator; does not confer marketplace verification.
- `python3 scripts/package.py`: deterministic plugin archive, including committed JS and runtime integrations. No binary bundle or installer.

After editing TypeScript, rebuild and commit `qml/v0_4_3/generated/Core.js`. CI checks reproducibility. Dependencies are pinned in `package-lock.json`. Crypto uses the MIT-licensed js-sha3 Keccak implementation; Monero Base58 is block-oriented byte arithmetic, avoiding BigInt unavailable in QML. QR generation uses qrcode-generator; public address/network/checksum tests cover standard, integrated and subaddresses.

Application and presentation sources live in `src/core/*.ts`; contributor build/compatibility scripts are also TypeScript. Node 22.6+ strips their types, while `tsc` checks them strictly before execution. Python is used only for native integration/packaging checks, not as an application backend.

The only tracked `.js` file is the minified runtime bundle generated from TypeScript plus the licensed QR and Keccak libraries. Quickshell cannot execute TypeScript directly. `.gitattributes` marks this output as generated so GitHub language statistics reflect authored source. Edit TypeScript, never the generated file.

Only current JSON configuration is supported. No TOML parser, migration layer or old service-management action is shipped. Native upgrade tests retain JSON choices from the previous native release.
