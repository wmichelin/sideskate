"""Build SideSkate's original stylized humanoid with Blender 5.0+.

Run from the repository root:
  blender -b --factory-startup --python-exit-code 1 --python tools/art/build_skater.py
The editable source and studio renders live in art/characters; only the GLB is
imported by Godot. No runtime scene is changed by this asset build.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/characters"
EXPORT = ROOT / "assets/characters/ssk_skater.glb"
SOURCE.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for action in list(bpy.data.actions):
    bpy.data.actions.remove(action)

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.render.fps = 60
scene.frame_start = 1
scene.frame_end = 121
parts = []


def material(name, color, roughness=0.8):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    return mat


M = {
    "jacket": material("01 • Burnt orange / windbreaker", (0.75, 0.185, 0.035)),
    "trim": material("02 • Deep rust / cuffs", (0.32, 0.057, 0.025)),
    "pants": material("03 • Midnight / trousers", (0.028, 0.045, 0.062)),
    "seam": material("04 • Slate / pockets", (0.062, 0.09, 0.115)),
    "teal": material("05 • Petrol / beanie", (0.025, 0.22, 0.22)),
    "skin": material("06 • Warm clay / skin", (0.53, 0.29, 0.16)),
    "cream": material("07 • Chalk / canvas and trim", (0.87, 0.83, 0.69)),
    "rubber": material("08 • Gum / soles", (0.26, 0.155, 0.078)),
    "ink": material("09 • Ink / eyes and brows", (0.009, 0.015, 0.024)),
    "eye": material("10 • Warm white / eyes", (0.95, 0.91, 0.79)),
}


def bind_part(obj, mat, weights):
    obj.data.materials.append(mat)
    if isinstance(weights, str):
        weights = [{weights: 1.0} for _ in obj.data.vertices]
    for index, assignments in enumerate(weights):
        total = sum(assignments.values())
        for bone, weight in assignments.items():
            group = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            group.add([index], weight / total, "REPLACE")
    parts.append(obj)
    return obj


def mesh_part(name, verts, faces, mat, weights):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return bind_part(obj, mat, weights)


def rings(name, rows, mat, segments=12, axis=None):
    """Closed loft; each row supplies center, two radii and explicit skin weights."""
    tangent = Vector(axis or (0, 0, 1)).normalized()
    ref = Vector((1, 0, 0)) if axis is None else Vector((0, 1, 0))
    u = (ref - tangent * ref.dot(tangent)).normalized()
    v = tangent.cross(u)
    verts, weights, faces = [], [], []
    for center, a, b, group_weights in rows:
        center = Vector(center)
        for i in range(segments):
            angle = 2 * math.pi * i / segments
            verts.append(center + a * math.cos(angle) * u + b * math.sin(angle) * v)
            weights.append(group_weights)
    for row in range(len(rows) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((row * segments + i, row * segments + j,
                          (row + 1) * segments + j, (row + 1) * segments + i))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(rows) - 1) * segments + i for i in range(segments)))
    return mesh_part(name, verts, faces, mat, weights)


def ellipsoid(name, center, scale, mat, bone, segments=16, ring_count=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=ring_count, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return bind_part(obj, mat, bone)


def block(name, center, scale, mat, bone, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft manufactured edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return bind_part(obj, mat, bone)


def between(name, a, b, radius, mat, bone, radius_end=None):
    a, b = Vector(a), Vector(b)
    return rings(name, [(a, radius, radius, {bone: 1}),
                        (b, radius_end or radius, radius_end or radius, {bone: 1})],
                 mat, segments=8, axis=b - a)


# A relaxed A-pose, upright +Z and facing -Y. Feet sit on Z=0.
bone_specs = {}


def bone(name, head, tail, parent=None, deform=True):
    bone_specs[name] = (Vector(head), Vector(tail), parent, deform)


bone("root", (0, 0, 0), (0, 0, 0.18))
# Exported animation marker: the existing game board follows this local rotation.
bone("board_pose", (0, 0, 0), (0, 0, 0.10), "root")
bone("pelvis", (0, 0, 0.89), (0, 0, 1.01), "root")
bone("spine", (0, 0, 1.01), (0, 0, 1.17), "pelvis")
bone("chest", (0, 0, 1.17), (0, 0, 1.34), "spine")
bone("neck", (0, 0, 1.34), (0, 0, 1.43), "chest")
bone("head", (0, 0, 1.43), (0, 0, 1.70), "neck")

rings("Windbreaker / fitted hem to shoulders", [
    ((0, 0, 0.91), .163, .097, {"pelvis": 1}),
    ((0, 0, 0.97), .173, .108, {"pelvis": .6, "spine": .4}),
    ((0, 0, 1.06), .180, .113, {"spine": 1}),
    ((0, 0, 1.18), .203, .121, {"spine": .3, "chest": .7}),
    ((0, 0, 1.28), .223, .112, {"chest": 1}),
    ((0, 0, 1.325), .177, .093, {"chest": 1}),
    ((0, 0, 1.355), .072, .064, {"chest": .8, "neck": .2}),
], M["jacket"], 16)
rings("Ribbed hem", [((0, 0, .90), .163, .099, {"pelvis": 1}),
                    ((0, 0, .934), .169, .104, {"pelvis": 1})], M["trim"], 16)
rings("Trouser seat", [((0, 0, .79), .157, .09, {"pelvis": 1}),
                       ((0, 0, .88), .167, .098, {"pelvis": 1}),
                       ((0, 0, .93), .153, .095, {"pelvis": 1})], M["pants"], 12)
between("Neck", (0, 0, 1.33), (0, 0, 1.46), .055, M["skin"], "neck")
rings("Stand collar", [((0, 0, 1.335), .080, .071, {"chest": 1}),
                       ((0, 0, 1.375), .074, .067, {"neck": .5, "chest": .5})], M["trim"], 12)

# Narrow segmented zipper follows torso deformation rather than bridging joints.
for i in range(9):
    z = .96 + i * .041
    y = -.114 if z < 1.13 else (-.123 if z < 1.28 else -.099)
    group = "pelvis" if z < 1 else ("spine" if z < 1.15 else "chest")
    block(f"Zipper {i:02}", (0, y, z), (.009, .009, .042), M["cream"], group, .001)
block("Zipper pull", (0, -.111, 1.285), (.017, .011, .031), M["ink"], "chest", .004)
block("Chest badge", (.098, -.119, 1.235), (.055, .008, .034), M["cream"], "chest", .004)
block("Badge stripe", (.098, -.125, 1.235), (.034, .006, .008), M["teal"], "chest", .002)

# The face is geometry, so the export has no missing texture dependencies.
ellipsoid("Head", (0, -.004, 1.535), (.123, .109, .158), M["skin"], "head")
ellipsoid("Jaw", (0, -.028, 1.461), (.089, .083, .073), M["skin"], "head", 12, 6)
ellipsoid("Nose", (0, -.112, 1.523), (.022, .030, .030), M["skin"], "head", 8, 4)
block("Mouth", (0, -.108, 1.471), (.037, .007, .006), M["trim"], "head", .002)
for side, sign in (("L", 1), ("R", -1)):
    ellipsoid(f"Ear.{side}", (sign * .119, 0, 1.527), (.024, .030, .041), M["skin"], "head", 10, 6)
    ellipsoid(f"Eye.{side}", (sign * .043, -.101, 1.557), (.025, .012, .017), M["eye"], "head", 12, 6)
    ellipsoid(f"Pupil.{side}", (sign * .043, -.113, 1.557), (.010, .005, .012), M["ink"], "head", 10, 6)
    block(f"Brow.{side}", (sign * .043, -.104, 1.584), (.044, .011, .009), M["ink"], "head", .003)

rings("Beanie / crown", [
    ((0, .003, 1.603), .126, .111, {"head": 1}),
    ((0, .005, 1.651), .122, .108, {"head": 1}),
    ((0, .009, 1.697), .098, .088, {"head": 1}),
    ((0, .010, 1.727), .060, .056, {"head": 1}),
    ((0, .010, 1.738), .012, .012, {"head": 1}),
], M["teal"], 16)
rings("Beanie / folded brim", [((0, .003, 1.601), .129, .114, {"head": 1}),
                              ((0, .003, 1.639), .130, .115, {"head": 1})], M["teal"], 16)
block("Beanie label", (.053, -.105, 1.620), (.029, .008, .026), M["cream"], "head", .003)

for side, s in (("L", 1), ("R", -1)):
    suffix = "." + side
    hip = Vector((s * .103, 0, .90))
    knee = Vector((s * .124, -.036, .51))
    ankle = Vector((s * .14, 0, .13))
    toe = Vector((s * .14, -.13, .066))
    thigh, shin, foot = (n + suffix for n in ("thigh", "shin", "foot"))
    bone(thigh, hip, knee, "pelvis")
    bone(shin, knee, ankle, thigh)
    bone(foot, ankle, toe, shin)
    bone("toe" + suffix, toe, (s * .14, -.216, .060), foot)
    rings("Trouser leg" + suffix, [
        (ankle + Vector((0, 0, .015)), .058, .062, {shin: 1}),
        (ankle.lerp(knee, .22), .066, .072, {shin: 1}),
        (ankle.lerp(knee, .75), .076, .080, {shin: .9, thigh: .1}),
        (knee, .081, .088, {shin: .5, thigh: .5}),
        (knee.lerp(hip, .20), .084, .092, {shin: .1, thigh: .9}),
        (knee.lerp(hip, .75), .095, .104, {thigh: 1}),
        (hip, .097, .10, {thigh: .75, "pelvis": .25}),
    ], M["pants"], 12)
    rings("Trouser cuff" + suffix, [(ankle, .060, .064, {shin: 1}),
                                    (ankle + Vector((0, 0, .042)), .061, .065, {shin: 1})], M["seam"], 12)
    block("Utility pocket" + suffix, (s * .162, -.084, .745), (.068, .023, .115), M["seam"], thigh, .013)
    block("Pocket flap" + suffix, (s * .162, -.100, .782), (.071, .016, .030), M["pants"], thigh, .005)
    block("Sneaker sole" + suffix, (s * .14, -.069, .023), (.141, .295, .046), M["rubber"], foot, .018)
    block("Sneaker canvas" + suffix, (s * .14, -.065, .078), (.132, .279, .108), M["cream"], foot, .036)
    block("Sneaker heel" + suffix, (s * .14, .064, .084), (.101, .014, .066), M["teal"], foot, .005)
    for i in range(3):
        block(f"Lace {i}" + suffix, (s * .14, -.04 - i * .035, .132), (.076, .009, .008), M["ink"], foot, .003)

    shoulder = Vector((s * .219, 0, 1.303))
    elbow = Vector((s * .391, -.028, 1.124))
    wrist = Vector((s * .524, -.025, .965))
    hand_end = Vector((s * .573, -.027, .902))
    clavicle, upper, lower, hand = (n + suffix for n in ("clavicle", "upper_arm", "forearm", "hand"))
    bone(clavicle, (s * .07, 0, 1.31), shoulder, "chest")
    bone(upper, shoulder, elbow, clavicle)
    bone(lower, elbow, wrist, upper)
    bone(hand, wrist, hand_end, lower)
    arm_axis = wrist - shoulder
    ellipsoid("Shoulder seam" + suffix, (s * .210, 0, 1.29),
              (.097, .098, .098), M["jacket"], clavicle, 12, 6)
    rings("Sleeve" + suffix, [
        (shoulder, .084, .083, {upper: .8, "chest": .2}),
        (shoulder.lerp(elbow, .28), .080, .080, {upper: 1}),
        (shoulder.lerp(elbow, .80), .072, .073, {upper: .9, lower: .1}),
        (elbow, .069, .070, {upper: .5, lower: .5}),
        (elbow.lerp(wrist, .22), .065, .066, {upper: .1, lower: .9}),
        (elbow.lerp(wrist, .75), .054, .055, {lower: 1}),
        (elbow.lerp(wrist, .91), .047, .047, {lower: 1}),
    ], M["jacket"], 12, arm_axis)
    between("Wrist cuff" + suffix, elbow.lerp(wrist, .86), wrist, .049, M["trim"], lower, .044)
    between("Wrist" + suffix, wrist, wrist.lerp(hand_end, .32), .029, M["skin"], hand)
    palm = ellipsoid("Palm" + suffix, wrist.lerp(hand_end, .67), (.041, .028, .047), M["skin"], hand, 12, 6)
    # Four fingers and a thumb, each with two deform bones for useful grip posing.
    direction = (hand_end - wrist).normalized()
    across = Vector((s * .79, 0, .61)).normalized()
    for index, finger in enumerate(("index", "middle", "ring", "pinky")):
        base = hand_end + across * ((index - 1.5) * .019)
        length = (.061, .068, .062, .047)[index]
        middle = base + direction * length * .53
        tip = base + direction * length
        first, second = finger + "_01" + suffix, finger + "_02" + suffix
        bone(first, base, middle, hand)
        bone(second, middle, tip, first)
        rings(finger + suffix, [(base, .011, .011, {hand: .2, first: .8}),
                                (base.lerp(middle, .8), .010, .010, {first: 1}),
                                (middle, .010, .010, {first: .5, second: .5}),
                                (middle.lerp(tip, .7), .009, .009, {second: 1}),
                                (tip, .004, .004, {second: 1})], M["skin"], 8, direction)
    thumb_base = wrist.lerp(hand_end, .45) - across * .028 + Vector((0, -.012, 0))
    thumb_mid = thumb_base - across * .027 + direction * .018
    thumb_tip = thumb_mid + direction * .025
    bone("thumb_01" + suffix, thumb_base, thumb_mid, hand)
    bone("thumb_02" + suffix, thumb_mid, thumb_tip, "thumb_01" + suffix)
    between("Thumb base" + suffix, thumb_base, thumb_mid, .014, M["skin"], "thumb_01" + suffix, .012)
    between("Thumb tip" + suffix, thumb_mid, thumb_tip, .012, M["skin"], "thumb_02" + suffix, .007)

    # Controls remain in the .blend, but are excluded from the exported skin.
    bone("CTRL_foot" + suffix, ankle, toe, "root", False)
    bone("CTRL_knee" + suffix, knee + Vector((0, -.5, 0)), knee + Vector((0, -.5, .09)), "root", False)
    bone("CTRL_hand" + suffix, wrist, hand_end, "root", False)
    bone("CTRL_elbow" + suffix, elbow + Vector((0, -.4, 0)), elbow + Vector((0, -.4, .09)), "root", False)

# One skinned mesh with deliberately assigned weights, no automatic heat binding.
bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "Skater_Mesh"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.normals_make_consistent(inside=False) if hasattr(bpy.ops.mesh, "normals_make_consistent") else None
bpy.ops.object.mode_set(mode="OBJECT")

armature = bpy.data.armatures.new("Skater_Skeleton")
rig = bpy.data.objects.new("Skater_Rig", armature)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
body.select_set(False)
rig.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, (head, tail, parent, deform) in bone_specs.items():
    edit = armature.edit_bones.new(name)
    edit.head, edit.tail = head, tail
    edit.use_deform = deform
    if parent:
        edit.parent = armature.edit_bones[parent]
bpy.ops.object.mode_set(mode="OBJECT")
rig.show_in_front = True
rig.display_type = "WIRE"
body.parent = rig
modifier = body.modifiers.new("Weighted humanoid deformation", "ARMATURE")
modifier.object = rig
modifier.use_deform_preserve_volume = False  # Match glTF/Godot linear skinning.

deform_collection = armature.collections.new("Deform skeleton")
control_collection = armature.collections.new("IK controls • move hands and feet")
finger_collection = armature.collections.new("Fingers • rotate to curl")
for b in armature.bones:
    target = control_collection if b.name.startswith("CTRL_") else deform_collection
    if any(b.name.startswith(f) for f in ("thumb", "index", "middle", "ring", "pinky")):
        target = finger_collection
    target.assign(b)
    b.color.palette = "THEME04" if b.name.endswith(".L") else ("THEME03" if b.name.endswith(".R") else "THEME02")
    rig.pose.bones[b.name].rotation_mode = "QUATERNION"

rig["arm_ik"] = 1.0
rig["leg_ik"] = 1.0
for prop in ("arm_ik", "leg_ik"):
    rig.id_properties_ui(prop).update(min=0, max=1, description="1: IK controls; 0: rotate deform bones directly (FK)")
rig["instructions"] = "Pose Mode: move CTRL_hand/foot; pole controls steer joints. Rotate finger bones. Pelvis moves body; root moves everything."


def drive_influence(constraint, prop):
    driver = constraint.driver_add("influence").driver
    variable = driver.variables.new()
    variable.name = "amount"
    variable.type = "SINGLE_PROP"
    variable.targets[0].id = rig
    variable.targets[0].data_path = f'["{prop}"]'
    driver.expression = "amount"


ik_constraints = []
for side in ("L", "R"):
    for limb, end, target, pole, prop in (
        ("leg", "shin", "foot", "knee", "leg_ik"),
        ("arm", "forearm", "hand", "elbow", "arm_ik"),
    ):
        suffix = "." + side
        constraint = rig.pose.bones[end + suffix].constraints.new("IK")
        constraint.name = f"{limb.title()} IK • {side}"
        constraint.target = rig
        constraint.subtarget = "CTRL_" + target + suffix
        constraint.pole_target = rig
        constraint.pole_subtarget = "CTRL_" + pole + suffix
        constraint.chain_count = 2
        constraint.use_stretch = False
        drive_influence(constraint, prop)
        # Calibrate pole roll against the authored rest joint, including mirrored limbs.
        expected = bone_specs[end + suffix][0]
        candidates = []
        for step in range(72):
            angle = -math.pi + step * math.tau / 72
            constraint.pole_angle = angle
            bpy.context.view_layer.update()
            actual = rig.pose.bones[end + suffix].head
            candidates.append(((actual - expected).length, angle))
        constraint.pole_angle = min(candidates)[1]
        ik_constraints.append(constraint)
        orient = rig.pose.bones[target + suffix].constraints.new("COPY_ROTATION")
        orient.name = "Follow IK control orientation"
        orient.target = rig
        orient.subtarget = "CTRL_" + target + suffix
        drive_influence(orient, prop)
bpy.context.view_layer.update()

# Simple visible control widgets, stored outside the export selection.
widgets = bpy.data.collections.new("Rig widgets (authoring only)")
scene.collection.children.link(widgets)
for kind, radius in (("hand", .075), ("foot", .10), ("pole", .045), ("root", .30)):
    mesh = bpy.data.meshes.new("WGT_" + kind)
    verts = [(radius * math.cos(i * math.tau / 24), 0, radius * math.sin(i * math.tau / 24)) for i in range(24)]
    mesh.from_pydata(verts, [(i, (i + 1) % 24) for i in range(24)], [])
    shape = bpy.data.objects.new("WGT_" + kind, mesh)
    widgets.objects.link(shape)
    shape.hide_render = True
    shape.hide_set(True)
    for pb in rig.pose.bones:
        match = (kind == "root" and pb.name == "root") or (pb.name.startswith("CTRL_" + kind))
        match = match or (kind == "pole" and (pb.name.startswith("CTRL_knee") or pb.name.startswith("CTRL_elbow")))
        if match:
            pb.custom_shape = shape
            pb.use_custom_shape_bone_size = False


def reset_pose():
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)


def offset(name, delta):
    pb = rig.pose.bones[name]
    pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector(delta)


def rotate_world(name, axis, angle):
    pb = rig.pose.bones[name]
    rest = pb.bone.matrix_local.to_quaternion()
    pb.rotation_quaternion = rest.inverted() @ Quaternion(axis, angle) @ rest


def pose_ride(depth=.085, sway=0, reach=0.0, pitch=0.0, swing=0.0, twist=0.0, shift=0.0):
    reset_pose()
    # Sit the hips back and hinge the torso over the board, rather than just
    # dropping a vertical torso between inward-collapsing knees.
    offset("pelvis", (-pitch * .08 + shift, .025 + depth * .35, -depth))
    rotate_world("pelvis", (0, 0, 1), twist)
    rotate_world("spine", (1, 0, 0), .12 + depth * .95)
    rotate_world("chest", (1, 0, 0), .06 + depth * .22)
    rotate_world("head", (0, 0, 1), 1.05 - twist * .65)
    board_rotation = Quaternion((0, 1, 0), -pitch)
    rotate_world("board_pose", (0, 1, 0), -pitch)
    for side, s in (("L", 1), ("R", -1)):
        # Soles stay on the authored board plane, including the front-foot lead
        # during pop. Move the knee poles with the wide stance and turn them out.
        foot = board_rotation @ Vector((s * .32, 0, .13))
        offset("CTRL_foot." + side, foot - bone_specs["CTRL_foot." + side][0])
        rotate_world("CTRL_foot." + side, (0, 1, 0), -pitch)
        knee = Vector((s * .62, -.62, .48))
        offset("CTRL_knee." + side, knee - bone_specs["CTRL_knee." + side][0])
        # The front arm leads the swing; the rear arm follows for balance.
        # Hand targets lag the hip drive instead of mirroring each other.
        target = Vector((s * (.43 - depth * .1 + reach * .16) + swing * .04,
                         -.16 + sway * s - swing * (.08 if side == "L" else .05),
                         .94 - depth * 1.05 + reach * .47 + swing * (.07 if side == "L" else -.035)))
        offset("CTRL_hand." + side, target - bone_specs["CTRL_hand." + side][0])
        for finger in ("index", "middle", "ring", "pinky"):
            for n in ("01", "02"):
                rotate_world(f"{finger}_{n}.{side}", (s * .8, 0, .6), .24)


def insert_pose(frame):
    # Author timing at 30 fps, bake IK at 60 fps to keep soles planted between keys.
    frame = 1 + (frame - 1) * 2
    for pb in rig.pose.bones:
        for prop in ("location", "rotation_quaternion", "scale"):
            pb.keyframe_insert(prop, frame=frame, group=pb.name)


rig.animation_data_create()
for name in ("ride_idle", "ollie_charge", "ollie_pop", "airborne", "landing", "grind", "fall", "crouch_preview", "rig_check"):
    rig.animation_data.action = None
    action = bpy.data.actions.new(name)
    rig.animation_data.action = action
    action.use_fake_user = True
    if name == "ride_idle":
        for frame, depth, sway in ((1, .085, 0), (16, .09, .008), (31, .095, 0), (46, .09, -.008), (61, .085, 0)):
            pose_ride(depth, sway)
            insert_pose(frame)
    elif name == "ollie_charge":
        for frame, depth, swing, twist, shift in (
                (1, .085, 0, 0, 0), (5, .13, -.10, -.015, -.008),
                (10, .25, -.45, -.04, -.022), (16, .34, -.75, -.06, -.03)):
            pose_ride(depth, swing=swing, twist=twist, shift=shift)
            insert_pose(frame)
    elif name == "ollie_pop":
        # Reference sequence compressed from slow motion into the game's jump:
        # extend, lead with the front knee, bring the rear knee up, level out.
        for frame, depth, reach, pitch, swing, twist, shift in (
                (1, .34, 0, 0, -.75, -.06, -.03),
                (2, .27, .12, .17, -.45, -.035, -.02),
                (3, .18, .65, .38, .25, .025, -.005),
                (4, .19, .90, .34, .85, .07, .005),
                (6, .24, 1.0, .24, 1.0, .08, .025),
                (8, .34, .9, .10, .65, .055, .015),
                (10, .36, .8, 0, .35, .035, .005)):
            pose_ride(depth, reach=reach, pitch=pitch, swing=swing, twist=twist, shift=shift)
            insert_pose(frame)
    elif name == "airborne":
        # Tuck at the apex, then open the legs and lower the arms for contact.
        for frame, depth, reach, swing, twist in (
                (1, .36, .8, .35, .035), (6, .34, .78, .30, .03),
                (11, .26, .60, .25, .02), (16, .18, .45, .20, .015)):
            pose_ride(depth, reach=reach, swing=swing, twist=twist)
            insert_pose(frame)
    elif name == "landing":
        for frame, depth, reach, swing, twist in (
                (1, .18, .45, .20, .015), (4, .38, .30, .50, -.025),
                (8, .25, .15, -.15, .02), (13, .085, 0, 0, 0)):
            pose_ride(depth, reach=reach, swing=swing, twist=twist)
            insert_pose(frame)
    elif name == "grind":
        for frame, sway in ((1, -.012), (16, .012), (31, -.012)):
            pose_ride(.14, sway)
            for side, s in (("L", 1), ("R", -1)):
                target = Vector((s * .57, -.045 + sway, 1.125))
                offset("CTRL_hand." + side, target - bone_specs["CTRL_hand." + side][0])
            insert_pose(frame)
    elif name == "fall":
        for frame in (1, 31):
            pose_ride(.26)
            for side, s in (("L", 1), ("R", -1)):
                target = Vector((s * .28, -.28, 1.18))
                offset("CTRL_hand." + side, target - bone_specs["CTRL_hand." + side][0])
            insert_pose(frame)
    elif name == "crouch_preview":
        for frame, depth, swing, twist in ((1, .085, 0, 0), (16, .34, -.75, -.06), (31, .085, 0, 0)):
            pose_ride(depth, swing=swing, twist=twist, shift=twist * .5)
            insert_pose(frame)
    else:
        for frame in (1, 16, 31, 46, 61):
            reset_pose()
            if frame == 16:
                offset("CTRL_foot.L", (0, -.15, .22))
                offset("CTRL_hand.R", (-.03, -.18, .18))
            elif frame == 31:
                offset("CTRL_foot.R", (0, -.15, .22))
                offset("CTRL_hand.L", (.03, -.18, .18))
            elif frame == 46:
                pose_ride(.20)
            insert_pose(frame)

# Validate the actual evaluated rig before writing deliverables.
checks = []


def check(name, ok, **details):
    checks.append({"name": name, "ok": bool(ok), **details})
    if not ok:
        raise RuntimeError(f"Character validation failed: {name}: {details}")


deform_names = {b.name for b in armature.bones if b.use_deform}
check("all_vertices_weighted", all(v.groups for v in body.data.vertices), vertices=len(body.data.vertices))
check("normalized_weights", all(abs(sum(g.weight for g in v.groups) - 1) < 1e-5 for v in body.data.vertices))
check("only_deform_bone_weights", all(g.name in deform_names for g in body.vertex_groups))
check("maximum_four_influences", max(len(v.groups) for v in body.data.vertices) <= 4)
check("humanoid_bones", all(n in deform_names for n in ("pelvis", "head", "hand.L", "hand.R", "foot.L", "foot.R")))
check("feet_at_ground", abs(min(v.co.z for v in body.data.vertices)) < .001)
check("identity_mesh_transform", all(abs(v - 1) < 1e-6 for v in body.scale) and body.location.length < 1e-6)
height = max(v.co.z for v in body.data.vertices)

def evaluated_positions():
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    positions = [v.co.copy() for v in mesh.vertices]
    evaluated.to_mesh_clear()
    return positions

rig.animation_data.action = bpy.data.actions["rig_check"]
scene.frame_set(1)
baseline = evaluated_positions()
scene.frame_set(31)
raised = evaluated_positions()
check("mesh_deforms_with_controls", max((a - b).length for a, b in zip(baseline, raised)) > .15)
for action in bpy.data.actions:
    rig.animation_data.action = action
    for frame in range(1, int(action.frame_range[1]) + 1):
        scene.frame_set(frame)
        evaluated_positions()
        for side in ("L", "R"):
            for end, control in (("shin", "foot"), ("forearm", "hand")):
                error = (rig.pose.bones[end + "." + side].tail - rig.pose.bones["CTRL_" + control + "." + side].head).length
                check(f"{action.name}:{frame}:{end}.{side}:IK", error < .035, error=error)
        check(f"{action.name}:{frame}:finite", all(math.isfinite(x) for p in evaluated_positions() for x in p))

# Export only the skinned character; constraints are sampled into deform bones.
rig.animation_data.action = bpy.data.actions["ride_idle"]
scene.frame_set(1)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", use_selection=True,
                          export_yup=True, export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_def_bones=True,
                          export_skins=True, export_influence_nb=4, export_leaf_bone=False,
                          export_rest_position_armature=True, export_cameras=False, export_lights=False)

# A separate studio collection provides a useful, editable presentation scene.
studio = bpy.data.collections.new("Studio (not exported)")
scene.collection.children.link(studio)


def to_studio(obj):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    studio.objects.link(obj)
    return obj


floor_mat = material("Studio / midnight blue", (.018, .032, .05))
bpy.ops.mesh.primitive_plane_add(size=200)
floor = to_studio(bpy.context.object)
floor.name = "Studio floor"
floor.data.materials.append(floor_mat)
floor.location.z = -.012


def aim(obj, point):
    obj.rotation_euler = (Vector(point) - obj.location).to_track_quat("-Z", "Y").to_euler()


def light(name, location, power, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = power, color, "DISK", size
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = location
    aim(obj, (0, 0, .9))


light("Key / warm softbox", (3, -4, 5), 550, (1, .83, .66), 4)
light("Fill / cool softbox", (-3, -2, 2.5), 350, (.58, .76, 1), 3)
light("Rim / high rear", (1, 3, 4), 750, (.6, 1, .93), 2.5)
scene.world.color = (.12, .12, .12)
camera_data = bpy.data.cameras.new("Character portrait")
camera = bpy.data.objects.new("Character portrait", camera_data)
studio.objects.link(camera)
camera.location = (2.7, -5, 2.3)
aim(camera, (0, 0, .86))
camera_data.type = "ORTHO"
camera_data.ortho_scale = 2.23
scene.camera = camera
scene.render.engine = "CYCLES"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.view_settings.view_transform = "AgX"

# Save in Pose Mode, on a ready-to-edit ride pose. Native drivers need no scripts.
rig.animation_data.action = bpy.data.actions["ride_idle"]
scene.frame_set(1)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="POSE")
for pb in rig.pose.bones:
    pb.select = False
rig.pose.bones["CTRL_hand.L"].select = True
armature.bones.active = armature.bones["CTRL_hand.L"]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_distance = 3.1
            area.spaces.active.region_3d.view_location = (0, 0, .88)
            area.spaces.active.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            area.spaces.active.shading.type = "MATERIAL"
            area.spaces.active.shading.type = "SOLID"
            area.spaces.active.shading.color_type = "MATERIAL"
            area.spaces.active.overlay.show_floor = False

notes = bpy.data.texts.new("START HERE • SideSkate skater")
notes.write("""SIDESKATE / ORIGINAL SKATER

