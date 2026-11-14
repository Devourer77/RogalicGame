# Хозяин трясины — уникальный дух топи (~1.5 м). Горб из чёрно-зелёной тины, наполовину ушедший в трясину:
# ни ног, ни туловища — только кочка, которая поднялась. Сверху и по бокам — мокрые коряги, две длинные
# руки-корни уходят вперёд и вниз в воду. На «голове» — венчик осоки и рогоза. Изнутри тины тлеет свет:
# бирюзовые трещины спереди, два бирюзовых огня под камышом.
# Облик — claude/мир.md, 5.1; референс Gemini утверждён 14 ноября.
# Смотрит в -Y (после экспорта в glTF это +Z).
#
# Анимации: Idle (горб дышит, камыш качается, корни шевелятся), Walk (тяжело переваливается),
# Attack (Хватка корней — корни взлетают и хлещут вперёд), Hit, Death (покорён: уходит в трясину).
# Запуск: python3 build_spirit_bog.py out/spirit_bog.glb out/spirit_bog.blend
import os
import sys
import math
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "SpiritBog"
HUMP_Z = 0.45
HEAD_Z = 0.92


def strand(name, pts, r0, r1, material, bone):
    """Корень или коряга по точкам, толщина от r0 к r1."""
    n = len(pts) - 1
    for i in range(n):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        k.limb(f"{name}_{i}", pts[i], pts[i + 1], ra, rb, material, bone, segs=5)


