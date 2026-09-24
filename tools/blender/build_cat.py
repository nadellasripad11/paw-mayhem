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

    def nearest(self, p):
        loc, normal, _, _ = self.bvh.find_nearest(p)
        return loc, normal


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
        parts.append(ellipsoid((0.5 * i, -0.3, -0.26), (0.44, 0.34, 0.4)))  # full, smooth cheeks
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
    EX, EY = 0.46, -0.09
    layers = {"EyeWhite": [], "Iris": [], "IrisGlow": [], "Pupil": [], "Shine": []}
    for i in (-1, 1):
        x = EX * i
        layers["EyeWhite"].append(decal(ellipse_pts(0.26, 0.295), surf, head, x, EY, 0.006, 0.01))
        layers["Iris"].append(decal(ellipse_pts(0.235, 0.265), surf, head, x, EY, 0.014, 0.008))
        layers["IrisGlow"].append(decal(ellipse_pts(0.185, 0.1), surf, head, x, EY - 0.14, 0.02, 0.008))
        layers["Pupil"].append(decal(ellipse_pts(0.195, 0.22), surf, head, x, EY + 0.015, 0.026, 0.008))
        layers["Shine"].append(decal(ellipse_pts(0.09, 0.1), surf, head, x + 0.085, EY + 0.11, 0.034, 0.008))
        layers["Shine"].append(decal(ellipse_pts(0.045, 0.045), surf, head, x - 0.095, EY - 0.13, 0.034, 0.008))
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
    smile = []
    for k in range(7):
        t = -1 + 2 * k / 6
        hit, n = surf.front(0.1 * t, -0.36 - 0.035 * (1 - t * t))
        smile.append(hit + n * 0.01)
    arcs = [tube(smile, 0.013, "mouth")]
    add("Mouth", arcs, 1200)



# ── BODY (root-local) ─────────────────────────────────────────────────────────
TORSO_C, TORSO_R = (0, -0.15, 0), (0.66, 0.58, 0.52)

# Hoodie body profile, top to bottom: (y, half-width, half-depth). A garment
# silhouette: rounded shoulders, straight sides, hem flaring a touch.
JACKET_RINGS = [
    (0.45, 0.29, 0.25), (0.42, 0.42, 0.34), (0.36, 0.56, 0.44), (0.27, 0.65, 0.5),
    (0.12, 0.68, 0.53), (-0.08, 0.68, 0.54), (-0.3, 0.69, 0.55), (-0.5, 0.71, 0.56),
    (-0.66, 0.73, 0.57),
]
HEM_Y = -0.66


def opening_half(y):
    """Half-width of the hoodie's open front at height y."""
    return 0.12 + (0.42 - y) * 0.045


def ring_at(y):
    """Interpolated (rx, rz) of the hoodie profile at height y."""
    for (y0, rx0, rz0), (y1, rx1, rz1) in zip(JACKET_RINGS, JACKET_RINGS[1:]):
        if y1 <= y <= y0:
            t = (y0 - y) / (y0 - y1)
            return rx0 + (rx1 - rx0) * t, rz0 + (rz1 - rz0) * t
    return JACKET_RINGS[-1][1], JACKET_RINGS[-1][2]


def lofted_shell(rings, segs=64, drape=0.0):
    """Open tube through elliptical rings (Roblox y, rx, rz), no caps.
    `drape` adds hanging vertical folds that grow towards the hem."""
    bm = bmesh.new()
    rows = []
    top = rings[0][0]
    for y, rx, rz in rings:
        t = max(0.0, min(1.0, (0.15 - y) / (0.15 - HEM_Y)))
        row = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            wave = 1 + drape * t * (0.7 * math.sin(7 * a + 0.6) + 0.3 * math.sin(12 * a + 2.1))
            row.append(bm.verts.new(R(math.sin(a) * rx * wave, y, -math.cos(a) * rz * wave)))
        rows.append(row)
    for r in range(len(rows) - 1):
        for k in range(segs):
            a, b = rows[r][k], rows[r][(k + 1) % segs]
            c, d = rows[r + 1][(k + 1) % segs], rows[r + 1][k]
            bm.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("shell")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("shell", me)
    bpy.context.collection.objects.link(o)
    return o


def crumple(obj, strength=0.03, scale=0.3, name="folds"):
    """Soft irregular fabric undulation (displace along normals)."""
    tex = bpy.data.textures.new(name, "CLOUDS")
    tex.noise_scale = scale
    tex.noise_depth = 2
    d = obj.modifiers.new("crumple", "DISPLACE")
    d.texture = tex
    d.strength = strength
    d.mid_level = 0.5
    d.texture_coords = "GLOBAL"
    apply_mods(obj)


