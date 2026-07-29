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

`.ssk` → `IdlCompiler` → immutable `ParkModel`: support patches, pipe surfaces, explicit wall surfaces, Z-partitioned coping spans, and topology edges.

| Coping class | Behavior |
|--------------|----------|
| `OPEN` | Air-out on rise; stick fly-out / deck-out in window |
| `SUPPORT_SEAM` | Auto-roll onto abutting **floor** at matching height |
| `WALL_EXTENSION` | Pipe seam to an explicit vertical wall; wall top then mounts or opens to air |
| `SHARED_SPINE` | Same-height opposite-facing pair; action target; air/fly like `OPEN` |

Classification is per Z span. Cross-story upper copings are action-only targets, not automatic seams. Same-height outward `#` is an air/fly corridor (`OPEN`), not an auto-mount.

Glyphs: `=` / `#` / `x` solid; `.` hole (fall to lower support or invisible void floor); space = solid invisible wall. World AABB has invisible border walls. Lava (`x`): airborne OK; grounded contact kills and respawns. You cannot fall out of the park.

## Grounded motion

Stick → wish. Per axis:

- **X / along:** Neutral → **coast** (`friction` / `ramp_friction`; default 0). Opposite → **brake**. Aligned → **accel** toward max (default accel 3250, max X 880).
- **Z (depth):** Zero momentum — velocity = stick × max Z (default 400); release stops immediately.

**Facing** `l`/`r`: follows world X speed when X-dominant. Spawn from `spawn_facing`.

**Ollie** (hold Space): mild accel toward max speed in facing direction; skipped while stick brakes opposite.

**Pipe:** UV along-arc (+along = toward coping), always `u∈[0,1]`; gravity projects onto the tangent. A compiled seam enters a separate `WallSurface`, whose own `u∈[0,1]` runs bottom→top.

## Air

| Mode | Enter | X | Height |
|------|-------|---|--------|
| **Air-out** | Leave a compiled open pipe/wall edge with along | Locked to that edge anchor | Ballistic |
| **Free** (fly-out / deck-out) | Outward X-dominant stick in `FLY_OUT_ABOVE`, or ride-off | Unlocked; ballistic (no friction — stick steers only while held) | Gravity only |
| **Maneuver** | Accepted spine / acid / fly-out plan | Plan owns pose | Plan owns pose |

**Fly-out / deck-out:** unlock X and travel away from the pipe (left on left / right on right). Stick into the lip (outward), X-dominant, within the height window.

**Air-out land:** descending through the retained edge returns to its exact source pipe/wall with speed preserved. Never auto-land the opposite-facing transfer target.

**Spine:** transfer button while rising/apex → opposite-facing pipe from its outward side (left of left / right of right).

**Acid:** transfer button while descending → along travel to an opposite wall, or explicit deck drop-in onto an abutting pipe.

Hang stores `hang_edge_id`; it clears on fly-out, spine, acid, return, or leaving the edge’s Z span. Plans never retarget mid-flight.

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
| [`sim/surface_query.gd`](../scripts/sim/surface_query.gd) | Separate support projection, edge lookup, and deterministic swept solid contact |
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
3. Every grounded pose has one surface owner; pipe/wall `u` always stays in `[0,1]`.
4. Spine while rising/apex; acid while descending; plans never retarget.
5. Ordinary contact cannot switch to an opposite-facing transfer target; only an accepted plan can.
6. Shared boundaries have one compiled owner and every crossing consumes motion once.
7. Presentation + collision stamp the same full-geometry `ParkModel.model_hash` as `PlayerSim`.