Pose Mode is already active. Move (G) CTRL_hand.L/R and CTRL_foot.L/R.
Move CTRL_elbow/knee to steer the bend. Rotate (R) hand/foot controls.
Move pelvis to crouch; root moves the entire character.
Finger bones have two joints each. No facial animation rig is included.
Object custom properties arm_ik and leg_ik: 1 = IK; 0 = FK.
Gameplay clips: ride_idle, ollie_charge, ollie_pop, airborne, landing, grind, fall.
Authoring previews: crouch_preview and rig_check.
Height: approximately 1.74 m; feet at origin; Blender -Y forward / +Z up.
GLB contains the mesh, materials, deform skeleton and baked preview clips.
The source studio and control widgets are excluded from that export.
Gameplay position and board motion remain owned by the game simulation.
Rebuild recipe: tools/art/build_skater.py. Rebuilding replaces generated files;
save a separate .blend for hand edits you want to retain.
""")
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "ssk_skater.blend"))

for label, action_name, frame in (("preview", "ride_idle", 1), ("crouch", "crouch_preview", 31), ("rig_check", "rig_check", 31)):
    rig.animation_data.action = bpy.data.actions[action_name]
    scene.frame_set(frame)
    scene.render.filepath = str(SOURCE / f"ssk_skater_{label}.png")
    bpy.ops.render.render(write_still=True)

body.data.calc_loop_triangles()
report = {"completed": True, "blender": bpy.app.version_string,
          "blend": str(SOURCE / "ssk_skater.blend"), "glb": str(EXPORT),
          "vertices": len(body.data.vertices), "triangles": len(body.data.loop_triangles),
          "materials": len(body.data.materials), "deform_bones": len(deform_names),
          "control_bones": len(armature.bones) - len(deform_names), "height_m": height,
          "actions": [a.name for a in bpy.data.actions], "checks": checks,
          "failed": sum(not c["ok"] for c in checks)}
(SOURCE / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
print("CHARACTER_BUILD_COMPLETE", json.dumps({k: v for k, v in report.items() if k != "checks"}))
