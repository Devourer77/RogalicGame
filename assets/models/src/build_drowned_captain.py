# Утопший капитан — босс акта 1 (~2.0 м в игре: модель собрана в росте рыцаря, size = 1.2 в .tres).
# Бывший капитан Стражи, товарищ рыцаря: утонул в топи и встал. Тяжёлые латы Стражи почернели и покрылись
# бурой ржавчиной и тиной, с наплечников и шлема свисают пряди водорослей, сквозь прорезь шлема и трещину
# на кирасе светится бирюза Раскола. Табард выцвел до серо-оливкового (без жёлтого — он занят на поле).
# Большой ржавый щит с треснувшим колоколом, алебарда выше роста. Стоит в лужице тёмной воды, с него каплет.
# Облик — claude/мир.md, «Будущие враги»; референс Gemini — 14 ноября. Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (Удар щитом), Attack2 (Алебарда — рубящий сверху), Attack3 (Колокол —
# бьёт древком в щит-колокол и в землю), Hit, Death. Основа скелета и движений — рыцарь (build_knight.py).
# Запуск: python3 build_drowned_captain.py out.glb out.blend (рядом char_kit.py)
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "DrownedCaptain"


# ---------- Модель ----------

def build_mesh():
    steel = k.mat("Cap_Steel", (0.27, 0.28, 0.29), metallic=0.6, rough=0.55)       # почерневшая сталь
    dark = k.mat("Cap_DarkSteel", (0.17, 0.18, 0.19), metallic=0.6, rough=0.6)
    rust = k.mat("Cap_Rust", (0.39, 0.26, 0.16), metallic=0.2, rough=0.9)          # бурая ржавчина
    rust_d = k.mat("Cap_RustDark", (0.32, 0.2, 0.12), metallic=0.2, rough=0.95)
    slime = k.mat("Cap_Slime", (0.22, 0.29, 0.15), rough=0.45)                       # тина, мокрая
    weed = k.mat("Cap_Weed", (0.33, 0.42, 0.22), rough=0.6)
    cloth = k.mat("Cap_Tabard", (0.44, 0.46, 0.35), rough=0.95)                       # выцветший табард
    cloth_d = k.mat("Cap_TabardDark", (0.33, 0.35, 0.26), rough=0.95)
    leather = k.mat("Cap_Leather", (0.24, 0.17, 0.11), rough=0.85)
    wood = k.mat("Cap_Wood", (0.28, 0.21, 0.15), rough=0.9)
    bronze = k.mat("Cap_Bell", (0.56, 0.47, 0.3), metallic=0.5, rough=0.5)          # потемневший колокол
    water = k.mat("Cap_Water", (0.1, 0.15, 0.15), metallic=0.15, rough=0.08)
    rift = k.mat("Cap_Rift", (0.3, 0.95, 0.82), rough=0.3, emit=1.6)

    for side, s in (("R", -1), ("L", 1)):
        x = 0.12 * s
        k.box(f"Sabaton.{side}", (0.14, 0.21, 0.09), (x, -0.03, 0.045), dark, f"Foot.{side}")
        k.limb(f"Toe.{side}", (x, -0.12, 0.04), (x, -0.2, 0.025), 0.065, 0.02, steel, f"Foot.{side}", segs=4)
        k.limb(f"Greave.{side}", (x, 0, 0.09), (x, 0, 0.46), 0.078, 0.095, steel, f"Shin.{side}")
        k.sphere(f"GreaveRust.{side}", 0.05, (x + 0.05 * s, -0.06, 0.3), rust, f"Shin.{side}", scale=(0.6, 0.6, 1.4), segs=5, rings=3)
        k.sphere(f"Knee.{side}", 0.08, (x, -0.035, 0.47), steel, f"Shin.{side}", scale=(1, 0.9, 1), segs=6, rings=4)
        k.plate(f"KneeFin.{side}", [(0, -0.05), (0.07, 0.0), (0, 0.06)], 0.02, (x + 0.075 * s, -0.03, 0.47),
                (s, 0, 0), (0, 0, 1), rust, f"Shin.{side}")
        k.limb(f"Thigh.{side}", (x, 0, 0.47), (x, 0, 0.84), 0.09, 0.11, dark, f"Thigh.{side}")
        k.plate(f"Tasset.{side}", [(-0.08, 0), (0.08, 0), (0.065, -0.22), (0.0, -0.26), (-0.065, -0.22)], 0.025,
                (x + 0.04 * s, -0.115, 0.86), (1, 0, 0), (0, -0.12, 1), steel, f"Thigh.{side}")

        ax = 0.29 * s
        k.sphere(f"Pauldron.{side}", 0.15, (ax, 0, 1.28), steel, f"UpperArm.{side}", scale=(1.15, 1.15, 0.85), segs=8, rings=4)
        k.sphere(f"PauldronRim.{side}", 0.16, (ax + 0.01 * s, 0, 1.23), rust, f"UpperArm.{side}",
                 scale=(1.15, 1.15, 0.22), segs=8, rings=3)
        k.sphere(f"PauldronSlime.{side}", 0.12, (ax, 0.02, 1.36), slime, f"UpperArm.{side}", scale=(1.1, 1.1, 0.35), segs=7, rings=3)
        for i, (dx, dy, ln) in enumerate([(0.09, -0.06, 0.2), (0.13, 0.04, 0.26), (0.05, 0.1, 0.16)]):
            top = (ax + dx * s, dy, 1.27)
            k.limb(f"Weed.{side}{i}", top, (ax + (dx + 0.02) * s, dy - 0.01, 1.27 - ln), 0.022, 0.006, weed, f"UpperArm.{side}", segs=4)
        k.limb(f"UpperArm.{side}", (ax, 0, 1.24), (0.3 * s, 0, 1.0), 0.07, 0.068, dark, f"UpperArm.{side}")
        k.sphere(f"Elbow.{side}", 0.074, (0.3 * s, 0.012, 1.0), steel, f"ForeArm.{side}", segs=6, rings=4)
        k.limb(f"Vambrace.{side}", (0.3 * s, 0, 1.0), (0.3 * s, -0.02, 0.79), 0.07, 0.082, steel, f"ForeArm.{side}")
        k.sphere(f"VambraceRust.{side}", 0.045, (0.3 * s + 0.06 * s, -0.03, 0.88), rust, f"ForeArm.{side}", scale=(0.5, 0.8, 1.2), segs=5, rings=3)
        hx = 0.3 * s
        k.sphere(f"Fist.{side}", 0.066, (hx, -0.03, 0.73), dark, f"Hand.{side}", scale=(0.85, 1.05, 1.0), segs=6, rings=4)
        k.box(f"Fingers.{side}", (0.1, 0.045, 0.098), (hx, -0.078, 0.725), steel, f"Hand.{side}")
        k.box(f"Thumb.{side}", (0.038, 0.078, 0.038), (hx - 0.033 * s, -0.057, 0.78), dark, f"Hand.{side}", rot=(15, 0, 0))

    # Таз, пояс, полы выцветшего табарда — рваные и длиннее, чем у рыцаря
    k.barrel("Pelvis", 0.18, 0.19, 0.78, 0.9, dark, "Hips", sy=0.8)
    k.barrel("Belt", 0.2, 0.2, 0.85, 0.91, leather, "Hips", sy=0.82)
    k.box("Buckle", (0.07, 0.025, 0.055), (0, -0.166, 0.88), rust, "Hips")
    front = [(-0.14, 0.0), (0.14, 0.0), (0.13, -0.34), (0.08, -0.46), (0.04, -0.36), (-0.01, -0.5), (-0.06, -0.38),
             (-0.12, -0.44)]
    k.plate("TabardFront", front, 0.022, (0, -0.175, 0.87), (1, 0, 0), (0, 0, 1), cloth, "TabardF")
    k.plate("TabardBack", front, 0.022, (0, 0.175, 0.87), (-1, 0, 0), (0, 0, 1), cloth_d, "TabardB")

    # Кираса: почерневшая, ржавые пятна, тина, бирюзовая трещина Раскола на груди
    k.barrel("Torso", 0.2, 0.255, 0.88, 1.18, steel, "Spine", sy=0.76)
    k.barrel("Chest", 0.255, 0.215, 1.18, 1.34, steel, "Chest", sy=0.76)
    k.box("ChestRidge", (0.03, 0.03, 0.3), (0, -0.19, 1.04), dark, "Spine", rot=(-8, 0, 0))
    for i, (x, z, r) in enumerate([(0.12, 1.0, 0.06), (-0.1, 1.12, 0.05), (0.06, 1.22, 0.045)]):
        k.sphere(f"ChestRust{i}", r, (x, -0.18, z), rust, "Spine" if z < 1.18 else "Chest", scale=(1.2, 0.35, 1.0), segs=6, rings=3)
    k.sphere("ChestSlime", 0.16, (0.0, -0.06, 1.3), slime, "Chest", scale=(1.5, 1.1, 0.4), segs=8, rings=3)
    k.crack("ChestCrack", [(-0.07, 0.07), (-0.02, 0.03), (0.0, -0.03), (0.05, -0.06), (0.09, -0.04)],
            (0.0, -0.2, 1.12), (1, 0, 0), (0, 0, 1), rift, "Spine", width=0.016, depth=0.03)
    k.crack("ChestCrack2", [(0.0, 0.03), (-0.04, 0.0), (-0.05, -0.05)], (-0.01, -0.2, 1.1), (1, 0, 0), (0, 0, 1),
            rift, "Spine", width=0.012, depth=0.03)
    k.barrel("Gorget", 0.13, 0.1, 1.3, 1.38, dark, "Chest")

    # Шлем-ведро: плоский верх, узкая прорезь светится бирюзой, ржавчина и пряди тины
    k.barrel("Helm", 0.145, 0.14, 1.36, 1.62, steel, "Head", segs=10)
    k.barrel("HelmTop", 0.14, 0.12, 1.62, 1.66, dark, "Head", segs=10)
    k.box("Visor", (0.2, 0.03, 0.026), (0, -0.136, 1.52), rift, "Head")
    k.box("VisorBar", (0.03, 0.04, 0.17), (0, -0.14, 1.48), dark, "Head")
    for s in (-1, 1):
        for i in range(2):
            k.box(f"Breath{s}{i}", (0.012, 0.03, 0.05), (0.05 * s + 0.03 * i * s, -0.134, 1.43), dark, "Head")
    k.sphere("HelmRust", 0.06, (0.09, -0.11, 1.58), rust, "Head", scale=(1.0, 0.4, 0.8), segs=6, rings=3)
    k.sphere("HelmSlime", 0.12, (-0.02, 0.03, 1.66), slime, "Head", scale=(1.2, 1.2, 0.3), segs=7, rings=3)
    for i, (x, y, ln) in enumerate([(-0.12, 0.06, 0.24), (0.1, 0.1, 0.2), (-0.05, 0.14, 0.3)]):
        k.limb(f"HelmWeed{i}", (x, y, 1.65), (x * 1.15, y + 0.03, 1.65 - ln), 0.02, 0.005, weed, "Head", segs=4)

    # Алебарда (кость Halberd, древко вверх через кулак): древко выше роста, топор, остриё и крюк
    wx, wy, wz = -0.3, -0.06, 0.73
    k.limb("Shaft", (wx, wy, wz - 0.75), (wx, wy, wz + 1.2), 0.022, 0.02, wood, "Halberd", segs=6)
    k.limb("ButtCap", (wx, wy, wz - 0.82), (wx, wy, wz - 0.72), 0.012, 0.028, dark, "Halberd", segs=5)
    k.limb("Spike", (wx, wy, wz + 1.18), (wx, wy, wz + 1.45), 0.03, 0.0, dark, "Halberd", segs=4)
    axe = [(0.0, 0.0), (0.0, 0.3), (0.1, 0.32), (0.26, 0.38), (0.24, 0.16), (0.27, -0.04), (0.1, 0.04)]
    k.plate("AxeHead", axe, 0.025, (wx, wy - 0.02, wz + 0.95), (0, -1, 0), (0, 0, 1), steel, "Halberd")
    k.plate("AxeRust", [(0.12, 0.08), (0.24, 0.14), (0.22, 0.3), (0.13, 0.26)], 0.03, (wx, wy - 0.02, wz + 0.95),
            (0, -1, 0), (0, 0, 1), rust, "Halberd")
    k.plate("Hook", [(0.0, 0.0), (0.0, 0.08), (0.16, 0.02), (0.06, -0.01)], 0.022, (wx, wy + 0.02, wz + 1.03),
            (0, 1, 0), (0, 0, 1), dark, "Halberd")
    k.box("Socket", (0.05, 0.05, 0.12), (wx, wy, wz + 1.1), dark, "Halberd")

    # Большой ржавый щит (кость Shield) с треснувшим колоколом Стражи
    sx = 0.39
    tower = [(-0.26, 0.42), (0.26, 0.42), (0.26, -0.22), (0.0, -0.5), (-0.26, -0.22)]
    rim = [(a * 1.08, b * 1.05 + 0.006) for a, b in tower]
    k.plate("ShieldRim", rim, 0.03, (sx, -0.04, 0.94), (0, 1, 0), (0, 0, 1), rust_d, "Shield")
    k.plate("ShieldFace", tower, 0.045, (sx + 0.012, -0.04, 0.94), (0, 1, 0), (0, 0, 1), rust, "Shield")
    k.plate("ShieldSteel", [(-0.18, 0.34), (0.2, 0.36), (0.18, 0.0), (-0.12, -0.08)], 0.05, (sx + 0.014, -0.04, 0.94),
            (0, 1, 0), (0, 0, 1), steel, "Shield")
    bell = [(-0.075, 0.19), (0.075, 0.19), (0.11, -0.04), (0.19, -0.13), (-0.19, -0.13), (-0.11, -0.04)]
    k.plate("ShieldBell", bell, 0.03, (sx + 0.04, -0.04, 1.0), (0, 1, 0), (0, 0, 1), bronze, "Shield")
    k.box("ShieldClapper", (0.025, 0.06, 0.06), (sx + 0.045, -0.04, 0.86), bronze, "Shield")
    k.crack("BellCrack", [(0.02, 0.13), (-0.01, 0.06), (0.03, 0.0), (0.0, -0.08)], (sx + 0.058, -0.04, 1.0),
            (0, 1, 0), (0, 0, 1), dark, "Shield", width=0.012, depth=0.012)

    # Лужица тёмной воды под ногами и капли
    k.barrel("Pool", 0.42, 0.38, 0.0, 0.012, water, "Root", segs=12)
    for i, (x, y, z) in enumerate([(-0.33, -0.08, 0.62), (0.18, -0.2, 0.55), (0.42, 0.06, 0.4)]):
        k.sphere(f"Drip{i}", 0.016, (x, y, z), water, "Root", scale=(1, 1, 1.6), segs=5, rings=3)
    return k.join_parts("DrownedCaptainMesh")


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
    "Halberd": ((-0.3, -0.06, 0.73), (-0.3, -0.06, 0.95), "Hand.R"),   # древко вверх через кулак
    "Shield": ((0.33, -0.04, 0.9), (0.33, -0.04, 1.1), "ForeArm.L"),
}
for side, s in (("R", -1), ("L", 1)):
    BONES.update({
        f"UpperArm.{side}": ((0.29 * s, 0, 1.27), (0.3 * s, 0, 1.0), "Chest"),
        f"ForeArm.{side}": ((0.3 * s, 0, 1.0), (0.3 * s, -0.02, 0.78), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.3 * s, -0.02, 0.78), (0.3 * s, -0.03, 0.68), f"ForeArm.{side}"),
        f"Thigh.{side}": ((0.12 * s, 0, 0.86), (0.12 * s, 0, 0.47), "Hips"),
        f"Shin.{side}": ((0.12 * s, 0, 0.47), (0.12 * s, 0, 0.09), f"Thigh.{side}"),
        f"Foot.{side}": ((0.12 * s, 0, 0.09), (0.12 * s, -0.14, 0.02), f"Shin.{side}"),
    })


