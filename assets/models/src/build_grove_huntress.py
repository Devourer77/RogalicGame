# Ловчая Рощи (~1.7 м) — Хранители Рощи, лесная ветка акта 1. Тело — grove_kin.py (поуже Стража).
# Стройная лучница в серо-зелёной и бурой одежде, на плечах — тёмные перья, короткая накидка сзади.
# Резная птичья маска орехового дерева с длинным клювом, на лбу светится лист. Длинный лук из гнутой
# живой ветви (на нём листья), стрела на тетиве, колчан из коры за спиной. Облик — claude/мир.md;
# референс Gemini 17 ноября (набор «А»). Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (выстрел, линия 4), Hit, Death.
# Запуск: python3 build_grove_huntress.py out/grove_huntress.glb out/grove_huntress.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GroveHuntress"
g.setup(0.86, 0.95)
P = g.P

# Левая рука держит лук перед собой, правая — стрелу на тетиве у груди.
SH_L, EL_L, WR_L = P(0.24, 0.0, 1.33), P(0.3, -0.13, 1.13), P(0.27, -0.3, 1.04)
SH_R, EL_R, WR_R = P(-0.24, 0.0, 1.33), P(-0.31, -0.08, 1.1), P(-0.13, -0.2, 1.06)
FIST_L = Vector(WR_L) + (Vector(WR_L) - Vector(EL_L)).normalized() * 0.05 * g.W
FIST_R = Vector(WR_R) + (Vector(WR_R) - Vector(EL_R)).normalized() * 0.05 * g.W
BOW_HALF = 0.62 * g.H
ARROW_DIR = (FIST_L + Vector((0, -0.06, 0)) - FIST_R).normalized()


def bow_point(f):
    """Точка дуги лука: f от -1 (нижний конец) до 1 (верхний); середина выгнута вперёд."""
    return FIST_L + Vector((0, -0.14 * math.cos(f * math.pi / 2) + 0.03, BOW_HALF * f))


# ---------- Модель ----------

def build_mesh():
    M = g.materials("Huntress")
    g.legs(M)
    g.torso(M)
    g.arm_upper(M, "R", -1, SH_R, EL_R)
    g.arm_lower(M, "R", -1, EL_R, WR_R, fist_dir=(0.6, -0.6, 0.2))
    g.arm_upper(M, "L", 1, SH_L, EL_L)
    g.arm_lower(M, "L", 1, EL_L, WR_L, fist_dir=(-1, -0.2, 0))
    g.hood_and_head(M)
    g.bird_mask(M)
    g.feather_mantle(M)
    g.vines(M, count=2)

    # Лук (кость Bow): дуга из отрезков живой ветви, листья на концах, тетива
    n = 10
    pts = [bow_point(-1 + 2 * i / n) for i in range(n + 1)]
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        r = 0.022 - 0.01 * abs((i + 0.5) / n * 2 - 1)
        k.limb(f"Bow{i}", tuple(a), tuple(b), r, r, M["wood"], "Bow", segs=5)
    k.limb("Grip", tuple(FIST_L - Vector((0, 0, 0.07))), tuple(FIST_L + Vector((0, 0, 0.07))), 0.027, 0.027,
           M["leather"], "Bow", segs=6)
    k.limb("BowString", tuple(pts[0]), tuple(pts[-1]), 0.004, 0.004, M["string"], "Bow", segs=4)
    for i, end in enumerate((pts[1], pts[-2], pts[2])):
        g.leaf_at(M, f"BowLeaf{i}", tuple(end), "Bow", tilt=40 + 70 * i, size=0.08)
    k.limb("Twig", tuple(pts[-2]), tuple(pts[-2] + Vector((0.05, -0.06, 0.1))), 0.008, 0.003, M["wood"], "Bow", segs=4)

    # Стрела на тетиве (кость Arrow — исчезает при выстреле): древко, каменный наконечник, оперение
    tail = FIST_R - ARROW_DIR * 0.08
    head = FIST_L + ARROW_DIR * 0.12
    k.limb("ArrowShaft", tuple(tail), tuple(head), 0.007, 0.007, M["wood"], "Arrow", segs=4)
    k.limb("ArrowTip", tuple(head), tuple(head + ARROW_DIR * 0.07), 0.018, 0.0, M["stone"], "Arrow", segs=4)
    for j, up in enumerate(((0, 0, 1), (0.6, 0.6, -0.5))):
        k.plate(f"Fletch{j}", [(0, 0), (0.08, 0), (0.06, 0.03), (0.0, 0.025)], 0.004, tuple(tail),
                tuple(ARROW_DIR), up, M["feather"], "Arrow")

    # Колчан из коры за спиной со стрелами
    qc = P(0.07, 0.21, 1.12)
    k.box("Quiver", (0.11 * g.W, 0.1 * g.W, 0.44 * g.H), qc, M["fur_d"], "Chest", rot=(-12, 18, 0))
    k.box("QuiverBand", (0.12 * g.W, 0.11 * g.W, 0.04 * g.H), (qc[0], qc[1], qc[2] + 0.12), M["leather"], "Chest",
          rot=(-12, 18, 0))
    for i in range(4):
        x0 = qc[0] + 0.03 * (i - 1.5) + 0.06
        top = (x0 + 0.04, qc[1] + 0.06, qc[2] + 0.32 * g.H)
        k.limb(f"QArrow{i}", (x0, qc[1] + 0.02, qc[2] + 0.18), top, 0.006, 0.006, M["wood"], "Chest", segs=4)
        k.plate(f"QFletch{i}", [(0, 0), (0.07, 0), (0.06, 0.025), (0, 0.025)], 0.004, top, (0.3, 0.2, -1), (1, 0, 0),
                M["feather"], "Chest")
    k.limb("QuiverStrap", P(-0.2, -0.13, 1.38), P(0.18, -0.16, 0.98), 0.018 * g.W, 0.018 * g.W, M["leather"], "Spine", segs=4)
    return k.join_parts("GroveHuntressMesh")


