# Mobile touch controls — design

In-level virtual controls for phone/tablet OS builds: thumbstick, Ollie, Transfer, and Pause. Overlay feeds Godot’s InputMap so `player.gd` / PlayerSim stay unchanged.

## Goals

- Playable on mobile without a keyboard or physical controller.
- One input path for all platforms (keyboard, pad, touch → same actions).
- Clean boundaries suitable for shipping many targets (iOS, Android, desktop, web).

## Non-goals (v1)

- Touch redesign of main menu / pause menu (Buttons already work with taps).
- On-screen Fall button.
- Web/desktop touchscreen detection (`DisplayServer.is_touchscreen_available`).
- Re-showing the overlay after joypad hide (no “show touch controls” toggle).
- Custom art / skins for the pad.

## Detection

- Show when `PlatformCaps.should_show_touch_controls()`:
  - native `OS.has_feature("mobile")` (Android/iOS export tags), **or**
  - HTML5 phone/tablet: `OS.has_feature("web")` plus UA / iPadOS-touch / `(pointer: coarse)` + `maxTouchPoints` via `JavaScriptBridge`.
- Centralize in `PlatformCaps` so call sites do not scatter feature checks.
- Desktop web browsers do not show the overlay.

## Architecture

Approach: **overlay feeds the InputMap**.

| Piece | Role |
|-------|------|
| `scripts/platform_caps.gd` | Static helpers; `is_mobile_os()` |
| `scenes/touch_controls.tscn` + `scripts/touch_controls.gd` | CanvasLayer HUD: UI + synthesize actions |
| `scenes/main.tscn` | Instances overlay next to `PauseMenu` |
| `player.gd` | Unchanged — still `Input.get_axis` / `is_action_*` |

### Input synthesis

- Stick → analog strengths on `move_left` / `move_right` / `move_up` / `move_down` (compatible with `Input.get_axis`).
- Ollie / Transfer → press/hold/release on existing `ollie` / `transfer` actions (charge + hold-transfer keep working).
- Prefer `Input.action_press` / `action_release` (with strength) or equivalent `Input.parse_input_event` so strengths are visible to `get_axis` / `is_action_pressed`.
- Never write into PlayerSim or bypass the action map.

### Pause

- Top-left Pause control calls `PauseMenu.open_pause()` / `toggle_pause()` (same path as Esc via `main.gd`).
- Do not rely on synthesizing `menu_back` unless the direct API is unavailable.

### Menus

- Start menu and pause menu: no overlay; existing `Button` nodes accept touch.
- Missing piece today is opening pause without Esc — covered by the in-level Pause hit target.

## Layout

In-level only (`main` scene while playing):

| Control | Placement |
|---------|-----------|
| Pause | Top-left, ~48–56 logical px hit target |
| Thumbstick | Bottom-left (base + draggable knobs) |
| Transfer | Bottom-right, above Ollie |
| Ollie | Bottom-right, primary lower button |

Visual: semi-transparent, low-ink; short labels (“Pause”, “Ollie”, “Transfer”). Match existing warm UI tones lightly. No custom textures required in v1.

Insets: offset controls by `DisplayServer.get_display_safe_area()` so notches/home indicators do not cover hits.

While pause is open: hide the gameplay overlay (or set `mouse_filter` ignore and clear actions) so touches do not leak into gameplay. Pause menu Buttons remain tappable.

## Joypad hide

- While the overlay is visible, the first `InputEventJoypadButton` or `InputEventJoypadMotion` past a small deadzone hides the overlay for the rest of that in-level session.
- On hide: force-release all synthesized actions (stick + buttons).
- Reset visibility policy when the main/play scene loads again (mobile OS + no hide flag yet). No in-session “show touch again” UI in v1.

## Lifecycle / stuck-input safety

Force-release stick and button actions when:

- Overlay hides (joypad or pause)
- Node exits tree / scene changes
- Window focus lost (`NOTIFICATION_WM_WINDOW_FOCUS_OUT`), if applicable on target

## Testing

- Headless: stick vector → axis strengths (deadzone, clamp); clear-on-hide; joypad motion triggers hide + clear.
- `PlatformCaps.is_mobile_os()` can be tested via a thin injectable predicate in tests, or by documenting that CI (desktop) leaves the overlay hidden — prefer a test seam so logic is covered without a phone.
- Manual: Android/iOS device smoke (stick skate, Ollie charge, Transfer hold, Pause open/resume).

## Docs

- Short section in `docs/gameplay.md`: mobile overlay, feature gate, InputMap feeding, joypad hide.
- Controls catalog: optional “Mobile” row in a follow-up; not required to ship v1.

## File touch list (expected)

- `scripts/platform_caps.gd` (new)
- `scripts/touch_controls.gd` (new)
- `scenes/touch_controls.tscn` (new)
- `scenes/main.tscn` (instance)
- `scripts/main.gd` (wire pause reference if needed)
- `tests/test_touch_controls.gd` (or similar)
- `docs/gameplay.md`
)
