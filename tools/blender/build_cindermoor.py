"""Builds the kit for Cindermoor's Boat Stair (Day 81), the Keepers' landing under the island's east cliff where
the lane in comes ashore, into the dressing kit:

- **boat_stair**: the quay — a block of black dressed stone (~6 × 4 m, deck top at z 0.9) with a flight of steps
  down its seaward face (-Y) into the water, iron mooring rings on the face, a granite kerb, and at the landward
  end the iron **bow-lantern rack**: a rail on two posts with eight hooks, every one empty (the boats took their
  bow lanterns out with them the week of the Snuffing).
- **boathouse_slips**: the boathouse cut into the cliff — a long low front of the same black stone with **eight
  arched slips** opening to the water (-Y), a slate roof stepped into the cliff behind. Seven slips are empty, their
  greased rollers running down to the water; **in the eighth (the +X end) a Keepers' boat still sits on its
  rollers, oars shipped, never launched**.
- **hearthspire_far_lit** (Day 97): the same, lit — the lantern gold with the Firstflame in it, the slits glowing.
- **hearthspire_far**: the Hearthspire as seen from the Boat Stair, far up on the crown of the moor: a tall slender
  tower of pale stone (the only pale thing on the island), banded, a gallery, and the lantern room **dark** — ink
  panes and a cold iron cap. Modelled ~1/3 scale (11 m) to stand on the terrain's distant crown, so the fog and the
  perspective sell the rest.
- **cinder_cresset**: a cold iron cresset on a post at the foot of the cinder road (the first waymark of the way
  up, Act III step 2), its basket full of dead black coals; **cinder_cresset_lit** (Day 82) the same lit from the
  ember, and **cinder_cresset_doused** one the Unmoored put out on purpose (packed with wet cinder, a stone on top).

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_cindermoor.py
    .tools/bin/blender-py tools/blender/build_cindermoor.py [boat_stair hearthspire_far]

Same conventions as build_dressing/build_kindleby: origin at the base centre, flat-shaded, palette colours and
tonal shades, Blender -Y = Godot +Z = the front, merged by material.
"""
import math
import os
import random
import sys

import bpy  # noqa: F401  (must be imported before mathutils when running as the bpy module)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dressing as bd  # noqa: E402  (materials, primitives, merge + export)

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod

# The quay's deck height (Godot y) — the region places the quay's walkable top here (tests pin it).
QUAY_TOP = 0.9


def _black_stone():
    return (mat("ink", 0.1), mat("ink", 0.17), mat("slate", -0.62))


def build_boat_stair() -> None:
    """The Keepers' quay: 6 m along X, 4 m deep (Y), deck at QUAY_TOP; steps down the -Y face at the -X end."""
    bd.reset()
    rng = random.Random(810)
    STONE = _black_stone()
    KERB, IRON = mat("slate", -0.3), mat("ink", 0.05)
    # The quay block in courses of dressed stone, a little battered toward the foot.
    courses = 4
    for k in range(courses):
        z = -0.6 + k * (QUAY_TOP + 0.6) / courses
        h = (QUAY_TOP + 0.6) / courses
        inset = (courses - 1 - k) * -0.04
        box("Course", (6.0 - inset * 2, 4.0 - inset * 2, h), (0, 0, z), STONE[k % 2])
    box("Kerb", (6.1, 0.3, 0.12), (0, -1.95, QUAY_TOP - 0.04), KERB)
    box("KerbSide", (0.3, 4.0, 0.12), (3.0, 0, QUAY_TOP - 0.04), KERB)
    # Joints scored in the deck.
    for k in range(5):
        x = -2.4 + k * 1.2 + rng.uniform(-0.1, 0.1)
        box("Joint", (0.04, 3.6, 0.02), (x, 0.1, QUAY_TOP - 0.01), STONE[2])
    # The flight of steps down the seaward face at the -X end, into the water (sea at z ≈ -0.25).
    for k in range(7):
        z = QUAY_TOP - (k + 1) * 0.17
        box("Step", (1.4, 0.32, 0.17), (-2.1, -2.16 - k * 0.3, z), STONE[(k + 1) % 2])
        box("StepSide", (1.4, 0.32 * (k + 1), 0.17), (-2.1, -2.0 - k * 0.15, z - 0.17), STONE[2])
    # Iron mooring rings on the face.
    for x in (-0.4, 1.4):
        rod("RingPin", (x, -2.0, 0.35), (x, -2.12, 0.35), 0.04, IRON)
        for j in range(8):
            a0, a1 = j / 8 * math.tau, (j + 1) / 8 * math.tau
            rod("Ring", (x + math.cos(a0) * 0.14, -2.14, 0.2 + math.sin(a0) * 0.14),
                (x + math.cos(a1) * 0.14, -2.14, 0.2 + math.sin(a1) * 0.14), 0.025, IRON, verts=4)
    # Bollards along the kerb.
    for x in (-0.6, 2.4):
        cyl("Bollard", 0.16, 0.14, 0.42, 8, (x, -1.65, QUAY_TOP), IRON)
        cyl("BollardCap", 0.2, 0.2, 0.07, 8, (x, -1.65, QUAY_TOP + 0.42), IRON)
    # The bow-lantern rack at the landward end: two posts and a rail with eight empty hooks.
    for x in (-2.0, 2.0):
        rod("RackPost", (x, 1.5, QUAY_TOP), (x, 1.5, QUAY_TOP + 1.9), 0.06, IRON)
    rod("RackRail", (-2.1, 1.5, QUAY_TOP + 1.8), (2.1, 1.5, QUAY_TOP + 1.8), 0.045, IRON)
    for k in range(8):
        x = -1.75 + k * 0.5
        rod("Hook", (x, 1.5, QUAY_TOP + 1.8), (x, 1.5, QUAY_TOP + 1.55), 0.018, IRON, verts=4)
        rod("HookTip", (x, 1.5, QUAY_TOP + 1.55), (x, 1.42, QUAY_TOP + 1.6), 0.016, IRON, verts=4)
    # Salt and weed at the waterline.
    for k in range(16):
        x = -2.9 + k * 0.38
        box("Wrack", (0.34, 0.05, rng.uniform(0.25, 0.45)), (x, -2.02, -0.45), mat("moss", -0.6 + 0.06 * (k % 3)))
    bd.export("boat_stair")


def _keeper_boat(x: float, y: float, z: float, pitch: float) -> None:
    """A Keepers' boat (4.2 m) on its rollers, bow to the water (-Y), oars shipped along the thwarts; built at the
    origin, then pitched down the slip and moved into place."""
    from mathutils import Matrix
    before = set(bpy.context.scene.objects)
    stations = bd.hull_stations(4.2, 0.72, 0.62, 0.16)
    tar, strake = mat("ink", 0.18), mat("bone", -0.35)
    bd.hull("Hull", stations, 0.62, 0.16, tar)
    bd.gunwale("Rail", stations, mat("driftwood", -0.45))
    bd.gunwale("Strake", stations, strake, thick=0.05, drop=0.14)
    oar = mat("driftwood", -0.2)
    for side in (-0.28, 0.28):
        rod("Oar", (side, -1.6, 0.05), (side * 0.9, 1.5, 0.1), 0.03, oar)
    for yy in (-0.6, 0.5):
        box("Thwart", (1.1, 0.2, 0.05), (0, yy, -0.08), mat("driftwood", -0.35))
    place = Matrix.Translation((x, y, z)) @ Matrix.Rotation(pitch, 4, "X")
    for obj in set(bpy.context.scene.objects) - before:
        obj.matrix_world = place @ obj.matrix_world


