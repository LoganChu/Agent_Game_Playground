"""Builds the Saltmarrow dressing kit (Act I set dressing) and exports each piece as .glb.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_dressing.py
    .tools/bin/blender-py tools/blender/build_dressing.py

Outputs assets/models/dressing/<name>.glb. Same conventions as build_props.py: origin at the
base centre (boats: at the waterline), flat-shaded, palette colours and tonal shades of them
only, Blender -Y = Godot +Z (the "front"). Pieces that replace a procedural PropFactory shape
keep that shape's footprint and heights so region data can swap `shape` for `model` without
moving anything (e.g. the dock's deck top stays at 0.675, the beacon glass at 4.14–5.0).
Lights are not exported: a region prop adds one with its `light` field (docs/TECH.md).
"""
import math
import os
import random
import sys

import bpy  # must be imported before bmesh/mathutils when running as the bpy module
import bmesh  # noqa: E402
from mathutils import Vector  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_props as bp  # noqa: E402  (palette, colour conversion, primitives)

OUT_DIR = os.path.join(bp.ROOT, "assets", "models", "dressing")

_materials: dict = {}


def mat(name: str, shade: float = 0.0, emissive: bool = False) -> bpy.types.Material:
    """Palette material; shade in [-1, 1] darkens (<0) or lightens (>0) the palette colour."""
    key = (name, round(shade, 3), emissive)
    if key in _materials:
        return _materials[key]
    h = bp.PALETTE[name].lstrip("#")
    rgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    rgb = [c * (1.0 + shade) for c in rgb] if shade < 0 else [c + (1.0 - c) * shade for c in rgb]
    rgba = tuple(bp.srgb_to_linear(c) for c in rgb) + (1.0,)
    label = name + (f"_{'d' if shade < 0 else 'l'}{abs(int(shade * 100))}" if shade else "")
    m = bpy.data.materials.new(label + ("_glow" if emissive else ""))
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.95
    if emissive:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = 2.0
    _materials[key] = m
    return m


def horn(name: str, alpha: float, shade: float = 0.0, glow: float = 0.5) -> bpy.types.Material:
    """Emissive, see-through palette material (exported as glTF alphaMode BLEND): lit horn or
    glass panes that glow and still let the fire behind them show."""
    key = (name, round(shade, 3), "horn", round(alpha, 3), round(glow, 3))
    if key in _materials:
        return _materials[key]
    base = mat(name, shade, emissive=True)
    m = base.copy()
    m.name = base.name + f"_horn{int(alpha * 100)}"
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Alpha"].default_value = alpha
    bsdf.inputs["Emission Strength"].default_value = glow  # faint, so the fire behind still reads
    m.surface_render_method = "BLENDED"
    _materials[key] = m
    return m


def reset() -> None:
    bp.reset_scene()
    _materials.clear()


def box(name, size, loc, material, rot_z=0.0):
    """Box standing on loc (base centre)."""
    return bp.box(name, size, loc, material, rot_z)


def cyl(name, r1, r2, depth, verts, loc, material, rot_z=0.0):
    """Cylinder/cone standing on loc (base centre)."""
    return bp.cone(name, r1, r2, depth, verts, loc, material, rot_z)


def _align(obj, p0: Vector, p1: Vector) -> None:
    obj.location = (p0 + p1) / 2
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (p1 - p0).to_track_quat("Z", "Y")


def beam(name, p0, p1, thick, material, width=None):
    """Square-section plank/beam from p0 to p1 (thick × width)."""
    p0, p1 = Vector(p0), Vector(p1)
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (width or thick, thick, (p1 - p0).length)
    bpy.ops.object.transform_apply(scale=True)
    _align(obj, p0, p1)
    return bp.finish(obj, material)


def rod(name, p0, p1, radius, material, verts=5, r_end=None):
    """Round pole from p0 to p1 (optionally tapering to r_end)."""
    p0, p1 = Vector(p0), Vector(p1)
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius if r_end is None else r_end,
                                    depth=(p1 - p0).length)
    obj = bpy.context.active_object
    obj.name = name
    _align(obj, p0, p1)
    return bp.finish(obj, material)


def net(name, width, height, centre, material, spacing=0.16, strand=0.022, sag=0.0):
    """A fishing net as a lattice of thin strands in the XZ plane, centred on `centre`.
    `sag` bows the bottom rows outward (+/-Y) a little so it reads as hanging cloth."""
    cx, cy, cz = centre
    nx = max(2, int(round(width / spacing)) + 1)
    nz = max(2, int(round(height / spacing)) + 1)
    x0, z_top = cx - width / 2, cz + height / 2
    for i in range(nx):
        x = x0 + width * i / (nx - 1)
        beam(f"{name}V{i}", (x, cy, z_top), (x, cy + sag, z_top - height), strand, material)
    for j in range(nz):
        f = j / (nz - 1)
        z = z_top - height * f
        beam(f"{name}H{j}", (x0, cy + sag * f, z), (x0 + width, cy + sag * f, z), strand, material)


