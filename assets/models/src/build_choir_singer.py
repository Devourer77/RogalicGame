# Певчая Венца — элита Культа (~1.9 м в бою: size 1.12 в .tres). Стройная, очень прямая, длинная угольно-чёрная
# ряса с пепельно-серыми накидками и длинными рукавами, высокий капюшон; в глубине капюшона — бледный свет
# (она «поёт светом»). Над капюшоном — большое пустое костяное кольцо-венец, внутри него второе, поменьше.
# С рукавов и пояса свисают костяные ленты. Обе руки подняты ладонями вверх — дирижирует невидимым хором.
# Скелет — от культиста (build_cultist.py), анимации свои.
#
# Анимации: Idle, Walk, Attack (Луч Венца), Attack2 (Хор Венца), Hit, Death.
# Запуск: python3 build_choir_singer.py out/choir_singer.glb out/choir_singer.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
import build_cultist as c
from char_kit import Pose, wave, track, pulse

NAME = "ChoirSinger"


def ring(name, r, z, width, mat, bone, n=16, y=0.02):
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        k.limb(f"{name}{i}", (r * math.cos(a0), y + r * math.sin(a0), z), (r * math.cos(a1), y + r * math.sin(a1), z),
               width, width, mat, bone, segs=4)


def build_mesh():
    black = k.mat("Singer_Black", (0.17, 0.17, 0.17), rough=0.95)
    ash = k.mat("Singer_Ash", (0.42, 0.42, 0.40), rough=0.95)
    void = k.mat("Singer_Void", (0.02, 0.02, 0.025), rough=1.0)
    bone = k.mat("Singer_Bone", (0.86, 0.84, 0.76), rough=0.55)
    crown = k.mat("Singer_Crown", (0.9, 0.88, 0.8), rough=0.5, emit=0.3)
    skin = k.mat("Singer_Hand", (0.56, 0.54, 0.50), rough=0.8)
    light = k.mat("Singer_Light", (0.92, 0.95, 0.92), rough=0.3, emit=2.6)

    # Ряса до земли, расширяется книзу, поверх — серые накидки
    k.barrel("Gown", 0.34, 0.16, 0.0, 0.94, black, "Hips", segs=10, sy=0.9)
    k.barrel("Torso", 0.18, 0.15, 0.94, 1.44, black, "Chest", segs=8, sy=0.8)
    k.barrel("Sash", 0.18, 0.18, 0.96, 1.02, ash, "Spine", segs=8, sy=0.8)
    for name, (x, y), u, v in c.ROBE:
        w = 0.17 if name in ("RobeF", "RobeB") else 0.14
        k.plate(name, [(-w, 0), (w, 0), (w * 1.1, -0.72), (-w * 1.1, -0.72)], 0.02, (x * 1.05, y * 1.05, 1.32),
                u, v, ash, name)
    k.barrel("Mantle", 0.25, 0.14, 1.24, 1.46, ash, "Chest", segs=8, sy=0.85)
    # Высокий капюшон, в глубине — бледный свет
    k.sphere("Hood", 0.16, (0, 0.02, 1.6), ash, "Head", scale=(1.0, 1.1, 1.2), segs=8, rings=5)
    k.limb("HoodTip", (0, 0.06, 1.72), (0, 0.12, 1.9), 0.09, 0.01, ash, "Head", segs=6)
    k.sphere("Void", 0.11, (0, -0.07, 1.57), void, "Head", scale=(0.9, 0.6, 1.1), segs=7, rings=4)
    k.sphere("Song", 0.045, (0, -0.12, 1.55), light, "Glow", segs=6, rings=4)
    # Двойной пустой венец над капюшоном
    ring("CrownOuter", 0.24, 2.02, 0.02, crown, "Crown", n=18)
    ring("CrownInner", 0.15, 2.04, 0.014, crown, "Crown", n=14)
    # Руки в длинных рукавах; с рукавов и пояса свисают костяные ленты
    for side, s in c.SIDES:
        k.limb(f"Sleeve.{side}", (0.19 * s, 0, 1.42), (0.27 * s, -0.04, 1.16), 0.07, 0.09, ash, f"UpperArm.{side}", segs=6)
        k.limb(f"Cuff.{side}", (0.27 * s, -0.04, 1.16), (0.3 * s, -0.08, 0.9), 0.09, 0.15, ash, f"ForeArm.{side}", segs=6)
        k.plate(f"SleeveTail.{side}", [(-0.06, 0), (0.06, 0), (0.03, -0.4), (-0.04, -0.34)], 0.015, (0.31 * s, -0.02, 0.92),
                (0, 1, 0), (0, 0, 1), ash, f"ForeArm.{side}")
        k.sphere(f"Hand.{side}", 0.045, (0.3 * s, -0.09, 0.86), skin, f"Hand.{side}", scale=(0.8, 1.0, 1.2), segs=5, rings=3)
        for f, dx in enumerate((-0.025, 0.0, 0.025)):
            k.limb(f"Finger{f}.{side}", (0.3 * s + dx, -0.1, 0.83), (0.3 * s + dx * 1.4, -0.12, 0.76), 0.012, 0.006, skin,
                   f"Hand.{side}", segs=3)
        k.plate(f"Ribbon.{side}", [(-0.02, 0), (0.02, 0), (0.025, -0.55), (-0.015, -0.6)], 0.01, (0.29 * s, 0.02, 0.98),
                (0, 1, 0), (0, 0, 1), bone, f"ForeArm.{side}")
    for i, (x, y) in enumerate([(0.12, -0.12), (-0.1, -0.14), (0.02, 0.17)]):
        k.plate(f"BeltRibbon{i}", [(-0.018, 0), (0.018, 0), (0.02, -0.7), (-0.016, -0.74)], 0.01, (x, y, 0.98),
                (1, 0, 0), (0, 0, 1), bone, "RobeF" if y < 0 else "RobeB")
    return k.join_parts("ChoirSingerMesh")


