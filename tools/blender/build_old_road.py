"""Builds the kit for Thornwold's old Keepers' road north (Day 53) into the dressing kit: the
Northing — the Keepers' fire-cairn on the north cliff, where the keeper lit the basket once a
winter to call the Spire's boat in under the cliff — with what can burn in its basket (a
collier's charcoal fire, or a lantern lit off the Ridge Light hung on its hook), and a waymark
on the road with a collier's rake driven into its cairn (Abe and Tolly Dray's, that never once
agreed whose rake it was).

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_old_road.py
    .tools/bin/blender-py tools/blender/build_old_road.py [northing_cairn cresset_coals cresset_lantern waymark_rake]

Same conventions as build_dressing/build_woods: origin at the base centre, flat-shaded,
palette colours and tonal shades, Blender -Y = Godot +Z = the front, merged by material.
`cresset_coals` and `cresset_lantern` are overlays modelled at their place on `northing_cairn`,
so a region places them with the cairn's own `position` and `rotation_y`.
"""
import math
import os
import random
import sys

import bpy  # noqa: F401  (must be imported before mathutils when running as the bpy module)
from mathutils import Vector  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dressing as bd  # noqa: E402  (materials, primitives, merge + export)
import build_woods as bw  # noqa: E402  (rough lumps, the waymark)

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod

# The basket on top of the cairn: its floor, rim and radii; the hook the boat-lantern hangs on.
BASKET_FLOOR, BASKET_RIM = 2.05, 2.5
BASKET_R_LOW, BASKET_R_TOP = 0.24, 0.36
HOOK = Vector((0.0, -0.78, 2.12))   # the hook's tip is 0.2 below this; the lantern's glass centre 0.23 below the tip


def build_northing_cairn() -> None:
    """The Northing: a Keepers' cairn on the north cliff (~2.6 m to the basket's rim), dry-laid of
    the ridge's grey stone in four tapering courses, big stones low; an iron post up its middle
    carrying a fire-basket (a cresset of eight bars and two hoops) with grey ash in it; an iron arm
    reaching out to the front (-Y, Godot +Z) with a hook, where the keeper hung the boat-lantern;
    and the Keepers' ember (a flame in a ring) cut into a pale face-stone low on the front."""
    bd.reset()
    rng = random.Random(53)
    courses = ((0.78, 9, 0.3, 0.16), (0.6, 8, 0.26, 0.5), (0.42, 6, 0.22, 0.86), (0.24, 4, 0.18, 1.18))
    for c, (radius, count, size, z) in enumerate(courses):
        for k in range(count):
            a = k / count * math.tau + c * 0.4
            bw._lump("Cairn", (size * 1.1, size, size * 0.72), (math.cos(a) * radius, math.sin(a) * radius, z),
                     mat("slate", (-0.12, -0.28, -0.04, -0.2)[k % 4]), rng, 0.14)
        bw._lump("CairnCore", (radius * 0.9, radius * 0.9, 0.2), (0, 0, z), mat("slate", -0.35), rng, 0.08)
    for k in range(5):  # lichen, and the fog's silvering on the seaward (+Y, north) side
        a = rng.uniform(0, math.tau)
        z = rng.uniform(0.3, 1.2)
        r = 0.8 - z * 0.42
        box("Lichen", (0.16, 0.1, 0.03), (math.cos(a) * r, math.sin(a) * r, z), mat("silverfog", -0.2), a)
    # The face-stone with the ember cut in it, on the front.
    box("FaceStone", (0.5, 0.12, 0.42), (0, -0.78, 0.5), mat("bone", -0.35), 0.0)
    for k in range(8):
        a0, a1 = k / 8 * math.tau, (k + 1) / 8 * math.tau
        beam("Ring", (math.cos(a0) * 0.12, -0.845, 0.52 + math.sin(a0) * 0.12),
             (math.cos(a1) * 0.12, -0.845, 0.52 + math.sin(a1) * 0.12), 0.03, mat("ink", 0.2))
    beam("Flame", (0, -0.845, 0.44), (0, -0.845, 0.62), 0.035, mat("ink", 0.2), width=0.06)
    # The iron post and the basket on it.
    iron = mat("ink", 0.15)
    rod("Post", (0, 0, 1.1), (0, 0, BASKET_FLOOR), 0.06, iron, verts=6)
    cyl("Floor", BASKET_R_LOW, BASKET_R_LOW, 0.04, 8, (0, 0, BASKET_FLOOR), iron)
    for k in range(8):
        a = k / 8 * math.tau
        rod("Bar", (math.cos(a) * BASKET_R_LOW, math.sin(a) * BASKET_R_LOW, BASKET_FLOOR),
            (math.cos(a) * BASKET_R_TOP, math.sin(a) * BASKET_R_TOP, BASKET_RIM + 0.06), 0.018, iron, verts=4)
    for z, r in ((BASKET_FLOOR + 0.2, (BASKET_R_LOW + BASKET_R_TOP) / 2), (BASKET_RIM, BASKET_R_TOP)):
        for k in range(8):
            a0, a1 = k / 8 * math.tau, (k + 1) / 8 * math.tau
            beam("Hoop", (math.cos(a0) * r, math.sin(a0) * r, z), (math.cos(a1) * r, math.sin(a1) * r, z), 0.025, iron)
    cyl("Ash", BASKET_R_LOW - 0.02, BASKET_R_LOW + 0.04, 0.08, 8, (0, 0, BASKET_FLOOR + 0.04), mat("silverfog", -0.3))
    # The boat-lantern's arm out to the front, braced to the post, and its hook.
    beam("Arm", (0, 0.0, 1.98), (0, HOOK.y - 0.06, 1.98), 0.045, iron)
    beam("Brace", (0, 0.0, 1.55), (0, -0.45, 1.97), 0.035, iron)
    beam("Hook", (0, HOOK.y, 1.98), (0, HOOK.y, HOOK.z - 0.2), 0.022, iron)
    bd.export("northing_cairn")


