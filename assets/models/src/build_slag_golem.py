# Шлаковый голем — тварь вулкана (акт 2, Тракт), ~1.8 м. Сутулая глыба остывшего чёрного шлака и базальта:
# короткие толстые ноги, очень длинные руки с огромными каменными кулаками почти до земли, маленькая
# голова утоплена в плечи, бирюзовые глаза. Сквозь трещины груди и суставов светится оранжевое
# лавовое ядро. Камень тёмный (не светло-серый, как у огра), тело в пределах клетки — наружу только руки.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (удар кулаком), Hit, Death (оседает глыбой — в игре
# на его месте остаётся камень-преграда).
# Запуск: python3 build_slag_golem.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))


def build_mesh():
    v = a2.volcano_mats()
    rock = v["slag"]
    rock2 = v["basalt"]
    # Лавовое ядро в груди (кость Core пульсирует) и глыбы поверх с щелями
    k.sphere("Core", 0.22, (0, -0.02, 1.24), v["lava"], "Core", scale=(1.1, 0.8, 1.0), segs=7, rings=5)
    for i, (x, y, z, sx, sz, rot) in enumerate([
        (-0.15, -0.2, 1.38, 0.22, 0.2, (8, -10, 12)), (0.15, -0.2, 1.38, 0.22, 0.2, (8, 10, -12)),
        (-0.17, -0.22, 1.13, 0.2, 0.2, (-6, -8, -10)), (0.16, -0.22, 1.12, 0.2, 0.2, (-6, 8, 8)),
        (0.0, -0.25, 1.25, 0.12, 0.1, (0, 0, 45)),
    ]):
        a2.rock(f"ChestRock{i}", (sx, 0.14, sz), (x, y, z), rock if i % 2 == 0 else rock2, "Chest", rot=rot)
    a2.rock("Back", (0.6, 0.34, 0.5), (0, 0.08, 1.28), rock, "Chest", rot=(10, 0, 0))
    a2.rock("Hump", (0.46, 0.3, 0.24), (0, 0.12, 1.56), rock2, "Chest", rot=(18, 0, 4))
    # Живот и таз
    a2.rock("Belly", (0.46, 0.32, 0.28), (0, -0.02, 0.92), rock2, "Spine", rot=(0, 0, 4))
    a2.rock("BellyFront", (0.3, 0.12, 0.2), (0, -0.18, 0.94), rock, "Spine", rot=(-8, 0, -6))
    a2.rock("Pelvis", (0.42, 0.3, 0.2), (0, 0, 0.74), rock, "Hips")
    k.crack("BellyLava", [(-0.1, 0.0), (-0.02, 0.05), (0.06, -0.02), (0.12, 0.04)], (0.0, -0.245, 0.96), (1, 0, 0),
            (0, 0, 1), v["lava"], "Spine", width=0.03, depth=0.03)
    # Голова — маленькая, утоплена между плечами
    a2.rock("Head", (0.22, 0.2, 0.18), (0, -0.2, 1.6), rock2, "Head", rot=(-10, 0, 0))
    a2.rock("Brow", (0.26, 0.08, 0.07), (0, -0.3, 1.66), rock, "Head", rot=(-20, 0, 0))
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.05, 0.02, 0.025), (0.055 * s, -0.31, 1.61), v["rift"], "Head")
    k.crack("HeadRift", [(0, 0), (0.04, 0.05), (0.08, 0.03)], (-0.06, -0.31, 1.68), (1, 0, 0), (0, 0, 1), v["rift"],
            "Head", width=0.012, depth=0.012)
    for side, s in SIDES:
        # Плечи-валуны
        a2.rock(f"Shoulder.{side}", (0.3, 0.32, 0.28), (0.4 * s, 0.0, 1.5), rock, "Chest", rot=(10, 0, 20 * s))
        k.crack(f"ShoulderLava.{side}", [(0, 0), (0.05, 0.04), (0.1, 0.0)], (0.33 * s, -0.17, 1.42), (1, 0, 0), (0, 0, 1),
                v["lava"], "Chest", width=0.025, depth=0.025)
        k.crack(f"ShoulderRift.{side}", [(0, 0), (0.04, -0.05), (0.07, -0.09)], (0.46 * s, -0.16, 1.56), (1, 0, 0),
                (0, 0, 1), v["rift"], "Chest", width=0.012, depth=0.012)
        # Руки: длинные, глыбами
        a2.rock(f"UpperArm.{side}", (0.2, 0.2, 0.36), (0.5 * s, 0.0, 1.18), rock2, f"UpperArm.{side}", rot=(0, 0, -6 * s))
        k.sphere(f"Elbow.{side}", 0.09, (0.52 * s, 0.0, 0.98), v["lava"], f"ForeArm.{side}", segs=5, rings=3)
        a2.rock(f"ForeArm.{side}", (0.22, 0.22, 0.34), (0.53 * s, -0.02, 0.8), rock, f"ForeArm.{side}", rot=(6, 0, 4 * s))
        a2.rock(f"Fist.{side}", (0.3, 0.3, 0.28), (0.54 * s, -0.05, 0.5), rock2, f"Hand.{side}", rot=(8, 0, 10 * s))
        a2.rock(f"Knuckles.{side}", (0.26, 0.12, 0.12), (0.54 * s, -0.2, 0.46), rock, f"Hand.{side}")
        k.crack(f"FistRift.{side}", [(0, 0), (0.06, 0.03), (0.1, -0.02)], (0.5 * s, -0.205, 0.54), (1, 0, 0), (0, 0, 1),
                v["rift"], f"Hand.{side}", width=0.012, depth=0.012)
        # Ноги: короткие толстые
        a2.rock(f"Thigh.{side}", (0.22, 0.24, 0.26), (0.17 * s, 0, 0.56), rock2, f"Thigh.{side}")
        k.sphere(f"Knee.{side}", 0.08, (0.18 * s, -0.08, 0.4), v["lava"], f"Shin.{side}", segs=5, rings=3)
        a2.rock(f"Shin.{side}", (0.24, 0.26, 0.3), (0.18 * s, -0.01, 0.22), rock, f"Shin.{side}")
        a2.rock(f"Foot.{side}", (0.26, 0.34, 0.1), (0.18 * s, -0.06, 0.05), rock2, f"Foot.{side}")
    return k.join_parts("SlagGolemMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.2), None),
    "Hips": ((0, 0, 0.68), (0, 0, 0.8), "Root"),
    "Spine": ((0, 0, 0.8), (0, 0, 1.04), "Hips"),
    "Chest": ((0, 0, 1.04), (0, 0, 1.6), "Spine"),
    "Core": ((0, -0.04, 1.06), (0, -0.04, 1.42), "Chest"),
    "Head": ((0, -0.14, 1.52), (0, -0.14, 1.72), "Chest"),
}
for _side, _s in SIDES:
    BONES.update({
        f"UpperArm.{_side}": ((0.44 * _s, 0.0, 1.42), (0.52 * _s, 0.0, 0.98), "Chest"),
        f"ForeArm.{_side}": ((0.52 * _s, 0.0, 0.98), (0.54 * _s, -0.03, 0.64), f"UpperArm.{_side}"),
        f"Hand.{_side}": ((0.54 * _s, -0.03, 0.64), (0.54 * _s, -0.05, 0.36), f"ForeArm.{_side}"),
        f"Thigh.{_side}": ((0.17 * _s, 0, 0.7), (0.18 * _s, -0.02, 0.4), "Hips"),
        f"Shin.{_side}": ((0.18 * _s, -0.02, 0.4), (0.18 * _s, 0, 0.1), f"Thigh.{_side}"),
        f"Foot.{_side}": ((0.18 * _s, 0, 0.1), (0.18 * _s, -0.2, 0.03), f"Shin.{_side}"),
    })

