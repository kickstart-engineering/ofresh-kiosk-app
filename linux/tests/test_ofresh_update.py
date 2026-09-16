from __future__ import annotations

import argparse
import base64
from contextlib import ExitStack
import hashlib
from importlib.machinery import SourceFileLoader
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).parents[1] / "bin" / "ofresh-update"
LOADER = SourceFileLoader("ofresh_update", str(SCRIPT_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC and SPEC.loader
ofresh_update = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ofresh_update)


class Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *_args):
        self.close()


def sha512(data: bytes) -> str:
    return base64.b64encode(hashlib.sha512(data).digest()).decode("ascii")


class OfreshUpdateTest(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        directory = Path(self.temporary_directory.name)
        ofresh_update.APP_PATH = directory / "OfreshKioskApp.AppImage"
        ofresh_update.STAMP_PATH = directory / ".last-update-check"
        ofresh_update.REPOSITORY = "example/ofresh-kiosk"
        ofresh_update.TAG_PREFIX = "fridge-v"

    def tearDown(self):
        self.temporary_directory.cleanup()

    def release_bytes(self, appimage: bytes) -> tuple[bytes, bytes]:
        release = [
            {
                "tag_name": "fridge-v0.1.3",
                "draft": False,
                "prerelease": False,
                "assets": [
                    {
                        "name": "latest-linux.yml",
                        "url": "https://example.test/metadata",
                    },
                    {
                        "name": "OfreshKioskApp-0.1.3.AppImage",
                        "url": "https://example.test/app",
                    },
                ],
            }
        ]
        metadata = f"sha512: {sha512(appimage)}\n".encode()
        return json.dumps(release).encode(), metadata

    def patches(self, appimage: bytes, restart_service: str | None):
        releases, metadata = self.release_bytes(appimage)

        def github_bytes(url: str, *_args):
            return metadata if url == "https://example.test/metadata" else releases

        stack = ExitStack()
        stack.enter_context(
            patch.object(
                ofresh_update,
                "parse_args",
                return_value=argparse.Namespace(
                    force=True,
                    restart_service=restart_service,
                ),
            )
        )
        stack.enter_context(patch.object(ofresh_update, "token", return_value=""))
        stack.enter_context(
            patch.object(ofresh_update, "github_bytes", side_effect=github_bytes)
        )
        urlopen = stack.enter_context(
            patch.object(ofresh_update, "urlopen", return_value=Response(appimage))
        )
        restart = stack.enter_context(patch.object(ofresh_update, "restart_service"))
        return stack, urlopen, restart

    def test_restarts_service_after_installing_a_different_appimage(self):
        new_appimage = b"new AppImage"
        ofresh_update.APP_PATH.write_bytes(b"old AppImage")

        stack, urlopen, restart = self.patches(
            new_appimage,
            "ofresh-kiosk.service",
        )
        with stack:
            self.assertEqual(ofresh_update.main(), 0)

        self.assertEqual(ofresh_update.APP_PATH.read_bytes(), new_appimage)
        self.assertTrue(ofresh_update.STAMP_PATH.is_file())
        urlopen.assert_called_once()
        restart.assert_called_once_with("ofresh-kiosk.service")

    def test_does_not_restart_service_when_appimage_is_current(self):
        current_appimage = b"current AppImage"
        ofresh_update.APP_PATH.write_bytes(current_appimage)

        stack, urlopen, restart = self.patches(
            current_appimage,
            "ofresh-kiosk.service",
        )
        with stack:
            self.assertEqual(ofresh_update.main(), 0)

        self.assertTrue(ofresh_update.STAMP_PATH.is_file())
        urlopen.assert_not_called()
        restart.assert_not_called()


if __name__ == "__main__":
    unittest.main()
