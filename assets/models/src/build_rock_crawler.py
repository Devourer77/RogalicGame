# Панцирный скальник — тварь Раскола (~0.9 м). Низкий широкий краб-жук из замшелого валуна:
# толстый купол-панцирь из треснувших каменных плит (спереди выступает козырьком, как щит),
# между плитами — бирюзовые трещины, из-под козырька смотрят два глаза. Короткие толстые
# каменные ноги (три пары) и две тяжёлые клешни спереди. Мох и пара сухих стеблей на панцире.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Анимации: Idle, Walk, Attack (удар клешнёй), Hit (прячется в панцирь), Death.
# Запуск: python3 build_rock_crawler.py out/rock_crawler.glb out/rock_crawler.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "RockCrawler"
SIDES = (("R", -1), ("L", 1))
# Ноги: (y корня, y стопы, x стопы)
LEGS = [(-0.06, -0.16, 0.48), (0.08, 0.1, 0.5), (0.22, 0.36, 0.44)]
SHELL_C = (0, 0.06, 0.42)
SHELL_R = (0.44, 0.46, 0.34)


def leg_names(i, side):
    return f"Coxa{i}.{side}", f"Knee{i}.{side}"


def on_shell(phi, th, grow=1.0):
    """Точка на куполе: phi — угол вокруг вертикали (0 — вправо по +X, 90 — назад по +Y), th — от макушки вниз."""
    t, p = math.radians(th), math.radians(phi)
    return (SHELL_C[0] + SHELL_R[0] * grow * math.sin(t) * math.cos(p),
            SHELL_C[1] + SHELL_R[1] * grow * math.sin(t) * math.sin(p),
            SHELL_C[2] + SHELL_R[2] * grow * math.cos(t))


# ---------- Модель ----------

def build_mesh():
    stone = k.mat("Crawler_Stone", (0.46, 0.47, 0.44), rough=0.95)       # серый камень панциря
    stone_d = k.mat("Crawler_StoneDark", (0.31, 0.33, 0.30), rough=0.95)  # тело и ноги
    stone_l = k.mat("Crawler_StoneLight", (0.52, 0.53, 0.49), rough=0.95)
    moss = k.mat("Crawler_Moss", (0.38, 0.47, 0.26), rough=1.0)
    weed = k.mat("Crawler_Weed", (0.42, 0.36, 0.27), rough=1.0)
    rift = k.mat("Crawler_Rift", (0.30, 0.92, 0.82), rough=0.4, emit=1.4)

    # Тело под панцирем
    k.sphere("Body", 0.3, (0, 0.04, 0.3), stone_d, "Hips", scale=(1.0, 1.1, 0.6), segs=8, rings=5)
    k.sphere("Face", 0.16, (0, -0.28, 0.27), stone_d, "Head", scale=(1.2, 0.8, 0.7), segs=7, rings=4)
    for side, s in SIDES:
        k.sphere(f"Eye.{side}", 0.03, (0.07 * s, -0.4, 0.31), rift, "Head", segs=5, rings=3)

    # Панцирь-купол: основа и плиты разного размера поверх
    k.sphere("Shell", 1.0, SHELL_C, stone, "Shell", scale=SHELL_R, segs=10, rings=6)
    # Плиты только на макушке (там они лежат ровно), ниже — швы-борозды между плитами
    for i, (phi, th, r) in enumerate([(0, 6, 0.17), (90, 26, 0.14), (210, 28, 0.13), (330, 26, 0.13)]):
        c = on_shell(phi, th, 1.0)
        k.sphere(f"Plate{i}", r, c, stone_l if i == 0 else stone, "Shell", scale=(1.0, 1.0, 0.3), segs=6, rings=3)
    for j, th in enumerate((44, 68)):
        ring = [on_shell(a, th, 1.02) for a in range(0, 361, 30)]
        for n in range(len(ring) - 1):
            k.limb(f"Seam{j}_{n}", ring[n], ring[n + 1], 0.016, 0.016, stone_d, "Shell", segs=4)
    # Козырёк спереди — панцирь как щит
    k.sphere("Visor", 0.3, (0, -0.3, 0.42), stone_l, "Shell", scale=(1.35, 0.55, 0.5), segs=8, rings=4)
    # Бирюзовые трещины между плитами (от макушки вниз)
    for j, phi in enumerate([45, 135, 200, 260, 315]):
        pts = [on_shell(phi + (6 if n % 2 else -6), th, 1.05) for n, th in enumerate((20, 40, 58, 76))]
        for n in range(len(pts) - 1):
            k.limb(f"Rift{j}_{n}", pts[n], pts[n + 1], 0.014, 0.014, rift, "Shell", segs=4)
    for n, (a, b) in enumerate([((-0.18, -0.42, 0.4), (-0.02, -0.46, 0.44)), ((0.02, -0.46, 0.44), (0.2, -0.42, 0.38))]):
        k.limb(f"VisorRift{n}", a, b, 0.012, 0.012, rift, "Shell", segs=4)
    # Мох и сухие стебли
    for i, (phi, th, r) in enumerate([(100, 20, 0.12), (230, 50, 0.1), (20, 55, 0.08)]):
        k.sphere(f"Moss{i}", r, on_shell(phi, th, 1.07), moss, "Shell", scale=(1.3, 1.1, 0.3), segs=5, rings=3)
    for i, (phi, th) in enumerate([(120, 25), (60, 30), (300, 40)]):
        base = on_shell(phi, th, 1.05)
        k.limb(f"Weed{i}", base, (base[0] * 1.1, base[1] * 1.1, base[2] + 0.16), 0.008, 0.003, weed, "Shell", segs=3)

    # Ноги: короткие толстые каменные столбики
    for side, s in SIDES:
        for i, (yr, yf, xf) in enumerate(LEGS):
            coxa, knee = leg_names(i, side)
            root = (0.22 * s, yr, 0.26)
            kn = (0.38 * s, (yr + yf) / 2, 0.3)
            foot = (xf * s, yf, 0.02)
            k.limb(f"Femur{i}{side}", root, kn, 0.07, 0.06, stone_d, coxa, segs=5)
            k.sphere(f"KneeStone{i}{side}", 0.065, kn, stone, knee, segs=5, rings=3)
            k.limb(f"Tibia{i}{side}", kn, foot, 0.06, 0.035, stone_d, knee, segs=5)
        # Клешня: плечо, кулак-клешня из двух пальцев (нижний — на кости Pincer)
        sh = (0.2 * s, -0.24, 0.26)
        el = (0.36 * s, -0.42, 0.22)
        k.limb(f"ClawArm{side}", sh, el, 0.07, 0.065, stone_d, f"Claw.{side}", segs=5)
        k.sphere(f"ClawPalm{side}", 0.13, (0.36 * s, -0.5, 0.2), stone, f"ClawHand.{side}", scale=(0.9, 1.2, 0.8), segs=6, rings=4)
        k.limb(f"ClawTop{side}", (0.36 * s, -0.56, 0.25), (0.28 * s, -0.8, 0.23), 0.09, 0.018, stone_l, f"ClawHand.{side}", segs=5)
        k.limb(f"ClawLow{side}", (0.38 * s, -0.56, 0.15), (0.31 * s, -0.75, 0.12), 0.065, 0.014, stone, f"Pincer.{side}", segs=5)
    return k.join_parts("RockCrawlerMesh")


