# Маг — последний ученик ордена Стихий. Потрёпанный тёмно-синий плащ до земли с глубоким капюшоном,
# лицо в тени, посох выше роста с парящим осколком кристалла. Худой, сутулый, широкие рукава. ~1.6 м.
# Смотрит в -Y (после экспорта в glTF это +Z).
#
# Запуск в Blender: вкладка Scripting → Open → этот файл → Run Script. Рядом должен лежать char_kit.py.
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "Hero"


# ---------- Модель ----------

def build_mesh():
    robe = k.mat("Mage_Robe", (0.24, 0.29, 0.60), rough=0.9)            # тёмно-синий
    robe_d = k.mat("Mage_RobeDark", (0.16, 0.19, 0.42), rough=0.92)
    lining = k.mat("Mage_Lining", (0.36, 0.27, 0.58), rough=0.9)        # фиолетовая подкладка
    trim = k.mat("Mage_Trim", (0.66, 0.72, 0.86), rough=0.6, metallic=0.3)   # выцветшая серебристая кайма
    skin = k.mat("Mage_Skin", (0.82, 0.68, 0.56), rough=0.8)
    shadow = k.mat("Mage_Shadow", (0.04, 0.04, 0.08), rough=1.0)        # лицо в тени капюшона
    wood = k.mat("Mage_Wood", (0.34, 0.25, 0.17), rough=0.9)
    leather = k.mat("Mage_Leather", (0.30, 0.22, 0.15), rough=0.85)
    paper = k.mat("Mage_Paper", (0.80, 0.76, 0.62), rough=0.9)
    glow = k.mat("Mage_Crystal", (0.55, 0.85, 1.0), rough=0.15, emit=1.6)   # осколок кристалла и глаза

    for side, s in (("R", -1), ("L", 1)):
        x = 0.09 * s
        k.box(f"Boot.{side}", (0.1, 0.2, 0.08), (x, -0.03, 0.04), leather, f"Foot.{side}")
        k.limb(f"Shin.{side}", (x, 0, 0.08), (x, 0, 0.4), 0.05, 0.06, robe_d, f"Shin.{side}", segs=5)
        k.limb(f"Thigh.{side}", (x, 0, 0.4), (x, 0, 0.72), 0.065, 0.08, robe_d, f"Thigh.{side}", segs=5)

        # Худые плечи, широкие рукава-раструбы, кисти видны
        ax = 0.2 * s
        k.sphere(f"Shoulder.{side}", 0.085, (ax, 0, 1.17), robe, f"UpperArm.{side}", scale=(1.0, 1.0, 0.8), segs=6, rings=4)
        k.limb(f"UpperArm.{side}", (ax, 0, 1.15), (0.215 * s, 0, 0.93), 0.058, 0.065, robe, f"UpperArm.{side}")
        k.limb(f"Sleeve.{side}", (0.215 * s, 0, 0.93), (0.225 * s, -0.02, 0.74), 0.065, 0.115, robe, f"ForeArm.{side}", segs=7)
        k.limb(f"SleeveIn.{side}", (0.224 * s, -0.018, 0.76), (0.225 * s, -0.02, 0.735), 0.1, 0.105, lining, f"ForeArm.{side}", segs=7)
        k.limb(f"Wrist.{side}", (0.223 * s, -0.015, 0.8), (0.226 * s, -0.025, 0.71), 0.03, 0.028, skin, f"ForeArm.{side}", segs=5)
        hx = 0.226 * s
        k.sphere(f"Palm.{side}", 0.046, (hx, -0.03, 0.675), skin, f"Hand.{side}", scale=(0.85, 1.05, 1.0), segs=6, rings=4)
        if s < 0:   # правая сжимает посох
            k.box("Fingers.R", (0.075, 0.036, 0.07), (hx, -0.068, 0.672), skin, "Hand.R")
            k.box("Thumb.R", (0.03, 0.06, 0.03), (hx + 0.03, -0.05, 0.71), skin, "Hand.R", rot=(15, 0, 0))
        else:       # левая раскрыта — ею он плетёт заклинания
            for i in range(3):
                k.limb(f"Finger.L{i}", (hx - 0.025 + 0.025 * i, -0.045, 0.65), (hx - 0.04 + 0.04 * i, -0.075, 0.58),
                       0.012, 0.006, skin, "Hand.L", segs=4)
            k.limb("Thumb.L", (hx - 0.035, -0.03, 0.68), (hx - 0.08, -0.06, 0.64), 0.013, 0.006, skin, "Hand.L", segs=4)

    # Подол мантии — на своей кости, качается; по низу рваная кайма
    k.barrel("Skirt", 0.30, 0.19, 0.05, 0.76, robe, "Robe", segs=10, sy=0.86)
    k.barrel("SkirtHem", 0.306, 0.298, 0.05, 0.085, trim, "Robe", segs=10, sy=0.87)
    for i, (ang, h) in enumerate(((20, 0.2), (95, 0.14), (160, 0.22), (215, 0.12), (280, 0.2), (335, 0.15))):
        r = math.radians(ang)
        k.plate(f"Tear{i}", [(-0.04, 0), (0.04, 0), (0, h)], 0.02, (math.cos(r) * 0.295, math.sin(r) * 0.25, 0.085),
                (-math.sin(r), math.cos(r), 0), (-math.cos(r) * 0.14, -math.sin(r) * 0.12, 1), robe_d, "Robe")

    # Пояс, сумка с книгой и свитком, палантин ордена спереди (своя кость)
    k.barrel("Belt", 0.2, 0.2, 0.73, 0.79, leather, "Hips", segs=10, sy=0.84)
    k.box("Book", (0.05, 0.13, 0.16), (0.2, 0.0, 0.68), leather, "Hips", rot=(0, -8, 0))
    k.box("Pages", (0.035, 0.11, 0.14), (0.205, -0.012, 0.68), paper, "Hips", rot=(0, -8, 0))
    k.limb("Scroll", (-0.17, 0.08, 0.66), (-0.21, -0.06, 0.7), 0.028, 0.028, paper, "Hips", segs=5)
    stole = [(-0.075, 0.0), (0.075, 0.0), (0.085, -0.42), (0.03, -0.5), (0.0, -0.44), (-0.04, -0.52), (-0.085, -0.42)]
    k.plate("Stole", stole, 0.02, (0, -0.172, 0.76), (1, 0, 0), (0, 0, 1), lining, "Stole")
    k.plate("StoleRune", [(0, -0.12), (0.035, -0.2), (0, -0.28), (-0.035, -0.2)], 0.026, (0, -0.172, 0.76),
            (1, 0, 0), (0, 0, 1), trim, "Stole")

    # Худой торс, узкая грудь
    k.barrel("Torso", 0.185, 0.2, 0.76, 1.02, robe, "Spine", segs=8, sy=0.8)
    k.barrel("Chest", 0.2, 0.17, 1.02, 1.2, robe, "Chest", segs=8, sy=0.8)
    k.barrel("Collar", 0.2, 0.13, 1.14, 1.26, robe_d, "Chest", segs=8, sy=0.9)

    # Плащ на спине: рваный низ, знак ордена Стихий (героя мы видим в основном со спины)
    cloak = [(-0.2, 0.0), (0.2, 0.0), (0.27, -0.7), (0.2, -1.04), (0.11, -0.95), (0.04, -1.1), (-0.07, -0.98),
             (-0.16, -1.08), (-0.27, -0.72)]
    k.plate("Cloak", cloak, 0.025, (0, 0.185, 1.2), (-1, 0, 0), (0, 0.1, 1), robe_d, "Cloak")
    k.plate("SigilTri", [(0, -0.3), (0.075, -0.44), (-0.075, -0.44)], 0.03, (0, 0.2, 1.2), (-1, 0, 0), (0, 0.1, 1), trim, "Cloak")
    k.plate("SigilBar", [(-0.1, -0.5), (0.1, -0.5), (0.1, -0.52), (-0.1, -0.52)], 0.03, (0, 0.2, 1.2), (-1, 0, 0), (0, 0.1, 1), trim, "Cloak")

    # Глубокий капюшон: лицо — тёмный провал, из него светятся глаза; хвост капюшона на своей кости
    k.sphere("Hood", 0.165, (0, 0.01, 1.36), robe, "Head", scale=(1.0, 1.1, 1.08), segs=8, rings=5)
    k.sphere("Face", 0.125, (0, -0.07, 1.345), shadow, "Head", scale=(0.9, 0.9, 1.05), segs=7, rings=4)
    k.plate("HoodBrim", [(-0.15, -0.02), (-0.1, 0.11), (0, 0.17), (0.1, 0.11), (0.15, -0.02), (0.11, 0.06), (0, 0.11), (-0.11, 0.06)],
            0.07, (0, -0.15, 1.37), (1, 0, 0), (0, 0, 1), robe_d, "Head")
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.036, 0.02, 0.016), (0.045 * s, -0.18, 1.35), glow, "Head", rot=(0, 0, -8 * s))
    k.limb("HoodTip", (0, 0.1, 1.47), (0, 0.3, 1.3), 0.085, 0.01, robe_d, "HoodTip", segs=5)

    # Посох выше роста (кость Staff): корявое древко, развилка, в ней парит осколок кристалла (кость Crystal)
    sx, sy_ = -0.226, -0.04
    k.limb("StaffShaft", (sx, sy_, 0.02), (sx, sy_, 1.62), 0.024, 0.03, wood, "Staff", segs=6)
    k.limb("StaffWrap", (sx, sy_, 0.6), (sx, sy_, 0.76), 0.034, 0.034, leather, "Staff", segs=6)
    k.limb("StaffKnot", (sx, sy_, 1.2), (sx + 0.05, sy_, 1.27), 0.03, 0.008, wood, "Staff", segs=4)
    k.limb("Prong1", (sx, sy_, 1.6), (sx - 0.1, sy_, 1.8), 0.028, 0.008, wood, "Staff", segs=5)
    k.limb("Prong2", (sx, sy_, 1.6), (sx + 0.09, sy_, 1.84), 0.028, 0.008, wood, "Staff", segs=5)
    k.limb("Prong3", (sx, sy_, 1.6), (sx, sy_ + 0.07, 1.74), 0.022, 0.006, wood, "Staff", segs=4)
    k.limb("ShardUp", (sx, sy_, 1.78), (sx + 0.01, sy_, 1.96), 0.055, 0.004, glow, "Crystal", segs=5)
    k.limb("ShardDown", (sx, sy_, 1.78), (sx - 0.01, sy_, 1.7), 0.055, 0.004, glow, "Crystal", segs=5)
    k.limb("ShardChip", (sx + 0.09, sy_ + 0.02, 1.9), (sx + 0.1, sy_ + 0.02, 1.97), 0.018, 0.002, glow, "Crystal", segs=4)

    return k.join_parts("HeroMesh")


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.2), None),
    "Hips": ((0, 0, 0.72), (0, 0, 0.82), "Root"),
    "Robe": ((0, 0, 0.76), (0, 0, 0.1), "Hips"),
    "Stole": ((0, -0.172, 0.76), (0, -0.172, 0.3), "Hips"),
    "Spine": ((0, 0, 0.82), (0, 0, 1.02), "Hips"),
    "Chest": ((0, 0, 1.02), (0, 0, 1.2), "Spine"),
    "Head": ((0, 0, 1.2), (0, 0, 1.5), "Chest"),
    "HoodTip": ((0, 0.1, 1.47), (0, 0.3, 1.3), "Head"),
    "Cloak": ((0, 0.185, 1.2), (0, 0.2, 0.2), "Chest"),
    "Staff": ((-0.226, -0.04, 0.68), (-0.226, -0.04, 1.2), "Hand.R"),
    "Crystal": ((-0.226, -0.04, 1.78), (-0.226, -0.04, 1.98), "Staff"),
}
for side, s in (("R", -1), ("L", 1)):
    BONES.update({
        f"UpperArm.{side}": ((0.2 * s, 0, 1.17), (0.215 * s, 0, 0.93), "Chest"),
        f"ForeArm.{side}": ((0.215 * s, 0, 0.93), (0.225 * s, -0.02, 0.74), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.225 * s, -0.02, 0.74), (0.226 * s, -0.03, 0.64), f"ForeArm.{side}"),
        f"Thigh.{side}": ((0.09 * s, 0, 0.72), (0.09 * s, 0, 0.4), "Hips"),
        f"Shin.{side}": ((0.09 * s, 0, 0.4), (0.09 * s, 0, 0.08), f"Thigh.{side}"),
        f"Foot.{side}": ((0.09 * s, 0, 0.08), (0.09 * s, -0.13, 0.02), f"Shin.{side}"),
    })


