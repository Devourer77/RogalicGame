# Вихорь — одичавший дух ветра (~1.35 м). Воронка из серебристо-зелёного тумана, сужается книзу
# и касается плиты остриём — ног нет. Вокруг воронки витки лент-ветра и сухие листья камыша,
# две длинные ленты-«руки» закручиваются шире. Сверху — гранёный шар-голова без лица, два бирюзовых огня.
# Внутри воронки — бирюзовые искры Раскола. Облик — claude/мир.md, 5.1; референс Gemini утверждён 14 ноября.
# Смотрит в -Y (после экспорта в glTF это +Z).
#
# Анимации: Idle (ленты крутятся, голова покачивается), Walk (наклон вперёд, вращение быстрее),
# Attack (Порыв — откидывается и выбрасывает ветер вперёд), Attack2 (Круговерть — раскручивается и расширяется),
# Hit, Death (покорён: вращение глохнет, ленты разлетаются, воронка оседает).
# Запуск: python3 build_spirit_wind.py out/spirit_wind.glb out/spirit_wind.blend
import os
import sys
import math
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "SpiritWind"
TOP = 1.0      # верх воронки
HEAD_Z = 1.17
TOP_R = 0.36   # радиус воронки наверху


def funnel_r(z):
    """Радиус воронки на высоте z: остриё внизу, к верху шире."""
    f = max(0.0, min(1.0, z / TOP))
    return 0.02 + (TOP_R - 0.02) * (f ** 1.25)


def helix(name, z0, z1, turns, extra_r, phase, r, material, bone, steps_per_turn=9):
    steps = max(2, int(turns * steps_per_turn))
    pts = []
    for i in range(steps + 1):
        f = i / steps
        z = z0 + (z1 - z0) * f
        a = phase + math.tau * turns * f
        rr = funnel_r(z) + extra_r
        pts.append((math.cos(a) * rr, math.sin(a) * rr, z))
    # Плоская лента: в каждом шаге — четырёхугольник шириной r*3 по вертикали, чуть наклонённый
    for i in range(steps):
        a, b = pts[i], pts[i + 1]
        d = tuple(b[j] - a[j] for j in range(3))
        ln = math.sqrt(sum(x * x for x in d))
        u = tuple(x / ln for x in d)
        w = r * 3.2
        k.plate(f"{name}_{i}", [(0, -w / 2), (ln + 0.01, -w / 2), (ln + 0.01, w / 2), (0, w / 2)], 0.012,
                a, u, (0, 0, 1), material, bone)
    return pts


