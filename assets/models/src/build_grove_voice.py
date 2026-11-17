# Голос Рощи (~2.2 м, элита) — Хранители Рощи, лесная ветка акта 1. Тело — grove_kin.py (выше и стройнее всех).
# Длинная тёмно-бурая ряса из коры и кожи, тёмный пятнистый плащ из мха и шкуры. Большая круглая маска-спил
# ствола: кора по краю, годовые кольца светятся бледным серебристо-зелёным ярче, чем у остальных. Над маской —
# низкий венок живых побегов (без рогов). В левой руке посох — живая ветвь с крюком и свежими листьями.
# Облик — claude/мир.md; референс Gemini 17 ноября (перерисованный). Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (Зов: призыв двух Стражей), Attack2 (Корни: линия сквозь преграды,
# опутывает), Attack3 (укрепить своих: аура), Hit, Death.
# Запуск: python3 build_grove_voice.py out/grove_voice.glb out/grove_voice.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GroveVoice"
g.setup(0.95, 1.22)
P = g.P

# Левая рука держит посох стоймя, правая опущена ладонью вперёд (поднимается, когда он «говорит»).
SH_L, EL_L, WR_L = P(0.24, 0.0, 1.33), P(0.37, -0.04, 1.16), P(0.35, -0.13, 1.33)
SH_R, EL_R, WR_R = P(-0.24, 0.0, 1.33), P(-0.33, -0.04, 1.1), P(-0.31, -0.14, 0.94)
FIST_L = Vector(WR_L) + (Vector(WR_L) - Vector(EL_L)).normalized() * 0.05 * g.W
STAFF_A = Vector((FIST_L.x, FIST_L.y, 0.04))
STAFF_B = Vector((FIST_L.x + 0.03, FIST_L.y - 0.03, FIST_L.z + 0.62))


# ---------- Модель ----------

def build_mesh():
    M = g.materials("Voice")
    R = dict(M, cloth=M["fur_d"], cloth_d=M["hood"])          # ряса — бурая, из коры и кожи
    g.legs(M)
    g.robe(R)
    g.torso(R, skirt=False)
    g.arm_upper(R, "R", -1, SH_R, EL_R)
    g.arm_lower(R, "R", -1, EL_R, WR_R, fist_dir=(0, -1, -0.2))
    g.arm_upper(R, "L", 1, SH_L, EL_L)
    g.arm_lower(R, "L", 1, EL_L, WR_L, fist_dir=(-1, -0.3, 0))
    g.hood_and_head(M)
    g.slice_mask(M)
    g.fur_mantle(dict(M, fur=M["moss"], fur_d=M["fur_d"]), big=1.0)   # пятнистый мох и шкура
    g.vines(M, count=3)

    # Посох (кость Staff): живая ветвь, наверху крюк-завиток с листьями
    n = 5
    pts = [STAFF_A.lerp(STAFF_B, i / n) + Vector((0.018 * math.sin(i * 1.9), 0.012 * math.cos(i * 2.3), 0)) for i in range(n + 1)]
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        k.limb(f"Staff{i}", tuple(a), tuple(b), 0.028 - 0.003 * i, 0.025 - 0.003 * i, M["wood"], "Staff", segs=6)
    hook = [STAFF_B, STAFF_B + Vector((-0.06, -0.02, 0.12)), STAFF_B + Vector((-0.16, -0.03, 0.14)),
            STAFF_B + Vector((-0.2, -0.03, 0.06))]
    for i, (a, b) in enumerate(zip(hook, hook[1:])):
        k.limb(f"Hook{i}", tuple(a), tuple(b), 0.016 - 0.003 * i, 0.013 - 0.003 * i, M["wood"], "Staff", segs=5)
    for i, at in enumerate(hook[1:] + [STAFF_A.lerp(STAFF_B, 0.8)]):
        g.leaf_at(M, f"StaffLeaf{i}", tuple(at), "Staff", tilt=30 + 55 * i, size=0.1)
    return k.join_parts("GroveVoiceMesh")


# ---------- Скелет ----------

BONES = g.bones(SH_R, EL_R, WR_R, SH_L, EL_L, WR_L, extra={
    "Staff": (tuple(FIST_L), tuple(FIST_L + Vector((0, 0, 0.2))), "Hand.L"),
})


# ---------- Анимации ----------
STANCE = dict(g.LEG_STANCE)
STANCE.update({"Spine": (0, -6, 0), "Chest": (-3, -4, 0), "Head": (-4, 8, 0),
               "Thigh.L": (-10, 0, -4), "Shin.L": (12, 0, 0), "Thigh.R": (4, 0, 6), "Shin.R": (8, 0, 0),
               "FlapF": (-4, 0, 0), "FlapB": (2, 0, 0), "UpperArm.R": (-12, 0, 6)})
