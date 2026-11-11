# Гоблин — тварь Раскола. Низкий (~1 м), сутулый, с длинными руками, большой головой и ушами.
# Серо-зелёная кожа с бирюзовыми светящимися трещинами, ржавый тесак, щит-баклер, лохмотья.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Запуск в Blender: вкладка Scripting → Open → этот файл → в конце поправь пути → Run Script.
# Рядом должен лежать char_kit.py.
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "Goblin"


# ---------- Модель ----------

def build_mesh():
    skin = k.mat("Goblin_Skin", (0.50, 0.60, 0.40), rough=0.85)          # серо-зелёная кожа
    dark = k.mat("Goblin_DarkSkin", (0.34, 0.43, 0.28), rough=0.9)
    leather = k.mat("Goblin_Leather", (0.27, 0.20, 0.14), rough=0.9)
    rag = k.mat("Goblin_Rag", (0.60, 0.47, 0.28), rough=0.95)            # лохмотья
    iron = k.mat("Goblin_RustIron", (0.40, 0.31, 0.26), metallic=0.5, rough=0.65)
    edge = k.mat("Goblin_Edge", (0.62, 0.62, 0.60), metallic=0.7, rough=0.4)   # заточенная кромка
    brass = k.mat("Goblin_Brass", (0.55, 0.45, 0.20), metallic=0.6, rough=0.5)
    wood = k.mat("Goblin_Wood", (0.36, 0.28, 0.19), rough=0.9)
    bone = k.mat("Goblin_Tooth", (0.82, 0.78, 0.64), rough=0.6)
    rift = k.mat("Goblin_Rift", (0.25, 0.85, 0.75), rough=0.4, emit=1.1)  # трещины Раскола и глаза

    for side, s in (("R", -1), ("L", 1)):
        x = 0.10 * s
        # Ступня с тремя когтями
        k.box(f"Foot.{side}", (0.10, 0.17, 0.06), (x, -0.035, 0.03), skin, f"Foot.{side}")
        for i in (-1, 0, 1):
            k.limb(f"Claw.{side}{i}", (x + 0.032 * i, -0.11, 0.03), (x + 0.04 * i, -0.17, 0.012), 0.02, 0.004,
                   dark, f"Foot.{side}", segs=3)
        # Кривые короткие ноги
        k.limb(f"Shin.{side}", (x, 0, 0.07), (x, -0.01, 0.22), 0.045, 0.06, skin, f"Shin.{side}")
        k.sphere(f"Knee.{side}", 0.058, (x, -0.015, 0.22), dark, f"Shin.{side}", segs=6, rings=4)
        k.limb(f"Thigh.{side}", (x, 0, 0.22), (x, 0, 0.40), 0.062, 0.08, skin, f"Thigh.{side}")

        # Длинные руки с толстыми предплечьями
        ax = 0.19 * s
        k.sphere(f"Shoulder.{side}", 0.068, (ax, 0, 0.68), skin, f"UpperArm.{side}", segs=6, rings=4)
        k.limb(f"UpperArm.{side}", (ax, 0, 0.68), (0.22 * s, 0, 0.50), 0.052, 0.045, skin, f"UpperArm.{side}")
        k.sphere(f"Elbow.{side}", 0.05, (0.22 * s, 0.005, 0.50), dark, f"ForeArm.{side}", segs=6, rings=4)
        k.limb(f"ForeArm.{side}", (0.22 * s, 0, 0.50), (0.225 * s, -0.02, 0.33), 0.046, 0.058, skin, f"ForeArm.{side}")
        k.limb(f"Bracer.{side}", (0.222 * s, -0.012, 0.42), (0.225 * s, -0.02, 0.335), 0.058, 0.064, leather,
               f"ForeArm.{side}")
        # Кулак: кисть, пальцы, обхватившие рукоять спереди, и большой палец сверху
        hx = 0.225 * s
        k.sphere(f"Fist.{side}", 0.056, (hx, -0.03, 0.28), skin, f"Hand.{side}", scale=(0.85, 1.05, 1.0), segs=6, rings=4)
        k.box(f"Fingers.{side}", (0.088, 0.04, 0.085), (hx, -0.072, 0.275), dark, f"Hand.{side}")
        k.box(f"Thumb.{side}", (0.035, 0.07, 0.035), (hx - 0.03 * s, -0.055, 0.325), skin, f"Hand.{side}", rot=(15, 0, 0))

    # Таз, пояс с пряжкой
    k.sphere("Pelvis", 0.15, (0, 0, 0.42), leather, "Hips", scale=(1.08, 0.85, 0.7), segs=6, rings=4)
    k.limb("Belt", (0, 0, 0.445), (0, 0, 0.50), 0.168, 0.165, leather, "Hips", segs=8)
    k.box("Buckle", (0.08, 0.03, 0.07), (0, -0.165, 0.472), brass, "Hips")
    # Рваная набедренная повязка — на своих костях, чтобы болталась
    flap = [(-0.09, 0.0), (0.09, 0.0), (0.08, -0.15), (0.035, -0.20), (0.0, -0.14), (-0.05, -0.21), (-0.085, -0.13)]
    k.plate("LoinFront", flap, 0.02, (0, -0.158, 0.46), (1, 0, 0), (0, 0, 1), rag, "LoinF")
    k.plate("LoinBack", flap, 0.02, (0, 0.15, 0.46), (-1, 0, 0), (0, 0, 1), rag, "LoinB")

    # Пузо и грудь в кожаной жилетке
    k.sphere("Belly", 0.158, (0, -0.012, 0.53), skin, "Spine", scale=(1.05, 0.92, 0.9), segs=7, rings=4)
    k.limb("Vest", (0, 0.012, 0.52), (0, 0.005, 0.70), 0.172, 0.15, leather, "Chest", segs=8)
    k.box("VestStrap", (0.06, 0.03, 0.2), (0.07, -0.145, 0.63), leather, "Chest", rot=(-8, 0, -32))
    k.limb("Neck", (0, 0, 0.68), (0, -0.02, 0.77), 0.075, 0.065, skin, "Chest")

    # Асимметричный наплечник на левом плече с шипом
    k.sphere("Pauldron", 0.105, (0.205, 0, 0.695), rag, "UpperArm.L", scale=(1.1, 1.05, 0.8), segs=8, rings=4)
    k.sphere("PauldronRim", 0.112, (0.21, 0, 0.675), leather, "UpperArm.L", scale=(1.1, 1.05, 0.3), segs=8, rings=4)
    k.limb("PauldronSpike", (0.24, 0, 0.75), (0.31, 0, 0.84), 0.03, 0.003, bone, "UpperArm.L", segs=5)

    # Большая голова: череп, тяжёлые брови, крючковатый нос, светящиеся глаза
    k.sphere("Skull", 0.16, (0, -0.02, 0.87), skin, "Head", scale=(1.15, 1.05, 0.9), segs=8, rings=4)
    k.box("BrowRidge", (0.24, 0.07, 0.04), (0, -0.155, 0.905), dark, "Head", rot=(14, 0, 0))
    for side, s in (("R", -1), ("L", 1)):
        eye = [(-0.035, 0.012), (0.035, 0.024), (0.03, -0.014), (-0.028, -0.012)]
        k.plate(f"Eye.{side}", eye if s > 0 else [(-a, b) for a, b in reversed(eye)], 0.02,
                (0.07 * s, -0.178, 0.868), (1, 0, 0), (0, 0, 1), rift, "Head")
        # Длинные уши на своих костях — дёргаются и запаздывают за головой
        ear = [(0.0, -0.045), (0.0, 0.05), (0.14, 0.085), (0.30, 0.10), (0.17, 0.02), (0.13, -0.03)]
        k.plate(f"Ear.{side}", ear, 0.022, (0.155 * s, 0.0, 0.87), (s, 0.18, 0.28), (0, 0, 1), skin, f"Ear.{side}")
        k.plate(f"EarInner.{side}", [(0.02, -0.02), (0.02, 0.03), (0.2, 0.07), (0.12, 0.0)], 0.026,
                (0.155 * s, -0.002, 0.872), (s, 0.18, 0.28), (0, 0, 1), dark, f"Ear.{side}")
    k.limb("Nose", (0, -0.16, 0.875), (0, -0.30, 0.79), 0.042, 0.012, skin, "Head", segs=5)
    # Нижняя челюсть с клыками — своя кость, чтобы скалился и орал
    k.box("Jaw", (0.21, 0.17, 0.06), (0, -0.085, 0.765), dark, "Jaw")
    for s in (-1, 1):
        k.limb(f"Tusk{s}", (0.075 * s, -0.155, 0.78), (0.085 * s, -0.165, 0.86), 0.02, 0.003, bone, "Jaw", segs=4)
    k.box("Teeth", (0.11, 0.02, 0.025), (0, -0.168, 0.798), bone, "Jaw")

    # Трещины Раскола на коже
    k.crack("CrackHead", [(0, -0.02), (0.025, 0.02), (0.0, 0.05), (0.02, 0.08)], (0.075, -0.158, 0.93),
            (1, 0, 0), (0, 0.55, 1), rift, "Head", depth=0.03)
    k.crack("CrackBelly", [(0, 0.07), (0.03, 0.03), (-0.01, 0.0), (0.04, -0.05)], (-0.04, -0.148, 0.53),
            (1, 0, 0), (0, 0, 1), rift, "Spine", depth=0.035)
    k.crack("CrackArm", [(0, 0.06), (0.018, 0.02), (-0.02, -0.02), (0.01, -0.07)], (-0.247, 0.0, 0.60),
            (0, 1, 0), (0, 0, 1), rift, "UpperArm.R", depth=0.03)
    k.crack("CrackLeg", [(0, 0.05), (0.02, 0.01), (-0.01, -0.04)], (0.10, -0.066, 0.32),
            (1, 0, 0), (0, 0, 1), rift, "Thigh.L", depth=0.03)

    # Ржавый тесак (кость Weapon): рукоять проходит сквозь кулак, клинок вперёд, кромка вниз
    wx, wz = -0.225, 0.28
    k.limb("Grip", (wx, 0.075, wz), (wx, -0.105, wz), 0.02, 0.018, leather, "Weapon", segs=5)
    k.sphere("Pommel", 0.03, (wx, 0.085, wz), iron, "Weapon", segs=5, rings=3)
    k.box("Guard", (0.035, 0.03, 0.13), (wx, -0.112, wz), iron, "Weapon")
    blade = [(0.0, 0.035), (0.40, 0.055), (0.47, -0.01), (0.42, -0.10), (0.31, -0.088), (0.28, -0.112),
             (0.16, -0.10), (0.13, -0.078), (0.0, -0.045)]
    k.plate("Blade", blade, 0.018, (wx, -0.125, wz), (0, -1, 0), (0, 0, 1), iron, "Weapon")
    k.plate("BladeEdge", [(0.01, -0.047), (0.13, -0.08), (0.16, -0.102), (0.28, -0.114), (0.31, -0.09),
                          (0.42, -0.102), (0.40, -0.075), (0.02, -0.03)], 0.02, (wx, -0.125, wz),
            (0, -1, 0), (0, 0, 1), edge, "Weapon")

    # Круглый щит-баклер на левом предплечье
    k.limb("ShieldRim", (0.262, -0.02, 0.40), (0.287, -0.02, 0.40), 0.2, 0.2, iron, "ForeArm.L", segs=10)
    k.limb("ShieldWood", (0.27, -0.02, 0.40), (0.297, -0.02, 0.40), 0.178, 0.172, wood, "ForeArm.L", segs=10)
    k.limb("ShieldBoss", (0.297, -0.02, 0.40), (0.345, -0.02, 0.40), 0.06, 0.02, iron, "ForeArm.L", segs=6)
    k.box("ShieldPlank", (0.012, 0.012, 0.33), (0.30, 0.05, 0.40), leather, "ForeArm.L")

    return k.join_parts("GoblinMesh")


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Hips": ((0, 0, 0.40), (0, 0, 0.47), "Root"),
    "Spine": ((0, 0, 0.47), (0, 0, 0.58), "Hips"),
    "Chest": ((0, 0, 0.58), (0, 0, 0.72), "Spine"),
    "Head": ((0, 0, 0.72), (0, 0, 0.98), "Chest"),
    "Jaw": ((0, -0.02, 0.79), (0, -0.16, 0.76), "Head"),
    "LoinF": ((0, -0.158, 0.46), (0, -0.158, 0.28), "Hips"),
    "LoinB": ((0, 0.15, 0.46), (0, 0.15, 0.28), "Hips"),
    "Weapon": ((-0.225, -0.03, 0.28), (-0.225, -0.25, 0.28), "Hand.R"),
}
for side, s in (("R", -1), ("L", 1)):
    BONES.update({
        f"Ear.{side}": ((0.155 * s, 0, 0.87), (0.42 * s, 0.05, 0.97), "Head"),
        f"UpperArm.{side}": ((0.19 * s, 0, 0.68), (0.22 * s, 0, 0.50), "Chest"),
        f"ForeArm.{side}": ((0.22 * s, 0, 0.50), (0.225 * s, -0.02, 0.33), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.225 * s, -0.02, 0.33), (0.225 * s, -0.03, 0.24), f"ForeArm.{side}"),
        f"Thigh.{side}": ((0.10 * s, 0, 0.40), (0.10 * s, 0, 0.22), "Hips"),
        f"Shin.{side}": ((0.10 * s, 0, 0.22), (0.10 * s, 0, 0.07), f"Thigh.{side}"),
        f"Foot.{side}": ((0.10 * s, 0, 0.07), (0.10 * s, -0.12, 0.02), f"Shin.{side}"),
    })


