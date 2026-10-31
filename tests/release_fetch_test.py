"""The native setup must verify a GitHub release before unpacking it."""
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "installer"))
import engine
import release_fetch


ASSET = "omamonero-0.3.6-linux-x86_64.tar.gz"
URL = "https://github.com/OnurByte/OmaMonero/releases/download/v0.3.6/" + ASSET


def archive_bytes():
    content = {
        "payload/omamonero-core": b"prebuilt",
        "payload/omamonero.service": b"ExecStart=/usr/bin/omamonero-core daemon\n",
        "payload/plugin/manifest.json": json.dumps({"id": engine.PLUGIN_ID, "schemaVersion": 1, "version": "0.3.6"}).encode(),
    }
    metadata = {"version": "0.3.6", "architecture": engine.machine(), "files": {name: hashlib.sha256(data).hexdigest() for name, data in content.items()}}
    content["bundle.json"] = json.dumps(metadata).encode()
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w:gz") as archive:
        for name, data in content.items():
            item = tarfile.TarInfo("omamonero-0.3.6-linux-x86_64/" + name)
            item.size = len(data)
            archive.addfile(item, io.BytesIO(data))
    return output.getvalue()


class Response(io.BytesIO):
    def __init__(self, content, url):
        super().__init__(content)
        self.url = url

    def geturl(self):
        return self.url


class ReleaseDownloadTests(unittest.TestCase):
    def make_opener(self, archive, digest):
        def open_url(request, timeout=30):
            url = request.full_url
            if url == URL:
                return Response(archive, URL)
            if url == "https://api.github.com/repos/OnurByte/OmaMonero/releases/tags/v0.3.6":
                metadata = {"tag_name": "v0.3.6", "assets": [{"name": ASSET, "size": len(archive), "digest": "sha256:" + digest, "browser_download_url": URL}]}
                return Response(json.dumps(metadata).encode(), url)
            raise AssertionError("unexpected URL: " + url)
        return open_url

    def test_matching_release_is_verified_before_extraction(self):
        archive = archive_bytes()
        with tempfile.TemporaryDirectory() as location:
            bundle = release_fetch.download_verified_release("0.3.6", Path(location), self.make_opener(archive, hashlib.sha256(archive).hexdigest()))
            self.assertEqual(engine.verify_bundle(bundle)["version"], "0.3.6")

    def test_changed_release_archive_is_rejected(self):
        archive = archive_bytes()
        with tempfile.TemporaryDirectory() as location:
            with self.assertRaisesRegex(engine.InstallError, "digest"):
                release_fetch.download_verified_release("0.3.6", Path(location), self.make_opener(archive, "0" * 64))
            self.assertFalse(list(Path(location).rglob("omamonero-core")))


if __name__ == "__main__":
    unittest.main()
