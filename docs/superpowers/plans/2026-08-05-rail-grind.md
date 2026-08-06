# Rail Grind Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add along-X `-` rails: airborne + R mounts a grind; coast + balance; ollie-release or end-eject leave; no-R contact Rejects; always-on balance HUD while grinding.

**Architecture:** First-class `RailSurface` in `ParkModel` (IDL → compiler). New `SimState.Mode.GRINDING` with a small grind solver in `PlayerSim` (or `grind_solver.gd`). Air contacts treat rails as SOLID Reject unless mount gate fires. Presentation draws a thin bar; thickness is runtime-tunable.

**Tech Stack:** Godot 4.7 GDScript analytical sim (`scripts/sim/`), `.ssk` LevelLoader, mesh builders, headless `tests/sim/test_sim_runtime.gd` + level_loader tests.

**Approved design:** [`docs/superpowers/specs/2026-08-05-rail-grind-design.md`](../specs/2026-08-05-rail-grind-design.md).

## Global Constraints

- Simulation on physics ticks only (`_physics_process` / `PlayerSim.tick`); presentation never mounts or balances
- Aerial vocabulary unchanged (air-out / fly-out / transfer / spine / acid); grind is a separate mode
- Motion vectors stay `INPUT` / `MOMENTUM` / `ACTUAL`
- Fall uses existing `begin_fall()`; end eject and ollie out do **not** fall
- Grind mount requires **airborne** + **R held** + snap radius; R not required to stay locked
- Stick on grind = signed balance only (both axes); no accel/brake
- Ollie on grind uses the **same** charge curve/bar (debug-gated bar); charge must build while grinding
- Thickness slider only; `RAIL_OFFSET` fixed constant
- Along-X rails only (v1)

## File map

| File | Responsibility |
|------|----------------|
| `docs/superpowers/specs/2026-08-05-rail-grind-design.md` | Locked design |
| `docs/superpowers/plans/2026-08-05-rail-grind.md` | This plan |
| `scripts/level_loader.gd` | Accept `-`; emit rail descriptors |
| `scripts/level_spec.gd` | `rails: Array` |
| `scripts/sim/model/rail_surface.gd` | **Create** — analytical rail segment |
| `scripts/sim/model/sim_kinds.gd` | `SurfaceKind.RAIL` |
| `scripts/sim/model/park_model.gd` | `rails` dict + id cache |
| `scripts/sim/idl_compiler.gd` | Compile rails into model |
| `scripts/sim/surface_query.gd` | Rail proximity + air contact volume |
| `scripts/sim/sim_state.gd` | `Mode.GRINDING`, grind fields, helpers |
| `scripts/sim/sim_tolerances.gd` | Offset, thickness, snap, balance fail |
| `scripts/sim/grind_solver.gd` | **Create** — coast / balance / exits |
| `scripts/sim/air_solver.gd` | Mount attempt; Reject rail without grind |
| `scripts/sim/player_sim.gd` | Mode branch, grind input, ollie-on-grind |
| `scripts/sim/crash_classifier.gd` | Rail Reject → fall when appropriate |
| `scripts/player.gd` | `grind` action; thickness export; balance frac |
| `project.godot` | InputMap `grind` → R |
| `scripts/controls_catalog.gd` | Controls row |
| `scripts/mesh/rail_mesh_builder.gd` | **Create** — thin bar mesh |
| `scripts/mesh/level_geometry.gd` | Include rail parts |
| `scripts/rendering_3d/player_debug_3d.gd` | Always-on balance meter while grinding |
| `scripts/debug_sliders.gd` | Rail thickness slider |
| `docs/level_format.md`, `docs/gameplay.md` | Glyph + controls |
| `tests/levels/sim/` | Small rail fixture `.ssk` |
| `tests/sim/test_sim_runtime.gd` | Grind matrices |
| `tests/test_level_loader.gd` | `-` parse / invalid still fails |

## Defaults (initial)

```gdscript
# SimTolerances
const RAIL_OFFSET: float = 28.0          # top above layer.height (tune so board sits on bar)
static var RAIL_THICKNESS: float = 4.0   # few pixels; debug slider
const RAIL_SNAP_RADIUS: float = 28.0     # logical units around rail top/centerline
const GRIND_BALANCE_FAIL: float = 1.0    # |lean| >= this → begin_fall
```

