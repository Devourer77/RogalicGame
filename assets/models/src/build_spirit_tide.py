# Омутник — одичавший дух воды (~1.3 м). Фигура из тёмной воды по пояс, ниже растекается лужей — ног нет.
# Длинные руки-струи до земли, у ладоней вода плещется по плитам. Голова — вытянутая капля без лица,
# два бледных бирюзовых огня вместо глаз, внутри воды — бирюзовые трещины-прожилки Раскола.
# Облик — claude/мир.md, раздел 5.1; референс Gemini утверждён 14 ноября.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Анимации: Idle, Walk (скользит, лужа тянется следом), Attack (Струя — хлёст правой рукой вперёд),
# Attack2 (Водяные руки — обе руки тянутся вперёд и рывком тащат к себе), Hit, Death (покорён: оседает в лужу).
# Запуск: python3 build_spirit_tide.py out/spirit_tide.glb out/spirit_tide.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "SpiritTide"
WAIST = 0.5       # где тело выходит из лужи и сужается к поясу
SHOULDER = 0.86
HEAD = 1.02


def build_mesh():
    # Вода — глянцевая (низкая шероховатость, лёгкий металл даёт блики) и идёт полосами от тёмной
    # глубины у лужи к светлой поверхности у плеч: так однотонные материалы читаются как толща воды.
    abyss = k.mat("Tide_Abyss", (0.07, 0.14, 0.2), metallic=0.1, rough=0.15, emit=0.02)
    deep = k.mat("Tide_Deep", (0.11, 0.21, 0.29), metallic=0.1, rough=0.12, emit=0.03)
    water = k.mat("Tide_Water", (0.17, 0.31, 0.41), metallic=0.1, rough=0.1, emit=0.04)
    shallow = k.mat("Tide_Shallow", (0.29, 0.49, 0.6), metallic=0.08, rough=0.1, emit=0.06)
    foam = k.mat("Tide_Foam", (0.6, 0.8, 0.86), rough=0.3, emit=0.1)
    film = k.mat("Tide_Film", (0.34, 0.6, 0.72), metallic=0.1, rough=0.05, emit=0.05, alpha=0.42)
    puddle = k.mat("Tide_Puddle", (0.12, 0.23, 0.31), metallic=0.15, rough=0.06, emit=0.03)
    rift = k.mat("Tide_Rift", (0.30, 0.95, 0.85), rough=0.3, emit=1.4)
    core = k.mat("Tide_Core", (0.42, 1.0, 0.9), rough=0.3, emit=2.2)
    eye = k.mat("Tide_Eye", (0.55, 1.0, 0.95), rough=0.3, emit=3.0)

    # --- Лужа: гладкое зеркало, кольцо мелкой воды, пенный край, рябь кольцами и брызги по краю ---
    k.barrel("Puddle", 0.54, 0.5, 0.0, 0.03, puddle, "Puddle", segs=14)
    k.barrel("PuddleInner", 0.4, 0.36, 0.0, 0.034, deep, "Puddle", segs=10)
    k.barrel("PuddleRim", 0.58, 0.55, 0.0, 0.016, foam, "Puddle", segs=14)
    for ring, (rad, n, s) in enumerate([(0.47, 9, 0.05), (0.31, 6, 0.04)]):
        for i in range(n):
            a = 2 * math.pi * (i + 0.5 * ring) / n
            k.box(f"Ripple{ring}_{i}", (s * 0.35, s * 2.4, 0.008), (rad * math.cos(a), rad * math.sin(a), 0.033), water,
                  "Puddle", rot=(0, 0, math.degrees(a)))
    for i, (a, h) in enumerate([(20, 0.09), (75, 0.06), (140, 0.1), (200, 0.07), (255, 0.08), (320, 0.06)]):
        r = math.radians(a)
        base_p = (0.53 * math.cos(r), 0.53 * math.sin(r), 0.01)
        tip = (0.6 * math.cos(r), 0.6 * math.sin(r), h)
        k.limb(f"Spray{i}", base_p, tip, 0.018, 0.0, shallow, "Puddle", segs=4)

    # --- Тело: поток из лужи — полосы от бездны внизу к светлой воде, сужение к поясу ---
    body = [(0.02, 0.37, abyss), (0.1, 0.3, deep), (0.22, 0.23, deep), (0.36, 0.18, water), (WAIST, 0.16, None)]
    for i in range(len(body) - 1):
        z0, r0, m = body[i]
        z1, r1, _ = body[i + 1]
        k.barrel(f"Skirt{i}", r0, r1, z0, z1, m, "Body", segs=10, sy=0.85)
    # Пенный воротник там, где тело выходит из лужи
    for i in range(7):
        a = 2 * math.pi * i / 7
        k.sphere(f"WaistFoam{i}", 0.065, (0.33 * math.sin(a), -0.29 * math.cos(a), 0.06), foam, "Body",
                 scale=(1.5, 0.8, 0.5), rot=(0, 0, -math.degrees(a)), segs=4, rings=2)

    # Торс: тёмная вода внутри, светящееся сердце Раскола, сверху — прозрачная плёнка поверхности
    k.barrel("TorsoLow", 0.15, 0.2, WAIST - 0.03, 0.66, water, "Chest", segs=10, sy=0.7)
    k.barrel("TorsoHigh", 0.2, 0.235, 0.66, SHOULDER - 0.04, shallow, "Chest", segs=10, sy=0.7)
    k.sphere("Core", 0.055, (0.0, -0.13, 0.68), core, "Chest", scale=(1.0, 0.6, 1.2), segs=6, rings=4)
    k.barrel("TorsoFilm", 0.19, 0.27, WAIST - 0.01, SHOULDER - 0.02, film, "Chest", segs=10, sy=0.78)
    k.barrel("Shoulders", 0.26, 0.13, SHOULDER - 0.05, SHOULDER + 0.05, shallow, "Chest", segs=10, sy=0.72)
    # Гребень волны с плеч: пенные «языки», загнутые назад
    for i, (x, h, lean) in enumerate([(-0.17, 0.13, -15), (-0.07, 0.17, -5), (0.05, 0.16, 6), (0.16, 0.12, 15)]):
        mid = (x * 1.08, 0.12, SHOULDER + h * 0.65)
        k.limb(f"Crest{i}", (x, 0.04, SHOULDER), mid, 0.05, 0.03, shallow, "Chest", segs=5)
        k.limb(f"CrestTip{i}", mid, (x * 1.12, 0.21, SHOULDER + h * 0.8), 0.03, 0.0, foam, "Chest", segs=5)
    k.limb("Neck", (0, 0.0, SHOULDER + 0.03), (0, -0.01, HEAD - 0.06), 0.085, 0.07, water, "Chest", segs=8)
    # Капли, висящие в воздухе у плеч
    for i, (x, y, z) in enumerate([(-0.33, -0.05, 0.98), (0.31, 0.02, 1.04), (-0.2, 0.12, 1.12), (0.12, -0.16, 1.2)]):
        k.sphere(f"Drop{i}", 0.022, (x, y, z), shallow, "Chest", scale=(1, 1, 1.5), segs=6, rings=4)

    # --- Голова-капля: круглый низ, верхушка загибается назад гребнем и разбрызгивается ---
    k.sphere("HeadBulb", 0.135, (0, -0.01, HEAD), water, "Head", scale=(0.9, 0.85, 1.0), segs=9, rings=5)
    # верхушка — одна и та же вода, без «полос», чтобы не читалась шляпой; загиб назад
    k.limb("HeadTip", (0, -0.005, HEAD + 0.03), (0, 0.04, HEAD + 0.19), 0.118, 0.07, water, "Head", segs=9)
    k.sphere("HeadTipJoint", 0.07, (0, 0.04, HEAD + 0.19), water, "Head", segs=8, rings=4)
    k.limb("HeadTip2", (0, 0.04, HEAD + 0.19), (0, 0.13, HEAD + 0.28), 0.07, 0.035, water, "Head", segs=8)
    k.limb("HeadTip3", (0, 0.13, HEAD + 0.28), (0, 0.23, HEAD + 0.27), 0.035, 0.0, shallow, "Head", segs=6)
    for side in (-1, 1):
        k.limb(f"HeadSpray{side}", (0.0, 0.18, HEAD + 0.28), (0.06 * side, 0.25, HEAD + 0.33), 0.012, 0.0, foam, "Head", segs=4)
    k.limb("HeadHi", (0.045, -0.085, HEAD + 0.06), (0.035, -0.035, HEAD + 0.17), 0.013, 0.005, shallow, "Head", segs=4)
    for side in (-1, 1):
        k.sphere(f"Eye{side}", 0.024, (0.046 * side, -0.11, HEAD + 0.01), eye, "Head", scale=(1.3, 0.6, 0.8), segs=6, rings=3)

    # --- Руки-струи: плечо → локоть → кисть у земли; пенная спираль, стекающие капли, всплеск-корона ---
    for side, pre in ((-1, "R"), (1, "L")):
        sh = (0.22 * side, 0.0, SHOULDER - 0.02)
        el = (0.34 * side, -0.04, 0.5)
        hd = (0.38 * side, -0.07, 0.1)
        k.sphere(f"ShoulderBall{pre}", 0.085, sh, shallow, f"Arm{pre}", segs=6, rings=3)
        k.limb(f"Arm{pre}", sh, el, 0.08, 0.06, water, f"Arm{pre}", segs=8)
        k.sphere(f"Elbow{pre}", 0.064, el, water, f"Fore{pre}", segs=6, rings=4)
        k.limb(f"Fore{pre}", el, hd, 0.06, 0.08, deep, f"Fore{pre}", segs=8)
        # пенная полоса, обвивающая предплечье
        for j in range(3):
            f0 = j / 3.0
            f1 = (j + 0.8) / 3.0
            a0 = math.radians(120 * j)
            a1 = math.radians(120 * j + 90)
            p0 = tuple(el[n] + (hd[n] - el[n]) * f0 for n in range(3))
            p1 = tuple(el[n] + (hd[n] - el[n]) * f1 for n in range(3))
            r = 0.068
            k.limb(f"Swirl{pre}{j}", (p0[0] + r * math.cos(a0), p0[1] + r * math.sin(a0), p0[2]),
                   (p1[0] + r * math.cos(a1), p1[1] + r * math.sin(a1), p1[2]), 0.014, 0.01, foam, f"Fore{pre}", segs=4)
        # капли, отрывающиеся снизу руки
        for j, f in enumerate((0.35, 0.7)):
            p = tuple(el[n] + (hd[n] - el[n]) * f for n in range(3))
            k.sphere(f"Drip{pre}{j}", 0.02, (p[0] + 0.07 * side, p[1] - 0.02, p[2] - 0.04), shallow, f"Fore{pre}",
                     scale=(1, 1, 1.7), segs=4, rings=3)
        # всплеск у ладони: плоский пенный диск и корона струй
        k.limb(f"Splash{pre}", (hd[0], hd[1], hd[2] + 0.04), (hd[0], hd[1] - 0.02, 0.0), 0.065, 0.15, shallow, f"Hand{pre}", segs=9)
        k.barrel(f"SplashFoam{pre}", 0.16, 0.12, 0.0, 0.02, foam, f"Hand{pre}", segs=7, loc=(hd[0], hd[1] - 0.02))
        for j in range(3):
            a = math.radians(-90 + 120 * j + 30 * side)
            b = (hd[0] + 0.12 * math.cos(a), hd[1] - 0.02 + 0.12 * math.sin(a), 0.01)
            tip = (hd[0] + 0.2 * math.cos(a), hd[1] - 0.02 + 0.2 * math.sin(a), 0.08 + 0.03 * (j % 2))
            k.limb(f"Crown{pre}{j}", b, tip, 0.022, 0.0, foam if j % 2 else shallow, f"Hand{pre}", segs=4)
        for j, dx in enumerate((-0.05, 0.05)):
            k.limb(f"Finger{pre}{j}", (hd[0], hd[1] - 0.02, hd[2]),
                   (hd[0] + dx, hd[1] - 0.14, 0.01), 0.026, 0.006, water, f"Hand{pre}", segs=5)

    # --- Трещины Раскола внутри воды: грудь (сходятся к сердцу), юбка, руки, затылок ---
    def surf(r_bottom, r_top, z0, z1, z, ang, sy):
        r = r_bottom + (r_top - r_bottom) * (z - z0) / (z1 - z0)
        a = math.radians(ang)
        return (r * math.sin(a), -r * math.cos(a) * sy - 0.006, z)

    veins = [
        ("Body", 0.33, 0.16, 0.02, WAIST, 0.85, [(0.08, -10), (0.2, 6), (0.32, -4), (0.44, 10)]),
        ("Body", 0.33, 0.16, 0.02, WAIST, 0.85, [(0.12, 25), (0.24, 34), (0.36, 22)]),
        ("Body", 0.33, 0.16, 0.02, WAIST, 0.85, [(0.1, -38), (0.22, -28), (0.3, -40)]),
        ("Chest", 0.15, 0.235, WAIST - 0.03, SHOULDER - 0.04, 0.7, [(0.52, 8), (0.6, -4), (0.66, 0)]),
        ("Chest", 0.15, 0.235, WAIST - 0.03, SHOULDER - 0.04, 0.7, [(0.7, 0), (0.76, -14), (0.8, -26)]),
        ("Chest", 0.15, 0.235, WAIST - 0.03, SHOULDER - 0.04, 0.7, [(0.7, 4), (0.75, 18), (0.81, 22)]),
        ("Body", 0.33, 0.16, 0.02, WAIST, 0.85, [(0.1, 170), (0.26, 185), (0.4, 175)]),
    ]
    for i, (bone, rb, rt, z0, z1, sy, pts) in enumerate(veins):
        ps = [surf(rb, rt, z0, z1, z, a, sy) for z, a in pts]
        for n in range(len(ps) - 1):
            k.limb(f"Vein{i}_{n}", ps[n], ps[n + 1], 0.011, 0.011, rift, bone, segs=3)
    for side, pre in ((-1, "R"), (1, "L")):
        k.limb(f"ArmVein{pre}", (0.3 * side, -0.07, 0.68), (0.36 * side, -0.09, 0.42), 0.009, 0.007, rift, f"Arm{pre}", segs=3)
    k.limb("HeadVein", (0.06, 0.07, HEAD + 0.02), (0.02, 0.1, HEAD + 0.17), 0.009, 0.006, rift, "Head", segs=3)
    return k.join_parts("SpiritTideMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Puddle": ((0, 0, 0.0), (0, 0, 0.05), None),
    "Body": ((0, 0, 0.02), (0, 0, WAIST), "Root"),
    "Chest": ((0, 0, WAIST), (0, 0, SHOULDER), "Body"),
    "Head": ((0, 0, HEAD - 0.08), (0, 0, HEAD + 0.3), "Chest"),
    "ArmR": ((-0.22, 0, SHOULDER - 0.02), (-0.34, -0.04, 0.5), "Chest"),
    "ForeR": ((-0.34, -0.04, 0.5), (-0.38, -0.07, 0.1), "ArmR"),
    "HandR": ((-0.38, -0.07, 0.1), (-0.38, -0.09, 0.0), "ForeR"),
    "ArmL": ((0.22, 0, SHOULDER - 0.02), (0.34, -0.04, 0.5), "Chest"),
    "ForeL": ((0.34, -0.04, 0.5), (0.38, -0.07, 0.1), "ArmL"),
    "HandL": ((0.38, -0.07, 0.1), (0.38, -0.09, 0.0), "ForeL"),
}
SCALED = ("Puddle", "Body", "Chest", "ForeR", "ForeL", "HandR", "HandL")


