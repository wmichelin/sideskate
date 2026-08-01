# Bounded Fall Presentation and Containment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore a physics-like visual crash body that cannot enter the analytical support/impact planes, and stop a deck-launched fall from Corridoring through an abutting layered L1 pipe.

**Architecture:** `SimState` records logical fall support and impact planes at the authoritative Reject. `PlayerSim` exposes their world-space conversions to the presenter. A new `FallBoxConstraint` script extends `RigidBody3D`, owns the oriented-box plane clamp in its `_integrate_forces`, and never changes `PlayerSim`. `LogicalPosePresenter3D` restores that body as the visual FallBox. `AirSolver` keeps the deck seam Corridor only while not falling and returns Reject for every deck-abutting slope contact during a fall.

**Tech Stack:** Godot 4 GDScript, `PlayerSim`, `RigidBody3D`, headless test runner, `tools/render_iteration.sh`.

## Global Constraints

- Gameplay simulation runs on fixed physics ticks only.
- `PlayerSim` / `SimState` remain the only gameplay authority.
- The FallBox is presentation-only: no FallBox transform, collision, impulse, or velocity may write sim position or velocity.
- Non-falling deck seam `support_top` / `LIP_COLUMN` remains Corridor.
- Falling deck-launch contacts with the abutting pipe/ramp always Reject; never Corridor or Mount.
- Do not stage `levels/offset_demo.ssk`.

---

### Task 1: Add failing regressions for fall containment

**Files:**
- Modify: `tests/sim/test_sim_runtime.gd`
- Modify: `tests/test_logical_pose.gd`
- Test: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`

**Interfaces:**
- Consumes: `PlayerSim`, `PipeSurface`, `LogicalPosePresenter3D`
- Produces: an L1 deck-launched fall containment regression and oriented-box plane tests

- [ ] **Step 1: Add the deck-launched falling L1-pipe regression**

Add `_falling_deck_launch_rejects_abutting_l1_pipe()` to `test_sim_runtime.gd`
and wire it into `run()` beside the existing deck-launch tests.

Use `res://levels/layered_demo.ssk`. Select a left-side L1 pipe dynamically:

```gdscript
var target: PipeSurface = null
var launch_deck: SupportPatch = null
for id in sim.model.pipes.keys():
	var pipe: PipeSurface = sim.model.pipes[id]
	if int(pipe.side) != SimKinds.PipeSide.LEFT:
		continue
	if not pipe.id.contains("_L1_"):
		continue
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var cope: CopingEdge = sim.model.copings.get(pipe.coping_id)
	var span: CopingSpan = cope.span_at_z(z) if cope != null else null
	if span == null or span.outward_deck_id.is_empty():
		continue
	var deck: SupportPatch = sim.model.patches.get(span.outward_deck_id)
	if deck != null and deck.height > 0.0:
		target = pipe
		launch_deck = deck
		break
```

Start and fall with this exact state:

```gdscript
var z := (target.z_min + target.z_max) * 0.5
var outward := target.outward_sign()
var cope_x := target.coping_x_at(z)
sim.state.mode = SimState.Mode.AIRBORNE
sim.state.surface_id = ""
sim.state.air_launch_surface_id = launch_deck.id
sim.state.position = Vector3(cope_x + outward * 5.0, z, launch_deck.height)
sim.state.velocity = Vector3(-outward * 180.0, 0.0, -80.0)
sim.state.note_air_height(sim.state.position.z)
sim.begin_fall()
```

Tick 90 times. Fail if:

```gdscript
sim.state.is_grounded() and sim.state.surface_id == target.id
```

or if `target.project(sim.state.position.x, z, sim.state.position.z)` is valid
and the current height is below the projected ride height. Require the fall bout
to remain active for at least one tick after the first pipe contact.

- [ ] **Step 2: Add oriented-box plane helpers to the pose test**

In `tests/test_logical_pose.gd`, add these helpers:

```gdscript
func _box_corners(xf: Transform3D, size: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				out.append(xf * Vector3(
					sx * size.x * 0.5,
					sy * size.y * 0.5,
					sz * size.z * 0.5
				))
	return out


func _assert_box_on_plane(
	xf: Transform3D, size: Vector3, point: Vector3, normal: Vector3, label: String
) -> bool:
	for corner in _box_corners(xf, size):
		if normal.dot(corner - point) < -0.0001:
			push_error("%s: FallBox crossed plane at %s" % [label, corner])
			return false
	return true
```

- [ ] **Step 3: Add failing flat, tilted, and impact-plane tests**

