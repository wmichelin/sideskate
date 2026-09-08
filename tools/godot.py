#!/usr/bin/env python3
"""Pinned engine setup and shared binary resolution for local checks and exports."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile

VERSION = "4.7"
RELEASE = f"{VERSION}-stable"
CACHE = Path(os.environ.get("SIDESKATE_TOOL_CACHE", Path.home() / ".cache/sideskate"))
ASSETS = {
    "Linux": (f"Godot_v{RELEASE}_linux.x86_64.zip", "0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c", f"Godot_v{RELEASE}_linux.x86_64"),
    "Darwin": (f"Godot_v{RELEASE}_macos.universal.zip", "a6708c336f690e0dd8abd3d587d661707f4f33ed436946a3ec000d2fb497fd6c", "Godot.app/Contents/MacOS/Godot"),
}
TEMPLATES = (f"Godot_v{RELEASE}_export_templates.tpz", "9714459dc071907c0f3d5f17d608faf69e7cda21331fc5d39c4503ffa4e99eec")


def engine_version(binary: str) -> str:
    result = subprocess.run([binary, "--version"], capture_output=True, text=True, timeout=15, check=True)
    version = result.stdout.strip()
    if not version.startswith(VERSION + "."):
        raise RuntimeError(f"Need Godot {VERSION}.x, got {version!r} from {binary}")
    return version


def resolve() -> str:
    explicit = os.environ.get("GODOT")
    candidates = [shutil.which(explicit) or explicit] if explicit else [shutil.which("godot4"), shutil.which("godot"), "/Applications/Godot.app/Contents/MacOS/Godot"]
    if not explicit and platform.system() in ASSETS:
        candidates.append(str(CACHE / RELEASE / ASSETS[platform.system()][2]))
    rejected = []
    for candidate in candidates:
        if candidate and Path(candidate).is_file() and os.access(candidate, os.X_OK):
            try:
                engine_version(candidate)
            except (RuntimeError, OSError, subprocess.SubprocessError) as error:
                if explicit:
                    raise
                rejected.append(str(error))
                continue
            return str(Path(candidate).resolve())
    detail = " Rejected candidates: " + "; ".join(rejected) if rejected else ""
    raise RuntimeError(f"Godot {VERSION} not found. Run ./tools/check.sh setup or set GODOT=/path/to/Godot.{detail}")


def download(name: str, expected_sha: str) -> Path:
    destination = CACHE / "downloads" / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and file_hash(destination) == expected_sha:
        return destination
    partial = destination.with_suffix(destination.suffix + ".part")
    url = f"https://github.com/godotengine/godot-builds/releases/download/{RELEASE}/{name}"
    print(f"Downloading {name}", flush=True)
    try:
        with urllib.request.urlopen(url, timeout=60) as response, partial.open("wb") as output:
            shutil.copyfileobj(response, output, length=1024 * 1024)
        if file_hash(partial) != expected_sha:
            raise RuntimeError(f"Checksum mismatch: {name}")
        partial.replace(destination)
    finally:
        partial.unlink(missing_ok=True)
    return destination


def file_hash(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def setup(web: bool = False) -> None:
    system = platform.system()
    if system not in ASSETS or (system == "Linux" and platform.machine() not in ("x86_64", "amd64")):
        raise RuntimeError("Automatic setup supports Linux x86_64 and macOS; provide GODOT on other platforms")
    name, digest, executable = ASSETS[system]
    folder = CACHE / RELEASE
    binary = folder / executable
    if not binary.is_file():
        with zipfile.ZipFile(download(name, digest)) as archive:
            archive.extractall(folder)
        binary.chmod(0o755)
    engine_version(str(binary))
    if system == "Linux" and not shutil.which("Xvfb") and not (CACHE / "xvfb/usr/bin/Xvfb").is_file():
        if not shutil.which("apt-get") or not shutil.which("dpkg-deb"):
            raise RuntimeError("Install Xvfb for unattended rendering, or set XVFB=/path/to/Xvfb")
        packages = CACHE / "xvfb-packages"
        packages.mkdir(parents=True, exist_ok=True)
        subprocess.run(["apt-get", "download", "xvfb", "libxfont2"], cwd=packages, check=True, timeout=60)
        for package in packages.glob("*.deb"):
            subprocess.run(["dpkg-deb", "-x", str(package), str(CACHE / "xvfb")], check=True, timeout=30)
    if web:
        templates = template_dir()
        if not (templates / "web_nothreads_release.zip").is_file():
            with zipfile.ZipFile(download(*TEMPLATES)) as archive:
                templates.mkdir(parents=True, exist_ok=True)
                for entry in archive.namelist():
                    if Path(entry).name.startswith("web_") or Path(entry).name == "version.txt":
                        with archive.open(entry) as source, (templates / Path(entry).name).open("wb") as output:
                            shutil.copyfileobj(source, output)
    (CACHE / "setup.json").write_text(json.dumps({"engine": engine_version(str(binary)), "binary": str(binary), "archive_sha256": digest, "web_templates": str(template_dir()) if web else None}, indent=2) + "\n")
    print(f"Ready: {binary}")


def template_dir() -> Path:
    if platform.system() == "Darwin":
        return Path.home() / "Library/Application Support/Godot/export_templates" / f"{VERSION}.stable"
    return CACHE / "data/godot/export_templates" / f"{VERSION}.stable"


def engine_env() -> dict[str, str]:
    env = os.environ.copy()
    # Godot's export-template discovery uses XDG_DATA_HOME on Linux.
    if platform.system() == "Linux":
        env["XDG_DATA_HOME"] = str(CACHE / "data")
    return env


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--setup", action="store_true")
    parser.add_argument("--web", action="store_true")
    args = parser.parse_args()
    try:
        if args.setup:
            setup(args.web)
        else:
            print(resolve())
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
