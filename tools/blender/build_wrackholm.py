"""Builds Wrackholm's first kit (Day 40) into the dressing kit: the Tidewrights' **lane-house**
(where masters are sworn: a long low hall of black island stone, its turf roof roped down with
old hawsers weighted with stones, its door to the sea), the **answering horn** on its frame by
the door (lashed shut since the Snuffing), the **Gannet** hauled up on the hard (stove in on the
Teeth, her copper half stripped, her crew board gone blank), the yard's **salvage stacks** and
**come-home pile** of glass floats, and Wrackholm's beacon, **the Wrack Light**, dark on its stack
out on the Teeth.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_wrackholm.py
    .tools/bin/blender-py tools/blender/build_wrackholm.py [lane_house answering_horn gannet_hulk
        salvage_stack float_pile wrack_light teeth_rock teeth_mark answering_horn_open gannet_hulk_bare
        gannet_hulk_named
        wrack_light_lit]

Day 42 (the Teeth): `teeth_rock` (a low reef slab of black rock, wrack-weed round its foot) and
`teeth_mark` (the same slab with a lampwarden's white-lead mark on its back, a hand's width:
"put your feet where the white is"); the Wrack Light's ships' timbers each carry their lead tag.

Day 43 (the Wrack's burning): `wrack_light_lit` (gold through the horn, a fire in the cradle),
`answering_horn_open` (unlashed and sounded) and `gannet_hulk_bare` (her crew board prised off).
Day 44: `gannet_hulk_named` (the board chalked again once the ember has read it).

Same conventions as build_dressing/build_fen: origin at the base centre, flat-shaded, palette
colours and tonal shades, Blender -Y = Godot +Z = the front, merged by material.
"""
import math
import os
import random
import sys

import bpy  # noqa: F401  (must be imported before mathutils when running as the bpy module)
from mathutils import Vector  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dressing as bd  # noqa: E402  (materials, primitives, merge + export)

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod

# The lane-house's proportions (the region's collider [10.4, 3.6, 5.0] fits them).
HALL_L, HALL_D, HALL_H = 10.0, 4.6, 2.2
# Where the chimney's smoke leaves, in Godot model space (x, y, -Blender y): the region's `smoke`.
HALL_SMOKE = (4.1, 4.35, 0.6)
# The Gannet's crew board on her transom, Godot model space (the region places the inspectable
# with it; tests/test_wrackholm.gd checks the object stands at it).
GANNET_BOARD = (0.0, 1.3, -3.25)


def _stone(rng: random.Random):
    """One of the island's black stones (dark shades of ink and slate, a few paler)."""
    return rng.choice((mat("ink", 0.22), mat("ink", 0.3), mat("slate", -0.55), mat("slate", -0.45)))