Add `_fall_box_stays_above_support_planes()` and
`_fall_box_stays_on_impact_approach_side()` to `run()`. Instantiate
`FallBoxConstraint`, set `box_size = Vector3(0.18, 0.40, 0.14)`, call its new
production helper `transform_for_planes(feet, basis, support_point,
support_normal, impact_point, impact_normal)`, and assert all corners pass:

```gdscript
var basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(55.0)))
var xf := constraint.transform_for_planes(
	Vector3.ZERO, basis, Vector3.ZERO, Vector3.UP, Vector3.ZERO, Vector3.ZERO
)
if not _assert_box_on_plane(xf, constraint.box_size, Vector3.ZERO, Vector3.UP, "flat"):
	return false
```

Repeat with `support_normal = Vector3(0.6, 0.0, 0.8).normalized()` and with
`impact_point = Vector3(-0.2, 0, 0)`,
`impact_normal = Vector3(1, 0, 0)`. The current FallTip implementation has no
FallBox helper, so this test must fail to compile until Task 3.

- [ ] **Step 4: Run RED**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `FAIL test_sim_runtime.gd` because the falling deck launch Corridors
the pipe; `FAIL test_logical_pose.gd` because
`FallBoxConstraint.transform_for_planes` does not exist.

- [ ] **Step 5: Commit only the failing regressions**

```bash
git add tests/sim/test_sim_runtime.gd tests/test_logical_pose.gd
git commit -m "Add fall containment regressions"
```

---

### Task 2: Make fall containment authoritative in the sim

**Files:**
- Modify: `scripts/sim/sim_state.gd`
- Modify: `scripts/sim/player_sim.gd`
- Modify: `scripts/sim/air_solver.gd`
- Modify: `scripts/player.gd`
- Test: `tests/sim/test_sim_runtime.gd`

**Interfaces:**
- Produces: `SimState.stamp_fall_planes(support_point, support_normal, impact_point, impact_normal)`
- Produces: `SimState.clear_fall_planes()`
- Produces: `Player.fall_support_plane_world() -> Dictionary` and `Player.fall_impact_plane_world() -> Dictionary`

- [ ] **Step 1: Add explicit logical plane state to `SimState`**

After `fall_eject_pipe_id`, add:

```gdscript
var fall_support_point: Vector3 = Vector3.ZERO
var fall_support_normal: Vector3 = Vector3(0.0, 0.0, 1.0)
var fall_impact_point: Vector3 = Vector3.ZERO
var fall_impact_normal: Vector3 = Vector3.ZERO
var fall_has_impact_plane: bool = false
```

Add:

```gdscript
func stamp_fall_planes(
	support_point: Vector3, support_normal: Vector3,
	impact_point: Vector3 = Vector3.ZERO, impact_normal: Vector3 = Vector3.ZERO
) -> void:
	fall_support_point = support_point
	fall_support_normal = support_normal.normalized()
	if fall_support_normal.length_squared() < 0.0001:
		fall_support_normal = Vector3(0.0, 0.0, 1.0)
	fall_impact_point = impact_point
	fall_impact_normal = impact_normal.normalized()
	fall_has_impact_plane = fall_impact_normal.length_squared() >= 0.0001


func clear_fall_planes() -> void:
	fall_support_point = Vector3.ZERO
	fall_support_normal = Vector3(0.0, 0.0, 1.0)
	fall_impact_point = Vector3.ZERO
	fall_impact_normal = Vector3.ZERO
	fall_has_impact_plane = false
```

Call `clear_fall_planes()` at the end of `clear_fall()`.

- [ ] **Step 2: Stamp default and Reject-specific planes**

At the beginning of `PlayerSim.begin_fall()`, after the early return and before
setting `falling`, call:

```gdscript
state.stamp_fall_planes(
	state.position, Vector3(0.0, 0.0, 1.0)
)
```

In `AirSolver._reject_air_contact`, after the wall approach `side` is known,
stamp the wall support and impact planes before positioning the sim feet:

```gdscript
state.stamp_fall_planes(
	Vector3(pt_w.x, state.position.y, state.position.z),
	Vector3(0.0, 0.0, 1.0),
	Vector3(pt_w.x, state.position.y, state.position.z),
	Vector3(side, 0.0, 0.0)
)
```

For a pipe/ramp solid Reject while falling, use `contact.projection` and
`contact.normal` as the support point and normal; do not create an impact plane
unless the normal has a nonzero X component pointing toward the approach side.

- [ ] **Step 3: Disable deck-seam Corridor during a fall**

In `_deck_launch_slope_disposition`, immediately after confirming the contact
belongs to the launch deck’s abutting slope, add:

```gdscript
if state.falling:
	return SimKinds.ContactDisposition.REJECT
```

This line must precede the surface-crossing and seam-Corridor branches. It keeps
ordinary deck coast playable, but makes every deck-abutting slope contact reject
while a fall is active.

