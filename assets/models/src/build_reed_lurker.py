# Камышовый скрытень — тварь Раскола (~1.3 м, в стойке сгорблен ниже метра). Худое серо-зелёное тело
# с длинными тонкими руками (три крючковатых пальца) и ногами; спина, плечи и голова укрыты лохматым плащом
# из сухого камыша, травы и тины — издали это просто ком камыша. Из-под гривы смотрят два бирюзовых глаза,
# на предплечьях бирюзовые трещины. Сверху торчат стебли рогоза с бурыми початками.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Анимации: Idle, Walk, Attack (прыжок из засады с ударом когтями), Hit, Death.
# Запуск: python3 build_reed_lurker.py out/reed_lurker.glb out/reed_lurker.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "ReedLurker"
SIDES = (("R", -1), ("L", 1))


def build_mesh():
    skin = k.mat("Lurker_Skin", (0.42, 0.46, 0.40), rough=0.85)
    skin_d = k.mat("Lurker_SkinDark", (0.29, 0.32, 0.28), rough=0.9)
    reed = k.mat("Lurker_Reed", (0.60, 0.52, 0.36), rough=1.0)
    reed_d = k.mat("Lurker_ReedDark", (0.44, 0.38, 0.27), rough=1.0)
    mud = k.mat("Lurker_Mud", (0.40, 0.35, 0.25), rough=1.0)
    moss = k.mat("Lurker_Moss", (0.38, 0.46, 0.26), rough=1.0)
    cattail = k.mat("Lurker_Cattail", (0.38, 0.28, 0.19), rough=1.0)
    claw = k.mat("Lurker_Claw", (0.22, 0.22, 0.2), rough=0.6)
    rift = k.mat("Lurker_Rift", (0.30, 0.92, 0.82), rough=0.4, emit=1.4)

    # Худое тело
    k.limb("Pelvis", (0, 0, 0.78), (0, 0, 0.92), 0.12, 0.11, skin_d, "Hips", segs=6)
    k.limb("Torso", (0, 0, 0.92), (0, 0, 1.28), 0.12, 0.15, skin, "Chest", segs=6)
    # Лицо: узкая вытянутая морда, глаза
    k.limb("Muzzle", (0, -0.05, 1.42), (0, -0.2, 1.36), 0.075, 0.035, skin_d, "Head", segs=6)
    for side, s in SIDES:
        k.sphere(f"Eye.{side}", 0.022, (0.04 * s, -0.15, 1.45), rift, "Head", segs=4, rings=2)

    # Плащ из камыша и тины: ком грязи и мха на спине, «грива» на голове
    k.sphere("Cloak", 0.27, (0, 0.06, 1.18), mud, "Chest", scale=(1.15, 1.1, 1.0), segs=8, rings=5)
    k.sphere("CloakMoss", 0.14, (0.06, 0.06, 1.42), moss, "Chest", scale=(1.3, 1.2, 0.4), segs=6, rings=3)
    k.sphere("Mane", 0.14, (0, -0.04, 1.47), mud, "Head", scale=(1.1, 1.1, 0.9), segs=7, rings=4)
    # Стебли камыша: торчат во все стороны со спины и плеч, свисают гривой на лицо
    n = 0
    for ring, (zc, rad, tilt, cnt, bone) in enumerate([(1.4, 0.16, 0.95, 10, "Chest"), (1.22, 0.25, -0.35, 14, "Chest"),
                                                        (1.0, 0.25, -0.85, 12, "Chest"), (1.5, 0.1, 0.6, 8, "Head")]):
        for i in range(cnt):
            a = math.tau * i / cnt + ring * 0.4
            # спереди, у лица, стебли короче и свисают вниз (грива)
            front = math.sin(a) < -0.6
            base = (rad * math.cos(a), 0.06 + rad * math.sin(a), zc)
            length = 0.22 if front else 0.34 + 0.08 * ((i + ring) % 3)
            up = (-0.6 if front else tilt)
            tip = (base[0] + math.cos(a) * length * 0.7, base[1] + math.sin(a) * length * 0.7 + (0 if front else 0.08),
                   base[2] + up * length)
            k.limb(f"Reed{n}", base, tip, 0.032, 0.004, reed if (i + ring) % 2 else reed_d, bone, segs=3)
            n += 1
    # Рогоз с початками
    for i, (x, y) in enumerate([(0.06, 0.12), (-0.1, 0.08), (0.14, -0.02)]):
        b, t2 = (x, y, 1.42), (x * 1.6, y + 0.14, 1.85 - 0.05 * i)
        k.limb(f"Cattail{i}", b, t2, 0.01, 0.006, reed_d, "Chest", segs=3)
        k.limb(f"CattailHead{i}", (t2[0], t2[1], t2[2] - 0.12), t2, 0.022, 0.018, cattail, "Chest", segs=4)

    # Длинные тонкие руки с крючковатыми пальцами, ноги
    for side, s in SIDES:
        k.limb(f"UpperArm.{side}", (0.16 * s, 0, 1.24), (0.3 * s, -0.02, 0.92), 0.05, 0.04, skin, f"UpperArm.{side}", segs=5)
        k.limb(f"ForeArm.{side}", (0.3 * s, -0.02, 0.92), (0.36 * s, -0.06, 0.56), 0.04, 0.033, skin, f"ForeArm.{side}", segs=5)
        k.crack(f"ArmRift.{side}", [(0, 0), (0.06, 0.012), (0.14, -0.01), (0.22, 0.01)], (0.33 * s, -0.05, 0.84),
                (0.1 * s, -0.05, -1), (0, -1, 0), rift, f"ForeArm.{side}", width=0.012, depth=0.02)
        k.sphere(f"Hand.{side}", 0.04, (0.36 * s, -0.07, 0.53), skin_d, f"Hand.{side}", segs=5, rings=3)
        for f, (dx, dy) in enumerate([(-0.035, -0.04), (0.0, -0.06), (0.035, -0.04)]):
            a = (0.36 * s + dx, -0.07 + dy * 0.5, 0.51)
            k.limb(f"Finger{f}.{side}", a, (a[0] + dx * 0.6, a[1] + dy, 0.4), 0.014, 0.005, claw, f"Hand.{side}", segs=3)
        k.limb(f"Thigh.{side}", (0.09 * s, 0, 0.8), (0.12 * s, -0.02, 0.44), 0.06, 0.045, skin_d, f"Thigh.{side}", segs=5)
        k.limb(f"Shin.{side}", (0.12 * s, -0.02, 0.44), (0.12 * s, 0.02, 0.08), 0.045, 0.035, skin, f"Shin.{side}", segs=5)
        k.box(f"Foot.{side}", (0.08, 0.2, 0.05), (0.12 * s, -0.06, 0.03), skin_d, f"Foot.{side}")
    return k.join_parts("ReedLurkerMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Hips": ((0, 0, 0.8), (0, 0, 0.92), "Root"),
    "Spine": ((0, 0, 0.92), (0, 0, 1.08), "Hips"),
    "Chest": ((0, 0, 1.08), (0, 0, 1.3), "Spine"),
    "Head": ((0, -0.02, 1.32), (0, -0.02, 1.55), "Chest"),
}
for side, s in SIDES:
    BONES.update({
        f"UpperArm.{side}": ((0.16 * s, 0, 1.24), (0.3 * s, -0.02, 0.92), "Chest"),
        f"ForeArm.{side}": ((0.3 * s, -0.02, 0.92), (0.36 * s, -0.06, 0.56), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.36 * s, -0.06, 0.56), (0.36 * s, -0.08, 0.42), f"ForeArm.{side}"),
        f"Thigh.{side}": ((0.09 * s, 0, 0.8), (0.12 * s, -0.02, 0.44), "Hips"),
        f"Shin.{side}": ((0.12 * s, -0.02, 0.44), (0.12 * s, 0.02, 0.08), f"Thigh.{side}"),
        f"Foot.{side}": ((0.12 * s, 0.02, 0.08), (0.12 * s, -0.14, 0.03), f"Shin.{side}"),
    })