# ---------- Анимации ----------

# Стойка Стражи: левая нога и щит впереди, меч поднят у правого плеча остриём вверх-вперёд,
# корпус развёрнут левым плечом к врагу, голова смотрит прямо.
STANCE = {
    "Spine": (5, -14, 0), "Chest": (4, -10, 0), "Head": (-6, 22, 0),
    "Thigh.L": (-24, 0, -7), "Shin.L": (28, 0, 0), "Foot.L": (4, 0, 0),
    "Thigh.R": (4, 0, 10), "Shin.R": (18, 0, 0), "Foot.R": (22, 0, 0),
    "UpperArm.R": (-12, 0, 30), "ForeArm.R": (-96, 55, 0), "Halberd": (110, 0, 0),
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
    p.add("Halberd", x=4 * wave(t, 1, 0.2), z=4 * wave(t, 1, 0.45))
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
    p.add("Halberd", x=6 * wave(t, 2, 0.25))
    p.add("UpperArm.L", x=-8 * a)
    p.add("Shield", x=3 * bounce)
    p.set("TabardF", -8 - 16 * abs(a), 0, 0)
    p.set("TabardB", 14 + 8 * wave(t, 2, -0.12), 0, 0)
    p.set("Plume", -8 * wave(t, 2, -0.15), 0, 6 * a)
    return p


def shield_bash(t):
    """Удар щитом (0.87 сек): отводит щит и корпус назад → рывок вперёд всем телом, щит впечатывается
    в цель (к 0.4 сек, толчок 2) → держит → возвращается. Алебарда остаётся стоймя."""
    p = Pose({}, {})
    K = [0.0, 0.22, 0.4, 0.55, 1.0]   # стойка, замах, удар, держит, стойка
    S = STANCE

    def tr(bone, wind, hit_, hold):
        base = S.get(bone, (0, 0, 0))
        p.set(bone, *track3(t, [(K[0], base), (K[1], wind), (K[2], hit_), (K[3], hold), (K[4], base)]))

    tr("Spine", (-6, -30, 0), (14, 10, 0), (12, 6, 0))
    tr("Chest", (-4, -14, 0), (10, 8, 0), (8, 6, 0))
    tr("Head", (-4, 30, 0), (-12, 0, 0), (-10, 4, 0))
    tr("UpperArm.L", (-20, -30, -6), (-78, -20, -22), (-74, -20, -20))
    tr("ForeArm.L", (-80, 0, 0), (-24, 0, 0), (-30, 0, 0))
    tr("Shield", (0, 0, 0), (-12, 0, 0), (-8, 0, 0))
    tr("UpperArm.R", (-4, 0, 34), (-20, 0, 26), (-16, 0, 28))
    tr("ForeArm.R", (-90, 55, 0), (-100, 55, 0), (-98, 55, 0))
    tr("Halberd", (100, 0, 20), (110, 0, 20), (108, 0, 20))
    tr("Thigh.L", (-14, 0, -7), (-48, 0, -7), (-46, 0, -7))
    tr("Shin.L", (24, 0, 0), (50, 0, 0), (48, 0, 0))
    tr("Thigh.R", (8, 0, 10), (22, 0, 10), (20, 0, 10))
    tr("Shin.R", (24, 0, 0), (14, 0, 0), (16, 0, 0))
    tr("Foot.R", (20, 0, 0), (36, 0, 0), (34, 0, 0))
    tr("TabardF", (-4, 0, 0), (-36, 0, 0), (-28, 0, 0))
    tr("TabardB", (-4, 0, 0), (28, 0, 0), (18, 0, 0))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.08), (K[2], -0.26), (K[3], -0.24), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.035), (K[1], -0.06), (K[2], -0.1), (K[3], -0.09), (1, -0.035)]))
    return p


