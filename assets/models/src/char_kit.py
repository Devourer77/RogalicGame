# Общий набор инструментов для персонажей: фигуры, скелет, «живые» анимации, экспорт.
# Его подключают скрипты build_<персонаж>.py из этой же папки.
#
# Как устроены оси костей (нужно, чтобы писать позы):
#   персонаж смотрит в -Y, его правая рука на -X, верх — +Z.
#   Кости «вверх» (спина, грудь, голова):  X+ наклон вперёд, Y+ поворот влево, Z+ наклон вправо.
#   Кости «вниз» (руки, ноги, тряпки):     X- вперёд (X+ назад), Z+ в сторону правой руки, Y — скручивание.
import bpy
import bmesh
import math
from mathutils import Vector, Matrix


def srgb(c):
    """Цвет «как на экране» -> линейный (так его хранит Blender)."""
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mat(name, color, metallic=0.0, rough=0.8, emit=0.0, alpha=1.0):
    """Однотонный материал. color — как на экране (sRGB). alpha < 1 — полупрозрачный (вода, стекло)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    lin = (*srgb(color), 1.0)
    bsdf.inputs["Base Color"].default_value = lin
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = lin
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"   # glTF: alphaMode BLEND
    m.diffuse_color = lin
    return m


# ---------- Фигуры (каждая целиком привязана к одной кости) ----------

PARTS = []


def _finish(bm, name, material, bone, matrix=None):
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
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
    return _finish(bm, name, material, bone, Matrix.Translation(loc) @ _rot(rot) @ Matrix.Diagonal((*size, 1.0)))


def limb(name, a, b, r1, r2, material, bone, segs=6):
    """Конус-«кость» от точки a (радиус r1) до точки b (радиус r2)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=max(r2, 0.0005), depth=d.length)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return _finish(bm, name, material, bone, Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4())


def barrel(name, r1, r2, z0, z1, material, bone, segs=8, loc=(0, 0), sy=1.0):
    """Вертикальный «бочонок» (торс, шлем): радиус r1 внизу, r2 вверху, sy сплющивает спереди-сзади."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=max(r2, 0.0005), depth=z1 - z0)
    return _finish(bm, name, material, bone,
                   Matrix.Translation((loc[0], loc[1], (z0 + z1) / 2)) @ Matrix.Diagonal((1, sy, 1, 1)))


def sphere(name, r, loc, material, bone, scale=(1, 1, 1), segs=8, rings=5, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    return _finish(bm, name, material, bone, Matrix.Translation(loc) @ _rot(rot) @ Matrix.Diagonal((*scale, 1)))


def plate(name, points, thickness, origin, ax_u, ax_v, material, bone):
    """Плоская деталь (клинок, тряпка, ухо): контур points в осях ax_u/ax_v, толщина — поперёк."""
    u, v = Vector(ax_u).normalized(), Vector(ax_v).normalized()
    n = u.cross(v).normalized()
    o = Vector(origin)
    bm = bmesh.new()
    front = [bm.verts.new(o + u * a + v * b + n * (thickness / 2)) for a, b in points]
    back = [bm.verts.new(o + u * a + v * b - n * (thickness / 2)) for a, b in points]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    cnt = len(points)
    for i in range(cnt):
        j = (i + 1) % cnt
        bm.faces.new([front[j], front[i], back[i], back[j]])
    return _finish(bm, name, material, bone)


def crack(name, points, origin, ax_u, ax_v, material, bone, width=0.012, depth=0.012):
    """Светящаяся трещина Раскола: ломаная из тонких брусков по точкам (в осях ax_u/ax_v)."""
    u, v = Vector(ax_u).normalized(), Vector(ax_v).normalized()
    o = Vector(origin)
    for i, (p1, p2) in enumerate(zip(points, points[1:])):
        a = o + u * p1[0] + v * p1[1]
        b = o + u * p2[0] + v * p2[1]
        d = b - a
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((width, depth, d.length + width, 1))
        _finish(bm, f"{name}{i}", material, bone, m)


def join_parts(name):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    body = bpy.context.view_layer.objects.active
    body.name = name
    body.data.name = name
    return body


# ---------- Скелет ----------

def build_armature(name, bones):
    """bones: имя -> (начало, конец, родитель)."""
    arm_data = bpy.data.armatures.new(name + "Rig")
    rig = bpy.data.objects.new(name, arm_data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bone, (h, t, parent) in bones.items():
        b = arm_data.edit_bones.new(bone)
        b.head, b.tail = h, t
        b.roll = 0.0
    for bone, (h, t, parent) in bones.items():
        if parent:
            arm_data.edit_bones[bone].parent = arm_data.edit_bones[parent]
            arm_data.edit_bones[bone].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
    return rig


# ---------- Анимация: поза считается формулой для каждого кадра ----------
# Так движения накладываются друг на друга со сдвигом по времени (дыхание, покачивание,
# запаздывание ушей и тряпок) — персонаж не выглядит деревянным.

TAU = math.tau


def wave(t, cycles=1.0, phase=0.0):
    """Синус: t от 0 до 1 — одна анимация; cycles — сколько колебаний; phase — сдвиг (в долях круга)."""
    return math.sin(TAU * (t * cycles + phase))


def smooth(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def track(t, keys):
    """Значение по ключам [(время, значение), ...] с плавным разгоном и торможением."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * smooth((t - t0) / (t1 - t0)) if t1 > t0 else v1
    return keys[-1][1]