def hull_stations(length, half_beam, depth, sheer, stations=7, transom=0.55):
    """Cross-section stations of a boat hull, bow (-Y, pointed) to stern (+Y, a transom
    `transom` × the beam): [(y, half_width, sheer_z, keel_z)]. The bow sweeps up a little."""
    out = []
    for s in range(stations):
        t = s / (stations - 1)  # 0 bow .. 1 stern
        w = half_beam * math.sin(math.pi * min(t * 1.25, 1.0) / 2)
        if t > 0.8:
            w = half_beam * (1.0 - (t - 0.8) / 0.2 * (1.0 - transom))
        rise = 0.12 * (1.0 - t) ** 3 * depth / 0.5
        out.append((-length / 2 + length * t, w, sheer + rise, sheer - depth * (0.6 + 0.4 * math.sin(math.pi * t))))
    return out


def hull(name, stations, depth, sheer, material):
    """Open hull lofted through V cross-sections at `stations` (from hull_stations), with a
    transom face at the stern and planking thickness from a Solidify modifier."""
    verts, faces = [], []
    for y, w, s_z, keel in stations:
        chine = sheer - depth * 0.62
        verts += [(-w, y, s_z), (-0.78 * w, y, chine), (0, y, keel), (0.78 * w, y, chine), (w, y, s_z)]
    for s in range(len(stations) - 1):
        a, b = s * 5, (s + 1) * 5
        for k in range(4):
            faces.append((a + k, a + k + 1, b + k + 1, b + k))
    last = (len(stations) - 1) * 5
    faces.append(tuple(range(last, last + 5)))  # transom
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    solid = obj.modifiers.new("Planking", "SOLIDIFY")
    solid.thickness = 0.05
    return bp.finish(obj, material)


def gunwale(name, stations, material, thick=0.07, drop=0.0):
    """A rail (or painted stripe, with `drop` below the sheer) following the hull's sheer line
    on both sides, just proud of the planking."""
    for side in (-1, 1):
        for (y0, w0, z0, _), (y1, w1, z1, _) in zip(stations, stations[1:]):
            beam(name, (side * (w0 + 0.03), y0, z0 - drop), (side * (w1 + 0.03), y1, z1 - drop), thick, material)


def deck(name, stations, upto, material, below=0.06):
    """A flat deck filling the hull's plan from the bow to station index `upto`."""
    pts = stations[:upto + 1]
    z = min(p[2] for p in pts) - below
    verts = [(-w, y, z) for y, w, _, _ in pts] + [(w, y, z) for y, w, _, _ in reversed(pts)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], [tuple(range(len(verts)))])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.modifiers.new("Thick", "SOLIDIFY").thickness = 0.05
    return bp.finish(obj, material)


def merge_by_material() -> None:
    """Joins every mesh that shares a material into one object (modifiers applied first), so
    a net's dozens of strands become one draw call in Godot instead of one node each."""
    groups: dict = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        groups.setdefault(obj.data.materials[0].name, []).append(obj)
    for name, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objs:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1:
            bpy.ops.object.join()
        joined = bpy.context.view_layer.objects.active
        joined.name = name
        # Bake the transform so every exported mesh sits at the model origin untransformed.
        bpy.ops.object.select_all(action="DESELECT")
        joined.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        joined.rotation_mode = "XYZ"  # beams use quaternions; later rotation_euler edits must apply


def export(name: str) -> None:
    merge_by_material()
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False,
                              export_apply=True, export_yup=True, export_lights=False,
                              export_cameras=False)
    print(f"[build_dressing] wrote {path} ({os.path.getsize(path) // 1024} KB)")


# --- Harbor ---------------------------------------------------------------------------------

