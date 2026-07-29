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
<<<==========================>>>
<<<=============@============>>>
<<<==========================>>>
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
- `depth = rows × cell_size_z` (default cell Z = **47**, matching X so glyphs are square)

Add glyphs to grow the plaza; do not set `width` / `depth` in the header (ignored if present). Cell sizes are game-wide (RampLevel exports + TUNING sliders `cell x` / `cell z`).

Pipe radius follows run width in cells (`<<<` → 3 × cell_x, `<<<<` → 4 × cell_x), so
glyph count sets the quarter-circle size. Draw code builds a **screen-space** 90°
circle from that projected width; deck tops/walls use `deck_visual_height` so the
pad lowers/raises to meet those pipe copings (physics still uses logical `base + radius`).

Perspective (`perspective_inset`, `far_geometry_scale`, `reference_depth`, `reference_width`) lives on **RampLevel** / TUNING only — not in `.ssk` files.

## Header keys

| Key | Required | Meaning |
|-----|----------|---------|
| `ssk 2` | yes (first line) | Format version |
| `name` | no | Level id (default: filename) |
| `pipe_radius` | no | Default pipe radius; else from `<>` run width |
| `deck_height` | no | Override **rise** for all `#` decks (added to layer height) |
| `spawn_facing` | no | Spawn horizontal facing: `l` or `r` (default `r`) |

`@` may sit on any layer; the skater spawns at that layer’s `height` (`LevelSpec.spawn_height`).

Deprecated (ignored with a warning): `width`, `depth`, `perspective_inset`, `far_geometry_scale`, `reference_depth`, `reference_width`.

## Layer blocks

```text
---
layer 0
height 0
<<<======>>>
<<<==@==>>>
<<<======>>>
---
layer 1
height 141
....====....
....====....
....====....
```

| Directive | Meaning |
|-----------|---------|
| `layer N` | Story index (unique; usually 0, 1, …) |
| `height H` | Absolute logical floor height for this story |

- Layer **0** defines the playable **footprint**: any non-space cell is playable.  
- Upper layers must use `.` for holes **inside** that footprint — never space (space = solid invisible wall).
- One `@` spawn total across all layers (player starts at that story’s `height`).

## Glyphs

| Glyph | Kind | Height |
|-------|------|--------|
| `=` | Floor at layer height | `layer.height` |
| `x` / `X` | Lava pad (solid; lethal when grounded) | `layer.height` |
| `.` | Hole (nil) on this layer — fall through | — |
| `#` | Deck (spine / coping flat) | `layer.height + pipe rise` |
| `@` | Spawn + floor | `layer.height` |
| `<` | Left-facing pipe (lip on **right** edge of run) | `base + R(1−cosθ)` |
| `>` | Right-facing pipe (lip on **left** edge of run) | `base + R(1−cosθ)` |
| space | Solid invisible wall (never enter; not a kill) | — |

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
<<<=========>>>##<<<=========>>>
<<<=========>>>##<<<=========>>>
<<<=============@============>>>
<<<==========================>>>
<<<==========================>>>
```

`>>>##<<<` = right-pipe → elevated deck spine → left-pipe.  
Both pipe runs must be the same width so coping height matches on both sides.

## Multi-story example

See `levels/layered_demo.ssk`: ground halfpipe plus an upper floor with a hole. Ride the pipe to the upper story, or fall through `.` cells with gravity.

## Sampling

`RampLevel.sample(...)` is a **presentation / debug** helper for cell highlight and mesh projection. It is **not** gameplay contact authority — the analytical sim uses `SurfaceQuery` over the compiled `ParkModel`.

Optional sticky preferences exist only so debug underfoot labels can stay on a pipe footprint while inspecting; they do not drive `PlayerSim`.

## Scaling

Grid `W`×`H`, cell size `cw = cell_size_x`, `ch = cell_size_z`.

Tile `(col, row)` with `row=0` at top/far:

- `x ∈ [col·cw, (col+1)·cw]`
- `z ∈ [(H-1-row)·ch, (H-row)·ch]`

## Derived topology (analytical sim)

The glyph language is unchanged. The analytical compiler (`scripts/sim/idl_compiler.gd`)
derives an immutable park model from the grid:

### Pipe lofts

Same-side contiguous `<` / `>` cells form a pipe component. Per ASCII row, radius =
run width × `cell_w` (or header `pipe_radius`). Across Z, `lip(z)`, `radius(z)`, and
`base(z)` are joined with monotone interpolation that does not overshoot. Runtime
logic never branches on layer index — layers only contribute absolute heights at
compile time.

### Coping classification

Every pipe coping edge is classified exactly once:

| Class | When | Behavior |
|-------|------|----------|
| `OPEN` | No outward solid at coping height | Explicit fly-out allowed |
| `SUPPORT_SEAM` | Outward deck/floor top matches coping height (within seam eps) | Auto-roll onto pad |
| `WALL_EXTENSION` | Outward floor above coping, or taller opposite pipe (cross-story) | Climb to effective lip; mount floor or air/fly |
| `SHARED_SPINE` | Opposite-facing coping at matching height (`>>>##<<<`, `>>><<<`) | Spine target relation |

An outward `#` deck abutting a coping is never simultaneously fly-out space and a
catch wall. See [`docs/movement_contract.md`](movement_contract.md).

### Validation

Ambiguous geometry is a hard compile error with layer/row/column/glyph context:
self-intersecting lofts, mismatched shared-spine heights, unclassifiable deck–pipe
contacts, and duplicate nondeterministic targets.