def track3(t, keys):
    """То же для троек углов: [(время, (x, y, z)), ...]."""
    return tuple(track(t, [(k[0], k[1][i]) for k in keys]) for i in range(3))


def pulse(t, center, width):
    """Короткий всплеск 0→1→0 вокруг момента center (для подёргиваний)."""
    x = abs(t - center) / width
    return 0.0 if x >= 1 else (math.cos(x * math.pi) + 1) / 2


class Pose:
    """Поза = стойка + добавки. add() прибавляет углы к кости, move() сдвигает Root/Hips (в метрах, мир),
    size() растягивает кость (нужно редко: зоб жабы, язык, пульс ядра)."""

    def __init__(self, stance, loc=None):
        self.rot = {k: list(v) for k, v in stance.items()}
        self.loc = {k: list(v) for k, v in (loc or {}).items()}
        self.scl = {}

    def size(self, bone, x=1.0, y=None, z=None):
        """Размер кости: одно число — равномерно, три — по её осям (Y — вдоль кости)."""
        self.scl[bone] = (x, x if y is None else y, x if z is None else z)
        return self

    def add(self, bone, x=0.0, y=0.0, z=0.0):
        r = self.rot.setdefault(bone, [0, 0, 0])
        r[0] += x
        r[1] += y
        r[2] += z
        return self

    def set(self, bone, x, y, z):
        self.rot[bone] = [x, y, z]
        return self

    def move(self, bone, x=0.0, y=0.0, z=0.0):
        p = self.loc.setdefault(bone, [0, 0, 0])
        p[0] += x
        p[1] += y
        p[2] += z
        return self


def bake(rig, name, frames, fn, cyclic=False, loc_bones=("Root", "Hips"), scale_bones=()):
    """Записывает анимацию: fn(t) -> Pose для t от 0 до 1, ключ на каждом кадре.
    scale_bones — кости, которым пишется ещё и размер (Pose.size)."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = act
    for f in range(frames + 1):
        t = f / frames
        if cyclic and f == frames:
            t = 0.0   # последний кадр = первому, чтобы цикл не дёргался
        p = fn(t)
        for pb in rig.pose.bones:
            r = p.rot.get(pb.name, (0, 0, 0))
            pb.rotation_euler = tuple(math.radians(a) for a in r)
            pb.keyframe_insert("rotation_euler", frame=f)
            if pb.name in loc_bones:
                wx, wy, wz = p.loc.get(pb.name, (0, 0, 0))
                pb.location = (wx, wz, -wy)   # мир -> оси кости, смотрящей вверх
                pb.keyframe_insert("location", frame=f)
            if pb.name in scale_bones:
                pb.scale = p.scl.get(pb.name, (1, 1, 1))
                pb.keyframe_insert("scale", frame=f)
    act.frame_range = (0, frames)
    act.use_frame_range = True
    act.use_cyclic = cyclic
    track_ = rig.animation_data.nla_tracks.new()
    track_.name = name
    track_.strips.new(name, 0, act)
    track_.mute = True
    rig.animation_data.action = None
    return act


# ---------- Сборка и экспорт ----------

def start_scene(scene_name):
    scene = bpy.context.scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene.name = scene_name
    scene.render.fps = 30
    scene.frame_start = 0
    scene.frame_end = 90
    PARTS.clear()
    return scene


def export(rig, body, glb_path, blend_path=None):
    body.parent = rig
    mod = body.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
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
        pb.scale = (1, 1, 1)
    if "Idle" in bpy.data.actions:
        rig.animation_data.action = bpy.data.actions["Idle"]
    if blend_path:
        bpy.ops.wm.save_as_mainfile(filepath=blend_path, compress=True)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("%s: %d треугольников, %d костей" % (rig.name, tris, len(rig.pose.bones)))
