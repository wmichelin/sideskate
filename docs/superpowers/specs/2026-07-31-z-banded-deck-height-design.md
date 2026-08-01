# Z-banded deck height — stepped `#` spines

## Goal

When a connected `#` strip abuts pipe/ramp runs of different rises along depth (Z), compile **separate flat deck patches** per rise band so each short/tall coping meets a matching deck top. Stop lifting the whole strip to `max(neighbor rise)` (the floating-roof gap over short pipes).

Example authoring that must work:

```text
===)##(===
===)##(===
===)##(===
===)##(===
===)##(===
=)))##(((=
=)))##(((=
=)))##(((=
=)))##(((=
=)))##(((=
```

Short `)##(` bands get a short deck; tall `)))##(((` bands get a tall deck; hard vertical step between them.

## Non-goals

- Smooth / lerped deck height along Z (no blend ramp between bands).
- Auto-retargeting layered story `height` when TUNING `step_height` changes.
- Changing pipe/ramp loft math (run width → rise already works).
- Authoring-only workarounds (forcing separate `#` components) as the product solution.

## Approach

**Split at LevelLoader deck emit** (not a new sim mode):

1. For each connected `#` component, assign every deck cell an **abutting rise** from 4-neighbor `()` / `<>` runs on that layer.
2. Same row with conflicting left/right abutting rises → **hard compile error** (no silent `max`).
3. Group cells into contiguous Z-bands sharing one rise (same X footprint as today’s component).
4. Emit one `SupportPatch` deck per band: `height = layer.height + rise`, poly/cells for that band only.
5. Equal-rise continuous `#` remains a **single** patch (no extra seams).
6. Remove / replace the current “`max` + warning” path for unequal rises on one component.

**Step seam** wherever two Z-adjacent bands share X overlap and heights differ:

- Compile a **feature wall** on the tall band’s open Z face at the seam (same family as deck open-side / endcaps).
- **Tall → short:** open ledge — leave into free air / fall (deck ride-off corridor), not sticky mid-air mount onto the short pad unless ordinary descending deck-land gates already allow a legal land from above.
- **Short → tall:** riser contact → Reject + crash via existing deck / `feature_wall` crash path.
- Coping `outward_deck_id` / lip ownership per Z span points at the **band** abutting that span (short lip ↔ short `#`, tall ↔ tall).

Presentation and Godot collision consume the same compiled patches — one flat slab per band + vertical seam face; no special-case “roof at max height” mesh.

## Architecture

| Piece | Ownership |
|-------|-----------|
| `LevelLoader` deck emit | Cell→rise, Z-band split, deck dicts, seam wall descriptors |
| `IdlCompiler` | `SupportPatch` per band; coping spans link `outward_deck_id` to the correct band; feature wall solids for seams |
| `AirSolver` / `GroundSolver` / `CrashClassifier` | Reuse deck open-side + feature_wall crash; no new motion mode |
| Mesh / `level_collision_3d` | Follow patches + feature walls as today |
| Docs | `level_format.md` deck-height rules |

## Data flow

```text
# component cells
  → per-cell abutting rise (error if L/R conflict)
  → Z-bands by equal rise
  → SupportPatch per band + feature_wall at tall|short Z seam
  → coping spans outward_deck_id = band at that Z
  → sim contact + mesh
```

## Error handling

| Case | Result |
|------|--------|
| Deck cell with no pipe/ramp neighbor and no `deck_height` header | Existing error (unchanged) |
| Same row, left and right abutting rises disagree | Compile **error** naming layer/row |
| Header `deck_height` override | Still forces a single rise for that component (no Z split from neighbors); document as override |

## Tests

1. Fixture matching the short+tall spine above → two deck heights; short coping Z meets short deck top; no tall pad volume over the short pipe Z span.
2. Equal-rise continuous `#` → still one deck patch.
3. Same-row left/right unequal abutting rises → compile failure (parse/compile error).
4. Grounded tall→short across the seam → free air / fall, not sticky mount on the short pad.
5. Into the tall riser from the short side (grounded or free-air) → `falling`.

## Docs to update (implementation)

- `docs/level_format.md` — Z-banded deck height; hard step; L/R conflict error; note matching run widths only required **per Z band**, not for the whole `#` strip.
- Cross-link from gameplay deck / spine notes if they still say “must match both sides for the whole spine.”

## Self-review

- **Mount vs fall:** Tall→short is open leave; short→tall is crash wall — matches chosen skate policy.
- **One height per patch:** Keeps `SupportPatch.height` scalar; avoids height-at-z rewrites across solvers.
- **Coping ownership:** Per-span `outward_deck_id` must follow the band, or hang/air-out carve-outs will point at the wrong pad.
- **Scope:** One feature (compile split + seam wall + regressions); suitable for a single implementation plan.
