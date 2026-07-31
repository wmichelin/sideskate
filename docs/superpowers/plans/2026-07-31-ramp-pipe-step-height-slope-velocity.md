# Ramp/Pipe Step Height + Slope Velocity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Scale pipe/ramp rise by glyph run × `step_height`, and stop air land / free-air slope ollie from killing ride X.

**Architecture:** Parse optional `step_height` into `LevelSpec`; compile loft samples with separate footprint `radius` (X = `run_cells × cell_w`) and height `rise` (`run_cells × step_height`). Unify air→slope mounts to `vx * outward_sign()`. Drop peak-ward X zeroing on free-air slope ollie.

**Tech Stack:** Godot 4 GDScript, analytical sim in `scripts/sim/`, headless `tests/test_runner.gd`. Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-31-ramp-pipe-step-height-slope-velocity-design.md`
- Shared header `step_height`; default when omitted = `cell_w`
- Footprint X stays `run_cells × cell_w`; height rise = `run_cells × step_height`
- When `step_height ≠ cell_w`, pipes are elliptical (rx ≠ ry); ramps are non-45°
- Lip-band hang ollie policy unchanged (X-lock; along does not stack onto vertical)
- Prefer `LevelLoader.parse_text` in tests; never `load_path` for bad maps
- Simulation on physics / `FIXED_DT` only

## File map

| File | Responsibility |
|------|----------------|
| `scripts/level_spec.gd` | `step_height` field |
| `scripts/level_loader.gd` | Parse header; emit rise on pipe/ramp dicts; deck neighbor rise |
| `scripts/sim/idl_compiler.gd` | Loft samples include `rise`; `_slope_run_on_row` |
| `scripts/sim/model/pipe_surface.gd` | X from `radius`, height from `rise` |
| `scripts/sim/model/ramp_surface.gd` | X from `radius`, height from `rise` |
| `scripts/sim/air_solver.gd` | Land along = `vx * outward_sign()` |
| `scripts/sim/ground_solver.gd` | Free-air slope ollie keeps peak-ward X |
| `docs/level_format.md`, `docs/movement_contract.md`, `docs/gameplay.md` | Document rules |
| `tests/sim/test_sim_compiler.gd` | Step-height compile regressions |
| `tests/sim/test_sim_runtime.gd` | Land + ollie X retention |

---

### Task 1: `step_height` header + compile rise

**Files:**
- Modify: `scripts/level_spec.gd`
- Modify: `scripts/level_loader.gd`
- Modify: `scripts/sim/idl_compiler.gd`
- Modify: `scripts/sim/model/pipe_surface.gd`
- Modify: `scripts/sim/model/ramp_surface.gd`
- Modify: `tests/sim/test_sim_compiler.gd`
- Test fixtures: inline `parse_text` / small `.ssk` under `tests/levels/sim/` if needed

**Interfaces:**
- Produces: `LevelSpec.step_height: float` (`-1.0` = unset → use `cell_w`)
- Produces: loft sample keys `{z, lip_x, radius, rise, base_height}` where `radius` = X span, `rise` = height span
- Produces: `PipeSurface` / `RampSurface` height uses `rise`; X uses `radius`
- Consumes: glyph run width in cells

- [ ] **Step 1: Write failing compiler tests**

In `tests/sim/test_sim_compiler.gd`, add to `run()` and implement:

```gdscript
func _step_height_scales_ramp_and_pipe() -> bool:
	var text := """ssk 2
name step_h
step_height 40
layer 0
height 0
>>>=======<<<
>>>=======<<<
>>>=======<<<
>>>===@===<<<
>>>=======<<<
>>>=======<<<
>>>=======<<<
"""
	# Also need a pipe-only map or combine — prefer two small maps.
	var ramp_m: ParkModel = IdlCompiler.compile(LevelLoader.parse_text(text))
	# Resolve right-ramp sample rise: 3 cells × 40 = 120; radius X = 3 × cell_w
	# (cell_w comes from RampLevel defaults via parse — assert rise explicitly)
	...