def build_mesh():
    rnd = random.Random(5)
    slime = k.mat("Bog_Slime", (0.12, 0.18, 0.15), rough=0.5, emit=0.02)
    slime_l = k.mat("Bog_SlimeLight", (0.19, 0.27, 0.21), rough=0.5)
    hollow = k.mat("Bog_Hollow", (0.04, 0.06, 0.05), rough=1.0)
    pool = k.mat("Bog_Pool", (0.09, 0.15, 0.14), rough=0.15, emit=0.02)
    pool_rim = k.mat("Bog_PoolRim", (0.16, 0.25, 0.23), rough=0.3)
    wood = k.mat("Bog_Wood", (0.42, 0.33, 0.24), rough=0.9)
    wood_d = k.mat("Bog_WoodDark", (0.30, 0.23, 0.17), rough=0.9)
    sedge = k.mat("Bog_Sedge", (0.55, 0.57, 0.30), rough=0.9)
    cattail = k.mat("Bog_Cattail", (0.45, 0.30, 0.18), rough=0.9)
    rift = k.mat("Bog_Rift", (0.30, 0.95, 0.85), rough=0.3, emit=1.4)
    eye = k.mat("Bog_Eye", (0.55, 1.0, 0.95), rough=0.3, emit=3.0)

    # Трясина вокруг (своя кость Pool — расходится, когда он уходит вниз)
    k.barrel("Pool", 0.56, 0.52, 0.0, 0.04, pool, "Pool", segs=11)
    k.barrel("PoolRim", 0.6, 0.57, 0.0, 0.02, pool_rim, "Pool", segs=11)

    # Горб: широкий бугор тины, сверху «голова»-навершие, спереди тёмная впадина
    k.sphere("Hump", 0.44, (0, 0.02, HUMP_Z), slime, "Hump", scale=(1.15, 0.95, 1.08), segs=10, rings=7)
    k.sphere("HumpBase", 0.5, (0, 0.03, 0.12), slime, "Hump", scale=(1.1, 0.95, 0.4), segs=10, rings=5)
    for i, (x, y, z, s) in enumerate([(-0.3, -0.25, 0.35, 0.12), (0.28, -0.22, 0.6, 0.1), (0.05, 0.35, 0.5, 0.14)]):
        k.sphere(f"Lump{i}", s, (x, y, z), slime_l, "Hump", scale=(1.2, 1.0, 0.8), segs=6, rings=4)
    k.sphere("HeadMass", 0.3, (0, 0.04, HEAD_Z - 0.06), slime, "Head", scale=(1.0, 0.9, 0.85), segs=9, rings=6)
    k.sphere("Hollow", 0.16, (0, -0.2, HEAD_Z - 0.08), hollow, "Head", scale=(1.15, 0.55, 0.8), segs=8, rings=5)
    for side in (-1, 1):
        k.sphere(f"Eye{side}", 0.024, (0.06 * side, -0.29, HEAD_Z - 0.05), eye, "Head",
                 scale=(1.2, 0.6, 0.8), segs=6, rings=3)
    # Бирюзовые трещины спереди горба (свет изнутри тины)
    for j, pts in enumerate([[(-0.05, 0.62), (0.02, 0.52), (-0.04, 0.42), (0.05, 0.32), (0.0, 0.22)],
                             [(0.02, 0.52), (0.13, 0.46), (0.17, 0.36)],
                             [(-0.04, 0.42), (-0.15, 0.37), (-0.2, 0.28)],
                             [(0.05, 0.32), (0.12, 0.24)]]):
        ps = []
        for x, z in pts:
            # точка на поверхности сплюснутого шара горба спереди
            dz = (z - HUMP_Z) / (0.44 * 1.08)
            rr = 0.44 * math.sqrt(max(0.0, 1 - dz * dz - (x / (0.44 * 1.15)) ** 2))
            ps.append((x, 0.02 - rr * 0.95 - 0.008, z))
        for n in range(len(ps) - 1):
            k.limb(f"Rift{j}_{n}", ps[n], ps[n + 1], 0.013, 0.012, rift, "Hump", segs=4)

    # Коряги поверх горба: арки через «плечи» и спину
    for i, side in enumerate((-1, 1)):
        strand(f"Drift{i}", [(0.12 * side, 0.15, HEAD_Z + 0.12), (0.3 * side, 0.05, 0.82),
                             (0.4 * side, -0.02, 0.55), (0.42 * side, 0.02, 0.25)], 0.05, 0.035, wood, "Hump")
        strand(f"DriftB{i}", [(0.05 * side, 0.25, HEAD_Z), (0.25 * side, 0.3, 0.6), (0.3 * side, 0.3, 0.2)],
               0.04, 0.03, wood_d, "Hump")
        strand(f"Brow{i}", [(0.02 * side, -0.24, HEAD_Z + 0.05), (0.2 * side, -0.2, HEAD_Z + 0.08),
                            (0.32 * side, -0.08, HEAD_Z - 0.04)], 0.035, 0.025, wood, "Head")

    # Руки-корни: от плеча наружу и вперёд, вниз в воду; у кисти — расходятся пальцами-корнями
    for side, pre in ((-1, "R"), (1, "L")):
        sh = (0.36 * side, -0.05, 0.78)
        el = (0.55 * side, -0.18, 0.52)
        hd = (0.48 * side, -0.32, 0.05)
        strand(f"Arm{pre}", [sh, (0.48 * side, -0.1, 0.7), el], 0.09, 0.07, wood, f"Arm{pre}")
        strand(f"ArmC{pre}", [(sh[0], sh[1] - 0.04, sh[2] + 0.03), (0.52 * side, -0.16, 0.72), el], 0.045, 0.035, wood, f"Arm{pre}")
        strand(f"ArmB{pre}", [(sh[0], sh[1] + 0.04, sh[2] - 0.04), (0.5 * side, -0.06, 0.66), el], 0.04, 0.035, wood_d, f"Arm{pre}")
        strand(f"Fore{pre}", [el, (0.54 * side, -0.26, 0.3), hd], 0.07, 0.055, wood, f"Fore{pre}")
        strand(f"ForeC{pre}", [el, (0.58 * side, -0.2, 0.28), (hd[0] + 0.05 * side, hd[1] + 0.02, hd[2])], 0.035, 0.03, wood, f"Fore{pre}")
        strand(f"ForeB{pre}", [el, (0.5 * side, -0.22, 0.3), (hd[0] - 0.06 * side, hd[1] + 0.03, hd[2])], 0.035, 0.03, wood_d, f"Fore{pre}")
        for j, (dx, dy) in enumerate(((-0.09, -0.08), (0.0, -0.13), (0.09, -0.07))):
            strand(f"Root{pre}{j}", [hd, (hd[0] + dx * 0.6, hd[1] + dy * 0.5, 0.03), (hd[0] + dx, hd[1] + dy, 0.0)],
                   0.03, 0.01, wood_d, f"Hand{pre}")

    # Венчик осоки и рогоза на голове (кость Reeds — качается с опозданием)
    for i in range(24):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0.05, 0.22)
        base_p = (math.cos(a) * rr, 0.06 + math.sin(a) * rr * 0.8, HEAD_Z + 0.12)
        tip = (base_p[0] * 2.2 + rnd.uniform(-0.05, 0.05), base_p[1] * 1.6 + rnd.uniform(-0.05, 0.05),
               HEAD_Z + rnd.uniform(0.32, 0.5))
        k.limb(f"Sedge{i}", base_p, tip, 0.035, 0.0, sedge, "Reeds", segs=3)
    for i, (x, y, h) in enumerate([(-0.12, 0.02, 0.58), (0.08, 0.12, 0.66), (0.17, -0.02, 0.52),
                                   (-0.04, 0.18, 0.62), (0.0, -0.06, 0.55)]):
        b0 = (x, y, HEAD_Z + 0.1)
        b1 = (x * 1.3, y * 1.2, HEAD_Z + h)
        k.limb(f"Stem{i}", b0, b1, 0.009, 0.007, sedge, "Reeds", segs=3)
        k.sphere(f"Cattail{i}", 0.032, (b1[0], b1[1], b1[2] - 0.06), cattail, "Reeds", scale=(1, 1, 2.6), segs=6, rings=4)
    return k.join_parts("SpiritBogMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Pool": ((0, 0, 0), (0, 0, 0.05), None),
    "Hump": ((0, 0, 0.05), (0, 0, HEAD_Z - 0.2), "Root"),
    "Head": ((0, 0, HEAD_Z - 0.2), (0, 0, HEAD_Z + 0.15), "Hump"),
    "Reeds": ((0, 0.05, HEAD_Z + 0.1), (0, 0.05, HEAD_Z + 0.5), "Head"),
    "ArmR": ((-0.36, -0.05, 0.78), (-0.55, -0.18, 0.52), "Hump"),
    "ForeR": ((-0.55, -0.18, 0.52), (-0.48, -0.32, 0.05), "ArmR"),
    "HandR": ((-0.48, -0.32, 0.05), (-0.48, -0.38, 0.0), "ForeR"),
    "ArmL": ((0.36, -0.05, 0.78), (0.55, -0.18, 0.52), "Hump"),
    "ForeL": ((0.55, -0.18, 0.52), (0.48, -0.32, 0.05), "ArmL"),
    "HandL": ((0.48, -0.32, 0.05), (0.48, -0.38, 0.0), "ForeL"),
}
SCALED = ("Hump", "Pool")


