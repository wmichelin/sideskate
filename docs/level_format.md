# SideSkate level format (`.ssk`)

ASCII-first layout language. World size is derived from the glyph grid × global cell size.  
Top row = **far** (high Z). Bottom row = **near** (low Z). X increases left → right.

## Structure

```text
ssk 1
name my_level
# optional header comments / keys:
# pipe_radius 150
# deck_height 150
---
<<<<========================>>>>
<<<<============@===========>>>>
<<<<========================>>>>
```

1. **Header** — version, keys, `#` comments, blank lines  
2. **`---`** — required separator (also accepts `map`)  
3. **Map** — ASCII grid; `#` here is a **deck**, never a comment  

Files in `levels/` whose names start with `_` (e.g. `_template.ssk`) are templates only — the start menu ignores them.

All map rows must be the **same length**. Uneven widths are a hard error (dialog + quit) naming the file and the mismatched row — short rows are not padded.

## World size

Level extents are automatic:

- `width = columns × cell_size_x` (default cell X = **47**)
- `depth = rows × cell_size_z` (default cell Z = **26**)

Add glyphs to grow the plaza; do not set `width` / `depth` in the header (ignored if present). Cell sizes are game-wide (RampLevel exports + TUNING sliders `cell x` / `cell z`).

Pipe radius follows run width in cells (`<<<<` → 4 × cell_x), so the same glyph pattern always builds the same logical ramp.

Perspective (`perspective_inset`, `far_geometry_scale`, `reference_depth`, `reference_width`) lives on **RampLevel** / TUNING only — not in `.ssk` files. Default inset is 160; X convergence uses fixed `reference_width`. Lean is relative to the skater over `reference_depth` (not level `z_min`); drawing pads past that band so near/far perspective lines still show.

## Header keys

| Key | Required | Meaning |
|-----|----------|---------|
| `ssk 1` | yes (first line) | Format version |
| `name` | no | Level id (default: filename) |
| `pipe_radius` | no | Default pipe radius; else from `<>` run width |
| `deck_height` | no | Override height for all `#` decks |
| `spawn_facing` | no | Spawn horizontal facing: `l` or `r` (default `r`) |

Deprecated (ignored with a warning): `width`, `depth`, `perspective_inset`, `far_geometry_scale`, `reference_depth`, `reference_width`.

## Glyphs

| Glyph | Kind | Height |
|-------|------|--------|
| `=` `.` | floor (plaza) | 0 |
| `#` | deck (spine / coping flat / edge platform) | adjacent pipe radius (coping) |
| `@` | spawn (counts as floor) | 0 |
| `<` | left-facing pipe (lip on **right** edge of run) | quarter-circle |
| `>` | right-facing pipe (lip on **left** edge of run) | quarter-circle |
| space | out of bounds | — |

## Deck height

For each connected `#` component:

1. Find 4-neighbor pipe tiles (`<` or `>`)
2. `deck_height = max(radius)` of those pipes
3. Or use header `deck_height` if set
4. Error if no neighboring pipe and no header override

## Spine example

```text
ssk 1
name spine_demo
---
<<<<=======>>>>##<<<<=======>>>>
<<<<=======>>>>##<<<<=======>>>>
<<<<============@===========>>>>
<<<<========================>>>>
<<<<========================>>>>
```

`>>>>##<<<<` = right-pipe → elevated deck spine → left-pipe.  
Both pipe runs must be the same width so coping height matches on both sides.

## Decks (spine / edge / partial depth)

`#` after `---` is always a deck glyph (never a header comment).

- Decks may cover only some rows (partial depth) while pipes continue — that’s valid.
- Pipe runs merge vertically only when **column spans match**; stepped `<>` columns become separate pipes (no fat AABB overlap).
- All map rows must be the same length.
- Rendering is **surface-only**: decks are elevated top faces (same family as floors), not solid pillars. Pipe ribbons meet deck edges at coping height; spine troughs stay open.

### Multi-spine / stepped example

```text
ssk 1
name spine_demo
---
<<<<===>>>>##<<<<=======>>>>##<<<<=======>>>>
<<<<===>>>>##<<<<=======>>>>##<<<<=======>>>>
<<<<===>>>>##<<<<=======>>>>##<<<<=======>>>>
<<<<===>>>>##<<<<=======>>>>##<<<<=======>>>>
<<<<====>>>><<<<====@===>>>>##<<<<=======>>>>
```

Bottom row drops the first spine deck (`>>>><<<<`) and shifts a bay — pipes stay separate because columns differ.

### Partial-depth spine (deck only in far rows)

```text
ssk 1
name partial_spine
---
<<<<=======>>>>##<<<<=======>>>>
<<<<=======>>>>##<<<<=======>>>>
<<<<============@===========>>>>
<<<<========================>>>>
<<<<========================>>>>
```

Here the spine pipes and deck share the far rows only; plaza pipes on the sides can still run full depth.

```text
ssk 1
name plaza_default
---
<<<<========================>>>>
<<<<========================>>>>
<<<<============@===========>>>>
<<<<========================>>>>
<<<<========================>>>>
```

## Scaling

Grid `W`×`H`, cell size `cw = cell_size_x`, `ch = cell_size_z`.

Tile `(col, row)` with `row=0` at top/far:

- `x ∈ [col·cw, (col+1)·cw]`
- `z ∈ [(H-1-row)·ch, (H-row)·ch]`

## Sampling priority

1. Pipe footprint  
2. Deck  
3. Floor  
4. Out of bounds  