def base():
    """Стойка: сгорблен вперёд, голова опущена и чуть повёрнута, левая рука ближе к телу, правая отведена."""
    p = Pose({}, {})
    p.add("Body", x=6, z=-3)
    p.add("Chest", x=10, y=6)
    p.add("Head", x=8, y=-10, z=4)
    p.add("ArmR", x=-6, z=8)
    p.add("ForeR", x=-6)
    p.add("ArmL", x=4, z=-4)
    p.add("ForeL", x=-10)
    return p


def idle(t):
    """Покой (3 сек): вода «дышит» волнами снизу вверх, руки-струи покачиваются не в такт,
    голова резко поворачивается и замирает; посередине — правая рука нехотя поднимается, как в замахе."""
    p = base()
    b = wave(t, 1)
    p.size("Body", 1 + 0.03 * b, 1 + 0.03 * b, 1 - 0.025 * b)
    p.size("Chest", 1 + 0.03 * wave(t, 1, -0.15), 1.0, 1 + 0.02 * wave(t, 1, -0.15))
    p.size("Puddle", 1 + 0.04 * wave(t, 2, 0.1), 1 + 0.04 * wave(t, 2, 0.35), 1.0)
    p.add("Body", z=3 * wave(t, 1, 0.25), x=2 * wave(t, 2))
    p.add("Chest", z=-3 * wave(t, 1, 0.1), x=2 * wave(t, 2, 0.2))
    look = track(t, [(0, 0), (0.18, 0), (0.24, 22), (0.5, 22), (0.56, -14), (0.8, -14), (0.88, 0), (1, 0)])
    p.add("Head", y=look, x=3 * wave(t, 2, 0.4))
    lift = pulse(t, 0.5, 0.18)
    p.add("ArmR", x=-6 * wave(t, 1, 0.3) - 30 * lift, z=4 * wave(t, 1, 0.55))
    p.add("ForeR", x=-5 * wave(t, 1, 0.45) - 30 * lift)
    p.add("ArmL", x=5 * wave(t, 1, 0.75), z=-3 * wave(t, 1, 0.1))
    p.add("ForeL", x=-4 * wave(t, 1, 0.9))
    p.size("HandR", 1 + 0.1 * wave(t, 2, 0.2) - 0.3 * lift)
    p.size("HandL", 1 + 0.1 * wave(t, 2, 0.6))
    return p