# ---------- Скелет ----------

BONES = g.bones(SH_R, EL_R, WR_R, SH_L, EL_L, WR_L, extra={
    "Bow": (tuple(FIST_L), tuple(FIST_L + Vector((0, 0, 0.2))), "Hand.L"),
    "Arrow": (tuple(FIST_R), tuple(FIST_R + ARROW_DIR * 0.2), "Hand.R"),
})


# ---------- Анимации ----------
STANCE = dict(g.LEG_STANCE)
STANCE.update({"Spine": (4, -8, 0), "Chest": (2, -4, 0), "Head": (-6, 10, 0)})


def stance():
    return Pose(STANCE, g.STANCE_LOC)


def idle(t):
    """Покой (3.3 сек): дышит, вертит головой, как птица, — резко, с паузами; лук покачивается.
    Характерное: проверяет стрелу — подносит её к маске и опускает."""
    p = stance()
    breath, sway = g.idle_body(p, t)
    look = track(t, [(0, 0), (0.1, 0), (0.13, 28), (0.3, 28), (0.33, -20), (0.5, -20), (0.53, 6), (1, 6)])
    tilt = track(t, [(0, 0), (0.3, 0), (0.33, 12), (0.5, 12), (0.53, 0), (1, 0)])
    p.add("Head", y=look, z=tilt, x=-1.5 * breath)
    check = track(t, [(0, 0), (0.62, 0), (0.7, 1), (0.82, 1), (0.9, 0), (1, 0)])
    p.add("UpperArm.R", x=-26 * check - 1.5 * breath, z=-8 * check)
    p.add("ForeArm.R", x=-30 * check)
    p.add("Head", x=10 * check)
    p.add("UpperArm.L", x=-1.5 * breath + 2 * wave(t, 1, 0.3))
    p.add("Bow", x=3 * wave(t, 1, 0.15), z=2 * wave(t, 1, 0.4))
    return p


def walk(t):
    """Шаг (0.8 сек): лёгкий, крадущийся; лук опущен и покачивается."""
    p = Pose(STANCE)
    a = g.walk_body(p, t)
    p.add("Spine", x=4)
    p.add("UpperArm.L", x=-8 * a)
    p.add("UpperArm.R", x=8 * a)
    p.add("Bow", x=4 * wave(t, 2, 0.25))
    return p


