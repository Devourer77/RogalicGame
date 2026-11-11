# Гоблин-шаман — тварь Раскола (~1.1 м с рогами). Маска-шлем из коры с рогами-сучьями и синими
# перьями, рваная серо-зелёная накидка, кривой посох выше роста, над развилкой посоха парит
# светящийся осколок Раскола. Кости и лилового нет: кость — знак Культа, лиловый — цвет Мага.
# Тело — общее гоблинское (goblin_kin.py). Смотрит в -Y.
#
# Запуск: python3 build_goblin_shaman.py out.glb out.blend (нужен модуль bpy)
# или в Blender: Scripting → Open → Run Script. Рядом должны лежать char_kit.py и goblin_kin.py.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
import goblin_kin as g
from char_kit import Pose, wave, track, track3, pulse

NAME = "GoblinShaman"

# Посох проходит сквозь правый кулак (в исходной позе рука висит, кулак на высоте 0.28)
SX, SY, FIST = -0.225, -0.03, 0.28
STAFF_LOW, STAFF_TOP = FIST - 0.47, FIST + 0.50    # низ уходит «под землю»: в стойке кулак поднят
CRYSTAL = (SX + 0.03, SY - 0.02, FIST + 0.72)      # осколок парит над развилкой


def bipyramid(name, c, r, h, material, bone):
    """Гранёный кристалл: две четырёхгранные пирамиды основаниями друг к другу."""
    k.limb(name + "Up", c, (c[0], c[1], c[2] + h), r, 0.002, material, bone, segs=4)
    k.limb(name + "Dn", (c[0], c[1], c[2] - h * 0.7), c, 0.002, r, material, bone, segs=4)


