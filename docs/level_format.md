# SideSkate level format (`.ssk`)

ASCII-first layout language. Absolute world size via `width` / `depth`.  
Top row = **far** (high Z). Bottom row = **near** (low Z). X increases left → right.

## Structure

```text
ssk 1
name my_level
width 1280
depth 100
perspective_inset 200
far_geometry_scale 1.0
reference_depth 500
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

## Header keys

| Key | Required | Meaning |
|-----|----------|---------|
| `ssk 1` | yes (first line) | Format version |
| `name` | no | Level id (default: filename) |
| `width` | yes | Logical X span of the full ASCII grid |
| `depth` | yes | Logical Z span of the full ASCII grid. Screen Y uses a fixed px/Z rate from `reference_depth`; deeper levels extend off-frame and the camera pans with the player. |
| `pipe_radius` | no | Default pipe radius; else from `<>` run width |
| `deck_height` | no | Override height for all `#` decks |
| `perspective_inset` | no | How hard far X converges toward the skater (px; → `far_x_scale`). Lower ≈ more isometric / parallel. |
| `far_geometry_scale` | no | Far size factor for vertical geometry (closer to 1 ≈ more isometric). Lean/scale use `reference_depth`, not the full level depth. |
| `reference_depth` | no | Z span over which perspective lean/X converge saturate (default ~500). Deep plazas keep converging only for this band, then parallel. |
| `spawn_facing` | no | Spawn horizontal facing: `l` or `r` (default `r`) |

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
width 1280
depth 100
perspective_inset 80
far_geometry_scale 0.72
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
width 1280
depth 100
perspective_inset 80
far_geometry_scale 0.72
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
width 1280
depth 100
perspective_inset 80
far_geometry_scale 0.72
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
width 1280
depth 100
perspective_inset 80
far_geometry_scale 0.72
---
<<<<========================>>>>
<<<<========================>>>>
<<<<============@===========>>>>
<<<<========================>>>>
<<<<========================>>>>
```

## Scaling

Grid `W`×`H`, cell size `cw = width/W`, `ch = depth/H`.

Tile `(col, row)` with `row=0` at top/far:

- `x ∈ [col·cw, (col+1)·cw]`
- `z ∈ [(H-1-row)·ch, (H-row)·ch]`

## Sampling priority

1. Pipe footprint  
2. Deck  
3. Floor  
4. Out of bounds  
