# Мшистый корягач — элитная тварь Раскола (~2.1 м). Голем из корней и коры: ноги-корневища,
# бочкообразный ствол, длинные руки-сучья до колен, пень-голова с ветвистыми рогами, шапки мха
# на плечах. В груди за «рёбрами» из корней светится бирюзовое ядро Раскола. Смотрит в -Y.
#
# Запуск: python3 build_mossy_treant.py out.glb out.blend (нужен модуль bpy)
# или в Blender: Scripting → Open → Run Script. Рядом должен лежать char_kit.py.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "MossyTreant"
SIDES = (("R", -1), ("L", 1))
CORE = (0, -0.31, 1.24)     # где в груди сидит ядро


def build_mesh():
    bark = k.mat("Treant_Bark", (0.33, 0.24, 0.19), rough=0.95)           # кора (светлее палитры — чтобы не сливался)
    dark = k.mat("Treant_DarkBark", (0.21, 0.15, 0.13), rough=0.95)
    cut = k.mat("Treant_Cut", (0.56, 0.44, 0.38), rough=0.9)              # сколы древесины
    moss = k.mat("Treant_Moss", (0.24, 0.46, 0.26), rough=0.95)
    moss2 = k.mat("Treant_MossLight", (0.36, 0.56, 0.30), rough=0.95)
    rift = k.mat("Treant_Rift", (0.37, 0.92, 0.83), rough=0.4, emit=1.3)  # трещины и глазницы
    core = k.mat("Treant_Core", (0.30, 0.92, 0.82), rough=0.3, emit=1.5)    # ядро Раскола

    for side, s in SIDES:
        x = 0.24 * s
        # Ступня — три расползшихся корня
        for i, (dx, dy) in enumerate([(-0.13, -0.22), (0.02, -0.30), (0.16, -0.16)]):
            k.limb(f"Root.{side}{i}", (x, -0.02, 0.10), (x + dx, dy, 0.02), 0.07, 0.015, dark, f"Foot.{side}", segs=4)
        k.limb(f"Heel.{side}", (x, 0.0, 0.10), (x, 0.16, 0.02), 0.07, 0.02, dark, f"Foot.{side}", segs=4)
        k.limb(f"Shin.{side}", (x, 0, 0.06), (x, -0.01, 0.42), 0.13, 0.11, bark, f"Shin.{side}", segs=6)
        k.limb(f"Thigh.{side}", (x, 0, 0.40), (0.20 * s, 0, 0.78), 0.12, 0.16, bark, f"Thigh.{side}", segs=6)
        k.sphere(f"Knee.{side}", 0.125, (x, -0.03, 0.42), dark, f"Shin.{side}", segs=5, rings=3)
        # Рука-сук: плечо, локоть-нарост, утолщённое предплечье и три когтя-ветки
        ax = 0.50 * s
        k.limb(f"UpperArm.{side}", (ax, 0, 1.50), (0.58 * s, 0, 1.02), 0.12, 0.085, bark, f"UpperArm.{side}", segs=6)
        k.sphere(f"Elbow.{side}", 0.105, (0.58 * s, 0.01, 1.02), dark, f"ForeArm.{side}", segs=5, rings=3)
        k.limb(f"ForeArm.{side}", (0.58 * s, 0, 1.02), (0.60 * s, -0.03, 0.52), 0.085, 0.135, bark, f"ForeArm.{side}", segs=6)
        k.limb(f"Wrist.{side}", (0.60 * s, -0.03, 0.56), (0.60 * s, -0.03, 0.46), 0.145, 0.12, cut, f"ForeArm.{side}", segs=6)
        for i, (dx, dy) in enumerate([(-0.09, -0.04), (0.0, -0.10), (0.09, -0.02)]):
            k.limb(f"Claw.{side}{i}", (0.60 * s + dx * 0.6, -0.03 + dy * 0.5, 0.48), (0.60 * s + dx * 1.3, -0.03 + dy * 1.6, 0.20),
                   0.05, 0.008, dark, f"Hand.{side}", segs=4)
        # Шапка мха на плече и свисающие пряди (своя кость)
        k.sphere(f"MossCap.{side}", 0.21, (0.47 * s, 0.01, 1.58), moss, f"UpperArm.{side}", scale=(1.15, 1.1, 0.6), segs=6, rings=3)
        k.sphere(f"MossTuft.{side}", 0.10, (0.40 * s, -0.10, 1.66), moss2, f"UpperArm.{side}", scale=(1.0, 1.0, 0.7), segs=5, rings=3)
        for i, (dx, dy, ln) in enumerate([(0.06, -0.10, 0.30), (0.12, 0.06, 0.40), (-0.02, 0.13, 0.26)]):
            k.limb(f"MossStrand.{side}{i}", ((0.47 + dx) * s, dy, 1.52), ((0.50 + dx) * s, dy * 1.2, 1.52 - ln),
                   0.05, 0.008, moss if i != 1 else moss2, f"Moss.{side}", segs=4)

    # Ствол: комель-таз, бочка туловища с дуплом, широкая грудь-развилка
    k.barrel("Pelvis", 0.34, 0.30, 0.66, 0.92, dark, "Hips", segs=7, sy=0.85)
    k.barrel("Trunk", 0.30, 0.36, 0.88, 1.20, bark, "Spine", segs=8, sy=0.88)
    k.barrel("ChestTrunk", 0.37, 0.45, 1.16, 1.58, bark, "Chest", segs=8, sy=0.80)
    k.barrel("Shoulders", 0.46, 0.30, 1.56, 1.70, dark, "Chest", segs=8, sy=0.78)
    # Дупло в груди: тёмная ниша, в ней ядро, поверх — «рёбра» из корней
    k.box("Hollow", (0.36, 0.06, 0.40), (0, -0.30, 1.24), dark, "Chest")
    k.sphere("Core", 0.13, CORE, core, "Core", segs=6, rings=4)
    for i, (x0, x1) in enumerate([(-0.20, -0.07), (0.03, -0.02), (0.21, 0.10)]):
        k.limb(f"Rib{i}", (x0, -0.40, 1.04), (x1, -0.43, 1.45), 0.032, 0.026, bark, "Chest", segs=4)
    k.limb("RibCross", (-0.2, -0.43, 1.36), (0.2, -0.42, 1.12), 0.024, 0.02, cut, "Chest", segs=4)
    # Обломанные сучья на спине и боку
    k.limb("Stub1", (0.12, 0.26, 1.40), (0.24, 0.50, 1.62), 0.07, 0.03, bark, "Chest", segs=5)
    k.limb("Stub1Cut", (0.235, 0.49, 1.61), (0.245, 0.51, 1.63), 0.03, 0.03, cut, "Chest", segs=5)
    k.limb("Stub2", (-0.2, 0.24, 1.30), (-0.34, 0.42, 1.36), 0.06, 0.02, bark, "Chest", segs=4)
    k.sphere("MossBack", 0.22, (0, 0.20, 1.62), moss, "Chest", scale=(1.5, 0.9, 0.5), segs=6, rings=3)
    k.sphere("MossBelt", 0.12, (-0.2, -0.22, 0.90), moss2, "Hips", scale=(1.2, 0.8, 0.6), segs=5, rings=3)

    # Голова-пень: тяжёлые надбровья, светящиеся глазницы, челюсть из коры (своя кость), рога-ветви
    k.barrel("Skull", 0.19, 0.16, 1.64, 1.92, bark, "Head", segs=7, loc=(0, -0.06), sy=1.05)
    k.box("Brow", (0.36, 0.10, 0.07), (0, -0.235, 1.83), dark, "Head", rot=(14, 0, 0))
    for side, s in SIDES:
        k.sphere(f"Socket.{side}", 0.05, (0.085 * s, -0.235, 1.775), rift, "Head", scale=(1.1, 0.5, 0.75), segs=5, rings=3)
        k.limb(f"Antler.{side}", (0.12 * s, -0.04, 1.90), (0.30 * s, 0.0, 2.10), 0.055, 0.03, bark, "Head", segs=5)
        k.limb(f"AntlerTip.{side}", (0.30 * s, 0.0, 2.10), (0.26 * s, -0.08, 2.30), 0.03, 0.006, bark, "Head", segs=4)
        k.limb(f"AntlerTine.{side}", (0.23 * s, -0.015, 2.02), (0.44 * s, -0.04, 2.12), 0.026, 0.006, cut, "Head", segs=4)
        k.limb(f"AntlerBack.{side}", (0.20 * s, -0.02, 1.99), (0.24 * s, 0.14, 2.14), 0.024, 0.006, bark, "Head", segs=4)
    k.sphere("MossHead", 0.15, (0.02, 0.0, 1.93), moss2, "Head", scale=(1.1, 1.2, 0.45), segs=6, rings=3)
    k.box("Jaw", (0.27, 0.19, 0.09), (0, -0.16, 1.655), dark, "Jaw")
    for i in (-1, 0, 1):
        k.limb(f"Fang{i}", (0.09 * i, -0.24, 1.69), (0.09 * i, -0.25, 1.76), 0.025, 0.004, cut, "Jaw", segs=4)

    # Трещины Раскола: расходятся от дупла по стволу и руке
    k.crack("CrackA", [(0.0, 0.0), (0.06, 0.10), (0.02, 0.18), (0.08, 0.26)], (0.20, -0.345, 1.30),
            (1, 0, 0), (0, 0, 1), rift, "Chest", width=0.022, depth=0.06)
    k.crack("CrackB", [(0.0, 0.0), (-0.07, -0.08), (-0.03, -0.17), (-0.10, -0.26)], (-0.14, -0.31, 1.04),
            (1, 0, 0), (0, 0, 1), rift, "Spine", width=0.022, depth=0.06)
    k.crack("CrackArm", [(0, 0.14), (0.03, 0.05), (-0.03, -0.04), (0.02, -0.14)], (0.675, -0.02, 0.80),
            (0, 1, 0), (0, 0, 1), rift, "ForeArm.L", width=0.02, depth=0.06)
    k.crack("CrackLeg", [(0, 0.10), (0.03, 0.02), (-0.02, -0.08)], (-0.23, -0.14, 0.60),
            (1, 0, 0), (0, 0, 1), rift, "Thigh.R", width=0.02, depth=0.05)
    return k.join_parts("MossyTreantMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.25), None),
    "Hips": ((0, 0, 0.78), (0, 0, 0.92), "Root"),
    "Spine": ((0, 0, 0.92), (0, 0, 1.18), "Hips"),
    "Chest": ((0, 0, 1.18), (0, 0, 1.60), "Spine"),
    "Head": ((0, -0.04, 1.64), (0, -0.04, 1.95), "Chest"),
    "Jaw": ((0, -0.06, 1.70), (0, -0.26, 1.65), "Head"),
    "Core": ((CORE[0], CORE[1], CORE[2] - 0.10), (CORE[0], CORE[1], CORE[2] + 0.10), "Chest"),
}
for side, s in SIDES:
    BONES.update({
        f"UpperArm.{side}": ((0.50 * s, 0, 1.50), (0.58 * s, 0, 1.02), "Chest"),
        f"ForeArm.{side}": ((0.58 * s, 0, 1.02), (0.60 * s, -0.03, 0.52), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.60 * s, -0.03, 0.52), (0.60 * s, -0.06, 0.22), f"ForeArm.{side}"),
        f"Moss.{side}": ((0.50 * s, 0, 1.52), (0.54 * s, 0, 1.14), "Chest"),
        f"Thigh.{side}": ((0.20 * s, 0, 0.78), (0.24 * s, 0, 0.42), "Hips"),
        f"Shin.{side}": ((0.24 * s, 0, 0.42), (0.24 * s, 0, 0.10), f"Thigh.{side}"),
        f"Foot.{side}": ((0.24 * s, 0, 0.10), (0.24 * s, -0.22, 0.02), f"Shin.{side}"),
    })

