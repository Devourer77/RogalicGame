# Носящий шкуру (~1.8 м, но сгорблен почти на четвереньках) — Хранители Рощи, лесная ветка акта 1.
# Тело — grove_kin.py. Резная деревянная волчья маска с ушами и мордой, на плечах и спине — целая серая
# волчья шкура с хвостом. К пальцам привязаны когти из дерева и камня. Явно человек в маске, не оборотень.
# Облик — claude/мир.md; референс Gemini 17 ноября (набор «А»). Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (удар когтями, вплотную), Hit, Death.
# Запуск: python3 build_grove_skinwearer.py out/grove_skinwearer.glb out/grove_skinwearer.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GroveSkinwearer"
g.setup(1.02, 1.0)
P = g.P

# Руки висят вперёд, кисти с когтями растопырены.
SH_R, EL_R, WR_R = P(-0.26, 0.0, 1.33), P(-0.33, -0.08, 1.1), P(-0.3, -0.18, 0.9)
SH_L, EL_L, WR_L = P(0.26, 0.0, 1.33), P(0.33, -0.08, 1.1), P(0.3, -0.18, 0.9)


# ---------- Модель ----------

def claws(M, side, el, wr):
    """Три когтя из тёмного камня, привязанные кожаными ремнями к пальцам."""
    e, w_ = Vector(el), Vector(wr)
    d = (w_ - e).normalized()
    c = w_ + d * 0.05 * g.W
    across = Vector((1, 0, 0))
    k.barrel(f"ClawStrap.{side}", 0.05, 0.05, c.z - 0.015, c.z + 0.015, M["leather"], f"Hand.{side}", segs=6, loc=(c.x, c.y))
    for i in (-1, 0, 1):
        base = c + across * 0.03 * i + d * 0.03
        tip = base + d * 0.14 + Vector((0, -0.06, 0)) + across * 0.02 * i
        k.limb(f"Claw.{side}{i}", tuple(base), tuple(tip), 0.016, 0.0, M["bark"], f"Hand.{side}", segs=4)


def build_mesh():
    M = g.materials("Skinwearer")
    g.legs(M)
    g.torso(M)
    g.arm_upper(M, "R", -1, SH_R, EL_R)
    g.arm_lower(M, "R", -1, EL_R, WR_R, fist_dir=(0, -1, -0.3))
    g.arm_upper(M, "L", 1, SH_L, EL_L)
    g.arm_lower(M, "L", 1, EL_L, WR_L, fist_dir=(0, -1, -0.3))
    claws(M, "R", EL_R, WR_R)
    claws(M, "L", EL_L, WR_L)
    g.hood_and_head(M)
    g.wolf_mask(M)
    # Шкура — та же накидка, что у Стража, но серая волчья, плюс хвост
    pelt = dict(M, fur=M["pelt"], fur_d=M["pelt_d"])
    g.fur_mantle(pelt, big=1.02)
    g.vines(M, count=2)
    tail = [P(0, 0.26, 0.85), P(0, 0.33, 0.7), P(0.03, 0.36, 0.52), P(0.06, 0.34, 0.36)]
    for i, (a, b) in enumerate(zip(tail, tail[1:])):
        k.limb(f"Tail{i}", a, b, 0.07 - 0.015 * i, 0.06 - 0.015 * i, M["pelt"] if i % 2 == 0 else M["pelt_d"], "Tail", segs=6)
    k.limb("TailTip", tail[-1], P(0.07, 0.3, 0.26), 0.04, 0.0, M["pelt_d"], "Tail", segs=5)
    return k.join_parts("GroveSkinwearerMesh")


# ---------- Скелет ----------

BONES = g.bones(SH_R, EL_R, WR_R, SH_L, EL_L, WR_L, extra={
    "Tail": (P(0, 0.26, 0.85), P(0, 0.34, 0.4), "Cloak"),
})


