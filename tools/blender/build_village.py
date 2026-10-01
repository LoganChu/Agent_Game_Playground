"""Builds Saltmarrow's village buildings and wayside pieces (Day 14) into the dressing kit.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_village.py
    .tools/bin/blender-py tools/blender/build_village.py [house_tall house_porch gate_post house_stilt …]

Outputs assets/models/dressing/<name>.glb with the dressing kit's conventions (origin at the
base centre, flat-shaded, palette colours and tonal shades, Blender -Y = Godot +Z = the
front, merged by material). The houses share one 2.6 × 2.2 m wall box on a
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
            board: float = 0.26, skip=()) -> None:
    """Vertical boards on all four faces of a wall box, so the flat wall reads as planked from
    every side; alternate boards take the given shades. `skip` lists (face, index) boards to
    leave out (faces "-y", "+y", "-x", "+x") — a gap where a board has fallen off."""
    for face in ("-y", "+y", "-x", "+x"):
        along_x = face[1] == "y"
        span = width if along_x else depth
        n = max(2, int(span / board))
        step = span / n
        side = -1 if face[0] == "-" else 1
        for i in range(n):
            if (face, i) in skip:
                continue
            t = -span / 2 + step * (i + 0.5)
            h = height + rng.uniform(-0.03, 0.03)
            m = mat(material_name, shades[i % len(shades)])
            if along_x:
                box("Board", (step - 0.02, 0.03, h), (t, side * (depth / 2 + 0.012), z), m)
            else:
                box("Board", (0.03, step - 0.02, h), (side * (width / 2 + 0.012), t, z), m)


def _corner_posts(half_x: float, half_y: float, z: float, height: float, material) -> None:
    """Square posts at the four corners of a wall box, covering the board ends."""
    for x in (-half_x, half_x):
        for y in (-half_y, half_y):
            box("CornerPost", (0.12, 0.12, height), (x, y, z), material)


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
    side ladder. Deck at 1.0 m and walls 2.6 × 2.2 m like house_stilt; ~5.6 m tall."""
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
    _corner_posts(1.31, 1.11, 1.06, 1.5, mat("slate", -0.3))
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
    Walls/deck as house_stilt; the porch reaches to y -2.4 and the steps to -3.25."""
    bd.reset()
    rng = random.Random(17)
    _stilts(1.1, 0.9, 1.0, mat("slate", -0.3), rng)
    box("Deck", (3.0, 2.6, 0.12), (0, 0, 0.94), mat("driftwood", -0.2))
    box("Walls", (2.6, 2.2, 1.6), (0, 0, 1.06), mat("driftwood", 0.05))
    _boards(2.6, 2.2, 1.6, 1.06, (0.05, -0.08), "driftwood", rng)
    _corner_posts(1.31, 1.11, 1.06, 1.6, mat("driftwood", -0.35))
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


def _cottage(rng, wall: str, wall_shades, trim, roof: str, roof_rows: int = 2, skip=()) -> None:
    """The village stilt cottage every small house shares (the old stilt_house.glb's shape):
    four stilts, a deck at 1.0 m, a 2.6 × 2.2 × 1.6 m planked wall box with corner posts and a
    gable roof (ridge along Y) peaking at ~3.8 m. Door left of centre on the front (-Y)."""
    _stilts(1.1, 0.9, 1.0, mat("slate", -0.3), rng)
    box("Deck", (3.0, 2.6, 0.12), (0, 0, 0.94), mat("driftwood", -0.25))
    box("Walls", (2.6, 2.2, 1.6), (0, 0, 1.06), mat(wall, wall_shades[0]))
    _boards(2.6, 2.2, 1.6, 1.06, wall_shades, wall, rng, skip=skip)
    _corner_posts(1.31, 1.11, 1.06, 1.6, trim)
    box("WallPlate", (2.74, 2.34, 0.08), (0, 0, 2.62), trim)
    _shingled_roof(3.1, 2.8, 1.1, 2.7, roof, rows=roof_rows)
    box("Ridge", (0.12, 2.9, 0.08), (0, 0, 3.78), mat("driftwood", -0.25))
    box("Door", (0.62, 0.06, 1.12), (-0.5, -1.13, 1.06), mat("ink", 0.2))
    box("Lintel", (0.8, 0.08, 0.1), (-0.5, -1.15, 2.2), trim)
    box("Step", (0.7, 0.36, 0.06), (-0.5, -1.45, 0.62), mat("driftwood", -0.25))
    box("Step", (0.7, 0.36, 0.06), (-0.5, -1.75, 0.3), mat("driftwood", -0.25))
    for x in (-0.83, -0.17):
        beam("Stringer", (x, -1.3, 0.94), (x, -1.95, 0.0), 0.06, trim, width=0.08)


def build_house_stilt() -> None:
    """The plain village stilt house (replaces build_props' flat-walled stilt_house.glb, same
    footprint and heights): warm planks on all four faces, a coal shingle roof, a lit window
    with tide-blue shutters, a side window, a chimney and steps down from the door."""
    bd.reset()
    rng = random.Random(23)
    trim = mat("driftwood", -0.4)
    _cottage(rng, "driftwood", (0.0, -0.12), trim, "coal")
    box("Chimney", (0.34, 0.34, 0.95), (0.8, 0.6, 2.95), mat("slate", -0.1))
    box("ChimneyCap", (0.44, 0.44, 0.07), (0.8, 0.6, 3.9), mat("slate", -0.3))
    box("Window", (0.5, 0.06, 0.45), (0.6, -1.13, 1.62), mat("kindle", 0.0, emissive=True))
    box("Sill", (0.66, 0.12, 0.05), (0.6, -1.16, 1.57), trim)
    for s in (-1, 1):
        box("Shutter", (0.25, 0.04, 0.49), (0.6 + s * 0.4, -1.15, 1.6), mat("tide", -0.15))
    box("SideWindow", (0.06, 0.45, 0.4), (1.34, 0.3, 1.65), mat("kindle", 0.0, emissive=True))
    box("SideSill", (0.12, 0.6, 0.05), (1.37, 0.3, 1.6), trim)
    bd.export("house_stilt")


def build_house_wren() -> None:
    """The Wrens' old house — Brother Aldous's family home on Saltmarrow's west side. The
    cottage gone grey: bleached, salt-silvered boards (two fallen off the +X side), a slate
    roof patched in mismatched shingles, the side window boarded over with a cross of planks,
    and a Keeper's touches: a cold iron brazier at the foot of the steps, its ash long grey,
    and an iron hook by the door. What hangs on the hook is a separate prop (`ember_sign` /
    `ember_sign_wrapped`, placed with the house's own position and turn) so it can change with
    the story."""
    bd.reset()
    rng = random.Random(41)
    trim = mat("slate", -0.35)
    _cottage(rng, "silverfog", (-0.25, -0.38), trim, "slate", roof_rows=3, skip=(("+x", 5), ("+x", 6)))
    # Two boards gone from the +X side show the dark wall behind (the box is wall-coloured
    # under the boards; a darker strip reads as the gap).
    box("Gap", (0.02, 0.55, 1.5), (1.305, 0.55, 1.1), mat("ink", 0.2))
    # Mismatched patch shingles on the roof's front slope.
    for i, (y, dz) in enumerate(((-0.6, 0.25), (-0.2, 0.32), (0.45, 0.2))):
        beam(f"Patch{i}", (-0.55, y - 0.18, 3.18 + dz), (-0.55, y + 0.18, 3.18 + dz), 0.05, mat("driftwood", -0.25),
             width=0.42)
    box("Chimney", (0.34, 0.34, 0.8), (0.8, 0.6, 2.95), mat("slate", -0.25))
    # Front window, shutters closed; the side window boarded with a cross of planks.
    box("Window", (0.5, 0.06, 0.45), (0.6, -1.13, 1.62), mat("ink", 0.2))
    for s in (-1, 1):
        box("Shutter", (0.25, 0.04, 0.49), (0.6 + s * 0.125, -1.16, 1.6), mat("tide", -0.45))
    box("Sill", (0.66, 0.12, 0.05), (0.6, -1.17, 1.57), trim)
    box("SideWindow", (0.06, 0.45, 0.4), (1.34, -0.4, 1.65), mat("ink", 0.2))
    beam("Boarding", (1.37, -0.68, 1.6), (1.37, -0.12, 2.1), 0.04, mat("driftwood", -0.25), width=0.12)
    beam("Boarding", (1.37, -0.68, 2.1), (1.37, -0.12, 1.6), 0.04, mat("driftwood", -0.25), width=0.12)
    # The ember-hook by the door: an iron bracket reaching out from the wall at 2.0 m.
    iron = mat("ink", 0.25)
    beam("HookArm", (-1.02, -1.13, 2.02), (-1.02, -1.52, 2.02), 0.045, iron)
    beam("HookStay", (-1.02, -1.13, 1.78), (-1.02, -1.46, 2.0), 0.03, iron)
    beam("Hook", (-1.02, -1.5, 2.02), (-1.02, -1.5, 1.94), 0.025, iron)
    # The cold brazier at the foot of the steps: three splayed iron legs, a shallow bowl, grey
    # ash heaped with a few dead coals (charcoal grey, not glowing — the Keepers' fire is out).
    bx, by = -1.25, -2.0
    for k in range(3):
        a = math.tau * k / 3 + 0.3
        beam("BrazierLeg", (bx + math.cos(a) * 0.32, by + math.sin(a) * 0.32, 0.0),
             (bx + math.cos(a) * 0.2, by + math.sin(a) * 0.2, 0.62), 0.04, iron)
    cyl("BrazierBowl", 0.18, 0.34, 0.2, 8, (bx, by, 0.58), iron)
    cyl("BrazierRim", 0.36, 0.36, 0.04, 8, (bx, by, 0.78), iron)
    cyl("Ash", 0.3, 0.12, 0.08, 7, (bx, by, 0.76), mat("silverfog", -0.35))
    for k in range(4):
        a = math.tau * k / 4 + 0.7
        bp.rock(f"DeadCoal{k}", 0.06, (bx + math.cos(a) * 0.12, by + math.sin(a) * 0.12, 0.84),
                mat("ink", 0.2), rng)
    bd.export("house_wren")


def _ember_disc(wrapped: bool) -> None:
    """The sign on the Wrens' ember-hook, modelled where the hook is on house_wren (its origin
    is the house's): hung by a short chain below the hook at (-1.02, -1.5, 1.94)."""
    x, y = -1.02, -1.5
    beam("Chain", (x, y, 1.95), (x, y, 1.82), 0.02, mat("ink", 0.25))
    if wrapped:
        # A lumpy sailcloth bundle, cord-tied at the neck: the sign hidden, not thrown away.
        sack = bp.rock("Sack", 0.2, (x, y, 1.5), mat("driftwood", 0.15), random.Random(3))
        sack.scale = (1.0, 0.45, 1.3)
        cyl("Cord", 0.07, 0.07, 0.05, 6, (x, y, 1.74), mat("coal", -0.3))
        cyl("Neck", 0.05, 0.03, 0.09, 6, (x, y, 1.76), mat("driftwood", 0.15))
        return
    # A bone-white enamel disc ringed in iron, with the Keepers' ember on both faces.
    rod("Disc", (x, y - 0.025, 1.62), (x, y + 0.025, 1.62), 0.2, mat("bone", -0.1), verts=10)
    rod("DiscRim", (x, y - 0.018, 1.62), (x, y + 0.018, 1.62), 0.225, mat("ink", 0.25), verts=10)
    for side in (-1, 1):
        fy = y + side * 0.03
        rod("Ember", (x, fy, 1.52), (x, fy, 1.6), 0.07, mat("ember", -0.1), verts=6, r_end=0.1)
        rod("Ember", (x, fy, 1.6), (x, fy, 1.76), 0.1, mat("ember", -0.1), verts=6, r_end=0.0)
        rod("EmberHeart", (x, fy + side * 0.01, 1.56), (x, fy + side * 0.01, 1.66), 0.04, mat("coal", -0.1),
            verts=6, r_end=0.0)


def build_ember_sign() -> None:
    """The Keepers' ember sign, uncovered — hung on the Wrens' hook once Aldous has told the
    truth about the Hearthspire."""
    bd.reset()
    _ember_disc(False)
    bd.export("ember_sign")


def build_ember_sign_wrapped() -> None:
    """The same sign wrapped in sacking: how it hangs while Aldous still keeps his secret."""
    bd.reset()
    _ember_disc(True)
    bd.export("ember_sign_wrapped")


def build_net_loft_broken() -> None:
    """A Gull's Head net-loft left to the Greying: net_loft.glb's frame and footprint (stilts at
    ±1.4 × ±1.0, floor at 1.2 m, roof eaves at 3.0 m, so the same collider fits) gone to ruin —
    bleached grey timber, a snapped side rail hanging down, a roof of planks with a hole torn
    in it and one plank slid to the eave, a back wall missing boards, one net hanging by a
    corner, another fallen in a heap, and a ladder short of two rungs. Nobody has mended
    anything here since the fog came, except old Hesk, and she forgets what she mends."""
    bd.reset()
    rng = random.Random(53)
    grey = mat("driftwood", -0.35)
    pale = mat("silverfog", -0.3)
    for x in (-1.4, 1.4):
        for y in (-1.0, 1.0):
            cyl("Stilt", 0.1, 0.09, 3.0, 5, (x, y, 0), mat("slate", -0.2), rng.uniform(0, 1))
    beam("Brace", (-1.4, 1.0, 0.15), (1.4, 1.0, 1.15), 0.05, mat("slate", -0.2))
    for i in range(8):  # floor planks along X, one missing
        if i == 5:
            continue
        y = -1.05 + i * 0.3
        box(f"Floor{i}", (3.2 + rng.uniform(-0.1, 0.05), 0.28, 0.1), (rng.uniform(-0.05, 0.05), y, 1.2),
            (grey, pale)[i % 2])
    for i in range(10):  # back wall boards, two gone
        if i in (3, 4):
            continue
        x = -1.44 + i * 0.32
        box("BackBoard", (0.3, 0.06, 1.7 + rng.uniform(-0.25, 0.0)), (x, 1.15, 1.32), (grey, pale)[i % 2])
    # Rails: the left one whole, the right one snapped in the middle and hanging.
    beam("Rail", (-1.4, -1.05, 2.3), (-1.4, 1.05, 2.3), 0.08, grey)
    beam("RailStub", (1.4, 1.05, 2.3), (1.4, 0.1, 2.3), 0.08, grey)
    beam("RailBroken", (1.4, -1.05, 2.3), (1.45, -0.1, 1.55), 0.08, grey)
    # Roof: strips along the ridge on each slope (eaves 3.0 m at x ±1.8, ridge 3.9 m). A beam
    # from p0 to p1 up the slope lies flat on it with its width along Y. The -X slope has a
    # hole where two strips end short, and a slipped strip hangs over the eave below it.
    for side in (-1, 1):
        n = 6
        for i in range(n):
            f0, f1 = i / n, (i + 1) / n
            p0 = (side * 1.8 * (1 - f0), 3.0 + 0.9 * f0 + 0.03)
            p1 = (side * 1.8 * (1 - f1), 3.0 + 0.9 * f1 + 0.03)
            m = mat("slate", (-0.05, -0.2)[i % 2])
            if side < 0 and i in (2, 3):  # the hole: these strips only cover the back end
                beam(f"Roof{side}{i}", (p0[0], 0.75, p0[1]), (p1[0], 0.75, p1[1]), 0.06, m, width=1.4 - 0.4 * (i - 2))
                continue
            y_off = rng.uniform(-0.06, 0.06)
            beam(f"Roof{side}{i}", (p0[0], y_off, p0[1]), (p1[0], y_off, p1[1]), 0.06, m, width=2.9)
    beam("RoofSlid", (-2.15, -0.75, 2.78), (-1.75, -0.75, 2.98), 0.06, mat("slate", -0.05), width=1.1)
    for y in (-1.4, 1.4):  # gable rafters
        beam("Rafter", (-1.8, y, 3.0), (0, y, 3.9), 0.08, grey)
        beam("Rafter", (1.8, y, 3.0), (0, y, 3.9), 0.08, grey)
    beam("RidgeBeam", (0, -1.45, 3.9), (0, 1.45, 3.9), 0.1, grey)
    # Nets: one hanging by a corner from its bar, one heaped on the floor.
    box("NetBar", (0.8, 0.05, 0.05), (-0.9, -0.2, 2.33), grey)
    box("NetBarFallen", (0.05, 0.8, 0.05), (0.6, 0.6, 1.3), grey)
    bd.net("Hang", 0.7, 0.9, (0, 0, 0), mat("silverfog", -0.15), spacing=0.12, strand=0.024, sag=0.05)
    hang = _join("Hang")
    hang.rotation_euler.y = 0.45
    hang.location = (-0.95, -0.2, 1.88)
    for k in range(3):
        heap = bp.rock(f"NetHeap{k}", 0.3 - k * 0.06, (0.2 + k * 0.25, 0.2 - k * 0.15, 1.3),
                       mat("silverfog", -0.15 - 0.1 * k), rng)
        heap.scale.z = 0.45
    # Ladder (+X front corner like net_loft) with two rungs gone.
    for x in (0.7, 1.1):
        beam("LadderRail", (x, -1.35, 0.0), (x, -1.2, 1.25), 0.05, grey)
    for i, z in enumerate((0.25, 0.5, 0.75, 1.0)):
        if i in (1, 2):
            continue
        beam(f"Rung{i}", (0.7, -1.33 + z * 0.12, z), (1.1, -1.33 + z * 0.12, z), 0.04, grey)
    bd.export("net_loft_broken")


BUILDERS = [build_house_tall, build_house_porch, build_gate_post, build_house_stilt, build_house_wren,
            build_ember_sign, build_ember_sign_wrapped, build_net_loft_broken]

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
