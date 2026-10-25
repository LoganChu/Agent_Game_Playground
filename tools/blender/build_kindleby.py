"""Builds the kit for Kindleby (Day 62), the Keepers' mother-house south-about from Wrackholm, into the
dressing kit: the **chapter_house** (a long hall of pale dressed stone, every tall window lit, a bell-cote
on the gable), a **candle_ledge** (a low stone sea wall with tallow candles burning in a row: the Keepers'
vigil against the fog), the **vigil_bell** (the quay bell on its frame that answers boats before they
blow), the **quiet_house** (a small stone house by the water, its shutters barred from outside) and the
**vigil_light** (Kindleby's beacon: a squat pale tower, dark, candles burning round its foot).

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_kindleby.py
    .tools/bin/blender-py tools/blender/build_kindleby.py [chapter_house candle_ledge vigil_bell quiet_house vigil_light]

Same conventions as build_dressing/build_bend: origin at the base centre, flat-shaded, palette colours
and tonal shades, Blender -Y = Godot +Z = the front, merged by material.
"""
import math
import os
import random
import sys

import bpy  # noqa: F401  (must be imported before mathutils when running as the bpy module)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dressing as bd  # noqa: E402  (materials, primitives, merge + export)

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod


def _candle(x: float, y: float, z: float, rng: random.Random, tallow, flame) -> None:
    """One tallow candle standing on z: a pale stub, a drip down its side, a flame."""
    h = rng.uniform(0.12, 0.26)
    cyl("Candle", 0.035, 0.032, h, 6, (x, y, z), tallow)
    box("Drip", (0.02, 0.02, h * 0.5), (x + 0.03, y, z), tallow)
    cyl("Flame", 0.022, 0.0, 0.07, 4, (x, y, z + h + 0.01), flame)


def _diamond(name: str, size: tuple, loc: tuple, material) -> bpy.types.Object:
    """A box turned 45° about Y in place, standing on loc (the Keepers' ember cut in stone). The primitives
    bake their location into the mesh, so it is built on the origin, turned, then moved (Day 63: turning
    it where it stood swung it round the model's origin — Day 62's door embers hung in the air)."""
    obj = box(name, size, (0, 0, -size[2] / 2), material)
    obj.rotation_euler = (0, math.radians(45), 0)
    obj.location = (loc[0], loc[1], loc[2] + size[2] / 2)
    return obj


