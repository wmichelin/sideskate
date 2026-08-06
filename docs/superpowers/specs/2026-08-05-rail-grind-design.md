# Rail grind (along-X glyph)

**Status:** approved design (2026-08-05). Implementation plan:
[`docs/superpowers/plans/2026-08-05-rail-grind.md`](../plans/2026-08-05-rail-grind.md).

## Goal

Add an along-X **rail** glyph. While airborne near a rail, hold **grind (R)** to
lock on and grind. Coast with mount speed; stick only balances. Leave via
**ollie release** (shared ollie charge curve/bar) or by riding off the rail end.
Balance fail triggers the existing fall bout. Without R, the rail is a solid
bonk/Reject.

## Context

SideSkate’s park is IDL → `IdlCompiler` → analytical `ParkModel`; `PlayerSim` is
sole gameplay authority. Surfaces today: floor, deck, pipe, ramp, wall, lava.
No rail/grind path exists. Hang/transfer/fly-out stay separate vocabulary;
grind is a new ride mode on a new surface kind.

## Vocabulary

| Term | Meaning |
|------|---------|
| **Rail** | Compiled along-X grind bar from glyph `-` |
| **Grind** | Locked-on ride along a rail (sim mode / on-rail state) |
| **Grind lock** | Input action `grind` (physical **R**); required only to **mount** |
| **Snap radius** | Airborne proximity to rail for magnetic mount while R held |
| **Balance** | Signed lean in `[-1, 1]` from both stick axes (A/D + W/S); `|lean|` past fail threshold → fall |
| **End eject** | Leaving free air when grind X crosses rail `x_min` / `x_max` |
| **Ollie out** | Hold Space (shared charge), release → pop off rail into free air |

## Player-facing behavior

| Rule | Behavior |
|------|----------|
| Glyph | `-` horizontal runs only (v1). No Z-oriented rail glyph yet. |
| Height | Rail top at `layer.height + RAIL_OFFSET` (fixed constant; not slider). |
| Thickness | Thin vertical bar; default ~a few screen pixels; **debug slider** tunes thickness only (runtime — mesh + Reject volume; not bake-only). |
| Mount | **Airborne** + **R held** + within snap radius → lock onto rail (magnetic snap). Grounded near rail does **not** mount. |
| Miss | Airborne contact / path into rail **without** R → solid **Reject / bonk** (crash family). |
| Grind motion | Coast along X with **signed** mount `vx` as along-rail speed; stick does **not** accel/brake. |
| Balance | Stick X and depth both feed one signed lean; `|lean|` over fail threshold → `begin_fall()`. |
| Stay locked | R not required after mount. |
| Ollie out | Same ollie charge curve and **debug-controlled** charge bar as grounded/air ollie; release while grinding → free air with pop + carry along-rail speed into `vx`. |
| End of rail | X past segment end while grinding → auto free-air eject along momentum (not a wipeout). |
| Balance HUD | **Always shown while grinding** (production HUD): center = neutral; fill **left/right** with signed lean toward fail. Not a debug toggle. |
| Ignored on grind (v1) | Air spin, transfer hold, fly-out. |

**Exit priority (same tick):** ollie release > end eject for voluntary leave; balance fail / fall request aborts the grind.

## Architecture

First-class analytical rail + grind mode (not a `ManeuverPlan`, not hang reuse).

| Piece | Role |
|-------|------|
| LevelLoader / `.ssk` | Accept `-`; connected runs → rail descriptors on the layer |
| `IdlCompiler` | Emit `RailSurface` (`x_min`/`x_max`, centerline `z`, top height from layer + fixed offset) |
| `SimKinds.SurfaceKind.RAIL` | New kind for queries / crash / debug |
| `ParkModel` | Store rails; open ends imply end-eject (no special edge required beyond segment bounds) |
| Air / contact | Without grind lock: rail volume (runtime thickness) → Reject. With airborne + R + in radius: mount grind |
| `PlayerSim` / grind solver | Grind tick: integrate X, update balance, classify exits |
| `SimState` | Grind flags, rail id, along-rail speed, signed balance lean |
| InputMap | `grind` → R; wire through `player.gd` → `set_input` |
| Presentation | Thin bar mesh from rail segment (thickness from tunable); always-on balance meter while grinding |
| Debug | Thickness slider only (offset fixed). Ollie charge bar remains debug-gated as today |

### Geometry (v1)

- One contiguous `-` run on a single map row → one `RailSurface` along **X**.
- Centerline `z` = cell mid-Z for that row.
- Stacked `-` on adjacent rows → **separate** rails (not merged into a pad).
- Vertical extent = thickness (slider); mount seats on the **top** of the bar.
- Snap radius: constant around the rail top/centerline (tunable later if needed).

### Grind loop

1. Airborne, R held, nearest rail in snap radius → enter grind; pin depth/`z` and height to rail top; seed along-rail speed from signed approach `vx`.
2. Each physics tick: coast X; sample stick → signed balance; if `|lean|` fails → `begin_fall()` and clear grind.
3. Ollie pressed while grinding builds shared `ollie_charge`; release → exit grind to airborne with pop impulse + carry along-rail speed into `vx`.
4. If `x` leaves `[x_min, x_max]` → end eject to airborne (no fall).
5. New air bout after leave resets air-spin bout as usual.

## Out of scope (v1)

- Along-Z / vertical rails or dual-orientation glyphs
- Slider for rail offset / snap radius / balance threshold (constants OK)
- Stick speed control or brake on rail
- Grind tricks (50-50 vs boardslide, manuals on rail)
- Requiring R to stay locked; release-R drop
- Touch binding for grind (can follow mobile controls later)
- Score / combo metering

## Acceptance

1. `-` in a `.ssk` compiles to an along-X rail at fixed offset with slider thickness
2. Airborne + R in radius mounts; grounded + R does not
3. Air into rail without R Rejects / bonks
4. While grinding, stick lean past threshold → fall; balance HUD visible
5. Ollie charge (debug bar) works on rail; release pops into free air
6. Coasting past either end ejects into free air without fall
7. Thickness debug slider changes bar mesh + collision thickness
8. Headless tests cover mount / reject / balance fail / ollie out / end eject

## Defaults (initial)

- Glyph: `-`
- Grind input: `grind` / **R**
- `RAIL_OFFSET`: `56` logical (~board/knee height above layer floor)
- Thickness: small logical height (~few pixels at default cam); debug slider range covers thinner→thicker bar
- Balance: stick tips a meter over time (`GRIND_BALANCE_RATE`); neutral stick recovers; fail at `|lean| ≥ 1`
