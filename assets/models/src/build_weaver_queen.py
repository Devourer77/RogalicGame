# Прядильщица — элита акта 1, тварь Раскола. Огромная паучиха (~1.4 м с поднятыми серпами):
# тело из чёрной мокрой коры и мха, на брюшке гнездо из сухого камыша с бирюзовыми яйцами,
# передняя пара лап — длинные изогнутые серпы. Под брюшком свисают клочья паутины.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Анимации: Idle, Walk, Attack (Сеть), Attack2 (Ядовитый укус), Attack3 (Кладка), Hit, Death.
# Запуск: python3 build_weaver_queen.py out/weaver_queen.glb out/weaver_queen.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "WeaverQueen"

# Три пары ходильных лап (передняя пара — серпы, отдельно): (y корня, y колена, y стопы)
LEGS = [(-0.14, -0.24, -0.34), (-0.06, 0.06, 0.12), (0.02, 0.34, 0.50)]
ROOT_X, ROOT_Z = 0.13, 0.42
KNEE_X, KNEE_Z = 0.40, 0.78
FOOT_X = 0.56

THORAX = (0, -0.22, 0.44)
ABDOMEN = (0, 0.20, 0.58)
ABD_R = (0.30, 0.36, 0.28)
NEST_Z = ABDOMEN[2] + ABD_R[2] * 0.82   # гнездо сидит на макушке брюшка


def leg_names(i, side):
    return f"Coxa{i}.{side}", f"Knee{i}.{side}"


def surf(phi, th, grow=1.02):
    """Точка на поверхности брюшка: phi — вокруг продольной оси, th — от головы к хвосту."""
    t, p = math.radians(th), math.radians(phi)
    return (ABDOMEN[0] + ABD_R[0] * grow * math.sin(t) * math.cos(p),
            ABDOMEN[1] - ABD_R[1] * grow * math.cos(t),
            ABDOMEN[2] + ABD_R[2] * grow * math.sin(t) * math.sin(p))


# ---------- Модель ----------