# ---------- Анимации ----------

class MagePose(Pose):
    def staff_arm(self, upper, fore, lean=0.0, side=0.0, out=12.0):
        """Правая рука с посохом. upper/fore — насколько плечо и локоть вынесены вперёд (градусы).
        Посох сам остаётся вертикальным; lean наклоняет его вперёд, side — вбок."""
        self.set("UpperArm.R", -upper, 0, out)
        self.set("ForeArm.R", -fore, 0, 0)
        self.set("Staff", (upper + fore) + lean, 0, side)
        return self

    def left_arm(self, upper, fore, out=10.0, twist=0.0):
        self.set("UpperArm.L", -upper, twist, -out)
        self.set("ForeArm.L", -fore, 0, 0)
        return self

    def legs(self, l=(0, 0), r=(0, 0)):
        """(бедро вперёд, сгиб колена); стопа выравнивается сама."""
        for side, (thigh, knee), z in (("L", l, -5), ("R", r, 6)):
            self.set(f"Thigh.{side}", -thigh, 0, z)
            self.set(f"Shin.{side}", knee, 0, 0)
            self.set(f"Foot.{side}", knee - thigh, 0, 0)
        return self


def stance():
    """Сутулится, опирается на посох, выставленный вперёд-вправо; левая рука полусогнута ладонью вверх."""
    p = MagePose({}, {})
    p.move("Hips", z=-0.015)
    p.set("Spine", 9, -6, 0).set("Chest", 8, -4, 0).set("Head", -8, 8, 0)
    p.staff_arm(34, 46, lean=8, side=-4)
    p.left_arm(16, 62, out=12, twist=20)
    p.set("Hand.L", -20, 0, 0)
    p.legs(l=(14, 10), r=(-4, 10))
    p.set("Cloak", 6, 0, 0).set("Stole", -8, 0, 0).set("HoodTip", 0, 0, 0).set("Robe", 0, 0, 0)
    return p


