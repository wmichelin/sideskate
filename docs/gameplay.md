# SideSkate — gameplay & systems

Intent brief for humans and agents. Motion law lives in [`movement_contract.md`](movement_contract.md) — if this file disagrees, the contract wins. ASCII IDL: [`level_format.md`](level_format.md).

## Product shape

Godot 4 **pseudo-3D** skate prototype. Simulation lives in **logical** space:

- **X** — left/right across the plaza
- **Z** — near/far depth (stick “up” = farther)
- **Height** — feet elevation above flat (pipe arc, deck, air)

Screen placement is a **projection** of `(x, z, height)`. The camera sits on the skater. Depth uses a homogeneous scale so skating in Z dollies the park projectively. World size is `columns × cell_x` / `rows × cell_z` (defaults both **47**). Visuals draw floors, pipe ride ribbons, outer walls/endcaps, and deck tops. Park draw uses a **Far → Player → Near** Z-split at the skater’s `logical_z`.

## Simulation law

All gameplay simulation runs on the **fixed physics timestep** (`_physics_process` / physics `delta`) only — never on render frames. Debug/UI may read state in `_process` but must not step the world.

**Authority:** [`scripts/sim/`](../scripts/sim/) (`PlayerSim` + compiled `ParkModel`). Godot collision is presentation / optional blocker reporting only — it must never slide, depenetrate, select a surface, retarget an action, or rewrite gameplay velocity.

See also [AGENTS.md](../AGENTS.md) and [movement_contract.md](movement_contract.md).

## Park model (compiled)

`.ssk` → `IdlCompiler` → immutable `ParkModel`: support patches, pipe surfaces, coping edges, topology edges.

| Coping class | Behavior |
|--------------|----------|
| `OPEN` | Air-out on rise; stick fly-out / deck-out in window |
| `SUPPORT_SEAM` | Auto-roll onto abutting **floor** at matching height |
| `WALL_EXTENSION` | Climb to taller outward floor **or** taller opposite pipe lip; then mount / air / fly |
| `SHARED_SPINE` | Opposite-facing pair (incl. cross-story); spine target; air/fly like `OPEN` |

Same-height outward `#` is an air/fly corridor (`OPEN`), not an auto-mount.

Glyphs: `=` / `#` / `x` solid; `.` hole; space OOB. Lava (`x`): airborne OK; grounded contact kills and respawns.

## Grounded motion

Stick → wish. Per axis:

- Neutral → **coast** (`friction` / `ramp_friction`; default 0)
- Opposite velocity → **brake** (default 1250), no reverse until stopped
- Aligned → **accel** toward max speed (default accel 3250, max X 880, max Z 400)

**Facing** `l`/`r`: follows world X speed when X-dominant. Spawn from `spawn_facing`.

**Ollie** (hold Space): mild accel toward max speed in facing direction; skipped while stick brakes opposite.

**Pipe:** UV along-arc (+along = toward coping). Gravity projects onto the tangent. `WALL_EXTENSION` continues as a vertical face after θ=π/2.

## Air

| Mode | Enter | X | Height |
|------|-------|---|--------|
| **Air-out** | Leave `OPEN`/`SHARED_SPINE` with along | Locked to exit coping X | Ballistic |
| **Free** (fly-out / deck-out) | Outward X-dominant stick in `FLY_OUT_ABOVE`, or ride-off | Unlocked | Ballistic |
| **Maneuver** | Accepted spine / acid / fly-out plan | Plan owns pose | Plan owns pose |

**Fly-out / deck-out:** unlock X and travel away from the pipe (left on left / right on right). Stick into the lip (outward), X-dominant, within the height window.

**Air-out land:** same-facing pipe whose coping X matches the lock (any layer/height), or floor/deck under the lock. Never auto-land opposite-facing.

**Spine:** transfer button while rising/apex → opposite-facing pipe from its outward side (left of left / right of right).

**Acid:** transfer button while descending → along travel to an opposite wall.

Hang clears on fly-out, spine, acid, or land. Return onto the exit pipe seeds into-bowl along. Plans never retarget mid-flight.

## Motion vectors

`MotionVectors.Kind` for debug arrows / wish display:

| Kind | Signal |
|------|--------|
| **INPUT** | Stick wish × max speeds (planar) |
| **MOMENTUM** | Integrated control (`tangent_velocity` / air `velocity`) |
| **ACTUAL** | Same as momentum for the analytical sim (measured rates) |

Fly-out gates on **INPUT** only.

## Presentation

Physics ticks publish `_pose_prev` / `_pose_curr`. `LogicalPosePresenter3D` and `CameraRig3D` interpolate on `_process`. Airborne: circular ground shadow on support height under feet. Hang keeps coping lean (body perpendicular to flat).

## Debug overlays

Gated by autoload `DebugTools` (`OS.is_debug_build()` or export feature `debug_tools`). Force off: `godot --path . -- --no-debug-tools`.

| Piece | Role |
|-------|------|
| Head arrows | INPUT / MOMENTUM / ACTUAL |
| Overlay | Zone / surface / next coping candidate |
| TUNING sliders | Gravity, fly-out window, spine/acid cast cells, ollie, speeds, accel, brake, friction, cell size, camera |
| Cell / facing cast / edge lattice | Presentation-only highlight |

Tunable sim values sync into `SimTolerances` / `PlayerSim` each physics tick. Cast-cell highlight distance is debug draw only (not a separate gameplay path).

## Key scripts

**PlayerSim** is the sole gameplay authority. `player.gd` is a thin shell.

| Script | Role |
|--------|------|
| [`sim/player_sim.gd`](../scripts/sim/player_sim.gd) | Orchestrator |
| [`sim/idl_compiler.gd`](../scripts/sim/idl_compiler.gd) | `.ssk` → `ParkModel` |
| [`sim/surface_query.gd`](../scripts/sim/surface_query.gd) | Support, edges, coping search, capsule sweep |
| [`sim/ground_solver.gd`](../scripts/sim/ground_solver.gd) | Grounded + wall climb + seams |
| [`sim/air_solver.gd`](../scripts/sim/air_solver.gd) | Free air + maneuvers |
| [`sim/maneuver_planner.gd`](../scripts/sim/maneuver_planner.gd) | Fly-out / spine / acid plans |
| [`sim/sim_tolerances.gd`](../scripts/sim/sim_tolerances.gd) | Epsilons, gravity, cast ranges |
| [`player.gd`](../scripts/player.gd) | Input → tick → pose sync |
| [`ramp_level.gd`](../scripts/ramp_level.gd) | Load `.ssk`, projection helpers, debug sample |
| [`physics/level_collision_3d.gd`](../scripts/physics/level_collision_3d.gd) | Visual/blocker trimeshes (not gameplay authority) |
| [`rendering_3d/*`](../scripts/rendering_3d/) | Park mesh + pose presenter + camera |

Analytical suites: [`tests/sim/`](../tests/sim/).

## Behavioral invariants

1. Sim only on physics ticks.
2. No gameplay state depends on layer index, collider order, scene-tree order, render FPS, or depenetration.
3. Continuous seams auto-roll; `WALL_EXTENSION` climbs; `OPEN` permits stick fly-out.
4. Spine while rising/apex; acid while descending; plans never retarget.
5. Ordinary landing requires descending support crossing.
6. Presentation + collision stamp the same `ParkModel.model_hash` as `PlayerSim`.
