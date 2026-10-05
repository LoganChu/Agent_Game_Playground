"""Builds the ridge kit for Thornwold (Day 22) into the dressing kit: Thornwold's beacon — the
Ridge Light, a Keeper-built tower of the island's own stone and timber, cold and lit — and the
keeper's lodge beside it, where the Lamp sits up nights over a lantern bench — and (Day 24) the way
up to them: the Keepers' log stair and ladder on the woods' north bank, and what the colliers who
climbed it left behind (a cap on a waymark, a dropped sack).

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_ridge.py
    .tools/bin/blender-py tools/blender/build_ridge.py [thornwold_beacon keeper_lodge ridge_steps keeper_ladder
                                                         waymark_cap sack_dropped]

Same conventions as build_dressing/build_woods: origin at the base centre, flat-shaded,
palette colours and tonal shades, Blender -Y = Godot +Z = the front, merged by material.
"""
import math
import os
import random
import sys

import bpy  # noqa: F401  (must be imported before mathutils when running as the bpy module)
from mathutils import Vector  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dressing as bd  # noqa: E402  (materials, primitives, merge + export)
import build_woods as bw  # noqa: E402  (rough lumps)

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod

# The tower's proportions, shared by the cold and lit builds (and the docstring below).
BASE_HALF, TOP_HALF, SHAFT_H = 1.7, 1.25, 6.0
CAGE_HALF, CAGE_H = 1.0, 1.35


def _half_at(z: float) -> float:
    return BASE_HALF + (TOP_HALF - BASE_HALF) * z / SHAFT_H


def _iron_pine(top: Vector, iron) -> None:
    """Thornwold's sign on the roof, as the Gull's Beacon wears an iron gull: a flat iron pine
    (three tiers on a spike) facing front."""
    rod("VaneSpike", top, top + Vector((0, 0, 1.15)), 0.035, iron, verts=4)
    for i, (w, z) in enumerate(((0.42, 0.3), (0.32, 0.58), (0.2, 0.84))):
        p = top + Vector((0, 0, z))
        for s in (-1, 1):
            beam(f"VaneTier{i}", p + Vector((s * w, 0, 0)), p + Vector((0, 0, 0.26)), 0.03, iron, width=0.05)
        beam(f"VaneBar{i}", p + Vector((-w, 0, 0)), p + Vector((w, 0, 0)), 0.03, iron, width=0.04)


