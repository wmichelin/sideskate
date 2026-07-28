#!/usr/bin/env bash
# Stable entry for 2D/3D render iteration captures.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PAIR="${1:-plaza_default}"
POSE="${2:-spawn}"
MODE="${3:-3d-only}"
OUT="${4:-$ROOT/artifacts/render_compare}"
WAIT="${5:-4}"

mkdir -p "$OUT"
mkdir -p "$ROOT/artifacts/render_compare"

echo "[render_iteration] pair=$PAIR pose=$POSE mode=$MODE out=$OUT"
"$GODOT" --path "$ROOT" "res://tests/render_iteration/RenderIterationRunner.tscn" -- \
  --pair "$PAIR" \
  --pose "$POSE" \
  --out "$OUT" \
  --mode "$MODE" \
  --wait-frames "$WAIT"
