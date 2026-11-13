# Послушник Венца (~1.5 м в бою: модель культиста, size 0.9 в .tres). Простая пепельно-серая ряса с
# верёвочным поясом, рваный подол, ступни в обмотках. Своего венца над капюшоном ещё нет — костяное кольцо
# висит на шнурке на груди. В правой руке на короткой цепи дымящееся железное кадило.
# Скелет и анимации — от культиста (build_cultist.py): кадило висит на тех же костях Chain/Lantern/Glow,
# только они перенесены к кисти; кость Crown осталась, но пустая.
#
# Запуск: python3 build_cult_novice.py out/cult_novice.glb out/cult_novice.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
import build_cultist as c

NAME = "CultNovice"
HX, HY, HZ = c.HAND_R
CH_TOP = (HX, HY - 0.03, HZ - 0.06)


def build_mesh():
    robe = k.mat("Novice_Robe", (0.43, 0.42, 0.39), rough=0.95)
    under = k.mat("Novice_Under", (0.30, 0.30, 0.29), rough=0.95)
    void = k.mat("Novice_Void", (0.02, 0.02, 0.025), rough=1.0)
    bone = k.mat("Novice_Bone", (0.84, 0.82, 0.74), rough=0.6)
    skin = k.mat("Novice_Hand", (0.60, 0.57, 0.52), rough=0.8)
    rope = k.mat("Novice_Rope", (0.50, 0.44, 0.34), rough=1.0)
    wrap = k.mat("Novice_Wrap", (0.58, 0.55, 0.48), rough=1.0)
    iron = k.mat("Novice_Iron", (0.24, 0.24, 0.26), metallic=0.6, rough=0.55)
    smoke = k.mat("Novice_Smoke", (0.62, 0.68, 0.64), rough=0.9, emit=0.25)

    # Ряса покороче, чем у культиста: из-под подола видны ступни
    k.barrel("UnderRobe", 0.27, 0.17, 0.16, 0.92, under, "Hips", segs=9, sy=0.85)
    k.barrel("Torso", 0.2, 0.17, 0.92, 1.42, robe, "Chest", segs=8, sy=0.8)
    for name, (x, y), u, v in c.ROBE:
        w = 0.2 if name in ("RobeF", "RobeB") else 0.16
        teeth = [(-w, 0), (w, 0), (w * 1.1, -0.62), (w * 0.5, -0.5), (w * 0.1, -0.7), (-w * 0.4, -0.52),
                 (-w * 0.8, -0.68), (-w * 1.1, -0.56)]
        k.plate(name, teeth, 0.025, (x, y, 0.96), u, v, robe, name)
    # Верёвочный пояс с узлом и свисающими концами
    k.barrel("Belt", 0.2, 0.2, 0.93, 0.97, rope, "Spine", segs=8, sy=0.8)
    k.limb("BeltEnd1", (0.05, -0.16, 0.94), (0.07, -0.18, 0.7), 0.014, 0.012, rope, "RobeF", segs=3)
    k.limb("BeltEnd2", (-0.02, -0.17, 0.94), (-0.03, -0.19, 0.74), 0.014, 0.012, rope, "RobeF", segs=3)
    # Капюшон с пустотой, без венца
    k.barrel("Mantle", 0.25, 0.15, 1.22, 1.44, robe, "Chest", segs=8, sy=0.85)
    k.sphere("Hood", 0.16, (0, 0.02, 1.58), robe, "Head", scale=(1.0, 1.1, 1.1), segs=8, rings=5)
    k.limb("HoodTip", (0, 0.06, 1.68), (0, 0.14, 1.76), 0.08, 0.01, robe, "Head", segs=6)
    k.sphere("Void", 0.11, (0, -0.07, 1.56), void, "Head", scale=(0.9, 0.6, 1.1), segs=7, rings=4)
    # Костяное кольцо на шнурке на груди — «обещание венца»
    k.limb("Cord1", (0.08, -0.12, 1.42), (0.03, -0.2, 1.26), 0.007, 0.007, rope, "Chest", segs=3)
    k.limb("Cord2", (-0.08, -0.12, 1.42), (-0.03, -0.2, 1.26), 0.007, 0.007, rope, "Chest", segs=3)
    for i in range(10):
        a0, a1 = math.tau * i / 10, math.tau * (i + 1) / 10
        p0 = (0.05 * math.cos(a0), -0.215, 1.21 + 0.05 * math.sin(a0))
        p1 = (0.05 * math.cos(a1), -0.215, 1.21 + 0.05 * math.sin(a1))
        k.limb(f"Ring{i}", p0, p1, 0.013, 0.013, bone, "Chest", segs=4)
    # Руки и ступни в обмотках
    for side, s in c.SIDES:
        k.limb(f"Sleeve.{side}", (0.2 * s, 0, 1.4), (0.27 * s, -0.04, 1.16), 0.07, 0.08, robe, f"UpperArm.{side}", segs=6)
        k.limb(f"Cuff.{side}", (0.27 * s, -0.04, 1.16), (0.29 * s, -0.08, 0.94), 0.08, 0.1, robe, f"ForeArm.{side}", segs=6)
        k.sphere(f"Hand.{side}", 0.05, (0.29 * s, -0.09, 0.88), skin, f"Hand.{side}", scale=(0.9, 1.0, 1.1), segs=5, rings=3)
        k.box(f"Foot.{side}", (0.1, 0.2, 0.07), (0.1 * s, -0.1, 0.035), wrap, f"Foot.{side}")
        k.limb(f"Ankle.{side}", (0.1 * s, 0.0, 0.05), (0.1 * s, 0.0, 0.2), 0.05, 0.045, wrap, f"Shin.{side}", segs=5)
    # Кадило на короткой цепи (Chain → Lantern), дым над ним (Glow)
    for i in range(3):
        z = CH_TOP[2] - 0.03 - i * 0.055
        k.box(f"Link{i}", (0.014, 0.035 if i % 2 else 0.012, 0.05), (CH_TOP[0], CH_TOP[1], z), iron, "Chain")
    bz = CH_TOP[2] - 0.26
    k.barrel("CenserBowl", 0.04, 0.075, bz - 0.05, bz + 0.03, iron, "Lantern", segs=8, loc=(CH_TOP[0], CH_TOP[1]))
    k.sphere("CenserLid", 0.06, (CH_TOP[0], CH_TOP[1], bz + 0.04), iron, "Lantern", scale=(1.0, 1.0, 0.5), segs=7, rings=3)
    for i, (dx, dz, r) in enumerate([(0.0, 0.1, 0.045), (0.03, 0.17, 0.038), (-0.02, 0.23, 0.03)]):
        k.sphere(f"Smoke{i}", r, (CH_TOP[0] + dx, CH_TOP[1], bz + dz), smoke, "Glow", segs=5, rings=3)
    return k.join_parts("CultNoviceMesh")


