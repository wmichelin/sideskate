# Hold-to-Auto-Transfer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Holding transfer auto-accepts spine/acid once eligible after a debug-tunable delay; tap still fires immediately.

**Architecture:** `PlayerSim` owns an eligible-time accumulator on the fixed physics tick. Tap uses `action_just`; hold fires when `transfer_hold_eligible >= transfer_hold_delay`. Shell only syncs the delay export and already forwards `action_down`.

**Tech Stack:** Godot 4 GDScript, headless `tests/sim/test_sim_runtime.gd`, debug sliders.

## Global Constraints

- Sim authority only — no presentation-fired transfers.
- Physics ticks only for arm/fire.
- Same `TRANSFER` path for spine and acid.
- Default delay **0.08** s; slider ~0–0.5 s.
- Tap immediate even when delay is large.

---

### Task 1: Failing hold/tap tests

**Files:**
- Modify: `tests/sim/test_sim_runtime.gd`
- Fixture: `tests/levels/sim/sim_spine_transfer_speed.ssk` (exists)

**Interfaces:**
- Consumes: `PlayerSim.set_input(wish, action_down, action_edge, …)`, `transfer_hold_delay`
- Produces: `_transfer_hold_delay_zero_auto()`, `_transfer_hold_waits_delay()`, `_transfer_tap_ignores_hold_delay()` wired in `run()`

- [x] **Step 1:** Write three tests per spec (hold delay 0; hold waits delay; tap with large delay).
- [x] **Step 2:** Run them red (hold path not wired yet).

### Task 2: Sim hold arm + accept path

**Files:**
- Modify: `scripts/sim/player_sim.gd`

**Interfaces:**
- Produces: `action_held: bool`, `transfer_hold_delay: float`, `transfer_hold_eligible: float`, `_update_transfer_hold(delta)`, fire in `_try_actions`

- [x] **Step 1:** Wire `action_held` in `set_input`; clear on fall.
- [x] **Step 2:** Accumulate eligible time; fire on just OR elapsed delay; reset on accept / ineligible.
- [x] **Step 3:** Tests green.

### Task 3: Player export + debug slider + docs

**Files:**
- Modify: `scripts/player.gd`, `scripts/debug_sliders.gd`, `docs/gameplay.md`
- Spec status: `docs/superpowers/specs/2026-08-01-hold-transfer-auto-design.md`

- [x] **Step 1:** `@export var transfer_hold_delay` default 0.08; sync to sim.
- [x] **Step 2:** Debug slider row (0–0.5).
- [x] **Step 3:** Docs + full `test_runner.gd` green.
- [x] **Step 4:** Commit.
