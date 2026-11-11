# Топляк — тварь Раскола (~1.6 м). Сгорбленный утопленник: сине-серая кожа, пучки тины на плечах
# и голове, тёмные штаны, к правой руке ржавой цепью примотан обломок морёного бревна.
# Глазницы и трещины на груди светятся бирюзой. Смотрит в -Y.
#
# Запуск: python3 build_drowned_walker.py out.glb out.blend (нужен модуль bpy)
# или в Blender: Scripting → Open → Run Script. Рядом должен лежать char_kit.py.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "DrownedWalker"
SIDES = (("R", -1), ("L", 1))


def build_mesh():
    skin = k.mat("Drowned_Skin", (0.44, 0.55, 0.60), rough=0.75)          # сине-серая кожа (светлее палитры — чтобы не сливался)
    dark = k.mat("Drowned_DarkSkin", (0.30, 0.39, 0.44), rough=0.8)
    weed = k.mat("Drowned_Weed", (0.20, 0.34, 0.20), rough=0.95)          # болотная тина
    pants = k.mat("Drowned_Pants", (0.27, 0.19, 0.16), rough=0.95)
    wood = k.mat("Drowned_Log", (0.25, 0.17, 0.13), rough=0.95)           # морёное бревно
    cut = k.mat("Drowned_LogCut", (0.48, 0.38, 0.28), rough=0.9)
    iron = k.mat("Drowned_Chain", (0.36, 0.30, 0.27), metallic=0.5, rough=0.7)
    rift = k.mat("Drowned_Rift", (0.30, 0.82, 0.88), rough=0.4, emit=1.2)

    for side, s in SIDES:
        x = 0.12 * s
        k.box(f"Foot.{side}", (0.13, 0.26, 0.08), (x, -0.05, 0.04), dark, f"Foot.{side}")
        k.limb(f"Shin.{side}", (x, 0, 0.08), (x, -0.01, 0.42), 0.055, 0.075, pants, f"Shin.{side}")
        k.limb(f"Thigh.{side}", (x, 0, 0.42), (x, 0, 0.80), 0.08, 0.105, pants, f"Thigh.{side}")
        # Рваные края штанин
        k.limb(f"PantsHem.{side}", (x, 0, 0.14), (x, 0, 0.22), 0.085, 0.07, pants, f"Shin.{side}", segs=5)
        ax = 0.25 * s
        k.sphere(f"Shoulder.{side}", 0.095, (ax, 0, 1.25), skin, f"UpperArm.{side}", segs=6, rings=4)
        k.limb(f"UpperArm.{side}", (ax, 0, 1.25), (0.28 * s, 0, 0.94), 0.07, 0.058, skin, f"UpperArm.{side}")
        k.sphere(f"Elbow.{side}", 0.062, (0.28 * s, 0.005, 0.94), dark, f"ForeArm.{side}", segs=6, rings=4)
        k.limb(f"ForeArm.{side}", (0.28 * s, 0, 0.94), (0.29 * s, -0.02, 0.64), 0.058, 0.05, skin, f"ForeArm.{side}")
        # Пучок тины на плече: три гранёных «сосульки» вниз, на своей кости
        for i, (dx, dy, ln) in enumerate([(0.0, -0.06, 0.30), (0.05, 0.03, 0.38), (-0.04, 0.07, 0.26)]):
            k.limb(f"Weed.{side}{i}", ((0.26 + dx) * s, dy, 1.33), ((0.30 + dx) * s, dy * 1.4, 1.33 - ln),
                   0.06, 0.008, weed, f"Weed.{side}", segs=4)
        k.sphere(f"WeedCap.{side}", 0.115, (0.26 * s, 0.0, 1.31), weed, f"Weed.{side}", scale=(1.0, 1.1, 0.55), segs=6, rings=3)

    # Левая кисть: распухшая ладонь с длинными пальцами
    k.sphere("Palm.L", 0.062, (0.29, -0.03, 0.58), skin, "Hand.L", scale=(0.8, 1.0, 1.2), segs=6, rings=4)
    for i in (-1, 0, 1):
        k.limb(f"Finger.L{i}", (0.29 + 0.03 * i, -0.04, 0.54), (0.29 + 0.04 * i, -0.07, 0.42), 0.02, 0.008, dark, "Hand.L", segs=3)
    # Правая кисть — кулак, вросший в бревно
    k.sphere("Fist.R", 0.07, (-0.29, -0.03, 0.59), skin, "Hand.R", segs=6, rings=4)

    # Таз и раздутый живот утопленника, рёбра
    k.sphere("Pelvis", 0.2, (0, 0, 0.84), pants, "Hips", scale=(1.1, 0.85, 0.75), segs=7, rings=4)
    k.sphere("Belly", 0.215, (0, -0.03, 1.0), skin, "Spine", scale=(1.05, 0.95, 0.95), segs=8, rings=5)
    k.limb("Ribcage", (0, 0.01, 1.02), (0, 0.0, 1.30), 0.225, 0.20, skin, "Chest", segs=8)
    k.sphere("Hump", 0.17, (0, 0.11, 1.26), dark, "Chest", scale=(1.3, 0.9, 0.8), segs=7, rings=4)   # горб
    k.limb("Neck", (0, -0.02, 1.28), (0, -0.07, 1.40), 0.08, 0.07, skin, "Chest")
    # Голова: лысый череп, провалы глазниц светятся, челюсть отвисла (своя кость)
    k.sphere("Skull", 0.15, (0, -0.08, 1.50), skin, "Head", scale=(1.0, 1.1, 1.05), segs=8, rings=5)
    k.box("Brow", (0.22, 0.06, 0.04), (0, -0.215, 1.535), dark, "Head", rot=(10, 0, 0))
    for side, s in SIDES:
        k.sphere(f"Socket.{side}", 0.043, (0.062 * s, -0.215, 1.495), rift, "Head", scale=(1.0, 0.5, 0.9), segs=6, rings=3)
    k.box("Cheeks", (0.18, 0.1, 0.06), (0, -0.16, 1.43), dark, "Head")
    k.box("Jaw", (0.17, 0.15, 0.055), (0, -0.14, 1.375), skin, "Jaw")
    k.box("Teeth", (0.12, 0.02, 0.03), (0, -0.21, 1.405), cut, "Jaw")
    # Тина на затылке — как мокрые волосы, своя кость
    strand = [(-0.035, 0.0), (0.035, 0.0), (0.02, -0.34), (-0.01, -0.42), (-0.03, -0.30)]
    for i, (dx, tilt) in enumerate([(-0.09, -0.5), (0.0, 0.0), (0.09, 0.5)]):
        k.plate(f"Hair{i}", strand, 0.03, (dx, 0.055, 1.60), (1, tilt * 0.6, 0), (0, 0.25, 1), weed, "Hair")
    k.sphere("HairCap", 0.12, (0, -0.03, 1.60), weed, "Head", scale=(1.1, 1.2, 0.5), segs=6, rings=3)

    # Трещины Раскола на груди и животе
    k.crack("CrackChest", [(-0.06, 0.12), (-0.02, 0.06), (-0.05, 0.0), (0.0, -0.06), (-0.03, -0.12)], (0.03, -0.212, 1.16),
            (1, 0, 0), (0, 0, 1), rift, "Chest", width=0.02, depth=0.05)
    k.crack("CrackChest2", [(0.0, 0.03), (0.06, 0.05), (0.10, 0.0)], (0.0, -0.21, 1.20),
            (1, 0, 0), (0, 0, 1), rift, "Chest", width=0.018, depth=0.05)
    k.crack("CrackBelly", [(0.0, 0.08), (0.04, 0.03), (0.0, -0.03), (0.05, -0.08)], (-0.09, -0.225, 1.0),
            (1, 0, 0), (0, 0, 1), rift, "Spine", width=0.018, depth=0.05)
    k.crack("CrackArm", [(0, 0.08), (0.02, 0.02), (-0.02, -0.04), (0.01, -0.10)], (0.345, 0.0, 1.10),
            (0, 1, 0), (0, 0, 1), rift, "UpperArm.L", width=0.016, depth=0.04)

    # Бревно-таран (кость Weapon вдоль правого предплечья): толстый обломок с расщепом, примотан цепью
    lx, ly = -0.30, -0.065
    k.limb("Log", (lx, ly, 0.98), (lx, ly - 0.02, 0.26), 0.085, 0.105, wood, "Weapon", segs=7)
    k.limb("LogCut", (lx, ly - 0.02, 0.262), (lx, ly - 0.02, 0.25), 0.095, 0.08, cut, "Weapon", segs=7)
    for i, (dx, dy, ln) in enumerate([(-0.04, 0.02, 0.16), (0.03, -0.03, 0.11), (0.0, 0.05, 0.08)]):   # щепа сверху
        k.limb(f"Splinter{i}", (lx + dx, ly + dy, 0.97), (lx + dx * 1.3, ly + dy * 1.3, 0.97 + ln), 0.035, 0.004, wood, "Weapon", segs=4)
    k.limb("Knot", (lx - 0.07, ly, 0.5), (lx - 0.17, ly - 0.02, 0.54), 0.04, 0.025, wood, "Weapon", segs=5)   # сук
    for i, z in enumerate((0.86, 0.72, 0.60)):   # три витка цепи вокруг бревна и руки
        k.limb(f"Chain{i}", (lx + 0.012, ly + 0.03, z), (lx + 0.012, ly + 0.03, z - 0.045), 0.128, 0.128, iron, "Weapon", segs=7)
    k.box("ChainTail", (0.035, 0.035, 0.2), (lx + 0.11, ly + 0.07, 0.50), iron, "ChainTail")
    k.box("ChainTail2", (0.045, 0.03, 0.06), (lx + 0.11, ly + 0.07, 0.385), iron, "ChainTail")
    return k.join_parts("DrownedWalkerMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.2), None),
    "Hips": ((0, 0, 0.80), (0, 0, 0.92), "Root"),
    "Spine": ((0, 0, 0.92), (0, 0, 1.08), "Hips"),
    "Chest": ((0, 0, 1.08), (0, 0, 1.30), "Spine"),
    "Head": ((0, -0.04, 1.36), (0, -0.04, 1.66), "Chest"),
    "Jaw": ((0, -0.07, 1.42), (0, -0.22, 1.37), "Head"),
    "Hair": ((0, 0.06, 1.60), (0, 0.10, 1.25), "Head"),
    "Weapon": ((-0.29, -0.04, 0.94), (-0.29, -0.06, 0.30), "ForeArm.R"),
    "ChainTail": ((-0.19, 0.005, 0.60), (-0.19, 0.005, 0.36), "Weapon"),
}
for side, s in SIDES:
    BONES.update({
        f"UpperArm.{side}": ((0.25 * s, 0, 1.25), (0.28 * s, 0, 0.94), "Chest"),
        f"ForeArm.{side}": ((0.28 * s, 0, 0.94), (0.29 * s, -0.02, 0.64), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.29 * s, -0.02, 0.64), (0.29 * s, -0.04, 0.46), f"ForeArm.{side}"),
        f"Weed.{side}": ((0.26 * s, 0, 1.33), (0.30 * s, 0, 1.0), "Chest"),
        f"Thigh.{side}": ((0.12 * s, 0, 0.80), (0.12 * s, 0, 0.42), "Hips"),
        f"Shin.{side}": ((0.12 * s, 0, 0.42), (0.12 * s, 0, 0.08), f"Thigh.{side}"),
        f"Foot.{side}": ((0.12 * s, 0, 0.08), (0.12 * s, -0.16, 0.02), f"Shin.{side}"),
    })