def crystal(p, t, spin=1.0, wobble=6.0):
    """Осколок над посохом медленно вращается и покачивается."""
    p.set("Crystal", wobble * wave(t, 2), 360.0 * spin * t, wobble * wave(t, 2, 0.25))


def idle(t):
    """Покой (3.3 сек): дышит, опираясь на посох; поглядывает на кристалл; левая рука перебирает пальцами — плетёт заготовку заклинания."""
    p = stance()
    breath = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", x=0.01 * sway, z=-0.006 * (breath * 0.5 + 0.5))
    p.add("Hips", z=1.2 * sway)
    p.add("Spine", x=1.8 * breath, z=-1.0 * sway)
    p.add("Chest", x=2.2 * wave(t, 2, -0.07))
    # Голова: смотрит вперёд, потом поднимает взгляд на кристалл, потом влево
    look_y = track(t, [(0, 0), (0.1, 0), (0.24, -26), (0.42, -26), (0.56, 0), (0.7, 18), (0.84, 18), (0.96, 0), (1, 0)])
    look_x = track(t, [(0, 0), (0.1, 0), (0.24, -14), (0.42, -14), (0.56, 0), (1, 0)])
    p.add("Head", x=look_x - 1.5 * breath, y=look_y)
    p.add("HoodTip", x=4 * breath, z=-look_y * 0.3)
    # Посох чуть гуляет под весом, кристалл вращается
    p.add("UpperArm.R", x=-2 * breath)
    p.add("Staff", x=2 * breath + 2 * sway, z=2 * wave(t, 1, 0.2))
    crystal(p, t)
    # Левая рука: кисть описывает маленький круг, будто наматывает нить
    weave = pulse(t, 0.72, 0.16)
    p.add("UpperArm.L", x=-10 * weave + 2 * breath, z=-4 * weave)
    p.add("ForeArm.L", x=-14 * weave + 6 * weave * wave(t, 6))
    p.add("Hand.L", x=24 * weave * wave(t, 6, 0.25), z=20 * weave * wave(t, 6))
    # Ткань запаздывает за телом
    p.add("Cloak", x=2.5 * wave(t, 1, -0.2), z=2 * wave(t, 1, -0.3))
    p.add("Stole", x=2.5 * wave(t, 1, -0.15))
    p.add("Robe", x=1.5 * wave(t, 1, -0.2), z=1.5 * wave(t, 1, -0.3))
    return p