def base():
    p = Pose({}, {})
    p.add("Hump", x=6)
    p.add("Head", x=6, y=-6)
    p.add("ArmR", x=-4)
    p.add("ArmL", x=4, z=-4)
    return p


def idle(t):
    """Покой (3 сек): горб медленно вздымается (дышит тиной), голова поворачивается и замирает,
    корни шевелятся по отдельности, камыш качается с опозданием; один раз пальцы-корни сжимаются."""
    p = base()
    b = wave(t, 1)
    p.size("Hump", 1 + 0.025 * b, 1 + 0.025 * b, 1 + 0.035 * b)
    p.move("Root", z=0.015 * b)
    look = track(t, [(0, 0), (0.25, 0), (0.32, 16), (0.6, 16), (0.67, -12), (0.88, -12), (1, 0)])
    p.add("Head", y=look, x=3 * wave(t, 1, 0.2))
    p.add("Reeds", x=5 * wave(t, 1, -0.15), z=6 * wave(t, 2, 0.1) - look * 0.2)
    p.add("ArmR", x=-4 * wave(t, 1, 0.3), z=3 * wave(t, 1, 0.6))
    p.add("ArmL", x=-4 * wave(t, 1, 0.8), z=-3 * wave(t, 1, 0.1))
    grip = pulse(t, 0.45, 0.08)
    p.add("ForeR", x=-6 * wave(t, 1, 0.5) - 12 * grip)
    p.add("ForeL", x=-6 * wave(t, 1, 0.9))
    p.add("HandR", x=-25 * grip)
    p.size("Pool", 1 + 0.02 * wave(t, 2, 0.4))
    return p