def build_boathouse_slips() -> None:
    """The boathouse (~17 m along X, 6 m deep, 3.6 m to the ridge): eight arched slips open to the water (-Y), the
    slip floors ramping down from z 0.9 at the back to z -0.4 at the mouth. The eighth (+X end) holds a boat."""
    bd.reset()
    rng = random.Random(811)
    STONE = _black_stone()
    SLATE, IRON = mat("slate", -0.35), mat("ink", 0.05)
    n, bay, pier = 8, 2.0, 0.22
    width = n * bay + pier
    x0 = -width / 2
    depth = 6.0
    # Back wall (against the cliff) and end walls.
    box("Back", (width, 0.5, 3.0), (0, depth / 2 - 0.25, -0.4), STONE[0])
    for sx in (x0 + pier / 2, -x0 - pier / 2):
        box("End", (pier + 0.1, depth, 3.0), (sx, 0, -0.4), STONE[1])
    # Piers between the slips, each with a voussoir-ish lintel stack forming a pointed arch over the mouth.
    for k in range(n + 1):
        px = x0 + pier / 2 + k * bay
        box("Pier", (pier, depth, 2.4), (px, 0, -0.4), STONE[k % 2])
    for k in range(n):
        cx = x0 + pier + bay * (k + 0.5) - pier / 2
        for j in range(4):
            a = j / 4 * (math.pi / 2)
            w = (bay - pier) / 2 * (1 - math.cos(a)) + 0.12
            z = 2.0 + math.sin(a) * 0.45
            for sgn in (-1, 1):
                box("Arch", (w, 0.45, 0.16), (cx + sgn * ((bay - pier) / 2 - w / 2), -depth / 2 + 0.22, z), STONE[2])
        box("Keystone", (0.24, 0.5, 0.3), (cx, -depth / 2 + 0.22, 2.45), STONE[1])
        # The slip floor: a ramp of stone and two greased rollers' worth of timber rails.
        floor = bd.box("Slip", (bay - pier, depth, 0.2), (0, 0, 0), STONE[2])
        floor.rotation_euler = (math.atan2(1.3, depth), 0, 0)
        floor.location = (cx, 0, 0.25)
        for rx in (-0.35, 0.35):
            beam("Rail", (cx + rx, depth / 2 - 0.3, 0.92), (cx + rx, -depth / 2, -0.38), 0.08, mat("driftwood", -0.55), 0.1)
        for j in range(5):
            yy = depth / 2 - 0.8 - j * 1.15
            zz = 0.92 - (depth / 2 - yy - 0.3) * 1.3 / depth + 0.06
            rod("Roller", (cx - 0.55, yy, zz), (cx + 0.55, yy, zz), 0.07, mat("driftwood", -0.4 + 0.05 * (j % 2)))
    # The front above the arches and the roof, stepped back into the cliff.
    box("Front", (width, 0.5, 0.7), (0, -depth / 2 + 0.25, 2.55), STONE[0])
    roof = mat("slate", -0.45)
    for k, (y, z) in enumerate(((-depth / 2 + 0.4, 3.2), (-0.5, 3.45), (1.6, 3.7))):
        box("Roof", (width + 0.4, 2.4, 0.18), (0, y + 1.0, z), roof if k % 2 == 0 else SLATE)
    # Iron rings over each slip mouth, the painter hooks; numbers chiselled (pale marks) over the arches.
    for k in range(n):
        cx = x0 + pier + bay * (k + 0.5) - pier / 2
        for m in range(k + 1):
            box("Tally", (0.03, 0.02, 0.12), (cx - 0.06 * k / 2 + m * 0.06, -depth / 2 - 0.01, 2.75), mat("bone", -0.3))
    # The eighth slip's boat, on its rollers, never launched.
    cx8 = x0 + pier + bay * 7.5 - pier / 2
    _keeper_boat(cx8, 0.2, 0.5, math.atan2(1.3, depth))
    # Weed on the piers' feet.
    for k in range(n + 1):
        px = x0 + pier / 2 + k * bay
        box("Wrack", (pier + 0.06, 0.06, rng.uniform(0.3, 0.5)), (px, -depth / 2 - 0.02, -0.45), mat("moss", -0.6))
    bd.export("boathouse_slips")


def build_hearthspire_far(lit: bool = False) -> None:
    """The Hearthspire, dark (~11 m tall, ~1/3 scale for distance): pale banded stone, gallery, a dark lantern.
    `lit` (Day 97, the lit ending): the lantern full of the Firstflame, the slits up the stair glowing, the stone's
    top catching the gold."""
    bd.reset()
    PALE, PALE2 = mat("bone", -0.12), mat("bone", -0.25)
    DARK, IRON = mat("ink", 0.0), mat("ink", 0.12)
    if lit:
        DARK = mat("kindle", 0.1, emissive=True)
    cyl("Foot", 1.7, 1.45, 1.2, 12, (0, 0, -0.4), PALE2)
    cyl("Shaft", 1.25, 0.82, 7.4, 12, (0, 0, 0.8), PALE)
    for k in range(5):
        z = 1.6 + k * 1.35
        r = 1.25 - (z - 0.8) / 7.4 * 0.43 + 0.03
        cyl("Band", r, r - 0.01, 0.12, 12, (0, 0, z), PALE2)
    # Slit windows up the east face (-Y), spiralling with the east stair.
    for k in range(9):
        z = 1.4 + k * 0.72
        a = -math.pi / 2 + (k % 3 - 1) * 0.5
        r = 1.25 - (z - 0.8) / 7.4 * 0.43 + 0.01
        box("Slit", (0.1, 0.06, 0.32), (math.cos(a) * r, math.sin(a) * r, z), DARK, a + math.pi / 2)
    cyl("Gallery", 1.25, 1.25, 0.2, 12, (0, 0, 8.2), PALE2)
    for k in range(12):
        a = k / 12 * math.tau
        rod("Rail", (math.cos(a) * 1.18, math.sin(a) * 1.18, 8.4), (math.cos(a) * 1.18, math.sin(a) * 1.18, 8.75), 0.03, IRON)
    cyl("Lantern", 0.78, 0.78, 1.5, 8, (0, 0, 8.4), DARK)
    for k in range(8):
        a = k / 8 * math.tau + math.pi / 8
        rod("Mullion", (math.cos(a) * 0.8, math.sin(a) * 0.8, 8.4), (math.cos(a) * 0.8, math.sin(a) * 0.8, 9.9), 0.05, IRON)
    cyl("Cap", 0.95, 0.1, 1.1, 8, (0, 0, 9.9), IRON)
    rod("Finial", (0, 0, 10.9), (0, 0, 11.4), 0.05, IRON)
    if lit:
        # The flame standing up inside the lantern, and the gallery's stone warmed from above.
        cyl("Flame", 0.5, 0.0, 1.2, 5, (0, 0, 8.45), mat("ember", 0.15, emissive=True), 0.3)
        cyl("GalleryGlow", 1.27, 1.27, 0.06, 12, (0, 0, 8.4), mat("ember", -0.2, emissive=True))
    bd.export("hearthspire_far_lit" if lit else "hearthspire_far")


