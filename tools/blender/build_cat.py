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
# A soft, round kitten head (no spikes): wide cheeks with gentle fluff, a tiny
# tuft, rounded-tip ears. Face details are thin "decals" wrapped onto the
# head surface so the eyes sit flat and glossy like the reference.
def ellipse_pts(rx, ry, n=36):
    return [(rx * math.cos(2 * math.pi * k / n), ry * math.sin(2 * math.pi * k / n)) for k in range(n)]


def rotated(pts, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(x * c - y * s, x * s + y * c) for x, y in pts]


def decal(name, pts, surf, target, x, y, offset, thickness=0.008, subdiv=2):
    hit, n = surf.front(x, y)
    if hit is None:
        return None
    o = flat_shape(pts, hit, n, subdiv=subdiv)
    stick(o, target, offset=offset, thickness=thickness)
    o.name = name
    return o


def decal_toward(name, pts, surf, target, origin_r, dir_r, offset, thickness=0.01):
    hit, n = surf.toward(origin_r, dir_r)
    if hit is None:
        return None
    o = flat_shape(pts, hit, n, subdiv=2)
    stick(o, target, offset=offset, thickness=thickness)
    o.name = name
    return o


def build_head():
    parts = [ellipsoid((0, 0.02, 0), (1.22, 0.96, 1.0))]
    for i in (-1, 1):
        parts.append(ellipsoid((0.56 * i, -0.36, -0.3), (0.5, 0.4, 0.46)))  # full lower cheeks
        parts.append(cone_between((1.0 * i, -0.32, -0.08), (1.3 * i, -0.46, -0.04), 0.2, 0.07))  # soft cheek tufts
        parts.append(cone_between((0.92 * i, -0.52, -0.06), (1.14 * i, -0.72, -0.02), 0.17, 0.06))
        # ears: wide, with rounded tips, squashed front-to-back
        ear = cone_between((0.54 * i, 0.5, 0.08), (1.02 * i, 1.5, 0.12), 0.52, 0.05)
        c = R(0.78 * i, 0.98, 0.1)
        ear.data.transform(Matrix.Translation(-c))
        ear.data.transform(Matrix.Diagonal((1.0, 0.46, 1.0, 1.0)))
        ear.data.transform(Matrix.Translation(c))
        parts.append(ear)
    parts.append(ellipsoid((0.02, 0.92, -0.1), (0.17, 0.14, 0.15)))  # tiny top tuft
    head = fuse(parts, "HeadFur", voxel=0.02, smooth=16, tris=8000)
    piece(head, "Head")
    surf = Surface(head)

    def add(name, objs, tris=2500):
        objs = [o for o in objs if o]
        if not objs:
            return
        o = join(objs, name)
        finish(o, tris)
        piece(o, "Head")

    # Big pink ear insides
    inner = []
    for i in (-1, 1):
        tri = rotated([(-0.42, -0.42), (0.42, -0.42), (0.0, 0.52)], 24 * i)
        inner.append(decal_toward("ear", tri, surf, head, (0.8 * i, 1.02, -2), (0, 0, 1), 0.01, 0.02))
    add("InnerEar", inner)

    # Eyes: round, a touch taller than wide. Mostly dark, green glow at the
    # bottom, big shine upper-left + a small one lower-right (viewer's view;
    # the viewer's left is +X).
    EX, EY = 0.5, -0.06
    layers = {"EyeWhite": [], "Iris": [], "IrisGlow": [], "Pupil": [], "Shine": []}
    for i in (-1, 1):
        x = EX * i
        layers["EyeWhite"].append(decal("rim", ellipse_pts(0.28, 0.31), surf, head, x, EY, 0.006, 0.01))
        layers["Iris"].append(decal("iris", ellipse_pts(0.25, 0.28), surf, head, x, EY, 0.014, 0.008))
        layers["IrisGlow"].append(decal("glow", ellipse_pts(0.2, 0.11), surf, head, x, EY - 0.14, 0.02, 0.008))
        layers["Pupil"].append(decal("pupil", ellipse_pts(0.18, 0.2), surf, head, x, EY + 0.03, 0.026, 0.008))
        layers["Shine"].append(decal("shine", ellipse_pts(0.095, 0.105), surf, head, x + 0.09, EY + 0.11, 0.034, 0.008))
        layers["Shine"].append(decal("shine", ellipse_pts(0.045, 0.045), surf, head, x - 0.1, EY - 0.13, 0.034, 0.008))
    for name, objs in layers.items():
        add(name, objs)

    # Faint little brows
    brows = []
    for i in (-1, 1):
        pts = []
        for t in (0.0, 0.5, 1.0):
            hit, n = surf.front((0.4 + 0.18 * t) * i, 0.33 + 0.035 * math.sin(t * math.pi))
            pts.append(hit + n * 0.012)
        brows.append(tube(pts, 0.024, "brow"))
    add("Brows", brows, 1200)

    # Soft forehead mark pointing down
    add("ForeheadMark", [decal("mark", [(-0.17, 0.12), (0.17, 0.12), (0.0, -0.2)], surf, head, 0, 0.64, 0.006, 0.008, subdiv=3)], 1200)

    # Small pink nose (rounded triangle) + a little smile
    add("Nose", [decal("nose", [(-0.085, 0.045), (0.085, 0.045), (0.0, -0.065)], surf, head, 0, -0.28, 0.008, 0.035, subdiv=3)], 1000)
    arcs = []
    for i in (-1, 1):
        pts = []
        for k in range(5):
            a = math.pi * k / 4
            hit, n = surf.front(0.045 * i + 0.045 * math.cos(a) * i, -0.37 - 0.035 * math.sin(a))
            pts.append(hit + n * 0.01)
        arcs.append(tube(pts, 0.013, "mouth"))
    add("Mouth", arcs, 1200)

    # Blush
    add("Blush", [decal("blush", ellipse_pts(0.16, 0.08), surf, head, 0.8 * i, -0.3, 0.008, 0.006) for i in (-1, 1)], 1200)

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
    piece(fuse([ellipsoid((0, -0.66, 0.02), (0.52, 0.2, 0.42))], "Hips", voxel=0.02, smooth=0, tris=2500), "Root")