def build_lane_house() -> None:
    """Wrackholm's lane-house (~4.3 m to the ridge): a long low hall of dry-laid black stone in
    rough courses, pale quoins at the corners; a low-pitched turf roof **roped down with old
    hawsers, a hanging stone at each end** (wind off the Teeth); a heavy plank door to the sea
    under a lintel that was a ship's beam, an iron hand-scale on a bracket over it (the Guild's
    sign: deeds are weighed here); two shuttered windows with **a line of firelight in the crack**
    (they're inside, round a fire that doesn't help); a stone chimney at the east gable."""
    bd.reset()
    rng = random.Random(40)
    hx, hy = HALL_L / 2, HALL_D / 2
    box("Core", (HALL_L - 0.1, HALL_D - 0.1, HALL_H), (0, 0, 0), mat("ink", 0.25))
    # Courses: a band of stones proud of each face, staggered, every course a little different.
    course = 0.36
    for c in range(int(HALL_H / course)):
        z = c * course
        for face, (length, n, along) in enumerate(((HALL_L, Vector((0, -1, 0)), Vector((1, 0, 0))),
                                                   (HALL_L, Vector((0, 1, 0)), Vector((1, 0, 0))),
                                                   (HALL_D, Vector((1, 0, 0)), Vector((0, 1, 0))),
                                                   (HALL_D, Vector((-1, 0, 0)), Vector((0, 1, 0))))):
            dist = hy if face < 2 else hx
            x = -length / 2 + (0.3 if c % 2 else 0.0)
            while x < length / 2 - 0.2:
                w = min(rng.uniform(0.55, 1.1), length / 2 - x)
                centre = n * (dist + 0.02) + along * (x + w / 2) + Vector((0, 0, z + 0.02))
                if face == 0 and abs(x + w / 2) < 0.75 and z < 1.85:  # the doorway
                    x += w
                    continue
                size = (w - 0.05, 0.12, course - 0.05) if face < 2 else (0.12, w - 0.05, course - 0.05)
                box("Stone", size, tuple(centre), _stone(rng))
                x += w
    # Quoins: big pale blocks at each corner, alternating long and short.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for c in range(int(HALL_H / course)):
                long_x = c % 2 == 0
                size = (0.7 if long_x else 0.4, 0.4 if long_x else 0.7, course - 0.03)
                box("Quoin", size, (sx * (hx - size[0] / 2 + 0.06), sy * (hy - size[1] / 2 + 0.06), c * course + 0.01),
                    mat("slate", -0.05))
    # The doorway: a recess, a heavy plank door, the ship's-beam lintel, a worn sill stone.
    box("Doorway", (1.3, 0.1, 1.9), (0, -hy - 0.02, 0), mat("ink", 0.05))
    for k in range(4):
        box("Door", (0.27, 0.08, 1.8), (-0.42 + k * 0.28, -hy - 0.1, 0.02), mat("driftwood", -0.5))
    for z in (0.35, 1.45):
        box("DoorBand", (1.18, 0.04, 0.07), (0, -hy - 0.15, z), mat("ink", 0.15))
    beam("Lintel", (-0.95, -hy - 0.12, 2.0), (0.95, -hy - 0.12, 2.0), 0.24, mat("driftwood", -0.5), width=0.3)
    box("Sill", (1.6, 0.6, 0.12), (0, -hy - 0.3, 0), mat("slate", -0.45))
    # The Guild's sign over the door: an iron hand-scale on a bracket, pans at rest.
    iron = mat("ink", 0.15)
    beam("SignBracket", (0, -hy - 0.12, 2.35), (0, -hy - 0.62, 2.35), 0.05, iron)
    rod("ScaleCord", (0, -hy - 0.58, 2.33), (0, -hy - 0.58, 2.12), 0.012, iron, verts=4)
    beam("ScaleBeam", (-0.32, -hy - 0.58, 2.12), (0.32, -hy - 0.58, 2.12), 0.035, iron)
    for px in (-0.3, 0.3):
        rod("ScaleChain", (px, -hy - 0.58, 2.12), (px, -hy - 0.58, 1.9), 0.008, iron, verts=3)
        cyl("ScalePan", 0.11, 0.13, 0.04, 8, (px, -hy - 0.58, 1.86), iron)
    # Two shuttered windows, firelight showing in the crack between the shutters.
    glow = mat("ember", 0.1, emissive=True)
    for wx in (-3.0, 3.0):
        box("WindowRecess", (0.9, 0.08, 0.8), (wx, -hy - 0.02, 0.95), mat("ink", 0.05))
        for s in (-1, 1):
            box("Shutter", (0.4, 0.08, 0.72), (wx + s * 0.215, -hy - 0.08, 0.99), mat("driftwood", -0.5))
        box("Firelight", (0.035, 0.05, 0.66), (wx, -hy - 0.06, 1.02), glow)
    # The turf roof: two low slopes, a thick turf skin with ragged edges hanging over the eaves.
    eave_z, ridge_z = HALL_H, HALL_H + 1.55
    run = hy + 0.45
    TURF = (mat("moss", -0.42), mat("moss", -0.5), mat("moss", -0.42))
    for s in (-1, 1):
        beam("Turf", (0, s * run, eave_z - 0.12), (0, s * 0.04, ridge_z + 0.12), 0.34, TURF[0], width=HALL_L + 0.7)
        for k in range(14):
            x = -hx - 0.2 + k * (HALL_L + 0.4) / 13
            beam("TurfLip", (x, s * (run + 0.02), eave_z - 0.05), (x + s * 0.0, s * (run + 0.12), eave_z - 0.32),
                 0.2, TURF[1 + k % 2], width=0.6)
    beam("RidgeTurf", (-hx - 0.3, 0, ridge_z + 0.1), (hx + 0.3, 0, ridge_z + 0.1), 0.26, TURF[1], width=0.5)
    # Gable ends: stone triangles under the roof, course by course narrowing.
    for sx in (-1, 1):
        for c in range(4):
            z = eave_z + c * 0.38
            half = hy * (1 - (c + 0.5) / 4.2)
            box("Gable", (0.5, half * 2, 0.38), (sx * (hx - 0.25), 0, z), _stone(rng))
    # Old hawsers over the roof, weighted with a slung stone at each end (they lie on the turf).
    HAWSER = mat("driftwood", -0.4)
    for x in (-3.6, -1.2, 1.2, 3.6):
        for s in (-1, 1):
            beam("Hawser", (x, 0, ridge_z + 0.26), (x, s * (run - 0.05), eave_z + 0.12), 0.07, HAWSER)
            rod("HawserEnd", (x, s * (run + 0.02), eave_z + 0.1), (x, s * (run + 0.1), eave_z - 0.55), 0.035, HAWSER, verts=4)
            cyl("WeightStone", 0.2, 0.16, 0.3, 6, (x, s * (run + 0.12), eave_z - 0.92), _stone(rng))
    # The chimney at the east gable, smoke-dark at the top (smoke from HALL_SMOKE).
    box("Chimney", (0.8, 0.8, 1.6), (HALL_SMOKE[0], -HALL_SMOKE[2], ridge_z - 0.9), mat("ink", 0.25))
    box("ChimneyCap", (0.95, 0.95, 0.12), (HALL_SMOKE[0], -HALL_SMOKE[2], HALL_SMOKE[1] - 0.12), mat("ink", 0.15))
    # A stone mounting step by the door and a coil of rope on a peg.
    beam("Peg", (1.1, -hy - 0.05, 1.5), (1.1, -hy - 0.25, 1.52), 0.05, mat("driftwood", -0.5))
    cyl("RopeCoil", 0.17, 0.17, 0.12, 8, (1.1, -hy - 0.2, 1.24), HAWSER)
    bd.export("lane_house")