def walk(t):
    """Шаг (0.8 сек): идёт, опираясь на посох — переставляет его раз в два шага; подол, плащ и капюшон качаются."""
    p = stance()
    a = wave(t, 1)            # +1: правая нога впереди
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.08)
    p.move("Hips", z=-0.02 + 0.016 * bounce, x=0.012 * a)
    p.add("Hips", y=6 * a, z=2.5 * a)
    p.legs(l=(6 - 24 * a, 12 + 30 * max(0.0, -c)), r=(6 + 24 * a, 12 + 30 * max(0.0, c)))
    p.set("Spine", 13, -4 - 6 * a, 0).set("Chest", 9, -3 - 3 * a, 0).set("Head", -12 + 2 * bounce, 6 + 6 * a, 0)
    # Посох: выносит вперёд и ставит, пока шагает левая нога
    plant = wave(t, 1, 0.1)
    p.staff_arm(34 - 14 * plant, 46 + 8 * plant, lean=8 + 22 * plant, side=-4)
    p.move("Hips", y=0.0)
    crystal(p, t, spin=0.5, wobble=10)
    p.left_arm(16 + 16 * a, 50, out=10, twist=20)
    p.set("Cloak", 14 + 6 * wave(t, 2, -0.15), 0, 5 * a)
    p.set("Stole", -6 - 14 * abs(a), 0, 0)
    p.set("Robe", 4 * wave(t, 2, -0.1), 0, 5 * wave(t, 1, -0.12))
    p.set("HoodTip", 8 * wave(t, 2, -0.2), 0, 4 * a)
    return p


