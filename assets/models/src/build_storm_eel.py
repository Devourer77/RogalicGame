# Грозовой угорь (~1.5 м над трясиной, элита болот акта 1) — тварь Раскола. Огромный угорь наполовину
# в тёмной болотной воде: кольца лежат в пределах клетки, передняя часть поднята. Тёмно-оливковая
# скользкая кожа из колец-сегментов, длинный зубчатый плавник по спине. Вдоль тела бегут бледные
# холодно-жёлтые разряды (как у Грозовика) и бирюзовые трещины Раскола; в пасти искрит.
# Облик — claude/мир.md; референс Gemini 17 ноября (второй вариант: пасть светится, не бордовая).
# Смотрит в -Y.
#
# Анимации: Idle, Walk (плывёт по трясине), Attack (бросок с молнией по лужам), Hit, Death.
# Запуск: python3 build_storm_eel.py out/storm_eel.glb out/storm_eel.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
from mathutils import Vector

NAME = "StormEel"

# Хребет: от колец в воде вверх S-образно до головы
SPINE = [(0, 0.2, 0.08), (0, 0.13, 0.42), (0, -0.02, 0.74), (0, 0.03, 1.04), (0, -0.07, 1.3), (0, -0.24, 1.42)]
RADII = [0.17, 0.16, 0.145, 0.13, 0.12, 0.115]
SEGS = ["Seg0", "Seg1", "Seg2", "Seg3", "Seg4"]
SNOUT = (0, -0.46, 1.34)


# ---------- Модель ----------

