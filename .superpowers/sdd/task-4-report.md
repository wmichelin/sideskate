# Task 4 Report: Wire BoardYawTracker in player.gd

## Status

DONE_WITH_CONCERNS

## Changes

- Added player pose snapshot coverage for `board_yaw` first-capture snap, apex yaw deltas, fall-end snap, restore force snap, and depth-turn isolation.
- Wired `BoardYawTracker` into `scripts/player.gd` pose snapshots.
- Added `_was_falling_board` edge tracking using `SimState.falling`.
- Added a one-shot `_board_force_snap` path for respawn/restore snapshots so stale apex yaw does not leak into the snapped board yaw.

## TDD / Verification

- RED 1: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`
  - Failed as expected: `player board_yaw must track apex yaw delta, got 0.0`.
- RED 2: same command
  - Failed as expected before the one-shot restore flag existed: invalid assignment to `_board_force_snap`.
- GREEN: same command
  - Exit 0; `=== 15 passed, 0 failed ===`.
- `git diff --check`
  - Exit 0.

## Self-review

- Confirmed `player.gd` remains a fixed-physics pose publisher; no render/idle simulation changes.
- Confirmed `depth_turn_yaw` remains separate from stored `board_yaw`.
- Confirmed respawn/restore uses the tracker's force-snap path instead of a bare `snap_to_facing()` call that can leave stale `_prev_facing_yaw`.
- Did not split FallBox or start Task 5.

## Concerns

- The full suite exits 0, but existing tests emit expected diagnostic `push_error`/warning output and leak/resource warnings at process exit.
- Pre-existing untracked file left untouched: `levels/offset_demo.ssk`.
