# Отравительница (~1.6 м, всегда пригнута) — Хранители Рощи, лесная ветка акта 1. Тело — grove_kin.py.
# Худая фигура в тёмной серо-зелёной одежде, короткая бурая накидка с капюшоном, по ней побеги.
# Узкая вытянутая змеиная маска орехового дерева с косыми прорезями, на лбу светится лист.
# Длинная духовая трубка из тростника у маски, на поясе кожаные мешочки и глиняные пузырьки.
# Облик — claude/мир.md; референс Gemini 17 ноября (набор «А»). Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (дротик из трубки, линия 3, яд), Hit, Death.
# Запуск: python3 build_grove_poisoner.py out/grove_poisoner.glb out/grove_poisoner.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GrovePoisoner"
g.setup(0.82, 0.92)
P = g.P

# Обе руки подняты к маске: трубка у рта, смотрит вперёд.
MOUTH = Vector(P(0.0, -0.2, 1.53))
_D = Vector((0.08, -1.0, 0.36)).normalized()   # чуть вверх: стойка наклоняет корпус вперёд
SH_R, EL_R = P(-0.23, 0.0, 1.33), P(-0.3, -0.12, 1.2)
SH_L, EL_L = P(0.23, 0.0, 1.33), P(0.26, -0.22, 1.22)
FIST_R = MOUTH + _D * 0.09
FIST_L = MOUTH + _D * 0.33
WR_R = tuple(FIST_R - (FIST_R - Vector(EL_R)).normalized() * 0.05 * g.W)
WR_L = tuple(FIST_L - (FIST_L - Vector(EL_L)).normalized() * 0.05 * g.W)
PIPE_A = MOUTH + _D * 0.02
PIPE_B = MOUTH + _D * 0.95


# ---------- Модель ----------

def build_mesh():
    M = g.materials("Poisoner")
    g.legs(M)
    g.torso(M)
    g.arm_upper(M, "R", -1, SH_R, EL_R)
    g.arm_lower(M, "R", -1, EL_R, WR_R, fist_dir=(0, 0, -1))
    g.arm_upper(M, "L", 1, SH_L, EL_L)
    g.arm_lower(M, "L", 1, EL_L, WR_L, fist_dir=(0, 0, -1))
    g.hood_and_head(M)
    g.snake_mask(M)
    g.cape(M)
    g.vines(M, count=3)

    # Духовая трубка (кость Weapon): тростник с узлами-коленцами
    k.limb("Pipe", tuple(PIPE_A), tuple(PIPE_B), 0.018, 0.016, M["reed"], "Weapon", segs=6)
    for i in range(1, 5):
        c = PIPE_A + (PIPE_B - PIPE_A) * (i / 5)
        k.limb(f"Node{i}", tuple(c - _D * 0.012), tuple(c + _D * 0.012), 0.022, 0.022, M["wood"], "Weapon", segs=6)
    k.limb("Mouthpiece", tuple(PIPE_A - _D * 0.02), tuple(PIPE_A + _D * 0.04), 0.024, 0.02, M["leather"], "Weapon", segs=6)
    g.leaf_at(M, "PipeLeaf", tuple(PIPE_A + (PIPE_B - PIPE_A) * 0.7), "Weapon", tilt=60, size=0.08)

    # Пояс: кожаные мешочки и глиняные пузырьки
    for i, (x, y, z, r) in enumerate([(-0.17, -0.1, 0.84, 0.055), (0.17, -0.11, 0.84, 0.05), (0.2, 0.05, 0.83, 0.05)]):
        k.sphere(f"Pouch{i}", r * g.W, P(x, y, z), M["leather"], "Hips", scale=(1, 0.8, 1.2), segs=6, rings=4)
    for i, (x, y) in enumerate([(-0.08, -0.17), (-0.02, -0.18), (0.07, -0.17)]):
        k.barrel(f"Vial{i}", 0.026 * g.W, 0.018 * g.W, 0.76 * g.H, 0.86 * g.H, M["clay"], "Hips", segs=6, loc=P(x, y, 0)[:2])
        k.barrel(f"Cork{i}", 0.012 * g.W, 0.012 * g.W, 0.86 * g.H, 0.89 * g.H, M["wood"], "Hips", segs=5, loc=P(x, y, 0)[:2])
    return k.join_parts("GrovePoisonerMesh")


# ---------- Скелет ----------

BONES = g.bones(SH_R, EL_R, WR_R, SH_L, EL_L, WR_L, extra={
    "Weapon": (tuple(FIST_R), tuple(FIST_R + _D * 0.2), "Hand.R"),
})


# ---------- Анимации ----------
# Пригнутая стойка: колени согнуты сильнее, корпус вперёд, голова поднята к цели.
STANCE = dict(g.LEG_STANCE)
STANCE.update({
    "Thigh.L": (-40, 0, -8), "Shin.L": (52, 0, 0), "Foot.L": (-10, 0, 0),
    "Thigh.R": (-6, 0, 10), "Shin.R": (50, 0, 0), "Foot.R": (-30, 0, 0),
    "Spine": (18, -8, 0), "Chest": (8, -4, 0), "Head": (-20, 6, 0),
    "Cloak": (16, 0, 0), "FlapF": (-26, 0, 0), "FlapB": (16, 0, 0),
})
STANCE_LOC = {"Hips": (0, 0, -0.16)}
LOWER = 10   # в покое трубка чуть опущена (больше нельзя: левая кисть съезжает с трубки)


