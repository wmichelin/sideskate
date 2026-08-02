# Mobile Touch Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an in-level mobile-only touch overlay (stick, Ollie, Transfer, Pause) that feeds the existing InputMap without changing PlayerSim.

**Architecture:** `PlatformCaps` gates visibility on `OS.has_feature("mobile")`. `TouchControls` CanvasLayer synthesizes `move_*` / `ollie` / `transfer` via `Input.action_press`/`action_release`, and calls `PauseMenu.open_pause()`. First joypad activity hides the overlay for the session.

**Tech Stack:** Godot 4.7 GDScript, existing InputMap actions, headless `tests/test_*.gd` runner.

## Global Constraints

- Show only when `OS.has_feature("mobile")` (via `PlatformCaps.is_mobile_os()`).
- Overlay feeds InputMap only — do not write PlayerSim or bypass actions.
- No Fall button; no menu touch redesign; no re-show toggle after joypad hide.
- `player.gd` stays on `Input.get_axis` / `is_action_*`.
- Simulation stays on physics ticks; overlay UI may use `_process` / GUI input only for presentation + action synthesis.

## File structure

| File | Responsibility |
|------|----------------|
| `scripts/platform_caps.gd` | `class_name PlatformCaps`; mobile OS gate + test override |
| `scripts/touch_controls.gd` | Overlay logic: stick math, action synth, joypad hide, pause |
| `scenes/touch_controls.tscn` | CanvasLayer layout (Pause / stick / Transfer / Ollie) |
| `scenes/main.tscn` | Instance TouchControls |
| `scripts/main.gd` | Optional wire if NodePath needed |
| `tests/test_touch_controls.gd` | Stick axes, override visibility, joypad hide + clear |
| `docs/gameplay.md` | Short mobile controls section |

---

### Task 1: PlatformCaps + stick axis math (TDD)

**Files:**
- Create: `scripts/platform_caps.gd`
- Create: `scripts/touch_controls.gd` (static math + class shell first)
- Test: `tests/test_touch_controls.gd`

**Interfaces:**
- Produces: `PlatformCaps.is_mobile_os() -> bool`, `PlatformCaps.mobile_os_override: Variant`, `PlatformCaps.clear_overrides() -> void`
- Produces: `TouchControls.axes_from_stick(v: Vector2, deadzone: float = 0.15) -> Dictionary` with keys `left`,`right`,`up`,`down` (floats 0..1)

- [ ] **Step 1: Write failing tests**

```gdscript
extends RefCounted

const PlatformCaps = preload("res://scripts/platform_caps.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")

func run() -> bool:
	PlatformCaps.clear_overrides()
	PlatformCaps.mobile_os_override = true
	if not PlatformCaps.is_mobile_os():
		push_error("override true failed")
		return false
	PlatformCaps.mobile_os_override = false
	if PlatformCaps.is_mobile_os():
		push_error("override false failed")
		return false
	PlatformCaps.clear_overrides()

	var zero := TouchControls.axes_from_stick(Vector2.ZERO)
	if float(zero.left) != 0.0 or float(zero.right) != 0.0:
		push_error("zero stick should clear X")
		return false
	var dead := TouchControls.axes_from_stick(Vector2(0.1, 0.0), 0.15)
	if float(dead.right) != 0.0:
		push_error("inside deadzone should be zero")
		return false
	var right := TouchControls.axes_from_stick(Vector2(1, 0), 0.15)
	if float(right.right) < 0.99 or float(right.left) != 0.0:
		push_error("full right failed: %s" % right)
		return false
	var up := TouchControls.axes_from_stick(Vector2(0, -1), 0.15)
	if float(up.up) < 0.99:
		push_error("full up failed (note: UI -Y is up)")
		return false
	return true
```

- [ ] **Step 2: Run tests — expect FAIL (missing scripts)**

```bash
godot4 --headless --path . --script res://tests/test_runner.gd
```

- [ ] **Step 3: Implement PlatformCaps + axes_from_stick**

`platform_caps.gd`:

```gdscript
class_name PlatformCaps
extends RefCounted
## Platform feature gates for multi-target shipping.

static var mobile_os_override: Variant = null

static func is_mobile_os() -> bool:
	if mobile_os_override is bool:
		return mobile_os_override as bool
	return OS.has_feature("mobile")

static func clear_overrides() -> void:
	mobile_os_override = null
```

In `touch_controls.gd`, add static:

```gdscript
static func axes_from_stick(v: Vector2, deadzone: float = 0.15) -> Dictionary:
	var out := {"left": 0.0, "right": 0.0, "up": 0.0, "down": 0.0}
	var len := v.length()
	if len <= deadzone:
		return out
	var n := v / len
	var mag := clampf((len - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	var scaled := n * mag
	if scaled.x < 0.0:
		out.left = -scaled.x
	elif scaled.x > 0.0:
		out.right = scaled.x
	# Screen/UI Y: negative = up → move_up
	if scaled.y < 0.0:
		out.up = -scaled.y
	elif scaled.y > 0.0:
		out.down = scaled.y
	return out
```