def walk(t):
    """Скользит (0.8 сек): корпус наклонён вперёд и раскачивается, руки волочатся следом в противофазе,
    лужа тянется назад и рябит."""
    p = base()
    s = wave(t, 1)
    p.add("Body", x=10 + 2 * wave(t, 2), z=5 * s)
    p.add("Chest", x=4, z=-4 * s, y=-5 * s)
    p.add("Head", x=-6, z=3 * wave(t, 1, -0.15))
    p.add("ArmR", x=18 + 8 * s, z=6)
    p.add("ArmL", x=18 - 8 * s, z=-4)
    p.add("ForeR", x=8 + 6 * wave(t, 1, -0.2))
    p.add("ForeL", x=8 - 6 * wave(t, 1, -0.2))
    p.size("Puddle", 1 + 0.06 * wave(t, 2), 1.18 + 0.05 * wave(t, 2, 0.3), 1.0)
    p.move("Root", z=0.015 * abs(wave(t, 1)))
    p.size("Body", 1.0, 1.0, 1 - 0.03 * wave(t, 2, 0.25))
    return p


def attack(t):
    """Струя (0.8 сек): правая рука уходит назад, корпус скручивается → хлёст вперёд (удар около 0.4 сек),
    кисть вытягивается в длинную струю → рука опадает обратно."""
    p = base()
    K = [0.0, 0.3, 0.45, 0.6, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Body", x=tr([0, -6, 10, 8, 0]), z=tr([0, 4, -4, -2, 0]))
    p.add("Chest", y=tr([0, 24, -26, -18, 0]), x=tr([0, -10, 12, 8, 0]))
    p.add("Head", x=tr([0, -6, 6, 4, 0]), y=tr([0, -10, 14, 8, 0]))
    p.add("ArmR", x=tr([0, 40, -95, -80, 0]), z=tr([0, 25, 10, 12, 0]))
    p.add("ForeR", x=tr([0, -20, -15, -10, 0]))
    p.size("ForeR", 1.0, tr([1, 0.9, 1.7, 1.4, 1]), 1.0)
    p.size("HandR", tr([1, 0.9, 1.25, 1.15, 1]))
    p.add("ArmL", x=tr([0, -12, 20, 14, 0]), z=tr([0, -6, -10, -8, 0]))
    p.size("Body", 1.0, 1.0, tr([1, 0.94, 1.06, 1.03, 1]))
    return p


def attack2(t):
    """Водяные руки (0.9 сек): обе руки тянутся вперёд и вверх (удар около 0.4 сек), хватают
    и рывком тащат к себе, корпус откидывается назад."""
    p = base()
    K = [0.0, 0.2, 0.42, 0.62, 0.8, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    reach = tr([0, -40, -95, -60, -20, 0])
    p.add("ArmR", x=reach, z=tr([0, 6, -6, 4, 6, 0]))
    p.add("ArmL", x=reach, z=tr([0, -6, 6, -4, -6, 0]))
    p.add("ForeR", x=tr([0, -10, -5, -40, -20, 0]))
    p.add("ForeL", x=tr([0, -10, -5, -40, -20, 0]))
    stretch = tr([1, 1.1, 1.5, 0.85, 0.95, 1])
    p.size("ForeR", 1.0, stretch, 1.0)
    p.size("ForeL", 1.0, stretch, 1.0)
    grab = tr([1, 1.05, 1.3, 0.85, 0.95, 1])
    p.size("HandR", grab)
    p.size("HandL", grab)
    p.add("Body", x=tr([0, 6, 14, -8, -4, 0]))
    p.add("Chest", x=tr([0, 6, 12, -10, -4, 0]))
    p.add("Head", x=tr([0, 0, -8, 8, 4, 0]))
    p.size("Puddle", tr([1, 1.04, 1.1, 0.96, 1, 1]))
    return p


def hit(t):
    """Получил удар (0.47 сек): вода плещется назад сразу, голова и руки мотаются с опозданием."""
    p = base()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.38, 1), (0.6, -0.4), (0.82, 0.1), (1, 0)])
    p.add("Body", x=-12 * snap, z=6 * snap)
    p.add("Chest", x=-14 * snap)
    p.add("Head", x=-22 * whip, z=-10 * whip)
    p.add("ArmR", x=14 * whip, z=10 * whip)
    p.add("ArmL", x=14 * whip, z=-10 * whip)
    p.size("Body", 1 + 0.08 * snap, 1 + 0.08 * snap, 1 - 0.1 * snap)
    p.size("Puddle", 1 + 0.12 * snap)
    return p