def build_mesh():
    bark = k.mat("Queen_Bark", (0.27, 0.25, 0.21), rough=0.9)
    groove = k.mat("Queen_Groove", (0.13, 0.12, 0.10), rough=0.95)
    leg_m = k.mat("Queen_Leg", (0.34, 0.31, 0.24), rough=0.9)
    knot = k.mat("Queen_Knot", (0.20, 0.18, 0.15), rough=0.95)
    moss = k.mat("Queen_Moss", (0.33, 0.42, 0.24), rough=1.0)
    reed = k.mat("Queen_Reed", (0.55, 0.47, 0.32), rough=1.0)
    blade = k.mat("Queen_Blade", (0.38, 0.35, 0.28), rough=0.6)
    rift = k.mat("Queen_Rift", (0.30, 0.90, 0.80), rough=0.4, emit=1.3)
    egg = k.mat("Queen_Egg", (0.45, 0.92, 0.85), rough=0.3, emit=0.9)
    web = k.mat("Queen_Web", (0.62, 0.70, 0.69), rough=0.8, emit=0.08)

    # Головогрудь и голова
    k.sphere("Thorax", 0.2, THORAX, bark, "Hips", scale=(1.0, 1.15, 0.75), segs=8, rings=5)
    k.sphere("ThoraxMoss", 0.1, (0.04, -0.2, 0.58), moss, "Hips", scale=(1.3, 1.1, 0.35), segs=6, rings=3)
    k.sphere("Head", 0.12, (0, -0.42, 0.44), bark, "Head", scale=(1.15, 0.9, 0.85), segs=7, rings=4)
    for i, (ex, ez, r) in enumerate([(0.04, 0.5, 0.022), (-0.04, 0.5, 0.022), (0.085, 0.475, 0.015),
                                     (-0.085, 0.475, 0.015), (0.025, 0.535, 0.013), (-0.025, 0.535, 0.013)]):
        k.sphere(f"Eye{i}", r, (ex, -0.525, ez), rift, "Head", segs=4, rings=2)
    for s in (-1, 1):
        k.limb(f"Chelicera{s}", (0.045 * s, -0.5, 0.40), (0.05 * s, -0.58, 0.31), 0.042, 0.028, knot, "Fangs", segs=5)
        k.limb(f"Fang{s}", (0.05 * s, -0.58, 0.31), (0.015 * s, -0.6, 0.21), 0.024, 0.004, blade, "Fangs", segs=4)

    # Брюшко: тёмная кора с бороздами, трещинами и мхом
    k.sphere("Abdomen", 1.0, ABDOMEN, bark, "Abdomen", scale=ABD_R, segs=9, rings=6)
    for j, phi in enumerate([5, 40, 140, 175, -40, -90, -140]):
        pts = [surf(phi, th) for th in (25, 65, 105, 145, 165)]
        for n in range(len(pts) - 1):
            k.limb(f"Groove{j}_{n}", pts[n], pts[n + 1], 0.02, 0.02, groove, "Abdomen", segs=4)
    for j, (phi, ths) in enumerate([(-15, (70, 100, 125, 150)), (195, (75, 105, 135)), (-65, (90, 120, 150)), (-115, (85, 115, 145))]):
        pts = [surf(phi + (9 if n % 2 else -9), th, 1.03) for n, th in enumerate(ths)]
        for n in range(len(pts) - 1):
            k.limb(f"Rift{j}_{n}", pts[n], pts[n + 1], 0.016, 0.016, rift, "Abdomen", segs=4)
    k.sphere("MossBack", 0.09, surf(20, 150, 1.0), moss, "Abdomen", scale=(1.3, 1.0, 0.5), segs=5, rings=3)
    k.sphere("MossSide", 0.08, surf(160, 60, 1.0), moss, "Abdomen", scale=(0.6, 1.3, 1.0), segs=5, rings=3)

    # Гнездо из камыша на спине: чаша и торчащие стебли, внутри яйца-огоньки (кость Nest — дрожит)
    k.barrel("NestBowl", 0.13, 0.24, NEST_Z - 0.04, NEST_Z + 0.09, reed, "Nest", segs=9, loc=(0, ABDOMEN[1] - 0.02))
    for i in range(12):
        a = math.tau * i / 12
        r0, r1 = 0.2, 0.29 + 0.03 * (i % 3)
        p0 = (r0 * math.cos(a), ABDOMEN[1] - 0.02 + r0 * math.sin(a), NEST_Z + 0.06)
        p1 = (r1 * math.cos(a + 0.35), ABDOMEN[1] - 0.02 + r1 * math.sin(a + 0.35), NEST_Z + 0.12 + 0.03 * (i % 2))
        k.limb(f"Stalk{i}", p0, p1, 0.012, 0.004, reed, "Nest", segs=3)
    for i, (ex, ey, r) in enumerate([(0, 0, 0.055), (0.08, 0.04, 0.045), (-0.07, 0.05, 0.048), (0.03, -0.08, 0.045),
                                     (-0.05, -0.06, 0.042), (0.1, -0.04, 0.038), (-0.11, -0.01, 0.038)]):
        r *= 1.3
        k.sphere(f"Egg{i}", r, (ex * 1.1, ABDOMEN[1] - 0.02 + ey * 1.1, NEST_Z + 0.09 + r * 0.5), egg, "Nest", segs=5, rings=3)

    # Клочья паутины под брюшком и сзади
    for i, (a, b) in enumerate([((0.08, 0.3, 0.36), (0.14, 0.42, 0.04)), ((-0.1, 0.3, 0.36), (-0.16, 0.38, 0.03)),
                                ((0, 0.5, 0.5), (0.04, 0.72, 0.06)), ((0.02, 0.52, 0.48), (-0.08, 0.7, 0.03))]):
        k.limb(f"Web{i}", a, b, 0.007, 0.004, web, "Web", segs=3)
    k.plate("WebSheet", [(-0.07, 0), (0.07, 0), (0.09, -0.2), (-0.08, -0.22)], 0.004, (0, 0.33, 0.34),
            (1, 0, 0), (0, 0.25, 1), web, "Web")

    # Ходильные лапы-сучья
    for side, s in (("R", -1), ("L", 1)):
        for i, (yr, yk, yf) in enumerate(LEGS):
            coxa, knee = leg_names(i, side)
            root = (ROOT_X * s, yr, ROOT_Z)
            kn = (KNEE_X * s, yk, KNEE_Z - 0.03 * i)
            foot = (FOOT_X * s, yf, 0.02)
            k.limb(f"Femur{i}{side}", root, kn, 0.05, 0.034, leg_m, coxa, segs=5)
            k.sphere(f"KneeKnot{i}{side}", 0.042, kn, knot, knee, segs=5, rings=3)
            mid = tuple(kn[n] + (foot[n] - kn[n]) * 0.45 for n in range(3))
            k.limb(f"Tibia{i}{side}", kn, mid, 0.034, 0.024, leg_m, knee, segs=5)
            k.limb(f"Tarsus{i}{side}", mid, foot, 0.024, 0.005, knot, knee, segs=4)
            if i == 1:
                k.limb(f"Twig{i}{side}", mid, (mid[0] + 0.06 * s, mid[1] + 0.03, mid[2] + 0.09), 0.014, 0.003, knot, knee, segs=3)

        # Серп: плечо вверх, затем дуга-лезвие вперёд и вниз (кости Scythe и Blade)
        sh = (0.15 * s, -0.32, 0.5)
        el = (0.3 * s, -0.42, 0.98)
        k.limb(f"ScytheArm{side}", sh, el, 0.05, 0.036, leg_m, f"Scythe.{side}", segs=5)
        k.sphere(f"ScytheKnot{side}", 0.045, el, knot, f"Blade.{side}", segs=5, rings=3)
        arc = [el, (0.32 * s, -0.6, 1.08), (0.3 * s, -0.8, 1.04), (0.26 * s, -0.95, 0.9), (0.22 * s, -1.02, 0.72)]
        rads = [0.04, 0.034, 0.026, 0.017, 0.006]
        for n in range(len(arc) - 1):
            k.limb(f"Blade{side}{n}", arc[n], arc[n + 1], rads[n], rads[n + 1], blade if n else leg_m, f"Blade.{side}", segs=5)

    return k.join_parts(NAME + "Mesh")


