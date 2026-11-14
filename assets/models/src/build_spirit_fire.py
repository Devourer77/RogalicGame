# Жаровик — одичавший дух огня (~1.45 м), секретный босс Тлеющей пещеры (claude/тз-дух-огня.md).
# Стоит прямо, как ожившее обгоревшее дерево: узкий корпус из чёрного угля с оранжевыми швами, внизу
# расходится и стекает в лужу жара; широкие угловатые плечи; руки целиком из пламени с пальцами-языками;
# вместо головы — высокий язык огня без лица, два бирюзовых огня-глаза. Бирюзовые трещины Раскола по углю.
# Референс Gemini (вариант «Угольный страж») утверждён 14 ноября.
# Смотрит в -Y (после экспорта в glTF это +Z).
#
# Анимации: Idle (пламя дрожит, руки тлеют), Walk (скользит, пламя тянется назад),
# Attack (Плевок жаром — голова откидывается и плюёт вперёд, правая рука выбрасывается следом),
# Attack2 (Вспышка — сжимается и вспыхивает во все стороны), Attack3 (Раздуть угли — руки вверх, пламя растёт),
# Hit, Death (покорён: пламя опадает, угольный корпус оседает в лужу жара).
# Запуск: python3 build_spirit_fire.py out/spirit_fire.glb out/spirit_fire.blend
import os
import sys
import math
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "SpiritFire"
WAIST = 0.45
SHOULDER = 0.86
HEAD = 0.9


