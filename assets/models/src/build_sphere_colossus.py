# Колосс Сфер — босс акта 2 (ветка Подземье), механизм технарей (~2.5 м).
# Корпус-бочка из тёмной бронзы и чернёного железа, ноги-поршни, руки с клешнями, две трубы с паром на спине,
# щель-визор вместо головы. Три стеклянные сферы в железных клетках с пленными духами:
# грудь — огонь, правое плечо (-X) — вода, левое плечо (+X) — молния (заметно жёлтая, с разрядами).
# Стороны — как на принятом листе Gemini (19 ноября): на виде спереди вода слева, молния справа.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Анимации: Idle, Walk, Attack (водяная сфера: клешня вверх → удар вперёд), Attack2 (грозовая сфера: обе клешни
# вверх → в землю), Attack3 (огненная сфера: сжался → выплеск вокруг), Hit, Death.
# Запуск: python3 build_sphere_colossus.py out/sphere_colossus.glb out/sphere_colossus.blend (нужен модуль bpy)
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k   # подключает bpy — после него доступны bmesh и mathutils
import bmesh
from mathutils import Vector, Matrix
from char_kit import Pose, wave, track, track3, pulse

NAME = "SphereColossus"
SIDES = (("R", -1), ("L", 1))
SY = 0.82   # корпус чуть сплющен спереди-сзади


def ring(name, big_r, small_r, loc, axis, material, bone, seg=12, minor=3):
    """Тонкое кольцо (тор) — прутья клетки вокруг сферы. axis — ось, вокруг которой кольцо."""
    bm = bmesh.new()
    rows = []
    for i in range(seg):
        a = math.tau * i / seg
        c = Vector((math.cos(a), math.sin(a), 0))
        row = []
        for j in range(minor):
            b = math.tau * j / minor
            p = c * (big_r + small_r * math.cos(b)) + Vector((0, 0, small_r * math.sin(b)))
            row.append(bm.verts.new(p))
        rows.append(row)
    for i in range(seg):
        r0, r1 = rows[i], rows[(i + 1) % seg]
        for j in range(minor):
            j1 = (j + 1) % minor
            bm.faces.new([r0[j], r1[j], r1[j1], r0[j1]])
    q = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
    return k._finish(bm, name, material, bone, Matrix.Translation(loc) @ q.to_matrix().to_4x4(), hard=1.0)


# ---------- Модель ----------

