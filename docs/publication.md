# 0.4.0 publication handoff

This candidate is a native TypeScript/QML plugin. It has no Rust backend, Python installer, service binary or separate setup step. The exact shipped archive is `dist/omamonero-plugin-0.4.0.tar.gz`, with SHA-256 in `dist/SHA256SUMS`.

Local evidence: strict TypeScript and behavior/security tests, real curl proxy/redirect/response-bound tests, native lifecycle tests, a real Wayland Quickshell QtObject-root integration harness and the official Omarchy validator against the packaged archive. See `verification-0.4.0.md` for current results.

Still required before calling the whole release plan accepted:

1. Publish the reviewed 0.4.0 commit to the repository/release.
2. Test the official graphical plugin manager install and update against that exact published commit in a clean Omarchy session. The isolated QML harness is not a claim that this external lifecycle has already passed.
3. Submit that exact commit for marketplace update/review and request reevaluation of Manual setup, since no separate backend setup is required anymore.
4. Record the maintainers' actual decision and commit-bound verification record. Only then describe that commit as marketplace verified or say that Manual setup was removed.

Do not claim that local checksums, test results or a valid manifest are marketplace approval. Do not remove or invent marketplace status locally. Existing 0.3.x evidence documents are historical.

## Prepared update text

OmaMonero 0.4.0 replaces its separate Rust daemon and Python installer with strict TypeScript compiled into committed QML-compatible JavaScript. The standard Omarchy plugin installation supplies the widget, settings and all read-only features directly; users need no OmaMonero binary, systemd service, npm or manual build/setup. External market prices remain explicit opt-in. Wallet and mining integrations are optional. Please reevaluate the Manual setup designation for the submitted commit after your normal review. No Verified status is claimed by this submission.

Official review entrypoint: [Omarchy plugin marketplace](https://github.com/omacom/omarchy-plugin-marketplace).
