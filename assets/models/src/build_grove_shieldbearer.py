# Щит Коры (~1.9 м, самый крупный из Хранителей) — Хранители Рощи, лесная ветка акта 1. Тело — grove_kin.py.
# Широкий и массивный, тяжёлая бурая шкура на плечах, побеги. Широкая плоская маска-щит с острым низом.
# В левой руке — огромный круглый щит из цельного спила ствола: годовые кольца, кора по краю, мох.
# Облик — claude/мир.md; референс Gemini 17 ноября (набор «А», щит темнее). Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (толчок щитом, толчок 1), Hit, Death.
# Запуск: python3 build_grove_shieldbearer.py out/grove_shieldbearer.glb out/grove_shieldbearer.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GroveShieldbearer"
g.setup(1.16, 1.05)
P = g.P

# Левая рука держит щит перед собой, правая — свободный тяжёлый кулак.
SH_L, EL_L, WR_L = P(0.26, 0.0, 1.33), P(0.33, -0.17, 1.12), P(0.17, -0.3, 1.02)
SH_R, EL_R, WR_R = P(-0.26, 0.0, 1.33), P(-0.35, -0.02, 1.08), P(-0.33, -0.13, 0.9)
SH_C = Vector(P(0.06, -0.4, 0.86))   # центр щита
SH_N = Vector((0.12, -1.0, 0.0)).normalized()   # куда смотрит лицо щита
SH_R_ = 0.42


# ---------- Модель ----------

def build_mesh():
    M = g.materials("Shieldbearer")
    g.legs(M)
    g.torso(M)
    g.arm_upper(M, "R", -1, SH_R, EL_R)
    g.arm_lower(M, "R", -1, EL_R, WR_R, fist_dir=(0, -1, -0.2))
    g.arm_upper(M, "L", 1, SH_L, EL_L)
    g.arm_lower(M, "L", 1, EL_L, WR_L, fist_dir=(0, 0, 1))
    g.hood_and_head(M)
    g.shield_mask(M)
    g.fur_mantle(M, big=1.08)
    g.vines(M, count=3)

    # Щит-спил (кость Shield): диск-цилиндр, кора по краю, кольца на лице, мох и трещина
    back = SH_C - SH_N * 0.05
    face = SH_C + SH_N * 0.05
    k.limb("ShieldBark", tuple(back), tuple(face - SH_N * 0.01), SH_R_ * 1.03, SH_R_ * 1.03, M["bark"], "Shield", segs=10)
    k.limb("ShieldFace", tuple(face - SH_N * 0.012), tuple(face + SH_N * 0.003), SH_R_ * 0.95, SH_R_ * 0.95,
           M["cut"], "Shield", segs=10)
    for i, rr in enumerate((0.72, 0.48, 0.24)):
        k.limb(f"Ring{i}", tuple(face + SH_N * 0.001), tuple(face + SH_N * 0.006), SH_R_ * rr, SH_R_ * rr,
               M["ring"] if i % 2 == 0 else M["cut"], "Shield", segs=9)
    up = Vector((0, 0, 1))
    side = SH_N.cross(up).normalized()
    k.box("Crack", (0.015, 0.012, SH_R_ * 0.7), tuple(face + SH_N * 0.008 + side * 0.08 + up * 0.12), M["bark"],
          "Shield", rot=(0, 18, 0))
    for i, a in enumerate((0.3, 0.9, 1.6, 2.6)):
        pos = SH_C + (side * math.cos(a) + up * math.sin(a)) * SH_R_ * 0.98
        k.sphere(f"ShieldMoss{i}", 0.07, tuple(pos), M["moss"], "Shield", scale=(1.3, 0.8, 0.6), segs=5, rings=3)
    k.box("ShieldGrip", (0.05, 0.04, 0.18), tuple(SH_C - SH_N * 0.08), M["leather"], "Shield")
    return k.join_parts("GroveShieldbearerMesh")


# ---------- Скелет ----------

FIST_L = Vector(WR_L) + (Vector(WR_L) - Vector(EL_L)).normalized() * 0.05 * g.W
BONES = g.bones(SH_R, EL_R, WR_R, SH_L, EL_L, WR_L, extra={
    "Shield": (tuple(FIST_L), tuple(FIST_L + Vector((0, 0, 0.2))), "Hand.L"),
})


# ---------- Анимации ----------
STANCE = dict(g.LEG_STANCE)
STANCE.update({"Spine": (6, -6, 0), "Chest": (4, -4, 0), "Head": (-6, 8, 0),
               "Thigh.L": (-20, 0, -10), "Thigh.R": (8, 0, 12),
               "UpperArm.R": (-10, 0, 8), "ForeArm.R": (-20, 0, 0)})
