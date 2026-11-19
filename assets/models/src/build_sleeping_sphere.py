# Спящая сфера — механизм-ловушка лаборатории (акт 2, Подземье). Во сне — обычный клёпаный постамент
# со сферой молнии (~1.15 м), выдаёт его только крошечная бирюзовая линза. Проснувшись, раскрывает
# четыре панели, встаёт на паучьи ноги и выдвигает искрящее жало (~1.35 м).
# Тот же постамент в позе сна годится для декора Зала сфер — ловушку не отличить.
# Смотрит в -Y. Анимации: Sleep (сон, для скрытого врага и декора), Wake (пробуждение), Idle, Walk,
# Attack (жало), Hit, Death.
# Запуск: python3 build_sleeping_sphere.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

LEGS = (("FL", 1, -1), ("FR", -1, -1), ("BL", 1, 1), ("BR", -1, 1))
PANELS = (("F", 0, -1), ("B", 0, 1), ("L", 1, 0), ("R", -1, 0))


def build_mesh():
    m = a2.mech_mats()
    glass, mark = a2.element_mats()["storm"]
    # Сердцевина и цоколь
    k.barrel("Core", 0.17, 0.17, 0.1, 0.74, m["iron_d"], "Body", segs=8)
    k.barrel("Plinth", 0.3, 0.27, 0.0, 0.1, m["iron_d"], "Root", segs=8)   # цоколь остаётся на полу
    k.barrel("Cap", 0.28, 0.24, 0.72, 0.8, m["iron"], "Body", segs=8)
    k.barrel("Collar", 0.2, 0.17, 0.8, 0.86, m["bronze_d"], "Body", segs=8)
    k.limb("PipeL", (0.2, -0.02, 0.83), (0.25, 0.1, 0.83), 0.025, 0.025, m["copper"], "Body", segs=5)
    k.limb("PipeR", (-0.2, -0.02, 0.83), (-0.25, 0.1, 0.83), 0.025, 0.025, m["copper"], "Body", segs=5)
    # Четыре панели-лепестка (откидываются наружу на шарнире снизу)
    for name, sx, sy in PANELS:
        size = (0.3, 0.045, 0.62) if sx == 0 else (0.045, 0.3, 0.62)
        loc = (0.23 * sx, 0.23 * sy, 0.42)
        k.box(f"Panel.{name}", size, loc, m["iron"], f"Panel.{name}")
        for j, dz in enumerate((-0.22, 0.0, 0.22)):
            off = (0.1 * (1 if sx == 0 else 0), 0.1 * (1 if sy == 0 else 0))
            for side in (-1, 1):
                k.box(f"Rivet.{name}{j}{side}", (0.025, 0.025, 0.025),
                      (loc[0] + off[0] * side + 0.025 * sx, loc[1] + off[1] * side + 0.025 * sy, 0.42 + dz),
                      m["iron_d"], f"Panel.{name}")
    k.box("Lens", (0.04, 0.02, 0.04), (0, -0.258, 0.64), m["lens"], "Panel.F")   # единственная примета
    # Сфера молнии (клетка на корпусе, стекло на кости Top — «лопается» при гибели)
    a2.caged_sphere("Orb", 0.22, (0, 0, 1.08), glass, m["iron_d"], "Top", cage_bone="Body")
    a2.element_marks("Orb", "storm", (0, 0, 1.08), 0.22, mark, "Top")
    k.box("Hook", (0.04, 0.04, 0.06), (0, 0, 1.33), m["iron_d"], "Body")
    # Паучьи ноги (во сне спрятаны за панелями)
    for name, sx, sy in LEGS:
        h = (0.1 * sx, 0.1 * sy, 0.5)
        kn = (0.12 * sx, 0.12 * sy, 0.3)
        ft = (0.13 * sx, 0.13 * sy, 0.02)
        k.limb(f"LegU.{name}", h, kn, 0.04, 0.032, m["iron_d"], f"LegU.{name}", segs=5)
        k.sphere(f"Knee.{name}", 0.035, kn, m["bronze_d"], f"LegL.{name}", segs=5, rings=3)
        k.limb(f"LegL.{name}", kn, ft, 0.032, 0.014, m["steel"], f"LegL.{name}", segs=5)
    # Жало (во сне сложено вниз внутри передней панели)
    k.limb("Sting", (0, -0.15, 0.6), (0, -0.15, 0.32), 0.03, 0.022, m["steel"], "Sting", segs=5)
    k.limb("StingTip", (0, -0.15, 0.32), (0, -0.15, 0.24), 0.022, 0.004, mark, "Sting", segs=5)
    return k.join_parts("SleepingSphereMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Body": ((0, 0, 0.1), (0, 0, 0.74), "Root"),
    "Top": ((0, 0, 0.86), (0, 0, 1.3), "Body"),
    "Sting": ((0, -0.15, 0.6), (0, -0.15, 0.24), "Body"),
}
for _n, _sx, _sy in PANELS:
    BONES[f"Panel.{_n}"] = ((0.23 * _sx, 0.23 * _sy, 0.11), (0.23 * _sx, 0.23 * _sy, 0.73), "Body")
