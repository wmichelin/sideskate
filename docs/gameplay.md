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

`.ssk` → `IdlCompiler` → immutable `ParkModel`: support patches, pipe surfaces, explicit wall surfaces, behavior-partitioned coping spans, and topology edges. Adjacent equivalent spans are merged so unrelated story breakpoints never create physical coping seams.

| Coping class | Behavior |
|--------------|----------|
| `OPEN` | Air-out on rise; stick fly-out / deck-out in window |
| `SUPPORT_SEAM` | Auto-roll onto abutting **floor** at matching height |
| `WALL_EXTENSION` | Pipe seam to an explicit vertical wall; wall top then mounts or opens to air |
| `SHARED_SPINE` | Same-height opposite-facing pair; action target; air/fly like `OPEN` |

Classification is per Z span. Cross-story upper copings are action-only targets, not automatic seams. Same-height outward `#` is an air/fly corridor (`OPEN`), not an auto-mount.

Glyphs: `=` / `#` / `x` solid; `.` hole (fall to lower support or invisible void floor); space = solid invisible wall. World AABB has invisible border walls. Lava (`x`): airborne OK; **any grounded contact** kills (`alive = false`) and the death overlay plays then respawns ~1.5s back on the floor/deck history. You cannot fall out of the park.

## Grounded motion

Stick → wish. Per axis:

- **X / along:** Neutral → **coast** (`friction` / `ramp_friction`; default 0). Opposite → **brake**. Aligned → **accel** toward max (default accel 3250, max X 880). `max_speed_x` is an absolute `|vx|` / along ceiling (air + pipe gravity included).
- **Z (depth):** Zero momentum — velocity = stick × max Z (default 400); release stops immediately.

**Facing** `l`/`r`: follows world X speed when X-dominant. Spawn from `spawn_facing`.

**Ollie** (Space): hold for mild facing accel (skipped while stick brakes opposite) and to charge a jump **while grounded**; release pops up to charge% × `ollie_height_flat` (floor/deck) or `ollie_height_pipe` (pipe/ramp/wall) level units (tunable charge time / heights). One jump charge — spent on release, restored when grounded on any surface. Below the lip / air-out band on pipes, free-air takeoff carries full along → world X. Pipe upper band (`ollie lip` slider, default top 50%) X-locks into hang air. **Ramps never hang / X-lock / fly-out** — peak leave and lip-band ollie are free air (adjacent pipes do not steal the ride). Pipe air keeps pre-takeoff lean until fly-out; ramp free-air leave from the upper `ollie lip` band (and peak leave) sets `free_air_upright` and presentation lerps lean upright (`free_air_upright_duration`), mid-ramp keeps lean.

**Pipe:** UV along-arc (+along = toward coping), always `u∈[0,1]`; gravity projects onto the tangent. A compiled seam enters a separate `WallSurface`, whose own `u∈[0,1]` runs bottom→top. Rise scales with glyph run × `step_height` (see `level_format.md`).

## Air

| Mode | Enter | X | Height |
|------|-------|---|--------|
| **Air-out** | Leave a compiled open pipe/wall edge with along | Locked to that edge anchor | Ballistic |
| **Free** (fly-out / deck-out) | Outward X-dominant stick in `FLY_OUT_ABOVE`, or ride-off | Unlocked; ballistic (no friction — stick steers only while held) | Gravity only |
| **Maneuver** | Fly-out unlock, or transfer-button X-lerp | Plan owns X (transfer) / unlock seed (fly-out) | Gravity (transfer) / plan seed (fly-out) |

**Fly-out / deck-out:** same unlock — clear X-lock, keep rising height, seed outward free-air X from climb/air speed, and **reset surface lean upright**. Stick must be outward to accept; after unlock X is ballistic. Cross-story walls gate the height window on the connected upper lip; outward stick stays with the source-pipe climb direction.

**Air-out** (and ollie free air) keep pre-takeoff pipe/wall lean. Do not confuse with fly-out.

**Free-air land on pipe/ramp:** along is the projection of world velocity onto the
slope tangent (X + height). Skating onto a ramp with mostly horizontal speed keeps
uphill along; falling back in after an air-out / fly-out includes the descent so you
drop into the bowl instead of seeding fake uphill (which felt like friction). Hang
remount into the bowl still seeds downhill along.

**Air-out land:** descending through the retained edge returns to its exact source pipe/wall with speed preserved. Never auto-land the opposite-facing transfer target. Same-facing X-aligned pipes still win over flats under the lock. If nothing remountable is under the lock (outside the pipe), land the nearest floor/deck/void and clear hang (drop lip lean / X-lock).

**Deck contact in free air:** rising or apex through a `#` volume keeps height. Grounding needs a descending pad crossing and an air-bout peak ≥ `DECK_LAND_MIN_ABOVE` above the pad, so lip/apex skims cannot sticky-mount. Only stick-gated fly-out unlocks onto a rear deck from a wall top. A wall face that shares the deck’s rear X owns the full climb band — the overhanging pad must not mid-climb rescue onto the deck.

**Deck back ride-off:** crosses the one-sided backing wall into ordinary free air. It never mounts the wall or creates an implicit acid drop.

**Deck open-side skate-off** (`####(((=====` and mirrors): grounded leave is free air (`air_launch` = that `#`). The initial deck-seam support/lip ownership event is a Corridor only outside a fall bout, so it does not Mount or crash. Gravity then carries the rider toward the abutting pipe/ramp, which Mounts only when the descending free-air sweep crosses its sampled ride surface from above. An actual outer/back wall, underside, or lateral solid-face hit first Rejects and starts a fall. While falling, every contact with that abutting slope Rejects and clears on the approach/outward side — never Corridor or Mount through the pipe. Acid and Spine are explicit transfer plans and use their own target-seat rules.