def build_mesh():
    skin = k.mat("Eel_Skin", (0.4, 0.42, 0.26), rough=0.35)        # тёмно-оливковая, мокрая (светлее природной)
    skin_d = k.mat("Eel_SkinDark", (0.29, 0.31, 0.19), rough=0.35)
    belly = k.mat("Eel_Belly", (0.52, 0.53, 0.38), rough=0.4)
    fin = k.mat("Eel_Fin", (0.33, 0.3, 0.2), rough=0.5)
    water = k.mat("Eel_Water", (0.1, 0.14, 0.12), metallic=0.15, rough=0.08)
    tooth = k.mat("Eel_Tooth", (0.8, 0.8, 0.7), rough=0.5)
    mouth = k.mat("Eel_Mouth", (0.16, 0.14, 0.12), rough=0.8)
    spark = k.mat("Eel_Spark", (0.96, 0.96, 0.72), rough=0.3, emit=2.2)   # бледный холодный жёлтый — только разряды
    rift = k.mat("Eel_Rift", (0.25, 0.85, 0.75), rough=0.4, emit=1.3)

    # Болотная вода и кольца, лежащие в ней (в пределах клетки)
    k.barrel("Pool", 0.46, 0.44, 0.0, 0.014, water, "Root", segs=12)
    n = 14
    ring = [Vector((0.27 * math.cos(math.tau * i / n), 0.05 + 0.27 * math.sin(math.tau * i / n), 0.07)) for i in range(n)]
    for i in range(n - 2):   # кольцо не замкнуто: из него поднимается тело
        k.limb(f"Coil{i}", tuple(ring[i]), tuple(ring[i + 1]), 0.13, 0.13, skin if i % 2 else skin_d, "Root", segs=7)
    k.limb("CoilJoin", tuple(ring[n - 2]), SPINE[0], 0.14, 0.16, skin, "Root", segs=7)

    # Поднятое тело — кольца-сегменты, светлое брюхо спереди
    for i, bone in enumerate(SEGS):
        a, b = Vector(SPINE[i]), Vector(SPINE[i + 1])
        k.limb(f"Body{i}", tuple(a), tuple(b), RADII[i], RADII[i + 1], skin if i % 2 else skin_d, bone, segs=8)
        mid = a.lerp(b, 0.5)
        if i > 0:   # сустав-шар прячет щель между сегментами при изгибе
            k.sphere(f"Joint{i}", RADII[i] * 0.98, tuple(a), skin_d if i % 2 else skin, bone, segs=7, rings=4)
        k.sphere(f"Belly{i}", RADII[i] * 0.75, tuple(mid + Vector((0, -RADII[i] * 0.45, 0))), belly, bone,
                 scale=(0.8, 0.4, 1.6), segs=6, rings=4)
        # Зубчатый плавник по спине
        back = Vector((0, 1, 0))
        fin_pts = [(0.0, 0.0), (0.06, 0.13), (0.12, 0.02), (0.18, 0.15), (0.24, 0.0)]
        d = (b - a).normalized()
        k.plate(f"Fin{i}", fin_pts, 0.015, tuple(a + back * RADII[i] * 0.9), tuple(d), tuple(back), fin, bone)
        # Разряды молнии (зигзаг вдоль тела) и бирюзовые трещины
        side = Vector((1 if i % 2 else -1, 0, 0))
        k.crack(f"Spark{i}", [(0, 0), (0.06, 0.03), (0.1, -0.03), (0.16, 0.03), (0.22, -0.02)],
                tuple(a + side * RADII[i] * 0.98), tuple(d), (0, 1, 0), spark, bone, width=0.014, depth=0.02)
        if i in (1, 3):
            k.crack(f"Rift{i}", [(0, 0.03), (0.05, 0.0), (0.1, 0.03), (0.14, -0.01)],
                    tuple(a - side * RADII[i] * 0.98), tuple(d), (0, 1, 0), rift, bone, width=0.014, depth=0.02)

    # Голова: череп, верхняя челюсть, нижняя на своей кости, зубы, глаза, искра в пасти
    h0, h1 = Vector(SPINE[4]), Vector(SPINE[5])
    k.sphere("NeckJoint", RADII[5] * 0.98, tuple(h1), skin_d, "Head", segs=7, rings=4)
    k.limb("Skull", tuple(h0), tuple(h1), RADII[4], 0.11, skin_d, "Head", segs=8)
    k.limb("UpperJaw", tuple(h1), SNOUT, 0.1, 0.045, skin, "Head", segs=7)
    k.limb("HeadFin", tuple(h0 + Vector((0, 0.09, 0.08))), tuple(h1 + Vector((0, 0.04, 0.16))), 0.03, 0.0, fin, "Head", segs=4)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.04, 0.035, 0.025), (0.085 * s, -0.27, 1.47), rift, "Head", rot=(10, -20 * s, 0))
        for j, f in enumerate((0.3, 0.6, 0.85)):
            c = h1.lerp(Vector(SNOUT), f)
            k.limb(f"Tooth{s}{j}", (c.x + 0.05 * s * (1 - f * 0.4), c.y, c.z - 0.03), (c.x + 0.05 * s * (1 - f * 0.4), c.y, c.z - 0.08),
                   0.012, 0.0, tooth, "Head", segs=3)
    k.sphere("MouthIn", 0.07, tuple(h1.lerp(Vector(SNOUT), 0.4) + Vector((0, 0, -0.06))), mouth, "Head", scale=(1.0, 1.6, 0.6), segs=6, rings=3)
    k.sphere("MouthSpark", 0.05, tuple(h1.lerp(Vector(SNOUT), 0.45) + Vector((0, 0, -0.06))), spark, "Spark",
             scale=(1.0, 1.4, 0.8), segs=6, rings=3)
    jaw0 = (0, -0.26, 1.33)
    k.limb("LowerJaw", jaw0, (0, -0.44, 1.24), 0.08, 0.035, belly, "Jaw", segs=6)
    for s in (-1, 1):
        k.limb(f"LowTooth{s}", (0.035 * s, -0.4, 1.27), (0.035 * s, -0.4, 1.33), 0.011, 0.0, tooth, "Jaw", segs=3)
    return k.join_parts("StormEelMesh")


# ---------- Скелет ----------

BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None)}
parent = "Root"
for i, bone in enumerate(SEGS):
    BONES[bone] = (SPINE[i], SPINE[i + 1], parent)
    parent = bone
BONES["Head"] = (SPINE[5], SNOUT, "Seg4")
BONES["Jaw"] = ((0, -0.26, 1.33), (0, -0.44, 1.24), "Head")
BONES["Spark"] = ((0, -0.32, 1.33), (0, -0.38, 1.33), "Head")
SCALED = ("Spark",)


# ---------- Анимации ----------
# Сегменты — кости «вверх»: X+ клонит вперёд, Z+ — вбок вправо, Y — скручивание.