def build_dock() -> None:
    """Plank dock 2 × 6 m, deck top at z 0.675 (matches the Saltmarrow pier deck at y 0.275
    when placed at y -0.4). Sea end at -Y (Godot +Z): taller mooring posts and a ladder."""
    reset()
    rng = random.Random(11)
    top, thick = 0.675, 0.08
    for i in range(24):
        y = -2.875 + i * 0.25
        m = mat("driftwood", rng.choice((-0.08, -0.16, -0.24)))
        box(f"Plank{i}", (2.0 + rng.uniform(-0.06, 0.06), 0.22, thick), (rng.uniform(-0.03, 0.03), y, top - thick), m)
    for x in (-0.7, 0.7):
        box("Stringer", (0.12, 6.0, 0.14), (x, 0, top - thick - 0.14), mat("driftwood", -0.45))
    for y in (-2.8, -0.95, 0.95, 2.8):
        for x in (-0.95, 0.95):
            tall = y < -2.0
            cyl("Piling", 0.12, 0.1, 2.0 + (0.45 if tall else 0.0) - 0.08, 6, (x, y, -1.4), mat("slate", -0.25), rng.uniform(0, 1))
            if tall:
                cyl("PilingCap", 0.12, 0.08, 0.06, 6, (x, y, top + 0.37), mat("coal", -0.2))
    for y in (-1.9, 1.9):
        beam("Brace", (-0.95, y - 0.9, -0.2), (-0.95, y + 0.9, 0.4), 0.07, mat("slate", -0.35))
        beam("Brace", (0.95, y + 0.9, -0.2), (0.95, y - 0.9, 0.4), 0.07, mat("slate", -0.35))
    for i, z in enumerate((-0.9, -0.5, -0.1, 0.3)):
        beam(f"Rung{i}", (0.55, -3.08, z), (0.85, -3.08, z), 0.05, mat("driftwood", -0.3))
    for x in (0.55, 0.85):
        beam("LadderRail", (x, -3.08, -1.1), (x, -3.02, top + 0.35), 0.05, mat("driftwood", -0.3))
    cyl("Bollard", 0.1, 0.13, 0.28, 6, (-0.6, -2.3, top), mat("ink", 0.25))
    cyl("RopeCoil", 0.24, 0.24, 0.1, 8, (-0.55, -1.6, top), mat("driftwood", 0.25))
    export("dock")


ROWBOAT = dict(length=3.0, half_beam=0.62, depth=0.45, sheer=0.5)


def _rowboat(hull_colour, rail_colour):
    st = hull_stations(ROWBOAT["length"], ROWBOAT["half_beam"], ROWBOAT["depth"], ROWBOAT["sheer"])
    parts = [hull("Hull", st, ROWBOAT["depth"], ROWBOAT["sheer"], hull_colour)]
    gunwale("Gunwale", st, rail_colour, thick=0.06)
    for y in (-0.2, 0.55):
        box("Thwart", (1.1, 0.22, 0.05), (0, y, 0.34), mat("driftwood", -0.1))
    return parts


def build_rowboat() -> None:
    """Small open rowboat (3 m), resting upright on the ground; origin at the base centre."""
    reset()
    _rowboat(mat("tide", -0.1), mat("coal", -0.1))
    rod("Oar", (-0.3, -0.6, 0.42), (0.25, 1.3, 0.45), 0.03, mat("driftwood", 0.1))
    beam("Blade", (0.22, 1.1, 0.45), (0.28, 1.45, 0.45), 0.02, mat("driftwood", 0.1), width=0.14)
    export("rowboat")


def build_rowboat_upturned() -> None:
    """A rowboat hauled up and turned keel-up on two driftwood trestles (beached, for tarring)."""
    reset()
    _rowboat(mat("tide", -0.25), mat("coal", -0.3))
    merge_by_material()
    for obj in list(bpy.context.scene.objects):  # flip the whole boat keel-up onto the trestles
        obj.rotation_euler = (0, math.pi, 0)
        obj.location = (0, 0, 0.78)
    for y in (-0.8, 0.7):
        rod("Trestle", (-0.75, y, 0.2), (0.75, y, 0.2), 0.12, mat("driftwood", 0.15), verts=6)
    box("TarPot", (0.3, 0.3, 0.3), (1.0, 0.9, 0), mat("ink", 0.1), 0.4)
    export("rowboat_upturned")


def build_moored_boat() -> None:
    """A single-masted Saltmarrow fishing boat (5.4 m), origin at the WATERLINE: place it
    with `"snap": false` at the water level. Sail furled along the boom."""
    reset()
    st = hull_stations(5.4, 0.95, 0.95, 0.55, stations=9)
    hull("Hull", st, 0.95, 0.55, mat("ink", 0.3))
    gunwale("Rail", st, mat("driftwood", -0.3), thick=0.08)
    gunwale("Stripe", st, mat("ember", -0.15), thick=0.06, drop=0.14)
    deck("Foredeck", st, 2, mat("driftwood", -0.15))
    box("Cuddy", (0.9, 0.8, 0.5), (0, -0.8, 0.3), mat("driftwood", -0.05))
    bp.prism("CuddyRoof", 1.05, 0.9, 0.22, (0, -0.8, 0.8), mat("slate", -0.2))
    rod("Mast", (0, -0.2, 0.0), (0, -0.2, 4.2), 0.07, mat("driftwood", -0.2), r_end=0.05)
    rod("Boom", (0, -0.2, 1.3), (0, 2.3, 1.2), 0.05, mat("driftwood", -0.2))
    rod("Sail", (0, -0.05, 1.42), (0, 2.1, 1.32), 0.13, mat("bone", -0.1), verts=6, r_end=0.08)
    beam("Stay", (0, -0.2, 4.1), (0, -2.6, 0.9), 0.02, mat("ink", 0.2))
    beam("Stay", (0, -0.2, 4.1), (0, 2.65, 0.6), 0.02, mat("ink", 0.2))
    box("Pennant", (0.02, 0.35, 0.14), (0, 0.0, 4.05), mat("moss"))
    for y in (0.7, 1.4):
        box("Thwart", (1.3, 0.22, 0.05), (0, y, 0.28), mat("driftwood", -0.1))
    box("Fishbox", (0.6, 0.4, 0.3), (0.2, 2.0, 0.05), mat("driftwood", -0.3))
    export("moored_boat")