def build_mesh():
    M = g.materials("Shaman")
    leather, rift = M["leather"], M["rift"]
    bark = k.mat("Shaman_Bark", (0.36, 0.27, 0.19), rough=0.95)          # кора маски и рогов
    bark_cut = k.mat("Shaman_BarkCut", (0.56, 0.46, 0.33), rough=0.9)    # светлые сколы
    cloak = k.mat("Shaman_Cloak", (0.25, 0.33, 0.33), rough=0.95)        # серо-зелёная накидка
    rag = k.mat("Shaman_Rag", (0.41, 0.48, 0.43), rough=0.95)            # светлый слой лохмотьев
    feather = k.mat("Shaman_Feather", (0.25, 0.43, 0.66), rough=0.8)     # синие перья
    feather2 = k.mat("Shaman_FeatherPale", (0.56, 0.70, 0.80), rough=0.8)
    wood = k.mat("Shaman_Staff", (0.33, 0.24, 0.17), rough=0.95)
    shard = k.mat("Shaman_Shard", (0.30, 0.95, 0.85), rough=0.3, emit=2.2)   # осколок Раскола
    g.body(M, vest=False)

    # Маска-шлем из коры: шапка поверх черепа, тяжёлый козырёк над глазами, щитки на скулах
    k.sphere("MaskCap", 0.168, (0, -0.02, 0.915), bark, "Head", scale=(1.17, 1.09, 0.62), segs=6, rings=4)
    k.box("MaskBrow", (0.31, 0.06, 0.075), (0, -0.172, 0.945), bark, "Head", rot=(16, 0, 0))
    for s in (-1, 1):
        k.box(f"MaskCheek{s}", (0.05, 0.05, 0.10), (0.142 * s, -0.135, 0.835), bark, "Head", rot=(0, 0, 14 * s))
        # Рога-сучья: ствол, верхний отросток и боковой
        k.limb(f"Horn{s}", (0.10 * s, -0.03, 0.98), (0.19 * s, -0.05, 1.10), 0.036, 0.02, bark, "Head", segs=4)
        k.limb(f"HornTip{s}", (0.19 * s, -0.05, 1.10), (0.155 * s, -0.10, 1.20), 0.02, 0.004, bark, "Head", segs=4)
        k.limb(f"HornTine{s}", (0.155 * s, -0.042, 1.05), (0.265 * s, -0.02, 1.11), 0.016, 0.004, bark_cut, "Head", segs=3)
    # Перья на затылке — веером, на своей кости
    quill = [(-0.022, 0.0), (0.022, 0.0), (0.036, 0.12), (0.0, 0.21), (-0.036, 0.12)]
    for i, (dx, lean, m) in enumerate([(-0.08, -0.55, feather), (0.0, 0.0, feather2), (0.08, 0.55, feather)]):
        k.plate(f"Feather{i}", quill, 0.012, (dx, 0.13, 0.93), (1, 0, -lean * 0.3), (lean * 0.4, 0.75, 1), m, "Feathers")

    # Накидка: оплечье, рваное полотнище на спине (своя кость) и светлые лохмотья поверх
    k.limb("Mantle", (0, 0.012, 0.60), (0, 0.0, 0.735), 0.218, 0.125, cloak, "Chest", segs=6)
    cape = [(-0.20, 0.0), (0.20, 0.0), (0.25, -0.30), (0.13, -0.44), (0.05, -0.34), (-0.04, -0.48), (-0.13, -0.35), (-0.23, -0.41)]
    k.plate("Cape", cape, 0.024, (0, 0.155, 0.70), (1, 0, 0), (0, -0.2, 1), cloak, "Cape")
    tatter = [(-0.15, 0.0), (0.15, 0.0), (0.17, -0.15), (0.07, -0.24), (0.0, -0.16), (-0.09, -0.26), (-0.17, -0.17)]
    k.plate("CapeRag", tatter, 0.02, (0, 0.175, 0.705), (1, 0, 0), (0, -0.22, 1), rag, "Cape")
    for s in (-1, 1):
        flap = [(0.0, 0.0), (0.13, 0.0), (0.15, -0.16), (0.07, -0.11), (0.02, -0.19)]
        k.plate(f"ShoulderRag{s}", flap if s > 0 else [(-a, b) for a, b in reversed(flap)], 0.02,
                (0.10 * s, -0.02, 0.715), (1, 0, 0), (0, 0.5 , 1), rag, "Chest")
    # Тряпка на поясе спереди (своя кость) и амулет — щепка с бирюзовой трещиной
    cloth = [(-0.075, 0.0), (0.075, 0.0), (0.085, -0.19), (0.01, -0.27), (-0.065, -0.18)]
    k.plate("Loincloth", cloth, 0.02, (0, -0.158, 0.475), (1, 0, 0), (0, 0.08, 1), rag, "Rag")
    k.box("Amulet", (0.06, 0.02, 0.075), (0, -0.165, 0.60), bark_cut, "Chest", rot=(0, 0, 12))
    k.crack("AmuletCrack", [(0.0, 0.025), (0.012, 0.0), (-0.008, -0.025)], (0, -0.178, 0.60),
            (1, 0, 0), (0, 0, 1), rift, "Chest", width=0.01, depth=0.01)

    # Посох: кривое древко, обмотка у кулака, развилка-рогатка наверху и перо на шнурке
    k.limb("StaffLow", (SX, SY, STAFF_LOW), (SX - 0.012, SY, FIST + 0.12), 0.024, 0.021, wood, "Staff", segs=5)
    k.limb("StaffMid", (SX - 0.012, SY, FIST + 0.12), (SX + 0.03, SY - 0.01, FIST + 0.36), 0.021, 0.019, wood, "Staff", segs=5)
    k.limb("StaffTop", (SX + 0.03, SY - 0.01, FIST + 0.36), (SX + 0.01, SY - 0.01, STAFF_TOP), 0.019, 0.018, wood, "Staff", segs=5)
    k.limb("ForkA", (SX + 0.01, SY - 0.01, STAFF_TOP), (SX - 0.07, SY - 0.02, STAFF_TOP + 0.15), 0.018, 0.006, wood, "Staff", segs=4)
    k.limb("ForkB", (SX + 0.01, SY - 0.01, STAFF_TOP), (SX + 0.12, SY - 0.02, STAFF_TOP + 0.13), 0.018, 0.006, wood, "Staff", segs=4)
    k.limb("StaffWrap", (SX, SY, FIST - 0.08), (SX, SY, FIST + 0.08), 0.03, 0.03, leather, "Staff", segs=4)
    k.plate("StaffFeather", quill, 0.01, (SX + 0.03, SY + 0.02, FIST + 0.30), (1, 0, 0), (0.25, 0.3, -1), feather, "Staff")
    # Осколок Раскола — парит и вращается на своей кости; рядом маленький
    bipyramid("Shard", CRYSTAL, 0.058, 0.11, shard, "Crystal")
    bipyramid("ShardA", (CRYSTAL[0] + 0.1, CRYSTAL[1], CRYSTAL[2] + 0.05), 0.02, 0.04, shard, "Crystal")
    return k.join_parts("GoblinShamanMesh")


