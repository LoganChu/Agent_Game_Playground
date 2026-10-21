"""Builds the kit for Thornwold's old Keepers' road north (Day 53) into the dressing kit: the
Northing — the Keepers' fire-cairn on the north cliff, where the keeper lit the basket once a
winter to call the Spire's boat in under the cliff — with what can burn in its basket (a
collier's charcoal fire, or a lantern lit off the Ridge Light hung on its hook), and a waymark
on the road with a collier's rake driven into its cairn (Abe and Tolly Dray's, that never once
agreed whose rake it was).

Day 55 adds the far shore below the Northing, at the foot of the Keepers' steps: the bottom flight of the steps cut
up the cliff (`steps_foot`), the Keepers' **boat-stage** where the Spire's boat came in (`boat_stage`; the lantern on
its bracket is the overlay `stage_lantern`, another prop family so the variant check reads it as an overlay), the
colliers' driftwood fire (`drift_fire`, raked out: `drift_fire_out`) and their lean-to against the cliff
(`drift_shelter`).

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_old_road.py
    .tools/bin/blender-py tools/blender/build_old_road.py [northing_cairn cresset_coals cresset_lantern waymark_rake
        steps_foot boat_stage stage_lantern drift_fire drift_fire_out drift_shelter]

Same conventions as build_dressing/build_woods: origin at the base centre, flat-shaded,
palette colours and tonal shades, Blender -Y = Godot +Z = the front, merged by material.
`cresset_coals` and `cresset_lantern` are overlays modelled at their place on `northing_cairn`,
so a region places them with the cairn's own `position` and `rotation_y`; `stage_lantern` is
modelled at its place on `boat_stage` the same way.
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
# The boat-stage's lantern bracket: the hook at the end of its arm, out over the water (front, -Y).
STAGE_HOOK = Vector((-0.85, -0.95, 2.3))


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


def _hung_lantern(hook: Vector) -> None:
    """A Keeper's lantern hanging from the tip of a hook 0.2 below `hook`: iron bail, cap and foot,
    gold behind horn; the glass centre is 0.43 below `hook`."""
    iron = mat("ink", 0.15)
    x, y, top = hook.x, hook.y, hook.z - 0.2
    beam("Bail", (x, y, top + 0.05), (x, y, top - 0.01), 0.015, iron)
    cyl("Cap", 0.15, 0.02, 0.13, 6, (x, y, top - 0.08), iron)
    cyl("Glass", 0.1, 0.1, 0.26, 6, (x, y, top - 0.36), mat("kindle", 0.0, emissive=True))
    cyl("Base", 0.12, 0.12, 0.04, 6, (x, y, top - 0.4), iron)
    for i in range(3):
        a = math.tau * i / 3
        beam("Frame", (x + math.cos(a) * 0.11, y + math.sin(a) * 0.11, top - 0.38),
             (x + math.cos(a) * 0.11, y + math.sin(a) * 0.11, top - 0.07), 0.02, iron)


def build_steps_foot() -> None:
    """The foot of the Keepers' steps on the far shore: a buttress of the cliff's grey rock (~5 m
    wide, 4.6 m tall) standing proud of the cliff, with steps cut up its front face along +X — the
    bottom one at the origin, ten steps rising 0.26 each — and on round the buttress's shoulder into
    the fog. An iron rail on pins along the open (front, -Y) side, rubbed bright where hands go. The
    Keepers' ember is cut in the bottom step's riser."""
    bd.reset()
    rng = random.Random(55)
    rock = mat("slate", -0.3)
    # The buttress: rough slabs stacked behind and above the flight.
    for k in range(7):
        x = -0.6 + k * 0.8
        h = 3.2 + rng.uniform(0.0, 1.4)
        bw._lump("Buttress", (0.62, 0.9, h / 2), (x, 1.15, h / 2), mat("slate", (-0.32, -0.2, -0.4)[k % 3]), rng, 0.1)
    bw._lump("Shoulder", (1.4, 1.0, 0.9), (4.6, 0.9, 3.4), rock, rng, 0.1)
    # The flight: ten cut steps, each a block 0.95 wide (along Y) against the rock, rising along +X.
    for k in range(10):
        x = k * 0.4
        z = (k + 1) * 0.26
        box("Step", (0.42, 0.95, z), (x, 0.0, 0.0), mat("slate", (-0.12, -0.18)[k % 2]), 0.0)
        box("Tread", (0.4, 0.9, 0.03), (x, -0.02, z - 0.01), mat("silverfog", -0.38), 0.0)  # worn hollow, pale
    # The ember cut in the bottom riser: a ring and a flame.
    for k in range(8):
        a0, a1 = k / 8 * math.tau, (k + 1) / 8 * math.tau
        beam("Ring", (-0.215, math.cos(a0) * 0.1, 0.13 + math.sin(a0) * 0.08),
             (-0.215, math.cos(a1) * 0.1, 0.13 + math.sin(a1) * 0.08), 0.02, mat("ink", 0.2))
    # The iron rail on pins along the front edge, climbing with the steps.
    iron = mat("ink", 0.15)
    rail = []
    for k in range(0, 11, 2):
        x = k * 0.4 - 0.15
        z = (min(k, 9) + 1) * 0.26
        rod("Pin", (x, -0.42, z), (x, -0.42, z + 0.85), 0.022, iron, verts=4)
        rail.append(Vector((x, -0.42, z + 0.85)))
    for a, b in zip(rail, rail[1:]):
        rod("Rail", a, b, 0.025, iron, verts=5)
    rod("Bright", rail[0], rail[1], 0.027, mat("bone", -0.2), verts=5)  # rubbed bright at the bottom
    bd.export("steps_foot")


def build_boat_stage() -> None:
    """The Keepers' boat-stage on the far shore, where the Spire's boat came in once a winter: the
    built end of a stone quay (the walkable stage is the region's ground; this is its dressing).
    Squared kerb stones along both sides and across the end (origin = the end's centre; the quay
    runs back along +Y); a stone bollard with an iron mooring ring worn bright on its seaward side; and at the right-hand corner a timber post with an
    iron bracket reaching out over the water (-Y) to an empty hook, where the boat's lantern hung."""
    bd.reset()
    rng = random.Random(56)
    for k in range(6):  # side kerbs, both sides, 4.8 m back from the end
        for side in (-1, 1):
            box("Kerb", (0.34, 0.78, 0.22), (side * 1.12, 0.4 + k * 0.8, 0.0), mat("slate", (-0.1, -0.25, -0.18)[(k + side) % 3]),
                rng.uniform(-0.03, 0.03))
    for k in range(3):  # across the end
        box("Kerb", (0.72, 0.34, 0.24), (-0.76 + k * 0.76, -0.1, 0.0), mat("slate", (-0.2, -0.08, -0.3)[k]), rng.uniform(-0.04, 0.04))
    # The bollard and its ring, bright where thirty winters of the same rope have worn it.
    cyl("Bollard", 0.2, 0.17, 0.5, 8, (0.55, 0.45, 0.0), mat("slate", -0.05))
    cyl("BollardCap", 0.2, 0.12, 0.08, 8, (0.55, 0.45, 0.5), mat("slate", -0.15))
    iron = mat("ink", 0.15)
    for k in range(8):
        a0, a1 = k / 8 * math.tau, (k + 1) / 8 * math.tau
        worn = mat("bone", -0.2) if k in (5, 6) else iron
        beam("MooringRing", (0.55 + math.cos(a0) * 0.1, 0.24, 0.32 + math.sin(a0) * 0.1),
             (0.55 + math.cos(a1) * 0.1, 0.24, 0.32 + math.sin(a1) * 0.1), 0.022, worn)
    # The boat's lantern bracket, at the right-hand corner of the end.
    post = mat("driftwood", -0.45)
    px, py = STAGE_HOOK.x, -0.05
    rod("LanternPost", (px, py, 0.0), (px, py, 2.45), 0.08, post, verts=6, r_end=0.065)
    cyl("PostCap", 0.09, 0.03, 0.08, 6, (px, py, 2.45), post)
    beam("BracketArm", (px, py + 0.05, STAGE_HOOK.z), (px, STAGE_HOOK.y - 0.06, STAGE_HOOK.z), 0.045, iron)
    beam("BracketBrace", (px, py, STAGE_HOOK.z - 0.45), (px, STAGE_HOOK.y + 0.42, STAGE_HOOK.z - 0.01), 0.035, iron)
    beam("Hook", (px, STAGE_HOOK.y, STAGE_HOOK.z), (px, STAGE_HOOK.y, STAGE_HOOK.z - 0.2), 0.022, iron)
    bd.export("boat_stage")


def build_stage_lantern() -> None:
    """The Ridge Light's lantern hung on the boat-stage's empty bracket (overlay on `boat_stage`): Ottie
    hung it where the boat's lantern went. Glass centre at Blender (-0.85, -0.95, 1.87) = Godot
    [-0.85, 1.87, 0.95] in model space, where the region puts its halo."""
    bd.reset()
    _hung_lantern(STAGE_HOOK)
    bd.export("stage_lantern")


def _drift_fire(lit: bool) -> None:
    rng = random.Random(57)
    for k in range(9):  # a ring of beach stones
        a = k / 9 * math.tau
        bw._lump("Stone", (0.14, 0.12, 0.09), (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.06),
                 mat("slate", (-0.05, -0.2, -0.3)[k % 3]), rng, 0.2)
    cyl("Ash", 0.38, 0.42, 0.04, 8, (0, 0, 0), mat("silverfog", -0.3 if lit else -0.15))
    wood = mat("driftwood", 0.15 if lit else -0.55)
    for k in range(5):  # driftwood sticks leaned in a cone (lit) / fallen in, charred (out)
        a = k / 5 * math.tau + 0.3
        if lit:
            rod("Stick", (math.cos(a) * 0.36, math.sin(a) * 0.36, 0.04), (math.cos(a) * 0.04, math.sin(a) * 0.04, 0.5), 0.035, wood, verts=5)
        else:
            rod("Stick", (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.05), (math.cos(a + 1.9) * 0.18, math.sin(a + 1.9) * 0.18, 0.06),
                0.03, wood, verts=5)
    if lit:
        for k in range(5):
            a = k / 5 * math.tau
            bw._lump("Glow", (0.07, 0.06, 0.05), (math.cos(a) * 0.15, math.sin(a) * 0.15, 0.07),
                     mat("coal", 0.1, emissive=True), rng, 0.2)
        bw._lump("Heart", (0.12, 0.12, 0.09), (0, 0, 0.1), mat("ember", 0.0, emissive=True), rng, 0.15)
    # The colliers' kettle on a stone, and a split-log seat.
    cyl("Kettle", 0.11, 0.08, 0.18, 7, (0.75, 0.2, 0.0), mat("ink", 0.1))
    rod("Seat", (-0.95, -0.35, 0.16), (-0.6, 0.6, 0.16), 0.15, mat("driftwood", 0.2), verts=6)


def build_drift_fire() -> None:
    """The colliers' fire on the far shore: a ring of beach stones, driftwood leaned in a cone over a
    red heart (the sea's leavings: the fog lets it be, the way it lets a collier's clamp be), a black
    kettle on a stone and a driftwood log for a seat. Ordinary fire: the region gives it smoke, not
    a light, and it clears no fog."""
    bd.reset()
    _drift_fire(lit=True)
    bd.export("drift_fire")


def build_drift_fire_out() -> None:
    """The same fire raked out once the colliers have gone up the steps: grey ash, the sticks fallen
    in and charred, the kettle left on its stone."""
    bd.reset()
    _drift_fire(lit=False)
    bd.export("drift_fire_out")


def build_drift_shelter() -> None:
    """The colliers' lean-to against the cliff foot: driftwood poles leaned on a ridge-pole propped
    on two forked sticks, roofed with charcoal sacks split and pegged out, three folded sacks for
    bedding under it. Front (-Y) open; the back (+Y) goes against the rock."""
    bd.reset()
    rng = random.Random(58)
    wood = mat("driftwood", 0.2)
    for x in (-1.1, 1.1):
        rod("Fork", (x, -0.4, 0.0), (x, -0.4, 1.35), 0.05, wood, verts=5)
    rod("Ridge", (-1.3, -0.4, 1.35), (1.3, -0.4, 1.38), 0.055, wood, verts=5)
    for k in range(6):
        x = -1.15 + k * 0.46
        rod("Pole", (x, -0.42, 1.38), (x + rng.uniform(-0.08, 0.08), 0.75, 0.0), 0.04, mat("driftwood", (0.2, 0.0, 0.3)[k % 3]), verts=5)
    for k in range(4):  # the sacking roof, in strips laid over the poles
        x = -0.95 + k * 0.62
        beam("Sacking", (x, -0.38, 1.33), (x, 0.7, 0.06), 0.03, mat("driftwood", (-0.4, -0.5, -0.35, -0.45)[k]), width=0.6)
    for k in range(3):
        bw._sack((-0.7 + k * 0.7, 0.1, 0.0), rng, lying=True, shade=-0.35)
    bd.export("drift_shelter")


BUILDERS = [build_northing_cairn, build_cresset_coals, build_cresset_lantern, build_waymark_rake,
            build_steps_foot, build_boat_stage, build_stage_lantern, build_drift_fire, build_drift_fire_out,
            build_drift_shelter]

if __name__ == "__main__":
    only = {a for a in sys.argv[1:] if not a.startswith("-")}
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
