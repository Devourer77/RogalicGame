# Рыцарь — последний из Стражи Марки. Тяжёлые латы тусклой стали, закрытый шлем с узкой прорезью,
# тёмно-жёлтый потёртый табард с гербом-колоколом, большой щит с колоколом и меч. ~1.7 м, силуэт — «квадрат».
# Смотрит в -Y (после экспорта в glTF это +Z).
#
# Запуск в Blender: вкладка Scripting → Open → этот файл → Run Script. Рядом должен лежать char_kit.py.
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "Knight"


# ---------- Модель ----------

def build_mesh():
    steel = k.mat("Knight_Steel", (0.56, 0.58, 0.62), metallic=0.75, rough=0.5)    # тусклая сталь
    dark = k.mat("Knight_DarkSteel", (0.30, 0.31, 0.36), metallic=0.75, rough=0.5)
    brass = k.mat("Knight_Brass", (0.62, 0.50, 0.22), metallic=0.65, rough=0.45)   # потемневшая латунь
    cloth = k.mat("Knight_Tabard", (0.60, 0.47, 0.16), rough=0.9)                  # тёмно-жёлтый Стражи
    cloth_d = k.mat("Knight_TabardDark", (0.45, 0.35, 0.11), rough=0.9)
    leather = k.mat("Knight_Leather", (0.30, 0.21, 0.13), rough=0.85)
    visor = k.mat("Knight_Visor", (0.03, 0.03, 0.04), rough=1.0)
    blade = k.mat("Knight_Blade", (0.78, 0.80, 0.84), metallic=0.85, rough=0.3)

    for side, s in (("R", -1), ("L", 1)):
        x = 0.11 * s
        # Ноги: латный башмак, поножи, наколенник с гребнем, набедренник
        k.box(f"Sabaton.{side}", (0.13, 0.2, 0.09), (x, -0.03, 0.045), dark, f"Foot.{side}")
        k.limb(f"Toe.{side}", (x, -0.12, 0.04), (x, -0.2, 0.025), 0.06, 0.02, steel, f"Foot.{side}", segs=4)
        k.limb(f"Greave.{side}", (x, 0, 0.09), (x, 0, 0.46), 0.07, 0.088, steel, f"Shin.{side}")
        k.sphere(f"Knee.{side}", 0.075, (x, -0.035, 0.47), steel, f"Shin.{side}", scale=(1, 0.9, 1), segs=6, rings=4)
        k.plate(f"KneeFin.{side}", [(0, -0.05), (0.07, 0.0), (0, 0.06)], 0.02, (x + 0.07 * s, -0.03, 0.47),
                (s, 0, 0), (0, 0, 1), brass, f"Shin.{side}")
        k.limb(f"Thigh.{side}", (x, 0, 0.47), (x, 0, 0.84), 0.082, 0.1, dark, f"Thigh.{side}")
        k.plate(f"Tasset.{side}", [(-0.075, 0), (0.075, 0), (0.06, -0.2), (0.0, -0.24), (-0.06, -0.2)], 0.025,
                (x + 0.035 * s, -0.105, 0.86), (1, 0, 0), (0, -0.12, 1), steel, f"Thigh.{side}")

        # Руки: большой наплечник с кантом, плечо, налокотник, наруч, латная перчатка-кулак
        ax = 0.27 * s
        k.sphere(f"Pauldron.{side}", 0.13, (ax, 0, 1.28), steel, f"UpperArm.{side}", scale=(1.15, 1.15, 0.85), segs=8, rings=4)
        k.sphere(f"PauldronRim.{side}", 0.14, (ax + 0.01 * s, 0, 1.235), brass, f"UpperArm.{side}",
                 scale=(1.15, 1.15, 0.22), segs=8, rings=3)
        k.limb(f"UpperArm.{side}", (ax, 0, 1.24), (0.28 * s, 0, 1.0), 0.062, 0.062, dark, f"UpperArm.{side}")
        k.sphere(f"Elbow.{side}", 0.068, (0.28 * s, 0.012, 1.0), steel, f"ForeArm.{side}", segs=6, rings=4)
        k.limb(f"Vambrace.{side}", (0.28 * s, 0, 1.0), (0.285 * s, -0.02, 0.79), 0.064, 0.076, steel, f"ForeArm.{side}")
        hx = 0.285 * s
        k.sphere(f"Fist.{side}", 0.06, (hx, -0.03, 0.73), dark, f"Hand.{side}", scale=(0.85, 1.05, 1.0), segs=6, rings=4)
        k.box(f"Fingers.{side}", (0.095, 0.042, 0.092), (hx, -0.075, 0.725), steel, f"Hand.{side}")
        k.box(f"Thumb.{side}", (0.036, 0.075, 0.036), (hx - 0.032 * s, -0.055, 0.78), dark, f"Hand.{side}", rot=(15, 0, 0))

    # Таз, пояс
    k.barrel("Pelvis", 0.17, 0.18, 0.78, 0.9, dark, "Hips", sy=0.8)
    k.barrel("Belt", 0.19, 0.19, 0.85, 0.91, leather, "Hips", sy=0.82)
    k.box("Buckle", (0.07, 0.025, 0.055), (0, -0.158, 0.88), brass, "Hips")
    # Полы табарда — на своих костях, рваный край
    front = [(-0.13, 0.0), (0.13, 0.0), (0.12, -0.3), (0.07, -0.37), (0.03, -0.31), (-0.03, -0.39), (-0.11, -0.32)]
    k.plate("TabardFront", front, 0.022, (0, -0.165, 0.87), (1, 0, 0), (0, 0, 1), cloth, "TabardF")
    k.plate("TabardBack", front, 0.022, (0, 0.165, 0.87), (-1, 0, 0), (0, 0, 1), cloth_d, "TabardB")

    # Кираса и табард на груди с гербом-колоколом
    k.barrel("Torso", 0.18, 0.235, 0.88, 1.18, steel, "Spine", sy=0.76)
    k.barrel("Chest", 0.235, 0.2, 1.18, 1.33, steel, "Chest", sy=0.76)
    k.plate("TabardChest", [(-0.12, 0.0), (0.12, 0.0), (0.15, 0.3), (0.09, 0.42), (-0.09, 0.42), (-0.15, 0.3)], 0.02,
            (0, -0.182, 0.9), (1, 0, 0), (0, -0.02, 1), cloth, "Spine")
    bell = [(-0.03, 0.075), (0.03, 0.075), (0.045, -0.02), (0.075, -0.055), (-0.075, -0.055), (-0.045, -0.02)]
    k.plate("Crest", bell, 0.016, (0, -0.196, 1.12), (1, 0, 0), (0, 0, 1), dark, "Spine")
    k.box("CrestClapper", (0.03, 0.016, 0.03), (0, -0.196, 1.05), dark, "Spine")
    k.barrel("Gorget", 0.12, 0.095, 1.3, 1.38, dark, "Chest")

    # Закрытый шлем: узкая прорезь, дыхательные щели, латунный гребень, конский хвост на своей кости
    k.barrel("Helm", 0.135, 0.13, 1.36, 1.59, steel, "Head", segs=10)
    k.sphere("HelmTop", 0.13, (0, 0, 1.585), steel, "Head", scale=(1, 1, 0.6), segs=10, rings=4)
    k.box("Visor", (0.2, 0.03, 0.022), (0, -0.126, 1.505), visor, "Head")
    k.box("VisorNose", (0.03, 0.04, 0.16), (0, -0.13, 1.47), brass, "Head")
    for s in (-1, 1):
        for i in range(2):
            k.box(f"Breath{s}{i}", (0.012, 0.03, 0.05), (0.045 * s + 0.03 * i * s, -0.124, 1.43), visor, "Head")
    k.box("HelmRidge", (0.03, 0.26, 0.045), (0, 0.0, 1.665), brass, "Head")
    tail = [(0, 0.03), (0.12, 0.07), (0.3, 0.0), (0.36, -0.16), (0.3, -0.1), (0.26, -0.2), (0.2, -0.08), (0.1, -0.04), (0, -0.04)]
    k.plate("Plume", tail, 0.035, (0, 0.09, 1.675), (0, 1, 0), (0, 0, 1), cloth_d, "Plume")

    # Меч (кость Weapon): рукоять сквозь кулак, клинок вперёд, плоскость клинка вертикальна
    wx, wz = -0.285, 0.73
    k.limb("Grip", (wx, 0.085, wz), (wx, -0.1, wz), 0.02, 0.02, leather, "Weapon", segs=5)
    k.sphere("Pommel", 0.034, (wx, 0.1, wz), brass, "Weapon", segs=5, rings=3)
    k.box("Guard", (0.035, 0.035, 0.26), (wx, -0.11, wz), brass, "Weapon")
    k.plate("Blade", [(0, 0.03), (0.72, 0.026), (0.82, 0.0), (0.72, -0.026), (0, -0.03)], 0.014, (wx, -0.125, wz),
            (0, -1, 0), (0, 0, 1), blade, "Weapon")
    k.plate("Fuller", [(0.02, 0.006), (0.55, 0.005), (0.55, -0.005), (0.02, -0.006)], 0.018, (wx, -0.125, wz),
            (0, -1, 0), (0, 0, 1), dark, "Weapon")

    # Большой каплевидный щит (кость Shield): цвет табарда, латунная окантовка, колокол Стражи
    sx = 0.36
    kite = [(-0.21, 0.26), (0.21, 0.26), (0.2, -0.04), (0.0, -0.4), (-0.2, -0.04)]
    rim = [(a * 1.13, b * 1.09 + 0.006) for a, b in kite]
    k.plate("ShieldRim", rim, 0.03, (sx, -0.04, 0.92), (0, 1, 0), (0, 0, 1), brass, "Shield")
    k.plate("ShieldFace", kite, 0.04, (sx + 0.012, -0.04, 0.92), (0, 1, 0), (0, 0, 1), cloth, "Shield")
    big = [(-0.055, 0.13), (0.055, 0.13), (0.085, -0.03), (0.14, -0.085), (-0.14, -0.085), (-0.085, -0.03)]
    k.plate("ShieldBell", big, 0.02, (sx + 0.036, -0.04, 0.96), (0, 1, 0), (0, 0, 1), dark, "Shield")
    k.box("ShieldClapper", (0.02, 0.055, 0.055), (sx + 0.036, -0.04, 0.83), dark, "Shield")

    return k.join_parts("KnightMesh")


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.2), None),
    "Hips": ((0, 0, 0.86), (0, 0, 0.95), "Root"),
    "Spine": ((0, 0, 0.95), (0, 0, 1.16), "Hips"),
    "Chest": ((0, 0, 1.16), (0, 0, 1.36), "Spine"),
    "Head": ((0, 0, 1.36), (0, 0, 1.62), "Chest"),
    "Plume": ((0, 0.09, 1.675), (0, 0.4, 1.6), "Head"),
    "TabardF": ((0, -0.165, 0.87), (0, -0.165, 0.5), "Hips"),
    "TabardB": ((0, 0.165, 0.87), (0, 0.165, 0.5), "Hips"),
    "Weapon": ((-0.285, -0.03, 0.73), (-0.285, -0.3, 0.73), "Hand.R"),
    "Shield": ((0.33, -0.04, 0.9), (0.33, -0.04, 1.1), "ForeArm.L"),
}
for side, s in (("R", -1), ("L", 1)):
    BONES.update({
        f"UpperArm.{side}": ((0.27 * s, 0, 1.27), (0.28 * s, 0, 1.0), "Chest"),
        f"ForeArm.{side}": ((0.28 * s, 0, 1.0), (0.285 * s, -0.02, 0.78), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.285 * s, -0.02, 0.78), (0.285 * s, -0.03, 0.68), f"ForeArm.{side}"),
        f"Thigh.{side}": ((0.11 * s, 0, 0.86), (0.11 * s, 0, 0.47), "Hips"),
        f"Shin.{side}": ((0.11 * s, 0, 0.47), (0.11 * s, 0, 0.09), f"Thigh.{side}"),
        f"Foot.{side}": ((0.11 * s, 0, 0.09), (0.11 * s, -0.14, 0.02), f"Shin.{side}"),
    })


