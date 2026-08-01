# Task 3 report: Orange rider + board meshes and apply_pose

## Summary

- Updated `LogicalPosePresenter3D` rider material to orange: `Color(1.0, 0.45, 0.08, 1.0)`.
- Added `@export var board_size: Vector3 = Vector3(0.40, 0.05, 0.14)`.
- Added presenter-root `Board` with `BoardNose` red half and `BoardTail` blue half using the plan's exact sizes and offsets.
- Updated `apply_pose` so riding visuals show the body and board, board yaw is `pose.board_yaw + pose.depth_turn_yaw`, board position is `Vector3(0, -board_size.y * 0.5, 0)`, and board scale stays `Vector3.ONE`.
- Kept the single `FallBox`; it reuses the rider material and hides the board while the active fall box is shown.
- Included untracked `scripts/rendering_3d/board_yaw_tracker.gd.uid` per repository convention.

## TDD evidence

1. RED test edit:
   - Added orange rider material assertion.
   - Added Board existence, board yaw, and no board facing-scale-flip assertions in `_centered_y_turn_presentation()`.
2. RED run:
   - Command requested in brief, `godot4 --headless --path . --script res://tests/test_runner.gd`, could not start because `godot4` is not on PATH.
   - Used installed equivalent `/Applications/Godot.app/Contents/MacOS/Godot`.
   - Expected failure observed: `rider must be orange placeholder`; suite result `14 passed, 1 failed`.
3. GREEN implementation:
   - Implemented only the presenter mesh/material and `apply_pose` board path from Task 3.
4. GREEN run:
   - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/test_runner.gd`
   - Result: `=== 15 passed, 0 failed ===`, exit code 0.

## Self-review

- Scope check: did not wire `BoardYawTracker` into `player.gd`; did not split or rename `FallBox`; left unrelated `levels/offset_demo.ssk` untracked.
- Presenter check: board is a separate root child from the body, so body facing scale does not flip the board.
- Values check: board size, nose/tail offsets, and material colors match the task brief.
- Test check: presentation assertions cover orange material, Board creation, independent board yaw, and no facing-scale flip.

## Concerns

- The environment lacks a `godot4` PATH shim, so verification used `/Applications/Godot.app/Contents/MacOS/Godot` (Godot `4.7.1.stable`) instead.
- The suite still prints existing warnings/expected negative-parse errors and exit-time leak/resource messages, but exits 0 after this change.
