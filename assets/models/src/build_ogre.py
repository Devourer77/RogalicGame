# Строит low-poly огра-босса со скелетом и анимациями и экспортирует в .glb.
# Масштаб: 1 единица = 1 метр, рост ~2.05 м (массивный гигант с шипастой дубиной).
# Смотрит в -Y (после экспорта в glTF это +Z).
import bpy
import bmesh
import math
from mathutils import Vector, Matrix

SCENE_NAME = "Ogre"


# ---------- Материалы ----------

def mat(name, color, metallic=0.0, rough=0.78, emission=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.8
    m.diffuse_color = (*color, 1.0)
    return m


# ---------- Примитивы через bmesh ----------

PARTS = []


def _finish(bm, name, material, bone, matrix=None):
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    vg = ob.vertex_groups.new(name=bone)
    vg.add([v.index for v in me.vertices], 1.0, "REPLACE")
    PARTS.append(ob)
    return ob


def _rot(r):
    return (Matrix.Rotation(math.radians(r[2]), 4, "Z")
            @ Matrix.Rotation(math.radians(r[1]), 4, "Y")
            @ Matrix.Rotation(math.radians(r[0]), 4, "X"))


def box(name, size, loc, material, bone, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(loc) @ _rot(rot) @ Matrix.Diagonal((*size, 1.0))
    return _finish(bm, name, material, bone, m)


def cyl(name, r1, r2, z0, z1, material, bone, segs=8, loc=(0, 0), scale_y=1.0, rot=(0, 0, 0)):
    bm = bmesh.new()
    depth = z1 - z0
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    m = Matrix.Translation((loc[0], loc[1], (z0 + z1) / 2)) @ _rot(rot) @ Matrix.Diagonal((1, scale_y, 1, 1))
    return _finish(bm, name, material, bone, m)


def limb(name, a, b, r1, r2, material, bone, segs=6):
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=d.length)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
    return _finish(bm, name, material, bone, m)


def sphere(name, r, loc, material, bone, scale=(1, 1, 1), segs=8, rings=5, cut_below=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    if cut_below is not None:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, cut_below), plane_no=(0, 0, 1), clear_inner=True)
        edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        bmesh.ops.edgeloop_fill(bm, edges=edges)
    m = Matrix.Translation(loc) @ Matrix.Diagonal((*scale, 1))
    return _finish(bm, name, material, bone, m)