def halberd_chop(t):
    """Алебарда (0.9 сек): заносит алебарду высоко над головой → рубит сверху вперёд (к 0.4 сек),
    клинок уходит низко → медленно поднимает обратно."""
    p = Pose({}, {})
    K = [0.0, 0.25, 0.42, 0.6, 1.0]   # стойка, занёс, удар, пронос, стойка
    S = STANCE

    def tr(bone, wind, hit_, follow):
        base = S.get(bone, (0, 0, 0))
        p.set(bone, *track3(t, [(K[0], base), (K[1], wind), (K[2], hit_), (K[3], follow), (K[4], base)]))

    tr("Spine", (-8, -22, 0), (20, 12, 0), (24, 16, 0))
    tr("Chest", (-6, -12, 0), (12, 8, 0), (14, 10, 0))
    tr("Head", (-14, 20, 0), (-18, -6, 0), (-20, -8, 0))
    tr("UpperArm.R", (-150, 0, 24), (-70, 0, 12), (-50, 0, 8))
    tr("ForeArm.R", (-50, 55, 0), (-30, 55, 0), (-26, 55, 0))
    tr("Halberd", (150, 0, 20), (-30, 0, 20), (-50, 0, 20))
    tr("UpperArm.L", (-30, -30, -20), (-20, -20, -30), (-16, -20, -30))
    tr("ForeArm.L", (-60, 0, 0), (-56, 0, 0), (-56, 0, 0))
    tr("Thigh.L", (-20, 0, -7), (-46, 0, -7), (-44, 0, -7))
    tr("Shin.L", (30, 0, 0), (50, 0, 0), (50, 0, 0))
    tr("Thigh.R", (0, 0, 10), (20, 0, 10), (18, 0, 10))
    tr("Shin.R", (24, 0, 0), (16, 0, 0), (16, 0, 0))
    tr("Foot.R", (22, 0, 0), (34, 0, 0), (34, 0, 0))
    tr("TabardF", (-8, 0, 0), (-40, 0, 0), (-30, 0, 0))
    tr("TabardB", (-2, 0, 0), (30, 0, 0), (14, 0, 0))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.05), (K[2], -0.18), (K[3], -0.18), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.035), (K[1], -0.02), (K[2], -0.12), (K[3], -0.11), (1, -0.035)]))
    return p