def build_mesh():
    rnd = random.Random(3)
    coal = k.mat("Fire_Coal", (0.15, 0.12, 0.11), rough=0.95)
    coal_l = k.mat("Fire_CoalLight", (0.25, 0.2, 0.17), rough=0.9)
    seam = k.mat("Fire_Seam", (1.0, 0.42, 0.08), rough=0.4, emit=1.1)
    flame = k.mat("Fire_Flame", (1.0, 0.38, 0.06), rough=0.5, emit=0.85)
    flame_l = k.mat("Fire_FlameLight", (1.0, 0.55, 0.18), rough=0.5, emit=1.1)
    pool = k.mat("Fire_Pool", (0.92, 0.36, 0.06), rough=0.4, emit=0.8)
    rim = k.mat("Fire_Rim", (0.24, 0.16, 0.11), rough=1.0)
    rift = k.mat("Fire_Rift", (0.30, 0.95, 0.85), rough=0.3, emit=1.5)
    eye = k.mat("Fire_Eye", (0.55, 1.0, 0.95), rough=0.3, emit=3.0)

    # Лужа жара (своя кость Pool): тёмный край и светящаяся середина, угли
    k.barrel("PoolRim", 0.55, 0.5, 0.0, 0.045, rim, "Pool", segs=11)
    k.barrel("PoolGlow", 0.42, 0.36, 0.0, 0.055, pool, "Pool", segs=11)
    for i in range(7):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.3, 0.5)
        k.sphere(f"Ember{i}", rnd.uniform(0.025, 0.045), (math.cos(a) * r, math.sin(a) * r, 0.05),
                 seam if i % 2 else coal_l, "Pool", segs=5, rings=3)

    # Корпус: низ расширяется и «стекает» в лужу, талия узкая, грудь и плечи широкие
    k.barrel("Flare", 0.34, 0.2, 0.02, 0.2, coal, "Body", segs=8, sy=0.9)
    k.barrel("Trunk", 0.2, 0.16, 0.18, WAIST + 0.02, coal, "Body", segs=7, sy=0.85)
    k.barrel("Chest", 0.16, 0.29, WAIST, SHOULDER - 0.06, coal, "Chest", segs=7, sy=0.72)
    k.barrel("ChestTop", 0.29, 0.15, SHOULDER - 0.07, SHOULDER + 0.04, coal_l, "Chest", segs=7, sy=0.72)
    for side in (-1, 1):
        k.box(f"Pauldron{side}", (0.22, 0.24, 0.13), (0.25 * side, 0.0, SHOULDER - 0.02), coal_l, "Chest",
              rot=(0, -18 * side, 8 * side))
        k.box(f"PauldronB{side}", (0.15, 0.2, 0.1), (0.3 * side, 0.02, SHOULDER - 0.11), coal, "Chest",
              rot=(0, -30 * side, 0))
    # Сколы-плиты на груди и бёдрах (угловатость, как на референсе)
    for i, (x, z, s) in enumerate([(-0.08, 0.72, 0.09), (0.09, 0.66, 0.08), (0.0, 0.56, 0.08), (-0.1, 0.3, 0.08), (0.11, 0.22, 0.09)]):
        k.box(f"Plate{i}", (s * 1.4, 0.04, s * 1.2), (x, -0.16 if z > 0.45 else -0.14, z), coal_l,
              "Chest" if z > 0.45 else "Body", rot=(0, rnd.uniform(-15, 15), 0))

    # Оранжевые швы и бирюзовые трещины по поверхности
    def surf(rb, rt, z0, z1, z, ang, sy, out=0.008):
        r = rb + (rt - rb) * (z - z0) / (z1 - z0)
        a = math.radians(ang)
        return (r * math.sin(a), -r * math.cos(a) * sy - out, z)

    seams = [
        ("Body", 0.2, 0.16, 0.18, WAIST + 0.02, 0.85, [(0.2, -5), (0.3, 8), (0.42, -4)], seam, 0.016),
        ("Body", 0.34, 0.2, 0.02, 0.2, 0.9, [(0.04, 30), (0.1, 22), (0.19, 34)], seam, 0.016),
        ("Body", 0.34, 0.2, 0.02, 0.2, 0.9, [(0.05, -40), (0.13, -28), (0.19, -36)], seam, 0.016),
        ("Chest", 0.16, 0.29, WAIST, SHOULDER - 0.06, 0.72, [(0.48, 0), (0.58, -10), (0.68, 6), (0.78, -4)], seam, 0.016),
        ("Chest", 0.16, 0.29, WAIST, SHOULDER - 0.06, 0.72, [(0.6, -10), (0.66, -35), (0.74, -42)], seam, 0.014),
        ("Chest", 0.16, 0.29, WAIST, SHOULDER - 0.06, 0.72, [(0.68, 6), (0.73, 30), (0.79, 38)], seam, 0.014),
        ("Chest", 0.16, 0.29, WAIST, SHOULDER - 0.06, 0.72, [(0.62, 22), (0.7, 18), (0.76, 26)], rift, 0.011),
        ("Body", 0.2, 0.16, 0.18, WAIST + 0.02, 0.85, [(0.24, 20), (0.34, 26), (0.4, 18)], rift, 0.011),
        ("Chest", 0.16, 0.29, WAIST, SHOULDER - 0.06, 0.72, [(0.52, 175), (0.64, 186), (0.76, 178)], seam, 0.016),
    ]
    for i, (bone, rb, rt, z0, z1, sy, pts, m, w) in enumerate(seams):
        ps = [surf(rb, rt, z0, z1, z, a, sy) for z, a in pts]
        for n in range(len(ps) - 1):
            k.limb(f"Seam{i}_{n}", ps[n], ps[n + 1], w, w, m, bone, segs=4)

    # Голова — язык пламени без лица: основной конус, два боковых языка, светлая сердцевина
    k.limb("FlameMain", (0, 0.0, HEAD - 0.04), (0, 0.03, HEAD + 0.52), 0.15, 0.0, flame, "Head", segs=7)
    k.limb("FlameCore", (0, -0.05, HEAD), (0, -0.01, HEAD + 0.3), 0.09, 0.0, flame_l, "Head", segs=6)
    for side in (-1, 1):
        k.limb(f"FlameSide{side}", (0.05 * side, 0.0, HEAD + 0.06), (0.12 * side, 0.03, HEAD + 0.36), 0.06, 0.0,
               flame, "Head", segs=5)
    for side in (-1, 1):
        k.sphere(f"Eye{side}", 0.022, (0.05 * side, -0.14, HEAD + 0.1), eye, "Head",
                 scale=(1.4, 0.6, 0.7), segs=6, rings=3, rot=(0, 15 * side, 0))

    # Руки из пламени: плечо → локоть → кисть с пальцами-языками
    for side, pre in ((-1, "R"), (1, "L")):
        sh = (0.3 * side, -0.02, SHOULDER - 0.05)
        el = (0.38 * side, -0.07, 0.6)
        hd = (0.4 * side, -0.12, 0.36)
        k.limb(f"Arm{pre}", sh, el, 0.08, 0.065, flame, f"Arm{pre}", segs=6)
        k.limb(f"Fore{pre}", el, hd, 0.065, 0.055, flame, f"Fore{pre}", segs=6)
        k.limb(f"ForeCore{pre}", (el[0], el[1] - 0.02, el[2]), (hd[0], hd[1] - 0.02, hd[2] + 0.05), 0.025, 0.02,
               flame_l, f"Fore{pre}", segs=4)
        for j, (dx, dy) in enumerate(((-0.05, -0.03), (0.0, -0.06), (0.05, -0.03), (0.07 * side, 0.02))):
            k.limb(f"Finger{pre}{j}", hd, (hd[0] + dx, hd[1] + dy - 0.02, hd[2] - 0.15), 0.025, 0.0,
                   flame, f"Hand{pre}", segs=4)
    return k.join_parts("SpiritFireMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Pool": ((0, 0, 0.0), (0, 0, 0.05), None),
    "Body": ((0, 0, 0.02), (0, 0, WAIST), "Root"),
    "Chest": ((0, 0, WAIST), (0, 0, SHOULDER), "Body"),
    "Head": ((0, 0, HEAD - 0.05), (0, 0, HEAD + 0.45), "Chest"),
    "ArmR": ((-0.3, -0.02, SHOULDER - 0.05), (-0.38, -0.07, 0.6), "Chest"),
    "ForeR": ((-0.38, -0.07, 0.6), (-0.4, -0.12, 0.36), "ArmR"),
    "HandR": ((-0.4, -0.12, 0.36), (-0.4, -0.14, 0.22), "ForeR"),
    "ArmL": ((0.3, -0.02, SHOULDER - 0.05), (0.38, -0.07, 0.6), "Chest"),
    "ForeL": ((0.38, -0.07, 0.6), (0.4, -0.12, 0.36), "ArmL"),
    "HandL": ((0.4, -0.12, 0.36), (0.4, -0.14, 0.22), "ForeL"),
}
SCALED = ("Pool", "Body", "Head", "ForeR", "ForeL", "HandR", "HandL")