def build_mesh():
    rnd = random.Random(11)
    mist = k.mat("Wind_Mist", (0.62, 0.72, 0.68), rough=0.7, emit=0.04)
    mist_d = k.mat("Wind_MistDark", (0.46, 0.55, 0.52), rough=0.8)
    ribbon = k.mat("Wind_Ribbon", (0.66, 0.77, 0.72), rough=0.7, emit=0.03)
    leaf = k.mat("Wind_Leaf", (0.62, 0.55, 0.37), rough=0.9)
    rift = k.mat("Wind_Rift", (0.30, 0.95, 0.85), rough=0.3, emit=1.6)
    eye = k.mat("Wind_Eye", (0.55, 1.0, 0.95), rough=0.3, emit=3.0)

    # Сама воронка: стопка сужающихся колец (тёмная внутри, светлее снаружи)
    zs = [0.0, 0.12, 0.25, 0.4, 0.56, 0.72, 0.88, TOP]
    for i in range(len(zs) - 1):
        k.barrel(f"Funnel{i}", funnel_r(zs[i]) * 0.85, funnel_r(zs[i + 1]) * 0.85, zs[i], zs[i + 1],
                 mist_d if i % 2 else mist, "Funnel", segs=8)
    # Бирюзовые искры по воронке (кость Core — крутится в обратную сторону)
    for i in range(16):
        z = rnd.uniform(0.15, 0.9)
        a = rnd.uniform(0, math.tau)
        rr = funnel_r(z) * 0.87
        k.sphere(f"Spark{i}", 0.018, (math.cos(a) * rr, math.sin(a) * rr, z), rift, "Core", segs=4, rings=3)
    for i in range(4):
        z = rnd.uniform(0.25, 0.75)
        a = rnd.uniform(0, math.tau)
        p0 = (math.cos(a) * funnel_r(z) * 0.87, math.sin(a) * funnel_r(z) * 0.87, z)
        p1 = (math.cos(a + 0.4) * funnel_r(z + 0.1) * 0.87, math.sin(a + 0.4) * funnel_r(z + 0.1) * 0.87, z + 0.1)
        k.limb(f"SparkLine{i}", p0, p1, 0.01, 0.01, rift, "Core", segs=3)
    # Витки лент вплотную к воронке (кость Spiral — крутится)
    helix("Coil", 0.03, TOP + 0.02, 3.2, 0.035, 0.0, 0.024, ribbon, "Spiral", steps_per_turn=8)
    helix("CoilB", 0.12, TOP - 0.05, 2.6, 0.06, math.pi, 0.02, ribbon, "Spiral", steps_per_turn=8)
    # Листья камыша в витках
    for i in range(9):
        z = rnd.uniform(0.15, 0.95)
        a = rnd.uniform(0, math.tau)
        rr = funnel_r(z) + 0.09
        c = (math.cos(a) * rr, math.sin(a) * rr, z)
        k.plate(f"Leaf{i}", [(-0.06, 0), (0, 0.018), (0.07, 0), (0, -0.015)], 0.006, c,
                (-math.sin(a), math.cos(a), rnd.uniform(-0.4, 0.4)), (0, 0, 1), leaf, "Spiral")
    # Ленты-«руки»: широкие витки снаружи, на своих костях (раскидываются в Круговерти)
    helix("ArmR", 0.45, 0.95, 1.1, 0.2, 0.6, 0.024, ribbon, "ArmR")
    helix("ArmL", 0.3, 0.85, 1.0, 0.24, 0.6 + math.pi, 0.022, ribbon, "ArmL")

    # Голова-шар без лица
    k.sphere("Head", 0.17, (0, 0, HEAD_Z), mist, "Head", segs=9, rings=6)
    k.sphere("HeadShade", 0.15, (0, 0.03, HEAD_Z - 0.03), mist_d, "Head", segs=8, rings=5)
    for side in (-1, 1):
        k.sphere(f"Eye{side}", 0.022, (0.05 * side, -0.155, HEAD_Z + 0.0), eye, "Head",
                 scale=(1.2, 0.6, 0.9), segs=6, rings=3)
    return k.join_parts("SpiritWindMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Funnel": ((0, 0, 0.0), (0, 0, TOP), "Root"),
    "Core": ((0, 0, 0.1), (0, 0, TOP), "Funnel"),
    "Spiral": ((0, 0, 0.02), (0, 0, TOP), "Funnel"),
    "ArmR": ((0, 0, 0.3), (0, 0, 0.95), "Funnel"),
    "ArmL": ((0, 0, 0.25), (0, 0, 0.85), "Funnel"),
    "Head": ((0, 0, TOP), (0, 0, HEAD_Z + 0.17), "Funnel"),
}
SCALED = ("Funnel", "Spiral", "ArmR", "ArmL", "Core")


def spin(p, t, turns, arms_turns=None):
    """Вращение лент: целое число оборотов за анимацию, чтобы цикл не дёргался."""
    p.add("Spiral", y=360 * turns * t)
    p.add("Core", y=-360 * max(1, round(turns / 2)) * t)
    at = turns if arms_turns is None else arms_turns
    p.add("ArmR", y=360 * at * t)
    p.add("ArmL", y=360 * at * t)


def base():
    p = Pose({}, {})
    p.add("Funnel", x=4)
    p.add("Head", x=6)
    return p


def idle(t):
    """Покой (3 сек): ленты крутятся (2 оборота), искры — навстречу, воронку водит из стороны в сторону,
    голова покачивается и иногда резко поворачивается."""
    p = base()
    spin(p, t, 2, 1)
    p.add("Funnel", z=4 * wave(t, 1), x=3 * wave(t, 1, 0.25))
    look = track(t, [(0, 0), (0.3, 0), (0.35, 25), (0.6, 25), (0.66, -10), (0.9, -10), (1, 0)])
    p.add("Head", y=look, x=4 * wave(t, 2, 0.1), z=-4 * wave(t, 1))
    p.move("Root", z=0.02 * wave(t, 2))
    p.size("ArmR", 1 + 0.06 * wave(t, 1, 0.3), 1.0, 1 + 0.06 * wave(t, 1, 0.3))
    p.size("ArmL", 1 + 0.06 * wave(t, 1, 0.8), 1.0, 1 + 0.06 * wave(t, 1, 0.8))
    return p


