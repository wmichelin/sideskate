# SideSkate — gameplay & systems

Intent brief for humans and agents. For the ASCII level IDL, see [level_format.md](level_format.md).

## Product shape

Godot 4 **pseudo-3D** skate prototype. Simulation lives in **logical** space:

- **X** — left/right across the plaza
- **Z** — near/far depth (stick “up” = farther). Screen Y uses a fixed px/Z rate (not “fit whole level in frame”), so deep levels scroll off-screen; the camera pans with the player in X and Y.
- **Height** — feet elevation above flat (pipe arc, deck, air)

Screen placement is a **projection** of `(x, z, height)`. Far X converges toward the skater over a fixed `reference_width` (`perspective_inset` default 160). Screen Y uses a fixed px/Z from `reference_depth` (deep levels scroll off-frame with the follow cam). World size is `columns × cell_x` / `rows × cell_z`. Visuals are surface-only (floors, pipe ribbons, deck tops).

## Simulation law

All gameplay simulation runs on the **fixed physics timestep** (`_physics_process` / physics `delta`) only — never on render frames. Debug/UI may read state in `_process` but must not step the world.

See also [AGENTS.md](../AGENTS.md).

## Surfaces & zones

Underfoot sampling (see `RampLevel.sample`):

1. Pipe footprint  
2. Deck  
3. Floor (flat)  
4. Out of bounds  

Player-facing zone labels include `flat`, `left_pipe`, `right_pipe`, `deck`, and `air (over …)` while airborne.

**Pipe geometry (logical):**

- **Lip** — where the quarter-pipe meets flat (`lip_x`)
- **Top coping** — `lip ± radius` at θ = π/2 (never treat the lip as coping for air locks / acid drop)

## Grounded motion

- Stick integrates into intent velocity `_velocity` (X and Z).
- **Horizontal X**: opposite stick **brakes hard** toward zero via **`brake`** (default 1250) — no reverse until `|vx|` reaches 0. Coasting uses **friction** only (default 0).
- **Depth Z**: immediate — stick maps straight to `±max_speed_z` (default 60; debug slider).
- **Acceleration** (default 3250) / **brake** / **max speed x** (default 880) / **max speed z**: tunable via debug sliders.
- **Horizontal facing** `facing_h` (`l` / `r`): follows motion while moving; stick only when nearly stopped. Spawn from level header `spawn_facing` (default `r`). Head debug shows `hd l` / `hd r`.
- **Ollie** (hold Space): mild forward accel (`ollie_accel`, default 650) toward `max_speed_x` in facing direction. Skipped while stick is braking opposite. Tunable via debug slider.
- On flat/deck: move in X/Z; leaving a **higher** support into a lower one **rides off** into free air (keep prior height, apply gravity).
- On a pipe: along-arc speed (`_ramp_along`) follows the arc (θ). Horiz remnant is `along * cosθ`; vertical is `along * sinθ`. At the top coping (θ = π/2) **all** remaining along-speed converts into `air_vel_y` (horiz → 0). **`ramp_friction`** (default 0, debug slider) drains along-speed while on the pipe.

## Air model

Feet height while airborne: `air_abs_height`. Vertical rate for gravity: `air_vel_y` (when gravity applies).

| Mode | How you get there | X | Height |
|------|-------------------|---|--------|
| **Pipe coping lock** | Exit pipe at top coping | Locked to **top** coping | Gravity; land on coping height (`radius`). At vertical **apex**, facing flips unless stick holds L/R. |
| **Free air** | Ride-off, transfer, etc. | Free (unless lerping) | Gravity; land on **sampled** underfoot height |
| **Acid-drop lock** | Acid drop action | Locked to opposite-facing **top** coping | Gravity only — action must not snap/alter height |

Pipe coping lock treats the top coping height (`radius`) as the floor. Acid-drop lock and free air **must not** use that shortcut (it would snap feet upward); they sample the real surface under `(x, z)`.

### Ride-off

When grounded motion would place you on a surface lower than prior support (beyond a small epsilon), enter free air at the **previous** support height and start gravity. Works for deck → pipe/flat and similar drops. Spawn is assumed to start on floor.

### Gravity

Applied while unlocked air, or while acid-drop X-locked. Default ≈ `-12.8` m/s², converted with `logic_per_meter` (default 100). Tunable via top-right debug slider.

## Aerial actions (same button: `transfer` / P)

One **transfer** and one **acid drop** per aerial. Both refill on any surface contact (`_clear_air`).

