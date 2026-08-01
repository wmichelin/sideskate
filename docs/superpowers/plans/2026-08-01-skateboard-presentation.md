# Skateboard Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an orange rider on a red-nose / blue-tail placeholder board with presentation-owned independent `board_yaw`, hang-apex co-rotation, and a dual RigidBody fall (rider + board).

**Architecture:** `board_yaw` lives on `LogicalPose` snapshots. A small `BoardYawTracker` applies spawn/restore snaps, hang-apex deltas (skipping the facing_yaw settle handoff), and never reacts to gameplay facing flips. `LogicalPosePresenter3D` draws rider + board under the shared lean root and replaces the single FallBox with `RiderFall` + `BoardFall`. Camera/debug keep tracking the rider fall body only. `PlayerSim` is unchanged.

**Tech Stack:** Godot 4 GDScript, `LogicalPose` / pose snapshots, `FallBoxConstraint`, headless `tests/test_runner.gd`.

## Global Constraints

- Gameplay simulation runs on fixed physics ticks only.
- `PlayerSim` / `SimState` remain the only gameplay authority; board yaw is presentation-only in this slice.
- Fall RigidBodies are presentation-only: never write sim position or velocity.
- Prefer **fly-out** vocabulary in code; do not invent synonyms.
- Do not stage `levels/offset_demo.ssk`.
- Spec: `docs/superpowers/specs/2026-08-01-skateboard-presentation-design.md`.

## File structure

| File | Role |
|------|------|
| `scripts/logical_pose.gd` | Add `board_yaw`; copy / lerp |
| `scripts/rendering_3d/board_yaw_tracker.gd` | Snap / apex-delta / handoff skip rules |
| `scripts/player.gd` | Own tracker; stamp pose; snap on boot / fall end / respawn |
| `scripts/rendering_3d/logical_pose_presenter_3d.gd` | Orange rider, board meshes, apply board yaw, dual fall bodies |
| `scripts/rendering_3d/camera_rig_3d.gd` | `fall_box_path` → `../RiderFall` |
| `scripts/rendering_3d/player_debug_3d.gd` | Same rider fall path |
| `tests/test_logical_pose.gd` | Lerp, tracker rules, board apply_pose, dual fall planes |
| `docs/gameplay.md` | Presentation + fall note |

---

### Task 1: `LogicalPose.board_yaw` lerp

**Files:**
- Modify: `scripts/logical_pose.gd`
- Modify: `tests/test_logical_pose.gd`
- Test: `godot4 --headless --path . --script res://tests/test_runner.gd`

**Interfaces:**
- Consumes: existing `LogicalPose` / `lerp_poses`
- Produces: `var board_yaw: float = 0.0` on `LogicalPose`; copied in `duplicate_pose` / `copy_from_depth` (default 0); `lerp_angle`'d in `lerp_poses`

- [ ] **Step 1: Write the failing lerp assertion**

In `tests/test_logical_pose.gd`, extend `_lerp_midpoint()`:

```gdscript
	a.board_yaw = 0.0
	b.board_yaw = PI
	# ... existing mid checks ...
	if absf(mid.board_yaw - PI * 0.5) > 0.01:
		push_error("lerp board_yaw: %s" % mid.board_yaw)
		return false
```

Wire nothing else yet. `run()` already calls `_lerp_midpoint()`.

- [ ] **Step 2: Run tests — expect FAIL**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: FAIL with `lerp board_yaw` (property missing or always 0).

- [ ] **Step 3: Add `board_yaw` to `LogicalPose`**

In `scripts/logical_pose.gd`:

```gdscript
## Persistent presentation board yaw (local Y in lean frame). Independent of facing.
var board_yaw: float = 0.0
```

In `copy_from_depth`, leave `board_yaw` untouched (caller stamps it) **or** set `board_yaw = 0.0` explicitly and always overwrite in `player.gd` — prefer leave untouched so `copy_from_depth` does not wipe a value already set; simplest: do not assign in `copy_from_depth`.

In `duplicate_pose`:

```gdscript
	p.board_yaw = board_yaw
```

In `lerp_poses`, after `depth_turn_yaw`:

```gdscript
	out.board_yaw = lerp_angle(a.board_yaw, b.board_yaw, u)
```

- [ ] **Step 4: Run tests — expect PASS for board_yaw lerp**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: PASS (or only unrelated failures none).

- [ ] **Step 5: Commit**

```bash
git add scripts/logical_pose.gd tests/test_logical_pose.gd
git commit -m "$(cat <<'EOF'
Add board_yaw to LogicalPose and lerp it between snapshots.

EOF
)"
```

---

### Task 2: `BoardYawTracker` rules

**Files:**
- Create: `scripts/rendering_3d/board_yaw_tracker.gd`
- Modify: `tests/test_logical_pose.gd`
- Test: `godot4 --headless --path . --script res://tests/test_runner.gd`

**Interfaces:**
- Consumes: facing_h (`float`, +1 right / −1 left), `facing_yaw` (`float`)
- Produces:

```gdscript
class_name BoardYawTracker
extends RefCounted

var yaw: float = 0.0

func snap_to_facing(facing_h: float) -> void
func tick(facing_h: float, facing_yaw: float, force_snap: bool = false) -> float
```

Rules for `tick`:
1. If `force_snap` or first call: `yaw = 0.0` if `facing_h >= 0.0` else `PI`; store `facing_yaw`; return `yaw`.
2. Else compute `dyaw = angle_difference(_prev_facing_yaw, facing_yaw)`.
3. **Handoff skip:** if `absf(absf(_prev_facing_yaw) - PI) < 0.01` and `absf(facing_yaw) < 0.01`, do **not** add `dyaw` (apex settle / facing flip canonicalize).
4. Else if `absf(dyaw) > 0.0001`: `yaw += dyaw` (no need to wrap for storage; presenter can use as-is).
5. Facing_h changes alone never alter `yaw`.
6. Update `_prev_facing_yaw = facing_yaw`; return `yaw`.

- [ ] **Step 1: Write failing tracker tests**

Add to `tests/test_logical_pose.gd` and `run()`:

```gdscript
func _board_yaw_tracker_rules() -> bool:
	var t := BoardYawTracker.new()
	if absf(t.tick(1.0, 0.0, true) - 0.0) > 0.001:
		push_error("snap right should be 0")
		return false
	# Facing flip alone: no change
	var y0 := t.tick(-1.0, 0.0, false)
	if absf(y0) > 0.001:
		push_error("facing flip must not change board_yaw, got %s" % y0)
		return false
	# Apex co-rotation: facing_yaw 0 → -PI
	var y1 := t.tick(-1.0, -PI * 0.5, false)
	if absf(y1 - (-PI * 0.5)) > 0.01:
		push_error("apex mid delta failed: %s" % y1)
		return false
	var y2 := t.tick(-1.0, -PI, false)
	if absf(y2 - (-PI)) > 0.01:
		push_error("apex end delta failed: %s" % y2)
		return false
	# Handoff: facing_yaw -PI → 0 must not spin the board back
	var y3 := t.tick(1.0, 0.0, false)
	if absf(y3 - (-PI)) > 0.01 and absf(y3 - PI) > 0.01:
		# -PI and PI are equivalent orientation; accept either
		push_error("handoff must keep board orientation, got %s" % y3)
		return false
	# Depth turn is NOT the tracker's job — ensure force_snap restore
	var y4 := t.tick(1.0, 0.0, true)
	if absf(y4) > 0.001:
		push_error("force_snap right failed: %s" % y4)
		return false
	return true
```

Note: after apex to `-PI`, handoff with `facing_h=1` and `facing_yaw=0` must keep yaw at `-PI` (or `PI`). The `absf(y3 - PI) > 0.01` clause accepts the equivalent angle if implementation normalizes.

- [ ] **Step 2: Run tests — expect FAIL**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: FAIL — `BoardYawTracker` missing.

- [ ] **Step 3: Implement `BoardYawTracker`**