**Transfer:** press transfer when `next acid / spine` has a candidate. Normal gravity. Progress is **time-phased** 0→1 from accept (never pre-seeded — that snaps lean/X). Lean is upright at the ballistic apex (`apex_frac`); if already falling, upright at mid-pull. Lateral X follows the same clock; finishes on lip touch. Keeps facing; zeros `vx` on arrival; re-anchors hang on that open edge. Depth (logical Z) stays free. Lean rolls start → upright → dest (never the inverted backflip half).

Hang stores `hang_edge_id` (and launch id for lock/apex); it clears on fly-out, land, or return. Leaving the launch Z span retargets onto a colinear same-side OPEN edge or keeps a synthetic X-lock across the gap — it does not free-air / level out. Depth-transfer before apex keeps takeoff orientation. Fly-out plans never retarget mid-flight. At hang apex on the launch span, facing turns around the character's centered local Y axis into the source pipe over `APEX_FACING_DELAY`.

## Motion vectors

`MotionVectors.Kind` for debug arrows / wish display:

| Kind | Signal |
|------|--------|
| **INPUT** | Stick wish × max speeds (planar) |
| **MOMENTUM** | Integrated control (`tangent_velocity` / air `velocity`) |
| **ACTUAL** | Same as momentum for the analytical sim (measured rates) |

Fly-out gates on **INPUT** only.

## Presentation

Physics ticks publish `_pose_prev` / `_pose_curr`. `LogicalPosePresenter3D` and `CameraRig3D` interpolate on `_process`. Hang keeps coping lean (body perpendicular to flat). Z-stick input adds a subtle centered local-Y body turn toward/away from the camera, mirrored by facing. During a fall bout the camera tracks the FallBox’s **X** (the visible tumble; sim pose often parks) — world Y/Z stay locked at fall start, then full follow resumes when the bout ends.

## Debug overlays

Gated by autoload `DebugTools` (`OS.is_debug_build()` or export feature `debug_tools`). Force off: `godot --path . -- --no-debug-tools`.

| Piece | Role |
|-------|------|
| Head arrows | INPUT / MOMENTUM / ACTUAL |
| Overlay | Zone / surface / next coping candidate |
| TUNING sliders | Gravity, fly-out window, apex turn duration, depth-turn angle, spine/acid cast cells, ollie accel / charge ms / height / lip %, ollie charge bar, speeds, accel, brake, friction, cell size, camera |
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
| [`sim/crash_classifier.gd`](../scripts/sim/crash_classifier.gd) | Sudden-stop fall / wipeout policy |
| [`sim/maneuver_planner.gd`](../scripts/sim/maneuver_planner.gd) | Fly-out + transfer X-lerp plans |
| [`sim/sim_tolerances.gd`](../scripts/sim/sim_tolerances.gd) | Epsilons, gravity, cast ranges |
| [`player.gd`](../scripts/player.gd) | Input → tick → pose sync |
| [`ramp_level.gd`](../scripts/ramp_level.gd) | Load `.ssk`, projection helpers, debug sample |
| [`physics/level_collision_3d.gd`](../scripts/physics/level_collision_3d.gd) | Visual/blocker trimeshes (not gameplay authority) |
| [`rendering_3d/*`](../scripts/rendering_3d/) | Park mesh + pose presenter + camera |
| [`rendering_3d/fall_box_constraint.gd`](../scripts/rendering_3d/fall_box_constraint.gd) | Presentation FallBox plane clamp (visual only) |

### Fall bout

`PlayerSim.begin_fall()` starts a soft wipeout: clears hang/maneuver/ollie charge, ignores stick/transfer/ollie, keeps analytical collision + gravity, lerps planar X/depth to 0 over `fall_stop_duration`, leans onto the approach / facing side over `fall_anim_duration`, and after `fall_duration` soft-restores to the last floor/deck checkpoint (same ~1.5s history as lava, no death overlay) — even if still airborne against a Reject crash wall. Triggers live in [`sim/crash_classifier.gd`](../scripts/sim/crash_classifier.gd): level walls, deck walls/volumes, ramp/pipe outer-back, an actual deck-launch outer/back, underside, or lateral solid-face hit before a real descending ride-surface crossing, free-air **into-face** on a foreign pipe’s upper `ollie_lip_frac` band (Reject + fall, never Mount), hang clip/land onto floor/deck. Non-falling deck-seam support/lip ownership Corridor, same-slope remount, the valid descending deck-launch ride-surface crossing, hang on the coping lip-column of an abutting `#`, and free-air into the launch slope’s own outward `#` (lip/peak leave) stay playable. `SimState` stamps support/impact planes on Reject; presentation uses a visual-only `FallBoxConstraint` RigidBody that tumbles under gravity but clamps to those planes (never writes sim state). Dev invoke: **Y** / InputMap `fall`. Debug TUNING exposes the three durations and a head countdown bar (`show_fall_cooldown`).

Analytical suites: [`tests/sim/`](../tests/sim/).

## Behavioral invariants

1. Sim only on physics ticks.
2. No gameplay state depends on layer index, collider order, scene-tree order, render FPS, or depenetration.
3. Every grounded pose has one surface owner; pipe/wall `u` always stays in `[0,1]`.
4. Fly-out plans unlock free air immediately; they never retarget.
5. Ordinary contact cannot switch to an opposite-facing pipe (transfers TBD).
6. Shared boundaries have one compiled owner and every crossing consumes motion once.
7. Presentation + collision stamp the same full-geometry `ParkModel.model_hash` as `PlayerSim`.
