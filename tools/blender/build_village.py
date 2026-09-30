"""Builds Saltmarrow's village buildings and wayside pieces (Day 14) into the dressing kit.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_village.py
    .tools/bin/blender-py tools/blender/build_village.py [house_tall house_porch gate_post]

Outputs assets/models/dressing/<name>.glb with the dressing kit's conventions (origin at the
base centre, flat-shaded, palette colours and tonal shades, Blender -Y = Godot +Z = the
front, merged by material). The houses share stilt_house.glb's 2.6 × 2.2 m wall box on a
deck at 1.0 m, so the region `collider` of a stilt house fits them; extras (the porch and its
steps) take their own boxes via the prop's `colliders` field (docs/TECH.md).
"""
import math
import os
import random
import sys

import bpy  # must be imported before bmesh/mathutils when running as the bpy module)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dressing as bd  # noqa: E402  (materials, primitives, merge + export)
import build_props as bp  # noqa: E402

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod


def _stilts(half_x: float, half_y: float, top: float, material, rng) -> None:
    for x in (-half_x, half_x):
        for y in (-half_y, half_y):
            cyl("Stilt", 0.1, 0.085, top, 5, (x, y, 0), material, rng.uniform(0, 1))
    for y in (-half_y, half_y):  # cross-braces between the front and back stilt pairs
        beam("Brace", (-half_x, y, 0.1), (half_x, y, top - 0.12), 0.05, material)


def _boards(width: float, depth: float, height: float, z: float, shades, material_name: str, rng,
            board: float = 0.26) -> None:
    """Vertical boards on the front and back faces (±Y) of a wall box, so the flat wall reads
    as planked; alternate boards take the given shades."""
    n = max(2, int(width / board))
    step = width / n
    for side in (-1, 1):
        for i in range(n):
            x = -width / 2 + step * (i + 0.5)
            h = height + rng.uniform(-0.03, 0.03)
            box("Board", (step - 0.02, 0.03, h), (x, side * (depth / 2 + 0.012), z),
                mat(material_name, shades[i % len(shades)]))


def _shingled_roof(width: float, depth: float, height: float, z: float, material_name: str,
                   rows: int = 3) -> None:
    """A gable roof (ridge along Y) with `rows` stepped courses of shingles: stacked prisms,
    each a little smaller and alternately shaded, so the slope reads as layered."""
    for r in range(rows):
        f = r / rows
        shade = (-0.1, -0.25)[r % 2]
        bp.prism(f"Roof{r}", width * (1.0 - f), depth, height * (1.0 - f), (0, 0, z + height * f * 0.98),
                 mat(material_name, shade))


def _join(prefix: str) -> bpy.types.Object:
    """Joins every object named `prefix`* into one with its transform applied (at the origin,
    rotation mode XYZ) so it can be placed and turned as a whole."""
    parts = [o for o in bpy.context.scene.objects if o.name.startswith(prefix)]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(parts) > 1:
        bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.rotation_mode = "XYZ"
    return joined


