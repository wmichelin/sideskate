# SideSkate

Godot 4.7 3D skate prototype with an analytical simulation in logical X/Z + height.

Gameplay authority is the analytical sim ([`docs/movement_contract.md`](docs/movement_contract.md)). Overview: [`docs/gameplay.md`](docs/gameplay.md).

## Run

Open the project in Godot **4.7** and play. It starts at the level select menu.
For a fresh checkout, the unattended setup below installs the pinned engine and
imports are handled by the check commands.

## Controls

| Input | Action |
|-------|--------|
| WASD / arrows / left stick | Move (W = farther) |
| Space / Cross (×) | Hold to charge ollie; release to jump |
| P / T / R2 | Spine (rising) / acid drop (falling) |
| Q / L1 · E / R1 | Air spin CCW / CW |
| R / Triangle (△) | Grind lock (airborne near rail) |
| Esc / Options | Pause (Return to Main Menu from pause) |
| Y | Fall |

## Levels

ASCII `.ssk` files in `levels/` (playable). Debug/prototype maps live in
`debug_levels/` and only appear in the menu when debug tools are available.
Format: [docs/level_format.md](docs/level_format.md).

## Unattended checks

Requires Python **3.11+**. Automatic engine setup supports Linux x86_64 and macOS;
Linux rendering uses Xvfb (setup caches it on apt-based systems when missing).
The Godot binary is resolved from `GODOT`, `godot4`/`godot` on `PATH`, the macOS
application, or the tool cache. Engine/template downloads have pinned checksums
in `tools/godot.py`; the default cache is `~/.cache/sideskate`
(`SIDESKATE_TOOL_CACHE` overrides it).

```bash
./tools/check.sh setup
./tools/check.sh all
```

`all` imports the project, runs the tests and complete gameplay scenarios, then
captures all five required debug maps. It uses the OpenGL Compatibility renderer by
default and drives the real player/menu inputs without an editor or user input.
Each child process has a timeout; success requires a completed nonempty report
and no unexpected engine/script errors or invariant diagnostics.

For focused iteration:

```bash
./tools/check.sh tests
./tools/check.sh tests --test test_sim_replay.gd
./tools/check.sh tests --test test_sim_replay.gd --sim-soak --no-debug-tools
./tools/check.sh gameplay --scenario all
./tools/check.sh replay       # compare 30/60/120 FPS and replay every recording
./tools/check.sh gameplay --level res://levels/offset_demo.ssk --scenario spawn
./tools/check.sh render --level plaza_default
./tools/render_iteration.sh plaza_default spawn pair
```

Use an existing playable `.ssk` path for `--level`; debug map basenames also work.
Gameplay scenarios are `spawn`, `gameplay` (menu/movement/ollie/pause), `air-out`,
`fly-out`, `spine`, `acid`, `ramp-peak`, `grind`, `fall`, `lava`, and `all`.
Use `--max-fps 30`, `60`, or `120` to compare native gameplay hashes at equal
physics checkpoints; physics remains at 60 Hz. Only capture pose `spawn` is
supported. Legacy `pair` performs real Escape → pause
→ main menu → reload. `--renderer forward_plus` selects the production renderer
when the host supports it; the legacy render script defaults to Forward+.

Reports, logs, screenshots and recordings go to `artifacts/checks/`; `--out DIR`
chooses another destination. The legacy script keeps
`artifacts/render_compare/<level>/spawn/`. Inspect screenshots as well as reports.
Test suites also run from `tests/TestRunner.tscn` with F6 after import.
`python3 tools/verification/runner_contract.py` verifies failure handling by
injecting broken scripts into a temporary checkout. CI runs these checks and
uploads evidence; scheduled/manual runs also include the longer memory soak.

## Local Web checks

Web smoke checks need Node.js/npm, Chromium and matching Godot export templates:

```bash
./tools/check.sh setup --web
npm ci --prefix tools/browser
npm run --prefix tools/browser install-browser
./tools/check.sh export
./tools/check.sh web
```

`export` writes `build/html5/index.html` and its packaged resources.
`web` exports the same local release build, serves it on loopback and runs
browser checks with screenshots and console/network diagnostics under
`artifacts/checks/web/`. It does not publish. Synthetic browser touch input supplements actual-device testing.
Release builds exclude debug tools/maps and do not retain ordinary sim traces;
explicit diagnostic recording is separate from debug UI availability.

## Deploy (itch.io HTML5)

Prod page: [wmichelin.itch.io/sideskater](https://wmichelin.itch.io/sideskater)

Prerequisites:

1. Godot **4.7** with **Web** export templates installed
2. [butler](https://itch.io/docs/butler/installing.html) on `PATH` and `butler login`

```bash
./tools/deploy_prod.sh
```

Exports a clean release Web build (no debug tools) to `build/html5/`, then pushes
channel `html5` on `wmichelin/sideskater` (overrides that channel’s previous build).

- `DRY_RUN=1 ./tools/deploy_prod.sh` — export only
- `GODOT=/path/to/Godot` — override binary
- `USERVERSION=1.2.3` — override butler version label (default: git short SHA)

After the **first** push, on the itch Edit game page: set kind to **HTML**, mark the
`html5` upload playable in browser, then delete/hide any old manual upload.
Prod currently uses a **no-threads** Web build (SharedArrayBuffer not required).
