# Лавовый ползун — тварь вулкана (акт 2, Тракт), низкая саламандра ~0.45 м высотой и длиной в клетку.
# Тело из пластин чёрного стеклянистого шлака, между пластинами светится оранжевая лава, с брюха
# капает расплав. Тяжёлый хвост, короткие расставленные лапы, плоская голова с бирюзовыми глазами.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (удар хвостом), Hit, Death.
# Запуск: python3 build_lava_crawler.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

LEGS = (("FL", 0.15, -0.16), ("FR", -0.15, -0.16), ("BL", 0.15, 0.16), ("BR", -0.15, 0.16))
TAIL = 3


def build_mesh():
    v = a2.volcano_mats()
    # Лавовое нутро и пластины шлака поверх
    k.sphere("Core", 0.18, (0, 0, 0.24), v["lava"], "Body", scale=(1.0, 1.55, 0.7), segs=8, rings=5)
    plates = []
    for row, y in enumerate((-0.2, -0.08, 0.04, 0.16, 0.26)):
        for col, x in enumerate((-0.11, 0.0, 0.11)):
            if row == 4 and col != 1:
                continue
            z = 0.34 - 0.02 * abs(col - 1) - (0.015 if row in (0, 4) else 0)
            plates.append((x, y, z, col))
    for i, (x, y, z, col) in enumerate(plates):
        tilt = (col - 1) * 22
        k.box(f"Plate{i}", (0.115, 0.115, 0.055), (x * 1.1, y, z), v["slag"], "Body", rot=(0, tilt, 8 * (i % 3 - 1)))
    for side in (-1, 1):
        k.box(f"SidePlate{side}", (0.05, 0.36, 0.1), (0.19 * side, 0.0, 0.22), v["slag"], "Body", rot=(0, 30 * side, 0))
    k.box("Belly", (0.26, 0.4, 0.05), (0, 0, 0.13), v["basalt"], "Body")
    for i, (x, y) in enumerate([(0.06, -0.1), (-0.07, 0.04), (0.03, 0.16)]):
        k.limb(f"Drip{i}", (x, y, 0.12), (x, y, 0.04), 0.022, 0.006, v["lava"], "Body", segs=5)
    k.crack("BackRift", [(0, 0), (0.04, 0.06), (0.02, 0.12)], (0.04, -0.16, 0.375), (1, 0, 0), (0, 1, 0), v["rift"], "Body",
            width=0.012, depth=0.01)
    # Голова — плоская широкая
    k.sphere("Head", 0.12, (0, -0.4, 0.24), v["basalt"], "Head", scale=(1.15, 1.2, 0.6), segs=8, rings=4)
    k.box("HeadPlate", (0.2, 0.16, 0.04), (0, -0.39, 0.3), v["slag"], "Head", rot=(-8, 0, 0))
    k.box("Jaw", (0.2, 0.14, 0.05), (0, -0.44, 0.19), v["slag"], "Head")
    k.box("MouthGlow", (0.16, 0.1, 0.015), (0, -0.45, 0.22), v["lava"], "Head")
    for side in (-1, 1):
        k.box(f"Eye{side}", (0.03, 0.03, 0.025), (0.08 * side, -0.48, 0.27), v["rift"], "Head")
    k.crack("HeadRift", [(0, 0), (0.03, 0.04), (0.06, 0.03)], (-0.05, -0.36, 0.322), (1, 0, 0), (0, 1, 0), v["rift"], "Head",
            width=0.01, depth=0.01)
    # Хвост: три сегмента с пластинами
    y0, z0, r = 0.3, 0.24, 0.12
    for i in range(TAIL):
        y1 = y0 + 0.14
        r1 = r * 0.72
        k.limb(f"Tail{i}", (0, y0, z0), (0, y1, z0 - 0.04), r, r1, v["lava"] if i == 0 else v["slag"], f"Tail{i + 1}", segs=7)
        k.box(f"TailPlate{i}", (r * 1.4, 0.1, 0.04), (0, y0 + 0.07, z0 + r * 0.8), v["slag"], f"Tail{i + 1}")
        y0, z0, r = y1, z0 - 0.04, r1
    k.limb("TailTip", (0, y0, z0), (0, y0 + 0.1, z0 - 0.03), r, 0.01, v["slag"], f"Tail{TAIL}", segs=6)
    # Лапы
    for name, x, y in LEGS:
        s = 1 if x > 0 else -1
        hip = (x, y, 0.22)
        kn = (x + 0.14 * s, y, 0.25)
        ft = (x + 0.24 * s, y - 0.03, 0.02)
        k.limb(f"Up.{name}", hip, kn, 0.055, 0.045, v["slag"], f"Coxa.{name}", segs=6)
        k.limb(f"Low.{name}", kn, ft, 0.045, 0.04, v["basalt"], f"Knee.{name}", segs=6)
        k.box(f"Paw.{name}", (0.1, 0.1, 0.04), (x + 0.25 * s, y - 0.05, 0.02), v["slag"], f"Knee.{name}")
        for j in (-1, 0, 1):
            k.limb(f"Claw.{name}{j}", (x + 0.25 * s + 0.03 * j, y - 0.09, 0.025), (x + 0.25 * s + 0.035 * j, y - 0.13, 0.01),
                   0.012, 0.003, v["basalt"], f"Knee.{name}", segs=4)
    return k.join_parts("LavaCrawlerMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Body": ((0, 0, 0.16), (0, 0, 0.36), "Root"),
    "Head": ((0, -0.3, 0.24), (0, -0.5, 0.24), "Body"),
}
_y, _z = 0.3, 0.24
for _i in range(TAIL):
    BONES[f"Tail{_i + 1}"] = ((0, _y, _z), (0, _y + 0.14, _z - 0.04), "Body" if _i == 0 else f"Tail{_i}")
    _y, _z = _y + 0.14, _z - 0.04