Create `scripts/rendering_3d/board_yaw_tracker.gd`:

```gdscript
class_name BoardYawTracker
extends RefCounted
## Presentation board yaw: snap on spawn/restore; co-rotate with hang apex facing_yaw.

var yaw: float = 0.0
var _prev_facing_yaw: float = 0.0
var _inited: bool = false


func snap_to_facing(facing_h: float) -> void:
	yaw = 0.0 if facing_h >= 0.0 else PI
	_inited = true


func tick(facing_h: float, facing_yaw: float, force_snap: bool = false) -> float:
	if force_snap or not _inited:
		snap_to_facing(facing_h)
		_prev_facing_yaw = facing_yaw
		return yaw
	var dyaw := angle_difference(_prev_facing_yaw, facing_yaw)
	var handoff := (
		absf(absf(_prev_facing_yaw) - PI) < 0.01
		and absf(facing_yaw) < 0.01
	)
	if absf(dyaw) > 0.0001 and not handoff:
		yaw += dyaw
	_prev_facing_yaw = facing_yaw
	return yaw
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/rendering_3d/board_yaw_tracker.gd tests/test_logical_pose.gd
git commit -m "$(cat <<'EOF'
Add BoardYawTracker for independent board yaw with apex co-rotation.

EOF
)"
```

---

### Task 3: Orange rider + board meshes and `apply_pose`

**Files:**
- Modify: `scripts/rendering_3d/logical_pose_presenter_3d.gd`
- Modify: `tests/test_logical_pose.gd`
- Test: `godot4 --headless --path . --script res://tests/test_runner.gd`

**Interfaces:**
- Consumes: `LogicalPose.board_yaw`, `depth_turn_yaw`, `surface_tilt`
- Produces:
  - Rider albedo `Color(1.0, 0.45, 0.08)` (orange)
  - Node `Board` under presenter root with children `BoardNose` (red `Color(0.9, 0.12, 0.12)`) and `BoardTail` (blue `Color(0.15, 0.35, 0.95)`)
  - `@export var board_size: Vector3 = Vector3(0.40, 0.05, 0.14)` — X length (nose↔tail), Y thickness, Z cross-width
  - Board local Y rotation = `pose.board_yaw + pose.depth_turn_yaw` (no facing scale flip on board)
  - Board position: `Vector3(0, -board_size.y * 0.5, 0)` so the top face sits at feet (local ground)

Geometry for halves (each a `BoxMesh` under `Board`):
- Nose: size `(board_size.x * 0.5, board_size.y, board_size.z)`, position `(+board_size.x * 0.25, 0, 0)`
- Tail: same size, position `(-board_size.x * 0.25, 0, 0)`

Update `_centered_y_turn_presentation` expectations: body still uses `facing_yaw + depth_turn_yaw`; add board checks.

- [ ] **Step 1: Write failing presentation assertions**

Replace/extend the end of `_centered_y_turn_presentation()` after `apply_pose`:

```gdscript
	var board := presenter.get_node_or_null("Board") as Node3D
	if board == null:
		push_error("Y-turn presentation: missing Board")
		presenter.free()
		return false
	pose.board_yaw = 0.7
	presenter.apply_pose(pose)
	var expect_board_yaw := pose.board_yaw + pose.depth_turn_yaw
	if absf(board.rotation.y - expect_board_yaw) > 0.01:
		push_error("board yaw must be board_yaw+depth_turn, got %s" % board.rotation.y)
		presenter.free()
		return false
	# Facing scale must not flip the board node
	if board.scale.x < 0.0:
		push_error("board must not use facing scale flip")
		presenter.free()
		return false
```

Keep existing body checks. Also assert rider material is orange after `_build_meshes` if easy (`_body_mat.albedo_color` roughly orange), or skip color in headless and rely on code review — prefer a simple albedo check:

```gdscript
	var mat := (body.material_override as StandardMaterial3D)
	if mat == null or mat.albedo_color.r < 0.8 or mat.albedo_color.g < 0.3:
		push_error("rider must be orange placeholder")
		presenter.free()
		return false
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: FAIL — missing `Board` / still pink.

- [ ] **Step 3: Implement meshes + `apply_pose` board path**

In `_build_meshes`:
- Set `_body_mat.albedo_color = Color(1.0, 0.45, 0.08, 1.0)`.
- Build `Board` node + nose/tail meshes as above; store `_board: Node3D`.
- Keep building fall bodies for now as a single FallBox (Task 4 renames/splits) **or** leave FallBox until Task 4 — do not break camera yet. Task 3 only adds riding visuals; FallBox can still clone rider color (orange).

In `apply_pose`:
- When not falling: show `_body` and `_board`; set root `rotation.z = tilt`.
- Board: `_board.rotation = Vector3(0, pose.board_yaw + pose.depth_turn_yaw, 0)`; `_board.position = Vector3(0, -board_size.y * 0.5, 0)`; `_board.scale = Vector3.ONE`.
- When falling (existing FallBox active): hide `_body` and `_board`.

- [ ] **Step 4: Run tests — expect PASS**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/rendering_3d/logical_pose_presenter_3d.gd tests/test_logical_pose.gd
git commit -m "$(cat <<'EOF'
Present orange rider and red/blue board with independent yaw.

EOF
)"
```

---

### Task 4: Wire `BoardYawTracker` in `player.gd`

**Files:**
- Modify: `scripts/player.gd`
- Modify: `tests/test_logical_pose.gd` (optional pure tests already cover tracker; add restore-snap note via tracker `force_snap` already tested)
- Test: `godot4 --headless --path . --script res://tests/test_runner.gd`

**Interfaces:**
- Consumes: `BoardYawTracker.tick`, `visual_facing_h`, `facing_yaw`, `is_falling()`
- Produces: each pose snapshot’s `board_yaw`; snaps when:
  - first capture after boot
  - fall bout ends (`_was_falling` → not falling) — use a `_was_falling_for_board` flag updated in `_physics_process` after sync, or inside `_capture_pose_snapshots` by reading `is_falling()` edge
  - respawn (`_on_death_finished` before capture) via `force_snap`

- [ ] **Step 1: Write a small wiring regression (optional but preferred)**

Add `_board_yaw_depth_turn_not_persisted()` that only documents the contract via tracker + pose fields (no Godot player tree):

```gdscript
func _board_yaw_depth_turn_not_persisted() -> bool:
	var t := BoardYawTracker.new()
	t.tick(1.0, 0.0, true)
	var pose := LogicalPose.new()
	pose.board_yaw = t.yaw
	pose.depth_turn_yaw = 0.3
	# Presenter would show board_yaw+depth_turn; stored board_yaw unchanged
	if absf(pose.board_yaw) > 0.001:
		push_error("depth turn must not bake into board_yaw")
		return false
	return true
```

Add to `run()`.

- [ ] **Step 2: Run tests — expect PASS** (contract test does not need player yet)

- [ ] **Step 3: Wire player**

In `player.gd`:

```gdscript
var _board_yaw := BoardYawTracker.new()
var _was_falling_board: bool = false
```

In `_capture_pose_snapshots`:

```gdscript
	var facing := 1.0 if visual_facing_h == "r" else -1.0
	var falling := _sim != null and _sim.state != null and _sim.state.falling
	var force_snap := false
	if _was_falling_board and not falling:
		force_snap = true
	_was_falling_board = falling
	var next = _LogicalPose.new()
	next.copy_from_depth(depth, facing, 0)
	next.facing_yaw = facing_yaw
	next.depth_turn_yaw = deg_to_rad(depth_turn_degrees) * _last_wish.y * facing
	next.board_yaw = _board_yaw.tick(facing, facing_yaw, force_snap or not _pose_snap_ready)
	# ... rest unchanged
```

In `_on_death_finished`, before `_capture_pose_snapshots()`:

```gdscript
	_board_yaw.snap_to_facing(1.0 if visual_facing_h == "r" else -1.0)
```

