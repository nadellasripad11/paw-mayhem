# Renders every blaster from src/ReplicatedStorage/Shared/Character/BlasterDesigns.json
# (the same data the game builds them from) into tools/blender/preview_blasters.png.
#   blender --background --python tools/blender/preview_blasters.py
import bpy
import bmesh
import json
import math
import os
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
DATA = json.load(open(os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Character", "BlasterDesigns.json")))
OUT = os.path.join(HERE, "preview_blasters.png")

C3 = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox -> Blender axes


def R(x, y, z):
    return Vector((x, -z, y))


def rot_r(rx, ry, rz):
    def m(axis, a):
        return Matrix.Rotation(math.radians(a), 3, axis)
    return C3 @ (m("X", rx) @ m("Y", ry) @ m("Z", rz)) @ C3.inverted()


def srgb(c):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), 1)


MATS = {}


def material(rgb, kind, alpha):
    key = (tuple(rgb), kind, alpha)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new("m%d" % len(MATS))
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = srgb(rgb)
    b.inputs["Roughness"].default_value = 0.38
    if kind == "neon":
        b.inputs["Emission Color"].default_value = srgb(rgb)
        b.inputs["Emission Strength"].default_value = 3.0
    if kind == "glass" or alpha > 0:
        b.inputs["Alpha"].default_value = 1 - alpha
        b.inputs["Roughness"].default_value = 0.05
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    MATS[key] = m
    return m


def place(o, piece, offset):
    rot = piece.get("rot", [0, 0, 0])
    m = Matrix.Translation(offset + R(*piece["pos"])) @ rot_r(*rot).to_4x4()
    o.data.transform(m)


def add_mesh(verts, faces):
    me = bpy.data.meshes.new("p")
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new("p", me)
    bpy.context.collection.objects.link(o)
    return o


def cylinder_x(length, d):
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=d / 2, depth=length)
    o = bpy.context.active_object
    o.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))  # axis Z -> X
    return o


def sphere(d):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=d / 2)
    return bpy.context.active_object


def build_piece(piece, pal, offset):
    rgb = pal[piece["c"]]
    kind = piece.get("m", "")
    alpha = piece.get("t", 0)
    k = piece["k"]
    objs = []
    if k == "pill":
        body = cylinder_x(max(0.01, piece["len"] - piece["d"]), piece["d"])
        objs.append(body)
        for s in (-1, 1):
            b = sphere(piece["d"])
            b.data.transform(Matrix.Translation(Vector((s * (piece["len"] - piece["d"]) / 2, 0, 0))))
            objs.append(b)
    elif k == "cyl":
        objs.append(cylinder_x(piece["len"], piece["d"]))
    elif k == "ball":
        objs.append(sphere(piece["d"]))
    elif k == "box":
        sx, sy, sz = piece["size"]
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.active_object
        o.data.transform(Matrix.Diagonal((sx, sz, sy, 1)))
        objs.append(o)
    elif k == "wedge":
        sx, sy, sz = piece["size"]
        # Roblox wedge: full bottom, full back (+Z) face, slope down to the front.
        pts = [(-sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, -sz / 2), (sx / 2, -sy / 2, sz / 2), (-sx / 2, -sy / 2, sz / 2),
               (-sx / 2, sy / 2, sz / 2), (sx / 2, sy / 2, sz / 2)]
        verts = [tuple(R(*p)) for p in pts]
        o = add_mesh(verts, [(0, 1, 2, 3), (3, 2, 5, 4), (0, 3, 4), (1, 5, 2), (0, 4, 5, 1)])
        objs.append(o)
    for o in objs:
        place(o, piece, offset)
        o.data.materials.append(material(rgb, kind, alpha))
        for poly in o.data.polygons:
            poly.use_smooth = k in ("pill", "cyl", "ball")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "CYCLES"
    if scene.render.engine == "CYCLES":
        scene.cycles.samples = 32
    scene.render.resolution_x, scene.render.resolution_y = 1600, 700
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = srgb((28, 36, 60))
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9

    order = ["PawBlaster", "Starfall", "BoomPaw", "RapidPaw", "FrostBlaster",
             "VoidCannon", "BubbleBlaster", "GoldenPurr", "CometClaw", "PurrfectStorm"]
    for i, wid in enumerate(order):
        pal = {k: v for k, v in DATA["palettes"][wid].items()}
        col, row = i % 5, i // 5
        offset = Vector((col * 6.2, 0, -row * 4.2))
        for piece in DATA["designs"][wid] + DATA["grip"]:
            build_piece(piece, pal, offset)

    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(30))
    scene.collection.objects.link(sun)
    fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
    fill.data.energy = 1.0
    fill.rotation_euler = (math.radians(-60), 0, math.radians(200))
    scene.collection.objects.link(fill)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 33
    scene.collection.objects.link(cam)
    scene.camera = cam
    target = Vector((12.4, 0, -1.8))
    cam.location = target + Vector((-6, -30, 9))
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = (target - cam.location).to_track_quat("-Z", "Y")
    scene.render.filepath = OUT
    bpy.ops.render.render(write_still=True)
    print("BLASTERS OK", OUT)


main()