def build_mesh():
    bronze = k.mat("Col_Bronze", (0.52, 0.42, 0.29), metallic=0.55, rough=0.55)     # тусклая бронза
    bronze_d = k.mat("Col_BronzeDark", (0.40, 0.32, 0.22), metallic=0.55, rough=0.6)
    iron = k.mat("Col_Iron", (0.30, 0.30, 0.31), metallic=0.5, rough=0.65)          # чернёное железо (чуть светлее)
    iron_d = k.mat("Col_IronDark", (0.21, 0.21, 0.22), metallic=0.5, rough=0.7)
    steel = k.mat("Col_Claw", (0.50, 0.50, 0.49), metallic=0.6, rough=0.5)
    copper = k.mat("Col_Copper", (0.64, 0.40, 0.25), metallic=0.6, rough=0.45)
    gauge = k.mat("Col_Gauge", (0.80, 0.77, 0.66), rough=0.6)
    steam = k.mat("Col_Steam", (0.88, 0.9, 0.9), rough=0.95)
    visor = k.mat("Col_Visor", (1.0, 0.86, 0.66), rough=0.4, emit=2.2)               # бело-оранжевый свет
    fire = k.mat("Col_Fire", (0.95, 0.3, 0.04), rough=0.3, emit=1.0)
    fire_core = k.mat("Col_FireCore", (1.0, 0.55, 0.14), rough=0.3, emit=1.5)
    water = k.mat("Col_Water", (0.28, 0.55, 1.0), rough=0.25, emit=0.85)
    swirl = k.mat("Col_WaterSwirl", (0.7, 0.9, 1.0), rough=0.25, emit=1.5)
    volt = k.mat("Col_Volt", (0.95, 0.86, 0.2), rough=0.25, emit=0.8)                # заметно жёлтая, холодная
    bolt = k.mat("Col_Bolt", (1.0, 0.96, 0.62), rough=0.25, emit=2.4)
    rift = k.mat("Col_Rift", (0.30, 0.95, 0.85), rough=0.4, emit=1.8)

    # Таз и шарниры бёдер
    k.barrel("Pelvis", 0.27, 0.32, 0.80, 1.0, iron_d, "Hips", segs=8, sy=SY)
    for side, s in SIDES:
        k.sphere(f"HipJoint.{side}", 0.1, (0.22 * s, 0, 0.86), iron, "Hips", segs=6, rings=4)

    # Корпус-бочка: узкий низ, широкая середина, купол сверху
    k.barrel("BellyBarrel", 0.30, 0.44, 1.0, 1.45, bronze, "Spine", segs=9, sy=SY)
    k.barrel("ChestBarrel", 0.44, 0.40, 1.45, 1.95, bronze, "Chest", segs=9, sy=SY)
    k.barrel("Dome", 0.40, 0.22, 1.95, 2.12, bronze_d, "Chest", segs=9, sy=SY)
    k.barrel("DomeCap", 0.22, 0.16, 2.12, 2.17, iron, "Chest", segs=8, sy=SY)
    # Железные обручи и заклёпки
    for i, (r, z0, z1, bone) in enumerate([(0.36, 1.1, 1.15, "Spine"), (0.452, 1.42, 1.48, "Chest"),
                                          (0.41, 1.92, 1.97, "Chest")]):
        k.barrel(f"Hoop{i}", r, r, z0, z1, iron, bone, segs=9, sy=SY)
    for i in range(6):
        a = math.radians(-90 + (i - 2.5) * 26)
        for j, (r, z, bone) in enumerate([(0.455, 1.45, "Chest"), (0.415, 1.945, "Chest")]):
            k.box(f"Rivet{i}_{j}", (0.035, 0.03, 0.035), (r * math.cos(a), r * SY * math.sin(a) - 0.008, z), iron_d, bone)
    # Нижний конус-«киль» под корпусом
    k.barrel("Keel", 0.10, 0.30, 0.9, 1.0, bronze_d, "Spine", segs=8, sy=SY)

    # Визор
    k.box("VisorFrame", (0.32, 0.07, 0.11), (0, -0.30, 2.02), iron_d, "Chest", rot=(-18, 0, 0))
    k.box("VisorGlow", (0.25, 0.04, 0.05), (0, -0.335, 2.025), visor, "Chest", rot=(-18, 0, 0))

    # Огненная сфера на груди (своя кость Core — пульсирует) и её клетка
    k.sphere("FireGlass", 0.18, (0, -0.35, 1.62), fire, "Core", segs=7, rings=5)
    k.sphere("FireHeart", 0.11, (0, -0.44, 1.6), fire_core, "Core", scale=(1, 0.8, 1.2), segs=6, rings=4)
    ring("FireCageRim", 0.195, 0.022, (0, -0.42, 1.62), (0, 1, 0), iron_d, "Core", seg=14)
    ring("FireCageV", 0.19, 0.016, (0, -0.35, 1.62), (1, 0, 0), iron, "Core")
    ring("FireCageH", 0.19, 0.016, (0, -0.35, 1.62), (0, 0, 1), iron, "Core")
    k.crack("FireRift", [(0, 0), (0.04, 0.05), (0.02, 0.1)], (-0.06, -0.52, 1.55), (1, 0, 0), (0, 0, 1), rift, "Core",
            width=0.014, depth=0.014)
    # Медные трубки от груди к плечам и манометр
    for side, s in SIDES:
        # трубки прижаты к корпусу: два колена, уходят под плечевую сферу и в бок
        k.limb(f"Pipe.{side}", (0.16 * s, -0.37, 1.66), (0.28 * s, -0.3, 1.7), 0.024, 0.024, copper, "Chest", segs=5)
        k.limb(f"Pipe2.{side}", (0.28 * s, -0.3, 1.7), (0.36 * s, -0.12, 1.76), 0.024, 0.024, copper, "Chest", segs=5)
        k.limb(f"PipeLow.{side}", (0.14 * s, -0.38, 1.5), (0.3 * s, -0.3, 1.4), 0.022, 0.022, copper, "Spine", segs=5)
        k.limb(f"PipeLow2.{side}", (0.3 * s, -0.3, 1.4), (0.38 * s, -0.1, 1.32), 0.022, 0.022, copper, "Spine", segs=5)
    k.limb("GaugeRim", (0.27, -0.31, 1.83), (0.275, -0.355, 1.83), 0.055, 0.055, iron_d, "Chest", segs=6)
    k.limb("GaugeFace", (0.275, -0.355, 1.83), (0.277, -0.36, 1.83), 0.044, 0.044, gauge, "Chest", segs=6)
    k.box("GaugeNeedle", (0.008, 0.008, 0.04), (0.282, -0.364, 1.818), iron_d, "Chest", rot=(0, 30, 0))

    # Трубы на спине и клубы пара (кости Steam.* — растягиваются)
    for side, s in SIDES:
        x = 0.13 * s
        k.limb(f"Stack.{side}", (x, 0.24, 1.88), (x, 0.26, 2.38), 0.06, 0.055, iron, "Chest", segs=6)
        k.limb(f"StackLip.{side}", (x, 0.26, 2.34), (x, 0.26, 2.4), 0.075, 0.075, iron_d, "Chest", segs=6)
        # клуб пара — несколько неровных шаров
        k.sphere(f"Puff.{side}", 0.13, (x, 0.27, 2.52), steam, f"Steam.{side}", scale=(1.1, 1.0, 0.85), segs=6, rings=4)
        k.sphere(f"Puff2.{side}", 0.09, (x + 0.07 * s, 0.25, 2.6), steam, f"Steam.{side}", segs=5, rings=3)
        k.sphere(f"Puff3.{side}", 0.08, (x - 0.05 * s, 0.31, 2.66), steam, f"Steam.{side}", segs=5, rings=3)
        k.sphere(f"Puff4.{side}", 0.05, (x + 0.03 * s, 0.3, 2.78), steam, f"Steam.{side}", segs=5, rings=3)

    # Сферы на плечах: правое (-X) — вода, левое (+X) — молния
    for side, s in SIDES:
        c = (0.52 * s, 0.0, 1.84)
        glass = water if s < 0 else volt
        k.sphere(f"PodGlass.{side}", 0.19, c, glass, "Chest", segs=7, rings=5)
        k.barrel(f"PodSocket.{side}", 0.16, 0.2, 1.62, 1.7, iron, "Chest", segs=8, loc=(c[0], c[1]))
        ring(f"PodCageH.{side}", 0.2, 0.02, c, (0, 0, 1), iron_d, "Chest")
        ring(f"PodCageF.{side}", 0.2, 0.017, c, (1, 0, 0), iron, "Chest")
        ring(f"PodCageS.{side}", 0.2, 0.017, c, (0, 1, 0), iron, "Chest")
        if s < 0:
            # Водоворот внутри: светлые завитки и бирюза Раскола
            k.crack("Swirl.R", [(-0.1, -0.02), (-0.04, 0.06), (0.05, 0.05), (0.09, -0.03), (0.03, -0.08)],
                    (c[0], -0.17, c[2]), (1, 0, 0), (0, 0, 1), swirl, "Chest", width=0.022, depth=0.02)
            k.crack("SwirlSide.R", [(-0.08, 0.04), (0.0, 0.09), (0.08, 0.02)], (c[0] - 0.17, 0.0, c[2]),
                    (0, 1, 0), (0, 0, 1), swirl, "Chest", width=0.02, depth=0.02)
            k.crack("PodRift.R", [(0, 0), (0.05, -0.04), (0.09, 0.01)], (c[0] - 0.02, -0.18, c[2] - 0.06),
                    (1, 0, 0), (0, 0, 1), rift, "Chest", width=0.013, depth=0.013)
        else:
            # Ломаные разряды молнии
            k.crack("Bolt.L", [(-0.1, 0.09), (-0.02, 0.02), (-0.06, -0.01), (0.04, -0.09), (0.02, -0.03), (0.1, -0.06)],
                    (c[0], -0.17, c[2]), (1, 0, 0), (0, 0, 1), bolt, "Chest", width=0.02, depth=0.02)
            k.crack("BoltSide.L", [(-0.09, 0.07), (0.0, 0.0), (-0.03, -0.03), (0.08, -0.08)], (c[0] + 0.17, 0.0, c[2]),
                    (0, -1, 0), (0, 0, 1), bolt, "Chest", width=0.018, depth=0.018)
            k.crack("PodRift.L", [(0, 0), (-0.04, 0.05), (-0.09, 0.03)], (c[0] + 0.03, -0.18, c[2] + 0.06),
                    (1, 0, 0), (0, 0, 1), rift, "Chest", width=0.013, depth=0.013)

    # Руки: железное плечо, бронзовый наруч, клешни
    for side, s in SIDES:
        k.limb(f"UpperArm.{side}", (0.53 * s, 0.0, 1.66), (0.58 * s, 0.0, 1.3), 0.085, 0.08, iron, f"UpperArm.{side}", segs=6)
        k.limb(f"ArmBand.{side}", (0.545 * s, 0.0, 1.52), (0.555 * s, 0.0, 1.44), 0.11, 0.11, bronze_d, f"UpperArm.{side}", segs=7)
        k.sphere(f"Elbow.{side}", 0.1, (0.58 * s, 0.0, 1.3), iron_d, f"ForeArm.{side}", segs=6, rings=4)
        k.limb(f"Gauntlet.{side}", (0.58 * s, -0.01, 1.26), (0.6 * s, -0.05, 0.98), 0.12, 0.145, bronze, f"ForeArm.{side}", segs=8)
        k.limb(f"Cuff.{side}", (0.598 * s, -0.045, 1.02), (0.6 * s, -0.05, 0.97), 0.155, 0.155, iron, f"ForeArm.{side}", segs=8)
        k.limb(f"Cuff2.{side}", (0.585 * s, -0.02, 1.2), (0.59 * s, -0.025, 1.15), 0.135, 0.135, iron, f"ForeArm.{side}", segs=8)
        k.box(f"Palm.{side}", (0.16, 0.17, 0.12), (0.6 * s, -0.07, 0.9), iron_d, f"Hand.{side}")
        x = 0.6 * s
        # Передняя челюсть клешни — крюк вперёд-вниз; задняя — короче, загнута назад
        k.plate(f"ClawA.{side}", [(0, 0.02), (0.09, 0.0), (0.16, -0.1), (0.15, -0.23), (0.07, -0.3), (0.09, -0.21),
                                  (0.08, -0.12), (0.02, -0.07)],
                0.07, (x, -0.1, 0.86), (0, -1, 0), (0, 0, 1), steel, f"ClawA.{side}")
        k.plate(f"ClawB.{side}", [(0, 0.02), (0.07, 0.0), (0.12, -0.09), (0.1, -0.2), (0.04, -0.25), (0.05, -0.17),
                                  (0.04, -0.09), (0, -0.05)],
                0.07, (x, -0.03, 0.86), (0, 1, 0), (0, 0, 1), steel, f"ClawB.{side}")

        # Ноги-поршни: бронзовый кожух сверху, железный шток, колено, бронзовый сапог
        k.limb(f"ThighSleeve.{side}", (0.22 * s, 0, 0.84), (0.23 * s, -0.01, 0.64), 0.135, 0.125, bronze_d, f"Thigh.{side}", segs=7)
        k.limb(f"Piston.{side}", (0.23 * s, -0.01, 0.66), (0.24 * s, -0.02, 0.5), 0.07, 0.07, steel, f"Thigh.{side}", segs=6)
        k.sphere(f"Knee.{side}", 0.11, (0.24 * s, -0.03, 0.5), iron, f"Shin.{side}", segs=6, rings=4)
        k.limb(f"Shin.{side}", (0.24 * s, -0.02, 0.48), (0.24 * s, 0, 0.14), 0.12, 0.15, bronze, f"Shin.{side}", segs=8)
        k.limb(f"ShinBand.{side}", (0.24 * s, -0.01, 0.34), (0.24 * s, -0.01, 0.29), 0.14, 0.14, iron, f"Shin.{side}", segs=8)
        k.box(f"Foot.{side}", (0.26, 0.36, 0.12), (0.24 * s, -0.07, 0.06), iron_d, f"Foot.{side}")
        k.box(f"Toe.{side}", (0.24, 0.1, 0.09), (0.24 * s, -0.26, 0.05), bronze_d, f"Foot.{side}")

    return k.join_parts("SphereColossusMesh")


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.2), None),
    "Hips": ((0, 0, 0.86), (0, 0, 1.0), "Root"),
    "Spine": ((0, 0, 1.0), (0, 0, 1.45), "Hips"),
    "Chest": ((0, 0, 1.45), (0, 0, 2.15), "Spine"),
    "Core": ((0, -0.3, 1.62), (0, -0.5, 1.62), "Chest"),
}
for side, s in SIDES:
    x = 0.13 * s
    BONES.update({
        f"Steam.{side}": ((x, 0.27, 2.4), (x, 0.27, 2.7), "Chest"),
        f"UpperArm.{side}": ((0.53 * s, 0.0, 1.66), (0.58 * s, 0.0, 1.3), "Chest"),
        f"ForeArm.{side}": ((0.58 * s, 0.0, 1.3), (0.6 * s, -0.05, 0.98), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.6 * s, -0.05, 0.98), (0.6 * s, -0.08, 0.84), f"ForeArm.{side}"),
        f"ClawA.{side}": ((0.6 * s, -0.1, 0.86), (0.6 * s, -0.16, 0.66), f"Hand.{side}"),
        f"ClawB.{side}": ((0.6 * s, -0.03, 0.86), (0.6 * s, 0.02, 0.68), f"Hand.{side}"),
        f"Thigh.{side}": ((0.22 * s, 0, 0.86), (0.24 * s, -0.02, 0.5), "Hips"),
        f"Shin.{side}": ((0.24 * s, -0.02, 0.5), (0.24 * s, 0, 0.14), f"Thigh.{side}"),
        f"Foot.{side}": ((0.24 * s, 0, 0.14), (0.24 * s, -0.2, 0.04), f"Shin.{side}"),
    })

