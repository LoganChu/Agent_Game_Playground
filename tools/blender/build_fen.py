"""Builds Glasswater Fen's first kit (Day 29) into the dressing kit: the Unmoored's **reed
houses** on Stillhithe (fen-folk houses of bundled reed on low stilts, left empty when the fen
folk went to the lanes), the **letting post** on its islet (where the Unmoored hang what they
leave for the ones further in) with a variant carrying the Wakebearer's word tied on, and the
fen's beacon, **the Heron Light** — a Keeper-built lantern room on four tall legs out in the
mere, cold, an iron heron for a vane.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_fen.py
    .tools/bin/blender-py tools/blender/build_fen.py [reed_house letting_post heron_light staithe boardwalk
        plank_path punt eel_traps alder_snag reed_bed]

Same conventions as build_dressing/build_ridge: origin at the base centre, flat-shaded,
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

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod

# The reed house's proportions (the region's collider [3.0, 3.4, 2.6] fits them).
DECK_Z, HALF_W, HALF_D, WALL_H = 0.45, 1.4, 1.15, 1.7


def build_reed_house() -> None:
    """A fen-folk house (~3.6 m): a plank floor on short stilts over the wet ground, walls of
    reed bundles lashed upright between corner posts, a steep reed-thatch roof bound along the
    ridge with cord, a low doorway on the front with a step, and a coil of eel-line on a peg.
    The fen folk left them; the Unmoored live in them now and mend nothing."""
    bd.reset()
    rng = random.Random(29)
    POST, PLANK = mat("driftwood", -0.45), mat("driftwood", -0.25)
    REED = (mat("driftwood", -0.05), mat("driftwood", -0.18), mat("moss", -0.05))
    THATCH, CORD = mat("driftwood", -0.12), mat("coal", -0.55)
    for sx in (-1, 1):
        for sy in (-1, 1):
            rod("Stilt", (sx * (HALF_W - 0.1), sy * (HALF_D - 0.1), -0.22),
                (sx * (HALF_W - 0.1), sy * (HALF_D - 0.1), DECK_Z), 0.08, POST, verts=5)
            rod("CornerPost", (sx * HALF_W, sy * HALF_D, DECK_Z), (sx * HALF_W, sy * HALF_D, DECK_Z + WALL_H + 0.1),
                0.08, POST, verts=5)
    box("Floor", (HALF_W * 2 + 0.3, HALF_D * 2 + 0.3, 0.1), (0, 0, DECK_Z - 0.1), PLANK)
    # Reed walls: upright bundles side by side on each face, a gap left for the door (front).
    for face in range(4):
        a = face * math.pi / 2
        n = Vector((math.cos(a), math.sin(a), 0))
        t = Vector((-n.y, n.x, 0))
        half = HALF_W if face % 2 else HALF_D
        dist = HALF_D if face % 2 else HALF_W
        count = int(half * 2 / 0.16)
        for i in range(count):
            off = -half + 0.08 + i * (half * 2 - 0.16) / max(1, count - 1)
            if face == 3 and abs(off) < 0.42:  # the doorway in the front (-Y) wall
                continue
            p = n * dist + t * off
            top = WALL_H * rng.uniform(0.96, 1.02)
            rod("Reed", (p.x, p.y, DECK_Z), (p.x, p.y, DECK_Z + top), 0.085, REED[i % 3], verts=4)
        for z in (0.35, 1.1):  # two lashing bands round each wall
            box("Lash", (half * 2 + 0.04, 0.05, 0.05), tuple(n * (dist + 0.07) + Vector((0, 0, DECK_Z + z))), CORD,
                a + math.pi / 2)
    box("Doorway", (0.8, 0.05, WALL_H - 0.1), (0, -HALF_D - 0.02, DECK_Z), mat("ink", 0.05))
    box("Lintel", (1.0, 0.16, 0.14), (0, -HALF_D - 0.05, DECK_Z + WALL_H - 0.15), POST)
    box("Step", (0.9, 0.42, 0.12), (0, -HALF_D - 0.42, 0.12), PLANK)
    # The roof: two steep thatch slopes with a deep overhang, the ridge bound with cord.
    eave_z, ridge_z = DECK_Z + WALL_H - 0.05, DECK_Z + WALL_H + 1.35
    run = HALF_W + 0.45
    for s in (-1, 1):
        # A slab from the eave up to the ridge: `beam`'s width runs along world Y here (the
        # house's depth) and its thickness is the slab's.
        beam("Thatch", (s * run, 0, eave_z - 0.1), (s * 0.05, 0, ridge_z + 0.08), 0.26, THATCH, width=HALF_D * 2 + 0.7)
        # Shaggy eaves: short reed ends hanging under the slope's edge.
        for k in range(9):
            y = -HALF_D - 0.3 + k * (HALF_D * 2 + 0.6) / 8
            rod("Eave", (s * (run + 0.02), y, eave_z - 0.02), (s * (run + 0.12), y, eave_z - 0.3), 0.06,
                REED[k % 2], verts=3, r_end=0.0)
    beam("Ridge", (0, -HALF_D - 0.4, ridge_z), (0, HALF_D + 0.4, ridge_z), 0.2, mat("driftwood", -0.3))
    for y in (-HALF_D, 0.0, HALF_D):
        beam("RidgeCord", (-0.16, y, ridge_z - 0.05), (0.16, y, ridge_z - 0.05), 0.06, CORD)
    # Gable ends: a triangle of reed under each slope, front and back.
    for sy in (-1, 1):
        for k in range(7):
            x = -run * 0.8 + k * run * 1.6 / 6
            h = (ridge_z - eave_z) * (1 - abs(x) / run)
            rod("Gable", (x, sy * HALF_D, eave_z), (x, sy * HALF_D, eave_z + h), 0.09, REED[k % 3], verts=4)
    # An eel-line coiled on a peg by the door; a pole leaning on the wall.
    beam("Peg", (0.65, -HALF_D - 0.05, DECK_Z + 1.2), (0.65, -HALF_D - 0.2, DECK_Z + 1.22), 0.04, POST)
    cyl("EelLine", 0.13, 0.13, 0.1, 8, (0.65, -HALF_D - 0.16, DECK_Z + 1.02), mat("slate", -0.35))
    rod("Pole", (HALF_W + 0.35, -0.6, 0.0), (HALF_W + 0.08, -0.3, 2.6), 0.035, POST, verts=4)
    bd.export("reed_house")


def _letting_post(word: bool) -> None:
    rng = random.Random(7)
    WOOD = mat("silverfog", -0.4)
    IRON = mat("ink", 0.2)
    for k in range(6):  # a ring of fen stones round the foot
        a = k / 6 * math.tau + rng.uniform(-0.2, 0.2)
        cyl("FootStone", 0.2, 0.12, 0.18, 5, (math.cos(a) * 0.4, math.sin(a) * 0.4, 0), mat("slate", -0.2 - 0.05 * (k % 3)))
    rod("Post", (0, 0, 0), (0, 0, 2.3), 0.12, WOOD, verts=6, r_end=0.1)
    cyl("PostCap", 0.12, 0.04, 0.12, 6, (0, 0, 2.3), WOOD)
    beam("Crossbar", (-0.85, 0, 1.9), (0.85, 0, 1.9), 0.1, WOOD)
    hooks = (-0.75, -0.45, -0.15, 0.15, 0.45, 0.75)
    for x in hooks:
        beam("Hook", (x, -0.05, 1.86), (x, -0.08, 1.7), 0.025, IRON)
    # What's been left for the ones further in, every thing silvering where it hangs.
    # A child's shoe on a lace.
    rod("Lace", (-0.75, -0.08, 1.7), (-0.75, -0.08, 1.45), 0.008, mat("bone", -0.3), verts=3)
    box("Shoe", (0.1, 0.2, 0.09), (-0.75, -0.1, 1.33), mat("coal", -0.35))
    # A ribbon, faded.
    beam("Ribbon", (-0.45, -0.08, 1.7), (-0.42, -0.1, 1.2), 0.012, mat("ember", -0.1), width=0.05)
    # A key on a string.
    rod("KeyString", (-0.15, -0.08, 1.7), (-0.15, -0.08, 1.5), 0.006, mat("bone", -0.3), verts=3)
    cyl("KeyBow", 0.04, 0.04, 0.015, 6, (-0.15, -0.08, 1.46), IRON)
    beam("KeyShaft", (-0.15, -0.08, 1.45), (-0.15, -0.08, 1.33), 0.015, IRON)
    # A bundle of letters tied with string.
    box("Letters", (0.16, 0.06, 0.11), (0.15, -0.1, 1.48), mat("bone", -0.15))
    beam("LettersString", (0.15, -0.08, 1.7), (0.15, -0.1, 1.59), 0.01, mat("coal", -0.4))
    # A whittled gull hung by a thread from the fifth hook (the big man's), wings out.
    g = Vector((0.45, -0.1, 1.5))
    rod("GullThread", (0.45, -0.08, 1.7), tuple(g + Vector((0, 0, 0.03))), 0.006, mat("bone", -0.3), verts=3)
    box("GullBody", (0.05, 0.14, 0.05), tuple(g), mat("driftwood", 0.1))
    for s in (-1, 1):
        beam("GullWing", tuple(g + Vector((0, 0, 0.04))), tuple(g + Vector((s * 0.14, 0.01, 0.07))), 0.012,
             mat("driftwood", 0.1), width=0.06)
    box("GullHead", (0.04, 0.05, 0.04), tuple(g + Vector((0, -0.08, 0.04))), mat("driftwood", 0.1))
    # A spoon.
    beam("Spoon", (0.75, -0.08, 1.7), (0.75, -0.08, 1.48), 0.015, mat("slate", 0.1))
    cyl("SpoonBowl", 0.035, 0.035, 0.02, 6, (0.75, -0.08, 1.44), mat("slate", 0.1))
    # Things nobody took, gone grey in the heap at the foot: a cap, a cup, a doll.
    box("GreyCap", (0.22, 0.2, 0.08), (0.42, -0.28, 0.05), mat("silverfog", -0.15), 0.4)
    cyl("GreyCup", 0.06, 0.05, 0.1, 6, (-0.35, -0.42, 0.04), mat("silverfog", -0.1))
    box("GreyDoll", (0.08, 0.2, 0.06), (-0.5, -0.1, 0.12), mat("silverfog", -0.05), -0.6)
    if word:
        # The Wakebearer's word: a strip of sailcloth knotted to the post under the bar, a cord
        # of Saltmarrow red through it (whatever it says; the post doesn't tell).
        # (Sailcloth and cord share the letters' and the shoe's materials: one draw call each.)
        box("WordKnot", (0.1, 0.09, 0.1), (0, -0.13, 1.55), mat("bone", -0.15))
        beam("WordTail", (0.0, -0.15, 1.56), (0.06, -0.17, 1.2), 0.012, mat("bone", -0.15), width=0.08)
        rod("WordCord", (-0.12, -0.13, 1.62), (0.12, -0.13, 1.62), 0.012, mat("coal", -0.35), verts=4)
    bd.export("letting_post_word" if word else "letting_post")


def build_letting_post() -> None:
    """The letting post on its islet (~2.3 m): a silvered post with a crossbar of iron hooks, hung
    with what the Unmoored leave for the ones further in — a child's shoe, a ribbon, a key, a
    bundle of letters, a whittled gull, a spoon — and a heap of greyed things nobody took at its
    foot. `letting_post_word` adds a strip of sailcloth knotted on with a red cord: the word the
    Wakebearer left there."""
    bd.reset()
    _letting_post(False)
    bd.reset()
    _letting_post(True)


def _heron(top: Vector, iron) -> None:
    """Glasswater's sign on the roof, as the Gull's Beacon wears an iron gull and the Ridge Light an
    iron pine: an iron heron standing on one leg, neck folded, beak forward (-Y)."""
    rod("HeronLeg", top, top + Vector((0, 0, 0.55)), 0.02, iron, verts=4)
    body = top + Vector((0, 0.05, 0.68))
    beam("HeronBody", tuple(body + Vector((0, 0.16, 0.04))), tuple(body + Vector((0, -0.12, 0.0))), 0.12, iron, width=0.09)
    beam("HeronTail", tuple(body + Vector((0, 0.16, 0.04))), tuple(body + Vector((0, 0.3, -0.06))), 0.04, iron, width=0.07)
    neck = body + Vector((0, -0.12, 0.02))
    head = neck + Vector((0, -0.04, 0.3))
    beam("HeronNeck", tuple(neck), tuple(head), 0.04, iron)
    beam("HeronBeak", tuple(head), tuple(head + Vector((0, -0.3, -0.04))), 0.025, iron)
    beam("HeronCrest", tuple(head), tuple(head + Vector((0, 0.16, 0.05))), 0.012, iron)


def build_heron_light() -> None:
    """Glasswater Fen's beacon, the Heron Light (~11 m to the vane), cold: Keepers built it out in
    the mere where the fen has no stone — four tall silvered timber legs driven into the mere bed
    (standing in ~0.9 m of water when placed at y -1.15), X-braced in two tiers; a plank platform
    at 6.2 m with a rail; a square lantern room with horn panes, dark; a steep reed-thatch roof;
    an iron heron for a vane. A ladder up one leg; a keeper's skiff tied to the legs, half full of
    water. Cradle inside on an iron plate (ash in it)."""
    bd.reset()
    LEG, BRACE, PLANK = mat("silverfog", -0.45), mat("silverfog", -0.55), mat("driftwood", -0.4)
    IRON, THATCH = mat("ink", 0.15), mat("driftwood", -0.2)
    plat_z, foot = 6.2, 1.6
    top_half = 1.15
    legs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            a, b = Vector((sx * foot, sy * foot, 0)), Vector((sx * top_half, sy * top_half, plat_z))
            rod("Leg", tuple(a), tuple(b), 0.14, LEG, verts=6)
            legs.append((a, b))
    for z0, z1 in ((0.6, 3.2), (3.2, 5.8)):  # two tiers of X-bracing on every face
        for i in range(4):
            (a0, b0), (a1, b1) = legs[(0, 1, 3, 2)[i]], legs[(1, 3, 2, 0)[i]]
            p = lambda a, b, z: a + (b - a) * (z / plat_z)  # noqa: E731
            beam("Brace", tuple(p(a0, b0, z0)), tuple(p(a1, b1, z1)), 0.09, BRACE)
            beam("Brace", tuple(p(a1, b1, z0)), tuple(p(a0, b0, z1)), 0.09, BRACE)
    box("Platform", (top_half * 2 + 1.0, top_half * 2 + 1.0, 0.16), (0, 0, plat_z), PLANK)
    ph = top_half + 0.5
    for k in range(4):
        a = k * math.pi / 2
        n = Vector((math.cos(a), math.sin(a), 0))
        t = Vector((-n.y, n.x, 0))
        beam("Rail", tuple(n * ph + t * ph + Vector((0, 0, plat_z + 0.9))), tuple(n * ph - t * ph + Vector((0, 0, plat_z + 0.9))),
             0.07, PLANK)
        for s in (-1.0, 0.0, 1.0):
            beam("RailPost", tuple(n * ph + t * ph * s + Vector((0, 0, plat_z + 0.16))),
                 tuple(n * ph + t * ph * s + Vector((0, 0, plat_z + 0.95))), 0.06, PLANK)
    # The lantern room: dark timber frame, horn panes (cold: dark), a cradle on an iron plate.
    rz, rh, rhalf = plat_z + 0.16, 1.4, 0.85
    box("RoomSill", (rhalf * 2 + 0.16, rhalf * 2 + 0.16, 0.16), (0, 0, rz), PLANK)
    box("Panes", (rhalf * 2 - 0.06, rhalf * 2 - 0.06, rh - 0.3), (0, 0, rz + 0.16), mat("ink", 0.12))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("RoomPost", (0.13, 0.13, rh), (sx * rhalf, sy * rhalf, rz), mat("pine", -0.6))
    box("RoomHead", (rhalf * 2 + 0.2, rhalf * 2 + 0.2, 0.14), (0, 0, rz + rh - 0.1), mat("pine", -0.6))
    box("CradlePlate", (0.5, 0.5, 0.06), (0, 0, rz + 0.16), IRON)
    cyl("Ash", 0.2, 0.12, 0.1, 6, (0, 0, rz + 0.22), mat("silverfog", -0.15))
    # The roof: a steep four-sided reed-thatch pyramid with a shaggy eave.
    roof_z = rz + rh + 0.02
    cyl("Roof", rhalf * 1.95, 0.08, 1.7, 4, (0, 0, roof_z), THATCH, math.pi / 4)
    cyl("RoofEave", rhalf * 2.05, rhalf * 1.9, 0.14, 4, (0, 0, roof_z - 0.08), mat("driftwood", -0.35), math.pi / 4)
    _heron(Vector((0, 0, roof_z + 1.68)), IRON)
    # A ladder up the front-left leg, rungs lashed; the lowest rungs green with slime.
    (a, b) = legs[0]
    side = Vector((0.32, 0, 0))
    for s in (-1, 1):
        rod("LadderRail", tuple(a + side * s * 0.5 + Vector((0, -0.25, 0))), tuple(b + side * s * 0.5 + Vector((0, -0.25, 0))),
            0.035, PLANK, verts=4)
    for k in range(1, 20):
        p = a + (b - a) * (k / 20) + Vector((0, -0.25, 0))
        beam("Rung", tuple(p - side * 0.5), tuple(p + side * 0.5), 0.04, mat("moss", -0.3) if k < 5 else PLANK)
    # The keeper's skiff tied to a back leg, half full of water: pale weathered boards and a bone
    # gunwale so it reads from the shore through the fog (Day 30), an oar left across it.
    sk = Vector((foot + 1.0, foot - 0.4, 0.8))
    box("Skiff", (0.95, 2.5, 0.34), tuple(sk), mat("driftwood", 0.05), 0.35)
    box("SkiffGunwale", (1.05, 2.6, 0.06), tuple(sk + Vector((0, 0, 0.32))), mat("bone", -0.1), 0.35)
    box("SkiffWater", (0.8, 2.2, 0.05), tuple(sk + Vector((0, 0, 0.2))), mat("slate", -0.2), 0.35)
    beam("SkiffOar", tuple(sk + Vector((-0.75, -0.3, 0.42))), tuple(sk + Vector((0.6, 0.35, 0.4))), 0.05, mat("bone", -0.1))
    rod("SkiffLine", tuple(sk + Vector((-0.3, 0.6, 0.35))), (foot, foot, 1.3), 0.015, mat("bone", -0.1), verts=3)
    bd.export("heron_light")


# --- The fen, dressed (Day 30) -----------------------------------------------------------

# The staithe and the boardwalk keep the dock's deck top (placed at y -0.4 → a 0.275 pier deck).
DECK_TOP = 0.675


def _whittled_gull(at: Vector, facing: float, wood) -> None:
    """A whittled gull sitting on a post top (~0.3 m long), beak toward `facing` (radians about Z
    from -Y): the gulls the big man paid his mooring in, one on every post."""
    fwd = Vector((math.sin(facing), -math.cos(facing), 0))
    side = Vector((-fwd.y, fwd.x, 0))
    body = at + Vector((0, 0, 0.07))
    beam("GullBody", tuple(body - fwd * 0.13), tuple(body + fwd * 0.1), 0.1, wood, width=0.1)
    beam("GullTail", tuple(body - fwd * 0.12 + Vector((0, 0, 0.01))), tuple(body - fwd * 0.22 + Vector((0, 0, 0.04))), 0.025, wood,
         width=0.07)
    for s in (-1, 1):  # folded wings along the back, tips crossing over the tail
        beam("GullWing", tuple(body + side * s * 0.045 + fwd * 0.06 + Vector((0, 0, 0.03))),
             tuple(body + side * s * 0.02 - fwd * 0.2 + Vector((0, 0, 0.05))), 0.02, wood, width=0.06)
    head = body + fwd * 0.12 + Vector((0, 0, 0.1))
    beam("GullNeck", tuple(body + fwd * 0.08), tuple(head), 0.06, wood)
    cyl("GullHead", 0.045, 0.04, 0.07, 5, tuple(head - Vector((0, 0, 0.03))), wood)
    beam("GullBeak", tuple(head + fwd * 0.03), tuple(head + fwd * 0.1 - Vector((0, 0, 0.015))), 0.018, mat("ember", -0.3))


def build_staithe() -> None:
    """Glasswater Staithe (2 × 6 m, the dock's footprint and deck top 0.675): silvered planks on
    stringers, every piling rising through the deck as a post with **a whittled gull** on it, a
    ladder down at the channel end (-Y, Godot +Z) where the Slow Mercy lies, a coil of line.
    No bollard: fen folk tie to the posts."""
    bd.reset()
    rng = random.Random(30)
    top, thick = DECK_TOP, 0.08
    for i in range(24):
        y = -2.875 + i * 0.25
        box(f"Plank{i}", (2.0 + rng.uniform(-0.08, 0.08), 0.22, thick), (rng.uniform(-0.04, 0.04), y, top - thick),
            mat("driftwood", rng.choice((-0.2, -0.3, -0.38))))
    for x in (-0.7, 0.7):
        box("Stringer", (0.12, 6.0, 0.14), (x, 0, top - thick - 0.14), mat("silverfog", -0.55))
    gull = mat("driftwood", 0.15)
    for k, y in enumerate((-2.8, -0.95, 0.95, 2.8)):
        for j, x in enumerate((-0.95, 0.95)):
            rise = 0.62 if y < -2.0 else 0.5
            cyl("Post", 0.12, 0.1, 1.4 + top + rise, 6, (x, y, -1.4), mat("silverfog", -0.5), rng.uniform(0, 1))
            # Every gull faces out to sea (down the channel, -Y), each carved a little askew (LORE).
            _whittled_gull(Vector((x, y, top + rise)), rng.uniform(-0.25, 0.25), gull)
    for y in (-1.9, 1.9):
        beam("Brace", (-0.95, y - 0.9, -0.2), (-0.95, y + 0.9, 0.4), 0.07, mat("silverfog", -0.6))
        beam("Brace", (0.95, y + 0.9, -0.2), (0.95, y - 0.9, 0.4), 0.07, mat("silverfog", -0.6))
    for i, z in enumerate((-0.9, -0.5, -0.1, 0.3)):
        beam(f"Rung{i}", (0.55, -3.08, z), (0.85, -3.08, z), 0.05, mat("moss", -0.35) if z < 0 else mat("driftwood", -0.3))
    for x in (0.55, 0.85):
        beam("LadderRail", (x, -3.08, -1.1), (x, -3.02, top + 0.35), 0.05, mat("driftwood", -0.3))
    cyl("RopeCoil", 0.24, 0.24, 0.1, 8, (-0.5, -1.6, top), mat("driftwood", 0.1))
    bd.export("staithe")


# Where the boardwalk's piles stand in the pool (Blender x, y): the region's `wading` rings.
BOARDWALK_PILES = [(sx * 0.88, y) for y in (-2.4, -0.8, 0.8, 2.4) for sx in (-1, 1)]


def build_boardwalk() -> None:
    """The fen's low boardwalk (2 × 6 m, the dock's footprint and deck top 0.675 like the dock it replaces): split
    planks laid crosswise on two runners, a hand above the water on stubby pile pairs, one
    plank gone and one sprung, slime-green where the water laps. No ladder, no bollards, no rail:
    fen folk walk it with a pole."""
    bd.reset()
    rng = random.Random(31)
    top, thick = DECK_TOP, 0.07
    for i in range(26):
        y = -2.9 + i * 0.232
        if i == 17:  # a plank gone: the gap shows the water
            continue
        tilt = 0.08 if i == 9 else 0.0
        box(f"Plank{i}", (1.92 + rng.uniform(-0.14, 0.06), 0.2, thick), (rng.uniform(-0.06, 0.06), y, top - thick + tilt),
            mat("driftwood", rng.choice((-0.25, -0.35, -0.42))), rng.uniform(-0.04, 0.04) + (0.06 if tilt else 0.0))
    for x in (-0.66, 0.66):
        box("Runner", (0.14, 6.0, 0.12), (x, 0, top - thick - 0.12), mat("silverfog", -0.55))
    for x, y in BOARDWALK_PILES:
        cyl("Pile", 0.09, 0.08, 1.2 + top - thick - 0.1, 5, (x, y, -1.2), mat("silverfog", -0.6), rng.uniform(0, 1))
        cyl("Slime", 0.095, 0.095, 0.12, 5, (x, y, 0.32), mat("moss", -0.35))
        beam("Cap", (x - 0.12, y, top - thick - 0.13), (x + 0.12, y, top - thick - 0.13), 0.07, mat("silverfog", -0.55))
    bd.export("boardwalk")


def build_plank_path() -> None:
    """Boards laid on the wet ground of the long walk (1 × 3 m along Y, ~7 cm high, no collider):
    two sunken runners and crosswise boards, some askew, some mossed over — someone laid them
    going in, and nobody mends them."""
    bd.reset()
    rng = random.Random(32)
    for x in (-0.35, 0.35):
        box("Runner", (0.1, 3.0, 0.03), (x, 0, 0.0), mat("silverfog", -0.6))
    for i in range(11):
        if i in (4, 8) and rng.random() < 0.9:
            continue
        y = -1.36 + i * 0.272
        box(f"Board{i}", (1.0 + rng.uniform(-0.15, 0.1), 0.2, 0.04), (rng.uniform(-0.08, 0.08), y, 0.03),
            mat("moss", -0.4) if i % 5 == 2 else mat("driftwood", rng.choice((-0.3, -0.42))), rng.uniform(-0.12, 0.12))
    bd.export("plank_path")


def build_punt() -> None:
    """Corran's eel-punt (4.2 × 0.95 m), moored: flat bottomed, square ended, the ends raked up out
    of the water, tarred black with pale thwarts; a quant pole and an eel-trap lying in her. Origin
    at the bottom's centre (place at the water level less ~0.15 with `float`)."""
    bd.reset()
    TAR, RIM, WOOD = mat("ink", 0.12), mat("coal", -0.55), mat("driftwood", -0.2)
    L, W, H = 3.2, 0.95, 0.32
    box("Bottom", (W, L, 0.06), (0, 0, 0), TAR)
    for s in (-1, 1):
        box("Side", (0.06, L + 0.6, H), (s * (W / 2 - 0.03), 0, 0.02), TAR)
        box("Rim", (0.09, L + 0.7, 0.05), (s * (W / 2 - 0.02), 0, H + 0.02), RIM)
        # The raked ends: a slab from the bottom's end up and out.
        beam("Rake", (0, s * L / 2, 0.03), (0, s * (L / 2 + 0.5), H + 0.02), 0.05, TAR, width=W)
        box("Transom", (W, 0.06, 0.12), (0, s * (L / 2 + 0.5), H - 0.08), RIM)
    for y in (-0.8, 0.9):
        box("Thwart", (W - 0.1, 0.24, 0.05), (0, y, H - 0.08), WOOD)
    rod("Quant", (-0.25, -2.1, H + 0.06), (0.2, 2.2, H + 0.1), 0.025, mat("driftwood", -0.05), verts=5)
    _eel_trap(Vector((0.1, 0.0, 0.12)), 0.3, 0.75)
    bd.export("punt")


