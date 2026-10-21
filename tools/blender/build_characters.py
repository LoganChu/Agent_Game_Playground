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
from mathutils import Euler, Vector  # noqa: E402

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

    def __init__(self, seated: bool = False, build: float = 1.0, crouch: float = 0.0):
        self.seated = seated
        self.build = build            # width multiplier (1 = average, >1 broad)
        self.crouch = crouch          # standing only: how far the hips drop with the knees bent forward
        self.hip = 0.46 if seated else 0.68 - crouch
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
        self.torso_rest = (0.0, 0.0, 0.0)  # a stoop: the torso (and the head and arms with it) bent at the waist

    def knee(self, x: float) -> Vector:
        """Standing with `crouch`: the knee, forward of the hip and ankle."""
        return Vector((x, -self.crouch * 2.4, (self.hip + 0.1) * 0.5))

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
        elif b.crouch > 0.0:
            knee = b.knee(x)
            leg.append(limb((x, 0, b.hip), knee, 0.1, 0.085, trousers))
            leg.append(limb(knee, (x, 0, 0.1), 0.085, 0.075, trousers))
            leg.append(block((0.16, 0.26, 0.12), (x, -0.04, 0.06), boots))
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
    made["Torso"].rotation_euler = b.torso_rest
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
    # The coat's collar turned up against the wind: stiff at the back and sides, open at the front.
    t.append(block((0.36, 0.06, 0.2), (0, 0.13, b.shoulder + 0.09), coat, rot=(-0.3, 0, 0)))
    for side in (1, -1):
        t.append(block((0.06, 0.2, 0.17), (side * 0.17, 0.02, b.shoulder + 0.07), coat, rot=(0, side * 0.3, side * 0.25)))
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
    # Sea boots to the knee with the tops turned down (a gatekeeper stands in the wet all day).
    for side, x in (("L", 0.12), ("R", -0.12)):
        b.parts["Leg" + side].append(limb((x, 0, 0.1), (x, 0, 0.26), 0.09, 0.1, material("ink", 0.1)))
        b.parts["Leg" + side].append(limb((x, 0, 0.23), (x, 0, 0.31), 0.125, 0.13, material("ink", 0.24)))
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


def build_hob_lantern() -> None:
    """Hob at the ladder's head on Thornwold's ridge (Day 49, *The Fifth*): told he is the fifth and
    handed what the four came up for, a lantern of his own lit off the Ridge Light. No rake (he
    left it on the tally-house bench); the lantern held out in front of him by its bail in his
    right hand, gold behind horn, and his head lifted off the stoop for once, looking up the road."""
    _hob(seated=False, lantern=True)


def _hob(seated: bool, lantern: bool = False) -> None:
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
    if lantern:
        # A Keeper's lantern held out by its bail: iron foot and cap, horn panes lit gold.
        hand = b.hand("R")
        arm = b.parts["ArmR"]
        arm.append(limb(hand + Vector((0, -0.02, 0.02)), hand + Vector((0, -0.02, -0.1)), 0.01, 0.01, iron, verts=4))
        lamp = hand + Vector((0, -0.02, -0.36))
        arm.append(limb(lamp, lamp + Vector((0, 0, 0.02)), 0.075, 0.075, iron, verts=6))
        arm.append(limb(lamp + Vector((0, 0, 0.02)), lamp + Vector((0, 0, 0.17)), 0.06, 0.06, material("kindle", 0.0, emissive=True), verts=6))
        arm.append(limb(lamp + Vector((0, 0, 0.17)), lamp + Vector((0, 0, 0.24)), 0.08, 0.015, iron, verts=6))
        b.arm_rest["ArmR"] = (math.radians(-38), 0, math.radians(-4))  # held out in front
        b.arm_rest["ArmL"] = (math.radians(-4), 0, math.radians(6))
        b.head_rest = (math.radians(-6), 0, 0)  # head up: looking along the road, not at his feet
        assemble(b, "hob_lantern")
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


def build_lamp(hood_down: bool = False) -> None:
    """The Lamp, Thornwold's beacon-keeper (old, a Keeper thirty years at the Ridge Light): thin
    and stooped under a hooded oilskin cape, the hood up and the face lost in its shadow (nobody
    has seen it — "you don't ask the Lamp"); under the cape a Keeper's long silverfog robe, the
    ember stitched bright on the breast (not faded like Aldous's); hands soot-black from the
    chisel; a lantern pole in the right hand with a lit Keeper's lantern on its crook (the light
    "proper, like yours"); two cold lanterns at the belt to hang. Half-Hushed like Hob: the
    cape's hem and the left sleeve gone silver.

    hood_down: `lamp_named` — told its name (WYNN SALLOW, out of the Tidewrights' Book), the Lamp has
    put its hood back for the first time anyone has seen: a long weathered face, soot in the lines,
    white hair cropped close as a Keeper's, the hood lying in a thick roll on its shoulders, the
    head lifted off the bench."""
    reset_scene()
    b = Body(build=0.88)
    robe = material("silverfog", -0.12)
    cape = material("driftwood", -0.55)          # oilskin, dark and dull with wax and soot
    soot = material("ink", 0.1)
    iron = material("ink", 0.18)
    skin = material("driftwood", -0.15) if not hood_down else material("driftwood", -0.02)
    base_body(b, skin, robe, material("ink", 0.0), robe, sleeves=cape, face=hood_down)
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
    h = b.parts["Head"]
    hood = cape
    if hood_down:
        # The hood put back: a thick roll of oilskin lying round the neck and down the back.
        t.append(ring(0.2, b.neck - 0.02, 0.07, hood))
        t.append(ball(0.2, (0, 0.17, b.shoulder - 0.02), hood, scale=(1.15, 0.55, 0.8)))
        t.append(limb((0, 0.2, b.shoulder - 0.12), (0, 0.24, b.shoulder - 0.42), 0.08, 0.03, hood, verts=5))  # hood point
        # White hair cropped close, a Keeper's crop gone untended; soot in the lines of the face.
        hair = material("bone", 0.25)
        h.append(ball(b.head_r * 1.02, (0, 0.06, b.head + 0.06), hair, scale=(1.04, 0.95, 0.74)))
        h.append(block((0.2, 0.025, 0.02), (0, -b.head_r * 0.97, b.head + 0.075), material("ink", 0.05)))  # a soot-dark brow
        h.append(block((0.06, 0.02, 0.05), (0.06, -b.head_r * 0.9, b.head - 0.08), material("ink", -0.1)))  # a thumb of soot on the cheek
        h.append(block((0.1, 0.02, 0.016), (0, -b.head_r * 0.92, b.head - 0.11), material("ink", 0.1)))  # a thin mouth
    else:
        # The hood, up and deep: the face is a shadow in it.
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
    if hood_down:
        b.head_rest = (math.radians(4), 0, 0)  # lifted: looking at whoever said its name
        assemble(b, "lamp_named")
    else:
        b.head_rest = (math.radians(14), 0, 0)  # bowed: the hood hangs over the face
        assemble(b, "lamp")


def build_lamp_named() -> None:
    build_lamp(hood_down=True)


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
    _corran(cord=True)


def build_corran_nocord() -> None:
    """Corran once his knot-cord is given away (Day 36, `fen_corran_cord_away`: given to the
    Wakebearer, then burned in the Heron or not yet given back): the belt bare at the left hip and
    his left hand drawn in to it, where the cord hung."""
    _corran(cord=False)


