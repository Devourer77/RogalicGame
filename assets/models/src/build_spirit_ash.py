# Пепельник — обычный дух пепла и дыма (акт 2, Тракт), ~1.4 м. Колонна густого серого дыма: сверху сутулая
# голова из сажи без лица (как капюшон), книзу дым тает в закрученный хвост — ног нет. Длинные руки из дыма
# с рваными концами, как клочья ткани. Внутри тлеют угольки, с него сыплются хлопья пепла; в груди —
# бирюзовые трещины Раскола, два бирюзовых огонька глаз. Не воронка (это Пепельный вихрь).
# Смотрит в -Y. Анимации: Idle, Walk, Attack (выдох пепла вперёд), Attack2 (завеса — дым вокруг), Hit,
# Death (покорение — рассеивается дымом).
# Запуск: python3 build_spirit_ash.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))
TAIL = (("Tail1", 0.62, 0.36, 0.17, 0.12), ("Tail2", 0.36, 0.16, 0.12, 0.07), ("Tail3", 0.16, 0.02, 0.07, 0.015))


def build_mesh():
    v = a2.volcano_mats()
    smoke = k.mat("SA_Smoke", (0.6, 0.58, 0.56), rough=0.95)
    smoke_d = k.mat("SA_SmokeDark", (0.44, 0.42, 0.41), rough=0.95)
    soot = k.mat("SA_Soot", (0.2, 0.19, 0.19), rough=0.95)
    flake = k.mat("SA_Flake", (0.82, 0.8, 0.77), rough=0.9)
    # Грудь и плечи из дыма
    k.limb("Waist", (0, 0.0, 0.62), (0, -0.02, 0.86), 0.17, 0.22, smoke, "Hips", segs=8)
    k.sphere("Chest", 0.24, (0, -0.02, 1.0), smoke, "Chest", scale=(1.15, 0.85, 0.95), segs=8, rings=5)
    k.sphere("Hunch", 0.18, (0, 0.08, 1.14), smoke_d, "Chest", scale=(1.3, 1.0, 0.8), segs=7, rings=4)
    k.crack("ChestRift", [(-0.1, 0.06), (-0.03, 0.0), (0.02, 0.05), (0.07, -0.03), (0.12, 0.02)], (0, -0.22, 1.0),
            (1, 0, 0), (0, 0, 1), v["rift"], "Chest", width=0.022, depth=0.02)
    k.crack("ChestRift2", [(0, 0), (0.02, -0.06), (-0.02, -0.12)], (0.0, -0.22, 0.98), (1, 0, 0), (0, 0, 1), v["rift"],
            "Chest", width=0.018, depth=0.02)
    # Голова из сажи, сутулая, без лица
    k.sphere("Head", 0.14, (0, -0.08, 1.24), soot, "Head", scale=(1.0, 1.05, 1.0), segs=8, rings=5)
    k.sphere("HoodTop", 0.11, (0.02, -0.02, 1.34), soot, "Head", scale=(1.1, 1.0, 0.8), segs=7, rings=4)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.04, 0.02, 0.025), (0.05 * s, -0.215, 1.24), v["rift"], "Head", rot=(0, 0, -15 * s))
    # Угольки внутри дыма
    for i, (x, y, z, bone) in enumerate([(0.12, -0.18, 1.1, "Chest"), (-0.14, -0.16, 0.92, "Chest"), (0.06, -0.2, 0.8, "Hips"),
                                         (-0.08, -0.12, 0.7, "Hips"), (0.16, 0.0, 1.16, "Chest")]):
        k.box(f"Ember{i}", (0.025, 0.025, 0.025), (x, y, z), v["ember"], bone)
    # Хвост дыма вместо ног — закручивается
    for name, z0, z1, r0, r1 in TAIL:
        k.limb(name, (0, 0.0, z0), (0, 0.0, z1), r0, r1, smoke if name != "Tail3" else smoke_d, name, segs=7)
    # Хлопья пепла вокруг (кость Flakes)
    for i in range(8):
        a = math.tau * i / 8
        r = 0.32 + 0.06 * (i % 3)
        k.box(f"Flake{i}", (0.03, 0.03, 0.01), (r * math.cos(a), r * math.sin(a), 0.3 + 0.12 * (i % 4)), flake, "Flakes",
              rot=(30 * i, 20 * i, 0))
    # Руки из дыма с рваными концами
    for side, s in SIDES:
        k.limb(f"UpperArm.{side}", (0.22 * s, -0.02, 1.1), (0.4 * s, -0.08, 0.92), 0.08, 0.06, smoke, f"UpperArm.{side}", segs=7)
        k.limb(f"ForeArm.{side}", (0.4 * s, -0.08, 0.92), (0.52 * s, -0.16, 0.7), 0.06, 0.045, smoke, f"ForeArm.{side}", segs=7)
        for j in range(4):
            dx = (j - 1.5) * 0.035
            k.limb(f"Wisp.{side}{j}", (0.52 * s + dx * s, -0.16, 0.7), (0.56 * s + dx * 1.6 * s, -0.24 + 0.02 * j, 0.52 - 0.03 * j),
                   0.03, 0.004, smoke_d if j % 2 else smoke, f"Hand.{side}", segs=5)
    return k.join_parts("SpiritAshMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Hips": ((0, 0, 0.62), (0, 0, 0.86), "Root"),
    "Chest": ((0, 0, 0.86), (0, 0, 1.14), "Hips"),
    "Head": ((0, -0.04, 1.12), (0, -0.06, 1.42), "Chest"),
    "Flakes": ((0, 0, 0.3), (0, 0, 0.7), "Hips"),
}
_parent = "Hips"
for _name, _z0, _z1, _r0, _r1 in TAIL:
    BONES[_name] = ((0, 0, _z0), (0, 0, _z1), _parent)
    _parent = _name