BONES = g.bones({
    "Feathers": ((0, 0.13, 0.93), (0, 0.24, 1.10), "Head"),
    "Cape": ((0, 0.155, 0.70), (0, 0.22, 0.34), "Chest"),
    "Rag": ((0, -0.158, 0.475), (0, -0.17, 0.25), "Hips"),
    "Staff": ((SX, SY, FIST), (SX, SY, FIST + 0.36), "Hand.R"),
    "Crystal": ((CRYSTAL[0], CRYSTAL[1], CRYSTAL[2] - 0.08), (CRYSTAL[0], CRYSTAL[1], CRYSTAL[2] + 0.08), "Staff"),
})

# Стойка: сгорбился и опирается на посох, выставленный вперёд правой рукой; левая рука
# со скрюченными пальцами поднята к осколку. Голова повёрнута к врагу.
ARM_R = -38 + -58                      # насколько правая рука вынесена вперёд (плечо + локоть)
STANCE = {
    "Spine": (20, 12, 0), "Chest": (12, 8, 0), "Head": (-24, -18, -3),
    "Thigh.R": (-34, 0, 10), "Shin.R": (42, 0, 0), "Foot.R": (8, 0, 0),
    "Thigh.L": (-4, 0, -12), "Shin.L": (32, 0, 0), "Foot.L": (28, 0, 0),
    "UpperArm.R": (-38, 0, 34), "ForeArm.R": (-58, 0, 0), "Hand.R": (0, 0, 0),
    "Staff": (-ARM_R - 32 + 6, 0, -8),   # посох стоит почти отвесно (−32 — наклон спины)
    "UpperArm.L": (-64, 20, -22), "ForeArm.L": (-70, 0, 0), "Hand.L": (-20, 0, 0),
    "Ear.R": (4, 0, 0), "Ear.L": (4, 0, 0),
    "Cape": (-24, 0, 0), "Rag": (0, 0, 0), "Feathers": (0, 0, 0), "Crystal": (0, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.05)}
LOC = ("Root", "Hips", "Crystal")       # кости, которым пишется сдвиг


def stance():
    return Pose(STANCE, STANCE_LOC)


def float_shard(p, t, spins=1, lift=0.0, grow=1.0):
    """Осколок парит: вращается вокруг своей оси, покачивается вверх-вниз, может расти (пульс)."""
    p.set("Crystal", 0, 360 * spins * t, 0)
    p.move("Crystal", z=0.025 * wave(t, 2) + lift)
    p.size("Crystal", grow)


