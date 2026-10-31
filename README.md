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

### Verified terminal setup (optional)

On Omarchy x86_64, paste this **single line** in the terminal (Bash, fish or zsh):

```bash
bash -euo pipefail -c 'installer=$(mktemp); trap "rm -f -- \"\$installer\"" EXIT; curl -fsSL --proto "=https" --tlsv1.2 https://raw.githubusercontent.com/OnurByte/OmaMonero/main/install.sh -o "$installer"; printf "%s  %s\n" "d61fc48b035dc4dca4cd2baa6237dc8d97ab0d3bf618b1d04a94746344786104" "$installer" | sha256sum --check --status; bash "$installer"'
```

The command downloads `install.sh` into a private temporary file, verifies its
pinned SHA-256 **before running Bash**, then verifies the pinned `v0.3.2` release
archive before opening the native installation panel. If either digest differs,
the install stops. No `sudo`, Rust compiler or administrator password is needed.

The bootstrap digest is intentionally fixed in this README. It must be updated
with every reviewed bootstrap change; it never silently executes a changed
`main/install.sh`. The bundle SHA-256 is also fixed, so the install does not
follow `releases/latest`. Release v0.3.2 points to source commit
`004c7620a0bfdd2bdc4969a738acfed654b7157e`, although that alone does
not prove build provenance.

### Graphical setup

1. Download the [OmaMonero v0.3.2 Linux x86_64 bundle](https://github.com/OnurByte/OmaMonero/releases/download/v0.3.2/omamonero-linux-x86_64.tar.gz).
2. Verify the downloaded archive's SHA-256 against the pinned value below before opening any file inside it. A checksum published alongside the same archive is not an independent trust anchor.
3. Extract the folder and open **Install OmaMonero** or its desktop shortcut. If your file manager asks, choose **Allow Launching / Run**.
4. The existing Omarchy bar opens its native setup panel. Choose whether to show public prices, then click **Install OmaMonero**.

Pinned v0.3.2 archive SHA-256:

```text
b1ea936ff1a0edb254f615f2dc02d3fb9ac61722e40c7a053100d87dba3fff3b
```

The graphical archive does not verify its own download provenance. If your file manager cannot check SHA-256 before launching, use the terminal setup above. A signed graphical distribution is still needed for completely command-free verification.

Both options open OmaMonero's setup inside the existing Omarchy bar. The official
plugin manager installs the frontend and the user service starts only after
you click **Install OmaMonero**. Public market prices remain off until you opt
in. Your bar orientation is preserved; no second dock or settings app is used.

The v0.3.2 release was built and tested on **Omarchy 4.0.6-1, Linux x86_64**.
Other processor architectures require a separately tested release.

## Everyday use

- **Click the bar indicator:** open the chart and node panel.
- **Click the OmaMonero mark in the bar or panel header:** open the in-panel About page with logo, license, maintainer, X, and repository links.
- **Settings tab in the bar panel:** change the node address, price opt-in, or market source. Leave the source URL empty for Kraken, or enter a public HTTPS JSON API and its JSON Pointer fields.
- **Diagnostics / Remove:** both are inside the same native bar panel.
- **Escape:** close the native panel. Tab/arrows and Enter navigate its actions.

## Brand assets

<p align="center">
  <img src="qml/v0_3_6/assets/OmaMonero-logo.svg" alt="OmaMonero orange Monero mark" width="120">
</p>

A local node is optional for the price display. If no node is running, the panel
says so while the price chart continues independently. Nothing starts monerod or
downloads a blockchain automatically.

The **Receive** tab creates a local QR and `monero:` request from a public address
you paste from your wallet. An optional amount and label are supported. You may
opt in to registering `monero:` links with this bar panel; that registration is
reversible during removal. Link previews never send money. **Open Feather** or
**Open Monero GUI** is a separate, explicit action: OmaMonero copies the request
to the clipboard and opens the installed wallet, where you review and confirm it.
It does not pass a payment URI as a wallet send command.

The **Modules** tab provides optional, read-only views for a confirmed watch-only
wallet RPC, local XMRig API and local P2Pool statistics files. These integrations
are off until configured. Wallet RPC must be loopback HTTP and explicitly
confirmed as watch-only; wallet RPC authentication is unsupported. Incoming
history is limited to a recent 720-block window plus the current pool, and that
coverage is shown in the UI. It is not a complete accounting history, and
watch-only wallets cannot always account for outgoing transactions. Payment
proof checks use the configured watch-only RPC and do not access keys or spend.
Notifications are optional and show neither the address nor amount.

## Privacy and prices

Prices are **off until you choose to enable them**. When enabled, the backend
contacts the selected HTTPS market source every two minutes for XMR/USD data.
The default Kraken source provides five-minute candles. Custom sources supply a
JSON response with current price and ordered Unix-second history; source name,
JSON Pointers and the 5/15/30/60-minute sample interval are editable in the
native bar panel. The chart covers the trailing 24 hours with an interpolated
reference. Prices represent the chosen provider, not a global price average.
Source and update time appear in the panel. Stale or unavailable prices are
never shown as current.

The selected provider can see your request IP unless you have configured a supported proxy.
If a Tor/I2P SOCKS policy is configured, market requests use it with remote DNS
and no direct fallback. This covers the RPC/price requests; it does **not** prove
that monerod's P2P traffic uses Tor/I2P. The panel always makes that distinction.

Node monitoring is read-only. The optional wallet adapter connects only to the
explicitly configured local watch-only RPC. No payment is sent, private key is
read or stored, or account login is used. Node status is published in private
local files and shared by all monitor widgets through one backend.

## Remove or repair

Click **XMR** in the bar, open **Settings**, then choose **Remove OmaMonero** and confirm.
The user service stops, the official manager removes the frontend, and installed
program files are removed. Your configuration and additional user files remain.
Removing only the frontend through Omarchy keeps the separately installed backend.

To repair or update this user-only installation, open a matching end-user bundle
and click Install again. The installer refuses to overwrite unrelated or modified
files, checks that the service publishes a fresh heartbeat, and restores previous
files/service state if installation fails.

The normal installation requires no privilege. If a future installer ever needs
system dependencies, only that installation step may use one narrow `pkexec`
authorization. The GUI, daemon and plugin must always run as the desktop user.

## Verification status

**Tested locally; not officially marketplace-verified.** Local manifest validation,
checksums, code review and tests do not grant an Omarchy Verified badge. That
requires an actual marketplace record for the published commit. Checksums detect
a damaged download; obtain releases from a trusted source.

See the [end-user release test record](docs/verification-0.3.2.md),
[persistent product requirements](PRODUCT_REQUIREMENTS.md), and
[publication checklist](docs/publication.md).

For developers: [source build and CLI reference](docs/development.md),
[architecture](docs/architecture.md), and [original v0.1 evidence](docs/verification.md).
Node P2P route verification, authenticated wallet RPC and broader real-world
wallet/mining integration coverage remain outside this release.
