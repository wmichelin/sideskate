"""Engine resolution must honor explicit choices and skip incompatible defaults."""
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import godot


@unittest.skipUnless(os.name == "posix", "POSIX executable fixture")
class EngineResolution(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.folder = Path(self.temporary.name)
        self.old = self.binary(self.folder / "bin/godot4", "4.6.stable.official.test")
        self.supported = self.binary(self.folder / godot.RELEASE / godot.ASSETS["Linux"][2], "4.7.stable.official.test")

    def tearDown(self):
        self.temporary.cleanup()

    def binary(self, path, version):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\nprintf '%s\\n' '" + version + "'\n")
        path.chmod(0o755)
        return path

    def test_wrong_path_version_falls_back_to_pinned_cache(self):
        with patch.dict(os.environ, {"PATH": str(self.old.parent)}, clear=True), patch.object(godot, "CACHE", self.folder), patch("godot.platform.system", return_value="Linux"):
            self.assertEqual(godot.resolve(), str(self.supported))

    def test_explicit_incompatible_engine_is_rejected(self):
        with patch.dict(os.environ, {"GODOT": str(self.old)}, clear=True), patch.object(godot, "CACHE", self.folder):
            with self.assertRaisesRegex(RuntimeError, "4.6"):
                godot.resolve()

    def test_explicit_command_can_resolve_on_path(self):
        selected = self.binary(self.old.parent / "my-godot", "4.7.stable.official.test")
        with patch.dict(os.environ, {"PATH": str(selected.parent), "GODOT": "my-godot"}, clear=True):
            self.assertEqual(godot.resolve(), str(selected))
