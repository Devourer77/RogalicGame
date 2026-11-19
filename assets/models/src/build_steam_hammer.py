# Паровой молот — тяжёлый механизм лаборатории (акт 2, Подземье), ~2.0 м. Сутулый корпус из чернёного
# клёпаного железа с бронзовыми накладками, медный котёл на спине с двумя манометрами, на плечах
# клапаны, которые светятся, когда набран пар. Правая рука — молот-кувалда на поршне, левая — зажим.
# Стороны — как на принятом листе Gemini (молот на виде спереди слева = правая рука).
# Смотрит в -Y. Анимации: Idle, Walk, Attack (удар молотом), Attack2 (набирает пар), Hit, Death.
# Запуск: python3 build_steam_hammer.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))
SY = 0.8


def build_mesh():
    m = a2.mech_mats()
    # Таз и корпус: широкая «бочка» груди, сутулая, голова утоплена
    k.barrel("Pelvis", 0.24, 0.28, 0.78, 0.96, m["iron_d"], "Hips", segs=8, sy=SY)
    k.barrel("Waist", 0.26, 0.34, 0.96, 1.2, m["iron"], "Spine", segs=8, sy=SY)
    k.barrel("Chest", 0.36, 0.42, 1.2, 1.62, m["iron"], "Chest", segs=9, sy=SY)
    k.barrel("ChestTop", 0.42, 0.3, 1.62, 1.76, m["iron_d"], "Chest", segs=9, sy=SY)
    k.box("ChestPlate", (0.42, 0.06, 0.32), (0, -0.33, 1.44), m["bronze_d"], "Chest", rot=(-6, 0, 0))
    k.box("BellyPlate", (0.3, 0.05, 0.16), (0, -0.27, 1.06), m["bronze_d"], "Spine")
    for i in range(5):
        for z in (1.26, 1.6):
            k.box(f"Rivet{i}_{z}", (0.03, 0.03, 0.03), (-0.16 + i * 0.08, -0.365, z), m["iron_d"], "Chest")
    # Голова — низкий шлем-колпак со щелью
    k.barrel("Head", 0.15, 0.12, 1.64, 1.8, m["iron_d"], "Head", segs=8, loc=(0, -0.18))
    k.box("Visor", (0.18, 0.03, 0.035), (0, -0.33, 1.72), m["lamp"], "Head")
    # Котёл на спине и манометры
    k.barrel("Boiler", 0.24, 0.24, 1.18, 1.78, m["copper"], "Chest", segs=10, loc=(0, 0.34))
    k.barrel("BoilerCap", 0.24, 0.16, 1.78, 1.86, m["copper"], "Chest", segs=10, loc=(0, 0.34))
    for i, z in enumerate((1.3, 1.66)):
        k.barrel(f"BoilerBand{i}", 0.25, 0.25, z, z + 0.04, m["iron_d"], "Chest", segs=10, loc=(0, 0.34))
    for side, s in SIDES:
        x = 0.1 * s
        k.limb(f"GaugeStem.{side}", (x, 0.3, 1.86), (x, 0.3, 1.93), 0.015, 0.015, m["iron_d"], "Chest", segs=4)
        k.limb(f"GaugeRim.{side}", (x, 0.27, 1.99), (x, 0.24, 1.99), 0.07, 0.07, m["iron_d"], "Chest", segs=7)
        k.limb(f"GaugeFace.{side}", (x, 0.24, 1.99), (x, 0.235, 1.99), 0.058, 0.058, m["gauge"], "Chest", segs=7)
        # Клапаны на плечах — светятся (пар набран) + клубы пара (кости Steam.*)
        k.barrel(f"Valve.{side}", 0.06, 0.05, 1.78, 1.86, m["iron"], "Chest", segs=6, loc=(0.38 * s, 0.05))
        k.barrel(f"ValveGlow.{side}", 0.045, 0.045, 1.86, 1.9, m["hot"], "Chest", segs=6, loc=(0.38 * s, 0.05))
        k.sphere(f"Puff.{side}", 0.1, (0.38 * s, 0.05, 2.0), m["steam"], f"Steam.{side}", segs=6, rings=4)
        k.sphere(f"Puff2.{side}", 0.07, (0.42 * s, 0.08, 2.12), m["steam"], f"Steam.{side}", segs=5, rings=3)
        # Наплечники и руки
        k.sphere(f"Shoulder.{side}", 0.17, (0.42 * s, 0.0, 1.62), m["iron"], "Chest", scale=(1.0, 1.0, 0.85), segs=7, rings=4)
        k.box(f"Pauldron.{side}", (0.3, 0.3, 0.08), (0.44 * s, 0.0, 1.74), m["bronze_d"], "Chest", rot=(0, 18 * s, 0))
        k.limb(f"UpperArm.{side}", (0.46 * s, 0, 1.56), (0.5 * s, 0, 1.22), 0.08, 0.075, m["iron_d"], f"UpperArm.{side}", segs=6)
        k.sphere(f"Elbow.{side}", 0.08, (0.5 * s, 0, 1.22), m["bronze_d"], f"ForeArm.{side}", segs=6, rings=4)
        # Ноги — короткие толстые
        k.limb(f"Thigh.{side}", (0.18 * s, 0, 0.82), (0.2 * s, -0.02, 0.48), 0.12, 0.11, m["iron_d"], f"Thigh.{side}", segs=7)
        k.box(f"KneePlate.{side}", (0.2, 0.08, 0.16), (0.2 * s, -0.12, 0.48), m["bronze_d"], f"Shin.{side}")
        k.limb(f"Shin.{side}", (0.2 * s, -0.02, 0.46), (0.2 * s, 0, 0.12), 0.11, 0.13, m["iron"], f"Shin.{side}", segs=7)
        k.box(f"Foot.{side}", (0.22, 0.32, 0.12), (0.2 * s, -0.07, 0.06), m["iron_d"], f"Foot.{side}")
    # Правая рука — поршень и молот
    k.limb("PistonR", (-0.5, 0, 1.22), (-0.52, -0.04, 0.94), 0.07, 0.07, m["steel"], "ForeArm.R", segs=6)
    k.limb("SleeveR", (-0.5, 0, 1.2), (-0.51, -0.02, 1.06), 0.1, 0.1, m["bronze_d"], "ForeArm.R", segs=7)
    k.box("HammerHead", (0.28, 0.34, 0.26), (-0.52, -0.06, 0.78), m["steel"], "Hand.R")
    k.box("HammerFace", (0.3, 0.36, 0.06), (-0.52, -0.06, 0.63), m["iron_d"], "Hand.R")
    k.box("HammerTop", (0.22, 0.28, 0.06), (-0.52, -0.06, 0.93), m["iron_d"], "Hand.R")
    # Левая рука — зажим
    k.limb("ForeL", (0.5, 0, 1.22), (0.52, -0.06, 0.94), 0.07, 0.065, m["iron"], "ForeArm.L", segs=6)
    k.box("ClampBase", (0.12, 0.12, 0.08), (0.52, -0.07, 0.9), m["iron_d"], "Hand.L")
    k.plate("ClampA", [(0, 0), (0.05, 0), (0.07, -0.12), (0.03, -0.16), (0.02, -0.08)], 0.05,
            (0.52, -0.1, 0.88), (0, -1, 0), (0, 0, 1), m["steel"], "Hand.L")
    k.plate("ClampB", [(0, 0), (0.05, 0), (0.07, -0.12), (0.03, -0.16), (0.02, -0.08)], 0.05,
            (0.52, -0.03, 0.88), (0, 1, 0), (0, 0, 1), m["steel"], "Hand.L")
    return k.join_parts("SteamHammerMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.2), None),
    "Hips": ((0, 0, 0.82), (0, 0, 0.96), "Root"),
    "Spine": ((0, 0, 0.96), (0, 0, 1.2), "Hips"),
    "Chest": ((0, 0, 1.2), (0, 0, 1.76), "Spine"),
    "Head": ((0, -0.18, 1.64), (0, -0.18, 1.82), "Chest"),
}
for _side, _s in SIDES:
    BONES.update({
        f"Steam.{_side}": ((0.38 * _s, 0.05, 1.9), (0.38 * _s, 0.05, 2.2), "Chest"),
        f"UpperArm.{_side}": ((0.46 * _s, 0, 1.56), (0.5 * _s, 0, 1.22), "Chest"),
        f"ForeArm.{_side}": ((0.5 * _s, 0, 1.22), (0.52 * _s, -0.04, 0.94), f"UpperArm.{_side}"),
        f"Hand.{_side}": ((0.52 * _s, -0.05, 0.94), (0.52 * _s, -0.06, 0.7), f"ForeArm.{_side}"),
        f"Thigh.{_side}": ((0.18 * _s, 0, 0.82), (0.2 * _s, -0.02, 0.48), "Hips"),
        f"Shin.{_side}": ((0.2 * _s, -0.02, 0.48), (0.2 * _s, 0, 0.12), f"Thigh.{_side}"),
        f"Foot.{_side}": ((0.2 * _s, 0, 0.12), (0.2 * _s, -0.2, 0.04), f"Shin.{_side}"),
    })

