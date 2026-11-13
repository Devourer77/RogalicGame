# Болотный ткач — тварь Раскола. Паук размером с крупную собаку (~0.7 м): тело из коры и мха,
# брюшко как кусок коряги с продольными бороздами и бирюзовыми трещинами, лапы-сучья.
# Брюшко нарочно буро-серое и рифлёное, а не гладкое серое: иначе его путают с валуном-преградой.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Паучонок (spiderling.glb) собирается этим же скриптом с ключом --spiderling: меньше и светлее.
#
# Запуск: python3 build_swamp_weaver.py out/swamp_weaver.glb out/swamp_weaver.blend [--spiderling]
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

SPIDERLING = "--spiderling" in sys.argv
NAME = "Spiderling" if SPIDERLING else "SwampWeaver"
S = 0.62 if SPIDERLING else 1.0   # масштаб всей модели (паучонок — уменьшенный ткач)
LIGHT = 1.25 if SPIDERLING else 1.0  # паучонок светлее


def c(rgb):
    return tuple(min(1.0, v * LIGHT) for v in rgb)


def v(x, y, z):
    return (x * S, y * S, z * S)


# Лапы: четыре пары. Корень у груди, колено высоко над телом (паучий силуэт), стопа далеко в стороне.
# Для каждой пары: (y корня, y колена, y стопы)
LEGS = [(-0.27, -0.46, -0.58), (-0.20, -0.22, -0.26), (-0.13, 0.02, 0.10), (-0.06, 0.26, 0.42)]
ROOT_X, ROOT_Z = 0.10, 0.30
KNEE_X, KNEE_Z = 0.33, 0.58
FOOT_X = 0.50

THORAX = (0, -0.17, 0.30)
ABDOMEN = (0, 0.16, 0.44)
ABD_R = (0.21, 0.27, 0.20)


def leg_names(i, side):
    return f"Coxa{i}.{side}", f"Knee{i}.{side}"


# ---------- Модель ----------

