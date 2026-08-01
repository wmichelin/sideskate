# With-slope leave/land + wipeout presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deck skate-off onto abutting pipe is consistent free air then with-slope Mount (never wipeout); joint/wall wipeouts park on the approach side with a kinematic fall tip that cannot enter the wall mesh.

**Architecture:** Extend `CrashClassifier` with `is_with_slope` / deck-abut leave helpers; `AirSolver`/`GroundSolver` disposition uses them so foreign-lip Reject is into-face only. Replace RigidBody `FallBox` with a kinematic tip driven from sim feet + `fall_lean_sign`. Update `movement_contract.md`.

**Tech Stack:** Godot 4 GDScript, analytical `PlayerSim`, headless `godot4 --headless --path . --script res://tests/test_runner.gd`.

## Global Constraints

- Gameplay sim on physics ticks only.
- With-slope leave/land never foreign-lip Reject / wipeout.
- Into-face Reject parks at `WALL_REJECT_CLEAR` on approach; lean away from face.
- Fall presentation must not use an independent RigidBody that can tunnel into wall trimeshes.
- Existing union fly-out + mid-face no-tunnel regressions stay green.
- Prefer `tests/levels/` fixtures + `LevelLoader.parse_text`.

## File map

| File | Role |
|------|------|
| Modify `scripts/sim/crash_classifier.gd` | `is_with_slope`, `deck_abuts_slope`, narrow foreign-lip |
| Modify `scripts/sim/air_solver.gd` | Disposition + wipeout park; stop tip eject fighting with-slope |
| Modify `scripts/sim/ground_solver.gd` | Deck open leave → free air no fall; stamp `air_launch` |
| Modify `scripts/rendering_3d/logical_pose_presenter_3d.gd` | Kinematic fall tip; remove RigidBody FallBox |
| Modify `tests/sim/test_sim_runtime.gd` | Ride-off + wipeout regressions |
| Create `tests/levels/sim/deck_to_left_pipe.ssk` | `####(((=====` fixture |
| Modify `docs/movement_contract.md`, `docs/gameplay.md` | Contract text |

---

### Task 1: Failing tests — deck skate-off + wipeout approach park

**Files:**
- Create: `tests/levels/sim/deck_to_left_pipe.ssk`
- Modify: `tests/sim/test_sim_runtime.gd` (`run()` + new funcs)
- Test: headless runner

**Interfaces:**
- Consumes: existing `PlayerSim.setup_from_path` / `parse` via path
- Produces: failing tests that define success criteria

- [ ] **Step 1: Add level fixture**

Create `tests/levels/sim/deck_to_left_pipe.ssk` (minimal valid SSK — match header style of other `tests/levels/sim/*.ssk`):

```text
# rows of: ####(((=====
```

Use the same meta/header pattern as `tests/levels/sim/sim_halfpipe.ssk` (cell size, layers) so `IdlCompiler` accepts it. Seven identical rows of `####(((=====`.

- [ ] **Step 2: Write failing ride-off test**

In `tests/sim/test_sim_runtime.gd` `run()`, add `_deck_skate_off_to_left_pipe_no_wipeout()`:

```gdscript
func _deck_skate_off_to_left_pipe_no_wipeout() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/deck_to_left_pipe.ssk"):
		push_error("deck skate-off: setup")
		return false
	var deck: SupportPatch = null
	var pipe: PipeSurface = null
	for id in sim.model.patches.keys():
		var p: SupportPatch = sim.model.patches[id]
		if int(p.kind) == SimKinds.SurfaceKind.DECK:
			deck = p
			break
	for id in sim.model.pipes.keys():
		var pp: PipeSurface = sim.model.pipes[id]
		if int(pp.side) == SimKinds.PipeSide.LEFT:
			pipe = pp
			break
	if deck == null or pipe == null:
		push_error("deck skate-off: missing deck/pipe")
		return false
	var z := (deck.z_min + deck.z_max) * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = deck.id
	sim.state.position = Vector3(deck.x_max - 15.0, z, deck.height)
	sim.state.tangent_velocity = Vector2(280.0, 0.0)
	sim.state.facing = "r"
	sim.state.clear_hang()
	var saw_air := false
	for i in range(90):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			push_error(
				"deck skate-off: wipeout on leave i=%s x=%.1f h=%.1f sid=%s"
				% [i, sim.state.position.x, sim.state.position.z, sim.state.surface_id]
			)
			return false
		if sim.state.is_airborne():
			saw_air = true
		if saw_air and sim.state.is_grounded() and sim.state.surface_id == pipe.id:
			return true
	push_error(
		"deck skate-off: never mounted pipe mode=%s sid=%s pos=%s air=%s"
		% [sim.state.mode, sim.state.surface_id, sim.state.position, saw_air]
	)
	return false
```