def wave_body(p, t, amp_x=3.0, amp_z=5.0, cycles=1.0):
    """Волна бежит по телу снизу вверх: у каждого сегмента своя задержка."""
    for i, bone in enumerate(SEGS):
        p.add(bone, x=amp_x * wave(t, cycles, -0.12 * i), z=amp_z * wave(t, cycles, -0.15 * i + 0.25))


def stance():
    p = Pose({}, {})
    p.add("Head", x=-6)
    return p


def idle(t):
    """Покой (3 сек): тело медленно покачивается волной, пасть приоткрывается, искра в пасти мерцает,
    иногда — треск разряда (голова дёргается, искра вспыхивает)."""
    p = stance()
    wave_body(p, t, amp_x=3, amp_z=5)
    crack = pulse(t, 0.4, 0.03) + pulse(t, 0.46, 0.03)
    p.add("Head", z=6 * wave(t, 1, 0.5) + 6 * crack * wave(t, 20), x=3 * wave(t, 2))
    p.add("Jaw", x=-(8 + 6 * wave(t, 2, 0.1) + 14 * crack))
    p.size("Spark", 1.0 + 0.25 * wave(t, 7) + 1.2 * crack)
    return p


def walk(t):
    """Плывёт по трясине (0.8 сек): волна по телу сильнее и быстрее, голова держит направление."""
    p = stance()
    wave_body(p, t, amp_x=4, amp_z=12, cycles=1.0)
    p.add("Head", z=-6 * wave(t, 1, 0.1))
    p.move("Root", z=-0.02 * (1 + wave(t, 2)))
    p.size("Spark", 1.0 + 0.2 * wave(t, 4))
    return p


def attack(t):
    """Бросок с молнией (0.8 сек): откидывается назад, пасть распахнута, искра разгорается →
    резкий бросок вперёд-вниз (к 0.4 сек), разряд вспыхивает → возврат."""
    p = stance()
    K = [0.0, 0.3, 0.48, 0.62, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    for i, bone in enumerate(SEGS):
        f = (i + 1) / len(SEGS)
        p.add(bone, x=tr([0, -10 * f, 18 * f, 14 * f, 0]))
    p.add("Head", x=tr([-6, -20, 14, 10, -6]))
    p.add("Jaw", x=tr([0, -40, -50, -20, 0]))
    p.size("Spark", tr([1, 2.0, 3.2, 1.8, 1]))
    p.move("Root", y=tr([0, 0.05, -0.12, -0.1, 0]))
    return p


def hit(t):
    """Получил удар (0.45 сек): тело отдёргивается назад волной, голова мотается, искра гаснет."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.34, 1), (0.6, -0.3), (0.82, 0.08), (1, 0)])
    for i, bone in enumerate(SEGS):
        p.add(bone, x=-8 * snap * (i + 1) / len(SEGS), z=6 * whip * (1 if i % 2 else -1))
    p.add("Head", x=-20 * whip, z=14 * whip)
    p.add("Jaw", x=-30 * snap)
    p.size("Spark", 1.0 - 0.7 * snap)
    return p


def death(t):
    """Гибель (1.4 сек): последний разряд, тело обмякает и падает вперёд в трясину, уходит под воду."""
    p = stance()
    K = [0.0, 0.2, 0.5, 0.8, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    for i, bone in enumerate(SEGS):
        f = (i + 1) / len(SEGS)
        p.add(bone, x=tr([0, -10 * f, 24, 30, 30]), z=tr([0, 6, -4, 4, 4]))
    p.add("Head", x=tr([-6, -30, 20, 30, 30]))
    p.add("Jaw", x=tr([0, -50, -20, -30, -30]))
    p.size("Spark", tr([1, 3.0, 0.4, 0.05, 0.02]))
    p.move("Root", z=tr([0, 0, -0.1, -0.35, -0.5]))
    p.add("Seg4", z=14 * pulse(t, 0.9, 0.04))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, scale_bones=SCALED)
    k.bake(rig, "Hit", 14, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 42, death, scale_bones=SCALED)


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
    glb = args[0] if args else os.path.join(here, "..", "storm_eel.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "storm_eel.blend")
    build(glb, blend)