# ---------- Анимации ----------

# Стойка Стражи: левая нога и щит впереди, меч поднят у правого плеча остриём вверх-вперёд,
# корпус развёрнут левым плечом к врагу, голова смотрит прямо.
STANCE = {
    "Spine": (5, -14, 0), "Chest": (4, -10, 0), "Head": (-6, 22, 0),
    "Thigh.L": (-24, 0, -7), "Shin.L": (28, 0, 0), "Foot.L": (4, 0, 0),
    "Thigh.R": (4, 0, 10), "Shin.R": (18, 0, 0), "Foot.R": (22, 0, 0),
    "UpperArm.R": (-12, 0, 30), "ForeArm.R": (-96, 55, 0), "Weapon": (-22, 0, 0),
    "UpperArm.L": (-42, -30, -14), "ForeArm.L": (-68, 0, 0), "Shield": (0, 0, 0),
    "TabardF": (-10, 0, 0), "TabardB": (4, 0, 0), "Plume": (0, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.035)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3.3 сек): тяжело дышит, переносит вес, медленно оглядывает поле, поправляет щит, меч покачивается."""
    p = stance()
    breath = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", x=0.012 * sway, z=-0.008 * (breath * 0.5 + 0.5))
    p.add("Hips", z=1.5 * sway)
    p.add("Thigh.L", z=-1.5 * sway).add("Thigh.R", z=-1.5 * sway)
    p.add("Spine", x=1.5 * breath, z=-1.2 * sway)
    p.add("Chest", x=2.5 * wave(t, 2, -0.06))
    p.add("UpperArm.R", z=2.5 * wave(t, 2, -0.06)).add("UpperArm.L", z=-2.5 * wave(t, 2, -0.06))   # плечи ходят от дыхания
    # Голова: спокойно осматривает поле — влево, пауза, вправо, пауза
    look = track(t, [(0, 0), (0.12, 0), (0.3, 20), (0.46, 20), (0.66, -24), (0.82, -24), (0.96, 0), (1, 0)])
    p.add("Head", y=look, x=-1.5 * breath + 3 * pulse(t, 0.56, 0.1))
    p.add("Plume", x=-3 * breath, z=-look * 0.35 + 4 * wave(t, 1, -0.15))
    # Меч: остриё чертит медленный круг
    p.add("ForeArm.R", x=3 * wave(t, 1, 0.1))
    p.add("Weapon", x=4 * wave(t, 1, 0.2), z=4 * wave(t, 1, 0.45))
    # Поправляет щит: приподнял, встряхнул, опустил
    fix = pulse(t, 0.74, 0.1)
    p.add("UpperArm.L", x=-8 * fix + 2 * breath, z=-5 * fix)
    p.add("ForeArm.L", x=-10 * fix)
    p.add("Shield", x=4 * wave(t, 12) * pulse(t, 0.76, 0.05))
    p.add("TabardF", x=2.5 * wave(t, 1, -0.2)).add("TabardB", x=2.5 * wave(t, 1, -0.25))
    return p


def walk(t):
    """Марш (0.8 сек): тяжёлый шаг, щит впереди, плечи ходят навстречу ногам, табард и хвост шлема качаются."""
    p = Pose(STANCE)
    a = wave(t, 1)            # +1: правая нога впереди
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.08)
    p.move("Hips", z=-0.03 + 0.02 * bounce, x=0.014 * a)
    p.add("Hips", y=7 * a, z=3 * a)
    p.set("Thigh.R", -10 - 32 * a, 0, 5)
    p.set("Thigh.L", -10 + 32 * a, 0, -5)
    p.set("Shin.R", 18 + 36 * max(0.0, c) + 6 * a, 0, 0)
    p.set("Shin.L", 18 + 36 * max(0.0, -c) - 6 * a, 0, 0)
    p.set("Foot.R", 8 - 18 * a, 0, 0)
    p.set("Foot.L", 8 + 18 * a, 0, 0)
    p.set("Spine", 9, -10 - 8 * a, 0)
    p.set("Chest", 5, -8 - 4 * a, 0)
    p.set("Head", -8 + 2 * bounce, 18 + 10 * a, 0)
    p.add("UpperArm.R", x=10 * a, z=-4)
    p.add("Weapon", x=6 * wave(t, 2, 0.25))
    p.add("UpperArm.L", x=-8 * a)
    p.add("Shield", x=3 * bounce)
    p.set("TabardF", -8 - 16 * abs(a), 0, 0)
    p.set("TabardB", 14 + 8 * wave(t, 2, -0.12), 0, 0)
    p.set("Plume", -8 * wave(t, 2, -0.15), 0, 6 * a)
    return p


def attack(t):
    """Удар мечом (0.87 сек): замах из-за плеча → шаг вперёд и рубящий удар наискось (к 0.4 сек) → пронос → в стойку."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.34, 0.46, 0.62, 1.0]   # стойка, замах, пик, удар, пронос, стойка
    S = STANCE

    def tr(bone, wind, peak, hit_, follow):
        base = S.get(bone, (0, 0, 0))
        p.set(bone, *track3(t, [(K[0], base), (K[1], wind), (K[2], peak), (K[3], hit_), (K[4], follow), (K[5], base)]))

    tr("Spine", (0, -26, 0), (-4, -30, 0), (16, 14, 0), (20, 22, 0))
    tr("Chest", (0, -16, 0), (-4, -18, 0), (10, 12, 0), (12, 16, 0))
    tr("Head", (-4, 36, 0), (-2, 40, 0), (-16, -14, 0), (-18, -20, 0))
    tr("UpperArm.R", (-80, 0, 44), (-150, 0, 34), (-66, 0, 0), (-34, 0, -24))
    tr("ForeArm.R", (-112, 55, 0), (-96, 55, 0), (-18, 45, 0), (-12, 30, 0))
    tr("Weapon", (0, 0, 0), (26, 0, 0), (-42, 0, 0), (-64, 0, 0))
    tr("UpperArm.L", (-50, -30, -20), (-46, -30, -24), (-10, -20, -34), (-4, -20, -34))
    tr("ForeArm.L", (-74, 0, 0), (-70, 0, 0), (-60, 0, 0), (-60, 0, 0))
    tr("Thigh.L", (-18, 0, -7), (-30, 0, -7), (-50, 0, -7), (-48, 0, -7))
    tr("Shin.L", (30, 0, 0), (40, 0, 0), (54, 0, 0), (52, 0, 0))
    tr("Foot.L", (12, 0, 0), (10, 0, 0), (4, 0, 0), (4, 0, 0))
    tr("Thigh.R", (-4, 0, 10), (4, 0, 10), (24, 0, 10), (22, 0, 10))
    tr("Shin.R", (30, 0, 0), (20, 0, 0), (14, 0, 0), (16, 0, 0))
    tr("Foot.R", (26, 0, 0), (24, 0, 0), (38, 0, 0), (38, 0, 0))
    tr("TabardF", (0, 0, 0), (-4, 0, 0), (-40, 0, 0), (-30, 0, 0))
    tr("TabardB", (-6, 0, 0), (0, 0, 0), (30, 0, 0), (10, 0, 0))
    tr("Plume", (-10, 0, 0), (-14, 0, 0), (30, 0, -10), (-12, 0, 6))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.05), (K[2], 0.02), (K[3], -0.24), (K[4], -0.24), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.035), (K[1], -0.05), (K[2], -0.02), (K[3], -0.11), (K[4], -0.1), (1, -0.035)]))
    return p


