#!/bin/bash
# Small explicit OS integrations only. All product logic lives in TypeScript.
set -euo pipefail
umask 077
config="${XDG_CONFIG_HOME:-$HOME/.config}/omamonero"
data="${XDG_DATA_HOME:-$HOME/.local/share}/omamonero/native"
runtime="${XDG_RUNTIME_DIR:?}/omamonero-native"
private_dir() {
  [[ ! -L $1 ]] || exit 1
  mkdir -p -- "$1"
  [[ -O $1 && -d $1 ]] || exit 1
  chmod 700 -- "$1"
}
private_dir "$config"; private_dir "$data"; private_dir "$runtime"
case "${1:-}" in
init)
  printf '{"state":"ready"}\n'
  ;;
p2pool)
  file="${2:?}/local/stratum"
  [[ -f $file && ! -L $file && $(stat -c %s -- "$file") -le 524288 ]] || exit 1
  stat -c %Y -- "$file"
  dd if="$file" iflag=nofollow,nonblock bs=524289 count=1 status=none
  ;;
wallet)
  case "${2:-}" in feather) exec feather ;; monero_gui) exec monero-wallet-gui ;; *) exit 1 ;; esac
  ;;
register-uri)
  apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p -- "$apps"
  desktop="$apps/omamonero-native-uri.desktop"
  [[ ! -L $desktop && ! -L $data/uri-handler.sh ]] || exit 1
  if [[ ! -f $data/uri-owned ]]; then
    xdg-mime query default x-scheme-handler/monero > "$data/previous-handler"
    cp -- "$(dirname -- "$0")/uri-handler.sh" "$data/uri-handler.sh"
    chmod 700 "$data/uri-handler.sh"
    # The desktop parser needs quoting independently of shell quoting.
    escaped=${data//\\/\\\\}; escaped=${escaped//\"/\\\"}; escaped=${escaped//\`/\\\`}; escaped=${escaped//\$/\\\$}; escaped=${escaped//%/%%}
    printf '[Desktop Entry]\nType=Application\nName=OmaMonero payment preview\nNoDisplay=true\nExec="%s/uri-handler.sh" %%u\nMimeType=x-scheme-handler/monero;\nTerminal=false\n' "$escaped" > "$desktop"
    touch "$data/uri-owned"
  fi
  xdg-mime default omamonero-native-uri.desktop x-scheme-handler/monero
  [[ $(xdg-mime query default x-scheme-handler/monero) == omamonero-native-uri.desktop ]] || exit 1
  printf '{"uri_handler":true}\n'
  ;;
remove)
  trap 'printf "{\"state\":\"error\",\"message\":\"Removal failed; owned URI handler files and receipt were retained for retry.\"}\n" > "$runtime/native-job.json"' ERR
  printf '{"state":"running"}\n' > "$runtime/native-job.json"
  # Restore and verify before deleting any owned handler file or plugin.
  if [[ -f $data/uri-owned ]]; then
    current=$(xdg-mime query default x-scheme-handler/monero)
    previous=$(cat "$data/previous-handler")
    if [[ $current == omamonero-native-uri.desktop ]]; then
      if [[ -n $previous && $previous != omamonero-native-uri.desktop ]]; then
        xdg-mime default "$previous" x-scheme-handler/monero
      else
        # Remove only our exact association; preserve unrelated MIME defaults.
        for list in "${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/mimeapps.list"; do
          [[ -f $list && ! -L $list ]] || continue
          tmp=$(mktemp "${list}.XXXXXX")
          awk '/^x-scheme-handler\/monero=/{gsub(/omamonero-native-uri\.desktop;?/, ""); if ($0 == "x-scheme-handler/monero=") next} {print}' "$list" > "$tmp"
          mv -f -- "$tmp" "$list"
        done
      fi
      restored=$(xdg-mime query default x-scheme-handler/monero)
      [[ $restored != omamonero-native-uri.desktop && ( -z $previous || $restored == "$previous" ) ]]
    fi
    rm -f -- "${XDG_DATA_HOME:-$HOME/.local/share}/applications/omamonero-native-uri.desktop" "$data/uri-handler.sh" "$data/uri-owned" "$data/previous-handler"
  fi
  # This job was detached by Quickshell; plugin removal cannot kill its own action.
  omarchy plugin remove io.github.onurbyte.omamonero --yes
  printf '{"state":"done"}\n' > "$runtime/native-job.json"
  ;;
*) exit 1 ;;
esac