def _corran(cord: bool) -> None:
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
    # (Day 34) The knot-cord at his belt, left hip: a short tarred cord hanging from the belt with
    # a row of knots in it — one tied at every turning out through the channels, "so I can count
    # them back".
    # Front of the hip, clear of his arm, the knots pale so they count from a few metres off.
    if cord:
        cord_m, knot = material("coal", -0.6), material("driftwood", -0.25)
        top = Vector((0.17, -0.29, b.waist + 0.03))
        low = top + Vector((0.03, -0.05, -0.36))
        t.append(limb(top, low, 0.014, 0.012, cord_m, verts=4))
        for k in range(5):
            t.append(ball(0.03, top + (low - top) * (0.22 + k * 0.17), knot, segments=5, rings=4))
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
    # Without the cord the left hand comes in to the bare belt (forward and across).
    b.arm_rest["ArmL"] = (math.radians(-5), 0, math.radians(8)) if cord else (math.radians(-16), 0, math.radians(-2))
    b.head_rest = (math.radians(-3), 0, 0)
    assemble(b, "corran" if cord else "corran_nocord")


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


def build_dunstan() -> None:
    """Dunstan Tollen, glimpsed at the Heron's legs (Day 33): Mara's brother, a big Saltmarrow
    fisherman, standing on a tussock at the fog's edge looking down into the water. A fisher's knit
    gansey gone grey with wet over oilskin trousers and sea boots, bare-headed, dark curls and a
    beard, and a ship's lantern hanging from his left hand — not lit ("It's for after")."""
    _dunstan(seated=False)


def build_dunstan_seated() -> None:
    """Dunstan found (Day 37): sat on a sedge tussock at the end of the long walk with his boots in
    the mere, forearms on his knees, whittling a thumb-sized gull (knife in the right hand, the gull
    in the left); the ship's lantern stood lit on the tussock beside him, horn panes gold."""
    _dunstan(seated=True)


def build_dunstan_seated_cord() -> None:
    """As `dunstan_seated`, with a bit of Mara's red cord knotted at his belt (her word was tied on
    the letting post, and he took it: the other half is round the gull's neck on the Heron's rim)."""
    _dunstan(seated=True, cord=True)


def build_dunstan_lantern() -> None:
    """Dunstan walking back (Day 51, *The Walk Back*): done, or as near as he can tell, coming in along
    the long walk. The same man as at the Heron's foot, but the ship's lantern in his left hand is lit
    now, horn panes gold, and his head is up: for once he is looking where he's going, not where he's been."""
    _dunstan(seated=False, lit=True)


def build_dunstan_home() -> None:
    """Dunstan home (Day 51): on his own driftwood stool by Mara's door (the dent is his), sea boots
    planted, a cup held in both big hands between his knees: the second cup, the one that was going cold."""
    _dunstan(seated=True, home=True)


def build_dunstan_turning() -> None:
    """Dunstan stayed (Day 52, *The Walk Back*): named, and staying on the fen to turn the long walk's
    boards the other way round. Stooped at the head of the walk with his knees bent, a board lifted
    crosswise in both hands, half turned; the ship's lantern stood lit on the boards at his left boot."""
    _dunstan(seated=False, turning=True)


def _ship_lantern(parts: list, base: Vector, lit: bool) -> None:
    """A squat ship's lantern standing on `base`: brass foot and cap, horn panes (gold when lit), a bail."""
    brass = material("driftwood", -0.45)
    panes = material("kindle", 0.0, emissive=True) if lit else material("ink", 0.1)
    parts.append(limb(base, base + Vector((0, 0, 0.04)), 0.12, 0.12, brass, verts=6))
    parts.append(limb(base + Vector((0, 0, 0.04)), base + Vector((0, 0, 0.3)), 0.1, 0.1, panes, verts=6))
    parts.append(limb(base + Vector((0, 0, 0.3)), base + Vector((0, 0, 0.38)), 0.11, 0.03, brass, verts=6))
    parts.append(limb(base + Vector((-0.06, 0, 0.36)), base + Vector((0, 0, 0.47)), 0.012, 0.012, brass, verts=3))
    parts.append(limb(base + Vector((0.06, 0, 0.36)), base + Vector((0, 0, 0.47)), 0.012, 0.012, brass, verts=3))