def build_answering_horn(open_: bool = False) -> None:
    """The answering horn (~2.7 m): a long horn of black wood bound in brass, big enough that it
    takes two to sound it, slung under a beam between two posts with its bell to the sea (-Y) and
    its mouthpiece at a standing mouth's height at the back. **Lashed**: a sailcloth bung in the
    bell, tarred line crossed over it, and turns of tarred line round the mouthpiece (Wenna Garrow
    lashed it the night the Gannet struck).

    `open_` (Day 43, `answering_horn_open`, once the Wrack is lit and the horn sounded): the bung out
    and the lashing cut away, the bell's mouth black and open, the cut line hanging in a coil off the
    seaward post."""
    bd.reset()
    WOOD, BRASS = mat("ink", 0.12), mat("ember", -0.4)
    POST, TAR = mat("driftwood", -0.5), mat("ink", 0.02)
    for y in (-1.05, 1.05):
        rod("Post", (0, y, 0), (0, y, 2.55), 0.11, POST, verts=6)
        cyl("PostFoot", 0.24, 0.2, 0.22, 6, (0, y, 0), mat("slate", -0.4))
    beam("Beam", (0, -1.25, 2.55), (0, 1.25, 2.55), 0.16, POST, width=0.18)
    # The horn: a cone along Y from the mouthpiece (back, low) to the bell (front, higher).
    mouth, bell = Vector((0, 1.35, 1.5)), Vector((0, -1.3, 1.85))
    rod("Horn", tuple(mouth), tuple(bell), 0.05, WOOD, verts=10, r_end=0.42)
    for t in (0.2, 0.55, 0.88):
        p = mouth + (bell - mouth) * t
        r = 0.05 + 0.37 * t
        rod("Band", tuple(p - (bell - mouth).normalized() * 0.03), tuple(p + (bell - mouth).normalized() * 0.03),
            r + 0.02, BRASS, verts=10)
    rod("Mouthpiece", tuple(mouth + Vector((0, 0.18, -0.02))), tuple(mouth), 0.035, BRASS, verts=8, r_end=0.05)
    # The slings: rope from the beam round the horn, front and back.
    for t in (0.3, 0.75):
        p = mouth + (bell - mouth) * t
        r = 0.05 + 0.37 * t
        for s in (-1, 1):
            rod("Sling", (s * 0.06, p.y, 2.48), (s * (r + 0.02), p.y, p.z), 0.022, mat("driftwood", -0.3), verts=4)
    # Lashed: a sailcloth bung in the bell, two tarred lines crossed over it and turned round the
    # bell's rim; turns of tarred line wound thick round the mouthpiece.
    d = (bell - mouth).normalized()
    if open_:
        # Unlashed: the bell's dark throat, the cut line coiled and hung off the seaward post.
        rod("Throat", tuple(bell - d * 0.25), tuple(bell + d * 0.005), 0.33, mat("ink", 0.0), verts=10, r_end=0.39)
        for k in range(4):
            cyl("CutLine", 0.16 - k * 0.01, 0.16 - k * 0.01, 0.035, 8, (0.12, -1.05, 1.15 - k * 0.05), TAR, k * 0.4)
        rod("CutEnd", (0.12, -1.05, 1.0), (0.14, -1.1, 0.55), 0.015, TAR, verts=3)
        bd.export("answering_horn_open")
        return
    rod("Bung", tuple(bell - d * 0.1), tuple(bell + d * 0.01), 0.4, mat("bone", -0.12), verts=10)
    for a in (math.radians(45), math.radians(-45)):
        off = Vector((math.cos(a), 0, math.sin(a))) * 0.43
        beam("Lash", tuple(bell + d * 0.03 + off), tuple(bell + d * 0.03 - off), 0.035, TAR)
        for s in (-1, 1):  # each line's end turned back round the rim
            beam("LashTurn", tuple(bell + d * 0.03 + off * s), tuple(bell - d * 0.12 + off * s * 1.08), 0.035, TAR)
    for k in range(5):
        p = mouth + d * (0.05 + k * 0.06)
        rod("MouthLash", tuple(p - d * 0.02), tuple(p + d * 0.02), 0.075, TAR, verts=8)
    rod("LashEnd", tuple(mouth + d * 0.3 + Vector((0.06, 0, -0.02))), (0.08, 0.95, 1.0), 0.015, TAR, verts=3)
    bd.export("answering_horn")