def block(t):
    """Блок (0.67 сек): щит рывком перед собой, присел за ним, голова за кромкой; удар в щит — дрожь; обратно в стойку."""
    p = stance()
    up = track(t, [(0, 0), (0.22, 1), (0.7, 1), (1, 0)])
    jolt = pulse(t, 0.36, 0.1)
    p.move("Hips", z=-0.07 * up, y=0.03 * jolt)
    p.add("Thigh.L", x=-14 * up).add("Shin.L", x=22 * up).add("Foot.L", x=8 * up)
    p.add("Thigh.R", x=-6 * up).add("Shin.R", x=18 * up).add("Foot.R", x=12 * up)
    p.add("Spine", x=10 * up - 8 * jolt, y=-6 * up)
    p.add("Chest", x=4 * up - 4 * jolt)
    p.add("Head", x=10 * up, y=4 * up)
    p.add("UpperArm.L", x=-34 * up + 10 * jolt, y=16 * up, z=-4 * up)
    p.add("ForeArm.L", x=-22 * up + 12 * jolt)
    p.add("Shield", x=-10 * up + 8 * jolt * wave(t, 9))
    p.add("UpperArm.R", x=18 * up, z=8 * up)
    p.add("Weapon", x=-14 * up)
    p.add("TabardF", x=-10 * up + 14 * jolt).add("Plume", x=14 * jolt)
    return p