def build_hearthspire_far_lit() -> None:
    build_hearthspire_far(lit=True)


def _cresset_frame(IRON) -> None:
    """The cairn, post and iron basket every cresset shares (basket rim at z 2.35)."""
    for k in range(8):
        a = k / 8 * math.tau
        box("Cairn", (0.32, 0.26, 0.24), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0), mat("ink", 0.2 + 0.06 * (k % 2)), a)
    cyl("CairnTop", 0.3, 0.2, 0.3, 7, (0, 0, 0.2), mat("ink", 0.25))
    rod("Post", (0, 0, 0.2), (0, 0, 2.0), 0.06, IRON)
    for k in range(6):
        a = k / 6 * math.tau
        rod("Basket", (math.cos(a) * 0.12, math.sin(a) * 0.12, 1.95), (math.cos(a) * 0.3, math.sin(a) * 0.3, 2.35), 0.02, IRON, verts=4)
    for z, r in ((2.0, 0.15), (2.33, 0.29)):
        for k in range(6):
            a0, a1 = k / 6 * math.tau, (k + 1) / 6 * math.tau
            rod("Hoop", (math.cos(a0) * r, math.sin(a0) * r, z), (math.cos(a1) * r, math.sin(a1) * r, z), 0.018, IRON, verts=4)


def build_cinder_cresset() -> None:
    """A cold waymark cresset (~2.3 m): an iron basket of dead coals on a post set in a cairn of cinder."""
    bd.reset()
    rng = random.Random(812)
    _cresset_frame(mat("ink", 0.1))
    for k in range(7):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.16)
        box("Coal", (0.12, 0.1, 0.09), (math.cos(a) * r, math.sin(a) * r, 2.1 + rng.uniform(0, 0.1)), mat("slate", -0.65), a)
    bd.export("cinder_cresset")


def build_cinder_cresset_lit() -> None:
    """The same cresset lit from the ember (Day 82): the old coals caught red through the gaps, a gold heart, and
    three short tongues of flame standing up out of the basket (all emissive — the region gives it a halo and
    smoke, no light). Fire centre Godot [0, 2.25, 0] = Cressets.FIRE."""
    bd.reset()
    rng = random.Random(821)
    _cresset_frame(mat("ink", 0.1))
    for k in range(7):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.16)
        box("Coal", (0.12, 0.1, 0.09), (math.cos(a) * r, math.sin(a) * r, 2.1 + rng.uniform(0, 0.1)), mat("ink", 0.04), a)
    for k in range(6):
        a = k / 6 * math.tau + 0.4
        r = rng.uniform(0.05, 0.17)
        box("Glow", (0.09, 0.08, 0.06), (math.cos(a) * r, math.sin(a) * r, 2.17), mat("coal", 0.1, emissive=True), a)
    cyl("Heart", 0.13, 0.1, 0.08, 6, (0, 0, 2.18), mat("ember", 0.0, emissive=True))
    flame = mat("kindle", 0.15, emissive=True)
    for k, (h, r) in enumerate(((0.42, 0.09), (0.3, 0.07), (0.26, 0.06))):
        a = k / 3 * math.tau + 0.9
        off = 0.0 if k == 0 else 0.1
        cyl("Flame", r, 0.0, h, 4, (math.cos(a) * off, math.sin(a) * off, 2.22), flame)
    bd.export("cinder_cresset_lit")


def build_cinder_cresset_doused() -> None:
    """A cresset put out on purpose (Day 82, past the Unmoored on the moor): the coals raked out onto the cairn,
    the basket packed with wet black cinder to the rim and a flat stone set on top, the basket knocked askew."""
    bd.reset()
    rng = random.Random(822)
    IRON = mat("ink", 0.1)
    _cresset_frame(IRON)
    wet = mat("ink", -0.4)
    cyl("Packed", 0.27, 0.29, 0.28, 7, (0, 0, 2.08), wet)
    box("Lid", (0.36, 0.3, 0.07), (0.02, -0.01, 2.38), mat("slate", -0.5), 0.3)
    for k in range(9):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.45, 0.85)
        box("Raked", (0.1, 0.09, 0.07), (math.cos(a) * r, math.sin(a) * r, 0.03), mat("slate", -0.65), a)
    bd.export("cinder_cresset_doused")