def _tracks(p, t, K, rows):
    """rows: {кость: [тройки углов по ключам K]}"""
    for bone, vals in rows.items():
        p.set(bone, *[track(t, [(K[i], v[j]) for i, v in enumerate(vals)]) for j in range(3)])


def attack(t):
    """Удар посохом (0.87 сек): перехват, замах над головой → шаг и удар навершием сверху вниз (к 0.4 сек) → возврат."""
    p = stance()
    K = [0.0, 0.22, 0.36, 0.46, 0.62, 1.0]
    up = track(t, list(zip(K, [34, 120, 150, 70, 60, 34])))
    fore = track(t, list(zip(K, [46, 60, 30, 10, 14, 46])))
    lean = track(t, list(zip(K, [8, -30, -40, 84, 92, 8])))
    p.staff_arm(up, fore, lean=lean, side=-4, out=track(t, list(zip(K, [12, 20, 16, 4, 0, 12]))))
    p.left_arm(track(t, list(zip(K, [16, 50, 70, 30, 10, 16]))), track(t, list(zip(K, [62, 80, 60, 40, 50, 62]))), out=14, twist=20)
    _tracks(p, t, K, {
        "Spine": [(9, -6, 0), (0, -16, 0), (-6, -18, 0), (24, 10, 0), (28, 14, 0), (9, -6, 0)],
        "Chest": [(8, -4, 0), (0, -10, 0), (-6, -10, 0), (14, 8, 0), (16, 10, 0), (8, -4, 0)],
        "Head": [(-8, 8, 0), (-14, 14, 0), (-18, 14, 0), (-22, -8, 0), (-24, -10, 0), (-8, 8, 0)],
        "Cloak": [(6, 0, 0), (-4, 0, 0), (-8, 0, 0), (40, 0, 0), (20, 0, 0), (6, 0, 0)],
        "HoodTip": [(0, 0, 0), (-10, 0, 0), (-14, 0, 0), (30, 0, 0), (-10, 0, 0), (0, 0, 0)],
        "Stole": [(-8, 0, 0), (0, 0, 0), (4, 0, 0), (-40, 0, 0), (-30, 0, 0), (-8, 0, 0)],
        "Robe": [(0, 0, 0), (4, 0, 0), (6, 0, 0), (-10, 0, 0), (-6, 0, 0), (0, 0, 0)],
    })
    step = track(t, list(zip(K, [0, 0, 0.2, 1, 1, 0])))
    p.legs(l=(14 + 26 * step, 10 + 30 * step), r=(-4 - 20 * step, 10))
    p.move("Root", y=-0.2 * step)
    p.move("Hips", z=-0.06 * step)
    crystal(p, t, spin=1.0, wobble=14)
    return p