# ---------- Анимации ----------

# Боевая стойка: присел, левая нога и щит впереди, тесак занесён у правого плеча,
# спина сгорблена, голова задрана — смотрит исподлобья.
STANCE = {
    "Spine": (16, -10, 0), "Chest": (12, -8, 0), "Head": (-24, 16, 3),
    "Thigh.L": (-36, 0, -9), "Shin.L": (44, 0, 0), "Foot.L": (8, 0, 0),
    "Thigh.R": (-4, 0, 12), "Shin.R": (34, 0, 0), "Foot.R": (30, 0, 0),
    "UpperArm.R": (-20, 0, 48), "ForeArm.R": (-100, 55, 0), "Hand.R": (0, 0, 0), "Weapon": (-28, 0, 0),
    "UpperArm.L": (-52, -35, -16), "ForeArm.L": (-62, 0, 0), "Hand.L": (0, 0, 0),
    "Ear.R": (4, 0, 0), "Ear.L": (4, 0, 0),
    "LoinF": (-14, 0, 0), "LoinB": (6, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.045)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def ears(p, up=0.0, back=0.0):
    """Уши: up — приподнять, back — прижать назад (у правого уха ось Z зеркальна)."""
    p.add("Ear.L", x=up, z=back)
    p.add("Ear.R", x=up, z=-back)


def idle(t):
    """Покой (3 сек): дышит, переминается, зыркает по сторонам, уши дёргаются, скалится."""
    p = stance()
    breath = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", x=0.014 * sway, z=-0.012 * (breath * 0.5 + 0.5))
    p.add("Hips", z=2.5 * sway)
    p.add("Thigh.L", z=-2.5 * sway, x=-2 * breath)
    p.add("Thigh.R", z=-2.5 * sway, x=-1.5 * breath)
    p.add("Shin.L", x=3 * (breath * 0.5 + 0.5))
    p.add("Shin.R", x=3 * (breath * 0.5 + 0.5))
    p.add("Spine", x=2.5 * breath, z=-2.0 * sway)
    p.add("Chest", x=2.5 * wave(t, 2, -0.08))
    # Голова: резкие повороты с остановками, как у настороженного зверька
    yaw = track(t, [(0, 0), (0.14, 0), (0.2, -30), (0.44, -30), (0.5, -8), (0.72, 14), (0.78, 14), (0.92, 0), (1, 0)])
    nod = track(t, [(0, 0), (0.2, 4), (0.44, 4), (0.5, -4), (0.72, 2), (1, 0)])
    p.add("Head", x=nod - 2 * breath, y=yaw, z=-yaw * 0.12)
    # Уши запаздывают за головой и дёргаются после каждого поворота
    lag = track(t, [(0, 0), (0.14, 0), (0.2, 14), (0.3, 0), (0.44, 0), (0.5, -10), (0.6, 0), (1, 0)])
    twitch = pulse(t, 0.3, 0.05) + pulse(t, 0.64, 0.045) + pulse(t, 0.86, 0.04)
    p.add("Ear.L", x=10 * twitch + 2 * breath, z=lag)
    p.add("Ear.R", x=14 * pulse(t, 0.34, 0.05) + 10 * pulse(t, 0.86, 0.04) + 2 * breath, z=lag)
    # Скалится
    p.add("Jaw", x=-10 * pulse(t, 0.58, 0.1) - 2 * (breath * 0.5 + 0.5))
    # Тесак покачивается на плече, один раз перехватывает поудобнее
    heft = pulse(t, 0.75, 0.09)
    p.add("UpperArm.R", x=-3 * breath - 6 * heft, z=2 * sway)
    p.add("ForeArm.R", x=3 * wave(t, 2, 0.1) + 10 * heft)
    p.add("Weapon", x=5 * wave(t, 2, 0.2) - 16 * heft, z=4 * sway)
    # Щит чуть гуляет
    p.add("UpperArm.L", x=3 * wave(t, 2, 0.15), z=-2 * sway)
    p.add("ForeArm.L", x=-4 * wave(t, 1, 0.3))
    p.add("LoinF", x=3 * wave(t, 1, -0.2))
    p.add("LoinB", x=3 * wave(t, 1, -0.25))
    return p


def walk(t):
    """Бег вприпрыжку (0.67 сек): наклон вперёд, таз крутится, уши и лохмотья болтаются."""
    p = Pose(STANCE)
    a = wave(t, 1)            # +1 — правая нога впереди
    c = wave(t, 1, 0.25)      # косинус: скорость ноги
    bounce = wave(t, 2, 0.1)
    p.move("Hips", z=-0.035 + 0.028 * bounce, x=0.012 * a)
    p.add("Hips", y=10 * a, z=4 * a)
    p.set("Thigh.R", -20 - 42 * a, 0, 6)
    p.set("Thigh.L", -20 + 42 * a, 0, -6)
    p.set("Shin.R", 30 + 46 * max(0.0, c) + 8 * a, 0, 0)
    p.set("Shin.L", 30 + 46 * max(0.0, -c) - 8 * a, 0, 0)
    p.set("Foot.R", 14 - 22 * a, 0, 0)
    p.set("Foot.L", 14 + 22 * a, 0, 0)
    p.set("Spine", 22, -6 - 10 * a, 0)
    p.set("Chest", 12, -6 - 6 * a, 0)
    p.set("Head", -26 + 4 * bounce, 10 + 12 * a, 0)
    p.add("UpperArm.R", x=14 * a - 6, z=-4)
    p.add("ForeArm.R", x=8 * wave(t, 2, 0.2))
    p.add("Weapon", x=10 * wave(t, 2, 0.3))
    p.add("UpperArm.L", x=-16 * a + 10, y=10)
    p.add("ForeArm.L", x=10 * a)
    flop = wave(t, 2, -0.12)
    ears(p, up=-12 * flop, back=16)
    p.add("Jaw", x=-6 - 4 * bounce)
    p.set("LoinF", -8 - 18 * abs(a), 0, 0)
    p.set("LoinB", 22 + 10 * flop, 0, 0)
    return p


def attack(t):
    """Удар (0.87 сек): присел и замахнулся → прыжок с рубящим ударом (к 0.4 сек) → проносит тесак → встаёт."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.33, 0.44, 0.6, 1.0]   # стойка, замах, полёт, удар, пронос, стойка
    S = STANCE

    def tr(bone, wind, fly, hit, follow):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], wind), (K[2], fly), (K[3], hit),
                                (K[4], follow), (K[5], S.get(bone, (0, 0, 0)))]))

    tr("Spine", (6, 16, 0), (-6, 20, 0), (34, -30, 0), (38, -36, 0))
    tr("Chest", (2, 8, 0), (-8, 10, 0), (16, -18, 0), (18, -22, 0))
    tr("Head", (-18, -6, 0), (-10, -10, 0), (-40, 30, 0), (-36, 34, 0))
    tr("UpperArm.R", (-110, 0, 40), (-160, 0, 26), (-70, 0, 4), (-42, 0, -10))
    tr("ForeArm.R", (-110, 55, 0), (-80, 55, 0), (-18, 40, 0), (-10, 30, 0))
    tr("Hand.R", (0, 0, 0), (-20, 0, 0), (20, 0, 0), (25, 0, 0))
    tr("Weapon", (-10, 0, 0), (10, 0, 0), (-50, 0, 0), (-62, 0, 0))
    tr("UpperArm.L", (-70, -35, -20), (-40, -20, -40), (10, -10, -45), (20, -10, -40))
    tr("ForeArm.L", (-70, 0, 0), (-50, 0, 0), (-40, 0, 0), (-45, 0, 0))
    tr("Thigh.L", (-50, 0, -9), (-60, 0, -9), (-58, 0, -9), (-52, 0, -9))
    tr("Shin.L", (70, 0, 0), (40, 0, 0), (62, 0, 0), (60, 0, 0))
    tr("Foot.L", (10, 0, 0), (-20, 0, 0), (4, 0, 0), (8, 0, 0))
    tr("Thigh.R", (-20, 0, 12), (20, 0, 12), (24, 0, 12), (14, 0, 12))
    tr("Shin.R", (64, 0, 0), (30, 0, 0), (34, 0, 0), (36, 0, 0))
    tr("Foot.R", (30, 0, 0), (-30, 0, 0), (10, 0, 0), (24, 0, 0))
    tr("Jaw", (-8, 0, 0), (-30, 0, 0), (-34, 0, 0), (-20, 0, 0))
    tr("LoinF", (-20, 0, 0), (10, 0, 0), (-30, 0, 0), (-24, 0, 0))
    tr("LoinB", (10, 0, 0), (40, 0, 0), (-10, 0, 0), (6, 0, 0))
    # Уши: прижаты в полёте, хлопают вперёд после удара (запаздывание)
    back = track(t, [(0, 0), (K[1], -10), (K[2], 30), (K[3], 26), (K[3] + 0.08, -18), (K[4] + 0.1, 6), (1, 0)])
    p.set("Ear.L", 4, 0, back)
    p.set("Ear.R", 4, 0, -back)
    # Тело: присел назад, прыгнул вперёд-вверх, приземлился низко
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.07), (K[2], -0.16), (K[3], -0.34), (K[4], -0.34), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.045), (K[1], -0.11), (K[2], 0.07), (K[3], -0.10), (K[4], -0.11), (1, -0.045)]))
    return p


def hit(t):
    """Получил удар (0.47 сек): корпус отбрасывает назад, голова мотается с запозданием, уши и руки вразлёт."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.18, 0.4), (0.32, 1), (0.55, -0.35), (0.78, 0.1), (1, 0)])   # голова позже корпуса
    p.move("Root", y=0.12 * snap)
    p.move("Hips", z=-0.03 * snap)
    p.add("Spine", x=-30 * snap, y=14 * snap)
    p.add("Chest", x=-14 * snap)
    p.add("Head", x=-30 * whip, y=-20 * snap, z=8 * whip)
    p.add("Jaw", x=-28 * snap)
    p.add("UpperArm.R", x=26 * snap, z=26 * snap)
    p.add("ForeArm.R", x=40 * snap)
    p.add("Weapon", x=-30 * whip)
    p.add("UpperArm.L", x=40 * snap, z=-30 * snap)
    p.add("Thigh.L", x=14 * snap)
    p.add("Thigh.R", x=-16 * snap)
    p.add("Shin.R", x=14 * snap)
    ears(p, up=22 * whip, back=-34 * whip)
    p.add("LoinF", x=-30 * whip)
    p.add("LoinB", x=-20 * whip)
    return p


def death(t):
    """Гибель (1.3 сек): пошатнулся, колени подломились, рухнул на спину; уши и рука дёргаются напоследок."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.42, 0.68, 1.0]   # стойка, отшатнулся, на коленях, упал, затих
    S = STANCE

    def tr(bone, stagger, kneel, fall, rest):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], stagger), (K[2], kneel), (K[3], fall), (K[4], rest)]))

    tr("Spine", (-22, 12, 0), (10, 0, 6), (-12, 0, 0), (-8, 0, 0))
    tr("Chest", (-12, 6, 0), (14, 0, 4), (-6, 0, 0), (-4, 0, 0))
    tr("Head", (-34, -20, 0), (26, 10, 10), (-22, 24, 0), (-14, 30, 0))
    tr("Jaw", (-30, 0, 0), (-12, 0, 0), (-26, 0, 0), (-18, 0, 0))
    tr("UpperArm.R", (-10, 0, 50), (10, 0, 30), (-60, 0, 72), (-70, 0, 80))
    tr("ForeArm.R", (-50, 55, 0), (-30, 40, 0), (-30, 20, 0), (-14, 0, 0))
    tr("Weapon", (0, 0, 0), (-50, 0, 0), (-20, 0, 30), (-10, 0, 40))
    tr("UpperArm.L", (-10, 0, -50), (16, 0, -30), (-50, 0, -64), (-58, 0, -70))
    tr("ForeArm.L", (-50, 0, 0), (-40, 0, 0), (-30, 0, 0), (-20, 0, 0))
    tr("Thigh.L", (-10, 0, -9), (-60, 0, -12), (-30, 0, -16), (-18, 0, -18))
    tr("Shin.L", (30, 0, 0), (118, 0, 0), (60, 0, 0), (28, 0, 0))
    tr("Thigh.R", (-30, 0, 12), (-40, 0, 14), (-14, 0, 18), (-6, 0, 20))
    tr("Shin.R", (40, 0, 0), (112, 0, 0), (40, 0, 0), (12, 0, 0))
    tr("Foot.L", (8, 0, 0), (40, 0, 0), (30, 0, 0), (30, 0, 0))
    tr("Foot.R", (20, 0, 0), (40, 0, 0), (30, 0, 0), (30, 0, 0))
    tr("LoinF", (-30, 0, 0), (-50, 0, 0), (-70, 0, 0), (-80, 0, 0))
    tr("LoinB", (0, 0, 0), (30, 0, 0), (60, 0, 0), (70, 0, 0))
    # Заваливается на спину: Root поворачивается назад, таз опускается до земли
    lean = track(t, [(0, 0), (K[1], -6), (K[2], 6), (K[3], -86), (K[3] + 0.06, -80), (K[3] + 0.12, -88), (1, -88)])
    p.set("Root", lean, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.1), (K[2], 0.12), (K[3], 0.22), (1, 0.22)]),
           z=track(t, [(0, 0), (K[2], 0), (K[3], 0.1), (1, 0.1)]))
    p.move("Hips", z=track(t, [(0, -0.045), (K[1], -0.03), (K[2], -0.2), (K[3], -0.06), (1, -0.06)]))
    # Уши хлопают при падении и опадают; последняя судорога
    flop = track(t, [(0, 0), (K[1], -30), (K[2], 20), (K[3], -40), (K[3] + 0.08, 14), (K[3] + 0.16, -6), (1, 0)])
    spasm = pulse(t, 0.86, 0.05)
    p.set("Ear.L", 4 - 30 * smoothstep(t, K[3], 1.0) + 12 * spasm, 0, flop)
    p.set("Ear.R", 4 - 30 * smoothstep(t, K[3], 1.0), 0, -flop)
    p.add("ForeArm.R", x=-24 * spasm)
    p.add("Shin.L", x=16 * spasm)
    return p


def smoothstep(t, a, b):
    return k.smooth((t - a) / (b - a))


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 20, walk, cyclic=True)
    k.bake(rig, "Attack", 26, attack)
    k.bake(rig, "Hit", 14, hit)
    k.bake(rig, "Death", 40, death)


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
    glb = args[0] if args else os.path.join(here, "..", "goblin.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "goblin.blend")
    build(glb, blend)