def walk(t):
    """Несётся (0.8 сек): наклон вперёд, вращение быстрее, ленты-руки отстают."""
    p = base()
    spin(p, t, 2, 1)
    p.add("Funnel", x=14, z=6 * wave(t, 1))
    p.add("Head", x=-8, z=-5 * wave(t, 1, -0.15))
    p.move("Root", z=0.02 * abs(wave(t, 1)))
    return p


def attack(t):
    """Порыв (0.8 сек): воронка откидывается назад и сжимается → резко бросается вперёд и выдыхает
    (удар около 0.4 сек), ленты вытягиваются вперёд → выпрямляется."""
    p = base()
    spin(p, t, 2, 1)
    K = [0.0, 0.3, 0.45, 0.62, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Funnel", x=tr([0, -18, 22, 14, 0]))
    p.add("Head", x=tr([0, -10, 14, 6, 0]))
    p.size("Funnel", 1.0, tr([1, 0.92, 1.08, 1.03, 1]), 1.0)
    p.size("Spiral", tr([1, 0.88, 1.22, 1.08, 1]))
    p.move("Root", y=tr([0, 0.06, -0.08, -0.04, 0]))
    return p


def attack2(t):
    """Круговерть (0.9 сек): раскручивается всё быстрее, ленты-руки расходятся широким кругом
    (удар около 0.4 сек), потом стягиваются."""
    p = base()
    K = [0.0, 0.3, 0.45, 0.65, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    spin(p, t, 3, 3)
    wide = tr([1, 1.1, 1.9, 1.6, 1])
    p.size("ArmR", wide, 1.0, wide)
    p.size("ArmL", wide, 1.0, wide)
    p.size("Spiral", tr([1, 1.05, 1.35, 1.2, 1]))
    p.size("Funnel", tr([1, 0.95, 1.12, 1.06, 1]), 1.0, tr([1, 0.95, 1.12, 1.06, 1]))
    p.move("Root", z=tr([0, 0.03, 0.08, 0.04, 0]))
    p.add("Head", x=tr([0, 6, -8, -4, 0]))
    return p


def hit(t):
    """Получил удар (0.47 сек): воронку сносит назад, голова мотается с опозданием, ленты на миг разлетаются."""
    p = base()
    spin(p, t, 1, 1)
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.25, 0.3), (0.4, 1), (0.62, -0.4), (0.85, 0.1), (1, 0)])
    p.add("Funnel", x=-18 * snap, z=8 * snap)
    p.add("Head", x=-24 * whip, z=-10 * whip)
    p.size("Spiral", 1 + 0.2 * snap)
    return p


def death(t):
    """Покорён (1.4 сек): вращение глохнет, ленты расходятся и тают, воронка клонится и оседает,
    голова опускается на плиту."""
    p = base()
    K = [0.0, 0.15, 0.4, 0.7, 0.9, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    turn = tr([0, 0.25, 0.6, 0.8, 0.85, 0.85])
    p.add("Spiral", y=360 * turn)
    p.add("ArmR", y=360 * turn)
    p.add("ArmL", y=360 * turn)
    fade = tr([1, 1.2, 1.5, 0.5, 0.05, 0.05])
    p.size("Spiral", fade)
    p.size("ArmR", fade)
    p.size("ArmL", fade)
    p.size("Core", tr([1, 1.2, 0.6, 0.1, 0.02, 0.02]))
    p.add("Funnel", x=tr([0, -10, 18, 32, 36, 36]), z=tr([0, 4, -8, -12, -12, -12]))
    p.size("Funnel", 1.0, tr([1, 1.05, 0.8, 0.5, 0.35, 0.35]), 1.0)
    p.add("Head", x=tr([0, -15, 20, 10, 0, 0]))
    p.move("Root", z=tr([0, 0.04, -0.05, -0.3, -0.42, -0.44]))
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
    glb = args[0] if args else os.path.join(here, "..", "spirit_wind.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "spirit_wind.blend")
    build(glb, blend)