BONES = dict(c.BONES)
BONES["Chain"] = (CH_TOP, (CH_TOP[0], CH_TOP[1], CH_TOP[2] - 0.18), "Hand.R")
BONES["Lantern"] = ((CH_TOP[0], CH_TOP[1], CH_TOP[2] - 0.18), (CH_TOP[0], CH_TOP[1], CH_TOP[2] - 0.34), "Chain")
BONES["Glow"] = ((CH_TOP[0], CH_TOP[1], CH_TOP[2] - 0.2), (CH_TOP[0], CH_TOP[1], CH_TOP[2] - 0.05), "Lantern")

# Стойка: сгорбился вперёд, кадило висит в опущенной правой руке, левая — кулак у бедра
c.STANCE.update({
    "Spine": (16, -4, 0), "Chest": (14, -2, 0), "Head": (10, 6, 6),
    "UpperArm.R": (-14, 0, 14), "ForeArm.R": (-14, 0, 0), "Hand.R": (0, 0, 0),
    "UpperArm.L": (-10, 0, -14), "ForeArm.L": (-30, 0, 0), "Hand.L": (0, 0, 0),
})


def build(glb_path, blend_path=None):
    k.start_scene(NAME)
    body = build_mesh()
    rig = k.build_armature(NAME, BONES)
    body.parent = rig
    c.build_actions(rig)
    k.export(rig, body, glb_path, blend_path)
    print("%s: треугольников %d" % (NAME, sum(len(p.vertices) - 2 for p in body.data.polygons)))
    return rig, body


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    glb = args[0] if args else os.path.join(here, "..", "cult_novice.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "cult_novice.blend")
    build(glb, blend)
