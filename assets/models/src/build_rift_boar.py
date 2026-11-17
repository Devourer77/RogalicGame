# Вепрь Раскола (~0.9 м в холке) — тварь Раскола, лесная ветка акта 1. Кабан с тёмно-бурой щетиной,
# вдоль хребта — каменные наросты-гребни, между ними светятся бирюзовые трещины Раскола; бивни из тёмного
# камня (не костяные), глаза светятся бирюзой. Низкое тяжёлое тело, голова опущена для удара.
# Облик — claude/мир.md; референс Gemini 17 ноября. Скелет и помощники поз — как у волка (build_wolf.py).
# Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (удар клыками с разбега, толчок 2), Hit, Death.
# Запуск: python3 build_rift_boar.py out/rift_boar.glb out/rift_boar.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "RiftBoar"
SIDES = (("R", -1), ("L", 1))


# ---------- Модель ----------

def build_mesh():
    hide = k.mat("Boar_Hide", (0.4, 0.29, 0.21), rough=0.9)        # тёмно-бурая щетина (светлее природной)
    dark = k.mat("Boar_Dark", (0.25, 0.18, 0.13), rough=0.9)
    snout = k.mat("Boar_Snout", (0.36, 0.27, 0.23), rough=0.8)
    stone = k.mat("Boar_Stone", (0.56, 0.56, 0.54), rough=0.8)      # каменные гребни
    tusk = k.mat("Boar_Tusk", (0.33, 0.33, 0.34), rough=0.6)        # бивни — тёмный камень
    hoof = k.mat("Boar_Hoof", (0.16, 0.13, 0.11), rough=0.7)
    rift = k.mat("Boar_Rift", (0.25, 0.85, 0.75), rough=0.4, emit=1.2)

    # Туловище: тяжёлый перед, зад поуже
    k.limb("Rump", (0, 0.42, 0.52), (0, 0.18, 0.56), 0.15, 0.2, hide, "Hips", segs=8)
    k.limb("Belly", (0, 0.2, 0.55), (0, -0.04, 0.58), 0.2, 0.25, hide, "Spine", segs=8)
    k.limb("Chest", (0, -0.04, 0.58), (0, -0.24, 0.6), 0.25, 0.23, hide, "Chest", segs=8)
    k.sphere("Hump", 0.18, (0, -0.12, 0.74), dark, "Chest", scale=(1.0, 1.4, 0.7), segs=7, rings=4)
    # Голова: клин вниз-вперёд, пятачок, уши, бирюзовые глаза
    k.limb("Neck", (0, -0.22, 0.62), (0, -0.36, 0.56), 0.2, 0.17, hide, "Neck", segs=8)
    k.limb("Skull", (0, -0.34, 0.58), (0, -0.62, 0.38), 0.16, 0.08, hide, "Head", segs=7)
    k.limb("SnoutTip", (0, -0.6, 0.39), (0, -0.67, 0.35), 0.085, 0.08, snout, "Head", segs=7)
    k.box("Nose", (0.1, 0.02, 0.07), (0, -0.685, 0.35), hoof, "Head")
    for side, s in SIDES:
        k.box(f"Eye.{side}", (0.035, 0.04, 0.026), (0.11 * s, -0.45, 0.55), rift, "Head", rot=(30, -18 * s, 10 * s))
        k.plate(f"Ear.{side}", [(-0.04, 0.0), (0.04, 0.0), (0.0, 0.11)], 0.02, (0.1 * s, -0.36, 0.67),
                (1, 0, 0), (0.4 * s, 0.4, 1), dark, f"Ear.{side}")
        # Бивни из тёмного камня: из нижней челюсти вбок и вверх
        k.limb(f"Tusk.{side}", (0.06 * s, -0.6, 0.33), (0.12 * s, -0.62, 0.42), 0.022, 0.014, tusk, "Jaw", segs=5)
        k.limb(f"TuskTip.{side}", (0.12 * s, -0.62, 0.42), (0.12 * s, -0.58, 0.49), 0.014, 0.0, tusk, "Jaw", segs=4)
    k.limb("Jaw", (0, -0.38, 0.45), (0, -0.6, 0.32), 0.09, 0.05, dark, "Jaw", segs=6)

    # Каменные гребни вдоль хребта с бирюзовыми трещинами у основания
    crest = [(-0.3, 0.74, 0.16, "Neck"), (-0.16, 0.82, 0.22, "Chest"), (-0.02, 0.8, 0.2, "Chest"),
             (0.12, 0.74, 0.16, "Spine"), (0.26, 0.68, 0.12, "Hips")]
    for i, (y, z, h, bone) in enumerate(crest):
        for j, dx in enumerate((-0.05, 0.05)):
            k.limb(f"Crest{i}{j}", (dx, y, z - 0.06), (dx * 1.6, y + 0.03 * j, z + h), 0.06, 0.0, stone, bone, segs=4)
        for j, dx in enumerate((-0.05, 0.05)):   # трещина бежит по камню от основания вверх
            base, top = (dx, y, z - 0.02), (dx * 1.6, y + 0.03 * j, z + h)
            ln = math.dist(base, top)
            k.crack(f"CrestCrack{i}{j}", [(0.0, 0.0), (0.012, 0.35 * ln), (-0.008, 0.62 * ln)],
                    (base[0] * 1.15, base[1] - 0.045, base[2]), (1, 0, 0),
                    (top[0] - base[0], top[1] - base[1], top[2] - base[2]), rift, bone, width=0.014, depth=0.03)
        k.limb(f"Bristle{i}", (0, y + 0.07, z - 0.04), (0, y + 0.12, z + 0.04), 0.03, 0.0, dark, bone, segs=4)
    k.crack("FlankCrack", [(0, 0.06), (0.03, 0.0), (-0.02, -0.05), (0.02, -0.1)], (0.2, -0.1, 0.56),
            (0, 1, 0), (0, 0, 1), rift, "Chest", width=0.014, depth=0.03)

    # Короткие толстые ноги с копытами
    for side, s in SIDES:
        for name, y0, bone_y in (("Front", -0.18, -0.18), ("Back", 0.3, 0.3)):
            x = 0.13 * s
            k.limb(f"{name}Upper.{side}", (x, y0, 0.5), (x, y0 + 0.02, 0.27), 0.08, 0.055, hide, f"{name}Upper.{side}")
            k.limb(f"{name}Lower.{side}", (x, y0 + 0.02, 0.27), (x, y0, 0.07), 0.05, 0.04, dark, f"{name}Lower.{side}")
            k.box(f"{name}Hoof.{side}", (0.07, 0.09, 0.07), (x, y0 - 0.02, 0.035), hoof, f"{name}Paw.{side}")
    # Короткий хвост-закорючка
    k.limb("Tail", (0, 0.45, 0.58), (0.02, 0.53, 0.5), 0.025, 0.012, dark, "Tail1", segs=4)
    k.limb("TailTip", (0.02, 0.53, 0.5), (0.0, 0.55, 0.42), 0.012, 0.0, dark, "Tail1", segs=4)
    return k.join_parts("RiftBoarMesh")