def _beacon(lit: bool) -> None:
    """Thornwold's beacon on the ridge, the Ridge Light (~10 m to the vane tip): a square
    dry-stone tower (3.4 m at the foot, tapering to 2.5 m at 6 m), coursed in the island's grey
    stone with quoins of paler stone and a band of bark-dark timber lacing every few courses; a
    plank gallery on beams at 6 m; a timber lantern cage (2 m square, 1.35 m) with horn panes;
    a bark-shingle pyramid roof; an iron pine for a vane. Inside the cage an iron cradle on a
    stone plinth. Round the foot: a doorway on the front (-Y) face with an ember carved over
    it, and a **lantern rack** on the +X face — a beam of hooks, every one empty but one.
    Lit: the horn panes glow kindle (glass centre ≈ (0, 0, 6.7)); cold: dark, ash in the cradle."""
    rng = random.Random(40)
    STONE = (mat("slate", -0.05), mat("slate", -0.2), mat("slate", 0.08))
    QUOIN, TIMBER = mat("slate", 0.3), mat("pine", -0.62)
    WOOD, IRON = mat("driftwood", -0.4), mat("ink", 0.15)
    # The shaft: courses of stone blocks laid round the four faces, jittered so they read as
    # dry-laid, with paler quoins at the corners and a timber lacing band every fourth course.
    course_h = 0.5
    for c in range(int(SHAFT_H / course_h)):
        z = c * course_h
        half = _half_at(z + course_h / 2)
        if c % 4 == 3:
            for k in range(4):
                a = k * math.pi / 2
                d = Vector((math.cos(a), math.sin(a), 0))
                box("Lacing", (half * 2 + 0.1, 0.16, course_h * 0.5), tuple(d * (half - 0.02) + Vector((0, 0, z))),
                    TIMBER, a + math.pi / 2)
            box("CoreBand", (half * 2 - 0.1, half * 2 - 0.1, course_h), (0, 0, z), STONE[0])
            continue
        box("Core", (half * 2 - 0.12, half * 2 - 0.12, course_h), (0, 0, z), STONE[1])
        for k in range(4):  # each face: a row of blocks, staggered course by course
            a = k * math.pi / 2
            n = Vector((math.cos(a), math.sin(a), 0))
            t = Vector((-n.y, n.x, 0))
            blocks = 3
            span = half * 2 / blocks
            for b in range(blocks):
                off = -half + span * (b + 0.5) + (span * 0.5 if c % 2 else 0)
                if abs(off) > half - span * 0.3:
                    continue
                w = span * rng.uniform(0.82, 0.96)
                p = n * (half - 0.05) + t * off + Vector((0, 0, z + 0.02))
                box("Block", (w, 0.14, course_h * rng.uniform(0.86, 0.96)), tuple(p), STONE[(c + b + k) % 3], a + math.pi / 2)
            corner = n * half + t * half  # quoins, alternating long and short
            q = (0.5, 0.32)[(c + k) % 2]
            box("Quoin", (q, q, course_h * 0.94), tuple(corner - n * q * 0.35 - t * q * 0.35 + Vector((0, 0, z + 0.02))),
                QUOIN, a)
    # Doorway on the front face: a dark opening, a timber frame, a lintel stone, the ember
    # carved over it (a ring with a flame in it, as on the waymarks).
    fy = -_half_at(0.6) - 0.1
    box("Door", (0.9, 0.12, 1.75), (0, fy + 0.02, 0), mat("ink", 0.0))
    for sx in (-0.52, 0.52):
        box("DoorJamb", (0.14, 0.18, 1.85), (sx, fy, 0), WOOD)
    box("Lintel", (1.4, 0.24, 0.3), (0, fy - 0.02, 1.85), QUOIN)
    ey = -_half_at(2.4) - 0.12
    for k in range(10):
        a0, a1 = k / 10 * math.tau, (k + 1) / 10 * math.tau
        beam("Ring", (math.cos(a0) * 0.22, ey, 2.45 + math.sin(a0) * 0.22),
             (math.cos(a1) * 0.22, ey, 2.45 + math.sin(a1) * 0.22), 0.05, mat("bone", -0.15))
    beam("Flame", (0, ey, 2.3), (0, ey, 2.62), 0.06, mat("ember", -0.25), width=0.12)
    for k in range(3):  # a worn step and two flags in front of the door
        box("Step", (1.3 - k * 0.15, 0.5, 0.16 - k * 0.05), (rng.uniform(-0.1, 0.1), fy - 0.35 - k * 0.55, 0),
            STONE[k % 3], rng.uniform(-0.08, 0.08))
    # The lantern rack on the +X face: a beam on two iron brackets, eight hooks; one lantern.
    rx = _half_at(1.9) + 0.32
    beam("RackBeam", (rx, -1.0, 1.9), (rx, 1.0, 1.9), 0.12, TIMBER)
    for y in (-0.8, 0.8):
        beam("RackBracket", (rx - 0.36, y, 1.6), (rx, y, 1.86), 0.05, IRON)
    for i in range(8):
        y = -0.88 + i * 0.25
        beam("RackHook", (rx + 0.07, y, 1.88), (rx + 0.07, y, 1.72), 0.025, IRON)
    ly = -0.88 + 5 * 0.25
    cyl("RackLanternCap", 0.12, 0.02, 0.1, 6, (rx + 0.07, ly, 1.6), IRON)
    cyl("RackLanternGlass", 0.08, 0.08, 0.2, 6, (rx + 0.07, ly, 1.38), mat("bone", -0.45))  # cold, empty
    cyl("RackLanternBase", 0.1, 0.1, 0.04, 6, (rx + 0.07, ly, 1.34), IRON)
    # The gallery: beams cantilevered out of the top course, a plank deck, a low rail.
    gz = SHAFT_H
    gh = TOP_HALF + 0.55
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        d = Vector((math.cos(a), math.sin(a), 0))
        beam("GalleryBeam", tuple(d * TOP_HALF * 0.8 + Vector((0, 0, gz - 0.3))),
             tuple(d * (gh + 0.25) * 1.3 + Vector((0, 0, gz - 0.05))), 0.16, TIMBER)
        beam("GalleryStrut", tuple(d * TOP_HALF * 1.2 + Vector((0, 0, gz - 1.0))),
             tuple(d * gh * 1.2 + Vector((0, 0, gz - 0.12))), 0.1, TIMBER)
    box("GalleryDeck", (gh * 2, gh * 2, 0.14), (0, 0, gz), WOOD)
    for k in range(4):
        a = k * math.pi / 2
        n = Vector((math.cos(a), math.sin(a), 0))
        t = Vector((-n.y, n.x, 0))
        beam("GalleryRail", tuple(n * gh + t * gh + Vector((0, 0, gz + 0.85))),
             tuple(n * gh - t * gh + Vector((0, 0, gz + 0.85))), 0.07, WOOD)
        for s in (-1.0, -0.33, 0.33, 1.0):
            beam("GalleryPost", tuple(n * gh + t * gh * s + Vector((0, 0, gz + 0.14))),
                 tuple(n * gh + t * gh * s + Vector((0, 0, gz + 0.9))), 0.06, WOOD)
    # The lantern cage: corner posts and sills of dark timber, horn panes between.
    cz = gz + 0.14
    pane = mat("kindle", 0.0, emissive=True) if lit else mat("ink", 0.12)
    box("CageSill", (CAGE_HALF * 2 + 0.16, CAGE_HALF * 2 + 0.16, 0.18), (0, 0, cz), TIMBER)
    box("Panes", (CAGE_HALF * 2 - 0.08, CAGE_HALF * 2 - 0.08, CAGE_H - 0.3), (0, 0, cz + 0.18), pane)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("CagePost", (0.14, 0.14, CAGE_H), (sx * CAGE_HALF, sy * CAGE_HALF, cz), TIMBER)
    for k in range(4):  # a mullion down the middle of every face
        a = k * math.pi / 2
        n = Vector((math.cos(a), math.sin(a), 0)) * (CAGE_HALF - 0.02)
        box("Mullion", (0.07, 0.07, CAGE_H - 0.3), (n.x, n.y, cz + 0.18), TIMBER)
    box("CageHead", (CAGE_HALF * 2 + 0.2, CAGE_HALF * 2 + 0.2, 0.16), (0, 0, cz + CAGE_H - 0.12), TIMBER)
    # The cradle inside on its plinth (seen through the panes when cold; a dark core when lit).
    box("CradlePlinth", (0.5, 0.5, 0.35), (0, 0, cz + 0.18), STONE[1])
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        rod("CradleBar", (math.cos(a) * 0.12, math.sin(a) * 0.12, cz + 0.53),
            (math.cos(a) * 0.3, math.sin(a) * 0.3, cz + 0.95), 0.03, IRON, verts=4)
    if not lit:
        cyl("Ash", 0.2, 0.12, 0.12, 6, (0, 0, cz + 0.53), mat("silverfog", -0.15))
    # The roof: a bark-shingle pyramid in two pitches (a flared eave), and the iron pine.
    rz = cz + CAGE_H + 0.04
    cyl("Eave", (CAGE_HALF + 0.75) * math.sqrt(2), (CAGE_HALF + 0.2) * math.sqrt(2), 0.4, 4, (0, 0, rz),
        mat("pine", -0.55), math.pi / 4)
    cyl("Roof", (CAGE_HALF + 0.2) * math.sqrt(2), 0.05, 1.0, 4, (0, 0, rz + 0.4), mat("pine", -0.45), math.pi / 4)
    for k in range(4):  # ridge battens down the hips
        a = k * math.pi / 2 + math.pi / 4
        d = Vector((math.cos(a), math.sin(a), 0))
        beam("Hip", tuple(d * (CAGE_HALF + 0.75) * math.sqrt(2) * 0.98 + Vector((0, 0, rz + 0.02))),
             (0, 0, rz + 1.4), 0.07, TIMBER)
    _iron_pine(Vector((0, 0, rz + 1.38)), IRON)
    # Fallen stones and a drift of needles at the foot.
    for k in range(5):
        a = rng.uniform(0, math.tau)
        d = BASE_HALF + rng.uniform(0.3, 0.9)
        bw._lump("Fallen", (0.24, 0.18, 0.14), (math.cos(a) * d, math.sin(a) * d, 0.06), STONE[k % 3], rng)