def build_mesh():
    bark = k.mat("Weaver_Bark", c((0.44, 0.39, 0.31)), rough=0.95)
    groove = k.mat("Weaver_Groove", c((0.22, 0.19, 0.15)), rough=0.95)
    leg_m = k.mat("Weaver_Leg", c((0.40, 0.35, 0.27)), rough=0.95)
    knot = k.mat("Weaver_Knot", c((0.28, 0.24, 0.19)), rough=0.95)
    moss = k.mat("Weaver_Moss", c((0.38, 0.47, 0.27)), rough=1.0)
    fang = k.mat("Weaver_Fang", c((0.26, 0.23, 0.18)), rough=0.7)
    rift = k.mat("Weaver_Rift", (0.30, 0.90, 0.80), rough=0.4, emit=1.2)
    web = k.mat("Weaver_Web", (0.78, 0.84, 0.82), rough=0.6, emit=0.25)

    # Головогрудь: приплюснутый ком коры
    k.sphere("Thorax", 0.15 * S, v(*THORAX), bark, "Hips", scale=(1.0, 1.15, 0.72), segs=8, rings=5)
    k.sphere("ThoraxTop", 0.085 * S, v(0, -0.15, 0.39), knot, "Hips", scale=(1.0, 1.2, 0.5), segs=6, rings=3)
    # Голова с глазами-точками (бирюза Раскола)
    k.sphere("Head", 0.085 * S, v(0, -0.31, 0.31), bark, "Head", scale=(1.15, 0.9, 0.8), segs=7, rings=4)
    for i, (ex, ez, r) in enumerate([(0.03, 0.355, 0.016), (-0.03, 0.355, 0.016), (0.062, 0.335, 0.011),
                                     (-0.062, 0.335, 0.011), (0.018, 0.38, 0.01), (-0.018, 0.38, 0.01)]):
        k.sphere(f"Eye{i}", r * S, v(ex, -0.385, ez), rift, "Head", segs=4, rings=2)
    # Хелицеры — клыки на своей кости (жуют, раскрываются перед плевком)
    for s in (-1, 1):
        k.limb(f"Chelicera{s}", v(0.03 * s, -0.36, 0.28), v(0.035 * s, -0.42, 0.22), 0.028 * S, 0.018 * S, knot, "Fangs", segs=5)
        k.limb(f"Fang{s}", v(0.035 * s, -0.42, 0.22), v(0.012 * s, -0.43, 0.15), 0.016 * S, 0.003 * S, fang, "Fangs", segs=4)

    # Брюшко: ком коры, задран вверх
    k.sphere("Abdomen", 1.0 * S, v(*ABDOMEN), bark, "Abdomen", scale=ABD_R, segs=9, rings=6)
    # Продольные борозды коры (как у ствола) — по поверхности эллипсоида
    for j, phi in enumerate([20, 55, 90, 125, 160, -30, -150]):
        pts = []
        for th in (25, 60, 95, 130, 160):
            t, p = math.radians(th), math.radians(phi)
            pts.append((ABDOMEN[0] + ABD_R[0] * 1.02 * math.sin(t) * math.cos(p),
                        ABDOMEN[1] - ABD_R[1] * 1.02 * math.cos(t),
                        ABDOMEN[2] + ABD_R[2] * 1.02 * math.sin(t) * math.sin(p)))
        for n in range(len(pts) - 1):
            k.limb(f"Groove{j}_{n}", v(*pts[n]), v(*pts[n + 1]), 0.016 * S, 0.016 * S, groove, "Abdomen", segs=4)
    # Мох шапками на спине
    k.sphere("MossA", 0.11 * S, v(0.03, 0.10, 0.62), moss, "Abdomen", scale=(1.3, 1.1, 0.35), segs=6, rings=3)
    k.sphere("MossB", 0.07 * S, v(-0.10, 0.26, 0.58), moss, "Abdomen", scale=(1.2, 1.3, 0.4), segs=6, rings=3)
    k.sphere("MossC", 0.05 * S, v(0.13, 0.30, 0.50), moss, "Abdomen", scale=(0.8, 1.2, 0.5), segs=5, rings=3)
    k.sphere("MossThorax", 0.05 * S, v(0.05, -0.12, 0.405), moss, "Hips", scale=(1.3, 1.0, 0.35), segs=5, rings=3)
    # Трещины Раскола по брюшку — между бороздами
    if not SPIDERLING:
        for j, (phi, ths) in enumerate([(72, (40, 75, 105, 140)), (108, (50, 80, 115)), (-5, (45, 85, 120)), (-175, (55, 90, 125))]):
            pts = []
            for n, th in enumerate(ths):
                t, p = math.radians(th), math.radians(phi + (8 if n % 2 else -8))
                pts.append((ABDOMEN[0] + ABD_R[0] * 1.03 * math.sin(t) * math.cos(p),
                            ABDOMEN[1] - ABD_R[1] * 1.03 * math.cos(t),
                            ABDOMEN[2] + ABD_R[2] * 1.03 * math.sin(t) * math.sin(p)))
            for n in range(len(pts) - 1):
                k.limb(f"Rift{j}_{n}", v(*pts[n]), v(*pts[n + 1]), 0.011, 0.011, rift, "Abdomen", segs=4)
    else:
        k.limb("RiftA", v(0.0, 0.0, 0.64), v(0.02, 0.2, 0.62), 0.012 * S, 0.012 * S, rift, "Abdomen", segs=4)
    # Паутинные бородавки и нить, тянущаяся с брюшка
    k.limb("Spinner", v(0, 0.40, 0.42), v(0, 0.45, 0.38), 0.035 * S, 0.012 * S, knot, "Abdomen", segs=5)
    if not SPIDERLING:
        k.limb("Thread1", v(0, 0.45, 0.38), v(0.02, 0.58, 0.12), 0.006, 0.004, web, "Thread", segs=3)
        k.limb("Thread2", v(0.02, 0.58, 0.12), v(-0.03, 0.66, 0.0), 0.004, 0.003, web, "Thread", segs=3)

    # Лапы-сучья: бедро вверх к колену-сучку, голень вниз к стопе-когтю
    for side, s in (("R", -1), ("L", 1)):
        for i, (yr, yk, yf) in enumerate(LEGS):
            coxa, knee = leg_names(i, side)
            spread = 1.0 - 0.06 * abs(i - 1.5)
            root = (ROOT_X * s, yr, ROOT_Z)
            kn = (KNEE_X * s * spread, yk, KNEE_Z - 0.02 * abs(i - 1.5))
            foot = (FOOT_X * s * spread, yf, 0.02)
            k.limb(f"Femur{i}{side}", v(*root), v(*kn), 0.042 * S, 0.026 * S, leg_m, coxa, segs=5)
            k.sphere(f"KneeKnot{i}{side}", 0.03 * S, v(*kn), knot, knee, segs=5, rings=3)
            mid = tuple(kn[n] + (foot[n] - kn[n]) * 0.45 for n in range(3))
            k.limb(f"Tibia{i}{side}", v(*kn), v(*mid), 0.028 * S, 0.02 * S, leg_m, knee, segs=5)
            # Сучок на голени — лапа выглядит как ветка
            if i in (0, 3):
                twig = (mid[0] + 0.05 * s, mid[1] + (-0.04 if i == 0 else 0.04), mid[2] + 0.07)
                k.limb(f"Twig{i}{side}", v(*mid), v(*twig), 0.011 * S, 0.003 * S, knot, knee, segs=3)
            k.limb(f"Tarsus{i}{side}", v(*mid), v(*foot), 0.016 * S, 0.004 * S, knot, knee, segs=4)

    return k.join_parts(NAME + "Mesh")


