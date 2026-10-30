#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY="OnurByte/OmaMonero"
ASSET="omamonero-linux-x86_64.tar.gz"
RELEASE_URL="https://github.com/${REPOSITORY}/releases/latest/download"

if (( EUID == 0 )); then
    printf '%s\n' 'Run OmaMonero setup as your normal desktop user; administrator access is not needed.' >&2
    exit 1
fi

for tool in curl sha256sum python3 mktemp; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required tool not found: %s\n' "$tool" >&2
        exit 1
    fi
done

case "$(uname -m)" in
    x86_64|amd64) ;;
    *) printf 'No OmaMonero release is published for this processor (%s).\n' "$(uname -m)" >&2; exit 1 ;;
esac

work="$(mktemp -d "${TMPDIR:-/tmp}/omamonero-install.XXXXXXXX")"
cleanup() {
    python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' "$work"
}
trap cleanup EXIT

archive="$work/$ASSET"
checksum="$work/$ASSET.sha256"
curl --fail --location --silent --show-error --retry 3 --output "$archive" "$RELEASE_URL/$ASSET"
curl --fail --location --silent --show-error --retry 3 --output "$checksum" "$RELEASE_URL/$ASSET.sha256"
(cd "$work" && sha256sum --check --status "$ASSET.sha256") || {
    printf '%s\n' 'The release archive failed its SHA-256 check. Nothing was installed.' >&2
    exit 1
}

extracted="$work/extracted"
mkdir -m 700 "$extracted"
python3 - "$archive" "$extracted" <<'PY'
import os
from pathlib import Path, PurePosixPath
import shutil
import sys
import tarfile

archive, destination = Path(sys.argv[1]), Path(sys.argv[2]).resolve()
with tarfile.open(archive, "r:gz") as source:
    members = source.getmembers()
    roots = set()
    seen = set()
    total_size = 0
    for member in members:
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or not path.parts:
            raise SystemExit("The release archive contains an unsafe path.")
        if not (member.isdir() or member.isfile()):
            raise SystemExit("The release archive contains a link or special file.")
        roots.add(path.parts[0])
        if member.name in seen:
            raise SystemExit("The release archive contains a duplicate path.")
        seen.add(member.name)
        total_size += member.size
        if total_size > 100 * 1024 * 1024:
            raise SystemExit("The release archive is larger than expected.")
        target = destination.joinpath(*path.parts)
        if not target.resolve().is_relative_to(destination):
            raise SystemExit("The release archive escapes its temporary directory.")
        if member.isdir():
            target.mkdir(parents=True, exist_ok=True, mode=0o700)
            continue
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        payload = source.extractfile(member)
        if payload is None:
            raise SystemExit("The release archive is incomplete.")
        with payload, target.open("xb") as output:
            shutil.copyfileobj(payload, output)
        os.chmod(target, member.mode & 0o777)

if len(roots) != 1:
    raise SystemExit("The release archive must contain one installation folder.")
bundle = destination / next(iter(roots))
installer = bundle / "Install OmaMonero"
if not bundle.is_dir() or not (bundle / "bundle.json").is_file() or not installer.is_file():
    raise SystemExit("The downloaded release is not a complete OmaMonero installer.")
PY

bundle="$(find "$extracted" -mindepth 1 -maxdepth 1 -type d -print -quit)"
python3 "$bundle/Install OmaMonero"
