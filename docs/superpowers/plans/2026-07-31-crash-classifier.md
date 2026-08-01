# Crash classifier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize sudden-stop fall policy in `CrashClassifier`; foreign pipe upper-lip Reject+fall, hang flat clip fall, pipe/ramp outer-back fall; keep same-slope remount playable.

**Architecture:** New `scripts/sim/crash_classifier.gd` owns enumerated crash rules. `PlayerSim` constructs it and syncs `ollie_lip_frac`. `AirSolver` / `GroundSolver` consult it instead of ad-hoc `_contact_requests_fall` duplicates. Fall bout + checkpoint recovery unchanged.

**Tech Stack:** Godot 4 GDScript, analytical `PlayerSim` / `AirSolver` / `GroundSolver`, headless `tests/test_runner.gd`.

## Global Constraints

- Physics-tick only for gameplay simulation.
- Same-slope (or Z-adjacent ramp↔pipe) remount must not crash, including upper lip band.
- Foreign pipe `u ≥ 1 - ollie_lip_frac` → Reject + fall, never Mount.
- Ramp ride face never crashes from this rule; ramp **and pipe** outer-back do.
- Lava kill still wins over fall.
- No general body-parallel classifier this pass.

## File map

| File | Role |
|------|------|
| Create `scripts/sim/crash_classifier.gd` | Pure crash policy |
| Modify `scripts/sim/player_sim.gd` | Own classifier; sync lip frac; wire into air/ground |
| Modify `scripts/sim/air_solver.gd` | Use classifier; foreign high pipe Reject; hang clip |
| Modify `scripts/sim/ground_solver.gd` | Use classifier on contain bail |
| Modify `tests/sim/test_sim_runtime.gd` | New regression tests |
| Modify `docs/movement_contract.md`, `docs/gameplay.md` | Document triggers |

---

### Task 1: CrashClassifier + wire into PlayerSim / solvers (migrate existing bail)

**Files:**
- Create: `scripts/sim/crash_classifier.gd`
- Modify: `scripts/sim/player_sim.gd` (`_finish_setup`, tick lip sync)
- Modify: `scripts/sim/air_solver.gd` (`_init`, replace `_contact_requests_fall` body)
- Modify: `scripts/sim/ground_solver.gd` (optional hold ref; or call via air.crash)
- Test: existing fall impact tests must keep passing

**Interfaces:**
- Produces: `CrashClassifier.is_crash(state, contact, ctx: Dictionary = {}) -> bool`
- `ctx` keys: `u` (float, optional), `launch_id` (String, optional), `was_hanging` (bool), `mode` (`"reject"` / `"hang_flat_mount"` / `"hang_clip"` / `"ground_contain"`)
- Consumes: `ParkModel`, `ollie_lip_frac`

- [x] **Step 1: Add failing test for foreign high-pipe crash (TDD entry)**

In `tests/sim/test_sim_runtime.gd` `run()`, add `_crash_foreign_pipe_lip_rejects_and_falls()` after fall recovery tests.

```gdscript
func _crash_foreign_pipe_lip_rejects_and_falls() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("crash lip: setup")
		return false
	var right: PipeSurface = null
	var floor_id := ""
	for id in sim.model.pipes.keys():
		var p: PipeSurface = sim.model.pipes[id]
		if p.side == SimKinds.PipeSide.RIGHT:
			right = p
			break
	for id in sim.model.patches.keys():
		if int(sim.model.patches[id].kind) == SimKinds.SurfaceKind.FLOOR:
			floor_id = id
			break
	if right == null or floor_id.is_empty():
		push_error("crash lip: missing pipe/floor")
		return false
	var z := (right.z_min + right.z_max) * 0.5
	var u := 0.92
	var th := u * PI * 0.5
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.clear_hang()
	sim.state.air_launch_surface_id = floor_id
	sim.state.position = Vector3(
		right.x_at_theta(z, th), z, right.height_at_theta(z, th) + 20.0
	)
	sim.state.velocity = Vector3(0.0, 0.0, -200.0)
	sim.state.note_air_height(sim.state.position.z)
	for _i in range(60):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.is_grounded() and sim.state.surface_id == right.id:
			push_error("crash lip: must not Mount foreign high pipe")
			return false
		if sim.state.falling:
			return true
	push_error("crash lip: never fell")
	return false
```