- [ ] **Step 4: Expose planes to the presenter through `player.gd`**

Add:

```gdscript
func fall_support_plane_world() -> Dictionary:
	if _sim == null or _sim.state == null:
		return {"point": Vector3.ZERO, "normal": Vector3.UP}
	var s := _sim.state
	return {
		"point": WorldSpace.logical_to_world(
			s.fall_support_point.x, s.fall_support_point.y, s.fall_support_point.z
		),
		"normal": WorldSpace.logical_velocity_to_world(
			s.fall_support_normal.x, s.fall_support_normal.y, s.fall_support_normal.z
		).normalized(),
	}


func fall_impact_plane_world() -> Dictionary:
	if _sim == null or _sim.state == null or not _sim.state.fall_has_impact_plane:
		return {}
	var s := _sim.state
	return {
		"point": WorldSpace.logical_to_world(
			s.fall_impact_point.x, s.fall_impact_point.y, s.fall_impact_point.z
		),
		"normal": WorldSpace.logical_velocity_to_world(
			s.fall_impact_normal.x, s.fall_impact_normal.y, s.fall_impact_normal.z
		).normalized(),
	}
```

- [ ] **Step 5: Run sim tests and commit**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
git add scripts/sim/sim_state.gd scripts/sim/player_sim.gd scripts/sim/air_solver.gd scripts/player.gd tests/sim/test_sim_runtime.gd
git commit -m "Contain deck-launched fall contacts"
```

Expected: the new L1 regression and all existing sim tests pass.

---

### Task 3: Restore a bounded visual FallBox

**Files:**
- Create: `scripts/rendering_3d/fall_box_constraint.gd`
- Modify: `scripts/rendering_3d/logical_pose_presenter_3d.gd`
- Modify: `tests/test_logical_pose.gd`
- Test: `tests/test_logical_pose.gd`

**Interfaces:**
- Produces: `FallBoxConstraint.transform_for_planes(feet, basis, support_point, support_normal, impact_point, impact_normal) -> Transform3D`
- Produces: a visual-only `_fall_box: FallBoxConstraint`

- [ ] **Step 1: Restore the old FallBox structure**

Replace `_fall_tip: MeshInstance3D` with:

```gdscript
var _fall_box: FallBoxConstraint
var _fall_mesh: MeshInstance3D
var _fall_mark: MeshInstance3D
```

In `_build_meshes`, recreate `FallBox` with:

```gdscript
_fall_box = FallBoxConstraint.new()
_fall_box.name = "FallBox"
_fall_box.box_size = body_size
_fall_box.mass = 4.0
_fall_box.linear_damp = 0.6
_fall_box.angular_damp = 0.25
_fall_box.continuous_cd = true
_fall_box.collision_layer = CollisionLayersScript.bit(CollisionLayersScript.RAGDOLL)
_fall_box.collision_mask = (
	CollisionLayersScript.bit(CollisionLayersScript.WORLD_RIDE)
	| CollisionLayersScript.bit(CollisionLayersScript.WORLD_WALL)
	| CollisionLayersScript.bit(CollisionLayersScript.PLAYABLE_BOUNDS)
)
_fall_box.freeze = true
_fall_box.visible = false
```

Add a `CollisionShape3D` containing a `BoxShape3D` sized `body_size`, the
existing pink `BoxMesh`, and a yellow `_fall_mark` from `_make_facing_triangle`.
Reparent `_fall_box` to the `World3D` sibling with the existing deferred
reparent pattern.

- [ ] **Step 2: Add oriented-box plane math**

Create `scripts/rendering_3d/fall_box_constraint.gd`:

```gdscript
class_name FallBoxConstraint
extends RigidBody3D

var box_size: Vector3 = Vector3(0.18, 0.40, 0.14)
var support_plane: Dictionary = {}
var impact_plane: Dictionary = {}


func configure_planes(support: Dictionary, impact: Dictionary = {}) -> void:
	support_plane = support.duplicate()
	impact_plane = impact.duplicate()


func _box_radius_along_normal(basis: Basis, normal: Vector3) -> float:
	var n := normal.normalized()
	return (
		absf(n.dot(basis.x)) * box_size.x * 0.5
		+ absf(n.dot(basis.y)) * box_size.y * 0.5
		+ absf(n.dot(basis.z)) * box_size.z * 0.5
	)


