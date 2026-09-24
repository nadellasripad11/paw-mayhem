# Paw Mayhem cat — procedural Blender model.
#
#   blender --background --python tools/blender/build_cat.py
#
# Builds the cat as separate smooth meshes (so Roblox can tint each one with
# the player's fur / outfit colours and the rig can still animate them),
# exports them to assets/CatMeshes.fbx, writes the Lua layout table
# src/ReplicatedStorage/Shared/Character/CatMeshData.lua, and renders preview
# images to tools/blender/preview_*.png.
#
# Every piece is modelled in the local space of the rig part it attaches to
# ("anchor"), using Roblox axes: X right, Y up, -Z = the way the cat faces.
# R(x, y, z) converts a Roblox position to Blender's Z-up axes.

import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_FBX = os.path.join(ROOT, "assets", "CatMeshes.fbx")
OUT_LUA = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Character", "CatMeshData.lua")
OUT_PREVIEW = os.path.join(ROOT, "tools", "blender")

# ── axes ─────────────────────────────────────────────────────────────────────
C3 = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox -> Blender


def R(x, y, z):
    return Vector((x, -z, y))


def rb(v):
    """Blender vector -> Roblox tuple."""
    return (v.x, v.z, -v.y)


def rot_r(rx=0.0, ry=0.0, rz=0.0):
    """Roblox CFrame.Angles(rx, ry, rz) (degrees) as a Blender 3x3."""
    def rx_m(a):
        c, s = math.cos(a), math.sin(a)
        return Matrix(((1, 0, 0), (0, c, -s), (0, s, c)))

    def ry_m(a):
        c, s = math.cos(a), math.sin(a)
        return Matrix(((c, 0, s), (0, 1, 0), (-s, 0, c)))

    def rz_m(a):
        c, s = math.cos(a), math.sin(a)
        return Matrix(((c, -s, 0), (s, c, 0), (0, 0, 1)))

    m = rx_m(math.radians(rx)) @ ry_m(math.radians(ry)) @ rz_m(math.radians(rz))
    return C3 @ m @ C3.inverted()


# ── scene helpers ────────────────────────────────────────────────────────────
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_mods(obj):
    activate(obj)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def apply_transform(obj):
    activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def ellipsoid(center, radii, rot=None, seg=48, rings=32):
    """Roblox-space centre + (rx, ry, rz) radii."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1)
    o = bpy.context.active_object
    o.scale = (radii[0], radii[2], radii[1])
    o.location = R(*center)
    if rot is not None:
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = rot.to_quaternion()
        # rotation must wrap the scaled shape: bake scale first
    apply_transform(o)
    return o


def ellipsoid_rot(center, radii, rot3):
    """Ellipsoid whose axes follow rot3 (Blender 3x3 built with rot_r / frame)."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=1)
    o = bpy.context.active_object
    me = o.data
    # local axes: x = width, y = height (Roblox Y), z = depth (Roblox Z)
    s = Matrix.Diagonal((radii[0], radii[2], radii[1], 1.0))
    me.transform(s)
    m4 = rot3.to_4x4()
    me.transform(m4)
    me.transform(Matrix.Translation(R(*center)))
    return o


def cone_between(base, tip, r0, r1=0.0, verts=24):
    """Cone from Roblox point base to tip."""
    b, t = R(*base), R(*tip)
    d = t - b
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r0, radius2=r1, depth=d.length)
    o = bpy.context.active_object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.location = (b + t) / 2
    apply_transform(o)
    return o


def join(objs, name):
    objs = [o for o in objs if o]
    activate(objs[0])
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


def fuse(objs, name, voxel=0.02, smooth=6, tris=6000):
    """Union overlapping shapes into one smooth closed surface."""
    o = join(objs, name)
    rm = o.modifiers.new("remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = voxel
    rm.adaptivity = 0.0
    apply_mods(o)
    if smooth:
        sm = o.modifiers.new("smooth", "SMOOTH")
        sm.factor = 0.6
        sm.iterations = smooth
        apply_mods(o)
    finish(o, tris)
    return o


def finish(o, tris=6000):
    count = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if count > tris:
        dm = o.modifiers.new("decimate", "DECIMATE")
        dm.ratio = tris / count
        apply_mods(o)
    activate(o)
    bpy.ops.object.shade_smooth()


def frame_at(point, normal, up=Vector((0, 0, 1))):
    """3x3 whose Z = normal, Y ~ up, X = Y x Z (all Blender space)."""
    z = normal.normalized()
    x = up.cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x).normalized()
    return Matrix((x, y, z)).transposed()