def build_thornwold_beacon() -> None:
    bd.reset()
    _beacon(False)
    bd.export("thornwold_beacon")
    bd.reset()
    _beacon(True)
    bd.export("thornwold_beacon_lit")


def build_keeper_lodge() -> None:
    """The keeper's lodge beside the Ridge Light (~4.4 × 3.2 m, 3.3 m to the chimney top): a low
    stone house with a turf-and-bark roof pitched front to back, a squat stone chimney, a plank
    door under the Keepers' ember (front, -Y), one shuttered window. Outside under the eave, the
    Lamp's **lantern bench**: a plank bench with a lantern waiting open, a small iron box shut,
    a hammer and a cold chisel laid by it (breaking a coal into slivers — shown, not explained),
    and three lanterns on pegs; a split-log pile and a bucket by the corner."""
    bd.reset()
    rng = random.Random(41)
    STONE = (mat("slate", -0.12), mat("slate", 0.05), mat("slate", -0.25))
    WOOD, IRON, LOG = mat("driftwood", -0.4), mat("ink", 0.15), mat("driftwood", -0.2)
    w, d, wall_h = 4.0, 2.8, 1.9
    box("Walls", (w, d, wall_h), (0, 0, 0), STONE[0])
    for k in range(10):  # proud stones in the walls (front, back, the two ends)
        side = k % 4
        z = rng.uniform(0.2, wall_h - 0.4)
        if side < 2:
            x, y, rot = rng.uniform(-w / 2 + 0.4, w / 2 - 0.4), (-1 if side == 0 else 1) * (d / 2 + 0.04), 0.0
        else:
            x, y, rot = (1 if side == 2 else -1) * (w / 2 + 0.04), rng.uniform(-d / 2 + 0.4, d / 2 - 0.4), math.pi / 2
        if side == 0 and (abs(x - 0.9) < 0.7 or abs(x + 0.9) < 0.6):
            continue  # the door and the window
        box("WallStone", (rng.uniform(0.4, 0.7), 0.1, rng.uniform(0.25, 0.4)), (x, y, z), STONE[1 + k % 2], rot)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Corner", (0.36, 0.36, wall_h + 0.05), (sx * (w / 2 - 0.12), sy * (d / 2 - 0.12), 0), STONE[2])
    # Roof: a ridge running along X, gable ends of stone; turf over bark.
    bd.bp.prism("RoofBark", d + 0.7, w + 0.5, 1.0, (0, 0, wall_h), mat("pine", -0.55)).rotation_euler = (0, 0, math.pi / 2)
    bd.bp.prism("RoofTurf", d + 0.5, w + 0.3, 0.92, (0, 0, wall_h + 0.12), mat("moss", -0.45)).rotation_euler = (
        0, 0, math.pi / 2)
    for sx in (-1, 1):  # stone gables under the roof ends
        bd.bp.prism("Gable", d, 0.3, 0.9, (sx * (w / 2 - 0.15), 0, wall_h), STONE[0]).rotation_euler = (0, 0, math.pi / 2)
    # Chimney at the west gable, cold.
    box("Chimney", (0.7, 0.7, 3.3), (-w / 2 + 0.35, 0.3, 0), STONE[2])
    box("ChimneyCap", (0.85, 0.85, 0.12), (-w / 2 + 0.35, 0.3, 3.3), STONE[1])
    # Door and the ember over it; a shuttered window.
    dx, fy = 0.9, -d / 2 - 0.03
    box("Door", (0.8, 0.08, 1.55), (dx, fy, 0), WOOD)
    for k in range(3):
        box("DoorBatten", (0.84, 0.1, 0.07), (dx, fy - 0.01, 0.25 + k * 0.5), mat("driftwood", -0.5))
    box("DoorLintel", (1.1, 0.16, 0.18), (dx, fy - 0.02, 1.6), STONE[1])
    for k in range(8):
        a0, a1 = k / 8 * math.tau, (k + 1) / 8 * math.tau
        beam("Ring", (dx + math.cos(a0) * 0.12, fy - 0.12, 1.82 + math.sin(a0) * 0.12),
             (dx + math.cos(a1) * 0.12, fy - 0.12, 1.82 + math.sin(a1) * 0.12), 0.03, mat("bone", -0.15))
    beam("Flame", (dx, fy - 0.12, 1.74), (dx, fy - 0.12, 1.92), 0.04, mat("ember", -0.25), width=0.07)
    box("Window", (0.6, 0.08, 0.55), (-0.9, fy, 0.9), mat("ink", 0.0))
    for sx in (-0.48, 0.48):
        box("Shutter", (0.32, 0.06, 0.6), (-0.9 + sx, fy - 0.02, 0.88), WOOD)
    # The lantern bench under the eave, to the left of the door (Godot -X when facing it).
    bx, by = -1.0, -d / 2 - 0.65
    box("BenchTop", (1.6, 0.5, 0.08), (bx, by, 0.72), WOOD)
    for sx in (-0.65, 0.65):
        for sy in (-0.18, 0.18):
            beam("BenchLeg", (bx + sx, by + sy, 0), (bx + sx, by + sy, 0.72), 0.07, WOOD)
    # An open lantern waiting (door hinged out), a small shut iron box, hammer and chisel.
    lx = bx - 0.45
    cyl("BenchLanternBase", 0.12, 0.12, 0.04, 6, (lx, by, 0.8), IRON)
    for i in range(3):
        a = math.tau * i / 3
        beam("BenchLanternFrame", (lx + math.cos(a) * 0.11, by + math.sin(a) * 0.11, 0.82),
             (lx + math.cos(a) * 0.11, by + math.sin(a) * 0.11, 1.12), 0.02, IRON)
    cyl("BenchLanternCap", 0.15, 0.02, 0.13, 6, (lx, by, 1.12), IRON)
    beam("BenchLanternDoor", (lx + 0.1, by - 0.08, 0.84), (lx + 0.24, by - 0.2, 1.1), 0.015, mat("bone", -0.45), width=0.14)
    box("CoalBox", (0.26, 0.18, 0.14), (bx + 0.05, by + 0.02, 0.8), IRON, 0.2)
    box("CoalBoxBand", (0.28, 0.2, 0.03), (bx + 0.05, by + 0.02, 0.88), IRON, 0.2)
    beam("HammerHaft", (bx + 0.35, by - 0.12, 0.83), (bx + 0.68, by + 0.04, 0.83), 0.03, WOOD)
    box("HammerHead", (0.06, 0.16, 0.06), (bx + 0.35, by - 0.12, 0.8), IRON, 0.45)
    beam("Chisel", (bx + 0.3, by + 0.14, 0.82), (bx + 0.52, by + 0.17, 0.82), 0.022, IRON)
    # Lanterns on pegs along the wall to the right of the door: three, cold.
    for i in range(4):
        px = dx + 0.75 + i * 0.32
        if px > w / 2 - 0.25:
            break
        rod("Peg", (px, fy, 1.5), (px, fy - 0.16, 1.52), 0.02, WOOD, verts=4)
        if i == 2:
            continue  # one peg empty
        cyl("PegLanternCap", 0.1, 0.02, 0.09, 6, (px, fy - 0.16, 1.34), IRON)
        cyl("PegLanternGlass", 0.07, 0.07, 0.18, 6, (px, fy - 0.16, 1.14), mat("bone", -0.45))
        cyl("PegLanternBase", 0.08, 0.08, 0.03, 6, (px, fy - 0.16, 1.11), IRON)
    # A split-log pile against the east gable and a bucket.
    for row in range(3):
        for k in range(4 - row):
            y = -0.75 + k * 0.32 + row * 0.16
            rod("Log", (w / 2 + 0.1, y, 0.15 + row * 0.27), (w / 2 + 0.8, y, 0.15 + row * 0.27), 0.14,
                (LOG, WOOD)[(row + k) % 2], verts=5)
    cyl("Bucket", 0.2, 0.24, 0.36, 7, (w / 2 + 0.4, -d / 2 - 0.4, 0), mat("driftwood", -0.5))
    cyl("BucketHoop", 0.23, 0.23, 0.04, 7, (w / 2 + 0.4, -d / 2 - 0.4, 0.26), IRON)
    bd.export("keeper_lodge")


