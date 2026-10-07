"""Builds the first kit for Thornwold's woods past the bramble wall (Day 20) into the dressing
kit: the charcoal folk's hut and sack cart, the Keepers' waymarks up the old cart road (bare,
and with a lantern hung), a cutter's trail stake, and the Greyed undergrowth and pines of the
woods going grey from the inside.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_woods.py
    .tools/bin/blender-py tools/blender/build_woods.py [collier_hut sack_cart waymark …]

Same conventions as build_dressing/build_thornwold: origin at the base centre, flat-shaded,
palette colours and tonal shades, Blender -Y = Godot +Z = the front, merged by material.
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


def _lump(name, scale, loc, material, rng, jitter=0.12, rot=None) -> None:
    """A rough ico-sphere lump (bush, sack, stone) squashed to `scale`, its verts jittered."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0)
    obj = bpy.context.active_object
    obj.name = name
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for v in bm.verts:
        v.co *= 1.0 + rng.uniform(-jitter, jitter)
    bm.to_mesh(obj.data)
    bm.free()
    obj.scale = scale
    obj.location = loc
    obj.rotation_euler = rot or (0, 0, rng.uniform(0, math.pi))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bd.bp.finish(obj, material)


def _sack(loc, rng, lying: bool = False, shade: float = -0.2) -> None:
    """A tied sailcloth sack of charcoal: a lumpy body and a dark tied neck (or, lying, the
    neck pointing along -X)."""
    x, y, z = loc
    if lying:
        _lump("Sack", (0.36, 0.22, 0.2), (x, y, z + 0.18), mat("driftwood", shade), rng, 0.08,
              (0, 0, rng.uniform(-0.3, 0.3)))
        rod("Neck", (x - 0.32, y, z + 0.2), (x - 0.46, y, z + 0.22), 0.07, mat("driftwood", -0.55), verts=5, r_end=0.04)
    else:
        _lump("Sack", (0.22, 0.2, 0.3), (x, y, z + 0.28), mat("driftwood", shade), rng, 0.08)
        cyl("Neck", 0.08, 0.05, 0.12, 5, (x, y, z + 0.54), mat("driftwood", -0.55))