def disc(point, normal, w, h, depth, lift, xoff=0.0, yoff=0.0, seg=40):
    """Flattened ellipsoid lying on a surface: w/h across it, depth along it."""
    f = frame_at(normal=normal, point=point)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=24, radius=1)
    o = bpy.context.active_object
    me = o.data
    me.transform(Matrix.Diagonal((w, h, depth, 1.0)))
    me.transform(f.to_4x4())
    center = point + normal.normalized() * lift + f.col[0] * xoff + f.col[1] * yoff
    me.transform(Matrix.Translation(center))
    return o


def tube(points, radius, name=None, taper=None):
    """Smooth tube through Blender-space points."""
    cu = bpy.data.curves.new(name or "tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p.x, p.y, p.z, 1)
        if taper:
            sp.points[i].radius = taper[i]
    sp.use_endpoint_u = True
    sp.order_u = 3
    o = bpy.data.objects.new(name or "tube", cu)
    bpy.context.collection.objects.link(o)
    activate(o)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def stick(obj, target, offset=0.01, thickness=0.012):
    """Wrap a flat shape onto target's surface and give it a little thickness."""
    sw = obj.modifiers.new("wrap", "SHRINKWRAP")
    sw.target = target
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "OUTSIDE_SURFACE"
    sw.offset = offset
    so = obj.modifiers.new("solid", "SOLIDIFY")
    so.thickness = thickness
    so.offset = 1.0
    apply_mods(obj)
    return obj


def flat_shape(verts, hit, normal, scale=1.0, subdiv=3):
    """A flat polygon (2D verts in the surface frame) placed at hit, subdivided round."""
    me = bpy.data.meshes.new("flat")
    me.from_pydata([(x * scale, y * scale, 0) for x, y in verts], [], [list(range(len(verts)))])
    o = bpy.data.objects.new("flat", me)
    bpy.context.collection.objects.link(o)
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = subdiv
    apply_mods(o)
    me.transform(frame_at(hit, normal).to_4x4())
    me.transform(Matrix.Translation(hit + normal.normalized() * 0.05))
    return o


class Surface:
    """Ray-cast helper to stick details onto a mesh."""

    def __init__(self, obj):
        self.bvh = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())

    def front(self, x, y):
        """Point + normal on the surface seen from the front at Roblox (x, y)."""
        origin = R(x, y, -5)
        hit, normal, _, _ = self.bvh.ray_cast(origin, Vector((0, -1, 0)))
        return hit, normal

    def toward(self, origin_r, dir_r):
        o = R(*origin_r)
        d = R(*dir_r) - R(0, 0, 0)
        hit, normal, _, _ = self.bvh.ray_cast(o, d.normalized())
        return hit, normal


PIECES = []  # (object, anchor)


def piece(obj, anchor):
    PIECES.append((obj, anchor))
    return obj


