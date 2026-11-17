# Саженец (~1.0 м) — Хранители Рощи, лесная ветка акта 1. Ожившая фигура из живых ветвей и корней
# (не человек и не ребёнок): угловатое тело-плетёнка, тонкие ноги-корни, руки-ветки с пальцами-сучками,
# из плеч растут листья, на голове — крошечная резная маска со светящимся листом. Погибая, пускает корни
# и становится деревцем (деревце ставит игра). Облик — claude/мир.md; референс Gemini 17 ноября,
# в модели уменьшен до ~1 м, руки и ноги короче, голова-маска крупнее (чтобы не напоминал Корягача).
# Смотрит в -Y. Материалы — общие с Хранителями (grove_kin.py).
#
# Анимации: Idle, Walk, Attack (удар веткой, вплотную), Hit, Death.
# Запуск: python3 build_grove_sapling.py out/grove_sapling.glb out/grove_sapling.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GroveSapling"
SIDES = (("R", -1), ("L", 1))


# ---------- Модель ----------

def twig(name, pts, r0, r1, m, bone, segs=5):
    """Ломаная ветка по точкам, толщина от r0 к r1."""
    n = len(pts) - 1
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        k.limb(f"{name}{i}", a, b, ra, rb, m, bone, segs=segs)


def build_mesh():
    g.setup(1.0, 1.0)
    M = g.materials("Sapling")
    wood, bark, leaf = M["wood"], M["bark"], M["leaf"]
    # Ноги-корни: от таза вниз, внизу растопыренные корешки
    for side, s in SIDES:
        x = 0.08 * s
        twig(f"Thigh.{side}", [(x, 0, 0.46), (x + 0.02 * s, -0.01, 0.3)], 0.045, 0.035, wood, f"Thigh.{side}")
        twig(f"Shin.{side}", [(x + 0.02 * s, -0.01, 0.3), (x + 0.01 * s, 0.0, 0.16), (x, -0.01, 0.05)], 0.035, 0.03,
             bark, f"Shin.{side}")
        for j, (dx, dy) in enumerate(((0.06, -0.06), (-0.04, -0.07), (0.02, 0.06))):
            k.limb(f"Root.{side}{j}", (x, -0.01, 0.06), (x + dx * s, dy, 0.0), 0.022, 0.006, bark, f"Foot.{side}", segs=4)
    # Тело-плетёнка: несколько перекрученных веток от таза к плечам
    for i in range(5):
        a = math.tau * i / 5
        b = a + 0.9
        lo = (0.07 * math.cos(a), 0.05 * math.sin(a), 0.44)
        mid = (0.1 * math.cos(b), 0.07 * math.sin(b), 0.6)
        hi = (0.12 * math.cos(a + 1.6), 0.07 * math.sin(a + 1.6), 0.76)
        k.limb(f"BodyLow{i}", lo, mid, 0.03, 0.028, wood if i % 2 else bark, "Spine", segs=5)
        k.limb(f"BodyHigh{i}", mid, hi, 0.028, 0.024, bark if i % 2 else wood, "Chest", segs=5)
    k.sphere("Core", 0.09, (0, 0, 0.6), M["fur_d"], "Spine", scale=(1.1, 0.8, 1.2), segs=6, rings=4)
    k.barrel("Pelvis", 0.1, 0.08, 0.4, 0.48, bark, "Hips", segs=6, sy=0.8)
    k.barrel("Shoulders", 0.15, 0.1, 0.72, 0.8, wood, "Chest", segs=6, sy=0.7)
    # Руки-ветки с пальцами-сучками
    for side, s in SIDES:
        sh, el, wr = (0.15 * s, 0, 0.76), (0.22 * s, -0.03, 0.6), (0.24 * s, -0.08, 0.45)
        twig(f"UpperArm.{side}", [sh, el], 0.03, 0.024, wood, f"UpperArm.{side}")
        twig(f"ForeArm.{side}", [el, wr], 0.024, 0.02, bark, f"ForeArm.{side}")
        for j, (dx, dy, dz) in enumerate(((0.02, -0.06, -0.06), (-0.02, -0.07, -0.04), (0.03, -0.02, -0.08))):
            k.limb(f"Finger.{side}{j}", wr, (wr[0] + dx * s, wr[1] + dy, wr[2] + dz), 0.014, 0.003, wood,
                   f"Hand.{side}", segs=4)
        # листья из плеч (свои кости — шевелятся)
        for j, tilt in enumerate((20, 80, 140)):
            g.leaf_at(M, f"ShLeaf.{side}{j}", (0.13 * s + 0.03 * j * s, 0.02 * j, 0.8 + 0.02 * j), f"Sprout.{side}",
                      tilt=tilt + 30 * s, size=0.1)
        k.limb(f"Shoot.{side}", (0.12 * s, 0.02, 0.78), (0.2 * s, 0.05, 0.9), 0.012, 0.004, M["vine"], f"Sprout.{side}", segs=4)
    # Шея-веточка и голова: комок коры с крупной резной маской
    k.limb("Neck", (0, 0, 0.78), (0, -0.01, 0.84), 0.035, 0.03, wood, "Head", segs=5)
    k.sphere("HeadKnot", 0.085, (0, 0.02, 0.9), bark, "Head", scale=(1.0, 1.0, 1.1), segs=6, rings=4)
    k.sphere("Mask", 0.085, (0, -0.045, 0.9), M["mask"], "Head", scale=(0.86, 0.35, 1.15), segs=7, rings=5)
    for s in (-1, 1):
        k.box(f"Slit{s}", (0.03, 0.015, 0.01), (0.026 * s, -0.073, 0.905), M["mask_d"], "Head")
    g.leaf_sign(M, (0, -0.07, 0.955), size=0.035)
    for j, (dx, tilt) in enumerate(((-0.05, 30), (0.03, 120), (0.0, 70))):
        k.limb(f"HeadTwig{j}", (dx, 0.03, 0.97), (dx * 1.8, 0.05, 1.05 + 0.02 * j), 0.012, 0.003, wood, "Head", segs=4)
        g.leaf_at(M, f"HeadLeaf{j}", (dx * 1.8, 0.05, 1.05 + 0.02 * j), "Head", tilt=tilt, size=0.07)
    return k.join_parts("GroveSaplingMesh")


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Hips": ((0, 0, 0.44), (0, 0, 0.5), "Root"),
    "Spine": ((0, 0, 0.5), (0, 0, 0.64), "Hips"),
    "Chest": ((0, 0, 0.64), (0, 0, 0.78), "Spine"),
    "Head": ((0, 0, 0.78), (0, 0, 1.0), "Chest"),
}
for side, s in SIDES:
    BONES.update({
        f"UpperArm.{side}": ((0.15 * s, 0, 0.76), (0.22 * s, -0.03, 0.6), "Chest"),
        f"ForeArm.{side}": ((0.22 * s, -0.03, 0.6), (0.24 * s, -0.08, 0.45), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.24 * s, -0.08, 0.45), (0.25 * s, -0.12, 0.38), f"ForeArm.{side}"),
        f"Sprout.{side}": ((0.13 * s, 0.02, 0.78), (0.18 * s, 0.03, 0.9), "Chest"),
        f"Thigh.{side}": ((0.08 * s, 0, 0.46), (0.1 * s, -0.01, 0.3), "Hips"),
        f"Shin.{side}": ((0.1 * s, -0.01, 0.3), (0.08 * s, -0.01, 0.05), f"Thigh.{side}"),
        f"Foot.{side}": ((0.08 * s, -0.01, 0.05), (0.08 * s, -0.08, 0.0), f"Shin.{side}"),
    })