STANCE = {
    "Hips": (2, -6, 0), "Spine": (8, -4, 0), "Chest": (10, -4, 0), "Head": (-14, 6, 0),
    "Thigh.L": (-18, 0, -6), "Shin.L": (22, 0, 0), "Foot.L": (-4, 0, 0),
    "Thigh.R": (6, 0, 8), "Shin.R": (18, 0, 0), "Foot.R": (-22, 0, 0),
    "UpperArm.R": (-10, 0, 10), "ForeArm.R": (-20, 0, 0),
    "UpperArm.L": (-14, 0, -10), "ForeArm.L": (-30, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.04)}
SCALED = ("Steam.R", "Steam.L")


def stance():
    return Pose(STANCE, STANCE_LOC)


def puff(p, a, b=None):
    p.size("Steam.R", 0.5 + 0.7 * a)
    p.size("Steam.L", 0.5 + 0.7 * (a if b is None else b))
    return p


def idle(t):
    """Покой (3 сек): тяжело «дышит» котлом, пар толчками из клапанов, молот покачивается."""
    p = stance()
    br = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", z=-0.012 * (br * 0.5 + 0.5), x=0.02 * sway)
    p.add("Hips", z=2 * sway)
    p.add("Spine", x=2 * br)
    p.add("Chest", y=k.track(t, [(0, 0), (0.25, 0), (0.3, -14), (0.55, -14), (0.6, 8), (0.85, 8), (0.9, 0), (1, 0)]))
    p.add("Head", x=-2 * br)
    p.add("UpperArm.R", x=3 * wave(t, 1, 0.2))
    p.add("UpperArm.L", x=3 * wave(t, 1, 0.5))
    puff(p, 0.3 + 0.7 * pulse(t, 0.35, 0.12), 0.3 + 0.7 * pulse(t, 0.75, 0.12))
    return p