# ---------- Скелет ----------
# Все кости «вверх»: X+ наклон вперёд, Y+ поворот влево, Z+ наклон вправо.
# Лапа: Coxa в корне (качает всю лапу), Knee в колене (сгибает голень).

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15 * S), None),
    "Hips": (v(0, -0.12, 0.26), v(0, -0.12, 0.40), "Root"),
    "Head": (v(0, -0.30, 0.28), v(0, -0.30, 0.38), "Hips"),
    "Fangs": (v(0, -0.37, 0.27), v(0, -0.37, 0.35), "Head"),
    "Abdomen": (v(0, -0.02, 0.36), v(0, -0.02, 0.50), "Hips"),
    "Thread": (v(0, 0.45, 0.38), v(0, 0.45, 0.48), "Abdomen"),
}
for side, s in (("R", -1), ("L", 1)):
    for i, (yr, yk, yf) in enumerate(LEGS):
        coxa, knee = leg_names(i, side)
        spread = 1.0 - 0.06 * abs(i - 1.5)
        kz = KNEE_Z - 0.02 * abs(i - 1.5)
        BONES[coxa] = (v(ROOT_X * s, yr, ROOT_Z), v(ROOT_X * s, yr, ROOT_Z + 0.1), "Hips")
        BONES[knee] = (v(KNEE_X * s * spread, yk, kz), v(KNEE_X * s * spread, yk, kz + 0.1), coxa)


class WeaverPose(Pose):
    def leg(self, i, side, fwd=0.0, lift=0.0, curl=0.0):
        """Лапа i (0 — передняя) стороны side: fwd — вперёд, lift — поднять, curl — поджать голень под себя."""
        coxa, knee = leg_names(i, side)
        s = 1 if side == "L" else -1
        self.add(coxa, y=-fwd * s, z=lift * s)
        self.add(knee, z=-curl * s)
        return self

    def legs(self, fn):
        for side in ("L", "R"):
            for i in range(4):
                fn(self, i, side)
        return self


# ---------- Анимации ----------

def stance():
    """Присел, брюшко задрано, передние лапы чуть приподняты — готов плюнуть."""
    p = WeaverPose({}, {})
    p.move("Hips", z=-0.02 * S)
    p.add("Hips", x=6)          # голова ниже брюшка
    p.add("Abdomen", x=-14)     # брюшко вверх
    p.add("Head", x=-6)
    p.leg(0, "L", fwd=4, lift=10).leg(0, "R", fwd=-2, lift=6)
    p.leg(3, "L", fwd=-3).leg(3, "R", fwd=4)
    return p


GAIT_A = [(0, "L"), (1, "R"), (2, "L"), (3, "R")]   # лапы, которые шагают вместе


def idle(t):
    """Покой (3 сек): тело дышит, брюшко пульсирует, лапы перебирают по одной, клыки жуют, поворот к цели."""
    p = stance()
    breath = wave(t, 2)
    p.move("Hips", z=0.008 * S * breath)
    p.add("Abdomen", x=-3 * wave(t, 2, -0.15), z=2 * wave(t, 1))
    # Резкие повороты головогруди с паузами — высматривает добычу
    look = track(t, [(0, 0), (0.14, 0), (0.2, 16), (0.46, 16), (0.52, -12), (0.78, -12), (0.86, 0), (1, 0)])
    p.add("Hips", y=look)
    p.add("Head", y=look * 0.3, x=2 * breath)
    for i, side in [(0, "L"), (2, "R"), (1, "L"), (3, "R"), (0, "R")]:
        pass
    # Лапы перебирают по одной (как пианист)
    taps = [(0, "L", 0.1), (1, "R", 0.24), (0, "R", 0.38), (2, "L", 0.55), (1, "L", 0.7), (3, "R", 0.85)]
    for i, side, tc in taps:
        tap = pulse(t, tc, 0.06)
        p.leg(i, side, lift=12 * tap, fwd=4 * tap)
    # Клыки жуют, перед паузой — раскрываются
    p.add("Fangs", x=-8 * abs(wave(t, 6)) - 14 * pulse(t, 0.6, 0.06))
    p.add("Thread", x=6 * wave(t, 1, 0.2), z=8 * wave(t, 1, -0.1))
    return p