def build_chapter_house() -> None:
    """Kindleby's chapter-house (~7.4 × 3.6 m, 5.6 m to the bell-cote): a long hall of pale dressed
    stone in courses, a steep slate roof, buttresses between four tall lit windows on the front (-Y),
    an arched double door in the middle of the front under the Keepers' ember cut in the stone, a
    bell-cote on the east gable with its bell, and candles burning on every sill."""
    bd.reset()
    rng = random.Random(620)
    STONE = (mat("bone", -0.18), mat("bone", -0.28), mat("bone", -0.1))
    ROOF, WOOD, IRON = mat("slate", -0.35), mat("driftwood", -0.45), mat("ink", 0.15)
    glow = mat("kindle", 0.0, emissive=True)
    tallow, flame = mat("bone", 0.1), mat("ember", 0.1, emissive=True)
    w, d, wall_h = 7.0, 3.2, 2.9
    box("Plinth", (w + 0.3, d + 0.3, 0.3), (0, 0, 0), STONE[1])
    box("Walls", (w, d, wall_h), (0, 0, 0.3), STONE[0])
    for k in range(5):  # coursing: a slightly paler band every course
        z = 0.6 + k * 0.52
        box("Course", (w + 0.04, d + 0.04, 0.05), (0, 0, z), STONE[2])
    # Steep roof: two slabs meeting at the ridge, gables filled.
    top = 0.3 + wall_h
    rise = 1.55
    half = d / 2 + 0.25
    slope = math.atan2(rise, half)
    length = math.hypot(rise, half)
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cube_add(size=1)
        slab = bpy.context.active_object
        slab.name = "Roof"
        slab.scale = (w + 0.5, length, 0.14)
        bpy.ops.object.transform_apply(scale=True)
        slab.rotation_euler = (-side * slope, 0, 0)
        slab.location = (0, side * half / 2, top + rise / 2)
        bd.bp.finish(slab, ROOF)
    for gx in (-w / 2, w / 2):  # gable triangles in stone
        for i in range(6):
            frac = i / 6
            box("Gable", (0.3, max(0.1, 2 * half * (1 - frac - 1 / 6) - 0.2), rise / 6 + 0.02), (gx * 0.98, 0, top + rise * frac), STONE[0])
    beam("Ridge", (-w / 2 - 0.25, 0, top + rise + 0.02), (w / 2 + 0.25, 0, top + rise + 0.02), 0.12, ROOF)
    # The bell-cote on the east gable (Day 63: opened to the sea so it reads as a cote, not a chimney): two
    # stone piers across the gable top, an arch between them, a little pitched cap with the ember on its
    # finial, the bell hung on its headstock in the opening and the rope down the outside of the gable.
    cx = w / 2 - 0.15
    base = top + rise - 0.25
    pier_h = 1.25
    for px in (-0.42, 0.42):
        box("Cote", (0.24, 0.42, pier_h), (cx + px, 0, base), STONE[0])
    box("CoteSill", (1.12, 0.48, 0.12), (cx, 0, base - 0.02), STONE[2])
    box("CoteArch", (1.08, 0.42, 0.2), (cx, 0, base + pier_h - 0.05), STONE[0])
    for side in (-1, 1):  # the cap: two slate slabs pitched along the gable
        bpy.ops.mesh.primitive_cube_add(size=1)
        cap = bpy.context.active_object
        cap.name = "CoteCap"
        cap.scale = (0.72, 0.62, 0.08)
        bpy.ops.object.transform_apply(scale=True)
        cap.rotation_euler = (0, side * math.radians(35), 0)
        cap.location = (cx + side * 0.28, 0, base + pier_h + 0.33)
        bd.bp.finish(cap, ROOF)
    rod("Finial", (cx, 0, base + pier_h + 0.5), (cx, 0, base + pier_h + 0.78), 0.03, IRON)
    _diamond("CoteEmber", (0.14, 0.04, 0.14), (cx, 0, base + pier_h + 0.72), mat("ember", -0.35))
    beam("Headstock", (cx - 0.36, 0, base + pier_h - 0.12), (cx + 0.36, 0, base + pier_h - 0.12), 0.08, WOOD)
    cyl("Bell", 0.26, 0.12, 0.42, 10, (cx, 0, base + pier_h - 0.62), mat("ember", -0.5))
    cyl("BellLip", 0.28, 0.26, 0.05, 10, (cx, 0, base + pier_h - 0.64), mat("ember", -0.4))
    rod("BellRope", (cx + 0.2, -0.12, base + pier_h - 0.55), (cx + 0.32, -0.3, 0.9), 0.02, mat("driftwood", -0.1), verts=4)
    # Buttresses and tall lit windows along the front; candles on every sill.
    front = -d / 2
    for i, x in enumerate((-2.55, -0.9, 0.9, 2.55)):
        box("Window", (0.55, 0.06, 1.5), (x, front - 0.02, 1.0), glow)
        box("Arch", (0.4, 0.06, 0.2), (x, front - 0.02, 2.5), glow)
        box("Mullion", (0.06, 0.08, 1.7), (x, front - 0.04, 1.0), STONE[1])
        box("Sill", (0.75, 0.22, 0.08), (x, front - 0.1, 0.92), STONE[2])
        for k in range(3):
            _candle(x - 0.22 + k * 0.22, front - 0.14, 1.0, rng, tallow, flame)
    for x in (-3.4, -1.75, 1.75, 3.4):
        box("Buttress", (0.4, 0.45, 2.2), (x, front - 0.2, 0.0), STONE[1])
    # Windows on the back too, so the hall reads lit from the sea.
    for x in (-2.0, 0.0, 2.0):
        box("Window", (0.5, 0.06, 1.4), (x, d / 2 + 0.02, 1.05), glow)
    # The double door under a pointed arch, the ember cut over it.
    box("DoorFrame", (1.5, 0.12, 2.25), (0, front - 0.04, 0.3), STONE[2])
    box("Door", (1.1, 0.1, 1.85), (0, front - 0.08, 0.3), WOOD)
    beam("DoorSplit", (0, front - 0.14, 0.32), (0, front - 0.14, 2.12), 0.04, IRON)
    for z in (0.75, 1.65):
        beam("Strap", (-0.5, front - 0.14, z), (0.5, front - 0.14, z), 0.05, IRON)
    _diamond("Ember", (0.26, 0.06, 0.26), (0, front - 0.06, 2.62), mat("ember", -0.3))
    # A hood moulding over the door: dressed voussoirs stepping up to a point (Day 63).
    for k in range(4):
        dx = 0.78 - k * 0.2
        for s in (-1, 1):
            box("Hood", (0.22, 0.1, 0.12), (s * dx, front - 0.1, 2.0 + k * 0.14), STONE[2])
    box("HoodKey", (0.2, 0.1, 0.18), (0, front - 0.1, 2.56), STONE[2])
    # Steps down from the door, candles at both ends of each (Day 63: the steps were lore'd as candle-lined).
    for k in range(2):
        sw = 1.8 - k * 0.3
        sy = front - 0.35 - k * 0.35
        sz = 0.15 - k * 0.15
        box("Step", (sw, 0.4, 0.15), (0, sy, sz), STONE[1])
        for s in (-1, 1):
            for j in range(2):
                _candle(s * (sw / 2 - 0.1 - j * 0.12), sy - 0.05 + j * 0.06, sz + 0.15, rng, tallow, flame)
    bd.export("chapter_house")


