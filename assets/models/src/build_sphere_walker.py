# Сферник — механизм лаборатории (акт 2, Подземье), ~1.3 м. Котелок из бронзы на трёх ногах-поршнях,
# одна рука с захватом, труба с паром сзади, щель-глаз спереди. Сверху стеклянная сфера в клетке
# с пленным духом. Один корпус — четыре врага: сфера огня, воды, молнии или ветра.
# Скрипт собирает все четыре: sphere_walker_fire / _water / _storm / _wind.
# Смотрит в -Y. Анимации: Idle, Walk, Attack, Hit, Death (сфера сжимается — «лопается»).
# Запуск: python3 build_sphere_walker.py (пишет .glb в assets/models/, .blend рядом)
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

KINDS = ("fire", "water", "storm", "wind")
SY = 0.9
LEGS = (("FR", -0.2, -0.12), ("FL", 0.2, -0.12), ("B", 0.0, 0.2))   # имя, x, y бедра


def build_mesh(kind):
    m = a2.mech_mats()
    glass, mark = a2.element_mats()[kind]
    # Корпус-котелок
    k.barrel("BodyLow", 0.22, 0.34, 0.36, 0.62, m["bronze"], "Body", segs=9, sy=SY)
    k.barrel("BodyHigh", 0.34, 0.27, 0.62, 0.84, m["bronze"], "Body", segs=9, sy=SY)
    k.barrel("Band", 0.35, 0.35, 0.6, 0.65, m["iron"], "Body", segs=9, sy=SY)
    k.barrel("Bottom", 0.14, 0.22, 0.31, 0.36, m["iron_d"], "Body", segs=8, sy=SY)
    for i in range(6):
        a = math.radians(-90 + (i - 2.5) * 30)
        k.box(f"Rivet{i}", (0.03, 0.03, 0.03), (0.355 * math.cos(a), 0.355 * SY * math.sin(a) - 0.005, 0.625), m["iron_d"], "Body")
    # Щель-глаз
    k.box("EyeFrame", (0.2, 0.05, 0.08), (0, -0.29, 0.7), m["iron_d"], "Body", rot=(-8, 0, 0))
    k.box("Eye", (0.15, 0.03, 0.035), (0, -0.315, 0.7), m["lamp"], "Body", rot=(-8, 0, 0))
    # Воротник и сфера (кость Top — сфера качается и «лопается» при гибели)
    k.barrel("Collar", 0.2, 0.17, 0.84, 0.9, m["iron"], "Body", segs=8)
    a2.caged_sphere("Orb", 0.23, (0, 0, 1.1), glass, m["iron_d"], "Top", cage_bone="Body")
    a2.element_marks("Orb", kind, (0, 0, 1.1), 0.23, mark, "Top")
    k.crack("OrbRift", [(0, 0), (0.04, 0.05), (0.08, 0.02)], (0.08, -0.2, 1.02), (1, 0, 0), (0, 0, 1), m["rift"], "Top",
            width=0.014, depth=0.014)
    k.box("CageTop", (0.05, 0.05, 0.05), (0, 0, 1.35), m["iron_d"], "Body")
    # Труба с паром сзади
    k.limb("Pipe", (0.16, 0.2, 0.7), (0.2, 0.28, 0.98), 0.04, 0.035, m["copper"], "Body", segs=6)
    k.sphere("Puff", 0.07, (0.21, 0.29, 1.07), m["steam"], "Steam", segs=5, rings=3)
    k.sphere("Puff2", 0.05, (0.24, 0.3, 1.16), m["steam"], "Steam", segs=5, rings=3)
    # Рука с захватом (правая, -X)
    k.sphere("Shoulder", 0.07, (-0.33, -0.1, 0.62), m["iron"], "Arm", segs=6, rings=4)
    k.limb("UpperArm", (-0.33, -0.1, 0.62), (-0.38, -0.2, 0.46), 0.04, 0.035, m["iron"], "Arm", segs=6)
    k.limb("ForeArm", (-0.38, -0.2, 0.46), (-0.36, -0.36, 0.42), 0.035, 0.035, m["steel"], "Fore", segs=6)
    k.box("Wrist", (0.08, 0.06, 0.07), (-0.36, -0.37, 0.42), m["iron_d"], "Fore")
    k.plate("GrabA", [(0, 0.02), (0.06, 0), (0.1, -0.06), (0.08, -0.12), (0.05, -0.07), (0, -0.04)], 0.03,
            (-0.36, -0.39, 0.44), (0, -1, 0), (0, 0, 1), m["steel"], "Grab")
    k.plate("GrabB", [(0, -0.02), (0.06, 0), (0.1, 0.06), (0.08, 0.12), (0.05, 0.07), (0, 0.04)], 0.03,
            (-0.36, -0.39, 0.4), (0, -1, 0), (0, 0, 1), m["steel"], "Grab")
    # Ноги-поршни
    for name, x, y in LEGS:
        k.sphere(f"Hip.{name}", 0.06, (x, y, 0.38), m["iron"], "Body", segs=6, rings=4)
        k.limb(f"Thigh.{name}", (x, y, 0.38), (x * 1.25, y * 1.4, 0.2), 0.055, 0.05, m["bronze_d"], f"Leg.{name}", segs=6)
        k.limb(f"Rod.{name}", (x * 1.25, y * 1.4, 0.22), (x * 1.3, y * 1.5, 0.06), 0.03, 0.03, m["steel"], f"Leg.{name}", segs=5)
        k.box(f"Foot.{name}", (0.12, 0.14, 0.05), (x * 1.3, y * 1.5 - 0.02, 0.03), m["iron_d"], f"Leg.{name}")
    return k.join_parts("SphereWalkerMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Body": ((0, 0, 0.36), (0, 0, 0.84), "Root"),
    "Top": ((0, 0, 0.86), (0, 0, 1.3), "Body"),
    "Steam": ((0.2, 0.28, 0.98), (0.2, 0.28, 1.2), "Body"),
    "Arm": ((-0.33, -0.1, 0.62), (-0.38, -0.2, 0.46), "Body"),
    "Fore": ((-0.38, -0.2, 0.46), (-0.36, -0.37, 0.42), "Arm"),
    "Grab": ((-0.36, -0.38, 0.42), (-0.36, -0.48, 0.42), "Fore"),
}
for _n, _x, _y in LEGS:
    BONES[f"Leg.{_n}"] = ((_x, _y, 0.38), (_x * 1.3, _y * 1.5, 0.04), "Body")

