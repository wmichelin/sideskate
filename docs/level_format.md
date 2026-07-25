# SideSkate level format (`.ssk`)

ASCII-first layout language. Absolute world size via `width` / `depth`.  
Top row = **far** (high Z). Bottom row = **near** (low Z). X increases left → right.

## Structure

```text
ssk 1
name my_level
width 1280
depth 100
perspective_inset 80
far_geometry_scale 0.72
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

All map rows must be the **same length**. Uneven widths are a hard error (dialog + quit) naming the file and the mismatched row — short rows are not padded.

## Header keys

| Key | Required | Meaning |
|-----|----------|---------|
| `ssk 1` | yes (first line) | Format version |
| `name` | no | Level id (default: filename) |
| `width` | yes | Logical X span of the full ASCII grid |
| `depth` | yes | Logical Z span of the full ASCII grid |
| `pipe_radius` | no | Default pipe radius; else from `<>` run width |
| `deck_height` | no | Override height for all `#` decks |
| `perspective_inset` | no | Camera converge (px at far) |
| `far_geometry_scale` | no | Far size factor for geometry |

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

## Edge deck example

Rows may begin with `#` after `---` (edge platform outside a pipe).  
Every map row must share one width:

```text
ssk 1
name edge_decks
width 1280
depth 100
perspective_inset 80
far_geometry_scale 0.72
---
##<<<<======>>>>##<<<<======>>>>
##<<<<======>>>>##<<<<======>>>>
<<<<============@===========>>>>
<<<<========================>>>>
<<<<========================>>>>
```
## Single-bay plaza

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