STANCE = {
    "Hips": (2, -6, 0), "Spine": (10, -4, 0), "Chest": (14, -4, 0), "Head": (-24, 8, 0),
    "Thigh.L": (-16, 0, -6), "Shin.L": (18, 0, 0), "Foot.L": (-2, 0, 0),
    "Thigh.R": (6, 0, 8), "Shin.R": (14, 0, 0), "Foot.R": (-20, 0, 0),
    "UpperArm.R": (-12, 0, 10), "ForeArm.R": (-16, 0, 0), "UpperArm.L": (-16, 0, -10), "ForeArm.L": (-20, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.03)}
SCALED = ("Core",)


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3 сек): стоит камнем, тяжело дышит, лава в груди пульсирует, голова медленно поворачивается,
    кулак сжимается."""
    p = stance()
    br = wave(t, 1.5)
    p.move("Hips", z=-0.01 * (br * 0.5 + 0.5))
    p.add("Spine", x=2 * br)
    p.add("Chest", y=k.track(t, [(0, 0), (0.3, 0), (0.4, -10), (0.65, -10), (0.75, 6), (0.9, 6), (1, 0)]))
    p.add("Head", y=k.track(t, [(0, 0), (0.35, 0), (0.45, -16), (0.7, -16), (0.8, 8), (0.95, 8), (1, 0)]))
    p.size("Core", 1.0 + 0.06 * wave(t, 3))
    p.add("Hand.R", x=-8 * pulse(t, 0.55, 0.08))
    p.add("UpperArm.L", x=2 * wave(t, 1, 0.4))
    return p


def walk(t):
    """Тяжёлая поступь (1.1 сек): переваливается, кулаки волочатся почти по земле."""
    p = Pose(STANCE)
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.1)
    p.move("Hips", z=-0.05 + 0.03 * bounce, x=0.04 * a)
    p.add("Hips", y=-6 + 8 * a, z=6 * a)
    p.set("Thigh.R", -4 - 24 * a, 0, 8)
    p.set("Thigh.L", -4 + 24 * a, 0, -6)
    p.set("Shin.R", 12 + 28 * max(0.0, c), 0, 0)
    p.set("Shin.L", 12 + 28 * max(0.0, -c), 0, 0)
    p.add("Chest", y=-6 * a, x=2 * bounce)
    p.add("UpperArm.R", x=-12 * a)
    p.add("UpperArm.L", x=12 * a)
    p.add("Head", x=-2 * bounce)
    return p


def attack(t):
    """Удар кулаком (1.0 сек): правый кулак заносится над головой → обрушивается вниз-вперёд (к 0.4 сек),
    корпус наваливается следом → тяжёлый возврат."""
    p = Pose({}, {})
    K = [0.0, 0.26, 0.4, 0.62, 1.0]
    for bone, *keys in [
        ("Spine", (-6, 12, 0), (22, -6, 0), (20, -6, 0)),
        ("Chest", (-6, 14, 0), (18, -8, 0), (16, -8, 0)),
        ("Head", (-14, 0, 0), (-30, 0, 0), (-28, 0, 0)),
        ("UpperArm.R", (-170, 0, 16), (-56, 0, 4), (-50, 0, 4)),
        ("ForeArm.R", (-30, 0, 0), (-4, 0, 0), (-8, 0, 0)),
        ("UpperArm.L", (-30, 0, -26), (10, 0, -16), (8, 0, -14)),
        ("Thigh.L", (-14, 0, -6), (-30, 0, -6), (-28, 0, -6)),
        ("Shin.L", (16, 0, 0), (36, 0, 0), (34, 0, 0)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.move("Hips", z=track(t, [(0, -0.03), (K[1], -0.01), (K[2], -0.12), (K[3], -0.1), (1, -0.03)]))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.05), (K[2], -0.1), (K[3], -0.1), (1, 0)]))
    p.size("Core", track(t, [(0, 1.0), (K[1], 1.1), (K[2], 1.2), (1, 1.0)]))
    return p


def hit(t):
    """Получил удар (0.5 сек): едва покачнулся — глыба тяжёлая; голова дёргается позже."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.move("Root", y=0.04 * snap)
    p.add("Spine", x=-8 * snap, y=6 * snap)
    p.add("Head", x=-14 * whip, z=6 * whip)
    p.add("UpperArm.R", x=10 * whip)
    p.add("UpperArm.L", x=12 * whip)
    p.size("Core", 1.0 + 0.15 * snap)
    return p


