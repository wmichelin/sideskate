# SideSkate — gameplay & systems

Intent brief for humans and agents. For the ASCII level IDL, see [level_format.md](level_format.md).

## Product shape

Godot 4 **pseudo-3D** skate prototype. Simulation lives in **logical** space:

- **X** — left/right across the plaza
- **Z** — near/far depth (stick “up” = farther). Screen Y uses a fixed px/Z rate (not “fit whole level in frame”), so deep levels scroll off-screen; the camera pans with the player in X and Y.
- **Height** — feet elevation above flat (pipe arc, deck, air)

Screen placement is a **projection** of `(x, z, height)`. Far X converges toward the skater over a fixed `reference_width` (`perspective_inset` default 70). X lean vs depth uses a **world-fixed** Z band (`z_min` → `z_min + reference_depth`) and is **not** clamped — lip lines keep one continuous slope. Moving the skater in Z only trucks the camera / draw window up-down; it does **not** re-center perspective. Screen Y uses a fixed px/Z. World size is `columns × cell_x` / `rows × cell_z`. Visuals are surface-only (floors, pipe ribbons, deck tops).

## Simulation law

All gameplay simulation runs on the **fixed physics timestep** (`_physics_process` / physics `delta`) only — never on render frames. Debug/UI may read state in `_process` but must not step the world.

See also [AGENTS.md](../AGENTS.md).

## Surfaces & zones

**Air contact (label = collision):** each airborne physics tick, after XZ is committed, `RampLevel.resolve_air_contact` builds one underfoot record `{zone, layer, height, solid, hit}`. The **zone matches cell highlight** (`sample(x,z,prefer_h)`). Sticky pipe identity only overrides when you have already dipped below that pipe’s surface while still in its footprint (no tunnel). Glyph `.` → `hole` on that story. Grounded debug zones also show `L#` (e.g. `flat L1`).

**Vertical sweep (air):** when contact is a hole (or still above a solid), a sweep over `[h_before → h_after]` may still catch a **lower** solid crossed this tick. Holes contribute no floor on their story. Landing through a hole may use a surface at **equal** height to the hole story (e.g. L0 coping floor matching L1 `height` under `.`) — only surfaces *above* the hole plane are rejected.

**Solids vs holes:** `=` / `#` / `x` are solid. `.` is a hole (fall-through on that story). Space is hard OOB — the skater is **clamped** into the layer-0 playable footprint (`LevelSpec.clamp_to_playable`). Grounded/`sample` never reports `oob` on a playable cell (deck `#` cells stay `deck` even on outline-poly edges); outside the footprint resolves as a hole so ride-off works until clamp corrects pose.

**Lava (`x`):** zone `lava`. Flying over lava is fine. Landing / standing with `aerial = false` and zone lava freezes the skater, flashes the screen red with “you're dead”, then respawns at the last grounded **floor** or **deck** pad with all MOMENTUM / ACTUAL / air velocity cleared. Spawn `@` seeds the first safe pad.

**Contact vs fall:** fresh pipe mounts require the surface within `ride_off_height_eps` of the feet; solid pads at the same height block remounting the pipe underneath. Coping-exit launch only fires when underfoot is that same pipe identity (side + lip + base). While already on a pipe, height follows the arc. Leaving support into a hole rides off into free air at the prior feet height.

Player-facing zone labels include `flat L#`, `left_pipe L#`, `right_pipe L#`, `deck L#`, and `air (over … L#)` / `air (over hole L#)` while airborne.

**Pipe geometry (logical):**

- **Lip** — where the quarter-pipe meets flat (`lip_x`)
- **Top coping** — `lip ± radius` at θ = π/2 (never treat the lip as coping for air locks / acid drop)

## Grounded motion

