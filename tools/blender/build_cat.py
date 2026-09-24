# Paw Mayhem cat — procedural Blender model (v3: furry).
#
#   blender --background --python tools/blender/build_cat.py
#
# Builds the cat as separate smooth meshes (each tinted in Roblox with the
# player's fur / outfit colours, and still driven by the rig's joints),
# bakes fur / fabric textures (colour + normal maps) for the big pieces,
# exports everything to assets/CatMeshes.glb, writes the Lua layout table
# src/ReplicatedStorage/Shared/Character/CatMeshData.lua and renders preview
# images to tools/blender/preview_*.png.
#
# Every piece is modelled in the local space of the rig part it welds to
# ("anchor"), in Roblox axes: X right, Y up, -Z = the way the cat faces.
# R(x, y, z) converts a Roblox position to Blender's Z-up axes.

import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_GLB = os.path.join(ROOT, "assets", "CatMeshes.glb")
OUT_LUA = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Character", "CatMeshData.lua")
OUT_PREVIEW = os.path.join(ROOT, "tools", "blender")
TEX_DIR = os.path.join(ROOT, "tools", "blender", "textures")

random.seed(7)

# Rig layout (Roblox root space) — must match CatBuilder.
HEAD_CENTER = (0, 1.22, 0)
SHOULDER = (0.68, 0.24, 0)
HIP = (0.3, -0.78, 0)
TAIL_POINTS = [
    (0.1, -0.6, 0.5), (0.32, -0.78, 0.6), (0.54, -0.98, 0.58), (0.72, -1.1, 0.46),
    (0.84, -1.12, 0.3), (0.9, -1.04, 0.16),
]

# ── axes ─────────────────────────────────────────────────────────────────────
C3 = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # Roblox -> Blender


def R(x, y, z):
    return Vector((x, -z, y))


def rb(v):
    return (v.x, v.z, -v.y)


def rot_r(rx=0.0, ry=0.0, rz=0.0):
    """Roblox CFrame.Angles(rx, ry, rz) (degrees) as a Blender 3x3."""
    def m(axis, a):
        return Matrix.Rotation(math.radians(a), 3, axis)
    rr = m("X", rx) @ m("Y", ry) @ m("Z", rz)  # in Roblox axes
    return C3 @ rr @ C3.inverted()


# ── scene helpers ────────────────────────────────────────────────────────────
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_mods(obj):
    activate(obj)
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def apply_transform(obj):
    activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def ellipsoid(center, radii, seg=48, rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1)
    o = bpy.context.active_object
    o.scale = (radii[0], radii[2], radii[1])
    o.location = R(*center)
    apply_transform(o)
    return o


def cone_between(base, tip, r0, r1=0.0, verts=24):
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


def finish(o, tris=6000):
    count = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if count > tris:
        dm = o.modifiers.new("decimate", "DECIMATE")
        dm.ratio = tris / count
        apply_mods(o)
    activate(o)
    bpy.ops.object.shade_smooth()


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


def frame_at(point, normal, up=Vector((0, 0, 1))):
    z = normal.normalized()
    x = up.cross(z)
    if x.length < 1e-4:
        x = Vector((1, 0, 0))
    x.normalize()
    y = z.cross(x).normalized()
    return Matrix((x, y, z)).transposed()


def disc(point, normal, w, h, depth, lift):
    f = frame_at(point, normal)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, radius=1)
    o = bpy.context.active_object
    o.data.transform(Matrix.Diagonal((w, h, depth, 1.0)))
    o.data.transform(f.to_4x4())
    o.data.transform(Matrix.Translation(point + normal.normalized() * lift))
    return o


def tube(points, radius, name="tube", taper=None, res=4):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = res
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p.x, p.y, p.z, 1)
        if taper:
            sp.points[i].radius = taper[i]
    sp.use_endpoint_u = True
    sp.order_u = min(3, len(points))
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    activate(o)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


def strand(base_b, direction_b, length, r0, bend=Vector((0, 0, 0)), name="strand"):
    """A soft tapered fur strand/tuft (Blender-space start + direction)."""
    d = direction_b.normalized()
    pts = [base_b + d * (length * t) + bend * (t * t) for t in (0.0, 0.35, 0.7, 1.0)]
    return tube(pts, r0, name, taper=[1.0, 0.8, 0.45, 0.08])