# Стойка: глубоко присел, корпус почти горизонтально, руки свисают к земле — ком камыша на ногах
STANCE = {
    "Hips": (20, 0, 0),
    "Spine": (24, 0, 0), "Chest": (16, 6, 0), "Head": (-40, -6, 0),
    "Thigh.L": (-60, 0, -14), "Shin.L": (90, 0, 0), "Foot.L": (-24, 0, 0),
    "Thigh.R": (-44, 0, 16), "Shin.R": (84, 0, 0), "Foot.R": (-36, 0, 0),
    "UpperArm.L": (-48, 0, -16), "ForeArm.L": (-10, 0, 0), "Hand.L": (-20, 0, 0),
    "UpperArm.R": (-30, 0, 22), "ForeArm.R": (-24, 0, 0), "Hand.R": (-14, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.26)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3 сек): почти неподвижен, как камыш; дыхание, редкие рывки головой, пальцы скребут землю,
    камыш на спине шевелится против ветра."""
    p = stance()
    breath = wave(t, 1)
    p.move("Hips", z=-0.26 + 0.01 * breath)
    p.add("Chest", x=2 * breath, z=3 * wave(t, 1, 0.25))
    look = track(t, [(0, 0), (0.3, 0), (0.33, 18), (0.6, 18), (0.63, -10), (0.86, -10), (0.9, 0), (1, 0)])
    p.add("Head", y=look)
    scratch = pulse(t, 0.48, 0.06) + pulse(t, 0.56, 0.06)
    p.add("Hand.R", x=-24 * scratch)
    p.add("ForeArm.R", x=-6 * scratch)
    p.add("UpperArm.L", x=4 * wave(t, 1, 0.4))
    return p


def walk(t):
    """Крадётся (0.7 сек): низко, на полусогнутых, руки подтягивают тело, как у зверя."""
    p = Pose(STANCE)
    a = wave(t, 1)
    p.move("Hips", z=-0.26 + 0.02 * wave(t, 2, 0.1), x=0.02 * a)
    p.add("Hips", y=6 * a)
    p.set("Thigh.R", -44 - 26 * a, 0, 16)
    p.set("Thigh.L", -60 + 26 * a, 0, -14)
    p.set("Shin.R", 84 + 20 * max(0.0, wave(t, 1, 0.25)), 0, 0)
    p.set("Shin.L", 90 + 20 * max(0.0, -wave(t, 1, 0.25)), 0, 0)
    p.add("UpperArm.L", x=-24 * a)
    p.add("UpperArm.R", x=24 * a)
    p.add("Chest", y=-6 * a)
    p.add("Head", y=6 * a)
    return p


def attack(t):
    """Прыжок из засады (0.8 сек): сжимается → бросок вперёд, руки с когтями расходятся (к 0.4 сек) →
    удар обеими руками вниз → приземлился."""
    p = Pose({}, {})
    K = [0.0, 0.25, 0.42, 0.58, 1.0]

    def tr(bone, *keys):
        p.set(bone, *track3(t, [(K[0], STANCE.get(bone, (0, 0, 0)))] + list(zip(K[1:-1], keys)) + [(K[-1], STANCE.get(bone, (0, 0, 0)))]))

    tr("Hips", (30, 0, 0), (0, 0, 0), (26, 0, 0))
    tr("Spine", (30, 0, 0), (0, 0, 0), (30, 0, 0))
    tr("Chest", (20, 0, 0), (-10, 0, 0), (24, 0, 0))
    tr("Head", (-44, 0, 0), (-20, 0, 0), (-40, 0, 0))
    tr("Thigh.L", (-80, 0, -14), (-10, 0, -10), (-70, 0, -14))
    tr("Shin.L", (110, 0, 0), (20, 0, 0), (100, 0, 0))
    tr("Thigh.R", (-70, 0, 16), (10, 0, 10), (-60, 0, 16))
    tr("Shin.R", (106, 0, 0), (30, 0, 0), (96, 0, 0))
    tr("UpperArm.L", (10, 0, -30), (-150, 0, -40), (-70, 0, -10))
    tr("ForeArm.L", (-30, 0, 0), (-10, 0, 0), (-10, 0, 0))
    tr("UpperArm.R", (10, 0, 30), (-150, 0, 40), (-70, 0, 10))
    tr("ForeArm.R", (-30, 0, 0), (-10, 0, 0), (-10, 0, 0))
    tr("Hand.L", (0, 0, 0), (20, 0, 0), (-30, 0, 0))
    tr("Hand.R", (0, 0, 0), (20, 0, 0), (-30, 0, 0))
    p.move("Hips", z=track(t, [(0, -0.26), (K[1], -0.34), (K[2], 0.02), (K[3], -0.22), (1, -0.26)]))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.04), (K[2], -0.3), (K[3], -0.36), (1, 0)]),
           z=track(t, [(0, 0), (K[1], 0), (K[2], 0.18), (K[3], 0), (1, 0)]))
    return p


def hit(t):
    """Получил удар (0.47 сек): отшатнулся, голова мотнулась, руки вскинуты."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.34, 1), (0.56, -0.3), (0.8, 0.1), (1, 0)])
    p.move("Root", y=0.1 * snap)
    p.add("Spine", x=-20 * snap)
    p.add("Chest", x=-10 * snap, y=8 * snap)
    p.add("Head", x=-24 * whip, z=12 * whip)
    p.add("UpperArm.L", x=30 * snap, z=-20 * snap)
    p.add("UpperArm.R", x=26 * snap, z=20 * snap)
    return p


