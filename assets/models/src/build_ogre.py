# Огр — босс акта 1, тварь Раскола (~2.4 м). Грузный, сутулый, растёт вверх, а не вширь.
# Серо-зелёная каменистая кожа с тёмными пятнами, бирюзовые трещины по всему телу — самые яркие среди тварей.
# Оружие — обломок каменной колонны в правой руке. На запястьях ржавые кандалы, с левого свисает цепь.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Анимации: Idle, Walk, Attack (Размах колонной), Attack2 (Хлёст цепью), Attack3 (Круговой удар), Hit, Death.
# Запуск: python3 build_ogre.py out/ogre.glb out/ogre.blend (нужен модуль bpy)
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "Ogre"
SIDES = (("R", -1), ("L", 1))
CHAIN = 4   # звеньев-костей у цепи


# ---------- Модель ----------

def build_mesh():
    skin = k.mat("Ogre_Skin", (0.47, 0.55, 0.50), rough=0.85)          # серо-зелёный камень
    dark = k.mat("Ogre_Dark", (0.32, 0.38, 0.34), rough=0.9)
    patch = k.mat("Ogre_Patch", (0.36, 0.32, 0.26), rough=0.95)        # бурые пятна
    cloth = k.mat("Ogre_Loin", (0.33, 0.25, 0.18), rough=0.95)
    stone = k.mat("Ogre_Column", (0.56, 0.53, 0.45), rough=0.9)         # колонна
    stone_d = k.mat("Ogre_ColumnDark", (0.40, 0.38, 0.32), rough=0.9)
    iron = k.mat("Ogre_Iron", (0.36, 0.28, 0.23), metallic=0.5, rough=0.7)
    tusk = k.mat("Ogre_Tusk", (0.70, 0.68, 0.58), rough=0.6)
    rift = k.mat("Ogre_Rift", (0.30, 0.95, 0.85), rough=0.4, emit=1.8)

    # Таз и живот
    k.barrel("Pelvis", 0.30, 0.34, 0.86, 1.08, skin, "Hips", segs=8, sy=0.8)
    k.sphere("Belly", 0.36, (0, -0.06, 1.18), skin, "Spine", scale=(1.0, 0.85, 0.9), segs=9, rings=5)
    # Грудь и горб: широкий верх, плечи-валуны
    k.sphere("Chest", 0.42, (0, 0.0, 1.55), skin, "Chest", scale=(1.0, 0.78, 0.82), segs=10, rings=6)
    k.sphere("Hump", 0.3, (0, 0.16, 1.78), dark, "Chest", scale=(1.25, 0.9, 0.7), segs=8, rings=4)
    for side, s in SIDES:
        k.sphere(f"Pec.{side}", 0.2, (0.17 * s, -0.24, 1.58), skin, "Chest", scale=(1.0, 0.6, 0.8), segs=7, rings=4)
        k.sphere(f"Shoulder.{side}", 0.22, (0.4 * s, 0.02, 1.8), skin, "Chest", scale=(1.0, 1.0, 0.9), segs=8, rings=5)
    # Бурые пятна на коже
    for i, (x, y, z, r, bone) in enumerate([(0.24, -0.3, 1.66, 0.07, "Chest"), (-0.3, -0.18, 1.4, 0.06, "Chest"),
                                           (0.15, 0.32, 1.7, 0.08, "Chest"), (-0.12, -0.36, 1.16, 0.06, "Spine"),
                                           (-0.42, 0.0, 1.92, 0.06, "Chest")]):
        k.sphere(f"Patch{i}", r, (x, y, z), patch, bone, scale=(1.2, 0.5, 1.0), segs=5, rings=3)
    # Голова маленькая, утоплена между плечами; тяжёлая надбровная дуга, клыки
    k.sphere("Head", 0.17, (0, -0.2, 1.96), skin, "Head", scale=(1.0, 1.05, 1.0), segs=8, rings=5)
    k.box("Brow", (0.3, 0.09, 0.07), (0, -0.34, 2.02), dark, "Head", rot=(-14, 0, 0))
    k.sphere("Nose", 0.05, (0, -0.37, 1.95), dark, "Head", scale=(1.1, 0.8, 0.8), segs=5, rings=3)
    for side, s in SIDES:
        k.box(f"Eye.{side}", (0.06, 0.025, 0.028), (0.075 * s, -0.355, 1.985), rift, "Head")
        k.sphere(f"Ear.{side}", 0.05, (0.17 * s, -0.17, 1.97), dark, "Head", scale=(0.5, 1.0, 1.3), segs=5, rings=3)
    k.box("Jaw", (0.27, 0.16, 0.1), (0, -0.3, 1.86), skin, "Jaw")
    for side, s in SIDES:
        k.limb(f"Tusk.{side}", (0.08 * s, -0.37, 1.88), (0.1 * s, -0.4, 1.98), 0.025, 0.006, tusk, "Jaw", segs=4)

    # Трещины Раскола — по груди, животу, плечам, спине (самые яркие)
    cracks = [
        ([(0, 0), (0.07, 0.1), (0.03, 0.18), (0.1, 0.28)], (0.12, -0.33, 1.42), (0, 0, 1), (1, 0, 0), "Chest"),
        ([(0, 0), (-0.06, 0.08), (-0.02, 0.16)], (-0.18, -0.32, 1.5), (1, 0, 0), (0, 0, 1), "Chest"),
        ([(0, 0), (0.08, 0.05), (0.13, -0.03), (0.2, 0.04)], (-0.12, -0.3, 1.14), (1, 0, 0), (0, 0, 1), "Spine"),
        ([(0, 0), (0.06, 0.07), (0.12, 0.02)], (-0.48, -0.12, 1.78), (0, -1, 0), (0, 0, 1), "Chest"),
        ([(0, 0), (0.05, 0.09), (0.11, 0.06), (0.15, 0.14)], (0.44, -0.12, 1.72), (0, -1, 0), (0, 0, 1), "Chest"),
        ([(0, 0), (0.1, 0.04), (0.16, -0.04), (0.26, 0.02)], (-0.12, 0.38, 1.62), (1, 0, 0), (0, 0, 1), "Chest"),
        ([(0, 0), (0.04, 0.06), (0.1, 0.05)], (0.04, -0.34, 2.06), (1, 0, 0), (0, 0, 1), "Head"),
    ]
    for i, (pts, o, u, v, bone) in enumerate(cracks):
        k.crack(f"Crack{i}", pts, o, u, v, rift, bone, width=0.022, depth=0.03)

    # Набедренная повязка
    k.plate("LoinF", [(-0.2, 0), (0.2, 0), (0.15, -0.36), (0.04, -0.3), (-0.05, -0.4), (-0.18, -0.32)], 0.03,
            (0, -0.27, 1.02), (1, 0, 0), (0, -0.2, 1), cloth, "LoinF")
    k.plate("LoinB", [(-0.22, 0), (0.22, 0), (0.2, -0.32), (-0.04, -0.38), (-0.2, -0.3)], 0.03,
            (0, 0.27, 1.02), (1, 0, 0), (0, 0.2, 1), cloth, "LoinB")
    k.barrel("Belt", 0.33, 0.33, 1.02, 1.08, cloth, "Hips", segs=8, sy=0.82)

    # Руки — длинные, толстые, кулаки ниже колен
    for side, s in SIDES:
        k.limb(f"UpperArm.{side}", (0.44 * s, 0.02, 1.78), (0.52 * s, 0.02, 1.36), 0.14, 0.12, skin, f"UpperArm.{side}", segs=7)
        k.sphere(f"Elbow.{side}", 0.11, (0.52 * s, 0.02, 1.36), dark, f"ForeArm.{side}", segs=6, rings=4)
        k.limb(f"ForeArm.{side}", (0.52 * s, 0.02, 1.36), (0.54 * s, -0.04, 0.96), 0.13, 0.1, skin, f"ForeArm.{side}", segs=7)
        k.barrel(f"Shackle.{side}", 0.125, 0.125, 0.98, 1.08, iron, f"ForeArm.{side}", segs=8, loc=(0.54 * s, -0.035))
        k.sphere(f"Fist.{side}", 0.12, (0.54 * s, -0.06, 0.86), skin, f"Hand.{side}", scale=(0.95, 1.1, 1.0), segs=7, rings=4)
        k.box(f"Knuckles.{side}", (0.17, 0.08, 0.08), (0.54 * s, -0.15, 0.86), dark, f"Hand.{side}")
        # Ноги — короткие толстые столбы
        k.limb(f"Thigh.{side}", (0.2 * s, 0, 0.92), (0.22 * s, -0.02, 0.5), 0.17, 0.14, dark, f"Thigh.{side}", segs=7)
        k.sphere(f"Knee.{side}", 0.12, (0.22 * s, -0.04, 0.5), skin, f"Shin.{side}", segs=6, rings=4)
        k.limb(f"Shin.{side}", (0.22 * s, -0.02, 0.5), (0.22 * s, 0, 0.12), 0.13, 0.12, skin, f"Shin.{side}", segs=7)
        k.box(f"Foot.{side}", (0.2, 0.3, 0.12), (0.22 * s, -0.08, 0.06), dark, f"Foot.{side}")
    # Обрывок цепи на правом кандале (короткий, просто висит)
    for i in range(2):
        k.box(f"RChain{i}", (0.035, 0.05 if i % 2 else 0.015, 0.07), (-0.62, -0.03, 0.94 - i * 0.07), iron, "ForeArm.R")

    # Колонна в правой руке (кость Weapon смотрит вперёд): ствол с каннелюрами, капитель на конце, обломанный край у кулака
    k.limb("ColumnShaft", (-0.54, 0.2, 0.86), (-0.54, -0.82, 0.86), 0.13, 0.12, stone, "Weapon", segs=8)
    for i in range(6):
        a = math.tau * i / 6
        k.box(f"Flute{i}", (0.03, 0.85, 0.03), (-0.54 + 0.12 * math.cos(a), -0.32, 0.86 + 0.12 * math.sin(a)), stone_d, "Weapon")
    k.box("Capital", (0.34, 0.12, 0.34), (-0.54, -0.86, 0.86), stone, "Weapon")
    k.box("CapitalTop", (0.28, 0.07, 0.28), (-0.54, -0.95, 0.86), stone_d, "Weapon")
    for i, (dx, dz, h) in enumerate([(0.06, 0.04, 0.12), (-0.07, -0.02, 0.08), (0.0, -0.08, 0.1)]):
        k.box(f"Broken{i}", (0.09, h, 0.09), (-0.54 + dx, 0.24 + h / 2, 0.86 + dz), stone_d, "Weapon", rot=(10 * i, 0, 15 * i))

    # Длинная цепь с левого кандала (кости Chain1..4 — болтается, хлещет)
    for i in range(CHAIN):
        z = 0.96 - i * 0.2
        for j in range(3):
            zz = z - j * 0.065
            k.box(f"Link{i}_{j}", (0.035, 0.055 if j % 2 else 0.018, 0.075), (0.6, -0.03, zz), iron, f"Chain{i + 1}")
    k.box("ChainHook", (0.06, 0.06, 0.08), (0.6, -0.03, 0.96 - CHAIN * 0.2 + 0.02), iron, f"Chain{CHAIN}")

    return k.join_parts("OgreMesh")


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.2), None),
    "Hips": ((0, 0, 0.92), (0, 0, 1.06), "Root"),
    "Spine": ((0, 0, 1.06), (0, 0, 1.34), "Hips"),
    "Chest": ((0, 0, 1.34), (0, 0, 1.86), "Spine"),
    "Head": ((0, -0.14, 1.86), (0, -0.14, 2.12), "Chest"),
    "Jaw": ((0, -0.2, 1.9), (0, -0.36, 1.86), "Head"),
    "LoinF": ((0, -0.27, 1.02), (0, -0.27, 0.66), "Hips"),
    "LoinB": ((0, 0.27, 1.02), (0, 0.27, 0.66), "Hips"),
    "Weapon": ((-0.54, -0.06, 0.86), (-0.54, -0.4, 0.86), "Hand.R"),
}
for side, s in SIDES:
    BONES.update({
        f"UpperArm.{side}": ((0.44 * s, 0.02, 1.78), (0.52 * s, 0.02, 1.36), "Chest"),
        f"ForeArm.{side}": ((0.52 * s, 0.02, 1.36), (0.54 * s, -0.04, 0.96), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.54 * s, -0.04, 0.96), (0.54 * s, -0.06, 0.78), f"ForeArm.{side}"),
        f"Thigh.{side}": ((0.2 * s, 0, 0.92), (0.22 * s, -0.02, 0.5), "Hips"),
        f"Shin.{side}": ((0.22 * s, -0.02, 0.5), (0.22 * s, 0, 0.12), f"Thigh.{side}"),
        f"Foot.{side}": ((0.22 * s, 0, 0.12), (0.22 * s, -0.2, 0.04), f"Shin.{side}"),
    })