(Or pass `force_snap` on the next capture by setting a `_board_force_snap` flag.)

- [ ] **Step 4: Run full suite**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/player.gd tests/test_logical_pose.gd
git commit -m "$(cat <<'EOF'
Drive pose board_yaw from BoardYawTracker on physics snapshots.

EOF
)"
```

---

### Task 5: Dual fall bodies (`RiderFall` + `BoardFall`)

**Files:**
- Modify: `scripts/rendering_3d/logical_pose_presenter_3d.gd`
- Modify: `scripts/rendering_3d/camera_rig_3d.gd` (`fall_box_path` default `../RiderFall`)
- Modify: `scripts/rendering_3d/player_debug_3d.gd` (`fall_box_path` default `../RiderFall`)
- Modify: `tests/test_logical_pose.gd`
- Test: `godot4 --headless --path . --script res://tests/test_runner.gd`

**Interfaces:**
- Consumes: `FallBoxConstraint`, pose `board_yaw` / lean / feet at fall enter
- Produces:
  - `RiderFall` — rename of current FallBox (orange, mass 4.0, facing mark); camera/debug track this
  - `BoardFall` — `FallBoxConstraint` with `box_size = board_size`, mass `1.0`, linear_damp `0.8`, angular_damp `0.4`; mesh = nose+tail (or single board-colored box split); no facing mark
  - Both reparented under `World3D` like today
  - On fall start: hide rider+board pose meshes; start both with shared support/impact planes; rider impulse as today; board uses `basis` from `board_yaw + depth_turn_yaw` and lean tilt, velocity from `motion_world`, lighter impulse e.g. `basis * Vector3(-lean * 0.6, 0.2, 0.0)` and small angular `basis * Vector3(0, lean * 3.0, -lean * 2.0)`
  - On fall stop: freeze+hide both; show pose meshes

- [ ] **Step 1: Extend plane tests for board-sized box**

In `tests/test_logical_pose.gd`, add and wire into `run()`:

```gdscript
func _board_fall_box_stays_above_support_planes() -> bool:
	var constraint := FallBoxConstraint.new()
	constraint.box_size = Vector3(0.40, 0.05, 0.14)
	var basis := Basis.from_euler(Vector3(0.0, 0.4, deg_to_rad(35.0)))
	var xf := constraint.transform_for_planes(
		Vector3.ZERO, basis, Vector3.ZERO, Vector3.UP, Vector3.ZERO, Vector3.ZERO
	)
	var ok := _assert_box_on_plane(xf, constraint.box_size, Vector3.ZERO, Vector3.UP, "board flat")
	constraint.free()
	return ok
```

- [ ] **Step 2: Run tests — expect PASS** (uses existing `transform_for_planes`; no presenter change required yet)

- [ ] **Step 3: Split fall bodies in the presenter**

Refactor `_build_meshes` fall setup into a helper:

```gdscript
func _make_fall_body(p_name: String, size: Vector3, mass: float, mat: Material, with_mark: bool) -> FallBoxConstraint:
	# same collision setup as current FallBox; name = p_name
```

- Create `_rider_fall` (`"RiderFall"`, `body_size`, mass 4.0, orange, with mark).
- Create `_board_fall` (`"BoardFall"`, `board_size`, mass 1.0, board materials — can use a neutral dark mat or attach two half meshes; simplest: one `BoxMesh` of `board_size` with a mid-split look via two child meshes parented to the rigid body).
- `_reparent_fall_box` → `_reparent_fall_bodies` for both.
- `_start_fall_box` → start rider (existing logic) + board (board yaw basis, board_size feet offset: board center was at feet − half thickness in lean frame; at enter use feet world + oriented offset).
- `_stop_fall_box` / `_refresh_fall_box_planes` operate on both.
- Keep a compatibility alias: if anything still looks up `FallBox`, also set `RiderFall` as the tracked node — **do not** leave a `FallBox` name; update camera/debug defaults to `../RiderFall`.

Board fall start sketch:

```gdscript
	var board_yaw := pose.board_yaw + pose.depth_turn_yaw
	var board_basis := Basis.from_euler(Vector3(0.0, board_yaw, tilt + lean * deg_to_rad(25.0)))
	_board_fall.configure_planes(support, impact)
	_board_fall.global_transform = _board_fall.transform_for_planes(
		feet, board_basis, support_point, support_normal, impact_point, impact_normal
	)
	_board_fall.linear_velocity = vel * 0.85
	_board_fall.angular_velocity = board_basis * Vector3(0.0, lean * 3.0, -lean * 2.0)
	_board_fall.freeze = false
	_board_fall.visible = true
	_board_fall.apply_impulse(board_basis * Vector3(-lean * 0.6, 0.25, 0.0), Vector3.ZERO)
```

Pass `pose` into fall start from `_physics_process` (already has interpolated pose).

- [ ] **Step 4: Update camera + debug paths**

```gdscript
@export var fall_box_path: NodePath = NodePath("../RiderFall")
```

in both `camera_rig_3d.gd` and `player_debug_3d.gd`. If `main.tscn` overrides the path, update the scene property to `../RiderFall`.

- [ ] **Step 5: Run full suite**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/rendering_3d/logical_pose_presenter_3d.gd \
  scripts/rendering_3d/camera_rig_3d.gd \
  scripts/rendering_3d/player_debug_3d.gd \
  scenes/main.tscn \
  tests/test_logical_pose.gd
git commit -m "$(cat <<'EOF'
Split fall into RiderFall and BoardFall presentation bodies.

EOF
)"
```

---

### Task 6: Docs + smoke

**Files:**
- Modify: `docs/gameplay.md` (presentation § ~95 and fall § ~132; Key scripts table if FallBox row exists)
- Modify: `docs/superpowers/specs/2026-08-01-skateboard-presentation-design.md` status → implemented (only after smoke)
- Test: `godot4 --headless --path . --script res://tests/test_runner.gd`

- [ ] **Step 1: Update gameplay.md**

In the presentation paragraph, replace the single-box / FallBox wording with:

- Orange rider on a red **nose** / blue **tail** placeholder board.
- Board yaw is presentation-owned and independent of facing; hang apex co-rotates the board; depth-turn yaw is temporary on both.
- During fall, **RiderFall** + **BoardFall** RigidBodies tumble (visual only); camera tracks **RiderFall** X with Y/Z lock.

Update Key scripts row for `fall_box_constraint.gd` / presenter accordingly.

- [ ] **Step 2: Run full suite**

Run: `godot4 --headless --path . --script res://tests/test_runner.gd`

Expected: PASS.

- [ ] **Step 3: Optional visual smoke**

```bash
./tools/render_iteration.sh plaza_default spawn 3d-only
```

Inspect `artifacts/render_compare/plaza_default/spawn/3d.png` for orange rider + board. Manual in-editor: hang apex board turn, fall separates both, camera follows rider.

- [ ] **Step 4: Mark spec implemented + commit**

Set spec status to `implemented on main (YYYY-MM-DD)`.

```bash
git add docs/gameplay.md docs/superpowers/specs/2026-08-01-skateboard-presentation-design.md
git commit -m "$(cat <<'EOF'
Document skateboard presentation and dual-fall bodies in gameplay.md.

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Orange rider | 3 |
| Red nose / blue tail board, proportions ~C | 3 |
| Local-ground shared lean | 3 (`surface_tilt` on root) |
| `board_yaw` on pose + lerp | 1 |
| Independent of facing flips | 2, 4 |
| Spawn/restore snap | 2, 4 |
| Apex co-rotation (delta, not snap) | 2, 4 |
| Depth-turn ephemeral | 2 (explicit), 3 (display), 4 |
| Dual fall + camera on rider | 5 |
| gameplay.md note | 6 |
| Headless tests 1–5 | 1, 2, 3, 5 |

## Out of scope (do not implement)

- Trick / free-air board spins beyond hang apex
- GLTF board asset
- `SimState.board_yaw`
- Camera midpoint / board tracking
