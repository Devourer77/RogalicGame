# Огнеход Жерла — культист акта 2 (Тракт, лавовые русла и край жерла), ~1.8 м. Худой, в плотных
# серых обмотках с тёмными полосами, глиняная маска с узкими прорезями вместо капюшона, над головой
# костяной венец. Толстые сапоги из глины и железа, подошвы раскалены. В руках длинный железный шест
# с тяжёлым крюком (один крюк — первый вариант листа Gemini): сталкивает героев в лаву.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (тычок крюком), Hit, Death.
# Запуск: python3 build_crater_walker.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2
import act2_human as hu
from mathutils import Vector

B = hu.Body(1.8)


def bands(prefix, a, b, r, n, mat, bone):
    """Тёмные полосы обмоток вдоль конечности от a до b."""
    a, b = Vector(a), Vector(b)
    for i in range(n):
        f0 = (i + 0.3) / n
        f1 = f0 + 0.35 / n
        k.limb(f"{prefix}{i}", tuple(a.lerp(b, f0)), tuple(a.lerp(b, f1)), r, r, mat, bone, segs=6)


def build_mesh():
    m = a2.mech_mats()
    wrap = k.mat("CW_Wrap", (0.5, 0.48, 0.45), rough=0.95)
    wrap_d = k.mat("CW_WrapDark", (0.28, 0.27, 0.27), rough=0.95)
    leather = k.mat("CW_Leather", (0.4, 0.27, 0.18), rough=0.85)
    clay = k.mat("CW_Clay", (0.6, 0.54, 0.46), rough=0.9)
    boot = k.mat("CW_Boot", (0.34, 0.3, 0.27), rough=0.85)
    bone_w = k.mat("CW_Bone", (0.86, 0.83, 0.74), rough=0.6, emit=0.15)
    slit = k.mat("CW_Slit", (0.08, 0.07, 0.07), rough=1.0)
    B.figure(wrap, wrap, wrap, boot, robe=False, head=False)
    p = B.p
    s = B.s
    # Полосы обмоток на теле и конечностях
    for i, z in enumerate((1.04, 1.16, 1.28)):
        k.barrel(f"TorsoBand{i}", 0.185 * s, 0.19 * s, p(0, 0, z)[2], p(0, 0, z + 0.045)[2], wrap_d, "Chest" if z > 1.18 else "Spine",
                 segs=8, sy=0.72)
    for side, sg in hu.SIDES:
        bands(f"ArmBand.{side}", p(0.2 * sg, 0, 1.36), p(0.24 * sg, 0, 1.12), 0.058 * s, 2, wrap_d, f"UpperArm.{side}")
        bands(f"ForeBand.{side}", p(0.24 * sg, 0, 1.12), p(0.26 * sg, -0.05, 0.9), 0.048 * s, 2, wrap_d, f"ForeArm.{side}")
        bands(f"ThighBand.{side}", p(0.1 * sg, 0, 0.9), p(0.11 * sg, -0.02, 0.5), 0.078 * s, 2, wrap_d, f"Thigh.{side}")
        bands(f"ShinBand.{side}", p(0.11 * sg, -0.02, 0.5), p(0.11 * sg, 0, 0.24), 0.063 * s, 2, wrap_d, f"Shin.{side}")
        # Раскалённые подошвы
        k.box(f"Sole.{side}", (0.12 * s, 0.23 * s, 0.025), p(0.11 * sg, -0.05, 0.012), m["hot"], f"Foot.{side}")
    # Ремни крест-накрест
    k.limb("StrapA", p(-0.16, -0.13, 1.4), p(0.14, -0.13, 1.02), 0.02, 0.02, leather, "Chest", segs=4)
    k.limb("StrapB", p(0.16, -0.13, 1.4), p(-0.14, -0.13, 1.02), 0.02, 0.02, leather, "Chest", segs=4)
    k.barrel("Belt", 0.17 * s, 0.17 * s, p(0, 0, 0.97)[2], p(0, 0, 1.01)[2], leather, "Hips", segs=8, sy=0.75)
    # Голова в обмотках и глиняная маска с прорезями
    k.sphere("HeadWrap", 0.115 * s, p(0, 0.0, 1.58), wrap, "Head", scale=(0.92, 1.0, 1.12), segs=8, rings=5)
    k.sphere("Mask", 0.1 * s, p(0, -0.05, 1.58), clay, "Head", scale=(0.95, 0.55, 1.12), segs=8, rings=5)
    for sg in (-1, 1):
        k.box(f"EyeSlit{sg}", (0.04 * s, 0.02, 0.01), p(0.035 * sg, -0.105, 1.6), slit, "Head", rot=(0, 0, 8 * sg))
    k.crack("MaskCrack", [(0, 0), (0.02, -0.03), (0.01, -0.06)], p(0.02, -0.106, 1.64), (1, 0, 0), (0, 0, 1), slit, "Head",
            width=0.006, depth=0.006)
    a2.ring("Crown", 0.11 * s, 0.012, p(0, 0.0, 1.86), (0, 0, 1), bone_w, "Crown", seg=14)
    # Шест с крюком (кость Weapon смотрит вперёд из правой руки)
    hx, hy, hz = B.hand_r
    k.limb("Pole", (hx, hy + 0.5, hz), (hx, hy - 1.0, hz), 0.022, 0.022, m["iron_d"], "Weapon", segs=6)
    k.plate("Hook", [(0, 0), (0.05, 0.0), (0.1, 0.05), (0.12, 0.13), (0.07, 0.16), (0.08, 0.1), (0.04, 0.05), (0.0, 0.04)],
            0.035, (hx, hy - 1.0, hz), (0, -1, 0), (0, 0, 1), m["iron"], "Weapon")
    k.limb("HookTip", (hx, hy - 1.07, hz + 0.16), (hx, hy - 1.03, hz + 0.2), 0.016, 0.004, m["hot"], "Weapon", segs=4)
    return k.join_parts("CraterWalkerMesh")


BONES = B.bones({"Crown": (B.p(0, 0.0, 1.82), B.p(0, 0.0, 1.92), "Head")})
ANIM = hu.Anim("thrust", hunch=6, extra_stance={"Crown": (0, 0, 0)})


def build(glb_path, blend_path=None):
    k.start_scene("CraterWalker")
    body = build_mesh()
    rig = k.build_armature("CraterWalker", BONES)
    body.parent = rig
    ANIM.bake_all(rig)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "crater_walker")