- [ ] **Step 4: Run tests — PASS for Task 1 cases**

- [ ] **Step 5: Commit**

```bash
git add scripts/platform_caps.gd scripts/touch_controls.gd tests/test_touch_controls.gd
git commit -m "Add PlatformCaps and touch stick axis math."
```

---

### Task 2: TouchControls scene + InputMap synthesis + joypad hide

**Files:**
- Modify: `scripts/touch_controls.gd`
- Create: `scenes/touch_controls.tscn`
- Modify: `scenes/main.tscn` (instance)
- Modify: `scripts/main.gd` if needed for pause path
- Modify: `tests/test_touch_controls.gd` (hide + clear + main instance)

**Interfaces:**
- Consumes: `PlatformCaps.is_mobile_os()`, `PauseMenu.open_pause()`, `PauseMenu.is_open()`
- Produces: overlay visible only when mobile (or override) and not joypad-hidden; synthesizes actions listed in spec

- [ ] **Step 1: Extend tests** — instantiate `touch_controls.tscn`, force `mobile_os_override = true`, call `force_show_for_test()`, apply stick via `apply_stick_for_test(Vector2(1,0))`, assert `Input.get_axis("move_left","move_right") > 0.5`, call `notify_joypad_activity_for_test()`, assert hidden and axis ~0, `clear_overrides` + release in teardown. Also assert `main.tscn` has `TouchControls` node.

- [ ] **Step 2: Run — FAIL until scene/API exist**

- [ ] **Step 3: Build scene + script**

Layout (`touch_controls.tscn`):
- `CanvasLayer` layer `70`, script `touch_controls.gd`
- Root `Control` full rect, mouse_filter STOP only on interactive children
- Pause `Button` top-left (~56×56)
- Stick zone bottom-left (~140×140) with base + knob `ColorRect`/`Panel`
- Transfer + Ollie buttons bottom-right (stacked)

Script responsibilities:
- `_ready`: resolve `%PauseMenu` sibling or `@export NodePath pause_menu_path`; `_refresh_visibility()` from `PlatformCaps.is_mobile_os()`; connect pause button → `_pause_menu.open_pause()`; apply safe-area margins
- `_input`: if visible and joypad button/motion past `0.25`, `_hide_for_joypad()`
- Stick: `gui_input` / drag → `axes_from_stick` → `_set_move_axes(dict)`; release → zeros
- Buttons: `button_down`/`button_up` → `Input.action_press`/`action_release` for `ollie`/`transfer`
- `_process` or pause signal: if pause `is_open()`, hide gameplay root + `_clear_all_actions()`; when closed and still eligible, show again (joypad hide still wins)
- `_clear_all_actions()` / `_notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)` / `NOTIFICATION_PREDELETE` / `_exit_tree`: release all
- Test seams: `force_show_for_test()`, `apply_stick_for_test(v)`, `notify_joypad_activity_for_test()`, `is_overlay_active() -> bool`

Wire in `main.tscn` after PauseMenu:

```
[node name="TouchControls" parent="." instance=ExtResource("touch")]
```

- [ ] **Step 4: Run full suite — PASS**

```bash
godot4 --headless --path . --script res://tests/test_runner.gd
```

- [ ] **Step 5: Commit**

```bash
git add scripts/touch_controls.gd scenes/touch_controls.tscn scenes/main.tscn scripts/main.gd tests/test_touch_controls.gd
git commit -m "Add mobile touch control overlay feeding InputMap."
```

---

### Task 3: Docs

**Files:**
- Modify: `docs/gameplay.md` (after Key scripts or new short section)

- [ ] **Step 1: Add section**

```markdown
## Mobile touch controls

On phone/tablet OS builds (`OS.has_feature("mobile")` via `PlatformCaps`), `TouchControls` overlays an in-level virtual stick, Ollie, Transfer, and Pause. Controls synthesize the same InputMap actions keyboard uses; `player.gd` is unchanged. First joypad activity hides the overlay for that play session. Main/pause menus rely on ordinary Buttons (no virtual pad).
```

Also add a Key scripts row for `touch_controls.gd` / `platform_caps.gd`.

- [ ] **Step 2: Commit**

```bash
git add docs/gameplay.md
git commit -m "Document mobile touch controls in gameplay.md."
```

---

## Spec coverage checklist

| Spec item | Task |
|-----------|------|
| `PlatformCaps.is_mobile_os()` | 1 |
| InputMap stick / ollie / transfer | 2 |
| Pause → PauseMenu API | 2 |
| Layout positions + safe area | 2 |
| Hide while pause open + clear | 2 |
| Joypad hide + clear | 2 |
| Lifecycle release | 2 |
| Headless tests + test seam | 1–2 |
| gameplay.md | 3 |
| No Fall / no menu redesign | (non-goals, omitted) |
