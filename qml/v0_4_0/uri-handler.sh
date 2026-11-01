#!/bin/bash
# The OS supplies the URI once. Never forward it to another process's argv.
set -euo pipefail
umask 077
uri=${1:-}
[[ $uri == monero:* && ${#uri} -le 2048 && $uri != *$'\n'* && $uri != *$'\r'* && $uri != *$'\t'* ]] || exit 1
runtime="${XDG_RUNTIME_DIR:?}/omamonero-native"
[[ ! -L $runtime ]] || exit 1
mkdir -p -- "$runtime"
[[ -O $runtime && -d $runtime ]] || exit 1
chmod 700 "$runtime"
exec 9>"$runtime/inbox.lock"
flock 9
stamp=$(date +%s%N)
tmp=$(mktemp "$runtime/.inbox.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
if [[ -f $runtime/inbox && ! -L $runtime/inbox ]]; then tail -n 19 -- "$runtime/inbox" > "$tmp"; fi
printf '%s\t%s\n' "$stamp" "$uri" >> "$tmp"
mv -f -- "$tmp" "$runtime/inbox"
# A generic native notification; no amount, address or payment data in argv.
notify-send -a OmaMonero 'Payment link received' 'Open OmaMonero in the bar to review it. No payment was sent.' || true