def front_most(surfs, x, y):
    """The frontmost hit among several surfaces (front = Blender +Y)."""
    best = (None, None)
    for s in surfs:
        hit, n = s.front(x, y)
        if hit is not None and (best[0] is None or hit.y > best[0].y):
            best = (hit, n)
    return best


def rounded_box(size_r, bevel, segments=5, subdiv=1, local=False):
    """A soft box centred on the origin. Roblox sizes (x, y, z), or with
    local=True a surface-frame box (width, height, depth)."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    d = size_r if local else (size_r[0], size_r[2], size_r[1])
    o.data.transform(Matrix.Diagonal((d[0], d[1], d[2], 1.0)))
    bev = o.modifiers.new("bev", "BEVEL")
    bev.width = bevel
    bev.segments = segments
    if subdiv:
        sub = o.modifiers.new("sub", "SUBSURF")
        sub.levels = subdiv
    apply_mods(o)
    return o


def ring_tube(y, radius, lift, skip_front=True, tilt=0.0, name="ring"):
    """A soft bead running round the hoodie at height y."""
    rx, rz = ring_at(y)
    edge = math.asin(min(1.0, opening_half(y) / rx)) if skip_front else 0.0
    pts = []
    n = 40
    for k in range(n + 1):
        a = edge + (2 * math.pi - 2 * edge) * k / n
        pts.append(R(math.sin(a) * (rx + lift), y + tilt * math.cos(a), -math.cos(a) * (rz + lift)))
    return tube(pts, radius, name)


def build_body():
    piece(fuse([ellipsoid(TORSO_C, TORSO_R)], "Body", voxel=0.02, smooth=0, tris=3000), "Root", ("cloth", (255, 255, 255)))

    # Peach tee underneath, with a soft crew neck.
    shirt = fuse([
        ellipsoid((0, -0.14, 0.03), (0.6, 0.55, 0.44)),
        ellipsoid((0, 0.34, -0.04), (0.29, 0.09, 0.24)),
    ], "Shirt", voxel=0.02, smooth=3, tris=3500)
    crumple(shirt, 0.012, 0.2, "teefolds")
    piece(shirt, "Root", ("knit", SHIRT))

    # Hoodie: lofted garment shell with drape folds, open down the front.
    shell = lofted_shell(JACKET_RINGS, drape=0.035)
    sub = shell.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    apply_mods(shell)
    bm = bmesh.new()
    bm.from_mesh(shell.data)
    kill = []
    for face in bm.faces:
        x, y, z = rb(face.calc_center_median())
        if z < -0.15 and abs(x) < opening_half(y):
            kill.append(face)
    bmesh.ops.delete(bm, geom=list(set(kill)), context="FACES")
    bm.to_mesh(shell.data)
    bm.free()
    crumple(shell, 0.04, 0.32, "jacketfolds")
    so = shell.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.05
    so.offset = 1.0
    so.use_rim = True
    apply_mods(shell)
    parts = [shell]
    # Thick rounded front edges (so the fabric has visible depth) + hem.
    for i in (-1, 1):
        pts = []
        for k in range(14):
            y = 0.42 - (0.42 - HEM_Y) * k / 13
            rx, rz = ring_at(y)
            x = opening_half(y) + 0.01
            z = -rz * math.sqrt(max(0.0, 1 - (x / rx) ** 2)) - 0.03
            pts.append(R(x * i, y, z))
        parts.append(tube(pts, 0.036, "placket"))
    parts.append(ring_tube(HEM_Y + 0.01, 0.034, 0.028, name="hem"))
    # Hood: a soft roll round the back of the neck whose ends come round to
    # the front, with bunched, creased fabric behind.
    roll = []
    for k in range(11):
        a = math.pi * (-0.8 + 1.6 * k / 10)
        roll.append(R(math.sin(a) * 0.41, 0.43 + 0.05 * math.cos(a), math.cos(a) * 0.35 + 0.02))
    parts.append(tube(roll, 0.115, "hoodroll"))
    parts.append(ellipsoid((0, 0.38, 0.42), (0.48, 0.23, 0.21)))
    parts.append(ellipsoid((0, 0.2, 0.52), (0.36, 0.22, 0.15)))
    for dx, dy in ((-0.2, 0.3), (0.18, 0.26), (0.0, 0.1)):
        parts.append(ellipsoid((dx, dy, 0.58), (0.12, 0.08, 0.07)))
    jacket = fuse(parts, "Jacket", voxel=0.015, smooth=3, tris=12000)
    piece(jacket, "Root", ("cloth", JACKET))
    jsurf = Surface(jacket)
    ssurf = Surface(shirt)

    # Long white drawstrings from the hood's front ends, with metal tips.
    strings = []
    for i in (-1, 1):
        pts = []
        for y in (0.33, 0.18, 0.03, -0.12, -0.24):
            hit, n = front_most([jsurf, ssurf], 0.13 * i, y)
            pts.append(hit + n * 0.035)
        strings.append(tube(pts, 0.021, "string"))
        hit, n = front_most([jsurf, ssurf], 0.13 * i, -0.3)
        strings.append(disc(hit, n, 0.032, 0.065, 0.032, 0.035))
    o = join(strings, "Drawstrings")
    finish(o, 2500)
    piece(o, "Root", ("cord", (246, 246, 250)))

    # Dog tag: a rounded rectangle on a thin chain, resting on the tee.
    tag = []
    hit, n = ssurf.front(-0.02, 0.02)
    plate = rounded_box((0.15, 0.21, 0.03), 0.05, segments=5, subdiv=0, local=True)
    plate.data.transform(frame_at(hit, n).to_4x4())
    plate.data.transform(Matrix.Translation(hit + n * 0.035))
    tag.append(plate)
    for i in (-1, 1):
        pts = []
        for k in range(4):
            t = k / 3
            h2, n2 = ssurf.front(-0.02 + 0.12 * i * (1 - t), 0.33 - t * 0.2)
            pts.append(h2 + n2 * 0.02)
        tag.append(tube(pts, 0.01, "chain"))
    o = join(tag, "DogTag")
    finish(o, 1500)
    piece(o, "Root")

    # ── Pocket: a pillowy pouch that curves with the hoodie, piped edges and
    # a thick overhanging flap with a metal snap.
    hardware = []
    hit, n = jsurf.toward((-0.44, -0.46, -2), (0, 0, 1))
    F = frame_at(hit, n)
    Finv = F.inverted()
    W, H = 0.3, 0.26

    def surface_patch(w, h, cx, cy, bulge, lift, res=18, round_bottom=False):
        """A curved patch on the jacket around local (cx, cy): hugs the
        surface, bulges `bulge` in the middle, then gets thickness."""
        bpy.ops.mesh.primitive_grid_add(x_subdivisions=res, y_subdivisions=res, size=1)
        g = bpy.context.active_object
        g.data.transform(Matrix.Diagonal((w, h, 1, 1)))
        g.data.transform(Matrix.Translation(Vector((cx, cy, 0))))
        bm = bmesh.new()
        bm.from_mesh(g.data)
        if round_bottom:
            for v in bm.verts:
                u = (v.co.x - cx) / w * 2
                t = (v.co.y - cy) / h + 0.5  # 0 bottom .. 1 top
                if t < 0.45:  # curve the bottom edge into a soft point
                    v.co.y += (1 - t / 0.45) * 0.35 * abs(u) * h * 0.4
        for v in bm.verts:
            local = v.co.copy()
            u = (local.x - cx) / w * 2
            t = (local.y - cy) / h * 2
            pillow = bulge * max(0.0, 1 - u ** 4) * max(0.0, 1 - t ** 4)
            world = F @ Vector((local.x, local.y, 0)) + hit
            wh, wn = jsurf.nearest(world)
            v.co = (wh if wh is not None else world) + n * (lift + pillow)
        bm.to_mesh(g.data)
        bm.free()
        so = g.modifiers.new("solid", "SOLIDIFY")
        so.thickness = 0.018
        so.offset = -1
        bev = g.modifiers.new("bev", "BEVEL")
        bev.width = 0.006
        bev.segments = 2
        apply_mods(g)
        return g

    pocket_parts = [surface_patch(W, H, 0, 0, 0.045, 0.006)]
    # Raised piping round the pouch
    rim = []
    for k in range(41):
        a = 2 * math.pi * k / 40
        u, t = math.cos(a), math.sin(a)
        su = math.copysign(abs(u) ** 0.35, u) * W / 2 * 0.98
        st = math.copysign(abs(t) ** 0.35, t) * H / 2 * 0.98
        wp = F @ Vector((su, st, 0)) + hit
        wh, _ = jsurf.nearest(wp)
        rim.append((wh if wh is not None else wp) + n * 0.02)
    pocket_parts.append(tube(rim, 0.013, "piping"))
    # Thick flap overhanging the top of the pocket, soft point at the bottom
    pocket_parts.append(surface_patch(W + 0.03, 0.11, 0, H / 2 - 0.02, 0.02, 0.05, round_bottom=True))
    snap_at = F @ Vector((0, H / 2 - 0.07, 0)) + hit
    sh, _ = jsurf.nearest(snap_at)
    hardware.append(disc((sh or snap_at) + n * 0.09, n, 0.028, 0.028, 0.014, 0.0))
    o = join(pocket_parts, "Pocket")
    finish(o, 3500)
    piece(o, "Root", ("canvas", (214, 140, 80)))

    # ── Messenger bag on the other hip: soft rounded body with piped edges,
    # a thick flap folded over the top, buckle + tab, D-rings for the strap.
    bw, bh, bd = 0.4, 0.32, 0.17
    # Hang it on the outside of the hoodie at the left hip: its back rests on
    # the fabric and it faces out along the surface normal.
    bhit, bn = jsurf.toward((0.52, -0.6, -2), (0, 0, 1))
    bx, by, bz = rb(bn)
    yaw = math.degrees(math.atan2(-bx, -bz))
    bag_center = bhit + bn.normalized() * (bd / 2 + 0.03)
    BAG_CF = Matrix.Translation(bag_center) @ rot_r(4, yaw, 6).to_4x4()
    body = rounded_box((bw, bh, bd), 0.075, segments=6, subdiv=2)
    cast = body.modifiers.new("soft", "CAST")
    cast.factor = 0.18
    apply_mods(body)
    bag_parts = [body]
    # Piping round the front and back faces
    for face_z in (-bd / 2 + 0.005, bd / 2 - 0.005):
        pts = []
        for k in range(49):
            a = 2 * math.pi * k / 48
            u, t = math.cos(a), math.sin(a)
            pts.append(R(math.copysign(abs(u) ** 0.3, u) * (bw / 2 - 0.035), math.copysign(abs(t) ** 0.3, t) * (bh / 2 - 0.035), face_z))
        bag_parts.append(tube(pts, 0.013, "bagpiping"))
    # Flap: over the top and two thirds down the front, with a rounded edge
    top = rounded_box((bw + 0.03, 0.035, bd + 0.03), 0.015, segments=3, subdiv=1)
    top.data.transform(Matrix.Translation(R(0, bh / 2 + 0.005, 0)))
    front = rounded_box((bw + 0.03, bh * 0.66, 0.035), 0.03, segments=4, subdiv=1)
    front.data.transform(Matrix.Translation(R(0, bh / 2 - bh * 0.33 + 0.01, -bd / 2 - 0.022)))
    bag_parts += [top, front]
    # Leather tab from the flap down through the buckle
    tab = rounded_box((0.07, 0.14, 0.02), 0.012, segments=3, subdiv=0)
    tab.data.transform(Matrix.Translation(R(0, -bh * 0.12, -bd / 2 - 0.05)))
    bag_parts.append(tab)
    bag = join(bag_parts, "Bag")
    bag.data.transform(BAG_CF)
    finish(bag, 5000)
    piece(bag, "Root", ("leather", (158, 72, 56)))
    # Buckle frame + D-rings (metal)
    buckle_pts = []
    for k in range(25):
        a = 2 * math.pi * k / 24
        u, t = math.cos(a), math.sin(a)
        buckle_pts.append(R(math.copysign(abs(u) ** 0.4, u) * 0.055, math.copysign(abs(t) ** 0.4, t) * 0.04 - bh * 0.1, -bd / 2 - 0.065))
    buckle = tube(buckle_pts, 0.011, "buckle")
    buckle.data.transform(BAG_CF)
    hardware.append(buckle)
    # D-rings standing up on leather tabs at the bag's top corners, facing
    # front so you can see the strap loop through them.
    bag_rot = BAG_CF.to_3x3()
    bag_front = (bag_rot @ R(0, 0, -1)).normalized()
    bag_up = (bag_rot @ R(0, 1, 0)).normalized()
    rings = []
    tabs = []
    for sx in (-1, 1):
        center_local = R(sx * (bw / 2 - 0.04), bh / 2 + 0.075, 0)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.012, major_segments=28, minor_segments=8)
        ring = bpy.context.active_object
        ring.data.transform(Matrix.Rotation(math.radians(90), 4, "X"))  # stand it up, facing front
        ring.data.transform(Matrix.Translation(center_local))
        ring.data.transform(BAG_CF)
        hardware.append(ring)
        # leather tab from the bag top up round the ring's bottom bar
        tab = rounded_box((0.07, 0.07, 0.03), 0.012, segments=3, subdiv=0)
        tab.data.transform(Matrix.Translation(center_local + R(0, -0.05, 0)))
        tab.data.transform(BAG_CF)
        tabs.append(tab)
        rings.append(BAG_CF @ center_local)

    def ribbon(points, normals, width=0.075, thickness=0.018, name="strapband"):
        """A flat leather band with real thickness and softened edges."""
        bm = bmesh.new()
        left, right = [], []
        count = len(points)
        for i, p in enumerate(points):
            t = (points[min(i + 1, count - 1)] - points[max(i - 1, 0)]).normalized()
            side = normals[i].normalized().cross(t).normalized()
            left.append(bm.verts.new(p + side * width / 2))
            right.append(bm.verts.new(p - side * width / 2))
        for i in range(count - 1):
            bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(o)
        so = o.modifiers.new("solid", "SOLIDIFY")
        so.thickness = thickness
        so.offset = 0.0
        bev = o.modifiers.new("bev", "BEVEL")
        bev.width = thickness * 0.35
        bev.segments = 2
        apply_mods(o)
        return o

    # ── Crossbody strap: lies flat on the hoodie (stretched straight over the
    # open front), runs down to each D-ring, over its top bar and folds back.
    proxy = lofted_shell([(y, rx + 0.06, rz + 0.06) for y, rx, rz in JACKET_RINGS])
    psub = proxy.modifiers.new("sub", "SUBSURF")
    psub.levels = 1
    apply_mods(proxy)
    psurf = Surface(proxy)
    bpy.data.objects.remove(proxy)
    def on_top(origin_r, dir_r):
        """Outermost of the real hoodie surface and the closed proxy, so the
        strap sits on the fabric folds but still bridges the open front."""
        best = (None, None)
        for srf in (psurf, jsurf):
            h, nn = srf.toward(origin_r, dir_r)
            if h is None:
                continue
            if best[0] is None or (h - R(*origin_r)).length < (best[0] - R(*origin_r)).length:
                best = (h, nn)
        return best

    inner_ring = min(rings, key=lambda p: p.x)
    outer_ring = max(rings, key=lambda p: p.x)

    def ring_tail(last_p, last_n, ring):
        """Points taking the band from the body down onto a ring, over its top
        bar and folding back, turning gradually to face the bag."""
        above = ring + bag_up * 0.12
        bar = ring + bag_up * 0.045 - bag_front * 0.006
        over = ring + bag_up * 0.05 + bag_front * 0.03
        back = ring + bag_front * 0.035
        out = []
        for j, p in enumerate((last_p.lerp(above, 0.5), above, bar, over, back)):
            out.append((p, last_n.lerp(-bag_front, min(1.0, (j + 1) / 2)).normalized()))
        return out

    # One continuous band round the body in a tilted plane: high over the
    # right shoulder, low at the left hip where it meets the bag's rings.
    ix, iy, iz = rb(inner_ring)
    ox, oy, oz = rb(outer_ring)
    ring_y = max(iy, oy) + 0.12
    slope = (ring_y - 0.37) / (0.6 + 0.5)

    def loop_y(x):
        return min(0.37, 0.37 + (x + 0.5) * slope)

    th_in = math.atan2(ix, -iz)
    th_out = math.atan2(ox, -oz) - 2 * math.pi
    loop = []
    steps = 64
    for k in range(steps + 1):
        th = (th_in - 0.1) + ((th_out + 0.1) - (th_in - 0.1)) * k / steps
        d = Vector((math.sin(th), 0, -math.cos(th)))
        x_guess = d.x * 0.7
        hit2 = n2 = None
        for _ in range(2):
            y = loop_y(x_guess)
            hit2, n2 = on_top((d.x * 3, y, d.z * 3), (-d.x, 0, -d.z))
            if hit2 is None:
                break
            x_guess = rb(hit2)[0]
        if hit2 is not None:
            loop.append((hit2 + n2 * 0.016, n2))
    start = list(reversed(ring_tail(loop[0][0], loop[0][1], inner_ring)))
    end = ring_tail(loop[-1][0], loop[-1][1], outer_ring)
    path = start + loop + end
    strap = [ribbon([p for p, _ in path], [n for _, n in path])]
    strap += tabs
    # Buckle slider high on the chest (front part of the loop)
    front = [(p, n) for p, n in loop if rb(p)[2] < -0.3 and rb(p)[0] < -0.1]
    if len(front) > 3:
        (a, n3), (b, _) = front[len(front) // 2], front[len(front) // 2 + 1]
        n3 = n3.normalized()
        along = (b - a).normalized()
        side = n3.cross(along).normalized()
        m = Matrix((side, along, n3)).transposed().to_4x4()
        slider = []
        for k in range(21):
            ang = 2 * math.pi * k / 20
            u, t = math.cos(ang), math.sin(ang)
            slider.append(Vector((math.copysign(abs(u) ** 0.4, u) * 0.055, math.copysign(abs(t) ** 0.4, t) * 0.03, 0.016)))
        hardware.append(tube([m @ p + a.lerp(b, 0.5) for p in slider], 0.01, "slider"))
    o = join(strap, "Strap")
    finish(o, 4000)
    piece(o, "Root", ("leather", (184, 110, 62)))
    hw = join(hardware, "Hardware")
    finish(hw, 3000)
    piece(hw, "Root")

    # Shorts seat (mostly hidden under the hoodie hem).
    seat = [ellipsoid((0, -0.72, 0.02), (0.56, 0.2, 0.44))]
    for i in (-1, 1):
        seat.append(cone_between((0.3 * i, -0.7, 0.0), (0.3 * i, -0.86, 0.0), 0.31, 0.33, verts=40))
        seat.append(tube([R(0.36 * i, -0.62, -0.4), R(0.45 * i, -0.72, -0.37), R(0.5 * i, -0.8, -0.31)], 0.011, "pocketseam"))
    seat.append(tube([R(0, -0.62, -0.44), R(0, -0.76, -0.43), R(0, -0.86, -0.36)], 0.012, "centreseam"))
    hips = fuse(seat, "Hips", voxel=0.013, smooth=2, tris=4000)
    crumple(hips, 0.012, 0.12, "seatfolds")
    piece(hips, "Root", ("cloth", (255, 255, 255)))


# ── ARM (arm-local: the sleeve's centre is the origin, hanging down) ────────
def build_arm():
    # Sleeve: tapered, rounded shoulder cap, a raised seam where it joins the
    # shoulder and one down the back, and irregular diagonal wrinkles.
    parts = [
        ellipsoid((0, 0.2, 0), (0.235, 0.16, 0.235)),
        cone_between((0, 0.22, 0), (0, -0.22, 0), 0.222, 0.205, verts=48),
    ]
    for y, tilt, roll, minor in ((-0.15, 18, 10, 0.024), (-0.06, -12, -14, 0.02), (0.05, 9, 22, 0.016), (-0.19, -6, 30, 0.018)):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.212, minor_radius=minor, major_segments=48, minor_segments=10)
        ring = bpy.context.active_object
        ring.data.transform(Matrix.Rotation(math.radians(tilt), 4, "X"))
        ring.data.transform(Matrix.Rotation(math.radians(roll), 4, "Y"))
        ring.data.transform(Matrix.Translation(R(0, y, 0)))
        parts.append(ring)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.232, minor_radius=0.012, major_segments=48, minor_segments=8)
    seam = bpy.context.active_object
    seam.data.transform(Matrix.Rotation(math.radians(-14), 4, "Y"))
    seam.data.transform(Matrix.Translation(R(0, 0.25, 0)))
    parts.append(seam)
    parts.append(tube([R(0, 0.24, 0.228), R(0, 0.0, 0.222), R(0, -0.2, 0.21)], 0.009, "backseam"))
    sleeve = fuse(parts, "Sleeve", voxel=0.01, smooth=3, tris=4500)
    crumple(sleeve, 0.022, 0.1, "sleevefolds")
    piece(sleeve, "Arm", ("cloth", (255, 255, 255)))
    hs = sleeve.copy()
    hs.data = sleeve.data.copy()
    bpy.context.collection.objects.link(hs)
    hs.name = "HoodieSleeve"
    hs.data.name = "HoodieSleeve"
    piece(hs, "Arm", ("cloth", JACKET))

    # Turned-back cuff: a hollow band (you can see into the sleeve around the
    # wrist) with a rolled lip.
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.232, depth=0.12, end_fill_type="NOTHING")
    band = bpy.context.active_object
    band.data.transform(Matrix.Translation(R(0, -0.25, 0)))
    so = band.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.03
    so.offset = 1.0
    so.use_rim = True
    apply_mods(band)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.248, minor_radius=0.022, major_segments=48, minor_segments=10)
    lip = bpy.context.active_object
    lip.data.transform(Matrix.Translation(R(0, -0.31, 0)))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.246, minor_radius=0.016, major_segments=48, minor_segments=8)
    top_lip = bpy.context.active_object
    top_lip.data.transform(Matrix.Translation(R(0, -0.19, 0)))
    piece(fuse([band, lip, top_lip], "Cuff", voxel=0.009, smooth=2, tris=3000), "Arm", ("cloth", (255, 255, 255)))

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
    # Boxy shorts leg: a wide tube over the thigh with a rolled, turned-up hem.
    bm = bmesh.new()
    rows = []
    rings = [(0.3, 0.315), (0.18, 0.33), (0.06, 0.345), (-0.04, 0.36), (-0.1, 0.365)]
    for idx, (y, r) in enumerate(rings):
        t = idx / (len(rings) - 1)
        row = []
        for k in range(48):
            ang = 2 * math.pi * k / 48
            wave = 1 + 0.045 * t * (0.7 * math.sin(5 * ang + 0.4) + 0.3 * math.sin(9 * ang + 1.7))
            row.append(bm.verts.new(R(math.sin(ang) * r * wave, y, -math.cos(ang) * r * wave)))
        rows.append(row)
    for r_ in range(len(rows) - 1):
        for k in range(48):
            bm.faces.new((rows[r_][k], rows[r_][(k + 1) % 48], rows[r_ + 1][(k + 1) % 48], rows[r_ + 1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("shortsleg")
    bm.to_mesh(me)
    bm.free()
    tubeo = bpy.data.objects.new("shortsleg", me)
    bpy.context.collection.objects.link(tubeo)
    sub = tubeo.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    so = tubeo.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.03
    so.offset = 1.0
    so.use_rim = True
    apply_mods(tubeo)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.375, minor_radius=0.024, major_segments=48, minor_segments=10)
    hem = bpy.context.active_object
    hem.data.transform(Matrix.Translation(R(0, -0.1, 0)))
    s = fuse([tubeo, hem], "ShortsLeg", voxel=0.011, smooth=2, tris=4000)
    crumple(s, 0.014, 0.12, "shortsfolds")
    piece(s, "Leg", ("cloth", (255, 255, 255)))


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
TEX_SIZE = {"fur_head": 1024, "fur_plain": 512, "cloth": 512, "knit": 512, "leather": 512, "canvas": 256, "cord": 256}
CLOTH_KINDS = ("cloth", "knit", "leather", "canvas", "cord")
JACKET = (52, 46, 66)
SHIRT = (236, 168, 148)


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


def build_bake_material(obj, kind, base_rgb=(255, 255, 255)):
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
    elif kind == "cloth":
        nz.inputs["Scale"].default_value = 300  # cotton weave
        fine.inputs["Scale"].default_value = 6  # very soft folds
        strength, dist = 0.2, 0.015
    elif kind == "leather":
        nz.inputs["Scale"].default_value = 90  # pebbled grain
        fine.inputs["Scale"].default_value = 14
        strength, dist = 0.25, 0.012
    elif kind == "canvas":
        nz.inputs["Scale"].default_value = 380
        fine.inputs["Scale"].default_value = 8
        strength, dist = 0.22, 0.012
    elif kind == "cord":
        mp.inputs["Scale"].default_value = (1, 1, 6)  # twisted cord
        nz.inputs["Scale"].default_value = 160
        fine.inputs["Scale"].default_value = 30
        strength, dist = 0.25, 0.01
    else:  # knit
        nz.inputs["Scale"].default_value = 420
        fine.inputs["Scale"].default_value = 30
        strength, dist = 0.3, 0.015
    height = N.new("ShaderNodeMath")
    height.operation = "MULTIPLY_ADD"
    height.inputs[1].default_value = 0.12 if kind in ("cloth", "canvas") else 0.35
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
    cloth = kind in CLOTH_KINDS
    # Clothes get deeper contact shadows: creases, under the hood and pocket
    # flap, inside the open front, where the strap sits.
    ao.inputs["Distance"].default_value = 0.3 if cloth else 0.25
    aof = N.new("ShaderNodeMapRange")
    aof.inputs["To Min"].default_value = 0.5 if cloth else 0.8
    L.new(ao.outputs["AO"], aof.inputs["Value"])
    var = N.new("ShaderNodeMapRange")
    var.inputs["To Min"].default_value = 0.94 if kind.startswith("fur") else 0.9
    L.new(nz.outputs["Fac"], var.inputs["Value"])
    shade = N.new("ShaderNodeMath")
    shade.operation = "MULTIPLY"
    L.new(aof.outputs["Result"], shade.inputs[0])
    L.new(var.outputs["Result"], shade.inputs[1])
    base = N.new("ShaderNodeRGB")
    # White = tinted with the player's colour in Roblox; otherwise baked in.
    base.outputs[0].default_value = srgb(base_rgb)
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
        width.inputs[1].default_value = 0.85
        width.inputs[2].default_value = -0.85 * 0.4
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
        # Soft pink blush on each cheek, just under the eyes.
        dx = N.new("ShaderNodeMath")
        dx.operation = "SUBTRACT"
        dx.inputs[1].default_value = 0.7
        L.new(ax.outputs["Value"], dx.inputs[0])
        dz = N.new("ShaderNodeMath")
        dz.operation = "ADD"
        dz.inputs[1].default_value = 0.3
        L.new(sep.outputs["Z"], dz.inputs[0])
        comb2 = N.new("ShaderNodeCombineXYZ")
        L.new(dx.outputs["Value"], comb2.inputs["X"])
        L.new(dz.outputs["Value"], comb2.inputs["Y"])
        dist = N.new("ShaderNodeVectorMath")
        dist.operation = "LENGTH"
        L.new(comb2.outputs["Vector"], dist.inputs[0])
        soft = N.new("ShaderNodeMapRange")
        soft.inputs["From Min"].default_value = 0.07
        soft.inputs["From Max"].default_value = 0.19
        soft.inputs["To Min"].default_value = 0.85
        soft.inputs["To Max"].default_value = 0.0
        L.new(dist.outputs["Value"], soft.inputs["Value"])
        bmask = N.new("ShaderNodeMath")
        bmask.operation = "MULTIPLY"
        L.new(soft.outputs["Result"], bmask.inputs[0])
        L.new(front.outputs["Result"], bmask.inputs[1])
        blush = N.new("ShaderNodeMix")
        blush.data_type = "RGBA"
        blush.blend_type = "MULTIPLY"
        L.new(bmask.outputs["Value"], blush.inputs["Factor"])
        L.new(tan.outputs[2], blush.inputs[6])
        blush.inputs[7].default_value = (1.0, 0.62, 0.66, 1)
        final = blush
    emit = N.new("ShaderNodeEmission")
    L.new(final.outputs[2], emit.inputs["Color"])
    img_node = N.new("ShaderNodeTexImage")
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return mat, out, bsdf, emit, img_node


def bake(obj, tex):
    kind, base_rgb = (tex, (255, 255, 255)) if isinstance(tex, str) else tex
    os.makedirs(TEX_DIR, exist_ok=True)
    unwrap(obj)
    mat, out, bsdf, emit, img_node = build_bake_material(obj, kind, base_rgb)
    size = 1024 if obj.name == "Jacket" else TEX_SIZE[kind]
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
    "Hips": (40, 38, 52), "ShortsLeg": (40, 38, 52), "Cuff": (40, 36, 52), "Sleeve": JACKET, "Body": JACKET,
}
FLAT = {
    "EarTufts": (255, 248, 244), "InnerEar": (255, 158, 172), "Nose": (255, 140, 160), "Blush": (255, 196, 204),
    "Mouth": (120, 70, 74), "Brows": (228, 192, 170), "EyeWhite": (18, 16, 22), "Iris": (18, 58, 58),
    "IrisGlow": (60, 170, 150), "Pupil": (8, 8, 12), "Shine": (255, 255, 255), "Sleeve": JACKET, "Cuff": (46, 38, 56),
    "Drawstrings": (246, 246, 250), "DogTag": (236, 238, 242), "Pocket": (214, 140, 80), "Bag": (158, 72, 56), "Strap": (184, 110, 62), "Hardware": (222, 186, 104),
    "Hips": (40, 38, 52), "ShortsLeg": (40, 38, 52), "Body": JACKET,
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
    if obj.name in ("Hardware", "DogTag"):
        b.inputs["Metallic"].default_value = 1.0
        b.inputs["Roughness"].default_value = 0.3
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
    for attr in ("use_gtao", "use_shadows"):
        try:
            setattr(scene.eevee, attr, True)
        except Exception:
            pass
    scene.render.resolution_x = 700
    scene.render.resolution_y = 900
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.012, 0.018, 0.04, 1)
    scene.world = world
    light("key", "AREA", (4, 6, -7), 1100, 5)
    light("fill", "AREA", (-6, 2, -5), 260, 7)
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
    # Close-up of the bag, strap and pocket
    tgt = R(0.35, -0.4, -0.4)
    pos = tgt + R(1.3, 0.5, -3.4)
    cam.location = pos
    cam.rotation_quaternion = (tgt - pos).to_track_quat("-Z", "Y")
    scene.render.filepath = os.path.join(OUT_PREVIEW, "preview_bag.png")
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
