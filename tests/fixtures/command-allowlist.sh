# Test instrumentation only. This is a regression guard, not a runtime sandbox.
# Assignment-only commands may contain quoted spaces or nested substitutions.
_oma_single_word() {
  local value=$1 quote='' escaped=0 depth=0 braces=0 c i
  for ((i=0;i<${#value};i++)); do
    c=${value:i:1}
    if [[ $escaped == 1 ]]; then escaped=0;continue;fi
    if [[ $c == '\' && $quote != "'" ]]; then escaped=1;continue;fi
    if [[ -n $quote ]]; then [[ $c != "$quote" ]] || quote='';continue;fi
    case "$c" in
      \"|\') quote=$c ;;
      '(') depth=$((depth+1)) ;;
      ')') depth=$((depth-1)) ;;
      '{') braces=$((braces+1)) ;;
      '}') braces=$((braces-1)) ;;
      ' '|$'\t'|$'\n') [[ $depth != 0 || $braces != 0 ]] || return 1 ;;
    esac
  done
  [[ -z $quote && $depth == 0 && $braces == 0 ]]
}
_oma_check_command() {
  local cmd=$1 head=${1%%[[:space:]]*} rest
  local fd_pattern='^[0-9]+>[[:space:]]*"[^"]*"$'
  if [[ $cmd =~ ^[a-zA-Z_][a-zA-Z_0-9]*= ]] && _oma_single_word "$cmd";then return 0;fi
  if [[ $head == exec ]];then
    rest=${cmd#exec };head=${rest%%[[:space:]]*}
    if [[ $rest =~ $fd_pattern ]];then return 0;fi
    case "$head" in feather|monero-wallet-gui) return 0 ;; esac
  else
    case "$head" in
      set|umask|'[['|private_dir|mkdir|chmod|case|printf|stat|dd|exit|xdg-mime|cp|dirname|touch|trap|cat|for|mktemp|awk|mv|rm|omarchy|continue|flock|date|tail|notify-send|true) return 0 ;;
    esac
  fi
  printf 'Unreviewed command rejected: %s\n' "$head" >&2
  exit 97
}
set -T
trap '_oma_check_command "$BASH_COMMAND"' DEBUG