```

Prefer a minimal dedicated fixture `tests/levels/sim/sim_step_height.ssk`:

```
ssk 2
name sim_step_height
step_height 40
layer 0
height 0
>>>====)))
>>>====)))
>>>====)))
>>>==@=)))
>>>====)))
>>>====)))
>>>====)))
```

Assert for a `>>>` ramp sample: `rise ≈ 120`, `radius ≈ 3 * cell_w`.  
Assert for a `)))` pipe sample: same.  
Second test: omit `step_height` → `rise ≈ radius` (both `run_cells * cell_w`).

Wire both into `run()`.

- [ ] **Step 2: Run tests — expect FAIL**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: FAIL on new step_height assertions (rise still equals footprint radius).

- [ ] **Step 3: Implement `LevelSpec` + loader parse**

`scripts/level_spec.gd`:

```gdscript
## Per-glyph-cell height rise for pipes/ramps. -1 = use cell_w at compile.
var step_height: float = -1.0
```

`scripts/level_loader.gd`:
- Allow key `step_height` in the header allow-list next to `deck_height`.
- Parse: `spec.step_height = float(val)`.
- Helper used by pipe/ramp builders:

```gdscript
static func _effective_step_height(spec: LevelSpec) -> float:
	if spec.step_height > 0.0:
		return spec.step_height
	return spec.cell_w
```

In `_pipe_from_band` / ramp equivalents: keep footprint `x0/x1` from cells × `cw`. Set:

```gdscript
var width_cells := ... # from band
var footprint := float(width_cells) * cw  # or x1-x0
var rise: float
if radius_override > 0.0:
	rise = radius_override  # legacy pipe_radius forces height
else:
	rise = float(width_cells) * _effective_step_height(spec)
```

Emit both `"radius": footprint` (X) and `"rise": rise` on the pipe/ramp dict. Deck neighbor max uses **`rise`** (not footprint).

Pass `spec` into helpers that currently only get `radius_override` as needed.

- [ ] **Step 4: Compiler loft + surface math**

`idl_compiler.gd` when building samples from LevelSpec dicts and `_slope_run_on_row`:

```gdscript
var width_cells := c - start
var radius := float(width_cells) * spec.cell_w  # X
var step_h := spec.step_height if spec.step_height > 0.0 else spec.cell_w
var rise := float(width_cells) * step_h
# if pipe_radius_override path still applies at refine, prefer documented behavior:
# refine from glyphs always uses step_height for rise; override already baked in loader samples.
return {"lip_x": lip, "radius": radius, "rise": rise}
```

Initial compile from LevelSpec dicts: copy `rise` from dict (fallback `radius` if missing for old data).

`pipe_surface.gd` / `ramp_surface.gd`:
- Samples: `{z, lip_x, radius, rise, base_height}` (`rise` defaults to `radius` if absent).
- `rebuild_bounds`: X from `radius`, height max from `rise`.
- Pipe: `x_at_theta` uses `radius`; `height_at_theta` uses `rise * (1-cos(th))`.
- Ramp: `x` uses `radius * u`; `height` uses `rise * u`.
- `project` / normals: use the same rx/ry (elliptical pipe: treat as scaled quarter-circle — dx/radius and dh/rise).

- [ ] **Step 5: Run tests — expect PASS**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `=== N passed, 0 failed ===` including new compiler tests.

- [ ] **Step 6: Commit**

```bash
git add scripts/level_spec.gd scripts/level_loader.gd scripts/sim/idl_compiler.gd \
  scripts/sim/model/pipe_surface.gd scripts/sim/model/ramp_surface.gd \
  tests/sim/test_sim_compiler.gd tests/levels/sim/sim_step_height.ssk
git commit -m "$(cat <<'EOF'
Add step_height so pipe/ramp rise scales with glyph runs.

EOF
)"
```

---

### Task 2: Air land retains world X

**Files:**
- Modify: `scripts/sim/air_solver.gd` (all `-maxf(impact, 80)` / `120` slope seeds)
- Modify: `tests/sim/test_sim_runtime.gd`

**Interfaces:**
- Consumes: `state.velocity.x`, pipe/ramp `outward_sign()`
- Produces: `tangent_velocity.x = velocity.x * outward_sign()` on air→slope mount

- [ ] **Step 1: Write failing land tests**

```gdscript
func _air_land_ramp_keeps_uphill_along() -> bool:
	# Free-air above mid >, vx > 0, land → tangent_velocity.x > 0
	...

func _air_land_pipe_maps_vx_via_outward() -> bool:
	# Free-air above mid ), vx > 0 → along == vx * outward_sign()
	# Must NOT equal -max(impact, 80)
	...
