# Price-first native UX correction

User instructions: default prices on, no default Offline widget, a simple comfortable interface with clear hierarchy. This explicitly supersedes the earlier opt-in/default-off preference. Keep truthful public source/freshness, proxy fail-closed behavior, all optional features and native Omarchy components.

Chosen implementation: price-led bar and first panel; three primary destinations (Price, Receive, More). Put wallet/mining, optional node, settings and diagnostics under More. Hide technical connection/source fields under Advanced settings and legacy cleanup/removal under Maintenance. Keep the supplied logo/banner and white XMR/red-negative/green-nonnegative presentation.

Alternatives considered: retaining five equal tabs keeps the confusing hierarchy; removing advanced features would violate the preservation requirement. Progressive disclosure preserves capability with a smaller first screen. Exact English labels follow the existing product language; hierarchy and disclosure are implementation decisions made for the user's request.

Default public Kraken XMR/USD is enabled. Existing explicit disabled preferences remain respected; the user in this chat explicitly requested enabling their own prices. Never fabricate prices, show Node offline as the widget's primary state, silently bypass a proxy or auto-start a node. Market loading/failure/staleness remain truthful. Optional node detail can report its own connectivity within its page.


Additional explicit production UI requirements: readable chart labels; Dexscreener-like advanced interaction; header information target limited to the supplied logo and title; a richer About section; a real native-panel screenshot in README. Implementation: retain actual Kraken OHLC/volume and incomplete-candle status, offer 5m/15m/1h, native candle/line chart with pointer/keyboard zoom and bounded pan. Custom close-only history remains line-only. High-contrast axes use explicit colors/fonts. No fabricated candles, fake trading controls, new backend, web embed or replacement branding.