def _collier_hut(cold: bool, cap: bool = False, boots: bool = True) -> None:
    """A charcoal-burner's hut, the kind the charcoal folk live in beside their clamps: a cone
    of leaning poles (3 m across, ~2.9 m tall) roofed in bark slabs and turf, the pole tops
    crossed at the peak, a low doorway at the front with a sacking curtain, a hearth ring of
    stones and a log seat outside, a rake and a sack against the wall.
    Cold (a collier who went up the ridge and didn't come back, Day 22): the same hut left —
    sods silvered and slipped off the cone (bare poles showing), the curtain gone from a dark
    doorway, the hearth ring kicked apart with no ash or spit, the rake leaning by the door,
    no sack, a pair of boots set neatly on the seat.
    Without boots (Day 27, `collier_hut_cold_empty`): Hob gave Ottie's boots (and the cap) to the
    Ridge Light, or to the player to carry there — the seat is bare and the hut is nobody's."""
    rng = random.Random(30)
    radius, height = 1.5, 2.6
    # Few shades, so the merged model stays a handful of draw calls.
    WOOD, BARK, CLOTH = mat("driftwood", -0.35), mat("pine", -0.55), mat("driftwood", -0.1)
    # The cone: rings of verts up to the peak, every face a bark slab or a turf sod (a
    # patchwork of materials on one mesh), the rings jittered so the slabs read as laid by hand.
    sides, rings = 11, 5
    verts = []
    for ring in range(rings):
        t = ring / rings
        r = radius * (1 - t) * (1.0 + (0.04 if ring else 0.0))
        for k in range(sides):
            a = (k + 0.5 * (ring % 2)) / sides * math.tau
            jr = 1.0 + (rng.uniform(-0.06, 0.06) if 0 < ring else 0.0)
            verts.append((math.cos(a) * r * jr, math.sin(a) * r * jr, height * t + (rng.uniform(-0.06, 0.06) if ring else 0)))
    verts.append((0, 0, height))
    faces = []
    for ring in range(rings - 1):
        for k in range(sides):
            a0, a1 = ring * sides + k, ring * sides + (k + 1) % sides
            b0, b1 = (ring + 1) * sides + k, (ring + 1) * sides + (k + 1) % sides
            faces.append((a0, a1, b1, b0))
    top = len(verts) - 1
    for k in range(sides):
        faces.append(((rings - 1) * sides + k, (rings - 1) * sides + (k + 1) % sides, top))
    mesh = bpy.data.meshes.new("Cone")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    cone = bpy.data.objects.new("Cone", mesh)
    bpy.context.collection.objects.link(cone)
    if cold:  # the turf greyed where it lies; slipped slabs leave holes (dark) between poles
        patch = (mat("pine", -0.5), mat("silverfog", -0.45), mat("silverfog", -0.55), mat("ink", 0.0))
        for m in patch:
            cone.data.materials.append(m)
    else:
        patch = (mat("pine", -0.5), mat("driftwood", -0.55), mat("moss", -0.5), mat("pine", -0.62))
        for m in patch:
            cone.data.materials.append(m)
    for i, poly in enumerate(cone.data.polygons):
        poly.use_smooth = False
        ring = i // sides
        poly.material_index = 2 if ring >= rings - 2 and i % 3 else (i * 7 + ring) % 4 if ring < rings - 2 else 3
        if cold and ring in (1, 2) and i % 5 == 2:
            poly.material_index = 3
    # A ridge of sods round the foot where the cone meets the ground.
    for k in range(sides):
        a = (k + 0.5) / sides * math.tau
        if abs(math.atan2(math.sin(a + math.pi / 2), math.cos(a + math.pi / 2))) < 0.4:
            continue  # the doorway
        if cold and k % 3 == 0:  # slipped off, lying out from the foot
            box("SlippedSod", (0.6, 0.3, 0.1), (math.cos(a) * (radius + 0.55), math.sin(a) * (radius + 0.55), 0),
                mat("silverfog", -0.5), a + math.pi / 2 + 0.4)
            continue
        box("FootSod", (0.6, 0.22, 0.16), (math.cos(a) * (radius + 0.05), math.sin(a) * (radius + 0.05), 0),
            mat("silverfog", -0.5) if cold else mat("moss", -0.55), a + math.pi / 2)
    # Pole tops crossing at the peak.
    for k in range(5):
        a = k / 5 * math.tau + 0.3
        base = Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, height - 0.25))
        rod("PoleTop", base, base + Vector((-math.cos(a) * 0.45, -math.sin(a) * 0.45, 0.55)), 0.04,
            WOOD, verts=4, r_end=0.025)
    # Doorway: a little gabled entrance standing out of the cone at the front — bark side
    # walls, a dark opening, door poles, a lintel, and sacking hung half across.
    door_y = -radius + 0.1
    box("Door", (0.6, 0.9, 1.15), (0, door_y + 0.1, 0), mat("ink", 0.0))
    for sx in (-0.38, 0.38):
        box("DoorWall", (0.1, 0.9, 1.2), (sx, door_y + 0.1, 0), BARK)
        rod("DoorPole", (sx, door_y - 0.36, 0), (sx, door_y - 0.36, 1.3), 0.05, WOOD, verts=5)
    bd.bp.prism("DoorRoof", 1.0, 1.1, 0.42, (0, door_y + 0.15, 1.2), BARK)
    beam("Lintel", (-0.45, door_y - 0.38, 1.22), (0.45, door_y - 0.38, 1.22), 0.07, WOOD)
    if not cold:
        box("Curtain", (0.34, 0.04, 0.95), (0.13, door_y - 0.37, 0.22), CLOTH)
    # Hearth ring of stones with a cold spit, and a log seat. Cold: the ring kicked apart.
    hx, hy = 0.9, -2.2
    for k in range(7):
        a = k / 7 * math.tau
        d = 0.4 + (rng.uniform(0.1, 0.5) if cold and k % 2 else 0.0)
        _lump("HearthStone", (0.13, 0.11, 0.08), (hx + math.cos(a) * d, hy + math.sin(a) * d, 0.04),
              mat("slate", -0.3), rng)
    if not cold:
        for k in range(3):
            box("Ash", (0.22, 0.16, 0.03), (hx + rng.uniform(-0.1, 0.1), hy + rng.uniform(-0.1, 0.1), 0),
                mat("silverfog", -0.4), k)
        for s in (-0.45, 0.45):
            rod("SpitPost", (hx + s, hy, 0), (hx + s, hy, 0.6), 0.025, WOOD, verts=4)
        rod("Spit", (hx - 0.5, hy, 0.58), (hx + 0.5, hy, 0.58), 0.02, mat("ink", 0.0), verts=4)
    rod("Seat", (-0.9, -2.4, 0.2), (-0.1, -2.75, 0.2), 0.2, BARK, verts=7)
    rod("SeatTop", (-0.88, -2.41, 0.39), (-0.12, -2.74, 0.39), 0.12, CLOTH, verts=5)
    if cold:
        # The rake leaning by the doorway, and a pair of boots set side by side on the seat.
        rod("Rake", (-0.55, door_y - 0.5, 0.02), (-0.45, door_y - 0.15, 1.75), 0.03, CLOTH, verts=4)
        beam("RakeHead", (-0.8, door_y - 0.52, 0.04), (-0.3, door_y - 0.52, 0.04), 0.06, mat("slate", -0.3))
        for k, off in enumerate((-0.12, 0.12) if boots else ()):
            x, y = -0.5 + off, -2.57 + off * 0.42
            box("Boot", (0.12, 0.26, 0.1), (x, y - 0.04, 0.45), mat("ink", 0.0), -0.42)
            box("BootLeg", (0.12, 0.12, 0.24), (x + 0.03, y + 0.05, 0.45), mat("ink", 0.0), -0.42)
        if cap and boots:
            # Ottie Swale's felt cap, brought down from the stair's waymark by the player: Hob
            # set it crown-up on the seat beside the boots, brim toward the door.
            cx, cy = -0.2, -2.71
            _lump("Cap", (0.15, 0.14, 0.08), (cx, cy, 0.56), mat("driftwood", -0.6), random.Random(71), 0.06,
                  (0, 0, -0.42))
            cyl("CapBand", 0.155, 0.15, 0.04, 7, (cx, cy, 0.5), mat("coal", -0.4), -0.42)
            beam("CapBrim", (cx - 0.02, cy - 0.05, 0.52), (cx - 0.1, cy - 0.22, 0.51), 0.02,
                 mat("driftwood", -0.6), width=0.2)
    else:
        # A rake leaning on the hut and a sack at its foot.
        rod("Rake", (1.45, -0.35, 0.05), (0.95, -0.2, 1.7), 0.03, CLOTH, verts=4)
        beam("RakeHead", (1.4, -0.6, 0.06), (1.55, -0.1, 0.06), 0.06, mat("slate", -0.3))
        _sack((-1.35, -0.6, 0), rng, shade=-0.1)


