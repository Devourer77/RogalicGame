# Пещерный слепыш — тварь подземного озера (акт 2, Подземье), ~1.2 м, стоит полупрямо (как на листе Gemini).
# Тощий безволосый зверь с влажной бледной серо-синей кожей (темнее и синее, чем на листе, — не кость),
# длинные тонкие лапы, гладкая голова без глаз, огромные перепончатые уши, как у летучей мыши,
# широкая пасть с мелкими тёмными зубами; бирюзовые трещины вдоль хребта и на ушах; с него капает.
# Не видит — слышит: идёт к тому, кто больше всех ходил.
# Смотрит в -Y. Анимации: Idle (прислушивается), Walk, Attack (укус-бросок), Hit, Death.
# Запуск: python3 build_blind_lurker.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))


def build_mesh():
    v = a2.volcano_mats()
    skin = k.mat("BL_Skin", (0.43, 0.5, 0.58), rough=0.45)
    skin_d = k.mat("BL_SkinDark", (0.32, 0.37, 0.45), rough=0.5)
    ear_in = k.mat("BL_EarIn", (0.6, 0.58, 0.62), rough=0.5)
    mouth = k.mat("BL_Mouth", (0.12, 0.1, 0.12), rough=0.9)
    teeth = k.mat("BL_Teeth", (0.32, 0.3, 0.3), rough=0.6)
    drip = k.mat("BL_Drip", (0.55, 0.75, 0.92), rough=0.2, emit=0.3)
    # Таз, живот, грудь — тощие, сутулые
    k.sphere("Pelvis", 0.13, (0, 0.02, 0.62), skin_d, "Hips", scale=(1.0, 0.85, 0.8), segs=7, rings=4)
    k.limb("Belly", (0, 0.0, 0.66), (0, -0.02, 0.86), 0.11, 0.14, skin, "Spine", segs=7)
    k.sphere("Chest", 0.17, (0, -0.04, 0.96), skin, "Chest", scale=(1.0, 0.85, 0.9), segs=8, rings=5)
    for i in range(4):   # рёбра
        k.box(f"Rib{i}", (0.26, 0.02, 0.018), (0, -0.16, 0.9 + i * 0.045), skin_d, "Chest", rot=(-10, 0, 0))
    # Хребет с бирюзовыми трещинами и костяными бугорками
    for i in range(5):
        k.box(f"Spine{i}", (0.04, 0.04, 0.04), (0, 0.13 - i * 0.01, 0.7 + i * 0.07), skin_d, "Spine" if i < 2 else "Chest",
              rot=(45, 0, 0))
    k.crack("SpineRift", [(0, 0), (0.02, 0.1), (-0.01, 0.2), (0.01, 0.3)], (0, 0.15, 0.7), (1, 0, 0), (0, 0, 1),
            v["rift"], "Chest", width=0.014, depth=0.014)
    # Голова: гладкая, без глаз, огромная пасть
    k.limb("Neck", (0, -0.06, 1.04), (0, -0.12, 1.12), 0.06, 0.06, skin, "Head", segs=6)
    k.sphere("Head", 0.14, (0, -0.16, 1.2), skin, "Head", scale=(1.0, 1.05, 0.9), segs=8, rings=5)
    k.box("Mouth", (0.18, 0.06, 0.03), (0, -0.29, 1.14), mouth, "Head")
    for i in range(6):
        x = -0.075 + i * 0.03
        k.limb(f"ToothU{i}", (x, -0.295, 1.155), (x, -0.3, 1.13), 0.008, 0.002, teeth, "Head", segs=3)
    k.sphere("Jaw", 0.1, (0, -0.22, 1.09), skin_d, "Jaw", scale=(1.05, 1.0, 0.45), segs=7, rings=3)
    for i in range(5):
        x = -0.06 + i * 0.03
        k.limb(f"ToothL{i}", (x, -0.3, 1.1), (x, -0.3, 1.125), 0.008, 0.002, teeth, "Jaw", segs=3)
    # Огромные уши-перепонки
    for side, s in SIDES:
        k.plate(f"Ear.{side}", [(0, -0.05), (0.1, -0.08), (0.28, 0.02), (0.34, 0.2), (0.2, 0.16), (0.06, 0.08)], 0.02,
                (0.09 * s, -0.12, 1.24), (s, 0, 0.25), (0, 0.1, 1), skin, f"Ear.{side}")
        k.plate(f"EarIn.{side}", [(0.04, -0.02), (0.12, -0.04), (0.25, 0.04), (0.28, 0.15), (0.17, 0.12), (0.06, 0.05)],
                0.022, (0.09 * s, -0.125, 1.24), (s, 0, 0.25), (0, 0.1, 1), ear_in, f"Ear.{side}")
        k.crack(f"EarRift.{side}", [(0.05, 0.0), (0.14, 0.04), (0.24, 0.1)], (0.09 * s, -0.145, 1.24), (s, 0, 0.25),
                (0, 0.1, 1), v["rift"], f"Ear.{side}", width=0.01, depth=0.01)
        # Руки длинные тонкие
        k.limb(f"UpperArm.{side}", (0.16 * s, -0.04, 1.02), (0.22 * s, -0.12, 0.78), 0.04, 0.032, skin, f"UpperArm.{side}", segs=6)
        k.limb(f"ForeArm.{side}", (0.22 * s, -0.12, 0.78), (0.24 * s, -0.2, 0.52), 0.032, 0.025, skin, f"ForeArm.{side}", segs=6)
        for j in (-1, 0, 1):
            k.limb(f"Finger.{side}{j}", (0.24 * s, -0.2, 0.52), (0.24 * s + 0.03 * j, -0.27, 0.44), 0.012, 0.004, skin_d,
                   f"Hand.{side}", segs=4)
        # Ноги: бедро вперёд, голень назад, длинная стопа (как у зверя на задних лапах)
        k.limb(f"Thigh.{side}", (0.11 * s, 0.02, 0.62), (0.14 * s, -0.14, 0.4), 0.06, 0.045, skin, f"Thigh.{side}", segs=6)
        k.limb(f"Shin.{side}", (0.14 * s, -0.14, 0.4), (0.15 * s, 0.06, 0.14), 0.04, 0.03, skin, f"Shin.{side}", segs=6)
        k.limb(f"Foot.{side}", (0.15 * s, 0.06, 0.14), (0.15 * s, -0.1, 0.02), 0.03, 0.025, skin_d, f"Foot.{side}", segs=5)
        for j in (-1, 1):
            k.limb(f"Toe.{side}{j}", (0.15 * s, -0.1, 0.02), (0.15 * s + 0.03 * j, -0.17, 0.01), 0.012, 0.004, skin_d,
                   f"Foot.{side}", segs=4)
    for i, (x, y, z) in enumerate([(0.08, -0.16, 0.86), (-0.1, -0.1, 0.72)]):
        k.limb(f"Drip{i}", (x, y, z), (x, y, z - 0.08), 0.012, 0.004, drip, "Chest" if z > 0.8 else "Spine", segs=4)
    return k.join_parts("BlindLurkerMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.12), None),
    "Hips": ((0, 0.02, 0.6), (0, 0.02, 0.7), "Root"),
    "Spine": ((0, 0.02, 0.7), (0, 0, 0.88), "Hips"),
    "Chest": ((0, 0, 0.88), (0, -0.04, 1.06), "Spine"),
    "Head": ((0, -0.08, 1.06), (0, -0.16, 1.32), "Chest"),
    "Jaw": ((0, -0.16, 1.12), (0, -0.3, 1.1), "Head"),
}
for _side, _s in SIDES:
    BONES.update({
        f"Ear.{_side}": ((0.09 * _s, -0.12, 1.24), (0.3 * _s, -0.1, 1.38), "Head"),
        f"UpperArm.{_side}": ((0.16 * _s, -0.04, 1.02), (0.22 * _s, -0.12, 0.78), "Chest"),
        f"ForeArm.{_side}": ((0.22 * _s, -0.12, 0.78), (0.24 * _s, -0.2, 0.52), f"UpperArm.{_side}"),
        f"Hand.{_side}": ((0.24 * _s, -0.2, 0.52), (0.24 * _s, -0.27, 0.44), f"ForeArm.{_side}"),
        f"Thigh.{_side}": ((0.11 * _s, 0.02, 0.62), (0.14 * _s, -0.14, 0.4), "Hips"),
        f"Shin.{_side}": ((0.14 * _s, -0.14, 0.4), (0.15 * _s, 0.06, 0.14), f"Thigh.{_side}"),
        f"Foot.{_side}": ((0.15 * _s, 0.06, 0.14), (0.15 * _s, -0.1, 0.02), f"Shin.{_side}"),
    })