# --- The way up (Day 24) --------------------------------------------------------------------
# The Keepers' stair up the woods' north bank: two flights of log steps on a built-up earth
# ramp (the ground itself is the region's `path` feature — these models only dress it), a turn
# between them, a landing under the last steep pitch, and a ladder for that pitch. Each flight
# model climbs along +X from its origin (the low end, on the ramp's centreline) by exactly the
# rise the region's path gives it, so snapping the origin to the ground puts every step on it.
STAIR_FLIGHTS = {
    # name: (length, rise, steps, rail side: -1 = Blender -Y = Godot +Z, the south side when unrotated)
    "ridge_steps_lower": (7.5, 1.85, 9, -1),
    "ridge_steps_upper": (6.0, 1.6, 7, 1),   # placed rotated 180°, so its +Y rail faces south too
}


def _stake(x, y, z, h, wood, rng) -> None:
    """A split stake driven in at (x, y) on ground height z, standing h, leaning a touch."""
    lean = Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.04, 0.04), 0))
    rod("Stake", (x, y, z - 0.15), Vector((x, y, z + h)) + lean, 0.05, wood, verts=5, r_end=0.04)


def _flight(length: float, rise: float, steps: int, rail_side: int) -> None:
    """One flight of the Keepers' stair: `steps` bark-dark log risers across the 2.8 m ramp, each
    held by two pegs on its downhill face and half sunk into the earth; a rope rail on stakes
    along one side, sagging between them; the Keepers' ember cut in the bottom stake."""
    rng = random.Random(51 + steps)
    LOG, PEG, ROPE = mat("driftwood", -0.55), mat("driftwood", -0.7), mat("driftwood", -0.05)
    half = 0.9  # the ramp is 2.8 m wide; the rail stands inside its flat top
    def ground(x: float) -> float:
        return rise * min(max(x, 0.0), length) / length
    for i in range(steps):
        x = length * (i + 0.5) / steps
        z = ground(x)
        # The log's top sits ~0.1 m proud of the ramp on its uphill edge (a step, not a lump).
        rod("Riser", (x, -half + rng.uniform(-0.05, 0.05), z + 0.02), (x, half + rng.uniform(-0.05, 0.05), z + 0.02),
            0.12, LOG, verts=6, r_end=0.1)
        for py in (-half + 0.25, half - 0.25):
            rod("Peg", (x - 0.15, py, z - 0.15), (x - 0.15, py, z + 0.15), 0.035, PEG, verts=4)
    # The rope rail: a stake every ~2 m on the open side, the rope looped over each top.
    y = rail_side * (half + 0.2)
    n = max(2, round(length / 1.9) + 1)
    tops = []
    for k in range(n):
        x = length * k / (n - 1)
        z = ground(x)
        _stake(x, y, z, 0.95, PEG, rng)
        tops.append(Vector((x, y, z + 0.88)))
    for a, b in zip(tops, tops[1:]):
        mid = (a + b) / 2 - Vector((0, 0, 0.12))
        rod("Rope", a, mid, 0.018, ROPE, verts=4)
        rod("Rope", mid, b, 0.018, ROPE, verts=4)
    # The carved ember on the bottom stake's outer face, as on the waymark posts.
    face = y + rail_side * 0.055
    for k in range(6):
        a0, a1 = k / 6 * math.tau, (k + 1) / 6 * math.tau
        beam("Ring", (math.cos(a0) * 0.05, face, 0.6 + math.sin(a0) * 0.05),
             (math.cos(a1) * 0.05, face, 0.6 + math.sin(a1) * 0.05), 0.015, mat("bone", -0.2))
    beam("Flame", (0, face, 0.57), (0, face, 0.65), 0.018, mat("ember", -0.2), width=0.03)