def build_house_tall() -> None:
    """A narrow two-storey stilt house: slate-blue planked ground floor, a jettied upper floor
    in dark tarred boards, a steep pine-shingled roof, tide-blue shutters, a stovepipe and a
    side ladder. Deck at 1.0 m and walls 2.6 × 2.2 m like stilt_house; ~5.6 m tall."""
    bd.reset()
    rng = random.Random(31)
    _stilts(1.1, 0.9, 1.0, mat("slate", -0.3), rng)
    box("Deck", (3.0, 2.6, 0.12), (0, 0, 0.94), mat("driftwood", -0.25))
    box("Walls", (2.6, 2.2, 1.5), (0, 0, 1.06), mat("slate", 0.05))
    _boards(2.6, 2.2, 1.5, 1.06, (0.05, -0.08), "slate", rng)
    # Upper floor, jutting 0.15 m over the front and back on joists.
    for x in (-1.1, -0.37, 0.37, 1.1):
        box("Joist", (0.1, 2.6, 0.1), (x, 0, 2.52), mat("driftwood", -0.5))
    box("Upper", (2.6, 2.5, 1.25), (0, 0, 2.62), mat("driftwood", -0.5))
    _boards(2.6, 2.5, 1.25, 2.62, (-0.5, -0.6), "driftwood", rng, board=0.22)
    _shingled_roof(3.1, 2.9, 1.9, 3.87, "pine")
    box("Ridge", (0.14, 3.0, 0.1), (0, 0, 5.72), mat("driftwood", -0.5))
    rod("Stovepipe", (0.75, 0.7, 4.3), (0.75, 0.7, 5.9), 0.1, mat("ink", 0.2), verts=6)
    cyl("PipeCap", 0.18, 0.06, 0.12, 6, (0.75, 0.7, 5.9), mat("ink", 0.2))
    # Front (-Y): door below, one window each floor with open shutters.
    box("Door", (0.62, 0.06, 1.12), (-0.55, -1.13, 1.06), mat("ink", 0.2))
    box("DoorFrame", (0.78, 0.05, 0.08), (-0.55, -1.14, 2.18), mat("driftwood", -0.25))
    for (x, z, w, h) in ((0.55, 1.55, 0.5, 0.45), (0.0, 3.0, 0.55, 0.45)):
        y = -1.14 if z < 2.5 else -1.28
        box("Window", (w, 0.06, h), (x, y, z), mat("kindle", 0.0, emissive=True))
        box("Sill", (w + 0.16, 0.12, 0.05), (x, y - 0.03, z - 0.05), mat("driftwood", -0.25))
        for s in (-1, 1):
            box("Shutter", (w * 0.5, 0.04, h + 0.04), (x + s * (w * 0.75 + 0.02), y - 0.02, z - 0.02),
                mat("tide", -0.15))
    # Side ladder to the deck (+X side).
    for yy in (-0.35, 0.05):
        beam("LadderRail", (1.62, yy, 0.0), (1.52, yy, 1.1), 0.05, mat("driftwood", -0.25))
    for i, z in enumerate((0.25, 0.5, 0.75)):
        beam(f"Rung{i}", (1.6 - z * 0.08, -0.35, z), (1.6 - z * 0.08, 0.05, z), 0.04, mat("driftwood", -0.25))
    bd.export("house_tall")