for _n, _sx, _sy in LEGS:
    BONES[f"LegU.{_n}"] = ((0.1 * _sx, 0.1 * _sy, 0.5), (0.12 * _sx, 0.12 * _sy, 0.3), "Body")
    BONES[f"LegL.{_n}"] = ((0.12 * _sx, 0.12 * _sy, 0.3), (0.13 * _sx, 0.13 * _sy, 0.02), f"LegU.{_n}")

SLEEP = {}   # сон — позиция сборки: всё закрыто
SLEEP_LOC = {}


def awake_pose():
    """Проснулась: панели откинуты, корпус поднят на ногах, жало вперёд."""
    p = Pose({}, {"Body": (0, 0, 0.04)})
    p.add("Panel.F", x=38)
    p.add("Panel.B", x=-38)
    p.add("Panel.L", z=-38)
    p.add("Panel.R", z=38)
    for name, sx, sy in LEGS:
        # кости ног смотрят вниз: X- — вперёд (-Y), Z+ — в сторону -X
        p.add(f"LegU.{name}", x=55 * sy, z=-55 * sx)
        p.add(f"LegL.{name}", x=-38 * sy, z=38 * sx)
    p.add("Sting", x=-100)
    return p


AWAKE = awake_pose()
STANCE = {b: tuple(v) for b, v in AWAKE.rot.items()}
STANCE_LOC = {b: tuple(v) for b, v in AWAKE.loc.items()}
LOC_BONES = ("Root", "Body")


def stance():
    return Pose(STANCE, STANCE_LOC)


def mix(t, a, b):
    """Поза между сном (a) и бодрствованием (b) по доле t."""
    p = Pose({}, {})
    for bone in set(a) | set(b):
        va, vb = a.get(bone, (0, 0, 0)), b.get(bone, (0, 0, 0))
        p.set(bone, *[x + (y - x) * t for x, y in zip(va, vb)])
    p.move("Body", z=STANCE_LOC["Body"][2] * t)
    return p


def sleep(t):
    """Сон (3 сек): почти неподвижна, только сфера тихо пульсирует."""
    p = Pose(SLEEP)
    p.size("Top", 1.0 + 0.02 * wave(t, 2))
    return p


def wake(t):
    """Пробуждение (0.9 сек): панели рывком распахиваются, корпус встаёт на ноги, жало выдвигается."""
    p = mix(k.smooth(track(t, [(0, 0), (0.15, 0.1), (0.7, 1.05), (1, 1)])), SLEEP, STANCE)
    p.add("Body", y=6 * pulse(t, 0.3, 0.1) - 6 * pulse(t, 0.5, 0.1))
    p.size("Top", 1.0 + 0.15 * pulse(t, 0.4, 0.2))
    return p


