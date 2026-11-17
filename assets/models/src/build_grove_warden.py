# Страж Рощи (~1.8 м) — Хранители Рощи, лесная ветка акта 1. База тела всех Хранителей (grove_kin.py).
# Крепкий человек в серо-зелёной шерстяной рубахе, на плечах — тяжёлая бурая шкура с клочьями меха,
# за спиной плащ из шкуры; по шкуре вьются живые побеги с листьями. Голова целиком под бурым капюшоном,
# спереди — гладкая овальная маска орехового дерева с узкими прорезями, на лбу светится вырезанный лист.
# Длинное деревянное копьё с каменным наконечником, по древку вьётся побег. Держит копьё двумя руками,
# остриём вперёд-вверх — «охраняет». Облик — claude/мир.md; референс Gemini 17 ноября (набор «А»).
# Смотрит в -Y (после экспорта в glTF это +Z).
#
# Анимации: Idle, Walk, Attack (выпад копьём, линия 2), Hit, Death.
# Запуск: python3 build_grove_warden.py out/grove_warden.glb out/grove_warden.blend (рядом char_kit.py)
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GroveWarden"
g.setup(1.0, 1.0)
P = g.P

# Хватка: правая кисть у бедра, левая впереди на древке; копьё смотрит вперёд-влево-вверх.
SH_R, EL_R, WR_R = P(-0.25, 0.0, 1.33), P(-0.31, 0.04, 1.1), P(-0.25, -0.11, 0.97)
SH_L, EL_L = P(0.25, 0.0, 1.33), P(0.24, -0.2, 1.14)
_D = Vector((0.36, -0.72, 0.6)).normalized()
FIST_R = Vector(WR_R) + (Vector(WR_R) - Vector(EL_R)).normalized() * 0.05
FIST_L = FIST_R + _D * 0.36
WR_L = tuple(FIST_L - (FIST_L - Vector(EL_L)).normalized() * 0.05)
SPEAR_A = FIST_R - _D * 0.55         # пятка копья (сзади-справа, у земли)
SPEAR_B = FIST_R + _D * 1.38         # начало наконечника
TIP = SPEAR_B + _D * 0.32


# ---------- Модель ----------

def build_mesh():
    M = g.materials("Warden")
    g.legs(M)
    g.torso(M)
    g.arm_upper(M, "R", -1, SH_R, EL_R)
    g.arm_lower(M, "R", -1, EL_R, WR_R, fist_dir=(0.3, -1, 0.2))
    g.arm_upper(M, "L", 1, SH_L, EL_L)
    g.arm_lower(M, "L", 1, EL_L, WR_L, fist_dir=(-0.4, -0.6, -0.6))
    g.hood_and_head(M)
    g.oval_mask(M)
    g.fur_mantle(M)
    g.vines(M)

    # Копьё (кость Weapon): древко, кожаная обмотка, каменный наконечник-ромб, побег вокруг древка
    k.limb("Shaft", tuple(SPEAR_A), tuple(SPEAR_B), 0.022, 0.02, M["wood"], "Weapon", segs=6)
    k.limb("Butt", tuple(SPEAR_A - _D * 0.04), tuple(SPEAR_A + _D * 0.06), 0.018, 0.026, M["wood"], "Weapon", segs=5)
    k.limb("Binding", tuple(SPEAR_B - _D * 0.09), tuple(SPEAR_B + _D * 0.02), 0.028, 0.026, M["leather"], "Weapon", segs=6)
    side = _D.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(_D).normalized()
    base = SPEAR_B + _D * 0.02
    k.limb("TipBack", tuple(base), tuple(base + _D * 0.1), 0.024, 0.068, M["stone"], "Weapon", segs=4)
    k.limb("Tip", tuple(base + _D * 0.1), tuple(TIP), 0.068, 0.0, M["stone"], "Weapon", segs=4)
    # Побег по древку — спираль из коротких отрезков, на нём листья
    turns, n = 2.0, 10
    pts = []
    for i in range(n + 1):
        f = i / n
        a = math.tau * turns * f
        c = FIST_R + _D * (0.12 + 1.0 * f)
        pts.append(c + (side * math.cos(a) + up * math.sin(a)) * 0.028)
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        k.limb(f"SpearVine{i}", tuple(a), tuple(b), 0.009, 0.009, M["vine"], "Weapon", segs=4)
        if i in (2, 6, 9):
            g.leaf_at(M, f"SpearLeaf{i}", tuple(b), "Weapon", tilt=i * 40, size=0.055)
    return k.join_parts("GroveWardenMesh")


# ---------- Скелет ----------

BONES = g.bones(SH_R, EL_R, WR_R, SH_L, EL_L, WR_L, extra={
    "Weapon": (tuple(FIST_R), tuple(FIST_R + _D * 0.2), "Hand.R"),
})


# ---------- Анимации ----------
# Копьё и обе руки уже стоят в модели как надо, поэтому руки в стойке почти не поворачиваются.
STANCE = dict(g.LEG_STANCE)
STANCE.update({"Spine": (6, -10, 0), "Chest": (4, -6, 0), "Head": (-4, 14, 0)})


def stance():
    return Pose(STANCE, g.STANCE_LOC)


def arms(p, x=0.0, z=0.0):
    """Обе руки вместе (копьё в двух руках): x — наклон вперёд-назад, z — вбок."""
    p.add("UpperArm.R", x=x, z=z)
    p.add("UpperArm.L", x=x, z=z)


