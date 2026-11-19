# Полусвободный дух — одичавший дух воды, наполовину вырвавшийся из треснувшей сферы (акт 2, Подземье), ~1.4 м.
# Большая треснувшая стеклянная сфера в сломанной клетке стоит на полу; из пролома в стекле по пояс
# вырвалась фигура из тёмной закрученной воды с длинными руками-струями, без лица, с бирюзовыми огоньками
# глаз. Нижняя половина ещё заперта в сфере. Вода с бледно-голубыми бликами (как у Омутника), чтобы не
# читалась тенью. Разбил сферу до гибели — духа можно покорить, иначе он улетает.
# Смотрит в -Y. Анимации: Idle, Walk (сфера катится-подпрыгивает), Attack (выплеск по дуге), Hit, Death (улетает).
# Запуск: python3 build_half_spirit.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))


def build_mesh():
    m = a2.mech_mats()
    glass = k.mat("HS_Glass", (0.62, 0.74, 0.8), rough=0.1, emit=0.1, alpha=0.6)
    shard = k.mat("HS_Shard", (0.72, 0.82, 0.86), rough=0.1, emit=0.15)
    water = k.mat("HS_Water", (0.16, 0.25, 0.36), rough=0.2, emit=0.25)
    shine = k.mat("HS_Shine", (0.55, 0.8, 1.0), rough=0.2, emit=1.2)
    # Сфера и сломанная клетка (стоят на полу)
    k.sphere("Sphere", 0.36, (0, 0, 0.38), glass, "Orb", segs=9, rings=6)
    k.sphere("Trapped", 0.26, (0, 0, 0.34), water, "Orb", segs=7, rings=5)
    a2.ring("CageBase", 0.34, 0.025, (0, 0, 0.1), (0, 0, 1), m["iron_d"], "Orb", seg=14)
    a2.ring("CageMid", 0.38, 0.02, (0, 0, 0.36), (0, 0, 1), m["iron_d"], "Orb", seg=14)
    for i in range(6):   # прутья, часть погнута
        a = math.tau * i / 6
        bend = 0.12 if i in (1, 4) else 0.0
        x, y = 0.37 * math.cos(a), 0.37 * math.sin(a)
        k.limb(f"Bar{i}", (x * 0.9, y * 0.9, 0.08), (x * (1 + bend), y * (1 + bend), 0.58 + bend * 0.5), 0.014, 0.014,
               m["iron"], "Orb", segs=4)
    for i, (pts, o, u) in enumerate([([(0, 0), (0.08, 0.1), (0.04, 0.2), (0.12, 0.28)], (-0.1, -0.35, 0.3), (1, 0, 0)),
                                     ([(0, 0), (0.06, -0.08), (0.14, -0.06)], (0.12, -0.33, 0.5), (1, 0, 0)),
                                     ([(0, 0), (0.08, 0.06), (0.16, 0.0)], (0.33, -0.08, 0.34), (0, 1, 0))]):
        k.crack(f"GlassCrack{i}", pts, o, u, (0, 0, 1), shard, "Orb", width=0.012, depth=0.012)
    for i, (x, y, r) in enumerate([(0.44, -0.2, 0.04), (-0.4, -0.3, 0.05), (0.2, -0.5, 0.035), (-0.5, 0.1, 0.03)]):
        k.box(f"Shard{i}", (r * 1.4, r, 0.012), (x, y, 0.01), shard, "Root", rot=(0, 0, 40 * i))
    # Дух по пояс из пролома
    k.limb("Waist", (0, -0.04, 0.62), (0, -0.06, 0.86), 0.13, 0.16, water, "Spirit", segs=8)
    k.sphere("Chest", 0.17, (0, -0.06, 0.94), water, "Chest", scale=(1.1, 0.85, 0.95), segs=8, rings=5)
    k.limb("Neck", (0, -0.06, 1.04), (0, -0.1, 1.14), 0.07, 0.06, water, "Head", segs=6)
    k.sphere("Head", 0.12, (0, -0.12, 1.24), water, "Head", scale=(0.9, 1.0, 1.25), segs=8, rings=5)
    k.limb("HeadTip", (0, -0.1, 1.36), (0, 0.04, 1.48), 0.06, 0.005, water, "Head", segs=6)   # голова-капля
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.035, 0.02, 0.025), (0.045 * s, -0.235, 1.25), m["rift"], "Head")
    for i, (pts, o, bone) in enumerate([([(0, 0), (0.04, 0.08), (-0.02, 0.16), (0.03, 0.24)], (0.04, -0.21, 0.78), "Chest"),
                                        ([(0, 0), (-0.05, 0.06), (0.0, 0.12)], (-0.06, -0.22, 0.9), "Chest")]):
        k.crack(f"Rift{i}", pts, o, (1, 0, 0), (0, 0, 1), m["rift"], bone, width=0.012, depth=0.012)
    for i, (pts, o, bone) in enumerate([([(0, 0), (0.06, 0.1), (0.02, 0.2)], (-0.12, -0.2, 0.86), "Chest"),
                                        ([(0, 0), (-0.04, 0.08), (0.02, 0.14)], (0.1, -0.2, 1.0), "Chest"),
                                        ([(0, 0), (0.03, 0.06), (0.0, 0.12)], (-0.05, -0.22, 1.2), "Head")]):
        k.crack(f"Shine{i}", pts, o, (1, 0, 0), (0, 0, 1), shine, bone, width=0.02, depth=0.015)
    # Руки-струи
    for side, s in SIDES:
        k.limb(f"UpperArm.{side}", (0.15 * s, -0.06, 1.0), (0.32 * s, -0.16, 0.92), 0.06, 0.045, water, f"UpperArm.{side}", segs=6)
        k.limb(f"ForeArm.{side}", (0.32 * s, -0.16, 0.92), (0.46 * s, -0.3, 0.9), 0.045, 0.03, water, f"ForeArm.{side}", segs=6)
        k.crack(f"ArmShine.{side}", [(0, 0), (0.1, -0.02), (0.2, 0.0)], (0.2 * s, -0.14, 0.98), (s, -0.4, 0), (0, 0, 1), shine,
                f"UpperArm.{side}", width=0.016, depth=0.012)
        for j in (-1, 0, 1):
            k.limb(f"Finger.{side}{j}", (0.46 * s, -0.3, 0.9), (0.52 * s + 0.02 * j, -0.38, 0.9 + 0.04 * j), 0.02, 0.004,
                   water, f"ForeArm.{side}", segs=4)
    return k.join_parts("HalfSpiritMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Orb": ((0, 0, 0.02), (0, 0, 0.6), "Root"),
    "Spirit": ((0, -0.04, 0.6), (0, -0.06, 0.86), "Orb"),
    "Chest": ((0, -0.06, 0.86), (0, -0.06, 1.04), "Spirit"),
    "Head": ((0, -0.08, 1.04), (0, -0.1, 1.38), "Chest"),
}
for _side, _s in SIDES:
    BONES.update({
        f"UpperArm.{_side}": ((0.15 * _s, -0.06, 1.0), (0.32 * _s, -0.16, 0.92), "Chest"),
        f"ForeArm.{_side}": ((0.32 * _s, -0.16, 0.92), (0.46 * _s, -0.3, 0.9), f"UpperArm.{_side}"),
    })