# ---------- Скелет (как у волка) ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Hips": ((0, 0.3, 0.48), (0, 0.3, 0.62), "Root"),
    "Spine": ((0, 0.2, 0.56), (0, -0.04, 0.58), "Hips"),
    "Chest": ((0, -0.04, 0.58), (0, -0.24, 0.6), "Spine"),
    "Neck": ((0, -0.22, 0.62), (0, -0.36, 0.56), "Chest"),
    "Head": ((0, -0.36, 0.56), (0, -0.62, 0.38), "Neck"),
    "Jaw": ((0, -0.38, 0.45), (0, -0.6, 0.32), "Head"),
    "Tail1": ((0, 0.45, 0.58), (0, 0.55, 0.42), "Hips"),
}
for side, s in SIDES:
    x = 0.13 * s
    BONES[f"Ear.{side}"] = ((0.1 * s, -0.36, 0.67), (0.13 * s, -0.33, 0.78), "Head")
    for name, y0, parent in (("Front", -0.18, "Chest"), ("Back", 0.3, "Hips")):
        BONES.update({
            f"{name}Upper.{side}": ((x, y0, 0.5), (x, y0 + 0.02, 0.27), parent),
            f"{name}Lower.{side}": ((x, y0 + 0.02, 0.27), (x, y0, 0.07), f"{name}Upper.{side}"),
            f"{name}Paw.{side}": ((x, y0, 0.07), (x, y0 - 0.08, 0.02), f"{name}Lower.{side}"),
        })

