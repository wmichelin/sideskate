# Agent guidelines — SideSkate

## Read first

- [docs/gameplay.md](docs/gameplay.md) — motion, air, transfer / acid-drop, debug
- [docs/level_format.md](docs/level_format.md) — `.ssk` IDL

## Simulation: physics ticks only

All gameplay simulation must run on the **fixed physics timestep** (`_physics_process` / physics `delta`), never on render/idle frames (`_process`, “once per drawn frame,” timers tied to FPS, etc.).

Applies to: movement, air, gravity, transfer lerps, surface sampling that drives state, zone transitions, and any other game logic that advances world state.

Debug / UI readouts may use `_process` to **display** state. They must not step simulation.

## Debug tools (production)

Autoload `DebugTools` (`scripts/debug_tools.gd`):

- **Available** only if `OS.is_debug_build()` or custom export feature `debug_tools`.
- Force off locally with user arg: `godot --path . -- --no-debug-tools` (strips HUD/arrows like a release).
- When unavailable: nodes in group `debug_tools` are freed; god mode and debug HUD do not run.
- Release exports should omit `debug_tools` so all debug affordances stay off.

## Testing

Minimal headless runner in `tests/` (no GUT). Each `test_*.gd` exposes `run() -> bool`.

```bash
godot4 --headless --path . --script res://tests/test_runner.gd
# or open tests/TestRunner.tscn and press F6
```

Prefer `LevelLoader.parse_text` over `load_path` in tests (`load_path` aborts the process on bad maps).