def _dunstan(seated: bool, cord: bool = False, lit: bool = False, home: bool = False, turning: bool = False) -> None:
    reset_scene()
    b = Body(seated=seated, build=1.28, crouch=0.08 if turning else 0.0)
    knit = material("tide", -0.55)
    skin = material("driftwood", -0.08)
    oilskin = material("slate", -0.35)
    base_body(b, skin, oilskin, material("ink", 0.08), knit, sleeves=knit)
    t = b.parts["Torso"]
    t.append(limb((0, 0, b.hip - 0.1), (0, 0, b.waist + 0.04), 0.33, 0.31, knit, verts=8))          # the gansey's skirt
    for z in (b.waist + 0.16, b.waist + 0.28):                                                     # knit ribs
        t.append(ring(0.325, z, 0.025, material("tide", -0.68)))
    t.append(ring(0.1, b.neck + 0.0, 0.06, knit))                                                  # roll neck
    if turning:
        for side, x in (("L", 0.12), ("R", -0.12)):                                               # boot tops, up the shin
            ankle = Vector((x, 0, 0.12))
            b.parts["Leg" + side].append(limb(ankle, ankle.lerp(b.knee(x), 0.85), 0.095, 0.1, material("ink", 0.04)))
    elif not seated:
        for side, x in (("L", 0.12), ("R", -0.12)):                                               # boot tops
            b.parts["Leg" + side].append(limb((x, 0, 0.12), (x, 0, 0.36), 0.095, 0.1, material("ink", 0.04)))
    h = b.parts["Head"]
    hair = material("ink", 0.2)
    h.append(ball(0.25, (0, 0.04, b.head + 0.07), hair, scale=(1.05, 1.0, 0.82)))                 # dark curls
    for k in range(5):
        a = k / 5 * math.tau
        h.append(ball(0.07, (math.cos(a) * 0.2, math.sin(a) * 0.2 + 0.05, b.head + 0.17), hair, segments=5, rings=3))
    h.append(ball(0.19, (0, -0.1, b.head - 0.13), hair, scale=(1.05, 0.75, 0.95)))                 # beard
    if turning:
        # Stooped at the waist, the arms reaching down and a little forward: a board lifted crosswise
        # in both hands (one of the long walk's: grey driftwood, a moss stain at one end), being turned.
        b.torso_rest = (math.radians(48), 0, 0)
        b.arm_rest["ArmL"] = (math.radians(-30), 0, math.radians(3))
        b.arm_rest["ArmR"] = (math.radians(-30), 0, math.radians(-3))
        b.head_rest = (math.radians(-22), 0, 0)  # eyes on the board, not the ground
        hand = b.hand("L")
        tilt = Euler((math.radians(-12), math.radians(8), 0))  # half turned: his right-hand end coming up
        mid = Vector((0.0, -0.05, hand.z - 0.02))
        b.parts["ArmL"].append(block((1.0, 0.2, 0.04), mid, material("driftwood", -0.36), rot=tilt))
        stain = Vector((-0.38, 0, 0))
        stain.rotate(tilt)
        b.parts["ArmL"].append(block((0.22, 0.205, 0.042), mid + stain, material("moss", -0.4), rot=tilt))
        # The lantern stood lit on the boards by his left boot.
        _ship_lantern(b.parts["Stool"], Vector((0.55, -0.15, 0.0)), lit=True)
        t.append(ring(0.335, b.waist + 0.05, 0.03, material("ink", 0.0)))                         # belt
        assemble(b, "dunstan_turning", scale=1.08)
        return
    if not seated:
        # The lantern in the left hand, hanging by its bail: a squat ship's lantern, horn panes dark
        # (gold once he's walking back with it lit).
        hand = b.hand("L")
        brass = material("driftwood", -0.45)
        panes = material("kindle", 0.0, emissive=True) if lit else material("ink", 0.1)
        lz = hand.z - 0.3
        b.parts["ArmL"].append(limb(hand + Vector((0, 0, -0.04)), hand + Vector((0, 0, -0.12)), 0.012, 0.012, brass, verts=3))
        b.parts["ArmL"].append(limb(Vector((hand.x, 0, lz - 0.12)), Vector((hand.x, 0, lz + 0.14)), 0.1, 0.1, panes, verts=6))
        b.parts["ArmL"].append(limb(Vector((hand.x, 0, lz + 0.14)), Vector((hand.x, 0, lz + 0.22)), 0.11, 0.03, brass, verts=6))
        b.parts["ArmL"].append(limb(Vector((hand.x, 0, lz - 0.15)), Vector((hand.x, 0, lz - 0.11)), 0.12, 0.12, brass, verts=6))
        b.parts["ArmL"].append(limb(Vector((hand.x, 0, lz + 0.22)), hand + Vector((0, 0, -0.12)), 0.015, 0.015, brass, verts=3))
        b.arm_rest["ArmL"] = (0, 0, math.radians(4))
        b.arm_rest["ArmR"] = (math.radians(-4), 0, math.radians(-6))
        if lit:
            b.head_rest = (math.radians(-4), 0, 0)  # head up: looking where he's going
            assemble(b, "dunstan_lantern", scale=1.08)
            return
        b.head_rest = (math.radians(24), 0, 0)  # looking down into the water
        assemble(b, "dunstan", scale=1.08)
        return
    if home:
        # Sea boots planted on the harbor stones, on his own stool by Mara's door.
        for side, x in (("L", 0.14), ("R", -0.14)):
            b.parts["Leg" + side].append(limb((x, -0.42, 0.04), (x, -0.42, 0.34), 0.1, 0.105, material("ink", 0.04)))
        t.append(ring(0.335, b.waist + 0.05, 0.03, material("ink", 0.0)))                         # belt
        # A cup held in both hands between the knees.
        b.arm_rest["ArmL"] = (math.radians(-52), 0, math.radians(-22))
        b.arm_rest["ArmR"] = (math.radians(-52), 0, math.radians(22))
        mid = (b.hand("L") + b.hand("R")) * 0.5
        b.parts["ArmL"].append(limb(mid + Vector((-0.02, -0.02, -0.05)), mid + Vector((-0.02, -0.02, 0.06)), 0.055, 0.065,
                                    material("bone", -0.15), verts=6))                             # the cup
        b.head_rest = (math.radians(6), 0, 0)  # out over the harbor
        # His stool: low driftwood, the seat dented.
        top = b.hip - 0.04
        stool = material("driftwood", -0.2)
        b.parts["Stool"].append(limb((0, 0.02, top - 0.08), (0, 0.02, top), 0.3, 0.28, stool, verts=8))
        for lx, ly in ((0.2, -0.16), (-0.2, -0.16), (0.2, 0.2), (-0.2, 0.2)):
            b.parts["Stool"].append(limb((lx * 1.1, ly * 1.1, 0), (lx * 0.8, ly * 0.8, top - 0.08), 0.035, 0.035, stool, verts=4))
        assemble(b, "dunstan_home", scale=1.08)
        return
    # Sea boots to the knee, in the mere (the tussock's foot is at the water).
    for side, x in (("L", 0.12), ("R", -0.12)):
        b.parts["Leg" + side].append(limb((x, -0.42, 0.04), (x, -0.42, 0.34), 0.1, 0.105, material("ink", 0.04)))
    t.append(ring(0.335, b.waist + 0.05, 0.03, material("ink", 0.0)))                             # belt
    if cord:
        # Mara's red cord knotted at his belt, a tail hanging.
        red = material("coal", 0.05)
        t.append(ball(0.03, (0.2, -0.27, b.waist + 0.05), red, segments=5, rings=3))
        t.append(limb((0.2, -0.28, b.waist + 0.04), (0.23, -0.29, b.waist - 0.16), 0.016, 0.012, red, verts=3))
    # Whittling: forearms out over the knees, a knife in the right hand, a thumb-sized gull in the left.
    b.arm_rest["ArmL"] = (math.radians(-58), 0, math.radians(-14))
    b.arm_rest["ArmR"] = (math.radians(-58), 0, math.radians(14))
    hand_r = b.hand("R")
    b.parts["ArmR"].append(limb(hand_r + Vector((0.03, 0, -0.04)), hand_r + Vector((0.07, -0.02, -0.15)), 0.012, 0.004,
                                material("bone", 0.1), verts=3))                                   # the blade
    hand_l = b.hand("L")
    pale = material("bone", -0.1)
    gull = hand_l + Vector((-0.06, -0.02, -0.07))
    b.parts["ArmL"].append(ball(0.035, gull, pale, scale=(0.8, 1.6, 0.8), segments=5, rings=3))     # body
    b.parts["ArmL"].append(ball(0.022, gull + Vector((0, -0.05, 0.025)), pale, segments=5, rings=3))  # head
    b.parts["ArmL"].append(block((0.11, 0.035, 0.008), gull + Vector((0, 0.005, 0.02)), pale))        # wings
    b.head_rest = (math.radians(18), 0, 0)  # down at his hands
    _unmoored_seat(b, "tussock")
    # The lantern stood lit on the tussock's shoulder at his left hand.
    b.parts["Stool"].append(limb((0.5, -0.02, 0.0), (0.5, -0.02, 0.2), 0.2, 0.16, material("moss", -0.45), verts=6))
    _ship_lantern(b.parts["Stool"], Vector((0.5, -0.02, 0.2)), lit=True)
    assemble(b, "dunstan_seated_cord" if cord else "dunstan_seated", scale=1.08)


def build_wenna() -> None:
    _wenna(brass=True)


def build_wenna_nobrass() -> None:
    """Wenna once she has given her answer (Day 44): the mouthpiece off its cord and in the
    Wakebearer's satchel, or burned in the Wrack. The cord hangs bare, and her right hand has come
    up off her knee to where the brass was."""
    _wenna(brass=False)


