#!/usr/bin/env bash
# Export a clean HTML5 release build and push to itch.io (wmichelin/sideskater:html5).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ITCH_TARGET="${ITCH_TARGET:-wmichelin/sideskater:html5}"
EXPORT_HTML="$ROOT/build/html5/index.html"
DRY_RUN="${DRY_RUN:-0}"

GODOT_BIN="$(python3 "$ROOT/tools/godot.py")"
VERSION_LINE="$("$GODOT_BIN" --version 2>/dev/null || true)"
if [[ ! "$VERSION_LINE" =~ ^4\.7 ]]; then
	echo "error: need Godot 4.7.x (got: ${VERSION_LINE:-unknown})" >&2
	echo "hint: GODOT=/Applications/Godot.app/Contents/MacOS/Godot" >&2
	exit 1
fi

if [[ "$DRY_RUN" != "1" ]]; then
	if ! command -v butler >/dev/null 2>&1; then
		echo "error: butler not on PATH. Install: https://itch.io/docs/butler/installing.html" >&2
		echo "hint: on this machine try export PATH=\"\$HOME/bin:\$PATH\"" >&2
		exit 1
	fi
fi

USERVERSION="${USERVERSION:-$(git -C "$ROOT" rev-parse --short HEAD)}"

echo "[deploy_prod] godot=$VERSION_LINE"
echo "[deploy_prod] target=$ITCH_TARGET userversion=$USERVERSION dry_run=$DRY_RUN"

echo "[deploy_prod] exporting HTML5 Prod → build/html5/"
"$ROOT/tools/check.sh" export

if [[ ! -f "$EXPORT_HTML" ]]; then
	echo "error: export failed — missing $EXPORT_HTML" >&2
	echo "hint: install Godot 4.7 Web export templates (Editor → Manage Export Templates)" >&2
	exit 1
fi

if [[ "$DRY_RUN" == "1" ]]; then
	echo "[deploy_prod] export ok, skipping push (DRY_RUN=1)"
	exit 0
fi

echo "[deploy_prod] butler push → $ITCH_TARGET"
butler push "$ROOT/build/html5" "$ITCH_TARGET" --userversion "$USERVERSION"

echo
echo "Pushed: https://wmichelin.itch.io/sideskater"
echo "First-time itch checklist (Edit game):"
echo "  1. Kind of project → HTML"
echo "  2. On the html5 upload → enable 'This file will be played in the browser'"
echo "  3. Delete or hide any old non-butler upload"