def death(t):
    """Покорён (1.4 сек): дух вздрагивает, руки бессильно падают вперёд, тело оседает и уходит в лужу,
    лужа растекается шире; в конце — короткая дрожь воды."""
    p = base()
    K = [0.0, 0.15, 0.4, 0.7, 0.9, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Body", x=tr([0, -10, 12, 20, 22, 22]))
    p.add("Chest", x=tr([0, -18, 14, 24, 25, 25]))
    p.add("Head", x=tr([0, -25, 20, 30, 30, 30]))
    p.add("ArmR", x=tr([0, 15, -25, -35, -36, -36]), z=tr([0, 10, 12, 14, 14, 14]))
    p.add("ArmL", x=tr([0, 15, -25, -35, -36, -36]), z=tr([0, -10, -12, -14, -14, -14]))
    p.add("ForeR", x=tr([0, 0, 20, 40, 42, 42]))
    p.add("ForeL", x=tr([0, 0, 20, 40, 42, 42]))
    p.move("Root", z=tr([0, 0.03, -0.25, -0.75, -0.95, -0.98]))
    p.size("Body", 1.0, 1.0, tr([1, 1.04, 0.85, 0.7, 0.65, 0.65]))
    p.size("Chest", tr([1, 1, 0.9, 0.6, 0.4, 0.4]))   # гребень и плечи тоже уходят под воду, не торчат из лужи
    p.size("Puddle", tr([1, 1.02, 1.2, 1.45, 1.55, 1.55]))
    shiver = pulse(t, 0.93, 0.05)
    p.size("Puddle", tr([1, 1.02, 1.2, 1.45, 1.55, 1.55]) + 0.06 * shiver)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, scale_bones=SCALED)
    k.bake(rig, "Attack2", 27, attack2, scale_bones=SCALED)
    k.bake(rig, "Hit", 14, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 42, death, scale_bones=SCALED)


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
    glb = args[0] if args else os.path.join(here, "..", "spirit_tide.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "spirit_tide.blend")
    build(glb, blend)