def _wenna(brass: bool) -> None:
    """Wenna Garrow, lane-warden of Wrackholm (eighties): she keeps the lane-house and its answering
    horn and swears the Tidewrights' masters (she swore Oda). Sits by the lashed horn on a coil of old
    hawser: a long tide-dark guild coat buttoned to the chin, a bone-white knitted shawl crossed over
    it, white hair in a knot under a black wool cap, big knuckled hands on her knees, a brass
    warden's mouthpiece on a cord at her neck (the horn's own is lashed)."""
    reset_scene()
    b = Body(seated=True, build=0.95)
    coat = material("abyss", -0.25)
    skin = material("driftwood", -0.05)
    base_body(b, skin, coat, material("ink", 0.1), coat)
    t = b.parts["Torso"]
    # The coat's long skirt over the knees, buttoned to the chin.
    t.append(limb((0, -0.02, b.hip - 0.02), (0, -0.02, b.waist + 0.1), 0.3, 0.27, coat, verts=8))
    b.parts["LegL"].append(block((0.5, 0.4, 0.04), (-0.12, -0.2, b.hip + 0.08), coat, rot=(0.05, 0, 0)))
    b.parts["LegL"].append(block((0.5, 0.04, 0.32), (-0.12, -0.41, b.hip - 0.08), coat, rot=(-0.12, 0, 0)))
    for z in (0.78, 0.9, 1.02):
        t.append(ball(0.022, (0, -0.25, z), material("ember", -0.4), segments=4, rings=3))
    t.append(ring(0.17, b.shoulder + 0.05, 0.1, coat))                                     # buttoned collar
    shawl = material("bone", -0.25)
    t.append(ball(0.33, (0, 0.02, b.shoulder - 0.07), shawl, scale=(1.0, 0.86, 0.62)))     # over the shoulders
    for s in (-1, 1):
        t.append(block((0.09, 0.04, 0.42), (s * 0.08, -0.25, b.shoulder - 0.25), shawl, rot=(0.12, 0, s * 0.45)))  # crossed ends
    # The warden's brass mouthpiece on a cord (the cord alone once she's given it).
    t.append(limb((0.1, -0.24, b.shoulder + 0.04), (0.03, -0.27, b.shoulder - 0.2), 0.008, 0.008, material("ink", 0.2), verts=3))
    if brass:
        t.append(limb((0.03, -0.28, b.shoulder - 0.2), (0.03, -0.29, b.shoulder - 0.29), 0.022, 0.035, material("ember", -0.3), verts=6))
    else:
        t.append(ball(0.012, (0.03, -0.275, b.shoulder - 0.21), material("ink", 0.2), segments=4, rings=3))  # the knot, empty
    h = b.parts["Head"]
    hair = material("bone", 0.05)
    h.append(ball(0.25, (0, 0.04, b.head + 0.02), hair, scale=(1.04, 1.0, 1.0)))
    h.append(ball(0.09, (0, 0.24, b.head + 0.0), hair))                                      # knot
    cap = material("ink", 0.15)
    h.append(ball(0.25, (0, 0.03, b.head + 0.1), cap, scale=(1.02, 1.02, 0.6)))
    h.append(ring(0.25, b.head + 0.05, 0.05, material("ink", 0.25)))
    for ex in (0.075, -0.075):
        h.append(block((0.08, 0.03, 0.02), (ex, -0.21, b.head + 0.07), hair))                 # white brows
    # Big knuckled hands on her knees.
    for side in ("L", "R"):
        b.parts["Arm" + side].append(ball(0.095, b.hand(side) + Vector((0, 0.0, 0.0)), skin, scale=(1.0, 1.1, 0.9), segments=6, rings=4))
    b.arm_rest["ArmL"] = (math.radians(-50), 0, math.radians(-6))
    b.arm_rest["ArmR"] = (math.radians(-50), 0, math.radians(6))
    if not brass:
        b.arm_rest["ArmR"] = (math.radians(-62), 0, math.radians(26))  # drawn in off her knee, toward where it hung
    b.head_rest = (math.radians(-6), 0, 0)  # looking out to sea
    # The seat: a coil of old hawser, turns showing.
    top = b.hip - 0.04
    rope = material("driftwood", -0.4)
    b.parts["Stool"].append(limb((0, 0.02, 0), (0, 0.02, top), 0.34, 0.32, rope, verts=9))
    for z in (0.08, 0.2, 0.32):
        b.parts["Stool"].append(limb((0, 0.02, z), (0, 0.02, z + 0.05), 0.35, 0.35, material("driftwood", -0.55), verts=9))
    b.parts["Stool"].append(limb((0.3, -0.18, 0.02), (0.55, -0.42, 0.02), 0.05, 0.05, rope, verts=5))  # the end
    assemble(b, "wenna" if brass else "wenna_nobrass", scale=0.95)


def build_jory() -> None:
    """Jory Pask, a Wrackholm salvager (nineteen): stripping the copper off the Gannet, his brother's
    boat, because the yard keeps what the sea gives back. Lanky; a coal-red gansey with the sleeves
    shoved up, canvas trousers, a tarred leather apron, sea boots; a mop of dark hair, bare-headed;
    a pry bar hanging from his right hand; a lead salvage tag and a hammer at his belt."""
    reset_scene()
    b = Body(build=0.92)
    gansey = material("coal", -0.3)
    skin = material("driftwood", 0.15)
    base_body(b, skin, material("driftwood", -0.35), material("ink", 0.05), gansey)
    t = b.parts["Torso"]
    apron = material("coal", -0.6)
    t.append(block((0.34, 0.04, 0.52), (0, -0.25, b.waist - 0.2), apron))                    # apron skirt
    t.append(block((0.26, 0.04, 0.24), (0, -0.26, b.waist + 0.2), apron))                    # bib
    t.append(ring(0.27, b.waist + 0.04, 0.05, material("driftwood", -0.5)))                  # belt
    t.append(block((0.07, 0.02, 0.05), (0.2, -0.27, b.waist - 0.04), material("slate", 0.05)))  # lead tag
    t.append(limb((-0.22, -0.2, b.waist + 0.0), (-0.22, -0.2, b.waist - 0.22), 0.02, 0.02, material("driftwood", -0.2), verts=4))  # hammer haft
    t.append(block((0.1, 0.05, 0.05), (-0.22, -0.2, b.waist + 0.0), material("ink", 0.2)))   # hammer head
    for side in ("L", "R"):
        hand = b.hand(side)
        b.parts["Arm" + side].append(limb(hand + Vector((0, 0, 0.24)), hand + Vector((0, 0, 0.06)), 0.074, 0.068, skin))
        b.parts["Arm" + side].append(limb(hand + Vector((0, 0, 0.29)), hand + Vector((0, 0, 0.23)), 0.095, 0.095, gansey))
    for side, x in (("L", 0.12), ("R", -0.12)):
        b.parts["Leg" + side].append(limb((x, 0, 0.08), (x, 0, 0.36), 0.095, 0.1, material("ink", 0.08)))  # sea boots
    h = b.parts["Head"]
    hair = material("ink", 0.3)
    h.append(ball(0.26, (0, 0.04, b.head + 0.06), hair, scale=(1.05, 1.02, 0.85)))
    for fx, fz in ((0.08, 0.12), (-0.05, 0.14)):                                              # fringe, fallen over the brow
        h.append(ball(0.075, (fx, -0.16, b.head + fz), hair, scale=(1.3, 0.7, 1.0), segments=5, rings=3))
    # A mop, not a cap: a shaggy rim of clumps over the ears and nape, a tuft standing up at the crown.
    for a, r, z, size in ((0.1, 0.25, 0.04, 0.07), (0.7, 0.24, 0.1, 0.075), (1.3, 0.23, 0.02, 0.07),
                          (1.9, 0.24, 0.09, 0.075), (2.5, 0.24, 0.0, 0.07), (3.05, 0.25, 0.06, 0.065),
                          (1.6, 0.13, 0.22, 0.055)):
        h.append(ball(size, (math.cos(a) * r, math.sin(a) * r + 0.04, b.head + z), hair, segments=5, rings=3))
    # The pry bar: iron, hooked at the foot, hanging from the right hand.
    hand = b.hand("R")
    iron = material("ink", 0.2)
    b.parts["ArmR"].append(limb(hand + Vector((0, -0.03, 0.06)), hand + Vector((0, -0.05, -0.6)), 0.018, 0.018, iron, verts=5))
    b.parts["ArmR"].append(limb(hand + Vector((0, -0.05, -0.6)), hand + Vector((0, -0.14, -0.66)), 0.018, 0.012, iron, verts=4))
    b.arm_rest["ArmR"] = (math.radians(-6), 0, math.radians(-4))
    b.arm_rest["ArmL"] = (0, 0, math.radians(8))
    b.head_rest = (math.radians(4), 0, math.radians(-6))
    assemble(b, "jory", scale=1.04)


