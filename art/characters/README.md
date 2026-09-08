# SideSkate skater

An original low-poly humanoid: orange windbreaker, teal beanie, cargo trousers,
canvas sneakers and a simple geometric face. `scenes/main.tscn` uses this character
on the existing board, with gameplay-driven skeletal animation.

## Open and pose

Blender **5.0.1** is installed at `/usr/bin/blender`, with its desktop application
launcher. Ubuntu's `blender` and `python3-numpy` packages provide the application
and the dependency needed by its glTF exporter.

From the repository root:

```bash
blender art/characters/ssk_skater.blend
```

The file opens in Pose Mode on the `ride_idle` action, with the left hand control
selected. Use **G** to move controls and **R** to rotate them.

| Control | Purpose |
| --- | --- |
| `root` | Move or rotate the entire character |
| `pelvis` | Lower the body into a crouch; IK feet remain planted |
| `spine`, `chest`, `neck`, `head` | Torso lean and head direction |
| `CTRL_hand.L/R` | Hand position and orientation |
| `CTRL_foot.L/R` | Foot position and orientation |
| `CTRL_elbow.L/R`, `CTRL_knee.L/R` | Steer elbow and knee bend direction |
| `thumb/index/middle/ring/pinky_01/02.L/R` | Two joints per finger for grips |

The rig object's custom properties `arm_ik` and `leg_ik` blend between IK controls
at **1** and direct FK bone rotation at **0**. Bone collections separate the
deform skeleton, fingers and controls. Left and right bones have different colors.

The gameplay actions are `ride_idle`, `ollie_charge`, `ollie_pop`, `airborne`,
`landing`, `grind` and `fall`. `crouch_preview` and `rig_check` remain authoring
previews. All gameplay clips use a sideways stance with planted feet; charge
lowers the pelvis, the pop extends and tucks the knees, and landing absorbs impact.
The face has static geometry, without facial controls or expressions.

## Files

| File | Contents |
| --- | --- |
| [ssk_skater.blend](ssk_skater.blend) | Editable model, weighted rig, controls, actions, camera and studio lighting |
| [ssk_skater.glb](../../assets/characters/ssk_skater.glb) | Active Godot character: mesh, materials, deform skeleton and baked clips |
| [ssk_skater_preview.png](ssk_skater_preview.png) | Riding stance render |
| [ssk_skater_crouch.png](ssk_skater_crouch.png) | Crouch render |
| [ssk_skater_rig_check.png](ssk_skater_rig_check.png) | Raised leg / arm deformation render |
| [validation.json](validation.json) | Blender geometry, weights and sampled rig checks |
| [godot_validation.json](godot_validation.json) | Actual Godot import, skin and animation checks |

The authored model has 3,738 vertices, 7,180 triangles, 10 flat-color materials,
42 deform bones and 8 authoring controls. Blender height is **1.738 m**, with
feet on Z=0, +Z up and -Y forward. The GLB converts to +Y up / +Z forward.
Flat normals and material boundaries may split vertices during export.

Materials use no external textures. The GLB excludes the studio, widgets and IK
control bones; the exporter samples constraints into the deform skeleton.
The gameplay scene uses the actual 1.738 m height, displays it at 0.55 m, and
rotates the sideways stance to match the board and logical facing. The larger
visual fall bounds contain the rider while tumbling; sim collision is unchanged.

## Rebuild and verify

The build recipe is [tools/art/build_skater.py](../../tools/art/build_skater.py).
It replaces generated files, so save hand-edited versions under another name.

```bash
blender --background --factory-startup --python-exit-code 1 \
  --python tools/art/build_skater.py
./tools/check.sh tests --test test_logical_pose.gd --out artifacts/checks/character
./tools/check.sh tests --test test_skater_animation.gd --out artifacts/checks/character
./tools/check.sh gameplay --scenario animation --out artifacts/checks/character
GODOT="$(python3 tools/godot.py)" # Or set your Godot 4.7 executable path.
"$GODOT" --headless --path . --script res://tools/art/verify_skater.gd
```

The build checks every vertex's bone membership and normalized weights, verifies
mesh deformation, and samples all nine actions for finite geometry and IK target
tracking. Godot checks the imported skin, absence of authoring control bones,
clip availability and bone movement when playing the exported animation.

`art/.gdignore` keeps Blender authoring files and studio renders out of Godot's
asset import. Only the `.glb` under `assets/characters/` is imported by the game.
