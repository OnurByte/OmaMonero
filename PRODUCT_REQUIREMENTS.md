# OmaMonero — binding end-user requirements

Recorded from the user's instruction on 2026-10-30. These requirements apply to
future work and override developer-oriented installation instructions.

- This is a production-oriented end-user product. Users must not type commands,
  compile Rust, edit configuration files or manually start services to install it.
- Ship a graphical, clickable installer with a prebuilt, architecture-matching
  binary. Prefer user-only installation requiring no administrator privilege.
- If system changes ever require privilege, use `pkexec` only during installation,
  at most one authorization flow. Never use sudo or elevate the GUI, daemon,
  shell plugin or routine operation.
- Respect the official Omarchy plugin manager, native components and
  enable/disable/update/remove lifecycle. Never edit packaged Omarchy sources or
  implement a second desktop shell/dock.
- Put the clickable Monero widget in the existing upper bar/dock area. Respect
  the user's chosen bar orientation; do not move the whole bar to force this.
- Show a compact XMR/USD sparkline and trailing 24-hour percentage change in the
  upper bar, with a detailed chart and node information on click. USD/24h was
  explicitly confirmed by the user.
- Explain external market requests in the installer and require an explicit
  choice. Default config remains local-only. Price requests must respect a
  selected proxy policy and never silently bypass it.
- Distinguish tested compatibility and checksums from official Omarchy
  marketplace verification. Never claim Verified or production certification
  without an actual registry record bound to the shipped commit.
- Keep stale/unavailable data explicit. Never fabricate prices, changes, node
  status, verification badges or successful installation.
- Receive QR/payment requests are created locally from a public address only.
  Incoming `monero:` links must open a preview without sending a payment or
  reading keys. Persist incoming previews outside setup-job progress, queue them
  with a bounded private session history, and preserve them across UI reloads.
- Wallet launch is explicit; pass no payment URI as an auto-send instruction.
  Copy the request for the user to review inside their wallet.
- The installed URI handler must be restored and verified before its launcher
  file can be removed. If restoration fails, retain the owned files and receipt
  so removal can be retried safely.

## Explicit native-only correction (2026-10-30)

The user rejected GNOME/Zenity dialogs, a separate settings application and the
custom icon. All setup, settings, diagnostics and removal must live inside the
existing Omarchy bar/panel using qs.Ui. No Zenity, GTK settings windows, desktop
settings app, custom dock or fabricated icon. A clickable downloaded launcher
may bootstrap the native bar panel, but it must not open another GUI toolkit.
Use a simple XMR text/sparkline indicator and native text controls. Explicit
helper jobs are detached so plugin reload/removal cannot kill their own action;
private FileView state carries progress, without subprocess polling.

## Branding and window correction
Use the user-supplied OmaMonero-logo.svg unchanged. Trend colors are red for negative, green for positive, and gray for exactly flat movement, independent of theme accent; keep the XMR label white. Never open a blank/white standalone Quickshell window. Test engines must have a QtObject root, not a top-level Item that the host could wrap in a visible window.
