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
import bmesh  # noqa: E402
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


# --- The camp's own buildings and the woods (Day 18) -----------------------------------------

def _log_course(name, a, b, y, z, r, material, gaps=(), along_x=True) -> None:
    """One round log from a to b (along X at y, or along Y at x=y when not along_x), split
    around `gaps` [(g0, g1)] where a door or window cuts through this course."""
    cuts = sorted(g for g in gaps if g[0] < b and g[1] > a)
    start = a
    for g0, g1 in cuts + [(b, b)]:
        if g0 - start > 0.12:
            p0 = (start, y, z) if along_x else (y, start, z)
            p1 = (g0, y, z) if along_x else (y, g0, z)
            rod(name, p0, p1, r, material, verts=7)
        start = max(start, g1)


def _log_walls(width: float, depth: float, height: float, rng, r: float = 0.13, overhang: float = 0.2,
               openings=()) -> float:
    """Saddle-notched round-log walls round a width × depth floor (front at -Y): the front and
    back courses sit half a log below the side courses, so the corners interlock and every log
    end sticks out `overhang` past the corner. A dark chinking box fills behind the logs.
    `openings` are (face, centre, w, z0, z1) holes ("-y"/"+y" along X, "-x"/"+x" along Y)
    where logs are cut short for a door or window. Returns the top of the walls."""
    shades = (mat("driftwood", -0.32), mat("driftwood", -0.45), mat("pine", -0.25))
    rise = r * 1.8
    courses = max(2, int(height / rise))
    hw, hd = width / 2, depth / 2
    box("Chinking", (width - r, depth - r, courses * rise), (0, 0, 0), mat("bone", -0.4))
    for i in range(courses):
        for face, along_x, pos, span, offset in (("-y", True, -hd, hw, 0.0), ("+y", True, hd, hw, 0.0),
                                                 ("-x", False, -hw, hd, 0.5), ("+x", False, hw, hd, 0.5)):
            z = r + (i + offset) * rise
            if z > courses * rise:
                continue
            gaps = [(c - w / 2, c + w / 2) for f, c, w, z0, z1 in openings if f == face and z0 - r < z < z1 + r * 0.5]
            ends = span + overhang + rng.uniform(-0.05, 0.05)
            _log_course("Log", -ends, ends, pos, z, r * rng.uniform(0.92, 1.05), shades[(i + len(face) + int(along_x)) % 3],
                        gaps, along_x)
    for x in (-hw, hw):  # pale cut ends where the logs cross
        for y in (-hd, hd):
            for i in range(courses):
                for along_x, z in ((True, r + i * rise), (False, r + (i + 0.5) * rise)):
                    if z > courses * rise:
                        continue
                    sx = (1 if x > 0 else -1)
                    sy = (1 if y > 0 else -1)
                    if along_x:
                        e = (x + sx * (overhang + 0.01), y, z)
                        rod("CutEnd", e, (e[0] + sx * 0.02, y, z), r * 0.8, mat("driftwood", -0.1), verts=7)
                    else:
                        e = (x, y + sy * (overhang + 0.01), z)
                        rod("CutEnd", e, (x, e[1] + sy * 0.02, z), r * 0.8, mat("driftwood", -0.1), verts=7)
    return courses * rise + r


def _bark_roof(length: float, span: float, pitch_h: float, z: float, overhang: float, rng,
               slab: float = 0.42) -> None:
    """A gable roof of overlapping bark slabs, ridge along X at z + pitch_h, eaves at
    ±(span/2 + overhang); a ridge pole and a dark underside prism that also closes the
    gables. Slabs alternate pine-dark and coal-dark so the roof reads as rough bark."""
    under = bd.bp.prism("RoofFill", span, length, pitch_h, (0, 0, z), mat("driftwood", -0.45))
    under.rotation_euler.z = math.pi / 2
    n = int((length + 2 * overhang) / slab) + 1
    eave_drop = pitch_h * overhang / (span / 2)
    for side in (-1, 1):
        for i in range(n):
            x = -length / 2 - overhang + slab * (i + 0.5)
            m = (mat("pine", -0.45), mat("slate", -0.4), mat("pine", -0.3))[(i + (side > 0)) % 3]
            p0 = (x, side * (span / 2 + overhang), z - eave_drop + rng.uniform(-0.02, 0.02))
            p1 = (x, 0.0, z + pitch_h + 0.05)
            beam("Slab", p0, p1, 0.06 + rng.uniform(0, 0.02), m, width=slab + 0.04)
    rod("RidgePole", (-length / 2 - overhang - 0.1, 0, z + pitch_h + 0.1),
        (length / 2 + overhang + 0.1, 0, z + pitch_h + 0.1), 0.1, mat("driftwood", -0.45), verts=6)


