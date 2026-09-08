#!/usr/bin/env python3
"""Inject failures only into a temporary checkout and require truthful exits."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import godot


def main():
    output = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "artifacts/checks/runner-contract"
    output.mkdir(parents=True, exist_ok=True)
    results = []
    with tempfile.TemporaryDirectory(prefix="sideskate-runner-contract-") as temporary:
        project = Path(temporary) / "project"
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns(".git", ".godot", "artifacts", "build", "node_modules", "__pycache__"))
        env = godot.engine_env()
        env["GODOT"] = godot.resolve()
        injected = project / "tests/test_injected.gd"
        cases = [
            ("fresh_checkout", None, [], True),
            ("parse_error", "extends RefCounted\nfunc run() -> bool:\n\tvar broken =\n\treturn true\n", [], False),
            ("runtime_error", "extends RefCounted\nfunc run() -> bool:\n\tvar target: Variant = null\n\ttarget.missing()\n\treturn true\n", [], False),
            ("false_result", "extends RefCounted\nfunc run() -> bool:\n\treturn false\n", [], False),
            ("empty_suite", "extends RefCounted\nfunc cases() -> Array:\n\treturn []\nfunc run() -> bool:\n\treturn true\n", [], False),
            ("assertion_failure", "extends RefCounted\nfunc run() -> bool:\n\tassert(false, 'injected assertion')\n\treturn true\n", [], False),
            ("engine_abort_stale_report", "extends RefCounted\nfunc run() -> bool:\n\tOS.kill(OS.get_process_id())\n\treturn true\n", [], False),
            ("hung_script", "extends RefCounted\nfunc run() -> bool:\n\twhile true:\n\t\tpass\n\treturn true\n", ["--timeout", "12"], False),
            ("empty_selection", None, ["--test", "no-such-case"], False),
            ("missing_engine", None, [], False),
        ]
        for name, source, extra, should_pass in cases:
            injected.unlink(missing_ok=True)
            if source:
                injected.write_text(source)
            case_out = output / name
            case_out.mkdir(exist_ok=True)
            command = [sys.executable, str(project / "tools/check.py"), "tests", "--out", str(case_out), *extra]
            if source:
                command += ["--test", "test_injected.gd"]
            case_env = env.copy()
            if name == "missing_engine":
                case_env["GODOT"] = str(project / "missing-engine")
            if name == "engine_abort_stale_report":
                stale = case_out / "tests/report.json"
                stale.parent.mkdir(exist_ok=True)
                stale.write_text(json.dumps({"completed": True, "check_count": 1, "failed": 0, "errors": [], "checks": [{"ok": True}]}))
            with (case_out / "launcher.log").open("w") as log:
                result = subprocess.run(command, cwd=project, env=case_env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
            ok = (result.returncode == 0) == should_pass
            results.append({"name": name, "ok": ok, "returncode": result.returncode})
            print(f"{'PASS' if ok else 'FAIL'} {name}: exit {result.returncode}", flush=True)
    report = {"completed": True, "checks": results, "check_count": len(results), "failed": sum(not result["ok"] for result in results), "errors": []}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    return int(report["failed"] > 0)


if __name__ == "__main__":
    sys.exit(main())
