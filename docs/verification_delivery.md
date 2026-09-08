# Verification delivery — 2026-09-07

Implemented assessment work items W1–W9 in the working tree based on
`7866a04b681832198a6984f76a4f7c6854183f01`. No build was published. The GitHub
workflow is configured; its commands were run locally, not on hosted Actions.

The reusable entry points are documented in [README](../README.md):

```bash
./tools/check.sh setup
./tools/check.sh all
./tools/check.sh replay
./tools/check.sh web
```

Web checks additionally require `setup --web`, `npm ci --prefix tools/browser`,
and `npm run --prefix tools/browser install-browser` once. Reports, logs,
screenshots and recordings are generated under `artifacts/checks/` and ignored
by Git. This delivery's evidence is under `artifacts/checks/final/`, with fresh
checkout failure checks under `artifacts/checks/runner-contract-final/`.

## Delivered behavior

- **W1:** pinned Godot setup, initial import, bounded process supervision,
  completed reports, named cases and explicit expected diagnostics. A successful
  engine exit alone cannot pass. Descendants are stopped, and partial report
  writes are detected even when Godot reports `OK`. Fixed test node/resource leaks.
- **W2:** actual scene-tree keyboard/gamepad input on physics ticks, all maneuver
  stories, normal camera follow, real pause/Controls/menu/reload, debug-off checks,
  screenshots and streamed recordings. Camera validation compares the rendered
  focus with both the displayed player and simulation pose.
- **W3–W4:** complete versioned gameplay/model identity and exact typed snapshot
  transport with a checksum. Replay includes input edges/holds, tuning, external
  fall/respawn and pending input at recording stop. Ordinary debug history retains
  180 frames; release/debug-off retains none. Full recording is explicit.
- **W5–W6:** preserved signed grind momentum on balance failure; restored falls
  when grounded axis slides hit walls; classified permitted rising wall corridors
  correctly; required the ramp regression to land on its named deck. Non-finite
  motion and invalid ownership fail verification. Corrected pipe landing tangent
  math and retained the incoming side during stacked-joint crashes.
- **W7:** one compiled model and shared triangle set now feed player, visuals,
  collision and debug geometry. Floor/deck holes and concave lava remain exact.
  Tests inspect actual rendered normals, elevations, owners and triangle sets;
  deliberately displaced geometry fails. Corrected winding and hard-edge shading.
- **W8–W9:** local release export/package audit/Chromium smoke, native/replay/Web
  CI jobs with evidence uploads, separate longer soak checks, and reconciled
  movement/level-format/presentation documentation.

## Validation

Engine: `4.7.stable.official.5b4e0cb0f`, Linux X11 at 1280×720, fixed 60 Hz physics.
Native checks used both Forward+ on NVIDIA RTX 2060 and software OpenGL
Compatibility on llvmpipe. Web used Playwright 1.55.1 and Chromium
`140.0.7339.186` with software rendering.

| Check | Result | Evidence |
| --- | --- | --- |
| Full headless suite | 174 checks across 24 suites; no unexpected diagnostics | `final/tests/report.json` |
| Actual native gameplay | 151 checks, including all eight maneuver/fall stories and menus | `final/gameplay/plaza_default/spawn/report.json` |
| Render-rate independence | All 15 complete checkpoints equal at 30/60/120 FPS | `final/replay/report.json` |
| Reconstruct actual gameplay recordings | All 12 sessions replay at each render rate | `final/replay/{30,60,120}/plaza_default/spawn/replay.json` |
| Required render gates | All five maps pass; captures inspected | `final/render/` |
| Release browser | 32 checks; both playable maps, keyboard, pause, resize, touch; no runtime/network errors | `final/web/report.json` |
| Release package | Shipped maps/fonts/skater included; tests/tools/debug maps excluded | `final/web/package.json` |
| Trace soak | Stationary and moving runs of 36,000 ticks each; 180 retained frames; zero growth after warmup | `final/soak/tests/engine.log` |
| Debug-off soak | Same runs; zero retained frames and zero growth after warmup | `final/soak-debug-off/tests/engine.log` |
| Fresh checkout and deliberate failures | 10 cases: fresh success; parse/runtime/assertion/false/empty-suite/abort/hang/empty-selection/missing-engine failures | `runner-contract-final/report.json` |
| Broken native camera/input/pause | Each mutation fails its specific check | `final/runtime-contract/report.json` |
| Missing Web package | HTTP 404/asset load failure makes browser check fail | `final/web-missing-asset/report.json` |
| Launcher/resolver regressions | 9 Python tests pass; covers child cleanup and incompatible PATH engine | `python3 -m unittest discover -s tools/tests -v` |

Memory figures use Godot static allocation, not total process RSS. The debug ring
allocated about 12.3 MB during warmup; the debug-off checkpoint history allocated
about 55 KB. Neither continued growing through tick 36,000. Startup FPS labels in
spawn screenshots are not performance measurements.

## New follow-ups outside the approved fixes

1. **Grounded elliptical pipe integration (P1).**
   [GroundSolver](../scripts/sim/ground_solver.gd) still uses
   `gravity * sin(theta)` and `along * delta / radius`. With radius 141, rise 120,
   and theta π/4, a stored speed of 300 produces an instantaneous arc speed of
   approximately 278.56. The actual ellipse metric is 130.9217, so preserving
   physical along-speed would require a different angular step and gravity
   projection. Address travel, gravity and seam remainder together, retaining
   circular compatibility and recording the resulting movement changes. This
   delivery changes landing projection; it preserves the existing grounded law.
2. **Live rail-thickness presentation refresh (P2).** The existing debug slider
   changes analytical blockers immediately; visual/collision meshes update on
   reload, as documented. A later geometry-only refresh can remove that gap
   without rebooting the simulation.
3. **Physical devices and other browsers.** Synthetic gamepad and Chromium touch
   checks establish automation coverage. Physical controllers/phones, Safari and
   Firefox remain unverified.