# ---------- Анимации ----------
# Скованный, «деревянный»: движения короткие, рывками; голова чуть склонена.
STANCE = {
    "Thigh.L": (-14, 0, -4), "Shin.L": (16, 0, 0), "Thigh.R": (6, 0, 4), "Shin.R": (10, 0, 0),
    "Spine": (6, -6, 4), "Chest": (4, 0, -3), "Head": (-6, 10, 8),
    "UpperArm.R": (-20, 0, 10), "ForeArm.R": (-14, 0, 0), "UpperArm.L": (-10, 0, -14), "ForeArm.L": (-20, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.015)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def step(x):
    """Рывок: плавное значение превращается в ступеньки — движение «деревянное»."""
    return round(x * 4) / 4


def idle(t):
    """Покой (3 сек): покачивается, как деревце на ветру; листья дрожат; голова наклоняется рывками.
    Характерное: потягивается — руки-ветки вверх, со скрипом."""
    p = stance()
    sway = wave(t, 1)
    p.move("Hips", x=0.01 * sway)
    p.add("Spine", z=4 * sway, x=2 * wave(t, 2))
    p.add("Head", z=10 * step(wave(t, 1, 0.3)), y=12 * step(wave(t, 0.5, 0.1)))
    stretch = track(t, [(0, 0), (0.6, 0), (0.72, 1), (0.82, 1), (0.92, 0), (1, 0)])
    p.add("UpperArm.R", x=-110 * stretch, z=10 * stretch).add("UpperArm.L", x=-110 * stretch, z=-10 * stretch)
    p.add("Chest", x=-8 * stretch)
    for side in ("R", "L"):
        p.add(f"Sprout.{side}", x=6 * wave(t, 4, 0.2 if side == "R" else 0.6), z=4 * wave(t, 3))
    return p


def walk(t):
    """Шаг (0.8 сек): негнущиеся ноги, переваливается с боку на бок, руки болтаются."""
    p = stance()
    a = wave(t, 1)
    p.move("Hips", x=0.03 * a, z=0.015 * wave(t, 2))
    p.add("Hips", z=8 * a)
    p.set("Thigh.R", -24 * a, 0, 4).set("Thigh.L", 24 * a, 0, -4)
    p.set("Shin.R", 8 + 10 * max(0.0, wave(t, 1, 0.25)), 0, 0).set("Shin.L", 8 + 10 * max(0.0, -wave(t, 1, 0.25)), 0, 0)
    p.add("Spine", z=-8 * a)
    p.add("UpperArm.R", x=20 * a).add("UpperArm.L", x=-20 * a)
    p.add("Head", z=6 * a)
    for side in ("R", "L"):
        p.add(f"Sprout.{side}", x=8 * wave(t, 2, 0.3))
    return p


def attack(t):
    """Удар веткой (0.8 сек): заносит правую руку-ветку → хлещет сверху наискось (к 0.4 сек) → возврат."""
    p = stance()
    K = [0.0, 0.3, 0.5, 0.62, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("UpperArm.R", x=tr([0, -130, -10, 10, 0]), z=tr([0, 30, -10, -14, 0]))
    p.add("ForeArm.R", x=tr([0, -30, -10, 0, 0]))
    p.add("Spine", y=tr([0, -20, 20, 22, 0]), x=tr([0, -6, 12, 10, 0]))
    p.add("Head", x=tr([0, -6, 6, 4, 0]))
    p.move("Root", y=tr([0, 0.03, -0.14, -0.12, 0]))
    p.add("Sprout.R", x=tr([0, -20, 30, 20, 0])).add("Sprout.L", x=tr([0, -10, 20, 10, 0]))
    return p


def hit(t):
    """Получил удар (0.5 сек): треснул и качнулся назад, листья взметнулись."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.34, 1), (0.6, -0.3), (0.82, 0.08), (1, 0)])
    p.move("Root", y=0.06 * snap)
    p.add("Spine", x=-18 * snap, z=8 * whip)
    p.add("Head", x=-20 * whip, z=-14 * whip)
    p.add("UpperArm.R", x=30 * snap).add("UpperArm.L", x=30 * snap)
    p.add("Sprout.R", x=-30 * whip).add("Sprout.L", x=-30 * whip)
    return p


def death(t):
    """Гибель (1.2 сек): ломается в поясе, оседает на корни, руки-ветки опускаются к земле — будто врастает."""
    p = stance()
    K = [0.0, 0.25, 0.55, 0.85, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -14, 30, 40, 40]), z=tr([0, 10, -6, -8, -8]))
    p.add("Chest", x=tr([0, -6, 20, 26, 26]))
    p.add("Head", x=tr([0, -20, 30, 40, 40]))
    p.add("Thigh.L", x=tr([0, 6, -50, -70, -70])).add("Shin.L", x=tr([0, -4, 80, 110, 110]))
    p.add("Thigh.R", x=tr([0, -6, -46, -66, -66])).add("Shin.R", x=tr([0, 4, 84, 116, 116]))
    p.move("Hips", z=tr([-0.015, 0.0, -0.18, -0.26, -0.26]))
    p.add("UpperArm.R", x=tr([0, 30, -20, -40, -40]), z=tr([0, 20, 30, 40, 40]))
    p.add("UpperArm.L", x=tr([0, 30, -20, -40, -40]), z=tr([0, -20, -30, -40, -40]))
    p.add("Sprout.R", x=tr([0, 30, -20, -30, -30])).add("Sprout.L", x=tr([0, 30, -20, -30, -30]))
    p.add("ForeArm.L", x=-16 * pulse(t, 0.93, 0.04))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 24, walk, cyclic=True)
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
    glb = args[0] if args else os.path.join(here, "..", "grove_sapling.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_sapling.blend")
    build(glb, blend)
