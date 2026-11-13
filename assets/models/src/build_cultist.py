# Культист Пустого Венца (~1.7 м). Высокий, худой, сутулый. Длинная рваная ряса пепельно-серого и
# угольно-чёрного цвета, глубокий капюшон — лица нет, только тьма. Над капюшоном парит пустое кольцо-венец
# костяного цвета. Тёмный железный посох, с конца на цепи свисает клетка-фонарь с бледным светом:
# из неё он бьёт линией. Никакого фиолетового (цвет Мага), красного и золота.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Анимации: Idle, Walk, Attack (луч из фонаря), Hit, Death.
# Запуск: python3 build_cultist.py out/cultist.glb out/cultist.blend (нужен модуль bpy)
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "Cultist"
SIDES = (("R", -1), ("L", 1))
ROBE = [("RobeF", (0, -0.2), (1, 0, 0), (0, -0.25, 1)), ("RobeB", (0, 0.2), (1, 0, 0), (0, 0.25, 1)),
        ("RobeL", (0.2, 0), (0, 1, 0), (0.25, 0, 1)), ("RobeR", (-0.2, 0), (0, 1, 0), (-0.25, 0, 1))]
HAND_R = (-0.29, -0.09, 0.88)    # правая кисть в покое: посох проходит сквозь кулак
_D = (0.38, -0.86, 0.34)         # направление посоха: вперёд, влево и вверх
STAFF_A = tuple(HAND_R[i] - 0.55 * _D[i] for i in range(3))   # нижний конец (сзади-справа)
STAFF_B = tuple(HAND_R[i] + 0.95 * _D[i] for i in range(3))   # верхний конец с крюком


# ---------- Модель ----------