def prism(name, points_xz, thickness, loc, material, bone, rot=(0, 0, 0)):
    bm = bmesh.new()
    verts = [bm.verts.new((x, -thickness / 2, z)) for x, z in points_xz]
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [v for v in res["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, thickness, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    m = Matrix.Translation(loc) @ _rot(rot)
    return _finish(bm, name, material, bone, m)


# ---------- Модель ----------

def build_mesh():
    skin = mat("Ogre_Skin", (0.42, 0.22, 0.08), rough=0.78)
    leather = mat("Ogre_Leather", (0.14, 0.08, 0.04), rough=0.85)
    fur = mat("Ogre_Fur", (0.24, 0.19, 0.15), rough=0.9)
    iron = mat("Ogre_Iron", (0.15, 0.17, 0.20), metallic=0.82, rough=0.42)
    steel = mat("Ogre_Steel", (0.38, 0.40, 0.45), metallic=0.85, rough=0.35)
    bone_mat = mat("Ogre_Bone", (0.88, 0.82, 0.66), rough=0.45)
    wood = mat("Ogre_Wood", (0.24, 0.12, 0.05), rough=0.85)
    wood_end = mat("Ogre_WoodEnd", (0.48, 0.30, 0.15), rough=0.8)
    eyes = mat("Ogre_Eyes", (1.0, 0.85, 0.45), rough=0.3, emission=(1.0, 0.78, 0.35))

    for side, s in (("R", -1), ("L", 1)):
        x = 0.20 * s
        # Тяжёлые сапоги с железными накладками и мощные ноги
        box(f"Boot.{side}", (0.22, 0.34, 0.14), (x, -0.06, 0.07), leather, f"Foot.{side}")
        box(f"BootStrap.{side}", (0.23, 0.10, 0.15), (x, -0.08, 0.075), iron, f"Foot.{side}")
        limb(f"Shin.{side}", (x, 0, 0.13), (x, 0, 0.46), 0.125, 0.145, leather, f"Shin.{side}", segs=8)
        box(f"ShinPlate.{side}", (0.16, 0.06, 0.20), (x, -0.12, 0.28), iron, f"Shin.{side}", rot=(6, 0, 0))
        sphere(f"Knee.{side}", 0.135, (x, -0.02, 0.48), skin, f"Shin.{side}")
        limb(f"Thigh.{side}", (x, 0, 0.48), (x, 0, 0.84), 0.155, 0.185, skin, f"Thigh.{side}", segs=8)

        # Огромные мускулистые руки, кожаные наручи со стальной пластиной и кулаки
        ax = 0.39 * s
        sphere(f"Shoulder.{side}", 0.165, (ax, 0, 1.54), skin, f"UpperArm.{side}")
        limb(f"UpperArm.{side}", (ax, 0, 1.52), (ax + 0.04 * s, 0, 1.18), 0.145, 0.125, skin, f"UpperArm.{side}", segs=8)
        sphere(f"Elbow.{side}", 0.12, (ax + 0.04 * s, 0.02, 1.18), skin, f"ForeArm.{side}")
        limb(f"ForeArm.{side}", (ax + 0.04 * s, 0, 1.18), (ax + 0.06 * s, -0.04, 0.86), 0.125, 0.135, skin, f"ForeArm.{side}", segs=8)
        limb(f"Bracer.{side}", (ax + 0.048 * s, -0.015, 1.08), (ax + 0.06 * s, -0.04, 0.87), 0.138, 0.145, leather, f"ForeArm.{side}", segs=8)
        box(f"BracerPlate.{side}", (0.04, 0.14, 0.18), (ax + 0.175 * s, -0.03, 0.97), iron, f"ForeArm.{side}")
        box(f"Hand.{side}", (0.18, 0.19, 0.18), (ax + 0.06 * s, -0.05, 0.76), skin, f"Hand.{side}")

    # Массивный шипастый наплечник из тёмного железа на левом плече (UpperArm.L)
    sphere("Pauldron.L", 0.24, (0.41, 0, 1.56), iron, "UpperArm.L",
           scale=(1.15, 1.12, 0.95), segs=8, rings=5, cut_below=-0.04)
    sphere("PauldronRim.L", 0.252, (0.41, 0, 1.54), steel, "UpperArm.L",
           scale=(1.17, 1.14, 0.28), segs=8, rings=4, cut_below=-0.01)
    # Шипы на наплечнике
    pauldron_spikes = [
        ((0.46, -0.02, 1.72), (0.56, -0.03, 1.92), 0.045),
        ((0.57, -0.03, 1.63), (0.75, -0.05, 1.74), 0.042),
        ((0.44, 0.14, 1.68), (0.52, 0.24, 1.84), 0.038),
        ((0.54, 0.12, 1.58), (0.69, 0.20, 1.66), 0.038),
        ((0.36, -0.18, 1.60), (0.41, -0.26, 1.66), 0.032),
    ]
    for i, (sa, sb, sr) in enumerate(pauldron_spikes):
        limb(f"PauldronSpike.{i}", sa, sb, sr, 0.004, steel, "UpperArm.L", segs=4)

    # Таз, меховая юбка, широкий кожаный пояс, набедренная повязка и пряжка-череп (Hips)
    cyl("Hips", 0.30, 0.33, 0.74, 0.96, fur, "Hips", segs=10, scale_y=0.86)
    # Зубцы меха по кругу пояса
    for angle_deg in range(0, 360, 36):
        rad = math.radians(angle_deg)
        fx, fy = math.sin(rad) * 0.31, -math.cos(rad) * 0.27
        limb(f"FurTooth_{angle_deg}", (fx, fy, 0.80), (fx * 1.06, fy * 1.06, 0.60), 0.075, 0.01, fur, "Hips", segs=4)
    cyl("Belt", 0.345, 0.345, 0.84, 0.96, leather, "Hips", segs=10, scale_y=0.88)
    loin_front = [(-0.16, 0.0), (0.16, 0.0), (0.12, -0.26), (0.0, -0.36), (-0.12, -0.26)]
    prism("LoinFront", loin_front, 0.035, (0, -0.295, 0.85), leather, "Hips", rot=(8, 0, 0))
    # Железная пряжка-череп
    sphere("SkullBuckle", 0.085, (0, -0.315, 0.91), steel, "Hips", scale=(1.0, 0.55, 0.95), segs=6, rings=4)
    box("SkullJaw", (0.09, 0.05, 0.065), (0, -0.32, 0.84), steel, "Hips")
    for side, s in (("R", -1), ("L", 1)):
        box(f"SkullEye.{side}", (0.032, 0.03, 0.028), (0.032 * s, -0.355, 0.915), iron, "Hips")

    # Большой живот и широкая мускулистая грудь с кожаным ремнём через плечо (Spine, Chest)
    sphere("Belly", 0.35, (0, -0.04, 1.12), skin, "Spine", scale=(1.02, 0.94, 0.85), segs=10, rings=6)
    cyl("ChestLow", 0.33, 0.39, 1.20, 1.52, skin, "Chest", segs=8, scale_y=0.78)
    cyl("ChestHigh", 0.39, 0.23, 1.52, 1.66, skin, "Chest", segs=8, scale_y=0.76)
    cyl("CrossStrap", 0.382, 0.382, 1.32, 1.42, leather, "Chest", segs=8, scale_y=0.81, rot=(0, -20, 0))
    cyl("NeckTraps", 0.22, 0.16, 1.60, 1.70, skin, "Chest", segs=8, scale_y=0.82)

    # Голова огра: тяжёлая нижняя челюсть, два торчащих клыка и железный обруч на лбу (Head)
    sphere("HeadSkull", 0.17, (0, -0.02, 1.83), skin, "Head", scale=(1.02, 1.05, 0.98), segs=8, rings=5)
    box("Jaw", (0.24, 0.22, 0.12), (0, -0.08, 1.68), skin, "Head")
    box("Chin", (0.18, 0.08, 0.085), (0, -0.17, 1.67), skin, "Head")
    box("Brow", (0.24, 0.09, 0.048), (0, -0.15, 1.84), skin, "Head", rot=(10, 0, 0))
    limb("Nose", (0, -0.15, 1.82), (0, -0.21, 1.76), 0.042, 0.030, skin, "Head", segs=5)
    for side, s in (("R", -1), ("L", 1)):
        # Крупные белые клыки по углам нижней челюсти (не закрывают глаза!)
        limb(f"Tusk.{side}", (0.095 * s, -0.175, 1.67), (0.105 * s, -0.195, 1.77), 0.028, 0.005, bone_mat, "Head", segs=5)
        # Маленькие злые светящиеся глаза под бровью
        box(f"Eye.{side}", (0.042, 0.022, 0.022), (0.055 * s, -0.175, 1.81), eyes, "Head", rot=(0, 0, -8 * s))
        # Острые уши огра
        limb(f"Ear.{side}", (0.16 * s, 0.0, 1.80), (0.24 * s, 0.03, 1.85), 0.042, 0.01, skin, "Head", segs=4)

    # Железный обруч с наносником на голове
    cyl("BrowBand", 0.18, 0.18, 1.85, 1.91, iron, "Head", segs=10, loc=(0, -0.02), scale_y=1.05)
    box("BrowNosePlate", (0.048, 0.03, 0.085), (0, -0.195, 1.86), steel, "Head")

    # Огромная деревянная дубина, окованная железными кольцами и шипами, в правой руке (Hand.R)
    # Отведена немного вправо-вперёд, чтобы не закрывать мощную грудь и череп на поясе
    hx, hy, hz = -0.45, -0.05, 0.76
    p_handle = Vector((hx + 0.04, hy + 0.10, hz - 0.08))
    p_tip = Vector((hx - 0.34, hy - 0.42, hz + 0.82))
    club_dir = (p_tip - p_handle).normalized()
    club_len = (p_tip - p_handle).length

    limb("ClubPommel", p_handle + club_dir * (-0.06), p_handle, 0.055, 0.045, iron, "Hand.R", segs=8)
    limb("ClubShaft", p_handle, p_tip, 0.048, 0.155, wood, "Hand.R", segs=8)
    limb("ClubCap", p_tip - club_dir * 0.02, p_tip + club_dir * 0.015, 0.145, 0.135, wood_end, "Hand.R", segs=8)

    # Ортогональный базис поперёк дубины для железных колец и шипов
    u_vec = club_dir.cross(Vector((0, 1, 0))).normalized()
    v_vec = club_dir.cross(u_vec).normalized()
    for t_frac, r_band in ((0.46, 0.108), (0.68, 0.135), (0.88, 0.160)):
        c_pos = p_handle + club_dir * (club_len * t_frac)
        limb(f"ClubBand_{t_frac}", c_pos - club_dir * 0.035, c_pos + club_dir * 0.035,
             r_band, r_band * 1.03, iron, "Hand.R", segs=8)
        for sp_idx in range(6):
            ang = math.radians(sp_idx * 60 + (30 if t_frac == 0.68 else 0))
            radial = u_vec * math.cos(ang) + v_vec * math.sin(ang)
            sp_base = c_pos + radial * (r_band * 0.95)
            sp_tip = c_pos + radial * (r_band + 0.12)
            limb(f"ClubSpike_{t_frac}_{sp_idx}", sp_base, sp_tip, 0.026, 0.003, steel, "Hand.R", segs=4)

    bpy.ops.object.select_all(action="DESELECT")
    for ob in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "OgreMesh"
    body.data.name = "OgreMesh"
    return body


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.30), None),
    "Hips": ((0, 0, 0.84), (0, 0, 0.96), "Root"),
    "Spine": ((0, 0, 0.96), (0, 0, 1.26), "Hips"),
    "Chest": ((0, 0, 1.26), (0, 0, 1.62), "Spine"),
    "Head": ((0, 0, 1.62), (0, 0, 1.98), "Chest"),
}
for side, s in (("R", -1), ("L", 1)):
    ax, lx = 0.39 * s, 0.20 * s
    BONES.update({
        f"UpperArm.{side}": ((ax, 0, 1.52), (ax + 0.04 * s, 0, 1.18), "Chest"),
        f"ForeArm.{side}": ((ax + 0.04 * s, 0, 1.18), (ax + 0.06 * s, -0.04, 0.86), f"UpperArm.{side}"),
        f"Hand.{side}": ((ax + 0.06 * s, -0.04, 0.86), (ax + 0.06 * s, -0.06, 0.72), f"ForeArm.{side}"),
        f"Thigh.{side}": ((lx, 0, 0.84), (lx, 0, 0.48), "Hips"),
        f"Shin.{side}": ((lx, 0, 0.48), (lx, 0, 0.13), f"Thigh.{side}"),
        f"Foot.{side}": ((lx, 0, 0.13), (lx, -0.18, 0.04), f"Shin.{side}"),
    })