# Стойка: навис над героями, ноги широко, правая рука отведена для размаха, левая тянется вперёд когтями.
STANCE = {
    "Spine": (14, -8, 0), "Chest": (12, -8, 0), "Head": (-14, 14, 0), "Jaw": (10, 0, 0),
    "Thigh.L": (-20, 0, -10), "Shin.L": (24, 0, 0), "Foot.L": (-4, 0, 0),
    "Thigh.R": (6, 0, 12), "Shin.R": (18, 0, 0), "Foot.R": (-24, 0, 12),
    "UpperArm.R": (-6, 0, 30), "ForeArm.R": (-42, 0, 0), "Hand.R": (-10, 0, 0),
    "UpperArm.L": (-40, 0, -14), "ForeArm.L": (-46, 0, 0), "Hand.L": (-24, 0, 0),
    "Moss.L": (-24, 0, 0), "Moss.R": (-24, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.04)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def core_glow(p, t, beats=2, extra=0.0):
    """Ядро «бьётся», как сердце: короткие толчки, extra — добавочное раздувание."""
    beat = max(0.0, wave(t, beats)) ** 3
    p.size("Core", 1.0 + 0.16 * beat + extra)


def idle(t):
    """Покой (3.7 сек): тяжело дышит и скрипит, ядро бьётся, голова медленно поворачивается, когти сжимаются."""
    p = stance()
    breath = wave(t, 2)
    sway = wave(t, 1)
    core_glow(p, t, beats=4)
    p.move("Hips", x=0.02 * sway, z=-0.015 * (breath * 0.5 + 0.5))
    p.add("Hips", z=2 * sway)
    p.add("Thigh.L", z=-2 * sway)
    p.add("Thigh.R", z=-2 * sway)
    p.add("Shin.L", x=2 * (breath * 0.5 + 0.5))
    p.add("Shin.R", x=2 * (breath * 0.5 + 0.5))
    p.add("Spine", x=2.5 * breath, z=-1.5 * sway)
    p.add("Chest", x=3 * wave(t, 2, -0.08))
    yaw = track(t, [(0, 0), (0.15, 0), (0.3, -26), (0.55, -26), (0.7, 6), (0.85, 6), (1, 0)])
    p.add("Head", x=-2 * breath + 4 * pulse(t, 0.62, 0.06), y=yaw, z=-yaw * 0.1)
    p.add("Jaw", x=6 * (breath * 0.5 + 0.5) + 10 * pulse(t, 0.62, 0.08))
    p.add("UpperArm.R", x=3 * wave(t, 2, -0.1), z=3 * breath)
    p.add("ForeArm.R", x=-4 * wave(t, 2, -0.18))
    p.add("Hand.R", x=-16 * pulse(t, 0.4, 0.1))
    p.add("UpperArm.L", x=4 * wave(t, 2, -0.12), z=-2 * breath)
    p.add("ForeArm.L", x=-5 * wave(t, 2, -0.2))
    p.add("Hand.L", x=-20 * pulse(t, 0.78, 0.08) - 6 * pulse(t, 0.86, 0.04))
    p.add("Moss.L", x=4 * wave(t, 1, -0.2), z=3 * wave(t, 2, 0.1))
    p.add("Moss.R", x=4 * wave(t, 1, -0.3), z=3 * wave(t, 2, 0.2))
    return p


def walk(t):
    """Шаг (1.1 сек): переваливается с ноги на ногу, руки тяжело качаются, мох мотается."""
    p = Pose(STANCE)
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.1)
    core_glow(p, t, beats=2)
    p.move("Hips", z=-0.05 + 0.03 * bounce, x=0.04 * a)
    p.add("Hips", y=8 * a, z=5 * a)
    p.set("Thigh.R", -12 - 28 * a, 0, 10)
    p.set("Thigh.L", -12 + 28 * a, 0, -10)
    p.set("Shin.R", 22 + 32 * max(0.0, c), 0, 0)
    p.set("Shin.L", 22 + 32 * max(0.0, -c), 0, 0)
    p.set("Foot.R", -8 - 12 * a, 0, 8)
    p.set("Foot.L", -8 + 12 * a, 0, -8)
    p.set("Spine", 18, -8 - 8 * a, -4 * a)
    p.set("Chest", 12, -6 - 6 * a, -3 * a)
    p.set("Head", -18 + 3 * bounce, 10 + 8 * a, 0)
    p.add("UpperArm.R", x=18 * a)
    p.add("ForeArm.R", x=-8 * wave(t, 1, 0.1))
    p.add("UpperArm.L", x=-18 * a)
    p.add("ForeArm.L", x=8 * wave(t, 1, 0.1))
    p.add("Jaw", x=4 + 4 * bounce)
    p.add("Moss.L", x=14 * wave(t, 2, -0.15), z=8 * a)
    p.add("Moss.R", x=14 * wave(t, 2, -0.2), z=8 * a)
    return p


