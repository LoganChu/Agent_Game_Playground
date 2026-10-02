"""Builds Thornwold's set dressing (Act II, Day 17) into the dressing kit.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_thornwold.py
    .tools/bin/blender-py tools/blender/build_thornwold.py [bramble log_pile stump charcoal_sacks]

Outputs assets/models/dressing/<name>.glb with the dressing kit's conventions (origin at the
base centre, flat-shaded, palette colours and tonal shades, Blender -Y = Godot +Z = the
front, merged by material).
"""
import math
import os
import random
import sys

import bpy  # must be imported before mathutils when running as the bpy module
from mathutils import Vector  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dressing as bd  # noqa: E402  (materials, primitives, merge + export)

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod


def build_bramble() -> None:
    """A 3 m section of the bramble wall that grew across Thornwold's cart road in one night:
    a dense, man-high tangle of arching canes (dark pine-green to coal-brown) with long pale
    thorns, a few last leaves and coal-red hips. Along X; ~1.2 m deep, ~1.9 m tall."""
    bd.reset()
    rng = random.Random(17)
    canes = (mat("pine", -0.45), mat("pine", -0.25), mat("coal", -0.55))
    thorn = mat("bone", -0.15)
    leaf = mat("moss", -0.2)
    hip = mat("coal", 0.05)
    for i in range(30):
        x0 = rng.uniform(-1.5, 1.5)
        y0 = rng.uniform(-0.45, 0.45)
        rise = rng.uniform(1.1, 1.9)
        reach = rng.uniform(-1.2, 1.2)
        lean = rng.uniform(-0.4, 0.4)
        material = canes[i % 3]
        # An arching cane in four segments: up from the root, over, and down.
        points = []
        for k in range(5):
            t = k / 4
            points.append(Vector((x0 + reach * t, y0 + lean * t, rise * math.sin(math.pi * (0.1 + 0.8 * t)))))
        for k in range(4):
            rod(f"Cane{i}", points[k], points[k + 1], 0.045 - k * 0.006, material, verts=4)
            if rng.random() < 0.8:
                mid = (points[k] + points[k + 1]) * 0.5
                out = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 0.8))).normalized()
                rod("Thorn", mid, mid + out * rng.uniform(0.09, 0.15), 0.02, thorn, verts=3, r_end=0.0)
        if i % 4 == 0:
            tip = points[2] + Vector((0, 0, 0.04))
            box("Leaf", (0.16, 0.1, 0.03), tip, leaf, rng.uniform(0, math.pi))
        if i % 5 == 1:
            bd.cyl("Hip", 0.045, 0.03, 0.08, 5, points[3], hip)
    # A dark, lumpy thicket inside the canes so the wall can't be seen through.
    for i in range(7):
        x = -1.35 + i * 0.45 + rng.uniform(-0.1, 0.1)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0)
        lump = bpy.context.active_object
        lump.name = "Thicket"
        lump.scale = (rng.uniform(0.38, 0.5), rng.uniform(0.32, 0.42), rng.uniform(0.55, 0.85))
        lump.location = (x, rng.uniform(-0.12, 0.12), lump.scale[2] * 0.75)
        lump.rotation_euler = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, math.pi))
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bd.bp.finish(lump, (mat("pine", -0.55), mat("pine", -0.4))[i % 2])
    bd.export("bramble")


def build_log_pile() -> None:
    """The lumber camp's stack of trimmed pine logs (3.2 m along X) chocked by posts: a
    pyramid of 3/2/1 logs, cut ends pale with rings, bark dark."""
    bd.reset()
    bark = mat("pine", -0.5)
    bark2 = mat("driftwood", -0.55)
    cut = mat("driftwood", 0.2)
    rings = mat("ember", -0.35)
    r = 0.22
    rows = ((-2 * r - 0.02, 0.0, 2 * r + 0.02), (-r - 0.01, r + 0.01), (0.0,))
    for row, ys in enumerate(rows):
        z = r + row * r * 1.72
        for j, y in enumerate(ys):
            material = bark if (row + j) % 2 else bark2
            rod("Log", (-1.6, y, z), (1.6, y, z), r, material, verts=7)
            for end in (-1.61, 1.61):
                rod("Cut", (end, y, z), (end + (0.02 if end > 0 else -0.02), y, z), r * 0.88, cut, verts=7)
                rod("Ring", (end + (0.025 if end > 0 else -0.025), y, z),
                    (end + (0.03 if end > 0 else -0.03), y, z), r * 0.45, rings, verts=6)
    for x in (-1.2, 1.2):
        for y in (-0.75, 0.75):
            rod("Chock", (x, y, 0.0), (x, y * 0.92, 0.7), 0.05, mat("driftwood", -0.25), verts=4)
    bd.export("log_pile")


def build_stump() -> None:
    """A wide chopping stump (0.55 m) with an axe bitten into it and a scatter of split
    billets and chips — the camp's woodpile corner."""
    bd.reset()
    rng = random.Random(5)
    cyl("Stump", 0.36, 0.32, 0.55, 8, (0, 0, 0), mat("pine", -0.45))
    cyl("Top", 0.31, 0.31, 0.03, 8, (0, 0, 0.55), mat("driftwood", 0.15))
    # The axe: haft angled up and back, head bitten into the top.
    head = Vector((0.05, 0.0, 0.6))
    rod("Haft", head, head + Vector((0.45, 0.25, 0.42)), 0.03, mat("driftwood", -0.05), verts=5)
    box("AxeHead", (0.08, 0.2, 0.12), head + Vector((0, 0, -0.06)), mat("slate", -0.35), 0.5)
    for i in range(5):
        a = rng.uniform(0, math.tau)
        p = Vector((math.cos(a) * rng.uniform(0.55, 0.85), math.sin(a) * rng.uniform(0.55, 0.85), 0.06))
        q = p + Vector((math.cos(a + 1.2) * 0.45, math.sin(a + 1.2) * 0.45, 0.02))
        beam("Billet", p, q, 0.1, mat("driftwood", 0.05 if i % 2 else -0.15), width=0.12)
    for i in range(8):
        a = rng.uniform(0, math.tau)
        box("Chip", (0.08, 0.05, 0.015), (math.cos(a) * 0.5, math.sin(a) * 0.5, 0), mat("driftwood", 0.2), a)
    bd.export("stump")


def build_charcoal_sacks() -> None:
    """Sacks of charcoal from the burners' clamps, waiting on the jetty for the ferry: three
    lumpy sailcloth sacks (one slumped open, black lumps showing) on a pallet."""
    bd.reset()
    sack = mat("driftwood", -0.2)
    coal = mat("ink", 0.05)
    box("Pallet", (1.3, 0.9, 0.12), (0, 0, 0), mat("driftwood", -0.4))
    for i, (x, y, tilt) in enumerate(((-0.35, -0.1, 0.1), (0.3, 0.12, -0.15), (0.0, 0.2, 0.0))):
        z = 0.12 if i < 2 else 0.5
        body = bd.cyl("Sack", 0.27, 0.22, 0.55 if i < 2 else 0.35, 7, (x, y, z), sack, tilt)
        body.rotation_euler.x = tilt * 0.5
        if i < 2:
            cyl("Neck", 0.1, 0.08, 0.12, 5, (x, y, z + 0.55), mat("coal", -0.45))
        else:
            for k in range(4):
                bd.box("Lump", (0.1, 0.09, 0.07), (x + (k - 1.5) * 0.08, y - 0.1, z + 0.33), coal, k)
    bd.export("charcoal_sacks")


BUILDERS = [build_bramble, build_log_pile, build_stump, build_charcoal_sacks]

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