- [ ] **Step 3: Write failing wipeout park test**

```gdscript
func _joint_wipeout_fall_tip_stays_approach() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://levels/layered_demo.ssk"):
		push_error("wipeout park: setup")
		return false
	sim.fall_duration = 5.0
	sim.fall_stop_duration = 0.85
	var wall: WallSurface = sim.model.walls.get("wall_span_coping_pipe_1_L0_S1_0")
	if wall == null:
		push_error("wipeout park: missing wall")
		return false
	var z := 250.0
	var ws: Dictionary = wall.sample_at_z(z)
	var wx := float(ws.x)
	var top := float(ws.top_height)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.free_air_upright = true
	sim.state.air_launch_surface_id = "floor_0_L0"
	sim.state.facing = "r"
	sim.state.position = Vector3(wx - 40.0, z, minf(top - 25.0, 100.0))
	sim.state.velocity = Vector3(500.0, 0.0, -80.0)
	sim.state.note_air_height(sim.state.position.z)
	var fell := false
	for _i in range(50):
		sim.set_input(Vector2(1, 0), false, false)
		sim.tick()
		if sim.state.falling:
			fell = true
			if sim.state.fall_lean_sign >= 0.0:
				push_error("wipeout park: lean into wall %.1f" % sim.state.fall_lean_sign)
				return false
			if sim.state.position.x > wx - SimTolerances.WALL_REJECT_CLEAR + 0.5:
				push_error(
					"wipeout park: feet past clear x=%.1f wx=%.1f"
					% [sim.state.position.x, wx]
				)
				return false
	if not fell:
		push_error("wipeout park: never fell")
		return false
	return true
```

Wire both into `run()` near other layered/deck tests.

- [ ] **Step 4: Run suite — expect FAIL on new ride-off (and/or wipeout if already green)**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `FAIL test_sim_runtime.gd` with `deck skate-off: wipeout on leave` or `never mounted pipe`.

- [ ] **Step 5: Commit tests + fixture**

```bash
git add tests/levels/sim/deck_to_left_pipe.ssk tests/sim/test_sim_runtime.gd
git commit -m "Add failing tests for deck skate-off and wipeout approach park."
```

---

### Task 2: Classifier with-slope + disposition (sim authority)

**Files:**
- Modify: `scripts/sim/crash_classifier.gd`
- Modify: `scripts/sim/air_solver.gd` (`_disposition_for_contact`, `_foreign_pipe_lip_is_crash_wall`, deck leave fall ctx)
- Modify: `scripts/sim/ground_solver.gd` (`_step_patch` ride-off path ~192)
- Test: Task 1 tests

**Interfaces:**
- Produces:
  - `CrashClassifier.deck_abuts_slope(deck_id: String, slope_id: String, z: float) -> bool`
  - `CrashClassifier.is_with_slope(state: SimState, contact: Dictionary, ctx: Dictionary = {}) -> bool`
  - `CrashClassifier.is_foreign_pipe_lip_crash` returns false when `is_with_slope`
- Consumes: `ParkModel` copings / patches / pipes / ramps; `state.air_launch_surface_id`; planar velocity

- [ ] **Step 1: Add helpers on CrashClassifier**

```gdscript
func deck_abuts_slope(deck_id: String, slope_id: String, z: float) -> bool:
	# true when a coping span at z has outward_deck_id == deck_id and source pipe/ramp == slope_id
	...

func is_with_slope(state: SimState, contact: Dictionary, ctx: Dictionary = {}) -> bool:
	# 1) same-slope reentry
	# 2) launch is deck that abuts contact pipe/ramp at state.position.y
	# 3) planar velocity in downhill/into-bowl half-plane of that slope (outward_sign)
	...

func is_foreign_pipe_lip_crash(...) -> bool:
	# existing checks, then:
	if is_with_slope(state, contact, ctx):
		return false
	return u >= 1.0 - ollie_lip_frac
```

- [ ] **Step 2: Air disposition**

In `_disposition_for_contact` / `_foreign_pipe_lip_is_crash_wall`:
- If `crash.is_with_slope(state, contact)` → Mount (or Corridor if rising), never Reject for lip.
- Deck open-side leave: ensure `_contact_requests_fall` gets `deck_ride_off: true` when `air_launch` is that deck (already partially wired); grounded leave must stamp `air_launch_surface_id` before air tick.

- [ ] **Step 3: Ground deck leave**