def build_mesh():
    robe = k.mat("Cultist_Robe", (0.40, 0.40, 0.38), rough=0.95)       # пепельно-серая ряса
    under = k.mat("Cultist_Under", (0.19, 0.19, 0.19), rough=0.95)     # угольно-чёрная нижняя ряса
    hood_in = k.mat("Cultist_Void", (0.02, 0.02, 0.025), rough=1.0)    # тьма под капюшоном
    bone = k.mat("Cultist_Bone", (0.84, 0.82, 0.74), rough=0.6)        # костяной белый
    skin = k.mat("Cultist_Hand", (0.56, 0.54, 0.50), rough=0.8)        # серые худые кисти
    iron = k.mat("Cultist_Iron", (0.24, 0.24, 0.26), metallic=0.6, rough=0.55)
    glow = k.mat("Cultist_Glow", (0.92, 0.94, 0.90), rough=0.3, emit=2.4)
    crown = k.mat("Cultist_Crown", (0.88, 0.86, 0.78), rough=0.5, emit=0.25)

    # Нижняя ряса (чёрная) до земли и верхняя (серая) покороче, с рваным краем
    k.barrel("UnderRobe", 0.3, 0.17, 0.02, 0.92, under, "Hips", segs=9, sy=0.85)
    k.barrel("Torso", 0.2, 0.17, 0.92, 1.42, robe, "Chest", segs=8, sy=0.8)
    k.barrel("Belt", 0.19, 0.19, 0.94, 1.0, under, "Spine", segs=8, sy=0.8)
    # Полы верхней рясы — на своих костях (колышутся), рваный край зубцами
    for name, (x, y), u, v in ROBE:
        w = 0.2 if name in ("RobeF", "RobeB") else 0.16
        teeth = [(-w, 0), (w, 0), (w * 1.1, -0.55), (w * 0.6, -0.42), (w * 0.3, -0.62), (-w * 0.1, -0.45),
                 (-w * 0.5, -0.66), (-w * 0.8, -0.48), (-w * 1.1, -0.58)]
        k.plate(name, teeth, 0.025, (x, y, 0.96), u, v, robe, name)
    # Наплечная пелерина
    k.barrel("Mantle", 0.27, 0.15, 1.22, 1.46, robe, "Chest", segs=8, sy=0.85)
    # Капюшон: большой, островерхий, лицо — пустота
    k.sphere("Hood", 0.16, (0, 0.02, 1.58), robe, "Head", scale=(1.0, 1.1, 1.15), segs=8, rings=5)
    k.limb("HoodTip", (0, 0.06, 1.68), (0, 0.18, 1.82), 0.09, 0.01, robe, "Head", segs=6)
    k.sphere("Void", 0.11, (0, -0.07, 1.56), hood_in, "Head", scale=(0.9, 0.6, 1.1), segs=7, rings=4)
    k.barrel("HoodRim", 0.14, 0.12, 1.43, 1.47, bone, "Head", segs=8, loc=(0, -0.02), sy=0.9)
    # Пустой венец — кольцо над капюшоном на своей кости (парит и покачивается)
    n = 14
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        p0 = (0.15 * math.cos(a0), 0.02 + 0.15 * math.sin(a0), 1.95)
        p1 = (0.15 * math.cos(a1), 0.02 + 0.15 * math.sin(a1), 1.95)
        k.limb(f"Crown{i}", p0, p1, 0.016, 0.016, crown, "Crown", segs=4)

    # Руки: широкие рукава с костяными манжетами, худые кисти
    for side, s in SIDES:
        k.limb(f"Sleeve.{side}", (0.2 * s, 0, 1.4), (0.27 * s, -0.04, 1.16), 0.07, 0.08, robe, f"UpperArm.{side}", segs=6)
        k.limb(f"Cuff.{side}", (0.27 * s, -0.04, 1.16), (0.29 * s, -0.08, 0.94), 0.08, 0.11, robe, f"ForeArm.{side}", segs=6)
        k.barrel(f"CuffBone.{side}", 0.11, 0.11, 0.93, 0.97, bone, f"ForeArm.{side}", segs=7, loc=(0.29 * s, -0.08))
        k.sphere(f"Hand.{side}", 0.045, (0.29 * s, -0.09, 0.88), skin, f"Hand.{side}", scale=(0.8, 1.0, 1.2), segs=5, rings=3)
        k.limb(f"Fingers.{side}", (0.29 * s, -0.1, 0.86), (0.29 * s, -0.13, 0.8), 0.03, 0.015, skin, f"Hand.{side}", segs=4)
        # Ступни чуть видны из-под рясы
        k.box(f"Foot.{side}", (0.09, 0.18, 0.06), (0.1 * s, -0.12, 0.03), under, f"Foot.{side}")

    # Посох (кость Weapon): тёмное железо, крюк наверху, цепь с клеткой-фонарём (кости Chain, Lantern)
    k.limb("Staff", STAFF_A, STAFF_B, 0.022, 0.02, iron, "Weapon", segs=6)
    hook = (STAFF_B[0] + 0.02, STAFF_B[1] - 0.06, STAFF_B[2] + 0.06)
    k.limb("StaffHook", STAFF_B, hook, 0.02, 0.014, iron, "Weapon", segs=5)
    k.limb("StaffHook2", hook, (hook[0], hook[1] - 0.02, hook[2] - 0.05), 0.014, 0.01, iron, "Weapon", segs=4)
    top = (hook[0], hook[1] - 0.02, hook[2] - 0.05)
    for i in range(4):
        z = top[2] - 0.04 - i * 0.055
        k.box(f"Link{i}", (0.014, 0.035 if i % 2 else 0.012, 0.05), (top[0], top[1], z), iron, "Chain")
    lz = top[2] - 0.34
    k.box("CageTop", (0.11, 0.11, 0.03), (top[0], top[1], lz + 0.1), iron, "Lantern")
    k.box("CageBottom", (0.12, 0.12, 0.03), (top[0], top[1], lz - 0.08), iron, "Lantern")
    k.limb("CageRing", (top[0], top[1], lz + 0.115), (top[0], top[1], lz + 0.15), 0.025, 0.012, iron, "Lantern", segs=5)
    for i in range(6):
        a = math.tau * i / 6
        bx, by = top[0] + 0.06 * math.cos(a), top[1] + 0.06 * math.sin(a)
        k.limb(f"Bar{i}", (bx, by, lz - 0.07), (bx, by, lz + 0.09), 0.008, 0.008, iron, "Lantern", segs=3)
    k.sphere("Flame", 0.062, (top[0], top[1], lz + 0.01), glow, "Glow", scale=(0.8, 0.8, 1.2), segs=6, rings=4)
    return k.join_parts("CultistMesh")