# --- Wrackholm's yard folk (Day 50): no names, no talk; they came out for the lighting -------

def build_yard_smock() -> None:
    """A Wrackholm yard hand come out of the lane-house for the lighting (old): broad and short, a
    tide-blue oilskin smock to the knee over a gansey, a coal-red knitted cap, a grey beard cut
    square; the cup he brought out from the fire still in his right hand, not drunk from."""
    _yard_smock(mallet=False)


def build_yard_smock_mallet() -> None:
    """The same yard hand back at work once the horn has answered the light: caulking a seam in the
    sorted timber, a wooden mallet in the left hand and a caulking iron in the right."""
    _yard_smock(mallet=True)


def _yard_smock(mallet: bool) -> None:
    reset_scene()
    b = Body(build=1.08)
    smock = material("tide", -0.35)
    skin = material("driftwood", 0.05)
    base_body(b, skin, material("abyss", -0.1), material("ink", 0.05), smock)
    t = b.parts["Torso"]
    t.append(ring(0.1, b.shoulder + 0.03, 0.06, material("slate", -0.45)))                    # gansey neck
    t.append(limb((0, 0, 0.36), (0, 0, b.waist + 0.1), 0.34, 0.28, smock, verts=8))          # smock skirt
    t.append(ball(0.27, (0, 0.0, b.shoulder - 0.05), smock, scale=(1.05, 0.85, 0.5)))          # yoke
    t.append(block((0.12, 0.03, 0.12), (0.0, -0.27, b.waist + 0.22), material("tide", -0.55)))  # kangaroo pocket
    t.append(ring(0.29, b.waist - 0.02, 0.04, material("ink", 0.12)))                          # lanyard belt
    for side, x in (("L", 0.12), ("R", -0.12)):
        b.parts["Leg" + side].append(limb((x, 0, 0.08), (x, 0, 0.34), 0.095, 0.1, material("ink", 0.08)))  # sea boots
    h = b.parts["Head"]
    cap = material("coal", -0.2)
    h.append(ball(0.25, (0, 0.02, b.head + 0.09), cap, scale=(1.0, 1.0, 0.7)))
    h.append(ring(0.25, b.head + 0.05, 0.06, material("coal", -0.35)))                         # turned-up rim
    beard = material("silverfog", -0.1)
    h.append(ball(0.15, (0, -0.15, b.head - 0.12), beard, scale=(1.25, 0.75, 1.0)))
    h.append(block((0.2, 0.08, 0.1), (0, -0.19, b.head - 0.2), beard))                           # cut square
    if mallet:
        wood = material("driftwood", -0.15)
        iron = material("ink", 0.2)
        hand = b.hand("L")
        b.parts["ArmL"].append(limb(hand + Vector((0, 0, 0.04)), hand + Vector((0, -0.02, -0.24)), 0.022, 0.02, wood, verts=5))
        b.parts["ArmL"].append(limb(hand + Vector((-0.08, -0.02, -0.26)), hand + Vector((0.08, -0.02, -0.26)), 0.06, 0.06, wood, verts=6))
        hand = b.hand("R")
        b.parts["ArmR"].append(limb(hand + Vector((0, 0.02, 0.06)), hand + Vector((0, -0.06, -0.16)), 0.016, 0.016, iron, verts=4))
        b.parts["ArmR"].append(block((0.07, 0.015, 0.05), hand + Vector((0, -0.07, -0.19)), iron))  # the iron's blade
        b.arm_rest["ArmR"] = (math.radians(-28), 0, math.radians(-6))
        b.arm_rest["ArmL"] = (math.radians(-6), 0, math.radians(6))
        b.head_rest = (math.radians(14), 0, 0)  # down at the seam
        assemble(b, "yard_smock_mallet", scale=0.98)
        return
    # The cup, held out a little in front, upright against the arm's forward swing.
    hand = b.hand("R")
    up = Vector((0, -math.sin(math.radians(38)), math.cos(math.radians(38))))
    b.parts["ArmR"].append(limb(hand + up * 0.07, hand + up * 0.2, 0.055, 0.062, material("bone", -0.2), verts=6))
    b.arm_rest["ArmR"] = (math.radians(-38), 0, math.radians(12))
    b.arm_rest["ArmL"] = (math.radians(-4), 0, math.radians(5))
    b.head_rest = (math.radians(-6), 0, 0)  # up at the light
    assemble(b, "yard_smock", scale=0.98)


def build_yard_shawl() -> None:
    """A yard woman come out for the lighting (middle years): a long slate skirt and a tarred work
    apron, a moss shawl pulled up over her head and held shut, her arms folded under it against
    the cold off the Teeth."""
    reset_scene()
    b = Body(build=0.96)
    dress = material("slate", -0.3)
    shawl = material("moss", -0.15)
    skin = material("driftwood", 0.2)
    base_body(b, skin, dress, material("ink", 0.12), dress, sleeves=shawl)
    t = b.parts["Torso"]
    t.append(limb((0, 0, 0.1), (0, 0, b.waist + 0.06), 0.33, 0.25, dress, verts=8))            # skirt to the boots
    t.append(block((0.3, 0.04, 0.5), (0, -0.27, b.waist - 0.16), material("coal", -0.6)))       # tarred apron
    t.append(ball(0.34, (0, 0.03, b.shoulder - 0.06), shawl, scale=(1.0, 0.9, 0.75)))           # shawl over the shoulders
    t.append(limb((0, 0.18, b.shoulder - 0.05), (0, 0.24, b.shoulder - 0.5), 0.12, 0.0, shawl, verts=4))  # point down the back
    h = b.parts["Head"]
    h.append(ball(0.27, (0, 0.1, b.head + 0.06), shawl, scale=(1.08, 1.05, 1.05)))             # shawl up over the head, face clear
    h.append(ball(0.09, (0, -0.12, b.head + 0.14), material("bone", -0.15), scale=(1.9, 0.9, 0.6)))  # grey hair at the brow
    # Arms folded: forearms forward and in, the hands meeting under the shawl's fold.
    b.arm_rest["ArmL"] = (math.radians(-62), 0, math.radians(-30))
    b.arm_rest["ArmR"] = (math.radians(-58), 0, math.radians(30))
    b.parts["Torso"].append(ball(0.16, (0, -0.24, b.shoulder - 0.36), shawl, scale=(1.6, 0.6, 0.6)))  # the fold over the arms
    b.head_rest = (math.radians(-4), 0, math.radians(3))
    assemble(b, "yard_shawl", scale=0.95)