def _stove_pipe(x: float, y: float, z0: float, z1: float) -> None:
    rod("StovePipe", (x, y, z0), (x, y, z1), 0.09, mat("slate", -0.4), verts=6)
    cyl("PipeCap", 0.2, 0.05, 0.16, 6, (x, y, z1 + 0.08), mat("slate", -0.4))
    rod("PipeCollar", (x, y, z1 - 0.3), (x, y, z1 - 0.24), 0.12, mat("slate", -0.2), verts=6)


def build_bunkhouse() -> None:
    """The Tidewright lumber camp's bunkhouse: a long saddle-notched log cabin (4.4 × 3.0 m
    floor, walls ~2 m, bark-slab gable roof peaking at ~3.2 m) on a footing of flat stones;
    a plank door and two lit windows on the front (-Y), a tin stove pipe through the roof at
    the back (Godot: smoke from a prop `smoke` field at (1.3, 3.75, -0.6) model space —
    Blender y 0.6 is Godot z -0.6), an axe and a bucksaw hung on the front wall, a chopping
    block and a woodpile under the eaves at the +X end."""
    bd.reset()
    rng = random.Random(181)
    for i in range(12):  # footing stones round the base
        t = i / 12 * math.tau
        x, y = math.cos(t) * 2.3, math.sin(t) * 1.6
        bd.bp.rock("Footing", 0.22, (max(-2.3, min(2.3, x)), max(-1.6, min(1.6, y)), 0.03), mat("slate", -0.4), rng)
    openings = [("-y", -0.4, 0.8, 0.0, 1.55), ("-y", 1.3, 0.62, 0.75, 1.3), ("-y", -1.55, 0.62, 0.75, 1.3),
                ("+x", 0.0, 0.6, 0.75, 1.3)]
    top = _log_walls(4.4, 3.0, 1.95, rng, openings=openings)
    _bark_roof(4.4, 3.0, 1.1, top, 0.35, rng)
    _stove_pipe(1.3, 0.6, top + 0.5, 3.75)
    trim = mat("driftwood", -0.45)
    box("Door", (0.74, 0.06, 1.5), (-0.4, -1.42, 0.02), mat("driftwood", -0.45))
    for z in (0.35, 1.2):
        box("DoorBrace", (0.78, 0.05, 0.1), (-0.4, -1.47, z), mat("ink", 0.15))
    box("Lintel", (1.0, 0.18, 0.16), (-0.4, -1.5, 1.55), trim)
    box("DoorStone", (1.0, 0.5, 0.08), (-0.4, -1.85, 0), mat("slate", -0.2))
    for wx in (1.3, -1.55):
        box("Window", (0.5, 0.05, 0.42), (wx, -1.4, 0.82), mat("kindle", 0.0, emissive=True))
        box("Mullion", (0.04, 0.06, 0.44), (wx, -1.43, 0.81), trim)
        box("Sill", (0.66, 0.16, 0.05), (wx, -1.5, 0.76), trim)
        box("Shutter", (0.3, 0.04, 0.5), (wx - 0.47, -1.5, 0.79), mat("pine", -0.25))
    box("SideWindow", (0.05, 0.48, 0.42), (2.2, 0, 0.82), mat("kindle", 0.0, emissive=True))
    # Tools hung on the front wall right of the door: an axe and a bucksaw.
    rod("AxeHaft", (0.3, -1.6, 0.6), (0.42, -1.6, 1.4), 0.025, mat("driftwood", -0.1), verts=4)
    box("AxeHead", (0.2, 0.05, 0.1), (0.46, -1.6, 1.34), mat("slate", -0.2), 0.0)
    beam("SawFrame", (0.7, -1.6, 1.0), (0.7, -1.6, 1.5), 0.04, mat("driftwood", -0.1))
    beam("SawBlade", (0.62, -1.62, 1.0), (1.02, -1.62, 1.0), 0.02, mat("slate", -0.2), width=0.06)
    beam("SawTop", (0.7, -1.6, 1.5), (1.02, -1.6, 1.02), 0.03, mat("driftwood", -0.1))
    # Woodpile of split billets under the eaves at the +X end.
    for row in range(4):
        for k in range(5 - (row // 2)):
            y = -0.9 + k * 0.3 + (row % 2) * 0.15
            beam("Billet", (2.45, y, 0.08 + row * 0.15), (2.85, y, 0.08 + row * 0.15), 0.13,
                 mat("driftwood", (-0.1, -0.32)[(row + k) % 2]), width=0.13)
    bd.export("bunkhouse")


def build_tally_house() -> None:
    """The camp's tally-house and store: a small log hut (2.8 × 2.4 m, walls ~1.7 m) with a
    bark lean-to porch on two posts over the front (-Y), a lit window, and the **tally board**
    by the door — a plank with rows of notched tally sticks on pegs (Bram's count of what
    goes out on the ferry; one row stops short). A barrel of pegs, a lantern hook."""
    bd.reset()
    rng = random.Random(77)
    for x in (-1.4, 1.4):
        for y in (-1.2, 1.2):
            bd.bp.rock("Footing", 0.2, (x, y, 0.03), mat("slate", -0.2), rng)
    openings = [("-y", 0.45, 0.72, 0.0, 1.4), ("-y", -0.75, 0.55, 0.7, 1.2)]
    top = _log_walls(2.8, 2.4, 1.7, rng, r=0.12, openings=openings)
    _bark_roof(2.8, 2.4, 0.95, top, 0.3, rng)
    _stove_pipe(-0.8, 0.5, top + 0.4, top + 1.45)
    trim = mat("driftwood", -0.45)
    box("Door", (0.66, 0.06, 1.36), (0.45, -1.12, 0.02), mat("driftwood", -0.45))
    box("DoorBrace", (0.7, 0.05, 0.08), (0.45, -1.16, 0.7), mat("ink", 0.15))
    box("Window", (0.44, 0.05, 0.4), (-0.75, -1.1, 0.75), mat("kindle", 0.0, emissive=True))
    box("Sill", (0.6, 0.16, 0.05), (-0.75, -1.2, 0.7), trim)
    # Lean-to porch: two posts, a beam and a single slope of slabs from the wall top.
    for x in (-1.3, 1.3):
        rod("PorchPost", (x, -2.15, 0), (x, -2.15, 1.75), 0.07, mat("pine", -0.45), verts=5)
    rod("PorchBeam", (-1.55, -2.15, 1.8), (1.55, -2.15, 1.8), 0.08, mat("pine", -0.45), verts=6)
    for i in range(8):
        x = -1.5 + i * 0.43
        beam("PorchSlab", (x, -2.45, 1.72), (x, -1.15, top - 0.05), 0.05, (mat("pine", -0.45), mat("slate", -0.4))[i % 2],
             width=0.45)
    box("PorchFloor", (2.8, 1.0, 0.08), (0, -1.7, 0), mat("driftwood", -0.45))
    # The tally board: a plank on the wall by the door, four rows of notched sticks on pegs.
    box("TallyBoard", (0.9, 0.05, 0.8), (1.15, -1.18, 0.5), mat("driftwood", -0.1))
    for row in range(4):
        count = (7, 6, 7, 3)[row]
        for k in range(count):
            x = 0.78 + k * 0.105
            z = 0.62 + row * 0.18
            box("TallyStick", (0.035, 0.03, 0.15), (x, -1.22, z - 0.07), mat("bone", -0.4 if k % 2 else -0.1))
            box("Notch", (0.04, 0.035, 0.012), (x, -1.235, z - 0.02), mat("ink", 0.2))
        box("Peg", (0.82, 0.04, 0.025), (1.15, -1.22, 0.62 + row * 0.18 + 0.08), trim)
    cyl("PegBarrel", 0.24, 0.22, 0.6, 7, (-1.05, -1.75, 0.08), mat("driftwood", -0.32))
    cyl("BarrelHoop", 0.25, 0.25, 0.05, 7, (-1.05, -1.75, 0.5), mat("slate", -0.4))
    beam("LanternHook", (-0.05, -1.2, 1.5), (-0.05, -1.5, 1.5), 0.04, mat("ink", 0.2))
    bd.export("tally_house")


def build_log_bench() -> None:
    """A split-log bench (1.3 m along X, seat top 0.44 m — a seated character's seat height,
    see build_characters.Body): a half log laid flat face up on two stub legs, bark on the
    underside, the flat top worn pale in the middle where people sit. Front is -Y (Godot +Z)."""
    bd.reset()
    rng = random.Random(21)
    bark, wood = mat("pine", -0.45), mat("driftwood", -0.2)
    for x in (-0.48, 0.48):
        cyl("Leg", 0.13, 0.12, 0.3, 6, (x, 0.04, 0), bark, rng.uniform(0, 1))
    # The half log: a 6-sided log cut along its axis, flat face up at 0.44.
    mesh = bpy.data.meshes.new("Seat")
    bm = bmesh.new()
    r, half = 0.17, 0.65
    ring = [(math.cos(a) * r, math.sin(a) * r) for a in (0.0, -math.pi / 3, -2 * math.pi / 3, -math.pi)]
    ends = []
    for x in (-half, half):
        ends.append([bm.verts.new((x, 0.04 + y, 0.44 + z)) for y, z in ring])
    bm.faces.new(ends[0][::-1])
    bm.faces.new(ends[1])
    for k in range(len(ring) - 1):
        bm.faces.new((ends[0][k], ends[0][k + 1], ends[1][k + 1], ends[1][k]))
    bm.faces.new((ends[0][-1], ends[0][0], ends[1][0], ends[1][-1]))  # the flat top
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    seat = bpy.data.objects.new("Seat", mesh)
    bpy.context.collection.objects.link(seat)
    seat.data.materials.append(bark)
    box("Worn", (0.5, 0.3, 0.01), (0.0, 0.04, 0.44), wood)
    for x in (-0.6, 0.6):
        box("EndGrain", (0.012, 0.3, 0.1), (x, 0.04, 0.34), mat("driftwood", -0.05))
    bd.export("log_bench")


def build_saw_pit() -> None:
    """The saw trestle where logs become planks: two X-legged trestles carrying a pine log
    (3 m along X), its +X end already sawn into planks that lie stacked beside it, a long
    two-handled pit saw resting in the kerf, and a heap of pale sawdust underneath."""
    bd.reset()
    rng = random.Random(33)
    leg = mat("driftwood", -0.45)
    for x in (-0.9, 0.75):
        for s in (-1, 1):
            beam("TrestleLeg", (x, -0.45, 0.0), (x, 0.3 * s, 0.95), 0.08, leg)
            beam("TrestleLeg", (x, 0.45, 0.0), (x, -0.3 * s, 0.95), 0.08, leg)
        beam("TrestleBar", (x, -0.35, 0.9), (x, 0.35, 0.9), 0.1, leg)
    z = 0.95 + 0.22
    rod("Log", (-1.6, 0, z), (0.35, 0, z), 0.22, mat("pine", -0.45), verts=7)
    rod("CutEnd", (-1.61, 0, z), (-1.63, 0, z), 0.18, mat("driftwood", 0.15), verts=7)
    for k in range(3):  # the log split into planks past the kerf
        box("SawnPlank", (1.1, 0.12, 0.38), (0.95, -0.13 + k * 0.13, z - 0.2), mat("driftwood", (0.15, 0.0, 0.1)[k]))
    beam("Saw", (0.38, 0, z + 0.9), (0.42, 0, z - 0.9), 0.015, mat("slate", 0.15), width=0.14)
    for zz in (z + 0.9, z - 0.9):
        rod("SawHandle", (0.4, -0.2, zz), (0.4, 0.2, zz), 0.025, mat("driftwood", -0.1), verts=4)
    cyl("Sawdust", 0.75, 0.25, 0.18, 8, (0.35, 0.05, 0), mat("driftwood", 0.3))
    cyl("Sawdust2", 0.45, 0.1, 0.1, 7, (-0.4, 0.2, 0), mat("driftwood", 0.2))
    for i in range(3):  # finished planks stacked on the ground behind
        box("Plank", (2.4, 0.3, 0.06), (0.1 + rng.uniform(-0.05, 0.05), 0.95, i * 0.065), mat("driftwood", (0.05, -0.12)[i % 2]),
            rng.uniform(-0.04, 0.04))
    bd.export("saw_pit")


def build_charcoal_clamp() -> None:
    """A charcoal clamp (burners' mound) at the edge of the woods: a low dome of earth and turf
    (3.2 m across, 1 m high) over a stack of smouldering wood, four vent holes round the
    crown (smoke comes from the prop's `smoke` field: model-space vents listed in TECH),
    a ring of stakes, a ladder and a long rake leaning on it, a heap of finished charcoal."""
    bd.reset()
    rng = random.Random(9)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
    dome = bpy.context.active_object
    dome.name = "Mound"
    dome.scale = (1.6, 1.6, 1.05)
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new()
    bm.from_mesh(dome.data)
    for v in bm.verts:
        v.co.z = max(v.co.z, 0.0)
        if v.co.z > 0.0:
            v.co.x *= 1.0 + rng.uniform(-0.06, 0.06)
            v.co.y *= 1.0 + rng.uniform(-0.06, 0.06)
            v.co.z *= 1.0 + rng.uniform(-0.08, 0.04)
    bm.to_mesh(dome.data)
    bm.free()
    bd.bp.finish(dome, mat("driftwood", -0.62))
    for i in range(14):  # turf sods laid over the earth
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0.3, 1.25)
        h = 1.05 * math.sqrt(max(0.0, 1 - (d / 1.6) ** 2))
        box("Turf", (0.4, 0.3, 0.06), (math.cos(a) * d, math.sin(a) * d, h - 0.04), mat("moss", (-0.45, -0.6)[i % 2]), a)
    for k in range(4):  # vent holes
        a = k * math.pi / 2 + 0.4
        d = 0.65
        h = 1.05 * math.sqrt(1 - (d / 1.6) ** 2)
        cyl("Vent", 0.1, 0.12, 0.08, 6, (math.cos(a) * d, math.sin(a) * d, h - 0.05), mat("ink", 0.0))
        cyl("VentGlow", 0.06, 0.06, 0.09, 6, (math.cos(a) * d, math.sin(a) * d, h - 0.05), mat("coal", 0.1, emissive=True))
    for i in range(10):  # stake ring
        a = i / 10 * math.tau
        rod("Stake", (math.cos(a) * 1.9, math.sin(a) * 1.9, 0), (math.cos(a) * 1.95, math.sin(a) * 1.95, 0.55),
            0.035, mat("driftwood", -0.45), verts=4, r_end=0.02)
    # Ladder and rake leaning on the -Y side.
    for s in (-0.22, 0.22):
        beam("LadderRail", (0.5 + s, -1.95, 0), (0.5 + s, -0.75, 1.0), 0.06, mat("driftwood", -0.3))
    for r in range(4):
        t = (r + 1) / 5
        beam("Rung", (0.27, -1.95 + 1.2 * t, t * 1.0), (0.73, -1.95 + 1.2 * t, t * 1.0), 0.04, mat("driftwood", -0.2))
    rod("RakeHandle", (-0.9, -1.9, 0.05), (-0.3, -0.9, 1.25), 0.03, mat("driftwood", -0.1), verts=4)
    beam("RakeHead", (-1.15, -1.95, 0.05), (-0.65, -1.85, 0.05), 0.06, mat("slate", -0.4))
    for i in range(9):  # finished charcoal heaped at the +X side
        a = rng.uniform(-0.6, 0.6)
        box("Charcoal", (0.14, 0.1, 0.08), (2.2 + rng.uniform(-0.25, 0.25), a, rng.uniform(0, 0.12)), mat("ink", 0.05),
            rng.uniform(0, math.pi))
    bd.export("charcoal_clamp")


def build_pine_dark() -> None:
    """Thornwold's pine: darker and narrower than Saltmarrow's (pine_tree.glb) — a coal-brown
    trunk and five drooping tiers of deep pine-green, ~4.6 m tall. Same 0.6 m trunk footprint,
    so it takes the same collider."""
    bd.reset()
    cyl("Trunk", 0.2, 0.12, 1.4, 6, (0, 0, 0), mat("coal", -0.6))
    tiers = ((1.15, 1.2, 0.9), (1.0, 1.1, 1.5), (0.82, 1.0, 2.1), (0.62, 0.95, 2.7), (0.4, 1.0, 3.3))
    for i, (r, h, z) in enumerate(tiers):
        cyl(f"Tier{i}", r, 0.0, h, 7, (0, 0, z), mat("pine", (-0.45, -0.6, -0.5)[i % 3]), i * 0.45)
        cyl(f"Droop{i}", r * 1.02, r * 0.85, 0.12, 7, (0, 0, z - 0.06), mat("pine", -0.68), i * 0.45 + 0.2)
    bd.export("pine_dark")


def build_pine_snag() -> None:
    """A Greyed pine at the edge of the woods: the trunk silvered, most needles gone, a few
    bare branch spars and one last ragged green tier. ~4 m; same trunk footprint as pine_dark."""
    bd.reset()
    rng = random.Random(12)
    cyl("Trunk", 0.2, 0.06, 4.0, 6, (0, 0, 0), mat("silverfog", -0.55))
    for i in range(9):
        z = 1.2 + i * 0.3
        a = rng.uniform(0, math.tau)
        ln = 0.9 - i * 0.07
        rod("Spar", (0, 0, z), (math.cos(a) * ln, math.sin(a) * ln, z - 0.15), 0.035, mat("silverfog", -0.6),
            verts=4, r_end=0.01)
    cyl("LastTier", 0.55, 0.0, 0.8, 6, (0, 0, 2.9), mat("pine", -0.55), 0.3)
    bd.export("pine_snag")


def build_underbrush() -> None:
    """A clump of forest-floor growth for under the pines (~1.8 m across, knee-high): dark
    bush lumps, fern fronds arching out from the middle, and a few coal-red berries."""
    bd.reset()
    rng = random.Random(4)
    for i in range(4):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0)
        lump = bpy.context.active_object
        lump.name = "Bush"
        lump.scale = (rng.uniform(0.3, 0.45), rng.uniform(0.3, 0.45), rng.uniform(0.25, 0.4))
        lump.location = (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), lump.scale[2] * 0.6)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        bd.bp.finish(lump, mat("pine", (-0.4, -0.55)[i % 2]))
    for i in range(11):  # fern fronds
        a = i / 11 * math.tau + rng.uniform(-0.2, 0.2)
        ln = rng.uniform(0.6, 0.9)
        base = Vector((0, 0, 0.05))
        mid = Vector((math.cos(a) * ln * 0.55, math.sin(a) * ln * 0.55, 0.45))
        tip = Vector((math.cos(a) * ln, math.sin(a) * ln, 0.15))
        m = mat("moss", (-0.3, -0.45, -0.2)[i % 3])
        beam("Frond", base, mid, 0.025, m, width=0.16)
        beam("Frond", mid, tip, 0.025, m, width=0.12)
    for i in range(5):
        cyl("Berry", 0.035, 0.03, 0.06, 5, (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0.45), mat("coal", 0.05))
    bd.export("underbrush")