def stick(obj, target, offset=0.01, thickness=0.012):
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


def flat_shape(verts, hit, normal, subdiv=2):
    me = bpy.data.meshes.new("flat")
    me.from_pydata([(x, y, 0) for x, y in verts], [], [list(range(len(verts)))])
    o = bpy.data.objects.new("flat", me)
    bpy.context.collection.objects.link(o)
    sub = o.modifiers.new("sub", "SUBSURF")
    sub.levels = subdiv
    apply_mods(o)
    me.transform(frame_at(hit, normal).to_4x4())
    me.transform(Matrix.Translation(hit + normal.normalized() * 0.05))
    return o


def ellipse_pts(rx, ry, n=36):
    return [(rx * math.cos(2 * math.pi * k / n), ry * math.sin(2 * math.pi * k / n)) for k in range(n)]


def rotated(pts, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(x * c - y * s, x * s + y * c) for x, y in pts]


class Surface:
    def __init__(self, obj):
        self.bvh = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())

    def front(self, x, y):
        hit, normal, _, _ = self.bvh.ray_cast(R(x, y, -5), Vector((0, -1, 0)))
        return hit, normal

    def toward(self, origin_r, dir_r):
        d = R(*dir_r)
        hit, normal, _, _ = self.bvh.ray_cast(R(*origin_r), d.normalized())
        return hit, normal


def decal(pts, surf, target, x, y, offset, thickness=0.008, subdiv=2):
    hit, n = surf.front(x, y)
    if hit is None:
        return None
    o = flat_shape(pts, hit, n, subdiv=subdiv)
    stick(o, target, offset=offset, thickness=thickness)
    return o


PIECES = []  # (object, anchor, texture kind or None)


def piece(obj, anchor, tex=None):
    PIECES.append((obj, anchor, tex))
    return obj


# ── HEAD (head-local; head centre = origin) ──────────────────────────────────
HR = (1.08, 0.84, 0.88)  # head radii


