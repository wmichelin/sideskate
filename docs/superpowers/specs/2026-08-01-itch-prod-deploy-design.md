# itch.io HTML5 prod deploy (butler)

**Status:** approved design (2026-08-01).

## Goal

Ship a clean HTML5 / play-in-browser build to
[wmichelin.itch.io/sideskater](https://wmichelin.itch.io/sideskater) with one
local command, overriding the existing (stale) upload via butler channel
`html5`.

## Decisions

| Choice | Value |
|--------|--------|
| Platform | HTML5 only |
| Trigger | Local script only (no CI) |
| Build flavor | Release — omit `debug_tools` custom feature |
| itch target | `wmichelin/sideskater:html5` |
| Approach | Export preset + `tools/deploy_prod.sh` (export then push) |

## Context

- Godot **4.7** project (`project.godot`); game page slug is `sideskater`.
- No deploy scripts or CI today; `tools/` only has `render_iteration.sh`.
- `export_presets.cfg` is gitignored — machine-local presets cannot be the
  sole source of truth for prod.
- Autoload `DebugTools` is available when `OS.is_debug_build()` **or** custom
  feature `debug_tools`. Release HTML5 export must not enable that feature so
  debug HUD/arrows stay off on itch (see `AGENTS.md`).

## Architecture

### 1. Tracked Web export preset source

Commit `export/html5_prod.cfg` — a full Godot `export_presets.cfg`-format file
containing a single Web preset named `HTML5 Prod`.

- Export path: `build/html5/index.html`
- Custom features: empty (must not include `debug_tools`)
- Runnable / debug export: off (release Web build)
- `build/` added to `.gitignore`

At deploy time the script copies `export/html5_prod.cfg` → project-root
`export_presets.cfg` (still gitignored for local editor experiments), then
runs headless export. Do **not** treat a hand-edited ignored preset as the
source of truth.

### 2. `tools/deploy_prod.sh`

Single entrypoint. Behavior:

1. Resolve `GODOT` binary (`GODOT` env, else `godot4`, else `godot`); fail with
   a clear message if missing or version is not 4.7.x.
2. Unless `DRY_RUN=1`, require `butler` on `PATH`; fail if missing.
3. `cp export/html5_prod.cfg export_presets.cfg`
4. Headless Web export:  
   `"$GODOT" --headless --path . --export-release "HTML5 Prod" build/html5/index.html`
5. Fail if `build/html5/index.html` is missing.
6. If `DRY_RUN=1`: print “export ok, skipping push” and exit 0.  
   Else:  
   `butler push build/html5 wmichelin/sideskater:html5 --userversion <ver>`  
   where `<ver>` is `USERVERSION` if set, else `git rev-parse --short HEAD`.
7. Print https://wmichelin.itch.io/sideskater and the one-time HTML /
   playable-in-browser checklist.

Env:

- `GODOT` — binary path
- `USERVERSION` — override butler user version
- `DRY_RUN=1` — export only; do not call butler

### 3. One-time host / itch setup (documented, not automated)

1. Install [butler](https://itch.io/docs/butler/installing.html); run
   `butler login`.
2. Install Godot **4.7** **Web** export templates matching the editor.
3. After the first successful push: on Edit game, set project type to **HTML**,
   mark the `html5` upload **This file will be played in the browser**, and
   delete or hide any old non-butler upload so players only see the new
   channel.

Pushing the same channel again replaces/updates that build (patch upload);
no special “override” flag is required.

### 4. Docs

Short **Deploy** section in `README.md`: prerequisites, `./tools/deploy_prod.sh`,
itch URL, and the one-time HTML / playable-in-browser checklist.

## Out of scope

- GitHub Actions / CI
- Desktop (Windows / macOS / Linux) channels
- Debug / `html5-debug` channel
- In-game update checks via Wharf API

## Success criteria

- Running `./tools/deploy_prod.sh` produces a Web build without debug tools
  and uploads it to `wmichelin/sideskater:html5`.
- A second run updates the same channel (old content superseded for that
  channel).
- Spec and script are usable by someone with Godot 4.7 + butler logged in.