def _eel_trap(base: Vector, yaw: float, scale: float = 1.0) -> None:
    """A wicker eel-trap lying on its side (~1.1 m): a long tapering basket, hoops round it, the
    funnel mouth at one end and the tail tied off at the other. `base` is the belly's lowest point."""
    WICKER, HOOP, TIE = mat("driftwood", -0.12), mat("driftwood", -0.45), mat("coal", -0.5)
    d = Vector((math.cos(yaw), math.sin(yaw), 0))
    r = 0.2 * scale
    c = base + Vector((0, 0, r))
    mouth, tail = c - d * 0.5 * scale, c + d * 0.6 * scale
    rod("Basket", tuple(mouth), tuple(tail), r, WICKER, verts=7, r_end=r * 0.3)
    rod("Funnel", tuple(mouth + d * 0.18 * scale), tuple(mouth - d * 0.02), r * 0.35, mat("driftwood", -0.32), verts=7,
        r_end=r * 1.02)
    for k in range(4):
        p = mouth + (tail - mouth) * (0.05 + k * 0.28)
        rr = r * (1.0 - 0.7 * (0.05 + k * 0.28)) + 0.012
        rod("Hoop", tuple(p - d * 0.02), tuple(p + d * 0.02), rr, HOOP, verts=7)
    rod("Tie", tuple(tail), tuple(tail + d * 0.08 * scale), r * 0.32, TIE, verts=5, r_end=0.01)