def build_head():
    parts = [ellipsoid((0, 0.02, 0), HR)]
    for i in (-1, 1):
        parts.append(ellipsoid((0.5 * i, -0.3, -0.26), (0.44, 0.34, 0.4)))  # full cheeks
        # Soft fluffy fringe low on the jaw (not beside the eyes): short clumps
        # that sweep out and down.
        for k in range(3):
            t = k / 2
            base = (0.86 * i - 0.12 * t * i, -0.34 - 0.18 * t, -0.12 + 0.02 * k)
            tip = (base[0] + 0.15 * i, base[1] - 0.1, base[2])
            parts.append(cone_between(base, tip, 0.13, 0.08))
    head = fuse(parts, "HeadFur", voxel=0.018, smooth=10, tris=9000)
    # A little tuft of loose strands on top (kept as strands, not fused).
    surf = Surface(head)
    tuft = [head]
    for dx, lean, ln in ((-0.05, -0.35, 0.15), (0.06, 0.3, 0.13)):
        hit, n = surf.toward((dx, 2, -0.2), (0, -1, 0))
        if hit:
            tuft.append(strand(hit - n * 0.04, n + R(lean, 0.3, -0.25), ln, 0.065, bend=R(lean * 0.1, 0, -0.03)))
    head = join(tuft, "HeadFur")
    finish(head, 9500)
    piece(head, "Head", "fur_head")
    surf = Surface(head)

    # Ears: cupped like real ears (hollowed front), rounded tip, fur outside.
    ears = []
    for i in (-1, 1):
        ear = cone_between((0.48 * i, 0.42, 0.08), (0.84 * i, 1.26, 0.12), 0.42, 0.07, verts=40)
        c = R(0.66 * i, 0.84, 0.1)
        ear.data.transform(Matrix.Translation(-c))
        ear.data.transform(Matrix.Diagonal((1.0, 0.5, 1.0, 1.0)))
        ear.data.transform(Matrix.Translation(c))
        cutter = ellipsoid((0.7 * i, 0.9, -0.12), (0.26, 0.4, 0.16))
        cutter.data.transform(Matrix.Translation(-R(0.7 * i, 0.9, -0.12)))
        cutter.data.transform(rot_r(0, 0, -24 * i).to_4x4())
        cutter.data.transform(Matrix.Translation(R(0.7 * i, 0.9, -0.12)))
        bo = ear.modifiers.new("cup", "BOOLEAN")
        bo.operation = "DIFFERENCE"
        bo.object = cutter
        bo.solver = "EXACT"
        apply_mods(ear)
        bpy.data.objects.remove(cutter)
        ears.append(ear)
    ears_obj = fuse(ears, "Ears", voxel=0.014, smooth=4, tris=5000)
    piece(ears_obj, "Head", "fur_plain")
    esurf = Surface(ears_obj)

    # Pink inside each ear cup + white fur tufts growing out of it.
    inner, tufts = [], []
    for i in (-1, 1):
        hit, n = esurf.toward((0.68 * i, 0.88, -2), (0, 0, 1))
        if hit:
            tri = rotated([(-0.26, -0.3), (0.26, -0.3), (0.0, 0.42)], 22 * i)
            o = flat_shape(tri, hit, n, subdiv=3)
            stick(o, ears_obj, offset=0.006, thickness=0.01)
            inner.append(o)
            for dx, ln in ((-0.05, 0.15), (0.0, 0.19), (0.05, 0.14)):
                base = hit + R(dx - 0.02 * i, -0.18, 0) - n * 0.01
                tufts.append(strand(base, R(0.18 * i + dx, 1.0, -0.12), ln, 0.035, bend=R(0.02 * i, 0, -0.02)))
    piece(join(inner, "InnerEar"), "Head")
    finish(bpy.data.objects["InnerEar"], 2000)
    t = join(tufts, "EarTufts")
    finish(t, 2500)
    piece(t, "Head")

    def add(name, objs, tris=2500):
        objs = [o for o in objs if o]
        if objs:
            o = join(objs, name)
            finish(o, tris)
            piece(o, "Head")

    # Eyes: round, a touch taller than wide; mostly dark with a green glow at
    # the bottom, a big shine upper-left and a small one lower-right.
    EX, EY = 0.45, -0.07
    layers = {"EyeWhite": [], "Iris": [], "IrisGlow": [], "Pupil": [], "Shine": []}
    for i in (-1, 1):
        x = EX * i
        layers["EyeWhite"].append(decal(ellipse_pts(0.25, 0.28), surf, head, x, EY, 0.006, 0.01))
        layers["Iris"].append(decal(ellipse_pts(0.225, 0.255), surf, head, x, EY, 0.014, 0.008))
        layers["IrisGlow"].append(decal(ellipse_pts(0.18, 0.1), surf, head, x, EY - 0.125, 0.02, 0.008))
        layers["Pupil"].append(decal(ellipse_pts(0.16, 0.18), surf, head, x, EY + 0.03, 0.026, 0.008))
        layers["Shine"].append(decal(ellipse_pts(0.085, 0.095), surf, head, x + 0.08, EY + 0.1, 0.034, 0.008))
        layers["Shine"].append(decal(ellipse_pts(0.04, 0.04), surf, head, x - 0.09, EY - 0.12, 0.034, 0.008))
    for name, objs in layers.items():
        add(name, objs)

    brows = []
    for i in (-1, 1):
        pts = []
        for t in (0.0, 0.5, 1.0):
            hit, n = surf.front((0.36 + 0.16 * t) * i, 0.28 + 0.03 * math.sin(t * math.pi))
            pts.append(hit + n * 0.012)
        brows.append(tube(pts, 0.022, "brow"))
    add("Brows", brows, 1200)

    add("Nose", [decal([(-0.075, 0.04), (0.075, 0.04), (0.0, -0.06)], surf, head, 0, -0.26, 0.008, 0.032, subdiv=3)], 1000)
    arcs = []
    for i in (-1, 1):
        pts = []
        for k in range(5):
            a = math.pi * k / 4
            hit, n = surf.front(0.04 * i + 0.04 * math.cos(a) * i, -0.34 - 0.03 * math.sin(a))
            pts.append(hit + n * 0.01)
        arcs.append(tube(pts, 0.012, "mouth"))
    add("Mouth", arcs, 1200)
    add("Blush", [decal(ellipse_pts(0.14, 0.07), surf, head, 0.72 * i, -0.28, 0.008, 0.006) for i in (-1, 1)], 1200)