SCALED = ("Steam.R", "Steam.L", "Core")


# ---------- Анимации ----------
# Стойка: широко, левая нога впереди, корпус чуть вперёд и довёрнут, руки вперёд, клешни приоткрыты.
STANCE = {
    "Hips": (0, -6, 0),
    "Spine": (6, -3, 0), "Chest": (4, -3, 0),
    "Thigh.L": (-16, 0, -6), "Shin.L": (18, 0, 0), "Foot.L": (-2, 0, 0),
    "Thigh.R": (6, 0, 8), "Shin.R": (14, 0, 0), "Foot.R": (-20, 0, 0),
    "UpperArm.R": (-16, 0, 12), "ForeArm.R": (-30, 0, 0),
    "UpperArm.L": (-8, 0, -12), "ForeArm.L": (-22, 0, 0),
    "ClawA.R": (-12, 0, 0), "ClawB.R": (12, 0, 0),
    "ClawA.L": (-8, 0, 0), "ClawB.L": (8, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.04)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def puff(p, a=0.0, b=None):
    """Клубы пара: 0 — маленькие, 1 — большие."""
    b = a if b is None else b
    p.size("Steam.R", 0.55 + 0.6 * a)
    p.size("Steam.L", 0.55 + 0.6 * b)
    return p


def claws(p, side, opened):
    """Клешня: opened > 0 раскрывает, < 0 сжимает (в градусах на каждую челюсть)."""
    p.add(f"ClawA.{side}", x=-opened)
    p.add(f"ClawB.{side}", x=opened)
    return p


def idle(t):
    """Покой (3 сек): поршни ходят вверх-вниз, корпус «дышит», трубы выпускают пар по очереди,
    корпус поворачивается с паузами, огонь в груди пульсирует, клешни дважды щёлкают."""
    p = stance()
    pump = wave(t, 3)
    sway = wave(t, 1)
    p.move("Hips", z=-0.012 * (pump * 0.5 + 0.5), x=0.015 * sway)
    p.add("Hips", z=2 * sway)
    p.add("Thigh.L", z=-2 * sway)
    p.add("Thigh.R", z=-2 * sway)
    p.add("Spine", x=1.5 * pump)
    yaw = track(t, [(0, 0), (0.2, 0), (0.26, -14), (0.52, -14), (0.58, 10), (0.82, 10), (0.9, 0), (1, 0)])
    p.add("Chest", y=yaw, x=1.5 * wave(t, 3, -0.15))
    p.size("Core", 1.0 + 0.05 * wave(t, 4))
    puff(p, 0.4 + 0.6 * pulse(t, 0.3, 0.14), 0.4 + 0.6 * pulse(t, 0.72, 0.14))
    snap = pulse(t, 0.44, 0.04) + pulse(t, 0.52, 0.04)
    claws(p, "R", -14 * snap + 4 * wave(t, 1))
    claws(p, "L", 3 * wave(t, 1, 0.3))
    p.add("UpperArm.R", x=-3 * snap - 2 * pump)
    p.add("UpperArm.L", x=2 * wave(t, 1, 0.2))
    p.add("ForeArm.L", x=-3 * wave(t, 1, 0.3))
    return p


def walk(t):
    """Тяжёлая поступь (1.0 сек): каждая нога топает, корпус качается, руки в противофазе, пар толчками."""
    p = Pose(STANCE)
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.1)
    p.move("Hips", z=-0.05 + 0.03 * bounce, x=0.035 * a)
    p.add("Hips", y=-6 + 6 * a, z=5 * a)
    p.set("Thigh.R", -4 - 24 * a, 0, 8)
    p.set("Thigh.L", -4 + 24 * a, 0, -8)
    p.set("Shin.R", 12 + 30 * max(0.0, c) + 4 * a, 0, 0)
    p.set("Shin.L", 12 + 30 * max(0.0, -c) - 4 * a, 0, 0)
    p.set("Foot.R", -6 - 12 * a, 0, 0)
    p.set("Foot.L", -6 + 12 * a, 0, 0)
    p.add("Spine", z=-4 * a)
    p.add("Chest", y=-5 * a, x=2 * bounce)
    p.add("UpperArm.R", x=-14 * a)
    p.add("UpperArm.L", x=14 * a)
    p.add("ForeArm.R", x=-6 * a)
    p.add("ForeArm.L", x=6 * a)
    claws(p, "R", 4 * wave(t, 2, 0.3))
    claws(p, "L", 4 * wave(t, 2, 0.55))
    puff(p, 0.5 + 0.5 * max(0.0, bounce), 0.5 + 0.5 * max(0.0, -bounce))
    return p


