# Production publication gate

The local 0.3.1 bundle is a tested end-user candidate. This document does not
claim marketplace acceptance, certification or a third-party security audit.

## Complete locally

- Prebuilt x86_64 user-only installer, with affirmative Install action and
  separate optional public-price consent; no terminal or elevation.
- Native upper-bar widget, sparkline, 24-hour USD chart and graphical management.
- Local receive QR/payment links, opt-in monero: association, explicit wallet
  launch, a bounded link preview queue and proof input.
- Opt-in watch-only wallet, XMRig and P2Pool read-only modules with truthful
  history/availability limits.
- Official add/update/enable/remove integration; versioned QML directories avoid
  stale component caches during updates in the existing shell.
- Integrity manifest, atomic file rollback, saved service state, service heartbeat
  readiness, unmanaged-file protection and concurrent-install lock.
- Reviewed and tested typed RPC/market data, privacy boundaries and stale states.
- Monero address/network/checksum validation and local QR encoding; incoming
  links persist independently of install progress, including while that job lock
  is held. Handler removal verifies restoration before deleting its launcher.

## Required before calling the public release Verified

1. Publish the actual source in the owner's chosen public GitHub repository.
   No repository or public message has been created automatically.
2. Run GitHub CI on the exact commit, attach the tested binary/end-user archives
   and checksums to its release, and bind download provenance to that commit.
3. Supply independently verifiable release signatures/provenance and establish
   trusted distribution. An editable checksum manifest is not authentication.
4. Submit the repository, manifest, README, license, preview and truthful external
   access/installer disclosures through the official marketplace submission flow.
5. Obtain the marketplace's exact-commit verification record/maintainer decision.
   Do not add a Verified badge before that record exists; do not imply it covers
   the separately distributed backend binary unless the actual review does.
6. Complete fresh-machine install/repair/removal, additional monitor/scale/theme,
   suspend/resume and real monerod/proxy integration acceptance testing. Sign off
   each supported architecture and Omarchy version separately.

Official references:
[Publishing](https://plugins.omarchy.org/publish.html) and
[commit-bound verification](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/VERIFICATION.md).
Marketplace verification is a separate trust boundary from installation and is
not a security audit or guarantee. The local installer and UI explicitly say
that this candidate has not received official marketplace verification.