# ── BODY (root-local) ─────────────────────────────────────────────────────────
TORSO_C, TORSO_R = (0, -0.15, 0), (0.66, 0.58, 0.52)


def build_body():
    piece(fuse([ellipsoid(TORSO_C, TORSO_R)], "Body", voxel=0.02, smooth=0, tris=3000), "Root")
    shirt = fuse([ellipsoid((0, -0.15, -0.01), (0.61, 0.54, 0.48)), ellipsoid((0, 0.3, -0.1), (0.28, 0.08, 0.22))], "Shirt", voxel=0.02, smooth=2, tris=3500)
    piece(shirt, "Root", "knit")

    # Jacket: a shell around the tee, open down the front.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=40, radius=1)
    shell = bpy.context.active_object
    shell.data.transform(Matrix.Diagonal((0.69, 0.55, 0.6, 1.0)))
    shell.data.transform(Matrix.Translation(R(*TORSO_C)))
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    kill = []
    for face in bm.faces:
        x, y, z = rb(face.calc_center_median())
        half = 0.12 + (0.2 - y) * 0.1
        if (z < -0.2 and abs(x) < half and y < 0.34) or y > 0.36:
            kill.append(face)
    bmesh.ops.delete(bm, geom=list(set(kill)), context="FACES")
    bm.to_mesh(shell.data)
    bm.free()
    so = shell.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.05
    so.offset = 1.0
    apply_mods(shell)
    parts = [shell]
    for i in (-1, 1):
        parts.append(tube([R(0.15 * i, 0.3, -0.48), R(0.19 * i, 0.05, -0.57), R(0.23 * i, -0.3, -0.56), R(0.27 * i, -0.62, -0.47)], 0.05, "lapel"))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.1, major_segments=48, minor_segments=16)
    collar = bpy.context.active_object
    collar.data.transform(Matrix.Diagonal((1.15, 1.0, 1.0, 1.0)))
    collar.data.transform(Matrix.Translation(R(0, 0.38, 0.02)))
    parts.append(collar)
    # Big bunched hood: behind the neck and peeking out at both shoulders
    parts.append(ellipsoid((0, 0.44, 0.34), (0.64, 0.28, 0.34)))
    parts.append(ellipsoid((0, 0.28, 0.48), (0.52, 0.26, 0.24)))
    for i in (-1, 1):
        parts.append(ellipsoid((0.44 * i, 0.4, 0.1), (0.2, 0.18, 0.26)))
    jacket = fuse(parts, "Jacket", voxel=0.018, smooth=3, tris=9500)
    piece(jacket, "Root", "fabric")
    jsurf = Surface(jacket)
    ssurf = Surface(shirt)

    strings = []
    for i in (-1, 1):
        pts = []
        for k, y in enumerate((0.3, 0.18, 0.06, -0.04)):
            hit, n = ssurf.front(0.14 * i + 0.012 * k * i, y)
            pts.append(hit + n * 0.035)
        strings.append(tube(pts, 0.021, "string"))
        hit, n = ssurf.front(0.19 * i, -0.1)
        strings.append(disc(hit, n, 0.035, 0.06, 0.035, 0.035))
    o = join(strings, "Drawstrings")
    finish(o, 2000)
    piece(o, "Root")

    tag = []
    hit, n = ssurf.front(0, 0.04)
    tag.append(disc(hit, n, 0.09, 0.125, 0.018, 0.03))
    for i in (-1, 1):
        pts = []
        for k in range(4):
            t = k / 3
            h2, n2 = ssurf.front(0.13 * i * (1 - t), 0.32 - t * 0.14)
            pts.append(h2 + n2 * 0.025)
        tag.append(tube(pts, 0.011, "chain"))
    o = join(tag, "DogTag")
    finish(o, 1500)
    piece(o, "Root")

    hit, n = jsurf.toward((-0.46, -0.42, -2), (0, 0, 1))
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

    bag = []
    for start_z, direction in ((-2, 1), (2, -1)):
        pts = []
        for k in range(17):
            t = k / 16
            hit, n = jsurf.toward((-0.52 + t * 1.06, 0.3 - t * 0.8, start_z), (0, 0, direction))
            if hit:
                pts.append(hit + n * 0.06)
        bag.append(tube(pts, 0.04, "strap"))
    for size, dy in (((0.44, 0.24, 0.38), 0.0), ((0.46, 0.26, 0.2), 0.1)):
        bpy.ops.mesh.primitive_cube_add(size=1)
        box = bpy.context.active_object
        box.data.transform(Matrix.Diagonal((size[0], size[1], size[2], 1.0)))
        bev = box.modifiers.new("bev", "BEVEL")
        bev.width = 0.07 if dy == 0 else 0.06
        bev.segments = 4
        apply_mods(box)
        box.data.transform(rot_r(0, -40, 0).to_4x4())
        box.data.transform(Matrix.Translation(R(0.62, -0.54 + dy, -0.22)))
        bag.append(box)
    o = join(bag, "Bag")
    finish(o, 4000)
    piece(o, "Root")

    piece(fuse([ellipsoid((0, -0.72, 0.02), (0.52, 0.2, 0.42))], "Hips", voxel=0.02, smooth=0, tris=2500), "Root")