# ── HEAD (head-local; head centre = origin) ──────────────────────────────────
def build_head():
    parts = []
    parts.append(ellipsoid((0, 0.02, 0), (1.2, 0.97, 1.0)))
    for i in (-1, 1):
        # chubby lower cheeks
        parts.append(ellipsoid((0.6 * i, -0.38, -0.32), (0.5, 0.4, 0.46)))
        # soft cheek fur clumps sweeping out
        parts.append(cone_between((0.98 * i, -0.28, -0.16), (1.32 * i, -0.4, -0.1), 0.26, 0.08))
        parts.append(cone_between((0.9 * i, -0.5, -0.12), (1.14 * i, -0.7, -0.06), 0.22, 0.07))
        parts.append(cone_between((1.06 * i, -0.04, -0.04), (1.28 * i, 0.02, 0.0), 0.18, 0.07))
        # ears: flattened cones tilted outward
        ear = cone_between((0.62 * i, 0.55, 0.06), (1.02 * i, 1.72, 0.12), 0.5)
        ear.data.transform(Matrix.Translation(-R(0.8 * i, 1.1, 0.09)))
        ear.data.transform(rot_r(0, -10 * i, 0).to_4x4())
        # squash ear front-to-back (Roblox Z = Blender -Y)
        ear.data.transform(Matrix.Diagonal((1.0, 0.42, 1.0, 1.0)))
        ear.data.transform(Matrix.Translation(R(0.8 * i, 1.1, 0.09)))
        parts.append(ear)
    # top-of-head tuft
    parts.append(cone_between((0.0, 0.84, -0.08), (0.1, 1.24, -0.18), 0.2, 0.06))
    parts.append(cone_between((-0.16, 0.8, -0.1), (-0.3, 1.08, -0.16), 0.15, 0.05))
    head = fuse(parts, "HeadFur", voxel=0.02, smooth=10, tris=8000)
    piece(head, "Head")
    surf = Surface(head)

    # Inner ears (pink) + fluff (accent): on the front face of each ear.
    inner, fluff = [], []
    for i in (-1, 1):
        hit, n = surf.toward((0.86 * i, 1.12, -2), (0, 0, 1))
        if hit:
            o = disc(hit, n, 0.2, 0.42, 0.05, 0.0)
            o.data.transform(Matrix.Translation(-hit))
            o.data.transform(rot_r(0, 0, -20 * i).to_4x4())
            o.data.transform(Matrix.Translation(hit))
            inner.append(o)
        hit, n = surf.toward((0.72 * i, 0.82, -2), (0, 0, 1))
        if hit:
            fluff.append(cone_between(rb(hit - n * 0.02), rb(hit + n * 0.03 + R(0.04 * i, 0.24, 0) - R(0, 0, 0)), 0.09, 0.03))
            fluff.append(cone_between(rb(hit - n * 0.02 + R(0.09 * i, 0, 0) - R(0, 0, 0)), rb(hit + n * 0.03 + R(0.16 * i, 0.2, 0) - R(0, 0, 0)), 0.08, 0.03))
    piece(join(inner, "InnerEar"), "Head")
    finish(bpy.data.objects["InnerEar"])
    for o in fluff:
        bpy.data.objects.remove(o)  # pale ear tufts read as fangs at this scale

    # Eyes: layered discs following the head curve.
    layers = {"EyeWhite": [], "Iris": [], "IrisGlow": [], "Pupil": [], "Shine": []}
    for i in (-1, 1):
        hit, n = surf.front(0.5 * i, -0.04)
        up = Vector((0, 0, 1))
        layers["EyeWhite"].append(disc(hit, n, 0.34, 0.37, 0.12, -0.075))
        layers["Iris"].append(disc(hit, n, 0.3, 0.33, 0.045, 0.012))
        layers["IrisGlow"].append(disc(hit, n, 0.22, 0.13, 0.04, 0.028, yoff=-0.15))
        layers["Pupil"].append(disc(hit, n, 0.19, 0.22, 0.04, 0.036, yoff=0.02))
        # frame X points to the viewer's right: big shine upper-left, small lower-right
        layers["Shine"].append(disc(hit, n, 0.11, 0.12, 0.025, 0.062, xoff=-0.11, yoff=0.13))
        layers["Shine"].append(disc(hit, n, 0.05, 0.05, 0.02, 0.058, xoff=0.12, yoff=-0.15))
    for name, objs in layers.items():
        o = join(objs, name)
        finish(o, 3000)
        piece(o, "Head")

    # Brows
    brows = []
    for i in (-1, 1):
        pts = []
        for t in (0.0, 0.5, 1.0):
            x = (0.38 + 0.24 * t) * i
            y = 0.4 + 0.05 * math.sin(t * math.pi) - 0.04 * t
            hit, n = surf.front(x, y)
            pts.append(hit + n * 0.02)
        brows.append(tube(pts, 0.035, "brow"))
    o = join(brows, "Brows")
    finish(o, 1500)
    piece(o, "Head")

    # Forehead mark: a rounded triangle pointing down, laid on the forehead.
    hit, n = surf.front(0, 0.5)
    tri = flat_shape([(-0.2, 0.12), (0.2, 0.12), (0.0, -0.24)], hit, n, subdiv=3)
    stick(tri, head, offset=0.006, thickness=0.012)
    tri.name = "ForeheadMark"
    tri.data.name = "ForeheadMark"
    finish(tri, 1500)
    piece(tri, "Head")

    # Muzzle puffs + chin (accent)
    muz = []
    for i in (-1, 1):
        hit, n = surf.front(0.12 * i, -0.42)
        muz.append(disc(hit, n, 0.17, 0.12, 0.1, 0.0))
    hit, n = surf.front(0, -0.56)
    muz.append(disc(hit, n, 0.12, 0.06, 0.07, 0.0))
    piece(fuse(muz, "Muzzle", voxel=0.012, smooth=3, tris=2500), "Head")

    # Nose: small rounded triangle pointing down
    hit, n = surf.front(0, -0.28)
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=0.24, radius2=0, depth=0.12)
    nose = bpy.context.active_object
    nose.data.transform(Matrix.Diagonal((1.3, 1.0, 1.0, 1.0)))
    nose.data.transform(Matrix.Rotation(math.radians(-90), 4, "Z"))
    nose.data.transform(frame_at(hit, n).to_4x4())
    nose.data.transform(Matrix.Translation(hit + n * 0.02))
    sub = nose.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    apply_mods(nose)
    nose.name = "Nose"
    finish(nose)
    piece(nose, "Head")

    # Mouth ":3" — two little arcs under the nose (sits on the muzzle)
    msurf = Surface(bpy.data.objects["Muzzle"])
    arcs = []
    for i in (-1, 1):
        pts = []
        for k in range(5):
            a = math.pi * k / 4
            x = 0.06 * i + 0.055 * math.cos(a) * i
            y = -0.39 - 0.045 * math.sin(a)
            hit, n = msurf.front(x, y)
            if hit is None:
                hit, n = surf.front(x, y)
            pts.append(hit + n * 0.008)
        arcs.append(tube(pts, 0.016, "mouth"))
    o = join(arcs, "Mouth")
    finish(o, 1500)
    piece(o, "Head")

    # Blush
    bl = []
    for i in (-1, 1):
        hit, n = surf.front(0.78 * i, -0.3)
        bl.append(disc(hit, n, 0.17, 0.085, 0.03, 0.0))
    o = join(bl, "Blush")
    finish(o, 1500)
    piece(o, "Head")