def build_yard_lad() -> None:
    """A yard lad (eleven or so) at the edge of the shingle: a tide-blue gansey too big for him, the
    sleeves rolled, bare-headed with a shock of fair hair; a glass float off the come-home pile
    held against his chest in both hands."""
    reset_scene()
    b = Body(build=0.86)
    gansey = material("tide", -0.1)
    skin = material("driftwood", 0.25)
    base_body(b, skin, material("driftwood", -0.4), material("ink", 0.1), gansey)
    t = b.parts["Torso"]
    t.append(limb((0, 0, b.hip - 0.12), (0, 0, b.hip + 0.06), 0.27, 0.26, gansey, verts=8))   # gansey hanging long
    for side in ("L", "R"):
        hand = b.hand(side)
        b.parts["Arm" + side].append(limb(hand + Vector((0, 0, 0.18)), hand + Vector((0, 0, 0.12)), 0.095, 0.095, gansey))  # rolled cuff
    h = b.parts["Head"]
    hair = material("kindle", -0.2)
    h.append(ball(0.26, (0, 0.03, b.head + 0.07), hair, scale=(1.08, 1.05, 0.85)))
    h.append(ball(0.09, (-0.06, -0.17, b.head + 0.15), hair, scale=(2.0, 1.0, 0.8)))
    # The float: green glass in a net of tarred cord, held to his chest (on the torso, so it stays put).
    glass = material("moss", 0.25)
    centre = Vector((0, -0.31, b.shoulder - 0.24))
    t.append(ball(0.11, centre, glass, segments=8, rings=6))
    cord = material("ink", 0.15)
    t.append(ring(0.115, centre.z, 0.02, cord, y=centre.y))
    t.append(limb(centre + Vector((0, 0, -0.12)), centre + Vector((0, 0, 0.12)), 0.012, 0.012, cord, verts=4))
    b.arm_rest["ArmL"] = (math.radians(-48), 0, math.radians(-26))
    b.arm_rest["ArmR"] = (math.radians(-48), 0, math.radians(26))
    b.head_rest = (math.radians(-8), 0, 0)
    assemble(b, "yard_lad", scale=0.8)


def build_ottie() -> None:
    """Ottie Swale at the Northing (Day 53): the fourth collier who went up after the Lamp, keeping a
    charcoal fire in the Keepers' fire-basket for the three who went down to the far shore. Lean and
    restless (forties), bare-headed (his cap is on the stair's waymark) with cropped dark hair gone grey
    at the temples and a short black beard; a sacking smock to mid-thigh, rope belt, a coal-red
    neckerchief; soot to the elbows; no boots (they're on his seat by the cold hut) — his feet bound in
    sacking and cord. A fire iron in his right hand. Half-Hushed: the hem and the right sleeve silvered."""
    _ottie(seated=False)


def build_ottie_cap() -> None:
    """As `ottie`, his felt cap back on (the player brought it up the road): crooked cord and all."""
    _ottie(seated=False, cap=True)


def build_ottie_home() -> None:
    """Ottie home (Day 53): on the log seat outside his own hut in the colliers' clearing, his boots on
    at last, forearms on his knees, bare-headed."""
    _ottie(seated=True, boots=True)


def build_ottie_home_cap() -> None:
    """As `ottie_home`, wearing his felt cap (off the seat where Hob set it, or brought up the road)."""
    _ottie(seated=True, boots=True, cap=True)


def build_ottie_home_unshod() -> None:
    """Ottie home without his boots (they burned in the Ridge Light, or the player still carries them):
    on the bare log seat with his feet still bound in sacking."""
    _ottie(seated=True, boots=False)


def build_ottie_home_unshod_cap() -> None:
    """As `ottie_home_unshod`, wearing the felt cap the player brought up the road."""
    _ottie(seated=True, boots=False, cap=True)


def _ottie(seated: bool, boots: bool = False, cap: bool = False) -> None:
    reset_scene()
    b = Body(seated=seated, build=0.95)
    smock = material("driftwood", -0.4)
    soot = material("ink", 0.12)
    skin = material("driftwood", 0.05)
    hem = material("silverfog", -0.2)
    sacking = material("driftwood", -0.2)
    feet = material("ink", 0.04) if boots else sacking
    base_body(b, skin, material("slate", -0.5), feet, smock, sleeves=soot)
    cord = material("driftwood", -0.55)
    for side, x in (("L", 0.12), ("R", -0.12)):
        leg = b.parts["Leg" + side]
        y = -0.43 if seated else -0.04
        if boots:  # sea-boot style legs up the shin
            top = 0.32 if seated else 0.3
            leg.append(limb((x, y + (0.05 if seated else 0.0), 0.08), (x, y + (0.05 if seated else 0.0), top), 0.09, 0.095, feet))
        else:      # sacking wound round the foot and ankle, bound with cord
            leg.append(ball(0.11, (x, y, 0.08), sacking, scale=(0.85, 1.25, 0.75), segments=6, rings=4))
            leg.append(limb((x - 0.08, y, 0.14), (x + 0.08, y, 0.14), 0.016, 0.016, cord, verts=4))
            leg.append(limb((x, y + 0.03, 0.12), (x, y + 0.03, 0.26), 0.08, 0.075, sacking, verts=6))
    t = b.parts["Torso"]
    if seated:
        t.append(limb((0, 0.0, b.hip - 0.06), (0, 0.0, b.waist + 0.06), 0.29, 0.26, smock, verts=8))
        b.parts["LegL"].append(block((0.5, 0.34, 0.05), (-0.12, -0.18, b.hip + 0.07), smock))
        b.parts["LegL"].append(block((0.5, 0.05, 0.12), (-0.12, -0.36, b.hip - 0.03), hem))
    else:
        # Sacking smock to mid-thigh, silvered at the hem.
        t.append(limb((0, 0.0, 0.44), (0, 0.0, b.waist + 0.06), 0.29, 0.26, smock, verts=8))
        t.append(limb((0, 0.0, 0.4), (0, 0.0, 0.48), 0.3, 0.3, hem, verts=8))
    t.append(ring(0.265, b.waist + 0.03, 0.04, material("driftwood", -0.15)))                 # rope belt
    t.append(ring(0.12, b.shoulder + 0.03, 0.06, material("coal", -0.1)))                     # neckerchief
    t.append(limb((0.03, -0.12, b.shoulder + 0.02), (0.06, -0.2, b.shoulder - 0.12), 0.035, 0.012, material("coal", -0.1), verts=4))
    for side in ("L", "R"):
        hand = b.hand(side)
        b.parts["Arm" + side].append(ball(0.09, hand, soot, scale=(0.95, 1.05, 1.15), segments=6, rings=4))
    # The fog has had his right sleeve: a silver band over the soot below the shoulder.
    r_top = Vector((-b.shoulder_x, 0, b.shoulder - 0.04))
    b.parts["ArmR"].append(limb(r_top + Vector((0, 0, -0.08)), r_top + Vector((0, 0, -0.22)), 0.09, 0.085, hem))
    h = b.parts["Head"]
    hair = material("ink", 0.2)
    h.append(ball(0.245, (0, 0.03, b.head + 0.05), hair, scale=(1.02, 1.0, 0.82)))              # cropped dark hair
    for sx in (0.215, -0.215):
        h.append(block((0.04, 0.12, 0.1), (sx, 0.0, b.head + 0.02), material("silverfog", -0.15)))  # grey at the temples
    h.append(ball(0.16, (0, -0.11, b.head - 0.14), hair, scale=(1.0, 0.7, 0.75)))                # short black beard
    h.append(block((0.09, 0.03, 0.04), (-0.07, -0.225, b.head + 0.13), soot))                    # soot smudge
    if cap:
        # The felt cap, black with charcoal dust, a coal-red band, and the cord he sewed on crooked.
        felt = material("driftwood", -0.6)
        h.append(ball(0.25, (0, 0.0, b.head + 0.1), felt, scale=(1.0, 1.0, 0.62)))
        h.append(ring(0.25, b.head + 0.04, 0.05, material("coal", -0.4)))
        h.append(block((0.3, 0.16, 0.025), (0, -0.25, b.head + 0.05), felt, rot=(math.radians(-12), 0, 0)))
        h.append(limb((0.18, -0.15, b.head + 0.08), (0.06, -0.22, b.head + 0.15), 0.012, 0.012, cord, verts=3))
    if seated:
        # Forearms on his knees, hands hanging together; head up, looking at nothing much.
        b.arm_rest["ArmL"] = (math.radians(-50), 0, math.radians(-12))
        b.arm_rest["ArmR"] = (math.radians(-50), 0, math.radians(12))
        b.head_rest = (math.radians(4), 0, 0)
        name = "ottie_home" + ("" if boots else "_unshod") + ("_cap" if cap else "")
        assemble(b, name)
        return
    # A fire iron in his right hand, point down, held a little out from his side.
    hand = b.hand("R")
    iron = material("slate", -0.5)
    b.parts["ArmR"].append(limb(hand + Vector((0, -0.04, 0.06)), hand + Vector((-0.04, -0.12, -0.7)), 0.016, 0.012, iron, verts=4))
    b.parts["ArmR"].append(limb(hand + Vector((-0.04, -0.12, -0.7)), hand + Vector((-0.04, -0.2, -0.76)), 0.014, 0.008, iron, verts=4))
    b.arm_rest["ArmR"] = (math.radians(-10), 0, math.radians(-8))
    b.arm_rest["ArmL"] = (math.radians(-4), 0, math.radians(6))
    b.head_rest = (math.radians(-4), 0, math.radians(-6))  # head up, a little aside: listening down the cliff
    assemble(b, "ottie_cap" if cap else "ottie")