def idle(t):
    """Покой (3.3 сек): дышит, переносит вес, оглядывает лес, остриё копья медленно ходит.
    Характерное: прислушивается — наклоняет голову набок и замирает, потом перехватывает копьё."""
    p = stance()
    breath, sway = g.idle_body(p, t)
    look = track(t, [(0, 0), (0.12, 0), (0.26, 22), (0.4, 22), (0.52, -16), (0.6, -16), (0.66, 0), (1, 0)])
    listen = track(t, [(0, 0), (0.42, 0), (0.48, 1), (0.6, 1), (0.66, 0), (1, 0)])
    p.add("Head", y=look, z=-14 * listen, x=-1.5 * breath)
    regrip = pulse(t, 0.82, 0.08)
    arms(p, x=-1.5 * breath - 10 * regrip + 2 * wave(t, 1, 0.2), z=1.5 * wave(t, 1, 0.45))
    p.add("Chest", y=2 * wave(t, 1, 0.3))
    p.add("Weapon", x=3 * wave(t, 1, 0.1))
    return p


def walk(t):
    """Шаг (0.8 сек): идёт, держа копьё наготове; остриё подрагивает в такт шагам."""
    p = Pose(STANCE)
    a = g.walk_body(p, t)
    arms(p, x=3 * wave(t, 2, 0.2), z=2 * a)
    p.add("Weapon", x=3 * wave(t, 2, 0.3))
    return p


def attack(t):
    """Выпад копьём (0.8 сек): отводит копьё и корпус назад → выпад на левую ногу, остриё вперёд
    (к 0.4 сек) → держит → возврат."""
    p = stance()
    K = [0.0, 0.3, 0.5, 0.64, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.move("Root", y=tr([0, 0.08, -0.3, -0.28, 0]))
    p.move("Hips", z=tr([-0.04, -0.05, -0.12, -0.11, -0.04]))
    p.add("Spine", x=tr([0, -10, 18, 16, 0]), y=tr([0, -10, 8, 6, 0]))
    p.add("Chest", x=tr([0, -6, 10, 8, 0]))
    p.add("Head", x=tr([0, 8, -16, -14, 0]))
    arms(p, x=tr([0, 14, -22, -18, 0]))
    p.add("ForeArm.R", x=tr([0, -6, 8, 6, 0]))
    p.add("Thigh.L", x=tr([0, 6, -30, -28, 0]))
    p.add("Shin.L", x=tr([0, -6, 22, 20, 0]))
    p.add("Thigh.R", x=tr([0, -6, 16, 14, 0]))
    p.add("Shin.R", x=tr([0, 4, -8, -6, 0]))
    p.add("Foot.R", x=tr([0, 0, 22, 20, 0]))
    p.add("Cloak", x=tr([0, -6, 26, 18, 0]))
    p.add("FlapF", x=tr([0, 4, -20, -14, 0])).add("FlapB", x=tr([0, -4, 20, 12, 0]))
    return p


def hit(t):
    """Получил удар (0.5 сек): отшатнулся, копьё вздёрнулось, голова мотается следом."""
    p = stance()
    snap, whip = g.hit_body(p, t)
    arms(p, x=16 * snap, z=6 * snap)
    p.add("Weapon", x=12 * whip)
    return p


def death(t):
    """Гибель (1.4 сек): выпустил копьё левой рукой, рухнул на колени, опёрся на копьё, завалился вперёд;
    в конце рука коротко дёргается."""
    p = stance()
    K = [0.0, 0.18, 0.42, 0.66, 0.86, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -16, 16, 24, 30, 30]))
    p.add("Chest", x=tr([0, -10, 10, 16, 14, 14]))
    p.add("Head", x=tr([0, -24, 20, 36, 20, 20]), y=tr([0, 10, 0, 10, 28, 30]))
    p.add("Thigh.L", x=tr([0, 6, -60, -62, -10, -6]))
    p.add("Shin.L", x=tr([0, -6, 90, 92, 16, 10]))
    p.add("Thigh.R", x=tr([0, -6, -58, -60, -6, -2]))
    p.add("Shin.R", x=tr([0, 4, 100, 102, 16, 8]))
    p.add("Foot.R", x=tr([0, 0, 40, 40, 30, 30]))
    p.move("Hips", z=tr([-0.04, -0.02, -0.38, -0.4, -0.12, -0.12]))
    lean = tr([0, -4, 4, 8, 82, 84])
    p.set("Root", lean, 0, 0)
    p.move("Root", y=tr([0, 0.08, 0.04, 0.02, -0.32, -0.32]), z=tr([0, 0, 0, 0, 0.14, 0.14]))
    p.add("UpperArm.L", x=tr([0, 30, 50, 40, -60, -70]), z=tr([0, -30, -40, -30, -20, -20]))
    p.add("ForeArm.L", x=tr([0, 20, 30, 20, 0, 0]))
    p.add("UpperArm.R", x=tr([0, 10, -10, -16, -80, -90]), z=tr([0, 10, 10, 10, 20, 24]))
    p.add("Weapon", x=tr([0, 10, -20, -26, -50, -56]), z=tr([0, 0, 10, 14, 40, 44]))
    p.add("Cloak", x=tr([0, -30, 10, 20, 4, 0]))
    p.add("FlapF", x=tr([0, -20, -40, -40, -10, -6])).add("FlapB", x=tr([0, -10, 20, 24, 0, 0]))
    p.add("ForeArm.R", x=-12 * pulse(t, 0.93, 0.04))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 100, idle, cyclic=True)
    k.bake(rig, "Walk", 24, walk, cyclic=True)
    k.bake(rig, "Attack", 24, attack)
    k.bake(rig, "Hit", 15, hit)
    k.bake(rig, "Death", 42, death)


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
    glb = args[0] if args else os.path.join(here, "..", "grove_warden.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_warden.blend")
    build(glb, blend)