def death(t):
    """Гибель (1.2 сек): выпрямился в судороге, рухнул ничком — снова просто ком камыша."""
    p = stance()
    K = [0.0, 0.2, 0.45, 0.72, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Spine", x=tr([0, -30, 10, 30, 30]))
    p.add("Chest", x=tr([0, -20, 10, 20, 20]))
    p.add("Head", x=tr([0, -20, 20, 30, 30]))
    p.add("UpperArm.L", x=tr([0, 40, -40, -70, -70]), z=tr([0, -20, -30, -40, -40]))
    p.add("UpperArm.R", x=tr([0, 40, -40, -70, -70]), z=tr([0, 20, 30, 40, 40]))
    p.add("Thigh.L", x=tr([0, 30, 20, 40, 40]))
    p.add("Thigh.R", x=tr([0, 30, 20, 40, 40]))
    p.add("Shin.L", x=tr([0, -40, -30, -60, -60]))
    p.add("Shin.R", x=tr([0, -40, -30, -60, -60]))
    p.set("Root", tr([0, -6, 26, 56, 58]), 0, 0)
    p.move("Hips", z=tr([-0.26, -0.1, -0.3, -0.36, -0.36]))
    p.move("Root", y=tr([0, 0.04, -0.1, -0.2, -0.2]))
    spasm = pulse(t, 0.86, 0.05)
    p.add("Hand.L", x=-30 * spasm)
    p.add("ForeArm.R", x=-20 * spasm)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 21, walk, cyclic=True)
    k.bake(rig, "Attack", 24, attack)
    k.bake(rig, "Hit", 14, hit)
    k.bake(rig, "Death", 36, death)


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
    glb = args[0] if args else os.path.join(here, "..", "reed_lurker.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "reed_lurker.blend")
    build(glb, blend)