for i in range(CHAIN):
    z = 0.96 - i * 0.2
    BONES[f"Chain{i + 1}"] = ((0.6, -0.03, z), (0.6, -0.03, z - 0.2), "ForeArm.L" if i == 0 else f"Chain{i}")


# ---------- Анимации ----------
# Стойка: широко расставленные ноги, левая впереди, горб вперёд, голова исподлобья,
# колонна заброшена на правое плечо, левая рука с цепью опущена и чуть отведена.
STANCE = {
    "Hips": (4, -8, 0),
    "Spine": (10, -4, 0), "Chest": (12, -6, 0), "Head": (-20, 10, 0),
    "Thigh.L": (-22, 0, -8), "Shin.L": (26, 0, 0), "Foot.L": (-4, 0, 0),
    "Thigh.R": (8, 0, 10), "Shin.R": (20, 0, 0), "Foot.R": (-24, 0, 0),
    "UpperArm.R": (-40, 0, 26), "ForeArm.R": (-96, 30, 0), "Hand.R": (0, 0, 0), "Weapon": (60, 0, 0),
    "UpperArm.L": (-14, 0, -18), "ForeArm.L": (-24, 0, 0),
    "LoinF": (-8, 0, 0), "LoinB": (6, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.05)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def chain(p, swing=0.0, side=0.0, lag=0.6):
    """Цепь: swing — вперёд/назад (минус — вперёд), side — вбок; каждое звено гнётся сильнее (запаздывание)."""
    for i in range(CHAIN):
        f = 1.0 + lag * i
        p.add(f"Chain{i + 1}", x=swing * f, z=side * f)
    return p


def idle(t):
    """Покой (3 сек): тяжело дышит горбом, переваливается с ноги на ногу, крутит головой, похлопывает
    колонной по плечу, цепь раскачивается."""
    p = stance()
    breath = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", x=0.025 * sway, z=-0.015 * (breath * 0.5 + 0.5))
    p.add("Hips", z=3 * sway)
    p.add("Thigh.L", z=-3 * sway)
    p.add("Thigh.R", z=-3 * sway)
    p.add("Spine", x=2 * breath)
    p.add("Chest", x=3 * wave(t, 2, -0.1), z=-2 * sway)
    yaw = track(t, [(0, 0), (0.18, 0), (0.26, -22), (0.5, -22), (0.58, 12), (0.8, 12), (0.9, 0), (1, 0)])
    p.add("Head", y=yaw, x=-2 * breath)
    p.add("Jaw", x=-10 * pulse(t, 0.54, 0.08) - 3 * (breath * 0.5 + 0.5))
    tap = pulse(t, 0.32, 0.07) + pulse(t, 0.42, 0.07)
    p.add("UpperArm.R", x=-6 * tap - 2 * breath)
    p.add("ForeArm.R", x=8 * tap)
    p.add("Weapon", x=-10 * tap)
    p.add("UpperArm.L", x=4 * wave(t, 1, 0.2), z=-3 * sway)
    chain(p, swing=6 * wave(t, 1, 0.1), side=5 * wave(t, 1, -0.05))
    p.add("LoinF", x=3 * wave(t, 1, -0.2))
    p.add("LoinB", x=3 * wave(t, 1, -0.25))
    return p


def walk(t):
    """Тяжёлая поступь (0.9 сек): корпус качается с ноги на ногу, каждая нога топает, цепь волочится."""
    p = Pose(STANCE)
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.1)
    p.move("Hips", z=-0.06 + 0.035 * bounce, x=0.04 * a)
    p.add("Hips", y=-8 + 8 * a, z=6 * a)
    p.set("Thigh.R", -6 - 28 * a, 0, 10)
    p.set("Thigh.L", -6 + 28 * a, 0, -10)
    p.set("Shin.R", 14 + 34 * max(0.0, c) + 6 * a, 0, 0)
    p.set("Shin.L", 14 + 34 * max(0.0, -c) - 6 * a, 0, 0)
    p.set("Foot.R", -8 - 14 * a, 0, 0)
    p.set("Foot.L", -8 + 14 * a, 0, 0)
    p.add("Spine", z=-5 * a)
    p.add("Chest", y=-6 * a, x=3 * bounce)
    p.add("Head", y=8 * a, x=-3 * bounce)
    p.add("UpperArm.R", x=-6 * a)
    p.add("UpperArm.L", x=18 * a)
    p.add("ForeArm.L", x=-10 * a)
    chain(p, swing=-12 * wave(t, 1, -0.12), side=6 * wave(t, 2, -0.2))
    p.add("LoinF", x=-10 * abs(a))
    p.add("LoinB", x=10 * abs(a))
    return p