In `_step_patch` when leaving deck unsupported toward abutting pipe (path that currently airs / falls ~192):

```gdscript
# Ride-off into air: stamp launch; never request_fall for open leave.
state.air_launch_surface_id = patch.id
state.mode = AIRBORNE
# velocity from tangent; no request_fall
```

Remove / bypass any contain path that sets `request_fall` for deck open-side leave into abutting slope airspace.

- [ ] **Step 4: Run Task 1 tests — expect PASS**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `=== N passed, 0 failed ===` (full suite).

- [ ] **Step 5: Commit**

```bash
git add scripts/sim/crash_classifier.gd scripts/sim/air_solver.gd scripts/sim/ground_solver.gd
git commit -m "Treat with-slope deck leave as free air then Mount, not wipeout."
```

---

### Task 3: Wipeout approach park + kinematic fall tip

**Files:**
- Modify: `scripts/sim/air_solver.gd` (wall reject park; tip-skim only for true tip band)
- Modify: `scripts/rendering_3d/logical_pose_presenter_3d.gd`
- Test: `_joint_wipeout_fall_tip_stays_approach` + visual sanity via existing suite

**Interfaces:**
- Consumes: `SimState.fall_lean_sign`, `WALL_REJECT_CLEAR`
- Produces: Fall tip Node3D without RigidBody physics

- [ ] **Step 1: Harden sim wipeout park**

On wall/feature into-face Reject + fall:
- `position.x = face_x + approach * WALL_REJECT_CLEAR`
- `velocity.x` into face = 0; `fall_start_vx` absorbed
- `stamp_fall_lean(approach)`
- Do **not** call `_try_eject_pipe_top_skim` for mid-band joint hits (keep tip-band only: `h` in `[peak - PIPE_TOP_SKIM_BAND, peak + eps]`)

- [ ] **Step 2: Replace FallBox RigidBody with kinematic tip**

In `logical_pose_presenter_3d.gd`:
- Remove `RigidBody3D` fall box (or freeze permanently and never unfreeze).
- Add `MeshInstance3D` tip child; on fall enter show tip at sim feet world pose with tip Euler from `fall_lean_sign * fall_anim_frac`.
- Each `_process` while falling: pose tip from interpolated logical feet + lean; never apply impulses.
- On fall end: hide tip, show body.

```gdscript
func _pose_fall_tip(feet_world: Vector3, lean: float, anim: float, yaw: float) -> void:
	var tip_ang := lean * deg_to_rad(55.0) * clampf(anim, 0.0, 1.0)
	_fall_tip.global_transform = Transform3D(
		Basis.from_euler(Vector3(0.0, yaw, tip_ang)),
		feet_world + Vector3(0.0, body_size.y * 0.5, 0.0)
	)
```

Expose `fall_anim_frac` from player if needed (already have `fall_lean_sign`).

- [ ] **Step 3: Run suite**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add scripts/sim/air_solver.gd scripts/rendering_3d/logical_pose_presenter_3d.gd scripts/player.gd
git commit -m "Drive wipeout tip from sim clearance; stop RigidBody tunneling into walls."
```

---

### Task 4: Docs + final verification

**Files:**
- Modify: `docs/movement_contract.md` (deck→pipe paragraph ~121–124)
- Modify: `docs/gameplay.md` (deck skate-off / fall presentation)
- Modify: `docs/superpowers/specs/2026-07-31-crash-classifier-design.md` (one-line cross-link: foreign-lip narrowed by with-slope)

- [ ] **Step 1: Update contract**

Replace:

```text
Outward `#` remains `OPEN`; riding its deck off onto an abutting pipe does **not**
auto-mount — fall like a ledge (deck→pipe remount TBD).
```

With with-slope leave → free air → Mount on descending ride-face contact; wipeout only into-face.

- [ ] **Step 2: Full suite**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `0 failed`.

- [ ] **Step 3: Commit + push**

```bash
git add docs/movement_contract.md docs/gameplay.md docs/superpowers/specs/2026-07-31-crash-classifier-design.md
git commit -m "Document with-slope deck leave/land and wipeout approach park."
git push origin HEAD
```

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Deck skate-off free air no wipeout | 1, 2 |
| With-slope Mount on abutting pipe | 2 |
| Foreign-lip only into-face | 2 |
| Joint wipeout approach park + lean | 1, 3 |
| Kinematic fall tip | 3 |
| Contract docs | 4 |
| Fly-out regressions stay green | 2–4 suite |

## Placeholder scan

None intentional — fixture header must be copied from a real `tests/levels/sim/*.ssk` at implementation time.