# ---------- Скелет ----------
# Все кости «вверх»: X+ наклон вперёд, Y+ поворот влево, Z+ наклон вправо.

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Hips": ((0, -0.15, 0.36), (0, -0.15, 0.52), "Root"),
    "Head": ((0, -0.4, 0.4), (0, -0.4, 0.52), "Hips"),
    "Fangs": ((0, -0.52, 0.38), (0, -0.52, 0.48), "Head"),
    "Abdomen": ((0, -0.04, 0.5), (0, -0.04, 0.66), "Hips"),
    "Nest": ((0, ABDOMEN[1], NEST_Z), (0, ABDOMEN[1], NEST_Z + 0.12), "Abdomen"),
    "Web": ((0, 0.33, 0.34), (0, 0.33, 0.44), "Abdomen"),
}
for side, s in (("R", -1), ("L", 1)):
    for i, (yr, yk, yf) in enumerate(LEGS):
        coxa, knee = leg_names(i, side)
        BONES[coxa] = ((ROOT_X * s, yr, ROOT_Z), (ROOT_X * s, yr, ROOT_Z + 0.1), "Hips")
        BONES[knee] = ((KNEE_X * s, yk, KNEE_Z - 0.03 * i), (KNEE_X * s, yk, KNEE_Z - 0.03 * i + 0.1), coxa)
    BONES[f"Scythe.{side}"] = ((0.15 * s, -0.32, 0.5), (0.15 * s, -0.32, 0.62), "Hips")
    BONES[f"Blade.{side}"] = ((0.3 * s, -0.42, 0.98), (0.3 * s, -0.42, 1.1), f"Scythe.{side}")


class QueenPose(Pose):
    def leg(self, i, side, fwd=0.0, lift=0.0, curl=0.0):
        coxa, knee = leg_names(i, side)
        s = 1 if side == "L" else -1
        self.add(coxa, y=-fwd * s, z=lift * s)
        self.add(knee, z=-curl * s)
        return self

    def legs(self, fn):
        for side in ("L", "R"):
            for i in range(3):
                fn(self, i, side)
        return self

    def scythe(self, side, raise_=0.0, out=0.0, chop=0.0):
        """Серп: raise_ — поднять (минус — опустить вперёд), out — развести в стороны, chop — рубануть лезвием вниз."""
        s = 1 if side == "L" else -1
        self.add(f"Scythe.{side}", x=-raise_, z=-out * s)
        self.add(f"Blade.{side}", x=chop)
        return self


# ---------- Анимации ----------

def stance():
    """Привстала: головогрудь приподнята, серпы занесены и разведены, брюшко с гнездом осело назад."""
    p = QueenPose({}, {})
    p.add("Hips", x=-8)
    p.add("Abdomen", x=8)
    p.add("Head", x=6)
    p.scythe("L", raise_=6, out=6).scythe("R", raise_=2, out=10, chop=6)
    p.leg(0, "L", fwd=4).leg(0, "R", fwd=-2)
    p.leg(2, "L", fwd=-4).leg(2, "R", fwd=3)
    return p


GAIT_A = [(0, "L"), (1, "R"), (2, "L")]