def walk(t):
    """Бег (0.5 сек): лапы двумя четвёрками, тело низко и ровно, брюшко покачивается с опозданием."""
    p = stance()
    a = wave(t, 1)
    lift_a = max(0.0, wave(t, 1, 0.25))
    lift_b = max(0.0, -wave(t, 1, 0.25))
    p.move("Hips", z=0.012 * S * abs(wave(t, 2)))
    p.add("Hips", y=3 * a, z=2 * a)
    p.add("Abdomen", z=-5 * wave(t, 1, -0.12), x=3 * wave(t, 2, -0.1))
    for side in ("L", "R"):
        for i in range(4):
            in_a = (i, side) in GAIT_A
            ph = a if in_a else -a
            lift = lift_a if in_a else lift_b
            p.leg(i, side, fwd=16 * ph, lift=18 * lift, curl=6 * lift)
    p.add("Thread", x=-14, z=10 * wave(t, 1, -0.2))
    return p


def attack(t):
    """Плевок паутиной (0.8 сек): привстал на задних лапах, брюшко подобрано → рывок вперёд, клыки раскрыты,
    плевок (к 0.4 сек) → отдача и возврат."""
    p = stance()
    K = [0.0, 0.3, 0.48, 0.62, 1.0]   # стойка, привстал, плевок, отдача, стойка

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.move("Root", y=tr([0, 0.05, -0.06, 0.02, 0]) * S)
    p.move("Hips", z=tr([0, 0.07, 0.02, 0.0, 0]) * S)
    p.add("Hips", x=tr([0, -24, 12, 2, 0]))
    p.add("Abdomen", x=tr([0, 22, -10, -4, 0]))
    p.add("Head", x=tr([0, -10, 14, 4, 0]))
    p.add("Fangs", x=tr([0, -10, -34, -14, 0]))
    front = tr([0, 28, 10, 4, 0])
    p.leg(0, "L", lift=front, fwd=tr([0, 14, 22, 6, 0])).leg(0, "R", lift=front, fwd=tr([0, 14, 22, 6, 0]))
    p.leg(1, "L", lift=front * 0.5).leg(1, "R", lift=front * 0.5)
    p.leg(3, "L", fwd=tr([0, -8, -2, 0, 0])).leg(3, "R", fwd=tr([0, -8, -2, 0, 0]))
    p.add("Thread", x=tr([0, 10, -20, -8, 0]))
    return p


def hit(t):
    """Получил удар (0.47 сек): тело отбросило, лапы поджались, брюшко мотнулось с опозданием."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.22, 0.3), (0.36, 1), (0.6, -0.3), (0.82, 0.1), (1, 0)])
    p.move("Root", y=0.08 * S * snap)
    p.move("Hips", z=-0.03 * S * snap)
    p.add("Hips", x=-14 * snap, z=8 * snap)
    p.add("Abdomen", x=18 * whip, z=-10 * whip)
    p.add("Head", x=-10 * whip)
    p.add("Fangs", x=-20 * snap)
    p.legs(lambda q, i, side: q.leg(i, side, lift=14 * snap, curl=22 * snap))
    p.add("Thread", x=20 * whip)
    return p


def death(t):
    """Гибель (1.2 сек): отшатнулся, лапы подломились, тело рухнуло брюхом на землю,
    лапы скрючились над телом (как у мёртвого паука); напоследок дёргаются."""
    p = WeaverPose({}, {})
    K = [0.0, 0.2, 0.45, 0.7, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.move("Root", y=tr([0, 0.06, 0.08, 0.08, 0.08]) * S)
    p.move("Hips", z=tr([-0.02, 0.02, -0.12, -0.17, -0.17]) * S)
    p.add("Hips", z=tr([0, 10, -6, 4, 4]))
    p.add("Hips", x=tr([6, 14, 4, 0, 0]))
    p.add("Abdomen", x=tr([-14, -6, 10, 6, 6]))
    p.add("Fangs", x=tr([0, -30, -10, -24, -20]))
    spasm = pulse(t, 0.84, 0.05) + pulse(t, 0.93, 0.04)
    curl = tr([0, 10, 30, 70, 80])

    def legf(q, i, side):
        twitch = spasm * (12 if (i + (side == "L")) % 2 else -8)
        q.leg(i, side, lift=tr([0, 14, -6, 34, 40]) + twitch, curl=curl + twitch, fwd=(1.5 - i) * tr([0, 0, 6, 10, 10]))
    p.legs(legf)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 15, walk, cyclic=True)
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
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("%s: треугольников %d" % (NAME, tris))
    return rig, body


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    default = "spiderling" if SPIDERLING else "swamp_weaver"
    glb = args[0] if args else os.path.join(here, "..", default + ".glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, default + ".blend")
    build(glb, blend)