# The Gannet: a 6.4 m Tidewright salvage boat, bow at -Y. Raised on keel blocks.
GANNET = dict(length=6.4, half_beam=1.15, depth=1.0, sheer=1.15)


def build_gannet_hulk(bare: bool = False, named: bool = False) -> None:
    """The Gannet, hauled up on Wrackholm's hard on keel blocks and shores, listing a little to
    port: dark tarred clinker, a tide-blue sheer strake, a mast stump. **Stove in at the bow** on
    the Teeth (planks sprung out, a black hole), **her copper sheathing half stripped** (green-
    brown sheets still on the starboard bottom, torn sheets stacked on the shingle beside her),
    and on her transom **the crew board** — black-painted, the chalk gone the grey of slate
    (GANNET_BOARD; the region's `gannet_board` object reads it).

    `bare` (Day 43, `gannet_hulk_bare`): the board prised off for the Wrack — a cleaner square of
    tar where it hung, two empty nail holes.

    `named` (Day 44, `gannet_hulk_named`): the board after the ember brought the chalk back
    (`wrackholm_board_read`) — three lines of white chalk on the black, the master's longest."""
    bd.reset()
    rng = random.Random(41)
    lift = 0.38
    st = bd.hull_stations(GANNET["length"], GANNET["half_beam"], GANNET["depth"], GANNET["sheer"], stations=9)
    st = [(y, w, s + lift, k + lift) for y, w, s, k in st]
    bd.hull("Hull", st, GANNET["depth"], GANNET["sheer"] + lift, mat("ink", 0.2))
    bd.gunwale("Rail", st, mat("driftwood", -0.35), thick=0.08)
    bd.gunwale("Strake", st, mat("tide", -0.35), thick=0.06, drop=0.16)
    bd.deck("Foredeck", st, 2, mat("driftwood", -0.3))
    for y in (-0.4, 0.9, 2.0):
        box("Thwart", (1.6, 0.24, 0.06), (0, y, GANNET["sheer"] + lift - 0.22), mat("driftwood", -0.25))
    rod("MastStump", (0, -0.6, lift + 0.2), (0, -0.6, lift + 2.1), 0.09, mat("driftwood", -0.3), r_end=0.07)
    # Stove in at the port bow: a black hole with sprung planks standing out of it.
    box("Hole", (0.08, 1.0, 0.55), (-0.62, -2.15, lift + 0.4), mat("ink", 0.02))
    for k in range(4):
        y = -2.55 + k * 0.26
        beam("Sprung", (-0.66, y, lift + 0.45 + 0.1 * k), (-0.98 - 0.08 * k, y - 0.1, lift + 0.95 - 0.05 * k), 0.04,
             mat("driftwood", -0.45), width=0.14)
    # Copper sheathing still on the starboard bottom (sheets in rows); the port side stripped.
    COPPER = (mat("coal", -0.15), mat("moss", -0.25), mat("coal", -0.3))
    for i, (y, w, s, k) in enumerate(st[2:7]):
        for row in range(2):
            z = k + 0.12 + row * 0.24
            box("Copper", (0.04, 0.6, 0.22), (w * (0.55 + 0.18 * row), y, z), COPPER[(i + row) % 3], -0.08)
    # Keel blocks under her and two shores holding her upright.
    for y in (-2.2, 0.0, 2.2):
        box("KeelBlock", (0.7, 0.5, lift - 0.02), (0, y, 0), mat("driftwood", -0.2 - 0.05 * (abs(y) > 1)))
    for y in (-1.0, 1.4):
        rod("Shore", (-1.85, y, 0.0), (-1.05, y, lift + 0.75), 0.06, mat("driftwood", -0.15), verts=5)
        rod("Shore", (1.85, y, 0.0), (1.05, y, lift + 0.7), 0.06, mat("driftwood", -0.15), verts=5)
    # Torn sheets stacked on the shingle by her starboard quarter, and a pry bar laid on them.
    for k in range(4):
        box("TornSheet", (0.62, 0.42, 0.025), (1.75, 1.3 + rng.uniform(-0.05, 0.05), 0.03 * k), COPPER[k % 3],
            rng.uniform(-0.25, 0.25))
    beam("PryBar", (1.5, 1.05, 0.14), (2.05, 1.6, 0.14), 0.035, mat("ink", 0.15))
    # The crew board on the transom: black paint, blank as slate (the chalk gone).
    bx, bz, by = GANNET_BOARD[0], GANNET_BOARD[1], -GANNET_BOARD[2]
    if bare:
        box("BoardScar", (0.95, 0.02, 0.34), (bx, by + 0.015, bz - 0.17), mat("ink", 0.14))
        for x in (-0.42, 0.42):
            cyl("NailHole", 0.02, 0.02, 0.02, 4, (bx + x, by + 0.03, bz - 0.01), mat("ink", -0.1))
        bd.export("gannet_hulk_bare")
        return
    box("CrewBoard", (0.95, 0.05, 0.34), (bx, by + 0.03, bz - 0.17), mat("ink", 0.06))
    if not named:
        box("Blank", (0.82, 0.02, 0.24), (bx, by + 0.065, bz - 0.12), mat("silverfog", -0.4))
    else:
        # HALE CORBET, master / ANNIS CORBET / RUAN PASK: words as chalk strokes, a gap between.
        chalk = mat("bone", 0.1)
        for row, words in enumerate(((0.16, 0.24, 0.2), (0.2, 0.24), (0.16, 0.16))):
            x = 0.36  # read from outside the transom (+Y), so the lines start at +X
            for w in words:
                box("Chalk", (w, 0.012, 0.035), (bx + x - w / 2, by + 0.06, bz - 0.04 - 0.085 * row), chalk)
                x -= w + 0.06
    for x in (-0.42, 0.42):
        cyl("BoardNail", 0.02, 0.02, 0.02, 4, (bx + x, by + 0.07, bz - 0.01), mat("ember", -0.4))
    bd.export("gannet_hulk_named" if named else "gannet_hulk")


