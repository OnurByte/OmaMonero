# Local verification record — 0.3.2

This record covers the source pushed for 0.3.2. It does not claim a public
binary release or Omarchy marketplace verification.

## Checks completed

- `cargo test --locked`: all 38 backend, market, module and payment tests passed.
- `python3 -m unittest discover -s tests -p 'installer_test.py'`: 26 tests passed.
- `node --test tests/status.test.cjs`: 13 tests passed.
- `python3 scripts/lint-qml.py`: QML lint passed without warnings.
- `python3 scripts/test-qml-runtime.py`: native Quickshell runtime passed,
  including chart axis fit at 300 px and 140 px.
- `python3 scripts/check-contract.py`: Cargo, lockfile, manifest and package
  versions agree at 0.3.2.
- `omarchy plugin validate .`: accepted by the installed Omarchy plugin
  validator.
- Public custom sources accept credential-free HTTPS JSON endpoints, bounded
  JSON Pointers and 5/15/30/60-minute Unix-second samples. Invalid pointers,
  short histories, unsafe prices, redirects, HTTP errors and oversized bodies
  do not produce a ready quote.

## Limits

The host provides `rustfmt` and `clippy-driver`, but not Cargo's `cargo-fmt` or
`cargo-clippy` wrappers. All Rust files passed direct `rustfmt --check`; the
workspace passed Clippy through `clippy-driver` with warnings denied. GitHub CI
uses the standard wrappers as an independent check. A local end-user bundle
was built, but none has been published as a GitHub release for this source
revision. The repository is not officially marketplace-verified;
that status requires an actual Omarchy registry record for the shipped commit.
