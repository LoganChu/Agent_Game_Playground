"""Builds Glasswater Fen's first kit (Day 29) into the dressing kit: the Unmoored's **reed
houses** on Stillhithe (fen-folk houses of bundled reed on low stilts, left empty when the fen
folk went to the lanes), the **letting post** on its islet (where the Unmoored hang what they
leave for the ones further in) with a variant carrying the Wakebearer's word tied on, and the
fen's beacon, **the Heron Light** — a Keeper-built lantern room on four tall legs out in the
mere, cold, an iron heron for a vane.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_fen.py
    .tools/bin/blender-py tools/blender/build_fen.py [reed_house letting_post heron_light]

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
    # The keeper's skiff tied to a back leg, half sunk (the water hides the rest).
    sk = Vector((foot + 0.9, foot - 0.4, 0.75))
    box("Skiff", (0.8, 2.2, 0.3), tuple(sk), mat("abyss", -0.35), 0.35)
    box("SkiffWater", (0.66, 1.9, 0.05), tuple(sk + Vector((0, 0, 0.18))), mat("slate", -0.2), 0.35)
    rod("SkiffLine", tuple(sk + Vector((-0.3, 0.6, 0.3))), (foot, foot, 1.3), 0.012, mat("driftwood", -0.4), verts=3)
    bd.export("heron_light")


BUILDERS = [build_reed_house, build_letting_post, build_heron_light]
ALIASES = {"letting_post_word": "letting_post"}

if __name__ == "__main__":
    only = {ALIASES.get(a, a) for a in sys.argv[1:] if not a.startswith("-")}
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