def idle(t):
    """Покой (3 сек): тяжело дышит брюшком, яйца в гнезде дрожат, серпы медленно покачиваются и
    щёлкают по очереди, лапы переступают, резкий поворот к цели."""
    p = stance()
    breath = wave(t, 2)
    p.move("Hips", z=0.01 * breath)
    p.add("Abdomen", x=-3 * wave(t, 2, -0.15), z=2 * wave(t, 1))
    p.add("Nest", x=2 * wave(t, 6, 0.1), z=2 * wave(t, 5))
    look = track(t, [(0, 0), (0.2, 0), (0.26, -14), (0.55, -14), (0.6, 10), (0.84, 10), (0.9, 0), (1, 0)])
    p.add("Hips", y=look)
    p.add("Head", y=look * 0.3)
    for side, ph in (("L", 0.0), ("R", 0.3)):
        p.scythe(side, raise_=4 * wave(t, 1, ph), out=3 * wave(t, 1, ph + 0.2))
    p.scythe("L", chop=-26 * pulse(t, 0.42, 0.05))
    p.scythe("R", chop=-26 * pulse(t, 0.7, 0.05))
    for i, side, tc in [(1, "L", 0.12), (0, "R", 0.33), (2, "R", 0.5), (1, "R", 0.78)]:
        p.leg(i, side, lift=12 * pulse(t, tc, 0.06), fwd=4 * pulse(t, tc, 0.06))
    p.add("Fangs", x=-6 * abs(wave(t, 5)))
    p.add("Web", x=6 * wave(t, 1, 0.2), z=5 * wave(t, 1, -0.1))
    return p


def walk(t):
    """Ход (0.6 сек): тяжёлая поступь двумя тройками лап, серпы покачиваются, гнездо трясётся."""
    p = stance()
    a = wave(t, 1)
    lift_a = max(0.0, wave(t, 1, 0.25))
    lift_b = max(0.0, -wave(t, 1, 0.25))
    p.move("Hips", z=0.016 * abs(wave(t, 2)))
    p.add("Hips", y=3 * a, z=2 * a)
    p.add("Abdomen", z=-4 * wave(t, 1, -0.12), x=3 * wave(t, 2, -0.1))
    p.add("Nest", x=4 * wave(t, 2, -0.25))
    for side in ("L", "R"):
        for i in range(3):
            in_a = (i, side) in GAIT_A
            p.leg(i, side, fwd=14 * (a if in_a else -a), lift=16 * (lift_a if in_a else lift_b))
    p.scythe("L", raise_=-6 * a).scythe("R", raise_=6 * a)
    p.add("Web", x=-12, z=8 * wave(t, 1, -0.2))
    return p