Stick integrates into **momentum** (`_velocity` on X/Z). See [Motion vectors](#motion-vectors).

- **Horizontal X**: opposite stick **brakes hard** toward zero via **`brake`** (default 1250) — no reverse until `|vx|` reaches 0. Coasting uses **friction** only (default 0). **MOMENTUM** X / `_ramp_along` are hard-capped to **`±max_speed_x`** (drop-ins, transfers, and live slider changes included).
- **Depth Z**: immediate — stick maps straight to `±max_speed_z` (default 400; debug slider).
- **Rest reset**: when measured **ACTUAL** speed is ≈0, integrated **MOMENTUM** (`_velocity` / `_ramp_along`) is cleared so reverse isn’t fighting leftover control speed (e.g. jammed on a bound). Skipped while air **gravity** applies (horizontal remnant must survive apex / free fall).
- **Acceleration** (default 3250) / **brake** / **max speed x** (default 880) / **max speed z**: tunable via debug sliders.
- **Horizontal facing** `facing_h` (`l` / `r`): follows measured **ACTUAL** X only when `|vx|` is above a small eps and **X-dominant** (`|vx| > |vz|`). Never MOMENTUM (so ollie thrust / leftover `_velocity.x` cannot flip facing). Spawn from level header `spawn_facing` (default `r`). Head debug shows `hd l` / `hd r`.
- **Ollie** (hold Space): mild forward accel (`ollie_accel`, default 650) toward `max_speed_x` in facing direction. Skipped while stick is braking opposite. Tunable via debug slider.
- On flat/deck: move in X/Z; leaving a **higher** support into a lower one **rides off** into free air (keep prior height, apply gravity).
- On a pipe: along-arc speed (`_ramp_along`) follows the arc (θ). Horiz remnant is `along * cosθ`; vertical is `along * sinθ`. At the top coping (θ = π/2) **all** remaining along-speed converts into `air_vel_y` (horiz → 0). **`ramp_friction`** (default 0, debug slider) drains along-speed while on the pipe.

## Motion vectors

Canonical triad for control vs world motion — `MotionVectors.Kind` in [`scripts/motion_vectors.gd`](../scripts/motion_vectors.gd). Same vocabulary for sim gates and head debug arrows. Pattern matches common “wish → control → world” controllers (e.g. Quake wishvel / velocity).

| Kind | Code | Signal | Axes | Head arrow |
|------|------|--------|------|------------|
| **INPUT** | `MotionVectors.Kind.INPUT` | Raw stick wish (`_last_input` × max speeds) | **X + Z only** (planar; no height) | Cyan |
| **MOMENTUM** | `MotionVectors.Kind.MOMENTUM` | Integrated control (`_velocity` / `_ramp_along`) | X/Z; on ramp also shows converted vertical | Orange |
| **ACTUAL** | `MotionVectors.Kind.ACTUAL` | Measured pose rates (`_actual_vel_*`, `_vert_vel`) | X, Z, **height** | Green |

**API:** `Player.motion_screen(kind)` / `Player.motion_speed(kind)` — prefer these over ad-hoc strings. Fly-out gates on **INPUT** only (`|input_x| > |input_z|` and X toward the pipe side); never MOMENTUM.

```gdscript
# Example: branch on the named kind
match kind:
	MotionVectors.Kind.INPUT:
		pass  # planar wish only
	MotionVectors.Kind.MOMENTUM:
		pass  # integrated control
	MotionVectors.Kind.ACTUAL:
		pass  # world measurement
```

## Air model

Feet height while airborne: `air_abs_height`. Vertical rate for gravity: `air_vel_y` (when gravity applies).

| Mode | How you get there | X | Height |
|------|-------------------|---|--------|
| **Pipe coping lock** | Exit pipe at top coping | Locked to **top** coping | Gravity; land on coping height (`radius`). At vertical **apex**, facing flips unless stick holds L/R. |
| **Free air** | Ride-off, transfer, fly-out, etc. | Free (unless lerping) | Gravity; land on **sampled** underfoot height |
| **Acid-drop lock** | Acid drop action | Locked to opposite-facing **top** coping | Gravity only — action must not snap/alter height; land converts vert → along-arc (keep approach if faster) |
| **Spine transfer lock** | Spine transfer (rising, facing-cast coping) | Locked to facing **top** coping | Gravity; land same drop-in merge as acid / pipe-exit. No apex facing flip. |

### Pipe fly-out

While in **pipe coping lock** (not acid-drop / spine), X stays locked even if underfoot becomes hole / flat / another zone — only **fly-out** clears it. Fly-out requires still **rising** (`air_vel_y > 0`), feet height ≥ `coping_floor + fly_out_above_coping` (debug slider **fly out**, default 40), **and** planar **INPUT** that is **X-dominant** (`|input_x| > |input_z|`) toward that pipe’s side (right pipe → right; left → left). MOMENTUM is never consulted. Keep `air_abs_height` / `air_vel_y` on unlock for a **parabolic** arc. Falling or Z-dominant / vertical-only stick → stay locked and land as usual. While locked, air contact **force-sticky**s to that coping — rising past a higher opposite pipe does **not** auto spine; press transfer for spine low→high.

Pipe coping lock treats the top coping height (`base_height + radius`) as the floor. Acid-drop lock and free air **must not** use that shortcut (it would snap feet upward); they sample the real surface under `(x, z)`.

### Ride-off

When grounded motion would place you on a surface lower than prior support (beyond a small epsilon), enter free air at the **previous** support height and start gravity. Works for deck → pipe/flat and similar drops. Spawn is assumed to start on floor.

### Air shadow

While airborne, a **circular** ground shadow sits on the underfoot support surface (same idea as cell highlight height, at the skater’s X/Z — not the cell footprint). Width matches body scale at support and shrinks toward a floor as feet rise (`PerspectiveMath.air_shadow_width_scale`; tunable on `PseudoDepthBody`: `air_shadow_ref_height`, `air_shadow_min_scale`). Hidden while grounded.

### Gravity

Applied while unlocked air, or while acid-drop X-locked. Default `-19.0` m/s², converted with `logic_per_meter` (default 100). Tunable via top-right debug slider.

## Aerial actions (same button: `transfer` / P or T)

One **transfer** and one **acid drop** per aerial. Both refill on any surface contact (`_clear_air`). Spine transfer spends **both**.

**Hold buffer:** keep `transfer` held while entering a ramp; once airborne, each physics tick retries **spine transfer only** while the button stays pressed and a facing coping is valid, including high→low (e.g. L1 → L0 shared coping). Free-air transfer and acid drop still require a tap (`just_pressed`).

Routing uses measured vertical rate (`_vert_vel`) and the last non-zero vertical rate (so a rising **apex** still counts as transfer, not acid drop):

| Vertical condition | Action |
|--------------------|--------|
| Rising, or `vert ≈ 0` after a positive (up) non-zero | **Transfer** path (spine transfer if eligible, else normal transfer) |
| Falling (or rest after down) | **Acid drop** |

### Spine transfer

When the transfer path runs and FacingCastMath finds a **top coping** within `facing_coping_cells` deck cells ahead of `facing_h` (default **3**, debug **coping cells** slider; excludes the pipe you’re on), fire spine transfer instead of free-air transfer. Works while **airborne and rising**, or **grounded on a pipe riding up** toward coping (T/P leaves the wall into the spine lock):

- Lerp/lock X to that **top coping** (never the lip); keep `air_abs_height` and `air_vel_y` (continue the rise). Same live height-scaled X settle + smoothstep as acid drop.
- Stash into-pipe **MOMENTUM** from **peak** aerial speed (`_air_carry_speed` / `lock_carry_velocity_x`) — not live `air_vel_y` after a gravity climb — so low→high still drop-ins at exit speed (`merge_drop_in_along` keeps the faster approach). Stick does not brake that carry while locked.
- While locked, air contact **force-sticky**s to that coping and does not adopt a different underfoot pipe (shared high→low column would otherwise snap identity back same tick).
- On land: same drop-in as pipe-exit / acid — falling `air_vel_y` → `_ramp_along` (keep approach if faster into the pipe).
- No fly-out while the spine lock is active.
- No apex facing flip while the spine lock is active (keep approach facing through the transfer).
- Holes are transparent in the cast — a lower-story coping under `.` still counts (high→low).
- Spend **both** transfer and acid-drop charges.

If no coping is in range → normal free-air transfer below.

### Transfer

- Probe “behind” the current pipe / last behind-sign for deck, other pipe, or flat.
- Enter free air over the target at **same** height; gravity applies.
- Leaving **locked** coping air: seed horizontal `_velocity.x` in the behind direction (`max(|momentum|, transfer_release_min)`) and **skip** the slow X position lerp so motion doesn’t restart from near-zero.
- Unlocked→unlocked transfers may still short-lerp X when needed; don’t double-apply X while a lerp owns position.

### Acid drop

- Falling only (same button as transfer).
- Travel = measured **ACTUAL** X if nonzero, else pipe-exit outward travel, else **MOMENTUM** X. Stick-MOMENTUM never beats exit travel (that used to cast back into the exit wall after fly-out). No travel signal → no acid. Facing is ignored.
- Target is the first **opposite-facing** top coping within `facing_coping_cells` strictly ahead along that travel (right → left pipe; left → right pipe). Never the exit wall / coping column, never a same-side coping (same-side land drop-in reverses travel).
- If acid is pressed with no valid forward coping: unlock the exit X-pin, keep/seed travel velocity, and mark the aerial so landing **cannot** run classic into-bowl `lock_carry` / merge (that was the “acid reversed me” snap when the cast missed).
- Animate/lerp X onto that coping; settle is hard-clamped so X never moves opposite travel. Keep `air_abs_height` / `air_vel_y`; gravity continues. Opposing MOMENTUM is cleared (not flipped into-pipe). Land only when falling onto sampled surface (no upward height snap). While acid is active, **refuse to land on the exit pipe** (and any non-target pipe) so mid-lerp underfoot contact cannot slam you back into the bowl.
- X settle duration from live height above coping: `acid_drop_x_duration + acid_drop_x_duration_per_height × h` (defaults 0.18 + 0.002×h, soft-capped at `acid_drop_x_duration_max` 0.9). Smoothstep ease.
- On land: along-arc keeps acid travel sign. Falling vert → along only when that drop-in continues travel (opposite wall). Never emit along opposite travel.
- Fly-out seeds outward horizontal speed and marks the aerial; falling back onto the exit wall soft-lands (no into-bowl yank). After fly-out, the transfer button always routes to **acid** (never transfer/spine) — fly-out apex used to count as transfer and slam into-bowl carry.

## Level units (.ssk cells)

Each ASCII map glyph is one logical cell:

- `cw = width / W`, `ch = depth / H`
- Row 0 = far (top of file); bottom row = near
- Stored on `LevelSpec` (`grid_w`, `grid_h`, `cell_w`, `cell_h`); helpers `cell_at`, `cell_at_for_pose`, `cell_bounds`

Debug **cell highlight** (default off) draws the cell under the player in yellow (air or grounded), using underfoot surface height (floor = 0 at spawn). Cell indexing for targeting / highlight uses `LevelSpec.cell_at_for_pose` (via `Player.cell_under_feet` / `cell_sample_xz`): while X-locked on pipe coping, sample X is nudged into the pipe so half-open `cell_at` does not assign **right**-pipe coping to the next cell outward.

Debug **facing cast** (default off) draws **N** green logical cells ahead of `facing_h` along X only. Cast length is the **cast cells** slider (default 3, max 16). Gameplay acid/spine use **`facing_coping_cells`** (**coping cells** slider, default 3) via the same FacingCastMath cast. Each tile is a flat constant-height pad; holes fall through; coping cells draw amber (`is_coping`).

## Debug overlays

Debug tools are gated by autoload `DebugTools`: available when `OS.is_debug_build()` **or** export feature `debug_tools`. Release exports strip HUD/arrows/cell highlight (group `debug_tools`) and ignore god mode.

| Piece | Role |
|-------|------|
| Head arrows | [Motion vectors](#motion-vectors): green **ACTUAL**, orange **MOMENTUM**, cyan **INPUT** |
| Top-left overlay | Depth/zone/surface + **airborne** + cell + **next coping** |
| Top-right sliders | Gravity, acid buffer, **fly out**, cell-highlight / facing-cast, cast cells / **coping cells**, **god mode** |
| **God mode** (default off; `G` or checkbox) | No gravity; **k** rise / **j** lower (`god_vert_speed`) |

## Key scripts

| Script | Role |
|--------|------|
| [`scripts/player.gd`](../scripts/player.gd) | Motion, air, transfer, acid drop, ride-off; `motion_screen` / `motion_speed` |
| [`scripts/ramp_level.gd`](../scripts/ramp_level.gd) | Load `.ssk`, sample surfaces, project to screen |
| [`scripts/ramp_visual.gd`](../scripts/ramp_visual.gd) | Surface draw + cell / facing-cast highlight |
| [`scripts/level_loader.gd`](../scripts/level_loader.gd) / [`level_spec.gd`](../scripts/level_spec.gd) | Parse IDL → floors, decks, pipes, grid metrics |
| [`scripts/perspective_math.gd`](../scripts/perspective_math.gd) | Pure pseudo-depth projection helpers |
| [`scripts/pipe_math.gd`](../scripts/pipe_math.gd) | Pure coping / opposite-pipe helpers |
| [`scripts/motion_math.gd`](../scripts/motion_math.gd) | Pure brake-no-reverse + facing / transfer-vert helpers |
| [`scripts/motion_vectors.gd`](../scripts/motion_vectors.gd) | Named triad `INPUT` / `MOMENTUM` / `ACTUAL` |
| [`scripts/aerial_math.gd`](../scripts/aerial_math.gd) | Pure transfer / spine / acid routing + `merge_drop_in_along` / `lock_carry_velocity_x` |
| [`scripts/facing_cast_math.gd`](../scripts/facing_cast_math.gd) | Pure facing-cast cells + story/pipe/coping surface resolve |
| [`scripts/pseudo_depth_body.gd`](../scripts/pseudo_depth_body.gd) | Logical pose → screen body + air/ground shadow |
| [`scripts/quarter_pipe.gd`](../scripts/quarter_pipe.gd) | Pipe sample (θ, height, zone) |
| [`scripts/debug_tools.gd`](../scripts/debug_tools.gd) | Production gate + god mode state |
| [`scripts/velocity_debug_arrow.gd`](../scripts/velocity_debug_arrow.gd) | Head arrow for one `MotionVectors.Kind` |
| [`scripts/debug_overlay.gd`](../scripts/debug_overlay.gd) / [`debug_sliders.gd`](../scripts/debug_sliders.gd) | HUD debug |

## Behavioral invariants (do not regress)

1. Sim only on physics ticks.  
2. Top coping ≠ lip.  
3. Pipe exit and acid drop both lock X; both use gravity. Acid drop must not snap height; pipe-exit lock may use coping radius as floor. Pipe fly-out unlocks X when above coping with outward INPUT; preserves vertical velocity.  
4. One transfer + one acid drop per aerial; refill on surface contact. Spine transfer spends both.  
5. Transfer at rising apex; acid drop must not steal that case. Spine transfer only on the rising path.  
6. Acid drop / spine: FacingCastMath first top coping within `facing_coping_cells` ahead of `facing_h` (excludes current pipe).  
7. Free air / acid drop land on **sampled** height — never snap up to coping radius as a fake floor.  
8. Fly-out: only unlock for pipe-exit X-lock; rising + X-dominant INPUT toward pipe (never MOMENTUM); never from acid/spine; contact changing to hole/flat does not unlock.  
9. Spine transfer: rising path + facing-cast coping in range; keep height + `air_vel_y`; land uses shared drop-in merge; else normal transfer. No apex facing flip while spine-locked.  
10. Locked pipe land (pipe-exit / acid / spine): `merge_drop_in_along` — fall vert → along-arc, keep approach if faster into the pipe. Peak `_air_carry_speed` this aerial seeds approach so low→high climbs keep exit speed.  
11. Acid/spine X settle: live `duration = base + rate × height_above` (`lock_x_duration_for_height`); progress `+= δt/duration`; smoothstep ease.

Covered by headless tests in `tests/test_aerial_math.gd` / `tests/test_motion_math.gd` / `tests/test_cell_at_for_pose.gd` (routing, acid selection, landing floor, spine gaps, lock carry vs weak land_vy, coping-lock cell targeting).
