"""Builds Emberwake's low-poly characters and exports them as .glb.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_characters.py
    .tools/bin/blender-py tools/blender/build_characters.py

Outputs assets/models/characters/<id>.glb. Every character shares one chunky base body
(big head and hands, short legs; ~1.7 m tall, facing -Y in Blender = +Z in Godot) and adds
the costume pieces that sell who they are.

Rig contract (read by scripts/world/character_rig.gd, which animates the idle in code):
    Rig                      root empty at the feet
      LegL, LegR             pivot at the hip
      Torso                  pivot at the waist (breathing / sway)
        Head                 pivot at the neck
        ArmL, ArmR           pivot at the shoulder; may carry a rest rotation (holding things)
      Stool                  optional static extras (seated characters)
L/R are the character's own left/right (L = Blender +X). Held items are part of the arm.
"""
import math
import os

import bpy  # must be imported before mathutils when running as the bpy module
from mathutils import Vector  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "models", "characters")

# Palette from docs/GAME_DESIGN.md. Characters may use tonal shades of these (see material()).
PALETTE = {
    "ember": "#F2A541",
    "kindle": "#F4D58D",
    "coal": "#B5452F",
    "moss": "#5E8C61",
    "pine": "#2F5D50",
    "tide": "#3D7EA6",
    "abyss": "#1F3A5F",
    "slate": "#6B7280",
    "driftwood": "#C9B28F",
    "silverfog": "#C7CCD4",
    "ink": "#1B1B2F",
    "bone": "#EDE6D6",
}


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def shaded_rgba(hex_color: str, shade: float) -> tuple:
    """shade in [-1, 1]: negative darkens toward black, positive lightens toward white."""
    h = hex_color.lstrip("#")
    rgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    if shade < 0:
        rgb = [c * (1.0 + shade) for c in rgb]
    else:
        rgb = [c + (1.0 - c) * shade for c in rgb]
    return tuple(srgb_to_linear(c) for c in rgb) + (1.0,)


_materials: dict = {}


