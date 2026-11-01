# OmaMonero 0.4.2 production UI verification

Latest user corrections: public XMR/USD prices default on; no global Offline label for an absent optional node; simple native hierarchy; advanced readable chart; About target limited to logo/title; preserve supplied banner/icon; add actual product screenshots.

Implemented: Price/Receive/More navigation, Advanced/Maintenance disclosure, real Kraken OHLC/volume at 5m/15m/1h, candle/line modes, crosshair inspection, zoom/pan/reset/expanded view, timestamp-anchored historical views, explicit readable axis styles and richer About information. Custom close-only history remains line-only.

Evidence so far:
- 57 strict core/transport/QR/chart/path tests, 8 presentation tests and 6 native OS lifecycle tests pass.
- Generated JS passes with QML-missing built-ins absent.
- Native Qt/Wayland fixture verifies chart viewport/zoom/pan, source-form validation, three-tab hierarchy, collapsed settings, wallet/miner/node data, proof/QR and incoming-link persistence after settings save.
- Eight real FileView cases verify fail-closed JSON/TOML errors, readable JSON precedence, existing pause, legacy Tor policy and genuinely new default-on installation. A no-network transport boundary records attempted real production request specs.
- Offscreen rendering of actual chart components uses explicitly labelled fixture data for visual QA only; it is not used as a README product screenshot.
- QML lint and the official Omarchy archive validator pass.

Fresh review identified config-error fallback, empty custom-source fallback and rolling-history drift. Each was reproduced and corrected. Read errors now cancel traffic; only genuinely absent settings permit initial defaults. UI validation requires HTTPS when custom source is selected. Panned charts retain the visible timestamp as new candles arrive.

Public release, actual panel screenshots and final marketplace decision are recorded separately after their authoritative checks; no verification badge is inferred from local tests.

Official fresh and 0.4.1 upgrade manager lifecycles pass at dac041f. The candidate was updated through the official manager in the existing desktop, with the public origin restored immediately afterward. The real bar shows live Kraken XMR/USD and 24h change. Actual bar, market and About captures are in docs/screenshots; they contain no fixture market data. Approved banner, root preview and supplied icon were not changed.