UP = -1.0     # кости вперёд: поднять передний конец — X * UP
LEFT = -1.0


class BoarPose(Pose):
    def lift(self, bone, deg):
        return self.add(bone, x=UP * deg)

    def turn(self, bone, deg):
        return self.add(bone, z=LEFT * deg)

    def leg(self, name, upper=0.0, lower=0.0, paw=0.0):
        """Нога: плюс — вперёд. name: FrontL, FrontR, BackL, BackR."""
        base, side = name[:-1], name[-1]
        self.add(f"{base}Upper.{side}", x=-upper)
        self.add(f"{base}Lower.{side}", x=-lower)
        self.add(f"{base}Paw.{side}", x=-paw)
        return self

    def ears(self, fwd=0.0, out=0.0):
        self.add("Ear.L", x=fwd, z=-out)
        self.add("Ear.R", x=fwd, z=out)
        return self


# ---------- Анимации ----------

def stance():
    """Голова опущена для удара, передние ноги расставлены, загривок вздыблен."""
    p = BoarPose({}, {})
    p.move("Hips", z=-0.02)
    p.add("Hips", x=4)
    p.lift("Neck", -8).lift("Head", -6)
    p.leg("FrontL", upper=8, lower=-6).leg("FrontR", upper=-6, lower=-4)
    p.leg("BackL", upper=-6, lower=4).leg("BackR", upper=6)
    return p


def idle(t):
    """Покой (3 сек): тяжело дышит, фыркает (голова дёргается вверх), уши дёргаются, хвост крутится.
    Характерное: роет землю передней ногой перед броском."""
    p = stance()
    breath = wave(t, 2)
    p.move("Hips", z=0.006 * breath)
    p.lift("Spine", 1.5 * breath).lift("Chest", -breath)
    snort = pulse(t, 0.25, 0.04) + pulse(t, 0.31, 0.04)
    p.lift("Head", 8 * snort + 4 * wave(t, 1, 0.2)).turn("Neck", 12 * wave(t, 1, 0.1))
    p.add("Jaw", x=6 * snort)
    p.ears(fwd=10 * pulse(t, 0.15, 0.04) - 10 * pulse(t, 0.55, 0.05))
    p.add("Tail1", z=20 * wave(t, 4))
    dig = track(t, [(0, 0), (0.6, 0), (0.64, 1), (0.7, -0.5), (0.74, 1), (0.8, -0.5), (0.86, 0), (1, 0)])
    p.leg("FrontR", upper=24 * dig, lower=-20 * abs(dig), paw=-10 * dig)
    p.lift("Neck", -6 * abs(dig))
    return p


def walk(t):
    """Тяжёлая рысь (0.6 сек): ноги по диагонали, корпус качается, голова кивает."""
    p = BoarPose({}, {})
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.05)
    p.move("Hips", z=-0.015 + 0.02 * bounce)
    p.add("Hips", x=4 + 2 * bounce, z=3 * a)
    p.turn("Spine", 4 * a).turn("Chest", -3 * a)
    p.lift("Neck", -8 + 4 * wave(t, 2, -0.1)).lift("Head", -6)
    for name, ph in (("FrontL", a), ("FrontR", -a)):
        lift = max(0.0, c if name == "FrontL" else -c)
        p.leg(name, upper=26 * ph, lower=-30 * lift, paw=20 * lift)
    for name, ph in (("BackR", a), ("BackL", -a)):
        lift = max(0.0, c if name == "BackR" else -c)
        p.leg(name, upper=26 * ph, lower=-20 * lift, paw=16 * lift)
    p.ears(fwd=-14)
    p.add("Tail1", z=14 * a)
    return p