def build_spire_foot(seat_open: bool = False) -> None:
    """The Hearthspire's foot at full scale (Day 83, the crown of Cindermoor): the plinth, the battered foot and the
    first ~14 m of the shaft going up into the fog (the rest is fog). On the front (-Y, Godot +Z) **the east stair
    door**, ajar a hand's width on the dark, two worn steps up to it; to its right (+X) **the warden's niche**, a
    little stone booth built out from the wall: a seat, a shelf with a bundle of uncut tapers and the knife that cut
    them, and the novices' roll on its peg. Origin at the plinth's centre on the ground. `seat_open` (Day 86,
    `spire_foot_open`): the warden's seat lifted on its pin like a lid and leant back on the niche wall, and under it
    the dark of the stair down to the lower rooms."""
    bd.reset()
    rng = random.Random(830)
    PALE, PALE2, PALE3 = mat("bone", -0.12), mat("bone", -0.25), mat("bone", -0.38)
    DARK, IRON = mat("ink", -0.2), mat("ink", 0.12)
    WOOD, VELLUM = mat("driftwood", -0.55), mat("bone", -0.05)
    cyl("Plinth", 5.6, 5.45, 0.55, 16, (0, 0, -0.25), PALE3)
    cyl("Foot", 5.1, 4.6, 3.6, 16, (0, 0, 0.3), PALE2)
    cyl("FootBand", 4.75, 4.6, 0.25, 16, (0, 0, 3.9), PALE3)
    cyl("Shaft", 3.75, 3.35, 13.0, 16, (0, 0, 4.15), PALE)
    for k in range(3):
        z = 7.0 + k * 3.6
        r = 3.75 - (z - 4.15) / 13.0 * 0.4 + 0.06
        cyl("Band", r, r - 0.01, 0.22, 16, (0, 0, z), PALE2)
    # Slit windows up the east face, spiralling with the stair inside.
    for k in range(6):
        z = 5.0 + k * 1.9
        a = -math.pi / 2 + (k % 3 - 1) * 0.45
        r = 3.75 - (z - 4.15) / 13.0 * 0.4 + 0.02
        box("Slit", (0.24, 0.16, 0.8), (math.cos(a) * r, math.sin(a) * r, z), DARK, a + math.pi / 2)
    # Weathered blocks scattered on the foot's face so it reads as dressed stone.
    for k in range(22):
        a = rng.uniform(0, math.tau)
        z = rng.uniform(0.5, 3.4)
        r = 5.1 - (z - 0.3) / 3.6 * 0.5
        if abs(math.sin(a) + 1) < 0.08 and abs(math.cos(a)) < 0.5:
            continue  # keep the door clear
        box("Block", (0.9, 0.08, 0.38), (math.cos(a) * r, math.sin(a) * r, z), PALE3, a + math.pi / 2)
    # The east stair door (front, -Y): a deep dark opening in a frame of jambs and a lintel, two steps up.
    door_y = -4.98
    box("DoorDark", (1.2, 0.6, 2.4), (0, door_y + 0.2, 0.3), DARK)
    for x in (-0.75, 0.75):
        box("Jamb", (0.3, 0.45, 2.5), (x, door_y - 0.05, 0.3), PALE3)
    box("Lintel", (1.9, 0.5, 0.42), (0, door_y - 0.06, 2.8), PALE3)
    box("Keystone", (0.42, 0.56, 0.5), (0, door_y - 0.09, 2.95), PALE2)
    box("Step", (1.8, 0.5, 0.17), (0, door_y - 0.5, 0.0), PALE3)
    box("Step", (1.6, 0.42, 0.17), (0, door_y - 0.12, 0.17), PALE2)
    # The door itself, iron-banded, swung in on its -X hinge, ajar on the dark.
    box("Door", (1.12, 0.1, 2.36), (-0.02, door_y + 0.12, 0.34), WOOD)
    for z in (0.75, 1.55, 2.3):
        box("DoorBand", (1.14, 0.12, 0.08), (-0.02, door_y + 0.1, z), IRON)
    box("DoorGap", (0.12, 0.3, 2.3), (0.5, door_y + 0.02, 0.34), DARK)
    rod("Ring", (0.32, door_y - 0.02, 1.25), (0.32, door_y - 0.12, 1.25), 0.05, IRON)
    # The warden's niche: a booth of the same stone built out from the wall to the door's right (+X).
    nx, back_y, front_y = 2.35, -4.42, -5.45
    depth = back_y - front_y
    mid_y = (back_y + front_y) / 2
    for x in (nx - 0.8, nx + 0.8):
        box("NicheWall", (0.22, depth, 2.3), (x, mid_y, 0.3), PALE2)
    box("NicheRoof", (1.9, depth + 0.2, 0.22), (nx, mid_y - 0.05, 2.6), PALE3)
    box("NicheBack", (1.4, 0.12, 2.3), (nx, back_y + 0.02, 0.3), mat("bone", -0.55))
    box("NicheFloor", (1.4, depth, 0.06), (nx, mid_y, 0.3), PALE3)
    if not seat_open:
        box("Seat", (1.2, 0.42, 0.45), (nx, back_y - 0.26, 0.36), PALE2)
    else:
        # The seat's a hollow box with a lid: the lid stands up against the back wall, the well under it is dark,
        # and the first step shows pale a hand below the rim.
        sy = back_y - 0.26
        for x in (nx - 0.56, nx + 0.56):
            box("SeatSide", (0.08, 0.42, 0.37), (x, sy, 0.36), PALE2)
        for y in (sy - 0.17, sy + 0.17):
            box("SeatSide", (1.2, 0.08, 0.37), (nx, y, 0.36), PALE2)
        box("Well", (1.04, 0.26, 0.04), (nx, sy, 0.62), DARK)
        box("FirstStep", (0.5, 0.12, 0.03), (nx - 0.22, sy - 0.06, 0.66), PALE3)
        lid = box("SeatLid", (1.2, 0.08, 0.42), (nx, back_y - 0.06, 0.73), PALE2)
        lid.rotation_euler[0] = math.radians(-8)
    box("Shelf", (1.3, 0.3, 0.06), (nx, back_y - 0.2, 1.45), WOOD)
    # A bundle of uncut tapers, and the knife that cut them, on the shelf.
    for k in range(7):
        rod("Taper", (nx - 0.48 + k * 0.035, back_y - 0.13 - (k % 2) * 0.04, 1.53),
            (nx - 0.02 + k * 0.035, back_y - 0.13 - (k % 2) * 0.04, 1.53), 0.016, VELLUM, verts=4)
    box("Blade", (0.2, 0.03, 0.01), (nx + 0.12, back_y - 0.26, 1.51), mat("silverfog", -0.2), 0.25)
    box("Haft", (0.12, 0.035, 0.03), (nx + 0.27, back_y - 0.22, 1.51), WOOD, 0.25)
    # The novices' roll, rolled on its peg on the niche's back wall, its foot hanging open.
    rod("Peg", (nx + 0.4, back_y, 1.95), (nx + 0.4, back_y - 0.16, 1.95), 0.02, WOOD)
    rod("Roll", (nx + 0.22, back_y - 0.1, 1.97), (nx + 0.58, back_y - 0.1, 1.97), 0.05, VELLUM, verts=6)
    box("RollFoot", (0.34, 0.01, 0.42), (nx + 0.4, back_y - 0.14, 1.53), VELLUM)
    bd.export("spire_foot_open" if seat_open else "spire_foot")


def build_spire_foot_open() -> None:
    build_spire_foot(seat_open=True)


def build_chapter_ring() -> None:
    """The chapter sitting at the Spire's foot (Day 86): a ring of candles stood in the cinder (r ~2.3 m, an opening
    at model -Y toward the niche) and, inside it, an oilcloth spread on the ground with the Long Book open on it — a
    doorstep of a book, its pages fanned. Flames emissive only (the region gives it a small warm light). Origin at
    the ring's centre on the ground."""
    bd.reset()
    rng = random.Random(860)
    wax, wick = mat("bone", -0.08), mat("kindle", 0.15, emissive=True)
    for k in range(26):
        a = -math.pi / 2 + 0.55 + k / 25 * (math.tau - 1.1)
        r = 2.3 + rng.uniform(-0.08, 0.08)
        h = rng.uniform(0.12, 0.3)
        x, y = math.cos(a) * r, math.sin(a) * r
        cyl("Candle", 0.035, 0.032, h, 5, (x, y, -0.04), wax)
        cyl("Flame", 0.026, 0.0, 0.09, 4, (x, y, h - 0.04), wick)
    box("Oilcloth", (1.3, 0.9, 0.02), (0.0, 0.4, 0.0), mat("moss", -0.55), 0.1)
    cover = mat("driftwood", -0.6)
    for side in (-1, 1):
        box("BookCover", (0.36, 0.5, 0.05), (side * 0.19, 0.4, 0.02), cover, 0.1)
        box("BookLeaves", (0.33, 0.46, 0.09), (side * 0.18, 0.4, 0.07), mat("bone", -0.18), 0.1)
    box("Spine", (0.06, 0.5, 0.1), (0.0, 0.4, 0.0), cover, 0.1)
    bd.export("chapter_ring")