def _tr(p, t, K, S, bone, *keys):
    p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0)))] + list(zip(K[1:-1], keys)) + [(K[-1], S.get(bone, (0, 0, 0)))]))


def attack(t):
    """Размах колонной (0.9 сек): замах — колонна уходит назад за правое плечо, корпус скручен → горизонтальный
    размах слева направо по трём клеткам перед собой (к 0.4 сек) → пронос → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.25, 0.4, 0.55, 1.0]
    S = STANCE
    tr = lambda bone, *keys: _tr(p, t, K, S, bone, *keys)
    tr("Hips", (4, -26, 0), (8, 18, 0), (10, 34, 0))
    tr("Spine", (4, -24, 0), (14, 20, 0), (16, 30, 0))
    tr("Chest", (6, -22, 0), (14, 18, 0), (14, 24, 0))
    tr("Head", (-16, 30, 0), (-20, -14, 0), (-18, -20, 0))
    tr("UpperArm.R", (-80, 0, 70), (-86, 0, 10), (-70, 0, -18))
    tr("ForeArm.R", (-40, 30, 0), (-10, 30, 0), (-14, 30, 0))
    tr("Weapon", (40, 0, 0), (0, 0, 0), (-6, 0, 0))
    tr("UpperArm.L", (-40, 0, -40), (10, 0, -20), (20, 0, -14))
    tr("ForeArm.L", (-40, 0, 0), (-20, 0, 0), (-16, 0, 0))
    tr("Thigh.L", (-30, 0, -10), (-36, 0, -10), (-34, 0, -10))
    tr("Shin.L", (40, 0, 0), (34, 0, 0), (34, 0, 0))
    tr("Thigh.R", (10, 0, 12), (12, 0, 12), (14, 0, 12))
    tr("Shin.R", (30, 0, 0), (24, 0, 0), (24, 0, 0))
    tr("Jaw", (-14, 0, 0), (-30, 0, 0), (-20, 0, 0))
    tr("LoinF", (-12, 0, 6), (-20, 0, -10), (-16, 0, -12))
    p.move("Hips", z=track(t, [(0, -0.05), (K[1], -0.1), (K[2], -0.12), (K[3], -0.1), (1, -0.05)]))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.06), (K[2], -0.08), (K[3], -0.08), (1, 0)]))
    chain(p, swing=track(t, [(0, 0), (K[1], 14), (K[2], -20), (K[3], -26), (1, 0)]),
          side=track(t, [(0, 0), (K[1], 10), (K[2], -24), (K[3], -30), (1, 0)]))
    return p


def attack2(t):
    """Хлёст цепью (0.9 сек): левая рука отводит цепь назад → бросок вперёд, цепь вытягивается в линию (к 0.4 сек)
    → рывок на себя (притягивание) → возврат."""
    p = stance()
    K = [0.0, 0.24, 0.42, 0.6, 1.0]
    S = STANCE
    tr = lambda bone, *keys: _tr(p, t, K, S, bone, *keys)
    tr("UpperArm.L", (40, 0, -30), (-100, 0, -10), (-40, 0, -14))
    tr("ForeArm.L", (-50, 0, 0), (-4, 0, 0), (-80, 0, 0))
    tr("Spine", (8, 18, 0), (16, -16, 0), (4, 8, 0))
    tr("Chest", (8, 16, 0), (16, -14, 0), (4, 10, 0))
    tr("Head", (-14, -10, 0), (-24, 10, 0), (-18, 0, 0))
    tr("Jaw", (-8, 0, 0), (-32, 0, 0), (-16, 0, 0))
    # Цепь: назад → вытянута вперёд прямо (каждое звено догоняет) → дёрнута к себе
    sw = track(t, [(0, 0), (K[1], 22), (K[2], -4), (K[2] + 0.06, 2), (K[3], 26), (1, 0)])
    for i in range(CHAIN):
        lagged = track(t, [(0, 0), (K[1] + 0.03 * i, 22 + 6 * i), (K[2] + 0.02 * i, -6), (K[3] + 0.03 * i, 30 + 4 * i), (1, 0)])
        p.add(f"Chain{i + 1}", x=lagged if i else sw)
    p.size("Chain1", 1.0, track(t, [(0, 1), (K[2] - 0.05, 1), (K[2], 1.6), (K[3], 1.0), (1, 1)]), 1.0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.05), (K[2], -0.06), (K[3], 0.03), (1, 0)]))
    p.add("Thigh.L", x=track(t, [(0, 0), (K[2], -10), (K[3], 4), (1, 0)]))
    return p


def attack3(t):
    """Круговой удар (1.0 сек): присел, колонна вытянута вбок → полный оборот на месте по всем клеткам вокруг
    (середина оборота к 0.4 сек) → шатается, восстанавливая равновесие."""
    p = Pose({}, {})
    K = [0.0, 0.22, 0.45, 0.62, 1.0]
    S = STANCE
    tr = lambda bone, *keys: _tr(p, t, K, S, bone, *keys)
    tr("Spine", (14, -20, 0), (12, 0, 0), (10, 10, 0))
    tr("Chest", (10, -18, 0), (10, 0, 0), (12, 8, 0))
    tr("Head", (-20, 20, 0), (-24, -10, 0), (-20, -6, 0))
    tr("UpperArm.R", (-50, 0, 80), (-30, 0, 84), (-40, 0, 40))
    tr("ForeArm.R", (-30, 30, 0), (-10, 30, 0), (-60, 30, 0))
    tr("Weapon", (30, 0, 0), (10, 0, 0), (40, 0, 0))
    tr("UpperArm.L", (-20, 0, -70), (-10, 0, -80), (-20, 0, -40))
    tr("ForeArm.L", (-30, 0, 0), (-10, 0, 0), (-30, 0, 0))
    tr("Thigh.L", (-36, 0, -16), (-30, 0, -14), (-26, 0, -10))
    tr("Shin.L", (50, 0, 0), (40, 0, 0), (34, 0, 0))
    tr("Thigh.R", (-10, 0, 16), (-10, 0, 14), (0, 0, 10))
    tr("Shin.R", (44, 0, 0), (40, 0, 0), (26, 0, 0))
    tr("Jaw", (-14, 0, 0), (-34, 0, 0), (-20, 0, 0))
    spin = track(t, [(0, 0), (K[1], 30), (K[3], -330), (K[3] + 0.08, -366), (K[3] + 0.18, -354), (1, -360)])
    p.set("Root", 0, spin, 0)
    p.move("Hips", z=track(t, [(0, -0.05), (K[1], -0.16), (K[3], -0.14), (1, -0.05)]))
    # Цепь и повязка разлетаются от вращения
    fly = track(t, [(0, 0), (K[1], 0.2), (K[2], 1), (K[3], 0.8), (1, 0)])
    chain(p, swing=-10 * fly, side=-40 * fly, lag=0.3)
    p.add("LoinF", x=-30 * fly, z=10 * fly)
    p.add("LoinB", x=30 * fly)
    return p


def hit(t):
    """Получил удар (0.5 сек): корпус отбрасывает, голова мотается позже, цепь хлещет, колонна чуть опускается."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.18, 0.4), (0.32, 1), (0.55, -0.35), (0.78, 0.1), (1, 0)])
    p.move("Root", y=0.1 * snap)
    p.move("Hips", z=-0.04 * snap)
    p.add("Spine", x=-18 * snap, y=10 * snap)
    p.add("Chest", x=-10 * snap)
    p.add("Head", x=-24 * whip, y=-16 * snap, z=8 * whip)
    p.add("Jaw", x=-24 * snap)
    p.add("UpperArm.R", x=16 * snap, z=10 * snap)
    p.add("Weapon", x=-16 * whip)
    p.add("UpperArm.L", x=30 * snap, z=-24 * snap)
    chain(p, swing=30 * whip, side=-14 * whip)
    p.add("Thigh.R", x=-10 * snap)
    p.add("LoinF", x=-20 * whip)
    return p


