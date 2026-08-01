# Deck Ride-off Contact Landing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make an outward-deck ride-off leave in free air, Mount only on a real descending crossing of the abutting slope’s ride surface, and Reject + fall every earlier lip, wall, underside, or lateral face hit.

**Architecture:** `GroundSolver` continues to launch a deck leave into ordinary air. `AirSolver` receives the complete swept segment (`from` → contact point) and owns a narrow deck-launch contact gate: it recognizes the launch deck’s abutting pipe/ramp via `CrashClassifier.deck_abuts_slope`, permits Mount only for a descending surface crossing, and marks every other contact with that slope as a crash Reject. Accepted Acid and Spine plans are untouched because `AirSolver.step()` routes a maneuver through `_step_maneuver` before free-air contact processing.

**Tech Stack:** Godot 4 GDScript, analytical `PlayerSim`, headless test runner, `tools/render_iteration.sh`.

## Global Constraints

- Gameplay simulation advances only on fixed physics ticks.
- PlayerSim remains the sole gameplay authority; Godot collision and presentation do not decide landings.
- Deck leave itself never Mounts or falls.
- Ordinary deck-launch Mount requires a descending segment crossing of the sampled pipe/ramp ride height from above.
- An earlier lip, wall, underside, or lateral contact with the deck’s abutting slope Rejects and starts a fall.
- Accepted Acid and Spine `ManeuverPlan.Kind.TRANSFER` plans bypass ordinary free-air deck-launch contact policy.
- Keep same-slope reentry, foreign-pipe lip, fly-out, and hang behavior unchanged outside deck-launch contacts.
- Do not stage or commit the unrelated `levels/offset_demo.ssk`.

## File map

| File | Responsibility |
|---|---|
| Modify `tests/sim/test_sim_runtime.gd` | Exact deck-launch regressions, real surface crossing, face crash, transfer preservation |
| Modify `scripts/sim/crash_classifier.gd` | Retain deck↔slope ownership lookup; remove the velocity-based deck “with-slope” exemption |
| Modify `scripts/sim/air_solver.gd` | Carry sweep endpoints into disposition; implement contact-gated deck-launch Mount/Reject |
| Modify `docs/movement_contract.md` | Replace with-slope auto-Mount contract |
| Modify `docs/gameplay.md` | Describe free ride-off, contact-gated ordinary land, and face crash |
| Modify `docs/superpowers/specs/2026-07-31-crash-classifier-design.md` | Remove obsolete with-slope foreign-lip wording |

---

### Task 1: Establish exact failing deck-launch regressions

**Files:**
- Modify: `tests/sim/test_sim_runtime.gd:81,6659-6707`
- Test: `godot4 --headless --path . --script res://tests/test_runner.gd`

**Interfaces:**
- Consumes: `PlayerSim.setup_from_path`, `PipeSurface.project`, `SimState.air_launch_surface_id`
- Produces: behavior tests for the free-air edge, the real ride-surface landing, and the crash face

- [ ] **Step 1: Replace the biased coast test with a shared fixture lookup**

Add this helper immediately before the deck-launch tests:

```gdscript
func _deck_left_pipe_setup() -> Dictionary:
	var sim := PlayerSim.new()
	if not sim.setup_from_path("res://tests/levels/sim/deck_to_left_pipe.ssk"):
		return {}
	var deck: SupportPatch = null
	var pipe: PipeSurface = null
	for id in sim.model.patches.keys():
		var patch: SupportPatch = sim.model.patches[id]
		if int(patch.kind) == SimKinds.SurfaceKind.DECK:
			deck = patch
	for id in sim.model.pipes.keys():
		var candidate: PipeSurface = sim.model.pipes[id]
		if int(candidate.side) == SimKinds.PipeSide.LEFT:
			pipe = candidate
	if deck == null or pipe == null:
		return {}
	return {"sim": sim, "deck": deck, "pipe": pipe}
```

- [ ] **Step 2: Write the failing no-proximity-Mount test**

Replace `_deck_skate_off_to_left_pipe_no_wipeout()` with this test and wire it into `run()` under the new name:

```gdscript
func _deck_ride_off_rejects_pre_surface_pipe_contact() -> bool:
	var setup := _deck_left_pipe_setup()
	if setup.is_empty():
		push_error("deck contact: setup")
		return false
	var sim: PlayerSim = setup.sim
	var deck: SupportPatch = setup.deck
	var pipe: PipeSurface = setup.pipe
	var z := (deck.z_min + deck.z_max) * 0.5
	var cx := pipe.coping_x_at(z)
	sim.state.mode = SimState.Mode.GROUNDED
	sim.state.surface_id = deck.id
	sim.state.position = Vector3(cx - 5.0, z, deck.height)
	sim.state.tangent_velocity = Vector2(180.0, 0.0)
	sim.state.facing = "r"
	sim.state.clear_hang()

	var saw_air := false
	for tick in range(12):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		saw_air = saw_air or sim.state.is_airborne()
		if sim.state.is_grounded() and sim.state.surface_id == pipe.id:
			push_error("deck contact: proximity-mounted pipe at tick %s" % tick)
			return false
		if sim.state.falling:
			return saw_air
	push_error("deck contact: pre-surface pipe face never rejected")
	return false
```

- [ ] **Step 3: Write the failing real ride-surface-crossing test**

Add this test beside the pre-surface test:

```gdscript
func _deck_ride_off_mounts_only_on_descending_surface_crossing() -> bool:
	var setup := _deck_left_pipe_setup()
	if setup.is_empty():
		push_error("deck crossing: setup")
		return false
	var sim: PlayerSim = setup.sim
	var deck: SupportPatch = setup.deck
	var pipe: PipeSurface = setup.pipe
	var z := (deck.z_min + deck.z_max) * 0.5
	var theta := 0.45 * PI * 0.5
	var x := pipe.x_at_theta(z, theta)
	var ride_h := pipe.height_at_theta(z, theta)
	sim.state.mode = SimState.Mode.AIRBORNE
	sim.state.surface_id = ""
	sim.state.air_launch_surface_id = deck.id
	sim.state.position = Vector3(x, z, ride_h + 18.0)
	sim.state.velocity = Vector3(0.0, 0.0, -240.0)
	sim.state.note_air_height(sim.state.position.z)

	for tick in range(20):
		sim.set_input(Vector2.ZERO, false, false)
		sim.tick()
		if sim.state.falling:
			push_error("deck crossing: fell instead of mounting at tick %s" % tick)
			return false
		if sim.state.is_grounded():
			if sim.state.surface_id != pipe.id:
				push_error("deck crossing: landed %s, want %s" % [sim.state.surface_id, pipe.id])
				return false
			return true
	push_error("deck crossing: never mounted sampled ride surface")
	return false
```

- [ ] **Step 4: Retain the shared Acid/Spine transfer regressions**

Keep `_transfer_button_lerps_x_holds_facing()` and
`_transfer_shared_x_spine_reanchors_hang()` in `run()` without creating an
Acid-specific contact path. `ManeuverPlanner.try_transfer()` constructs the
same `ManeuverPlan.Kind.TRANSFER` for both player-facing Acid and Spine
transfers, and `AirSolver.step()` dispatches every accepted maneuver to
`_step_maneuver()` before ordinary free-air contact processing. The full suite
must keep both existing transfer tests green.

- [ ] **Step 5: Run the suite and confirm RED**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `FAIL test_sim_runtime.gd` at `deck contact: proximity-mounted pipe`, because the current velocity-based `is_with_slope` branch returns `MOUNT` before a valid ride-surface crossing.

- [ ] **Step 6: Commit the failing regressions**

```bash
git add tests/sim/test_sim_runtime.gd
git commit -m "Add contact-gated deck ride-off regressions"
```

---

### Task 2: Replace velocity-based deck auto-Mount with a sweep crossing gate

**Files:**
- Modify: `scripts/sim/crash_classifier.gd:184-254`
- Modify: `scripts/sim/air_solver.gd:120-205,254-263,287-423,457-533,979-991`
- Test: `tests/sim/test_sim_runtime.gd`

