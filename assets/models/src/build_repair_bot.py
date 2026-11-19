# Ремонтник — маленький механизм лаборатории (акт 2, Подземье), ~0.6 м. Плоский бронзовый корпус
# на четырёх суставчатых ногах, как механический паук; правая рука — большой гаечный ключ,
# левая — сварочная горелка с раскалённым концом. Сверху ящик с инструментами и моток проволоки,
# спереди круглая линза. Стихийной сферы нет — так он отличается от сферников.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (чинит: горелка и удар ключом), Hit, Death.
# Запуск: python3 build_repair_bot.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

# Ноги: имя, x, y бедра (кость-шарнир вертикальная, как у скальника)
LEGS = (("FL", 0.2, -0.12), ("FR", -0.2, -0.12), ("BL", 0.2, 0.14), ("BR", -0.2, 0.14))


def build_mesh():
    m = a2.mech_mats()
    k.barrel("Shell", 0.27, 0.29, 0.28, 0.42, m["bronze"], "Body", segs=10, sy=0.9)
    k.barrel("ShellTop", 0.29, 0.25, 0.42, 0.46, m["bronze_d"], "Body", segs=10, sy=0.9)
    k.barrel("Belly", 0.2, 0.27, 0.24, 0.28, m["iron_d"], "Body", segs=8, sy=0.9)
    for i, (x, y) in enumerate([(0.2, -0.16), (-0.2, -0.16), (0.24, 0.08), (-0.24, 0.08), (0, 0.24)]):
        k.box(f"Rivet{i}", (0.03, 0.03, 0.03), (x, y, 0.445), m["iron_d"], "Body")
    k.limb("LensRim", (0, -0.24, 0.35), (0, -0.28, 0.35), 0.06, 0.06, m["iron_d"], "Body", segs=7)
    k.limb("Lens", (0, -0.28, 0.35), (0, -0.29, 0.35), 0.045, 0.045, m["lamp"], "Body", segs=7)
    # Ящик с инструментами и моток проволоки
    k.box("Toolbox", (0.2, 0.12, 0.09), (0.04, 0.04, 0.51), m["iron"], "Body")
    k.box("ToolLid", (0.21, 0.13, 0.025), (0.04, 0.04, 0.565), m["iron_d"], "Body")
    k.box("Handle", (0.08, 0.015, 0.03), (0.04, 0.04, 0.59), m["iron_d"], "Body")
    k.box("Box2", (0.09, 0.08, 0.07), (-0.13, 0.02, 0.495), m["iron_d"], "Body")
    a2.ring("Coil", 0.07, 0.012, (0.12, 0.16, 0.47), (0, 0, 1), m["copper"], "Body", seg=10)
    a2.ring("Coil2", 0.06, 0.012, (0.12, 0.16, 0.49), (0, 0, 1), m["copper"], "Body", seg=10)
    # Ноги: верхний сегмент вверх-наружу, нижний вниз к полу
    for name, x, y in LEGS:
        s = 1 if x > 0 else -1
        f = -1 if y < 0 else 1
        hip = (x, y, 0.32)
        kn = (x + 0.14 * s, y + 0.1 * f, 0.4)
        ft = (x + 0.2 * s, y + 0.15 * f, 0.02)
        k.sphere(f"Hip.{name}", 0.035, hip, m["iron"], f"Coxa.{name}", segs=5, rings=3)
        k.limb(f"Up.{name}", hip, kn, 0.026, 0.022, m["iron_d"], f"Coxa.{name}", segs=5)
        k.sphere(f"Knee.{name}", 0.03, kn, m["bronze_d"], f"Knee.{name}", segs=5, rings=3)
        k.limb(f"Low.{name}", kn, ft, 0.022, 0.01, m["iron_d"], f"Knee.{name}", segs=5)
    # Правая рука — гаечный ключ (поднят)
    k.sphere("ShoulderR", 0.035, (-0.15, -0.22, 0.42), m["iron"], "ArmR", segs=5, rings=3)
    k.limb("ArmR", (-0.15, -0.22, 0.42), (-0.2, -0.3, 0.6), 0.022, 0.02, m["iron_d"], "ArmR", segs=5)
    k.limb("ForeR", (-0.2, -0.3, 0.6), (-0.2, -0.28, 0.72), 0.02, 0.018, m["iron_d"], "ForeR", segs=5)
    k.box("WrenchShaft", (0.025, 0.02, 0.2), (-0.2, -0.28, 0.8), m["steel"], "ForeR")
    k.plate("WrenchJaw", [(-0.05, 0), (0.05, 0), (0.06, 0.07), (0.025, 0.08), (0.02, 0.04), (-0.02, 0.04),
                          (-0.025, 0.08), (-0.06, 0.07)], 0.025, (-0.2, -0.28, 0.89), (1, 0, 0), (0, 0, 1),
            m["steel"], "ForeR")
    # Левая рука — сварочная горелка (вперёд)
    k.sphere("ShoulderL", 0.035, (0.15, -0.22, 0.4), m["iron"], "ArmL", segs=5, rings=3)
    k.limb("ArmL", (0.15, -0.22, 0.4), (0.22, -0.34, 0.44), 0.022, 0.02, m["iron_d"], "ArmL", segs=5)
    k.limb("ForeL", (0.22, -0.34, 0.44), (0.22, -0.46, 0.38), 0.02, 0.018, m["copper"], "ForeL", segs=5)
    k.limb("Nozzle", (0.22, -0.46, 0.38), (0.22, -0.52, 0.33), 0.018, 0.01, m["steel"], "ForeL", segs=5)
    k.limb("Flame", (0.22, -0.52, 0.33), (0.22, -0.58, 0.29), 0.02, 0.003, m["hot"], "ForeL", segs=5)
    k.limb("Hose", (0.15, -0.1, 0.42), (0.22, -0.36, 0.44), 0.01, 0.01, m["copper"], "ArmL", segs=4)
    return k.join_parts("RepairBotMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Body": ((0, 0, 0.26), (0, 0, 0.46), "Root"),
    "ArmR": ((-0.15, -0.22, 0.42), (-0.2, -0.3, 0.6), "Body"),
    "ForeR": ((-0.2, -0.3, 0.6), (-0.2, -0.28, 0.72), "ArmR"),
    "ArmL": ((0.15, -0.22, 0.4), (0.22, -0.34, 0.44), "Body"),
    "ForeL": ((0.22, -0.34, 0.44), (0.22, -0.46, 0.38), "ArmL"),
}
for _n, _x, _y in LEGS:
    _s = 1 if _x > 0 else -1
    _f = -1 if _y < 0 else 1
    BONES[f"Coxa.{_n}"] = ((_x, _y, 0.32), (_x, _y, 0.42), "Body")
    _kx, _ky = _x + 0.14 * _s, _y + 0.1 * _f
    BONES[f"Knee.{_n}"] = ((_kx, _ky, 0.4), (_kx, _ky, 0.5), f"Coxa.{_n}")

