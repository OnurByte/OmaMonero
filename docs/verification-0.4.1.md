# OmaMonero 0.4.1 runtime-path correction

The 0.4.0 live installation exposed a gap in the earlier lifecycle check: the test checked widget presence, not completed native initialization. Long-running Quickshell can resolve external plugin resources through a `qs:` URL. Passing that URL directly as a filesystem path prevents the native helper from launching.

The stronger readiness check also reproduced legacy TOML migration failures caused by dependency built-ins absent in QML. The generated bundle now downlevels Object.hasOwn and underscore replaceAll calls without modifying host globals, and tests generated code with those built-ins and BigInt absent.

0.4.1 converts local `file:` and `qs:` URLs to decoded absolute filesystem paths, rejects foreign authorities/control bytes, and exposes widget readiness to the host. The official-manager lifecycle test now requires completed native settings initialization. Offline bar text remains compact and the detailed status stays in the panel/tooltip.

Validation: 49 strict TypeScript/core/transport/QR/path tests, 6 display/settings regressions, 6 native lifecycle tests, native Qt/Wayland fixture checks, official manager lifecycle, QML lint and official archive validation. URL cases include percent-encoded spaces, qs:/, qs:///, file:///, foreign authorities and null bytes. The URL tests were observed failing before the conversion fix.

Marketplace status remains external and commit-bound. No local test or release tag claims marketplace verification. The 0.4.0 helper-launch claims are superseded by this correction; see the explicit note in verification-0.4.0.md.
