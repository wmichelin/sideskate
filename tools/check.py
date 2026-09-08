#!/usr/bin/env python3
"""Bounded local test, render and gameplay checks; no publishing side effects."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import platform
import re
import select
import shutil
import signal
import subprocess
import sys
import time
import threading
import tempfile

import godot

ROOT = Path(__file__).resolve().parents[1]
GATES = ("plaza_default", "spine_demo", "layered_demo", "variable_height_ramps", "plaza_default_deep")


def stop_process(process: subprocess.Popen) -> None:
    if os.name == "posix":
        # The leader can exit while a descendant still holds its process group.
        # Always finish that group; waiting only on the leader leaks such children.
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        return
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def run(command: list[str], log_path: Path, timeout: float, env: dict[str, str]) -> int:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Running {log_path.stem}; log: {log_path}", flush=True)
    with log_path.open("w") as output:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            stop_process(process)
            raise RuntimeError(f"Timed out after {timeout}s: {log_path}")
        finally:
            stop_process(process)


def log_errors(log_path: Path, expected: list[str] | None = None) -> list[str]:
    expected = expected or []
    errors = []
    for line in log_path.read_text(errors="replace").splitlines():
        clean = re.sub(r"\x1b\[[0-9;]*m", "", line).strip()
        if clean.startswith(("ERROR:", "SCRIPT ERROR:", "SHADER ERROR:")) or (clean.startswith("WARNING:") and "invariant" in clean.lower()):
            message = clean.split(":", 1)[1].strip()
            if not any(message == item.splitlines()[0].strip() for item in expected):
                errors.append(clean)
    return errors


def validate_report(path: Path) -> dict:
    try:
        report = json.loads(path.read_text())
    except (OSError, ValueError) as error:
        raise RuntimeError(f"Missing/invalid completion report: {path}: {error}") from error
    if not isinstance(report, dict) or report.get("completed") is not True or type(report.get("check_count")) is not int or report["check_count"] < 1:
        raise RuntimeError(f"Incomplete or empty check report: {path}")
    checks = report.get("checks")
    if not isinstance(checks, list) or len(checks) != report["check_count"] or type(report.get("failed")) is not int or not isinstance(report.get("errors"), list):
        raise RuntimeError(f"Inconsistent check report: {path}")
    if report["failed"] != 0 or report["errors"] or any(not isinstance(item, dict) or item.get("ok") is not True for item in checks):
        raise RuntimeError(f"Checks failed: {path}")
    return report


def import_project(binary: str, out: Path, timeout: float, env: dict[str, str]) -> None:
    log = out / "import.log"
    code = run([binary, "--headless", "--editor", "--path", str(ROOT), "--import"], log, timeout, env)
    if code:
        raise RuntimeError(f"Asset import failed ({code}): {log}")
    # A first import can initially fail to load the theme it is about to import.
    # A second editor load must be clean; never infer success from exit status alone.
    if log_errors(log):
        validation_log = out / "post-import.log"
        code = run([binary, "--headless", "--editor", "--path", str(ROOT), "--quit"], validation_log, timeout, env)
        errors = log_errors(validation_log)
        if code or errors:
            raise RuntimeError(f"Post-import validation failed: {validation_log}: {errors[:3]}")


@contextmanager
def display(env: dict[str, str], out: Path):
    if platform.system() != "Linux":
        yield env, []
        return
    executable = os.environ.get("XVFB") or shutil.which("Xvfb")
    cached = godot.CACHE / "xvfb/usr/bin/Xvfb"
    if not executable and cached.is_file():
        executable = str(cached)
    if not executable:
        raise RuntimeError("Xvfb not found. Run ./tools/check.sh setup or set XVFB=/path/to/Xvfb")
    render_env = env.copy()
    cached_lib = godot.CACHE / "xvfb/usr/lib/x86_64-linux-gnu"
    if cached_lib.is_dir():
        render_env["LD_LIBRARY_PATH"] = str(cached_lib) + (":" + env["LD_LIBRARY_PATH"] if env.get("LD_LIBRARY_PATH") else "")
    read_fd, write_fd = os.pipe()
    out.mkdir(parents=True, exist_ok=True)
    with (out / "display.log").open("w") as output:
        process = subprocess.Popen([executable, "-displayfd", str(write_fd), "-screen", "0", "1280x720x24", "-nolisten", "tcp"], env=render_env, stdout=output, stderr=subprocess.STDOUT, pass_fds=(write_fd,), start_new_session=True)
        os.close(write_fd)
        try:
            ready, _, _ = select.select([read_fd], [], [], 10)
            if not ready:
                raise RuntimeError("Virtual display startup timed out")
            number = os.read(read_fd, 64).decode().strip()
            if not number.isdecimal():
                raise RuntimeError(f"Virtual display failed: {out / 'display.log'}")
            render_env["DISPLAY"] = ":" + number
            render_env["WAYLAND_DISPLAY"] = "sideskate-no-wayland-fallback"
            yield render_env, ["--display-driver", "x11"]
        finally:
            os.close(read_fd)
            stop_process(process)


def tests(binary: str, out: Path, args, env: dict[str, str]) -> None:
    destination = out / "tests/report.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.unlink(missing_ok=True)
    command = [binary, "--headless", "--path", str(ROOT), "--script", "res://tests/test_runner.gd", "--", "--report", str(destination)]
    if args.test:
        command += ["--test", args.test]
    if args.sim_soak:
        command.append("--sim-soak")
    if args.no_debug_tools:
        command.append("--no-debug-tools")
    log = out / "tests/engine.log"
    code = run(command, log, args.timeout, env)
    report = validate_report(destination)
    expected = [entry["message"] for entry in report.get("diagnostics", []) if entry.get("expected")]
    errors = log_errors(log, expected)
    if code or errors:
        raise RuntimeError(f"Test process failed ({code}): {log}: {errors[:3]}")
    print(f"PASS: {report['check_count']} test cases")


def gameplay(binary: str, out: Path, args, env: dict[str, str], *, capture_only=False) -> None:
    level = args.level or "plaza_default"
    level_name = Path(level).stem
    pose = args.pose
    destination = out / level_name / pose / "report.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.unlink(missing_ok=True)
    log = out / level_name / pose / "engine.log"
    with display(env, out) as (render_env, flags):
        command = [binary, *flags, "--audio-driver", "Dummy", "--windowed", "--resolution", "1280x720", "--max-fps", str(args.max_fps), "--rendering-method", args.renderer, "--path", str(ROOT), "res://tests/render_iteration/RenderIterationRunner.tscn", "--", "--pair", level_name, "--pose", pose, "--mode", args.mode if capture_only else "gameplay", "--out", str(out), "--report", str(destination), "--wait-frames", str(args.wait_frames)]
        if level.startswith("res://"):
            command += ["--level", level]
        if not capture_only:
            command += ["--scenario", args.scenario]
        if args.no_debug_tools or not capture_only:
            command.append("--no-debug-tools")
        code = run(command, log, args.timeout, render_env)
    report = validate_report(destination)
    errors = log_errors(log)
    if code or errors:
        raise RuntimeError(f"Gameplay process failed ({code}): {log}: {errors[:3]}")
    images = list(destination.parent.glob("*.png"))
    if not images or any(path.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n" for path in images):
        raise RuntimeError(f"Missing/invalid screenshots: {destination.parent}")
    print(f"PASS: {level_name}/{args.scenario if not capture_only else pose}: {report['check_count']} checks")
    if not capture_only:
        replay_report = destination.with_name("replay.json")
        replay_report.unlink(missing_ok=True)
        replay_log = destination.with_name("replay.log")
        code = run([binary, "--headless", "--path", str(ROOT), "--script", "res://tests/runtime/replay_recordings.gd", "--", str(destination), str(replay_report)], replay_log, args.timeout, env)
        replayed = validate_report(replay_report)
        if code or log_errors(replay_log):
            raise RuntimeError(f"Recorded gameplay replay failed ({code}): {replay_log}")
        print(f"PASS: {replayed['check_count']} recorded sessions replayed")


def export_web(binary: str, out: Path, args, env: dict[str, str]) -> Path:
    if not (godot.template_dir() / "web_nothreads_release.zip").is_file():
        raise RuntimeError("Matching Web templates missing. Run ./tools/check.sh setup --web")
    destination = ROOT / "build/html5"
    destination.parent.mkdir(parents=True, exist_ok=True)
    (ROOT / "build/.gdignore").touch()
    preset = ROOT / "export_presets.cfg"
    previous = preset.read_bytes() if preset.exists() else None
    working = Path(tempfile.mkdtemp(prefix=".html5-export-", dir=destination.parent))
    staged = working / "html5"
    staged.mkdir()
    backup = working / "previous"
    promoted = False
    html = staged / "index.html"
    log = out / "web/export.log"
    try:
        try:
            shutil.copyfile(ROOT / "export/html5_prod.cfg", preset)
            code = run([binary, "--headless", "--path", str(ROOT), "--export-release", "HTML5 Prod", str(html)], log, args.timeout, env)
        finally:
            if previous is None:
                preset.unlink(missing_ok=True)
            else:
                preset.write_bytes(previous)
        errors = log_errors(log)
        if code or errors or any(not (staged / ("index." + suffix)).is_file() or (staged / ("index." + suffix)).stat().st_size == 0 for suffix in ("html", "js", "wasm", "pck")):
            raise RuntimeError(f"Web export failed ({code}): {log}: {errors[:3]}")
        audit = out / "web/package.json"
        audit.unlink(missing_ok=True)
        with tempfile.TemporaryDirectory(prefix="sideskate-package-") as temporary:
            project = Path(temporary)
            (project / "project.godot").write_text("config_version=5\n")
            audit_log = out / "web/package.log"
            code = run([binary, "--headless", "--path", str(project), "--script", str(ROOT / "tools/verification/export_audit.gd"), "--", str(staged / "index.pck"), str(audit)], audit_log, args.timeout, env)
        validate_report(audit)
        if code or log_errors(audit_log):
            raise RuntimeError(f"Exported package audit failed: {audit_log}")
        # Both directories share a filesystem. Keep the last valid build until
        # the fresh export and package audit pass, then replace it as a whole.
        if destination.exists():
            destination.rename(backup)
        try:
            staged.rename(destination)
        except OSError as error:
            if backup.exists():
                try:
                    backup.rename(destination)
                except OSError as rollback_error:
                    raise RuntimeError(f"Build promotion failed; previous build preserved at {backup}: {rollback_error}") from error
            raise
        promoted = True
    finally:
        # If filesystem trouble also prevents rollback, retain the only copy of
        # the previous build at the path reported above for manual recovery.
        if promoted or not backup.exists():
            shutil.rmtree(working)
    print(f"PASS: local release export: {destination / 'index.html'}")
    return destination


def web(binary: str, out: Path, args, env: dict[str, str]) -> None:
    directory = export_web(binary, out, args, env)
    if not shutil.which("node") or not (ROOT / "tools/browser/node_modules/playwright").is_dir():
        raise RuntimeError("Browser tools missing. Run npm ci --prefix tools/browser and npm run --prefix tools/browser install-browser")
    destination = out / "web/report.json"
    destination.unlink(missing_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(SimpleHTTPRequestHandler, directory=str(directory)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    log = out / "web/browser.log"
    try:
        # Let the browser report its own workload timeout before terminating its
        # process group. Cleanup remains bounded if Chromium or Node hangs.
        code = run(["node", str(ROOT / "tools/browser/smoke.mjs"), "--url", f"http://127.0.0.1:{server.server_port}", "--out", str(out / "web"), "--timeout", str(int(args.timeout * 1000))], log, args.timeout + 15, env)
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
    report = validate_report(destination)
    if code or log_errors(log):
        raise RuntimeError(f"Browser process failed ({code}): {log}")
    print(f"PASS: {report['check_count']} browser checks")


def replay_rates(binary: str, out: Path, args, env: dict[str, str]) -> None:
    baseline = None
    checks = []
    for fps in (30, 60, 120):
        options = argparse.Namespace(**vars(args))
        options.max_fps = fps
        options.scenario = "all"
        run_out = out / "replay" / str(fps)
        gameplay(binary, run_out, options, env)
        level = Path(options.level or "plaza_default").stem
        report = validate_report(run_out / level / options.pose / "report.json")
        checkpoints = {name: data["hash"] for name, data in report.get("checkpoints", {}).items()}
        if not checkpoints:
            raise RuntimeError(f"Missing physics checkpoints at {fps} FPS")
        if baseline is None:
            baseline = checkpoints
        checks.append({"name": f"{fps}_fps_checkpoints", "ok": checkpoints == baseline, "hashes": checkpoints})
    summary = {"completed": True, "checks": checks, "check_count": len(checks), "failed": sum(not item["ok"] for item in checks), "errors": []}
    path = out / "replay/report.json"
    path.write_text(json.dumps(summary, indent=2) + "\n")
    validate_report(path)
    print(f"PASS: {len(baseline)} complete gameplay checkpoints match at 30/60/120 FPS")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["setup", "tests", "gameplay", "render", "all", "replay", "export", "web"])
    parser.add_argument("--web", action="store_true", help="Also install Web export templates during setup")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--test", help="Filter suite filename or named case")
    parser.add_argument("--sim-soak", action="store_true", help="Include the optional 36,000-tick replay/memory checks")
    parser.add_argument("--level", help="Debug basename or explicit res:// level path")
    parser.add_argument("--pose", default="spawn")
    parser.add_argument("--mode", default="3d-only")
    parser.add_argument("--scenario", default="all")
    parser.add_argument("--renderer", choices=["gl_compatibility", "forward_plus"], default="gl_compatibility")
    parser.add_argument("--wait-frames", type=int, default=4)
    parser.add_argument("--max-fps", type=int, default=120, help="Native render cap; physics remains 60 Hz")
    parser.add_argument("--no-debug-tools", action="store_true")
    args = parser.parse_args()
    if args.timeout <= 0 or args.wait_frames < 1 or args.max_fps < 1:
        parser.error("timeout, wait-frames and max-fps must be positive")
    if args.command == "setup":
        godot.setup(args.web)
        return 0
    out = (args.out or ROOT / "artifacts/checks").resolve()
    out.mkdir(parents=True, exist_ok=True)
    if out.is_relative_to(ROOT):
        (ROOT / "artifacts/.gdignore").touch()
    binary = godot.resolve()
    env = godot.engine_env()
    print(f"Godot {godot.engine_version(binary)}; output: {out}")
    import_project(binary, out, args.timeout, env)
    if args.command in ("tests", "all"):
        tests(binary, out, args, env)
    if args.command in ("gameplay", "all"):
        gameplay(binary, out / "gameplay", args, env)
    if args.command == "render":
        gameplay(binary, out, args, env, capture_only=True)
    if args.command == "all":
        for level in GATES:
            args.level = level
            gameplay(binary, out / "render", args, env, capture_only=True)
    if args.command == "export":
        export_web(binary, out, args, env)
    if args.command == "web":
        web(binary, out, args, env)
    if args.command == "replay":
        replay_rates(binary, out, args, env)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