def material(name: str, shade: float = 0.0, emissive: bool = False) -> bpy.types.Material:
    key = (name, round(shade, 3), emissive)
    if key in _materials:
        return _materials[key]
    label = name + (f"_{'d' if shade < 0 else 'l'}{abs(int(shade * 100))}" if shade else "")
    mat = bpy.data.materials.new(label + ("_glow" if emissive else ""))
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgba = shaded_rgba(PALETTE[name], shade)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.95
    if emissive:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = 1.6
    _materials[key] = mat
    return mat


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def _finish(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    # Bake rotation/scale into the mesh: joined parts keep only the first object's
    # transform, and the rig later overwrites part rotations with rest poses.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def _track_rotation(direction: Vector):
    return direction.to_track_quat("Z", "Y").to_euler()


def limb(a, b, r1, r2, mat, verts=6):
    """A tapered cylinder from point a (radius r1) to point b (radius r2)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length,
                                    location=(a + b) / 2, rotation=_track_rotation(d))
    return _finish(bpy.context.active_object, mat)


def ball(r, loc, mat, scale=(1.0, 1.0, 1.0), segments=8, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=r, location=loc)
    obj = bpy.context.active_object
    obj.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, mat)


def block(size, center, mat, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=rot)
    obj = bpy.context.active_object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, mat)


def ring(r, z, height, mat, verts=8, y=0.0):
    """A short flat band (scarf, belt, hat brim) centred on the body axis."""
    return limb((0, y, z - height / 2), (0, y, z + height / 2), r, r, mat, verts)


class Body:
    """Proportions for one character. All heights in metres, before the Rig scale."""

    def __init__(self, seated: bool = False, build: float = 1.0):
        self.seated = seated
        self.build = build            # width multiplier (1 = average, >1 broad)
        self.hip = 0.46 if seated else 0.68
        self.waist = self.hip + 0.06
        self.shoulder = self.hip + 0.52
        self.neck = self.shoulder + 0.05
        self.head = self.neck + 0.22   # head centre
        self.head_r = 0.235
        self.shoulder_x = 0.25 * build
        self.arm_len = 0.46
        self.parts = {k: [] for k in ("LegL", "LegR", "Torso", "Head", "ArmL", "ArmR", "Stool")}
        self.arm_rest = {"ArmL": (0.0, 0.0, 0.0), "ArmR": (0.0, 0.0, 0.0)}
        self.head_rest = (0.0, 0.0, 0.0)

    def pivots(self) -> dict:
        return {
            "LegL": (0.12, 0, self.hip), "LegR": (-0.12, 0, self.hip),
            "Torso": (0, 0, self.waist), "Head": (0, 0, self.neck),
            "ArmL": (self.shoulder_x, 0, self.shoulder - 0.04),
            "ArmR": (-self.shoulder_x, 0, self.shoulder - 0.04),
            "Stool": (0, 0, 0),
        }

    def hand(self, side: str) -> Vector:
        x = self.shoulder_x + 0.04 if side == "L" else -self.shoulder_x - 0.04
        return Vector((x, 0, self.shoulder - 0.04 - self.arm_len))


def base_body(b: Body, skin, trousers, boots, top, sleeves=None, face=True) -> None:
    """Legs, torso, arms, hands and a head with a simple face. Costume goes on top."""
    sleeves = sleeves or top
    p = b.parts
    for side, x in (("L", 0.12), ("R", -0.12)):
        leg = p["Leg" + side]
        if b.seated:
            knee = (x, -0.36, b.hip + 0.02)
            leg.append(limb((x, 0, b.hip), knee, 0.1, 0.09, trousers))
            leg.append(limb(knee, (x, -0.38, 0.1), 0.085, 0.075, trousers))
            leg.append(block((0.15, 0.24, 0.11), (x, -0.43, 0.055), boots))
        else:
            leg.append(limb((x, 0, b.hip), (x, 0, 0.1), 0.1, 0.075, trousers))
            leg.append(block((0.16, 0.26, 0.12), (x, -0.04, 0.06), boots))
    w = b.build
    p["Torso"].append(limb((0, 0, b.hip - 0.02), (0, 0, b.shoulder), 0.25 * w, 0.24 * w, top, verts=8))
    p["Torso"].append(ball(0.25 * w, (0, 0, b.shoulder - 0.02), top, scale=(1.0, 0.8, 0.45)))
    p["Torso"].append(limb((0, 0, b.shoulder), (0, 0, b.neck + 0.03), 0.07, 0.07, skin, verts=6))
    for side in ("L", "R"):
        sx = b.shoulder_x if side == "L" else -b.shoulder_x
        top_pt = Vector((sx, 0, b.shoulder - 0.04))
        hand = b.hand(side)
        p["Arm" + side].append(limb(top_pt, hand + Vector((0, 0, 0.07)), 0.085, 0.07, sleeves))
        p["Arm" + side].append(ball(0.085, hand, skin, scale=(0.9, 1.0, 1.1), segments=6, rings=4))
    head = Vector((0, 0, b.head))
    p["Head"].append(ball(b.head_r, head, skin, scale=(1.0, 0.95, 1.05)))
    if face:
        for ex in (0.075, -0.075):
            p["Head"].append(block((0.04, 0.02, 0.055), head + Vector((ex, -b.head_r * 0.93, 0.02)), material("ink")))
        p["Head"].append(limb(head + Vector((0, -b.head_r * 0.9, -0.03)),
                              head + Vector((0, -b.head_r * 1.12, -0.05)), 0.035, 0.0, skin, verts=4))


def assemble(b: Body, name: str, scale: float = 1.0) -> None:
    """Joins each part list into one object, sets its pivot, parents it and exports."""
    rig = bpy.data.objects.new("Rig", None)
    bpy.context.collection.objects.link(rig)
    rig.scale = (scale, scale, scale)
    pivots = b.pivots()
    made = {}
    for part in ("LegL", "LegR", "Torso", "Head", "ArmL", "ArmR", "Stool"):
        objs = b.parts[part]
        if not objs:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        obj = bpy.context.active_object
        obj.name = part
        obj.data.name = f"{name}_{part}"
        bpy.context.scene.cursor.location = pivots[part]
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        made[part] = obj
    # Parent with plain local offsets (no parent-inverse matrices) so glTF nodes stay clean.
    parents = {"LegL": "Rig", "LegR": "Rig", "Torso": "Rig", "Stool": "Rig",
               "Head": "Torso", "ArmL": "Torso", "ArmR": "Torso"}
    for part, obj in made.items():
        parent = rig if parents[part] == "Rig" else made[parents[part]]
        world = Vector(pivots[part])
        parent_world = Vector((0, 0, 0)) if parent is rig else Vector(pivots[parents[part]])
        obj.parent = parent
        obj.location = world - parent_world
    for arm, rot in b.arm_rest.items():
        if arm in made:
            made[arm].rotation_euler = rot
    made["Head"].rotation_euler = b.head_rest
    tris = sum(sum(len(poly.vertices) - 2 for poly in o.data.polygons) for o in made.values())
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False,
                              export_apply=True, export_yup=True, export_animations=False)
    print(f"[build_characters] wrote {path} ({os.path.getsize(path) // 1024} KB, {tris} tris)")


# --- The cast ---------------------------------------------------------------------------

def build_wakebearer() -> None:
    """The player: deep hooded cloak, bare-faced, the living ember cupped in the right hand."""
    reset_scene()
    b = Body()
    cloak = material("abyss")
    skin = material("driftwood", 0.35)
    base_body(b, skin, material("ink", 0.2), material("slate", -0.35), cloak, sleeves=material("abyss", 0.15))
    t = b.parts["Torso"]
    # Cloak: a wide flared cone from the shoulders down past the knees, split at the front.
    t.append(limb((0, 0.02, 0.28), (0, 0.02, b.shoulder + 0.02), 0.4, 0.27, cloak, verts=8))
    t.append(block((0.1, 0.03, 0.7), (0, -0.33, 0.62), material("ink", 0.2)))  # front opening
    t.append(ring(0.2, b.shoulder + 0.06, 0.08, material("ember", -0.35)))       # clasped collar
    # Hood pushed back behind the head, with a peak.
    h = b.parts["Head"]
    h.append(ball(0.27, (0, 0.07, b.head + 0.02), cloak, scale=(1.0, 1.0, 1.05)))
    h.append(limb((0, 0.2, b.head + 0.1), (0, 0.34, b.head - 0.08), 0.1, 0.0, cloak, verts=5))
    h.append(ball(0.1, (0, -0.02, b.head + 0.2), material("ink", 0.3), scale=(2.2, 1.6, 0.6)))  # hair
    # The ember: a glowing coal in the right hand, a kindle core, a coal-red scorched cuff.
    hand = b.hand("R")
    arm = b.parts["ArmR"]
    arm.append(ball(0.075, hand + Vector((0, -0.08, 0.02)), material("ember", emissive=True), segments=6, rings=4))
    arm.append(ball(0.04, hand + Vector((0, -0.13, 0.04)), material("kindle", emissive=True), segments=6, rings=4))
    arm.append(limb(hand + Vector((0, 0, 0.1)), hand + Vector((0, 0, 0.15)), 0.085, 0.085, material("coal")))
    b.arm_rest["ArmR"] = (math.radians(-40), 0, math.radians(-8))
    assemble(b, "wakebearer")


def build_mara() -> None:
    """Harbormaster: broad, heavy wool coat, coal-red scarf, grey hair tied back in a bun."""
    reset_scene()
    b = Body(build=1.2)
    coat = material("slate", -0.3)
    skin = material("driftwood", 0.1)
    base_body(b, skin, material("ink", 0.25), material("ink", 0.1), coat)
    t = b.parts["Torso"]
    t.append(limb((0, 0, 0.36), (0, 0, b.waist + 0.08), 0.36, 0.3, coat, verts=8))         # coat skirt
    t.append(ring(0.31, b.waist + 0.05, 0.07, material("ink", 0.2)))                          # belt
    for z in (0.95, 1.05):
        t.append(ball(0.025, (0.08, -0.29, z), material("kindle", -0.3), segments=4, rings=3))  # buttons
    # Scarf: thick wrap around the neck with one tail hanging over the chest.
    scarf = material("coal")
    t.append(ring(0.17, b.shoulder + 0.05, 0.1, scarf))
    t.append(block((0.1, 0.05, 0.36), (-0.1, -0.27, b.shoulder - 0.18), scarf, rot=(0.15, 0, 0.12)))
    h = b.parts["Head"]
    hair = material("silverfog", -0.1)
    h.append(ball(0.255, (0, 0.05, b.head + 0.035), hair, scale=(1.04, 1.0, 1.0)))
    h.append(ball(0.11, (0, 0.26, b.head + 0.0), hair))  # bun
    # Heavy brows: she frowns at the sea.
    for ex in (0.075, -0.075):
        h.append(block((0.08, 0.03, 0.025), (ex, -0.21, b.head + 0.075), hair))
    b.arm_rest["ArmL"] = (0, 0, math.radians(6))
    b.arm_rest["ArmR"] = (0, 0, math.radians(-6))
    assemble(b, "mara")


def build_pell() -> None:
    """Orphaned net-mender, twelve: oversized cap, patched jacket, net-needle in hand."""
    reset_scene()
    b = Body(build=0.9)
    jacket = material("kindle", -0.25)
    skin = material("driftwood", 0.2)
    base_body(b, skin, material("driftwood", -0.3), material("ink", 0.15), jacket)
    t = b.parts["Torso"]
    t.append(limb((0, 0, 0.58), (0, 0, b.waist + 0.06), 0.28, 0.26, jacket, verts=8))
    t.append(block((0.12, 0.03, 0.12), (0.12, -0.25, 0.95), material("tide")))   # patches
    t.append(block((0.1, 0.03, 0.09), (-0.1, -0.26, 1.08), material("coal")))
    b.parts["ArmL"].append(block((0.03, 0.1, 0.1), b.hand("L") + Vector((0.08, 0, 0.22)), material("tide")))
    h = b.parts["Head"]
    cap = material("slate", -0.1)
    h.append(ball(0.29, (0, 0.03, b.head + 0.14), cap, scale=(1.05, 1.1, 0.65)))  # floppy crown
    h.append(block((0.32, 0.2, 0.03), (0, -0.27, b.head + 0.12), cap, rot=(-0.3, 0, 0)))  # brim
    h.append(ball(0.04, (0, 0.03, b.head + 0.33), material("coal"), segments=4, rings=3))  # button
    h.append(ball(0.07, (0.2, 0.05, b.head - 0.03), material("driftwood", -0.5), scale=(0.6, 1.2, 1.2)))  # tufts
    h.append(ball(0.07, (-0.2, 0.05, b.head - 0.03), material("driftwood", -0.5), scale=(0.6, 1.2, 1.2)))
    # Net-needle: a long flat wooden shuttle held point-up.
    hand = b.hand("R")
    b.parts["ArmR"].append(block((0.035, 0.02, 0.28), hand + Vector((0, -0.06, 0.1)), material("driftwood", 0.2)))
    b.arm_rest["ArmR"] = (math.radians(-35), 0, 0)
    b.head_rest = (math.radians(-6), 0, math.radians(8))  # chin up, cocky tilt
    assemble(b, "pell", scale=0.78)


def build_aldous() -> None:
    """Fled Keeper: long faded robe with the stitched ember, rope belt, bottle, a stoop."""
    _aldous(seated=False)


def build_aldous_seated() -> None:
    """Aldous on the bench by the Wrens' steps (LORE: he sits on one): the robe's skirt over
    his knees, the bottle held loose on his left thigh, the right hand on his right knee, the
    stoop deeper sitting down. The "bottle" idle lifts it to his mouth now and then."""
    _aldous(seated=True)


def _aldous(seated: bool) -> None:
    reset_scene()
    b = Body(seated=seated, build=1.05)
    robe = material("silverfog", -0.12)
    skin = material("driftwood", 0.05)
    hem = material("silverfog", -0.3)
    base_body(b, skin, robe, material("driftwood", -0.45), robe)
    t = b.parts["Torso"]
    if seated:
        # The robe to the seat, its skirt over his thighs and falling past the knees.
        t.append(limb((0, 0.02, b.hip - 0.06), (0, 0.02, b.waist + 0.1), 0.34, 0.27, robe, verts=8))
        for side, x in (("L", 0.12), ("R", -0.12)):
            leg = b.parts["Leg" + side]
            leg.append(block((0.24, 0.4, 0.05), (x, -0.18, b.hip + 0.08), robe))
            leg.append(block((0.24, 0.05, 0.3), (x, -0.4, b.hip - 0.1), robe))
            leg.append(block((0.24, 0.055, 0.05), (x, -0.4, b.hip - 0.26), hem))           # frayed hem
    else:
        t.append(limb((0, 0, 0.05), (0, 0, b.waist + 0.1), 0.36, 0.27, robe, verts=8))    # hem to the floor
    t.append(ring(0.28, b.waist + 0.04, 0.05, material("driftwood", -0.2)))            # rope belt
    t.append(limb((0.12, -0.26, b.waist + 0.02), (0.14, -0.3, b.waist - 0.28), 0.02, 0.015,
                  material("driftwood", -0.2), verts=4))                               # belt tail
    # The faded stitched ember: a flame diamond on the chest, dull, half unpicked.
    t.append(block((0.1, 0.02, 0.1), (0, -0.25, b.shoulder - 0.17), material("ember", -0.3), rot=(0, math.radians(45), 0)))
    t.append(block((0.04, 0.02, 0.1), (0, -0.25, b.shoulder - 0.06), material("ember", -0.3)))
    h = b.parts["Head"]
    # Bald crown, a grey fringe and a short beard.
    fringe = material("silverfog", 0.2)
    h.append(ball(0.2, (0, 0.06, b.head - 0.02), fringe, scale=(1.25, 1.0, 0.6)))
    h.append(ball(0.14, (0, -0.14, b.head - 0.15), fringe, scale=(1.1, 0.8, 0.9)))
    # A dark green bottle in the left hand, held loose.
    hand = b.hand("L")
    glass = material("pine", -0.1)
    b.parts["ArmL"].append(limb(hand + Vector((0, -0.07, -0.16)), hand + Vector((0, -0.07, 0.02)), 0.06, 0.06, glass))
    b.parts["ArmL"].append(limb(hand + Vector((0, -0.07, 0.02)), hand + Vector((0, -0.07, 0.12)), 0.03, 0.025, glass))
    if seated:
        b.parts["ArmL"].append(ball(0.028, hand + Vector((0, -0.07, 0.13)), material("driftwood", -0.3),
                                    segments=5, rings=3))                               # cork
        # Hands down onto the thighs: the bottle stands on the left one.
        b.arm_rest["ArmL"] = (math.radians(-38), 0, math.radians(-4))
        b.arm_rest["ArmR"] = (math.radians(-46), 0, math.radians(6))
        b.head_rest = (math.radians(18), 0, 0)  # the stoop, deeper sitting down
        assemble(b, "aldous_seated")
        return
    b.arm_rest["ArmL"] = (math.radians(-20), 0, math.radians(4))
    b.head_rest = (math.radians(12), 0, 0)  # the stoop: head bowed forward
    assemble(b, "aldous")


def build_tam() -> None:
    """Young Tidewright gate guard: tide oilskin, sou'wester, a tall gate pole."""
    reset_scene()
    b = Body(build=0.95)
    oilskin = material("tide")
    skin = material("driftwood", 0.25)
    base_body(b, skin, material("abyss", 0.1), material("ink", 0.1), oilskin)
    t = b.parts["Torso"]
    t.append(limb((0, 0, 0.42), (0, 0, b.waist + 0.08), 0.32, 0.27, oilskin, verts=8))
    t.append(block((0.03, 0.03, 0.6), (0, -0.27, 0.8), material("abyss")))            # coat seam
    t.append(ring(0.26, b.waist + 0.04, 0.05, material("ink", 0.1)))
    h = b.parts["Head"]
    hat = material("tide", -0.25)
    h.append(ball(0.25, (0, 0.01, b.head + 0.07), hat, scale=(1.0, 1.0, 0.75)))
    h.append(limb((0, 0.05, b.head + 0.02), (0, 0.05, b.head + 0.05), 0.36, 0.32, hat, verts=8))  # wide brim
    h.append(ball(0.08, (0, 0.02, b.head - 0.02), material("kindle", -0.4), scale=(3.0, 1.8, 0.6)))  # fringe
    # Gate pole, planted beside the right foot, gripped at shoulder height.
    hand = b.hand("R")
    b.parts["ArmR"].append(limb(hand + Vector((0, -0.05, -0.55)), hand + Vector((0, -0.05, 1.0)), 0.035, 0.03,
                                material("driftwood", -0.1)))
    b.parts["ArmR"].append(limb(hand + Vector((0, -0.05, 0.9)), hand + Vector((0, -0.05, 1.05)), 0.05, 0.02,
                                material("slate"), verts=4))                           # iron tip
    b.arm_rest["ArmR"] = (math.radians(-25), 0, math.radians(-10))
    assemble(b, "tam")


def build_hesk() -> None:
    """Hushed netmender: seated on a low stool, shawl, a net across her knees, hands mending."""
    reset_scene()
    b = Body(seated=True, build=1.0)
    dress = material("slate", -0.2)
    shawl = material("moss", -0.35)
    skin = material("driftwood", 0.0)
    base_body(b, skin, dress, material("ink", 0.15), dress, sleeves=shawl)
    t = b.parts["Torso"]
    t.append(ball(0.34, (0, 0.02, b.shoulder - 0.08), shawl, scale=(1.0, 0.85, 0.7)))  # shawl over shoulders
    t.append(limb((0, -0.2, b.shoulder - 0.1), (0, -0.28, b.shoulder - 0.42), 0.07, 0.0, shawl, verts=4))  # shawl point
    h = b.parts["Head"]
    hair = material("bone", -0.05)
    h.append(ball(0.25, (0, 0.04, b.head + 0.04), hair, scale=(1.05, 1.0, 1.0)))
    h.append(ball(0.18, (0, 0.2, b.head - 0.14), hair, scale=(0.9, 0.6, 1.2)))  # long plait
    # The net: a draped sheet over the knees and a hanging fold, both greyed.
    net = material("silverfog", -0.25)
    cord = material("slate", -0.3)
    b.parts["LegL"].append(block((0.56, 0.4, 0.02), (-0.12, -0.2, b.hip + 0.13), net, rot=(0.06, 0, 0)))
    b.parts["LegL"].append(block((0.5, 0.02, 0.28), (-0.12, -0.41, b.hip - 0.02), net, rot=(-0.15, 0, 0.05)))
    # Mesh cords across the drape so it reads as a net, not a cloth.
    for i in range(4):
        x = -0.36 + 0.16 * i
        b.parts["LegL"].append(block((0.015, 0.4, 0.03), (x, -0.2, b.hip + 0.14), cord, rot=(0.06, 0, 0)))
        b.parts["LegL"].append(block((0.015, 0.03, 0.28), (x + 0.02, -0.42, b.hip - 0.02), cord, rot=(-0.15, 0, 0.05)))
    for y in (-0.08, -0.26):
        b.parts["LegL"].append(block((0.56, 0.015, 0.03), (-0.12, y, b.hip + 0.14 - y * 0.06), cord))
    b.parts["Stool"].append(limb((0, 0.02, 0), (0, 0.02, b.hip - 0.08), 0.18, 0.2, material("driftwood", -0.2), verts=6))
    b.parts["Stool"].append(limb((0, 0.02, b.hip - 0.1), (0, 0.02, b.hip - 0.02), 0.26, 0.26, material("driftwood"), verts=8))
    # Hands forward over the net, as if mending; the rig moves them.
    b.arm_rest["ArmL"] = (math.radians(-55), 0, math.radians(-14))
    b.arm_rest["ArmR"] = (math.radians(-55), 0, math.radians(14))
    b.head_rest = (math.radians(22), 0, 0)  # looking down at the work
    assemble(b, "hesk")


def build_oda() -> None:
    """Oda Farrow, Tidewright ferry-master (sixties): long abyss greatcoat over a bone
    gansey, pine watch cap, a white braid, the ferry's hand-scale for weighing deeds hanging
    from her left hand and a bone speaking-horn slung at her hip."""
    reset_scene()
    b = Body(build=1.1)
    coat = material("abyss", -0.05)
    skin = material("driftwood", -0.05)
    base_body(b, skin, material("ink", 0.2), material("ink", 0.05), material("bone", -0.2), sleeves=coat)
    t = b.parts["Torso"]
    # Greatcoat: open over the gansey, long skirts, wide collar, brass buttons down each edge.
    t.append(limb((0, 0.02, 0.22), (0, 0.02, b.waist + 0.1), 0.38, 0.29, coat, verts=8))
    for x in (0.2, -0.2):
        t.append(block((0.1, 0.06, 0.6), (x, -0.23, b.shoulder - 0.3), coat, rot=(0, 0, -0.1 if x > 0 else 0.1)))
        for z in (0.95, 1.08):
            t.append(ball(0.022, (x * 0.8, -0.28, z), material("ember", -0.4), segments=4, rings=3))
    t.append(ring(0.2, b.shoulder + 0.04, 0.12, coat))                                        # collar
    t.append(ring(0.29, b.waist + 0.04, 0.05, material("ink", 0.1)))                          # belt
    # The horn: a curved bone speaking-horn slung on the right hip from a cord.
    t.append(limb((-0.3, -0.05, b.waist - 0.02), (-0.3, -0.12, b.waist - 0.32), 0.07, 0.025, material("bone", 0.0), verts=6))
    t.append(limb((0.15, -0.2, b.shoulder), (-0.3, -0.08, b.waist - 0.02), 0.012, 0.012, material("driftwood", -0.3), verts=4))
    h = b.parts["Head"]
    cap = material("pine", -0.05)
    h.append(ball(0.25, (0, 0.03, b.head + 0.08), cap, scale=(1.02, 1.02, 0.72)))
    h.append(ring(0.25, b.head + 0.02, 0.07, material("pine", 0.15)))                       # turned-up cuff
    hair = material("bone", 0.1)
    h.append(limb((0, 0.22, b.head - 0.02), (0.02, 0.28, b.head - 0.42), 0.06, 0.035, hair, verts=5))  # braid
    for ex in (0.075, -0.075):
        h.append(block((0.08, 0.03, 0.02), (ex, -0.21, b.head + 0.07), hair))                 # white brows
    # The deed-scale: a small brass balance hanging from the left hand, pans at rest.
    hand = b.hand("L")
    brass = material("ember", -0.35)
    arm = b.parts["ArmL"]
    arm.append(limb(hand + Vector((0, -0.05, -0.02)), hand + Vector((0, -0.05, -0.22)), 0.012, 0.012, brass, verts=4))
    arm.append(block((0.3, 0.02, 0.02), hand + Vector((0, -0.05, -0.23)), brass))
    for px in (0.14, -0.14):
        arm.append(limb(hand + Vector((px, -0.05, -0.23)), hand + Vector((px, -0.05, -0.36)), 0.006, 0.006, brass, verts=4))
        arm.append(limb(hand + Vector((px, -0.05, -0.38)), hand + Vector((px, -0.05, -0.36)), 0.07, 0.07, brass, verts=6))
    b.arm_rest["ArmL"] = (math.radians(-30), 0, math.radians(6))
    b.arm_rest["ArmR"] = (0, 0, math.radians(-8))
    b.head_rest = (math.radians(-4), 0, 0)  # chin up, reading the weather
    assemble(b, "oda")


def build_bram() -> None:
    """Bram Kettle, foreman of the Tidewright lumber camp on Thornwold (forties): broad, moss
    wool shirt with the sleeves shoved up, a scarred leather apron, a big coal-brown beard, a
    pine knit cap, and a felling axe resting on his right shoulder."""
    reset_scene()
    b = Body(build=1.25)
    shirt = material("moss", -0.2)
    skin = material("driftwood", 0.05)
    base_body(b, skin, material("slate", -0.35), material("ink", 0.05), shirt, sleeves=shirt)
    t = b.parts["Torso"]
    apron = material("coal", -0.55)
    t.append(block((0.42, 0.05, 0.62), (0, -0.29, b.waist - 0.2), apron))                   # apron skirt
    t.append(block((0.3, 0.05, 0.3), (0, -0.3, b.waist + 0.22), apron))                     # bib
    t.append(ring(0.32, b.waist + 0.04, 0.06, material("ink", 0.1)))                        # belt
    t.append(block((0.16, 0.05, 0.12), (0.18, -0.33, b.waist - 0.08), material("driftwood", -0.4)))  # tally pouch
    for side in ("L", "R"):
        hand = b.hand(side)
        # Bare forearms where the sleeves are shoved up.
        b.parts["Arm" + side].append(limb(hand + Vector((0, 0, 0.26)), hand + Vector((0, 0, 0.06)), 0.078, 0.072, skin))
        b.parts["Arm" + side].append(limb(hand + Vector((0, 0, 0.3)), hand + Vector((0, 0, 0.25)), 0.1, 0.1, shirt))  # rolled cuff
    h = b.parts["Head"]
    beard = material("coal", -0.4)
    h.append(ball(0.2, (0, -0.1, b.head - 0.12), beard, scale=(1.05, 0.8, 1.0)))            # beard
    h.append(block((0.2, 0.04, 0.04), (0, -0.23, b.head - 0.02), beard))                    # moustache
    cap = material("pine", -0.1)
    h.append(ball(0.25, (0, 0.02, b.head + 0.09), cap, scale=(1.02, 1.02, 0.68)))
    h.append(ring(0.25, b.head + 0.03, 0.08, material("pine", 0.1)))                        # rolled brim
    # The axe on his right shoulder: haft down to the hand, the head behind him.
    hand = b.hand("R")
    haft = material("driftwood", -0.1)
    top = Vector((-b.shoulder_x - 0.02, 0.32, b.shoulder + 0.32))
    b.parts["ArmR"].append(limb(hand + Vector((0, -0.04, 0.0)), top, 0.03, 0.03, haft, verts=5))
    b.parts["ArmR"].append(block((0.05, 0.22, 0.16), top + Vector((0, 0.06, 0.02)), material("slate", -0.3)))
    b.arm_rest["ArmR"] = (math.radians(-55), 0, math.radians(-6))
    b.arm_rest["ArmL"] = (0, 0, math.radians(10))
    b.head_rest = (math.radians(3), 0, 0)
    assemble(b, "bram")


def build_hob() -> None:
    """Hob Marl, the last collier on Thornwold's near side (old): stooped and lean, soot to the
    elbows, a sacking smock belted with rope over an ink shirt, a leather hood pushed back off
    a bald, soot-smudged head, a grey stubble beard, and a long clamp rake held upright in his
    left hand. The Greying has had some of him: his smock is silvered at the hem."""
    _hob(seated=False)


def build_hob_seated() -> None:
    """Hob come in by daylight, sitting on the bench by the tally-house step with the clamp rake
    across his knees, both soot-black hands resting on the pole (the "sit" idle moves them). Same
    man as `hob`; the rake is a static extra (the Stool part) so it stays put while he breathes."""
    _hob(seated=True)


def _hob(seated: bool) -> None:
    reset_scene()
    b = Body(seated=seated, build=0.9)
    smock = material("driftwood", -0.45)
    soot = material("ink", 0.12)
    skin = material("driftwood", -0.1)
    hem = material("silverfog", -0.2)
    base_body(b, skin, material("slate", -0.4), material("ink", 0.0), smock, sleeves=soot)
    t = b.parts["Torso"]
    if seated:
        # The smock to the hips, its skirt over his thighs, silvered at the knees.
        t.append(limb((0, 0.0, b.hip - 0.06), (0, 0.0, b.waist + 0.06), 0.3, 0.26, smock, verts=8))
        b.parts["LegL"].append(block((0.5, 0.34, 0.05), (-0.12, -0.18, b.hip + 0.07), smock))
        b.parts["LegL"].append(block((0.5, 0.05, 0.14), (-0.12, -0.36, b.hip - 0.04), hem))
    else:
        # Sacking smock to the knees, silvered where the fog has had it.
        t.append(limb((0, 0.0, 0.34), (0, 0.0, b.waist + 0.06), 0.3, 0.26, smock, verts=8))
        t.append(limb((0, 0.0, 0.3), (0, 0.0, 0.4), 0.31, 0.3, hem, verts=8))
    t.append(ring(0.27, b.waist + 0.03, 0.04, material("driftwood", -0.15)))                # rope belt
    t.append(limb((0.12, -0.27, b.waist + 0.02), (0.15, -0.3, b.waist - 0.2), 0.02, 0.02, material("driftwood", -0.15), verts=4))  # rope end
    t.append(block((0.34, 0.05, 0.36), (0, -0.25, b.waist + 0.2), material("coal", -0.6)))  # scorched bib
    # Soot to the elbows: dark gauntlets over the forearms and hands.
    for side in ("L", "R"):
        hand = b.hand(side)
        b.parts["Arm" + side].append(ball(0.09, hand, soot, scale=(0.95, 1.05, 1.15), segments=6, rings=4))
    h = b.parts["Head"]
    hood = material("coal", -0.65)
    h.append(ball(0.29, (0, 0.13, b.head - 0.06), hood, scale=(1.0, 0.75, 0.95)))           # hood pushed back
    h.append(ring(0.2, b.head - 0.2, 0.08, hood))                                           # hood cowl at the neck
    h.append(ball(0.17, (0, -0.1, b.head - 0.13), material("silverfog", -0.1), scale=(1.05, 0.75, 0.85)))  # grey stubble
    h.append(block((0.1, 0.03, 0.05), (0.06, -0.225, b.head + 0.12), soot))                 # soot smudge
    for ex in (0.075, -0.075):
        h.append(block((0.08, 0.03, 0.025), (ex, -0.215, b.head + 0.075), material("silverfog", 0.0)))  # brows
    pole = material("driftwood", -0.25)
    iron = material("slate", -0.45)
    if seated:
        # The clamp rake across his knees, iron head out past his left knee, tines hanging.
        z = b.hip + 0.16
        b.parts["Stool"].append(limb((-0.62, -0.3, z), (0.66, -0.33, z - 0.02), 0.022, 0.022, pole, verts=5))
        head = Vector((0.7, -0.33, z - 0.02))
        b.parts["Stool"].append(block((0.05, 0.36, 0.04), head, iron))
        for ty in (-0.15, -0.05, 0.05, 0.15):
            b.parts["Stool"].append(block((0.025, 0.025, 0.11), head + Vector((0.0, ty, -0.09)), iron))
        # Hands forward onto the pole; a stoop, chin down.
        b.arm_rest["ArmL"] = (math.radians(-42), 0, math.radians(-6))
        b.arm_rest["ArmR"] = (math.radians(-42), 0, math.radians(6))
        b.head_rest = (math.radians(14), 0, 0)
        assemble(b, "hob_seated")
        return
    # The clamp rake, upright in his left hand: a long pole and an iron head over his shoulder.
    hand = b.hand("L")
    top = hand + Vector((0.02, -0.06, 1.05))
    b.parts["ArmL"].append(limb(hand + Vector((0, -0.06, -0.62)), top, 0.022, 0.022, pole, verts=5))
    b.parts["ArmL"].append(block((0.36, 0.05, 0.04), top, iron))
    for tx in (-0.15, -0.05, 0.05, 0.15):
        b.parts["ArmL"].append(block((0.025, 0.025, 0.11), top + Vector((tx, -0.02, -0.07)), iron))
    b.arm_rest["ArmL"] = (math.radians(-12), 0, math.radians(4))
    b.arm_rest["ArmR"] = (math.radians(-6), 0, math.radians(-6))
    b.head_rest = (math.radians(10), 0, 0)  # a stoop: chin down, looking up under his brows
    assemble(b, "hob")


def build_lamp() -> None:
    """The Lamp, Thornwold's beacon-keeper (old, a Keeper thirty years at the Ridge Light): thin
    and stooped under a hooded oilskin cape, the hood up and the face lost in its shadow (nobody
    has seen it — "you don't ask the Lamp"); under the cape a Keeper's long silverfog robe, the
    ember stitched bright on the breast (not faded like Aldous's); hands soot-black from the
    chisel; a lantern pole in the right hand with a lit Keeper's lantern on its crook (the light
    "proper, like yours"); two cold lanterns at the belt to hang. Half-Hushed like Hob: the
    cape's hem and the left sleeve gone silver."""
    reset_scene()
    b = Body(build=0.88)
    robe = material("silverfog", -0.12)
    cape = material("driftwood", -0.55)          # oilskin, dark and dull with wax and soot
    soot = material("ink", 0.1)
    iron = material("ink", 0.18)
    base_body(b, material("driftwood", -0.15), robe, material("ink", 0.0), robe, sleeves=cape, face=False)
    t = b.parts["Torso"]
    t.append(limb((0, 0, 0.05), (0, 0, b.waist + 0.1), 0.33, 0.26, robe, verts=8))           # robe to the ground
    # The cape: hung from the shoulders to mid-shin, open at the front over the robe.
    t.append(limb((0, 0.09, 0.3), (0, 0.04, b.shoulder + 0.02), 0.36, 0.27, cape, verts=8))
    t.append(limb((0, 0.09, 0.22), (0, 0.09, 0.32), 0.37, 0.36, material("silverfog", -0.3), verts=8))  # greyed hem
    for x in (0.22, -0.22):  # the cape's open front edges, the robe showing between them
        t.append(block((0.07, 0.05, 0.74), (x, -0.22, b.shoulder - 0.36), cape, rot=(0, 0, -0.08 if x > 0 else 0.08)))
    t.append(ring(0.27, b.waist + 0.04, 0.05, material("driftwood", -0.4)))                    # belt
    # The Keepers' ember, stitched bright: a flame diamond on the breast.
    t.append(block((0.12, 0.02, 0.12), (0, -0.25, b.shoulder - 0.18), material("ember", 0.0), rot=(0, math.radians(45), 0)))
    t.append(block((0.045, 0.02, 0.11), (0, -0.25, b.shoulder - 0.05), material("ember", 0.0)))
    # Two cold lanterns hung at the left hip, to go on waymarks.
    for k, (x, y) in enumerate(((0.3, -0.06), (0.26, 0.12))):
        z = b.waist - 0.2 - 0.04 * k
        t.append(limb((x, y, z + 0.18), (x, y, z + 0.1), 0.01, 0.01, iron, verts=4))
        t.append(limb((x, y, z - 0.06), (x, y, z + 0.1), 0.065, 0.06, material("silverfog", -0.45), verts=6))
        t.append(limb((x, y, z + 0.1), (x, y, z + 0.15), 0.07, 0.015, iron, verts=6))
    # The hood, up and deep: the face is a shadow in it.
    h = b.parts["Head"]
    hood = cape
    h.append(ball(0.27, (0, 0.03, b.head + 0.02), hood, scale=(1.0, 1.05, 1.1)))
    h.append(limb((0, -0.12, b.head + 0.02), (0, -0.26, b.head - 0.01), 0.23, 0.21, hood, verts=8))  # the cowl's lip
    h.append(ball(0.17, (0, -0.24, b.head - 0.03), material("ink", -0.2), scale=(1.0, 0.45, 1.15)))  # the shadow
    h.append(limb((0, 0.2, b.head - 0.05), (0, 0.3, b.head - 0.4), 0.09, 0.03, hood, verts=5))  # hood point
    h.append(ring(0.21, b.head - 0.22, 0.08, hood))
    # Soot-black hands; the left sleeve silvered where the fog has had it.
    for side in ("L", "R"):
        b.parts["Arm" + side].append(ball(0.088, b.hand(side), soot, scale=(0.95, 1.05, 1.15), segments=6, rings=4))
    sl = b.hand("L") + Vector((0, 0, 0.1))
    b.parts["ArmL"].append(limb(sl, sl + Vector((0, 0, 0.12)), 0.08, 0.08, material("silverfog", -0.3), verts=6))
    # The lantern pole: held upright in the right hand, an iron crook at the top and a lit
    # Keeper's lantern hanging from it, out in front.
    hand = b.hand("R")
    pole = material("driftwood", -0.3)
    arm = b.parts["ArmR"]
    top = hand + Vector((0, -0.04, 1.2))
    arm.append(limb(hand + Vector((0, -0.04, -0.6)), top, 0.022, 0.02, pole, verts=5))
    hook = top + Vector((0, -0.24, 0.06))
    arm.append(limb(top + Vector((0, 0, -0.04)), hook, 0.015, 0.015, iron, verts=4))
    arm.append(limb(hook, hook + Vector((0, 0, -0.1)), 0.01, 0.01, iron, verts=4))
    lamp = hook + Vector((0, 0, -0.33))
    arm.append(limb(lamp, lamp + Vector((0, 0, 0.02)), 0.075, 0.075, iron, verts=6))
    arm.append(limb(lamp + Vector((0, 0, 0.02)), lamp + Vector((0, 0, 0.17)), 0.06, 0.06, material("kindle", 0.0, emissive=True), verts=6))
    arm.append(limb(lamp + Vector((0, 0, 0.17)), lamp + Vector((0, 0, 0.24)), 0.08, 0.015, iron, verts=6))
    b.arm_rest["ArmR"] = (math.radians(-24), 0, math.radians(-4))
    b.arm_rest["ArmL"] = (math.radians(-4), 0, math.radians(5))
    b.head_rest = (math.radians(14), 0, 0)  # bowed: the hood hangs over the face
    assemble(b, "lamp")


def build_hesper() -> None:
    """Hesper Vail, warden of Stillhithe's staithe in Glasswater Fen, one of the Unmoored (forties):
    tall and spare, a long reed-grey coat worn open over a moss shift, a silverfog shawl over her
    head and shoulders, bare forearms, a reed-cutter's sickle hooked at her belt, and a string of
    small things at her wrist that she doesn't look at. The fog has had her coat's hem (silvered).
    She stands with her hands folded low and her head a little turned away (the ember reminds)."""
    reset_scene()
    b = Body(build=0.92)
    coat = material("silverfog", -0.38)
    shift = material("moss", -0.3)
    skin = material("driftwood", 0.2)
    base_body(b, skin, shift, material("ink", 0.1), shift, sleeves=coat)
    t = b.parts["Torso"]
    t.append(limb((0, 0.03, 0.12), (0, 0.03, b.waist + 0.12), 0.34, 0.27, coat, verts=8))       # long coat
    t.append(limb((0, 0.03, 0.08), (0, 0.03, 0.18), 0.35, 0.34, material("silverfog", 0.05), verts=8))  # silvered hem
    for x in (0.17, -0.17):  # open front edges, the shift between them
        t.append(block((0.08, 0.05, 0.75), (x, -0.25, b.shoulder - 0.42), coat, rot=(0, 0, -0.06 if x > 0 else 0.06)))
    t.append(ring(0.26, b.waist + 0.04, 0.04, material("driftwood", -0.35)))                    # cord belt
    # The reed-cutter's sickle hooked at her left hip: a short handle and a curved iron blade.
    iron = material("slate", -0.3)
    t.append(limb((0.26, -0.1, b.waist - 0.02), (0.27, -0.12, b.waist - 0.22), 0.02, 0.02, material("driftwood", -0.3), verts=4))
    for k in range(4):
        a0, a1 = k * 0.45, (k + 1) * 0.45
        t.append(limb((0.27 + math.sin(a0) * 0.12, -0.12 - math.cos(a0) * 0.02, b.waist - 0.22 - (1 - math.cos(a0)) * 0.06),
                      (0.27 + math.sin(a1) * 0.12, -0.12 - math.cos(a1) * 0.02, b.waist - 0.22 - (1 - math.cos(a1)) * 0.06),
                      0.012, 0.012, iron, verts=4))
    # The shawl: over the head and down round the shoulders.
    h = b.parts["Head"]
    shawl = material("silverfog", -0.08)
    h.append(ball(0.265, (0, 0.1, b.head + 0.05), shawl, scale=(1.02, 0.92, 1.05)))
    h.append(ring(0.23, b.head - 0.2, 0.1, shawl))
    t.append(ball(0.29, (0, 0.02, b.shoulder - 0.02), shawl, scale=(1.05, 0.85, 0.42)))
    hair = material("ink", 0.35)
    h.append(block((0.2, 0.05, 0.06), (0, -0.225, b.head + 0.13), hair))                         # dark hair under the shawl
    for x in (0.16, -0.16):  # two long locks fallen out of the shawl, down past the jaw
        h.append(limb((x, -0.17, b.head + 0.08), (x * 1.05, -0.2, b.head - 0.22), 0.045, 0.025, hair, verts=4))
    # The shawl's fringed hem: a point down her back and a ragged fringe at the shoulders.
    t.append(limb((0, 0.2, b.shoulder - 0.02), (0, 0.24, b.shoulder - 0.48), 0.13, 0.0, shawl, verts=4))
    for k in range(6):
        x = -0.24 + k * 0.096
        t.append(limb((x, -0.12 if abs(x) < 0.15 else 0.0, b.shoulder - 0.08), (x * 1.05, -0.13 if abs(x) < 0.15 else 0.0, b.shoulder - 0.2),
                      0.018, 0.006, material("silverfog", -0.2), verts=3))
    # Hands folded low in front; a string of small things at the right wrist.
    b.arm_rest["ArmL"] = (math.radians(-28), 0, math.radians(-16))
    b.arm_rest["ArmR"] = (math.radians(-28), 0, math.radians(16))
    wrist = b.hand("R") + Vector((0, 0, 0.1))
    for k, colour in enumerate(("bone", "coal", "ember", "bone")):
        a = k / 4 * math.tau
        b.parts["ArmR"].append(ball(0.025, wrist + Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, 0)),
                                    material(colour, -0.25), segments=4, rings=3))
    b.head_rest = (math.radians(6), 0, math.radians(14))  # a little turned away
    assemble(b, "hesper")


