# Z-Banded Deck Height Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split connected `#` strips into flat deck patches per Z-band of abutting pipe/ramp rise so short/tall copings meet matching decks with a hard open-ledge step.

**Architecture:** LevelLoader assigns each deck-component grid row an abutting rise, groups contiguous equal-rise rows into bands, and emits one deck dict per band. Existing `_deck_feature_wall` supplies the tall riser; tall→short leave uses existing open-side / ride-off. IdlCompiler unchanged aside from consuming multiple decks.

**Tech Stack:** Godot 4 GDScript, headless `tests/test_runner.gd`, `.ssk` fixtures under `tests/levels/`.

## Global Constraints

- Hard step only (no Z blend).
- Same-row left/right unequal abutting rises → compile **error**.
- Header `deck_height` → single rise for the whole component (no Z split).
- Equal-rise continuous `#` → still one patch.
- Analytical sim + mesh consume the same patches; no parallel height logic in presenters.

---

### Task 1: Failing loader tests + fixture

**Files:**
- Create: `tests/levels/sim/sim_z_band_deck.ssk`
- Modify: `tests/test_level_loader.gd`
- Modify: `docs/level_format.md` (with Task 2 or end)

**Interfaces:**
- Consumes: `LevelLoader.parse_text`, `LevelLoader.DEFAULT_STEP_HEIGHT`
- Produces: fixture + assertions for two deck heights / L-R conflict error

- [x] **Step 1: Add fixture** `sim_z_band_deck.ssk` (short `)##(` rows then tall `)))##(((` rows; spawn on floor).
- [x] **Step 2: Failing tests** — two deck heights (`1×` and `3×` step_height); equal-rise spine still one height; L/R conflict map errors.
- [x] **Step 3: Run** `godot4 --headless --path . --script res://tests/test_runner.gd` — expect FAIL on new asserts.
- [x] **Step 4: Commit** fixture + failing tests.

### Task 2: LevelLoader Z-band split

**Files:**
- Modify: `scripts/level_loader.gd` (deck emit loop ~416–454)
- Modify: `docs/level_format.md`

**Interfaces:**
- Consumes: `_deck_neighbor_pipes`, `_outline_poly`, `_components`, pipe dicts with `rise` / `z_min` / `z_max`
- Produces: multiple `spec.decks` entries per former component when rises differ by Z

- [x] **Step 1: Implement** per-row abutting rise, band split, emit one deck per band; error on L/R conflict; `deck_height` override keeps single patch.
- [x] **Step 2: Run tests** — loader tests PASS.
- [x] **Step 3: Commit**.

### Task 3: Runtime seam + sim regressions

**Files:**
- Modify: `tests/sim/test_sim_runtime.gd`
- Possibly no solver changes if feature walls already cover riser / open leave

- [x] **Step 1: Tests** — remount short pipe under short deck (no tall roof crash); tall→short leave free-air/fall; short→tall riser falls.
- [x] **Step 2: Fix solvers only if tests fail** (prefer existing deck open side / feature_wall).
- [x] **Step 3: Full suite green + commit**.

---

## Spec coverage

| Spec requirement | Task |
|------------------|------|
| Z-band split by abutting rise | 2 |
| L/R conflict error | 1–2 |
| Hard step / open ledge / riser crash | 3 (walls from split) |
| Equal-rise single patch | 1–2 |
| `deck_height` override | 2 |
| Docs | 2 |
| Fixture like user map | 1 |