def _held_lantern(b: Body, side: str = "R") -> None:
    """A Keeper's lantern held out by its bail in one hand (as Hob's): iron foot and cap, horn lit gold."""
    iron = material("slate", -0.45)
    hand = b.hand(side)
    arm = b.parts["Arm" + side]
    arm.append(limb(hand + Vector((0, -0.02, 0.02)), hand + Vector((0, -0.02, -0.1)), 0.01, 0.01, iron, verts=4))
    lamp = hand + Vector((0, -0.02, -0.36))
    arm.append(limb(lamp, lamp + Vector((0, 0, 0.02)), 0.075, 0.075, iron, verts=6))
    arm.append(limb(lamp + Vector((0, 0, 0.02)), lamp + Vector((0, 0, 0.17)), 0.06, 0.06, material("kindle", 0.0, emissive=True), verts=6))
    arm.append(limb(lamp + Vector((0, 0, 0.17)), lamp + Vector((0, 0, 0.24)), 0.08, 0.015, iron, verts=6))


def build_wenna_coll() -> None:
    """Wenna Coll on the far shore (Day 55): the collier who went down the Keepers' steps to wait for the
    Spire's boat. Fifties, big-handed and square; a sacking hood pulled up over her head and down over
    her shoulders like a cape, a long grey-black braid out of it over her left shoulder (its end gone
    silver), a dark smock to the shins, soot to the elbows. Sits on a folded sack at the end of the
    boat-stage with her forearms on her knees, looking out to sea for a boat."""
    _wenna_coll(seated=True)


def build_wenna_coll_lantern() -> None:
    """Wenna home from the far shore (Day 55, *The Far Shore*, up): standing in the colliers' clearing with
    a lantern the Lamp lit for her hearth off the warm side of the kept coal, held out by its bail, her
    hood pushed back off her head at last."""
    _wenna_coll(seated=False, lantern=True)


def _wenna_coll(seated: bool, lantern: bool = False) -> None:
    reset_scene()
    b = Body(seated=seated, build=1.05)
    smock = material("ink", 0.22)
    soot = material("ink", 0.1)
    skin = material("driftwood", -0.02)
    hem = material("silverfog", -0.2)
    sacking = material("driftwood", -0.35)
    base_body(b, skin, material("slate", -0.5), material("ink", 0.02), smock, sleeves=soot)
    t = b.parts["Torso"]
    if seated:
        t.append(limb((0, 0.0, b.hip - 0.06), (0, 0.0, b.waist + 0.06), 0.3, 0.27, smock, verts=8))
        b.parts["LegL"].append(block((0.5, 0.36, 0.05), (-0.12, -0.19, b.hip + 0.07), smock))
        b.parts["LegL"].append(block((0.5, 0.05, 0.3), (-0.12, -0.38, b.hip - 0.1), smock))
        b.parts["LegL"].append(block((0.5, 0.05, 0.08), (-0.12, -0.38, b.hip - 0.28), hem))
    else:
        # A dark smock to the shins, silvered at the hem.
        t.append(limb((0, 0.0, 0.2), (0, 0.0, b.waist + 0.06), 0.31, 0.27, smock, verts=8))
        t.append(limb((0, 0.0, 0.16), (0, 0.0, 0.24), 0.32, 0.31, hem, verts=8))
    t.append(ring(0.275, b.waist + 0.03, 0.04, material("driftwood", -0.15)))                 # rope belt
    for side in ("L", "R"):
        b.parts["Arm" + side].append(ball(0.095, b.hand(side), soot, scale=(1.0, 1.1, 1.15), segments=6, rings=4))
    h = b.parts["Head"]
    hair = material("ink", 0.3)
    h.append(ball(0.25, (0, 0.03, b.head + 0.04), hair, scale=(1.03, 1.0, 0.9)))
    # The braid over her left shoulder, down her front; its end silvered.
    braid = [Vector((0.16, -0.06, b.head - 0.14)), Vector((0.2, -0.2, b.shoulder - 0.02)), Vector((0.17, -0.27, b.shoulder - 0.24))]
    for a, c in zip(braid, braid[1:]):
        t.append(limb(a, c, 0.045, 0.04, hair, verts=5))
    t.append(limb(braid[-1], braid[-1] + Vector((-0.01, -0.01, -0.1)), 0.04, 0.02, hem, verts=5))
    for ex in (0.075, -0.075):
        h.append(block((0.08, 0.03, 0.025), (ex, -0.215, b.head + 0.075), material("ink", 0.35)))  # dark brows
    if not lantern:
        # The sacking hood up over her head and down over her shoulders like a cape.
        h.append(ball(0.29, (0, 0.1, b.head + 0.05), sacking, scale=(1.05, 1.0, 1.0)))
        h.append(block((0.46, 0.06, 0.08), (0, -0.17, b.head + 0.2), sacking))                  # the hood's brow
        t.append(ball(0.34, (0, 0.04, b.shoulder - 0.05), sacking, scale=(1.0, 0.85, 0.55)))
    else:
        # The hood pushed back: a heap of sacking on her shoulders behind the neck.
        h.append(ball(0.27, (0, 0.16, b.head - 0.1), sacking, scale=(1.0, 0.7, 0.8)))
        t.append(ball(0.33, (0, 0.06, b.shoulder - 0.05), sacking, scale=(1.0, 0.85, 0.5)))
    if seated:
        # On a folded sack; forearms on her knees, hands loosely together; head up, out to sea.
        b.parts["Stool"].append(block((0.56, 0.5, b.hip - 0.06), (0, 0.02, (b.hip - 0.06) / 2), sacking))
        b.parts["Stool"].append(block((0.58, 0.04, 0.06), (0, -0.23, b.hip - 0.1), material("driftwood", -0.55)))
        b.arm_rest["ArmL"] = (math.radians(-52), 0, math.radians(-12))
        b.arm_rest["ArmR"] = (math.radians(-52), 0, math.radians(12))
        b.head_rest = (math.radians(-5), 0, 0)
        assemble(b, "wenna_coll")
        return
    _held_lantern(b, "R")
    b.arm_rest["ArmR"] = (math.radians(-36), 0, math.radians(-4))
    b.arm_rest["ArmL"] = (math.radians(-4), 0, math.radians(6))
    b.head_rest = (math.radians(-4), 0, 0)
    assemble(b, "wenna_coll_lantern")