# Стойка: сгорблен, голова свесилась набок, бревно оттягивает правое плечо вниз и чуть вперёд,
# левая рука висит, ноги расставлены, правая подволакивается.
STANCE = {
    "Spine": (20, 6, -4), "Chest": (22, 8, -6), "Head": (-22, -10, 12), "Jaw": (22, 0, 0),
    "Thigh.L": (-22, 0, -8), "Shin.L": (26, 0, 0), "Foot.L": (-4, 0, 0),
    "Thigh.R": (8, 0, 10), "Shin.R": (20, 0, 0), "Foot.R": (-26, 0, 14),
    "UpperArm.R": (-22, 0, 10), "ForeArm.R": (-34, 0, 0), "Hand.R": (0, 0, 0), "Weapon": (0, 0, 0),
    "UpperArm.L": (-14, 0, -12), "ForeArm.L": (-24, 0, 0), "Hand.L": (-10, 0, 0),
    "Weed.L": (-22, 0, 0), "Weed.R": (-22, 0, 0), "Hair": (-10, 0, 0), "ChainTail": (0, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.03)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3.3 сек): тяжело качается, хрипло дышит, голова рывком перекатывается на другое плечо, пальцы скребут воздух."""
    p = stance()
    breath = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", x=0.022 * sway, z=-0.012 * (breath * 0.5 + 0.5))
    p.add("Hips", z=3 * sway)
    p.add("Thigh.L", z=-3 * sway)
    p.add("Thigh.R", z=-3 * sway)
    p.add("Spine", x=3 * breath, z=-3 * sway)
    p.add("Chest", x=4 * wave(t, 2, -0.1), z=-2 * sway)
    # Голова висит на одном плече, потом рывком переваливается на другое и обратно
    roll = track(t, [(0, 0), (0.3, 0), (0.36, -26), (0.66, -24), (0.74, 2), (1, 0)])
    look = track(t, [(0, 0), (0.3, 0), (0.36, 24), (0.66, 20), (0.74, -4), (1, 0)])
    p.add("Head", x=3 * breath + 6 * pulse(t, 0.36, 0.06), y=look, z=roll)
    p.add("Jaw", x=6 * (breath * 0.5 + 0.5) + 14 * pulse(t, 0.5, 0.1))
    p.add("Hair", x=4 * wave(t, 1, -0.2) - roll * 0.3, z=-roll * 0.5)
    # Тина на плечах запаздывает за качанием
    p.add("Weed.L", x=4 * wave(t, 1, -0.22), z=5 * wave(t, 1, -0.18))
    p.add("Weed.R", x=4 * wave(t, 1, -0.26), z=5 * wave(t, 1, -0.2))
    # Бревно тянет руку: едва покачивается, один раз он его перехватывает
    heft = pulse(t, 0.84, 0.08)
    p.add("UpperArm.R", x=2 * sway - 8 * heft, z=2 * breath)
    p.add("ForeArm.R", x=-3 * breath - 12 * heft)
    p.add("ChainTail", x=8 * wave(t, 2, -0.15), z=6 * wave(t, 1, -0.2))
    # Левая рука висит, пальцы дёргаются
    twitch = pulse(t, 0.18, 0.04) + pulse(t, 0.24, 0.04) + pulse(t, 0.6, 0.05)
    p.add("UpperArm.L", x=3 * wave(t, 1, 0.2), z=-2 * breath)
    p.add("ForeArm.L", x=-5 * wave(t, 1, 0.1) - 8 * twitch)
    p.add("Hand.L", x=-22 * twitch)
    return p


def walk(t):
    """Шаг (0.9 сек): ковыляет, заваливаясь с боку на бок; правую ногу подволакивает, бревно мотается."""
    p = Pose(STANCE)
    a = wave(t, 1)            # +1 — левая нога впереди
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.05)
    p.move("Hips", z=-0.04 + 0.02 * bounce, x=0.035 * a)
    p.add("Hips", y=-8 * a, z=-6 * a)
    p.set("Thigh.L", -16 - 30 * a, 0, -8)
    p.set("Shin.L", 22 + 40 * max(0.0, -c), 0, 0)
    p.set("Foot.L", 4 + 14 * a, 0, 0)
    p.set("Thigh.R", -4 + 20 * a, 0, 10)        # правая нога почти не сгибается — волочится
    p.set("Shin.R", 14 + 10 * max(0.0, c), 0, 0)
    p.set("Foot.R", -20 - 8 * a, 0, 14)
    p.set("Spine", 26, 6 + 8 * a, -4 + 6 * a)
    p.set("Chest", 24, 8 + 6 * a, -6 + 4 * a)
    p.set("Head", -24 + 5 * bounce, -10 - 8 * a, 12 - 10 * a)
    p.add("Jaw", x=8 * bounce)
    p.add("UpperArm.R", x=-12 * a, z=4)
    p.add("ForeArm.R", x=8 * wave(t, 1, 0.15))
    p.add("UpperArm.L", x=22 * a)
    p.add("ForeArm.L", x=-10 + 10 * a)
    p.add("Hand.L", x=14 * wave(t, 2, 0.2))
    lag = wave(t, 1, -0.18)
    p.add("Weed.L", x=10 * abs(lag), z=10 * lag)
    p.add("Weed.R", x=10 * abs(lag), z=10 * lag)
    p.add("Hair", x=10 * wave(t, 2, -0.2), z=-8 * lag)
    p.add("ChainTail", x=20 * wave(t, 2, -0.2), z=10 * lag)
    return p


def attack(t):
    """Удар бревном (1 сек): тяжело отводит бревно назад-вверх → шаг и удар сверху наискось (к 0.4 сек) → бревно тянет его вперёд → выпрямляется."""
    p = Pose({}, {})
    K = [0.0, 0.24, 0.34, 0.42, 0.62, 1.0]   # стойка, замах, разгон, удар, пронос, стойка
    S = STANCE

    def tr(bone, wind, rush, hit_, follow):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], wind), (K[2], rush), (K[3], hit_),
                                (K[4], follow), (K[5], S.get(bone, (0, 0, 0)))]))

    tr("Spine", (-4, 26, 0), (4, 18, 0), (36, -24, 0), (44, -30, 0))
    tr("Chest", (-6, 20, 0), (2, 12, 0), (26, -18, 0), (30, -22, 0))
    tr("Head", (-10, -30, 0), (-14, -20, 0), (-40, 18, 6), (-30, 22, 10))
    tr("Jaw", (10, 0, 0), (30, 0, 0), (40, 0, 0), (30, 0, 0))
    tr("UpperArm.R", (60, 0, 30), (-60, 0, 46), (-110, 0, 10), (-70, 0, -8))
    tr("ForeArm.R", (-80, 0, 0), (-70, 0, 0), (-12, 0, 0), (-8, 0, 0))
    tr("UpperArm.L", (-50, 0, -30), (-60, 0, -34), (30, 0, -30), (36, 0, -26))
    tr("ForeArm.L", (-50, 0, 0), (-40, 0, 0), (-20, 0, 0), (-24, 0, 0))
    tr("Hand.L", (-30, 0, 0), (-30, 0, 0), (10, 0, 0), (0, 0, 0))
    tr("Thigh.L", (-10, 0, -8), (-30, 0, -8), (-48, 0, -8), (-44, 0, -8))
    tr("Shin.L", (30, 0, 0), (40, 0, 0), (50, 0, 0), (52, 0, 0))
    tr("Foot.L", (0, 0, 0), (-10, 0, 0), (-2, 0, 0), (0, 0, 0))
    tr("Thigh.R", (-6, 0, 10), (10, 0, 10), (26, 0, 10), (20, 0, 10))
    tr("Shin.R", (30, 0, 0), (24, 0, 0), (20, 0, 0), (24, 0, 0))
    tr("Foot.R", (-10, 0, 14), (-30, 0, 14), (-40, 0, 14), (-34, 0, 14))
    # Тина и волосы: отстают на замахе, хлещут вперёд после удара
    lag = track(t, [(0, 0), (K[1], 20), (K[2], 30), (K[3], -10), (K[3] + 0.1, -44), (K[4] + 0.1, 12), (1, 0)])
    for b in ("Weed.L", "Weed.R"):
        p.set(b, S[b][0] + lag, 0, 0)
    p.set("Hair", S["Hair"][0] + lag * 1.2, 0, 0)
    p.set("ChainTail", lag * 1.5, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.08), (K[2], 0.02), (K[3], -0.22), (K[4], -0.26), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.03), (K[1], -0.02), (K[2], 0.0), (K[3], -0.13), (K[4], -0.16), (1, -0.03)]))
    return p


def hit(t):
    """Получил удар (0.5 сек): корпус откидывает, голова мотается следом, тина и цепь вразлёт."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.18, 0.4), (0.34, 1), (0.58, -0.35), (0.8, 0.1), (1, 0)])
    p.move("Root", y=0.14 * snap)
    p.move("Hips", z=-0.03 * snap)
    p.add("Spine", x=-26 * snap, y=-10 * snap)
    p.add("Chest", x=-20 * snap)
    p.add("Head", x=-34 * whip, y=16 * snap, z=-14 * whip)
    p.add("Jaw", x=26 * snap)
    p.add("UpperArm.R", x=14 * snap, z=16 * snap)
    p.add("ForeArm.R", x=-16 * snap)
    p.add("UpperArm.L", x=30 * snap, z=-30 * snap)
    p.add("ForeArm.L", x=-30 * snap)
    p.add("Thigh.L", x=14 * snap)
    p.add("Thigh.R", x=-12 * snap)
    p.add("Shin.R", x=12 * snap)
    for b in ("Weed.L", "Weed.R"):
        p.add(b, x=-36 * whip, z=10 * whip)
    p.add("Hair", x=-40 * whip)
    p.add("ChainTail", x=-40 * whip)
    return p