def build_armature():
    arm_data = bpy.data.armatures.new("OgreRig")
    rig = bpy.data.objects.new("Ogre", arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (h, t, parent) in BONES.items():
        b = arm_data.edit_bones.new(name)
        b.head, b.tail = h, t
        b.roll = 0.0
    for name, (h, t, parent) in BONES.items():
        if parent:
            arm_data.edit_bones[name].parent = arm_data.edit_bones[parent]
            arm_data.edit_bones[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    return rig


# ---------- Анимации ----------

def key(rig, frame, pose, loc=None):
    for pb in rig.pose.bones:
        r = pose.get(pb.name, (0, 0, 0))
        pb.rotation_euler = tuple(math.radians(a) for a in r)
        pb.keyframe_insert("rotation_euler", frame=frame)
        if pb.name in ("Root", "Hips"):
            wx, wy, wz = (loc or {}).get(pb.name, (0, 0, 0))
            pb.location = (wx, wz, -wy)
            pb.keyframe_insert("location", frame=frame)


def new_action(rig, name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    return act


def finish_action(rig, act, frames, cyclic=False):
    act.frame_range = (0, frames)
    act.use_frame_range = True
    act.use_cyclic = cyclic
    track = rig.animation_data.nla_tracks.new()
    track.name = act.name
    track.strips.new(act.name, 0, act)
    track.mute = True
    rig.animation_data.action = None


# Стойка огра: тяжёлая дубина в правой руке отведена чуть в сторону наготове
STANCE = {
    "Spine": (4, 0, 0), "Chest": (4, 0, 0), "Head": (-6, 0, 0),
    "UpperArm.R": (-6, 0, 0), "ForeArm.R": (-10, 0, 0), "Hand.R": (0, 0, 0),
    "UpperArm.L": (-8, 0, -10), "ForeArm.L": (-24, 0, 0), "Hand.L": (0, 0, 0),
    "Thigh.R": (-8, 0, 0), "Shin.R": (14, 0, 0), "Foot.R": (-6, 0, 0),
    "Thigh.L": (-8, 0, 0), "Shin.L": (14, 0, 0), "Foot.L": (-6, 0, 0),
}


def pose(**changes):
    p = dict(STANCE)
    for k, v in changes.items():
        p[k.replace("_R", ".R").replace("_L", ".L")] = v
    return p


def build_actions(rig):
    # Idle: тяжёлое дыхание грудью и покачивание дубины (60 кадров)
    act = new_action(rig, "Idle")
    for f, k in ((0, 0.0), (30, 1.0), (60, 0.0)):
        key(rig, f, pose(Spine=(4 + 3 * k, 0, 0), Chest=(4 + 3 * k, 0, 0), Head=(-6 - 3 * k, 0, 0),
                         UpperArm_R=(-14 - 5 * k, 0, 12), UpperArm_L=(-8 - 4 * k, 0, -10)),
            {"Hips": (0, 0, -0.025 * k)})
    finish_action(rig, act, 60, cyclic=True)

    # Walk: тяжёлая поступь босса вразвалку (20 кадров)
    act = new_action(rig, "Walk")
    for f, s in ((0, 1), (10, -1), (20, 1)):
        key(rig, f, pose(Thigh_R=(-8 - 26 * s, 0, 0), Thigh_L=(-8 + 26 * s, 0, 0),
                         Shin_R=(14 + 18 * max(0, -s), 0, 0), Shin_L=(14 + 18 * max(0, s), 0, 0),
                         UpperArm_R=(-14 + 14 * s, 0, 12), UpperArm_L=(-8 - 14 * s, 0, -10),
                         Spine=(6, 6 * s, 4 * s), Chest=(6, 4 * s, 0)),
            {"Hips": (0, 0, -0.02)})
    for f, s in ((5, 1), (15, -1)):
        key(rig, f, pose(Thigh_R=(-8, 0, 0), Thigh_L=(-8, 0, 0),
                         Shin_R=(14 + 24 * max(0, s), 0, 0), Shin_L=(14 + 24 * max(0, -s), 0, 0),
                         Spine=(6, 0, 0)),
            {"Hips": (0, 0, 0.03)})
    finish_action(rig, act, 20, cyclic=True)

    # Attack: широкий горизонтальный размах дубиной (под удар SWEEP по 3 клеткам перед собой, 24 кадра)
    act = new_action(rig, "Attack")
    key(rig, 0, pose())
    key(rig, 7, pose(Spine=(-6, 35, 0), Chest=(-4, 25, 0), Head=(4, -25, 0),
                     UpperArm_R=(-75, 0, 48), ForeArm_R=(-35, 0, 0), Hand_R=(-20, 0, 0),
                     UpperArm_L=(15, 0, -25), Thigh_R=(-22, 0, 0), Thigh_L=(10, 0, 0)))
    key(rig, 12, pose(Spine=(18, -38, 0), Chest=(12, -28, 0), Head=(-12, 22, 0),
                      UpperArm_R=(-55, 0, -45), ForeArm_R=(-15, 0, 0), Hand_R=(45, 0, 0),
                      UpperArm_L=(25, 0, -30), Thigh_R=(15, 0, 0), Thigh_L=(-32, 0, 0), Shin_L=(26, 0, 0)),
        {"Root": (0, -0.18, 0)})
    key(rig, 17, pose(Spine=(14, -28, 0), Chest=(10, -20, 0),
                      UpperArm_R=(-48, 0, -35), ForeArm_R=(-18, 0, 0), Hand_R=(35, 0, 0),
                      Thigh_L=(-24, 0, 0), Shin_L=(20, 0, 0)),
        {"Root": (0, -0.14, 0)})
    key(rig, 24, pose())
    finish_action(rig, act, 24)

    # Hit: тяжёлый отшат от удара (14 кадров)
    act = new_action(rig, "Hit")
    key(rig, 0, pose())
    key(rig, 4, pose(Spine=(-15, 0, 0), Chest=(-10, 0, 0), Head=(-16, 0, 0),
                     UpperArm_R=(5, 0, 28), UpperArm_L=(5, 0, -28)),
        {"Root": (0, 0.08, 0)})
    key(rig, 14, pose())
    finish_action(rig, act, 14)

    # Death: рушится на колени и падает на спину (36 кадров)
    act = new_action(rig, "Death")
    key(rig, 0, pose())
    key(rig, 12, pose(Thigh_R=(-75, 0, 0), Shin_R=(105, 0, 0), Thigh_L=(-40, 0, 0), Shin_L=(105, 0, 0),
                      Spine=(28, 0, 0), Head=(22, 0, 0), UpperArm_R=(15, 0, 30), UpperArm_L=(15, 0, -30)),
        {"Hips": (0, 0, -0.38)})
    for f, ang, z in ((24, -40, 0.0), (36, -88, 0.18)):
        p = pose(Thigh_R=(-12, 0, 0), Shin_R=(18, 0, 0), Thigh_L=(-20, 0, 0), Shin_L=(24, 0, 0),
                 Spine=(-6, 0, 0), Head=(-12, 0, 0), UpperArm_R=(-75, 0, 50), UpperArm_L=(-70, 0, -50))
        p["Root"] = (ang, 0, 0)
        key(rig, f, p, {"Root": (0, 0, z)})
    finish_action(rig, act, 36)


# ---------- Сборка и экспорт ----------

def build(glb_path, blend_path=None):
    scene = bpy.context.scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene.name = SCENE_NAME
    scene.render.fps = 30
    scene.frame_start = 0
    scene.frame_end = 60
    PARTS.clear()
    return _build_in_scene(scene, glb_path, blend_path)


def _build_in_scene(scene, glb_path, blend_path):
    body = build_mesh()
    rig = build_armature()
    body.parent = rig
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    build_actions(rig)
    actions = [t.strips[0].action for t in rig.animation_data.nla_tracks]

    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=glb_path, export_format="GLB", use_selection=True,
        export_animations=True, export_animation_mode="NLA_TRACKS",
        export_force_sampling=True, export_frame_range=False,
        export_def_bones=False, export_apply=False,
    )
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    rig.animation_data.action = bpy.data.actions["Idle"]
    if blend_path:
        datablocks = {scene, rig, body, rig.data, body.data} | set(actions) | set(body.data.materials)
        bpy.data.libraries.write(blend_path, datablocks, fake_user=True, compress=True)
    return scene, rig, body
