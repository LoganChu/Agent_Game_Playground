"""Builds the kit for Lowsong (Day 75), the Keepers' light on the biggest rock of the Low Water, the skerry
field in the ring's southern gap, into the dressing kit:

- **lowsong_light**: the light itself, cold since the Snuffing — a squat round tower of dark sea-worn stone,
  salt-streaked, battered at the foot, a low door on the front (-Y) with the Keepers' ember cut over it and
  an iron hook by the door where the Keeper hangs his own small lamp; a lantern room of dull horn panes under
  a conical slate cap. Against its back, the Keeper's **bothy**: a low lean-to of the same stone with a turf
  roof and a stub chimney, a water butt at its corner.
- **lowsong_cairn**: a chest-high cairn of flat skerry stones with a pale stone on top — the old brothers'
  markers on the wading way from the landing to the rock (each one stands where the shallows will bear you).
  Day 76: a skirt of black-green wrack round the foot where the tide lips it, salt crusted in the joints.
- **lowsong_stack** (Day 76): a sea stack — a tall, leaning column of dark stone a good deal higher than a
  man, stood up out of the deeper water round the field so the Low Water reads as a maze of rock from
  Lowsong's knoll: stepped and cracked, a weed band at the waterline (model z ≈ 0.5-0.9), white streaks down
  from the gull ledges near the top.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_lowsong.py
    .tools/bin/blender-py tools/blender/build_lowsong.py [lowsong_light lowsong_cairn]

Same conventions as build_dressing/build_kindleby: origin at the base centre, flat-shaded, palette colours
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

# Where the bothy's stub chimney lets out its peat smoke (Godot model space: x, y, -Blender y): the region's
# `smoke` on lowsong_light (Day 76). tests/test_lowsong_dressed.gd pins the region to it.
BOTHY_SMOKE = (1.0, 2.7, -2.5)

# The lamp hook by the door (Godot model space: +Z = front), empty: Brother Iver carries his lamp. A later
# lit variant can hang it here.
LAMP_HOOK = (0.72, 1.55, 1.42)


def _diamond(name: str, size: tuple, loc: tuple, material) -> bpy.types.Object:
    """A box turned 45° about Y in place, standing on loc (the Keepers' ember cut in stone)."""
    obj = box(name, size, (0, 0, -size[2] / 2), material)
    obj.rotation_euler = (0, math.radians(45), 0)
    obj.location = (loc[0], loc[1], loc[2] + size[2] / 2)
    return obj


def build_lowsong_light() -> None:
    """Lowsong's light (~3.2 m across, 6.4 m to the finial) and the bothy behind it (~3 × 2 m, 2 m high)."""
    bd.reset()
    rng = random.Random(750)
    STONE = (mat("slate", -0.42), mat("slate", -0.52), mat("slate", -0.3))
    SALT = mat("bone", -0.2)
    IRON, WOOD = mat("ink", 0.15), mat("driftwood", -0.5)
    cyl("Batter", 1.75, 1.45, 0.7, 10, (0, 0, 0), STONE[1])
    cyl("Tower", 1.4, 1.25, 3.3, 10, (0, 0, 0.7), STONE[0])
    for k in range(3):
        z = 1.3 + k * 0.85
        r = 1.4 - (z - 0.7) / 3.3 * 0.15
        cyl("Course", r + 0.03, r + 0.02, 0.06, 10, (0, 0, z), STONE[2])
    # Salt streaks down the seaward flanks: pale runs from the gallery.
    for k in range(9):
        a = rng.uniform(0.3, math.tau - 0.3) + math.pi / 2
        if math.sin(a) < -0.6:
            continue  # not over the door
        h = rng.uniform(0.6, 1.8)
        r = 1.31
        box("Salt", (0.08, 0.04, h), (math.cos(a) * r, math.sin(a) * r, 4.0 - h), SALT, a + math.pi / 2)
    cyl("Gallery", 1.6, 1.6, 0.16, 10, (0, 0, 4.0), STONE[1])
    # The lantern room: iron posts and dull horn panes round a cold cradle.
    for k in range(6):
        a = k / 6 * math.tau
        beam("Post", (math.cos(a) * 0.82, math.sin(a) * 0.82, 4.16), (math.cos(a) * 0.82, math.sin(a) * 0.82, 5.2), 0.07, IRON)
    cyl("Horn", 0.8, 0.8, 0.95, 6, (0, 0, 4.18), mat("silverfog", -0.4))
    cyl("Cradle", 0.3, 0.4, 0.28, 6, (0, 0, 4.16), IRON)
    cyl("Cap", 1.15, 0.12, 0.95, 6, (0, 0, 5.15), mat("slate", -0.6))
    rod("Finial", (0, 0, 6.05), (0, 0, 6.35), 0.035, IRON)
    _diamond("Ember", (0.18, 0.05, 0.18), (0, 0, 6.33), mat("ember", -0.45))
    # The door, low (a Keeper stoops), and the ember over it.
    box("DoorFrame", (0.9, 0.12, 1.75), (0, -1.36, 0.6), STONE[2])
    box("Door", (0.68, 0.1, 1.55), (0, -1.4, 0.6), WOOD)
    for z in (0.95, 1.7):
        beam("Band", (-0.33, -1.46, z), (0.33, -1.46, z), 0.045, IRON)
    _diamond("Sigil", (0.2, 0.05, 0.2), (0, -1.37, 2.55), mat("ember", -0.4))
    box("Step", (1.1, 0.5, 0.2), (0, -1.75, 0.0), STONE[1])
    # The lamp hook, empty: an iron bracket out of the wall by the door, a crook at its end.
    hx, hy, hz = LAMP_HOOK[0], -LAMP_HOOK[2], LAMP_HOOK[1]
    beam("Hook", (hx, hy + 0.22, hz + 0.25), (hx, hy, hz + 0.25), 0.03, IRON)
    beam("HookDrop", (hx, hy, hz + 0.25), (hx, hy, hz + 0.1), 0.025, IRON)
    # The bothy: a lean-to against the tower's back (+Y), turf roof falling away, a stub chimney.
    box("Bothy", (3.0, 1.9, 1.7), (0, 2.05, 0), STONE[0])
    bpy.ops.mesh.primitive_cube_add(size=1)
    roof = bpy.context.active_object
    roof.name = "Turf"
    roof.scale = (3.3, 2.3, 0.22)
    bpy.ops.object.transform_apply(scale=True)
    roof.rotation_euler = (math.radians(14), 0, 0)
    roof.location = (0, 2.1, 1.95)
    bd.bp.finish(roof, mat("moss", -0.45))
    box("Chimney", (0.42, 0.42, 0.75), (BOTHY_SMOKE[0], -BOTHY_SMOKE[2], BOTHY_SMOKE[1] - 0.8), STONE[2])
    box("ChimneyLip", (0.5, 0.5, 0.06), (BOTHY_SMOKE[0], -BOTHY_SMOKE[2], BOTHY_SMOKE[1] - 0.11), mat("ink", 0.1))
    box("Window", (0.5, 0.06, 0.4), (-1.52, 2.0, 0.9), mat("ink", -0.5), math.pi / 2)
    cyl("Butt", 0.3, 0.27, 0.7, 8, (1.75, 3.0, 0.0), WOOD)
    for z in (0.15, 0.55):
        cyl("Hoop", 0.31, 0.31, 0.05, 8, (1.75, 3.0, z), IRON)
    bd.export("lowsong_light")


def build_lowsong_cairn() -> None:
    """A chest-high cairn of flat dark stones, the pale one on top (~0.9 m across, 1.25 m high)."""
    bd.reset()
    rng = random.Random(751)
    STONE = (mat("slate", -0.45), mat("slate", -0.55), mat("slate", -0.35))
    z = 0.0
    for k in range(6):
        r = 0.45 - k * 0.055 + rng.uniform(-0.03, 0.03)
        h = rng.uniform(0.15, 0.22)
        cyl("Stone", r, r * 0.92, h, 6, (rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), z), STONE[k % 3],
            rng.uniform(0, math.pi))
        z += h * 0.95
    cyl("Top", 0.14, 0.1, 0.16, 5, (0, 0, z), mat("bone", -0.15), 0.4)
    # The wrack skirt where the tide lips the foot: ragged black-green fronds hanging off the lowest stones.
    WRACK = (mat("moss", -0.62), mat("moss", -0.5), mat("ink", 0.2))
    for k in range(11):
        a = k / 11 * math.tau + rng.uniform(-0.15, 0.15)
        r = 0.44 + rng.uniform(-0.02, 0.04)
        top = rng.uniform(0.18, 0.34)
        box("Wrack", (rng.uniform(0.14, 0.24), 0.05, top), (math.cos(a) * r, math.sin(a) * r, -0.02),
            WRACK[k % 3], a + math.pi / 2)
    # Salt crusted in the joints: pale flecks on the stones above the weed.
    for k in range(7):
        a = rng.uniform(0, math.tau)
        zz = rng.uniform(0.35, 0.85)
        r = 0.43 - zz * 0.2
        box("Salt", (0.1, 0.03, 0.04), (math.cos(a) * r, math.sin(a) * r, zz), mat("bone", -0.25), a + math.pi / 2)
    bd.export("lowsong_cairn")


