class_name SimTolerances
extends RefCounted
## Centralized logical epsilons — no local magic numbers in solvers.
## See docs/movement_contract.md.
## Tunables are static vars so debug TUNING can adjust them at runtime.

const CONTACT_EPS := 1.5
const SEAM_EPS := 0.75
const ALIGN_EPS := 2.0
const MAX_EDGE_CROSSINGS := 8
const CAPSULE_RADIUS := 9.0
## Wall / joint Reject clearance — ≥ half presentation body (0.18m) so the fall
## box and camera do not spawn inside the crash face.
const WALL_REJECT_CLEAR := CAPSULE_RADIUS * 2.0
## Height band under a pipe peak that counts as a tip/top skim (eject outside).
const PIPE_TOP_SKIM_BAND := 24.0
const CAPSULE_CYLINDER_H := 22.0
const BODY_FEET_TO_CENTER := CAPSULE_RADIUS + CAPSULE_CYLINDER_H * 0.5
const FIXED_DT := 1.0 / 60.0
const LOGIC_PER_METER := 100.0
## Invisible safety floor under every park — catches fall-through; never die from voids.
const VOID_FLOOR := -200.0

## Defaults match movement_contract.md; Player syncs debug sliders here.
static var FLY_OUT_ABOVE: float = 40.0
## Free-air deck land must start this far above the pad. Lip/apex skims within
## a couple units used to sticky-mount (keep vx, kill height) on the next gravity tick.
const DECK_LAND_MIN_ABOVE := 20.0
## How far back (seconds of safe floor/deck time) lava respawn restores.
static var CHECKPOINT_HISTORY_SEC: float = 1.5
static var FACING_COPING_CELLS: int = 3
static var ACID_COPING_CELLS: int = 16
static var GRAVITY: float = -1900.0
## Seconds of centered local-Y hang turn into the source pipe (0 = instant).
static var APEX_FACING_DELAY: float = 0.05
## Air spin yaw rate while rotate left/right held (rad/s).
static var SPIN_RATE: float = 7.95
## Half-width around nearest N×π for a successful spin land (radians).
static var LAND_SPIN_WINDOW: float = deg_to_rad(45.0)
## After a successful spun land, lerp contact yaw → nearest N×π (0 = snap).
## Board co-rotates; then one-frame rebase clears spin without unwinding.
static var SPIN_LAND_SETTLE: float = 0.15
## Rail top above layer.height (fixed; thickness is the tunable).
const RAIL_OFFSET: float = 56.0
## Vertical bar thickness (logical); debug slider syncs this.
static var RAIL_THICKNESS: float = 4.0
## Airborne + R mount proximity to rail top/centerline.
const RAIL_SNAP_RADIUS: float = 36.0
## |grind_balance| >= this → begin_fall while grinding.
const GRIND_BALANCE_FAIL: float = 1.0
## How fast stick tips the balance meter (units/sec toward ±fail).
const GRIND_BALANCE_RATE: float = 1.35
## How fast lean returns to center with stick released (units/sec).
const GRIND_BALANCE_RECOVER: float = 0.85