def build_eel_traps() -> None:
    """Corran's eel-traps on the landing (~1.7 × 1.4 m): two lying in the grass and one stood on
    end against a stake to dry, a coil of line on the stake."""
    bd.reset()
    _eel_trap(Vector((-0.2, -0.35, 0)), 0.15)
    _eel_trap(Vector((0.15, 0.25, 0)), -0.35, 0.9)
    rod("Stake", (0.75, 0.0, 0), (0.75, 0.0, 1.3), 0.04, mat("silverfog", -0.55), verts=5, r_end=0.025)
    stood = Vector((0.6, -0.05, 0))
    rod("Basket", tuple(stood), tuple(stood + Vector((0.08, 0.02, 0.95))), 0.17, mat("driftwood", -0.12), verts=7, r_end=0.06)
    for z in (0.15, 0.45, 0.75):
        rod("Hoop", tuple(stood + Vector((0.08 * z, 0.02 * z, z - 0.02))), tuple(stood + Vector((0.08 * z, 0.02 * z, z + 0.02))),
            0.17 * (1.0 - 0.6 * z) + 0.012, mat("driftwood", -0.45), verts=7)
    cyl("LineCoil", 0.11, 0.11, 0.07, 7, (0.75, -0.06, 0.95), mat("slate", -0.35))
    bd.export("eel_traps")