def build_collier_hut() -> None:
    bd.reset()
    _collier_hut(False)
    bd.export("collier_hut")
    bd.reset()
    _collier_hut(True)
    bd.export("collier_hut_cold")
    bd.reset()
    _collier_hut(True, cap=True)
    bd.export("collier_hut_cold_cap")
    bd.reset()
    _collier_hut(True, boots=False)
    bd.export("collier_hut_cold_empty")


def _wheel(x: float, y: float, r: float) -> None:
    """A spoked cart wheel in the XZ plane at (x, y), hub at height r."""
    rim = mat("driftwood", -0.4)
    for k in range(10):
        a0, a1 = k / 10 * math.tau, (k + 1) / 10 * math.tau
        beam("Rim", (x + math.cos(a0) * r, y, r + math.sin(a0) * r), (x + math.cos(a1) * r, y, r + math.sin(a1) * r),
             0.07, rim, width=0.07)
    for k in range(5):
        a = k / 5 * math.tau
        beam("Spoke", (x, y, r), (x + math.cos(a) * r * 0.95, y, r + math.sin(a) * r * 0.95), 0.035, rim)
    rod("Hub", (x, y - 0.09, r), (x, y + 0.09, r), 0.08, mat("ink", 0.1), verts=6)


def build_sack_cart() -> None:
    """The charcoal folk's handcart (2.6 m long with its shafts, along X; front = -X): a plank
    bed on two spoked wheels, low side-rails, shafts resting on the ground, five sacks of
    charcoal (one lying), a coil of rope and a lantern hook on the tail — what carries the
    sacks down to the jetty when nobody's looking."""
    bd.reset()
    rng = random.Random(31)
    wheel_r = 0.42
    bed_z = wheel_r + 0.12
    # Tipped forward onto its shafts: the bed is built level, then everything above the axle
    # leans a little — kept simple by building the shafts sloping down to the ground.
    box("Bed", (1.5, 0.95, 0.08), (0.2, 0, bed_z), mat("driftwood", -0.25))
    for y in (-0.47, 0.47):
        beam("Rail", (-0.55, y, bed_z + 0.28), (0.95, y, bed_z + 0.28), 0.06, mat("driftwood", -0.4))
        for x in (-0.5, 0.2, 0.9):
            beam("Stake", (x, y, bed_z), (x, y, bed_z + 0.32), 0.05, mat("driftwood", -0.4))
        beam("Shaft", (-0.55, y * 0.85, bed_z + 0.02), (-1.65, y * 0.6, 0.03), 0.07, mat("driftwood", -0.3))
    beam("Crossbar", (-1.55, -0.3, 0.07), (-1.55, 0.3, 0.07), 0.05, mat("driftwood", -0.3))
    rod("Axle", (0.2, -0.6, wheel_r), (0.2, 0.6, wheel_r), 0.04, mat("ink", 0.1), verts=5)
    for y in (-0.56, 0.56):
        _wheel(0.2, y, wheel_r)
    beam("TailProp", (0.95, 0, bed_z), (1.0, 0, 0), 0.06, mat("driftwood", -0.35))
    # The load.
    for i, (x, y) in enumerate(((-0.25, -0.22), (-0.25, 0.22), (0.3, -0.2), (0.3, 0.22))):
        _sack((x, y, bed_z + 0.04), rng, shade=(-0.2, -0.3)[i % 2])
    _sack((0.0, 0.0, bed_z + 0.5), rng, lying=True, shade=-0.12)
    for k in range(3):  # a coil of rope on the tail
        cyl("Rope", 0.16 - k * 0.01, 0.16 - k * 0.01, 0.03, 8, (0.75, 0.1, bed_z + 0.04 + k * 0.03), mat("driftwood", 0.1))
    rod("Hook", (1.0, 0, bed_z + 0.3), (1.0, 0, bed_z + 0.85), 0.025, mat("ink", 0.15), verts=4)
    beam("HookArm", (1.0, 0, bed_z + 0.85), (1.15, 0, bed_z + 0.85), 0.025, mat("ink", 0.15))
    for k in range(4):  # spilled charcoal under the tail
        box("Charcoal", (0.1, 0.08, 0.06), (1.1 + rng.uniform(-0.15, 0.15), rng.uniform(-0.3, 0.3), 0),
            mat("ink", 0.05), rng.uniform(0, math.pi))
    bd.export("sack_cart")