def _tr(p, t, K, S, bone, *keys):
    p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0)))] + list(zip(K[1:-1], keys)) + [(K[-1], S.get(bone, (0, 0, 0)))]))


def attack(t):
    """Водяная сфера (0.9 сек): правая клешня взлетает вверх (как на листе Gemini), корпус откидывается →
    бросок вперёд-вниз по линии (к 0.4 сек), клешня захлопывается → пронос → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.26, 0.4, 0.56, 1.0]
    S = STANCE
    tr = lambda bone, *keys: _tr(p, t, K, S, bone, *keys)
    tr("Hips", (-2, 10, 0), (2, -8, 0), (3, -10, 0))
    tr("Spine", (-6, 10, 0), (8, -8, 0), (9, -9, 0))
    tr("Chest", (-8, 12, 0), (6, -8, 0), (6, -10, 0))
    tr("UpperArm.R", (-150, 0, 26), (-70, 0, 8), (-50, 0, 4))
    tr("ForeArm.R", (-50, 0, 0), (-6, 0, 0), (-10, 0, 0))
    tr("Hand.R", (20, 0, 0), (-10, 0, 0), (-14, 0, 0))
    tr("ClawA.R", (-40, 0, 0), (6, 0, 0), (4, 0, 0))
    tr("ClawB.R", (40, 0, 0), (-6, 0, 0), (-4, 0, 0))
    tr("UpperArm.L", (-20, 0, -26), (10, 0, -16), (8, 0, -14))
    tr("ForeArm.L", (-40, 0, 0), (-20, 0, 0), (-20, 0, 0))
    tr("Thigh.L", (-14, 0, -6), (-30, 0, -6), (-28, 0, -6))
    tr("Shin.L", (16, 0, 0), (30, 0, 0), (30, 0, 0))
    tr("Thigh.R", (8, 0, 8), (14, 0, 8), (12, 0, 8))
    tr("Shin.R", (12, 0, 0), (22, 0, 0), (22, 0, 0))
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], -0.02), (K[2], -0.1), (K[3], -0.09), (1, -0.04)]))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.05), (K[2], -0.1), (K[3], -0.1), (1, 0)]))
    hiss = track(t, [(0, 0.4), (K[1], 0.6), (K[2], 1.0), (K[3], 0.8), (1, 0.4)])
    puff(p, hiss, hiss * 0.8)
    return p


def attack2(t):
    """Грозовая сфера (1.0 сек): обе клешни вверх, раскрыты, корпус откинут назад → удар обеими клешнями
    в землю (к 0.4 сек), присел → разряд — дрожь → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.26, 0.4, 0.62, 1.0]
    S = STANCE
    tr = lambda bone, *keys: _tr(p, t, K, S, bone, *keys)
    tr("Spine", (-10, 0, 0), (18, 0, 0), (16, 0, 0))
    tr("Chest", (-10, 0, 0), (14, 0, 0), (12, 0, 0))
    for side, s in SIDES:
        tr(f"UpperArm.{side}", (-160, 0, 18 * -s), (-56, 0, 14 * -s), (-50, 0, 12 * -s))
        tr(f"ForeArm.{side}", (-40, 0, 0), (-10, 0, 0), (-14, 0, 0))
        tr(f"Hand.{side}", (10, 0, 0), (-30, 0, 0), (-30, 0, 0))
        tr(f"ClawA.{side}", (-44, 0, 0), (-30, 0, 0), (-6, 0, 0))
        tr(f"ClawB.{side}", (44, 0, 0), (30, 0, 0), (6, 0, 0))
        tr(f"Thigh.{side}", (-10, 0, 10 * -s), (-36, 0, 10 * -s), (-32, 0, 10 * -s))
        tr(f"Shin.{side}", (16, 0, 0), (52, 0, 0), (46, 0, 0))
        tr(f"Foot.{side}", (-6, 0, 0), (-16, 0, 0), (-14, 0, 0))
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], 0.02), (K[2], -0.2), (K[3], -0.18), (1, -0.04)]))
    # Разряд: корпус мелко дрожит после удара
    buzz = (track(t, [(0, 0), (K[2], 0), (K[2] + 0.04, 1), (K[3], 1), (K[3] + 0.1, 0), (1, 0)])
            * math.sin(t * 90))
    p.add("Chest", z=3 * buzz, y=2 * buzz)
    puff(p, track(t, [(0, 0.4), (K[2], 1.0), (K[3], 0.9), (1, 0.4)]))
    return p


