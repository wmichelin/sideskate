# Fall impact triggers + checkpoint recovery — Implementation Plan

> **For agentic workers:** Implement task-by-task. Steps use checkbox syntax.

**Goal:** Bail on level/deck/ramp-launch solids (and hang→flat) via `begin_fall()`; after every fall bout, soft-restore to floor/deck checkpoint.

**Architecture:** Solvers set `SimState.request_fall` on bail Reject/contain/hang-flat mount; `PlayerSim` calls `begin_fall()` after the step. Recovery calls shared `_restore_to_checkpoint()` (same history as lava `respawn()`, no death overlay).

**Tech Stack:** Godot 4 GDScript, analytical `PlayerSim` / `AirSolver` / `GroundSolver`, headless tests.

## Global Constraints

- Physics-tick only for gameplay.
- Peak-leave / intentional deck-back ride-off must not bail.
- Lava kill still wins over fall.

---

## Task 1: Flag + checkpoint restore helper

- [x] Add `SimState.request_fall`; clear in `clear_fall` / reset paths
- [x] Factor `PlayerSim._restore_to_checkpoint()` from `respawn()`; fall recovery + `respawn()` both use it
- [x] Skip `_note_checkpoint` while `falling`
- [x] After ground/air step, if `request_fall`: `begin_fall()`

## Task 2: Air + ground bail hooks

- [x] `AirSolver._contact_requests_fall` + set flag in `_reject_air_contact` / rim clamp
- [x] Hang: include deck in flat land; on hang→floor/deck mount set `request_fall` (not lava)
- [x] `GroundSolver._contain_ground_xz`: on bail-blocked fail / world rim set `request_fall`

## Task 3: Tests + docs

- [x] Impact / hang-flat / peak-leave negative / recovery-to-checkpoint tests
- [x] Update movement_contract + gameplay + fall mechanic recovery note
- [x] Run headless suite
