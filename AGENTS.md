# Agent guidelines — SideSkate

## Read first

- [docs/gameplay.md](docs/gameplay.md) — motion, air, transfer / acid-drop, debug
- [docs/level_format.md](docs/level_format.md) — `.ssk` IDL

## Simulation: physics ticks only

All gameplay simulation must run on the **fixed physics timestep** (`_physics_process` / physics `delta`), never on render/idle frames (`_process`, “once per drawn frame,” timers tied to FPS, etc.).

Applies to: movement, air, gravity, transfer lerps, surface sampling that drives state, zone transitions, and any other game logic that advances world state.

Debug / UI readouts may use `_process` to **display** state. They must not step simulation.
