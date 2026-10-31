"""Builds the kit for Lowsong (Day 75), the Keepers' light on the biggest rock of the Low Water, the skerry
field in the ring's southern gap, into the dressing kit:

- **lowsong_light**: the light itself, cold since the Snuffing — a squat round tower of dark sea-worn stone,
  salt-streaked, battered at the foot, a low door on the front (-Y) with the Keepers' ember cut over it and
  an iron hook by the door where the Keeper hangs his own small lamp; a lantern room of dull horn panes under
  a conical slate cap. Against its back, the Keeper's **bothy**: a low lean-to of the same stone with a turf
  roof and a stub chimney, a water butt at its corner.
- **lowsong_cairn**: a chest-high cairn of flat skerry stones with a pale stone on top — the old brothers'
  markers on the wading way from the landing to the rock (each one stands where the shallows will bear you).

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
    box("Chimney", (0.42, 0.42, 0.75), (1.0, 2.5, 1.9), STONE[2])
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
    bd.export("lowsong_cairn")


BUILDERS = {
    "lowsong_light": build_lowsong_light,
    "lowsong_cairn": build_lowsong_cairn,
}

if __name__ == "__main__":
    only = {a for a in sys.argv[1:] if not a.startswith("-")}
    for key, build in BUILDERS.items():
        if not only or key in only:
            build()