def build_salvage_stack() -> None:
    """The yard keeps what the sea gives back, sorted: a stack of reclaimed planks on bearers,
    a curved oak knee and a broken rib on top, a coil of chain, two blocks; **a lead tag nailed on
    the end of the stack** (the yard's mark: held a year and a tide for its owner)."""
    bd.reset()
    rng = random.Random(43)
    for y in (-0.9, 0.0, 0.9):
        box("Bearer", (1.5, 0.2, 0.16), (0, y, 0), mat("driftwood", -0.45))
    for layer in range(5):
        for k in range(3):
            x = -0.45 + k * 0.45 + rng.uniform(-0.03, 0.03)
            box("Plank", (0.4, 2.3 + rng.uniform(-0.2, 0.15), 0.07), (x, rng.uniform(-0.08, 0.08), 0.16 + layer * 0.08),
                mat("driftwood", -0.15 - 0.08 * ((layer + k) % 3)), rng.uniform(-0.03, 0.03))
    top = 0.16 + 5 * 0.08
    beam("Knee", (0.1, -0.6, top + 0.05), (0.1, 0.1, top + 0.08), 0.16, mat("coal", -0.5), width=0.2)
    beam("KneeUp", (0.1, 0.1, top + 0.08), (0.12, 0.25, top + 0.65), 0.16, mat("coal", -0.5), width=0.2)
    beam("Rib", (-0.4, -0.9, top + 0.1), (-0.2, 0.8, top + 0.2), 0.1, mat("driftwood", 0.05), width=0.12)
    cyl("Chain", 0.32, 0.3, 0.14, 8, (1.2, 0.5, 0), mat("coal", -0.6))
    cyl("ChainTop", 0.18, 0.12, 0.1, 8, (1.2, 0.5, 0.14), mat("coal", -0.6))
    for k, p in enumerate(((1.1, -0.6, 0), (1.35, -0.3, 0))):
        box("Block", (0.22, 0.14, 0.3), p, mat("driftwood", -0.3), 0.3 * k)
        cyl("Sheave", 0.09, 0.09, 0.02, 6, (p[0], p[1] - 0.08, 0.14), mat("ink", 0.2))
    box("LeadTag", (0.16, 0.02, 0.1), (0, -1.21, 0.36), mat("slate", 0.05))
    bd.export("salvage_stack")