def attack3(t):
    """Огненная сфера (1.0 сек): сжимается, руки к груди, огонь разгорается → выплеск: руки и корпус
    распахиваются (к 0.4 сек), сфера вспыхивает → шатается → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.26, 0.4, 0.62, 1.0]
    S = STANCE
    tr = lambda bone, *keys: _tr(p, t, K, S, bone, *keys)
    tr("Spine", (18, 0, 0), (-12, 0, 0), (-6, 0, 0))
    tr("Chest", (16, 0, 0), (-14, 0, 0), (-8, 0, 0))
    for side, s in SIDES:
        tr(f"UpperArm.{side}", (-40, 0, 6 * -s), (-30, 0, 70 * -s), (-20, 0, 50 * -s))
        tr(f"ForeArm.{side}", (-100, 0, 0), (-10, 0, 0), (-20, 0, 0))
        tr(f"ClawA.{side}", (8, 0, 0), (-36, 0, 0), (-20, 0, 0))
        tr(f"ClawB.{side}", (-8, 0, 0), (36, 0, 0), (20, 0, 0))
        tr(f"Thigh.{side}", (-24, 0, 10 * -s), (-10, 0, 14 * -s), (-10, 0, 12 * -s))
        tr(f"Shin.{side}", (40, 0, 0), (16, 0, 0), (18, 0, 0))
    p.size("Core", track(t, [(0, 1.0), (K[1], 1.12), (K[2], 1.3), (K[3], 1.05), (1, 1.0)]))
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], -0.16), (K[2], 0.0), (K[3], -0.06), (1, -0.04)]))
    p.move("Root", y=track(t, [(0, 0), (K[2], 0.06), (K[3], 0.04), (1, 0)]))
    puff(p, track(t, [(0, 0.4), (K[1], 0.3), (K[2], 1.15), (K[3], 0.9), (1, 0.4)]))
    return p


def hit(t):
    """Получил удар (0.5 сек): корпус отбрасывает, руки взлетают с опозданием, пар вырывается рывком."""
    p = stance()
    snap = track(t, [(0, 0), (0.16, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.18, 0.4), (0.32, 1), (0.55, -0.3), (0.78, 0.1), (1, 0)])
    p.move("Root", y=0.08 * snap)
    p.move("Hips", z=-0.03 * snap)
    p.add("Spine", x=-12 * snap, y=8 * snap)
    p.add("Chest", x=-10 * whip, z=4 * whip)
    p.add("UpperArm.R", x=18 * whip, z=12 * whip)
    p.add("UpperArm.L", x=14 * whip, z=-14 * whip)
    claws(p, "R", 20 * whip)
    claws(p, "L", 20 * whip)
    p.add("Thigh.R", x=-8 * snap)
    puff(p, 0.4 + 0.8 * snap, 0.4 + 0.9 * whip)
    return p


def death(t):
    """Гибель (1.6 сек): пар вырывается из обеих труб, машина шатается, колени подгибаются,
    корпус оседает и валится вперёд; в конце клешня судорожно щёлкает, огонь гаснет (сфера сжимается)."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.45, 0.72, 1.0]
    S = STANCE

    def tr(bone, a, b, c, d):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], a), (K[2], b), (K[3], c), (K[4], d)]))

    tr("Spine", (-12, 10, 0), (16, 0, 0), (24, 0, 0), (22, 0, 0))
    tr("Chest", (-10, 8, 4), (12, 0, 0), (16, 0, 0), (14, 0, 0))
    tr("UpperArm.R", (10, 0, 30), (-10, 0, 20), (-120, 0, 20), (-130, 0, 22))
    tr("ForeArm.R", (-50, 0, 0), (-20, 0, 0), (-10, 0, 0), (-6, 0, 0))
    tr("UpperArm.L", (16, 0, -36), (-6, 0, -20), (-114, 0, -20), (-124, 0, -22))
    tr("ForeArm.L", (-40, 0, 0), (-30, 0, 0), (-12, 0, 0), (-6, 0, 0))
    tr("Thigh.L", (-10, 0, -8), (-78, 0, -10), (-30, 0, -10), (-20, 0, -10))
    tr("Shin.L", (20, 0, 0), (106, 0, 0), (40, 0, 0), (20, 0, 0))
    tr("Thigh.R", (-16, 0, 10), (-78, 0, 12), (-30, 0, 12), (-20, 0, 12))
    tr("Shin.R", (24, 0, 0), (106, 0, 0), (40, 0, 0), (20, 0, 0))
    tr("Foot.L", (0, 0, 0), (40, 0, 0), (40, 0, 0), (40, 0, 0))
    tr("Foot.R", (0, 0, 0), (40, 0, 0), (40, 0, 0), (40, 0, 0))
    tr("ClawA.R", (-30, 0, 0), (-20, 0, 0), (-10, 0, 0), (-10, 0, 0))
    tr("ClawB.R", (30, 0, 0), (20, 0, 0), (10, 0, 0), (10, 0, 0))
    fall = track(t, [(0, 0), (K[1], -6), (K[2], 6), (K[3], 82), (K[3] + 0.06, 76), (K[3] + 0.12, 84), (1, 84)])
    p.set("Root", fall, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.06), (K[2], -0.05), (K[3], -0.2), (1, -0.2)]),
           z=track(t, [(0, 0), (K[2], 0), (K[3], 0.3), (1, 0.3)]))
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], -0.02), (K[2], -0.46), (K[3], -0.1), (1, -0.1)]))
    spasm = pulse(t, 0.88, 0.05)
    p.add("ClawA.L", x=-30 * spasm)
    p.add("ClawB.L", x=30 * spasm)
    p.size("Core", track(t, [(0, 1.0), (K[1], 1.15), (K[3], 0.9), (1, 0.75)]))
    burst = track(t, [(0, 0.4), (K[1], 1.3), (K[2], 1.1), (K[3], 0.5), (1, 0.15)])
    puff(p, burst, burst * 0.9)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 30, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 27, attack, scale_bones=SCALED)
    k.bake(rig, "Attack2", 30, attack2, scale_bones=SCALED)
    k.bake(rig, "Attack3", 30, attack3, scale_bones=SCALED)
    k.bake(rig, "Hit", 15, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 48, death, scale_bones=SCALED)


# ---------- Сборка и экспорт ----------

def build(glb_path, blend_path=None):
    k.start_scene(NAME)
    body = build_mesh()
    rig = k.build_armature(NAME, BONES)
    body.parent = rig
    build_actions(rig)
    k.export(rig, body, glb_path, blend_path)
    return rig, body


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    glb = args[0] if args else os.path.join(here, "..", "sphere_colossus.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "sphere_colossus.blend")
    build(glb, blend)