def build_alder_snag() -> None:
    """A dead alder (~4 m): the fen's trees die standing, roots in the water. A crooked dark trunk
    from a flared root boss, forking into three leaning limbs with stub branches gone silver at
    the ends, a shelf of bracket fungus, one last dry catkin cluster. Same trunk footprint as the
    pine snag it replaces (collider ~0.5 m)."""
    bd.reset()
    rng = random.Random(33)
    BARK, TIP, FUNGUS = mat("slate", -0.5), mat("silverfog", -0.45), mat("driftwood", 0.1)
    for k in range(5):  # root boss: buttresses splaying into the mud
        a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
        rod("Root", (0, 0, 0.45), (math.cos(a) * 0.55, math.sin(a) * 0.55, -0.05), 0.12, BARK, verts=4, r_end=0.04)
    pts = [Vector((0, 0, 0))]
    for z in (0.7, 1.4, 1.9):  # a crooked trunk
        pts.append(Vector((rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15), z)))
    for i in range(len(pts) - 1):
        rod("Trunk", tuple(pts[i]), tuple(pts[i + 1]), 0.21 - i * 0.03, BARK, verts=6, r_end=0.18 - i * 0.03)
    fork = pts[-1]
    for k in range(3):
        a = k / 3 * math.tau + 0.4
        lean = rng.uniform(0.5, 0.9)
        mid = fork + Vector((math.cos(a) * lean * 0.6, math.sin(a) * lean * 0.6, 0.9))
        end = mid + Vector((math.cos(a) * lean * 0.5, math.sin(a) * lean * 0.5, rng.uniform(0.6, 1.1)))
        rod("Limb", tuple(fork), tuple(mid), 0.11, BARK, verts=5, r_end=0.07)
        rod("LimbTip", tuple(mid), tuple(end), 0.07, TIP, verts=4, r_end=0.015)
        for j in range(2):  # stub branches
            p = fork + (mid - fork) * (0.5 + j * 0.45)
            b = a + rng.choice((-1, 1)) * rng.uniform(0.6, 1.2)
            rod("Stub", tuple(p), tuple(p + Vector((math.cos(b) * 0.45, math.sin(b) * 0.45, 0.25))), 0.03, TIP, verts=3, r_end=0.008)
    for k, z in enumerate((0.9, 1.1, 1.25)):  # bracket fungus on the north side
        cyl("Fungus", 0.16 - k * 0.03, 0.12 - k * 0.03, 0.05, 6, (0.0, 0.17 + k * 0.01, z), FUNGUS)
    last = fork + Vector((-0.5, 0.3, 1.2))
    for k in range(3):
        rod("Catkin", tuple(last), tuple(last + Vector((0.03 * k - 0.03, 0.02, -0.14))), 0.022, mat("coal", -0.55), verts=4, r_end=0.01)
    bd.export("alder_snag")