def _waymark(lantern: bool) -> None:
    """A Keeper's waymark on the old cart road up to Thornwold's beacon: a stone cairn (1 m)
    with a weathered post set in it (2.3 m) and an iron arm reaching to -Y (Godot +Z) with a
    hook. A carved ember (a flame in a ring) on the post's face, Keeper-fashion. Lit: a
    Keeper's lantern hangs on the hook, glass centre (0, -0.5, 1.75) — where the prop's light
    goes. Bare: the hook is empty and the carving is all that says who set it."""
    rng = random.Random(32)
    for k in range(9):  # the cairn: big stones low, small high
        tier = 0 if k < 5 else 1 if k < 8 else 2
        a = k / (5 if tier == 0 else 3) * math.tau + tier * 0.6
        d = (0.42, 0.24, 0.0)[tier]
        s = (0.26, 0.2, 0.16)[tier]
        _lump("Cairn", (s, s * 0.9, s * 0.7), (math.cos(a) * d, math.sin(a) * d, 0.12 + tier * 0.26),
              mat("slate", (-0.15, -0.3, -0.05)[k % 3]), rng)
    for k in range(3):
        box("Lichen", (0.14, 0.1, 0.03), (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0.32 + k * 0.12),
            mat("silverfog", -0.2), rng.uniform(0, math.pi))
    rod("Post", (0, 0, 0), (0, 0, 2.3), 0.09, mat("silverfog", -0.5), verts=6, r_end=0.07)
    cyl("PostCap", 0.1, 0.03, 0.1, 6, (0, 0, 2.3), mat("silverfog", -0.55))
    beam("Arm", (0, 0.04, 2.15), (0, -0.62, 2.15), 0.04, mat("ink", 0.15))
    beam("Brace", (0, 0, 1.85), (0, -0.32, 2.14), 0.03, mat("ink", 0.15))
    beam("Hook", (0, -0.5, 2.15), (0, -0.5, 2.0), 0.02, mat("ink", 0.2))
    # The carved ember on the -Y face: a ring with a flame in it, in pale cut wood.
    face_y = -0.085
    for k in range(8):
        a0, a1 = k / 8 * math.tau, (k + 1) / 8 * math.tau
        beam("Ring", (math.cos(a0) * 0.07, face_y, 1.45 + math.sin(a0) * 0.07),
             (math.cos(a1) * 0.07, face_y, 1.45 + math.sin(a1) * 0.07), 0.018, mat("bone", -0.2))
    beam("Flame", (0, face_y, 1.4), (0, face_y, 1.52), 0.022, mat("ember", -0.2), width=0.04)
    if lantern:
        cyl("Cap", 0.15, 0.02, 0.13, 6, (0, -0.5, 1.92), mat("ink", 0.15))
        cyl("Glass", 0.1, 0.1, 0.26, 6, (0, -0.5, 1.64), mat("kindle", 0.0, emissive=True))
        cyl("Base", 0.12, 0.12, 0.04, 6, (0, -0.5, 1.6), mat("ink", 0.15))
        for i in range(3):
            a = math.tau * i / 3
            beam("Frame", (math.cos(a) * 0.11, -0.5 + math.sin(a) * 0.11, 1.62),
                 (math.cos(a) * 0.11, -0.5 + math.sin(a) * 0.11, 1.93), 0.02, mat("ink", 0.15))
        beam("Bail", (0, -0.5, 2.05), (0, -0.5, 1.99), 0.015, mat("ink", 0.2))


