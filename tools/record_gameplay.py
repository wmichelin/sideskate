#!/usr/bin/env python3
"""Record real InputMap gameplay with Godot's movie writer; deliver an H.264 MP4.

Usage: python3 tools/record_gameplay.py [--scenario all|animation|spine|...]
Requires ffmpeg/ffprobe and the engine/display setup from tools/check.sh setup.
The normal follow camera stays active. No gameplay or pose state is injected.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess

import check
import godot


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", default="all")
    parser.add_argument("--out", type=Path, default=check.ROOT / "artifacts/checks/video")
    args = parser.parse_args()
    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            raise RuntimeError(f"Missing {tool}; install ffmpeg to encode the recording")
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    binary, env = godot.resolve(), godot.engine_env()
    check.import_project(binary, out, 120, env)
    raw = out / "sideskate-gameplay.avi"
    movie = out / "sideskate-gameplay.mp4"
    report_path = out / "plaza_default/spawn/report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.unlink(missing_ok=True)
    with check.display(env, out) as (render_env, flags):
        command = [binary, *flags, "--audio-driver", "Dummy", "--windowed",
                   "--resolution", "1280x720", "--rendering-method", "forward_plus",
                   "--fixed-fps", "60", "--disable-vsync", "--write-movie", str(raw),
                   "--path", str(check.ROOT), "res://tests/render_iteration/RenderIterationRunner.tscn",
                   "--", "--pair", "plaza_default", "--pose", "spawn", "--mode", "gameplay",
                   "--scenario", args.scenario, "--out", str(out), "--report", str(report_path),
                   "--wait-frames", "30", "--no-debug-tools"]
        log = out / "movie.log"
        code = check.run(command, log, 240, render_env)
    report = check.validate_report(report_path)
    if code or check.log_errors(log) or not raw.is_file() or raw.stat().st_size == 0:
        raise RuntimeError(f"Game recording failed; inspect {log}")
    replay_report = out / "replay.json"
    replay_log = out / "replay.log"
    code = check.run([binary, "--headless", "--path", str(check.ROOT), "--script",
                      "res://tests/runtime/replay_recordings.gd", "--", str(report_path), str(replay_report)],
                     replay_log, 120, env)
    check.validate_report(replay_report)
    if code or check.log_errors(replay_log):
        raise RuntimeError(f"Recorded gameplay replay failed; inspect {replay_log}")
    # Keep the original frame timing. Fast-start and YUV420 support common players.
    code = check.run(["ffmpeg", "-hide_banner", "-nostdin", "-y", "-i", str(raw),
                      "-map", "0:v:0", "-map", "0:a?", "-c:v", "libx264", "-preset", "medium",
                      "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
                      "-movflags", "+faststart", str(movie)], out / "encode.log", 120, env)
    if code:
        raise RuntimeError(f"MP4 encoding failed; inspect {out / 'encode.log'}")
    probe = json.loads(subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(movie)],
        text=True, timeout=15))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    duration = float(probe["format"]["duration"])
    if video["codec_name"] != "h264" or video["width"] != 1280 or video["height"] != 720 or duration < 1:
        raise RuntimeError("Unexpected encoded video format or empty recording")
    summary = {"completed": True, "video": str(movie), "duration_seconds": duration,
               "width": video["width"], "height": video["height"], "fps": video["avg_frame_rate"],
               "bytes": movie.stat().st_size, "scenario": args.scenario,
               "gameplay_checks": report["check_count"], "physics_ticks": report["verified_physics_ticks"],
               "description": "Real keyboard/gamepad input through InputMap; normal follow camera; original frame timing."}
    (out / "video.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