for _side, _s in SIDES:
    BONES.update({
        f"UpperArm.{_side}": ((0.22 * _s, -0.02, 1.1), (0.4 * _s, -0.08, 0.92), "Chest"),
        f"ForeArm.{_side}": ((0.4 * _s, -0.08, 0.92), (0.52 * _s, -0.16, 0.7), f"UpperArm.{_side}"),
        f"Hand.{_side}": ((0.52 * _s, -0.16, 0.7), (0.56 * _s, -0.24, 0.52), f"ForeArm.{_side}"),
    })

STANCE = {"Hips": (8, 0, 0), "Chest": (10, 0, 0), "Head": (-6, 0, 0), "Tail1": (-10, 0, 8), "Tail2": (-14, 0, 14),
          "Tail3": (-10, 0, 22)}
STANCE_LOC = {"Hips": (0, 0, 0.08)}
SCALED = ("Flakes",)


def stance():
    return Pose(STANCE, STANCE_LOC)


def tail(p, t, amp=8.0, speed=1.0):
    for i, (name, *_) in enumerate(TAIL):
        p.add(name, z=amp * (1 + 0.5 * i) * wave(t, speed, -0.15 * i), x=amp * 0.4 * wave(t, speed, 0.25 - 0.1 * i))


def idle(t):
    """Покой (3 сек): дым медленно колышется, хвост вьётся, руки плавают, хлопья пепла кружат."""
    p = stance()
    p.move("Hips", z=0.08 + 0.03 * wave(t, 2), x=0.02 * wave(t, 1))
    p.add("Chest", y=8 * wave(t, 1, 0.2), z=3 * wave(t, 1))
    p.add("Head", y=k.track(t, [(0, 0), (0.3, 0), (0.36, -18), (0.6, -18), (0.66, 12), (0.9, 12), (1, 0)]))
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=-8 * wave(t, 1, 0.1 if s < 0 else 0.6), z=6 * wave(t, 2) * s)
        p.add(f"ForeArm.{side}", x=-6 * wave(t, 1, 0.3 if s < 0 else 0.8))
    tail(p, t)
    p.add("Flakes", y=360 * t)
    return p


def walk(t):
    """Плывёт (0.8 сек): наклон вперёд, хвост вытянут назад и вьётся быстрее."""
    p = stance()
    p.move("Hips", z=0.1 + 0.02 * wave(t, 2))
    p.add("Hips", x=14)
    tail(p, t, amp=12, speed=2)
    p.add("Tail1", x=20)
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=14, z=10 * s)
    p.add("Flakes", y=360 * t)
    return p