def build_abe() -> None:
    """Abe Dray (Day 55), the elder of the Dray brothers, colliers who never once agreed whose rake it
    was: big and broad, bald under a soot-smudged crown with a short rust-red beard, a sacking smock
    with the sleeves rolled to the elbow over soot-black forearms, a coal-red sash for a belt, hands
    on his hips. Half-Hushed: the smock's hem silvered."""
    reset_scene()
    b = Body(build=1.2)
    smock = material("driftwood", -0.5)
    soot = material("ink", 0.12)
    skin = material("driftwood", 0.02)
    hem = material("silverfog", -0.2)
    base_body(b, skin, material("slate", -0.45), material("ink", 0.0), smock, sleeves=smock)
    t = b.parts["Torso"]
    t.append(limb((0, 0.0, 0.42), (0, 0.0, b.waist + 0.06), 0.33, 0.31, smock, verts=8))
    t.append(limb((0, 0.0, 0.38), (0, 0.0, 0.46), 0.34, 0.34, hem, verts=8))
    t.append(ring(0.32, b.waist + 0.04, 0.07, material("coal", -0.15)))                       # the sash
    t.append(limb((-0.2, -0.25, b.waist + 0.02), (-0.24, -0.27, b.waist - 0.22), 0.03, 0.02, material("coal", -0.15), verts=4))
    for side in ("L", "R"):
        hand = b.hand(side)
        arm = b.parts["Arm" + side]
        arm.append(limb(hand + Vector((0, 0, 0.26)), hand + Vector((0, 0, 0.02)), 0.08, 0.075, soot))  # bare, sooty forearm
        arm.append(ball(0.1, hand, soot, scale=(1.0, 1.1, 1.1), segments=6, rings=4))
        x = hand.x
        arm.append(limb(Vector((x, 0, hand.z + 0.27)), Vector((x, 0, hand.z + 0.33)), 0.095, 0.095, smock))  # rolled sleeve
    h = b.parts["Head"]
    h.append(ball(0.17, (0, -0.1, b.head - 0.13), material("coal", -0.25), scale=(1.1, 0.75, 0.8)))  # rust-red beard
    h.append(block((0.12, 0.03, 0.05), (0.07, -0.222, b.head + 0.13), soot))                   # soot on the crown
    for ex in (0.075, -0.075):
        h.append(block((0.09, 0.03, 0.03), (ex, -0.215, b.head + 0.075), material("coal", -0.35)))
    # Hands on his hips: elbows out.
    b.arm_rest["ArmL"] = (math.radians(-8), math.radians(-10), math.radians(38))
    b.arm_rest["ArmR"] = (math.radians(-8), math.radians(10), math.radians(-38))
    b.head_rest = (math.radians(-4), 0, 0)
    assemble(b, "abe", scale=1.03)


def build_tolly() -> None:
    """Tolly Dray (Day 55), the younger: slight and long-armed, a moss-green knitted cap with a long tail
    hanging down his back, a scarf wound twice, a patched sacking smock, soot to the wrists, clean-shaven
    and sharp-nosed; his arms folded (he's waiting to be proved right). Half-Hushed: the cap's tail silvered."""
    _tolly(lantern=False)


def build_tolly_lantern() -> None:
    """Tolly home from the far shore (Day 55, *The Far Shore*, up), carrying the Drays' one lantern off the
    Lamp's coal (they couldn't agree who'd carry it, so he does)."""
    _tolly(lantern=True)


def _tolly(lantern: bool) -> None:
    reset_scene()
    b = Body(build=0.85)
    smock = material("driftwood", -0.32)
    soot = material("ink", 0.12)
    skin = material("driftwood", 0.08)
    base_body(b, skin, material("slate", -0.4), material("ink", 0.05), smock, sleeves=smock)
    t = b.parts["Torso"]
    t.append(limb((0, 0.0, 0.4), (0, 0.0, b.waist + 0.06), 0.27, 0.24, smock, verts=8))
    t.append(block((0.12, 0.04, 0.12), (-0.1, -0.25, b.waist + 0.15), material("driftwood", -0.55)))  # a patch
    t.append(ring(0.235, b.waist + 0.03, 0.04, material("driftwood", -0.15)))
    scarf = material("moss", -0.35)
    t.append(ring(0.13, b.shoulder + 0.02, 0.07, scarf))
    t.append(ring(0.125, b.shoulder + 0.08, 0.05, scarf))
    for side in ("L", "R"):
        b.parts["Arm" + side].append(ball(0.085, b.hand(side), soot, scale=(0.95, 1.05, 1.1), segments=6, rings=4))
    h = b.parts["Head"]
    cap = material("moss", -0.2)
    h.append(ball(0.25, (0, 0.02, b.head + 0.08), cap, scale=(1.02, 1.02, 0.75)))
    h.append(ring(0.25, b.head + 0.03, 0.06, material("moss", -0.4)))
    tail = [Vector((0, 0.2, b.head + 0.14)), Vector((0, 0.32, b.head - 0.05)), Vector((0.02, 0.3, b.head - 0.3))]
    for a, c in zip(tail, tail[1:]):
        h.append(limb(a, c, 0.06, 0.045, cap, verts=5))
    h.append(limb(tail[-1], tail[-1] + Vector((0, -0.01, -0.1)), 0.045, 0.02, material("silverfog", -0.2), verts=5))
    for ex in (0.075, -0.075):
        h.append(block((0.08, 0.03, 0.02), (ex, -0.215, b.head + 0.07), material("ink", 0.3)))
    if lantern:
        _held_lantern(b, "L")
        b.arm_rest["ArmL"] = (math.radians(-34), 0, math.radians(4))
        b.arm_rest["ArmR"] = (math.radians(-4), 0, math.radians(-6))
        assemble(b, "tolly_lantern")
        return
    # Arms folded across his chest: both forearms brought in and up.
    b.arm_rest["ArmL"] = (math.radians(-70), 0, math.radians(-38))
    b.arm_rest["ArmR"] = (math.radians(-64), 0, math.radians(40))
    b.head_rest = (math.radians(-3), 0, math.radians(8))
    assemble(b, "tolly")


BUILDERS = [build_wakebearer, build_mara, build_pell, build_aldous, build_aldous_seated, build_tam, build_hesk, build_oda, build_bram,
            build_hob, build_hob_seated, build_hob_lantern, build_lamp, build_lamp_named, build_hesper, build_corran, build_corran_nocord,
            build_unmoored_shawl, build_unmoored_coat, build_dunstan, build_dunstan_seated,
            build_dunstan_seated_cord, build_dunstan_lantern, build_dunstan_home, build_dunstan_turning,
            build_wenna, build_wenna_nobrass, build_jory,
            build_yard_smock, build_yard_smock_mallet, build_yard_shawl, build_yard_lad,
            build_ottie, build_ottie_cap, build_ottie_home, build_ottie_home_cap, build_ottie_home_unshod,
            build_ottie_home_unshod_cap, build_wenna_coll, build_wenna_coll_lantern, build_abe, build_tolly,
            build_tolly_lantern]

if __name__ == "__main__":
    import sys
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
