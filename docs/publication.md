# Omarchy marketplace publication and verification

“Verified” is an Omarchy marketplace status attached to one exact listed plugin
commit. It cannot be added by editing this repository or by passing local tests.
Marketplace checks are not a security audit, endorsement, certification or
guarantee. The backend release asset and the Bash bootstrap are separate from
the QML plugin snapshot and must not be described as marketplace-verified.

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

## Official submission requirements

The official publishing guide asks for a public GitHub repository, a valid root
manifest, README, license and safe install/removal instructions. Submissions go
through its GitHub issue form. The initial listing uses an explicit maintainer
`approved-and-verified` decision after a current automated baseline report and
fresh scan of the exact commit. A passing baseline creates an automatic
commit-bound verification record; eligible selective-review results require a
canonical maintainer attestation. Findings, stale reports, scan failures and
commit drift stay unverified.

This repository's source and install flow must therefore be finalized before
submitting. After the issue is opened, do not push another commit while the
baseline is under review. A newer source commit requires the marketplace's
plugin-update workflow; the old record never covers newer code.

The optional shell bootstrap must be downloaded and checked against the SHA-256
pinned in the reviewed README **before execution**. The bootstrap pins one
explicit release tag and one independent expected archive digest; it must never
execute from a moving branch without that pre-execution check, or download a
moving `latest` release. Each new release requires deliberate digest updates.
The no-terminal graphical path requires independent archive verification before
launch; a signed graphical package is still needed to make that automatic.
An archive checksum is not an authenticity signature, and marketplace status
applies only to the plugin snapshot, not the independently shipped binary.

Current repository: [OnurByte/OmaMonero](https://github.com/OnurByte/OmaMonero).
Submission status is tracked in the linked official marketplace issue once
created. Never display an Omarchy Verified badge until the registry publishes
the matching `listingValidatedCommit` record.

Official references: [Publishing guide](https://plugins.omarchy.org/publish.html),
[marketplace verification rules](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/VERIFICATION.md),
and [submission form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml).