def build_fallen_trunk() -> None:
    """A wind-thrown pine lying along X (~4.2 m): a mossy trunk with snapped branch stubs and
    its root plate standing up at the -X end, earth still in the roots."""
    bd.reset()
    rng = random.Random(21)
    rod("Trunk", (-1.8, 0, 0.3), (2.4, 0, 0.2), 0.3, mat("coal", -0.58), verts=7, r_end=0.18)
    for i in range(4):
        x = -1.2 + i * 0.95
        box("Moss", (0.5, 0.35, 0.06), (x, rng.uniform(-0.05, 0.05), 0.5 - i * 0.03), mat("moss", -0.35), rng.uniform(-0.3, 0.3))
    for i in range(6):
        x = -0.9 + i * 0.6
        a = rng.uniform(0.3, 2.8)
        rod("Stub", (x, 0, 0.3), (x + 0.15, math.cos(a) * 0.55, 0.3 + math.sin(a) * 0.55), 0.04,
            mat("silverfog", -0.45), verts=4, r_end=0.015)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.95, depth=0.3)
    plate = bpy.context.active_object
    plate.name = "RootPlate"
    plate.rotation_euler = (0, math.pi / 2, 0)
    plate.location = (-1.95, 0, 0.95)
    bd.bp.finish(plate, mat("driftwood", -0.62))
    for i in range(7):
        a = i / 7 * math.tau
        p = Vector((-2.05, math.cos(a) * 0.7, 0.95 + math.sin(a) * 0.7))
        rod("Root", p, p + Vector((-0.2, math.cos(a) * 0.45, math.sin(a) * 0.45)), 0.05, mat("coal", -0.55),
            verts=4, r_end=0.01)
    bd.export("fallen_trunk")


BUILDERS = [build_bramble, build_log_pile, build_stump, build_charcoal_sacks, build_bunkhouse, build_tally_house, build_log_bench,
            build_saw_pit, build_charcoal_clamp, build_pine_dark, build_pine_snag, build_underbrush, build_fallen_trunk]

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