STANCE = {"Hips": (6, -6, 0), "Spine": (14, -4, 0), "Chest": (10, -4, 0), "Head": (-14, 8, 10),
          "UpperArm.L": (-10, 0, -6), "UpperArm.R": (-20, 0, 4), "ForeArm.R": (-14, 0, 0),
          "Thigh.L": (-10, 0, -4), "Thigh.R": (6, 0, 6), "Jaw": (6, 0, 0)}
STANCE_LOC = {"Hips": (0, 0, -0.02)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def ears(p, spread=0.0, twitch=0.0):
    """Уши: spread — шире/плотнее к голове, twitch — повернуть на звук."""
    p.add("Ear.R", x=-spread + twitch, z=spread * 0.5)
    p.add("Ear.L", x=-spread - twitch, z=-spread * 0.5)


def idle(t):
    """Прислушивается (3 сек): замирает, уши поворачиваются на звук, голова наклоняется, пасть приоткрыта."""
    p = stance()
    br = wave(t, 2)
    p.move("Hips", z=-0.006 * br)
    p.add("Spine", x=2 * br)
    tilt = k.track(t, [(0, 0), (0.2, 0), (0.26, 1), (0.5, 1), (0.56, -1), (0.8, -1), (0.86, 0), (1, 0)])
    p.add("Head", z=14 * tilt, y=10 * tilt)
    ears(p, spread=8 * wave(t, 1, 0.1), twitch=16 * tilt + 10 * pulse(t, 0.4, 0.04))
    p.add("Jaw", x=10 * pulse(t, 0.66, 0.06))
    p.add("Hand.R", x=-14 * pulse(t, 0.7, 0.05))
    return p


def walk(t):
    """Крадётся (0.8 сек): низко, длинными шагами, голова вперёд, уши прижаты."""
    p = Pose(STANCE)
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    p.move("Hips", z=-0.04 + 0.02 * wave(t, 2))
    p.add("Spine", x=8)
    p.set("Thigh.R", 6 - 24 * a, 0, 6)
    p.set("Thigh.L", -10 + 24 * a, 0, -4)
    p.set("Shin.R", -16 * max(0.0, c), 0, 0)
    p.set("Shin.L", -16 * max(0.0, -c), 0, 0)
    p.add("UpperArm.R", x=-14 * a)
    p.add("UpperArm.L", x=14 * a)
    p.add("Head", x=6, y=6 * a)
    ears(p, spread=-12)
    return p


def attack(t):
    """Укус (0.8 сек): присел, уши прижаты → бросок вперёд, пасть распахнута (к 0.4 сек) → отскок."""
    p = Pose({}, {})
    K = [0.0, 0.24, 0.4, 0.58, 1.0]
    for bone, *keys in [
        ("Spine", (20, 0, 0), (30, 0, 0), (26, 0, 0)),
        ("Chest", (16, 0, 0), (24, 0, 0), (20, 0, 0)),
        ("Head", (-30, 0, 0), (-10, 0, 0), (-14, 0, 0)),
        ("Jaw", (10, 0, 0), (44, 0, 0), (30, 0, 0)),
        ("UpperArm.R", (20, 0, 20), (-70, 0, 10), (-60, 0, 10)),
        ("UpperArm.L", (20, 0, -20), (-70, 0, -10), (-60, 0, -10)),
        ("Thigh.L", (-30, 0, -4), (-20, 0, -4), (-20, 0, -4)),
        ("Thigh.R", (-20, 0, 6), (20, 0, 6), (16, 0, 6)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.move("Hips", z=track(t, [(0, -0.02), (K[1], -0.1), (K[2], -0.02), (1, -0.02)]))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.04), (K[2], -0.16), (K[3], -0.12), (1, 0)]))
    p.add("Ear.R", x=track(t, [(0, 0), (K[1], 20), (K[2], 30), (1, 0)]))
    p.add("Ear.L", x=track(t, [(0, 0), (K[1], 20), (K[2], 30), (1, 0)]))
    return p