def cast(t):
    """Заклинание (0.9 сек): собирает силу левой рукой у груди, отводит посох → выбрасывает его вперёд, кристалл на цель (к 0.35 сек) → отдача."""
    p = stance()
    K = [0.0, 0.2, 0.38, 0.5, 0.72, 1.0]   # стойка, сбор, выпад, отдача, держит, стойка
    up = track(t, list(zip(K, [34, 0, 84, 78, 70, 34])))
    fore = track(t, list(zip(K, [46, 90, 6, 14, 20, 46])))
    lean = track(t, list(zip(K, [8, -24, 60, 64, 62, 8])))
    p.staff_arm(up, fore, lean=lean, side=-4, out=track(t, list(zip(K, [12, 22, 4, 6, 8, 12]))))
    p.left_arm(track(t, list(zip(K, [16, 40, -30, -24, -10, 16]))), track(t, list(zip(K, [62, 110, 10, 16, 30, 62]))),
               out=track(t, list(zip(K, [12, 4, 40, 36, 24, 12]))), twist=20)
    _tracks(p, t, K, {
        "Spine": [(9, -6, 0), (2, -20, 0), (18, 2, 0), (10, 0, 0), (10, 0, 0), (9, -6, 0)],
        "Chest": [(8, -4, 0), (0, -12, 0), (12, 0, 0), (6, 0, 0), (6, 0, 0), (8, -4, 0)],
        "Head": [(-8, 8, 0), (-4, 22, 0), (-20, 0, 0), (-14, 0, 0), (-12, 0, 0), (-8, 8, 0)],
        "Cloak": [(6, 0, 0), (-6, 0, 0), (44, 0, 0), (56, 0, 6), (30, 0, -4), (6, 0, 0)],
        "HoodTip": [(0, 0, 0), (-12, 0, 0), (34, 0, 0), (-16, 0, 0), (6, 0, 0), (0, 0, 0)],
        "Stole": [(-8, 0, 0), (2, 0, 0), (-44, 0, 0), (-20, 0, 0), (-12, 0, 0), (-8, 0, 0)],
        "Robe": [(0, 0, 0), (5, 0, 0), (-12, 0, 0), (8, 0, 0), (-3, 0, 0), (0, 0, 0)],
    })
    lunge = track(t, list(zip(K, [0, -0.3, 1, 0.8, 0.7, 0])))
    p.legs(l=(14 + 22 * lunge, 10 + 24 * max(0.0, lunge)), r=(-4 - 16 * lunge, 10 + 8 * max(0.0, -lunge)))
    p.move("Root", y=-0.12 * lunge)
    p.move("Hips", z=-0.05 * abs(lunge))
    crystal(p, t, spin=3.0, wobble=18)
    return p


def cast_sky(t):
    """Заклинание с небес (1 сек): воздевает посох и левую руку к небу, встаёт на носки → обрушивает посох вниз (к 0.45 сек)."""
    p = stance()
    K = [0.0, 0.26, 0.4, 0.5, 0.72, 1.0]   # стойка, воздел, пик, обрушил, держит, стойка
    up = track(t, list(zip(K, [34, 150, 164, 60, 54, 34])))
    fore = track(t, list(zip(K, [46, 20, 10, 30, 34, 46])))
    lean = track(t, list(zip(K, [8, -6, -10, 20, 14, 8])))
    p.staff_arm(up, fore, lean=lean, side=-4, out=track(t, list(zip(K, [12, 24, 26, 10, 10, 12]))))
    p.left_arm(track(t, list(zip(K, [16, 140, 158, 30, 20, 16]))), track(t, list(zip(K, [62, 30, 14, 70, 66, 62]))),
               out=track(t, list(zip(K, [12, 30, 34, 16, 12, 12]))), twist=20)
    _tracks(p, t, K, {
        "Spine": [(9, -6, 0), (-10, 0, 0), (-14, 0, 0), (26, 0, 0), (20, -2, 0), (9, -6, 0)],
        "Chest": [(8, -4, 0), (-10, 0, 0), (-14, 0, 0), (16, 0, 0), (12, -2, 0), (8, -4, 0)],
        "Head": [(-8, 8, 0), (-30, 0, 0), (-36, 0, 0), (10, 0, 0), (0, 4, 0), (-8, 8, 0)],
        "Cloak": [(6, 0, 0), (-10, 0, 0), (-16, 0, 0), (50, 0, 0), (24, 0, 0), (6, 0, 0)],
        "HoodTip": [(0, 0, 0), (-20, 0, 0), (-26, 0, 0), (40, 0, 0), (-8, 0, 0), (0, 0, 0)],
        "Stole": [(-8, 0, 0), (6, 0, 0), (10, 0, 0), (-36, 0, 0), (-14, 0, 0), (-8, 0, 0)],
        "Robe": [(0, 0, 0), (-4, 0, 0), (-6, 0, 0), (10, 0, 0), (-3, 0, 0), (0, 0, 0)],
    })
    rise = track(t, list(zip(K, [0, 0.8, 1, -1, -0.6, 0])))
    p.legs(l=(14, 10 + 26 * max(0.0, -rise)), r=(-4, 10 + 26 * max(0.0, -rise)))
    p.add("Foot.L", x=-26 * max(0.0, rise)).add("Foot.R", x=-26 * max(0.0, rise))   # на носки
    p.move("Hips", z=0.06 * max(0.0, rise) - 0.09 * max(0.0, -rise))
    crystal(p, t, spin=4.0, wobble=22)
    return p


