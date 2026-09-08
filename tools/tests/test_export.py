"""Fresh export promotion and failure recovery at the external engine boundary."""
import argparse
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check


class ExportPromotion(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.destination = self.root / "build/html5"
        self.destination.mkdir(parents=True)
        self.original = {"index." + suffix: "old-" + suffix for suffix in ("html", "js", "wasm", "pck")}
        self.original["obsolete-debug.txt"] = "obsolete"
        for name, contents in self.original.items():
            (self.destination / name).write_text(contents)
        (self.root / "export").mkdir()
        (self.root / "export/html5_prod.cfg").write_text("production preset")
        self.preset = self.root / "export_presets.cfg"
        self.preset.write_text("user preset\n")
        self.templates = self.root / "templates"
        self.templates.mkdir()
        (self.templates / "web_nothreads_release.zip").touch()
        self.mode = "success"
        self.audit_calls = 0

    def tearDown(self):
        self.temporary.cleanup()

    def files(self, directory=None):
        return {path.name: path.read_text() for path in (directory or self.destination).iterdir()}

    def engine(self, command, log, timeout, env):
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text("")
        if "--export-release" in command:
            self.assertEqual(self.preset.read_text(), "production preset")
            output = Path(command[-1]).parent
            self.assertNotEqual(output, self.destination)
            if self.mode == "timeout":
                raise RuntimeError("Timed out")
            for suffix in ("html",) if self.mode == "partial" else ("html", "js", "wasm", "pck"):
                (output / ("index." + suffix)).write_text("new-" + suffix)
            if self.mode == "empty":
                (output / "index.wasm").write_text("")
            if self.mode == "export_diagnostic":
                log.write_text("SCRIPT ERROR: exporter failed\n")
            return 1 if self.mode == "export_exit" else 0
        self.audit_calls += 1
        self.assertEqual(Path(command[-2]).read_text(), "new-pck")
        if self.destination.exists():
            self.assertEqual(self.files(), self.original, "Old build changed before package validation")
        if self.mode == "audit_timeout":
            raise RuntimeError("Audit timed out")
        failed = self.mode == "audit_report"
        report = {"completed": True, "check_count": 1, "failed": int(failed), "errors": [], "checks": [{"ok": not failed}]}
        Path(command[-1]).write_text(json.dumps(report))
        if self.mode == "audit_diagnostic":
            log.write_text("ERROR: package read failed\n")
        return 1 if self.mode == "audit_exit" else 0

    def export(self):
        with patch.object(check, "ROOT", self.root), \
                patch.object(check.godot, "template_dir", return_value=self.templates), \
                patch.object(check, "run", side_effect=self.engine):
            return check.export_web("godot", self.root / "reports", argparse.Namespace(timeout=1), {})

    def assert_preserved(self):
        self.assertEqual(self.files(), self.original)
        self.assertEqual(self.preset.read_text(), "user preset\n")
        self.assertEqual(sorted(path.name for path in self.destination.parent.iterdir()), [".gdignore", "html5"])

    def test_success_replaces_whole_build_and_removes_obsolete_files(self):
        self.assertEqual(self.export(), self.destination)
        self.assertEqual(self.files(), {"index." + suffix: "new-" + suffix for suffix in ("html", "js", "wasm", "pck")})
        self.assertEqual(self.audit_calls, 1)
        self.assertEqual(self.preset.read_text(), "user preset\n")
        self.assertEqual(sorted(path.name for path in self.destination.parent.iterdir()), [".gdignore", "html5"])

    def test_first_export_does_not_leave_a_generated_user_preset(self):
        for path in self.destination.iterdir():
            path.unlink()
        self.destination.rmdir()
        self.preset.unlink()
        self.assertEqual(self.export(), self.destination)
        self.assertEqual((self.destination / "index.pck").read_text(), "new-pck")
        self.assertFalse(self.preset.exists())

    def test_export_failures_cannot_use_stale_files_or_replace_previous_build(self):
        for self.mode in ("partial", "empty", "export_exit", "export_diagnostic", "timeout"):
            with self.subTest(mode=self.mode), self.assertRaises(RuntimeError):
                self.export()
            self.assert_preserved()
        self.assertEqual(self.audit_calls, 0)

    def test_package_audit_failures_preserve_previous_build(self):
        for self.mode in ("audit_report", "audit_exit", "audit_diagnostic", "audit_timeout"):
            with self.subTest(mode=self.mode), self.assertRaises(RuntimeError):
                self.export()
            self.assert_preserved()

    def test_promotion_failure_restores_previous_build(self):
        rename = Path.rename

        def fail_promotion(source, target):
            if source != self.destination and source.name == "html5":
                raise OSError("promotion failed")
            return rename(source, target)

        with patch.object(Path, "rename", fail_promotion), self.assertRaisesRegex(OSError, "promotion failed"):
            self.export()
        self.assert_preserved()

    def test_failed_rollback_keeps_recoverable_previous_build(self):
        rename = Path.rename

        def fail_promotion_and_rollback(source, target):
            if source != self.destination:
                raise OSError("filesystem failure")
            return rename(source, target)

        with patch.object(Path, "rename", fail_promotion_and_rollback), self.assertRaisesRegex(RuntimeError, "previous build preserved at"):
            self.export()
        backups = list(self.destination.parent.glob("*/previous"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(self.files(backups[0]), self.original)
        self.assertEqual(self.preset.read_text(), "user preset\n")


if __name__ == "__main__":
    unittest.main()