def death(t):
    """Гибель (1.4 сек): лава гаснет, голем оседает на колени, сгибается и застывает глыбой."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.5, 0.75, 1.0]
    for bone, *keys in [
        ("Spine", (-8, 6, 0), (24, 0, 0), (40, 0, 0), (40, 0, 0)),
        ("Chest", (-6, 6, 0), (24, 0, 0), (36, 0, 0), (36, 0, 0)),
        ("Head", (-30, -10, 0), (0, 0, 0), (10, 0, 0), (10, 0, 0)),
        ("UpperArm.R", (10, 0, 20), (-20, 0, 24), (-30, 0, 30), (-30, 0, 30)),
        ("UpperArm.L", (14, 0, -24), (-20, 0, -24), (-30, 0, -30), (-30, 0, -30)),
        ("ForeArm.R", (-20, 0, 0), (-40, 0, 0), (-60, 0, 0), (-60, 0, 0)),
        ("ForeArm.L", (-20, 0, 0), (-40, 0, 0), (-60, 0, 0), (-60, 0, 0)),
        ("Thigh.L", (-10, 0, -8), (-90, 0, -10), (-100, 0, -10), (-100, 0, -10)),
        ("Shin.L", (20, 0, 0), (120, 0, 0), (130, 0, 0), (130, 0, 0)),
        ("Thigh.R", (-14, 0, 10), (-90, 0, 12), (-100, 0, 12), (-100, 0, 12)),
        ("Shin.R", (20, 0, 0), (120, 0, 0), (130, 0, 0), (130, 0, 0)),
    ]:
        a2.keyed_end(p, t, K, STANCE, bone, *keys)
    p.move("Hips", z=track(t, [(0, -0.03), (K[1], 0.0), (K[2], -0.4), (K[3], -0.46), (1, -0.46)]))
    p.size("Core", track(t, [(0, 1.0), (K[1], 1.2), (K[3], 0.6), (1, 0.5)]))
    p.add("Head", x=6 * pulse(t, 0.92, 0.04))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("SlagGolem")
    body = build_mesh()
    rig = k.build_armature("SlagGolem", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 33, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 30, attack, scale_bones=SCALED)
    k.bake(rig, "Hit", 15, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 42, death, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "slag_golem")
