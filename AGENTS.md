# OmaMonero product rules

Read PRODUCT_REQUIREMENTS.md before changing this project. It records explicit
user preferences that apply across future sessions.

End users install, configure, diagnose and remove through a graphical interface,
without typing commands. Prefer user-only installation. If privilege is ever
required, use one narrow pkexec operation during installation; never sudo and
never elevate the GUI, daemon or plugin. Use the official Omarchy plugin manager
and native upper-bar/popup components. Do not invent marketplace verification:
Verified requires an actual record for the shipped commit. External XMR/USD prices and the 24h chart are enabled by default by the user's explicit 2026-11-01 correction. Keep truthful freshness/source, a simple pause control, and fail-closed configured proxies.

All user flows must remain inside the existing Omarchy bar/panel. No Zenity/GTK dialogs, standalone settings app or custom icon; the user explicitly rejected those.

Use the user-supplied orange Monero artwork for branding; the ban is on fabricated/replacement icons. Qt's SVG renderer cannot render its original clipPath, so an equivalent path-flattened SVG preserves the visible design. Red denotes negative market change, green denotes zero/positive change, and the XMR label stays white.
