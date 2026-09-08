# SideSkate deep review and conformance plan

## Baseline

User direction: review deeply, install the engineering philosophy, plan and execute
the justified improvements, test changes, and commit/push each validated milestone.
That direction authorizes the reversible work below without another approval round.

- Application baseline: `b43c74b811d5108461a3ff92e8d17b600cf834ef`; clean `main`.
- Rules installation: `ee37592`, canonical source
  `wmichelin/agent-skills@a0e2141a435295a4eb9a04462341b7e21fb3d9e7`.
  `ENGINEERING_PHILOSOPHY.md` is authoritative for general engineering;
  explicit user direction, `AGENTS.md`, and the frozen movement contract take
  precedence. Go-specific package/interface prescriptions do not mandate a
  GDScript architecture rewrite.
- New files: engineering philosophy, Claude/Cursor/Copilot adapters. Modified:
  existing Codex `AGENTS.md`, preserving its project rules. All adapter links
  resolve to the root document; no conflicting existing adapters were found.
- Fresh `./tools/check.sh all --out artifacts/checks/review-2026-09-07/baseline
  --timeout 240`: 178 tests, 179 real-input gameplay checks, 13 recording replays,
  and all five render gates pass. `python3 -m unittest discover -s tools/tests -v`:
  nine pass. Fresh local Web baseline: 32 browser checks and 14 package checks
  pass in 110 seconds; this does not establish hosted-runner performance.
