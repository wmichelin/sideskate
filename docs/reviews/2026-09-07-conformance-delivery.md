# SideSkate review delivery

Implemented all eight work items in the [review plan](2026-09-07-conformance-plan.md).
Application changes run from baseline `b43c74b` through `717d07a`. Each milestone
was reviewed, validated, committed and pushed separately. The lead integrated
isolated tooling, runtime and simulation worktrees; independent reviewers checked
the combined changes and the analytical motion formulas.

The canonical engineering philosophy is installed at the repository root, pinned
to `wmichelin/agent-skills@a0e2141a435295a4eb9a04462341b7e21fb3d9e7`, with thin
Codex, Claude, Cursor and Copilot adapters. Existing Godot and movement contracts
retain precedence. The review found no reason for a directory reorganization or
a change to the gameplay/presentation ownership boundary.

## Delivered behavior

| Work | Fix and regression evidence | Main commits |
| --- | --- | --- |
| W1 | Browser checks capture rendered canvas frames, report capture cost, and retain time to write timeout evidence before process cleanup. A deliberate short timeout fails truthfully. Hosted software rendering needed about 270 seconds, so its workload budget is now 360 seconds with all assertions retained. | `ecefa6c`, `452143c` |
| W2 | Lava recovery advances only on pausable physics ticks. Real-input checks pause beyond the death hold, verify an unchanged complete sim hash, resume to exactly one physics recovery, and exit/reload during death. Visual inspection also caught and fixed the pause menu appearing below the death overlay. | `ba1ff2b`, `726ea71` |
| W3 | Touch holds cancel on pause, hiding, focus loss and scene exit. Fresh touch restores controls after gamepad use. Virtual input has separate device ownership so cancellation preserves physical keyboard/gamepad holds. Five lifecycle regressions fail before the fix and pass afterward. | `9ef33d1` |
| W4 | Swept support contacts must lie inside their selected footprint; successful landings consume the validated crossing position. Edge and hole reproductions no longer land beside a floor, while legitimate floor/pipe/ramp contacts remain valid. | `ea54b7e` |
| W5 | Coping classification splits at relevant outline and hole boundaries. Connected T/U floors, mirrored sides and holes produce actual walls and seams, avoiding phantom blockers. All 12 existing playable/debug map model hashes remain unchanged. | `55838ba` |
| W6 | Web exports are built in fresh staging, checked for complete nonempty outputs and audited before replacing `build/html5`. Export/audit failures preserve the previous build and user preset; promotion failure restores the previous build, or preserves its backup with a recovery path if rollback also fails. Obsolete files cannot survive successful promotion. | `be5907b` |
| W7 | Snapshot, tuning and replay boundaries reject prohibited NaN/infinity before applying malformed data. The documented negative-infinity air-peak sentinel still round-trips. Regression checks cover live state/global-tuning preservation and invalid replay commands. Serialization remains version 1. | `be7ee99` |
| W8 | World motion uses the correct depth limit, signed slope/vertical derivatives and rail velocity. Read-only vector checks compare actual tick movement on flat, pipe, ramp, wall, rail and air paths, including elliptical/lofted surfaces. Seven cases fail against the old reader. A real left-pipe fall verifies both visual bodies launch upward in the corresponding world direction. | `717d07a` |

W8 preserves the existing elliptical angular integration law. Independent review
caught a test depth input below the deadzone; the corrected test now asserts
nonzero measured depth motion. Simulation solvers remain the gameplay authority.
The current humanoid, board, animation assets and input bindings are preserved.

## Validation

Final integrated code: `717d07a523b43d4dd8e1fdef64a4475d731ab399`.
Local evidence is retained under `artifacts/checks/review-2026-09-07/`; generated
builds, screenshots, recordings and temporary reports are ignored by Git.

| Gate | Result | Evidence directory beneath the review output |
| --- | --- | --- |
| `./tools/check.sh all --renderer forward_plus --timeout 240` | 204 imported test cases; 204 real-input gameplay checks; 15 recordings replayed; five render gates, eight checks each. | `final/tests`, `final/gameplay`, `final/render` |
| `./tools/check.sh replay --timeout 240` | All 15 complete gameplay checkpoints agree at 30, 60 and 120 FPS; each run passes 204 gameplay checks and replays 15 recordings. | `final/replay` |
| `./tools/check.sh web --timeout 360` | Fresh release export; 14 package checks; 32 Chromium desktop/touch checks; zero errors. Browser report completes in 93.7 seconds locally. | `final/web` |
| `python3 -m unittest discover -s tools/tests -q` | 16 pass, including supervisor deadlines, stale reports, incomplete exports, audit failures and rollback failures. | Reproducible command; W6 focused evidence in `w6` and `agent-evidence/w6` |
| `python3 tools/verification/runner_contract.py` | All 10 expected outcomes pass, including parse/runtime/assertion errors, abort with stale report, empty suites, hangs and missing engine. | `runner-contract` |
| `./tools/check.sh tests --test test_sim_replay.gd --sim-soak` and the same with `--no-debug-tools` | Each mode passes 36,000 idle and 36,000 moving ticks. Zero measured growth after warmup and in the second half; debug history stays at 180 frames, disabled history at zero. | `soak`, `soak-debug-off` |

The five required Forward+ screenshots were inspected: `plaza_default`,
`spine_demo`, `layered_demo`, `variable_height_ramps`, `plaza_default_deep`.
The actual paused-death screen and left-pipe fall capture were inspected as well.
Normal follow-camera and actual input paths remain active throughout the stories.
Startup FPS labels in spawn captures are not performance measurements.

Fourteen of the baseline's 15 named gameplay checkpoints are exactly unchanged.
The changed `lava_respawn` checkpoint corresponds to the intentional recovery
timing/scenario correction and is deterministic across all three render rates.
W8 alone leaves all 15 pre-W8 checkpoint hashes unchanged.

Hosted [W1 acceptance run 34180927137](https://github.com/wmichelin/sideskate/actions/runs/34180927137)
passes native, replay and Web. Its browser report contains 32 passing checks,
zero errors and 33 captures, taking 269.7 seconds; all saved images have the
expected dimensions. Evidence is copied into `hosted-w1/`.
Final application CI: [run 34181272628](https://github.com/wmichelin/sideskate/actions/runs/34181272628)
passes all three jobs: native, replay and Web.

## Remaining limits and tradeoffs

- The historical elliptical grounded integration remains intentionally unchanged;
  replacing it with physical arc-length integration would alter skating feel and
  seam timing and needs a separate design decision.
- Chromium touch emulation does not establish behavior or frame budgets on a
  physical phone/controller, Safari or Firefox. Target-device profiling remains
  necessary before performance or graphics redesign.
- The suspected varying-X wall path was not reproduced through the supported
  compiler. Live rail-thickness tuning still needs the documented geometry reload.
  Neither justified a speculative collision/remeshing rewrite in this review.
- Current authored runs use constant profiles. Motion tests additionally exercise
  sampled loft laws; changes to derivative direction exactly at future authored
  profile knots are not established by this coverage.
- This establishes the listed behavioral gates, not universal game-industry
  certification or a proof that all possible defects have been eliminated.

Every implementation commit has an individual `git revert` rollback path. No
production game publishing or persisted-format migration was performed.