BONES = dict(c.BONES)
BONES["Crown"] = ((0, 0.02, 1.96), (0, 0.02, 2.08), "Head")
BONES["Glow"] = ((0, -0.12, 1.52), (0, -0.12, 1.6), "Head")
for name in ("Chain", "Lantern"):
    BONES.pop(name)

# Стойка: прямая, голова чуть запрокинута, обе руки подняты ладонями вверх
STANCE = {
    "Spine": (-2, 0, 0), "Chest": (-4, 0, 0), "Head": (-14, 0, 0),
    "UpperArm.R": (-20, 0, 78), "ForeArm.R": (-75, 0, 0), "Hand.R": (30, 0, 0),
    "UpperArm.L": (-20, 0, -78), "ForeArm.L": (-75, 0, 0), "Hand.L": (30, 0, 0),
}


def stance():
    return Pose(STANCE, {})


def arms(p, up=0.0, out=0.0, fwd=0.0):
    p.add("UpperArm.R", x=-up - fwd, z=out)
    p.add("UpperArm.L", x=-up - fwd, z=-out)
    return p


def idle(t):
    """Покой (3 сек): медленно водит руками, как дирижёр, голова плывёт, венцы вращаются навстречу, свет дышит."""
    p = stance()
    breath = wave(t, 1)
    arms(p, up=8 * wave(t, 1, 0.1), out=6 * wave(t, 2, 0.3))
    p.add("ForeArm.R", x=-8 * wave(t, 1, 0.2))
    p.add("ForeArm.L", x=-8 * wave(t, 1, 0.45))
    p.add("Head", z=6 * wave(t, 1, 0.3), x=-3 * breath)
    p.move("Hips", z=0.01 * breath)
    p.add("Crown", y=18 * t * 0 + 8 * wave(t, 1), x=4 * wave(t, 1, 0.25))
    p.size("Glow", 1 + 0.25 * wave(t, 2))
    c.robe(p, fwd=3 * wave(t, 1, -0.2), side=3 * wave(t, 1, 0.1))
    return p


def walk(t):
    """Плывёт (0.8 сек): почти не качается, ряса стелется, руки опущены и отведены."""
    p = stance()
    a = wave(t, 1)
    p.move("Hips", z=0.008 * wave(t, 2, 0.1))
    p.set("Thigh.R", -18 * a, 0, 0)
    p.set("Thigh.L", 18 * a, 0, 0)
    p.set("Shin.R", 8 + 16 * max(0.0, wave(t, 1, 0.25)), 0, 0)
    p.set("Shin.L", 8 + 16 * max(0.0, -wave(t, 1, 0.25)), 0, 0)
    arms(p, up=-24, out=10)
    p.add("Crown", x=-6 + 3 * wave(t, 2, -0.3))
    c.robe(p, fwd=8 + 4 * abs(a), side=4 * a)
    return p


