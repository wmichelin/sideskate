#!/usr/bin/env bash
# Backward-compatible entry into the supervised render/real Escape gate.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/check.sh" render \
  --level "${1:-plaza_default}" \
  --pose "${2:-spawn}" \
  --mode "${3:-3d-only}" \
  --out "${4:-$ROOT/artifacts/render_compare}" \
  --wait-frames "${5:-4}" \
  --renderer "${SIDESKATE_RENDERER:-forward_plus}"
