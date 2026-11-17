# Пасечник (~1.7 м, грузный и широкий) — Хранители Рощи, лесная ветка акта 1. Тело — grove_kin.py.
# Толстая одежда, тяжёлая бурая шкура на плечах с побегами. Широкая маска орехового дерева с узором
# пчелиных сот, на лбу светится лист. В правой руке на ладони — тёмный плетёный улей; вокруг улья и головы
# вьётся рой мелких тёмных пчёл. Облик — claude/мир.md; референс Gemini 17 ноября (набор «А», улей темнее,
# как в «Б»). Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (бросок улья: площадь вокруг цели, яд), Hit, Death.
# Запуск: python3 build_grove_beekeeper.py out/grove_beekeeper.glb out/grove_beekeeper.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GroveBeekeeper"
g.setup(1.12, 0.95)
P = g.P

# Правая рука держит улей на ладони перед грудью, левая висит свободно.
SH_R, EL_R, WR_R = P(-0.26, 0.0, 1.33), P(-0.4, -0.06, 1.1), P(-0.38, -0.27, 0.98)
SH_L, EL_L, WR_L = P(0.26, 0.0, 1.33), P(0.34, 0.02, 1.08), P(0.33, -0.07, 0.88)
FIST_R = Vector(WR_R) + (Vector(WR_R) - Vector(EL_R)).normalized() * 0.05 * g.W
HIVE = FIST_R + Vector((0.0, -0.02, 0.06))        # низ улья
HIVE_C = HIVE + Vector((0, 0, 0.17))


# ---------- Модель ----------

def build_mesh():
    M = g.materials("Beekeeper")
    g.legs(M)
    g.torso(M)
    for i, z in enumerate((1.0, 1.1, 1.2)):   # стёганая рубаха — швы-полосы
        k.barrel(f"Quilt{i}", 0.25 * g.W, 0.25 * g.W, z * g.H, (z + 0.02) * g.H, M["cloth_d"], "Spine", sy=0.75)
    g.arm_upper(M, "R", -1, SH_R, EL_R)
    g.arm_lower(M, "R", -1, EL_R, WR_R, fist_dir=(0, -0.4, 1))
    g.arm_upper(M, "L", 1, SH_L, EL_L)
    g.arm_lower(M, "L", 1, EL_L, WR_L, fist_dir=(0, -1, -0.3))
    g.hood_and_head(M)
    g.comb_mask(M)
    g.fur_mantle(M, big=1.05)
    g.vines(M, count=2)

    # Улей (кость Hive): яйцо из плетёных колец, леток спереди, ручка-петля сверху
    prof = [(0.0, 0.1), (0.06, 0.15), (0.13, 0.17), (0.2, 0.16), (0.27, 0.13), (0.32, 0.08), (0.355, 0.02)]
    for i, ((z0, r0), (z1, r1)) in enumerate(zip(prof, prof[1:])):
        k.barrel(f"Hive{i}", r0, r1, HIVE.z + z0, HIVE.z + z1, M["wicker"] if i % 2 else M["fur_d"], "Hive",
                 segs=8, loc=(HIVE.x, HIVE.y))
    k.box("HiveDoor", (0.06, 0.03, 0.04), tuple(HIVE + Vector((0, -0.16, 0.09))), M["bee"], "Hive")
    k.limb("HiveTop", tuple(HIVE + Vector((0, 0, 0.35))), tuple(HIVE + Vector((0, 0, 0.4))), 0.025, 0.01,
           M["wood"], "Hive", segs=5)

    # Рой: мелкие тёмные пчёлы на двух костях (кружат с разной скоростью)
    for i in range(10):
        a = math.tau * i / 10
        r = 0.27 + 0.05 * math.sin(i * 1.7)
        pos = HIVE_C + Vector((math.cos(a) * r, math.sin(a) * r, 0.12 * math.sin(i * 2.3)))
        k.box(f"Bee{i}", (0.03, 0.02, 0.02), tuple(pos), M["bee"], "Swarm", rot=(0, 0, math.degrees(a)))
    head = Vector(P(0, 0, 1.62))
    for i in range(7):
        a = math.tau * i / 7 + 0.4
        pos = head + Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.1 * math.sin(i * 1.9)))
        k.box(f"BeeH{i}", (0.028, 0.019, 0.019), tuple(pos), M["bee"], "Swarm2", rot=(0, 0, math.degrees(a)))
    return k.join_parts("GroveBeekeeperMesh")


# ---------- Скелет ----------

BONES = g.bones(SH_R, EL_R, WR_R, SH_L, EL_L, WR_L, extra={
    "Hive": (tuple(FIST_R), tuple(FIST_R + Vector((0, 0, 0.2))), "Hand.R"),
    "Swarm": (tuple(HIVE_C), tuple(HIVE_C + Vector((0, 0, 0.2))), "Hive"),
    "Swarm2": (P(0, 0, 1.62), P(0, 0, 1.82), "Head"),
})


# ---------- Анимации ----------
STANCE = dict(g.LEG_STANCE)
STANCE.update({"Spine": (2, -8, 0), "Chest": (-2, -4, 0), "Head": (-4, 12, 0),
               "Thigh.L": (-16, 0, -10), "Thigh.R": (6, 0, 12)})   # ноги шире — грузный


def stance():
    return Pose(STANCE, g.STANCE_LOC)


def swarm(p, t, speed=1.0, burst=1.0):
    """Пчёлы кружат: рой у улья и рой у головы — в разные стороны, с покачиванием."""
    p.add("Swarm", y=360 * speed * t, x=8 * wave(t, 3))
    p.add("Swarm2", y=-360 * speed * t, z=10 * wave(t, 2, 0.3))
    p.size("Swarm", burst)
    p.size("Swarm2", 1.0 + 0.1 * wave(t, 4))


