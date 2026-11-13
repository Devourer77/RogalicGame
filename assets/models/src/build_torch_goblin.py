# Гоблин-факельщик — тварь Раскола (~1.0 м). Тело — общее гоблинское (goblin_kin.py), собран на основе
# пращника: закопчённый тёмный капюшон, прожжённый кожаный фартук на верёвке, на спине связка запасных факелов,
# в правой руке горящий факел (оранжевое пламя — это огонь), в левой — глиняный горшок с маслом. Смотрит в -Y.
#
# Запуск: python3 build_torch_goblin.py out.glb out.blend (нужен модуль bpy)
# или в Blender: Scripting → Open → Run Script. Рядом должны лежать char_kit.py и goblin_kin.py.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
import goblin_kin as g
from char_kit import Pose, wave, track, track3, pulse

NAME = "TorchGoblin"


def build_mesh():
    M = g.materials("Torch")
    hood = k.mat("Torch_Hood", (0.20, 0.20, 0.21), rough=0.95)          # закопчённый капюшон
    apron = k.mat("Torch_Apron", (0.40, 0.31, 0.22), rough=0.95)        # прожжённый фартук
    burn = k.mat("Torch_Burn", (0.16, 0.14, 0.12), rough=1.0)
    wood = k.mat("Torch_Wood", (0.36, 0.27, 0.19), rough=0.95)
    rope = k.mat("Torch_Rope", (0.55, 0.47, 0.33), rough=1.0)
    clay = k.mat("Torch_Clay", (0.50, 0.38, 0.27), rough=0.85)
    flame = k.mat("Torch_Flame", (0.95, 0.32, 0.06), rough=0.5, emit=3.0)    # огонь — оранжевый
    flame_c = k.mat("Torch_FlameCore", (1.0, 0.48, 0.12), rough=0.5, emit=3.2)
    g.body(M)
    # Капюшон поверх головы и плеч, хвост капюшона на своей кости
    k.sphere("Hood", 0.19, (0, 0.01, 0.91), hood, "Head", scale=(1.12, 1.12, 1.0), segs=8, rings=4)
    k.box("HoodRim", (0.3, 0.05, 0.05), (0, -0.16, 0.93), hood, "Head", rot=(14, 0, 0))
    k.sphere("Cowl", 0.16, (0, 0.02, 0.7), hood, "Chest", scale=(1.25, 1.0, 0.45), segs=8, rings=3)
    tail = [(-0.04, 0.0), (0.04, 0.0), (0.02, -0.16), (-0.02, -0.18)]
    k.plate("HoodTail", tail, 0.018, (0, 0.17, 0.92), (1, 0, 0), (0, 0.3, 1), hood, "Knot")
    # Фартук на верёвке с прожжёнными дырами
    k.plate("Apron", [(-0.13, 0), (0.13, 0), (0.12, -0.3), (0.05, -0.26), (-0.02, -0.33), (-0.12, -0.28)], 0.02,
            (0, -0.15, 0.66), (1, 0, 0), (0, -0.1, 1), apron, "Chest")
    k.box("ApronRope", (0.3, 0.03, 0.025), (0, -0.12, 0.5), rope, "Hips")
    for i, (x, z) in enumerate([(0.05, 0.56), (-0.06, 0.47), (0.03, 0.42)]):
        k.sphere(f"Burn{i}", 0.022, (x, -0.165, z), burn, "Chest", scale=(1.0, 0.3, 1.0), segs=5, rings=2)
    # Связка факелов на спине (кость Bag — болтается)
    for i, (dx, dz) in enumerate([(-0.05, 0), (0.0, 0.03), (0.05, -0.02), (0.02, 0.05), (-0.03, 0.06)]):
        k.limb(f"Spare{i}", (0.06 + dx, 0.16, 0.42 + dz), (0.12 + dx * 1.4, 0.2, 0.92 + dz), 0.022, 0.02, wood, "Bag", segs=5)
    k.box("SpareRope", (0.16, 0.08, 0.03), (0.09, 0.17, 0.62), rope, "Bag", rot=(0, -8, 0))
    # Горшок с маслом в левом кулаке
    k.sphere("Pot", 0.07, (0.225, -0.085, 0.24), clay, "Hand.L", scale=(1.0, 1.0, 0.9), segs=7, rings=4)
    k.limb("PotNeck", (0.225, -0.085, 0.29), (0.225, -0.085, 0.33), 0.035, 0.04, clay, "Hand.L", segs=6)
    # Факел в правом кулаке (кость Torch): рукоять, обмотка и пламя (кость Flame — дрожит)
    tx, ty = -0.225, -0.03
    k.limb("TorchStick", (tx, ty, 0.2), (tx, ty, 0.56), 0.022, 0.026, wood, "Torch", segs=5)
    k.limb("TorchWrap", (tx, ty, 0.5), (tx, ty, 0.6), 0.038, 0.034, rope, "Torch", segs=6)
    k.limb("FlameOuter", (tx, ty, 0.58), (tx, ty, 0.8), 0.07, 0.01, flame, "Flame", segs=6)
    k.limb("FlameInner", (tx, ty, 0.58), (tx, ty, 0.72), 0.04, 0.006, flame_c, "Flame", segs=5)
    return k.join_parts("TorchGoblinMesh")