# ── ARM (arm-local: the sleeve's centre is the origin, hanging down) ────────
def build_arm():
    sleeve = fuse([ellipsoid((0, 0.02, 0), (0.22, 0.34, 0.22)), ellipsoid((0, 0.24, 0), (0.24, 0.16, 0.24))], "Sleeve", voxel=0.014, smooth=4, tris=2500)
    piece(sleeve, "Arm")
    piece(fuse([ellipsoid((0, -0.26, 0), (0.235, 0.07, 0.235))], "Cuff", voxel=0.012, smooth=3, tris=1500), "Arm")
    hand = [ellipsoid((0, -0.44, -0.02), (0.2, 0.19, 0.2))]
    for k in (-1, 0, 1):
        hand.append(ellipsoid((0.08 * k, -0.55, -0.09), (0.06, 0.05, 0.06)))
    piece(fuse(hand, "Hand", voxel=0.012, smooth=6, tris=2500), "Arm")


# ── LEG (leg-local) ───────────────────────────────────────────────────────────
def build_leg():
    parts = [ellipsoid((0, 0, 0), (0.28, 0.28, 0.28)), ellipsoid((0, -0.26, -0.1), (0.3, 0.17, 0.38))]
    for k in (-1, 0, 1):
        parts.append(ellipsoid((0.11 * k, -0.29, -0.41), (0.07, 0.07, 0.07)))
    piece(fuse(parts, "Leg", voxel=0.014, smooth=6, tris=3500), "Leg")
    piece(fuse([ellipsoid((0, 0.1, 0), (0.33, 0.22, 0.33))], "ShortsLeg", voxel=0.014, smooth=3, tris=2500), "Leg")


# ── TAIL (tail-local: relative to the first tail joint) ──────────────────────
# A small fluffy tail that curves down to the floor behind the cat (viewer's
# left), tip curling up a little.
TAIL_POINTS = [
    (0.1, -0.6, 0.5), (0.32, -0.78, 0.6), (0.54, -0.98, 0.58), (0.72, -1.1, 0.46),
    (0.84, -1.12, 0.3), (0.9, -1.04, 0.16),
]