def death(t):
    """Гибель (1.5 сек): качнулся, колонна выпала из руки, рухнул на колени, затем лицом вперёд; судорога."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.45, 0.72, 1.0]
    S = STANCE

    def tr(bone, a, b, c, d):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], a), (K[2], b), (K[3], c), (K[4], d)]))

    tr("Spine", (-16, 10, 0), (20, 0, 0), (30, 0, 0), (26, 0, 0))
    tr("Chest", (-10, 6, 0), (16, 0, 0), (20, 0, 0), (18, 0, 0))
    tr("Head", (-30, -20, 0), (10, 10, 0), (-30, 30, 0), (-24, 36, 0))
    tr("Jaw", (-30, 0, 0), (-14, 0, 0), (-26, 0, 0), (-20, 0, 0))
    tr("UpperArm.R", (-10, 0, 40), (10, 0, 20), (-150, 0, 30), (-160, 0, 34))
    tr("ForeArm.R", (-50, 30, 0), (-20, 20, 0), (-20, 0, 0), (-10, 0, 0))
    tr("Weapon", (40, 0, 0), (-40, 0, 30), (-60, 0, 50), (-60, 0, 50))
    tr("UpperArm.L", (-10, 0, -40), (16, 0, -20), (-140, 0, -30), (-150, 0, -34))
    tr("ForeArm.L", (-40, 0, 0), (-30, 0, 0), (-20, 0, 0), (-10, 0, 0))
    tr("Thigh.L", (-10, 0, -8), (-80, 0, -10), (-30, 0, -10), (-20, 0, -10))
    tr("Shin.L", (20, 0, 0), (110, 0, 0), (40, 0, 0), (20, 0, 0))
    tr("Thigh.R", (-20, 0, 10), (-80, 0, 12), (-30, 0, 12), (-20, 0, 12))
    tr("Shin.R", (24, 0, 0), (110, 0, 0), (40, 0, 0), (20, 0, 0))
    tr("Foot.L", (0, 0, 0), (40, 0, 0), (40, 0, 0), (40, 0, 0))
    tr("Foot.R", (0, 0, 0), (40, 0, 0), (40, 0, 0), (40, 0, 0))
    tr("LoinF", (-20, 0, 0), (-40, 0, 0), (-10, 0, 0), (-10, 0, 0))
    tr("LoinB", (10, 0, 0), (40, 0, 0), (50, 0, 0), (50, 0, 0))
    fall = track(t, [(0, 0), (K[1], -6), (K[2], 8), (K[3], 84), (K[3] + 0.06, 78), (K[3] + 0.12, 86), (1, 86)])
    p.set("Root", fall, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.06), (K[2], -0.05), (K[3], -0.2), (1, -0.2)]),
           z=track(t, [(0, 0), (K[2], 0), (K[3], 0.3), (1, 0.3)]))
    p.move("Hips", z=track(t, [(0, -0.05), (K[1], -0.02), (K[2], -0.5), (K[3], -0.12), (1, -0.12)]))
    spasm = pulse(t, 0.88, 0.05)
    p.add("ForeArm.L", x=-26 * spasm)
    chain(p, swing=track(t, [(0, 0), (K[1], 20), (K[2], -30), (K[3], 40), (1, 30)]) + 20 * spasm)
    return p


def build_actions(rig):
    scaled = ("Chain1",)
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=scaled)
    k.bake(rig, "Walk", 27, walk, cyclic=True, scale_bones=scaled)
    k.bake(rig, "Attack", 27, attack, scale_bones=scaled)
    k.bake(rig, "Attack2", 27, attack2, scale_bones=scaled)
    k.bake(rig, "Attack3", 30, attack3, scale_bones=scaled)
    k.bake(rig, "Hit", 15, hit, scale_bones=scaled)
    k.bake(rig, "Death", 45, death, scale_bones=scaled)


# ---------- Сборка и экспорт ----------

def build(glb_path, blend_path=None):
    k.start_scene(NAME)
    body = build_mesh()
    rig = k.build_armature(NAME, BONES)
    body.parent = rig
    build_actions(rig)
    k.export(rig, body, glb_path, blend_path)
    print("%s: треугольников %d" % (NAME, sum(len(p.vertices) - 2 for p in body.data.polygons)))
    return rig, body


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    glb = args[0] if args else os.path.join(here, "..", "ogre.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "ogre.blend")
    build(glb, blend)