STANCE = {"Body": (4, -8, 0), "ArmR": (0, 0, 0), "ForeR": (0, 0, 0)}
LOC_BONES = ("Root", "Body")


def stance():
    return Pose(STANCE)


def leg(p, name, swing=0.0, lift=0.0):
    """Нога паука: swing — вперёд/назад (поворот шарнира вокруг вертикали), lift — поднять."""
    x = dict((n, xx) for n, xx, _ in LEGS)[name]
    s = 1 if x > 0 else -1
    p.add(f"Coxa.{name}", y=-swing * s, z=lift * s)
    p.add(f"Knee.{name}", z=-lift * 0.6 * s)


def idle(t):
    """Покой (3 сек): переминается, вертит линзой, постукивает ключом, горелка вздрагивает."""
    p = stance()
    p.move("Body", z=0.006 * wave(t, 3))
    p.add("Body", y=14 * k.track(t, [(0, 0), (0.2, 0), (0.25, 1), (0.5, 1), (0.56, -1), (0.8, -1), (0.86, 0), (1, 0)]))
    tap = pulse(t, 0.36, 0.04) + pulse(t, 0.44, 0.04)
    p.add("ForeR", x=24 * tap)
    p.add("ArmL", x=4 * wave(t, 5), z=3 * wave(t, 4, 0.2))
    for i, (name, _, _) in enumerate(LEGS):
        leg(p, name, lift=4 * pulse(t, 0.15 + i * 0.2, 0.05))
    return p


def walk(t):
    """Паучий шаг (0.6 сек): ноги по диагонали попарно, корпус покачивается."""
    p = stance()
    a = wave(t, 1)
    p.move("Body", z=0.012 * wave(t, 2))
    for name, _, _ in LEGS:
        ph = a if name in ("FL", "BR") else -a
        leg(p, name, swing=18 * ph, lift=14 * max(0.0, wave(t, 1, 0.25) * (1 if name in ("FL", "BR") else -1)))
    p.add("ArmR", x=6 * a)
    return p


def attack(t):
    """Чинит (0.8 сек): тянется горелкой вперёд, ключ взлетает → удар ключом (к 0.4 сек) → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.22, 0.4, 0.58, 1.0]
    for bone, *keys in [
        ("Body", (-6, -8, 0), (14, -4, 0), (10, -6, 0)),
        ("ArmR", (-30, 0, 10), (50, 0, 0), (40, 0, 0)),
        ("ForeR", (-40, 0, 0), (40, 0, 0), (30, 0, 0)),
        ("ArmL", (-10, 0, 0), (16, 0, 0), (12, 0, 0)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.03), (K[2], -0.06), (K[3], -0.05), (1, 0)]))
    return p


def hit(t):
    """Получил удар (0.4 сек): отлетает назад, ноги подгибаются, руки дёргаются."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    p.move("Root", y=0.06 * snap)
    p.move("Body", z=-0.04 * snap)
    p.add("Body", x=-14 * snap, z=8 * snap)
    p.add("ArmR", x=-20 * snap)
    p.add("ArmL", x=-14 * snap)
    for name, _, _ in LEGS:
        leg(p, name, lift=-8 * snap)
    return p


def death(t):
    """Гибель (1.0 сек): подпрыгивает, переворачивается на спину, ноги поджимаются и дёргаются."""
    p = stance()
    flip = track(t, [(0, 0), (0.2, -0.1), (0.55, 1), (1, 1)])
    p.set("Root", 0, 0, 170 * flip)
    p.move("Root", z=track(t, [(0, 0), (0.3, 0.25), (0.55, 0.42), (1, 0.42)]))
    curl = track(t, [(0, 0), (0.5, 1), (1, 1)]) + 0.3 * pulse(t, 0.85, 0.05)
    for name, _, _ in LEGS:
        leg(p, name, lift=40 * curl)
    p.add("ArmR", x=40 * curl)
    p.add("ArmL", x=30 * curl)
    return p


def build(glb_path, blend_path=None):
    k.start_scene("RepairBot")
    body = build_mesh()
    rig = k.build_armature("RepairBot", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LOC_BONES)
    k.bake(rig, "Walk", 18, walk, cyclic=True, loc_bones=LOC_BONES)
    k.bake(rig, "Attack", 24, attack, loc_bones=LOC_BONES)
    k.bake(rig, "Hit", 12, hit, loc_bones=LOC_BONES)
    k.bake(rig, "Death", 30, death, loc_bones=LOC_BONES)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "repair_bot")