Lean: `lean = clampf(wish.x + wish.y, -1.0, 1.0)` (both axes). Fail when `absf(lean) >= GRIND_BALANCE_FAIL`.

---

### Task 1: Plan on disk + spec pointer

**Files:**
- Modify: `docs/superpowers/specs/2026-08-05-rail-grind-design.md` (status → plan path)
- Create: `docs/superpowers/plans/2026-08-05-rail-grind.md` (this file)

**Interfaces:**
- Consumes: approved design
- Produces: checked plan for agents

- [ ] **Step 1:** Ensure this plan file is saved at the path above
- [ ] **Step 2:** Update spec status line to point at this plan
- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-08-05-rail-grind.md docs/superpowers/specs/2026-08-05-rail-grind-design.md
git commit -m "$(cat <<'EOF'
Add rail grind implementation plan.

EOF
)"
```

---

### Task 2: IDL — accept `-` and emit rail descriptors

**Files:**
- Modify: `scripts/level_loader.gd` (valid glyph list + match arm + rail run builder)
- Modify: `scripts/level_spec.gd` (`var rails: Array = []`)
- Test: `tests/test_level_loader.gd`
- Fixture: `tests/levels/sim/sim_rail_x.ssk` (create)

**Interfaces:**
- Consumes: layer grid glyphs
- Produces: `LevelSpec.rails` entries:

```gdscript
# Each rail dict:
{
  "x_min": float, "x_max": float,
  "z": float,           # cell mid-Z
  "base_height": float, # layer.height
  "layer": int,
  "cells": Array,       # optional Vector2i list for mesh
}
# Top height at compile = base_height + SimTolerances.RAIL_OFFSET (or bake offset in compiler).
```

- [ ] **Step 1: Write failing loader test**

Add a tiny map and assert rails parse:

```gdscript
func _rail_glyph_emits_along_x_run() -> bool:
	var text := """ssk 2
name sim_rail_x
---
layer 0
height 0
========
=----===
========
"""
	var spec := LevelLoader.parse_text(text, "sim_rail_x")
	if spec == null or spec.rails.is_empty():
		push_error("rail glyph: expected rails")
		return false
	var r: Dictionary = spec.rails[0]
	if float(r.x_max) - float(r.x_min) < LevelLoader.cell_size_x * 3.5:
		push_error("rail glyph: expected ~4 cell X run")
		return false
	return true
```

Wire into `run()`; expect fail until Step 3.

- [ ] **Step 2: Run loader tests — expect fail**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: fail on missing `rails` / invalid `-`.

- [ ] **Step 3: Implement parse**

In `level_loader.gd`:
1. Add `"-"` to the valid-glyph check (~line 204).
2. In the match (~359): `"-" : rail_cells.append(Vector2i(c, r))` and mark playable story mask (same bit as floor = 1). Do **not** append to `floor_cells`.
3. After floor/deck/pipe build for the layer, group contiguous `-` on the **same row** into runs; for each run append a rail dict with world `x_min`/`x_max`/`z` from cell bounds (mid-Z), `base_height`, `layer`, `cells`.
4. `LevelSpec.rails.clear()` in geometry reset; append across layers.

- [ ] **Step 4: Re-run — expect pass for parse test**
- [ ] **Step 5: Commit**

```bash
git add scripts/level_loader.gd scripts/level_spec.gd tests/test_level_loader.gd tests/levels/sim/sim_rail_x.ssk
git commit -m "$(cat <<'EOF'
Parse along-X '-' rail glyphs into LevelSpec.rails.

EOF
)"
```

---

### Task 3: `RailSurface` + compiler + ParkModel

**Files:**
- Create: `scripts/sim/model/rail_surface.gd`
- Modify: `scripts/sim/model/sim_kinds.gd`, `park_model.gd`, `idl_compiler.gd`
- Test: `tests/sim/test_sim_compiler.gd` (or runtime setup)

**Interfaces:**
- Consumes: `LevelSpec.rails`
- Produces:

```gdscript
class_name RailSurface
extends RefCounted
var id: String = ""
var x_min: float = 0.0
var x_max: float = 0.0
var z: float = 0.0
var top_height: float = 0.0   # base + RAIL_OFFSET
var layer: int = 0

func contains_x(x: float, eps: float = 0.0) -> bool:
	return x >= x_min - eps and x <= x_max + eps

func distance_xz_height(pos: Vector3) -> float:
	# horizontal distance to segment + vertical distance to top
	...