def attack(t):
    """Удар клыками (0.8 сек): присел на задние → бросок вперёд с опущенной головой → подкидывает цель
    клыками вверх (к 0.4 сек) → отступает."""
    p = BoarPose({}, {})
    K = [0.0, 0.25, 0.42, 0.52, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.move("Root", y=tr([0, 0.08, -0.36, -0.32, 0]))
    p.move("Hips", z=tr([-0.02, -0.08, 0.02, -0.01, -0.02]))
    p.add("Hips", x=tr([4, 14, -4, 2, 4]))
    p.lift("Neck", tr([-8, -20, -24, 18, -8]))
    p.lift("Head", tr([-6, -14, -10, 26, -6]))
    p.add("Jaw", x=tr([0, 0, 0, 8, 0]))
    p.leg("FrontL", upper=tr([8, -20, 50, 20, 8]), lower=tr([-6, -40, -10, -20, -6]))
    p.leg("FrontR", upper=tr([-6, -26, 44, 14, -6]), lower=tr([-4, -40, -10, -20, -4]))
    p.leg("BackL", upper=tr([-6, 24, -40, -10, -6]), lower=tr([4, -30, 20, 0, 4]))
    p.leg("BackR", upper=tr([6, 28, -44, -6, 6]), lower=tr([0, -30, 20, 0, 0]))
    p.ears(fwd=tr([0, -30, -40, -20, 0]))
    p.add("Tail1", x=tr([0, 20, 30, 10, 0]))
    return p


def hit(t):
    """Получил удар (0.47 сек): визг, тело отбросило, голова мотнулась."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.34, 1), (0.58, -0.3), (0.8, 0.1), (1, 0)])
    p.move("Root", y=0.1 * snap)
    p.add("Hips", x=-6 * snap, y=6 * snap)
    p.turn("Spine", -10 * snap)
    p.lift("Neck", 20 * whip).turn("Head", 18 * whip)
    p.add("Jaw", x=20 * snap)
    p.ears(fwd=-30 * snap)
    p.leg("FrontL", upper=-16 * snap).leg("FrontR", upper=10 * snap, lower=-20 * snap)
    return p


def death(t):
    """Гибель (1.2 сек): ноги подкосились, завалился на бок, ноги дёрнулись напоследок."""
    p = BoarPose({}, {})
    K = [0.0, 0.2, 0.42, 0.66, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    side = track(t, [(0, 0), (K[2], 8), (K[3], 86), (K[3] + 0.07, 80), (K[3] + 0.14, 86), (1, 86)])
    p.set("Root", 0, 0, side)   # кость Root смотрит вверх: Z — завалиться на бок
    p.move("Root", y=tr([0, 0.08, 0.1, 0.1, 0.1]), z=tr([0, 0, 0, 0.18, 0.18]), x=tr([0, 0, 0, -0.12, -0.12]))
    p.move("Hips", z=tr([-0.02, 0.0, -0.14, -0.28, -0.28]))
    p.lift("Neck", tr([-8, 16, -20, -6, -10])).lift("Head", tr([-6, -10, 10, 0, 4]))
    p.add("Jaw", x=tr([0, 20, 10, 16, 12]))
    spasm = pulse(t, 0.85, 0.05)
    p.leg("FrontL", upper=tr([8, -16, 50, 20, 16]), lower=tr([-6, -20, -80, -30, -20]))
    p.leg("FrontR", upper=tr([-6, 16, 40, 10, 6]) + 14 * spasm, lower=tr([-4, -30, -80, -30, -20]) - 20 * spasm)
    p.leg("BackL", upper=tr([-6, 10, -10, -24, -20]), lower=tr([4, -16, -20, 6, 4]))
    p.leg("BackR", upper=tr([6, 20, 14, -6, -10]) + 16 * spasm, lower=tr([0, -24, -30, -6, 0]) - 18 * spasm)
    p.ears(fwd=tr([0, -30, -20, -30, -30]))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 18, walk, cyclic=True)
    k.bake(rig, "Attack", 24, attack)
    k.bake(rig, "Hit", 14, hit)
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
    glb = args[0] if args else os.path.join(here, "..", "rift_boar.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "rift_boar.blend")
    build(glb, blend)
