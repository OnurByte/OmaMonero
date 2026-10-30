> Historical record, superseded by the native-only 0.2.2 release. Correction: the initial Item-root test harness could create a white floating window; the current QtObject-root harness is verified windowless. Do not use the removed Zenity/desktop-settings candidate.

# End-user release verification — 0.2.0 — 2026-10-30

## Scope

The user required a no-command installer, installation-only pkexec if privilege
is needed, an Omarchy-native upper-bar entry and a USD/24h price graph. The chosen
implementation is user-only, so **no root authorization is necessary**. Normal
use never invokes sudo or pkexec. Product requirements are recorded in the root
PRODUCT_REQUIREMENTS.md and AGENTS.md for subsequent sessions.

## Automated checks

- Rust backend: the original 14 real-HTTP/process integration cases plus market
  parser/opt-in/proxy cases. Market parsing checks hourly closes, provisional
  candle timing, interpolated reference, bounded finite prices, ordering, stale
  provider data and error responses.
- JavaScript: 7 classifier/formatting cases, including independent prices with
  an offline node, invalid/stale markets, signed rise/fall/flat percentages and
  refusal to treat stale backend snapshots as current prices.
- Installer: 13 isolated tests cover integrity/tampering/symlinks/path traversal,
  unknown payload files, configuration preservation and opt-in, permissions,
  native command argument quoting, file rollback, install/update/removal,
  service-start failure, action lock, unmanaged destination protection, custom
  config homes and retention of additional user data. Actual local Git operations
  are used inside temporary homes; no real user service is changed by these tests.
- Native QML lint, the FileView atomic replacement/late-creation harness, official
  manifest validator, version contract, Rust format/clippy and release build.
- Bundle integrity verified after extraction; desktop launcher validated by
  desktop-file-validate. Release launcher opens the actual graphical installer.

## Real-session evidence

Test host: Omarchy 4.0.6-1, Quickshell 0.3.2, Qt6.12, Linux x86_64, one eDP-1
display at scale1.5. The graphical bundle was opened from its desktop entry and
installation completed with public-price opt-in. The user service is enabled
and active as the normal desktop account, without root authorization.

The installed backend publishes fresh API1 status with backend version0.2.0,
`node.state=offline` (no monerod running), and `market.state=ready`. A live Kraken
OHLC request yielded 26 plotted samples and a finite USD/24h change. No price
value is fixed in this record because the market changes.

The native upper bar and popup were visually inspected: price/change and compact
sparkline appear in the existing upper bar; the popup shows the full chart,
provider/update labels, settings/reload/close controls and honest offline-node
and unverified-P2P status. No fake price or node state is used for this evidence.

The real v0.1-to-v0.2 update exposed Qt retaining old component URLs after registry
reload. Moving the runtime source to `qml/v0_2_0/` and changing the manifest entry
point loaded the correct new singleton/panel without restarting the shell or
creating another desktop shell. Future releases must use distinct versioned
runtime paths. Existing Omarchy plugin-manager mechanisms remain authoritative.

Independent review found two installer issues (unmanaged-file replacement and
custom configuration-home unit placement). Both were reproduced with failing
tests and fixed; the reviewer independently reran all13 installer tests and found
no further important defect. Unknown user files and configuration survive removal.

## Release limits

This is **not** official marketplace verification or a public signed release.
No marketplace submission/public message was sent. See docs/publication.md.
Fresh-machine distribution, multiple monitors, extra display scales, theme
switching, suspend/resume, real monerod and real Tor/I2P integration still require
acceptance testing. Only the tested x86_64 architecture has an end-user bundle.
The separately packaged privileged system path is not part of the default GUI
installer. No system packages are installed automatically.