```

`ParkModel.rails: Dictionary` + `rebuild_id_caches` / `all_rail_ids()`.
`IdlCompiler._compile_rails(spec, model)`.
`SimKinds.SurfaceKind.RAIL = 6` (+ name in `surface_kind_name`).

- [ ] **Step 1: Failing compiler/setup test** — `PlayerSim.setup_from_path("res://tests/levels/sim/sim_rail_x.ssk")` → `model.rails` non-empty; top ≈ `0 + RAIL_OFFSET`
- [ ] **Step 2: Run — expect fail**
- [ ] **Step 3: Implement RailSurface + compile + park cache**
- [ ] **Step 4: Run — pass**
- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Compile LevelSpec rails into ParkModel RailSurface.

EOF
)"
```

---

### Task 4: Failing grind runtime tests (TDD)

**Files:**
- Modify: `tests/sim/test_sim_runtime.gd`
- Fixture: `tests/levels/sim/sim_rail_x.ssk`

**Interfaces:**
- Consumes: future grind API (`set_input(..., grind_down)`, `state.is_grinding()`, `state.grind_balance`)
- Produces: red tests that drive Task 5–6

- [ ] **Step 1: Add helpers + five tests** wired into `run()`:

```gdscript
func _rail_setup() -> PlayerSim:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/sim_rail_x.ssk"):
		return null
	return sim

func _rail_mount_air_hold_r() -> bool:
	# Place airborne above rail mid, vx > 0, grind held → Mode.GRINDING
	...

func _rail_no_r_rejects() -> bool:
	# Same approach without grind → not grinding; request_fall or Reject path / not stuck through
	...

func _rail_grounded_r_no_mount() -> bool:
	# On floor under/near rail with R → stays GROUNDED
	...

func _rail_balance_fail_falls() -> bool:
	# While grinding, wish at fail threshold → falling
	...

func _rail_end_eject_no_fall() -> bool:
	# Grind near x_max with +along speed → AIRBORNE, not falling
	...

func _rail_ollie_release_pops() -> bool:
	# Grind, charge ollie, release → AIRBORNE, velocity.z (height) > 0, not falling
	...
```

Use `set_input(wish, false, false, ollie_down, ollie_released, false, false, grind_down)` — extend arity in Task 5; until then tests fail on missing arg / missing mode.

- [ ] **Step 2: Run suite — expect these fail**
- [ ] **Step 3: Commit failing tests**

```bash
git commit -m "$(cat <<'EOF'
Add failing headless tests for rail grind mount and exits.

EOF
)"
```

---

### Task 5: Sim state, input, grind solver

**Files:**
- Modify: `scripts/sim/sim_state.gd`, `sim_tolerances.gd`, `player_sim.gd`
- Create: `scripts/sim/grind_solver.gd`
- Modify: `scripts/player.gd`, `project.godot`, `scripts/controls_catalog.gd`

**Interfaces:**
- Consumes: `RailSurface`, wish, grind/ollie flags
- Produces:

```gdscript
# SimState.Mode
GRINDING = 2

# SimState fields
var grind_rail_id: String = ""
var grind_along: float = 0.0      # signed X speed while grinding
var grind_balance: float = 0.0    # signed lean [-1,1]

func is_grinding() -> bool:
	return mode == Mode.GRINDING

func clear_grind() -> void:
	grind_rail_id = ""
	grind_along = 0.0
	grind_balance = 0.0
```

```gdscript
# PlayerSim.set_input — add grind_down: bool = false
var grind_held: bool = false

# grind_solver.gd
class_name GrindSolver
func try_mount(state, model, query, grind_held: bool) -> bool
func step(state, model, wish: Vector2, delta: float) -> void
# step: integrate x += grind_along * delta; pin z/height; update balance;
# if fail → state.request_fall = true; clear grind / mode air will be set by begin_fall
# if x out of range → exit to AIRBORNE with velocity = (grind_along, 0, 0) approx
```

**Ollie on grind:** change `_update_ollie_charge` to allow charge when `state.is_grinding()` (same ms curve). `_try_ollie_jump`: if grinding on release, exit grind → airborne with pop using `ollie_height` flat (or dedicated peak); carry `grind_along` into `velocity.x`.

**Tick branch:** if `state.is_grinding()`: run `grind.step` (skip ground/air solvers except fall handling). Clear grind in `begin_fall()`.