def build_chapter_boat() -> None:
    """The chapter's boat at the Boat Stair (Day 85): one of the seven Spire boats that went out the night of the
    Snuffing, the same lines as the eighth slip's but longer (5.4 m) and four-oared, come back down the lane in from
    Kindleby under oars. Afloat: model z 0 = the waterline (place `snap: false` at the water level). Tarred dark under
    a pale strake, a bone gunwale, four oars tossed up and laid in along the thwarts, the lug mast unstepped along the
    thwarts with its sail furled round it, and the bow lantern lit on its crook (an ordinary flame: emissive only, no
    light). Bow = -Y (Godot +Z): the region swings it alongside the quay's seaward face. Lantern glass centre ~
    Godot [0, 0.82, 2.5] — the placement's `halo`."""
    bd.reset()
    length, half_beam, depth, sheer = 5.4, 0.86, 0.74, 0.4
    st = bd.hull_stations(length, half_beam, depth, sheer)
    tar, strake, rail = mat("ink", 0.14), mat("bone", -0.3), mat("bone", -0.12)
    bd.hull("Hull", st, depth, sheer, tar)
    bd.gunwale("Gunwale", st, rail, thick=0.07)
    bd.gunwale("Strake", st, strake, thick=0.05, drop=0.14)
    wood = mat("driftwood", -0.32)
    for y in (-1.3, -0.4, 0.5, 1.4):
        box("Thwart", (half_beam * 1.8, 0.22, 0.05), (0, y, sheer - 0.14), wood)
    box("Floorboards", (0.7, 3.8, 0.03), (0, 0.1, -0.12), mat("driftwood", -0.2))
    # Four oars laid in along the thwarts, blades aft, looms over the bow thwart.
    for x in (-0.42, -0.2, 0.2, 0.42):
        rod("Oar", (x, -1.9, sheer - 0.06), (x, 1.5, sheer - 0.04), 0.026, rail)
        beam("OarBlade", (x, 1.5, sheer - 0.04), (x, 2.0, sheer - 0.03), 0.02, rail, width=0.13)
    # The lug mast unstepped, lying down the middle with its sail furled round it.
    rod("Mast", (0.0, -2.0, sheer + 0.06), (0.0, 1.9, sheer + 0.04), 0.045, mat("driftwood", -0.4), verts=6)
    rod("Furl", (0.0, -2.2, sheer + 0.1), (0.0, 0.4, sheer + 0.1), 0.11, mat("bone", -0.42), verts=7, r_end=0.08)
    # A box at the stern sheets (the chapter's candles and the Long Book in oilcloth) and a pair of lanterns on it.
    box("Chest", (0.62, 0.44, 0.34), (0, 1.95, 0.02), mat("driftwood", -0.5))
    box("Oilcloth", (0.42, 0.32, 0.1), (0, 1.95, 0.24), mat("moss", -0.55))
    # The stem-post, its crook and the lit bow lantern.
    bow_y, bow_z = st[0][0] + 0.08, st[0][2]
    post = mat("driftwood", -0.35)
    rod("StemPost", (0, bow_y, bow_z - 0.25), (0, bow_y, bow_z + 0.42), 0.05, post, verts=5)
    iron = mat("ink", 0.2)
    hy, hz = bow_y + 0.22, bow_z + 0.46
    beam("Crook", (0, bow_y, bow_z + 0.42), (0, hy, hz), 0.024, iron)
    gz = hz - 0.18
    rod("Bail", (0, hy, hz), (0, hy, gz + 0.1), 0.008, iron, verts=3)
    box("LanternPanes", (0.13, 0.13, 0.17), (0, hy, gz - 0.08), mat("kindle", 0.05, emissive=True))
    cyl("LanternFoot", 0.1, 0.1, 0.03, 4, (0, hy, gz - 0.11), iron, rot_z=math.radians(45))
    cyl("LanternCap", 0.1, 0.02, 0.06, 4, (0, hy, gz + 0.08), iron, rot_z=math.radians(45))
    # The painter from the stem eye, slack, over the side toward the quay (+X) and down into the water.
    rope = mat("driftwood", 0.05)
    eye = (0.0, bow_y + 0.02, bow_z + 0.05)
    for p0, p1 in (((eye), (0.5, bow_y + 0.3, bow_z + 0.02)), ((0.5, bow_y + 0.3, bow_z + 0.02), (1.1, bow_y + 0.6, -0.1))):
        rod("Painter", p0, p1, 0.016, rope, verts=4)
    bd.export("chapter_boat")


