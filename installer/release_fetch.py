"""Fetch a matching prebuilt release; never execute downloaded installer code."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import re
import shutil
import tarfile
from urllib.parse import urlsplit
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

import engine

REPOSITORY = "OnurByte/OmaMonero"
MAX_ARCHIVE_BYTES = 25 * 1024 * 1024
MAX_CONTENT_BYTES = 100 * 1024 * 1024


def download_verified_release(version: str, directory: Path, opener=urlopen) -> Path:
    """Download, hash-check and safely extract the exact plugin version."""
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise engine.InstallError("Invalid plugin release version.")
    if engine.machine() != "x86_64":
        raise engine.InstallError("No prebuilt OmaMonero release is available for this processor.")
    tag = "v" + version
    filename = f"omamonero-{version}-linux-x86_64.tar.gz"
    download_url = f"https://github.com/{REPOSITORY}/releases/download/{tag}/{filename}"
    api_url = f"https://api.github.com/repos/{REPOSITORY}/releases/tags/{tag}"
    request_headers = {"Accept": "application/vnd.github+json", "User-Agent": "OmaMonero-native-installer"}
    directory = Path(directory)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    try:
        with opener(Request(api_url, headers=request_headers), timeout=30) as response:
            metadata = json.loads(response.read(512 * 1024 + 1))
        if metadata.get("tag_name") != tag:
            raise engine.InstallError("GitHub returned a different release version.")
        assets = [asset for asset in metadata.get("assets", []) if asset.get("name") == filename]
        if len(assets) != 1 or assets[0].get("browser_download_url") != download_url:
            raise engine.InstallError("The matching prebuilt release is not published yet.")
        asset = assets[0]
        digest = asset.get("digest", "")
        if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            raise engine.InstallError("The release has no valid SHA-256 digest.")
        if not isinstance(asset.get("size"), int) or not (0 < asset["size"] <= MAX_ARCHIVE_BYTES):
            raise engine.InstallError("The release archive size is invalid.")
        archive_path = directory / filename
        hasher = hashlib.sha256()
        size = 0
        with opener(Request(download_url, headers=request_headers), timeout=90) as response:
            final_url = urlsplit(response.geturl())
            if final_url.scheme != "https" or not (final_url.hostname == "github.com" or final_url.hostname == "release-assets.githubusercontent.com"):
                raise engine.InstallError("The download redirected outside trusted GitHub HTTPS hosts.")
            with archive_path.open("xb") as output:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    size += len(chunk)
                    if size > MAX_ARCHIVE_BYTES:
                        raise engine.InstallError("The release archive exceeds its size limit.")
                    hasher.update(chunk)
                    output.write(chunk)
        if size != asset["size"] or hasher.hexdigest() != digest[7:]:
            raise engine.InstallError("The GitHub release archive digest did not match. Nothing was installed.")

        extracted = directory / "extracted"
        extracted.mkdir(mode=0o700)
        total = 0
        roots = set()
        seen = set()
        with tarfile.open(archive_path, "r:gz") as archive:
            members = archive.getmembers()
            if len(members) > 500:
                raise engine.InstallError("The release archive contains too many files.")
            for member in members:
                name = PurePosixPath(member.name)
                if name.is_absolute() or ".." in name.parts or not name.parts or member.name in seen:
                    raise engine.InstallError("The release archive contains an unsafe path.")
                if not (member.isfile() or member.isdir()):
                    raise engine.InstallError("The release archive contains a link or special file.")
                seen.add(member.name)
                roots.add(name.parts[0])
                total += member.size
                if total > MAX_CONTENT_BYTES:
                    raise engine.InstallError("The release expands beyond its size limit.")
                path = extracted.joinpath(*name.parts)
                if not path.resolve().is_relative_to(extracted):
                    raise engine.InstallError("The release contains a path outside its folder.")
                if member.isdir():
                    path.mkdir(parents=True, exist_ok=True, mode=0o700)
                else:
                    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                    with archive.extractfile(member) as source, path.open("xb") as output:
                        shutil.copyfileobj(source, output)
        if len(roots) != 1:
            raise engine.InstallError("The release has an invalid folder layout.")
        bundle = extracted / next(iter(roots))
        if engine.verify_bundle(bundle).get("version") != version:
            raise engine.InstallError("The downloaded backend version does not match this plugin.")
        return bundle
    except (HTTPError, URLError, TimeoutError, OSError, ValueError, tarfile.TarError) as error:
        raise engine.InstallError("Unable to download or verify the matching GitHub release.") from error