# ---------- Скелет ----------

_hook = (STAFF_B[0] + 0.02, STAFF_B[1] - 0.08, STAFF_B[2] + 0.01)
BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Hips": ((0, 0, 0.88), (0, 0, 0.98), "Root"),
    "Spine": ((0, 0, 0.98), (0, 0, 1.18), "Hips"),
    "Chest": ((0, 0, 1.18), (0, 0, 1.42), "Spine"),
    "Head": ((0, 0, 1.42), (0, 0, 1.75), "Chest"),
    "Crown": ((0, 0.02, 1.9), (0, 0.02, 2.0), "Head"),
    "Weapon": (HAND_R, (HAND_R[0], HAND_R[1] - 0.2, HAND_R[2]), "Hand.R"),
    "Chain": (_hook, (_hook[0], _hook[1], _hook[2] - 0.22), "Weapon"),
    "Lantern": ((_hook[0], _hook[1], _hook[2] - 0.22), (_hook[0], _hook[1], _hook[2] - 0.44), "Chain"),
    "Glow": ((_hook[0], _hook[1], _hook[2] - 0.34), (_hook[0], _hook[1], _hook[2] - 0.24), "Lantern"),
}
for name, (x, y), u, v in ROBE:
    BONES[name] = ((x, y, 0.96), (x * 1.2, y * 1.2, 0.4), "Hips")
for side, s in SIDES:
    BONES.update({
        f"UpperArm.{side}": ((0.2 * s, 0, 1.4), (0.27 * s, -0.04, 1.16), "Chest"),
        f"ForeArm.{side}": ((0.27 * s, -0.04, 1.16), (0.29 * s, -0.08, 0.94), f"UpperArm.{side}"),
        f"Hand.{side}": ((0.29 * s, -0.08, 0.94), (0.29 * s, -0.1, 0.82), f"ForeArm.{side}"),
        f"Thigh.{side}": ((0.1 * s, 0, 0.88), (0.1 * s, 0, 0.46), "Hips"),
        f"Shin.{side}": ((0.1 * s, 0, 0.46), (0.1 * s, 0, 0.08), f"Thigh.{side}"),
        f"Foot.{side}": ((0.1 * s, 0, 0.08), (0.1 * s, -0.16, 0.03), f"Shin.{side}"),
    })


# ---------- Анимации ----------
# Посох в модели уже стоит наискосок у груди, поэтому в стойке руки почти не поворачиваются:
# правая держит посох, левая открыта ладонью вперёд, голова склонена набок — «поёт».
STANCE = {
    "Spine": (10, -6, 0), "Chest": (12, -4, 0), "Head": (6, 10, 12),
    "UpperArm.R": (-10, 0, 0), "ForeArm.R": (-20, 0, 0),
    "UpperArm.L": (-40, 0, -24), "ForeArm.L": (-36, 0, 0), "Hand.L": (-20, 0, 0),
    "Thigh.L": (-12, 0, 0), "Shin.L": (14, 0, 0), "Thigh.R": (6, 0, 0), "Shin.R": (8, 0, 0),
    "RobeF": (-6, 0, 0), "RobeB": (4, 0, 0),
}


def stance():
    return Pose(STANCE, {"Hips": (0, 0, -0.02)})


def robe(p, fwd=0.0, side=0.0):
    """Полы рясы: fwd — колышутся вперёд-назад, side — вбок."""
    p.add("RobeF", x=-fwd)
    p.add("RobeB", x=fwd)
    p.add("RobeL", z=-side)
    p.add("RobeR", z=-side)
    return p