def idle(t):
    """Покой (3 сек): переминается на лапах, жало подрагивает, сфера искрит."""
    p = stance()
    p.move("Body", z=0.012 * wave(t, 3))
    p.add("Body", y=12 * k.track(t, [(0, 0), (0.3, 0), (0.36, 1), (0.6, 1), (0.66, -1), (0.9, -1), (1, 0)]))
    p.add("Sting", x=6 * wave(t, 4), z=5 * wave(t, 3, 0.2))
    for i, (name, sx, sy) in enumerate(LEGS):
        p.add(f"LegL.{name}", x=-4 * sy * wave(t, 3, i * 0.25))
    p.size("Top", 1.0 + 0.05 * pulse(t, 0.5, 0.08))
    return p


def walk(t):
    """Паучий шаг (0.8 сек): ноги по диагонали попарно."""
    p = stance()
    a = wave(t, 1)
    p.move("Body", z=0.015 * wave(t, 2))
    for name, sx, sy in LEGS:
        ph = a if name in ("FL", "BR") else -a
        p.add(f"LegU.{name}", x=-16 * ph)
        p.add(f"LegL.{name}", x=-10 * max(0.0, ph) * sy)
    p.add("Sting", x=-4 * a)
    return p


def attack(t):
    """Искровое жало (0.8 сек): присела, жало отведено назад → удар вперёд (к 0.4 сек) → возврат."""
    p = stance()
    lunge = track(t, [(0, 0), (0.25, -1), (0.42, 1), (0.6, 0.8), (1, 0)])
    p.add("Sting", x=-30 * lunge)
    p.add("Body", x=10 * lunge)
    p.move("Body", z=-0.05 * abs(lunge))
    p.move("Root", y=-0.08 * max(0.0, lunge))
    p.size("Top", 1.0 + 0.12 * pulse(t, 0.42, 0.12))
    return p


def hit(t):
    """Получил удар (0.5 сек): корпус отбрасывает, панели хлопают, жало дёргается."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.move("Root", y=0.06 * snap)
    p.add("Body", x=-12 * snap)
    p.add("Panel.F", x=-20 * whip)
    p.add("Panel.B", x=20 * whip)
    p.add("Sting", x=30 * whip)
    return p


def death(t):
    """Гибель (1.2 сек): ноги разъезжаются, корпус падает на цоколь, панели повисают, сфера лопается."""
    p = stance()
    fall = track(t, [(0, 0), (0.4, 1), (1, 1)])
    p.move("Body", z=-0.2 * fall)
    for name, sx, sy in LEGS:
        p.add(f"LegU.{name}", x=30 * sy * fall, z=-30 * sx * fall)
    p.add("Panel.F", x=15 * fall)
    p.add("Panel.L", z=-15 * fall)
    p.add("Sting", x=60 * fall)
    p.add("Body", z=12 * track(t, [(0, 0), (0.5, 1), (1, 1)]))
    p.size("Top", track(t, [(0, 1.0), (0.4, 1.25), (0.45, 0.15), (1, 0.12)]))
    p.add("Sting", x=20 * pulse(t, 0.9, 0.05))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("SleepingSphere")
    body = build_mesh()
    rig = k.build_armature("SleepingSphere", BONES)
    body.parent = rig
    sc = ("Top",)
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LOC_BONES, scale_bones=sc)
    k.bake(rig, "Sleep", 90, sleep, cyclic=True, loc_bones=LOC_BONES, scale_bones=sc)
    k.bake(rig, "Wake", 27, wake, loc_bones=LOC_BONES, scale_bones=sc)
    k.bake(rig, "Walk", 24, walk, cyclic=True, loc_bones=LOC_BONES, scale_bones=sc)
    k.bake(rig, "Attack", 24, attack, loc_bones=LOC_BONES, scale_bones=sc)
    k.bake(rig, "Hit", 15, hit, loc_bones=LOC_BONES, scale_bones=sc)
    k.bake(rig, "Death", 36, death, loc_bones=LOC_BONES, scale_bones=sc)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "sleeping_sphere")
