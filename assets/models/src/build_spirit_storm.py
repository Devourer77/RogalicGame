# Грозовик — одичавший дух молнии (~1.1 м, парит). Клубок серой грозовой тучи размером с бочку из гранёных
# «клубов», внутри ветвятся бледные холодно-жёлтые разряды, между клубами — бирюзовые трещины Раскола.
# В тёмной впадине спереди — два бирюзовых огня. Снизу к плитам свисают четыре нити молний — силуэт «медузы».
# Облик — claude/мир.md, раздел 5.1; референс Gemini утверждён 14 ноября.
# Смотрит в -Y (после экспорта в glTF это +Z).
#
# Анимации: Idle (парит, нити дрожат, разряды вспыхивают), Walk (плывёт, нити тянутся следом),
# Attack (Разряд — туча вздувается и бьёт нитями вперёд), Attack2 (Гром вокруг — сжимается и взрывается
# во все стороны), Hit, Death (покорён: разряды гаснут, туча оседает и расползается по земле).
# Запуск: python3 build_spirit_storm.py out/spirit_storm.glb out/spirit_storm.blend
import os
import sys
import math
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "SpiritStorm"
CZ = 0.78          # центр тучи
CR = 0.36          # радиус тучи
BOTTOM = CZ - 0.3  # откуда свисают нити


def zigzag(name, a, b, steps, jitter, r, material, bone, rnd):
    """Ломаная молния от a до b."""
    pts = [a]
    for i in range(1, steps):
        f = i / steps
        pts.append(tuple(a[j] + (b[j] - a[j]) * f + (rnd.uniform(-jitter, jitter) if j < 2 else 0) for j in range(3)))
    pts.append(b)
    for i in range(len(pts) - 1):
        k.limb(f"{name}_{i}", pts[i], pts[i + 1], r, r * 0.8, material, bone, segs=3)
    return pts