def attack(t):
    """Сеть (0.8 сек): подобрала брюшко под себя, раскрыла серпы → резкий выброс паутины брюшком
    вперёд под себя (к 0.4 сек) → отдача."""
    p = stance()
    K = [0.0, 0.3, 0.5, 0.65, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.move("Hips", z=tr([0, 0.06, 0.0, 0.01, 0]))
    p.add("Hips", x=tr([0, -14, 10, 4, 0]))
    p.add("Abdomen", x=tr([0, -18, 34, 12, 0]))
    p.add("Head", x=tr([0, -6, 10, 2, 0]))
    for side in ("L", "R"):
        p.scythe(side, raise_=tr([0, 16, 4, 6, 0]), out=tr([0, 22, 6, 8, 0]))
    p.add("Web", x=tr([0, -20, 40, 16, 0]))
    p.add("Nest", x=tr([0, -6, 10, 2, 0]))
    p.add("Fangs", x=tr([0, -10, -20, -8, 0]))
    return p


def attack2(t):
    """Ядовитый укус (0.8 сек): серпы взмывают → бросок вперёд, серпы смыкаются, клыки вонзаются (к 0.4 сек) → возврат."""
    p = stance()
    K = [0.0, 0.28, 0.48, 0.66, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.move("Root", y=tr([0, 0.06, -0.22, -0.16, 0]))
    p.move("Hips", z=tr([0, 0.05, -0.04, -0.02, 0]))
    p.add("Hips", x=tr([0, -18, 18, 10, 0]))
    p.add("Abdomen", x=tr([0, 10, -12, -6, 0]))
    p.add("Head", x=tr([0, -10, 16, 8, 0]))
    p.add("Fangs", x=tr([0, -30, 12, 4, 0]))
    for side in ("L", "R"):
        p.scythe(side, raise_=tr([0, 30, -26, -14, 0]), out=tr([0, 18, -10, -4, 0]), chop=tr([0, 10, -34, -20, 0]))
    p.leg(0, "L", fwd=tr([0, -6, 18, 10, 0])).leg(0, "R", fwd=tr([0, -6, 18, 10, 0]))
    p.leg(2, "L", fwd=tr([0, 10, -12, -6, 0])).leg(2, "R", fwd=tr([0, 10, -12, -6, 0]))
    p.add("Nest", x=tr([0, 6, -10, -4, 0]))
    return p


def attack3(t):
    """Кладка (0.8 сек): брюшко вздымается, гнездо раскачивается, яйца вспыхивают — паучата вылупились (к 0.4 сек)."""
    p = stance()
    K = [0.0, 0.25, 0.45, 0.6, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Hips", x=tr([0, 6, -6, 0, 0]))
    p.add("Abdomen", x=tr([0, -16, 10, -4, 0]), z=8 * wave(t, 3) * tr([0, 1, 1, 0.5, 0]))
    p.add("Nest", x=12 * wave(t, 4) * tr([0, 1, 1, 0.4, 0]), z=10 * wave(t, 3, 0.25) * tr([0, 1, 1, 0.4, 0]))
    p.size("Nest", 1.0 + 0.12 * tr([0, 0.4, 1, 0.3, 0]))
    for side in ("L", "R"):
        p.scythe(side, raise_=tr([0, 14, 22, 8, 0]), out=tr([0, 16, 26, 10, 0]))
    p.add("Web", x=tr([0, 10, -16, -4, 0]))
    return p


def hit(t):
    """Получила удар (0.47 сек): отшатнулась, серпы вскинуты, гнездо мотнулось с опозданием."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.22, 0.3), (0.36, 1), (0.6, -0.3), (0.82, 0.1), (1, 0)])
    p.move("Root", y=0.06 * snap)
    p.add("Hips", x=-12 * snap, z=6 * snap)
    p.add("Abdomen", x=14 * whip, z=-8 * whip)
    p.add("Nest", x=14 * whip)
    p.add("Head", x=-10 * whip)
    for side in ("L", "R"):
        p.scythe(side, raise_=20 * snap, out=14 * snap, chop=12 * whip)
    p.legs(lambda q, i, side: q.leg(i, side, lift=10 * snap, curl=16 * snap))
    p.add("Web", x=18 * whip)
    return p


def death(t):
    """Гибель (1.4 сек): вскинула серпы, лапы подломились, рухнула брюхом, серпы упали вперёд,
    лапы скрючились, яйца в гнезде погасли (сжались); напоследок дёргаются."""
    p = QueenPose({}, {})
    K = [0.0, 0.18, 0.42, 0.68, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.move("Root", y=tr([0, 0.06, 0.08, 0.08, 0.08]))
    p.move("Hips", z=tr([0, 0.04, -0.14, -0.22, -0.22]))
    p.add("Hips", x=tr([-8, -20, 6, 12, 12]), z=tr([0, 8, -6, 4, 4]))
    p.add("Abdomen", x=tr([8, 14, -6, -10, -10]))
    p.add("Fangs", x=tr([0, -30, -10, -24, -20]))
    p.add("Nest", x=tr([0, 10, -12, 6, 4]))
    p.size("Nest", tr([1, 1.05, 0.9, 0.75, 0.75]))
    spasm = pulse(t, 0.84, 0.05) + pulse(t, 0.93, 0.04)
    for side in ("L", "R"):
        p.scythe(side, raise_=tr([6, 40, -20, -46, -50]) + 10 * spasm, out=tr([8, 20, 10, 18, 20]),
                 chop=tr([0, 10, -20, -40, -44]))

    def legf(q, i, side):
        twitch = spasm * (12 if (i + (side == "L")) % 2 else -8)
        q.leg(i, side, lift=tr([0, 14, -6, 30, 36]) + twitch, curl=tr([0, 10, 30, 66, 76]) + twitch,
              fwd=(1 - i) * tr([0, 0, 6, 10, 10]))
    p.legs(legf)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=("Nest",))
    k.bake(rig, "Walk", 18, walk, cyclic=True, scale_bones=("Nest",))
    k.bake(rig, "Attack", 24, attack, scale_bones=("Nest",))
    k.bake(rig, "Attack2", 24, attack2, scale_bones=("Nest",))
    k.bake(rig, "Attack3", 24, attack3, scale_bones=("Nest",))
    k.bake(rig, "Hit", 14, hit, scale_bones=("Nest",))
    k.bake(rig, "Death", 42, death, scale_bones=("Nest",))


# ---------- Сборка и экспорт ----------

def build(glb_path, blend_path=None):
    k.start_scene(NAME)
    body = build_mesh()
    rig = k.build_armature(NAME, BONES)
    body.parent = rig
    build_actions(rig)
    k.export(rig, body, glb_path, blend_path)
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("%s: треугольников %d" % (NAME, tris))
    return rig, body


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    glb = args[0] if args else os.path.join(here, "..", "weaver_queen.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "weaver_queen.blend")
    build(glb, blend)