# ── BODY (root-local) ─────────────────────────────────────────────────────────
def build_body():
    # Plain torso for outfits other than the hoodie.
    piece(fuse([ellipsoid((0, -0.2, 0), (0.65, 0.5, 0.5))], "Body", voxel=0.02, smooth=0, tris=3000), "Root")
    # Tee underneath
    shirt = fuse([ellipsoid((0, -0.2, -0.01), (0.6, 0.47, 0.47)), ellipsoid((0, 0.18, -0.08), (0.3, 0.1, 0.26))], "Shirt", voxel=0.02, smooth=2, tris=3000)
    piece(shirt, "Root")

    # Jacket: a shell around the tee, open down the front.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=40, radius=1)
    shell = bpy.context.active_object
    shell.data.transform(Matrix.Diagonal((0.67, 0.53, 0.53, 1.0)))
    shell.data.transform(Matrix.Translation(R(0, -0.2, 0)))
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    kill = []
    for face in bm.faces:
        c = face.calc_center_median()
        x, y, z = rb(c)
        half = 0.13 + (0.1 - y) * 0.12  # opening widens towards the hem
        if z < -0.15 and abs(x) < half and y < 0.2:
            kill.append(face)
        if y > 0.26:  # neck hole
            kill.append(face)
    bmesh.ops.delete(bm, geom=list(set(kill)), context="FACES")
    bm.to_mesh(shell.data)
    bm.free()
    so = shell.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.05
    so.offset = 1.0
    apply_mods(shell)
    parts = [shell]
    # Lapels folded back along the opening
    for i in (-1, 1):
        pts = [R(0.16 * i, 0.2, -0.47), R(0.2 * i, -0.05, -0.54), R(0.24 * i, -0.35, -0.52), R(0.27 * i, -0.6, -0.44)]
        parts.append(tube(pts, 0.05, "lapel"))
    # Collar roll + bunched hood behind the neck
    bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.1, major_segments=48, minor_segments=16)
    collar = bpy.context.active_object
    collar.data.transform(Matrix.Diagonal((1.15, 1.0, 1.0, 1.0)))
    collar.data.transform(Matrix.Translation(R(0, 0.26, 0.02)))
    parts.append(collar)
    parts.append(ellipsoid((0, 0.3, 0.36), (0.58, 0.28, 0.3)))
    parts.append(ellipsoid((0, 0.18, 0.46), (0.46, 0.24, 0.2)))
    jacket = fuse(parts, "Jacket", voxel=0.018, smooth=3, tris=9000)
    piece(jacket, "Root")
    jsurf = Surface(jacket)

    # Drawstrings with tips
    ssurf = Surface(shirt)
    strings = []
    for i in (-1, 1):
        pts = []
        for k, y in enumerate((0.16, 0.06, -0.04, -0.14)):
            hit, n = ssurf.front(0.14 * i + 0.012 * k * i, y)
            pts.append(hit + n * 0.035)
        strings.append(tube(pts, 0.022, "string"))
        hit, n = ssurf.front(0.19 * i, -0.2)
        strings.append(disc(hit, n, 0.035, 0.06, 0.035, 0.035))
    o = join(strings, "Drawstrings")
    finish(o, 2000)
    piece(o, "Root")

    # Dog tag on a little chain, resting on the tee
    tag = []
    hit, n = ssurf.front(0, -0.04)
    tag.append(disc(hit, n, 0.085, 0.12, 0.018, 0.03))
    for i in (-1, 1):
        pts = []
        for k in range(4):
            t = k / 3
            h2, n2 = ssurf.front(0.12 * i * (1 - t), 0.2 - t * 0.12)
            pts.append(h2 + n2 * 0.025)
        tag.append(tube(pts, 0.012, "chain"))
    o = join(tag, "DogTag")
    finish(o, 1500)
    piece(o, "Root")

    # Patch pocket (lower front, your right as you face the cat)
    hit, n = jsurf.toward((-0.44, -0.44, -2), (0, 0, 1))
    bpy.ops.mesh.primitive_cube_add(size=1)
    pocket = bpy.context.active_object
    pocket.data.transform(Matrix.Diagonal((0.3, 0.26, 0.04, 1.0)))
    bev = pocket.modifiers.new("bev", "BEVEL")
    bev.width = 0.03
    bev.segments = 3
    apply_mods(pocket)
    pocket.data.transform(frame_at(hit, n).to_4x4())
    pocket.data.transform(Matrix.Translation(hit + n * 0.02))
    pocket.name = "Pocket"
    finish(pocket)
    piece(pocket, "Root")

    # Crossbody strap (front + back) and satchel
    bag = []
    front = []
    for k in range(17):
        t = k / 16
        x = -0.5 + t * 1.02
        y = 0.2 - t * 0.74
        hit, n = jsurf.toward((x, y, -2), (0, 0, 1))
        front.append(hit + n * 0.06)
    bag.append(tube(front, 0.04, "strap"))
    back = []
    for k in range(17):
        t = k / 16
        x = -0.5 + t * 1.02
        y = 0.2 - t * 0.74
        hit, n = jsurf.toward((x, y, 2), (0, 0, -1))
        back.append(hit + n * 0.06)
    bag.append(tube(back, 0.04, "strap"))
    bpy.ops.mesh.primitive_cube_add(size=1)
    sat = bpy.context.active_object
    sat.data.transform(Matrix.Diagonal((0.44, 0.24, 0.38, 1.0)))
    bev = sat.modifiers.new("bev", "BEVEL")
    bev.width = 0.07
    bev.segments = 4
    apply_mods(sat)
    sat.data.transform(rot_r(0, -40, 0).to_4x4())
    sat.data.transform(Matrix.Translation(R(0.6, -0.56, -0.24)))
    bag.append(sat)
    bpy.ops.mesh.primitive_cube_add(size=1)
    flap = bpy.context.active_object
    flap.data.transform(Matrix.Diagonal((0.46, 0.26, 0.2, 1.0)))
    bev = flap.modifiers.new("bev", "BEVEL")
    bev.width = 0.06
    bev.segments = 4
    apply_mods(flap)
    flap.data.transform(rot_r(0, -40, 0).to_4x4())
    flap.data.transform(Matrix.Translation(R(0.6, -0.46, -0.25) + Vector((0, 0, 0))))
    bag.append(flap)
    o = join(bag, "Bag")
    finish(o, 4000)
    piece(o, "Root")

    # Hips / shorts seat
    piece(fuse([ellipsoid((0, -0.7, 0.02), (0.58, 0.24, 0.46))], "Hips", voxel=0.02, smooth=0, tris=2500), "Root")


