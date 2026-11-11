# Гоблин-пращник — тварь Раскола (~0.9 м). Без щита и тесака: кожаная бандана с узлом,
# сумка с камнями через плечо, в правой руке праща с камнем, в левой — запасной булыжник.
# Тело — общее гоблинское (goblin_kin.py). Смотрит в -Y.
#
# Запуск: python3 build_goblin_slinger.py out.glb out.blend (нужен модуль bpy)
# или в Blender: Scripting → Open → Run Script. Рядом должны лежать char_kit.py и goblin_kin.py.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
import goblin_kin as g
from char_kit import Pose, wave, track, track3, pulse

NAME = "GoblinSlinger"


def build_mesh():
    M = g.materials("Slinger")
    leather = M["leather"]
    cloth = k.mat("Slinger_Bandana", (0.56, 0.52, 0.42), rough=0.95)     # серо-бежевая бандана
    stone = k.mat("Slinger_Stone", (0.55, 0.57, 0.67), rough=0.8)        # серые камни
    cord = k.mat("Slinger_Cord", (0.42, 0.34, 0.24), rough=0.95)
    g.body(M)
    # Бандана: шапочка поверх черепа, спереди валик, сзади узел с двумя хвостами (своя кость)
    k.sphere("Bandana", 0.166, (0, -0.015, 0.905), cloth, "Head", scale=(1.17, 1.08, 0.66), segs=8, rings=4)
    k.box("BandanaRoll", (0.30, 0.04, 0.045), (0, -0.168, 0.94), cloth, "Head", rot=(14, 0, 0))
    k.sphere("Knot", 0.04, (0, 0.165, 0.90), cloth, "Head", segs=5, rings=3)
    tail = [(-0.03, 0.0), (0.03, 0.0), (0.045, -0.15), (0.0, -0.11), (-0.04, -0.17)]
    k.plate("KnotTailA", tail, 0.014, (0.03, 0.175, 0.90), (1, 0.3, 0), (0, 0, 1), cloth, "Knot")
    k.plate("KnotTailB", tail, 0.014, (-0.035, 0.18, 0.895), (1, -0.4, 0), (0, 0, 1), cloth, "Knot")
    # Ремень через грудь и сумка с камнями у левого бедра (своя кость — болтается)
    k.box("BagStrap", (0.05, 0.36, 0.035), (0.0, -0.02, 0.62), leather, "Chest", rot=(0, -38, 90))
    k.box("BagStrapBack", (0.05, 0.035, 0.26), (0.03, 0.15, 0.60), leather, "Chest", rot=(0, 40, 0))
    k.box("Bag", (0.17, 0.13, 0.15), (0.2, 0.03, 0.42), leather, "Bag", rot=(0, 0, 8))
    k.box("BagFlap", (0.18, 0.14, 0.03), (0.2, 0.025, 0.50), cord, "Bag", rot=(0, 0, 8))
    for i, (dx, dy, r) in enumerate([(-0.04, -0.02, 0.04), (0.035, 0.0, 0.045), (0.0, 0.04, 0.035)]):
        k.sphere(f"BagStone{i}", r, (0.2 + dx, 0.03 + dy, 0.525), stone, "Bag", segs=5, rings=3)
    # Запасной булыжник в левом кулаке
    k.sphere("SpareStone", 0.055, (0.225, -0.085, 0.262), stone, "Hand.L", scale=(1.0, 0.9, 0.85), segs=5, rings=3)
    # Праща (кость Sling растёт вниз из правого кулака): два шнура, кожаная чашка и камень в ней
    sx, sy, top, low = -0.225, -0.03, 0.25, 0.0
    k.limb("SlingCordA", (sx - 0.012, sy, top), (sx - 0.03, sy, low + 0.03), 0.008, 0.008, cord, "Sling", segs=3)
    k.limb("SlingCordB", (sx + 0.012, sy, top), (sx + 0.03, sy, low + 0.03), 0.008, 0.008, cord, "Sling", segs=3)
    k.box("SlingPouch", (0.09, 0.07, 0.03), (sx, sy, low + 0.02), leather, "Sling")
    k.sphere("SlingStone", 0.045, (sx, sy, low + 0.05), stone, "Sling", segs=5, rings=3)
    return k.join_parts("GoblinSlingerMesh")


