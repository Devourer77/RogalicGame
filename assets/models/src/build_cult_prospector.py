# Старатель Венца — культист акта 2 (Подземье), ~1.6 м. Сутулый, в пыльной пепельно-серой рясе,
# подвязанной у колен, под капюшоном кожаная шахтёрская шапка с фонариком, над капюшоном — тонкий
# костяной венец. На спине деревянная рама со сферой огня в железной клетке (несёт её Венцу).
# В руках две кирки (как на листе Gemini). Погибая, сфера бьётся — в игре стихия рядом.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (кирки сверху), Hit, Death.
# Запуск: python3 build_cult_prospector.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2
import act2_human as hu

B = hu.Body(1.6)


def pickaxe(prefix, bone, hand, m, wood):
    x, y, z = hand
    k.limb(prefix + "Haft", (x, y + 0.08, z), (x, y - 0.38, z), 0.022, 0.02, wood, bone, segs=5)
    k.plate(prefix + "Head", [(-0.02, 0.0), (0.02, 0.0), (0.03, 0.16), (0.0, 0.2), (-0.01, 0.12), (-0.02, -0.12),
                              (0.0, -0.18), (0.03, -0.14), (0.02, 0.0)], 0.03,
            (x, y - 0.38, z), (0, -1, 0), (0, 0, 1), m["iron_d"], bone)


def build_mesh():
    m = a2.mech_mats()
    ash = k.mat("CP_Ash", (0.52, 0.51, 0.49), rough=0.95)
    ash_d = k.mat("CP_AshDark", (0.36, 0.35, 0.34), rough=0.95)
    leather = k.mat("CP_Leather", (0.38, 0.28, 0.2), rough=0.85)
    wood = k.mat("CP_Wood", (0.42, 0.32, 0.22), rough=0.9)
    bone_w = k.mat("CP_Bone", (0.86, 0.83, 0.74), rough=0.6, emit=0.15)
    void = k.mat("CP_Void", (0.08, 0.08, 0.09), rough=1.0)
    skin = k.mat("CP_Skin", (0.5, 0.46, 0.42), rough=0.8)
    fire, core = a2.element_mats()["fire"]
    B.figure(skin, ash, ash_d, leather, robe=True, head=False)
    p = B.p
    # Капюшон и шахтёрская шапка с фонариком
    k.sphere("Hood", 0.14 * B.s, p(0, 0.0, 1.58), ash, "Head", scale=(0.95, 1.05, 1.1), segs=8, rings=5)
    k.sphere("Face", 0.1 * B.s, p(0, -0.06, 1.56), void, "Head", scale=(0.85, 0.6, 0.95), segs=7, rings=4)
    k.barrel("Cap", 0.13 * B.s, 0.11 * B.s, p(0, 0, 1.66)[2], p(0, 0, 1.73)[2], leather, "Head", segs=8)
    k.limb("Lamp", p(0, -0.11, 1.69), p(0, -0.15, 1.69), 0.025, 0.025, m["iron_d"], "Head", segs=6)
    k.limb("LampGlow", p(0, -0.15, 1.69), p(0, -0.16, 1.69), 0.02, 0.02, m["lamp"], "Head", segs=6)
    a2.ring("Crown", 0.11 * B.s, 0.012, p(0, 0.01, 1.86), (0, 0, 1), bone_w, "Crown", seg=14)
    # Пояс-верёвка и подвязка у колен
    k.barrel("Belt", 0.17 * B.s, 0.17 * B.s, p(0, 0, 0.98)[2], p(0, 0, 1.01)[2], leather, "Hips", segs=8, sy=0.75)
    # Рама со сферой на спине
    for sx in (-1, 1):
        k.box(f"FramePost{sx}", (0.04, 0.04, 0.62), p(0.13 * sx, 0.2, 1.36), wood, "Chest")
    k.box("FrameBar", (0.32, 0.04, 0.04), p(0, 0.2, 1.12), wood, "Chest")
    k.box("FrameBar2", (0.32, 0.04, 0.04), p(0, 0.2, 1.58), wood, "Chest")
    k.limb("StrapL", p(0.12, -0.06, 1.38), p(0.12, 0.18, 1.12), 0.015, 0.015, leather, "Chest", segs=4)
    k.limb("StrapR", p(-0.12, -0.06, 1.38), p(-0.12, 0.18, 1.12), 0.015, 0.015, leather, "Chest", segs=4)
    c = p(0, 0.36, 1.44)
    a2.caged_sphere("Orb", 0.2 * B.s, c, fire, m["iron_d"], "Orb", cage_bone="Chest")
    a2.element_marks("Orb", "fire", c, 0.2 * B.s, core, "Orb")
    k.crack("OrbRift", [(0, 0), (0.04, 0.04), (0.08, 0.0)], (c[0] + 0.06, c[1] - 0.18, c[2] - 0.06), (1, 0, 0), (0, 0, 1),
            m["rift"], "Orb", width=0.012, depth=0.012)
    # Две кирки
    pickaxe("PickR", "Weapon", B.hand_r, m, wood)
    pickaxe("PickL", "Prop", B.hand_l, m, wood)
    return k.join_parts("CultProspectorMesh")


BONES = B.bones({
    "Crown": (B.p(0, 0.01, 1.82), B.p(0, 0.01, 1.92), "Head"),
    "Orb": (B.p(0, 0.36, 1.26), B.p(0, 0.36, 1.62), "Chest"),
})
ANIM = hu.Anim("swing", hunch=16, extra_stance={"Crown": (0, 0, 0)})
_base_death = ANIM.death


def death_orb(t):
    p = _base_death(t)
    p.size("Orb", track(t, [(0, 1.0), (0.4, 1.0), (0.45, 1.25), (0.5, 0.12), (1, 0.12)]))   # сфера бьётся
    p.add("Crown", x=30 * track(t, [(0, 0), (0.7, 1), (1, 1)]))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("CultProspector")
    body = build_mesh()
    rig = k.build_armature("CultProspector", BONES)
    body.parent = rig
    ANIM.death = death_orb
    ANIM.bake_all(rig, scale_bones=("Orb",))
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "cult_prospector")