- Hosted baseline [run 34174786568](https://github.com/wmichelin/sideskate/actions/runs/34174786568):
  native and replay pass; Web times out after 27 passing checks, before completing
  the touch scenario. Downloaded Web evidence establishes the failure phase.
- Pinned Godot 4.7, Python 3.11+, Playwright 1.55.1/Chromium; native Forward+ and
  Compatibility rendering, release Web Compatibility. No dependency upgrade is
  necessary for the confirmed findings.

Architecture: `project.godot` starts `scenes/start_menu.tscn`; `GameSession` routes
to `scenes/main.tscn`. `RampLevel` compiles `.ssk` into `ParkModel`; `PlayerSim`
owns gameplay, solvers consume compiled surfaces, and player/presenter/camera
consume snapshots. Shared compiled geometry supplies visuals and non-authoritative
Godot collision. Test tools import classes, supervise native/browser processes,
check completed reports, replay events, and audit release packages.

Root inventory is metadata/documentation only: `.gitignore`, `AGENTS.md`,
`CLAUDE.md`, `ENGINEERING_PHILOSOPHY.md`, `README.md`, `project.godot`, `icon.svg`
and its import metadata. Application source already lives under `scripts/`, with
simulation/model, rendering, mesh, physics and UI ownership. Large solver/test
files deserve caution, but size alone is not a defect. No directory moves proposed.

Review criteria use engine-specific guidance rather than a claim of universal
game-industry certification:

- Keep fixed simulation ticks independent from rendered frames, and interpolate
  presentation deliberately. [Godot physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)
- Check event routing, UI consumption and input ownership across pause and device
  transitions. [Godot InputEvent](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html)
- Measure slow paths before changing algorithms or quality settings; hosted
  software rendering is a different performance environment from the server GPU.
  [Godot optimization guidance](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html)
- Verify the actual browser export and its assets, including touch behavior, with
  the supported renderer. [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)

## Findings

Line references describe the baseline and may move as fixes land.

| ID | Observation and evidence | Impact / principle / confidence |
| --- | --- | --- |
| F1 | `tools/check.py:web:251` gives the browser and its supervisor equal deadlines; `tools/browser/smoke.mjs:snapshot:110` repeatedly captures the canvas through element screenshots. Hosted desktop checks take 205.8 seconds, touch controls pass at 219.2 seconds, then the 240-second deadline closes the browser during capture. | P1 verification reliability: incomplete touch coverage and misleading shutdown failure; observable failures and measured performance. High confidence from hosted artifacts. |
| F2 | `scripts/death_overlay.gd:play:54` uses a default idle/process-always timer. Its signal calls `scripts/player.gd:_on_death_finished:414`, which respawns immediately. An unchanged full-scene probe paused during death: `alive=true`, complete gameplay hash changed while paused; callback was outside physics. | P1 gameplay/pause correctness; violates frozen fixed-tick authority. High confidence from actual scene reproduction. |
| F3 | `scripts/touch_controls.gd:_refresh_visibility:146` hides controls on pause without cancelling held stick actions; hidden release is ignored. `_hide_for_joypad:153` permanently disables later touch. Full-scene pause probe retains `move_right` after release; subsequent screen touch cannot restore controls after gamepad use. | P1/P2 mobile input lifecycle: unintended movement and inability to switch controls. Clear ownership and intentional lifecycle behavior. High confidence. |
| F4 | `scripts/sim/surface_query.gd:_append_support_top_crossings:1061` samples support at a substep endpoint but emits an earlier crossing without verifying that point's footprint. `scripts/sim/air_solver.gd:_mount_support_top:859` seats pre-contact XZ. On valid rows `..@=== / ..==== / ..====`, an airborne step from `(91,70,0.1)` at `(360,0,-34.333333)` grounds at X=91.48545 on a floor beginning X=94. | P1 contact ownership: landing beside a platform or inside a hole, silently violating geometry. Single source of truth and behavioral boundary coverage. High confidence from public `PlayerSim.tick`. |
| F5 | `scripts/sim/idl_compiler.gd:_classify_copings:315` splits at patch Z bounds but misses interior outline occupancy changes. Lower five rows `=====)))====`, upper height 200 with rows `...........= / ...........= / ........==== / ...........= / ...........=` compile a wall for the whole span although the upper floor abuts only the middle row. Public sweep hits a phantom wall at `(376,23.5,160)`; inverse U shape misses real end walls. | P1 compiled topology: invisible blockers and missing authored wall segments. Exact support footprints and explicit local topology. High confidence from valid `.ssk` compilation and sweep. |
| F6 | `tools/check.py:export_web:207` deletes only old HTML and reuses JS/WASM/PCK. A boundary test with seeded stale files and an exporter writing only HTML passes; obsolete files survive normal export and `deploy_prod.sh` uploads the directory. | P2 release correctness: mixed/stale packages and accidental obsolete-file publishing. Validate fresh outputs before promotion. High confidence from isolated exporter reproduction. |
| F7 | `scripts/sim/player_sim.gd:apply_tuning:959` and `restore_snapshot:1001` check shape but accept nonfinite values. Unchanged public probes return true for NaN position and NaN global gravity, copying both into live state. | P2 replay boundary: malformed diagnostic data corrupts simulation/global tuning. Validate before mutation. High confidence; preserve legitimate `air_peak_height=-INF` sentinel. |
| F8 | `scripts/player.gd:motion_world:578` scales INPUT depth by X speed and treats grounded along speed as world X with zero height. `logical_pose_presenter_3d.gd:443` uses ACTUAL to seed falling rider/board velocity. | P2 presentation correctness: wrong depth magnitude and slope launch direction. Explicit coordinate contracts and one analytical source. High confidence for axis-scale error; slope fix must be checked against actual solver derivatives, including elliptical surfaces. |

## Ordered work items

Each work item is a separate validated commit, integrated and pushed by the lead.
Rollback is `git revert` of its commit; generated evidence remains local/ignored.
No work item changes level/save format, retunes skating, replaces the character,
changes input bindings, moves packages, or publishes the game.

### W1 — Complete browser verification on slower runners (F1)

- Owner: tooling agent. Paths: `tools/check.py`, `tools/browser/smoke.mjs`,
  focused `tools/tests/` coverage; workflow deadline only if evidence warrants it.
- Measure capture cost; use a real rendered-frame capture without unnecessary
  element stability waits. Give internal workload timeout and bounded outer
  cleanup/report grace distinct budgets. Keep failures failures and all assertions.
- Acceptance: all 32 browser checks complete; deliberately short timeout writes
  an explicit failure report and supervision still terminates hangs. No game-state
  injection or reduced render quality to manufacture a passing result.
- Validate tooling unit tests, real `check.sh web`, and hosted Web CI.
- Risk low/gameplay none. Independent from W2/W4; W6 follows on the same files.

### W2 — Move death recovery to pausable physics (F2)

- Owner: runtime agent. Paths: `scripts/player.gd`, `scripts/death_overlay.gd`,
  relevant `tests/runtime/` regression scenario and focused lifecycle tests.
- Advance recovery on the fixed physics path; make overlay display state rather
  than own the simulation transition. Preserve the existing hold duration,
  checkpoint semantics, and explicit replayable respawn event.
- Acceptance: actual lava death + actual pause remains dead with identical full
  gameplay hash beyond the hold duration; resuming causes exactly one respawn on
  physics ticks. Exiting during death leaves no callback acting on a new scene.
- Validate full imported tests, new runtime scenario, all maneuver stories, and
  final 30/60/120 FPS checkpoint comparison.
- Risk moderate: recovery ordering. No tuning/trajectory changes. W3 follows in
  this worktree; W7 uses different simulation implementation files.

### W3 — Cancel and restore touch input correctly (F3)

- Owner: runtime agent. Paths: `scripts/touch_controls.gd`, focused touch tests,
  runtime scenarios if necessary (same owner as W2).
- Cancel overlay-owned stick/button holds when paused, hidden, focus is lost,
  or the scene exits. Ignore new presses while inactive. Restore virtual controls
  after deliberate screen touch following gamepad use; keep the noise guard.
- Acceptance: held stick/action -> pause -> finger release -> resume is neutral;
  fresh touch works; gamepad -> touch switching works. Cancellation preserves
  unrelated keyboard/gamepad inputs. Include scene teardown and focus-loss cases.
- Validate focused InputMap lifecycle tests, full tests, real pause/menu/reload,
  and final release touch smoke. Risk moderate at shared InputMap ownership.

### W4 — Land only at valid support crossings (F4)

- Owner: simulation agent. Paths: `scripts/sim/surface_query.gd`,
  `scripts/sim/air_solver.gd`, a new focused contact regression suite/fixtures.
- Validate interpolated contact XZ against the selected support and seat at the
  valid contact point. Preserve existing contact priority, copings, hang remount,
  and deck minimum-height gates. Avoid a broad contact solver rewrite.
- Acceptance: reproduced edge/hole landing cannot acquire an absent owner;
  legitimate descending contacts still land; high-speed/lateral cases and slopes
  exercise the public sim/query boundaries with no unexpected diagnostics.
- Validate focused suite, full tests, all maneuver gameplay/replays. Risk moderate
  because contact timing changes at defective boundaries. W5 follows separately.

### W5 — Split coping classification at real occupancy changes (F5)

- Owner: simulation agent. Paths: `scripts/sim/idl_compiler.gd`, new compiler
  regression tests/fixtures, without concurrent edits to W4 files.
- Include relevant outline and hole Z breakpoints when classifying adjacent
  support, then retain existing merge of equivalent neighboring spans.
- Acceptance: connected T/L/U floor footprints create walls/seams only where
  actual outward support exists, including mirrored sides and holes; public
  queries reject phantom contacts and detect real walls. Existing story seams
  and model determinism remain covered.
- Validate targeted compiler/query tests, full suite, gameplay and five renders.
- Risk moderate: newly correct compiled spans change model hashes for affected
  maps. Existing recordings for changed geometry should reject model mismatch;
  no attempt to reinterpret them. Fresh runtime recordings must replay.

### W6 — Publish local exports only after fresh validation (F6)

- Owner: tooling agent, after W1. Paths: `tools/check.py`, focused exporter tests.
- Export into a fresh sibling staging directory, require fresh complete outputs,
  audit its PCK, then promote to the existing `build/html5/` interface. Preserve
  the prior successful build and user export preset on any failure; clean only
  temporary directories created by this run. No `deploy_prod.sh` publishing.
- Acceptance: stale/obsolete files cannot survive promotion, partial exports
  fail, audit failures leave the previous build intact, success replaces it.
- Validate mocked external exporter failure cases and real export/Web checks.
- Risk low to gameplay, moderate to local build promotion/error recovery.

### W7 — Reject nonfinite snapshot/replay values before mutation (F7)

- Owner: lead. Paths: `scripts/sim/sim_snapshot.gd`, `player_sim.gd`,
  `sim_trace.gd`, focused snapshot/replay regression tests.
- Add numeric boundary validation for snapshot state, checkpoint history, input,
  tuning and maneuver values. Permit only the documented negative-infinity
  air-peak sentinel. Reject malformed snapshots before changing live state or
  globals; validate replay event input/tuning before applying that event.
- Acceptance: NaN/+INF/-INF in prohibited fields is rejected with a useful replay
  error; rejected restoration changes neither gameplay state nor global tuning;
  valid snapshots and the sentinel round-trip, and normal replays remain exact.
- Do not impose speculative tuning ranges or change the serialization version.
- Validate focused malformed-data tests, full suite, real recording replay,
  and final render-rate checkpoints. Risk moderate: typed data/sentinel coverage.

### W8 — Report and seed correct world motion (F8)

- Owner: runtime agent, after W2/W3. Paths: `scripts/player.gd`,
  `tests/test_motion_vectors.gd`; a small analytical reader only if required,
  coordinated with the lead before crossing into W7's files.
- INPUT uses per-axis maxima. Grounded world velocity derives from the actual
  surface law (including its current elliptical derivative), with correct left/
  right sign and vertical component; grind and free air retain their paths.
- Acceptance: flat, left/right ramp/pipe, wall, grind and air vectors match their
  documented coordinate units; actual measured movement validates the derivative.
  Falling rider/board launches in the corresponding visible direction.
- Validate motion tests, full tests, a real fall render, all five visual gates,
  and unchanged gameplay checkpoints. Preserve the current grounded ellipse law.
- Risk moderate/presentation only. No change to simulation velocity integration.

## Execution topology

Lead `/root` owns plan, integration review, W7, documentation and final acceptance.
Agents use isolated worktrees; shared generated Godot imports, builds and evidence
must never be mutated concurrently. No agent pushes or merges the main branch.

- Tooling worktree: W1 then W6, each reviewed commit delivered separately.
- Runtime worktree: W2 then W3 then W8, distinct validated commits.
- Simulation worktree: W4 then W5, distinct validated commits.
- Lead W7 uses separate files; cross-boundary additions require coordination.
- Integrate in listed W1–W8 order. Review each diff before cherry-pick; rerun the
  focused checks against integrated main, then commit/push before the next item.
- Final: imported full tests, all actual-input stories, replay at 30/60/120 FPS,
  five Forward+ render gates inspected, local Web export/package/browser checks,
  tooling failure tests and latest hosted CI. Compare delivered work to every
  item; document residual limits rather than claiming complete certification.

## Approval gates and open questions

No unresolved approval gates for W1–W8: the user explicitly authorized planning,
implementation, testing, commits and pushes. No production publishing, destructive
migration or unrelated infrastructure changes are included.

Deferred findings/questions, intentionally outside implementation scope:

- Grounded elliptical pipe integration uses the historical circular angular law;
  fixing physical arc-length/gravity would change skating feel and seam timing.
  Preserve it here and record the discrepancy, as in `docs/verification_delivery.md`.
- A midpoint-based wall sweep may mishandle X-varying walls, but the review has
  not established such a wall through the current supported compiler. Do not
  change collision code on an unproven authored path.
- Live rail-thickness debug tuning updates analytical collision before a remesh.
  This is documented behavior; a safe geometry-only refresh remains future work.
- Physical-phone/controller testing and Safari/Firefox are not established by
  Chromium touch emulation. Server screenshots do not establish device frame
  budgets. Profile real target devices before graphics/performance redesign.
- No broad directory reshuffle, solver replacement, dependency upgrades or removal
  of legacy assets merely because they appear old; compatibility evidence is
  required before such work.