def hit(t):
    """Получил удар (0.5 сек): латы принимают удар — корпус отбрасывает, голова мотается следом, шаг назад."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.34, 1), (0.6, -0.3), (0.82, 0.08), (1, 0)])
    p.move("Root", y=0.1 * snap)
    p.move("Hips", z=-0.03 * snap)
    p.add("Spine", x=-20 * snap, y=12 * snap)
    p.add("Chest", x=-10 * snap)
    p.add("Head", x=-22 * whip, y=-14 * snap, z=6 * whip)
    p.add("UpperArm.R", x=20 * snap, z=20 * snap).add("ForeArm.R", x=30 * snap).add("Weapon", x=-24 * whip)
    p.add("UpperArm.L", x=30 * snap, z=-24 * snap).add("Shield", x=10 * whip)
    p.add("Thigh.L", x=16 * snap).add("Shin.L", x=-8 * snap)
    p.add("Thigh.R", x=-14 * snap).add("Shin.R", x=16 * snap)
    p.add("TabardF", x=-26 * whip).add("TabardB", x=-16 * whip)
    p.add("Plume", x=30 * whip)
    return p


def death(t):
    """Падение (1.5 сек): пошатнулся, упал на колено, опёрся на меч, уронил голову и завалился вперёд на щит."""
    p = Pose({}, {})
    K = [0.0, 0.18, 0.42, 0.62, 0.84, 1.0]   # стойка, отшатнулся, на колене с мечом, голова упала, лёг, затих
    S = STANCE

    def tr(bone, a, b, c, d, e):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], a), (K[2], b), (K[3], c), (K[4], d), (K[5], e)]))

    tr("Spine", (-16, -6, 0), (14, -10, 0), (22, -8, 4), (30, 0, 0), (28, 0, 0))
    tr("Chest", (-8, -4, 0), (8, -8, 0), (16, -6, 4), (16, 0, 0), (14, 0, 0))
    tr("Head", (-20, 10, 0), (4, 16, 0), (34, 8, 8), (24, 30, 0), (20, 34, 0))
    tr("UpperArm.R", (0, 0, 40), (-50, 0, 16), (-44, 0, 14), (-120, 0, 30), (-124, 0, 34))
    tr("ForeArm.R", (-60, 55, 0), (-40, 55, 0), (-46, 55, 0), (-20, 30, 0), (-12, 30, 0))
    tr("Weapon", (-30, 0, 0), (-80, 0, 0), (-84, 0, 0), (-20, 0, 0), (-10, 0, 0))
    tr("UpperArm.L", (-10, -20, -40), (-30, -30, -20), (-20, -30, -16), (-100, -10, -30), (-104, -10, -34))
    tr("ForeArm.L", (-50, 0, 0), (-60, 0, 0), (-50, 0, 0), (-40, 0, 0), (-34, 0, 0))
    tr("Thigh.L", (-6, 0, -7), (-80, 0, -8), (-82, 0, -8), (-14, 0, -10), (-8, 0, -12))
    tr("Shin.L", (20, 0, 0), (86, 0, 0), (88, 0, 0), (20, 0, 0), (10, 0, 0))
    tr("Foot.L", (10, 0, 0), (6, 0, 0), (6, 0, 0), (40, 0, 0), (40, 0, 0))
    tr("Thigh.R", (-20, 0, 10), (-2, 0, 10), (-4, 0, 10), (-4, 0, 14), (0, 0, 16))
    tr("Shin.R", (30, 0, 0), (96, 0, 0), (98, 0, 0), (24, 0, 0), (8, 0, 0))
    tr("Foot.R", (10, 0, 0), (60, 0, 0), (60, 0, 0), (50, 0, 0), (50, 0, 0))
    tr("TabardF", (-24, 0, 0), (-50, 0, 0), (-46, 0, 0), (-14, 0, 0), (-8, 0, 0))
    tr("TabardB", (-10, 0, 0), (20, 0, 0), (24, 0, 0), (-8, 0, 6), (-4, 0, 8))
    tr("Plume", (24, 0, 0), (-10, 0, 0), (-40, 0, 0), (-60, 0, 10), (-70, 0, 14))
    # Валится лицом вперёд: Root наклоняется, таз идёт к земле
    lean = track(t, [(0, 0), (K[1], -5), (K[2], 4), (K[3], 8), (K[4], 84), (K[4] + 0.06, 80), (1, 84)])
    p.set("Root", lean, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.1), (K[2], 0.06), (K[3], 0.04), (K[4], -0.3), (1, -0.3)]),
           z=track(t, [(0, 0), (K[3], 0), (K[4], 0.14), (1, 0.14)]))
    p.move("Hips", z=track(t, [(0, -0.035), (K[1], -0.02), (K[2], -0.4), (K[3], -0.42), (K[4], -0.1), (1, -0.1)]))
    twitch = pulse(t, 0.93, 0.04)
    p.add("ForeArm.R", x=-10 * twitch)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 100, idle, cyclic=True)
    k.bake(rig, "Walk", 24, walk, cyclic=True)
    k.bake(rig, "Attack", 26, attack)
    k.bake(rig, "Block", 20, block)
    k.bake(rig, "Hit", 15, hit)
    k.bake(rig, "Death", 45, death)


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
    glb = args[0] if args else os.path.join(here, "..", "knight.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "knight.blend")
    build(glb, blend)
