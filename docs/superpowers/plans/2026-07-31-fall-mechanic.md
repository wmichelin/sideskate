# Fall Mechanic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Invokable fall bout — side lean, planar velocity decay, input lockout, in-place recovery; Y key + `begin_fall()`; debug countdown HUD.

**Architecture:** `SimState` fall flag + timers; `PlayerSim.begin_fall()` / tick gate; collision solvers still run with zero wish; presentation fall roll; debug bar mirrors ollie charge but counts down.

**Tech Stack:** Godot 4 GDScript, headless `godot4` / `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-31-fall-mechanic-design.md`
- No third motion mode — bout flag only
- Collision / air contact / mounts stay active while falling
- Defaults: anim `0.15s`, stop `0.35s`, duration `1.0s`
- Exclude WIP maps (`plaza_default.ssk`, `offset_demo.ssk`) from commits

## File map

| File | Role |
|------|------|
| `scripts/sim/sim_state.gd` | Fall bout fields + clear helpers |
| `scripts/sim/player_sim.gd` | `begin_fall`, tick lockout/stop/recovery |
| `scripts/player.gd` | Y invoke, exports, lean override, HUD fracs |
| `scripts/logical_pose.gd` | Optional: no change if tilt set on PseudoDepthBody |
| `project.godot` | `fall` → Y |
| `scripts/debug_tools.gd` | `show_fall_cooldown` |
| `scripts/debug_sliders.gd` | Duration sliders + checkbox |
| `scripts/rendering_3d/player_debug_3d.gd` | Countdown bar |
| `tests/sim/test_sim_runtime.gd` | Headless regressions |
| `docs/gameplay.md` | Brief fall note |

---

### Task 1: Sim fall bout + tests

**Files:**
- Modify: `scripts/sim/sim_state.gd`
- Modify: `scripts/sim/player_sim.gd`
- Modify: `tests/sim/test_sim_runtime.gd`

**Interfaces:**
- Produces:
  - `SimState.falling: bool`
  - `SimState.fall_elapsed: float`
  - `SimState.fall_lean_sign: float` (+1 = facing `r`, −1 = `l`)
  - `SimState.fall_start_vx / fall_start_vy: float`
  - `SimState.clear_fall() -> void`
  - `PlayerSim.fall_anim_duration / fall_stop_duration / fall_duration: float`
  - `PlayerSim.begin_fall() -> void`
  - `PlayerSim.fall_cooldown_frac() -> float` (remaining 1→0 over `fall_duration`, 0 while waiting for land)
  - `PlayerSim.fall_anim_frac() -> float` (0→1 over anim duration)

- [ ] **Step 1: Add failing tests to `run()`**

```gdscript
and _fall_clears_hang_ignores_wish()
and _fall_stops_planar_keeps_gravity()
and _fall_air_waits_for_land_then_recovers()
and _fall_midair_still_collides_pipe()
```

Implement the four funcs (halfpipe fixture). Key asserts:

1. Hang then `begin_fall` → not hanging; stick-out for 20 ticks → along does not climb toward coping from wish (wish ignored).
2. Airborne with `velocity = (200, 0, 100)`; `begin_fall`; after `ceil(fall_stop_duration/dt)` ticks with zero wish → `|vx|` and `|vy|` ~0; `position.z` changed vs enter (gravity).
3. Airborne `begin_fall` with short `fall_duration`; after duration still airborne → still `falling`; mount/land floor → `falling` false, vel zero, then stick moves.
4. Airborne toward pipe body with outward vx while falling → must not tunnel past coping below peak (reuse pattern from `_ollie_into_pipe_with_stick_stays_outside` / contact assert).

- [ ] **Step 2: Run tests — expect FAIL**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

- [ ] **Step 3: Implement `SimState` fields**

```gdscript
var falling: bool = false
var fall_elapsed: float = 0.0
var fall_lean_sign: float = 1.0
var fall_start_vx: float = 0.0
var fall_start_vy: float = 0.0

func is_falling() -> bool:
	return falling

func clear_fall() -> void:
	falling = false
	fall_elapsed = 0.0
	fall_lean_sign = 1.0
	fall_start_vx = 0.0
	fall_start_vy = 0.0
```

Also clear fall in `respawn` / death paths that reset state.

- [ ] **Step 4: Implement `PlayerSim.begin_fall` + tick integration**

```gdscript
var fall_anim_duration: float = 0.15
var fall_stop_duration: float = 0.35
var fall_duration: float = 1.0

func begin_fall() -> void:
	if state == null or not state.alive or state.falling:
		return
	state.clear_hang()
	state.maneuver = null
	ollie_charge = 0.0
	ollie_charge_peak_height = 0.0
	ollie_pressed = false
	ollie_just_released = false
	action_just = false
	state.falling = true
	state.fall_elapsed = 0.0
	state.fall_lean_sign = 1.0 if state.facing == "r" else -1.0
	if state.is_airborne():
		state.fall_start_vx = state.velocity.x
		state.fall_start_vy = state.velocity.y
	else:
		# World planar from grounded tangent (floor: tangent≈world; slopes: use velocity if set, else approx)
		state.fall_start_vx = state.velocity.x if state.velocity.length_squared() > 0.01 \
			else state.tangent_velocity.x  # refined in impl via surface outward if needed
		state.fall_start_vy = state.tangent_velocity.y
		# Prefer deriving world vx from grounded pose helpers already used elsewhere if available
```

In `tick`, before solvers:

```gdscript
var wish := last_wish
var do_action := action_just
var ollie_down := ollie_pressed
var ollie_rel := ollie_just_released
if state.falling:
	wish = Vector2.ZERO
	do_action = false
	ollie_down = false
	ollie_rel = false
	ollie_just_released = false
# pass wish into ground/air; skip _try_ollie_jump / _try_actions when falling
```