func transform_for_planes(
	feet: Vector3, basis: Basis,
	support_point: Vector3, support_normal: Vector3,
	impact_point: Vector3, impact_normal: Vector3
) -> Transform3D:
	var center := feet + basis * Vector3(0.0, box_size.y * 0.5, 0.0)
	var support_n := support_normal.normalized()
	var support_radius := _box_radius_along_normal(basis, support_n)
	var support_dist := support_n.dot(center - support_point)
	if support_dist < support_radius:
		center += support_n * (support_radius - support_dist)
	if impact_normal.length_squared() > 0.0001:
		var impact_n := impact_normal.normalized()
		var impact_radius := _box_radius_along_normal(basis, impact_n)
		var impact_dist := impact_n.dot(center - impact_point)
		if impact_dist < impact_radius:
			center += impact_n * (impact_radius - impact_dist)
	return Transform3D(basis, center)


func _integrate_forces(physics_state: PhysicsDirectBodyState3D) -> void:
	if freeze or support_plane.is_empty():
		return
	var xf := physics_state.transform
	var support_point: Vector3 = support_plane.point
	var support_normal: Vector3 = support_plane.normal
	var support_radius := _box_radius_along_normal(xf.basis, support_normal)
	var support_dist := support_normal.dot(xf.origin - support_point)
	if support_dist < support_radius:
		xf.origin += support_normal * (support_radius - support_dist)
		physics_state.linear_velocity = physics_state.linear_velocity.slide(support_normal)
	if not impact_plane.is_empty():
		var impact_point: Vector3 = impact_plane.point
		var impact_normal: Vector3 = impact_plane.normal
		var impact_radius := _box_radius_along_normal(xf.basis, impact_normal)
		var impact_dist := impact_normal.dot(xf.origin - impact_point)
		if impact_dist < impact_radius:
			xf.origin += impact_normal * (impact_radius - impact_dist)
			physics_state.linear_velocity = physics_state.linear_velocity.slide(impact_normal)
	physics_state.transform = xf
```

- [ ] **Step 3: Start the physical visual tumble**

On the falling edge in `_physics_process`, read:

```gdscript
var support: Dictionary = _player.call("fall_support_plane_world")
var impact: Dictionary = _player.call("fall_impact_plane_world")
_fall_box.configure_planes(support, impact)
```

Build the tipped basis from visual yaw, facing, surface tilt, and
`fall_lean_sign`. Use `_fall_box.transform_for_planes` with the plane
dictionaries to set `_fall_box.global_transform`, then unfreeze it and set:

```gdscript
_fall_box.linear_velocity = (_player.call(
	"motion_world", MotionVectors.Kind.ACTUAL
) as Vector3).limit_length(8.0)
_fall_box.angular_velocity = basis * Vector3(0.0, 0.0, -lean * 8.0)
_fall_box.apply_impulse(
	basis * Vector3(lean * 1.4, 0.0, 0.0),
	basis * Vector3(0.0, body_size.y * 0.35, 0.0)
)
```

Hide `_body`, show `_fall_box`, and never call `_pose_fall_tip`. On fall exit,
zero velocities, freeze/hide `_fall_box`, call `_fall_box.configure_planes({})`,
and show `_body`.

- [ ] **Step 4: Run visual tests and commit**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
git add scripts/rendering_3d/fall_box_constraint.gd \
  scripts/rendering_3d/logical_pose_presenter_3d.gd tests/test_logical_pose.gd
git commit -m "Restore bounded physics-like fall tumble"
```

Expected: `test_logical_pose.gd` proves every FallBox corner remains above the
flat/tilted support plane and on the impact approach side.

---

### Task 4: Update docs and execute all final gates

**Files:**
- Modify: `docs/movement_contract.md`
- Modify: `docs/gameplay.md`
- Modify: `docs/superpowers/specs/2026-08-01-bounded-fall-presentation-containment-design.md`

- [ ] **Step 1: Document the two corrected rules**

State that falling deck-launch contacts always Reject and clear; the seam
Corridor exists only outside a fall bout. State that FallBox is a
presentation-only physics body bounded by simulation-owned support/impact
planes.

- [ ] **Step 2: Run all verification gates**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
./tools/render_iteration.sh plaza_default spawn 3d-only
./tools/render_iteration.sh spine_demo spawn 3d-only
./tools/render_iteration.sh layered_demo spawn 3d-only
./tools/render_iteration.sh variable_height_ramps spawn 3d-only
./tools/render_iteration.sh plaza_default_deep spawn pair
```

Expected: `=== 15 passed, 0 failed ===`; every report JSON has `"errors": []`;
the pair report has `"escape_ok": true`.

- [ ] **Step 3: Commit and push**

```bash
git add docs/movement_contract.md docs/gameplay.md \
  docs/superpowers/specs/2026-08-01-bounded-fall-presentation-containment-design.md \
  docs/superpowers/plans/2026-08-01-bounded-fall-presentation-containment.md
git commit -m "Document bounded fall presentation containment"
git push origin HEAD
```