- [ ] **Step 1: Tolerances + Mode + fields + `set_input` grind + InputMap R + player wiring**
- [ ] **Step 2: Implement `GrindSolver.try_mount` / `step` (balance + end eject); wire mount from airborne tick when `grind_held`**
- [ ] **Step 3: Ollie charge + release while grinding**
- [ ] **Step 4: Run Task 4 tests — mount / balance / end / ollie should pass; reject may still need Task 6**
- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Add GRINDING mode, R mount, coast/balance, ollie and end exits.

EOF
)"
```

---

### Task 6: Air Reject without R

**Files:**
- Modify: `scripts/sim/surface_query.gd`, `air_solver.gd`, `crash_classifier.gd` as needed

**Interfaces:**
- Consumes: `ParkModel.rails`, runtime `SimTolerances.RAIL_THICKNESS`
- Produces: air contact dicts `{ "kind": "rail", "surface_id": id, "role": SOLID, ... }` that disposition → **Reject** (and crash/fall per existing solid policy)

Mount must run **before** or instead of Reject when `grind_held` and in snap radius (same tick): prefer `try_mount` at start of air step so locked grind skips further rail Reject.

- [ ] **Step 1: Query rail AABB/capsule along segment (thickness vertical, small Z half-width ~ cell/4 or CAPSULE)**
- [ ] **Step 2: Disposition: rail → Reject; crash classifier treats like wall/solid for fall**
- [ ] **Step 3: `_rail_no_r_rejects` passes; mount still works**
- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
Reject airborne rail hits when grind is not held.

EOF
)"
```

---

### Task 7: Mesh, thickness slider, balance HUD

**Files:**
- Create: `scripts/mesh/rail_mesh_builder.gd`
- Modify: `scripts/mesh/level_geometry.gd`, `player.gd`, `debug_sliders.gd`, `rendering_3d/player_debug_3d.gd`

**Interfaces:**
- Consumes: `LevelSpec.rails` or `ParkModel.rails` + `RAIL_THICKNESS`
- Produces: bar mesh; `player.grind_balance_frac() -> float` in `[-1,1]`; HUD always visible iff grinding

Balance HUD (not debug-gated):
- Reuse charge-bar positioning pattern in `player_debug_3d.gd`
- Center tick; fill left if lean < 0, right if lean > 0
- Show when `_player` reports grinding (add `is_grinding()` on player mirroring sim)

Thickness:
```gdscript
# player.gd
@export_range(1.0, 24.0, 0.5) var rail_thickness: float = 4.0
# _sync_tuning_to_sim → SimTolerances.RAIL_THICKNESS
```

Mesh rebuild on slider: follow existing cell-size / step-height pattern if park rebuilds; if mesh is bake-once, document that thickness affects **collision immediately** and mesh on next level load — prefer live meta if easy (rebuild rail parts only).

- [ ] **Step 1: RailMeshBuilder box along X (top at top_height, height = thickness)**
- [ ] **Step 2: Thickness slider + sync**
- [ ] **Step 3: Always-on balance meter while grinding**
- [ ] **Step 4: Manual smoke — load fixture / plaza with a `-` run; grind; see bar + meter**
- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
Draw rails, tune thickness, show grind balance HUD.

EOF
)"
```

---

### Task 8: Docs + full suite

**Files:**
- Modify: `docs/level_format.md` (glyph table), `docs/gameplay.md` (controls + grind paragraph), `docs/superpowers/specs/2026-08-05-rail-grind-design.md` if defaults drifted
- Optional: debug level or plaza snippet with a short `-` rail for playtest

- [ ] **Step 1: Document glyph `-`, R grind, balance, ollie/end exits, thickness slider**
- [ ] **Step 2: Full headless suite green**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `=== N passed, 0 failed ===`

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
Document rail grind glyph and controls; verify full suite.

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Glyph `-` along X | 2 |
| Fixed offset, thickness slider | 3, 7 |
| Airborne + R + snap mount | 5 |
| Grounded no mount | 4, 5 |
| No R → Reject | 6 |
| Coast + balance both sticks | 5 |
| Balance fail → begin_fall | 5 |
| Always-on balance HUD | 7 |
| Shared ollie charge/bar; release pop | 5, 7 |
| End eject no fall | 5 |
| Headless tests | 4–6, 8 |
| Docs | 8 |

## Out of scope (do not implement)

Z-rails, offset slider, stick speed on rail, R-to-stay-locked, grind tricks, touch grind bind, score.