# ── ARM (arm-local: the sleeve's centre is the origin, hanging down) ────────
def build_arm():
    sleeve = fuse([ellipsoid((0, 0.02, 0), (0.22, 0.34, 0.22)), ellipsoid((0, 0.24, 0), (0.24, 0.16, 0.24))], "Sleeve", voxel=0.014, smooth=4, tris=2500)
    piece(sleeve, "Arm")
    hs = sleeve.copy()
    hs.data = sleeve.data.copy()
    bpy.context.collection.objects.link(hs)
    hs.name = "HoodieSleeve"
    hs.data.name = "HoodieSleeve"
    piece(hs, "Arm", "fabric")
    piece(fuse([ellipsoid((0, -0.26, 0), (0.235, 0.07, 0.235))], "Cuff", voxel=0.012, smooth=3, tris=1500), "Arm")
    hand = [ellipsoid((0, -0.44, -0.02), (0.2, 0.19, 0.2))]
    for k in (-1, 0, 1):
        hand.append(ellipsoid((0.08 * k, -0.55, -0.09), (0.06, 0.05, 0.06)))
    piece(fuse(hand, "Hand", voxel=0.012, smooth=6, tris=2500), "Arm", "fur_plain")


# ── LEG (leg-local) ───────────────────────────────────────────────────────────
def build_leg():
    parts = [ellipsoid((0, 0, 0), (0.28, 0.28, 0.28)), ellipsoid((0, -0.26, -0.1), (0.3, 0.17, 0.38))]
    for k in (-1, 0, 1):
        parts.append(ellipsoid((0.11 * k, -0.29, -0.41), (0.07, 0.07, 0.07)))
    piece(fuse(parts, "Leg", voxel=0.014, smooth=6, tris=3500), "Leg", "fur_plain")
    piece(fuse([ellipsoid((0, 0.1, 0), (0.33, 0.22, 0.33))], "ShortsLeg", voxel=0.014, smooth=3, tris=2500), "Leg")


# ── TAIL (tail-local: relative to the first tail joint) ──────────────────────
def build_tail():
    p0 = Vector(TAIL_POINTS[0])
    pts = [R(*(Vector(p) - p0)) for p in TAIL_POINTS]
    parts = [tube(pts, 0.25, "tail", taper=[0.75, 0.95, 1.05, 1.08, 0.95, 0.7])]
    # Fluffy clumps along the tail so the outline is soft and furry.
    for k in range(1, len(pts) - 1):
        along = (pts[k + 1] - pts[k - 1]).normalized()
        for j in range(5):
            side = Matrix.Rotation(j / 5 * math.pi * 2 + k, 3, along) @ along.orthogonal().normalized()
            c = pts[k] + side * 0.16 + along * 0.04
            parts.append(ellipsoid(rb(c), (0.11, 0.11, 0.11)))
    tail = fuse(parts, "Tail", voxel=0.016, smooth=10, tris=4000)
    piece(tail, "Tail", "fur_plain")


# ── texture baking ───────────────────────────────────────────────────────────
TEX_SIZE = {"fur_head": 1024, "fur_plain": 512, "fabric": 1024, "knit": 512}
JACKET = (58, 48, 70)
SHIRT = (228, 150, 132)


def srgb(c):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), 1)