STANCE_LOC = {"Hips": (0, 0, -0.015)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3.5 сек): стоит прямо и величаво, медленно дышит. Характерное: поднимает правую руку ладонью
    вперёд — «говорит» за лес — и медленно опускает."""
    p = stance()
    breath, sway = g.idle_body(p, t)
    speak = track(t, [(0, 0), (0.3, 0), (0.45, 1), (0.7, 1), (0.85, 0), (1, 0)])
    p.add("UpperArm.R", x=-90 * speak, z=16 * speak)
    p.add("ForeArm.R", x=-40 * speak)
    p.add("Hand.R", x=30 * speak)
    p.add("Head", x=-8 * speak + 2 * breath, y=8 * wave(t, 1, 0.1) * (1 - speak))
    p.add("Staff", x=2 * wave(t, 1, 0.2))
    return p


def walk(t):
    """Шаг (0.9 сек): медленный и плавный, ряса колышется, посох ставит в такт."""
    p = Pose(STANCE, STANCE_LOC)
    a = g.walk_body(p, t)
    p.add("Thigh.R", x=6).add("Thigh.L", x=6)
    p.add("UpperArm.R", x=10 * a)
    p.add("Staff", x=5 * wave(t, 2, 0.2))
    return p


def attack(t):
    """Зов (0.9 сек): разводит руки и вскидывает их вверх (к 0.4 сек) — лес отвечает, появляются Стражи."""
    p = stance()
    K = [0.0, 0.3, 0.46, 0.65, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("UpperArm.R", x=tr([0, -40, -150, -140, 0]), z=tr([0, 40, 20, 18, 0]))
    p.add("ForeArm.R", x=tr([0, -10, -10, -8, 0]))
    p.add("UpperArm.L", x=tr([0, -20, -60, -56, 0]), z=tr([0, -20, -20, -16, 0]))
    p.add("Spine", x=tr([0, 6, -14, -12, 0]))
    p.add("Chest", x=tr([0, 4, -10, -8, 0]))
    p.add("Head", x=tr([0, 10, -24, -20, 0]))
    return p


def attack2(t):
    """Корни (0.85 сек): заносит посох → со всей силы бьёт пяткой посоха в землю перед собой (к 0.4 сек),
    приседая; корни идут к цели."""
    p = stance()
    K = [0.0, 0.3, 0.46, 0.6, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("UpperArm.L", x=tr([0, -60, -20, -18, 0]), z=tr([0, -10, -4, -4, 0]))
    p.add("ForeArm.L", x=tr([0, -20, 10, 8, 0]))
    p.add("Staff", x=tr([0, -10, 16, 14, 0]))
    p.add("Spine", x=tr([0, -10, 18, 16, 0]))
    p.add("Head", x=tr([0, -6, 10, 8, 0]))
    p.add("UpperArm.R", x=tr([0, -30, 10, 8, 0]), z=tr([0, 30, 20, 16, 0]))
    p.move("Hips", z=tr([-0.015, 0.02, -0.12, -0.1, -0.015]))
    p.add("Thigh.L", x=tr([0, 0, -20, -18, 0])).add("Shin.L", x=tr([0, 0, 24, 22, 0]))
    return p


def attack3(t):
    """Укрепить своих (0.9 сек): широко разводит руки ладонями вниз (к 0.4 сек) — знаки на маске вспыхивают."""
    p = stance()
    K = [0.0, 0.32, 0.46, 0.7, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("UpperArm.R", x=tr([0, -40, -70, -66, 0]), z=tr([0, 50, 60, 56, 0]))
    p.add("UpperArm.L", x=tr([0, -20, -30, -28, 0]), z=tr([0, -40, -50, -46, 0]))
    p.add("Head", x=tr([0, -10, -4, -4, 0]))
    p.size("Head", tr([1, 1.0, 1.06, 1.03, 1]))
    return p


def hit(t):
    """Получил удар (0.5 сек): отшатнулся, посох качнулся, голова мотается."""
    p = stance()
    snap, whip = g.hit_body(p, t)
    p.add("UpperArm.R", x=20 * snap, z=10 * snap).add("UpperArm.L", x=10 * snap)
    p.add("Staff", x=-12 * whip)
    return p


def death(t):
    """Гибель (1.6 сек): опирается на посох, оседает, долго клонится и падает вперёд; кольца маски гаснут
    вместе с ним (делает игра)."""
    p = stance()
    K = [0.0, 0.2, 0.5, 0.8, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -12, 20, 26, 26]))
    p.add("Head", x=tr([0, -24, 30, 30, 30]))
    p.add("Thigh.L", x=tr([0, 4, -70, -10, -6])).add("Shin.L", x=tr([0, -4, 100, 14, 10]))
    p.add("Thigh.R", x=tr([0, -4, -64, -6, -2])).add("Shin.R", x=tr([0, 4, 104, 14, 8]))
    p.move("Hips", z=tr([-0.015, 0.0, -0.44, -0.12, -0.12]))
    p.set("Root", tr([0, -4, 4, 82, 84]), 0, 0)
    p.move("Root", y=tr([0, 0.06, 0.02, -0.38, -0.4]), z=tr([0, 0, 0, 0.14, 0.14]))
    p.add("UpperArm.L", x=tr([0, -10, -30, -110, -116])).add("Staff", x=tr([0, 10, 20, 50, 54]))
    p.add("UpperArm.R", x=tr([0, 20, 30, -100, -110]), z=tr([0, 10, 20, 30, 30]))
    p.add("ForeArm.R", x=-14 * pulse(t, 0.94, 0.03))
    return p


def build_actions(rig):
    sc = ("Head",)
    k.bake(rig, "Idle", 105, idle, cyclic=True, scale_bones=sc)
    k.bake(rig, "Walk", 27, walk, cyclic=True, scale_bones=sc)
    k.bake(rig, "Attack", 27, attack, scale_bones=sc)
    k.bake(rig, "Attack2", 26, attack2, scale_bones=sc)
    k.bake(rig, "Attack3", 27, attack3, scale_bones=sc)
    k.bake(rig, "Hit", 15, hit, scale_bones=sc)
    k.bake(rig, "Death", 48, death, scale_bones=sc)


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
    glb = args[0] if args else os.path.join(here, "..", "grove_voice.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_voice.blend")
    build(glb, blend)