# ---------- Скелет ----------
# Все кости «вверх»: X+ наклон вперёд, Y+ поворот влево, Z+ наклон вправо.

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Hips": ((0, 0.04, 0.2), (0, 0.04, 0.34), "Root"),
    "Head": ((0, -0.24, 0.24), (0, -0.24, 0.34), "Hips"),
    "Shell": ((0, 0.06, 0.3), (0, 0.06, 0.5), "Hips"),
}
for side, s in SIDES:
    for i, (yr, yf, xf) in enumerate(LEGS):
        coxa, knee = leg_names(i, side)
        BONES[coxa] = ((0.22 * s, yr, 0.26), (0.22 * s, yr, 0.36), "Hips")
        BONES[knee] = ((0.38 * s, (yr + yf) / 2, 0.3), (0.38 * s, (yr + yf) / 2, 0.4), coxa)
    BONES[f"Claw.{side}"] = ((0.2 * s, -0.24, 0.26), (0.2 * s, -0.24, 0.36), "Hips")
    BONES[f"ClawHand.{side}"] = ((0.36 * s, -0.42, 0.22), (0.36 * s, -0.42, 0.32), f"Claw.{side}")
    BONES[f"Pincer.{side}"] = ((0.38 * s, -0.54, 0.17), (0.38 * s, -0.54, 0.27), f"ClawHand.{side}")


class CrawlerPose(Pose):
    def leg(self, i, side, fwd=0.0, lift=0.0, curl=0.0):
        coxa, knee = leg_names(i, side)
        s = 1 if side == "L" else -1
        self.add(coxa, y=-fwd * s, z=lift * s)
        self.add(knee, z=-curl * s)
        return self

    def claw(self, side, raise_=0.0, out=0.0, snap=0.0):
        """Клешня: raise_ — поднять, out — развести в стороны, snap — раскрыть (плюс) / сомкнуть."""
        s = 1 if side == "L" else -1
        self.add(f"Claw.{side}", x=-raise_, z=-out * s)
        self.add(f"ClawHand.{side}", x=-raise_ * 0.5)
        self.add(f"Pincer.{side}", x=snap)
        return self


# ---------- Анимации ----------

def stance():
    """Присел за панцирем, клешни подняты перед собой — левая выше."""
    p = CrawlerPose({}, {})
    p.add("Shell", x=6)
    p.claw("L", raise_=14, out=4, snap=10).claw("R", raise_=8, out=8, snap=6)
    return p


GAIT_A = [(0, "L"), (1, "R"), (2, "L")]