def build_cresset_coals() -> None:
    """A collier's charcoal fire in the Northing's basket (overlay on `northing_cairn`): a heap of
    black charcoal banked over the ash, glowing coal-red through the gaps, as a collier builds one
    to last the night. Ordinary fire; the region gives it smoke, not a light."""
    bd.reset()
    rng = random.Random(54)
    for k in range(9):
        a = k / 9 * math.tau
        r = 0.17 if k % 3 else 0.06
        z = BASKET_FLOOR + 0.13 + (0.1 if k % 3 == 0 else 0.0)
        bw._lump("Char", (0.09, 0.08, 0.07), (math.cos(a) * r, math.sin(a) * r, z), mat("ink", 0.05), rng, 0.2)
    for k in range(6):
        a = k / 6 * math.tau + 0.5
        r = rng.uniform(0.06, 0.16)
        bw._lump("Glow", (0.07, 0.06, 0.05), (math.cos(a) * r, math.sin(a) * r, BASKET_FLOOR + 0.16),
                 mat("coal", 0.1, emissive=True), rng, 0.2)
    bw._lump("Heart", (0.1, 0.1, 0.05), (0, 0, BASKET_FLOOR + 0.12), mat("ember", 0.0, emissive=True), rng, 0.1)
    bd.export("cresset_coals")


def build_cresset_lantern() -> None:
    """A Keeper's lantern lit off the Ridge Light, hung on the Northing's boat-lantern hook (overlay
    on `northing_cairn`): iron cap and foot, gold behind horn. Glass centre at (0, -0.78, 1.69) in
    Blender = [0, 1.69, 0.78] in Godot model space, where the region puts its halo."""
    bd.reset()
    iron = mat("ink", 0.15)
    x, y, top = HOOK.x, HOOK.y, HOOK.z - 0.2
    beam("Bail", (x, y, top + 0.05), (x, y, top - 0.01), 0.015, iron)
    cyl("Cap", 0.15, 0.02, 0.13, 6, (x, y, top - 0.08), iron)
    cyl("Glass", 0.1, 0.1, 0.26, 6, (x, y, top - 0.36), mat("kindle", 0.0, emissive=True))
    cyl("Base", 0.12, 0.12, 0.04, 6, (x, y, top - 0.4), iron)
    for i in range(3):
        a = math.tau * i / 3
        beam("Frame", (x + math.cos(a) * 0.11, y + math.sin(a) * 0.11, top - 0.38),
             (x + math.cos(a) * 0.11, y + math.sin(a) * 0.11, top - 0.07), 0.02, iron)
    bd.export("cresset_lantern")


def build_waymark_rake() -> None:
    """A bare waymark on the old road with a collier's clamp rake driven upright into its cairn
    beside the post, iron head up and tines hanging, the pole notched on two sides (an A cut on one,
    a T on the other, and a newer notch across both): Abe and Tolly Dray's rake, left as a mark."""
    bd.reset()
    bw._waymark(False)
    pole, iron, cut = mat("driftwood", -0.25), mat("slate", -0.45), mat("bone", -0.1)
    foot, top = Vector((0.3, 0.12, 0.35)), Vector((0.36, 0.16, 2.05))
    rod("RakePole", foot, top, 0.024, pole, verts=5)
    beam("RakeHead", top + Vector((-0.2, 0, 0.02)), top + Vector((0.2, 0, 0.02)), 0.05, iron)
    for tx in (-0.15, -0.05, 0.05, 0.15):
        beam("Tine", top + Vector((tx, 0, 0.0)), top + Vector((tx, 0, -0.12)), 0.025, iron)
    for z, side in ((1.3, -1), (1.42, 1)):  # the two men's marks, one each side of the pole
        p = foot + (top - foot) * ((z - foot.z) / (top.z - foot.z))
        beam("Mark", p + Vector((side * 0.026, -0.03, 0)), p + Vector((side * 0.026, 0.03, 0)), 0.01, cut, width=0.02)
    p = foot + (top - foot) * ((1.6 - foot.z) / (top.z - foot.z))
    beam("Across", p + Vector((-0.03, -0.026, 0)), p + Vector((0.03, -0.026, 0)), 0.012, cut, width=0.02)
    bd.export("waymark_rake")


BUILDERS = [build_northing_cairn, build_cresset_coals, build_cresset_lantern, build_waymark_rake]

if __name__ == "__main__":
    only = {a for a in sys.argv[1:] if not a.startswith("-")}
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