def attack(t):
    """Выстрел (0.8 сек): поворачивается боком, поднимает лук, натягивает тетиву к маске → отпускает
    (к 0.4 сек): стрела исчезает, правая рука отлетает назад → лук опускается, стрела снова на тетиве."""
    p = stance()
    K = [0.0, 0.3, 0.48, 0.56, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", y=tr([0, 24, 26, 24, 0]), x=tr([0, -4, -4, -2, 0]))
    p.add("Chest", y=tr([0, 10, 10, 8, 0]))
    p.add("Head", y=tr([0, -26, -26, -22, 0]))
    p.add("UpperArm.L", x=tr([0, -58, -60, -56, 0]), z=tr([0, -10, -10, -8, 0]))
    p.add("ForeArm.L", x=tr([0, 10, 10, 8, 0]))
    p.add("Bow", x=tr([0, 52, 54, 58, 0]), y=tr([0, -10, -10, -10, 0]))
    p.add("UpperArm.R", x=tr([0, -60, -62, -40, 0]), z=tr([0, 30, 34, 50, 0]))
    p.add("ForeArm.R", x=tr([0, -70, -80, -40, 0]))
    shot = track(t, [(0, 1), (0.48, 1), (0.5, 0.0), (0.86, 0.0), (0.92, 1), (1, 1)])
    p.size("Arrow", max(shot, 0.001))
    p.move("Root", y=tr([0, 0.02, 0.02, 0.05, 0]))
    return p


def hit(t):
    """Получила удар (0.5 сек): отшатнулась, лук вскинулся, голова мотается."""
    p = stance()
    snap, whip = g.hit_body(p, t)
    p.add("UpperArm.L", x=20 * snap, z=-10 * snap)
    p.add("UpperArm.R", x=24 * snap, z=10 * snap)
    p.add("Bow", x=16 * whip)
    return p


def death(t):
    """Гибель (1.3 сек): выронила лук, осела на колени, завалилась набок; в конце рука дёргается."""
    p = stance()
    K = [0.0, 0.2, 0.45, 0.75, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -18, 20, 26, 26]), z=tr([0, 0, 6, 10, 10]))
    p.add("Head", x=tr([0, -26, 26, 30, 30]), y=tr([0, 14, 0, 20, 24]))
    p.add("Thigh.L", x=tr([0, 6, -70, -40, -36]))
    p.add("Shin.L", x=tr([0, -6, 100, 70, 66]))
    p.add("Thigh.R", x=tr([0, -6, -64, -36, -32]))
    p.add("Shin.R", x=tr([0, 4, 110, 76, 70]))
    p.move("Hips", z=tr([-0.04, -0.02, -0.4, -0.45, -0.46]))
    p.set("Root", 0, 0, tr([0, 0, -6, -78, -84]))
    p.move("Root", x=tr([0, 0, 0, 0.3, 0.32]), z=tr([0, 0, 0, 0.1, 0.1]))
    p.add("UpperArm.L", x=tr([0, 30, 40, 20, 18]), z=tr([0, -40, -30, -20, -20]))
    p.add("Bow", x=tr([0, 30, 60, 80, 80]), z=tr([0, 10, 30, 40, 40]))
    p.add("UpperArm.R", x=tr([0, 30, 20, -40, -44]))
    p.size("Arrow", tr([1, 1, 0.001, 0.001, 0.001]))
    p.add("Cloak", x=tr([0, -30, 10, 16, 16]))
    p.add("ForeArm.R", x=-14 * pulse(t, 0.92, 0.04))
    return p


def build_actions(rig):
    sc = ("Arrow",)
    k.bake(rig, "Idle", 100, idle, cyclic=True, scale_bones=sc)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=sc)
    k.bake(rig, "Attack", 24, attack, scale_bones=sc)
    k.bake(rig, "Hit", 15, hit, scale_bones=sc)
    k.bake(rig, "Death", 40, death, scale_bones=sc)


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
    glb = args[0] if args else os.path.join(here, "..", "grove_huntress.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_huntress.blend")
    build(glb, blend)