def attack(t):
    """Выдох пепла (0.8 сек): вбирает дым — руки к груди → выбрасывает обе руки вперёд (к 0.4 сек) → опадает."""
    p = Pose({}, {})
    K = [0.0, 0.24, 0.4, 0.58, 1.0]
    for bone, *keys in [
        ("Chest", (-12, 0, 0), (20, 0, 0), (16, 0, 0)),
        ("Head", (-10, 0, 0), (6, 0, 0), (2, 0, 0)),
        ("UpperArm.R", (30, 0, -20), (-60, 0, 10), (-50, 0, 10)),
        ("UpperArm.L", (30, 0, 20), (-60, 0, -10), (-50, 0, -10)),
        ("ForeArm.R", (-60, 0, 0), (0, 0, 0), (-6, 0, 0)),
        ("ForeArm.L", (-60, 0, 0), (0, 0, 0), (-6, 0, 0)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.move("Hips", z=0.08 + track(t, [(0, 0), (K[1], 0.05), (K[2], -0.02), (1, 0)]))
    p.move("Root", y=track(t, [(0, 0), (K[2], -0.08), (1, 0)]))
    p.size("Flakes", track(t, [(0, 1.0), (K[2], 1.6), (1, 1.0)]))
    tail(p, t, amp=10, speed=1)
    return p


def attack2(t):
    """Завеса (0.9 сек): руки разводятся широко, дым раздувается вокруг, хлопья пепла разлетаются кругом."""
    p = stance()
    veil = track(t, [(0, 0), (0.3, 1), (0.7, 1), (1, 0)])
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=-20 * veil, z=50 * veil * s)
        p.add(f"ForeArm.{side}", x=20 * veil)
    p.add("Chest", x=-10 * veil)
    p.add("Head", x=10 * veil)
    p.size("Flakes", 1.0 + 1.2 * veil)
    p.add("Flakes", y=360 * t)
    p.move("Hips", z=0.08 + 0.06 * veil)
    tail(p, t, amp=10, speed=2)
    return p


def hit(t):
    """Получил удар (0.4 сек): дым разрывает и снова стягивает, голова откидывается."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    p.move("Root", y=0.08 * snap)
    p.add("Chest", x=-18 * snap)
    p.add("Head", x=-20 * snap)
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", z=24 * snap * s)
    p.size("Flakes", 1.0 + 0.8 * snap)
    tail(p, t, amp=14 * snap, speed=2)
    return p


def death(t):
    """Покорение (1.2 сек): дым оседает и рассеивается, голова опускается, хлопья пепла падают."""
    p = stance()
    fade = track(t, [(0, 0), (0.3, 0.2), (1, 1)])
    p.size("Hips", max(0.02, 1.0 - 0.95 * fade))
    p.move("Hips", z=0.08 - 0.3 * fade)
    p.add("Chest", x=20 * fade)
    p.add("Head", x=20 * fade)
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=30 * fade, z=-20 * fade * s)
    p.size("Flakes", 1.0 + 0.5 * fade)
    p.move("Flakes", z=-0.3 * fade)
    return p


def build(glb_path, blend_path=None):
    k.start_scene("SpiritAsh")
    body = build_mesh()
    rig = k.build_armature("SpiritAsh", BONES)
    body.parent = rig
    sc = SCALED + ("Hips",)
    lb = ("Root", "Hips", "Flakes")
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=lb, scale_bones=sc)
    k.bake(rig, "Walk", 24, walk, cyclic=True, loc_bones=lb, scale_bones=sc)
    k.bake(rig, "Attack", 24, attack, loc_bones=lb, scale_bones=sc)
    k.bake(rig, "Attack2", 27, attack2, loc_bones=lb, scale_bones=sc)
    k.bake(rig, "Hit", 12, hit, loc_bones=lb, scale_bones=sc)
    k.bake(rig, "Death", 36, death, loc_bones=lb, scale_bones=sc)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "spirit_ash")
