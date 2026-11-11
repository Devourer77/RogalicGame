# Строит low-poly культиста со скелетом и анимациями и экспортирует в .glb.
# Масштаб: 1 единица = 1 метр, рост ~1.68 м (с посохом ~1.78 м).
# Смотрит в -Y (после экспорта в glTF это +Z).
import bpy
import bmesh
import math
from mathutils import Vector, Matrix

SCENE_NAME = "Cultist"


# ---------- Материалы ----------

def mat(name, color, metallic=0.0, rough=0.8, emission=None, emission_strength=2.8):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
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
    robe = mat("Cultist_Robe", (0.26, 0.08, 0.42), rough=0.82)
    dark = mat("Cultist_Dark", (0.07, 0.04, 0.11), rough=0.88)
    crimson = mat("Cultist_Crimson", (0.42, 0.07, 0.11), rough=0.8)
    gold = mat("Cultist_Gold", (0.74, 0.50, 0.16), metallic=0.82, rough=0.36)
    void = mat("Cultist_Void", (0.01, 0.01, 0.02), rough=1.0)
    magic = mat("Cultist_Magic", (0.85, 0.22, 1.0), rough=0.2, emission=(0.82, 0.18, 1.0), emission_strength=3.5)
    wood = mat("Cultist_Wood", (0.22, 0.11, 0.05), rough=0.8)
    iron = mat("Cultist_Iron", (0.36, 0.34, 0.40), metallic=0.78, rough=0.4)

    # Нижняя часть мантии в пол со складками (кость Hips)
    cyl("RobeSkirt", 0.34, 0.155, 0.01, 0.86, robe, "Hips", segs=10, scale_y=0.85)
    for angle_deg in (-60, -30, 30, 60, 140, 180, 220):
        rad = math.radians(angle_deg)
        fx, fy = math.sin(rad) * 0.25, -math.cos(rad) * 0.21
        tx, ty = math.sin(rad) * 0.12, -math.cos(rad) * 0.10
        limb(f"RobeFold_{angle_deg}", (fx, fy, 0.01), (tx, ty, 0.78), 0.072, 0.022, robe, "Hips", segs=4)

    # Пояс, золотой ромб-пряжка и длинная ритуальная лента-стола спереди (наклон -12° вдоль юбки!)
    cyl("Belt", 0.168, 0.168, 0.82, 0.89, dark, "Hips", segs=8, scale_y=0.84)
    box("BeltDiamond", (0.075, 0.03, 0.075), (0, -0.152, 0.855), gold, "Hips", rot=(0, 45, 0))
    stole_outer = [(-0.072, 0.0), (0.072, 0.0), (0.092, -0.52), (0.0, -0.64), (-0.092, -0.52)]
    stole_inner = [(-0.050, 0.0), (0.050, 0.0), (0.065, -0.50), (0.0, -0.59), (-0.065, -0.50)]
    prism("StoleCrimson", stole_outer, 0.022, (0, -0.148, 0.83), crimson, "Hips", rot=(-12, 0, 0))
    prism("StoleDark", stole_inner, 0.026, (0, -0.152, 0.83), dark, "Hips", rot=(-12, 0, 0))

    # Торс и грудь (Spine, Chest)
    cyl("Torso", 0.15, 0.185, 0.85, 1.15, robe, "Spine", segs=8, scale_y=0.78)
    cyl("Chest", 0.185, 0.165, 1.15, 1.30, robe, "Chest", segs=8, scale_y=0.78)

    # Ритуальное оплечье (коническая пелерина на плечах с золотым и багровым кантом)
    cyl("MantleCrimson", 0.30, 0.16, 1.13, 1.29, crimson, "Chest", segs=8, scale_y=0.78)
    cyl("MantleGold", 0.292, 0.156, 1.15, 1.295, gold, "Chest", segs=8, scale_y=0.79)
    cyl("MantleDark", 0.282, 0.152, 1.17, 1.30, dark, "Chest", segs=8, scale_y=0.80)
    # Треугольный мыс оплечья спереди на груди (прилегает к корпусу)
    tip_gold = [(-0.14, 0.0), (0.14, 0.0), (0.0, -0.18)]
    tip_dark = [(-0.10, 0.0), (0.10, 0.0), (0.0, -0.13)]
    prism("MantleTipGold", tip_gold, 0.022, (0, -0.152, 1.14), gold, "Chest", rot=(-6, 0, 0))
    prism("MantleTipDark", tip_dark, 0.026, (0, -0.155, 1.14), dark, "Chest", rot=(-6, 0, 0))

    # Высокий стоячий воротник вокруг шеи
    cyl("CollarGold", 0.135, 0.175, 1.28, 1.37, gold, "Chest", segs=8, scale_y=0.85)
    cyl("CollarInner", 0.125, 0.162, 1.285, 1.372, dark, "Chest", segs=8, scale_y=0.84)

    # Левая рука (опущена сбоку) и правая рука (выдвинута вперёд-вправо, держит посох)
    # Левая рука
    limb("UpperArm.L", (0.22, 0, 1.23), (0.26, 0.02, 1.00), 0.065, 0.075, robe, "UpperArm.L")
    limb("ForeArm.L", (0.26, 0.02, 1.00), (0.28, -0.06, 0.77), 0.075, 0.115, robe, "ForeArm.L", segs=6)
    limb("SleeveTrimGold.L", (0.276, -0.045, 0.81), (0.28, -0.06, 0.765), 0.11, 0.12, gold, "ForeArm.L", segs=6)
    box("Hand.L", (0.075, 0.085, 0.08), (0.28, -0.07, 0.72), dark, "Hand.L")

    # Правая рука (держит вертикальный посох справа-спереди на x=-0.32, y=-0.16)
    limb("UpperArm.R", (-0.22, 0, 1.23), (-0.27, -0.05, 1.02), 0.065, 0.075, robe, "UpperArm.R")
    limb("ForeArm.R", (-0.27, -0.05, 1.02), (-0.31, -0.15, 0.88), 0.075, 0.112, robe, "ForeArm.R", segs=6)
    limb("SleeveTrimGold.R", (-0.30, -0.13, 0.91), (-0.31, -0.15, 0.875), 0.108, 0.118, gold, "ForeArm.R", segs=6)
    box("Hand.R", (0.08, 0.09, 0.08), (-0.32, -0.16, 0.86), dark, "Hand.R")

    # Остроконечный капюшон, чёрная тень внутри и светящиеся фиолетовые глаза (Head)
    limb("HoodBase", (0, 0, 1.33), (0, 0.01, 1.50), 0.135, 0.155, robe, "Head", segs=8)
    limb("HoodMid", (0, 0.01, 1.48), (0, 0.05, 1.63), 0.152, 0.068, robe, "Head", segs=8)
    limb("HoodTip", (0, 0.05, 1.62), (0, 0.13, 1.70), 0.066, 0.010, robe, "Head", segs=6)
    hood_open = [(-0.085, -0.075), (0.0, 0.095), (0.085, -0.075)]
    prism("FaceVoid", hood_open, 0.045, (0, -0.122, 1.44), void, "Head", rot=(-6, 0, 0))
    for side, s in (("R", -1), ("L", 1)):
        box(f"Eye.{side}", (0.036, 0.02, 0.018), (0.036 * s, -0.145, 1.445), magic, "Head", rot=(0, 0, -14 * s))

    # Посох с рогатым полумесяцем и парящим кристаллом в правой руке (Hand.R)
    sx, sy = -0.32, -0.16
    limb("StaffShaft", (sx, sy, 0.02), (sx, sy, 1.38), 0.022, 0.026, wood, "Hand.R", segs=6)
    limb("StaffSpike", (sx, sy, 0.04), (sx, sy, 0.00), 0.026, 0.006, iron, "Hand.R", segs=6)
    cyl("StaffCollar", 0.032, 0.048, 1.35, 1.43, gold, "Hand.R", segs=6, loc=(sx, sy))

    for side, s in (("R", -1), ("L", 1)):
        limb(f"StaffSubHorn.{side}", (sx, sy, 1.38), (sx + 0.09 * s, sy, 1.32), 0.024, 0.006, gold, "Hand.R", segs=5)
        p0 = (sx, sy, 1.42)
        p1 = (sx + 0.12 * s, sy, 1.48)
        p2 = (sx + 0.15 * s, sy, 1.62)
        p3 = (sx + 0.07 * s, sy, 1.75)
        limb(f"Crescent1.{side}", p0, p1, 0.034, 0.030, gold, "Hand.R", segs=5)
        limb(f"Crescent2.{side}", p1, p2, 0.030, 0.024, gold, "Hand.R", segs=5)
        limb(f"Crescent3.{side}", p2, p3, 0.024, 0.005, gold, "Hand.R", segs=5)

    limb("CrystalTop", (sx, sy, 1.58), (sx, sy, 1.69), 0.048, 0.004, magic, "Hand.R", segs=6)
    limb("CrystalBot", (sx, sy, 1.58), (sx, sy, 1.47), 0.048, 0.004, magic, "Hand.R", segs=6)

    bpy.ops.object.select_all(action="DESELECT")
    for ob in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = "CultistMesh"
    body.data.name = "CultistMesh"
    return body


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.25), None),
    "Hips": ((0, 0, 0.82), (0, 0, 0.90), "Root"),
    "Spine": ((0, 0, 0.90), (0, 0, 1.15), "Hips"),
    "Chest": ((0, 0, 1.15), (0, 0, 1.32), "Spine"),
    "Head": ((0, 0, 1.32), (0, 0, 1.62), "Chest"),
    "UpperArm.L": ((0.22, 0, 1.23), (0.26, 0.02, 1.00), "Chest"),
    "ForeArm.L": ((0.26, 0.02, 1.00), (0.28, -0.06, 0.77), "UpperArm.L"),
    "Hand.L": ((0.28, -0.06, 0.77), (0.28, -0.08, 0.68), "ForeArm.L"),
    "UpperArm.R": ((-0.22, 0, 1.23), (-0.27, -0.05, 1.02), "Chest"),
    "ForeArm.R": ((-0.27, -0.05, 1.02), (-0.31, -0.15, 0.88), "UpperArm.R"),
    "Hand.R": ((-0.31, -0.15, 0.88), (-0.32, -0.16, 0.78), "ForeArm.R"),
}


