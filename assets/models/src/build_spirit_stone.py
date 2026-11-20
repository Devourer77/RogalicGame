# Каменник — обычный дух камня (акт 2, Подземье), ~1.3 м. Скопление тёмного базальта и серых глыб, которые
# парят по отдельности: сутулый торс, тяжёлая голова-блок без лица, руки из камней друг над другом с плоскими
# кистями-плитами; вместо ног — камни парят над кучкой щебня на полу. В щелях между камнями и в глазах —
# бирюзовый свет, тонкие бирюзовые трещины на крупных камнях. Без лавы (это не Шлаковый голем).
# Смотрит в -Y. Анимации: Idle, Walk, Attack (удар плитой), Attack2 (обвал — поднимает стену), Hit,
# Death (покорение — осыпается в кучу щебня).
# Запуск: python3 build_spirit_stone.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))
FLOATS = (("Float1", 0.46, 0.13), ("Float2", 0.32, 0.1), ("Float3", 0.2, 0.08))


def build_mesh():
    v = a2.volcano_mats()
    stone = k.mat("SS_Stone", (0.4, 0.39, 0.4), rough=0.85)
    stone_b = k.mat("SS_StoneBrown", (0.46, 0.41, 0.37), rough=0.9)
    glow = k.mat("SS_Glow", (0.30, 0.95, 0.85), rough=0.4, emit=1.4)
    # Светящаяся сердцевина — видна в щелях
    k.sphere("Core", 0.2, (0, 0, 0.96), glow, "Chest", scale=(1.1, 0.9, 1.1), segs=6, rings=4)
    # Торс из нескольких глыб
    for i, (x, y, z, sz, rot, mat) in enumerate([
        (0.0, -0.06, 1.04, (0.42, 0.32, 0.3), (6, 0, 4), stone),
        (-0.16, 0.0, 0.86, (0.26, 0.28, 0.24), (0, 10, -12), stone_b),
        (0.16, 0.0, 0.86, (0.26, 0.28, 0.24), (0, -10, 12), stone),
        (0.0, 0.1, 1.12, (0.36, 0.24, 0.24), (16, 0, 0), stone_b),
        (0.0, -0.02, 0.72, (0.24, 0.22, 0.16), (0, 0, 20), stone),
    ]):
        a2.rock(f"Torso{i}", sz, (x, y, z), mat, "Chest", rot=rot, seed=i)
    k.crack("TorsoRift", [(0, 0), (0.05, 0.06), (0.12, 0.02)], (-0.08, -0.25, 1.06), (1, 0, 0), (0, 0, 1), v["rift"],
            "Chest", width=0.014, depth=0.014)
    # Голова-блок
    k.box("Head", (0.22, 0.2, 0.22), (0, -0.1, 1.32), stone, "Head", rot=(-6, 0, 0))
    k.box("Brow", (0.24, 0.06, 0.05), (0, -0.2, 1.37), stone_b, "Head")
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.045, 0.02, 0.025), (0.05 * s, -0.21, 1.32), glow, "Head")
    # Парящие камни под торсом и щебень на полу
    for name, z, r in FLOATS:
        a2.rock(name, (r * 2.2, r * 2.0, r * 1.6), (0.02, -0.01, z), stone if name != "Float2" else stone_b, name, seed=len(name) + z)
    for i in range(7):
        a = math.tau * i / 7
        rr = 0.14 + 0.06 * (i % 2)
        a2.rock(f"Rubble{i}", (0.1, 0.09, 0.06), (rr * math.cos(a), rr * math.sin(a), 0.03), stone_b if i % 2 else stone,
                "Root", rot=(0, 0, 40 * i), seed=10 + i)
    # Руки: камни друг над другом, кисти-плиты
    for side, s in SIDES:
        a2.rock(f"Shoulder.{side}", (0.22, 0.22, 0.2), (0.3 * s, 0.0, 1.12), stone_b, "Chest", seed=20 + s)
        a2.rock(f"UpperArm.{side}", (0.17, 0.17, 0.2), (0.38 * s, -0.04, 0.92), stone, f"UpperArm.{side}", seed=22 + s)
        k.sphere(f"ElbowGlow.{side}", 0.04, (0.4 * s, -0.06, 0.8), glow, f"ForeArm.{side}", segs=5, rings=3)
        a2.rock(f"ForeArm.{side}", (0.16, 0.16, 0.18), (0.42 * s, -0.08, 0.66), stone_b, f"ForeArm.{side}", seed=24 + s)
        k.box(f"Hand.{side}", (0.2, 0.08, 0.24), (0.44 * s, -0.12, 0.46), stone, f"Hand.{side}", rot=(10, 0, 8 * s))
        k.crack(f"HandRift.{side}", [(0, 0), (0.04, 0.05), (0.02, 0.1)], (0.42 * s, -0.165, 0.42), (1, 0, 0), (0, 0, 1),
                v["rift"], f"Hand.{side}", width=0.012, depth=0.012)
    return k.join_parts("SpiritStoneMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Hips": ((0, 0, 0.62), (0, 0, 0.76), "Root"),
    "Chest": ((0, 0, 0.76), (0, 0, 1.2), "Hips"),
    "Head": ((0, -0.06, 1.2), (0, -0.08, 1.46), "Chest"),
}
for _name, _z, _r in FLOATS:
    BONES[_name] = ((0, 0, _z - _r), (0, 0, _z + _r), "Hips")