def build_smokehouse() -> None:
    """Fish smokehouse: stone plinth, tarred plank walls, a louvred smoke vent on the ridge,
    fish hung under the eave and a woodpile. ~2.4 × 2.0 m footprint, front (door) at -Y."""
    reset()
    rng = random.Random(5)
    box("Plinth", (2.5, 2.1, 0.4), (0, 0, 0), mat("slate", -0.1))
    tar = mat("driftwood", -0.55)
    for i in range(9):
        x = -1.1 + i * 0.275
        box(f"Board{i}", (0.26, 1.9, 1.5 + rng.uniform(-0.04, 0.04)), (x, 0, 0.4), tar if i % 3 else mat("driftwood", -0.45))
    box("Walls", (2.3, 1.9, 1.5), (0, 0, 0.4), mat("driftwood", -0.5))
    box("Door", (0.7, 0.06, 1.2), (0.45, -0.97, 0.4), mat("ink", 0.1))
    bp.prism("Roof", 2.8, 2.5, 1.2, (0, 0, 1.9), mat("slate", -0.25)).rotation_euler.z = math.pi / 2
    box("VentBase", (0.7, 0.5, 0.35), (0, 0, 2.85), mat("driftwood", -0.5))
    bp.prism("VentRoof", 0.95, 0.75, 0.3, (0, 0, 3.2), mat("coal", -0.2)).rotation_euler.z = math.pi / 2
    box("Ember", (0.5, 0.52, 0.08), (0, 0, 2.97), mat("ember", 0.0, emissive=True))
    beam("FishLine", (-1.3, -1.2, 1.85), (0.05, -1.2, 1.85), 0.03, mat("driftwood", -0.2))
    for i in range(5):
        x = -1.2 + i * 0.28
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.07, radius2=0.0, depth=0.42,
                                        location=(x, -1.2, 1.6), rotation=(math.pi, 0, 0.3))
        bp.finish(bpy.context.active_object, mat("kindle", -0.35) if i % 2 else mat("bone", -0.3))
    for j in range(3):
        for i in range(4 - j):
            beam("Log", (1.32, -0.85 + i * 0.25 + j * 0.12, 0.11 + j * 0.2), (1.82, -0.85 + i * 0.25 + j * 0.12, 0.11 + j * 0.2),
                 0.2, mat("driftwood", (-0.3, -0.1)[(i + j) % 2]))
    export("smokehouse")


def build_barrel() -> None:
    reset()
    _barrel((0, 0, 0), mat("driftwood", -0.2))
    export("barrel")


def _barrel(loc, wood, lying=False):
    x, y, z = loc
    parts = [cyl("BarrelLow", 0.25, 0.3, 0.4, 8, (0, 0, 0), wood), cyl("BarrelHigh", 0.3, 0.25, 0.4, 8, (0, 0, 0.4), wood)]
    for hz in (0.1, 0.4, 0.68):
        parts.append(cyl("Hoop", 0.3 if hz == 0.4 else 0.275, 0.3 if hz == 0.4 else 0.275, 0.05, 8, (0, 0, hz), mat("slate", -0.3)))
    parts.append(cyl("Lid", 0.22, 0.22, 0.02, 8, (0, 0, 0.8), mat("driftwood", -0.4)))
    for p in parts:
        if lying:
            p.location = Vector((p.location.x, p.location.z - 0.4, 0.3 + p.location.y))
            p.rotation_euler.x = -math.pi / 2
        p.location += Vector((x, y, z))
    return parts


def build_barrels() -> None:
    """Three upright barrels and one on its side — a harbor cluster (~1.4 m across)."""
    reset()
    _barrel((-0.3, 0.2, 0), mat("driftwood", -0.2))
    _barrel((0.33, 0.25, 0), mat("coal", -0.25))
    _barrel((0.0, -0.35, 0), mat("driftwood", -0.35))
    _barrel((0.85, -0.35, 0), mat("driftwood", -0.1), lying=True)
    export("barrels")


