# Гоблин-подрывник — тварь Раскола (~1.0 м). Тело — общее гоблинское (goblin_kin.py), движения — как у
# факельщика (тот же бросок через голову), но снаряжение своё: стёганая кожаная жилетка, тряпка на лице
# от газа, круглые очки на лбу, на спине рама со связкой глиняных горшков — из щелей и пробок сочится
# зелёный газ (как у бочки), в поднятой правой руке горшок с дымящейся пробкой. Огня нет — только газ.
# Облик — claude/мир.md, «Будущие враги»; референс Gemini — 14 ноября. Смотрит в -Y.
#
# Запуск: python3 build_goblin_bomber.py out.glb out.blend (нужен модуль bpy)
# или в Blender: Scripting → Open → Run Script. Рядом должны лежать char_kit.py и goblin_kin.py.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
import goblin_kin as g
from char_kit import Pose, wave, track, track3, pulse

NAME = "GoblinBomber"

def build_mesh():
    M = g.materials("Bomber")
    quilt = k.mat("Bomber_Quilt", (0.42, 0.31, 0.21), rough=0.95)        # стёганая жилетка
    stitch = k.mat("Bomber_Stitch", (0.22, 0.16, 0.11), rough=1.0)
    cloth = k.mat("Bomber_Cloth", (0.6, 0.55, 0.43), rough=1.0)           # тряпка на лице
    loin = k.mat("Bomber_Loin", (0.4, 0.43, 0.3), rough=1.0)
    strap = k.mat("Bomber_Strap", (0.24, 0.18, 0.12), rough=0.9)
    glass = k.mat("Bomber_Glass", (0.62, 0.72, 0.72), metallic=0.3, rough=0.15)
    wood = k.mat("Bomber_Wood", (0.38, 0.28, 0.19), rough=0.95)
    rope = k.mat("Bomber_Rope", (0.55, 0.47, 0.33), rough=1.0)
    clay = k.mat("Bomber_Clay", (0.52, 0.37, 0.26), rough=0.85)
    cork = k.mat("Bomber_Cork", (0.62, 0.5, 0.34), rough=1.0)
    gas = k.mat("Bomber_Gas", (0.42, 0.9, 0.25), rough=0.6, emit=1.3)   # болотный газ, как у бочки
    g.body(M)
    # Стёганая жилетка поверх: толще обычной, со швами ромбиками спереди и сзади
    k.limb("Quilt", (0, 0.012, 0.5), (0, 0.005, 0.71), 0.185, 0.162, quilt, "Chest", segs=8)
    for i, z in enumerate((0.55, 0.61, 0.67)):
        k.box(f"StitchF{i}", (0.26, 0.012, 0.012), (0, -0.172, z), stitch, "Chest")
        k.box(f"StitchB{i}", (0.26, 0.012, 0.012), (0, 0.18, z), stitch, "Chest")
    for i, x in enumerate((-0.06, 0.06)):
        k.box(f"StitchV{i}", (0.012, 0.012, 0.18), (x, -0.17, 0.6), stitch, "Chest")
    # Набедренная тряпка
    k.plate("Loin", [(-0.1, 0), (0.1, 0), (0.08, -0.16), (0.02, -0.12), (-0.04, -0.17), (-0.09, -0.12)], 0.018,
            (0, -0.15, 0.46), (1, 0, 0), (0, -0.1, 1), loin, "Hips")
    # Тряпка на лице (от газа), узел на затылке
    k.sphere("Mask", 0.115, (0, -0.17, 0.8), cloth, "Head", scale=(1.15, 1.05, 0.72), segs=8, rings=4)
    k.box("MaskKnot", (0.06, 0.04, 0.05), (0, 0.15, 0.84), cloth, "Head")
    k.plate("MaskTail", [(-0.02, 0), (0.02, 0), (0.015, -0.1), (-0.015, -0.11)], 0.012,
            (0.0, 0.17, 0.83), (1, 0, 0), (0, 0.4, 1), cloth, "Head")
    # Очки на лбу: ремешок вокруг головы и два круглых стекла
    k.limb("GoggleBand", (0, 0.0, 0.955), (0, 0.0, 0.985), 0.178, 0.17, strap, "Head", segs=8)
    for s in (-1, 1):
        rim = ((0.065 * s, -0.15, 0.985), (0.068 * s, -0.2, 0.995))
        k.limb(f"GoggleRim{s}", rim[0], rim[1], 0.045, 0.045, strap, "Head", segs=7)
        k.limb(f"GoggleGlass{s}", (0.068 * s, -0.198, 0.995), (0.068 * s, -0.204, 0.996), 0.036, 0.036, glass, "Head", segs=7)
    # Рама за спиной (кость Bag — болтается): две стойки, три перекладины, пять горшков, верёвки
    for s in (-1, 1):
        k.limb(f"Post{s}", (0.13 * s, 0.22, 0.36), (0.13 * s, 0.24, 0.98), 0.018, 0.016, wood, "Bag", segs=4)
    for i, z in enumerate((0.42, 0.66, 0.9)):
        k.box(f"Rail{i}", (0.3, 0.03, 0.03), (0, 0.23 + 0.02 * i / 2, z), wood, "Bag")
    pots = [(-0.07, 0.52, 0.085), (0.075, 0.5, 0.08), (0.0, 0.76, 0.09), (-0.09, 0.95, 0.065), (0.08, 0.93, 0.07)]
    for i, (x, z, r) in enumerate(pots):
        y = 0.3
        k.sphere(f"Pack{i}", r, (x, y, z), clay, "Bag", scale=(1.0, 0.95, 1.05), segs=6, rings=4)
        k.limb(f"PackNeck{i}", (x, y, z + r * 0.8), (x, y, z + r * 1.25), r * 0.45, r * 0.5, clay, "Bag", segs=5)
        k.limb(f"PackCork{i}", (x, y, z + r * 1.2), (x, y, z + r * 1.45), r * 0.36, r * 0.32, cork, "Bag", segs=5)
        k.crack(f"PackCrack{i}", [(0, 0.03), (0.015, 0.0), (-0.01, -0.03)], (x + r * 0.5, y - r * 0.85, z),
                (1, 0, 0), (0, 0, 1), gas, "Bag", width=0.01, depth=0.02)
    for i, (x, z) in enumerate([(0.0, 0.76), (-0.09, 0.95)]):
        k.sphere(f"PackWisp{i}", 0.03, (x + 0.01, 0.3, z + 0.16), gas, "Bag", scale=(1, 1, 1.4), segs=5, rings=3)
    k.box("PackRope", (0.32, 0.03, 0.025), (0, 0.27, 0.62), rope, "Bag", rot=(0, 6, 0))
    for s in (-1, 1):   # лямки через плечи
        k.box(f"Strap{s}", (0.04, 0.03, 0.26), (0.11 * s, -0.16, 0.62), strap, "Chest", rot=(0, 12 * s, 0))
    # Горшок в правой руке (кость Pot) с дымящейся пробкой (кость Gas — дым колышется)
    px, py = -0.225, -0.06
    k.sphere("Pot", 0.08, (px, py, 0.22), clay, "Pot", scale=(1.0, 1.0, 0.95), segs=8, rings=5)
    k.limb("PotNeck", (px, py, 0.285), (px, py, 0.33), 0.036, 0.042, clay, "Pot", segs=6)
    k.limb("PotCork", (px, py, 0.325), (px, py, 0.355), 0.03, 0.026, cork, "Pot", segs=5)
    k.crack("PotCrack", [(0, 0.03), (0.02, 0.0), (-0.01, -0.03)], (px - 0.03, py - 0.07, 0.22),
            (1, 0, 0), (0, 0, 1), gas, "Pot", width=0.01, depth=0.02)
    k.sphere("Wisp0", 0.03, (px, py, 0.39), gas, "Gas", scale=(1, 1, 1.3), segs=5, rings=3)
    k.sphere("Wisp1", 0.022, (px + 0.02, py + 0.01, 0.45), gas, "Gas", segs=5, rings=3)
    return k.join_parts("GoblinBomberMesh")


