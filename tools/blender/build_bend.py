"""Builds the kit for Coll's Hearth (Day 57) into the dressing kit: the bend in Thornwold's old cart road
where Wenna Coll's hearth stood before the road started lying — her clamp, burned right through while
nobody tended it (`clamp_spent`), and a Keeper's lantern hung on a forked stake by a hut door
(`hut_lantern`: Wenna's, if she keeps her light at her own door; Hob's, from the Lamp's coal, in the
colliers' clearing).

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_bend.py
    .tools/bin/blender-py tools/blender/build_bend.py [clamp_spent hut_lantern]

Same conventions as build_dressing/build_woods: origin at the base centre, flat-shaded,
palette colours and tonal shades, Blender -Y = Godot +Z = the front, merged by material.
"""
import math
import os
import random
import sys

import bpy  # noqa: F401  (must be imported before mathutils when running as the bpy module)
import bmesh  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_dressing as bd  # noqa: E402  (materials, primitives, merge + export)
import build_woods as bw  # noqa: E402  (rough lumps, sacks)

mat, box, cyl, beam, rod = bd.mat, bd.box, bd.cyl, bd.beam, bd.rod


def build_clamp_spent() -> None:
    """A charcoal clamp that burned itself through with nobody to tend it (3.2 m across, ~0.55 m high):
    the dome sunk to a low grey hump, the turf slipped and dried silver, the vents cold and open, one
    side broken in where it fell (the finished charcoal showing black inside), the stake ring
    leaning and two stakes down. No smoke, no glow."""
    bd.reset()
    rng = random.Random(570)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
    dome = bpy.context.active_object
    dome.name = "Mound"
    dome.scale = (1.6, 1.6, 0.55)
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    for v in bm.verts:
        v.co.z = max(v.co.z, 0.0)
        if v.co.z > 0.0:
            v.co.x *= 1.0 + rng.uniform(-0.08, 0.08)
            v.co.y *= 1.0 + rng.uniform(-0.08, 0.08)
            v.co.z *= 1.0 + rng.uniform(-0.2, 0.05)
            if v.co.y < -0.5 and v.co.x > -0.6:  # the front fell in
                v.co.z *= 0.45
    bm.to_mesh(dome.data)
    bm.free()
    bd.bp.finish(dome, mat("silverfog", -0.55))
    for i in range(12):  # turf slipped down the sides, dried silver
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.6, 1.5)
        h = 0.55 * math.sqrt(max(0.0, 1 - (d / 1.6) ** 2))
        box("Turf", (0.38, 0.28, 0.05), (math.cos(a) * d, math.sin(a) * d, max(0.0, h - 0.06)),
            mat("silverfog", (-0.35, -0.45)[i % 2]), a + rng.uniform(-0.4, 0.4))
    for k in range(4):  # the vents, cold and open
        a = k * math.pi / 2 + 0.4
        cyl("Vent", 0.1, 0.12, 0.06, 6, (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.38), mat("ink", -0.1))
    for i in range(14):  # the broken side: finished charcoal showing black inside
        box("Charcoal", (0.16, 0.11, 0.09), (rng.uniform(-0.3, 0.6), rng.uniform(-1.25, -0.7), rng.uniform(0.02, 0.22)),
            mat("ink", (0.05, -0.05)[i % 2]), rng.uniform(0, math.pi))
    for i in range(10):  # the stake ring, leaning; two down in the moss
        a = i / 10 * math.tau
        x, y = math.cos(a) * 1.9, math.sin(a) * 1.9
        if i in (2, 7):
            rod("Stake", (x, y, 0.03), (x + math.cos(a + 1.4) * 0.5, y + math.sin(a + 1.4) * 0.5, 0.05),
                0.03, mat("driftwood", -0.5), verts=4)
        else:
            lean = rng.uniform(0.05, 0.18)
            rod("Stake", (x, y, 0), (x * (1 + lean), y * (1 + lean), 0.5), 0.035, mat("driftwood", -0.5), verts=4, r_end=0.02)
    bw._sack((2.2, 0.4, 0.0), rng, lying=True, shade=-0.5)  # an empty sack, rotted grey
    bd.export("clamp_spent")


def build_hut_lantern() -> None:
    """A Keeper's lantern on a forked stake by a hut door (~1.7 m): a peeled pole driven in, a crook cut at
    its top holding a short iron hook out to the front, and the lantern hung from it — gold behind
    horn, a coal off the Lamp's kept one inside. Glass centre at Blender (0, -0.32, 1.28) = Godot
    [0, 1.28, 0.32], where the region puts its halo."""
    bd.reset()
    rng = random.Random(571)
    wood = mat("driftwood", -0.1)
    rod("Pole", (0, 0, 0), (0.02, 0.0, 1.72), 0.045, wood, verts=5, r_end=0.035)
    rod("Crook", (0.02, 0.0, 1.62), (0.0, -0.18, 1.8), 0.03, wood, verts=4)
    iron = mat("ink", 0.15)
    beam("Arm", (0.02, 0.02, 1.65), (0.0, -0.36, 1.65), 0.025, iron)
    beam("Hook", (0.0, -0.32, 1.66), (0.0, -0.32, 1.56), 0.016, iron)
    top = 1.56
    beam("Bail", (0, -0.32, top), (0, -0.32, top - 0.06), 0.015, iron)
    cyl("Cap", 0.13, 0.02, 0.11, 6, (0, -0.32, top - 0.15), iron)
    cyl("Glass", 0.09, 0.09, 0.22, 6, (0, -0.32, top - 0.39), mat("kindle", 0.0, emissive=True))
    cyl("Base", 0.11, 0.11, 0.04, 6, (0, -0.32, top - 0.42), iron)
    for i in range(3):
        a = math.tau * i / 3
        beam("Frame", (math.cos(a) * 0.1, -0.32 + math.sin(a) * 0.1, top - 0.4),
             (math.cos(a) * 0.1, -0.32 + math.sin(a) * 0.1, top - 0.14), 0.018, iron)
    for k in range(3):  # stones packed round the foot of the pole
        a = k / 3 * math.tau + 0.4
        bw._lump("Stone", (0.12, 0.1, 0.07), (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.04), mat("slate", -0.2), rng, 0.2)
    bd.export("hut_lantern")


BUILDERS = [build_clamp_spent, build_hut_lantern]

if __name__ == "__main__":
    only = {a for a in sys.argv[1:] if not a.startswith("-")}
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