def idle(t):
    """Покой (3.3 сек): тяжело дышит, качает улей на ладони, рой кружит. Характерное: подносит улей
    к маске, будто слушает пчёл, и кивает."""
    p = stance()
    breath, sway = g.idle_body(p, t)
    listen = track(t, [(0, 0), (0.45, 0), (0.55, 1), (0.75, 1), (0.85, 0), (1, 0)])
    p.add("UpperArm.R", x=-14 * listen - 2 * breath, z=10 * listen)
    p.add("ForeArm.R", x=-20 * listen)
    p.add("Head", y=-18 * listen + 10 * wave(t, 1, 0.2) * (1 - listen), x=6 * pulse(t, 0.68, 0.05) - breath)
    p.add("Hive", x=4 * wave(t, 1, 0.1), z=3 * wave(t, 1, 0.35))
    p.add("UpperArm.L", x=3 * wave(t, 1, 0.4), z=-2 * breath)
    swarm(p, t)
    return p


def walk(t):
    """Шаг (0.8 сек): тяжёлый, вразвалку; улей покачивается, рой тянется следом."""
    p = Pose(STANCE)
    a = g.walk_body(p, t)
    p.add("Hips", z=4 * a)
    p.add("UpperArm.L", x=-12 * a)
    p.add("Hive", x=5 * wave(t, 2, 0.2))
    swarm(p, t, speed=1.0)
    return p


def attack(t):
    """Бросок улья (0.8 сек): отводит улей за плечо → бросок вперёд-вверх (к 0.4 сек): улей улетает
    (исчезает), рой вспыхивает и рассыпается → новый улей появляется в руке."""
    p = stance()
    K = [0.0, 0.3, 0.5, 0.62, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("UpperArm.R", x=tr([0, 30, -70, -60, 0]), z=tr([0, 30, 10, 6, 0]))
    p.add("ForeArm.R", x=tr([0, -60, -10, -6, 0]))
    p.add("Spine", y=tr([0, -24, 16, 12, 0]), x=tr([0, -6, 10, 8, 0]))
    p.add("Chest", y=tr([0, -10, 8, 6, 0]))
    p.add("Head", y=tr([0, 10, -6, -4, 0]))
    p.add("UpperArm.L", x=tr([0, -30, 10, 6, 0]), z=tr([0, -20, 0, 0, 0]))
    p.add("Thigh.L", x=tr([0, 4, -16, -14, 0])).add("Shin.L", x=tr([0, 0, 14, 12, 0]))
    p.move("Root", y=tr([0, 0.05, -0.1, -0.08, 0]))
    gone = track(t, [(0, 1), (0.5, 1), (0.53, 0.001), (0.86, 0.001), (0.96, 1), (1, 1)])
    p.size("Hive", gone)
    swarm(p, t, speed=1.5, burst=track(t, [(0, 1), (0.48, 1), (0.6, 2.2), (0.8, 0.6), (1, 1)]))
    return p


def hit(t):
    """Получил удар (0.5 сек): грузно отшатнулся, улей качнулся, рой взметнулся."""
    p = stance()
    snap, whip = g.hit_body(p, t)
    p.add("UpperArm.R", x=14 * snap, z=10 * snap)
    p.add("Hive", x=-18 * whip)
    p.add("UpperArm.L", x=20 * snap, z=-14 * snap)
    swarm(p, t, burst=1.0 + 0.6 * snap)
    return p


def death(t):
    """Гибель (1.4 сек): выронил улей, рухнул на колени, завалился на спину; рой разлетается."""
    p = stance()
    K = [0.0, 0.2, 0.45, 0.75, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -16, 10, -10, -12]))
    p.add("Head", x=tr([0, -24, 20, -10, -12]), y=tr([0, 10, -6, 20, 24]))
    p.add("Thigh.L", x=tr([0, 6, -70, -40, -36])).add("Shin.L", x=tr([0, -6, 100, 60, 56]))
    p.add("Thigh.R", x=tr([0, -6, -64, -36, -30])).add("Shin.R", x=tr([0, 4, 104, 66, 60]))
    p.move("Hips", z=tr([-0.04, -0.02, -0.42, -0.5, -0.5]))
    p.set("Root", tr([0, 0, 0, -70, -76]), 0, 0)
    p.move("Root", y=tr([0, 0.04, 0.04, 0.3, 0.32]), z=tr([0, 0, 0, 0.1, 0.1]))
    p.add("UpperArm.R", x=tr([0, 20, 40, 10, 10]), z=tr([0, 20, 30, 50, 50]))
    p.add("Hive", x=tr([0, 30, 80, 90, 90]))
    p.size("Hive", tr([1, 1, 1, 0.001, 0.001]))
    p.add("UpperArm.L", x=tr([0, 20, 30, 0, 0]), z=tr([0, -20, -30, -50, -50]))
    swarm(p, t, speed=0.6, burst=tr([1, 1.4, 2.2, 3.0, 0.001]))
    p.add("ForeArm.L", x=-14 * pulse(t, 0.93, 0.04))
    return p


def build_actions(rig):
    sc = ("Hive", "Swarm", "Swarm2")
    k.bake(rig, "Idle", 100, idle, cyclic=True, scale_bones=sc)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=sc)
    k.bake(rig, "Attack", 24, attack, scale_bones=sc)
    k.bake(rig, "Hit", 15, hit, scale_bones=sc)
    k.bake(rig, "Death", 42, death, scale_bones=sc)


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
    glb = args[0] if args else os.path.join(here, "..", "grove_beekeeper.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_beekeeper.blend")
    build(glb, blend)