# ---------- Анимации ----------
# Сгорблен почти на четвереньках: колени сильно согнуты, корпус вперёд, голова задрана к цели,
# руки с когтями висят перед собой.
STANCE = dict(g.LEG_STANCE)
STANCE.update({
    "Thigh.L": (-50, 0, -8), "Shin.L": (70, 0, 0), "Foot.L": (-18, 0, 0),
    "Thigh.R": (-26, 0, 12), "Shin.R": (64, 0, 0), "Foot.R": (-34, 0, 0),
    "Spine": (34, -6, 0), "Chest": (18, -4, 0), "Head": (-42, 8, 0),
    "UpperArm.R": (-30, 0, 8), "ForeArm.R": (-20, 0, 0), "UpperArm.L": (-24, 0, -8), "ForeArm.L": (-26, 0, 0),
    "Cloak": (-38, 0, 0), "Tail": (-14, 0, 0), "FlapF": (-40, 0, 0), "FlapB": (30, 0, 0),
})
STANCE_LOC = {"Hips": (0, 0, -0.24)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3 сек): часто дышит, как зверь, плечи ходят, хвост мотается. Характерное: принюхивается —
    тянет морду вверх короткими рывками, потом резко поворачивает голову."""
    p = stance()
    breath, sway = g.idle_body(p, t)
    pant = wave(t, 6)
    p.add("Chest", x=2 * pant)
    p.add("UpperArm.R", x=3 * wave(t, 1, 0.1), z=2 * pant).add("UpperArm.L", x=3 * wave(t, 1, 0.35), z=-2 * pant)
    sniff = pulse(t, 0.4, 0.04) + pulse(t, 0.47, 0.04) + pulse(t, 0.54, 0.04)
    snap = track(t, [(0, 0), (0.6, 0), (0.63, 30), (0.85, 30), (0.9, 0), (1, 0)])
    p.add("Head", x=-12 * sniff, y=snap + 6 * wave(t, 1, 0.2))
    p.add("Tail", z=14 * wave(t, 2, 0.1), x=4 * wave(t, 1))
    p.add("Hand.R", x=-10 * pulse(t, 0.2, 0.05)).add("Hand.L", x=-10 * pulse(t, 0.75, 0.05))
    return p


def walk(t):
    """Бег (0.7 сек): охотник — быстрые низкие шаги, корпус ныряет, руки и хвост в противофазе."""
    p = Pose(STANCE, STANCE_LOC)
    a = g.walk_body(p, t)
    p.move("Hips", z=-0.2)
    p.add("Thigh.L", x=-30).add("Thigh.R", x=-30).add("Shin.L", x=40).add("Shin.R", x=40)
    p.add("Spine", x=30 + 4 * wave(t, 2))
    p.add("Head", x=-40)
    p.add("UpperArm.R", x=-30 + 20 * a).add("UpperArm.L", x=-30 - 20 * a)
    p.add("Tail", z=16 * a, x=-6)
    p.add("Cloak", x=-30)
    return p


def attack(t):
    """Удар когтями (0.8 сек): присел и вскинул обе руки → прыжок вперёд, когти рвут сверху вниз
    (к 0.4 сек) → пронос → назад в стойку."""
    p = stance()
    K = [0.0, 0.3, 0.5, 0.62, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    for side, sgn in (("R", 1), ("L", -1)):
        p.add(f"UpperArm.{side}", x=tr([0, -110, -10, 20, 0]), z=tr([0, 20 * sgn, 6 * sgn, 0, 0]))
        p.add(f"ForeArm.{side}", x=tr([0, -40, -10, 0, 0]))
        p.add(f"Hand.{side}", x=tr([0, 20, -30, -20, 0]))
    p.add("Spine", x=tr([0, -20, 16, 20, 0]))
    p.add("Head", x=tr([0, 10, 0, 6, 0]))
    p.move("Root", y=tr([0, 0.06, -0.3, -0.28, 0]))
    p.move("Hips", z=tr([-0.24, -0.3, -0.12, -0.18, -0.24]))
    p.add("Tail", x=tr([0, -20, 30, 20, 0]))
    return p


def hit(t):
    """Получил удар (0.5 сек): отпрыгнул, хвост поджат, голова мотается."""
    p = stance()
    snap, whip = g.hit_body(p, t)
    p.add("UpperArm.R", x=20 * snap).add("UpperArm.L", x=20 * snap)
    p.add("Tail", x=-30 * snap, z=10 * whip)
    return p


def death(t):
    """Гибель (1.2 сек): взвился на задние, рухнул ничком, хвост дёрнулся и замер."""
    p = stance()
    K = [0.0, 0.2, 0.45, 0.75, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -40, -10, -20, -20]))
    p.add("Head", x=tr([0, -10, 20, 30, 30]))
    p.add("UpperArm.R", x=tr([0, -60, -80, -120, -124])).add("UpperArm.L", x=tr([0, -50, -80, -116, -120]))
    p.set("Root", tr([0, -10, 30, 70, 74]), 0, 0)
    p.move("Root", y=tr([0, 0.06, -0.1, -0.3, -0.32]), z=tr([0, 0.06, 0.04, 0.06, 0.06]))
    p.add("Thigh.L", x=tr([0, 20, 30, 40, 40])).add("Thigh.R", x=tr([0, 20, 30, 36, 36]))
    p.add("Shin.L", x=tr([0, -40, -50, -60, -60])).add("Shin.R", x=tr([0, -40, -46, -56, -56]))
    p.add("Tail", x=tr([0, 30, 0, -10, -10]), z=24 * pulse(t, 0.9, 0.05))
    p.add("Cloak", x=tr([0, 30, 10, -20, -24]))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 21, walk, cyclic=True)
    k.bake(rig, "Attack", 24, attack)
    k.bake(rig, "Hit", 15, hit)
    k.bake(rig, "Death", 36, death)


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
    glb = args[0] if args else os.path.join(here, "..", "grove_skinwearer.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_skinwearer.blend")
    build(glb, blend)