def base():
    """Стойка: чуть наклонён вперёд, правая рука приподнята и согнута, левая ниже — как на референсе."""
    p = Pose({}, {})
    p.add("Body", x=4, z=-2)
    p.add("Chest", x=8, y=-8)
    p.add("Head", x=-4, y=6)
    p.add("ArmR", x=-25, z=10)
    p.add("ForeR", x=-40)
    p.add("ArmL", x=-6, z=-6)
    p.add("ForeL", x=-12)
    return p


def flicker(p, t, amp=1.0):
    """Пламя головы и рук дрожит быстро и не в такт."""
    p.size("Head", 1 + 0.05 * amp * wave(t, 6), 1 + 0.12 * amp * wave(t, 5, 0.3), 1 + 0.05 * amp * wave(t, 7, 0.6))
    p.add("Head", z=4 * amp * wave(t, 4, 0.2), x=3 * amp * wave(t, 3, 0.5))
    p.size("HandR", 1 + 0.15 * amp * wave(t, 6, 0.1))
    p.size("HandL", 1 + 0.15 * amp * wave(t, 5, 0.7))


def idle(t):
    """Покой (3 сек): пламя дрожит, корпус тяжело «дышит» жаром, лужа пульсирует; голова-пламя
    поворачивается рывками; правая рука сжимает и разжимает пальцы-языки."""
    p = base()
    flicker(p, t)
    b = wave(t, 1)
    p.size("Body", 1 + 0.015 * b, 1 + 0.015 * b, 1 - 0.01 * b)
    p.add("Chest", x=2 * b, z=2 * wave(t, 1, 0.3))
    p.size("Pool", 1 + 0.04 * wave(t, 2, 0.15))
    look = track(t, [(0, 0), (0.2, 0), (0.26, -18), (0.55, -18), (0.6, 14), (0.85, 14), (0.92, 0), (1, 0)])
    p.add("Head", y=look)
    grip = pulse(t, 0.4, 0.1) + pulse(t, 0.75, 0.08)
    p.add("ForeR", x=-6 * wave(t, 1, 0.4) - 15 * grip)
    p.size("HandR", 1 - 0.25 * grip)
    p.add("ArmL", x=-4 * wave(t, 1, 0.7))
    p.add("ForeL", x=-5 * wave(t, 1, 0.9))
    return p