- [x] **Step 2: Run test — expect FAIL**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `FAIL test_sim_runtime.gd` with `crash lip: never fell` or Mount error.

- [x] **Step 3: Implement `CrashClassifier`**

```gdscript
class_name CrashClassifier
extends RefCounted
## Enumerated sudden-stop fall policy for AirSolver / GroundSolver.


var model: ParkModel
var ollie_lip_frac: float = 0.50


func _init(m: ParkModel = null, lip_frac: float = 0.50) -> void:
	model = m
	ollie_lip_frac = clampf(lip_frac, 0.0, 1.0)


func set_ollie_lip_frac(lip_frac: float) -> void:
	ollie_lip_frac = clampf(lip_frac, 0.0, 1.0)


## `ctx`: optional u, launch_id, was_hanging, mode, launch_exit (bool), deck_ride_off (bool).
func is_crash(state: SimState, contact: Dictionary, ctx: Dictionary = {}) -> bool:
	if state == null or model == null or not state.alive or state.falling:
		return false
	var mode := str(ctx.get("mode", "reject"))
	if mode == "hang_flat_mount" or mode == "hang_clip":
		return _hang_flat_crash(state, contact, ctx)
	# Hang remount path must not use reject-bail table.
	if state.is_hanging() and mode != "hang_flat_mount" and mode != "hang_clip":
		return false
	if bool(ctx.get("launch_exit", false)) or bool(ctx.get("deck_ride_off", false)):
		return false
	var kind := str(contact.get("kind", ""))
	var role := int(contact.get("role", SimKinds.ContactRole.SOLID))
	var reason := str(contact.get("reason", ""))
	if reason == "slope outer back":
		return true
	if kind == "bounds" or role == SimKinds.ContactRole.BOUNDS:
		return true
	if kind == "feature_wall":
		return true
	if kind == "deck" or role == SimKinds.ContactRole.OUTWARD_DECK:
		return true
	if _foreign_pipe_lip_crash(state, contact, ctx):
		return true
	return false


func _hang_flat_crash(state: SimState, contact: Dictionary, ctx: Dictionary) -> bool:
	if not state.is_hanging() and not bool(ctx.get("was_hanging", false)):
		return false
	var sid := str(contact.get("owner_id", contact.get("surface_id", "")))
	if sid == "__void_floor__" or sid == "__park_floor__":
		return true
	if model.patches.has(sid):
		var patch: SupportPatch = model.patches[sid]
		var pk := int(patch.kind)
		if patch.lethal:
			return false
		return pk == SimKinds.SurfaceKind.FLOOR or pk == SimKinds.SurfaceKind.DECK
	var kind := str(contact.get("kind", ""))
	if kind == "deck" or int(contact.get("role", -1)) == SimKinds.ContactRole.OUTWARD_DECK:
		return true
	if kind == "support_top":
		var sk := int(contact.get("support_kind", -1))
		return sk == SimKinds.SurfaceKind.FLOOR or sk == SimKinds.SurfaceKind.DECK
	return false


func _foreign_pipe_lip_crash(state: SimState, contact: Dictionary, ctx: Dictionary) -> bool:
	var pipe := _contact_pipe(contact)
	if pipe == null:
		return false
	if _is_same_slope_reentry(state, pipe, ctx):
		return false
	var u := float(ctx.get("u", NAN))
	if is_nan(u):
		u = _estimate_pipe_u(pipe, state.position)
	if is_nan(u):
		return false
	var lip := clampf(ollie_lip_frac, 0.0, 1.0)
	return u >= 1.0 - lip


func _contact_pipe(contact: Dictionary) -> PipeSurface:
	var owner := str(contact.get("owner_id", contact.get("surface_id", "")))
	if model.pipes.has(owner):
		return model.pipes[owner]
	if model.walls.has(owner):
		var wall: WallSurface = model.walls[owner]
		return model.pipes.get(wall.source_pipe_id)
	var kind := str(contact.get("kind", ""))
	if kind == "support_top" and int(contact.get("support_kind", -1)) == SimKinds.SurfaceKind.PIPE:
		return model.pipes.get(owner)
	if kind == "pipe":
		return model.pipes.get(owner)
	return null


func _is_same_slope_reentry(state: SimState, pipe: PipeSurface, ctx: Dictionary) -> bool:
	var launch := str(ctx.get("launch_id", ""))
	if launch.is_empty() and state != null:
		launch = state.air_launch_surface_id
	if state != null and state.is_hanging():
		# Hang source pipe counts as same-slope.
		return true # caller should not invoke lip crash while hang-owned; belt
	if launch.is_empty() or pipe == null:
		return false
	if launch == pipe.id:
		return true
	# Z-adjacent ramp↔pipe: AirSolver helper parity — classifier duplicates abut check via model.
	if model.ramps.has(launch):
		return _ramp_abuts_pipe(launch, pipe, state.position.y if state != null else 0.0)
	return false


func _ramp_abuts_pipe(ramp_id: String, pipe: PipeSurface, z: float) -> bool:
	# Minimal footprint/side check; AirSolver keeps the detailed abut for motion.
	if not model.ramps.has(ramp_id) or pipe == null:
		return false
	var ramp: RampSurface = model.ramps[ramp_id]
	return ramp.side == pipe.side


func _estimate_pipe_u(pipe: PipeSurface, at: Vector3) -> float:
	var proj := pipe.project(at.x, at.y, at.z)
	if bool(proj.get("ok", false)):
		return float(proj.u)
	return NAN
```