def idle(t):
    """Покой (3 сек): покачивается, будто поёт, голова плавно клонится из стороны в сторону, венец парит,
    фонарь качается на цепи и мерцает, левая рука медленно водит по воздуху."""
    p = stance()
    breath = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", x=0.015 * sway, z=-0.01 * (breath * 0.5 + 0.5))
    p.add("Spine", z=3 * sway, x=2 * breath)
    p.add("Chest", z=2 * wave(t, 1, -0.1))
    tilt = track(t, [(0, 12), (0.4, 12), (0.55, -10), (0.85, -10), (1, 12)])
    p.add("Head", z=tilt - 12, y=4 * wave(t, 1, 0.2))
    p.move("Crown", z=0.0)
    p.add("Crown", x=6 * wave(t, 1, 0.1), z=6 * wave(t, 1, 0.35))
    p.add("Chain", x=8 * wave(t, 1, 0.15), z=6 * wave(t, 1, -0.1))
    p.add("Lantern", x=6 * wave(t, 1, -0.05))
    p.size("Glow", 1.0 + 0.12 * wave(t, 5) + 0.2 * pulse(t, 0.62, 0.06))
    p.add("UpperArm.L", x=-8 * wave(t, 1, 0.3), z=6 * sway)
    p.add("Hand.L", x=10 * wave(t, 1, 0.4))
    robe(p, fwd=3 * wave(t, 1, -0.2), side=3 * wave(t, 1, 0.1))
    return p


def walk(t):
    """Ход (0.8 сек): скользит, сутулясь; ряса колышется, фонарь мотается, венец отстаёт."""
    p = stance()
    a = wave(t, 1)
    bounce = wave(t, 2, 0.1)
    p.move("Hips", z=-0.02 + 0.012 * bounce, x=0.015 * a)
    p.add("Hips", y=6 * a)
    p.set("Thigh.R", -24 * a, 0, 0)
    p.set("Thigh.L", 24 * a, 0, 0)
    p.set("Shin.R", 10 + 24 * max(0.0, wave(t, 1, 0.25)), 0, 0)
    p.set("Shin.L", 10 + 24 * max(0.0, -wave(t, 1, 0.25)), 0, 0)
    p.add("Spine", x=6)
    p.add("Head", x=-4 * bounce)
    p.add("UpperArm.L", x=-10 * a)
    p.add("Chain", x=16 + 8 * wave(t, 2, -0.15), z=6 * a)
    p.add("Lantern", x=10 * wave(t, 2, -0.3))
    p.add("Crown", x=-8 + 4 * wave(t, 2, -0.3))
    robe(p, fwd=10 + 8 * abs(a), side=8 * a)
    return p


