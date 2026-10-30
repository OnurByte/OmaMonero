# Delivery status — 0.3.1

The supplied native Omarchy companion is implemented as a Rust user service
plus the official plugin-manager Quickshell frontend. The current workspace is
not a Git checkout; no commits, public repository writes, releases or
marketplace submissions have been made.

The 0.3.1 x86_64 candidate is installed in the current Omarchy 4.0.6-1 session.
The single upper-bar widget, brand artwork, red decline chart, five visible
price ticks, Receive page, service and setup integration were checked in the
running Omarchy shell. The Diagnostics tab now uses the compact “Diag” label
with its full name in the tooltip. Existing explicit USD price consent was
preserved. The local Monero node is offline; wallet, XMRig and P2Pool adapters
remain disabled until the user configures their local services.

Rust integration tests (35), Python installer/control tests (24), JS/UI tests
(11), native QML lint/runtime, official plugin validator, version contract and
bundle checksums passed. See
[`verification-0.3.1.md`](verification-0.3.1.md) for the evidence and limits.

This candidate is not officially marketplace-verified. That external status is
still pending source publication and review of the exact submitted commit; a
local validator result or checksum is not a substitute.