After solvers, `_tick_fall(delta)`:

- Advance `fall_elapsed`
- Planar stop: `u = clampf(fall_elapsed / max(fall_stop_duration, 1e-6), 0, 1)`; target vx/vy = lerp(start, 0, u); if airborne set `velocity.x/y`; if grounded set `tangent_velocity` to match stop (along/depth → 0 over stop — use world capture projected, or simply lerp `tangent_velocity` from enter-captured tangent toward 0). **Simplest correct approach:** on `begin_fall` also capture `fall_start_along` / `fall_start_depth` from `tangent_velocity` when grounded; while falling grounded, set `tangent_velocity = lerp(start, ZERO, u)` after step (overwrites wish/gravity along for stop window, then hold ZERO). Airborne: lerp `velocity.x/y` only.
- Recovery: if `fall_elapsed >= fall_duration` and grounded → zero all vel, `clear_fall()`, replenish ollie if grounded.
- Lava kill: ensure `_apply_lava_kill` clears fall when `alive = false`.

Expose:

```gdscript
func fall_cooldown_frac() -> float:
	if state == null or not state.falling:
		return 0.0
	if fall_duration <= 0.0:
		return 0.0
	return clampf(1.0 - state.fall_elapsed / fall_duration, 0.0, 1.0)

func fall_anim_frac() -> float:
	if state == null or not state.falling:
		return 0.0
	if fall_anim_duration <= 0.0:
		return 1.0
	return clampf(state.fall_elapsed / fall_anim_duration, 0.0, 1.0)
```

- [ ] **Step 5: Run tests — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add scripts/sim/sim_state.gd scripts/sim/player_sim.gd tests/sim/test_sim_runtime.gd
git commit -m "Add sim fall bout with lockout, planar stop, and recovery."
```

---

### Task 2: Input Y + presentation lean + Player exports

**Files:**
- Modify: `project.godot` (add `fall` action, physical_keycode Y = 89)
- Modify: `scripts/player.gd`

**Interfaces:**
- Consumes: `PlayerSim.begin_fall`, `fall_anim_frac`, `fall_lean_sign` via state
- Produces: Player exports + `fall_cooldown_frac()` for HUD

- [ ] **Step 1: Add InputMap `fall` → Y** in `project.godot` next to `ollie`.

- [ ] **Step 2: Player exports + sync + invoke**

```gdscript
@export_range(0.0, 5.0, 0.01) var fall_anim_duration: float = 0.15
@export_range(0.0, 5.0, 0.01) var fall_stop_duration: float = 0.35
@export_range(0.0, 10.0, 0.01) var fall_duration: float = 1.0
```

In `_physics_process`, after tuning sync:

```gdscript
if Input.is_action_just_pressed("fall"):
	_sim.begin_fall()
```

Sync the three durations in `_sync_tuning_to_sim`.

- [ ] **Step 3: Fall lean owns `surface_tilt` while falling**

In `_sync_from_sim`, after computing normal `tilt`, if `st.falling`:

```gdscript
var af := _sim.fall_anim_frac()
var target := st.fall_lean_sign * (PI * 0.5)
tilt = lerpf(0.0, target, af)  # or lerpf(_carry_tilt, target, af) — prefer from 0/upright carry toward side
_carry_tilt = tilt
```

On recovery (`not falling`), normal tilt path resumes.

- [ ] **Step 4: Expose HUD helper**

```gdscript
func fall_cooldown_frac() -> float:
	return _sim.fall_cooldown_frac() if _sim else 0.0
```

- [ ] **Step 5: Manual sanity (optional) + commit**

```bash
git add project.godot scripts/player.gd
git commit -m "Wire Y to begin_fall and presentation side lean."
```

---

### Task 3: Debug sliders + countdown HUD

**Files:**
- Modify: `scripts/debug_tools.gd`
- Modify: `scripts/debug_sliders.gd`
- Modify: `scripts/rendering_3d/player_debug_3d.gd`

- [ ] **Step 1: `DebugTools.show_fall_cooldown`** (+ setter/signal), default `true`.

- [ ] **Step 2: TUNING** — three duration sliders + checkbox “fall cooldown bar” (clone ollie charge bar row pattern; fill color distinct e.g. `Color(0.55, 0.75, 0.95)`).

- [ ] **Step 3: `player_debug_3d.gd`** — second bar (or reuse root with mode) at same `charge_bar_offset` (or slight Y offset if both visible — prefer fall bar replaces/hides when falling, ollie when charging). Update fill from `fall_cooldown_frac()` remaining %; show while falling && debug bool.

- [ ] **Step 4: Commit**

```bash
git add scripts/debug_tools.gd scripts/debug_sliders.gd scripts/rendering_3d/player_debug_3d.gd
git commit -m "Add fall cooldown debug bar and duration tuners."
```

---

### Task 4: Docs + full suite

**Files:**
- Modify: `docs/gameplay.md` (short fall section + key scripts if table exists)

- [ ] **Step 1: Doc blurb** — Y/`begin_fall`, three timers, collision stays on, recovery rules.

- [ ] **Step 2: Full test suite PASS**

- [ ] **Step 3: Commit docs**

---

## Spec coverage checklist

| Spec item | Task |
|-----------|------|
| `begin_fall` API / no-op if falling | 1 |
| Clear hang/maneuver/ollie | 1 |
| Zero wish; solvers still run (collision) | 1 |
| Planar stop + gravity Z | 1 |
| Recover after duration + grounded | 1 |
| Air wait-for-land | 1 |
| Lean toward facing | 2 |
| Y key | 2 |
| Debug durations | 3 |
| Countdown HUD | 3 |
| Collision test | 1 |
| gameplay.md | 4 |