def walk(t):
    """Переваливается (1 сек): горб кренится с боку на бок, приподнимается и плюхается, руки-корни
    по очереди загребают вперёд."""
    p = base()
    s = wave(t, 1)
    p.add("Hump", x=10, z=7 * s)
    p.move("Root", z=0.04 * abs(wave(t, 1)))
    p.add("Head", z=-5 * s, x=-4)
    p.add("Reeds", z=-8 * wave(t, 1, -0.15))
    p.add("ArmR", x=-20 * max(0.0, s) + 6)
    p.add("ArmL", x=-20 * max(0.0, -s) + 6)
    p.add("ForeR", x=-10 * max(0.0, s))
    p.add("ForeL", x=-10 * max(0.0, -s))
    p.size("Pool", 1 + 0.04 * wave(t, 2))
    return p


def attack(t):
    """Хватка корней (0.9 сек): горб откидывается, руки-корни взлетают → хлещут вперёд и вниз (около 0.4 сек),
    корни-пальцы впиваются → медленно отпускает."""
    p = base()
    K = [0.0, 0.3, 0.44, 0.62, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Hump", x=tr([0, -10, 16, 12, 0]))
    p.add("Head", x=tr([0, -10, 12, 8, 0]))
    p.add("Reeds", x=tr([0, 10, -14, -6, 0]))
    swing = tr([0, 25, -65, -55, 0])
    p.add("ArmR", x=swing, z=tr([0, 35, 6, 6, 0]))
    p.add("ArmL", x=swing, z=tr([0, -35, -6, -6, 0]))
    p.add("ForeR", x=tr([0, -40, -10, -20, 0]))
    p.add("ForeL", x=tr([0, -40, -10, -20, 0]))
    p.add("HandR", x=tr([0, 10, -30, -40, 0]))
    p.add("HandL", x=tr([0, 10, -30, -40, 0]))
    p.size("Hump", 1.0, 1.0, tr([1, 1.06, 0.94, 0.97, 1]))
    return p


def hit(t):
    """Получил удар (0.47 сек): горб вминается и откидывается, голова и камыш мотаются с опозданием."""
    p = base()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.25, 0.3), (0.4, 1), (0.62, -0.4), (0.85, 0.1), (1, 0)])
    p.add("Hump", x=-10 * snap, z=5 * snap)
    p.size("Hump", 1 + 0.05 * snap, 1 + 0.05 * snap, 1 - 0.08 * snap)
    p.add("Head", x=-16 * whip, z=-8 * whip)
    p.add("Reeds", x=-20 * whip)
    p.add("ArmR", x=12 * whip, z=8 * whip)
    p.add("ArmL", x=12 * whip, z=-8 * whip)
    return p


def death(t):
    """Покорён (1.6 сек): горб вздрагивает, руки-корни опадают в воду, кочка медленно уходит в трясину,
    последним скрывается камыш; трясина расходится шире и на миг пузырится."""
    p = base()
    K = [0.0, 0.15, 0.4, 0.75, 0.92, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Hump", x=tr([0, -12, 10, 16, 16, 16]))
    p.add("Head", x=tr([0, -18, 14, 20, 20, 20]))
    p.add("Reeds", x=tr([0, 15, -10, 8, 10, 10]))
    p.add("ArmR", x=tr([0, -20, 10, 25, 26, 26]), z=tr([0, 10, 20, 26, 26, 26]))
    p.add("ArmL", x=tr([0, -20, 10, 25, 26, 26]), z=tr([0, -10, -20, -26, -26, -26]))
    p.move("Root", z=tr([0, 0.04, -0.3, -1.05, -1.4, -1.45]))
    p.size("Pool", tr([1, 1.02, 1.15, 1.35, 1.4, 1.4]) + 0.05 * pulse(t, 0.95, 0.04))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 30, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 27, attack, scale_bones=SCALED)
    k.bake(rig, "Hit", 14, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 48, death, scale_bones=SCALED)


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
    glb = args[0] if args else os.path.join(here, "..", "spirit_bog.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "spirit_bog.blend")
    build(glb, blend)