for _side, _s in SIDES:
    BONES.update({
        f"UpperArm.{_side}": ((0.32 * _s, 0.0, 1.08), (0.4 * _s, -0.06, 0.8), "Chest"),
        f"ForeArm.{_side}": ((0.4 * _s, -0.06, 0.8), (0.43 * _s, -0.1, 0.56), f"UpperArm.{_side}"),
        f"Hand.{_side}": ((0.43 * _s, -0.1, 0.56), (0.44 * _s, -0.12, 0.34), f"ForeArm.{_side}"),
    })

STANCE = {"Chest": (8, -6, 0), "Head": (-8, 6, 0), "UpperArm.R": (-14, 0, 8), "UpperArm.L": (-10, 0, -8),
          "ForeArm.R": (-20, 0, 0), "ForeArm.L": (-16, 0, 0)}
STANCE_LOC = {"Hips": (0, 0, 0.04)}
LB = ("Root", "Hips", "Float1", "Float2", "Float3", "Head", "UpperArm.R", "UpperArm.L", "ForeArm.R", "ForeArm.L")


def stance():
    return Pose(STANCE, STANCE_LOC)


def bob(p, t, amp=0.02):
    """Каждый камень парит со своей фазой."""
    p.move("Hips", z=0.04 + amp * wave(t, 2))
    for i, (name, _, _) in enumerate(FLOATS):
        p.move(name, z=amp * 1.4 * wave(t, 2, 0.2 * (i + 1)))
        p.add(name, z=20 * wave(t, 1, 0.3 * i))
    p.move("Head", z=amp * 0.6 * wave(t, 2, 0.4))
    for j, side in enumerate(("R", "L")):
        p.move(f"UpperArm.{side}", z=amp * 0.5 * wave(t, 2, 0.15 + 0.3 * j))
        p.move(f"ForeArm.{side}", z=amp * 0.5 * wave(t, 2, 0.35 + 0.3 * j))


def idle(t):
    """Покой (3 сек): камни парят и поворачиваются по отдельности, голова медленно оглядывается."""
    p = stance()
    bob(p, t)
    p.add("Head", y=k.track(t, [(0, 0), (0.3, 0), (0.4, -16), (0.65, -16), (0.75, 10), (0.9, 10), (1, 0)]))
    p.add("Chest", y=4 * wave(t, 1))
    return p


def walk(t):
    """Плывёт над полом (0.9 сек): наклон вперёд, камни-ноги отстают, руки покачиваются."""
    p = stance()
    bob(p, t, amp=0.03)
    p.add("Hips", x=10)
    for i, (name, _, _) in enumerate(FLOATS):
        p.add(name, x=12 + 6 * i)
    a = wave(t, 1)
    p.add("UpperArm.R", x=-10 * a)
    p.add("UpperArm.L", x=10 * a)
    return p


