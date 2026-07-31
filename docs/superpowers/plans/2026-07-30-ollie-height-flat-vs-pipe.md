# Ollie Height Flat vs Pipe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split peak ollie height into flat vs pipe/ramp/wall tunables with two debug sliders.

**Architecture:** Replace `ollie_height` with `ollie_height_flat` and `ollie_height_pipe` on `Player`/`PlayerSim`. At release, pick height from grounded `surface_id` kind. TUNING panel gets two sliders; charge/lip stay shared.

**Tech Stack:** Godot 4 GDScript, headless `tests/test_runner.gd`.

## Global Constraints

- Defaults both `100.0`; slider range `0.0`–`200.0` step `0.1`.
- Pipe class = pipe, ramp, wall. Flat class = floor, deck. Unknown → flat.
- Charge ms and lip frac unchanged.
- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`.

---

### Task 1: Failing regression + sim pick

**Files:**
- Modify: `scripts/sim/player_sim.gd`
- Modify: `tests/sim/test_sim_runtime.gd`
- Modify: `docs/gameplay.md`, `docs/movement_contract.md` (with Task 2 if preferred; do in Task 3)

**Interfaces:**
- Produces: `PlayerSim.ollie_height_flat`, `PlayerSim.ollie_height_pipe`, `PlayerSim._ollie_peak_height_for_surface() -> float`

- [ ] **Step 1: Add failing regression and wire it into `run()`**

In `tests/sim/test_sim_runtime.gd` `run()`, after existing ollie tests (near other `_ollie_*` calls), add:

```gdscript
and _ollie_height_picks_flat_vs_pipe()
```

Add:

```gdscript
## Unequal flat/pipe heights: floor release uses flat, pipe release uses pipe.
func _ollie_height_picks_flat_vs_pipe() -> bool:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_halfpipe.ssk"):
		push_error("ollie pick: setup")
		return false
	sim.ollie_accel = 0.0
	sim.ollie_charge_ms = 0.0
	sim.ollie_height_flat = 40.0
	sim.ollie_height_pipe = 100.0
	sim.ollie_lip_frac = 0.0
	# Floor pop.
	sim.state.mode = SimState.Mode.GROUNDED
	# Use spawn floor ownership from setup.
	if not sim.model.patches.has(sim.state.surface_id):
		push_error("ollie pick: expected floor at spawn got %s" % sim.state.surface_id)
		return false
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ollie pick: floor should air")
		return false
	var want_flat := sqrt(2.0 * absf(SimTolerances.GRAVITY) * 40.0)
	if absf(sim.state.velocity.z - want_flat) > 1.0:
		push_error(
			"ollie pick: floor vz=%.1f want ~%.1f" % [sim.state.velocity.z, want_flat]
		)
		return false
	# Remount a pipe below lip band and pop with full pipe height.
	var pipe: PipeSurface = null
	for pid in sim.model.all_pipe_ids():
		pipe = sim.model.pipes[pid]
		break
	if pipe == null:
		push_error("ollie pick: no pipe")
		return false
	var z := (pipe.z_min + pipe.z_max) * 0.5
	var th := 0.25 * PI * 0.5
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = pipe.id
	sim.state.u = 0.25
	sim.state.v = 0.5
	sim.state.position = Vector3(pipe.x_at_theta(z, th), z, pipe.height_at_theta(z, th))
	sim.state.velocity = Vector3.ZERO
	sim.state.tangent_velocity = Vector2.ZERO
	sim.state.clear_hang()
	sim.state.maneuver = null
	sim.ollie_available = true
	sim.ollie_charge = 1.0
	sim.set_input(Vector2.ZERO, false, false, false, true)
	sim.tick()
	if not sim.state.is_airborne():
		push_error("ollie pick: pipe should air")
		return false
	var want_pipe := sqrt(2.0 * absf(SimTolerances.GRAVITY) * 100.0)
	if absf(sim.state.velocity.z - want_pipe) > 5.0:
		push_error(
			"ollie pick: pipe vz=%.1f want ~%.1f" % [sim.state.velocity.z, want_pipe]
		)
		return false
	return true