def idle(t):
    """Покой (3 сек): тяжело дышит панцирем, щёлкает клешнями, выглядывает из-под козырька, лапа переступает."""
    p = stance()
    breath = wave(t, 2)
    p.move("Hips", z=0.008 * breath)
    p.add("Shell", x=2 * breath, z=1.5 * wave(t, 1))
    peek = track(t, [(0, 0), (0.2, 0), (0.28, 1), (0.5, 1), (0.56, -0.5), (0.8, -0.5), (0.88, 0), (1, 0)])
    p.add("Head", y=14 * peek, x=-4 * abs(peek))
    p.claw("L", snap=-20 * pulse(t, 0.35, 0.05) - 20 * pulse(t, 0.42, 0.05))
    p.claw("R", snap=-22 * pulse(t, 0.7, 0.05), raise_=4 * wave(t, 1, 0.3))
    p.leg(1, "L", lift=10 * pulse(t, 0.15, 0.06)).leg(2, "R", lift=10 * pulse(t, 0.62, 0.06))
    return p


def walk(t):
    """Ход (0.7 сек): короткими шажками двумя тройками, панцирь покачивается, клешни перед собой."""
    p = stance()
    a = wave(t, 1)
    la = max(0.0, wave(t, 1, 0.25))
    lb = max(0.0, -wave(t, 1, 0.25))
    p.move("Hips", z=0.012 * abs(wave(t, 2)))
    p.add("Hips", y=3 * a, z=3 * a)
    p.add("Shell", z=-3 * wave(t, 1, -0.12))
    for side in ("L", "R"):
        for i in range(3):
            in_a = (i, side) in GAIT_A
            p.leg(i, side, fwd=12 * (a if in_a else -a), lift=14 * (la if in_a else lb))
    p.claw("L", raise_=4 * a).claw("R", raise_=-4 * a)
    return p


def attack(t):
    """Удар клешнёй (0.8 сек): правая клешня отведена и раскрыта → тяжёлый удар вперёд-вниз (к 0.4 сек),
    клешня смыкается, панцирь подаётся вперёд → возврат."""
    p = stance()
    K = [0.0, 0.28, 0.46, 0.62, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.claw("R", raise_=tr([0, 36, -10, -4, 0]), out=tr([0, 24, -6, 0, 0]), snap=tr([0, 34, -16, -8, 0]))
    p.claw("L", raise_=tr([0, 10, -4, 0, 0]), out=tr([0, -6, 6, 4, 0]))
    p.add("Hips", y=tr([0, -10, 8, 4, 0]), x=tr([0, -6, 10, 4, 0]))
    p.add("Shell", x=tr([0, -4, 10, 6, 0]))
    p.move("Root", y=tr([0, 0.04, -0.08, -0.05, 0]))
    p.leg(0, "L", fwd=tr([0, -4, 10, 6, 0])).leg(0, "R", fwd=tr([0, -4, 10, 6, 0]))
    return p


def hit(t):
    """Удар по нему (0.47 сек): мгновенно прячется под панцирь — ноги и клешни поджаты, голова втянута, — потом выглядывает."""
    p = stance()
    hide = track(t, [(0, 0), (0.12, 1), (0.6, 1), (1, 0)])
    jolt = track(t, [(0, 0), (0.12, 1), (0.3, -0.3), (0.5, 0), (1, 0)])
    p.move("Hips", z=-0.1 * hide)
    p.move("Root", y=0.04 * jolt)
    p.add("Shell", x=-6 * jolt, z=4 * jolt)
    p.move("Head", y=0.08 * hide)
    for side in ("L", "R"):
        p.claw(side, raise_=-10 * hide, out=-14 * hide, snap=-14 * hide)
        for i in range(3):
            p.leg(i, side, lift=16 * hide, curl=20 * hide)
    return p


def death(t):
    """Гибель (1.2 сек): осел, панцирь треснул и съехал набок, лапы подломились, клешни легли на землю; судорога."""
    p = CrawlerPose({}, {})
    K = [0.0, 0.2, 0.45, 0.7, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.move("Hips", z=tr([0, 0.03, -0.12, -0.17, -0.17]))
    p.add("Hips", z=tr([0, 8, -10, -6, -6]), x=tr([0, -8, 6, 10, 10]))
    p.add("Shell", z=tr([0, 4, -8, -12, -12]), x=tr([0, -6, 6, 8, 8]))
    p.move("Shell", x=tr([0, 0, 0.03, 0.06, 0.06]))
    p.add("Head", x=tr([0, -14, 10, 20, 20]))
    spasm = pulse(t, 0.86, 0.05)
    for side, s in (("L", 1), ("R", -1)):
        p.claw(side, raise_=tr([0, 24, -14, -26, -28]) + 8 * spasm, out=tr([0, 10, 18, 24, 24]), snap=tr([0, 20, 10, 24, 26]))
        for i in range(3):
            q = spasm * (10 if (i + (side == "L")) % 2 else -6)
            p.leg(i, side, lift=tr([0, 6, -14, -20, -22]) + q, curl=tr([0, 0, 10, 16, 18]) + q)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 21, walk, cyclic=True)
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
    print("%s: треугольников %d" % (NAME, sum(len(p.vertices) - 2 for p in body.data.polygons)))
    return rig, body


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    glb = args[0] if args else os.path.join(here, "..", "rock_crawler.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "rock_crawler.blend")
    build(glb, blend)