def build_ridge_steps() -> None:
    for name, (length, rise, steps, side) in STAIR_FLIGHTS.items():
        bd.reset()
        _flight(length, rise, steps, side)
        bd.export(name)


def _ladder(fallen: bool) -> None:
    """The Keepers' ladder for the last pitch (3.2 m): two peeled pole rails, eight rungs lashed
    on with dark cord. Standing (`keeper_ladder`): its feet at the origin, leaning back toward
    +Y (Godot -Z) at ~68° — top ≈ 2.95 m up and 1.2 m back. Fallen (`keeper_ladder_fallen`):
    lying flat along X, two rungs snapped out of it, the top end silvered by the fog."""
    rng = random.Random(61)
    RAIL, RUNG, CORD = mat("driftwood", -0.3), mat("driftwood", -0.15), mat("ink", 0.1)
    length, half = 3.2, 0.24
    if fallen:
        def at(t: float, side: float) -> Vector:  # flat on the ground along X
            return Vector((t * length - length / 2, side * half, 0.06))
    else:
        tilt = math.radians(22)
        def at(t: float, side: float) -> Vector:
            return Vector((side * half, t * length * math.sin(tilt), t * length * math.cos(tilt)))
    for side in (-1, 1):
        rod("Rail", at(0.0, side), at(0.82, side), 0.055, RAIL, verts=6, r_end=0.05)
        rod("RailTop", at(0.82, side), at(1.0, side), 0.05, mat("silverfog", -0.3) if fallen else RAIL, verts=6,
            r_end=0.045)
    for k in range(8):
        t = 0.08 + k * 0.12
        if fallen and k in (3, 5):
            # snapped: a stub on one rail, the rest gone
            rod("Rung", at(t, -1), at(t, -1) + (at(t, 1) - at(t, -1)) * 0.3, 0.03, RUNG, verts=5)
            continue
        rod("Rung", at(t, -1) + (at(t, -1) - at(t, 1)) * 0.08, at(t, 1) + (at(t, 1) - at(t, -1)) * 0.08,
            0.032, RUNG, verts=5)
        for side in (-1, 1):
            p = at(t, side)
            cyl("Lashing", 0.065, 0.065, 0.06, 5, p - Vector((0, 0, 0.03)) if not fallen else p, CORD,
                rng.uniform(0, 1))