BONES = g.bones({
    "Knot": ((0, 0.165, 0.90), (0, 0.19, 0.74), "Head"),
    "Bag": ((0.2, 0.03, 0.52), (0.2, 0.03, 0.36), "Hips"),
    "Sling": ((-0.225, -0.03, 0.25), (-0.225, -0.03, 0.0), "Hand.R"),
})

# Стойка вполоборота: присел, левый бок к врагу, праща висит в отведённой правой руке,
# левая рука с камнем — перед грудью.
STANCE = {
    "Spine": (18, -18, 0), "Chest": (12, -14, 0), "Head": (-24, 30, 3),
    "Thigh.L": (-36, 0, -9), "Shin.L": (44, 0, 0), "Foot.L": (8, 0, 0),
    "Thigh.R": (-4, 0, 12), "Shin.R": (34, 0, 0), "Foot.R": (30, 0, 0),
    "UpperArm.R": (-8, 0, 52), "ForeArm.R": (-96, 0, 0), "Hand.R": (0, 0, 0), "Sling": (100, 0, -40),
    "UpperArm.L": (-46, -30, -10), "ForeArm.L": (-74, 0, 0), "Hand.L": (0, 0, 0),
    "Ear.R": (4, 0, 0), "Ear.L": (4, 0, 0), "Knot": (10, 0, 0), "Bag": (0, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.05)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3 сек): дышит, озирается, лениво раскачивает пращу и подбрасывает в руке камень."""
    p = stance()
    breath, sway = g.idle_base(p, t)
    swing = wave(t, 3)                      # праща качается маятником
    p.add("Sling", x=22 * swing, z=6 * wave(t, 3, 0.25))
    p.add("UpperArm.R", x=3 * swing, z=2 * breath)
    p.add("ForeArm.R", x=-4 * swing)
    toss = pulse(t, 0.62, 0.1)              # взвешивает камень в ладони
    p.add("ForeArm.L", x=-16 * toss + 3 * breath)
    p.add("UpperArm.L", x=-6 * toss, z=-2 * sway)
    p.add("Hand.L", x=-14 * toss)
    p.add("Knot", x=5 * wave(t, 1, -0.2), z=4 * wave(t, 2, 0.1))
    p.add("Bag", x=3 * wave(t, 1, -0.25), z=2 * sway)
    return p


def walk(t):
    """Перебежка (0.67 сек): пригнувшись, праща и сумка болтаются, камень прижат к груди."""
    p = Pose(STANCE)
    a, bounce = g.walk_base(p, t, lean=26)
    p.add("UpperArm.R", x=14 * a, z=-6)
    p.add("ForeArm.R", x=8 * wave(t, 2, 0.2))
    p.add("Sling", x=-28 * a + 10 * bounce)
    p.add("UpperArm.L", x=-10 * a + 6)
    p.add("ForeArm.L", x=6 * a)
    p.add("Knot", x=26 + 10 * wave(t, 2, -0.15))
    p.add("Bag", x=14 * wave(t, 2, -0.2), z=6 * a)
    return p


def attack(t):
    """Бросок (0.87 сек): раскручивает пращу над головой → шаг и хлёсткий бросок (к 0.4 сек) → доводит руку."""
    p = Pose({}, {})
    K = [0.0, 0.16, 0.36, 0.46, 0.62, 1.0]   # стойка, поднял, раскрутил, бросок, пронос, стойка
    S = STANCE

    def tr(bone, lift, spin, throw, follow):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], lift), (K[2], spin), (K[3], throw),
                                (K[4], follow), (K[5], S.get(bone, (0, 0, 0)))]))

    tr("Spine", (4, -26, 0), (-4, -30, 0), (30, 22, 0), (34, 28, 0))
    tr("Chest", (2, -16, 0), (-6, -18, 0), (14, 14, 0), (16, 18, 0))
    tr("Head", (-16, 36, 0), (-10, 40, 0), (-36, -12, 0), (-32, -16, 0))
    tr("UpperArm.R", (-120, 0, 50), (-150, 0, 40), (-84, 0, 6), (-40, 0, -12))
    tr("ForeArm.R", (-70, 0, 0), (-60, 0, 0), (-10, 0, 0), (-16, 0, 0))
    tr("Hand.R", (0, 0, 0), (-10, 0, 0), (24, 0, 0), (20, 0, 0))
    tr("UpperArm.L", (-70, -30, -24), (-60, -30, -34), (8, -10, -40), (16, -10, -34))
    tr("ForeArm.L", (-50, 0, 0), (-40, 0, 0), (-50, 0, 0), (-56, 0, 0))
    tr("Thigh.L", (-44, 0, -9), (-48, 0, -9), (-60, 0, -9), (-54, 0, -9))
    tr("Shin.L", (56, 0, 0), (50, 0, 0), (64, 0, 0), (60, 0, 0))
    tr("Foot.L", (8, 0, 0), (0, 0, 0), (4, 0, 0), (8, 0, 0))
    tr("Thigh.R", (-6, 0, 12), (4, 0, 12), (22, 0, 12), (14, 0, 12))
    tr("Shin.R", (44, 0, 0), (36, 0, 0), (34, 0, 0), (36, 0, 0))
    tr("Foot.R", (30, 0, 0), (20, 0, 0), (10, 0, 0), (24, 0, 0))
    tr("Jaw", (-6, 0, 0), (-16, 0, 0), (-34, 0, 0), (-20, 0, 0))
    tr("Knot", (0, 0, 0), (-10, 0, 14), (40, 0, -10), (20, 0, 0))
    tr("Bag", (0, 0, 0), (0, 0, 10), (-24, 0, -8), (-10, 0, 0))
    # Праща: два полных оборота над головой, в момент броска вытягивается вперёд и повисает
    spin = track(t, [(0, 0), (K[1], -60), (K[3], -60 - 720), (K[4], -720 - 50), (1, -720)])   # −720° = снова стойка
    p.set("Sling", S["Sling"][0] + spin, 0, track(t, [(0, S["Sling"][2]), (K[1], 0), (K[4], 0), (1, S["Sling"][2])]))
    back = track(t, [(0, 0), (K[1], -8), (K[2], 20), (K[3], 26), (K[3] + 0.08, -18), (K[4] + 0.1, 6), (1, 0)])
    p.set("Ear.L", 4, 0, back)
    p.set("Ear.R", 4, 0, -back)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.04), (K[2], 0.06), (K[3], -0.16), (K[4], -0.18), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.05), (K[1], -0.03), (K[2], -0.02), (K[3], -0.10), (K[4], -0.11), (1, -0.05)]))
    return p


def hit(t):
    """Получил удар (0.47 сек): отбрасывает назад, голова мотается, праща и сумка вразлёт."""
    p = stance()
    snap, whip = g.hit_base(p, t)
    p.add("UpperArm.R", x=20 * snap, z=24 * snap)
    p.add("ForeArm.R", x=30 * snap)
    p.add("Sling", x=-60 * whip, z=20 * snap)
    p.add("UpperArm.L", x=36 * snap, z=-28 * snap)
    p.add("Knot", x=-40 * whip)
    p.add("Bag", x=-30 * whip, z=14 * snap)
    return p


def death(t):
    """Гибель (1.3 сек): отшатнулся, рухнул на колени, упал на спину; праща выпадает, рука дёргается."""
    p = Pose({}, {})
    tr, spasm = g.death_base(p, t, STANCE)
    tr("UpperArm.R", (-10, 0, 50), (10, 0, 30), (-10, 0, 76), (14, 0, 84))
    tr("ForeArm.R", (-50, 0, 0), (-30, 0, 0), (-30, 0, 0), (-14, 0, 0))
    tr("Sling", (140, 0, 0), (60, 0, 20), (30, 0, 40), (10, 0, 50))
    tr("UpperArm.L", (-10, 0, -50), (16, 0, -30), (-6, 0, -70), (16, 0, -80))
    tr("ForeArm.L", (-50, 0, 0), (-40, 0, 0), (-30, 0, 0), (-20, 0, 0))
    tr("Knot", (-30, 0, 0), (30, 0, 0), (-60, 0, 0), (-70, 0, 0))
    tr("Bag", (-20, 0, 0), (20, 0, 10), (-40, 0, 20), (-50, 0, 24))
    p.add("ForeArm.L", x=-24 * spasm)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 20, walk, cyclic=True)
    k.bake(rig, "Attack", 26, attack)
    k.bake(rig, "Hit", 14, hit)
    k.bake(rig, "Death", 40, death)


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
    glb = args[0] if args else os.path.join(here, "..", "goblin_slinger.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "goblin_slinger.blend")
    build(glb, blend)