STANCE = {"Body": (4, -6, 0), "Arm": (-20, 0, 6), "Fore": (-10, 0, 0), "Leg.FL": (-6, 0, 0), "Leg.FR": (4, 0, 0)}
LOC_BONES = ("Root", "Body")
SCALED = ("Top", "Steam")


def stance():
    return Pose(STANCE)


def idle(t):
    """Покой (3 сек): котелок покачивается на поршнях, сфера чуть дрожит, пар толчками, захват щёлкает."""
    p = stance()
    bob = wave(t, 3)
    p.move("Body", z=-0.01 * (bob * 0.5 + 0.5))
    yaw = k.track(t, [(0, 0), (0.25, 0), (0.3, -16), (0.6, -16), (0.66, 10), (0.88, 10), (0.94, 0), (1, 0)])
    p.add("Body", y=yaw, x=1.5 * bob)
    p.add("Top", x=2 * wave(t, 2, 0.2), z=2 * wave(t, 3, 0.1))
    p.size("Top", 1.0 + 0.03 * wave(t, 4))
    p.size("Steam", 0.6 + 0.6 * pulse(t, 0.4, 0.15) + 0.4 * pulse(t, 0.85, 0.1))
    snap = pulse(t, 0.5, 0.04) + pulse(t, 0.56, 0.04)
    p.add("Grab", x=-30 * snap)
    p.add("Arm", x=-6 * snap)
    return p