def walk(t):
    """Скользит (0.8 сек): наклон вперёд, пламя головы и рук тянется назад, корпус покачивается."""
    p = base()
    flicker(p, t, 0.7)
    s = wave(t, 1)
    p.add("Body", x=10, z=4 * s)
    p.add("Chest", z=-3 * s, y=-4 * s)
    p.add("Head", x=-14)
    p.add("ArmR", x=20 + 6 * s)
    p.add("ArmL", x=20 - 6 * s)
    p.add("ForeR", x=25)
    p.add("ForeL", x=10)
    p.size("Pool", 1.0, 1.12, 1.0)
    p.move("Root", z=0.012 * abs(wave(t, 1)))
    return p


def attack(t):
    """Плевок жаром (0.8 сек): голова-пламя откидывается назад и разгорается → резко бросается вперёд
    (удар около 0.4 сек), правая рука выбрасывается следом и вытягивается → возврат."""
    p = base()
    flicker(p, t, 0.5)
    K = [0.0, 0.3, 0.45, 0.62, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Chest", x=tr([0, -12, 16, 10, 0]), y=tr([0, 10, -14, -8, 0]))
    p.add("Head", x=tr([0, -30, 34, 20, 0]))
    p.size("Head", tr([1, 1.15, 1.3, 1.1, 1]), tr([1, 1.25, 1.5, 1.2, 1]), tr([1, 1.15, 1.3, 1.1, 1]))
    p.add("ArmR", x=tr([0, 30, -70, -55, 0]), z=tr([0, 15, 0, 4, 0]))
    p.add("ForeR", x=tr([0, -20, 35, 25, 0]))
    p.size("ForeR", 1.0, tr([1, 0.9, 1.5, 1.3, 1]), 1.0)
    return p


def attack2(t):
    """Вспышка (0.8 сек): сжимается, пламя опадает → вспыхивает во все стороны (около 0.4 сек):
    руки раскинуты, пламя головы взлетает, лужа жара расходится."""
    p = base()
    K = [0.0, 0.3, 0.42, 0.6, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    crouch = tr([0, 1, -0.6, -0.3, 0])
    p.size("Body", 1 + 0.05 * crouch, 1 + 0.05 * crouch, 1 - 0.1 * crouch)
    p.size("Head", tr([1, 0.7, 1.5, 1.25, 1]))
    out = tr([0, -10, 70, 55, 0])
    p.add("ArmR", z=out, x=tr([0, 10, -10, -5, 0]))
    p.add("ArmL", z=-out, x=tr([0, 10, -10, -5, 0]))
    p.add("ForeR", x=tr([0, -20, 30, 25, 0]))
    p.add("ForeL", x=tr([0, -20, 30, 25, 0]))
    p.size("HandR", tr([1, 0.7, 1.6, 1.3, 1]))
    p.size("HandL", tr([1, 0.7, 1.6, 1.3, 1]))
    p.size("Pool", tr([1, 0.95, 1.3, 1.2, 1]))
    return p


def attack3(t):
    """Раздуть угли (1 сек): поднимает руки-пламя вверх, будто раздувает костёр, пламя головы растёт;
    дважды «качает» жар (около 0.4 и 0.7 сек)."""
    p = base()
    flicker(p, t, 0.8)
    K = [0.0, 0.25, 0.85, 1.0]
    lift = track(t, [(K[0], 0), (K[1], 1), (K[2], 1), (K[3], 0)])
    pump = pulse(t, 0.4, 0.1) + pulse(t, 0.7, 0.1)
    p.add("ArmR", x=-120 * lift + 15 * pump, z=20 * lift)
    p.add("ArmL", x=-120 * lift + 15 * pump, z=-20 * lift)
    p.add("ForeR", x=40 * lift)
    p.add("ForeL", x=40 * lift)
    p.add("Chest", x=-8 * lift)
    p.add("Head", x=-10 * lift)
    p.size("Head", 1 + 0.25 * lift + 0.15 * pump, 1 + 0.4 * lift + 0.2 * pump, 1 + 0.25 * lift + 0.15 * pump)
    p.size("Pool", 1 + 0.1 * pump)
    return p


def hit(t):
    """Получил удар (0.47 сек): корпус отбрасывает, пламя головы сбивает и оно мотается с опозданием."""
    p = base()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.25, 0.3), (0.4, 1), (0.62, -0.4), (0.85, 0.1), (1, 0)])
    p.add("Body", x=-8 * snap, z=4 * snap)
    p.add("Chest", x=-14 * snap)
    p.add("Head", x=-28 * whip, z=-12 * whip)
    p.size("Head", 1 - 0.3 * snap)
    p.add("ArmR", x=20 * whip, z=10 * whip)
    p.add("ArmL", x=16 * whip, z=-10 * whip)
    return p