def build_mesh():
    rnd = random.Random(7)
    cloud = k.mat("Storm_Cloud", (0.34, 0.40, 0.46), rough=0.9)
    cloud_d = k.mat("Storm_CloudDark", (0.24, 0.29, 0.34), rough=0.9)
    hollow = k.mat("Storm_Hollow", (0.13, 0.16, 0.19), rough=1.0)
    bolt = k.mat("Storm_Bolt", (0.96, 0.95, 0.72), rough=0.3, emit=2.2)
    rift = k.mat("Storm_Rift", (0.30, 0.95, 0.85), rough=0.3, emit=1.4)
    eye = k.mat("Storm_Eye", (0.55, 1.0, 0.95), rough=0.3, emit=3.0)

    # Клубы тучи: крупные по поверхности шара, сверху чуть крупнее (туча «кучевая»)
    puffs = []
    n = 18
    for i in range(n):
        y = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(1 - y * y)
        a = i * 2.39996
        d = (math.cos(a) * rr, math.sin(a) * rr, y)
        s = 0.15 + 0.05 * (d[2] + 1) / 2 + rnd.uniform(-0.02, 0.02)
        c = (d[0] * (CR - 0.06) * 1.1, d[1] * (CR - 0.06), CZ + d[2] * (CR - 0.12))
        puffs.append((c, s))
        k.sphere(f"Puff{i}", s, c, cloud if i % 3 else cloud_d, "Cloud", segs=6, rings=4,
                 rot=(rnd.uniform(0, 40), 0, rnd.uniform(0, 60)))
    k.sphere("CloudCore", CR - 0.06, (0, 0, CZ), cloud_d, "Cloud", segs=8, rings=5)
    # Тёмная впадина спереди сверху и глаза в ней
    k.sphere("Hollow", 0.1, (0, -CR + 0.0, CZ + 0.15), hollow, "Cloud", scale=(1.3, 0.6, 0.8), segs=7, rings=4)
    for side in (-1, 1):
        k.sphere(f"Eye{side}", 0.022, (0.045 * side, -CR - 0.07, CZ + 0.15), eye, "Cloud",
                 scale=(1.2, 0.6, 0.9), segs=6, rings=3)
    # Трещины Раскола между клубами (короткие светящиеся черты по поверхности)
    for i in range(16):
        a = rnd.uniform(0, math.tau)
        z = rnd.uniform(-0.6, 0.5)
        rr = math.sqrt(1 - z * z) * (CR + 0.07)
        p0 = (math.cos(a) * rr, math.sin(a) * rr * 0.92, CZ + z * (CR - 0.02))
        a2 = a + rnd.uniform(-0.35, 0.35)
        z2 = z + rnd.uniform(-0.25, 0.25)
        rr2 = math.sqrt(max(0.0, 1 - z2 * z2)) * (CR + 0.07)
        p1 = (math.cos(a2) * rr2, math.sin(a2) * rr2 * 0.92, CZ + z2 * (CR - 0.02))
        k.limb(f"Rift{i}", p0, p1, 0.017, 0.017, rift, "Cloud", segs=3)
    # Разряды внутри: ветвистые молнии по передней и боковым сторонам (кость Bolts — вспыхивает)
    for j, (ang, z0) in enumerate([(-100, 0.1), (-70, -0.1), (-30, 0.05), (110, 0.0), (180, -0.05)]):
        a = math.radians(ang)
        r = CR + 0.1
        start = (math.cos(a) * r * 0.92, math.sin(a) * r * 0.92 * 0.92, CZ + z0 + 0.14)
        end = (math.cos(a + 0.25) * r, math.sin(a + 0.25) * r * 0.92, CZ + z0 - 0.2)
        pts = zigzag(f"Bolt{j}", start, end, 3, 0.05, 0.016, bolt, "Bolts", rnd)
        mid = pts[1]
        side = (math.cos(a - 0.45) * r, math.sin(a - 0.45) * r * 0.92, mid[2] - 0.12)
        zigzag(f"BoltB{j}", mid, side, 2, 0.03, 0.012, bolt, "Bolts", rnd)
    # Нити молний до земли (свои кости, чтобы тянулись и дрожали по отдельности)
    for i, (x, y) in enumerate([(-0.12, -0.08), (0.1, -0.1), (-0.06, 0.12), (0.14, 0.08)]):
        zigzag(f"Thread{i}", (x, y, BOTTOM + 0.04), (x * 1.4, y * 1.4, 0.0), 5, 0.04, 0.014, bolt, f"Thread{i}", rnd)
    return k.join_parts("SpiritStormMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Cloud": ((0, 0, CZ - 0.3), (0, 0, CZ + 0.3), "Root"),
    "Bolts": ((0, 0, CZ - 0.1), (0, 0, CZ + 0.1), "Cloud"),
}
for _i, (_x, _y) in enumerate([(-0.12, -0.08), (0.1, -0.1), (-0.06, 0.12), (0.14, 0.08)]):
    BONES[f"Thread{_i}"] = ((_x, _y, BOTTOM + 0.04), (_x * 1.4, _y * 1.4, 0.0), "Cloud")
THREADS = [f"Thread{i}" for i in range(4)]
SCALED = ("Cloud", "Bolts", *THREADS)


def base():
    p = Pose({}, {})
    p.add("Cloud", x=6)
    return p


def threads(p, t, amp=4.0, speed=3.0, extra_x=0.0, stretch=1.0, wide=1.0):
    for i, b in enumerate(THREADS):
        p.add(b, x=extra_x + amp * wave(t, speed, i * 0.27), z=amp * wave(t, speed + 1, i * 0.41))
        p.size(b, wide, stretch * (1 + 0.04 * wave(t, 7, i * 0.3)), wide)


def idle(t):
    """Покой (3 сек): туча парит вверх-вниз и медленно крутится, клубы «дышат», нити дрожат,
    разряды то тлеют, то вспыхивают (две вспышки за цикл)."""
    p = base()
    p.move("Root", z=0.04 * wave(t, 1))
    p.add("Cloud", y=8 * wave(t, 1, 0.2), z=4 * wave(t, 2, 0.1))
    p.size("Cloud", 1 + 0.03 * wave(t, 2, 0.3))
    flash = max(pulse(t, 0.3, 0.05), pulse(t, 0.72, 0.04))
    p.size("Bolts", 0.85 + 0.1 * wave(t, 5) + 0.35 * flash)
    threads(p, t, amp=5, stretch=1 - 0.04 * wave(t, 1))
    return p