def stance():
    return Pose(STANCE, STANCE_LOC)


def pipe(p, x=0.0, z=0.0):
    """Обе руки вместе (трубка в двух руках)."""
    p.add("UpperArm.R", x=x, z=z)
    p.add("UpperArm.L", x=x, z=z)


def idle(t):
    """Покой (3.3 сек): сидит пригнувшись, трубка опущена; голова ходит, как у змеи, — плавно из стороны
    в сторону. Характерное: вскидывает трубку, прицеливается и снова опускает."""
    p = stance()
    breath, sway = g.idle_body(p, t)
    p.add("Head", y=16 * wave(t, 1, 0.1), z=8 * wave(t, 1, 0.35), x=-2 * breath)
    aim = track(t, [(0, 0), (0.56, 0), (0.64, 1), (0.82, 1), (0.9, 0), (1, 0)])
    pipe(p, x=LOWER * (1 - aim) - 1.5 * breath)
    p.add("Spine", x=-6 * aim)
    p.add("Weapon", x=4 * wave(t, 1, 0.2) * (1 - aim))
    return p


def walk(t):
    """Шаг (0.8 сек): крадётся пригнувшись, трубка опущена."""
    p = Pose(STANCE, STANCE_LOC)
    a = g.walk_body(p, t)
    p.move("Hips", z=-0.12)
    p.add("Thigh.L", x=-24).add("Thigh.R", x=-24).add("Shin.L", x=30).add("Shin.R", x=30)
    p.add("Spine", x=14)
    pipe(p, x=LOWER + 4 * wave(t, 2, 0.2))
    p.add("Head", x=-14)
    return p


def attack(t):
    """Дротик (0.8 сек): вскидывает трубку к маске, вдох — корпус чуть назад → резкий выдох (к 0.4 сек):
    голова и трубка дёргаются вперёд → пауза → трубка опускается."""
    p = stance()
    K = [0.0, 0.3, 0.45, 0.5, 0.62, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    pipe(p, x=tr([LOWER, 0, -2, -6, -3, LOWER]))
    p.add("Spine", x=tr([0, -10, -12, 4, 2, 0]))
    p.add("Chest", x=tr([0, -6, -8, 6, 2, 0]))
    p.add("Head", x=tr([0, 4, 4, 0, 2, 0]))
    p.size("Weapon", tr([1, 1, 1, 1.06, 1.0, 1]))
    p.move("Root", y=tr([0, 0.03, 0.04, -0.04, -0.02, 0]))
    return p


def hit(t):
    """Получила удар (0.5 сек): отпрянула, трубка задралась, голова мотается."""
    p = stance()
    snap, whip = g.hit_body(p, t)
    pipe(p, x=LOWER + 20 * snap)
    p.add("Weapon", x=10 * whip)
    return p


def death(t):
    """Гибель (1.2 сек): выронила трубку, схватилась за грудь, завалилась на бок и свернулась."""
    p = stance()
    K = [0.0, 0.2, 0.5, 0.8, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -20, 10, 20, 20]))
    p.add("Head", x=tr([0, -30, 20, 30, 30]), y=tr([0, 10, -10, -20, -22]))
    pipe(p, x=tr([LOWER, 70, 60, 40, 40]))
    p.add("UpperArm.L", z=tr([0, -10, -20, -30, -30]))
    p.add("Weapon", x=tr([0, 30, 70, 90, 90]), z=tr([0, 20, 40, 50, 50]))
    p.add("Thigh.L", x=tr([0, 10, -30, -40, -40])).add("Shin.L", x=tr([0, -10, 40, 60, 60]))
    p.add("Thigh.R", x=tr([0, 10, -20, -50, -50])).add("Shin.R", x=tr([0, -10, 30, 70, 70]))
    p.move("Hips", z=tr([-0.16, -0.1, -0.3, -0.4, -0.4]))
    p.set("Root", 0, 0, tr([0, 0, 20, 80, 84]))
    p.move("Root", x=tr([0, 0, -0.1, -0.3, -0.32]), z=tr([0, 0, 0.04, 0.1, 0.1]))
    p.add("Cloak", x=tr([0, -20, 0, 10, 10]))
    p.add("Hand.L", x=-20 * pulse(t, 0.92, 0.04))
    return p


def build_actions(rig):
    sc = ("Weapon",)
    k.bake(rig, "Idle", 100, idle, cyclic=True, scale_bones=sc)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=sc)
    k.bake(rig, "Attack", 24, attack, scale_bones=sc)
    k.bake(rig, "Hit", 15, hit, scale_bones=sc)
    k.bake(rig, "Death", 36, death, scale_bones=sc)


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
    glb = args[0] if args else os.path.join(here, "..", "grove_poisoner.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_poisoner.blend")
    build(glb, blend)