def build_crate() -> None:
    """0.8 m crate (same size as the procedural `crate`) with darker corner frames."""
    reset()
    box("Body", (0.76, 0.76, 0.76), (0, 0, 0.02), mat("driftwood", -0.05))
    dark = mat("driftwood", -0.35)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Post", (0.08, 0.08, 0.8), (sx * 0.36, sy * 0.36, 0), dark)
    for z in (0.0, 0.72):
        for sy in (-1, 1):
            box("RailX", (0.8, 0.08, 0.08), (0, sy * 0.36, z), dark)
            box("RailY", (0.08, 0.8, 0.08), (sy * 0.36, 0, z), dark)
    beam("Brace", (-0.34, -0.405, 0.08), (0.34, -0.405, 0.72), 0.05, dark, width=0.09)
    beam("Brace", (0.405, -0.34, 0.08), (0.405, 0.34, 0.72), 0.05, dark, width=0.09)
    export("crate")


# --- Village -------------------------------------------------------------------------------

def _lantern_post(glass: str) -> None:
    """2.4 m post with a crossarm reaching to -Y (Godot +Z) and a lantern hung from it:
    glass centre at (0, -0.58, 1.85) — where the procedural signal_lantern's light sits."""
    rod("Post", (0, 0, 0), (0, 0, 2.4), 0.11, mat("driftwood", -0.2), verts=6, r_end=0.08)
    beam("Arm", (0, 0.05, 2.3), (0, -0.72, 2.3), 0.08, mat("driftwood", -0.2))
    beam("Strut", (0, 0, 1.95), (0, -0.38, 2.28), 0.05, mat("driftwood", -0.3))
    beam("Hook", (0, -0.58, 2.3), (0, -0.58, 2.14), 0.02, mat("ink", 0.2))
    cyl("Cap", 0.2, 0.02, 0.16, 6, (0, -0.58, 2.0), mat("ink", 0.15))
    cyl("Glass", 0.13, 0.13, 0.3, 6, (0, -0.58, 1.7), mat(glass, 0.0, emissive=True))
    cyl("Base", 0.16, 0.16, 0.05, 6, (0, -0.58, 1.66), mat("ink", 0.15))
    for i in range(3):
        a = math.tau * i / 3
        beam("Frame", (math.cos(a) * 0.14, -0.58 + math.sin(a) * 0.14, 1.68),
             (math.cos(a) * 0.14, -0.58 + math.sin(a) * 0.14, 2.02), 0.025, mat("ink", 0.15))


def build_lantern_post() -> None:
    reset()
    _lantern_post("kindle")
    export("lantern_post")


def build_signal_lantern() -> None:
    """Mara's ferry signal: the lantern post with moss-green glass ("passengers waiting")."""
    reset()
    _lantern_post("moss")
    cyl("Tie", 0.12, 0.12, 0.12, 6, (0, 0, 1.2), mat("moss", -0.3))
    export("signal_lantern")


def build_fence() -> None:
    """3 m weathered fence section along X: three leaning posts, two sagging rails."""
    reset()
    rng = random.Random(3)
    wood = mat("driftwood", -0.15)
    tops = []
    for x in (-1.45, 0.0, 1.45):
        lean = (rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06))
        top = (x + lean[0], lean[1], 1.0 + rng.uniform(-0.08, 0.05))
        rod("Post", (x, 0, 0), top, 0.07, wood, verts=5, r_end=0.055)
        tops.append(top)
    for h in (0.45, 0.85):
        for a, b in ((tops[0], tops[1]), (tops[1], tops[2])):
            beam("Rail", (a[0], a[1] - 0.06, h + rng.uniform(-0.03, 0.03)), (b[0], b[1] - 0.06, h - 0.05), 0.05,
                 mat("driftwood", rng.uniform(-0.3, 0.0)), width=0.1)
    export("fence")


def build_stool() -> None:
    """Dunstan's three-legged stool (same size as the procedural `stool`): seat top 0.49 m,
    a darker dent worn into it by a big man."""
    reset()
    wood = mat("driftwood", -0.05)
    for i in range(3):
        a = math.tau * i / 3 + 0.3
        rod("Leg", (math.cos(a) * 0.13, math.sin(a) * 0.13, 0.43), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.0),
            0.035, mat("driftwood", -0.25), verts=4)
    rod("Rung", (0.12, 0.05, 0.18), (-0.1, 0.09, 0.18), 0.02, mat("driftwood", -0.25), verts=4)
    cyl("Seat", 0.24, 0.22, 0.07, 7, (0, 0, 0.42), wood)
    cyl("Dent", 0.14, 0.13, 0.012, 7, (0.01, 0.02, 0.485), mat("driftwood", -0.3))
    export("stool")