def walk(t):
    """Плывёт (0.8 сек): туча наклоняется вперёд и покачивается, нити тянутся назад."""
    p = base()
    p.move("Root", z=0.03 * wave(t, 2))
    p.add("Cloud", x=12, z=5 * wave(t, 1))
    p.size("Bolts", 0.9 + 0.1 * wave(t, 4))
    threads(p, t, amp=6, speed=2, extra_x=20)
    return p


def attack(t):
    """Разряд (0.8 сек): туча вздувается и откидывается назад, разряды разгораются → рывок вперёд,
    нити хлещут вперёд линией (удар около 0.4 сек) → возврат."""
    p = base()
    K = [0.0, 0.3, 0.45, 0.62, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Cloud", x=tr([0, -14, 18, 12, 0]))
    p.size("Cloud", tr([1, 1.12, 0.94, 1.0, 1]))
    p.size("Bolts", tr([0.9, 1.3, 1.6, 1.1, 0.9]))
    p.move("Root", y=tr([0, 0.06, -0.08, -0.04, 0]), z=tr([0, 0.06, 0.0, 0.02, 0]))
    threads(p, t, amp=3, extra_x=tr([0, 20, -70, -50, 0]), stretch=tr([1, 0.85, 1.5, 1.3, 1]))
    return p


def attack2(t):
    """Гром вокруг (0.8 сек): туча сжимается, разряды гаснут → взрыв (около 0.4 сек): туча раздувается,
    нити раскидываются во все стороны → медленно стягивается обратно."""
    p = base()
    K = [0.0, 0.3, 0.42, 0.6, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.size("Cloud", tr([1, 0.82, 1.3, 1.12, 1]))
    p.size("Bolts", tr([0.9, 0.5, 1.8, 1.2, 0.9]))
    p.move("Root", z=tr([0, -0.05, 0.06, 0.03, 0]))
    spread = tr([0, -10, 55, 40, 0])
    for i, b in enumerate(THREADS):
        x, y = [(-0.12, -0.08), (0.1, -0.1), (-0.06, 0.12), (0.14, 0.08)][i]
        p.add(b, x=spread * (1 if y > 0 else -1), z=spread * (1 if x < 0 else -1) * 0.8)
        p.size(b, 1.0, tr([1, 0.8, 1.3, 1.15, 1]), 1.0)
    return p


def hit(t):
    """Получил удар (0.47 сек): тучу отбрасывает назад и сплющивает, разряды мигают, нити мотаются следом."""
    p = base()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.25, 0.3), (0.4, 1), (0.62, -0.4), (0.85, 0.1), (1, 0)])
    p.add("Cloud", x=-16 * snap, z=8 * snap)
    p.size("Cloud", 1 + 0.1 * snap, 1 + 0.1 * snap, 1 - 0.12 * snap)
    p.size("Bolts", 0.9 + 0.6 * pulse(t, 0.2, 0.12))
    threads(p, t, amp=2, extra_x=30 * whip, stretch=1 - 0.2 * snap)
    return p


def death(t):
    """Покорён (1.4 сек): разряды мигают и гаснут, нити втягиваются, туча оседает к земле
    и расползается плоским облаком; в конце — последняя слабая искра."""
    p = base()
    K = [0.0, 0.15, 0.4, 0.7, 0.9, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.size("Bolts", tr([1.0, 1.5, 0.6, 0.15, 0.05, 0.05]) + 0.4 * pulse(t, 0.94, 0.03))
    p.move("Root", z=tr([0, 0.05, -0.2, -0.5, -0.58, -0.6]))
    p.size("Cloud", tr([1, 1.05, 1.1, 1.25, 1.3, 1.3]), tr([1, 1.05, 1.1, 1.25, 1.3, 1.3]),
           tr([1, 1.05, 0.8, 0.5, 0.42, 0.42]))
    p.add("Cloud", x=tr([0, -10, 6, 0, 0, 0]))
    threads(p, 0.0, amp=0, stretch=tr([1, 1.1, 0.4, 0.05, 0.02, 0.02]))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, scale_bones=SCALED)
    k.bake(rig, "Attack2", 24, attack2, scale_bones=SCALED)
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
    glb = args[0] if args else os.path.join(here, "..", "spirit_storm.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "spirit_storm.blend")
    build(glb, blend)