# ── ARM (arm-local: the sleeve's centre is the origin, hanging down) ────────
def build_arm():
    sleeve = fuse([ellipsoid((0, 0.02, 0), (0.22, 0.34, 0.22)), ellipsoid((0, 0.24, 0), (0.24, 0.16, 0.24))], "Sleeve", voxel=0.014, smooth=2, tris=2500)
    piece(sleeve, "Arm")
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.04, major_segments=36, minor_segments=12)
    cuff = bpy.context.active_object
    cuff.data.transform(Matrix.Translation(R(0, -0.27, 0)))
    cuff.name = "Cuff"
    finish(cuff)
    piece(cuff, "Arm")
    hand = [ellipsoid((0, -0.44, -0.02), (0.2, 0.19, 0.2))]
    for k in (-1, 0, 1):
        hand.append(ellipsoid((0.09 * k, -0.56, -0.1), (0.07, 0.06, 0.07)))
    piece(fuse(hand, "Hand", voxel=0.012, smooth=3, tris=2500), "Arm")
    piece(fuse([ellipsoid((0, -0.49, -0.21), (0.09, 0.07, 0.03))], "PawPad", voxel=0.01, smooth=0, tris=800), "Arm")


# ── LEG (leg-local) ───────────────────────────────────────────────────────────
def build_leg():
    parts = [ellipsoid((0, 0, 0), (0.28, 0.28, 0.28)), ellipsoid((0, -0.26, -0.1), (0.3, 0.17, 0.38))]
    for k in (-1, 0, 1):
        parts.append(ellipsoid((0.12 * k, -0.28, -0.42), (0.08, 0.08, 0.08)))
    piece(fuse(parts, "Leg", voxel=0.014, smooth=4, tris=3500), "Leg")
    shorts = [ellipsoid((0, 0.14, 0), (0.33, 0.17, 0.33)), ellipsoid((0, 0.04, 0), (0.34, 0.08, 0.34))]
    piece(fuse(shorts, "ShortsLeg", voxel=0.014, smooth=4, tris=2500), "Leg")