def build_house_porch() -> None:
    """Mara's house: the village stilt house grown a porch. Warm planked walls, a coal roof,
    a centred door onto a 1.3 m front porch with side rails and steps down to the ground,
    a window box of moss, a lantern hook by the door and a net drying over the rail.
    Walls/deck as stilt_house; the porch reaches to y -2.4 and the steps to -3.25."""
    bd.reset()
    rng = random.Random(17)
    _stilts(1.1, 0.9, 1.0, mat("slate", -0.3), rng)
    box("Deck", (3.0, 2.6, 0.12), (0, 0, 0.94), mat("driftwood", -0.2))
    box("Walls", (2.6, 2.2, 1.6), (0, 0, 1.06), mat("driftwood", 0.05))
    _boards(2.6, 2.2, 1.6, 1.06, (0.05, -0.08), "driftwood", rng)
    for x in (-1.32, 1.32):
        box("Corner", (0.1, 2.3, 1.6), (x, 0, 1.06), mat("driftwood", -0.35))
    _shingled_roof(3.2, 2.9, 1.2, 2.66, "coal", rows=2)
    box("Chimney", (0.36, 0.36, 1.0), (-0.8, 0.6, 2.9), mat("slate", -0.1))
    box("ChimneyCap", (0.46, 0.46, 0.08), (-0.8, 0.6, 3.9), mat("slate", -0.3))
    # Porch: joists on two more stilts, planks, side rails with posts, and the steps.
    for x in (-1.1, 1.1):
        cyl("PorchStilt", 0.09, 0.08, 1.0, 5, (x, -2.3, 0), mat("slate", -0.3), rng.uniform(0, 1))
    for i in range(6):
        y = -1.3 - 0.2 - i * 0.2
        box(f"PorchPlank{i}", (2.4 + rng.uniform(-0.05, 0.05), 0.18, 0.07), (rng.uniform(-0.03, 0.03), y, 0.99),
            mat("driftwood", (-0.2, -0.08)[i % 2]))
    for x in (-1.15, 1.15):
        for y in (-1.4, -2.35):
            rod("RailPost", (x, y, 1.05), (x, y, 1.9), 0.045, mat("driftwood", -0.35), verts=4)
        beam("Rail", (x, -1.3, 1.85), (x, -2.4, 1.85), 0.07, mat("driftwood", -0.35))
    beam("FrontRail", (0.55, -2.35, 1.85), (1.18, -2.35, 1.85), 0.07, mat("driftwood", -0.35))
    beam("FrontRail", (-1.18, -2.35, 1.85), (-0.55, -2.35, 1.85), 0.07, mat("driftwood", -0.35))
    for s in range(4):  # steps from the porch (1.05) down to the ground, 0.26 m each
        z = 1.05 - (s + 1) * 0.26
        box(f"Step{s}", (1.0, 0.3, 0.06), (0, -2.55 - s * 0.24, z), mat("driftwood", -0.2))
    for x in (-0.52, 0.52):
        beam("Stringer", (x, -2.4, 1.02), (x, -3.35, 0.0), 0.07, mat("driftwood", -0.35), width=0.1)
    # Door, window with a box of moss, lantern hook.
    box("Door", (0.66, 0.06, 1.16), (0, -1.13, 1.06), mat("ink", 0.2))
    box("Lintel", (0.84, 0.08, 0.1), (0, -1.15, 2.22), mat("driftwood", -0.35))
    box("Knocker", (0.08, 0.04, 0.08), (0.2, -1.17, 1.66), mat("ember", -0.3))
    box("Window", (0.5, 0.06, 0.45), (0.78, -1.13, 1.62), mat("kindle", 0.0, emissive=True))
    box("WindowBox", (0.66, 0.2, 0.16), (0.78, -1.22, 1.38), mat("coal", -0.25))
    for i in range(4):
        cyl("Moss", 0.08, 0.02, 0.16, 4, (0.54 + i * 0.16, -1.22, 1.52), mat("moss", (-0.1, 0.15)[i % 2]))
    box("Window2", (0.45, 0.06, 0.42), (-0.85, -1.13, 1.62), mat("kindle", 0.0, emissive=True))
    beam("LanternHook", (-0.5, -1.13, 2.0), (-0.5, -1.45, 2.0), 0.04, mat("ink", 0.2))
    # A net drying over the left porch rail.
    bd.net("PorchNet", 0.95, 0.6, (0, 0, 0), mat("slate", 0.1), spacing=0.14, sag=0.05)
    drape = _join("PorchNet")
    drape.rotation_euler.z = math.pi / 2
    drape.location = (-1.2, -1.88, 1.55)
    bd.export("house_porch")


def build_gate_post() -> None:
    """A wayside marker post (~1.7 m): a weathered, slightly leaning post with two coal-red
    lashings, a cap, and a cork float hung from a peg on a short line — the island's way of
    saying "the road goes on here". Replaces the procedural `post` at the exits."""
    bd.reset()
    wood = mat("driftwood", -0.2)
    rod("Post", (0, 0, 0), (0.03, 0.02, 1.62), 0.11, wood, verts=6, r_end=0.085)
    cyl("Cap", 0.12, 0.05, 0.12, 6, (0.03, 0.02, 1.62), mat("driftwood", -0.45))
    for z in (0.95, 1.35):
        cyl("Lashing", 0.115, 0.115, 0.07, 6, (0.02, 0.01, z), mat("coal", -0.15))
    beam("Peg", (0.02, -0.05, 1.3), (0.02, -0.34, 1.34), 0.04, mat("driftwood", -0.4))
    beam("Line", (0.02, -0.3, 1.32), (0.02, -0.3, 0.98), 0.015, mat("driftwood", 0.2))
    cyl("Float", 0.1, 0.1, 0.2, 7, (0.02, -0.3, 0.8), mat("ember", -0.2))
    cyl("FloatBand", 0.105, 0.105, 0.05, 7, (0.02, -0.3, 0.875), mat("bone", -0.1))
    # A few stones heaped at the foot.
    rng = random.Random(8)
    for i in range(3):
        a = math.tau * i / 3 + 0.4
        bp.rock(f"Stone{i}", 0.12, (math.cos(a) * 0.16, math.sin(a) * 0.16, 0.04), mat("slate", rng.uniform(-0.2, 0.1)), rng)
    bd.export("gate_post")


BUILDERS = [build_house_tall, build_house_porch, build_gate_post]

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