def block(t):
    """Защита (0.67 сек): выставляет посох поперёк перед собой, левая ладонь вперёд — щит; толчок и обратно."""
    p = stance()
    up_ = track(t, [(0, 0), (0.25, 1), (0.7, 1), (1, 0)])
    jolt = pulse(t, 0.38, 0.1)
    p.staff_arm(34 + 26 * up_, 46 + 30 * up_, lean=8 + 6 * up_, side=-4 + 62 * up_, out=12 + 10 * up_)
    p.left_arm(16 + 50 * up_ - 14 * jolt, 62 - 30 * up_ + 20 * jolt, out=12 - 6 * up_, twist=20)
    p.set("Hand.L", -20 - 50 * up_, 0, 0)
    p.add("Spine", x=6 * up_ - 8 * jolt).add("Chest", x=4 * up_ - 4 * jolt).add("Head", x=8 * up_)
    p.legs(l=(14 + 6 * up_, 10 + 16 * up_), r=(-4 - 8 * up_, 10 + 14 * up_))
    p.move("Hips", z=-0.015 - 0.05 * up_, y=0.03 * jolt)
    p.add("Cloak", x=-6 * up_ + 20 * jolt).add("HoodTip", x=16 * jolt).add("Stole", x=12 * jolt)
    crystal(p, t, spin=2.0, wobble=10 + 20 * jolt)
    return p