def build_corran() -> None:
    """Corran Teal, the last of the fen folk on Glasswater (old, not Unmoored): short and broad in
    the back, thigh-high waders of tarred leather, a moss smock, a wide rush hat, a white fringe of
    beard, and an eel-leister (a long pole with a flat iron fork of barbed tines) held upright in his
    right hand. A creel on his back."""
    reset_scene()
    b = Body(build=1.08)
    smock = material("moss", -0.15)
    waders = material("ink", 0.12)
    skin = material("driftwood", -0.02)
    base_body(b, skin, waders, waders, smock, sleeves=smock)
    for side, x in (("L", 0.12), ("R", -0.12)):  # the waders' turned-down tops at the thigh
        b.parts["Leg" + side].append(limb((x, 0, b.hip - 0.12), (x, 0, b.hip - 0.2), 0.115, 0.11, material("coal", -0.6)))
    t = b.parts["Torso"]
    t.append(limb((0, 0, b.hip - 0.14), (0, 0, b.waist + 0.06), 0.29, 0.27, smock, verts=8))
    t.append(ring(0.29, b.waist + 0.03, 0.05, material("driftwood", -0.4)))
    # The creel: a reed basket on his back with a strap across the chest.
    # (Day 30: bigger and woven so it reads behind him: hoops, a lid, an eel's tail over the rim.)
    creel = material("driftwood", -0.12)
    weave = material("driftwood", -0.4)
    strap = material("coal", -0.5)
    cz, cy = b.waist - 0.06, 0.33
    t.append(limb((0, cy, cz), (0, cy + 0.02, cz + 0.5), 0.17, 0.22, creel, verts=7))
    for k in range(3):
        z = cz + 0.08 + k * 0.15
        t.append(limb((0, cy + 0.003 * k, z), (0, cy + 0.003 * k, z + 0.035), 0.185 + 0.035 * k, 0.19 + 0.035 * k, weave, verts=7))
    t.append(limb((0, cy + 0.03, cz + 0.5), (0, cy + 0.03, cz + 0.55), 0.23, 0.2, weave, verts=7))      # the lid
    t.append(limb((0.12, cy + 0.12, cz + 0.52), (0.2, cy + 0.2, cz + 0.36), 0.03, 0.005, material("slate", -0.5), verts=4))  # eel tail
    for x in (0.15, -0.15):  # shoulder straps
        t.append(limb((x, cy - 0.12, cz + 0.42), (x, -0.2, b.shoulder - 0.02), 0.025, 0.025, strap, verts=4))
        t.append(limb((x, -0.22, b.shoulder - 0.02), (x * 1.2, -0.24, b.waist + 0.05), 0.025, 0.025, strap, verts=4))
    # The rush hat: a wide, flat cone; a white beard fringe.
    h = b.parts["Head"]
    hat = material("driftwood", 0.05)
    h.append(limb((0, 0, b.head + 0.1), (0, 0, b.head + 0.17), 0.45, 0.34, hat, verts=8))
    h.append(limb((0, 0, b.head + 0.17), (0, 0, b.head + 0.33), 0.26, 0.05, hat, verts=8))
    h.append(ring(0.25, b.head + 0.17, 0.04, material("moss", -0.4)))
    h.append(ball(0.17, (0, -0.1, b.head - 0.14), material("bone", 0.05), scale=(1.1, 0.75, 0.8)))
    # The eel-leister, upright in the right hand: a long pole, a flat fork of barbed iron tines.
    hand = b.hand("R")
    pole = material("driftwood", -0.3)
    iron = material("slate", -0.4)
    top = hand + Vector((0, -0.05, 1.2))
    b.parts["ArmR"].append(limb(hand + Vector((0, -0.05, -0.62)), top, 0.024, 0.022, pole, verts=5))
    b.parts["ArmR"].append(block((0.28, 0.03, 0.05), top, iron))
    for tx in (-0.12, -0.04, 0.04, 0.12):
        b.parts["ArmR"].append(block((0.025, 0.025, 0.24), top + Vector((tx, 0, 0.13)), iron))
    b.arm_rest["ArmR"] = (math.radians(-12), 0, math.radians(-4))
    b.arm_rest["ArmL"] = (math.radians(-5), 0, math.radians(8))
    b.head_rest = (math.radians(-3), 0, 0)
    assemble(b, "corran")