STANCE = {"Spirit": (14, 0, 0), "Chest": (10, 0, 0), "Head": (-10, 0, 0)}
LOC_BONES = ("Root", "Orb", "Spirit")
SCALED = ("Spirit",)


def stance():
    return Pose(STANCE)


def idle(t):
    """Рвётся наружу (3 сек): тело извивается, руки-струи тянутся вперёд и бьют по клетке, сфера вздрагивает."""
    p = stance()
    p.add("Spirit", z=8 * wave(t, 1), x=4 * wave(t, 2))
    p.add("Chest", y=10 * wave(t, 1, 0.2), z=-6 * wave(t, 1, 0.1))
    p.add("Head", y=-12 * wave(t, 1, 0.35), x=-6 * pulse(t, 0.5, 0.06))
    for side, s in SIDES:
        ph = 0.0 if s < 0 else 0.5
        p.add(f"UpperArm.{side}", x=-14 * wave(t, 1, ph), z=8 * wave(t, 2, ph) * s)
        p.add(f"ForeArm.{side}", x=-12 * wave(t, 1, ph + 0.15))
    jolt = pulse(t, 0.3, 0.04) + pulse(t, 0.72, 0.04)
    p.add("Orb", z=3 * jolt)
    p.size("Spirit", 1.0 + 0.04 * wave(t, 2))
    return p


def walk(t):
    """Катит сферу (0.8 сек): сфера переваливается, дух тянет её руками вперёд."""
    p = stance()
    a = wave(t, 1)
    p.add("Orb", z=6 * a, x=-4)
    p.move("Orb", z=0.03 * max(0.0, wave(t, 2)))
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=-30 + 16 * (a if s < 0 else -a))
    p.add("Spirit", x=10)
    return p


def attack(t):
    """Выплеск (0.8 сек): дух откидывается назад, руки разведены → хлёст руками по дуге перед собой
    (к 0.4 сек) → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.24, 0.4, 0.58, 1.0]
    for bone, *keys in [
        ("Spirit", (-10, 20, 0), (24, -16, 0), (20, -12, 0)),
        ("Chest", (-10, 14, 0), (18, -14, 0), (14, -10, 0)),
        ("Head", (-20, 0, 0), (0, 0, 0), (-4, 0, 0)),
        ("UpperArm.R", (30, 0, 30), (-40, 0, -20), (-30, 0, -14)),
        ("UpperArm.L", (30, 0, -30), (-40, 0, 20), (-30, 0, 14)),
        ("ForeArm.R", (-30, 0, 0), (0, 0, 0), (-6, 0, 0)),
        ("ForeArm.L", (-30, 0, 0), (0, 0, 0), (-6, 0, 0)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.size("Spirit", track(t, [(0, 1.0), (K[1], 0.95), (K[2], 1.15), (K[3], 1.08), (1, 1.0)]))
    return p


def hit(t):
    """Получил удар (0.4 сек): дух отшатывается в сферу, вода колышется, сфера звенит."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.add("Spirit", x=-20 * snap)
    p.add("Head", x=-20 * whip)
    p.add("UpperArm.R", x=20 * whip)
    p.add("UpperArm.L", x=20 * whip)
    p.add("Orb", z=4 * whip)
    p.size("Spirit", 1.0 - 0.12 * snap)
    return p


def death(t):
    """Улетает (1.2 сек): дух вытягивается вверх из сферы, тает и исчезает; пустая сфера остаётся."""
    p = stance()
    up = track(t, [(0, 0), (0.25, 0.1), (1, 1)])
    p.move("Spirit", z=0.9 * up)
    p.size("Spirit", max(0.02, 1.0 - 0.95 * track(t, [(0, 0), (0.4, 0.1), (1, 1)])))
    p.add("Spirit", x=-10 * up)
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=-60 * up, z=20 * up * s)
    p.add("Orb", z=6 * pulse(t, 0.2, 0.08))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("HalfSpirit")
    body = build_mesh()
    rig = k.build_armature("HalfSpirit", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Hit", 12, hit, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Death", 36, death, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "half_spirit")
