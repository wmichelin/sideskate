# SideSkate level format (`.ssk`)

ASCII-first layout language. World size is derived from the glyph grid × global cell size.  
Top row = **far** (high Z). Bottom row = **near** (low Z). X increases left → right.

## Structure

```text
ssk 2
name my_level
# optional header comments / keys:
# pipe_radius 150
# deck_height 150
---
layer 0
height 0
<<<<========================>>>>
<<<<============@===========>>>>
<<<<========================>>>>
```

1. **Header** — `ssk 2`, keys, `#` comments, blank lines  
2. **`---`** — required separator before layer blocks  
3. **Layer blocks** — one or more `layer N` / `height H` / ASCII map grids  

Files in `levels/` whose names start with `_` (e.g. `_template.ssk`) are templates only — the start menu ignores them.

All map rows in a layer must be the **same length**. Every layer shares the same W×H. Uneven widths are a hard error.

`ssk 1` (single map, no layers) is **rejected**.

## World size

Level extents are automatic:

- `width = columns × cell_size_x` (default cell X = **47**)
- `depth = rows × cell_size_z` (default cell Z = **26**)

Add glyphs to grow the plaza; do not set `width` / `depth` in the header (ignored if present). Cell sizes are game-wide (RampLevel exports + TUNING sliders `cell x` / `cell z`).

Pipe radius follows run width in cells (`<<<<` → 4 × cell_x), so the same glyph pattern always builds the same logical ramp. Pipe **base** sits at the layer’s `height`; surface height is `base_height + radius * (1 − cos θ)`.

Perspective (`perspective_inset`, `far_geometry_scale`, `reference_depth`, `reference_width`) lives on **RampLevel** / TUNING only — not in `.ssk` files.

## Header keys

| Key | Required | Meaning |
|-----|----------|---------|
| `ssk 2` | yes (first line) | Format version |
| `name` | no | Level id (default: filename) |
| `pipe_radius` | no | Default pipe radius; else from `<>` run width |
| `deck_height` | no | Override **rise** for all `#` decks (added to layer height) |
| `spawn_facing` | no | Spawn horizontal facing: `l` or `r` (default `r`) |

Deprecated (ignored with a warning): `width`, `depth`, `perspective_inset`, `far_geometry_scale`, `reference_depth`, `reference_width`.

## Layer blocks

```text
---
layer 0
height 0
<<<<====>>>>
<<<<=@=>>>>
<<<<====>>>>
---
layer 1
height 188
....====....
....====....
....====....
```

| Directive | Meaning |
|-----------|---------|
| `layer N` | Story index (unique; usually 0, 1, …) |
| `height H` | Absolute logical floor height for this story |

- Layer **0** defines the playable **footprint**: any non-space cell is playable.  
- Upper layers must use `.` for holes **inside** that footprint — never space (space = hard OOB).  
- One `@` spawn total across all layers.

## Glyphs

| Glyph | Kind | Height |
|-------|------|--------|
| `=` | Floor at layer height | `layer.height` |
| `.` | Hole (nil) on this layer — fall through | — |
| `#` | Deck (spine / coping flat) | `layer.height + pipe rise` |
| `@` | Spawn + floor | `layer.height` |
| `<` | Left-facing pipe (lip on **right** edge of run) | `base + R(1−cosθ)` |
| `>` | Right-facing pipe (lip on **left** edge of run) | `base + R(1−cosθ)` |
| space | Out of bounds — player must never enter | — |

## Deck height

For each connected `#` component on a layer:

1. Find 4-neighbor pipe tiles (`<` or `>`) on that layer  
2. `rise = max(radius)` of those pipes (or header `deck_height`)  
3. Deck absolute height = `layer.height + rise`  
4. Error if no neighboring pipe and no header override  

## Spine example

```text
ssk 2
name spine_demo
---
layer 0
height 0
<<<<=======>>>>##<<<<=======>>>>
<<<<=======>>>>##<<<<=======>>>>
<<<<============@===========>>>>
<<<<========================>>>>
<<<<========================>>>>
```

`>>>>##<<<<` = right-pipe → elevated deck spine → left-pipe.  
Both pipe runs must be the same width so coping height matches on both sides.

## Multi-story example

See `levels/layered_demo.ssk`: ground halfpipe plus an upper floor with a hole. Ride the pipe to the upper story, or fall through `.` cells with gravity.

## Sampling

`RampLevel.sample(x, z, prefer_side, prefer_lip, prefer_h, prefer_base_h)`:

1. Collect all surfaces at `(x, z)` (pipes with `base_height`, decks, `=` floors).  
2. With `prefer_h` (feet / air height), pick the **topmost** surface at or below that height.  
3. Sticky ride matches side + lip + **base_height** so a lower-story pipe cannot steal the ride.  
4. Holes contribute no floor → fall-through. Space / empty → `oob`.

Contact rules (player): only stand within `ride_off_height_eps` of feet; never snap `surface_height` down onto a far-below story.

## Scaling

Grid `W`×`H`, cell size `cw = cell_size_x`, `ch = cell_size_z`.

Tile `(col, row)` with `row=0` at top/far:

- `x ∈ [col·cw, (col+1)·cw]`
- `z ∈ [(H-1-row)·ch, (H-row)·ch]`