def build_waymarks() -> None:
    bd.reset()
    _waymark(False)
    bd.export("waymark")
    bd.reset()
    _waymark(True)
    bd.export("waymark_lit")


def build_trail_stake() -> None:
    """A cutter's trail stake (1.2 m), driven in where a path leaves the camp: a split post
    leaning a little, its face cut with the camp's notches (three short, one long — "this way
    home") on its back (-X) face, a coal-red rag knotted round the top, and a pointer slat
    nailed across pointing +X: set rotation_y 90 and it points to -Z with the notches toward +Z."""
    bd.reset()
    beam("Stake", (0, 0, -0.1), (0.04, 0.03, 1.2), 0.13, mat("driftwood", -0.3), width=0.16)
    cyl("Point", 0.11, 0.0, 0.1, 4, (0.04, 0.03, 1.2), mat("driftwood", -0.35), math.pi / 4)
    for k, length in enumerate((0.07, 0.07, 0.07, 0.13)):
        z = 0.55 + k * 0.12
        beam("Notch", (-0.085, -length / 2, z), (-0.085, length / 2, z), 0.03, mat("bone", -0.1), width=0.02)
    cyl("Rag", 0.11, 0.11, 0.1, 6, (0.035, 0.028, 1.0), mat("coal", -0.1))
    beam("RagTail", (0.1, 0.0, 1.05), (0.24, -0.05, 0.82), 0.02, mat("coal", -0.1), width=0.07)
    beam("Pointer", (-0.15, -0.1, 0.9), (0.45, -0.1, 0.95), 0.03, mat("driftwood", -0.15), width=0.09)
    cyl("PointerTip", 0.06, 0.0, 0.1, 3, (0.45, -0.1, 0.95), mat("driftwood", -0.15))
    bd.export("trail_stake")