def build_keeper_ladder() -> None:
    bd.reset()
    _ladder(False)
    bd.export("keeper_ladder")
    bd.reset()
    _ladder(True)
    bd.export("keeper_ladder_fallen")


def build_waymark_cap() -> None:
    """A bare waymark at the foot of the stair with a collier's felt cap hung on its lantern
    hook where a lantern should be — one of the four who "went up after the Lamp" left it
    there (asking for a light? marking the way? not said)."""
    bd.reset()
    bw._waymark(False)
    felt, band = mat("driftwood", -0.6), mat("coal", -0.4)
    # The cap hangs by its band from the hook at (0, -0.5, 2.0): crown down, brim tipped.
    bw._lump("Cap", (0.15, 0.14, 0.09), (0, -0.5, 1.9), felt, random.Random(71), 0.06, (0.35, 0, 0.2))
    cyl("CapBand", 0.155, 0.15, 0.04, 7, (0, -0.5, 1.94), band)
    beam("CapBrim", (0, -0.47, 1.97), (0, -0.66, 1.93), 0.02, felt, width=0.2)
    bd.export("waymark_cap")


def build_sack_dropped() -> None:
    """A charcoal sack let fall on the stair's turn: lying split along its side, charcoal spilled
    downhill (-X) in a black fan, the neck cord still tied (whoever carried it up didn't come
    back down for it)."""
    bd.reset()
    rng = random.Random(81)
    bw._sack((0.15, 0, 0), rng, lying=True, shade=-0.25)
    box("Split", (0.4, 0.06, 0.12), (0.18, -0.2, 0.14), mat("ink", 0.0), 0.15)
    for k in range(14):
        r = rng.uniform(0.15, 0.75)
        a = rng.uniform(-0.9, 0.9) - math.pi / 2 - 0.3
        s = rng.uniform(0.04, 0.08)
        bw._lump("Coal", (s * 1.3, s, s * 0.8), (0.15 + math.cos(a) * r * 0.4 - r * 0.6, math.sin(a) * r * 0.5 - 0.15, s * 0.4),
                 mat("ink", 0.05), rng, 0.2)
    bd.export("sack_dropped")


BUILDERS = [build_thornwold_beacon, build_keeper_lodge, build_ridge_steps, build_keeper_ladder, build_waymark_cap,
            build_sack_dropped]
ALIASES = {"thornwold_beacon_lit": "thornwold_beacon", "ridge_steps_lower": "ridge_steps",
           "ridge_steps_upper": "ridge_steps", "keeper_ladder_fallen": "keeper_ladder"}

if __name__ == "__main__":
    only = {ALIASES.get(a, a) for a in sys.argv[1:] if not a.startswith("-")}
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