def unwrap(obj):
    activate(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def build_bake_material(obj, kind):
    """Procedural fur / fabric shader: height (for the normal bake) and an
    albedo emitted for the colour bake."""
    mat = bpy.data.materials.new(obj.name + "_bake")
    mat.use_nodes = True
    nt = mat.node_tree
    N, L = nt.nodes, nt.links
    N.clear()
    out = N.new("ShaderNodeOutputMaterial")
    tc = N.new("ShaderNodeTexCoord")
    mp = N.new("ShaderNodeMapping")
    L.new(tc.outputs["Object"], mp.inputs["Vector"])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Detail"].default_value = 8
    nz.inputs["Roughness"].default_value = 0.65
    L.new(mp.outputs["Vector"], nz.inputs["Vector"])
    fine = N.new("ShaderNodeTexNoise")
    fine.inputs["Detail"].default_value = 4
    L.new(mp.outputs["Vector"], fine.inputs["Vector"])
    if kind.startswith("fur"):
        # Long thin strands running down the body (object Z = up).
        mp.inputs["Scale"].default_value = (38, 38, 2.6)
        nz.inputs["Detail"].default_value = 3
        fine.inputs["Scale"].default_value = 2
        strength, dist = 0.22, 0.02
    elif kind == "fabric":
        nz.inputs["Scale"].default_value = 260
        fine.inputs["Scale"].default_value = 9  # soft wrinkles
        strength, dist = 0.35, 0.02
    else:  # knit
        nz.inputs["Scale"].default_value = 420
        fine.inputs["Scale"].default_value = 30
        strength, dist = 0.3, 0.015
    height = N.new("ShaderNodeMath")
    height.operation = "MULTIPLY_ADD"
    height.inputs[1].default_value = 0.35
    L.new(fine.outputs["Fac"], height.inputs[0])
    L.new(nz.outputs["Fac"], height.inputs[2])
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = strength
    bump.inputs["Distance"].default_value = dist
    L.new(height.outputs["Value"], bump.inputs["Height"])
    bsdf = N.new("ShaderNodeBsdfPrincipled")
    L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    # Albedo: base * strand variation * ambient occlusion
    ao = N.new("ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.25
    aof = N.new("ShaderNodeMapRange")
    aof.inputs["To Min"].default_value = 0.8
    L.new(ao.outputs["AO"], aof.inputs["Value"])
    var = N.new("ShaderNodeMapRange")
    var.inputs["To Min"].default_value = 0.94 if kind.startswith("fur") else 0.9
    L.new(nz.outputs["Fac"], var.inputs["Value"])
    shade = N.new("ShaderNodeMath")
    shade.operation = "MULTIPLY"
    L.new(aof.outputs["Result"], shade.inputs[0])
    L.new(var.outputs["Result"], shade.inputs[1])
    base = N.new("ShaderNodeRGB")
    if kind == "fabric":
        base.outputs[0].default_value = srgb(JACKET)
    elif kind == "knit":
        base.outputs[0].default_value = srgb(SHIRT)
    else:
        base.outputs[0].default_value = (1, 1, 1, 1)  # tinted in Roblox
    albedo = N.new("ShaderNodeMix")
    albedo.data_type = "RGBA"
    albedo.blend_type = "MULTIPLY"
    albedo.inputs["Factor"].default_value = 1.0
    L.new(base.outputs[0], albedo.inputs[6])
    comb = N.new("ShaderNodeCombineColor")
    for k in range(3):
        L.new(shade.outputs["Value"], comb.inputs[k])
    L.new(comb.outputs["Color"], albedo.inputs[7])
    final = albedo
    if kind == "fur_head":
        # Big soft tan patch pointing down from the top of the head.
        sep = N.new("ShaderNodeSeparateXYZ")
        L.new(tc.outputs["Object"], sep.inputs["Vector"])
        ax = N.new("ShaderNodeMath")
        ax.operation = "ABSOLUTE"
        L.new(sep.outputs["X"], ax.inputs[0])
        width = N.new("ShaderNodeMath")  # allowed half width grows with height
        width.operation = "MULTIPLY_ADD"
        width.inputs[1].default_value = 0.62
        width.inputs[2].default_value = -0.62 * 0.12
        L.new(sep.outputs["Z"], width.inputs[0])
        diff = N.new("ShaderNodeMath")
        diff.operation = "SUBTRACT"
        L.new(width.outputs["Value"], diff.inputs[0])
        L.new(ax.outputs["Value"], diff.inputs[1])
        edge = N.new("ShaderNodeMapRange")
        edge.inputs["From Min"].default_value = 0.0
        edge.inputs["From Max"].default_value = 0.1
        L.new(diff.outputs["Value"], edge.inputs["Value"])
        front = N.new("ShaderNodeMapRange")  # only on the front/top, not the back
        front.inputs["From Min"].default_value = -0.35
        front.inputs["From Max"].default_value = 0.05
        L.new(sep.outputs["Y"], front.inputs["Value"])
        mask = N.new("ShaderNodeMath")
        mask.operation = "MULTIPLY"
        L.new(edge.outputs["Result"], mask.inputs[0])
        L.new(front.outputs["Result"], mask.inputs[1])
        tan = N.new("ShaderNodeMix")
        tan.data_type = "RGBA"
        tan.blend_type = "MULTIPLY"
        L.new(mask.outputs["Value"], tan.inputs["Factor"])
        L.new(albedo.outputs[2], tan.inputs[6])
        tan.inputs[7].default_value = (0.93, 0.74, 0.58, 1)
        final = tan
    emit = N.new("ShaderNodeEmission")
    L.new(final.outputs[2], emit.inputs["Color"])
    img_node = N.new("ShaderNodeTexImage")
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return mat, out, bsdf, emit, img_node


def bake(obj, kind):
    os.makedirs(TEX_DIR, exist_ok=True)
    unwrap(obj)
    mat, out, bsdf, emit, img_node = build_bake_material(obj, kind)
    size = TEX_SIZE[kind]
    nt = mat.node_tree
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    scene.render.bake.margin = 6
    results = {}
    for bake_type, label, colorspace in (("NORMAL", "normal", "Non-Color"), ("EMIT", "color", "sRGB")):
        img = bpy.data.images.new("%s_%s" % (obj.name, label), size, size)
        img.colorspace_settings.name = colorspace
        img_node.image = img
        nt.nodes.active = img_node
        for link in list(out.inputs["Surface"].links):
            nt.links.remove(link)
        nt.links.new((bsdf if bake_type == "NORMAL" else emit).outputs[0], out.inputs["Surface"])
        activate(obj)
        if bake_type == "NORMAL":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
        else:
            bpy.ops.object.bake(type="EMIT")
        path = os.path.join(TEX_DIR, "%s_%s.png" % (obj.name, label))
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        results[label] = img
    # Final export material: colour map + normal map.
    fm = bpy.data.materials.new(obj.name)
    fm.use_nodes = True
    fb = fm.node_tree.nodes.get("Principled BSDF")
    col = fm.node_tree.nodes.new("ShaderNodeTexImage")
    col.image = results["color"]
    nrm = fm.node_tree.nodes.new("ShaderNodeTexImage")
    nrm.image = results["normal"]
    nm = fm.node_tree.nodes.new("ShaderNodeNormalMap")
    fm.node_tree.links.new(col.outputs["Color"], fb.inputs["Base Color"])
    fm.node_tree.links.new(nrm.outputs["Color"], nm.inputs["Color"])
    fm.node_tree.links.new(nm.outputs["Normal"], fb.inputs["Normal"])
    fb.inputs["Roughness"].default_value = 0.75
    obj.data.materials.clear()
    obj.data.materials.append(fm)


# ── export ──────────────────────────────────────────────────────────────────
def export():
    lines = [
        "--!strict",
        "-- GENERATED by tools/blender/build_cat.py — do not edit by hand.",
        "-- Each mesh piece: the rig part it welds to, its centre in that part's",
        "-- space, its size (studs) and whether it carries baked textures. The",
        "-- meshes live in ReplicatedStorage.CatMeshes (imported from",
        "-- assets/CatMeshes.glb).",
        "",
        "return {",
    ]
    for obj, anchor, tex in PIECES:
        activate(obj)
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
        c = rb(obj.location)
        d = obj.dimensions
        lines.append(
            '\t{ Name = "%s", Anchor = "%s", Center = Vector3.new(%.4f, %.4f, %.4f), Size = Vector3.new(%.4f, %.4f, %.4f), Textured = %s },'
            % (obj.name, anchor, c[0], c[1], c[2], d.x, d.z, d.y, "true" if tex else "false")
        )
    lines.append("}")
    with open(OUT_LUA, "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")

    for obj, _, tex in PIECES:
        if not tex:
            m = bpy.data.materials.new(obj.name)
            obj.data.materials.clear()
            obj.data.materials.append(m)
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj, _, _ in PIECES:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=True, export_materials="EXPORT", export_image_format="AUTO",
    )


# ── preview render (assembled, reference colours) ───────────────────────────
TINT = {
    "HeadFur": (255, 236, 224), "Ears": (255, 236, 224), "Hand": (255, 236, 224), "Leg": (255, 236, 224), "Tail": (255, 236, 224),
}
FLAT = {
    "EarTufts": (255, 248, 244), "InnerEar": (255, 158, 172), "Nose": (255, 140, 160), "Blush": (255, 196, 204),
    "Mouth": (120, 70, 74), "Brows": (228, 192, 170), "EyeWhite": (18, 16, 22), "Iris": (18, 58, 58),
    "IrisGlow": (60, 170, 150), "Pupil": (8, 8, 12), "Shine": (255, 255, 255), "Sleeve": JACKET, "Cuff": (46, 38, 56),
    "Drawstrings": (246, 246, 250), "DogTag": (236, 238, 242), "Pocket": (214, 140, 80), "Bag": (150, 84, 58),
    "Hips": (44, 40, 54), "ShortsLeg": (44, 40, 54), "Body": JACKET,
}


def arm_matrix(i):
    pivot = Matrix.Translation(R(SHOULDER[0] * i, SHOULDER[1], SHOULDER[2])) @ rot_r(0, 0, 12 * i).to_4x4()
    return pivot @ Matrix.Translation(R(0, -0.3, 0))


def leg_matrix(i):
    return Matrix.Translation(R(HIP[0] * i, HIP[1], HIP[2])) @ Matrix.Translation(R(0, -0.18, 0))


def preview_material(obj, tex):
    if tex:
        mat = obj.data.materials[0].copy()
        if obj.name in TINT:
            nt = mat.node_tree
            bsdf = nt.nodes.get("Principled BSDF")
            src = bsdf.inputs["Base Color"].links[0].from_socket
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1
            nt.links.new(src, mix.inputs[6])
            mix.inputs[7].default_value = srgb(TINT[obj.name])
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        return mat
    mat = bpy.data.materials.new(obj.name + "_p")
    mat.use_nodes = True
    b = mat.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = srgb(FLAT.get(obj.name, (200, 200, 200)))
    b.inputs["Roughness"].default_value = 0.15 if obj.name in ("EyeWhite", "Iris", "Pupil", "Shine", "IrisGlow", "Nose") else 0.6
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
    lo.rotation_mode = "QUATERNION"
    lo.rotation_quaternion = (R(0, 0.4, 0) - lo.location).to_track_quat("-Z", "Y")


def preview():
    anchors = {"Root": Matrix.Identity(4), "Head": Matrix.Translation(R(*HEAD_CENTER)), "Tail": Matrix.Translation(R(*TAIL_POINTS[0]))}
    for obj, anchor, tex in PIECES:
        if obj.name in ("Body", "Sleeve"):
            continue
        if anchor == "Arm":
            mats = [arm_matrix(-1), arm_matrix(1)]
        elif anchor == "Leg":
            mats = [leg_matrix(-1), leg_matrix(1)]
        else:
            mats = [anchors[anchor]]
        pm = preview_material(obj, tex)
        for m in mats:
            dup = obj.copy()
            dup.data = obj.data.copy()
            bpy.context.collection.objects.link(dup)
            dup.matrix_world = m @ Matrix.Translation(obj.location)
            dup.data.materials.clear()
            dup.data.materials.append(pm)
    for obj, _, _ in PIECES:
        obj.hide_render = True

    scene = bpy.context.scene
    for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = e
            break
        except Exception:
            pass
    try:
        scene.view_settings.view_transform = "Standard"
    except Exception:
        pass
    scene.render.resolution_x = 700
    scene.render.resolution_y = 900
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.012, 0.018, 0.04, 1)
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
    target = R(0, 0.5, 0)
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
    for obj, _, tex in PIECES:
        if tex:
            bake(obj, tex)
    export()
    preview()
    print("CAT BUILD OK", len(PIECES), "pieces")


main()