def build_greyed_brush() -> None:
    """Undergrowth the Greying has had (~1.8 m across): the same lumps and fern fans as
    `underbrush` but silvered and thinned, fronds bare to the rib, twig fans standing up,
    no berries — ash-pale under the dark pines."""
    bd.reset()
    rng = random.Random(33)
    for i in range(3):
        sz = rng.uniform(0.18, 0.3)
        _lump("Bush", (rng.uniform(0.25, 0.38), rng.uniform(0.25, 0.38), sz),
              (rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45), sz * 0.85), mat("silverfog", (-0.35, -0.5, -0.42)[i]),
              rng, 0.25)
    for i in range(9):  # bare frond ribs, a few with a grey leaf left
        a = i / 9 * math.tau + rng.uniform(-0.25, 0.25)
        ln = rng.uniform(0.55, 0.85)
        mid = Vector((math.cos(a) * ln * 0.5, math.sin(a) * ln * 0.5, 0.4))
        tip = Vector((math.cos(a) * ln, math.sin(a) * ln, 0.1))
        rod("Rib", (0, 0, 0.05), mid, 0.018, mat("silverfog", -0.55), verts=3)
        rod("Rib", mid, tip, 0.014, mat("silverfog", -0.55), verts=3, r_end=0.004)
        if i % 3 == 0:
            beam("Leaf", mid, mid + (tip - mid) * 0.5, 0.02, mat("silverfog", -0.3), width=0.1)
    for i in range(6):  # stiff dead twigs
        base = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0.1))
        top = base + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0.6, 0.95)))
        rod("Twig", base, top, 0.022, mat("silverfog", -0.62), verts=3, r_end=0.004)
        fork = base + (top - base) * 0.6
        rod("Twig", fork, fork + Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0.25)), 0.012,
            mat("silverfog", -0.62), verts=3, r_end=0.003)
    bd.export("greyed_brush")


def build_pine_grey() -> None:
    """A pine the Greying has taken deep in the woods (~4.6 m): pine_dark's shape — five
    drooping tiers — gone the colour of fog, the tiers thinner and ragged, the trunk
    silvered. Same 0.6 m trunk footprint, same collider as pine_dark."""
    bd.reset()
    rng = random.Random(34)
    cyl("Trunk", 0.2, 0.1, 1.5, 6, (0, 0, 0), mat("silverfog", -0.55))
    tiers = ((1.05, 1.0, 0.95), (0.9, 0.95, 1.55), (0.74, 0.9, 2.15), (0.55, 0.85, 2.75), (0.35, 0.9, 3.3))
    for i, (r, h, z) in enumerate(tiers):
        tier = cyl(f"Tier{i}", r, 0.0, h, 6, (0, 0, z), mat("silverfog", (-0.38, -0.48, -0.42)[i % 3]), i * 0.55)
        bm = bmesh.new()
        bm.from_mesh(tier.data)
        for v in bm.verts:  # ragged: some rim verts pulled in, as if needles had fallen
            if v.co.z < -h * 0.4:
                pull = rng.uniform(0.6, 1.0)
                v.co.x *= pull
                v.co.y *= pull
        bm.to_mesh(tier.data)
        bm.free()
    for i in range(5):  # bare spars poking out between the tiers
        z = 1.25 + i * 0.55
        a = rng.uniform(0, math.tau)
        rod("Spar", (0, 0, z), (math.cos(a) * 1.0, math.sin(a) * 1.0, z - 0.12), 0.03, mat("silverfog", -0.62),
            verts=3, r_end=0.008)
    bd.export("pine_grey")


BUILDERS = [build_collier_hut, build_sack_cart, build_waymarks, build_trail_stake, build_greyed_brush, build_pine_grey]
ALIASES = {"waymark": "waymarks", "waymark_lit": "waymarks", "collier_hut_cold": "collier_hut",
           "collier_hut_cold_cap": "collier_hut", "collier_hut_cold_empty": "collier_hut"}

if __name__ == "__main__":
    only = {ALIASES.get(a, a) for a in sys.argv[1:] if not a.startswith("-")}
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