def walk(t):
    """Тяжёлая поступь (1.0 сек): топает, корпус переваливается, молот тянет вниз."""
    p = Pose(STANCE)
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.1)
    p.move("Hips", z=-0.05 + 0.03 * bounce, x=0.035 * a)
    p.add("Hips", y=-6 + 6 * a, z=5 * a)
    p.set("Thigh.R", -4 - 24 * a, 0, 8)
    p.set("Thigh.L", -4 + 24 * a, 0, -8)
    p.set("Shin.R", 12 + 30 * max(0.0, c) + 4 * a, 0, 0)
    p.set("Shin.L", 12 + 30 * max(0.0, -c) - 4 * a, 0, 0)
    p.set("Foot.R", -6 - 12 * a, 0, 0)
    p.set("Foot.L", -6 + 12 * a, 0, 0)
    p.add("Chest", y=-5 * a, x=2 * bounce)
    p.add("UpperArm.R", x=-8 * a)
    p.add("UpperArm.L", x=12 * a)
    puff(p, 0.4 + 0.4 * max(0.0, bounce), 0.4 + 0.4 * max(0.0, -bounce))
    return p


def attack(t):
    """Удар молотом (1.0 сек): молот взлетает над головой, корпус откидывается → удар вниз-вперёд
    (к 0.4 сек), выброс пара → медленный возврат."""
    p = Pose({}, {})
    K = [0.0, 0.26, 0.4, 0.6, 1.0]
    for bone, *keys in [
        ("Spine", (-8, 10, 0), (20, -8, 0), (18, -6, 0)),
        ("Chest", (-8, 12, 0), (16, -10, 0), (14, -8, 0)),
        ("Head", (-6, 0, 0), (-24, 0, 0), (-20, 0, 0)),
        ("UpperArm.R", (-160, 0, 20), (-60, 0, 4), (-50, 0, 4)),
        ("ForeArm.R", (-20, 0, 0), (-6, 0, 0), (-8, 0, 0)),
        ("UpperArm.L", (-30, 0, -24), (10, 0, -16), (6, 0, -14)),
        ("Thigh.L", (-16, 0, -6), (-34, 0, -6), (-30, 0, -6)),
        ("Shin.L", (18, 0, 0), (40, 0, 0), (38, 0, 0)),
        ("Thigh.R", (8, 0, 8), (12, 0, 8), (12, 0, 8)),
        ("Shin.R", (14, 0, 0), (26, 0, 0), (26, 0, 0)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], -0.02), (K[2], -0.14), (K[3], -0.12), (1, -0.04)]))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.05), (K[2], -0.1), (K[3], -0.1), (1, 0)]))
    puff(p, track(t, [(0, 0.3), (K[1], 0.5), (K[2], 1.3), (K[3], 1.0), (1, 0.3)]))
    return p