def build_float_pile() -> None:
    """The yard's come-home pile: glass net-floats in cages of tarred cord heaped in an old net by
    a post — green and bottle-blue, a few bone-pale with salt. Floats are the one thing the sea
    always gives back; past a year and a tide nobody has claimed these."""
    bd.reset()
    rng = random.Random(44)
    rod("Post", (0.55, 0.2, 0), (0.55, 0.2, 1.3), 0.08, mat("driftwood", -0.45), verts=5)
    GLASS = (mat("moss", 0.1, emissive=False), mat("tide", 0.05), mat("moss", -0.15), mat("bone", -0.2))
    CORD = mat("ink", 0.1)
    placed = []
    for k in range(13):
        layer = 0 if k < 8 else (1 if k < 12 else 2)
        r = rng.uniform(0.12, 0.17)
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.0, 0.42 - 0.14 * layer)
        p = Vector((math.cos(a) * d - 0.1, math.sin(a) * d, r * 0.9 + layer * 0.2))
        if any((p - q).length < 0.2 for q in placed):
            continue
        placed.append(p)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=r, location=tuple(p))
        bd.bp.finish(bpy.context.active_object, GLASS[k % 4])
        beam("Cage", tuple(p + Vector((0, 0, -r - 0.01))), tuple(p + Vector((0, 0, r + 0.01))), 0.012, CORD, width=r * 2.1)
    box("NetHeap", (1.1, 0.95, 0.05), (-0.1, 0, 0), mat("slate", -0.35), 0.2)
    bd.export("float_pile")