def attack(t):
    """Удар плитой (0.9 сек): правая рука взлетает → обрушивается вниз-вперёд (к 0.4 сек) → камни рук
    расходятся и собираются."""
    p = Pose({}, {})
    K = [0.0, 0.26, 0.4, 0.6, 1.0]
    for bone, *keys in [
        ("Chest", (-10, 12, 0), (18, -8, 0), (16, -8, 0)),
        ("UpperArm.R", (-160, 0, 16), (-50, 0, 4), (-44, 0, 4)),
        ("ForeArm.R", (-20, 0, 0), (-6, 0, 0), (-8, 0, 0)),
        ("UpperArm.L", (-20, 0, -24), (6, 0, -12), (4, 0, -10)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    spread = pulse(t, 0.42, 0.12)
    p.move("ForeArm.R", z=-0.06 * spread)
    p.move("Hips", z=0.04 + track(t, [(0, 0), (K[1], 0.06), (K[2], -0.06), (1, 0)]))
    p.move("Root", y=track(t, [(0, 0), (K[2], -0.08), (1, 0)]))
    return p


def attack2(t):
    """Обвал (1.0 сек): обе руки вверх, щебень на полу поднимается, затем руки падают — встаёт стена."""
    p = stance()
    lift = track(t, [(0, 0), (0.35, 1), (0.5, 1), (0.6, 0.2), (1, 0)])
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=-140 * lift, z=20 * lift * s)
        p.add(f"ForeArm.{side}", x=-20 * lift)
    p.add("Chest", x=-10 * lift)
    p.move("Hips", z=0.04 + 0.1 * lift)
    for i, (name, _, _) in enumerate(FLOATS):
        p.move(name, z=0.05 * lift * (i + 1))
    return p


def hit(t):
    """Получил удар (0.4 сек): камни разлетаются в стороны и снова собираются."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.5, 0.3), (1, 0)])
    p.move("Root", y=0.05 * snap)
    p.add("Chest", x=-12 * snap)
    p.move("Head", z=0.06 * snap, y=0.04 * snap)
    for j, side in enumerate(("R", "L")):
        p.move(f"UpperArm.{side}", x=(0.05 if side == "L" else -0.05) * snap)
    for i, (name, _, _) in enumerate(FLOATS):
        p.move(name, x=0.04 * snap * (1 if i % 2 else -1))
    return p


def death(t):
    """Покорение (1.2 сек): свет гаснет, камни один за другим падают в кучу щебня."""
    p = stance()
    for i, (name, z, _) in enumerate(FLOATS):
        fall = track(t, [(0, 0), (0.1 + 0.08 * i, 0), (0.3 + 0.08 * i, 1), (1, 1)])
        p.move(name, z=-(z - 0.1 - 0.06 * i) * fall)
    drop = track(t, [(0, 0), (0.35, 0), (0.75, 1), (0.82, 0.95), (1, 1)])
    p.move("Hips", z=0.04 - 0.62 * drop)
    p.add("Chest", x=30 * drop, z=10 * drop)
    p.move("Head", z=-0.1 * drop, x=0.1 * drop)
    for side, s in SIDES:
        p.add(f"UpperArm.{side}", x=20 * drop, z=-30 * drop * s)
    return p


def build(glb_path, blend_path=None):
    k.start_scene("SpiritStone")
    body = build_mesh()
    rig = k.build_armature("SpiritStone", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LB)
    k.bake(rig, "Walk", 27, walk, cyclic=True, loc_bones=LB)
    k.bake(rig, "Attack", 27, attack, loc_bones=LB)
    k.bake(rig, "Attack2", 30, attack2, loc_bones=LB)
    k.bake(rig, "Hit", 12, hit, loc_bones=LB)
    k.bake(rig, "Death", 36, death, loc_bones=LB)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "spirit_stone")
