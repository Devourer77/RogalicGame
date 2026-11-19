# Пепельный вихрь — обломок одичавшего духа ветра (акт 2, Тракт, Ветреный перевал), ~1.3 м.
# Крутящаяся воронка из серого пепла и чёрных углей сужается книзу и касается земли остриём;
# внутри кружат оранжевые искры и угли, сверху — плотный ком пепла с двумя бирюзовыми огоньками.
# Ни ног, ни лица. Отличие от Вихоря: грязный пепел и угли вместо тумана и камыша.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (раздувается и толкает), Hit, Death (рассыпается).
# Запуск: python3 build_ash_whirl.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

BANDS = ((0.18, 0.08, 0.05), (0.38, 0.14, 0.07), (0.6, 0.21, 0.08), (0.82, 0.28, 0.09), (1.0, 0.33, 0.09))


def build_mesh():
    v = a2.volcano_mats()
    # Тонкий жар внутри воронки
    k.limb("Heat", (0, 0, 0.06), (0, 0, 0.95), 0.02, 0.16, v["ember"], "Spin1", segs=6)
    k.limb("Tip", (0, 0, 0.0), (0, 0, 0.2), 0.005, 0.07, v["ash_d"], "Spin1", segs=6)
    # Полосы пепла — наклонённые кольца разного радиуса, каждая на своей кости (крутятся с разной скоростью)
    for i, (z, r, th) in enumerate(BANDS):
        bone = f"Spin{i + 1}"
        tilt = math.radians(18 + 6 * i)
        axis = (math.sin(tilt), 0.0, math.cos(tilt))
        a2.ring(f"Band{i}", r, th, (0, 0, z), axis, v["ash"] if i % 2 == 0 else v["ash_d"], bone, seg=12, minor=4)
        a2.ring(f"BandIn{i}", r * 0.72, th * 0.6, (0, 0, z + 0.06), (-axis[0], 0.0, axis[2]), v["ash_d"], bone, seg=10, minor=3)
        for j in range(3):   # угли и искры
            a = math.tau * (j / 3 + i * 0.17)
            k.box(f"Coal{i}_{j}", (0.05, 0.05, 0.04), (r * 0.85 * math.cos(a), r * 0.85 * math.sin(a), z + 0.02),
                  v["slag"], bone, rot=(30 * j, 20 * i, 0))
            b = a + 1.0
            k.box(f"Spark{i}_{j}", (0.025, 0.025, 0.025), (r * 0.55 * math.cos(b), r * 0.55 * math.sin(b), z + 0.08),
                  v["ember"], bone)
        if i in (1, 3):
            k.crack(f"Rift{i}", [(0, 0), (0.05, 0.04), (0.1, 0.0)], (-0.05, -r - 0.01, z), (1, 0, 0), (0, 0, 1),
                    v["rift"], bone, width=0.012, depth=0.012)
    # Ком пепла-голова
    k.sphere("Head", 0.17, (0, 0, 1.18), v["ash_d"], "Head", scale=(1.0, 0.95, 0.9), segs=8, rings=5)
    k.sphere("HeadCap", 0.12, (0.03, 0.04, 1.28), v["ash"], "Head", segs=6, rings=4)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.04, 0.02, 0.025), (0.06 * s, -0.16, 1.19), v["rift"], "Head", rot=(0, 0, -12 * s))
    # Шлейф искр сбоку (кость Trail тянется по ветру)
    for i in range(5):
        k.box(f"Trail{i}", (0.03, 0.03, 0.03), (0.3 + 0.08 * i, 0.06 * i, 0.5 + 0.06 * i), v["ember"], "Trail",
              rot=(15 * i, 0, 25 * i))
    return k.join_parts("AshWhirlMesh")


BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Hips": ((0, 0, 0.0), (0, 0, 0.2), "Root")}
for _i, (_z, _r, _t) in enumerate(BANDS):
    BONES[f"Spin{_i + 1}"] = ((0, 0, _z - 0.1), (0, 0, _z + 0.1), "Hips")
BONES["Head"] = ((0, 0, 1.05), (0, 0, 1.35), "Hips")
BONES["Trail"] = ((0.3, 0, 0.5), (0.7, 0.3, 0.8), "Hips")