```

Add both to `run()`.

- [ ] **Step 2: Run tests — expect FAIL**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: FAIL (along still forced downhill).

- [ ] **Step 3: Fix air mounts**

Replace every slope land seed of the form:

```gdscript
state.tangent_velocity = Vector2(-maxf(impact, 80.0), vz)
```

with (pipe/ramp specific):

```gdscript
var out := pipe.outward_sign()  # or ramp.outward_sign()
state.tangent_velocity = Vector2(state.velocity.x * out, state.velocity.y)
```

Apply in `_mount_pipe_owner`, `_mount_ramp_owner`, and any hang-remount / lip-seat branches that force downhill onto a pipe or ramp (grep `-maxf(impact`). Do **not** change non-slope mounts (deck already preserves `velocity.x`).

Helper optional:

```gdscript
func _slope_along_from_world_vx(surf, world_vx: float) -> float:
	return world_vx * float(surf.outward_sign())
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

- [ ] **Step 5: Commit**

```bash
git add scripts/sim/air_solver.gd tests/sim/test_sim_runtime.gd
git commit -m "$(cat <<'EOF'
Retain world X when landing on pipes and ramps.

EOF
)"
```

---

### Task 3: Free-air slope ollie keeps peak-ward X

**Files:**
- Modify: `scripts/sim/ground_solver.gd` (`launch_height_impulse`)
- Modify: `tests/sim/test_sim_runtime.gd`

**Interfaces:**
- Consumes: `proj.tangent_along`, `along`, `depth`, `height_impulse`
- Produces: `world.x = t.x * along` without peak-ward zeroing (below lip / free-air only)

- [ ] **Step 1: Write failing ollie X test**

```gdscript
func _pipe_ollie_below_lip_keeps_peakward_x() -> bool:
	# Grounded on ), u below lip band, tangent_velocity.x peak-ward (toward coping),
	# full charge ollie → airborne, velocity.x keeps peak-ward sign, abs meaningfully > 0
	...
```

Add to `run()`.

- [ ] **Step 2: Run tests — expect FAIL**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: FAIL (`velocity.x` ~ 0 from peak-ward kill).

- [ ] **Step 3: Remove peak-ward X kill**

In `ground_solver.gd` `launch_height_impulse`, pipe/ramp free-air branch, delete:

```gdscript
if absf(n.x) > 0.001 and wx * n.x < 0.0:
	wx = 0.0
```

Keep:

```gdscript
var wx := t.x * along
world = Vector3(wx, depth, height_impulse)
world = _reject_into_normal(world, n)
```

Lip hang path unchanged.

- [ ] **Step 4: Run tests — expect PASS**

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

- [ ] **Step 5: Commit**

```bash
git add scripts/sim/ground_solver.gd tests/sim/test_sim_runtime.gd
git commit -m "$(cat <<'EOF'
Carry peak-ward ride X through free-air slope ollies.

EOF
)"
```

---

### Task 4: Docs

**Files:**
- Modify: `docs/level_format.md`
- Modify: `docs/movement_contract.md`
- Modify: `docs/gameplay.md`

- [ ] **Step 1: Update docs**

`level_format.md`: document `step_height` (optional; default `cell_w`); table that `)`/`>` rise = 1H, `))`/`>>` = 2H; footprint still `cell_w`; note elliptical pipe / non-45° ramp when H ≠ cell_w.

`movement_contract.md` / `gameplay.md`: air land on slope keeps `vx→along`; free-air slope ollie below air-out band carries full along→world X; hang lip path still X-locks.

- [ ] **Step 2: Commit**

```bash
git add docs/level_format.md docs/movement_contract.md docs/gameplay.md
git commit -m "$(cat <<'EOF'
Document step_height and slope velocity retention.

EOF
)"
```

---

## Spec coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| `step_height` header + default `cell_w` | Task 1 |
| Rise = run_cells × H; footprint = run_cells × cell_w | Task 1 |
| Pipes and ramps share H | Task 1 |
| Deck neighbor rise from new rise | Task 1 |
| Air land `along = vx * outward_sign()` | Task 2 |
| No `-max(impact,80)` downhill seed | Task 2 |
| Free-air slope ollie keeps peak-ward X | Task 3 |
| Hang lip policy unchanged | Task 3 (no change) |
| Docs | Task 4 |
| Compiler + land + ollie tests | Tasks 1–3 |

No TBD/placeholder steps. Sample field `rise` vs `radius` naming is consistent across Task 1 consumers.