# ── TAIL (tail-local: relative to the first tail joint) ──────────────────────
TAIL_POINTS = [
    (0.14, -0.62, 0.58), (0.46, -0.58, 0.7), (0.8, -0.44, 0.7), (1.06, -0.18, 0.62),
    (1.18, 0.14, 0.54), (1.16, 0.46, 0.46), (1.04, 0.7, 0.4),
]


def build_tail():
    p0 = Vector(TAIL_POINTS[0])
    pts = [R(*(Vector(p) - p0)) for p in TAIL_POINTS[:-1]]
    taper = [0.85, 1.0, 1.08, 1.1, 1.05, 0.95]
    t = tube(pts, 0.22, "tail", taper=taper)
    tail = fuse([t], "Tail", voxel=0.016, smooth=6, tris=3000)
    piece(tail, "Tail")
    q = Vector(TAIL_POINTS[-1]) - p0
    tip = [ellipsoid((q.x, q.y - 0.02, q.z), (0.21, 0.26, 0.21))]
    tip.append(cone_between((q.x, q.y + 0.1, q.z), (q.x - 0.06, q.y + 0.36, q.z - 0.02), 0.13, 0.03))
    piece(fuse(tip, "TailTip", voxel=0.012, smooth=6, tris=1500), "Tail")


# ── export ──────────────────────────────────────────────────────────────────
def export():
    lines = [
        "--!strict",
        "-- GENERATED by tools/blender/build_cat.py — do not edit by hand.",
        "-- Each mesh piece: the rig part it welds to, its centre in that part's",
        "-- space and its size (Roblox studs). The meshes themselves live in",
        "-- ReplicatedStorage.CatMeshes (imported from assets/CatMeshes.fbx).",
        "",
        "return {",
    ]
    for obj, anchor in PIECES:
        activate(obj)
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        c = rb(obj.location)
        d = obj.dimensions
        size = (d.x, d.z, d.y)
        lines.append(
            '\t{ Name = "%s", Anchor = "%s", Center = Vector3.new(%.4f, %.4f, %.4f), Size = Vector3.new(%.4f, %.4f, %.4f) },'
            % (obj.name, anchor, c[0], c[1], c[2], size[0], size[1], size[2])
        )
    lines.append("}")
    with open(OUT_LUA, "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")

    os.makedirs(os.path.dirname(OUT_FBX), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj, _ in PIECES:
        obj.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=OUT_FBX, use_selection=True, object_types={"MESH"},
        axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="FACE", use_mesh_modifiers=True, bake_space_transform=True,
    )


