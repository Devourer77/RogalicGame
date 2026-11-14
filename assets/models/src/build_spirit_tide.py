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
    water = k.mat("Tide_Water", (0.17, 0.29, 0.37), rough=0.35, emit=0.04)
    deep = k.mat("Tide_Deep", (0.11, 0.20, 0.27), rough=0.35, emit=0.03)
    light = k.mat("Tide_Light", (0.36, 0.54, 0.64), rough=0.25, emit=0.08)
    puddle = k.mat("Tide_Puddle", (0.14, 0.25, 0.32), rough=0.2, emit=0.03)
    rift = k.mat("Tide_Rift", (0.30, 0.95, 0.85), rough=0.3, emit=1.4)
    eye = k.mat("Tide_Eye", (0.55, 1.0, 0.95), rough=0.3, emit=3.0)

    # Лужа: плоский гранёный диск и светлый край-рябь (кость Puddle — растекается и дрожит)
    k.barrel("Puddle", 0.52, 0.47, 0.0, 0.035, puddle, "Puddle", segs=12)
    k.barrel("PuddleRim", 0.56, 0.53, 0.0, 0.018, light, "Puddle", segs=12)
    for i, (x, y, s) in enumerate([(0.3, 0.22, 0.09), (-0.34, 0.12, 0.07), (0.1, -0.38, 0.08), (-0.18, -0.3, 0.06)]):
        k.sphere(f"Ripple{i}", s, (x, y, 0.035), light, "Puddle", scale=(1.6, 1.0, 0.18), segs=6, rings=3)

    # Тело: юбка воды от лужи до пояса (тёмная, широкая внизу) и торс до плеч
    k.barrel("Skirt", 0.33, 0.16, 0.02, WAIST, deep, "Body", segs=9, sy=0.85)
    k.barrel("SkirtFlow", 0.38, 0.3, 0.02, 0.14, water, "Body", segs=9, sy=0.9)
    k.barrel("Torso", 0.16, 0.24, WAIST - 0.02, SHOULDER - 0.04, water, "Chest", segs=8, sy=0.7)
    k.barrel("Shoulders", 0.24, 0.12, SHOULDER - 0.05, SHOULDER + 0.05, light, "Chest", segs=8, sy=0.7)
    k.limb("Neck", (0, 0.0, SHOULDER + 0.03), (0, -0.01, HEAD - 0.06), 0.085, 0.07, water, "Chest", segs=6)

    # Голова-капля: круглый низ, вытянутая вверх и чуть назад верхушка; без лица, два огня-глаза
    k.sphere("HeadBulb", 0.13, (0, -0.01, HEAD), water, "Head", scale=(0.9, 0.85, 1.05), segs=8, rings=5)
    k.limb("HeadTip", (0, 0.0, HEAD + 0.05), (0, 0.035, HEAD + 0.2), 0.108, 0.06, water, "Head", segs=7)
    k.limb("HeadTip2", (0, 0.035, HEAD + 0.2), (0, 0.08, HEAD + 0.3), 0.06, 0.0, water, "Head", segs=7)
    k.limb("HeadHi", (0.03, -0.06, HEAD + 0.06), (0.02, 0.0, HEAD + 0.22), 0.018, 0.008, light, "Head", segs=4)
    for side in (-1, 1):
        k.sphere(f"Eye{side}", 0.022, (0.045 * side, -0.11, HEAD + 0.01), eye, "Head", scale=(1.3, 0.6, 0.8), segs=6, rings=3)

    # Руки-струи: плечо → локоть → кисть у земли, кисть растекается всплеском
    for side, pre in ((-1, "R"), (1, "L")):
        sh = (0.22 * side, 0.0, SHOULDER - 0.02)
        el = (0.34 * side, -0.04, 0.5)
        hd = (0.38 * side, -0.07, 0.1)
        k.limb(f"Arm{pre}", sh, el, 0.075, 0.06, water, f"Arm{pre}", segs=6)
        k.limb(f"Fore{pre}", el, hd, 0.06, 0.075, water, f"Fore{pre}", segs=6)
        k.limb(f"ForeHi{pre}", (el[0] - 0.02 * side, el[1] - 0.04, el[2] - 0.02),
               (hd[0] - 0.01 * side, hd[1] - 0.06, hd[2] + 0.08), 0.02, 0.015, light, f"Fore{pre}", segs=4)
        # Всплеск у ладони: широкий плоский конус и пара «пальцев»-струй
        k.limb(f"Splash{pre}", (hd[0], hd[1], hd[2] + 0.04), (hd[0], hd[1] - 0.02, 0.0), 0.06, 0.14, light, f"Hand{pre}", segs=7)
        for j, dx in enumerate((-0.05, 0.05)):
            k.limb(f"Finger{pre}{j}", (hd[0], hd[1] - 0.02, hd[2]),
                   (hd[0] + dx, hd[1] - 0.13, 0.01), 0.025, 0.006, water, f"Hand{pre}", segs=4)

    # Трещины Раскола внутри воды: по груди и юбке спереди, немного сзади
    def surf(r_bottom, r_top, z0, z1, z, ang, sy):
        r = r_bottom + (r_top - r_bottom) * (z - z0) / (z1 - z0)
        a = math.radians(ang)
        return (r * math.sin(a), -r * math.cos(a) * sy - 0.006, z)

    veins = [
        ("Body", 0.33, 0.16, 0.02, WAIST, 0.85, [(0.08, -10), (0.2, 6), (0.32, -4), (0.44, 10)]),
        ("Body", 0.33, 0.16, 0.02, WAIST, 0.85, [(0.12, 25), (0.24, 34), (0.36, 22)]),
        ("Body", 0.33, 0.16, 0.02, WAIST, 0.85, [(0.1, -38), (0.22, -28), (0.3, -40)]),
        ("Chest", 0.16, 0.24, WAIST - 0.02, SHOULDER - 0.04, 0.7, [(0.52, 8), (0.62, -6), (0.72, 4), (0.8, 18)]),
        ("Chest", 0.16, 0.24, WAIST - 0.02, SHOULDER - 0.04, 0.7, [(0.64, -6), (0.7, -24)]),
        ("Body", 0.33, 0.16, 0.02, WAIST, 0.85, [(0.1, 170), (0.26, 185), (0.4, 175)]),
    ]
    for i, (bone, rb, rt, z0, z1, sy, pts) in enumerate(veins):
        ps = [surf(rb, rt, z0, z1, z, a, sy) for z, a in pts]
        for n in range(len(ps) - 1):
            k.limb(f"Vein{i}_{n}", ps[n], ps[n + 1], 0.011, 0.011, rift, bone, segs=4)
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