**Interfaces:**
- Consumes: `CrashClassifier.deck_abuts_slope(deck_id: String, slope_id: String, z: float) -> bool`
- Produces: `AirSolver._deck_launch_slope_disposition(state, contact, from, at) -> int`, returning `-1` when the contact does not belong to the launch deck’s abutting slope, otherwise a `SimKinds.ContactDisposition`

- [ ] **Step 1: Remove the incorrect deck “with-slope” exemption**

In `scripts/sim/crash_classifier.gd`, delete `is_with_slope()` and `_planar_travels_with_slope()`. Keep `deck_abuts_slope()` and `contact_slope_id()` as geometry/ownership helpers. Remove this condition from `is_foreign_pipe_lip_crash()`:

```gdscript
if is_with_slope(state, contact, ctx):
	return false
```

Do not alter `is_same_slope_reentry()`: a launch from the slope itself remains a separate, valid reentry rule.

- [ ] **Step 2: Pass actual sweep endpoints into disposition**

Change the disposition signature and all callers:

```gdscript
func _disposition_for_contact(
	state: SimState, contact: Dictionary, from: Vector3, at: Vector3
) -> int:
```

In `_step_free`, use the segment endpoints already available:

```gdscript
var at := from.lerp(to, t)
state.position = from.lerp(to, maxf(t - 0.01, 0.0))
var disp := _disposition_for_contact(state, contact, from, at)
```

Change `_stream_has_later_mount` to accept `from: Vector3, to: Vector3`, calculate each `later_at := from.lerp(to, float(later.t))`, and call `_disposition_for_contact(state, later, from, later_at)`. Change `_resolve_air_contact` to call `_disposition_for_contact(state, contact, from, from)`, so an embedded deck-launch slope body is never mistaken for a surface crossing.

- [ ] **Step 3: Add the narrow deck-launch slope disposition**

Add this helper before `_disposition_for_contact`:

```gdscript
func _deck_launch_slope_disposition(
	state: SimState, contact: Dictionary, from: Vector3, at: Vector3
) -> int:
	if crash == null or state.has_maneuver() or state.is_hanging():
		return -1
	var launch := state.air_launch_surface_id
	if launch.is_empty() or not model.patches.has(launch):
		return -1
	var deck: SupportPatch = model.patches[launch]
	if int(deck.kind) != SimKinds.SurfaceKind.DECK:
		return -1
	var surf = _contact_slope_surf(contact)
	if surf == null or not crash.deck_abuts_slope(launch, surf.id, at.y):
		return -1
	if state.velocity.z >= -SimTolerances.CONTACT_EPS:
		return SimKinds.ContactDisposition.REJECT
	var from_proj: Dictionary = surf.project(from.x, from.y, from.z)
	var at_proj: Dictionary = surf.project(at.x, at.y, at.z)
	if not bool(from_proj.get("ok", false)) or not bool(at_proj.get("ok", false)):
		return SimKinds.ContactDisposition.REJECT
	var from_above := float(from_proj.separation) > SimTolerances.CONTACT_EPS
	var crossed := float(at_proj.separation) <= SimTolerances.CONTACT_EPS
	if from_above and crossed:
		return SimKinds.ContactDisposition.MOUNT
	return SimKinds.ContactDisposition.REJECT
```

At the top of `_disposition_for_contact`, after the hang handling and before generic bounds/lip/body cases, apply the gate:

```gdscript
var deck_launch_disp := _deck_launch_slope_disposition(state, contact, from, at)
if deck_launch_disp >= 0:
	return deck_launch_disp
```

Delete `_deck_ride_off_blocks_slope_contact()` and `_deck_ride_off_still_outward()`. Their old Corridor policy cannot distinguish an actual touchdown from a body overlap, and it allowed bowl-side auto-Mounts.

- [ ] **Step 4: Make a rejected deck-launch slope face start a fall**

In `_reject_air_contact`, before the generic `_contact_requests_fall()` call, add:

```gdscript
var hit_point: Vector3 = contact.get("point", state.position)
if _deck_launch_slope_disposition(state, contact, from, hit_point) \
		== SimKinds.ContactDisposition.REJECT:
	state.request_fall = true
```

This is deliberately in `AirSolver`: the crash condition depends on the sweep
segment and does not redefine global foreign-pipe or same-slope policy.

- [ ] **Step 5: Run the deck regressions and confirm GREEN**

Run:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `PASS test_sim_runtime.gd`; the pre-surface contact falls after first entering free air, the sampled descending crossing Mounts, and both transfer tests still accept `TRANSFER` plans.

- [ ] **Step 6: Commit the sim policy**

```bash
git add scripts/sim/air_solver.gd scripts/sim/crash_classifier.gd tests/sim/test_sim_runtime.gd
git commit -m "Gate deck ride-off mounts on real surface contact"
```

---

### Task 3: Align the player-facing contract

**Files:**
- Modify: `docs/movement_contract.md:78,121-128`
- Modify: `docs/gameplay.md:75,131`
- Modify: `docs/superpowers/specs/2026-07-31-crash-classifier-design.md:38`
- Test: documentation scan plus full headless suite

**Interfaces:**
- Consumes: approved `docs/superpowers/specs/2026-08-01-deck-ride-off-contact-landing-design.md`
- Produces: one consistent contract for deck ride-off, ordinary landing, and Acid/Spine exception paths

- [ ] **Step 1: Replace movement-contract auto-Mount wording**

Replace the deck paragraph with:

```text
Outward `#` ride-off is ordinary free air with `air_launch` = that deck; no
coping seam or nearby slope body may auto-Mount. The deck’s abutting pipe/ramp
Mounts only when a descending free-air sweep crosses its sampled ride surface
from above. A lip, wall, underside, or lateral face hit before that crossing
Rejects and starts a fall. Accepted Acid and Spine transfer plans use their own
target-seat rules.
```

Update the high-level fall exclusions so deck launch is not globally excluded:
only a real descending surface crossing is playable; a deck-launch slope face
hit is a fall trigger.

- [ ] **Step 2: Update gameplay and classifier documentation**

In `docs/gameplay.md`, replace “while traveling with the slope Mounts” with the
sweep-crossing rule and state the early-face crash rule. In
`2026-07-31-crash-classifier-design.md`, replace the obsolete “not with-slope”
cross-link with a link to
`2026-08-01-deck-ride-off-contact-landing-design.md`, explicitly noting that
deck-launch contact timing belongs to `AirSolver`.

- [ ] **Step 3: Run documentation and behavior verification**

Run:

```bash
rg -n "with-slope.*Mount|free air then with-slope" docs
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd
./tools/render_iteration.sh plaza_default spawn 3d-only
./tools/render_iteration.sh spine_demo spawn 3d-only
./tools/render_iteration.sh layered_demo spawn 3d-only
./tools/render_iteration.sh variable_height_ramps spawn 3d-only
./tools/render_iteration.sh plaza_default_deep spawn pair
```

Expected: the `rg` command reports no executable design/contract claim that a
deck launch auto-Mounts by “with-slope”; the test suite reports `0 failed`; all
five render reports contain `"errors": []`.

- [ ] **Step 4: Commit docs and push**

```bash
git add docs/movement_contract.md docs/gameplay.md \
  docs/superpowers/specs/2026-07-31-crash-classifier-design.md \
  docs/superpowers/plans/2026-08-01-deck-ride-off-contact-landing.md
git commit -m "Document contact-gated deck ride-off landings"
git push origin HEAD
```

## Spec coverage check

| Requirement | Task |
|---|---|
| Free deck ride-off, no edge auto-Mount | 1, 2 |
| Mount only on descending sampled-surface crossing | 1, 2 |
| Earlier slope face Reject + fall | 1, 2 |
| Acid and Spine bypass ordinary contact policy | 1, 2 |
| One coherent public contract | 3 |
| Existing sim and render behavior remains healthy | 2, 3 |