def walk(t):
    """Семенит (0.8 сек): ноги по очереди, котелок переваливается, рука качается."""
    p = Pose(STANCE)
    a = wave(t, 1)
    b = wave(t, 1, 0.33)
    c = wave(t, 1, 0.66)
    p.move("Body", z=0.02 * wave(t, 3))
    p.add("Body", z=5 * a, x=3)
    p.add("Leg.FR", x=-20 * a)
    p.add("Leg.FL", x=-20 * b)
    p.add("Leg.B", x=-20 * c)
    p.add("Arm", x=-10 * a)
    p.add("Top", z=-4 * a)
    p.size("Steam", 0.7 + 0.3 * max(0.0, a))
    return p


def attack(t):
    """Выплеск сферы (0.8 сек): откинулся назад, сфера раздувается → резкий наклон вперёд (к 0.4 сек),
    рука выброшена вперёд → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.25, 0.42, 0.6, 1.0]
    for bone, *keys in [
        ("Body", (-14, 10, 0), (16, -6, 0), (12, -6, 0)),
        ("Arm", (20, 0, 20), (-80, 0, 4), (-70, 0, 4)),
        ("Fore", (-40, 0, 0), (0, 0, 0), (-6, 0, 0)),
        ("Grab", (-40, 0, 0), (20, 0, 0), (10, 0, 0)),
        ("Leg.FL", (-12, 0, 0), (6, 0, 0), (4, 0, 0)),
        ("Leg.FR", (10, 0, 0), (-10, 0, 0), (-8, 0, 0)),
        ("Top", (-6, 0, 0), (10, 0, 0), (6, 0, 0)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.size("Top", track(t, [(0, 1.0), (K[1], 1.15), (K[2], 0.92), (K[3], 1.02), (1, 1.0)]))
    p.size("Steam", track(t, [(0, 0.6), (K[2], 1.3), (1, 0.6)]))
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.04), (K[2], -0.08), (K[3], -0.06), (1, 0)]))
    return p


def hit(t):
    """Получил удар (0.5 сек): котелок отбрасывает, сфера мотается позже, выброс пара."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.move("Root", y=0.06 * snap)
    p.add("Body", x=-14 * snap, z=6 * snap)
    p.add("Top", x=-12 * whip, z=-8 * whip)
    p.add("Arm", x=20 * whip)
    p.size("Steam", 0.6 + 0.9 * snap)
    return p


def death(t):
    """Гибель (1.2 сек): шатается, ноги подгибаются, котелок валится набок, сфера «лопается»
    (сжимается почти в ноль), в конце дёргается захват."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.45, 0.7, 1.0]
    for bone, *keys in [
        ("Body", (-10, 10, 8), (8, 0, 20), (10, 0, 70), (10, 0, 76)),
        ("Leg.FR", (10, 0, 0), (-30, 0, 0), (-50, 0, 0), (-50, 0, 0)),
        ("Leg.FL", (-10, 0, 0), (20, 0, 0), (30, 0, 0), (30, 0, 0)),
        ("Arm", (30, 0, 20), (10, 0, 40), (-20, 0, 60), (-20, 0, 60)),
        ("Top", (-10, 0, 0), (10, 0, 6), (14, 0, 10), (14, 0, 10)),
    ]:
        a2.keyed_end(p, t, K, STANCE, bone, *keys)
    p.move("Body", z=track(t, [(0, 0), (K[2], -0.1), (K[3], -0.2), (1, -0.22)]),
           x=track(t, [(0, 0), (K[3], 0.2), (1, 0.22)]))
    p.size("Top", track(t, [(0, 1.0), (K[1], 1.2), (K[2] - 0.05, 1.25), (K[2], 0.15), (1, 0.12)]))
    p.size("Steam", track(t, [(0, 0.6), (K[2], 1.6), (K[3], 1.0), (1, 0.2)]))
    p.add("Grab", x=-30 * pulse(t, 0.9, 0.05))
    return p


def build(kind, glb_path, blend_path=None):
    k.start_scene("SphereWalker_" + kind)
    body = build_mesh(kind)
    rig = k.build_armature("SphereWalker", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Hit", 15, hit, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Death", 36, death, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    only = os.environ.get("KIND")
    for kind in KINDS:
        if only and kind != only:
            continue
        build(kind, os.path.join(here, "..", f"sphere_walker_{kind}.glb"), os.path.join(here, f"sphere_walker_{kind}.blend"))