def build_armature():
    arm_data = bpy.data.armatures.new("CultistRig")
    rig = bpy.data.objects.new("Cultist", arm_data)
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


# Стойка культиста: посох в правой руке стоит вертикально сбоку-спереди
STANCE = {
    "Spine": (2, 0, 0), "Chest": (2, 0, 0), "Head": (-3, 0, 0),
    "UpperArm.R": (0, 0, 0), "ForeArm.R": (0, 0, 0), "Hand.R": (0, 0, 0),
    "UpperArm.L": (0, 0, 0), "ForeArm.L": (0, 0, 0), "Hand.L": (0, 0, 0),
}


def pose(**changes):
    p = dict(STANCE)
    for k, v in changes.items():
        p[k.replace("_R", ".R").replace("_L", ".L")] = v
    return p


def build_actions(rig):
    # Idle: зловещее парение/дыхание (60 кадров)
    act = new_action(rig, "Idle")
    for f, k in ((0, 0.0), (30, 1.0), (60, 0.0)):
        key(rig, f, pose(Spine=(2 + 2 * k, 0, 0), Chest=(2 + 2 * k, 0, 0), Head=(-3 - 3 * k, 0, 0),
                         UpperArm_R=(-4 * k, 0, 0), Hand_R=(4 * k, 0, 0),
                         UpperArm_L=(-5 * k, 0, 0)),
            {"Hips": (0, 0, 0.02 * k)})
    finish_action(rig, act, 60, cyclic=True)

    # Walk: плавное скольжение мантии (20 кадров)
    act = new_action(rig, "Walk")
    for f, s in ((0, 1), (10, -1), (20, 1)):
        key(rig, f, pose(Spine=(6, 4 * s, 2 * s), Chest=(4, -4 * s, 0),
                         UpperArm_R=(6 * s, 0, 0), Hand_R=(-6 * s, 0, 0),
                         UpperArm_L=(-10 * s, 0, 0)),
            {"Hips": (0, 0, 0.015)})
    for f, s in ((5, 1), (15, -1)):
        key(rig, f, pose(Spine=(6, 0, 0), Chest=(4, 0, 0)),
            {"Hips": (0, 0, 0.035)})
    finish_action(rig, act, 20, cyclic=True)

    # Attack: вскидывает посох вперёд, направляя кристалл на линию удара (24 кадра)
    act = new_action(rig, "Attack")
    key(rig, 0, pose())
    key(rig, 7, pose(Spine=(-8, 12, 0), Chest=(-6, 8, 0), Head=(-8, -10, 0),
                     UpperArm_R=(-75, 0, 18), ForeArm_R=(-35, 0, 0), Hand_R=(30, 0, -15),
                     UpperArm_L=(-55, 0, -20), ForeArm_L=(-40, 0, 0)))
    key(rig, 12, pose(Spine=(12, -10, 0), Chest=(8, -8, 0), Head=(-12, 8, 0),
                      UpperArm_R=(-85, 0, 5), ForeArm_R=(-10, 0, 0), Hand_R=(15, 0, -5),
                      UpperArm_L=(-80, 0, -15), ForeArm_L=(-15, 0, 0)),
        {"Root": (0, -0.08, 0)})
    key(rig, 17, pose(Spine=(10, -8, 0), Chest=(6, -6, 0),
                      UpperArm_R=(-80, 0, 6), ForeArm_R=(-12, 0, 0), Hand_R=(18, 0, -5),
                      UpperArm_L=(-70, 0, -15)),
        {"Root": (0, -0.06, 0)})
    key(rig, 24, pose())
    finish_action(rig, act, 24)

    # Hit: отшатнулся назад (14 кадров)
    act = new_action(rig, "Hit")
    key(rig, 0, pose())
    key(rig, 3, pose(Spine=(-16, 0, 0), Chest=(-10, 0, 0), Head=(-14, 0, 0),
                     UpperArm_R=(0, 0, 25), UpperArm_L=(5, 0, -25)),
        {"Root": (0, 0.07, 0)})
    key(rig, 14, pose())
    finish_action(rig, act, 14)

    # Death: оседает и падает на спину (36 кадров)
    act = new_action(rig, "Death")
    key(rig, 0, pose())
    key(rig, 12, pose(Spine=(22, 0, 0), Chest=(15, 0, 0), Head=(20, 0, 0),
                      UpperArm_R=(10, 0, 25), UpperArm_L=(10, 0, -25)),
        {"Hips": (0, 0, -0.25)})
    for f, ang, z in ((24, -42, 0.0), (36, -88, 0.14)):
        p = pose(Spine=(-6, 0, 0), Head=(-10, 0, 0),
                 UpperArm_R=(-65, 0, 45), Hand_R=(0, 0, 0), UpperArm_L=(-60, 0, -45))
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