def build_lower_stair() -> None:
    """The foot of the stair under the warden's seat (Day 87, the lower rooms): the last steps of the twelve coming
    down out of the dark through a cut in the rock wall, rising toward model +X (the wall) and turning out of sight;
    rough-cut cheeks each side, a lintel, and the dark of the stair beyond. Place it with its back (+X) against the
    room's east wall; the bottom step's front edge is at model x -1.6. Origin at the bottom step's foot centre-line."""
    bd.reset()
    STONE = (mat("bone", -0.5), mat("bone", -0.6), mat("slate", -0.55))
    DARK = mat("ink", -0.4)
    for k in range(7):
        z = k * 0.2
        front = -1.6 + k * 0.32
        box("Step", (1.9 - front, 1.3, 0.2), ((front + 1.9) / 2, 0, z), STONE[k % 2])
    for side in (-1, 1):
        box("Cheek", (3.6, 0.5, 3.4), (0.2, side * 0.9, 0), STONE[(side + 1) // 2])
        box("CheekCap", (3.7, 0.6, 0.2), (0.2, side * 0.9, 3.4), STONE[2])
    box("Lintel", (0.5, 2.3, 0.5), (-1.4, 0, 2.9), STONE[1])
    box("Dark", (0.1, 1.3, 2.0), (1.9, 0, 1.3), DARK)
    box("DarkTop", (3.2, 1.3, 0.1), (0.3, 0, 3.3), DARK)
    bd.export("lower_stair")


def build_spire_book() -> None:
    """The Spire's own book (Day 87): a lectern cut from one block of the pale stone, the book on it bigger than the
    Long Book and older — boards of black wood, leaves gone the colour of bone, open about two-thirds through (the
    last written page), an iron chain from the spine to a ring in the lectern's foot. Front (reader's side) = model -Y.
    ~1.3 m to the book. Origin at the lectern's foot."""
    bd.reset()
    PALE, PALE2 = mat("bone", -0.3), mat("bone", -0.45)
    box("LecternFoot", (0.9, 0.7, 0.18), (0, 0, 0), PALE2)
    box("LecternStem", (0.5, 0.42, 1.0), (0, 0, 0.18), PALE)
    box("LecternHead", (0.95, 0.7, 0.14), (0, 0.04, 1.14), PALE2)
    box("LecternLip", (0.95, 0.06, 0.08), (0, -0.33, 1.2), PALE2)
    cover = mat("ink", 0.12)
    for side in (-1, 1):
        box("BookBoard", (0.42, 0.6, 0.04), (side * 0.22, 0.02, 1.28), cover)
        thick = 0.11 if side < 0 else 0.06
        box("BookLeaves", (0.39, 0.56, thick), (side * 0.21, 0.02, 1.32), mat("bone", -0.2 if side < 0 else -0.1))
    box("Spine", (0.07, 0.6, 0.1), (0, 0.02, 1.26), cover)
    iron = mat("ink", 0.2)
    pts = [(0.0, 0.32, 1.27), (0.12, 0.38, 0.9), (0.18, 0.4, 0.5), (0.2, 0.37, 0.14)]
    for a, b in zip(pts, pts[1:]):
        rod("Chain", a, b, 0.015, iron, verts=4)
    bd.export("spire_book")


def build_hushed_bench() -> None:
    """A stone bench cut in the lower rooms (Day 87): long enough to lie on (2.0 × 0.7 m, 0.45 m high), worn
    hollow along its top by nine hundred years of somebody lying there, a grey blanket folded at its head. Where the
    Hushed waited for midwinter. Long axis model X. Origin at the base centre."""
    bd.reset()
    STONE, STONE2 = mat("bone", -0.48), mat("bone", -0.58)
    box("Bench", (2.0, 0.7, 0.36), (0, 0, 0), STONE)
    box("Lip", (2.0, 0.12, 0.09), (0, -0.29, 0.36), STONE2)
    box("Lip", (2.0, 0.12, 0.09), (0, 0.29, 0.36), STONE2)
    box("Head", (0.14, 0.7, 0.12), (-0.93, 0, 0.36), STONE2)
    box("Blanket", (0.36, 0.5, 0.1), (-0.72, 0, 0.36), mat("silverfog", -0.45))
    bd.export("hushed_bench")


def build_flame_root() -> None:
    """The flame's root (Day 87): the round of pale stone in the middle of the lower rooms where the Hearthspire's
    shaft comes down to the rock — a kerb r 1.3 m round a dark well, a cold iron grate over it, and the shaft's
    stone going straight up out of sight. What the flame was given was brought here. Origin at the kerb's centre."""
    bd.reset()
    PALE, PALE2, DARK, IRON = mat("bone", -0.35), mat("bone", -0.5), mat("ink", -0.4), mat("ink", 0.15)
    cyl("Kerb", 1.3, 1.25, 0.4, 14, (0, 0, 0), PALE2)
    cyl("Well", 1.0, 1.0, 0.02, 14, (0, 0, 0.39), DARK)
    for k in range(5):
        y = -0.8 + k * 0.4
        box("Grate", (2.0 - abs(y) * 0.9, 0.05, 0.04), (0, y, 0.4), IRON)
    for k in range(5):
        x = -0.8 + k * 0.4
        box("Grate", (0.05, 2.0 - abs(x) * 0.9, 0.04), (x, 0, 0.42), IRON)
    for k in range(6):
        a = k / 6 * math.tau
        box("Pillar", (0.3, 0.3, 4.6), (math.cos(a) * 1.55, math.sin(a) * 1.55, 0.0), PALE, a)
    cyl("Shaft", 1.75, 1.75, 0.5, 14, (0, 0, 4.6), PALE2)
    bd.export("flame_root")


def build_taper_row() -> None:
    """A row of fourteen candles stood along a rock ledge (Day 87, the lower rooms): lit, the flames emissive (the
    region gives the row one small warm light). 2.6 m long along model X, the ledge 0.9 m high. Origin at the
    ledge's foot."""
    bd.reset()
    rng = random.Random(870)
    box("Ledge", (2.8, 0.36, 0.9), (0, 0, 0), mat("bone", -0.55))
    wax, wick = mat("bone", -0.08), mat("kindle", 0.15, emissive=True)
    for k in range(14):
        x = -1.3 + k * 0.2 + rng.uniform(-0.03, 0.03)
        h = rng.uniform(0.1, 0.24)
        cyl("Candle", 0.03, 0.028, h, 5, (x, rng.uniform(-0.06, 0.06), 0.9), wax)
        cyl("Flame", 0.022, 0.0, 0.08, 4, (x, 0, 0.9 + h), wick)
    bd.export("taper_row")


def build_lower_vault() -> None:
    """The lower rooms' roof (Day 87): the rock overhead, a slab 26 × 20 m whose underside is at z 4.9, with three
    rough ribs of the pale stone across it east-west and a ring of the pale stone where the Spire's shaft goes up
    through it (over the flame's root, at model (-1.5, 1.0): Godot (-1.5, -1.0)). Origin on the floor at the room's
    centre; placed at the region's origin so the ribs line up with the walls."""
    bd.reset()
    ROCK, RIB, RING = mat("ink", 0.12), mat("bone", -0.62), mat("bone", -0.5)
    box("Roof", (26.0, 20.0, 0.5), (0, 0, 4.9), ROCK)
    for y in (-3.6, 0.0, 3.6):
        box("Rib", (16.0, 0.5, 0.35), (0, y, 4.56), RIB)
    cyl("ShaftRing", 2.0, 2.0, 0.3, 14, (-1.5, 1.0, 4.62), RING)
    bd.export("lower_vault")


def build_landing_shaft() -> None:
    """The Hearthspire's shaft where it passes the last landing (Day 92, the east stair): a parapet of the pale stone
    r 1.5 m, 0.95 m high, round a dark well going down out of sight, an iron rail along its top (the rail Isolde leans
    over, a turn above), and the shaft's own stone going on up through the roof. Where the flame's heat went up. Origin
    at the parapet's centre on the floor; the region puts it under the vault's shaft ring."""
    bd.reset()
    PALE, PALE2, DARK, IRON = mat("bone", -0.35), mat("bone", -0.5), mat("ink", -0.4), mat("ink", 0.15)
    cyl("Parapet", 1.5, 1.45, 0.95, 16, (0, 0, 0), PALE2)
    cyl("Well", 1.2, 1.2, 0.03, 16, (0, 0, 0.94), DARK)
    cyl("Lip", 1.55, 1.55, 0.1, 16, (0, 0, 0.92), PALE)
    for k in range(8):
        a = k / 8 * math.tau
        rod("Stanchion", (math.cos(a) * 1.4, math.sin(a) * 1.4, 1.0), (math.cos(a) * 1.4, math.sin(a) * 1.4, 1.35),
            0.025, IRON)
    for k in range(16):
        a0, a1 = k / 16 * math.tau, (k + 1) / 16 * math.tau
        rod("Rail", (math.cos(a0) * 1.4, math.sin(a0) * 1.4, 1.35), (math.cos(a1) * 1.4, math.sin(a1) * 1.4, 1.35),
            0.03, IRON)
    # The shaft's stone, standing up out of the parapet's far half and on through the roof: three pale ribs.
    for k in range(3):
        a = math.pi * (0.25 + k * 0.25)
        box("Rib", (0.35, 0.35, 3.9), (math.cos(a) * 1.6, math.sin(a) * 1.6, 0.95), PALE, a)
    bd.export("landing_shaft")


def build_landing_window() -> None:
    """A slit window in the Spire's wall at the last landing (Day 92): a deep reveal in a 3 m length of wall
    (0.9 m thick), the slit 0.22 m wide and 1.6 m high with a sill at 1.0 m, splayed inward; out through it the grey
    is faintly pale (an emissive pane, the only daylight on the stair). The room side is the front (model -Y = Godot
    +Z); the region turns it to face into the room from whichever wall it stands in. Origin at the wall's foot, at the
    room-side face."""
    bd.reset()
    STONE, STONE2, SILL = mat("bone", -0.5), mat("bone", -0.6), mat("bone", -0.35)
    GREY = mat("silverfog", 0.1, emissive=True)
    for side in (-1, 1):
        box("Wall", (1.2, 0.9, 3.4), (side * 0.9, 0.45, 0), STONE)
        box("Splay", (0.3, 0.5, 1.7), (side * 0.38, 0.2, 1.0), STONE2, side * 0.35)
    box("Under", (0.6, 0.9, 1.0), (0, 0.45, 0), STONE)
    box("Sill", (0.8, 0.6, 0.08), (0, 0.2, 1.0), SILL)
    box("Over", (0.6, 0.9, 0.8), (0, 0.45, 2.6), STONE)
    box("Pane", (0.24, 0.04, 1.6), (0, 0.85, 1.0), GREY)
    bd.export("landing_window")


def build_landing_stairhead() -> None:
    """The head of the east stair where it comes up into the last landing (Day 92): an opening in the wall 1.3 m wide
    under a pale lintel, and inside it the dark of the stairwell with the lips of the top steps going down into it. Place
    its back (+X) against the room's east wall; the top step's lip is at model x -1.2, level with the floor. Origin at
    the opening's foot centre-line."""
    bd.reset()
    STONE = (mat("bone", -0.5), mat("bone", -0.6), mat("slate", -0.55))
    DARK = mat("ink", -0.4)
    # The floor can't be cut, so the stairwell is a dark well-mouth laid on it, with the lips of the top steps
    # going down into it as pale strips that darken with depth.
    box("Sill", (0.4, 1.3, 0.04), (-1.0, 0, 0), STONE[2])
    box("Pit", (2.0, 1.3, 0.03), (0.2, 0, 0), DARK)
    for k in range(4):
        box("StepLip", (0.06, 1.3, 0.035), (-0.7 + k * 0.32, 0, 0), mat("bone", -0.55 - k * 0.1))
    for side in (-1, 1):
        box("Cheek", (3.0, 0.5, 3.2), (0.3, side * 0.9, 0), STONE[(side + 1) // 2])
    box("Lintel", (0.5, 2.3, 0.5), (-1.0, 0, 2.5), STONE[1])
    box("Back", (0.1, 1.3, 2.4), (1.75, 0, 0), DARK)
    box("Roof", (2.8, 1.3, 0.1), (0.4, 0, 2.4), DARK)
    bd.export("landing_stairhead")


def build_lantern_room() -> None:
    """The Hearthspire's lantern room (Day 95, Act III step 9): the top of the Spire, a square room 11 m across inside
    (the walls' inner faces at ±5.5 m, so the region's ground walls stand just behind them). A knee wall of the pale
    stone 0.9 m high, then a ring of tall panes black with nine hundred years of soot between iron mullions, three to
    a side, stone piers at the corners, and over it the roof's underside going up in a dark pyramid to an iron boss.
    The door comes in through the east wall (+X) at the head of the stair, its oak leaf swung back into the room.
    Origin on the floor at the room's centre, where the cradle stands."""
    bd.reset()
    PALE, PALE2, IRON, SOOT, SOOT2 = (mat("bone", -0.4), mat("bone", -0.55), mat("ink", 0.15), mat("ink", -0.25),
                                      mat("silverfog", -0.72))
    OAK, DARK = mat("driftwood", -0.45), mat("ink", -0.4)
    INNER, T = 5.5, 0.5
    for sx, sy, w, d in ((0, -1, 12.0, T), (0, 1, 12.0, T), (-1, 0, T, 12.0), (1, 0, T, 12.0)):
        x, y = sx * (INNER + T / 2), sy * (INNER + T / 2)
        if sx == 1:
            # The east wall's knee is broken by the door: two lengths either side of the 1.4 m opening.
            for side in (-1, 1):
                box("Knee", (T, 5.1, 0.9), (x, side * 3.15, 0), PALE2)
        else:
            box("Knee", (w, d, 0.9), (x, y, 0), PALE2)
        box("Cap", (w if sx == 0 else T + 0.1, d if sy == 0 else T + 0.1, 0.12), (x * 0.985, y * 0.985, 0.9), PALE)
    # The panes: three to a side between iron mullions (on the east side the middle one is the door).
    for side_k in range(4):
        a = side_k * math.pi / 2
        n = (round(math.cos(a)), round(math.sin(a)))
        t = (-n[1], n[0])
        for k in range(3):
            off = (k - 1) * 3.6
            cx, cy = n[0] * (INNER + 0.15) + t[0] * off, n[1] * (INNER + 0.15) + t[1] * off
            is_door = side_k == 0 and k == 1
            if not is_door:
                box("Pane", (3.3 if n[0] == 0 else 0.06, 0.06 if n[0] == 0 else 3.3, 3.2), (cx, cy, 1.02),
                    SOOT2 if (k + side_k) % 2 else SOOT)
            for m in (-1, 1):
                mx, my = cx + t[0] * m * 1.8, cy + t[1] * m * 1.8
                box("Mullion", (0.14, 0.14, 3.3), (mx, my, 0.95), IRON)
        box("Head", (12.0 if n[0] == 0 else 0.4, 0.4 if n[0] == 0 else 12.0, 0.35),
            (n[0] * (INNER + 0.2), n[1] * (INNER + 0.2), 4.2), PALE2)
    for cx in (-1, 1):
        for cy in (-1, 1):
            box("Pier", (0.9, 0.9, 4.55), (cx * (INNER + 0.1), cy * (INNER + 0.1), 0), PALE)
    # The door: a pale frame at the stairhead, the dark of the stair going down beyond, the oak leaf swung back.
    box("Jamb", (0.6, 0.3, 3.0), (INNER + 0.2, -0.85, 0), PALE)
    box("Jamb", (0.6, 0.3, 3.0), (INNER + 0.2, 0.85, 0), PALE)
    box("Lintel", (0.6, 2.0, 0.4), (INNER + 0.2, 0, 2.8), PALE)
    box("Stairdark", (0.1, 1.4, 2.8), (INNER + 0.55, 0, 0), DARK)
    box("Leaf", (1.35, 0.1, 2.6), (INNER - 0.55, 0.92, 0.04), OAK, 0.25)
    for z in (0.5, 1.3, 2.1):
        box("Band", (1.37, 0.12, 0.08), (INNER - 0.55, 0.92, z), IRON, 0.25)
    # The roof's underside: a dark pyramid from the panes' head to an iron boss over the cradle.
    cyl("Roof", 8.6, 0.35, 3.0, 4, (0, 0, 4.55), mat("ink", 0.05), math.pi / 4)
    cyl("Boss", 0.45, 0.2, 0.4, 8, (0, 0, 7.4), IRON)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        rod("Rafter", (math.cos(a) * 7.6, math.sin(a) * 7.6, 4.5), (math.cos(a) * 0.4, math.sin(a) * 0.4, 7.4), 0.12,
            IRON)
    bd.export("lantern_room")


def build_firstflame_cradle() -> None:
    """The Firstflame's cradle (Day 95, the lantern room): the iron basket the Hearthspire burned in for nine hundred
    years, over the top of the shaft — a kerb of the pale stone r 1.7 round the shaft's mouth, four iron legs curving
    up to a bowl of iron bands r 1.5 at 1.1-2.0 m, and in it a heap of pale ash with a hollow in the middle the size of
    two hands, where the last coal sat. Cold. Origin at the kerb's centre on the floor."""
    bd.reset()
    PALE, PALE2, IRON, ASH, DARK = (mat("bone", -0.35), mat("bone", -0.5), mat("ink", 0.15), mat("bone", -0.15),
                                    mat("ink", -0.4))
    cyl("Kerb", 1.75, 1.7, 0.35, 16, (0, 0, 0), PALE2)
    cyl("Mouth", 1.35, 1.35, 0.02, 16, (0, 0, 0.34), DARK)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        c, s = math.cos(a), math.sin(a)
        rod("Leg", (c * 1.6, s * 1.6, 0.35), (c * 1.75, s * 1.75, 1.1), 0.08, IRON)
        rod("Leg", (c * 1.75, s * 1.75, 1.1), (c * 1.5, s * 1.5, 2.0), 0.07, IRON)
    cyl("Bowl", 0.5, 1.45, 0.9, 16, (0, 0, 1.1), DARK)
    for z, r in ((1.12, 0.55), (1.45, 0.95), (1.75, 1.25), (2.0, 1.5)):
        for k in range(16):
            a0, a1 = k / 16 * math.tau, (k + 1) / 16 * math.tau
            rod("Band", (math.cos(a0) * (r + 0.03), math.sin(a0) * (r + 0.03), z),
                (math.cos(a1) * (r + 0.03), math.sin(a1) * (r + 0.03), z), 0.045, IRON)
    for k in range(12):
        a = k / 12 * math.tau
        rod("Rib", (math.cos(a) * 0.55, math.sin(a) * 0.55, 1.12), (math.cos(a) * 1.52, math.sin(a) * 1.52, 2.05),
            0.035, IRON)
    cyl("Ash", 1.42, 1.05, 0.14, 14, (0, 0, 1.99), ASH)
    cyl("Hollow", 0.3, 0.2, 0.03, 8, (0, 0, 2.12), DARK)
    bd.export("firstflame_cradle")


def build_firstflame_cradle_lit() -> None:
    """The cradle lit (Day 96, the `lit` ending): the same kerb, legs and bowl, the bands gone red with the heat, the
    ash caught gold from underneath, and the Firstflame standing up out of the hollow — a ring of short tongues round
    one tall one, all emissive (the region gives it its light). Fire centre Godot [0, 2.8, 0]."""
    bd.reset()
    rng = random.Random(961)
    PALE2, IRON, HOT, DARK = mat("bone", -0.5), mat("ink", 0.15), mat("coal", 0.0, emissive=True), mat("ink", -0.4)
    cyl("Kerb", 1.75, 1.7, 0.35, 16, (0, 0, 0), PALE2)
    cyl("Mouth", 1.35, 1.35, 0.02, 16, (0, 0, 0.34), DARK)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        c, s = math.cos(a), math.sin(a)
        rod("Leg", (c * 1.6, s * 1.6, 0.35), (c * 1.75, s * 1.75, 1.1), 0.08, IRON)
        rod("Leg", (c * 1.75, s * 1.75, 1.1), (c * 1.5, s * 1.5, 2.0), 0.07, IRON)
    cyl("Bowl", 0.5, 1.45, 0.9, 16, (0, 0, 1.1), DARK)
    for z, r in ((1.12, 0.55), (1.45, 0.95), (1.75, 1.25), (2.0, 1.5)):
        for k in range(16):
            a0, a1 = k / 16 * math.tau, (k + 1) / 16 * math.tau
            rod("Band", (math.cos(a0) * (r + 0.03), math.sin(a0) * (r + 0.03), z),
                (math.cos(a1) * (r + 0.03), math.sin(a1) * (r + 0.03), z), 0.045, HOT if z > 1.6 else IRON)
    for k in range(12):
        a = k / 12 * math.tau
        rod("Rib", (math.cos(a) * 0.55, math.sin(a) * 0.55, 1.12), (math.cos(a) * 1.52, math.sin(a) * 1.52, 2.05),
            0.035, IRON)
    cyl("Ash", 1.42, 1.05, 0.14, 14, (0, 0, 1.99), mat("ember", -0.1, emissive=True))
    cyl("Heart", 0.55, 0.4, 0.12, 10, (0, 0, 2.1), mat("kindle", 0.1, emissive=True))
    flame = mat("kindle", 0.2, emissive=True)
    cyl("Flame", 0.38, 0.0, 1.6, 5, (0, 0, 2.15), flame, 0.3)
    for k in range(7):
        a = k / 7 * math.tau + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.55, 0.9)
        cyl("Flame", rng.uniform(0.14, 0.22), 0.0, rng.uniform(0.6, 1.0), 4,
            (math.cos(a) * r, math.sin(a) * r, 2.1), flame, a)
    bd.export("firstflame_cradle_lit")


BUILDERS = {
    "spire_foot": build_spire_foot,
    "spire_foot_open": build_spire_foot_open,
    "chapter_ring": build_chapter_ring,
    "boat_stair": build_boat_stair,
    "boathouse_slips": build_boathouse_slips,
    "hearthspire_far": build_hearthspire_far,
    "hearthspire_far_lit": build_hearthspire_far_lit,
    "cinder_cresset": build_cinder_cresset,
    "cinder_cresset_lit": build_cinder_cresset_lit,
    "cinder_cresset_doused": build_cinder_cresset_doused,
    "chapter_boat": build_chapter_boat,
    "lower_stair": build_lower_stair,
    "spire_book": build_spire_book,
    "hushed_bench": build_hushed_bench,
    "flame_root": build_flame_root,
    "taper_row": build_taper_row,
    "lower_vault": build_lower_vault,
    "landing_shaft": build_landing_shaft,
    "landing_window": build_landing_window,
    "landing_stairhead": build_landing_stairhead,
    "lantern_room": build_lantern_room,
    "firstflame_cradle": build_firstflame_cradle,
    "firstflame_cradle_lit": build_firstflame_cradle_lit,
}

if __name__ == "__main__":
    only = {a for a in sys.argv[1:] if not a.startswith("-")}
    for key, build in BUILDERS.items():
        if not only or key in only:
            build()