# ── preview render (assembled, reference colours) ───────────────────────────
COLORS = {
    "HeadFur": (250, 226, 206), "Hand": (250, 226, 206), "Leg": (250, 226, 206), "Tail": (250, 226, 206),
    "Muzzle": (255, 244, 236), "EarFluff": (255, 244, 236), "TailTip": (255, 244, 236),
    "ForeheadMark": (240, 190, 158), "InnerEar": (255, 160, 180), "Nose": (255, 136, 160), "PawPad": (255, 160, 180),
    "Blush": (255, 160, 180), "Mouth": (110, 58, 66), "Brows": (206, 170, 150),
    "EyeWhite": (22, 16, 26), "Iris": (30, 96, 84), "IrisGlow": (70, 170, 140), "Pupil": (12, 8, 18), "Shine": (255, 255, 255),
    "Jacket": (42, 40, 58), "Sleeve": (42, 40, 58), "Cuff": (32, 30, 44), "Shirt": (242, 178, 152), "Drawstrings": (246, 246, 250),
    "Pocket": (214, 140, 72), "DogTag": (214, 218, 228), "Bag": (150, 88, 54), "Hips": (46, 42, 54), "ShortsLeg": (46, 42, 54), "Body": (42, 40, 58),
}


def srgb(c):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), 1)


ANCHORS = {
    "Root": Matrix.Identity(4),
    "Head": Matrix.Translation(R(0, 1.2, 0)),
    "Tail": Matrix.Translation(R(*TAIL_POINTS[0])),
}


def arm_matrix(i):
    pivot = Matrix.Translation(R(0.66 * i, 0.12, 0)) @ rot_r(0, 0, 12 * i).to_4x4()
    return pivot @ Matrix.Translation(R(0, -0.3, 0))


def leg_matrix(i):
    return Matrix.Translation(R(0.3 * i, -0.78, 0)) @ Matrix.Translation(R(0, -0.18, 0))


def preview():
    placed = []
    for obj, anchor in PIECES:
        if obj.name == "Body":
            continue
        mats = []
        if anchor == "Arm":
            mats = [arm_matrix(-1), arm_matrix(1)]
        elif anchor == "Leg":
            mats = [leg_matrix(-1), leg_matrix(1)]
        else:
            mats = [ANCHORS[anchor]]
        for m in mats:
            dup = obj.copy()
            dup.data = obj.data.copy()
            bpy.context.collection.objects.link(dup)
            local = Matrix.Translation(obj.location)
            dup.matrix_world = m @ local
            mat = bpy.data.materials.new(obj.name + "_m")
            mat.diffuse_color = srgb(COLORS.get(obj.name, (200, 200, 200)))
            dup.data.materials.clear()
            dup.data.materials.append(mat)
            placed.append(dup)
    for obj, _ in PIECES:
        obj.hide_render = True

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 700
    scene.render.resolution_y = 900
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.color = (0.02, 0.03, 0.06)
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    target = R(0, 0.55, 0)
    for name, yaw in (("front", -15), ("side", -70)):
        a = math.radians(yaw)
        pos = target + R(math.sin(a) * 11, 1.2, -math.cos(a) * 11) - R(0, 0, 0)
        cam.location = pos
        cam.rotation_mode = "QUATERNION"
        cam.rotation_quaternion = (target - pos).to_track_quat("-Z", "Y")
        scene.render.filepath = os.path.join(OUT_PREVIEW, "preview_%s.png" % name)
        bpy.ops.render.render(write_still=True)


def main():
    reset()
    build_head()
    build_body()
    build_arm()
    build_leg()
    build_tail()
    export()
    preview()
    print("CAT BUILD OK", len(PIECES), "pieces")


main()
