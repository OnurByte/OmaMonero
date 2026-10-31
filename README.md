# OmaMonero

<p align="center">
  <img src="docs/brand/banner-reference.png" alt="OmaMonero — Secure, private and untraceable" width="960">
</p>

<p align="center">
  <a href="https://github.com/tcballard/omarchy-badges"><img src="https://raw.githubusercontent.com/tcballard/omarchy-badges/75975e5b5bf75e7ede3764bcd2950046f7abfe2c/badges/v1/omarchy-plugin.svg" alt="Built for Omarchy: Plugin"></a>
  <a href="https://github.com/OnurByte/OmaMonero/actions/workflows/ci.yml"><img src="https://github.com/OnurByte/OmaMonero/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI status"></a>
</p>

**A clickable Monero companion for Omarchy Quattro.**

See XMR/USD price, a compact chart and the 24-hour change in your existing upper
bar. Click the indicator for the larger chart, node health and privacy status.
The native panel follows Omarchy's fonts, theme and scale. Market falls are red,
rises green and flat movement gray; the XMR label stays white.

## Install

```bash
omarchy plugin add https://github.com/OnurByte/OmaMonero.git --enable
```

Click **XMR → Settings → Install OmaMonero** in your Omarchy bar. The panel downloads the matching prebuilt backend from GitHub, verifies its SHA-256 and asks whether to enable public prices. No `sudo` or Rust compiler is needed. Linux x86_64 only.

## Features

- XMR/USD price, 24-hour change and chart in the existing Omarchy bar.
- Node sync and privacy status; optional watch-only wallet, XMRig and P2Pool views.
- Local receive QR codes and safe `monero:` payment-link previews.
- Settings, diagnostics and removal in the same native panel.

## Privacy

Public prices are **off by default**. Enabling them contacts the selected HTTPS provider, which can see your IP unless you configure a supported proxy. Node monitoring is read-only; OmaMonero never stores private keys or sends payments. No blockchain download starts automatically.

## Remove

**XMR → Settings → Remove OmaMonero.** Your personal configuration is kept. Removing just the plugin through Omarchy leaves the separately installed backend running.

Not officially marketplace-verified. For technical details, see [development](docs/development.md), [architecture](docs/architecture.md) and [verification](docs/verification-0.3.2.md).