def death(t):
    """Гибель (1.5 сек): свет в глазницах уже не держит — оседает на колени, бревно утягивает вбок, валится лицом вниз, пальцы скребут напоследок."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.46, 0.72, 1.0]   # стойка, отшатнулся, на коленях, упал, затих
    S = STANCE

    def tr(bone, stagger, kneel, fall, rest):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], stagger), (K[2], kneel), (K[3], fall), (K[4], rest)]))

    tr("Spine", (-14, -8, 0), (30, 10, -8), (10, 0, 0), (6, 0, 0))
    tr("Chest", (-10, -6, 0), (26, 8, -6), (6, 0, 0), (4, 0, 0))
    tr("Head", (-36, 14, -10), (30, -10, 16), (-30, 40, 0), (-24, 50, 0))
    tr("Jaw", (36, 0, 0), (16, 0, 0), (30, 0, 0), (26, 0, 0))
    tr("UpperArm.R", (-10, 0, 30), (-30, 0, 20), (-130, 0, 40), (-140, 0, 46))
    tr("ForeArm.R", (-40, 0, 0), (-20, 0, 0), (-20, 0, 0), (-10, 0, 0))
    tr("UpperArm.L", (-20, 0, -44), (-40, 0, -20), (-110, 0, -50), (-120, 0, -56))
    tr("ForeArm.L", (-50, 0, 0), (-30, 0, 0), (-40, 0, 0), (-30, 0, 0))
    tr("Hand.L", (-20, 0, 0), (0, 0, 0), (-10, 0, 0), (0, 0, 0))
    tr("Thigh.L", (-6, 0, -8), (-70, 0, -10), (-14, 0, -14), (-6, 0, -16))
    tr("Shin.L", (20, 0, 0), (126, 0, 0), (30, 0, 0), (10, 0, 0))
    tr("Thigh.R", (14, 0, 10), (-50, 0, 12), (-8, 0, 16), (-2, 0, 18))
    tr("Shin.R", (20, 0, 0), (120, 0, 0), (26, 0, 0), (8, 0, 0))
    tr("Foot.L", (0, 0, 0), (40, 0, 0), (50, 0, 0), (50, 0, 0))
    tr("Foot.R", (-20, 0, 14), (40, 0, 0), (50, 0, 0), (50, 0, 0))
    tr("Weed.L", (-40, 0, 0), (10, 0, 0), (40, 0, 20), (50, 0, 24))
    tr("Weed.R", (-40, 0, 0), (10, 0, 0), (40, 0, -20), (50, 0, -24))
    tr("Hair", (-40, 0, 0), (20, 0, 0), (60, 0, 0), (70, 0, 0))
    tr("ChainTail", (-30, 0, 0), (20, 0, 0), (50, 0, 0), (60, 0, 0))
    # Валится вперёд: Root наклоняется лицом вниз, таз опускается до земли
    lean = track(t, [(0, 0), (K[1], -8), (K[2], 10), (K[3], 86), (K[3] + 0.06, 80), (K[3] + 0.12, 87), (1, 87)])
    p.set("Root", lean, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.12), (K[2], 0.06), (K[3], -0.3), (1, -0.3)]),
           z=track(t, [(0, 0), (K[2], 0), (K[3], 0.14), (1, 0.14)]))
    p.move("Hips", z=track(t, [(0, -0.03), (K[1], -0.02), (K[2], -0.42), (K[3], -0.12), (1, -0.12)]))
    spasm = pulse(t, 0.88, 0.05)
    p.add("Hand.L", x=-30 * spasm)
    p.add("ForeArm.L", x=-14 * spasm)
    p.add("Shin.R", x=14 * spasm)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 100, idle, cyclic=True)
    k.bake(rig, "Walk", 27, walk, cyclic=True)
    k.bake(rig, "Attack", 30, attack)
    k.bake(rig, "Hit", 15, hit)
    k.bake(rig, "Death", 45, death)


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
    glb = args[0] if args else os.path.join(here, "..", "drowned_walker.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "drowned_walker.blend")
    build(glb, blend)