Note: refine `_ramp_abuts_pipe` / hang same-slope in Task 2 to call into shared helpers if abut is too loose — prefer injecting a Callable or duplicating AirSolver’s `_ramp_launch_abuts_pipe` logic into the classifier for correctness.

- [x] **Step 4: Wire classifier**

`PlayerSim._finish_setup`:
```gdscript
crash = CrashClassifier.new(model, ollie_lip_frac)
air.crash = crash
ground.crash = crash
```

Each tick before solvers: `crash.set_ollie_lip_frac(ollie_lip_frac)`.

`AirSolver._contact_requests_fall` → delegate to `crash.is_crash(...)` with carve-out ctx (`launch_exit`, `deck_ride_off` from existing helpers).

- [x] **Step 5: Foreign high pipe disposition = Reject + request_fall**

In `_disposition_for_contact`, before Mount on lip column / pipe body / pipe support_top:
if classifier says foreign lip crash → `REJECT` (and `_reject_air_contact` will set fall).

Also refuse `_mount_pipe_owner` / snap when classifier would crash (defense in depth).

- [x] **Step 6: Hang clip flat**

While hanging, if contact is floor/deck solid (blocker / deck / support_top flat) and not remountable source: `request_fall` even when disposition was Corridor. Prefer: if hang + crash.hang_clip → Reject path or set flag without Mount.

- [x] **Step 7: Run suite — foreign lip test PASS; existing fall tests PASS**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `=== N passed, 0 failed ===`

- [x] **Step 8: Commit**

```bash
git add scripts/sim/crash_classifier.gd scripts/sim/player_sim.gd scripts/sim/air_solver.gd scripts/sim/ground_solver.gd tests/sim/test_sim_runtime.gd
git commit -m "Add CrashClassifier; foreign high pipe Reject+fall."
```

---

### Task 2: Remaining tests + docs

**Files:**
- Modify: `tests/sim/test_sim_runtime.gd`
- Modify: `docs/movement_contract.md`, `docs/gameplay.md`
- Modify: `docs/superpowers/specs/2026-07-31-fall-impact-triggers-design.md` (cross-link superseded trigger table)

- [x] **Step 1: Add tests**

1. `_crash_foreign_pipe_below_lip_may_mount` — floor launch, `u≈0.4`, descending → can Mount, not forced fall from lip rule.
2. `_crash_same_slope_upper_remount_no_bail` — air_launch = pipe, land upper band → not fall from lip rule.
3. `_crash_hang_clips_deck_requests_fall` — hang over deck solid → falling.
4. Keep existing outer-back / bounds / hang-flat / peak-leave tests green (pipe outer-back covered by feature_wall reason).

- [x] **Step 2: Update docs** per spec “Docs to update”

- [x] **Step 3: Full suite + commit**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
git add docs/ tests/sim/test_sim_runtime.gd
git commit -m "Test and document crash classifier fall triggers."
```

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| CrashClassifier util | 1 |
| Foreign pipe upper lip Reject+fall | 1 |
| Same-slope remount exempt | 1–2 |
| Hang clip flat | 1–2 |
| Bounds / deck wall / outer-back (pipe+ramp) | 1 (migrate) |
| Ramp ride face not crash | 1 (no rule) |
| Checkpoint recovery unchanged | (existing) |
| Docs + tests | 2 |