def build_cups() -> None:
    """An upturned half-crate with two cups set out on it (the gull-burn aftermath)."""
    reset()
    box("HalfCrate", (0.5, 0.4, 0.36), (0, 0, 0), mat("driftwood", -0.15))
    beam("Slat", (-0.25, -0.205, 0.12), (0.25, -0.205, 0.12), 0.02, mat("driftwood", -0.4), width=0.06)
    for x in (-0.11, 0.12):
        cyl("Cup", 0.04, 0.05, 0.1, 7, (x, -0.02, 0.36), mat("bone", -0.05))
        cyl("Tea", 0.042, 0.042, 0.005, 7, (x, -0.02, 0.44), mat("coal", -0.55))
    beam("Handle", (0.175, -0.02, 0.38), (0.175, -0.02, 0.44), 0.02, mat("bone", -0.05), width=0.03)
    export("cups")


def _rack(net_colour: str, whole: bool) -> None:
    """Drying frame: two posts (x ±1.1) and a crossbar at 1.76 m. `whole` hangs a full net with
    a cork line; otherwise a small patch begun from the middle, tied up by one line."""
    wood = mat("driftwood", -0.1)
    for x in (-1.1, 1.1):
        rod("Post", (x, 0, 0), (x, 0, 1.82), 0.07, wood, verts=5, r_end=0.055)
        beam("Foot", (x, -0.35, 0.0), (x, 0.35, 0.0), 0.08, mat("driftwood", -0.3))
    beam("Bar", (-1.25, 0, 1.76), (1.25, 0, 1.76), 0.07, wood)
    strands = mat(net_colour, -0.1)
    if whole:
        net("Net", 2.0, 1.28, (0, 0, 1.08), strands, sag=0.12)
        for i in range(9):
            box("Cork", (0.07, 0.07, 0.07), (-0.96 + i * 0.24, 0.12, 0.4), mat("coal", -0.1))
        rod("Line", (-1.0, 0.0, 1.72), (1.0, 0.0, 1.72), 0.02, mat("driftwood", 0.2), verts=4)
    else:
        rod("Tie", (0, 0, 1.74), (0, 0, 1.25), 0.012, mat("driftwood", 0.2), verts=4)
        net("Patch", 0.66, 0.5, (0, 0, 0.98), strands, spacing=0.11, sag=0.04)
        # The bare frame reads emptier than the whole net: a few loose strands where a corner was cut.
        beam("Cut", (-1.1, 0, 1.62), (-0.9, 0.02, 1.38), 0.018, strands)
        beam("Cut", (-1.1, 0, 1.55), (-1.02, 0.03, 1.3), 0.018, strands)


def build_net_racks() -> None:
    for colour, suffix in (("slate", ""), ("pine", "_pine")):
        reset()
        _rack(colour, True)
        export("net_rack" + suffix)
        reset()
        _rack(colour, False)
        export("net_frame" + suffix)


# --- Shore & greenery ----------------------------------------------------------------------

def build_driftwood_log() -> None:
    """A bleached log lying along X (~2.4 m) with a snapped branch."""
    reset()
    wood = mat("driftwood", 0.25)
    rod("Log", (-1.2, 0.05, 0.15), (1.2, -0.08, 0.2), 0.17, wood, verts=6, r_end=0.12)
    rod("Branch", (0.4, -0.05, 0.25), (0.85, -0.5, 0.55), 0.06, wood, verts=5, r_end=0.03)
    cyl("Root", 0.26, 0.2, 0.34, 6, (-1.3, 0.05, 0.0), mat("driftwood", 0.1))
    export("driftwood_log")


def build_wreck() -> None:
    """Shingle Point's landmark: the ribs of an old boat, keel half-buried in the shingle,
    stem post still standing. ~6.5 m along Y (bow at -Y), no deck, several ribs broken."""
    reset()
    rng = random.Random(21)
    bleached, dark = mat("driftwood", 0.15), mat("driftwood", -0.3)
    beam("Keel", (0, -3.1, 0.05), (0, 3.0, 0.12), 0.2, dark, width=0.24)
    rod("Stem", (0, -3.1, 0.05), (0, -3.55, 2.3), 0.1, bleached, verts=5, r_end=0.06)
    rod("Sternpost", (0, 3.0, 0.1), (0, 3.2, 1.2), 0.1, bleached, verts=5, r_end=0.07)
    for i in range(8):
        y = -2.5 + i * 0.7
        t = i / 7
        half = 1.35 * math.sin(math.pi * (0.15 + 0.75 * t))
        height = 1.7 * (0.75 + 0.25 * math.sin(math.pi * t))
        for side in (-1, 1):
            broken = rng.random() < 0.35
            segs = 2 if broken else 4
            prev = Vector((0, y, 0.12))
            for k in range(1, segs + 1):
                a = k / 4 * math.pi / 2
                p = Vector((side * half * math.sin(a), y, 0.12 + height * (1 - math.cos(a)) * 1.1))
                if k == 4:
                    p.x *= 1.08  # flare at the gunwale
                beam(f"Rib{i}", prev, p, 0.1, bleached if (i + k) % 3 else dark, width=0.14)
                prev = p
    beam("Strake", (-1.2, -1.8, 1.0), (-1.3, 1.6, 1.25), 0.07, dark, width=0.2)
    export("wreck")