STANCE_LOC = {"Hips": (0, 0, -0.06)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3.3 сек): стоит стеной, тяжело дышит, щит чуть ходит. Характерное: бьёт кулаком в щит
    (глухой стук) — щит вздрагивает."""
    p = stance()
    breath, sway = g.idle_body(p, t)
    p.add("Head", y=14 * wave(t, 1, 0.15), x=-breath)
    knock = track(t, [(0, 0), (0.55, 0), (0.62, 1), (0.66, 0.4), (0.7, 1), (0.74, 0.3), (0.85, 0), (1, 0)])
    p.add("UpperArm.R", x=-34 * knock, z=-20 * knock)
    p.add("ForeArm.R", x=-50 * knock)
    p.add("Shield", x=3 * pulse(t, 0.63, 0.03) + 3 * pulse(t, 0.71, 0.03) + 2 * wave(t, 1, 0.3))
    p.add("UpperArm.L", x=-1.5 * breath)
    return p


def walk(t):
    """Шаг (0.8 сек): тяжёлый, щит впереди, корпус почти не крутится."""
    p = Pose(STANCE, STANCE_LOC)
    a = g.walk_body(p, t)
    p.add("Spine", y=4 * a)
    p.add("UpperArm.R", x=-14 * a)
    p.add("Shield", x=3 * wave(t, 2, 0.1))
    return p


def attack(t):
    """Толчок щитом (0.85 сек): отводит щит и корпус назад → рывок всем телом, щит впечатывается
    в цель (к 0.4 сек) → держит → возврат."""
    p = stance()
    K = [0.0, 0.26, 0.47, 0.6, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.move("Root", y=tr([0, 0.1, -0.3, -0.28, 0]))
    p.move("Hips", z=tr([-0.06, -0.08, -0.12, -0.11, -0.06]))
    p.add("Spine", x=tr([0, -10, 14, 12, 0]), y=tr([0, -18, 8, 6, 0]))
    p.add("Chest", x=tr([0, -4, 8, 6, 0]))
    p.add("UpperArm.L", x=tr([0, 16, -24, -20, 0]), z=tr([0, 6, -6, -4, 0]))
    p.add("Shield", x=tr([0, 6, -10, -8, 0]))
    p.add("UpperArm.R", x=tr([0, 20, 6, 4, 0]))
    p.add("Thigh.L", x=tr([0, 8, -30, -28, 0])).add("Shin.L", x=tr([0, -6, 26, 24, 0]))
    p.add("Thigh.R", x=tr([0, -8, 18, 16, 0])).add("Foot.R", x=tr([0, 0, 24, 22, 0]))
    p.add("Cloak", x=tr([0, -8, 24, 16, 0]))
    return p


def hit(t):
    """Получил удар (0.5 сек): щит принимает удар — его отбрасывает, корпус качается меньше обычного."""
    p = stance()
    snap, whip = g.hit_body(p, t)
    p.add("Spine", x=8 * snap)   # массивный: отшатывается слабее
    p.add("UpperArm.L", x=20 * snap)
    p.add("Shield", x=12 * whip)
    p.add("UpperArm.R", x=14 * snap, z=10 * snap)
    return p


def death(t):
    """Гибель (1.5 сек): шатается, падает на колено, опускает щит, валится набок — щит ложится на него."""
    p = stance()
    K = [0.0, 0.2, 0.45, 0.75, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -14, 14, 20, 20]))
    p.add("Head", x=tr([0, -22, 20, 26, 26]), y=tr([0, 10, -6, -14, -16]))
    p.add("Thigh.L", x=tr([0, 6, -70, -40, -36])).add("Shin.L", x=tr([0, -6, 96, 64, 60]))
    p.add("Thigh.R", x=tr([0, -6, -50, -30, -28])).add("Shin.R", x=tr([0, 4, 104, 70, 66]))
    p.move("Hips", z=tr([-0.06, -0.04, -0.44, -0.5, -0.5]))
    p.set("Root", 0, 0, tr([0, 0, 6, 80, 86]))
    p.move("Root", x=tr([0, 0, 0, -0.34, -0.36]), z=tr([0, 0, 0, 0.12, 0.12]))
    p.add("UpperArm.L", x=tr([0, 20, 30, 10, 10]), z=tr([0, -10, -20, -40, -40]))
    p.add("Shield", x=tr([0, 10, 30, 50, 50]))
    p.add("UpperArm.R", x=tr([0, 30, 20, -20, -24]), z=tr([0, 20, 30, 40, 40]))
    p.add("ForeArm.R", x=-14 * pulse(t, 0.93, 0.04))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 100, idle, cyclic=True)
    k.bake(rig, "Walk", 24, walk, cyclic=True)
    k.bake(rig, "Attack", 26, attack)
    k.bake(rig, "Hit", 15, hit)
    k.bake(rig, "Death", 45, death)


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
    glb = args[0] if args else os.path.join(here, "..", "grove_shieldbearer.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_shieldbearer.blend")
    build(glb, blend)
