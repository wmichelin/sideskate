"""Regression checks for false success, incomplete reports and process timeouts."""
import json
import argparse
from pathlib import Path
import os
import signal
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check


class CheckFailures(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.folder = Path(self.temporary.name)
        self.report = self.folder / "report.json"

    def tearDown(self):
        self.temporary.cleanup()

    def test_zero_exit_without_report_is_failure(self):
        code = check.run([sys.executable, "-c", "pass"], self.folder / "engine.log", 2, os.environ.copy())
        self.assertEqual(code, 0)
        with self.assertRaisesRegex(RuntimeError, "completion report"):
            check.validate_report(self.report)

    def test_incomplete_empty_or_failed_report_is_failure(self):
        for report in [
            {},
            {"completed": False, "check_count": 1},
            {"completed": True, "check_count": 0},
            {"completed": True, "check_count": 1, "failed": 1},
            {"completed": True, "check_count": 1, "errors": ["script aborted"]},
            {"completed": True, "check_count": 1, "checks": [{"ok": False}]},
            {"completed": True, "check_count": 2, "failed": 0, "errors": [], "checks": [{"ok": True}]},
            {"completed": True, "check_count": True, "failed": 0, "errors": [], "checks": [{"ok": True}]},
        ]:
            with self.subTest(report=report):
                self.report.write_text(json.dumps(report))
                with self.assertRaises(RuntimeError):
                    check.validate_report(self.report)

    def test_logged_script_failure_is_not_a_success_exit(self):
        log = self.folder / "engine.log"
        code = check.run([sys.executable, "-c", "print('SCRIPT ERROR: Invalid call')"], log, 2, os.environ.copy())
        self.assertEqual(code, 0)
        self.assertEqual(check.log_errors(log), ["SCRIPT ERROR: Invalid call"])

    def test_expected_parser_errors_do_not_hide_other_errors(self):
        log = self.folder / "engine.log"
        log.write_text("ERROR: Malformed level 'bad':\nERROR: Other problem\nWARNING: AirSolver invariant: penetration\nWARNING: V-Sync fallback\n")
        self.assertEqual(check.log_errors(log, ["Malformed level 'bad':\nrow 2"]), ["ERROR: Other problem", "WARNING: AirSolver invariant: penetration"])

    def test_hung_process_has_bounded_failure(self):
        started = time.monotonic()
        with self.assertRaisesRegex(RuntimeError, "Timed out"):
            check.run([sys.executable, "-c", "import time; time.sleep(20)"], self.folder / "engine.log", .1, os.environ.copy())
        self.assertLess(time.monotonic() - started, 3)

    def test_browser_timeout_can_finish_failure_report_before_supervisor_cleanup(self):
        (self.folder / "tools/browser/node_modules/playwright").mkdir(parents=True)
        report_path = self.folder / "web/report.json"
        report_path.parent.mkdir()
        failure = {"completed": True, "check_count": 1, "failed": 0,
                   "checks": [{"ok": True}], "errors": ["Browser smoke timed out"]}
        # Simulate the browser writing diagnostics after its workload deadline.
        # The outer supervisor must permit this, and still reject the report.
        child = "import pathlib,sys,time; time.sleep(.05); pathlib.Path(sys.argv[1]).write_text(sys.argv[2]); sys.exit(1)"
        real_run = check.run

        def browser_timeout(command, log, timeout, env):
            workload = int(command[command.index("--timeout") + 1]) / 1000
            self.assertGreater(timeout, workload)
            self.assertLessEqual(timeout - workload, 30)
            return real_run([sys.executable, "-c", child, str(report_path), json.dumps(failure)], log, timeout, env)

        with patch.object(check, "ROOT", self.folder), \
                patch.object(check, "export_web", return_value=self.folder), \
                patch.object(check.shutil, "which", return_value="node"), \
                patch.object(check, "run", side_effect=browser_timeout):
            with self.assertRaisesRegex(RuntimeError, "Checks failed"):
                check.web("godot", self.folder, argparse.Namespace(timeout=.01), os.environ.copy())
        self.assertEqual(json.loads(report_path.read_text())["errors"], failure["errors"])

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux process-state check")
    def test_timeout_stops_descendant_after_leader_exits(self):
        pid_file = self.folder / "child.pid"
        child = "import os,signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); open(os.environ['CHILD_PID_FILE'],'w').write(str(os.getpid())); time.sleep(30)"
        parent = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c',sys.argv[1]]); time.sleep(30)"
        env = os.environ.copy()
        env["CHILD_PID_FILE"] = str(pid_file)
        pid = None
        try:
            with self.assertRaisesRegex(RuntimeError, "Timed out"):
                check.run([sys.executable, "-c", parent, child], self.folder / "engine.log", .5, env)
            pid = int(pid_file.read_text())
            state = Path(f"/proc/{pid}/stat")
            # An adopted zombie has stopped, even if this container's PID1 has
            # not reaped it yet. It cannot keep the game or display alive.
            for _ in range(20):
                if not state.exists() or state.read_text().split()[2] == "Z":
                    return
                time.sleep(.01)
            self.fail("A descendant kept running after timeout cleanup")
        finally:
            if pid is not None:
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass


if __name__ == "__main__":
    unittest.main()
