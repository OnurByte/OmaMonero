#!/usr/bin/env bash
set -Eeuo pipefail

# Deprecated standalone bootstrap. The v0.3.2 release bundle contains a QML
# request path that exposes private receive/link/proof data in process arguments.
# Do not download, extract, or execute that release from this entrypoint.
printf '%s\n' \
  'The standalone OmaMonero installer has been disabled for privacy reasons.' \
  'The old v0.3.2 bundle can expose private payment details in process listings.' \
  '' \
  'Install the current Omarchy plugin instead:' \
  '  omarchy plugin add https://github.com/OnurByte/OmaMonero.git --enable' \
  'Then open XMR -> Settings -> Install OmaMonero in the Omarchy bar.' >&2
exit 1