def build_reeds() -> None:
    """A clump of reeds and three bulrush heads (~1.2 m); no collider needed."""
    reset()
    rng = random.Random(9)
    for i in range(12):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 0.35)
        base = Vector((math.cos(a) * r, math.sin(a) * r, 0))
        tip = base + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), rng.uniform(0.6, 1.25)))
        shade = rng.choice((("moss", -0.1), ("moss", 0.15), ("driftwood", -0.05), ("pine", 0.1)))
        rod(f"Reed{i}", base, tip, 0.035, mat(*shade), verts=3, r_end=0.0)
        if i < 3:
            head = base + (tip - base) * 0.85
            rod("Bulrush", head, head + (tip - base).normalized() * 0.16, 0.035, mat("coal", -0.5), verts=5)
    export("reeds")


def build_grass() -> None:
    """A low tuft of coarse dune grass (~0.5 m)."""
    reset()
    rng = random.Random(4)
    for i in range(9):
        a = rng.uniform(0, math.tau)
        base = Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0))
        tip = base + Vector((math.cos(a) * rng.uniform(0.1, 0.3), math.sin(a) * rng.uniform(0.1, 0.3), rng.uniform(0.3, 0.55)))
        rod(f"Blade{i}", base, tip, 0.05, mat("moss", rng.uniform(-0.2, 0.25)), verts=3, r_end=0.0)
    export("grass")


def build_ferry() -> None:
    """The Tidewright ferry *Slow Mercy* (9 m), origin at the WATERLINE like moored_boat:
    broad tide-blue hull with a bone stripe, a plank deckhouse aft with a slate roof and
    moss-green windows, one mast with a furled sail and the green masthead lantern, a
    bone horn on the deckhouse roof, fenders and a boarding plank on the port side (+X)."""
    reset()
    st = hull_stations(9.0, 1.6, 1.3, 0.8, stations=11, transom=0.7)
    hull("Hull", st, 1.3, 0.8, mat("tide", -0.25))
    gunwale("Rail", st, mat("driftwood", -0.35), thick=0.1)
    gunwale("Stripe", st, mat("bone", -0.1), thick=0.08, drop=0.2)
    gunwale("Boot", st, mat("abyss", -0.1), thick=0.12, drop=0.62)
    deck("Deck", st, 10, mat("driftwood", -0.1), below=0.12)
    # Deckhouse aft: planked walls, slate roof, a door forward and moss-green windows.
    box("House", (2.0, 2.2, 1.35), (0, 2.1, 0.68), mat("driftwood", -0.35))
    bp.prism("HouseRoof", 2.3, 2.5, 0.45, (0, 2.1, 2.03), mat("slate", -0.25))
    box("HouseDoor", (0.6, 0.05, 1.05), (0, 0.98, 0.68), mat("ink", 0.2))
    for x in (-1.01, 1.01):
        for y in (1.6, 2.6):
            box("Window", (0.04, 0.45, 0.35), (x, y, 1.35), mat("moss", 0.1, emissive=True))
    # The horn: a long bone horn on a post on the roof, flaring to the bow.
    rod("HornPost", (0.55, 2.6, 2.2), (0.55, 2.6, 2.6), 0.04, mat("ink", 0.2))
    rod("Horn", (0.55, 3.1, 2.62), (0.55, 1.9, 2.72), 0.05, mat("bone", -0.1), verts=6, r_end=0.2)
    # Mast, boom, furled sail, stays and the green lantern at the masthead.
    rod("Mast", (0, -1.2, 0.6), (0, -1.2, 7.4), 0.1, mat("driftwood", -0.25), r_end=0.07)
    rod("Yard", (-1.4, -1.2, 6.2), (1.4, -1.2, 6.2), 0.05, mat("driftwood", -0.25))
    rod("Sail", (-1.3, -1.12, 6.05), (1.3, -1.12, 6.05), 0.17, mat("driftwood", 0.2), verts=6, r_end=0.12)
    beam("Stay", (0, -1.2, 7.3), (0, -4.6, 1.3), 0.025, mat("ink", 0.2))
    beam("Stay", (0, -1.2, 7.3), (0, 4.5, 0.95), 0.025, mat("ink", 0.2))
    for x in (-1.45, 1.45):
        beam("Shroud", (0, -1.2, 6.9), (x, -0.9, 0.95), 0.02, mat("ink", 0.2))
    cyl("LanternCap", 0.18, 0.05, 0.14, 6, (0, -1.2, 7.55), mat("ink", 0.2))
    cyl("LanternGlass", 0.12, 0.12, 0.2, 6, (0, -1.2, 7.35), mat("moss", 0.1, emissive=True))
    box("Pennant", (0.02, 0.6, 0.2), (0, -0.85, 7.25), mat("bone", -0.1))
    # Cargo and gear on the foredeck: crates, a coil, barrels.
    box("Crate", (0.6, 0.6, 0.5), (-0.6, -2.6, 0.7), mat("driftwood", -0.25))
    box("Crate", (0.5, 0.5, 0.4), (-0.55, -2.0, 0.7), mat("driftwood", -0.25))
    cyl("Coil", 0.3, 0.3, 0.12, 8, (0.6, -2.4, 0.7), mat("driftwood", 0.2))
    cyl("Barrel", 0.24, 0.24, 0.6, 8, (0.7, 0.3, 0.7), mat("driftwood", -0.25))
    # Fenders along the port side (the dock side) and the boarding plank.
    for y in (-2.2, -0.5, 1.2, 2.9):
        cyl("Fender", 0.13, 0.13, 0.45, 6, (1.68, y, 0.2), mat("ink", 0.2))
    beam("Plank", (1.4, 0.2, 0.9), (2.9, 0.2, 0.55), 0.06, mat("driftwood", 0.2), width=0.55)
    export("ferry")