def _anchor(top: Vector, iron) -> None:
    """Wrackholm's sign on the roof, as the Gull's Beacon wears an iron gull, the Ridge Light an
    iron pine and the Heron a heron: an iron anchor, flukes down, ring up."""
    rod("Shank", tuple(top), tuple(top + Vector((0, 0, 0.75))), 0.03, iron, verts=5)
    cyl("Ring", 0.08, 0.08, 0.03, 8, tuple(top + Vector((0, 0, 0.78))), iron)
    beam("Stock", tuple(top + Vector((-0.22, 0, 0.62))), tuple(top + Vector((0.22, 0, 0.62))), 0.035, iron)
    for s in (-1, 1):
        beam("Arm", tuple(top + Vector((0, 0, 0.08))), tuple(top + Vector((s * 0.26, 0, 0.28))), 0.04, iron)
        beam("Fluke", tuple(top + Vector((s * 0.26, 0, 0.28))), tuple(top + Vector((s * 0.2, 0, 0.4))), 0.06, iron)


def build_wrack_light(lit: bool = False) -> None:
    """Wrackholm's beacon, the Wrack Light (~12 m from the stack's foot to the vane), dark: a ragged
    stack of black rock standing out of the Teeth, and on it a squat round tower of the same black
    stone, ringed with pale stone every few courses (Wrackholm builds low and heavy against the
    sea); a lantern room framed in **reclaimed ships' timbers**, horn panes, dark; a copper roof
    gone green; an iron anchor for a vane. Placed with its foot on the seabed (`snap: false`);
    seen from the hard through the fog, out of reach.

    `lit` (Day 43, `wrack_light_lit`, after Wrackholm's burning): the horn panes glow gold, a fire
    stands in the cradle (coals, ember tongues, a kindle heart, as at the Heron), and the lead tags
    on the timbers catch it."""
    bd.reset()
    rng = random.Random(45)
    # The stack: stacked, tilted rock blocks narrowing upward.
    z = 0.0
    for k in range(5):
        r = 2.4 - k * 0.3
        cyl("Stack", r, r * 0.86, 0.75, 7, (rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), z), _stone(rng),
            rng.uniform(0, math.tau))
        z += 0.7
    base = z
    # The tower: courses of black stone, a pale band every third.
    for c in range(9):
        shade = mat("slate", -0.05) if c % 3 == 2 else _stone(rng)
        cyl("Course", 1.35 - c * 0.025, 1.33 - c * 0.025, 0.42, 10, (0, 0, base + c * 0.4), shade, c * 0.17)
    top = base + 9 * 0.4
    box("Door", (0.7, 0.1, 1.3), (0, -1.33, base + 0.05), mat("driftwood", -0.55))
    cyl("Gallery", 1.6, 1.6, 0.14, 10, (0, 0, top), mat("driftwood", -0.4))
    # The lantern room: eight ships'-timber posts, horn panes between them (dark), a sill.
    TIMBER = mat("coal", -0.55)
    LEAD = mat("slate", 0.25)
    for k in range(8):
        a = k / 8 * math.tau
        rod("Timber", (math.cos(a) * 0.95, math.sin(a) * 0.95, top + 0.14), (math.cos(a) * 0.9, math.sin(a) * 0.9, top + 1.55),
            0.08, TIMBER, verts=4)
        # Every timber off a boat that never came home keeps the yard's lead tag (Day 42).
        box("Tag", (0.1, 0.03, 0.14), (math.cos(a) * 1.02, math.sin(a) * 1.02, top + 0.7 + (k % 3) * 0.12), LEAD,
            a + math.pi / 2)
    pane = bd.horn("kindle", 0.3, glow=0.35) if lit else mat("driftwood", -0.5)
    cyl("Panes", 0.9, 0.86, 1.3, 8, (0, 0, top + 0.2), pane, math.pi / 8)
    if lit:
        # The fire in the cradle, seen through the horn: red coals, ember tongues, a kindle heart.
        cyl("Cradle", 0.3, 0.24, 0.1, 8, (0, 0, top + 0.16), mat("ink", 0.1))
        cyl("Coals", 0.26, 0.18, 0.14, 7, (0, 0, top + 0.26), mat("coal", 0.0, emissive=True))
        for k in range(6):
            a = k / 6 * math.tau + 0.2
            r = 0.1 + 0.04 * (k % 2)
            h = 0.45 + 0.12 * ((k * 3) % 5) / 4
            tongue = cyl("Tongue", 0.1, 0.0, h, 4, (math.cos(a) * r, math.sin(a) * r, top + 0.36),
                         mat("ember", 0.0, emissive=True), a)
            tongue.rotation_euler = (math.sin(a) * 0.22, -math.cos(a) * 0.22, 0)
        cyl("Heart", 0.1, 0.0, 0.65, 5, (0, 0, top + 0.36), mat("kindle", 0.0, emissive=True))
    cyl("Head", 1.05, 1.05, 0.12, 8, (0, 0, top + 1.5), TIMBER)
    # The copper roof, gone green, and the anchor.
    cyl("Roof", 1.2, 0.08, 1.0, 8, (0, 0, top + 1.62), mat("moss", 0.05))
    _anchor(Vector((0, 0, top + 2.6)), mat("ink", 0.15))
    bd.export("wrack_light_lit" if lit else "wrack_light")