BONES = g.bones({
    "Knot": ((0, 0.17, 0.92), (0, 0.2, 0.76), "Head"),
    "Bag": ((0.09, 0.17, 0.75), (0.09, 0.17, 0.5), "Chest"),
    "Torch": ((-0.225, -0.03, 0.25), (-0.225, -0.03, 0.45), "Hand.R"),
    "Flame": ((-0.225, -0.03, 0.58), (-0.225, -0.03, 0.75), "Torch"),
})

# Стойка вполоборота: присел, факел поднят в правой руке над головой, горшок с маслом — у груди.
STANCE = {
    "Spine": (18, -18, 0), "Chest": (12, -14, 0), "Head": (-24, 30, 3),
    "Thigh.L": (-36, 0, -9), "Shin.L": (44, 0, 0), "Foot.L": (8, 0, 0),
    "Thigh.R": (-4, 0, 12), "Shin.R": (34, 0, 0), "Foot.R": (30, 0, 0),
    "UpperArm.R": (-30, 0, 70), "ForeArm.R": (-70, 0, 0), "Hand.R": (0, 0, 0), "Torch": (-20, 0, 70), "Flame": (0, 0, 0),
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
    swing = wave(t, 1)                      # помахивает факелом
    p.add("Torch", x=8 * swing, z=4 * wave(t, 1, 0.25))
    p.add("UpperArm.R", x=4 * swing, z=2 * breath)
    p.add("Flame", x=10 * wave(t, 7), z=8 * wave(t, 5, 0.3))   # пламя дрожит
    p.size("Flame", 1 + 0.12 * wave(t, 6, 0.1))
    toss = pulse(t, 0.62, 0.1)              # встряхивает горшок с маслом
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
    p.add("Torch", x=-10 * a)
    p.add("Flame", x=-20 + 8 * wave(t, 6), z=6 * wave(t, 5))
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
    # Факел: заносится за голову и в момент броска резко клонится вперёд; пламя рвётся назад
    p.set("Torch", track(t, [(0, S["Torch"][0]), (K[1], 30), (K[2], 10), (K[3], 120), (K[4], 100), (1, S["Torch"][0])]), 0,
          S["Torch"][2])
    p.set("Flame", track(t, [(0, 0), (K[2], 20), (K[3], -40), (K[4], -20), (1, 0)]), 0, 0)
    p.size("Flame", track(t, [(0, 1), (K[2], 1.2), (K[3], 1.5), (K[4], 0.6), (1, 1)]))
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
    p.add("Torch", x=-30 * whip, z=20 * snap)
    p.add("Flame", x=-30 * whip)
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
    tr("Torch", (100, 0, 0), (60, 0, 20), (30, 0, 40), (10, 0, 50))
    p.size("Flame", track(t, [(0, 1), (0.4, 1), (0.8, 0.4), (1, 0.3)]))
    tr("UpperArm.L", (-10, 0, -50), (16, 0, -30), (-6, 0, -70), (16, 0, -80))
    tr("ForeArm.L", (-50, 0, 0), (-40, 0, 0), (-30, 0, 0), (-20, 0, 0))
    tr("Knot", (-30, 0, 0), (30, 0, 0), (-60, 0, 0), (-70, 0, 0))
    tr("Bag", (-20, 0, 0), (20, 0, 10), (-40, 0, 20), (-50, 0, 24))
    p.add("ForeArm.L", x=-24 * spasm)
    return p


def build_actions(rig):
    sc = ("Flame",)
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
    glb = args[0] if args else os.path.join(here, "..", "torch_goblin.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "torch_goblin.blend")
    build(glb, blend)