def idle(t):
    """Покой (3 сек): дышит, озирается, осколок вращается над посохом, пальцы левой руки «плетут» чары."""
    p = stance()
    breath, sway = g.idle_base(p, t)
    float_shard(p, t, spins=1, grow=1.0 + 0.08 * wave(t, 3))
    p.add("Staff", x=2.5 * sway, z=2 * breath)
    p.add("UpperArm.R", x=2 * breath)
    weave = wave(t, 3, 0.1)                 # левая рука водит над осколком
    p.add("UpperArm.L", x=-5 * weave, z=-4 * wave(t, 1, 0.3))
    p.add("ForeArm.L", x=-9 * weave + 3 * breath)
    p.add("Hand.L", x=-16 * pulse(t, 0.5, 0.08) + 8 * weave)
    p.add("Cape", x=3 * wave(t, 1, -0.2), z=3 * wave(t, 2, 0.15))
    p.add("Rag", x=3 * wave(t, 1, -0.3))
    p.add("Feathers", x=5 * wave(t, 2, -0.15) - 14 * pulse(t, 0.2, 0.06), z=4 * sway)
    return p


def walk(t):
    """Ходьба (0.67 сек): семенит, пригнувшись, посох несёт перед собой, накидка и перья болтаются."""
    p = Pose(STANCE)
    a, bounce = g.walk_base(p, t, lean=24)
    float_shard(p, t, spins=1)
    p.set("UpperArm.R", -44 + 6 * a, 0, 14)
    p.set("ForeArm.R", -50 + 5 * bounce, 0, 0)
    p.set("Staff", 94 - 36 - 6 * a + 14, 0, -6 + 5 * a)
    p.add("UpperArm.L", x=-14 * a + 10)
    p.add("ForeArm.L", x=8 * a)
    p.set("Cape", -8 + 12 * wave(t, 2, -0.15), 0, 6 * a)
    p.add("Rag", x=14 * wave(t, 2, -0.2))
    p.add("Feathers", x=-16 + 10 * wave(t, 2, -0.2))
    return p