def build_lowsong_stack() -> None:
    """A sea stack (~2.2 m across at the foot, ~5.2 m high): drums of dark stone stepped and leaning."""
    bd.reset()
    rng = random.Random(752)
    STONE = (mat("slate", -0.5), mat("slate", -0.58), mat("slate", -0.42))
    z, x, y = 0.0, 0.0, 0.0
    radius = 1.1
    drums = []
    for k in range(7):
        h = rng.uniform(0.6, 0.95)
        r2 = radius * rng.uniform(0.82, 0.95)
        cyl("Drum", radius, r2, h, 7, (x, y, z), STONE[k % 3], rng.uniform(0, math.pi))
        drums.append((x, y, z, h, radius))
        z += h * 0.97
        x += rng.uniform(-0.05, 0.14)  # it leans a little to seaward (+X)
        y += rng.uniform(-0.06, 0.06)
        radius = max(0.45, r2 + rng.uniform(-0.04, 0.06))
    cyl("Crown", radius, radius * 0.55, 0.4, 6, (x, y, z), STONE[1], 0.3)
    # A cracked-off slab leant against the foot.
    slab = box("Slab", (0.9, 0.35, 1.3), (-0.95, 0.4, 0.0), STONE[2], 0.5)
    slab.rotation_euler = (0.25, -0.2, 0.5)
    # The weed band at the waterline (the stack stands with its base under water: see the region).
    for k in range(14):
        a = k / 14 * math.tau
        r = 1.08
        box("Wrack", (0.4, 0.06, rng.uniform(0.3, 0.45)), (math.cos(a) * r, math.sin(a) * r, 0.5),
            mat("moss", -0.6 + 0.08 * (k % 2)), a + math.pi / 2)
    # Gull ledges near the top and the white run down from them.
    for k in range(5):
        dx, dy, dz, dh, dr = drums[min(len(drums) - 1, 4 + k % 3)]
        a = rng.uniform(0, math.tau)
        r = dr * 0.9
        box("Ledge", (0.4, 0.2, 0.06), (dx + math.cos(a) * r, dy + math.sin(a) * r, dz + dh * 0.6), STONE[2], a + math.pi / 2)
        run = rng.uniform(0.8, 1.6)
        box("Lime", (0.12, 0.04, run), (dx + math.cos(a) * (r + 0.04), dy + math.sin(a) * (r + 0.04), dz + dh * 0.6 - run),
            mat("bone", 0.05), a + math.pi / 2)
    bd.export("lowsong_stack")


BUILDERS = {
    "lowsong_light": build_lowsong_light,
    "lowsong_cairn": build_lowsong_cairn,
    "lowsong_stack": build_lowsong_stack,
}

if __name__ == "__main__":
    only = {a for a in sys.argv[1:] if not a.startswith("-")}
    for key, build in BUILDERS.items():
        if not only or key in only:
            build()
