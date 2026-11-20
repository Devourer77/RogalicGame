# Котловик — уникальный дух пара (акт 2, Тракт, секрет Кипящих ключей), ~1.3 м. Клубящееся тело из горячего
# бело-серого пара поднимается из маленькой бурлящей лужи — ног нет, низ — сама лужа. Круглая грудь,
# голова без лица, толстые облачные руки, с которых капает. Внутри — тёплое свечение и бирюзовые трещины,
# два бирюзовых огонька глаз, из плеч бьют струйки пара. Край лужи в грязно-охристой сере.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (струя пара), Attack2 (гейзер — пар во все стороны), Hit,
# Death (покорение — оседает в лужу).
# Запуск: python3 build_spirit_steam.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))


def build_mesh():
    v = a2.volcano_mats()
    steam = k.mat("ST_Steam", (0.86, 0.87, 0.87), rough=0.9)
    steam_d = k.mat("ST_SteamShade", (0.72, 0.74, 0.76), rough=0.9)
    warm = k.mat("ST_Warm", (1.0, 0.62, 0.36), rough=0.5, emit=1.2)
    water = k.mat("ST_Water", (0.36, 0.5, 0.58), rough=0.1, emit=0.08)
    drop = k.mat("ST_Drop", (0.62, 0.8, 0.92), rough=0.1, emit=0.3)
    # Лужа с серой (остаётся на полу)
    k.barrel("Pool", 0.36, 0.38, 0.0, 0.03, water, "Root", segs=10)
    for i in range(7):
        a = math.tau * i / 7 + 0.4
        a2.rock(f"Sulfur{i}", (0.1, 0.08, 0.06), (0.38 * math.cos(a), 0.38 * math.sin(a), 0.03), v["sulfur"], "Root",
                rot=(0, 0, 30 * i), seed=30 + i)
    for i in range(4):
        a = math.tau * i / 4
        k.sphere(f"Bubble{i}", 0.03, (0.22 * math.cos(a), 0.22 * math.sin(a), 0.04), drop, "Root", segs=5, rings=3)
    # Столб пара из лужи
    # столб — клубы пара, сужается к луже
    for i, (x, y, z, r) in enumerate([(0.0, 0.0, 0.08, 0.1), (0.03, -0.02, 0.18, 0.11), (-0.03, 0.0, 0.28, 0.13),
                                      (0.06, -0.04, 0.38, 0.14), (-0.07, 0.02, 0.48, 0.15)]):
        k.sphere(f"ColPuff{i}", r, (x, y, z), steam, "Hips", segs=7, rings=4)
    # Грудь — клубы пара вокруг тёплого сердца
    k.sphere("Heart", 0.13, (0, -0.24, 0.86), warm, "Chest", scale=(1.0, 0.6, 1.0), segs=7, rings=4)
    for i, (x, y, z, r) in enumerate([(0.0, -0.1, 0.84, 0.22), (-0.16, 0.0, 0.92, 0.18), (0.16, 0.0, 0.92, 0.18),
                                      (0.0, 0.06, 1.02, 0.2), (0.0, -0.04, 0.66, 0.18), (-0.12, -0.12, 0.98, 0.12),
                                      (0.12, -0.12, 0.98, 0.12)]):
        k.sphere(f"ChestPuff{i}", r, (x, y, z), steam if i % 3 else steam_d, "Chest", segs=7, rings=5)
    for i, (pts, o) in enumerate([([(0, 0), (0.03, 0.06), (-0.01, 0.12), (0.03, 0.18)], (-0.08, -0.3, 0.74)),
                                  ([(0, 0), (-0.04, 0.05), (0.0, 0.1)], (0.1, -0.3, 0.8))]):
        k.crack(f"Rift{i}", pts, o, (1, 0, 0), (0, 0, 1), v["rift"], "Chest", width=0.014, depth=0.02)
    # Голова — круглая, без лица
    k.sphere("Head", 0.15, (0, -0.06, 1.18), steam, "Head", scale=(1.0, 0.95, 0.9), segs=8, rings=5)
    k.sphere("HeadPuff", 0.1, (0.05, 0.0, 1.3), steam_d, "Head", segs=6, rings=4)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.04, 0.02, 0.03), (0.055 * s, -0.2, 1.19), v["rift"], "Head")
    # Руки — толстые облачные, с каплями; струйки пара из плеч (кость Vent)
    for side, s in SIDES:
        k.sphere(f"Shoulder.{side}", 0.15, (0.28 * s, 0.0, 1.02), steam_d, "Chest", segs=7, rings=4)
        k.sphere(f"UpperArm.{side}", 0.12, (0.38 * s, -0.02, 0.86), steam, f"UpperArm.{side}", segs=7, rings=4)
        k.sphere(f"ForeArm.{side}", 0.11, (0.42 * s, -0.06, 0.7), steam_d, f"ForeArm.{side}", segs=7, rings=4)
        k.sphere(f"Fist.{side}", 0.13, (0.44 * s, -0.1, 0.54), steam, f"Hand.{side}", segs=7, rings=4)
        for j in range(2):
            k.limb(f"Drop.{side}{j}", (0.42 * s + 0.04 * j * s, -0.1, 0.42 - 0.02 * j), (0.42 * s + 0.04 * j * s, -0.1, 0.36 - 0.02 * j),
                   0.016, 0.004, drop, f"Hand.{side}", segs=4)
        k.sphere(f"Jet.{side}", 0.06, (0.35 * s, 0.03, 1.2), steam, f"Vent.{side}", segs=6, rings=4)
        k.sphere(f"Jet2.{side}", 0.045, (0.39 * s, 0.05, 1.29), steam, f"Vent.{side}", segs=5, rings=3)
    return k.join_parts("SpiritSteamMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Hips": ((0, 0, 0.04), (0, 0, 0.6), "Root"),
    "Chest": ((0, 0, 0.6), (0, 0, 1.06), "Hips"),
    "Head": ((0, -0.04, 1.06), (0, -0.06, 1.36), "Chest"),
}
for _side, _s in SIDES:
    BONES.update({
        f"Vent.{_side}": ((0.32 * _s, 0.02, 1.12), (0.42 * _s, 0.06, 1.34), "Chest"),
        f"UpperArm.{_side}": ((0.3 * _s, 0.0, 1.0), (0.4 * _s, -0.04, 0.78), "Chest"),
        f"ForeArm.{_side}": ((0.4 * _s, -0.04, 0.78), (0.43 * _s, -0.08, 0.62), f"UpperArm.{_side}"),
        f"Hand.{_side}": ((0.43 * _s, -0.08, 0.62), (0.44 * _s, -0.1, 0.44), f"ForeArm.{_side}"),
    })