def attack(t):
    """Болотный луч (0.87 сек): отводит посох назад → выбрасывает вперёд, осколок вспыхивает (к 0.4 сек) → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.18, 0.36, 0.46, 0.64, 1.0]   # стойка, замах, пауза, выпад, пронос, стойка
    S = STANCE

    def tr(bone, wind, hold, thrust, follow):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], wind), (K[2], hold), (K[3], thrust),
                                (K[4], follow), (K[5], S.get(bone, (0, 0, 0)))]))

    tr("Spine", (2, 26, 0), (-2, 30, 0), (32, -10, 0), (30, -12, 0))
    tr("Chest", (2, 16, 0), (-2, 18, 0), (16, -8, 0), (14, -8, 0))
    tr("Head", (-10, -30, 0), (-6, -34, 0), (-40, 8, 0), (-36, 8, 0))
    tr("UpperArm.R", (-10, 0, 34), (0, 0, 40), (-84, 0, 6), (-80, 0, 4))
    tr("ForeArm.R", (-100, 0, 0), (-110, 0, 0), (-8, 0, 0), (-12, 0, 0))
    tr("Staff", (110 - 4 + 20, 0, -10), (110 + 2 + 26, 0, -10), (92 - 48 + 46, 0, 0), (92 - 44 + 40, 0, 0))
    tr("UpperArm.L", (-40, 20, -30), (-34, 20, -36), (-76, 10, -8), (-70, 10, -10))
    tr("ForeArm.L", (-90, 0, 0), (-96, 0, 0), (-16, 0, 0), (-22, 0, 0))
    tr("Hand.L", (-10, 0, 0), (-10, 0, 0), (-30, 0, 0), (-24, 0, 0))
    tr("Thigh.R", (-30, 0, 10), (-26, 0, 10), (-56, 0, 10), (-52, 0, 10))
    tr("Shin.R", (44, 0, 0), (40, 0, 0), (62, 0, 0), (58, 0, 0))
    tr("Foot.R", (8, 0, 0), (4, 0, 0), (4, 0, 0), (8, 0, 0))
    tr("Thigh.L", (-8, 0, -12), (-4, 0, -12), (22, 0, -12), (16, 0, -12))
    tr("Shin.L", (36, 0, 0), (34, 0, 0), (30, 0, 0), (32, 0, 0))
    tr("Foot.L", (28, 0, 0), (26, 0, 0), (10, 0, 0), (20, 0, 0))
    tr("Jaw", (-4, 0, 0), (-10, 0, 0), (-36, 0, 0), (-22, 0, 0))
    tr("Cape", (-10, 0, 8), (-4, 0, 10), (-60, 0, -6), (-40, 0, 0))
    tr("Rag", (10, 0, 0), (6, 0, 0), (-30, 0, 0), (-14, 0, 0))
    tr("Feathers", (10, 0, 0), (14, 0, 0), (-34, 0, 0), (-10, 0, 0))
    flash = pulse(t, K[3] + 0.02, 0.12)
    float_shard(p, t, spins=2, lift=0.05 * flash, grow=1.0 + 0.9 * flash)
    back = track(t, [(0, 0), (K[1], -8), (K[2], 18), (K[3], 26), (K[3] + 0.08, -18), (K[4] + 0.1, 6), (1, 0)])
    p.set("Ear.L", 4, 0, back)
    p.set("Ear.R", 4, 0, -back)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.05), (K[2], 0.06), (K[3], -0.14), (K[4], -0.15), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.05), (K[1], -0.03), (K[2], -0.03), (K[3], -0.10), (K[4], -0.10), (1, -0.05)]))
    return p


def cast(t):
    """Зов Раскола (1 сек): воздевает посох обеими руками, осколок взмывает и раздувается (к 0.35 сек),
    потом шаман бьёт посохом оземь и возвращается в стойку."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.35, 0.55, 0.72, 1.0]    # стойка, присел, воздел, держит, удар оземь, стойка
    S = STANCE

    def tr(bone, crouch, raise_, hold, slam):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], crouch), (K[2], raise_), (K[3], hold),
                                (K[4], slam), (K[5], S.get(bone, (0, 0, 0)))]))

    tr("Spine", (30, 6, 0), (-14, 0, 0), (-16, 0, 0), (26, 8, 0))
    tr("Chest", (16, 4, 0), (-12, 0, 0), (-14, 0, 0), (14, 6, 0))
    tr("Head", (-10, -8, 0), (-46, 0, 0), (-50, 0, 4), (-20, -12, 0))
    tr("UpperArm.R", (-30, 0, 10), (-150, 0, 22), (-154, 0, 24), (-46, 0, 14))
    tr("ForeArm.R", (-80, 0, 0), (-20, 0, 0), (-16, 0, 0), (-50, 0, 0))
    tr("Staff", (110 - 46 + 4, 0, -6), (170 + 26 - 6, 0, -10), (170 + 30 - 4, 0, -10), (96 - 40 + 2, 0, -6))
    tr("UpperArm.L", (-50, 20, -16), (-146, 0, -30), (-150, 0, -34), (-60, 20, -20))
    tr("ForeArm.L", (-90, 0, 0), (-30, 0, 0), (-24, 0, 0), (-70, 0, 0))
    tr("Hand.L", (-10, 0, 0), (-30, 0, 0), (-34, 0, 0), (-20, 0, 0))
    tr("Thigh.R", (-48, 0, 10), (-20, 0, 12), (-18, 0, 12), (-40, 0, 10))
    tr("Shin.R", (64, 0, 0), (26, 0, 0), (24, 0, 0), (50, 0, 0))
    tr("Foot.R", (10, 0, 0), (2, 0, 0), (2, 0, 0), (8, 0, 0))
    tr("Thigh.L", (-18, 0, -12), (4, 0, -14), (6, 0, -14), (-8, 0, -12))
    tr("Shin.L", (52, 0, 0), (16, 0, 0), (14, 0, 0), (38, 0, 0))
    tr("Foot.L", (30, 0, 0), (14, 0, 0), (12, 0, 0), (28, 0, 0))
    tr("Jaw", (-4, 0, 0), (-40, 0, 0), (-44, 0, 0), (-10, 0, 0))
    tr("Cape", (-36, 0, 0), (30, 0, 0), (24, 0, 6), (-40, 0, 0))
    tr("Rag", (-20, 0, 0), (16, 0, 0), (10, 0, 0), (-20, 0, 0))
    tr("Feathers", (-10, 0, 0), (26, 0, 0), (16, 0, 6), (-24, 0, 0))
    swell = track(t, [(0, 0), (K[1], 0), (K[2], 1), (K[3], 0.85), (K[4], 0.1), (1, 0)])
    float_shard(p, t, spins=3, lift=0.10 * swell, grow=1.0 + 1.1 * swell + 0.15 * swell * wave(t, 12))
    up = track(t, [(0, 4), (K[1], -10), (K[2], 34), (K[3], 30), (K[4], -16), (1, 4)])
    p.set("Ear.L", up, 0, 0)
    p.set("Ear.R", up, 0, 0)
    p.move("Hips", z=track(t, [(0, -0.05), (K[1], -0.12), (K[2], 0.0), (K[3], 0.0), (K[4], -0.10), (1, -0.05)]))
    return p