# The reef slab's top, Godot model space: where a mark sits and the player's feet go.
TEETH_TOP = 0.42


def _teeth_slab(rng: random.Random) -> None:
    """A low reef slab (~2.2 x 1.5 m, top ~0.42 m over its origin): two or three tilted black
    blocks worn flat on top, the wet foot darker, a skirt of wrack-weed round it at the tide line."""
    WET = mat("ink", 0.12)
    for k in range(3):
        w, d = rng.uniform(0.8, 1.2), rng.uniform(0.7, 1.0)
        h = TEETH_TOP - (0.0 if k == 0 else rng.uniform(0.05, 0.14))
        cyl("Slab", w * 0.75, w * 0.62, h, 6, ((k - 1) * 0.6, rng.uniform(-0.2, 0.2), 0), _stone(rng), rng.uniform(0, math.tau))
        cyl("Wet", w * 0.8, w * 0.78, 0.12, 6, ((k - 1) * 0.6, 0, -0.04), WET, rng.uniform(0, math.tau))
    WEED = (mat("moss", -0.55), mat("driftwood", -0.6))
    for k in range(9):
        a = k / 9 * math.tau + rng.uniform(-0.2, 0.2)
        p = Vector((math.cos(a) * 1.25, math.sin(a) * 0.85, 0.02))
        tip = p + Vector((math.cos(a) * 0.35, math.sin(a) * 0.25, rng.uniform(-0.02, 0.05)))
        beam("Weed", tuple(p), tuple(tip), 0.03, WEED[k % 2], width=0.22)


def build_teeth_rock() -> None:
    """One of the Teeth at low water: a low black reef slab, weed round its foot."""
    bd.reset()
    _teeth_slab(random.Random(46))
    bd.export("teeth_rock")


def build_teeth_mark() -> None:
    """A slab of the Teeth carrying a lampwarden's mark: a daub of white lead a hand wide on its
    flat back, five finger-strokes off the heel of it toward the Wrack (Godot -X), every spring
    renewed. The fog had them off; the ember brings them back."""
    bd.reset()
    _teeth_slab(random.Random(47))
    WHITE = mat("bone", 0.35)
    box("Daub", (0.24, 0.2, 0.02), (0.05, 0, TEETH_TOP - 0.005), WHITE, 0.0)
    for f in range(4):
        y = -0.075 + f * 0.05
        beam("Stroke", (-0.07, y, TEETH_TOP + 0.005), (-0.2 - (0.03 if f in (1, 2) else 0.0), y * 1.15, TEETH_TOP + 0.005),
             0.02, WHITE, width=0.035)
    bd.export("teeth_mark")


BUILDERS = {
    "lane_house": build_lane_house,
    "answering_horn": build_answering_horn,
    "answering_horn_open": lambda: build_answering_horn(open_=True),
    "gannet_hulk": build_gannet_hulk,
    "gannet_hulk_bare": lambda: build_gannet_hulk(bare=True),
    "gannet_hulk_named": lambda: build_gannet_hulk(named=True),
    "salvage_stack": build_salvage_stack,
    "float_pile": build_float_pile,
    "wrack_light": build_wrack_light,
    "wrack_light_lit": lambda: build_wrack_light(lit=True),
    "teeth_rock": build_teeth_rock,
    "teeth_mark": build_teeth_mark,
}

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-") and a in BUILDERS]
    for key, build in BUILDERS.items():
        if not only or key in only:
            build()