def hit(t):
    """Получил удар (0.4 сек): отшатнулся, визг (пасть), уши хлопают с опозданием."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.move("Root", y=0.07 * snap)
    p.add("Spine", x=-16 * snap)
    p.add("Head", x=-20 * whip)
    p.add("Jaw", x=30 * snap)
    ears(p, spread=20 * whip)
    p.add("UpperArm.R", x=20 * whip)
    p.add("UpperArm.L", x=20 * whip)
    return p


def death(t):
    """Гибель (1.2 сек): корчится, падает набок, уши обвисают, последняя судорога лапы."""
    p = stance()
    fall = track(t, [(0, 0), (0.25, -8), (0.6, 80), (0.68, 74), (0.76, 82), (1, 82)])
    p.set("Root", 0, 0, fall)
    p.move("Root", x=track(t, [(0, 0), (0.6, 0.22), (1, 0.22)]), z=track(t, [(0, 0), (0.6, 0.1), (1, 0.1)]))
    curl = track(t, [(0, 0), (0.5, 1), (1, 1)])
    p.add("Spine", x=20 * curl)
    p.add("Head", x=10 * curl)
    p.add("Jaw", x=24 * curl)
    ears(p, spread=-30 * curl)
    p.add("Thigh.R", x=-40 * curl)
    p.add("Thigh.L", x=-30 * curl)
    p.add("Hand.L", x=-30 * pulse(t, 0.9, 0.05))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("BlindLurker")
    body = build_mesh()
    rig = k.build_armature("BlindLurker", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 24, walk, cyclic=True)
    k.bake(rig, "Attack", 24, attack)
    k.bake(rig, "Hit", 12, hit)
    k.bake(rig, "Death", 36, death)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "blind_lurker")