```

Also replace every `sim.ollie_height = X` in this file with both:
`sim.ollie_height_flat = X` and `sim.ollie_height_pipe = X` (preserve prior test intent).

- [ ] **Step 2: Run suite — expect fail on missing properties / pick**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: FAIL referencing `ollie_height` / pick.

- [ ] **Step 3: Implement pick on PlayerSim**

In `scripts/sim/player_sim.gd`, replace `var ollie_height` with:

```gdscript
## Peak ollie height at 100% charge on floor/deck (level units).
var ollie_height_flat: float = 100.0
## Peak ollie height at 100% charge on pipe/ramp/wall (level units).
var ollie_height_pipe: float = 100.0
```

Change `_try_ollie_jump`:

```gdscript
var height := frac * _ollie_peak_height_for_surface()
```

Add:

```gdscript
func _ollie_peak_height_for_surface() -> float:
	if state == null or not state.is_grounded():
		return ollie_height_flat
	var sid := state.surface_id
	if model != null:
		if model.pipes.has(sid) or model.ramps.has(sid) or model.walls.has(sid):
			return ollie_height_pipe
		if model.patches.has(sid):
			var patch: SupportPatch = model.patches[sid]
			if int(patch.kind) == SimKinds.SurfaceKind.DECK \
					or int(patch.kind) == SimKinds.SurfaceKind.FLOOR:
				return ollie_height_flat
	return ollie_height_flat
```

- [ ] **Step 4: Re-run tests — expect PASS for sim suite**

Same Godot command. Expected: `test_sim_runtime.gd` PASS (other failures only if Player still breaks nothing yet).

- [ ] **Step 5: Commit**

```bash
git add scripts/sim/player_sim.gd tests/sim/test_sim_runtime.gd
git commit -m "Pick ollie peak height from flat vs pipe surface class."
```

---

### Task 2: Player shell + debug sliders

**Files:**
- Modify: `scripts/player.gd`
- Modify: `scripts/debug_sliders.gd`

**Interfaces:**
- Consumes: `PlayerSim.ollie_height_flat`, `ollie_height_pipe`
- Produces: Player exports + TUNING rows `OllieHeightFlatRow`, `OllieHeightPipeRow`

- [ ] **Step 1: Update Player exports and sync**

Replace `@export ... ollie_height` with:

```gdscript
@export_range(0.0, 200.0, 0.1) var ollie_height_flat: float = 100.0
@export_range(0.0, 200.0, 0.1) var ollie_height_pipe: float = 100.0
```

In `_sync_tuning_to_sim`:

```gdscript
_sim.ollie_height_flat = ollie_height_flat
_sim.ollie_height_pipe = ollie_height_pipe
```

- [ ] **Step 2: Split TUNING sliders**

In `_setup_ollie_jump_sliders`, replace the single `OllieHeightRow` block with two rows after charge:

```gdscript
var flat_row := _make_slider_row(
	"OllieHeightFlatRow", "ollie height flat", charge_row["row"].get_index() + 1
)
_bind_float_slider(
	flat_row["slider"], 0.0, 200.0, 0.1, _player, "ollie_height_flat", 100.0,
	_on_ollie_height_flat_changed, _refresh_ollie_height_flat_label
)
flat_row["slider"].focus_mode = Control.FOCUS_NONE
var pipe_row := _make_slider_row(
	"OllieHeightPipeRow", "ollie height pipe", flat_row["row"].get_index() + 1
)
_bind_float_slider(
	pipe_row["slider"], 0.0, 200.0, 0.1, _player, "ollie_height_pipe", 100.0,
	_on_ollie_height_pipe_changed, _refresh_ollie_height_pipe_label
)
pipe_row["slider"].focus_mode = Control.FOCUS_NONE
var lip_row := _make_slider_row(
	"OllieLipFracRow", "ollie lip", pipe_row["row"].get_index() + 1
)
```

Replace `_on_ollie_height_changed` / `_refresh_ollie_height_label` with flat/pipe pair (labels `OllieHeightFlatRow/Value`, `OllieHeightPipeRow/Value`, format `"%.1f u"`).

- [ ] **Step 3: Run headless suite**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `=== 15 passed, 0 failed ===`

- [ ] **Step 4: Commit**

```bash
git add scripts/player.gd scripts/debug_sliders.gd
git commit -m "Expose flat and pipe ollie height on Player and TUNING sliders."
```

---

### Task 3: Docs

**Files:**
- Modify: `docs/gameplay.md`
- Modify: `docs/movement_contract.md`

- [ ] **Step 1: Update ollie copy**

`gameplay.md`: charge% × `ollie_height_flat` (floor/deck) or `ollie_height_pipe` (pipe/ramp/wall).

`movement_contract.md` ollie row: same wording; keep lip-band / lean sentences.

- [ ] **Step 2: Commit**

```bash
git add docs/gameplay.md docs/movement_contract.md
git commit -m "Document flat vs pipe ollie peak heights."
```

---

## Spec coverage

| Spec item | Task |
|-----------|------|
| Two heights + defaults 100 | 1 |
| Surface class table | 1 |
| Player sync | 2 |
| Debug sliders | 2 |
| Docs | 3 |
| Tests migrate + regression | 1 |
| Non-goals (charge/lip untouched) | — left alone |