for _n, _x, _yy in LEGS:
    _s = 1 if _x > 0 else -1
    BONES[f"Coxa.{_n}"] = ((_x, _yy, 0.22), (_x, _yy, 0.32), "Body")
    BONES[f"Knee.{_n}"] = ((_x + 0.14 * _s, _yy, 0.25), (_x + 0.14 * _s, _yy, 0.35), f"Coxa.{_n}")

STANCE = {"Body": (0, -10, 0), "Head": (6, 0, 12), "Tail1": (0, 0, 16), "Tail2": (0, 0, 18), "Tail3": (0, 0, 16)}
LOC_BONES = ("Root", "Body")


def stance():
    return Pose(STANCE)


def leg(p, name, swing=0.0, lift=0.0):
    x = dict((n, xx) for n, xx, _ in LEGS)[name]
    s = 1 if x > 0 else -1
    p.add(f"Coxa.{name}", y=-swing * s, z=lift * s)
    p.add(f"Knee.{name}", z=-lift * 0.7 * s)


def tail(p, side=0.0, up=0.0, lag=0.4):
    """Хвост: side — вбок (по оси Z кости), up — вверх; концы гнутся сильнее."""
    for i in range(TAIL):
        f = 1.0 + lag * i
        p.add(f"Tail{i + 1}", z=side * f, x=-up * f)
    return p


def idle(t):
    """Покой (3 сек): дышит (пластины приподнимаются), хвост медленно ведёт, голова озирается, язык жара."""
    p = stance()
    br = wave(t, 2)
    p.move("Body", z=0.008 * br)
    p.add("Body", x=1.5 * br)
    p.add("Head", z=k.track(t, [(0, 0), (0.2, 0), (0.25, -22), (0.5, -22), (0.56, 14), (0.8, 14), (0.86, 0), (1, 0)]),
          x=-6 * pulse(t, 0.6, 0.06))
    tail(p, side=6 * wave(t, 1, 0.1), up=2 * wave(t, 2))
    return p


def walk(t):
    """Ползёт (0.8 сек): лапы по диагонали, тело и хвост изгибаются волной, как у ящерицы."""
    p = stance()
    a = wave(t, 1)
    p.move("Body", z=0.01 * wave(t, 2))
    p.add("Body", y=10 * a)
    p.add("Head", z=-8 * a)
    for name, _, _ in LEGS:
        ph = a if name in ("FL", "BR") else -a
        leg(p, name, swing=22 * ph, lift=12 * max(0.0, wave(t, 1, 0.25) * (1 if name in ("FL", "BR") else -1)))
    tail(p, side=-12 * wave(t, 1, -0.15))
    return p


def attack(t):
    """Удар хвостом (0.9 сек): разворачивается боком, хвост заносится → хлёст по клетке перед собой
    (к 0.4 сек) → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.24, 0.4, 0.58, 1.0]
    for bone, *keys in [
        ("Body", (0, 30, 0), (0, -50, 0), (0, -40, 0)),
        ("Head", (6, 0, -20), (0, 0, 30), (4, 0, 24)),
        ("Tail1", (-10, 0, 40), (6, 0, -40), (4, 0, -30)),
        ("Tail2", (-10, 0, 50), (6, 0, -54), (4, 0, -40)),
        ("Tail3", (-14, 0, 50), (8, 0, -60), (6, 0, -46)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.move("Body", z=track(t, [(0, 0), (K[1], 0.03), (K[2], -0.01), (1, 0)]))
    return p


def hit(t):
    """Получил удар (0.4 сек): тело отбрасывает, голова и хвост дёргаются с опозданием."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.move("Root", y=0.06 * snap)
    p.add("Body", x=-8 * snap, z=6 * snap)
    p.add("Head", x=-18 * whip, z=12 * whip)
    tail(p, side=-14 * whip, up=8 * whip)
    return p


def death(t):
    """Гибель (1.2 сек): бьётся, переворачивается набок, лапы дёргаются, хвост замирает."""
    p = stance()
    roll = track(t, [(0, 0), (0.2, -10), (0.55, 95), (0.65, 88), (1, 90)])
    p.set("Root", 0, 0, roll)
    p.move("Root", x=track(t, [(0, 0), (0.55, 0.12), (1, 0.12)]), z=track(t, [(0, 0), (0.55, 0.12), (1, 0.12)]))
    curl = track(t, [(0, 0), (0.5, 1), (1, 1)])
    for name, _, _ in LEGS:
        leg(p, name, lift=30 * curl + 14 * pulse(t, 0.86, 0.05))
    p.add("Head", x=-20 * curl)
    tail(p, side=20 * curl, up=-6 * curl)
    return p


def build(glb_path, blend_path=None):
    k.start_scene("LavaCrawler")
    body = build_mesh()
    rig = k.build_armature("LavaCrawler", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LOC_BONES)
    k.bake(rig, "Walk", 24, walk, cyclic=True, loc_bones=LOC_BONES)
    k.bake(rig, "Attack", 27, attack, loc_bones=LOC_BONES)
    k.bake(rig, "Hit", 12, hit, loc_bones=LOC_BONES)
    k.bake(rig, "Death", 36, death, loc_bones=LOC_BONES)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "lava_crawler")