def attack(t):
    """Размах сучьями (1 сек): отводит правую руку далеко назад → широкий мах поперёк (удар к 0.4 сек) → пронос → стойка."""
    p = Pose({}, {})
    K = [0.0, 0.22, 0.34, 0.42, 0.62, 1.0]   # стойка, замах, пауза, удар, пронос, стойка
    S = STANCE

    def tr(bone, wind, hold, hit_, follow):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], wind), (K[2], hold), (K[3], hit_),
                                (K[4], follow), (K[5], S.get(bone, (0, 0, 0)))]))

    tr("Spine", (6, -34, 0), (4, -38, 0), (22, 30, 0), (24, 44, 0))
    tr("Chest", (4, -26, 0), (2, -30, 0), (14, 26, 0), (14, 34, 0))
    tr("Head", (-10, 40, 0), (-8, 44, 0), (-26, -30, 0), (-24, -40, 0))
    tr("UpperArm.R", (10, 0, 84), (16, 0, 90), (-78, 0, 40), (-84, 0, -24))
    tr("ForeArm.R", (-30, 0, 0), (-24, 0, 0), (-8, 0, 0), (-26, 0, 0))
    tr("Hand.R", (20, 0, 0), (26, 0, 0), (-10, 0, 0), (-20, 0, 0))
    tr("UpperArm.L", (-56, 0, -30), (-60, 0, -34), (4, 0, -40), (14, 0, -44))
    tr("ForeArm.L", (-60, 0, 0), (-64, 0, 0), (-50, 0, 0), (-46, 0, 0))
    tr("Thigh.L", (-28, 0, -10), (-30, 0, -10), (-34, 0, -10), (-30, 0, -10))
    tr("Shin.L", (34, 0, 0), (36, 0, 0), (40, 0, 0), (36, 0, 0))
    tr("Thigh.R", (10, 0, 14), (12, 0, 14), (-6, 0, 12), (-2, 0, 12))
    tr("Shin.R", (22, 0, 0), (22, 0, 0), (26, 0, 0), (24, 0, 0))
    tr("Foot.L", (-4, 0, 0), (-4, 0, 0), (-4, 0, 0), (-4, 0, 0))
    tr("Foot.R", (-24, 0, 12), (-26, 0, 12), (-14, 0, 12), (-18, 0, 12))
    tr("Jaw", (4, 0, 0), (2, 0, 0), (34, 0, 0), (20, 0, 0))
    tr("Moss.L", (-10, 0, -10), (-14, 0, -6), (-40, 0, 24), (-30, 0, 10))
    tr("Moss.R", (-10, 0, -10), (-14, 0, -6), (-40, 0, 24), (-30, 0, 10))
    core_glow(p, t, beats=2, extra=0.4 * pulse(t, K[3], 0.12))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.06), (K[2], 0.07), (K[3], -0.16), (K[4], -0.14), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], -0.02), (K[3], -0.12), (K[4], -0.10), (1, -0.04)]))
    return p


