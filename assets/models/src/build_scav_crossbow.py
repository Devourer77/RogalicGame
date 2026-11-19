# Мародёр с самострелом — третья сила Тракта (акт 2), ~1.7 м. Люди Марки без магии и техники, грабят
# брошенные обозы. Худой, в латаном мешковинном пальто, грязная тряпка на лице, помятый котелок
# с ручкой вместо шлема (не армейская каска), перевязь с разномастными болтами, мешок с добычей
# на спине. Тяжёлый самострел из тележной рессоры. Никаких знаков фракций.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (выстрел), Hit, Death.
# Запуск: python3 build_scav_crossbow.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2
import act2_human as hu

B = hu.Body(1.7)


def scav_mats():
    return dict(
        sack=k.mat("SC_Sack", (0.58, 0.52, 0.42), rough=0.95),
        patch=k.mat("SC_Patch", (0.44, 0.38, 0.3), rough=0.95),
        wool=k.mat("SC_Wool", (0.42, 0.43, 0.34), rough=0.95),
        leather=k.mat("SC_Leather", (0.4, 0.29, 0.2), rough=0.85),
        rag=k.mat("SC_Rag", (0.5, 0.45, 0.38), rough=0.95),
        skin=k.mat("SC_Skin", (0.66, 0.54, 0.45), rough=0.8),
        rust=k.mat("SC_Rust", (0.46, 0.34, 0.25), metallic=0.4, rough=0.7),
        wood=k.mat("SC_Wood", (0.44, 0.33, 0.22), rough=0.9),
        boot=k.mat("SC_Boot", (0.3, 0.26, 0.22), rough=0.85),
    )


def build_mesh():
    c = scav_mats()
    m = a2.mech_mats()
    B.figure(c["skin"], c["sack"], c["wool"], c["boot"], robe=True, sleeves=c["sack"])
    p = B.p
    # Заплаты на пальто
    for i, (x, y, z) in enumerate([(0.1, -0.15, 1.28), (-0.12, -0.19, 0.78), (0.14, 0.12, 1.1)]):
        k.box(f"Patch{i}", (0.08, 0.02, 0.08), p(x, y, z), c["patch"], "Chest" if z > 1.0 else "Hips", rot=(0, 0, 12 * i))
    for i, (x, z) in enumerate([(-0.12, 1.06), (0.12, 1.06)]):   # карманы
        k.box(f"Pocket{i}", (0.09, 0.03, 0.08), p(x, -0.135, z), c["patch"], "Spine")
    # Тряпка на лице, котелок с ручкой
    k.sphere("Rag", 0.1, p(0, -0.06, 1.53), c["rag"], "Head", scale=(1.0, 0.7, 0.55), segs=7, rings=4)
    k.barrel("Pot", 0.135, 0.125, p(0, 0, 1.63)[2], p(0, 0, 1.74)[2], c["rust"], "Head", segs=10)
    k.barrel("PotRim", 0.15, 0.15, p(0, 0, 1.63)[2], p(0, 0, 1.65)[2], c["rust"], "Head", segs=10)
    k.box("PotDent", (0.06, 0.02, 0.04), p(0.06, -0.12, 1.7), m["iron_d"], "Head", rot=(0, 0, 30))
    a2.ring("PotHandle", 0.1, 0.008, p(0, 0, 1.74), (1, 0, 0), m["iron_d"], "Head", seg=10)
    # Перевязь с болтами
    k.limb("Bandolier", p(-0.17, -0.12, 1.4), p(0.15, -0.13, 1.0), 0.022, 0.022, c["leather"], "Chest", segs=4)
    for i in range(5):
        f = i / 5
        x, z = -0.13 + 0.26 * f, 1.36 - 0.32 * f
        k.limb(f"Bolt{i}", p(x, -0.15, z), p(x - 0.02, -0.16, z + 0.12), 0.007, 0.007, c["wood"] if i % 2 else c["rust"],
               "Chest", segs=4)
    # Мешок с добычей на спине
    k.sphere("Loot", 0.2, p(0, 0.25, 1.24), c["patch"], "Chest", scale=(1.0, 0.75, 1.1), segs=7, rings=5)
    k.box("LootTie", (0.08, 0.06, 0.06), p(0, 0.27, 1.46), c["leather"], "Chest")
    # Самострел из тележной рессоры (кость Weapon — вперёд из правой руки)
    hx, hy, hz = B.hand_r
    k.box("Stock", (0.06, 0.5, 0.06), (hx, hy - 0.12, hz), c["wood"], "Weapon")
    k.plate("Bow", [(-0.34, 0.06), (-0.2, 0.0), (0.0, -0.02), (0.2, 0.0), (0.34, 0.06), (0.34, 0.1), (0.2, 0.04),
                    (0.0, 0.02), (-0.2, 0.04), (-0.34, 0.1)], 0.03, (hx, hy - 0.38, hz), (1, 0, 0), (0, -1, 0),
            c["rust"], "Weapon")
    k.limb("String1", (hx - 0.33, hy - 0.44, hz), (hx, hy - 0.2, hz), 0.004, 0.004, c["rag"], "Weapon", segs=3)
    k.limb("String2", (hx + 0.33, hy - 0.44, hz), (hx, hy - 0.2, hz), 0.004, 0.004, c["rag"], "Weapon", segs=3)
    k.limb("LoadedBolt", (hx, hy - 0.2, hz + 0.04), (hx, hy - 0.5, hz + 0.04), 0.008, 0.008, c["wood"], "Weapon", segs=4)
    return k.join_parts("ScavCrossbowMesh")


BONES = B.bones()
ANIM = hu.Anim("aim", crouch=0.35)


def build(glb_path, blend_path=None):
    k.start_scene("ScavCrossbow")
    body = build_mesh()
    rig = k.build_armature("ScavCrossbow", BONES)
    body.parent = rig
    ANIM.bake_all(rig)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "scav_crossbow")