def build_candle_ledge() -> None:
    """A length of the Keepers' low sea wall (2.4 m along X, 0.6 m high) with tallow candles burning in
    a row along its top: since the Snuffing every brother and sister on Kindleby keeps forty lit, turn
    and turn, and the wall rings the island. Old wax runs down the stone in pale tongues."""
    bd.reset()
    rng = random.Random(621)
    stone = (mat("bone", -0.22), mat("bone", -0.32))
    tallow, flame = mat("bone", 0.1), mat("ember", 0.1, emissive=True)
    x = -1.2
    k = 0
    while x < 1.2:  # dressed blocks, two courses, joints offset
        bw = rng.uniform(0.45, 0.65)
        bw = min(bw, 1.2 - x)
        box("Block", (bw - 0.02, 0.42, 0.28), (x + bw / 2, 0, 0), stone[k % 2])
        x += bw
        k += 1
    x = -1.2
    k = 1
    while x < 1.2:
        bw = rng.uniform(0.4, 0.6)
        bw = min(bw, 1.2 - x)
        box("Block", (bw - 0.02, 0.38, 0.28), (x + bw / 2, 0, 0.28), stone[k % 2])
        x += bw
        k += 1
    box("Cope", (2.44, 0.46, 0.06), (0, 0, 0.56), stone[0])
    for i in range(9):
        cx = -1.05 + i * 0.26 + rng.uniform(-0.04, 0.04)
        _candle(cx, rng.uniform(-0.08, 0.08), 0.62, rng, tallow, flame)
        if i % 2 == 0:  # old wax run down the seaward face
            box("Wax", (0.07, 0.02, rng.uniform(0.15, 0.35)), (cx, 0.23, 0.62 - 0.3), tallow)
    bd.export("candle_ledge")


def build_vigil_bell() -> None:
    """The quay bell (~2.3 m): two tarred posts and a crossbeam on a stone footing, a bronze bell hung
    from the middle with its rope looped round a cleat on the near post. Rung one, then three: a boat
    seen, and welcome."""
    bd.reset()
    wood, iron = mat("driftwood", -0.55), mat("ink", 0.15)
    box("Footing", (1.5, 0.6, 0.18), (0, 0, 0), mat("bone", -0.3))
    for x in (-0.6, 0.6):
        beam("Post", (x, 0, 0.18), (x, 0, 2.25), 0.14, wood)
        beam("Brace", (x, 0.25, 0.18), (x, 0, 1.0), 0.07, wood)
    beam("Cross", (-0.75, 0, 2.2), (0.75, 0, 2.2), 0.16, wood)
    beam("Hanger", (0, 0, 2.12), (0, 0, 1.95), 0.05, iron)
    cyl("Bell", 0.3, 0.14, 0.45, 10, (0, 0, 1.5), mat("ember", -0.5))
    cyl("Lip", 0.32, 0.3, 0.05, 10, (0, 0, 1.48), mat("ember", -0.4))
    rod("Clapper", (0, 0, 1.75), (0, 0, 1.38), 0.03, iron)
    rope = mat("driftwood", -0.1)
    rod("Rope", (0, 0, 1.4), (-0.55, -0.1, 0.95), 0.018, rope, verts=4)
    box("Cleat", (0.06, 0.08, 0.16), (-0.6, -0.08, 0.9), iron)
    bd.export("vigil_bell")


def build_quiet_house() -> None:
    """The Quiet House (~4.2 × 3.0 m, 3.4 m high), where the Keepers keep the Hushed: a squat house of
    the same pale stone, a hipped slate roof, no chimney smoke; its shutters closed and each barred
    with an iron bar across the outside, and the door too. A single candle burns on the step."""
    bd.reset()
    rng = random.Random(623)
    stone = mat("bone", -0.24)
    wood, iron = mat("slate", -0.5), mat("ink", 0.15)
    w, d, wall_h = 4.0, 2.8, 2.1
    box("Walls", (w, d, wall_h), (0, 0, 0), stone)
    box("Plinth", (w + 0.2, d + 0.2, 0.25), (0, 0, 0), mat("bone", -0.35))
    cyl("Roof", 2.95, 0.25, 1.3, 4, (0, 0, wall_h), mat("slate", -0.3), math.radians(45))
    bpy.context.active_object.scale = (1.0, 0.72, 1.0)
    front = -d / 2
    for x in (-1.2, 1.2):  # shuttered windows, barred
        box("Shutter", (0.7, 0.08, 0.8), (x, front - 0.04, 0.9), wood)
        beam("Bar", (x - 0.5, front - 0.12, 1.3), (x + 0.5, front - 0.12, 1.3), 0.06, iron)
    for x in (-1.4, 0.0, 1.4):  # and on the back
        box("Shutter", (0.6, 0.08, 0.7), (x, d / 2 + 0.04, 0.95), wood)
        beam("Bar", (x - 0.45, d / 2 + 0.12, 1.3), (x + 0.45, d / 2 + 0.12, 1.3), 0.06, iron)
    box("Door", (0.9, 0.1, 1.75), (0, front - 0.05, 0.25), wood)
    beam("DoorBar", (-0.65, front - 0.14, 1.1), (0.65, front - 0.14, 1.1), 0.08, iron)
    for x in (-0.6, 0.6):
        box("Staple", (0.08, 0.1, 0.16), (x, front - 0.1, 1.02), iron)
    box("Step", (1.2, 0.45, 0.2), (0, front - 0.3, 0.0), mat("bone", -0.35))
    _candle(0.35, front - 0.35, 0.2, rng, mat("bone", 0.1), mat("ember", 0.1, emissive=True))
    bd.export("quiet_house")