def build_tail():
    p0 = Vector(TAIL_POINTS[0])
    pts = [R(*(Vector(p) - p0)) for p in TAIL_POINTS]
    taper = [0.8, 1.0, 1.1, 1.1, 0.95, 0.7]
    t = tube(pts, 0.24, "tail", taper=taper)
    tail = fuse([t], "Tail", voxel=0.016, smooth=8, tris=3000)
    piece(tail, "Tail")


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


# ── preview render (assembled, reference colours, proper lighting) ─────────
COLORS = {
    "HeadFur": (255, 236, 224), "Hand": (255, 236, 224), "Leg": (255, 236, 224), "Tail": (255, 236, 224),
    "TailTip": (255, 246, 240), "ForeheadMark": (246, 206, 180), "InnerEar": (255, 158, 172),
    "Nose": (255, 140, 160), "Blush": (255, 196, 204), "Mouth": (120, 70, 74), "Brows": (230, 196, 176),
    "EyeWhite": (18, 16, 22), "Iris": (18, 58, 58), "IrisGlow": (60, 170, 150), "Pupil": (8, 8, 12), "Shine": (255, 255, 255),
    "Jacket": (58, 48, 70), "Sleeve": (58, 48, 70), "Cuff": (46, 38, 56), "Shirt": (228, 150, 132), "Drawstrings": (246, 246, 250),
    "DogTag": (236, 238, 242), "Pocket": (214, 140, 80), "Bag": (150, 84, 58), "Hips": (44, 40, 54), "ShortsLeg": (44, 40, 54),
    "Body": (58, 48, 70),
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


def material(name, rgb):
    mat = bpy.data.materials.new(name + "_m")
    mat.diffuse_color = srgb(rgb)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = srgb(rgb)
        bsdf.inputs["Roughness"].default_value = 0.2 if name in ("EyeWhite", "Iris", "Pupil", "Shine", "IrisGlow") else 0.6
    return mat


def light(name, kind, loc_r, energy, size=4.0, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if kind == "AREA":
        ld.size = size
    lo = bpy.data.objects.new(name, ld)
    bpy.context.collection.objects.link(lo)
    lo.location = R(*loc_r)
    target = R(0, 0.4, 0)
    lo.rotation_mode = "QUATERNION"
    lo.rotation_quaternion = (target - lo.location).to_track_quat("-Z", "Y")


def preview():
    for obj, anchor in PIECES:
        if obj.name == "Body":
            continue
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
            dup.matrix_world = m @ Matrix.Translation(obj.location)
            dup.data.materials.clear()
            dup.data.materials.append(material(obj.name, COLORS.get(obj.name, (200, 200, 200))))
    for obj, _ in PIECES:
        obj.hide_render = True

    scene = bpy.context.scene
    engine = "BLENDER_WORKBENCH"
    for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = e
            engine = e
            break
        except Exception:
            pass
    if engine == "BLENDER_WORKBENCH":
        scene.render.engine = engine
        scene.display.shading.light = "STUDIO"
        scene.display.shading.color_type = "MATERIAL"
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    scene.render.resolution_x = 700
    scene.render.resolution_y = 900
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.012, 0.018, 0.04, 1)
        bg.inputs["Strength"].default_value = 1.0
    world.color = (0.012, 0.018, 0.04)
    scene.world = world
    light("key", "AREA", (4, 6, -7), 900, 6)
    light("fill", "AREA", (-6, 2, -5), 350, 6)
    light("rim", "AREA", (0, 5, 7), 500, 5, (0.8, 0.9, 1.0))
    light("amb", "SUN", (0, 10, -3), 1.2)

    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 70
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    target = R(0, 0.55, 0)
    for name, yaw in (("front", -12), ("side", -65)):
        a = math.radians(yaw)
        pos = target + R(math.sin(a) * 11, 1.0, -math.cos(a) * 11)
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