def build_reed_bed() -> None:
    """A reed bed along a pool's edge (~3.2 × 1.2 m along X, to 1.9 m): dense common reed with
    feathery buff plumes, a few bent and broken, and bulrushes in front. No collider."""
    bd.reset()
    rng = random.Random(34)
    STEMS = (mat("moss", -0.15), mat("driftwood", -0.2), mat("pine", 0.05))
    PLUME = mat("driftwood", -0.28)
    for i in range(46):
        base = Vector((rng.uniform(-1.6, 1.6), rng.uniform(-0.45, 0.6), 0))
        h = rng.uniform(1.2, 1.9) * (1.0 - 0.25 * abs(base.x) / 1.6)
        lean = Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.1, 0.25), 0))
        if i % 9 == 0:  # broken and bent over
            knee = base + Vector((0, 0, h * 0.5))
            rod("Reed", tuple(base), tuple(knee), 0.022, STEMS[i % 3], verts=3)
            rod("Reed", tuple(knee), tuple(knee + Vector((0.5, -0.2, -0.25))), 0.018, STEMS[1], verts=3, r_end=0.0)
            continue
        tip = base + lean + Vector((0, 0, h))
        rod("Reed", tuple(base), tuple(tip), 0.022, STEMS[i % 3], verts=3, r_end=0.006)
        if i % 3 == 0:  # a plume drooping off the top
            rod("Plume", tuple(tip - Vector((0, 0, 0.02))), tuple(tip + lean.normalized() * 0.1 - Vector((0, 0, 0.22))), 0.03,
                PLUME, verts=3, r_end=0.0)
        if i % 4 == 1:  # a leaf
            p = base + (tip - base) * 0.4
            rod("Leaf", tuple(p), tuple(p + Vector((rng.uniform(-0.35, 0.35), -0.25, 0.2))), 0.03, STEMS[0], verts=3, r_end=0.0)
    for k in range(5):  # bulrushes in front
        base = Vector((-1.2 + k * 0.6 + rng.uniform(-0.1, 0.1), -0.6, 0))
        tip = base + Vector((0, 0, rng.uniform(0.9, 1.2)))
        rod("Bulrush", tuple(base), tuple(tip), 0.02, STEMS[0], verts=3)
        rod("BulrushHead", tuple(tip - Vector((0, 0, 0.26))), tuple(tip - Vector((0, 0, 0.06))), 0.04, mat("coal", -0.5), verts=5)
    bd.export("reed_bed")


BUILDERS = [build_reed_house, build_letting_post, build_heron_light, build_staithe, build_boardwalk, build_plank_path,
            build_punt, build_eel_traps, build_alder_snag, build_reed_bed]
ALIASES = {"letting_post_word": "letting_post"}

if __name__ == "__main__":
    only = {ALIASES.get(a, a) for a in sys.argv[1:] if not a.startswith("-")}
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