def death(t):
    """Покорён (1.4 сек): пламя головы и рук вздрагивает и опадает, угольный корпус клонится
    и оседает в лужу жара; остаются тлеющие угли, напоследок короткая вспышка."""
    p = base()
    K = [0.0, 0.15, 0.4, 0.7, 0.9, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    fade = tr([1, 1.3, 0.6, 0.15, 0.05, 0.05]) + 0.3 * pulse(t, 0.95, 0.03)
    p.size("Head", fade)
    p.size("HandR", fade)
    p.size("HandL", fade)
    p.size("ForeR", fade, fade, fade)
    p.size("ForeL", fade, fade, fade)
    p.add("Chest", x=tr([0, -15, 18, 30, 32, 32]))
    p.add("Body", x=tr([0, -6, 8, 14, 15, 15]))
    p.add("ArmR", x=tr([0, 20, 10, 5, 5, 5]), z=tr([0, 10, 25, 30, 30, 30]))
    p.add("ArmL", x=tr([0, 20, 10, 5, 5, 5]), z=tr([0, -10, -25, -30, -30, -30]))
    p.move("Root", z=tr([0, 0.03, -0.2, -0.6, -0.75, -0.78]))
    p.size("Pool", tr([1, 1.05, 1.2, 1.35, 1.4, 1.4]))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, scale_bones=SCALED)
    k.bake(rig, "Attack2", 24, attack2, scale_bones=SCALED)
    k.bake(rig, "Attack3", 30, attack3, scale_bones=SCALED)
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
    glb = args[0] if args else os.path.join(here, "..", "spirit_fire.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "spirit_fire.blend")
    build(glb, blend)