def attack2(t):
    """Набирает пар (1.0 сек): сжимается, молот у пола, корпус дрожит, клапаны выбрасывают пар всё сильнее."""
    p = stance()
    build_up = track(t, [(0, 0), (0.3, 1), (0.8, 1), (1, 0)])
    shake = build_up * wave(t, 12)
    p.move("Hips", z=-0.06 * build_up)
    p.add("Spine", x=10 * build_up)
    p.add("Chest", x=6 * build_up, z=2 * shake)
    p.add("Head", x=-10 * build_up)
    p.add("UpperArm.R", x=14 * build_up)
    p.add("UpperArm.L", x=-10 * build_up, z=-10 * build_up)
    p.add("Thigh.L", x=-8 * build_up)
    p.add("Shin.L", x=12 * build_up)
    p.add("Shin.R", x=12 * build_up)
    puff(p, 0.4 + 1.0 * build_up + 0.2 * shake, 0.4 + 1.0 * build_up - 0.2 * shake)
    return p


def hit(t):
    """Получил удар (0.5 сек): корпус отбрасывает, молот мотается с опозданием, пар рывком."""
    p = stance()
    snap = track(t, [(0, 0), (0.16, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.18, 0.4), (0.32, 1), (0.55, -0.3), (1, 0)])
    p.move("Root", y=0.07 * snap)
    p.add("Spine", x=-12 * snap, y=8 * snap)
    p.add("Chest", x=-8 * whip)
    p.add("Head", x=-14 * whip)
    p.add("UpperArm.R", x=16 * whip, z=10 * whip)
    p.add("UpperArm.L", x=18 * whip, z=-14 * whip)
    puff(p, 0.4 + 0.8 * snap, 0.4 + 0.9 * whip)
    return p


def death(t):
    """Гибель (1.5 сек): котёл стравливает пар, машина оседает на колени, молот тянет её вперёд,
    валится лицом вниз; в конце дёргается зажим."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.45, 0.72, 1.0]
    for bone, *keys in [
        ("Spine", (-10, 8, 0), (16, 0, 0), (24, 0, 0), (22, 0, 0)),
        ("Chest", (-8, 6, 0), (12, 0, 0), (16, 0, 0), (14, 0, 0)),
        ("Head", (-20, -10, 0), (6, 0, 0), (-20, 20, 0), (-16, 24, 0)),
        ("UpperArm.R", (10, 0, 26), (-20, 0, 14), (-110, 0, 16), (-120, 0, 18)),
        ("UpperArm.L", (14, 0, -30), (-6, 0, -18), (-110, 0, -18), (-118, 0, -20)),
        ("Thigh.L", (-10, 0, -8), (-80, 0, -10), (-30, 0, -10), (-20, 0, -10)),
        ("Shin.L", (20, 0, 0), (108, 0, 0), (40, 0, 0), (20, 0, 0)),
        ("Thigh.R", (-16, 0, 10), (-80, 0, 12), (-30, 0, 12), (-20, 0, 12)),
        ("Shin.R", (24, 0, 0), (108, 0, 0), (40, 0, 0), (20, 0, 0)),
        ("Foot.L", (0, 0, 0), (40, 0, 0), (40, 0, 0), (40, 0, 0)),
        ("Foot.R", (0, 0, 0), (40, 0, 0), (40, 0, 0), (40, 0, 0)),
    ]:
        a2.keyed_end(p, t, K, STANCE, bone, *keys)
    fall = track(t, [(0, 0), (K[1], -6), (K[2], 6), (K[3], 80), (K[3] + 0.06, 74), (K[3] + 0.12, 82), (1, 82)])
    p.set("Root", fall, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.05), (K[2], -0.05), (K[3], -0.2), (1, -0.2)]),
           z=track(t, [(0, 0), (K[2], 0), (K[3], 0.28), (1, 0.28)]))
    p.move("Hips", z=track(t, [(0, -0.04), (K[1], -0.02), (K[2], -0.44), (K[3], -0.1), (1, -0.1)]))
    p.add("ForeArm.L", x=-26 * pulse(t, 0.9, 0.05))
    burst = track(t, [(0, 0.4), (K[1], 1.4), (K[2], 1.2), (K[3], 0.6), (1, 0.15)])
    puff(p, burst, burst * 0.9)
    return p


def build(glb_path, blend_path=None):
    k.start_scene("SteamHammer")
    body = build_mesh()
    rig = k.build_armature("SteamHammer", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 30, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 30, attack, scale_bones=SCALED)
    k.bake(rig, "Attack2", 30, attack2, scale_bones=SCALED)
    k.bake(rig, "Hit", 15, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 45, death, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "steam_hammer")