Routing uses measured vertical rate (`_vert_vel`) and the last non-zero vertical rate (so a rising **apex** still counts as transfer, not acid drop):

| Vertical condition | Action |
|--------------------|--------|
| Rising, or `vert ≈ 0` after a positive (up) non-zero | **Transfer** |
| Falling (or rest after down) | **Acid drop** |

### Transfer

- Probe “behind” the current pipe / last behind-sign for deck, other pipe, or flat.
- Enter free air over the target at **same** height; gravity applies.
- Leaving **locked** coping air: seed horizontal `_velocity.x` in the behind direction (`max(|intent|, transfer_release_min)`) and **skip** the slow X position lerp so motion doesn’t restart from near-zero.
- Unlocked→unlocked transfers may still short-lerp X when needed; don’t double-apply X while a lerp owns position.

### Acid drop

- Only opposite-facing pipe: velocity **right** → `left_pipe`; velocity **left** → `right_pipe`.
- Target is **top coping** only (logical X), never the lip.
- Coping must lie in front of horizontal velocity, with grace **behind** up to `acid_drop_buffer` (logical X units, default **44** — not screen pixels), and not farther ahead than `acid_drop_max_ahead` (default 120).
- Animate/lerp X onto that coping; keep `air_abs_height` / `air_vel_y`; gravity continues. Land only when falling onto sampled surface (no upward height snap).

## Level units (.ssk cells)

Each ASCII map glyph is one logical cell:

- `cw = width / W`, `ch = depth / H`
- Row 0 = far (top of file); bottom row = near
- Stored on `LevelSpec` (`grid_w`, `grid_h`, `cell_w`, `cell_h`); helpers `cell_at`, `cell_bounds`

Debug **cell highlight** (default off) draws the cell under the player in yellow (air or grounded), using underfoot surface height (floor = 0 at spawn).

## Debug overlays

Debug tools are gated by autoload `DebugTools`: available when `OS.is_debug_build()` **or** export feature `debug_tools`. Release exports strip HUD/arrows/cell highlight (group `debug_tools`) and ignore god mode.

| Piece | Role |
|-------|------|
| Head **green** arrow | Measured actual velocity (dX, dZ, d(height)/dt) |
| Head **orange** arrow | Stick **intent** `_velocity` |
| Top-left overlay | Depth/zone/surface + cell `col`/`row` |
| Top-right sliders | Gravity, acid buffer, cell-highlight toggle, **god mode** |
| **God mode** (default off; `G` or checkbox) | No gravity; **k** rise / **j** lower (`god_vert_speed`) |

## Key scripts

| Script | Role |
|--------|------|
| [`scripts/player.gd`](../scripts/player.gd) | Motion, air, transfer, acid drop, ride-off, measured/intent debug APIs |
| [`scripts/ramp_level.gd`](../scripts/ramp_level.gd) | Load `.ssk`, sample surfaces, project to screen |
| [`scripts/ramp_visual.gd`](../scripts/ramp_visual.gd) | Surface draw + cell highlight |
| [`scripts/level_loader.gd`](../scripts/level_loader.gd) / [`level_spec.gd`](../scripts/level_spec.gd) | Parse IDL → floors, decks, pipes, grid metrics |
| [`scripts/pseudo_depth_body.gd`](../scripts/pseudo_depth_body.gd) | Logical pose → screen body/shadow |
| [`scripts/quarter_pipe.gd`](../scripts/quarter_pipe.gd) | Pipe sample (θ, height, zone) |
| [`scripts/debug_tools.gd`](../scripts/debug_tools.gd) | Production gate + god mode state |
| [`scripts/velocity_debug_arrow.gd`](../scripts/velocity_debug_arrow.gd) | Head arrows (`actual` / `intent`) |
| [`scripts/debug_overlay.gd`](../scripts/debug_overlay.gd) / [`debug_sliders.gd`](../scripts/debug_sliders.gd) | HUD debug |

## Behavioral invariants (do not regress)

1. Sim only on physics ticks.  
2. Top coping ≠ lip.  
3. Pipe exit and acid drop both lock X; both use gravity. Acid drop must not snap height; pipe-exit lock may use coping radius as floor.
4. One transfer + one acid drop per aerial; refill on surface contact.  
5. Transfer at rising apex; acid drop must not steal that case.  
6. Acid drop: opposite-facing pipe, top coping, logical-unit buffer/max-ahead.  
7. Free air / acid drop land on **sampled** height — never snap up to coping radius as a fake floor.