def build_vigil_light() -> None:
    """Kindleby's beacon, the Vigil Light (~2.8 m square, 6.6 m to the finial): a squat square tower of
    the island's pale dressed stone, battered at the foot, an iron-banded door on the front (-Y) with
    the Keepers' ember cut over it, a ring of candle niches round the base (all lit: the Keepers keep
    their vigil even here), and a lantern room of horn panes in an iron frame under a slate cap. The
    cradle inside is cold; the horn is dull."""
    bd.reset()
    rng = random.Random(624)
    STONE = (mat("bone", -0.2), mat("bone", -0.3), mat("bone", -0.12))
    IRON, WOOD = mat("ink", 0.15), mat("driftwood", -0.45)
    tallow, flame = mat("bone", 0.1), mat("ember", 0.1, emissive=True)
    cyl("Batter", 2.0, 1.75, 0.8, 4, (0, 0, 0), STONE[1], math.radians(45))
    box("Tower", (2.4, 2.4, 3.6), (0, 0, 0.8), STONE[0])
    for k in range(4):
        box("Course", (2.44, 2.44, 0.06), (0, 0, 1.4 + k * 0.75), STONE[2])
    box("Gallery", (2.9, 2.9, 0.18), (0, 0, 4.4), STONE[1])
    # The lantern room: iron posts, dull horn panes, the cold cradle inside.
    for x in (-0.8, 0.8):
        for y in (-0.8, 0.8):
            beam("Post", (x, y, 4.58), (x, y, 5.7), 0.08, IRON)
    for side in range(4):
        a = side * math.pi / 2
        cx, cy = math.cos(a) * 0.8, math.sin(a) * 0.8
        box("Horn", (0.08 if abs(cx) > 0.1 else 1.5, 1.5 if abs(cx) > 0.1 else 0.08, 1.0), (cx, cy, 4.62), mat("silverfog", -0.35), 0)
    cyl("Cradle", 0.35, 0.45, 0.3, 6, (0, 0, 4.6), IRON)
    cyl("Cap", 1.45, 0.15, 0.8, 4, (0, 0, 5.7), mat("slate", -0.3), math.radians(45))
    rod("Finial", (0, 0, 6.45), (0, 0, 6.85), 0.04, IRON)
    box("Ember", (0.2, 0.06, 0.2), (0, -1.0, 6.62), mat("ember", -0.4))
    # Door and the ember over it.
    box("DoorFrame", (1.0, 0.1, 1.95), (0, -1.22, 0.8), STONE[2])
    box("Door", (0.75, 0.1, 1.7), (0, -1.26, 0.8), WOOD)
    for z in (1.2, 2.0):
        beam("Band", (-0.36, -1.32, z), (0.36, -1.32, z), 0.05, IRON)
    box("Lock", (0.1, 0.06, 0.14), (0.25, -1.34, 1.5), IRON)
    _diamond("Sigil", (0.22, 0.06, 0.22), (0, -1.24, 2.95), mat("ember", -0.35))
    # Candle niches round the batter: the vigil kept even at the dark light.
    for k in range(10):
        a = k / 10 * math.tau + 0.3
        if abs(math.cos(a)) < 0.35 and math.sin(a) < 0:
            continue  # not across the door
        r = 1.95
        x, y = math.cos(a) * r, math.sin(a) * r
        _candle(x, y, 0.0, rng, tallow, flame)
    bd.export("vigil_light")


BUILDERS = [build_chapter_house, build_candle_ledge, build_vigil_bell, build_quiet_house, build_vigil_light]

if __name__ == "__main__":
    only = {a for a in sys.argv[1:] if not a.startswith("-")}
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
