# Development

Users install with the graphical Omarchy plugin manager. The commands here are only for contributors.

- `npm ci --ignore-scripts`: install pinned build/test dependencies.
- `npm run check`: strict TypeScript check, Vitest tests and QML-compatible bundle.
- `node --test tests/status.test.cjs`: display-format and market-state regressions.
- `python3 -m unittest discover -s tests -p '*_test.py'`: isolated native lifecycle tests.
- `python3 scripts/check-contract.py`: version and backend-free packaging contract.
- `python3 scripts/lint-qml.py`: native QML lint against installed Omarchy.
- `python3 scripts/test-http-cancel.py`: verifies active/queued HTTP cancellation with a QtObject-root engine.
- `python3 scripts/test-qml-runtime.py`: non-visual QtObject-root engine in a Wayland session, with fixture node/wallet/miner APIs, P2Pool data, proof and receive QR. Uses a temporary home and session directory, never installs or changes the live plugin.
- `python3 scripts/validate-plugin.py`: official local validator; does not confer marketplace verification.
- `python3 scripts/package.py`: deterministic plugin archive, including committed JS and runtime integrations. No binary bundle or installer.

After editing TypeScript, rebuild and commit `qml/v0_4_0/generated/Core.js`. CI checks reproducibility. Dependencies are pinned in `package-lock.json`. Crypto uses the MIT-licensed js-sha3 Keccak implementation; Monero Base58 is block-oriented byte arithmetic, avoiding BigInt unavailable in QML. QR generation uses qrcode-generator; public address/network/checksum tests cover standard, integrated and subaddresses.