def _unmoored_seat(b: Body, kind: str) -> None:
    """What an Unmoored sits on by the pools (the Stool part): a reed tussock or an upturned
    eel basket, its top at the seated Body's seat."""
    top = b.hip - 0.04
    if kind == "tussock":
        b.parts["Stool"].append(limb((0, 0.0, 0), (0, 0.0, top), 0.3, 0.24, material("moss", -0.45), verts=7))
        for k in range(7):
            a = k / 7 * math.tau
            base = Vector((math.cos(a) * 0.24, math.sin(a) * 0.24 + 0.02, top - 0.08))
            b.parts["Stool"].append(limb(base, base + Vector((math.cos(a) * 0.14, math.sin(a) * 0.14, 0.2)), 0.03, 0.0,
                                         material("driftwood", -0.25), verts=3))
    else:
        b.parts["Stool"].append(limb((0, 0.02, 0), (0, 0.02, top), 0.26, 0.2, material("driftwood", -0.3), verts=7))
        for z in (0.1, 0.25):
            b.parts["Stool"].append(limb((0, 0.02, z), (0, 0.02, z + 0.03), 0.255 - z * 0.2, 0.25 - z * 0.2,
                                         material("driftwood", -0.5), verts=7))


def build_unmoored_shawl() -> None:
    """One of the Unmoored by Stillhithe's pools (no name, no dialogue): a woman sitting on a
    reed tussock, a silverfog shawl over her head, her hands in her lap, looking down at the
    water. Everything about her the colour of the fog but a faded ribbon at her wrist."""
    reset_scene()
    b = Body(seated=True, build=0.9)
    dress = material("silverfog", -0.3)
    shawl = material("silverfog", -0.1)
    skin = material("driftwood", 0.15)
    base_body(b, skin, dress, material("slate", -0.4), dress, sleeves=shawl)
    t = b.parts["Torso"]
    t.append(ball(0.31, (0, 0.03, b.shoulder - 0.06), shawl, scale=(1.0, 0.85, 0.65)))
    t.append(limb((0, 0.2, b.shoulder - 0.05), (0, 0.24, b.shoulder - 0.45), 0.12, 0.0, shawl, verts=4))
    b.parts["LegL"].append(block((0.52, 0.42, 0.05), (-0.12, -0.19, b.hip + 0.07), dress))        # skirt over the knees
    b.parts["LegL"].append(block((0.5, 0.05, 0.36), (-0.12, -0.4, b.hip - 0.12), dress))
    h = b.parts["Head"]
    h.append(ball(0.26, (0, 0.08, b.head + 0.05), shawl, scale=(1.02, 0.92, 1.05)))
    h.append(ring(0.22, b.head - 0.2, 0.09, shawl))
    h.append(block((0.18, 0.04, 0.05), (0, -0.225, b.head + 0.13), material("bone", -0.2)))    # pale hair
    b.parts["ArmR"].append(ring(0.08, b.hand("R").z + 0.1, 0.03, material("ember", -0.35)))
    b.arm_rest["ArmL"] = (math.radians(-38), 0, math.radians(-18))  # hands in the lap
    b.arm_rest["ArmR"] = (math.radians(-38), 0, math.radians(18))
    b.head_rest = (math.radians(26), 0, 0)  # looking down at the water
    _unmoored_seat(b, "tussock")
    assemble(b, "unmoored_shawl")