def attack(t):
    """Луч Венца (0.8 сек): руки сводятся у груди, свет гаснет → руки выбрасываются вперёд, вспышка из капюшона
    (к 0.4 сек) → возврат."""
    p = stance()
    K = [0.0, 0.28, 0.45, 0.62, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    arms(p, up=tr([0, -10, 30, 24, 0]), out=tr([0, -40, -30, -24, 0]), fwd=tr([0, 10, 30, 24, 0]))
    p.add("ForeArm.R", x=tr([0, -40, 50, 40, 0]))
    p.add("ForeArm.L", x=tr([0, -40, 50, 40, 0]))
    p.add("Spine", x=tr([0, -8, 10, 6, 0]))
    p.add("Head", x=tr([0, 6, 18, 12, 0]))
    p.size("Glow", tr([1, 0.5, 3.0, 1.8, 1]))
    p.size("Crown", tr([1, 0.96, 1.12, 1.05, 1]))
    p.move("Root", y=tr([0, 0.03, -0.06, -0.04, 0]))
    c.robe(p, fwd=tr([0, -10, 20, 14, 0]))
    return p


def attack2(t):
    """Хор Венца (0.8 сек): руки взлетают высоко над головой, голова запрокинута, венцы вспыхивают и расходятся."""
    p = stance()
    K = [0.0, 0.3, 0.5, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    arms(p, up=tr([0, 70, 80, 0]), out=tr([0, -10, -16, 0]))
    p.add("ForeArm.R", x=tr([0, 40, 50, 0]))
    p.add("ForeArm.L", x=tr([0, 40, 50, 0]))
    p.add("Head", x=tr([0, -8, -10, 0]))
    p.add("Chest", x=tr([0, -8, -10, 0]))
    p.size("Glow", tr([1, 2.2, 2.6, 1]))
    p.size("Crown", tr([1, 1.18, 1.25, 1]))
    p.move("Hips", z=tr([0, 0.04, 0.05, 0]))
    c.robe(p, side=tr([0, 10, 12, 0]))
    return p


def hit(t):
    """Получила удар (0.47 сек): откинулась, руки вскинуты, венец сбился, свет мигнул."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.34, 1), (0.56, -0.3), (0.8, 0.1), (1, 0)])
    p.move("Root", y=0.08 * snap)
    p.add("Spine", x=-16 * snap)
    p.add("Head", x=-20 * whip, z=12 * whip)
    arms(p, up=20 * snap, out=20 * snap)
    p.add("Crown", x=-18 * whip, z=14 * whip)
    p.size("Glow", 1 - 0.5 * snap)
    c.robe(p, fwd=-16 * whip)
    return p


def death(t):
    """Гибель (1.4 сек): песня обрывается — руки падают, она оседает, ряса складывается, венцы падают и гаснут."""
    p = stance()
    K = [0.0, 0.2, 0.5, 0.75, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    arms(p, up=tr([0, 30, -40, -60, -60]), out=tr([0, 10, -20, -26, -26]))
    p.add("Spine", x=tr([0, -14, 20, 36, 40]))
    p.add("Head", x=tr([0, -24, 30, 40, 40]))
    p.add("Thigh.L", x=tr([0, 0, -70, -70, -70]))
    p.add("Shin.L", x=tr([0, 0, 110, 110, 110]))
    p.add("Thigh.R", x=tr([0, 0, -76, -76, -76]))
    p.add("Shin.R", x=tr([0, 0, 116, 116, 116]))
    p.move("Hips", z=tr([0, 0.03, -0.38, -0.5, -0.52]))
    p.move("Crown", z=0.0)
    p.add("Crown", x=tr([0, -20, 30, 70, 80]))
    p.size("Crown", tr([1, 1.1, 0.9, 0.8, 0.8]))
    p.size("Glow", tr([1, 2.0, 0.4, 0.05, 0.05]))
    c.robe(p, fwd=tr([0, -10, 30, 46, 50]), side=tr([0, 0, 10, 14, 14]))
    return p


def build_actions(rig):
    sc = ("Glow", "Crown")
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=sc)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=sc)
    k.bake(rig, "Attack", 24, attack, scale_bones=sc)
    k.bake(rig, "Attack2", 24, attack2, scale_bones=sc)
    k.bake(rig, "Hit", 14, hit, scale_bones=sc)
    k.bake(rig, "Death", 42, death, scale_bones=sc)


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
    glb = args[0] if args else os.path.join(here, "..", "choir_singer.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "choir_singer.blend")
    build(glb, blend)