BONES = g.bones({
    "Knot": ((0, 0.17, 0.84), (0, 0.2, 0.72), "Head"),
    "Bag": ((0, 0.22, 0.75), (0, 0.22, 0.5), "Chest"),
    "Pot": ((-0.225, -0.03, 0.25), (-0.225, -0.03, 0.45), "Hand.R"),
    "Gas": ((-0.225, -0.06, 0.36), (-0.225, -0.06, 0.5), "Pot"),
})

# Стойка вполоборота: присел, горшок поднят в правой руке над головой, левая рука придерживает лямку.
STANCE = {
    "Spine": (18, -18, 0), "Chest": (12, -14, 0), "Head": (-24, 30, 3),
    "Thigh.L": (-36, 0, -9), "Shin.L": (44, 0, 0), "Foot.L": (8, 0, 0),
    "Thigh.R": (-4, 0, 12), "Shin.R": (34, 0, 0), "Foot.R": (30, 0, 0),
    "UpperArm.R": (0, 0, 150), "ForeArm.R": (-10, 0, 60), "Hand.R": (0, 0, 0), "Pot": (0, 0, 0), "Gas": (0, 0, 0),
    "UpperArm.L": (-46, -30, -10), "ForeArm.L": (-74, 0, 0), "Hand.L": (0, 0, 0),
    "Ear.R": (4, 0, 0), "Ear.L": (4, 0, 0), "Knot": (10, 0, 0), "Bag": (0, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.05)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3 сек): дышит, озирается, покачивает горшком, из пробки вьётся газ; встряхивает связку за спиной."""
    p = stance()
    breath, sway = g.idle_base(p, t)
    swing = wave(t, 1)                      # покачивает горшком
    p.add("Pot", x=8 * swing, z=4 * wave(t, 1, 0.25))
    p.add("UpperArm.R", x=4 * swing, z=2 * breath)
    p.add("Gas", x=10 * wave(t, 7), z=8 * wave(t, 5, 0.3))   # газ над пробкой колышется
    p.size("Gas", 1 + 0.12 * wave(t, 6, 0.1))
    toss = pulse(t, 0.62, 0.1)              # встряхивает горшок с маслом
    p.add("ForeArm.L", x=-16 * toss + 3 * breath)
    p.add("UpperArm.L", x=-6 * toss, z=-2 * sway)
    p.add("Hand.L", x=-14 * toss)
    p.add("Knot", x=5 * wave(t, 1, -0.2), z=4 * wave(t, 2, 0.1))
    p.add("Bag", x=3 * wave(t, 1, -0.25), z=2 * sway)
    return p


def walk(t):
    """Перебежка (0.67 сек): пригнувшись, связка горшков подпрыгивает за спиной."""
    p = Pose(STANCE)
    a, bounce = g.walk_base(p, t, lean=26)
    p.add("UpperArm.R", x=14 * a, z=-6)
    p.add("ForeArm.R", x=8 * wave(t, 2, 0.2))
    p.add("Pot", x=-10 * a)
    p.add("Gas", x=-20 + 8 * wave(t, 6), z=6 * wave(t, 5))
    p.add("UpperArm.L", x=-10 * a + 6)
    p.add("ForeArm.L", x=6 * a)
    p.add("Knot", x=26 + 10 * wave(t, 2, -0.15))
    p.add("Bag", x=14 * wave(t, 2, -0.2), z=6 * a)
    return p


def attack(t):
    """Бросок (0.87 сек): заносит горшок за голову → шаг и бросок сверху (к 0.4 сек) → доводит руку."""
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
    # Горшок: заносится за голову и в момент броска клонится вперёд; газ рвётся назад
    p.set("Pot", track(t, [(0, S["Pot"][0]), (K[1], 30), (K[2], 10), (K[3], 120), (K[4], 100), (1, S["Pot"][0])]), 0,
          S["Pot"][2])
    p.set("Gas", track(t, [(0, 0), (K[2], 20), (K[3], -40), (K[4], -20), (1, 0)]), 0, 0)
    p.size("Gas", track(t, [(0, 1), (K[2], 1.2), (K[3], 1.5), (K[4], 0.6), (1, 1)]))
    back = track(t, [(0, 0), (K[1], -8), (K[2], 20), (K[3], 26), (K[3] + 0.08, -18), (K[4] + 0.1, 6), (1, 0)])
    p.set("Ear.L", 4, 0, back)
    p.set("Ear.R", 4, 0, -back)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.04), (K[2], 0.06), (K[3], -0.16), (K[4], -0.18), (1, 0)]))
    p.move("Hips", z=track(t, [(0, -0.05), (K[1], -0.03), (K[2], -0.02), (K[3], -0.10), (K[4], -0.11), (1, -0.05)]))
    return p


def hit(t):
    """Получил удар (0.47 сек): отбрасывает назад, голова мотается, горшки за спиной вразлёт."""
    p = stance()
    snap, whip = g.hit_base(p, t)
    p.add("UpperArm.R", x=20 * snap, z=24 * snap)
    p.add("ForeArm.R", x=30 * snap)
    p.add("Pot", x=-30 * whip, z=20 * snap)
    p.add("Gas", x=-30 * whip)
    p.add("UpperArm.L", x=36 * snap, z=-28 * snap)
    p.add("Knot", x=-40 * whip)
    p.add("Bag", x=-30 * whip, z=14 * snap)
    return p


def death(t):
    """Гибель (1.3 сек): отшатнулся, рухнул на колени, упал на спину; газ гаснет, рука дёргается."""
    p = Pose({}, {})
    tr, spasm = g.death_base(p, t, STANCE)
    tr("UpperArm.R", (-10, 0, 50), (10, 0, 30), (-10, 0, 76), (14, 0, 84))
    tr("ForeArm.R", (-50, 0, 0), (-30, 0, 0), (-30, 0, 0), (-14, 0, 0))
    tr("Pot", (100, 0, 0), (60, 0, 20), (30, 0, 40), (10, 0, 50))
    p.size("Gas", track(t, [(0, 1), (0.4, 1), (0.8, 0.4), (1, 0.3)]))
    tr("UpperArm.L", (-10, 0, -50), (16, 0, -30), (-6, 0, -70), (16, 0, -80))
    tr("ForeArm.L", (-50, 0, 0), (-40, 0, 0), (-30, 0, 0), (-20, 0, 0))
    tr("Knot", (-30, 0, 0), (30, 0, 0), (-60, 0, 0), (-70, 0, 0))
    tr("Bag", (-20, 0, 0), (20, 0, 10), (-40, 0, 20), (-50, 0, 24))
    p.add("ForeArm.L", x=-24 * spasm)
    return p


def build_actions(rig):
    sc = ("Gas",)
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=sc)
    k.bake(rig, "Walk", 20, walk, cyclic=True, scale_bones=sc)
    k.bake(rig, "Attack", 26, attack, scale_bones=sc)
    k.bake(rig, "Hit", 14, hit, scale_bones=sc)
    k.bake(rig, "Death", 40, death, scale_bones=sc)


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
    glb = args[0] if args else os.path.join(here, "..", "goblin_bomber.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "goblin_bomber.blend")
    build(glb, blend)