STANCE = {"Hips": (6, 0, 0)}
STANCE_LOC = {"Hips": (0, 0, 0.06)}
SCALED = tuple(f"Spin{i + 1}" for i in range(len(BANDS))) + ("Trail",)


def stance():
    return Pose(STANCE, STANCE_LOC)


def spin(p, t, turns=1.0, wobble=1.0):
    """Полосы крутятся с разной скоростью (целые обороты за цикл — цикл не дёргается)."""
    for i in range(len(BANDS)):
        n = turns * (2 + (i % 3))
        p.add(f"Spin{i + 1}", y=360.0 * n * t * (1 if i % 2 == 0 else -1),
              x=4 * wobble * wave(t, 2, i * 0.2), z=4 * wobble * wave(t, 3, i * 0.15))


def idle(t):
    """Покой (3 сек): воронка крутится, парит и покачивается, голова озирается, искры тянутся шлейфом."""
    p = stance()
    spin(p, t)
    p.move("Hips", z=0.03 * wave(t, 2), x=0.02 * wave(t, 1))
    p.add("Hips", z=4 * wave(t, 1))
    p.add("Head", y=k.track(t, [(0, 0), (0.3, 0), (0.36, -20), (0.6, -20), (0.66, 14), (0.9, 14), (1, 0)]),
          x=3 * wave(t, 2, 0.3))
    p.size("Trail", 0.8 + 0.3 * wave(t, 3))
    return p


def walk(t):
    """Летит (0.8 сек): наклон вперёд, кружится быстрее, шлейф вытянут."""
    p = stance()
    spin(p, t, turns=1.0, wobble=1.5)
    p.add("Hips", x=14 + 3 * wave(t, 2))
    p.move("Hips", z=0.04 * wave(t, 2))
    p.size("Trail", 1.3)
    return p


def attack(t):
    """Порыв (0.9 сек): сжимается → раздувается во все стороны (к 0.4 сек), толкая соседей → опадает."""
    p = stance()
    spin(p, t, turns=1.0, wobble=2.0)
    puff = track(t, [(0, 1.0), (0.25, 0.75), (0.4, 1.5), (0.6, 1.3), (1, 1.0)])
    for i in range(len(BANDS)):
        p.size(f"Spin{i + 1}", puff, 1.0, puff)
    p.add("Head", x=-10 * pulse(t, 0.4, 0.15))
    p.move("Head", z=0.0)
    p.size("Trail", puff)
    return p


def hit(t):
    """Получил удар (0.4 сек): воронку сносит вбок, полосы разлетаются и собираются."""
    p = stance()
    spin(p, t, turns=0.0, wobble=0.0)
    snap = track(t, [(0, 0), (0.15, 1), (0.5, 0.3), (1, 0)])
    p.move("Root", y=0.08 * snap)
    p.add("Hips", x=-18 * snap)
    for i in range(len(BANDS)):
        p.add(f"Spin{i + 1}", z=10 * snap * (1 if i % 2 else -1))
    p.add("Head", x=-16 * snap)
    return p


def death(t):
    """Рассыпается (1.2 сек): кружится всё медленнее, полосы снизу вверх опадают, голова оседает пеплом."""
    p = stance()
    for i in range(len(BANDS)):
        fade = track(t, [(0, 1.0), (0.2 + 0.1 * i, 1.0), (0.4 + 0.1 * i, 0.0), (1, 0.0)])
        p.size(f"Spin{i + 1}", max(0.02, fade))
        p.add(f"Spin{i + 1}", y=200 * track(t, [(0, 0), (1, 1)]) * (1 if i % 2 == 0 else -1))
    p.move("Head", z=-1.0 * track(t, [(0, 0), (0.5, 0.1), (1, 1.05)]))
    p.size("Trail", track(t, [(0, 1), (0.5, 0.2), (1, 0.01)]))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("AshWhirl")
    body = build_mesh()
    rig = k.build_armature("AshWhirl", BONES)
    body.parent = rig
    lb = ("Root", "Hips", "Head")
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=lb, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, loc_bones=lb, scale_bones=SCALED)
    k.bake(rig, "Attack", 27, attack, loc_bones=lb, scale_bones=SCALED)
    k.bake(rig, "Hit", 12, hit, loc_bones=lb, scale_bones=SCALED)
    k.bake(rig, "Death", 36, death, loc_bones=lb, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "ash_whirl")