def attack2(t):
    """Подземные корни (1.1 сек): воздевает обе руки → вбивает когти в землю перед собой (к 0.4 сек),
    ядро вспыхивает → вырывает руки и распрямляется."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.30, 0.38, 0.66, 1.0]    # стойка, воздел, пауза, вбил, держит, стойка
    S = STANCE

    def tr(bone, raise_, hold, slam, stay):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], raise_), (K[2], hold), (K[3], slam),
                                (K[4], stay), (K[5], S.get(bone, (0, 0, 0)))]))

    tr("Spine", (-10, 0, 0), (-12, 0, 0), (40, 0, 0), (38, 0, 0))
    tr("Chest", (-10, 0, 0), (-12, 0, 0), (26, 0, 0), (24, 0, 0))
    tr("Head", (-30, 0, 0), (-32, 0, 0), (-40, 0, 0), (-44, 0, 0))
    tr("UpperArm.R", (-150, 0, 26), (-156, 0, 28), (-58, 0, 10), (-56, 0, 10))
    tr("ForeArm.R", (-20, 0, 0), (-16, 0, 0), (-8, 0, 0), (-10, 0, 0))
    tr("Hand.R", (-30, 0, 0), (-34, 0, 0), (10, 0, 0), (6, 0, 0))
    tr("UpperArm.L", (-150, 0, -26), (-156, 0, -28), (-58, 0, -10), (-56, 0, -10))
    tr("ForeArm.L", (-20, 0, 0), (-16, 0, 0), (-8, 0, 0), (-10, 0, 0))
    tr("Hand.L", (-30, 0, 0), (-34, 0, 0), (10, 0, 0), (6, 0, 0))
    tr("Thigh.L", (-14, 0, -12), (-12, 0, -12), (-50, 0, -14), (-48, 0, -14))
    tr("Shin.L", (18, 0, 0), (16, 0, 0), (66, 0, 0), (64, 0, 0))
    tr("Thigh.R", (-4, 0, 12), (-2, 0, 12), (-40, 0, 14), (-38, 0, 14))
    tr("Shin.R", (14, 0, 0), (12, 0, 0), (60, 0, 0), (58, 0, 0))
    tr("Foot.L", (-4, 0, 0), (-4, 0, 0), (-16, 0, 0), (-16, 0, 0))
    tr("Foot.R", (-10, 0, 12), (-10, 0, 12), (-20, 0, 12), (-20, 0, 12))
    tr("Jaw", (20, 0, 0), (24, 0, 0), (40, 0, 0), (30, 0, 0))
    tr("Moss.L", (20, 0, 0), (10, 0, 0), (-70, 0, 0), (-50, 0, 0))
    tr("Moss.R", (20, 0, 0), (10, 0, 0), (-70, 0, 0), (-50, 0, 0))
    surge = track(t, [(0, 0), (K[2], 0.1), (K[3] + 0.04, 1), (K[4], 0.7), (1, 0)])
    core_glow(p, t, beats=6, extra=0.55 * surge)
    shake = pulse(t, K[3] + 0.03, 0.06)
    p.move("Root", y=-0.05 * surge)
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], 0.02), (K[2], 0.03), (K[3], -0.30), (K[4], -0.28), (1, -0.04)]) - 0.03 * shake)
    return p


def hit(t):
    """Получил удар (0.5 сек): ствол отшатывается, голова мотается с опозданием, мох взлетает."""
    p = stance()
    snap = track(t, [(0, 0), (0.2, 1), (0.5, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.36, 1), (0.6, -0.3), (0.8, 0.1), (1, 0)])
    core_glow(p, t, beats=1, extra=0.3 * snap)
    p.move("Root", y=0.10 * snap)
    p.move("Hips", z=-0.04 * snap)
    p.add("Spine", x=-22 * snap, y=10 * snap)
    p.add("Chest", x=-12 * snap)
    p.add("Head", x=-24 * whip, y=-16 * snap, z=8 * whip)
    p.add("Jaw", x=26 * snap)
    p.add("UpperArm.R", x=20 * snap, z=18 * snap)
    p.add("UpperArm.L", x=34 * snap, z=-22 * snap)
    p.add("ForeArm.L", x=20 * snap)
    p.add("Thigh.L", x=10 * snap)
    p.add("Thigh.R", x=-12 * snap)
    p.add("Moss.L", x=-40 * whip)
    p.add("Moss.R", x=-40 * whip)
    return p


def death(t):
    """Гибель (1.7 сек): хватается за ядро, оно гаснет; падает на колени и валится ничком, как срубленный; судорога в руке."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.45, 0.72, 1.0]          # стойка, схватился, на коленях, упал, затих
    S = STANCE

    def tr(bone, clutch, kneel, fall, rest):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], clutch), (K[2], kneel), (K[3], fall), (K[4], rest)]))

    tr("Spine", (-14, 10, 0), (24, 0, 4), (10, 0, 0), (8, 0, 0))
    tr("Chest", (-8, 6, 0), (20, 0, 4), (6, 0, 0), (4, 0, 0))
    tr("Head", (-30, -16, 0), (30, 10, 8), (-30, 30, 0), (-24, 36, 0))
    tr("Jaw", (36, 0, 0), (16, 0, 0), (30, 0, 0), (22, 0, 0))
    tr("UpperArm.R", (-50, 0, -20), (-30, 0, 10), (-150, 0, 30), (-158, 0, 36))
    tr("ForeArm.R", (-110, 0, 0), (-60, 0, 0), (-20, 0, 0), (-10, 0, 0))
    tr("UpperArm.L", (-50, 0, 20), (-20, 0, -20), (-130, 0, -50), (-136, 0, -56))
    tr("ForeArm.L", (-110, 0, 0), (-50, 0, 0), (-40, 0, 0), (-30, 0, 0))
    tr("Thigh.L", (-10, 0, -10), (-70, 0, -12), (-10, 0, -14), (-4, 0, -16))
    tr("Shin.L", (20, 0, 0), (120, 0, 0), (30, 0, 0), (14, 0, 0))
    tr("Thigh.R", (0, 0, 12), (-60, 0, 14), (-6, 0, 16), (0, 0, 18))
    tr("Shin.R", (20, 0, 0), (116, 0, 0), (24, 0, 0), (10, 0, 0))
    tr("Foot.L", (-4, 0, 0), (30, 0, 0), (40, 0, 0), (40, 0, 0))
    tr("Foot.R", (-10, 0, 12), (30, 0, 12), (40, 0, 12), (40, 0, 12))
    tr("Moss.L", (-40, 0, 0), (10, 0, 0), (60, 0, 0), (70, 0, 0))
    tr("Moss.R", (-40, 0, 0), (10, 0, 0), (60, 0, 0), (70, 0, 0))
    lean = track(t, [(0, 0), (K[1], -6), (K[2], 8), (K[3], 84), (K[3] + 0.05, 79), (K[3] + 0.1, 85), (1, 85)])
    p.set("Root", lean, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.08), (K[2], 0.0), (K[3], -0.35), (1, -0.35)]),
           z=track(t, [(0, 0), (K[2], 0), (K[3], 0.30), (1, 0.30)]))
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], -0.02), (K[2], -0.40), (K[3], -0.10), (1, -0.10)]))
    spasm = pulse(t, 0.88, 0.05)
    p.add("ForeArm.R", x=-20 * spasm)
    p.add("Hand.R", x=-30 * spasm)
    fade = track(t, [(0, 1), (K[1], 1.5), (K[2], 0.9), (K[3], 0.45), (1, 0.3)])
    p.size("Core", fade * (1.0 + 0.12 * wave(t, 8) * (1 - t)))
    return p


def build_actions(rig):
    kw = {"scale_bones": ("Core",)}
    k.bake(rig, "Idle", 110, idle, cyclic=True, **kw)
    k.bake(rig, "Walk", 34, walk, cyclic=True, **kw)
    k.bake(rig, "Attack", 30, attack, **kw)
    k.bake(rig, "Attack2", 33, attack2, **kw)
    k.bake(rig, "Hit", 15, hit, **kw)
    k.bake(rig, "Death", 50, death, **kw)


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
    glb = args[0] if args else os.path.join(here, "..", "mossy_treant.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "mossy_treant.blend")
    build(glb, blend)