def attack(t):
    """Луч из фонаря (0.8 сек): отводит посох к себе, фонарь гаснет → выбрасывает посох вперёд, фонарь взлетает
    на цепи и вспыхивает (к 0.4 сек) → свет угасает, возврат. Венец вспыхивает и подпрыгивает вместе со светом."""
    p = stance()
    K = [0.0, 0.25, 0.45, 0.62, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("UpperArm.R", x=tr([0, 20, -50, -40, 0]), z=tr([0, 10, -6, -4, 0]))
    p.add("ForeArm.R", x=tr([0, -30, 10, 4, 0]))
    p.add("Hand.R", x=tr([0, 10, -16, -10, 0]))
    p.add("UpperArm.L", x=tr([0, 20, -60, -50, 0]), z=tr([0, -10, 10, 6, 0]))
    p.add("Hand.L", x=tr([0, 20, -40, -30, 0]))
    p.add("Spine", x=tr([0, -14, 16, 10, 0]))
    p.add("Chest", x=tr([0, -8, 10, 6, 0]))
    p.add("Head", x=tr([0, -20, 10, 6, 0]), z=tr([0, -12, 0, 0, 0]))
    p.move("Root", y=tr([0, 0.05, -0.1, -0.08, 0]))
    p.add("Chain", x=tr([0, 20, -60, -40, 0]))
    p.add("Lantern", x=tr([0, 10, -30, -20, 0]))
    p.size("Glow", tr([1, 0.5, 2.6, 1.6, 1]))
    p.move("Crown", z=0.0)
    p.add("Crown", x=tr([0, -6, 4, 2, 0]))
    p.size("Crown", tr([1, 0.97, 1.08, 1.04, 1]))
    robe(p, fwd=tr([0, -10, 20, 14, 0]))
    return p


def hit(t):
    """Получил удар (0.47 сек): отшатнулся, голова запрокинута позже корпуса, фонарь мотается, венец сбился."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.34, 1), (0.56, -0.3), (0.8, 0.1), (1, 0)])
    p.move("Root", y=0.1 * snap)
    p.add("Spine", x=-20 * snap, y=10 * snap)
    p.add("Chest", x=-10 * snap)
    p.add("Head", x=-26 * whip, z=-14 * whip)
    p.add("UpperArm.L", x=30 * snap, z=-30 * snap)
    p.add("UpperArm.R", x=14 * snap)
    p.add("Chain", x=40 * whip, z=-20 * whip)
    p.add("Lantern", x=-20 * whip)
    p.add("Crown", x=-20 * whip, z=16 * whip)
    p.size("Glow", 1.0 - 0.4 * snap)
    robe(p, fwd=-20 * whip)
    return p


def death(t):
    """Гибель (1.3 сек): выронил посох, рухнул на колени, свет в фонаре гаснет, венец падает и тускнеет,
    тело заваливается вперёд и словно «сдувается» под рясой."""
    p = stance()
    K = [0.0, 0.2, 0.45, 0.72, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -16, 24, 40, 44]))
    p.add("Chest", x=tr([0, -10, 16, 24, 26]))
    p.add("Head", x=tr([0, -26, 30, 40, 40]), z=tr([0, 10, -6, -16, -16]))
    p.add("Thigh.L", x=tr([0, 0, -80, -70, -70]))
    p.add("Shin.L", x=tr([0, 0, 120, 110, 110]))
    p.add("Thigh.R", x=tr([0, 0, -86, -76, -76]))
    p.add("Shin.R", x=tr([0, 0, 126, 116, 116]))
    p.move("Hips", z=tr([-0.02, 0.0, -0.4, -0.5, -0.52]))
    p.move("Root", y=tr([0, 0.06, 0.0, -0.1, -0.12]))
    p.add("UpperArm.R", x=tr([0, 30, 60, 70, 70]), z=tr([0, 20, 30, 30, 30]))
    p.add("Weapon", x=tr([0, 0, -40, -70, -80]), z=tr([0, 10, 40, 60, 60]))
    p.add("Chain", x=tr([0, 30, 60, 50, 40]))
    p.size("Glow", tr([1, 1.4, 0.5, 0.1, 0.05]))
    p.move("Crown", z=0.0)
    p.add("Crown", x=tr([0, -30, 40, 80, 90]))
    p.size("Crown", tr([1, 1, 0.9, 0.8, 0.8]))
    p.add("UpperArm.L", x=tr([0, 20, -30, -40, -40]))
    spasm = pulse(t, 0.86, 0.05)
    p.add("Hand.L", x=-30 * spasm)
    robe(p, fwd=tr([0, -10, 30, 50, 54]), side=tr([0, 0, 10, 14, 14]))
    return p


def build_actions(rig):
    scaled = ("Glow", "Crown")
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=scaled)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=scaled)
    k.bake(rig, "Attack", 24, attack, scale_bones=scaled)
    k.bake(rig, "Hit", 14, hit, scale_bones=scaled)
    k.bake(rig, "Death", 40, death, scale_bones=scaled)


# ---------- Сборка и экспорт ----------

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
    glb = args[0] if args else os.path.join(here, "..", "cultist.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "cultist.blend")
    build(glb, blend)