def hit(t):
    """Получил удар (0.47 сек): отбрасывает назад, голова мотается, посох и накидка вразлёт."""
    p = stance()
    snap, whip = g.hit_base(p, t)
    float_shard(p, t, spins=1, lift=0.04 * snap)
    p.add("UpperArm.R", x=24 * snap, z=20 * snap)
    p.add("ForeArm.R", x=20 * snap)
    p.add("Staff", x=-30 * snap, z=-16 * whip)
    p.add("UpperArm.L", x=40 * snap, z=-30 * snap)
    p.add("ForeArm.L", x=30 * snap)
    p.add("Cape", x=-46 * whip)
    p.add("Rag", x=-30 * whip)
    p.add("Feathers", x=-40 * whip)
    return p


def death(t):
    """Гибель (1.3 сек): отшатнулся, рухнул на колени, упал на спину; посох выпадает, осколок гаснет (съёживается)."""
    p = Pose({}, {})
    tr, spasm = g.death_base(p, t, STANCE)
    tr("UpperArm.R", (-20, 0, 40), (10, 0, 30), (-10, 0, 74), (14, 0, 82))
    tr("ForeArm.R", (-50, 0, 0), (-30, 0, 0), (-30, 0, 0), (-14, 0, 0))
    tr("Staff", (80, 0, -20), (60, 0, -40), (20, 0, -70), (4, 0, -84))
    tr("UpperArm.L", (-10, 0, -50), (16, 0, -30), (-6, 0, -70), (16, 0, -80))
    tr("ForeArm.L", (-50, 0, 0), (-40, 0, 0), (-30, 0, 0), (-20, 0, 0))
    tr("Cape", (-50, 0, 0), (10, 0, 0), (-30, 0, 0), (-10, 0, 0))
    tr("Rag", (-20, 0, 0), (20, 0, 0), (-40, 0, 0), (-50, 0, 0))
    tr("Feathers", (-30, 0, 0), (30, 0, 0), (-40, 0, 0), (-50, 0, 0))
    fade = track(t, [(0, 1), (0.3, 1.2), (0.7, 0.5), (1, 0.3)])
    p.set("Crystal", 0, 200 * t, 0)
    p.move("Crystal", z=track(t, [(0, 0), (0.3, 0.03), (0.8, -0.12), (1, -0.14)]))
    p.size("Crystal", fade)
    p.add("ForeArm.L", x=-24 * spasm)
    return p


def build_actions(rig):
    kw = {"loc_bones": LOC, "scale_bones": ("Crystal",)}
    k.bake(rig, "Idle", 90, idle, cyclic=True, **kw)
    k.bake(rig, "Walk", 20, walk, cyclic=True, **kw)
    k.bake(rig, "Attack", 26, attack, **kw)
    k.bake(rig, "Cast", 30, cast, **kw)
    k.bake(rig, "Hit", 14, hit, **kw)
    k.bake(rig, "Death", 40, death, **kw)


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
    glb = args[0] if args else os.path.join(here, "..", "goblin_shaman.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "goblin_shaman.blend")
    build(glb, blend)