def build_bundle() -> None:
    """Pell's travelling bundle: a sailcloth sack tied off with cord, a net-needle poking out
    and a tin cup hung from the knot. ~0.5 m tall."""
    reset()
    cloth = mat("bone", -0.15)
    cyl("Sack", 0.2, 0.24, 0.3, 7, (0, 0, 0), cloth)
    cyl("SackTop", 0.24, 0.08, 0.16, 7, (0, 0, 0.3), cloth)
    cyl("Tie", 0.09, 0.09, 0.05, 6, (0, 0, 0.42), mat("coal", -0.1))
    cyl("Ears", 0.1, 0.02, 0.1, 5, (0, 0, 0.46), cloth)
    box("Patch", (0.12, 0.02, 0.1), (0.05, -0.22, 0.14), mat("tide", 0.0))
    beam("Needle", (-0.08, 0.02, 0.3), (-0.14, 0.04, 0.62), 0.03, mat("driftwood", 0.2), width=0.04)
    cyl("Cup", 0.05, 0.045, 0.08, 6, (0.14, -0.1, 0.33), mat("slate", 0.2))
    export("bundle")


# --- Gull's Head ---------------------------------------------------------------------------

def build_beacon_lit() -> None:
    """The Gull's Beacon's lit lantern room, placed over gull_beacon.glb: glowing glass inside
    the lantern (z 4.14–5.0) with iron mullions, and a flame core. Replaces `beacon_light`."""
    reset()
    cyl("Glass", 0.73, 0.73, 0.86, 8, (0, 0, 4.14), mat("kindle", 0.0, emissive=True), math.pi / 8)
    cyl("Flame", 0.22, 0.0, 0.55, 5, (0, 0, 4.2), mat("ember", 0.0, emissive=True))
    for i in range(8):
        a = math.tau * i / 8
        beam(f"Mullion{i}", (math.cos(a) * 0.75, math.sin(a) * 0.75, 4.12), (math.cos(a) * 0.75, math.sin(a) * 0.75, 5.02),
             0.06, mat("ink", 0.1))
    cyl("Rail", 1.18, 1.18, 0.04, 8, (0, 0, 4.62), mat("ink", 0.1))
    for i in range(8):
        a = math.tau * (i + 0.5) / 8
        beam(f"Stanchion{i}", (math.cos(a) * 1.12, math.sin(a) * 1.12, 4.12), (math.cos(a) * 1.12, math.sin(a) * 1.12, 4.66),
             0.04, mat("ink", 0.1))
    export("beacon_lit")


BUILDERS = [build_dock, build_rowboat, build_rowboat_upturned, build_moored_boat, build_smokehouse, build_barrel,
            build_barrels, build_crate, build_lantern_post, build_signal_lantern, build_fence, build_stool, build_cups,
            build_net_racks, build_driftwood_log, build_wreck, build_reeds, build_grass, build_beacon_lit,
            build_ferry, build_bundle]

if __name__ == "__main__":
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    for build in BUILDERS:
        if not only or build.__name__.removeprefix("build_") in only:
            build()