STANCE = {"Hips": (4, 0, 0), "Chest": (6, 0, 0), "Head": (-6, 0, 0),
          "UpperArm.R": (-20, 0, 10), "UpperArm.L": (-20, 0, -10), "ForeArm.R": (-30, 0, 0), "ForeArm.L": (-30, 0, 0)}
SCALED = ("Hips", "Chest", "Vent.R", "Vent.L")


def stance():
    return Pose(STANCE)


def vents(p, a, b=None):
    p.size("Vent.R", 0.4 + 0.9 * a)
    p.size("Vent.L", 0.4 + 0.9 * (a if b is None else b))


def idle(t):
    """Покой (3 сек): пар клубится (тело дышит), струйки пара из плеч толчками, руки покачиваются."""
    p = stance()
    br = wave(t, 2)
    p.size("Chest", 1.0 + 0.04 * br)
    p.size("Hips", 1.0 + 0.03 * wave(t, 3, 0.2))
    p.add("Chest", y=6 * wave(t, 1))
    p.add("Head", y=k.track(t, [(0, 0), (0.3, 0), (0.36, -16), (0.6, -16), (0.66, 12), (0.9, 12), (1, 0)]))
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=-6 * wave(t, 1, 0.2 if s < 0 else 0.7))
    vents(p, pulse(t, 0.3, 0.12), pulse(t, 0.75, 0.12))
    return p


def walk(t):
    """Плывёт вместе с лужей (0.8 сек): столб наклоняется вперёд, пар тянется следом."""
    p = stance()
    p.add("Hips", x=12 + 3 * wave(t, 2))
    p.add("Chest", z=4 * wave(t, 1))
    p.size("Chest", 1.0 + 0.04 * wave(t, 2))
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=10 * (wave(t, 1) if s < 0 else -wave(t, 1)))
    vents(p, 0.6)
    return p


def attack(t):
    """Струя пара (0.8 сек): сжимается, кулаки к груди → выбрасывает обе руки вперёд (к 0.4 сек), пар из плеч."""
    p = Pose({}, {})
    K = [0.0, 0.24, 0.4, 0.58, 1.0]
    for bone, *keys in [
        ("Chest", (-12, 0, 0), (18, 0, 0), (14, 0, 0)),
        ("UpperArm.R", (20, 0, -10), (-70, 0, 4), (-60, 0, 4)),
        ("UpperArm.L", (20, 0, 10), (-70, 0, -4), (-60, 0, -4)),
        ("ForeArm.R", (-80, 0, 0), (-4, 0, 0), (-10, 0, 0)),
        ("ForeArm.L", (-80, 0, 0), (-4, 0, 0), (-10, 0, 0)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.size("Chest", track(t, [(0, 1.0), (K[1], 0.9), (K[2], 1.12), (1, 1.0)]))
    vents(p, track(t, [(0, 0.2), (K[2], 1.4), (K[3], 1.1), (1, 0.2)]))
    return p


def attack2(t):
    """Гейзер (1.0 сек): поднимается из лужи, руки вверх, раздувается — пар бьёт во все стороны."""
    p = stance()
    up = track(t, [(0, 0), (0.35, 1), (0.6, 1), (1, 0)])
    burst = track(t, [(0, 0), (0.35, 0.3), (0.45, 1.3), (0.7, 1.0), (1, 0)])
    p.size("Hips", 1.0 + 0.25 * up)
    p.size("Chest", 1.0 + 0.15 * burst)
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=-130 * up, z=24 * up * s)
        p.add(f"ForeArm.{side}", x=-20 * up)
    p.add("Head", x=14 * up)
    vents(p, burst)
    return p


def hit(t):
    """Получил удар (0.4 сек): пар разрывает, тело отшатывается и снова густеет."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    p.add("Hips", x=-12 * snap)
    p.add("Chest", x=-10 * snap)
    p.add("Head", x=-16 * snap)
    p.size("Chest", 1.0 - 0.15 * snap)
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", z=20 * snap * s)
    vents(p, snap)
    return p


def death(t):
    """Покорение (1.2 сек): пар остывает и оседает в лужу, руки опадают, остаётся только лужа."""
    p = stance()
    sink = track(t, [(0, 0), (0.25, 0.05), (1, 1)])
    p.size("Hips", max(0.02, 1.0 - 0.98 * sink))
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=20 * sink, z=-20 * sink * s)
    p.add("Head", x=24 * sink)
    vents(p, track(t, [(0, 0.3), (0.3, 1.2), (1, 0.0)]))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("SpiritSteam")
    body = build_mesh()
    rig = k.build_armature("SpiritSteam", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, scale_bones=SCALED)
    k.bake(rig, "Attack2", 30, attack2, scale_bones=SCALED)
    k.bake(rig, "Hit", 12, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 36, death, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "spirit_steam")
