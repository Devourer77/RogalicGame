# Поджигатель — мародёр Тракта (акт 2), ~1.6 м. Жилистый, в прожжённом кожаном фартуке поверх латаной
# шерстяной рубахи, закопчённая тряпка на лице, очки из дымчатого стекла на лбу. Поперёк груди и на поясе —
# глиняные бутыли с маслом, заткнутые тряпками; одна бутыль с горящим фитилём поднята для броска.
# Огонь только на фитилях. Погибая, бутыли бьются — в игре огонь вокруг.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (бросок), Hit, Death.
# Запуск: python3 build_scav_arsonist.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2
import act2_human as hu
from build_scav_crossbow import scav_mats

B = hu.Body(1.6)


def bottle(name, base, mats, bone, lit=False, tilt=(0, 0, 0)):
    x, y, z = base
    k.limb(name, (x, y, z), (x, y, z + 0.09), 0.03, 0.028, mats["clay"], bone, segs=6)
    k.limb(name + "Neck", (x, y, z + 0.09), (x, y, z + 0.13), 0.014, 0.012, mats["clay"], bone, segs=5)
    k.box(name + "Rag", (0.03, 0.03, 0.03), (x, y, z + 0.145), mats["rag"], bone, rot=(20, 0, 30))
    if lit:
        k.limb(name + "Flame", (x, y, z + 0.16), (x, y, z + 0.24), 0.03, 0.003, mats["flame"], bone, segs=5)


def build_mesh():
    c = scav_mats()
    c["clay"] = k.mat("SA_Clay", (0.56, 0.42, 0.3), rough=0.85)
    c["flame"] = k.mat("SA_Flame", (1.0, 0.5, 0.12), rough=0.4, emit=2.0)
    soot = k.mat("SA_Soot", (0.3, 0.28, 0.26), rough=0.95)
    glass = k.mat("SA_Goggle", (0.2, 0.22, 0.22), metallic=0.3, rough=0.2)
    B.figure(c["skin"], c["wool"], c["patch"], c["boot"], robe=False, sleeves=c["wool"])
    p = B.p
    # Фартук
    k.plate("Apron", [(-0.17, 0), (0.17, 0), (0.18, -0.55), (0.05, -0.6), (-0.06, -0.56), (-0.18, -0.6)], 0.02,
            p(0, -0.15, 1.3), (B.s, 0, 0), (0, -0.08 * B.s, B.s), c["leather"], "Chest")
    k.plate("ApronLow", [(-0.18, 0), (0.18, 0), (0.17, -0.3), (0.0, -0.34), (-0.17, -0.31)], 0.02,
            p(0, -0.17, 0.92), (B.s, 0, 0), (0, -0.12 * B.s, B.s), c["leather"], "ClothF")
    for i, (x, z) in enumerate([(0.08, 1.12), (-0.1, 0.78)]):
        k.box(f"Burn{i}", (0.06, 0.01, 0.05), p(x, -0.165, z), soot, "Chest" if z > 1 else "ClothF")
    # Тряпка на лице, очки на лбу, кепка
    k.sphere("Rag", 0.1, p(0, -0.06, 1.53), soot, "Head", scale=(1.0, 0.7, 0.55), segs=7, rings=4)
    k.sphere("Cap", 0.115, p(0, 0.01, 1.64), c["patch"], "Head", scale=(1.0, 1.05, 0.6), segs=8, rings=4)
    for sg in (-1, 1):
        k.limb(f"Goggle{sg}", p(0.045 * sg, -0.09, 1.66), p(0.045 * sg, -0.13, 1.67), 0.03, 0.03, glass, "Head", segs=7)
    k.limb("GoggleStrap", p(-0.11, -0.04, 1.65), p(0.11, -0.04, 1.65), 0.012, 0.012, c["leather"], "Head", segs=4)
    # Перевязь и пояс с бутылями
    k.limb("Sash", p(-0.17, -0.13, 1.4), p(0.15, -0.14, 1.02), 0.024, 0.024, c["leather"], "Chest", segs=4)
    k.barrel("Belt", 0.17 * B.s, 0.17 * B.s, p(0, 0, 0.96)[2], p(0, 0, 1.0)[2], c["leather"], "Hips", segs=8, sy=0.75)
    for i in range(4):
        f = i / 4
        bottle(f"Sb{i}", p(-0.12 + 0.24 * f, -0.17, 1.28 - 0.26 * f), c, "Chest")
    for i, x in enumerate((-0.12, 0.0, 0.12)):
        bottle(f"Bb{i}", p(x, -0.16, 0.84), c, "Hips")
    # Бутыль в руке (кость Weapon), фитиль горит
    hx, hy, hz = B.hand_r
    bottle("Throw", (hx, hy - 0.02, hz - 0.03), c, "Weapon", lit=True)
    return k.join_parts("ScavArsonistMesh")


BONES = B.bones()
ANIM = hu.Anim("throw")


def build(glb_path, blend_path=None):
    k.start_scene("ScavArsonist")
    body = build_mesh()
    rig = k.build_armature("ScavArsonist", BONES)
    body.parent = rig
    ANIM.bake_all(rig)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "scav_arsonist")
