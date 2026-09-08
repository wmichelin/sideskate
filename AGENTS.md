# Agent guidelines — SideSkate

## Read first

- [docs/movement_contract.md](docs/movement_contract.md) — frozen analytical sim contract
- [docs/gameplay.md](docs/gameplay.md) — presentation, debug, **key scripts map**
- [docs/level_format.md](docs/level_format.md) — `.ssk` IDL + derived topology

## Player / sim layout

- **`scripts/sim/`** — sole gameplay authority (`PlayerSim`, `IdlCompiler`, solvers, park model).
- **`scripts/player.gd`** — thin `CharacterBody3D` shell: reads input, ticks `PlayerSim`, syncs pose snapshots for presenters.
- Presentation / Godot collision consume compiled park geometry; they must never slide, depenetrate, select surfaces, or rewrite velocity.

See gameplay.md § Key scripts for the full table.

## Motion vectors

Use `MotionVectors.Kind` (`INPUT` / `MOMENTUM` / `ACTUAL`) when referring to stick wish, integrated control, or measured world motion. See gameplay.md § Motion vectors. Do not invent parallel names (`intent`, `wishvel`, etc.) in new code.

## Aerial vocabulary

Use these terms exactly. Do not invent synonyms (`unlock`, `pop out`, `hang unlock`) in new code or docs. Details/gates: [docs/movement_contract.md](docs/movement_contract.md) § Aerial vocabulary.

| Term | Alias | Meaning |
|------|-------|---------|
| **Air-out** | hang | Leave an open coping with **X locked** to the edge anchor. Height (+ depth) only. Stick does **not** free X. |
| **Fly-out** | **deck-out** | Same action: exit X-lock and travel **outward** from the pipe/wall (world away from the bowl). Free-air XZ after unlock. |
| **Spine** | — | Explicit transfer to an **opposite-facing** pipe (never ordinary land). |
| **Acid** | — | Explicit descending transfer onto a pipe (button). |

**Fly-out / deck-out are the same.** Prefer **fly-out** in sim/code (`ManeuverPlan.Kind.FLY_OUT`, `try_fly_out`). **Deck-out** is the player/design name for that unlock toward a rear deck / outward free air — never a separate code path.

**Lean:** air-out and ollie keep pre-takeoff surface lean; fly-out / deck-out and ramp lip-band free-air leave (incl. peak leave) set `SimState.free_air_upright` and presentation lerps lean upright (`free_air_upright_duration`).

## Simulation: physics ticks only

All gameplay simulation must run on the **fixed physics timestep** (`_physics_process` / physics `delta`), never on render/idle frames (`_process`, “once per drawn frame,” timers tied to FPS, etc.).

Applies to: movement, air, gravity, transfer plans, surface sampling that drives state, zone transitions, and any other game logic that advances world state.

Debug / UI readouts may use `_process` to **display** state. They must not step simulation.

## Debug tools (production)

Autoload `DebugTools` (`scripts/debug_tools.gd`):

- **Available** only if `OS.is_debug_build()` or custom export feature `debug_tools`.
- Force off locally with user arg: `godot --path . -- --no-debug-tools` (strips HUD/arrows like a release).
- When unavailable: nodes in group `debug_tools` are freed; debug HUD does not run.
- Release exports should omit `debug_tools` so all debug affordances stay off.

## Testing

The headless runner in `tests/` uses no GUT. Each `test_*.gd` exposes
`run() -> bool`; large suites can also expose `cases()` for named checks. Expected
negative-test diagnostics must be declared narrowly. Unexpected script/engine
errors, invariant diagnostics and non-boolean results fail the gate.

```bash
./tools/check.sh setup        # fresh machine: pinned Godot + Linux display tools
./tools/check.sh tests        # imports assets/classes before testing
./tools/check.sh tests --test test_sim_replay.gd
# Or open tests/TestRunner.tscn and press F6 after import.
```

Use `./tools/check.sh all` for tests, all gameplay stories and the five required
render gates. Use `./tools/check.sh gameplay --scenario all` for real input/menu
verification, or `--level res://levels/offset_demo.ssk --scenario spawn` for a
playable map. Inputs and gameplay assertions belong to physics ticks; capture
only after the requested state and a rendered frame. The normal follow camera
must remain active. Do not set presentation transforms to manufacture a scenario.

The wrapper supervises processes and requires completed nonempty reports; an exit
code alone is not proof. Inspect `artifacts/checks/` reports, logs, screenshots and
recordings, or pass `--out DIR`. `GODOT` overrides the resolved engine. Native
checks use Compatibility rendering by default; pass `--renderer forward_plus`
for the production renderer. Linux checks use a supervised Xvfb display.

Long trace checks are separate from fast iteration:

```bash
./tools/check.sh tests --test test_sim_replay.gd --sim-soak
./tools/check.sh tests --test test_sim_replay.gd --sim-soak --no-debug-tools
```

`PlayerSim.gameplay_hash()` compares complete simulation checkpoints, including
input, charge, transfer eligibility, checkpoint history and effective tuning.
Use `--max-fps 30`, `60`, or `120` with gameplay checks to compare equal physics
checkpoints across render rates. Ordinary debug trace storage is a 180-frame ring;
release/`--no-debug-tools` retain none. Explicit `start_recording(path)` streams a
complete recording; verify `stop_recording()` and replay error/status fields.

Prefer `LevelLoader.parse_text` over `load_path` in tests (`load_path` aborts the process on bad maps).

Level fixtures for tests live in `tests/levels/` — prefer those over playable maps.
Playable maps: `res://levels/`. Debug/prototype maps: `res://debug_levels/` (menu-listed only when `DebugTools.available`). Analytical sim fixtures live in `tests/levels/sim/`; suite under `tests/sim/`.

## Renderer (3D)

- Playable maps live in `res://levels/`; debug maps in `res://debug_levels/`. Both load into `scenes/main.tscn` (Godot 3D park + analytical PlayerSim).
- Escape (`menu_back`) opens the in-level pause menu (tree paused); quit from there returns to the start menu.

### Agent iteration loop

1. Make one milestone-sized edit to the 3D renderer / pose / camera.
2. Run imported headless tests: `./tools/check.sh tests`.
3. Fast visual gate:
   ```bash
   ./tools/render_iteration.sh plaza_default spawn 3d-only
   ```
4. Inspect `artifacts/render_compare/<level>/spawn/3d.png` and `report.json`. Only pose `spawn` is supported.
5. Fix issues; repeat.
6. Exercise real Escape → pause → main menu → reload periodically:
   ```bash
   ./tools/render_iteration.sh plaza_default spawn pair
   ```

Required gates: `plaza_default`, `spine_demo`, `layered_demo`, `variable_height_ramps`, `plaza_default_deep`.


## Local release verification

`./tools/check.sh setup --web` installs matching Web templates. With Node.js/npm:

```bash
npm ci --prefix tools/browser
npm run --prefix tools/browser install-browser
./tools/check.sh export
./tools/check.sh web
```

`export` writes the local release build to `build/html5/`; `web` also serves it on
loopback and runs browser smoke checks. Browser evidence is under
`artifacts/checks/web/`. These checks do not publish. `tools/deploy_prod.sh` is the
separate publishing command; its `DRY_RUN=1` mode exports without pushing.
