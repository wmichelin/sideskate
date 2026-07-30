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

**Lean:** air-out and ollie keep pre-takeoff surface lean; fly-out / deck-out sets `SimState.free_air_upright` and resets presentation lean upright.

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

Minimal headless runner in `tests/` (no GUT). Each `test_*.gd` exposes `run() -> bool`.

```bash
godot4 --headless --path . --script res://tests/test_runner.gd
# or open tests/TestRunner.tscn and press F6
```

Prefer `LevelLoader.parse_text` over `load_path` in tests (`load_path` aborts the process on bad maps).

Level fixtures for tests live in `tests/levels/` — do not point tests at `res://levels/` (playable maps). Analytical sim fixtures live in `tests/levels/sim/`; suite under `tests/sim/`.

## Renderer (3D)

- Playable maps live in `res://levels/` and load into `scenes/main.tscn` (Godot 3D park + analytical PlayerSim).
- Escape (`menu_back`) returns to the start menu.

### Agent iteration loop

1. Make one milestone-sized edit to the 3D renderer / pose / camera.
2. Run headless tests: `godot4 --headless --path . --script res://tests/test_runner.gd`
3. Fast visual gate:
   ```bash
   ./tools/render_iteration.sh plaza_default spawn 3d-only
   ```
4. Inspect `artifacts/render_compare/<level>/<pose>/3d.png` + `report.json`.
5. Fix issues; repeat.
6. Smoke the Escape path periodically:
   ```bash
   ./tools/render_iteration.sh plaza_default spawn pair
   ```

Required gates: `plaza_default`, `spine_demo`, `layered_demo`, `variable_height_ramps`, `plaza_default_deep`.
