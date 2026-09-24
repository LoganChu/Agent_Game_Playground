"""Builds Emberwake's low-poly environment props and exports them as .glb.

Run either way (re-runnable; overwrites the outputs):
    blender --background --python tools/blender/build_props.py
    .tools/bin/blender-py tools/blender/build_props.py      # bpy module from tools/setup.sh

Outputs to assets/models/<name>.glb. Every model has its origin at the base centre, is
flat-shaded, uses palette colours from docs/GAME_DESIGN.md, and stays well under 5 MB.
"""
import math
import os
import random

import bpy  # must be imported before bmesh when running as the bpy module
import bmesh  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "models")

PALETTE = {
    "ember": "#F2A541",
    "kindle": "#F4D58D",
    "coal": "#B5452F",
    "moss": "#5E8C61",
    "pine": "#2F5D50",
    "tide": "#3D7EA6",
    "slate": "#6B7280",
    "driftwood": "#C9B28F",
    "silverfog": "#C7CCD4",
    "ink": "#1B1B2F",
    "bone": "#EDE6D6",
}


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(hex_color: str) -> tuple:
    h = hex_color.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


_materials: dict = {}


def material(name: str, emissive: bool = False) -> bpy.types.Material:
    key = (name, emissive)
    if key in _materials:
        return _materials[key]
    mat = bpy.data.materials.new(f"{name}{'_glow' if emissive else ''}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgba = hex_rgba(PALETTE[name])
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.95
    if emissive:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = 2.0
    _materials[key] = mat
    return mat


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def finish(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def cone(name, r1, r2, depth, verts, loc, mat, rot_z=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth,
                                    location=(loc[0], loc[1], loc[2] + depth / 2), rotation=(0, 0, rot_z))
    obj = bpy.context.active_object
    obj.name = name
    return finish(obj, mat)


def box(name, size, loc, mat, rot_z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0], loc[1], loc[2] + size[2] / 2), rotation=(0, 0, rot_z))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, mat)


def prism(name, width, depth, height, loc, mat):
    """Triangular roof prism: ridge along the Y axis."""
    w, d = width / 2, depth / 2
    verts = [(-w, -d, 0), (w, -d, 0), (0, -d, height), (-w, d, 0), (w, d, 0), (0, d, height)]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    return finish(obj, mat)


def rock(name, radius, loc, mat, rng):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for v in bm.verts:
        v.co *= 1.0 + rng.uniform(-0.18, 0.18)
        v.co.z *= 0.65
    bm.to_mesh(obj.data)
    bm.free()
    obj.rotation_euler.z = rng.uniform(0, math.tau)
    return finish(obj, mat)


def export(name: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, f"{name}.glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False,
                              export_apply=True, export_yup=True)
    print(f"[build_props] wrote {path} ({os.path.getsize(path) // 1024} KB)")


def build_pine_tree() -> None:
    reset_scene()
    cone("Trunk", 0.18, 0.12, 1.0, 6, (0, 0, 0), material("driftwood"))
    for i, (r, h, z) in enumerate([(1.2, 1.5, 0.8), (0.95, 1.3, 1.6), (0.65, 1.1, 2.4)]):
        cone(f"Tier{i}", r, 0.0, h, 7, (0, 0, z), material("pine" if i != 1 else "moss"), rot_z=i * 0.4)
    export("pine_tree")


def build_rock_cluster() -> None:
    reset_scene()
    rng = random.Random(7)
    rock("RockBig", 0.9, (0, 0, 0.3), material("slate"), rng)
    rock("RockMid", 0.55, (0.8, 0.5, 0.2), material("slate"), rng)
    rock("RockSmall", 0.35, (-0.6, 0.7, 0.1), material("silverfog"), rng)
    export("rock_cluster")


def build_stilt_house() -> None:
    reset_scene()
    for x in (-1.1, 1.1):
        for y in (-0.9, 0.9):
            cone("Stilt", 0.09, 0.09, 1.0, 5, (x, y, 0), material("slate"))
    box("Deck", (3.0, 2.6, 0.12), (0, 0, 1.0), material("driftwood"))
    box("Walls", (2.6, 2.2, 1.6), (0, 0, 1.12), material("driftwood"))
    prism("Roof", 3.0, 2.7, 1.1, (0, 0, 2.72), material("coal"))
    box("Door", (0.6, 0.06, 1.1), (-0.5, -1.12, 1.12), material("ink"))
    box("Window", (0.5, 0.06, 0.45), (0.6, -1.12, 1.7), material("kindle", emissive=True))
    box("Chimney", (0.3, 0.3, 0.8), (0.8, 0.6, 3.0), material("slate"))
    export("stilt_house")


def build_gull_beacon() -> None:
    reset_scene()
    cone("Tower", 1.3, 0.9, 4.0, 8, (0, 0, 0), material("slate"))
    cone("Band", 1.0, 1.0, 0.15, 8, (0, 0, 2.6), material("bone"))
    cone("Gallery", 1.15, 1.15, 0.12, 8, (0, 0, 4.0), material("driftwood"))
    cone("Lantern", 0.7, 0.7, 0.9, 8, (0, 0, 4.12), material("ink"))
    cone("Roof", 1.0, 0.0, 0.8, 8, (0, 0, 5.02), material("coal"))
    cone("Finial", 0.06, 0.06, 0.5, 4, (0, 0, 5.8), material("slate"))
    prism("Gull", 0.5, 0.08, 0.12, (0, 0, 6.3), material("bone"))
    box("Door", (0.7, 0.1, 1.2), (0, -1.25, 0), material("ink"))
    export("gull_beacon")


if __name__ == "__main__":
    build_pine_tree()
    build_rock_cluster()
    build_stilt_house()
    build_gull_beacon()
