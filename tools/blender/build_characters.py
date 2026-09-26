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
    reset_scene()
    b = Body(build=1.05)
    robe = material("silverfog", -0.12)
    skin = material("driftwood", 0.05)
    base_body(b, skin, robe, material("driftwood", -0.45), robe)
    t = b.parts["Torso"]
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


if __name__ == "__main__":
    build_wakebearer()
    build_mara()
    build_pell()
    build_aldous()
    build_tam()
    build_hesk()