def build_unmoored_coat() -> None:
    """Another of the Unmoored: a broad man in a long greyed coat, sitting on an upturned eel
    basket with his forearms on his knees and his head up, watching the fog over the pool as if
    something might come out of it. Bare-headed, grey stubble, a cup held loosely in both hands."""
    reset_scene()
    b = Body(seated=True, build=1.08)
    coat = material("slate", -0.15)
    skin = material("driftwood", -0.05)
    base_body(b, skin, material("silverfog", -0.45), material("ink", 0.05), coat, sleeves=coat)
    t = b.parts["Torso"]
    t.append(limb((0, 0.02, b.hip - 0.06), (0, 0.02, b.waist + 0.1), 0.31, 0.28, coat, verts=8))
    b.parts["LegR"].append(block((0.2, 0.36, 0.05), (-0.13, -0.17, b.hip + 0.07), coat))         # coat skirts over the thighs
    b.parts["LegL"].append(block((0.2, 0.36, 0.05), (0.13, -0.17, b.hip + 0.07), coat))
    t.append(ring(0.3, b.waist + 0.04, 0.04, material("silverfog", -0.2)))
    h = b.parts["Head"]
    h.append(ball(0.24, (0, 0.04, b.head + 0.06), material("silverfog", -0.15), scale=(1.0, 0.95, 0.75)))  # grey hair
    h.append(ball(0.17, (0, -0.1, b.head - 0.13), material("silverfog", 0.0), scale=(1.05, 0.75, 0.85)))   # stubble
    # Forearms on the knees, a cup between the hands (on the right arm).
    b.arm_rest["ArmL"] = (math.radians(-62), 0, math.radians(-12))
    b.arm_rest["ArmR"] = (math.radians(-62), 0, math.radians(12))
    hand = b.hand("R")
    b.parts["ArmR"].append(limb(hand + Vector((0.13, -0.02, -0.06)), hand + Vector((0.13, -0.02, 0.06)), 0.05, 0.06,
                                material("bone", -0.3), verts=6))
    b.head_rest = (math.radians(-4), 0, 0)
    _unmoored_seat(b, "basket")
    assemble(b, "unmoored_coat")


BUILDERS = [build_wakebearer, build_mara, build_pell, build_aldous, build_aldous_seated, build_tam, build_hesk, build_oda, build_bram,
            build_hob, build_hob_seated, build_lamp, build_hesper, build_corran,
            build_unmoored_shawl, build_unmoored_coat]

if __name__ == "__main__":
    import sys
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