def hit(t):
    """Получил удар (0.5 сек): худое тело складывается, капюшон и плащ мотаются, повисает на посохе."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.34, 1), (0.6, -0.3), (0.82, 0.08), (1, 0)])
    p.move("Root", y=0.1 * snap)
    p.move("Hips", z=-0.04 * snap)
    p.add("Spine", x=-22 * snap, y=14 * snap).add("Chest", x=-12 * snap)
    p.add("Head", x=-24 * whip, y=-16 * snap, z=8 * whip)
    p.add("UpperArm.R", x=20 * snap).add("Staff", x=-34 * snap, z=10 * whip)
    p.add("UpperArm.L", x=34 * snap, z=-30 * snap).add("ForeArm.L", x=30 * snap)
    p.add("Thigh.L", x=14 * snap).add("Thigh.R", x=-12 * snap).add("Shin.R", x=14 * snap)
    p.add("Cloak", x=-30 * whip).add("HoodTip", x=40 * whip).add("Stole", x=-30 * whip).add("Robe", x=-10 * whip)
    crystal(p, t, spin=1.0, wobble=30 * snap + 6)
    return p


def death(t):
    """Падение (1.5 сек): виснет на посохе, сползает по нему на колени, посох валится, маг ложится на бок."""
    p = stance()
    K = [0.0, 0.2, 0.46, 0.68, 0.86, 1.0]   # стойка, пошатнулся, на коленях у посоха, заваливается, лёг, затих

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.staff_arm(tr([34, 60, 110, 70, 30, 26]), tr([46, 70, 60, 30, 20, 16]), lean=tr([8, 4, 14, 60, 88, 90]), side=tr([-4, -8, -10, -30, -40, -40]),
                out=tr([12, 16, 20, 40, 60, 62]))
    p.left_arm(tr([16, -10, 20, 10, 40, 44]), tr([62, 30, 50, 40, 30, 24]), out=tr([12, 30, 16, 30, 50, 54]), twist=20)
    _tracks(p, t, K, {
        "Spine": [(9, -6, 0), (-10, 8, 0), (24, 0, 0), (26, 0, 8), (10, 0, 4), (8, 0, 4)],
        "Chest": [(8, -4, 0), (-8, 4, 0), (18, 0, 0), (16, 0, 6), (8, 0, 2), (6, 0, 2)],
        "Head": [(-8, 8, 0), (-22, -10, 0), (30, 0, 6), (20, 0, 14), (10, 10, 10), (8, 12, 10)],
        "Cloak": [(6, 0, 0), (-20, 0, 0), (20, 0, 0), (10, 0, -20), (4, 0, -30), (2, 0, -32)],
        "HoodTip": [(0, 0, 0), (30, 0, 0), (-30, 0, 0), (-10, 0, 20), (0, 0, 30), (0, 0, 30)],
        "Stole": [(-8, 0, 0), (-30, 0, 0), (-50, 0, 0), (-30, 0, 10), (-10, 0, 14), (-8, 0, 14)],
        "Robe": [(0, 0, 0), (-8, 0, 0), (-30, 0, 0), (-20, 0, 0), (-8, 0, 0), (-6, 0, 0)],
    })
    kneel = tr([0, 0.1, 1, 1, 0.3, 0.2])
    p.legs(l=(14 + 50 * kneel, 10 + 100 * kneel), r=(-4 + 10 * kneel, 10 + 100 * kneel))
    p.move("Hips", z=tr([-0.015, -0.03, -0.42, -0.5, -0.56, -0.56]))
    side = tr([0, 0, 0, 40, 84, 86])
    p.set("Root", 0, side, 0)
    p.move("Root", y=tr([0, 0.08, 0.04, 0.04, 0.04, 0.04]), x=tr([0, 0, 0, -0.1, -0.2, -0.2]), z=tr([0, 0, 0, 0.06, 0.12, 0.12]))
    twitch = pulse(t, 0.93, 0.04)
    p.add("Hand.L", x=30 * twitch)
    crystal(p, t, spin=1.0 - 0.6 * t, wobble=6 + 20 * pulse(t, 0.7, 0.1))
    return p


def sit(t):
    """Сидит на скамье у костра (4 сек, цикл): ссутулился к огню, посох прислонён к плечу и упирается
    в землю впереди, левая рука на колене. Дышит, клюёт носом, греет ладонь у огня, кристалл дремлет.
    Высота скамьи в хабе — 0,42 м (build_hub.py, build_campfire)."""
    p = MagePose({}, {})
    breath = wave(t, 2)
    p.move("Hips", z=-0.3, y=0.02)
    p.legs(l=(84, 84), r=(78, 80))
    p.set("Robe", -62, 0, 0).set("Stole", -50, 0, 0).set("Cloak", 8, 0, 0).set("HoodTip", 6, 0, 0)
    p.set("Spine", 16 + 1.5 * breath, 0, 0).set("Chest", 10 + 2 * wave(t, 2, -0.07), 0, 0)
    # Голова: смотрит в огонь, иногда клюёт носом и вздрагивает
    nod = pulse(t, 0.55, 0.12)
    p.set("Head", 14 + 16 * nod - 6 * pulse(t, 0.66, 0.03), 6 * wave(t, 1, 0.3), 0)
    p.add("HoodTip", x=3 * breath + 10 * nod)
    # Посох прислонён к правому плечу: верх уходит назад, низ стоит на земле впереди
    p.staff_arm(22, 58, lean=-58, side=-6, out=10)
    p.add("Staff", x=1.5 * breath)
    crystal(p, t, spin=0.25, wobble=3)
    # Левая рука лежит на колене; раз за цикл тянет ладонь к огню
    warm = pulse(t, 0.25, 0.14)
    p.left_arm(28 + 30 * warm, 52 - 30 * warm, out=8, twist=10 + 30 * warm)
    p.set("Hand.L", -10 - 20 * warm, 0, 0)
    p.add("Cloak", x=1.5 * wave(t, 1, -0.2))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 100, idle, cyclic=True)
    k.bake(rig, "Walk", 24, walk, cyclic=True)
    k.bake(rig, "Attack", 26, attack)
    k.bake(rig, "Cast", 27, cast)
    k.bake(rig, "CastSky", 30, cast_sky)
    k.bake(rig, "Block", 20, block)
    k.bake(rig, "Hit", 15, hit)
    k.bake(rig, "Death", 45, death)
    k.bake(rig, "Sit", 120, sit, cyclic=True)


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
    glb = args[0] if args else os.path.join(here, "..", "hero.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "hero.blend")
    build(glb, blend)