def bell_toll(t):
    """Колокол из-под воды (1.1 сек): поднимает щит-колокол высоко, вскидывает алебарду и бьёт древком
    в землю у ног (к 0.45 сек) — щит гудит и дрожит; потом снова в стойку."""
    p = stance()
    lift = track(t, [(0, 0), (0.3, 1), (0.42, 1), (0.47, 0.2), (0.8, 0.2), (1, 0)])
    slam = track(t, [(0, 0), (0.42, 0), (0.47, 1), (0.75, 0.6), (1, 0)])
    hum = pulse(t, 0.62, 0.18) * wave(t, 14)
    p.add("UpperArm.R", x=-40 * lift + 10 * slam)
    p.add("ForeArm.R", x=-20 * lift)
    p.add("Halberd", x=46 * lift - 8 * slam)   # древко остаётся стоймя, пока рука поднимается
    p.move("Hips", z=-0.08 * slam)
    p.add("Thigh.L", x=-10 * slam).add("Shin.L", x=16 * slam)
    p.add("Thigh.R", x=-8 * slam).add("Shin.R", x=14 * slam)
    p.add("Spine", x=10 * slam - 6 * lift)
    p.add("Head", x=-14 * lift + 8 * slam)
    p.add("UpperArm.L", x=-30 * lift - 20 * slam, z=-6 * lift)
    p.add("ForeArm.L", x=-10 * lift)
    p.add("Shield", x=6 * hum, z=4 * hum)
    p.add("TabardF", x=-14 * slam).add("TabardB", x=10 * slam)
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
    p.add("UpperArm.R", x=20 * snap, z=20 * snap).add("ForeArm.R", x=30 * snap).add("Halberd", x=-24 * whip)
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
    tr("Halberd", (100, 0, 20), (70, 0, 20), (66, 0, 20), (30, 0, 20), (20, 0, 20))
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
    k.bake(rig, "Attack", 26, shield_bash)
    k.bake(rig, "Attack2", 27, halberd_chop)
    k.bake(rig, "Attack3", 33, bell_toll)
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
    glb = args[0] if args else os.path.join(here, "..", "drowned_captain.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "drowned_captain.blend")
    build(glb, blend)
