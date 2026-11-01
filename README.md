# OmaMonero

<p align="center">
  <img src="docs/brand/banner-reference.png" alt="OmaMonero — Secure, private and untraceable" width="960">
</p>

<p align="center">
  <a href="https://github.com/tcballard/omarchy-badges"><img src="https://raw.githubusercontent.com/tcballard/omarchy-badges/75975e5b5bf75e7ede3764bcd2950046f7abfe2c/badges/v1/omarchy-plugin.svg" alt="Built for Omarchy: Plugin"></a>
  <a href="https://github.com/OnurByte/OmaMonero/actions/workflows/ci.yml"><img src="https://github.com/OnurByte/OmaMonero/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI status"></a>
</p>

A native Monero widget for Omarchy Quattro. TypeScript runs inside the existing Quickshell bar and panel. No OmaMonero backend, service, Rust binary, Python installer, Node.js or npm is required by users.

## Install and use

Open the official Omarchy plugin manager, add `https://github.com/OnurByte/OmaMonero.git`, and enable OmaMonero. Open the XMR widget in your existing bar. All settings, diagnostics, payments and removal stay in this panel. The repository must contain the 0.4.1 release before installing it from that URL; a local checkout can be validated before publication.

The default configuration contacts only numeric loopback Monero RPC. External prices are off until you explicitly enable **XMR / USD · 24h** in Settings. Choose local, HTTPS direct, Tor or I2P policy there. Tor/I2P uses a local SOCKS5h proxy with remote DNS and never falls back to direct access. Wallet and miner RPC always remain on numeric loopback.

Price source and freshness are shown with the chart. Stale, invalid or unavailable data is explicit. The widget does not start a Monero node, Tor, I2P, wallet RPC or miner for you.

## Features

- XMR/USD sparkline, trailing 24-hour change and detailed chart; Kraken or a configured HTTPS JSON source.
- Monero node synchronization, peers, network, latency and storage information.
- Local watch-only wallet balance and latest 20 incoming transfers from a bounded 720-block window. Atomic amounts retain all 12 decimal places.
- Local XMRig API and P2Pool `local/stratum` data API telemetry.
- Offline public-address validation (Monero block Base58 and Keccak checksum), receive QR, payment-link preview and local wallet RPC transaction-proof verification.
- Optional `monero:` integration with a private, bounded session inbox. Requests never send payments. Wallet opening is explicit and receives no payment URI as a launch argument.
- Native settings, read-only diagnostics and removal through the official plugin manager.

Monitoring and notifications run while Quickshell is active. No separate OmaMonero daemon runs after the shell closes. Watch-only is a user confirmation; balances may overstate spendable funds without imported key images. Seed phrases and private spend keys are never requested.

The obsolete v0.3.2 standalone bundle is retired: private payment requests could appear in process listings. Do not use it.

Version 0.4.1 corrects native helper paths in long-running Quickshell sessions and supersedes 0.4.0.

## Updating from 0.3.x

The panel reads existing `~/.config/omamonero/config.toml` without rewriting it. Saving creates `config.json`; existing node, network, proxy, price-source and module choices are retained. Invalid old settings pause requests until corrected. Public receiving-address settings are retained.

The old user service is not stopped automatically. Settings offers a separate confirmation to stop and disable it. Legacy system-wide services require their existing installation manager; the new widget never elevates itself. URI handler restoration is verified before owned handler files can be removed. If restoration fails, removal stops and keeps the receipt and files for retry.

## Compatibility and verification

Requires Omarchy Quattro / Quickshell and the standard desktop utilities shipped by Omarchy, including curl >=8.4, bash, coreutils, flock and xdg-mime. curl is a short-lived HTTP transport, not an OmaMonero backend. The optional wallet buttons require Feather or Monero GUI to be installed separately.

Local tests and checksums do not mean official marketplace verification. Marketplace review and removal of any Manual setup label are controlled by its maintainers; no approval is claimed here.

Development and test instructions: [docs/development.md](docs/development.md). Architecture: [docs/architecture.md](docs/architecture.md). Migration evidence: [docs/typescript-migration.md](docs/typescript-migration.md).
