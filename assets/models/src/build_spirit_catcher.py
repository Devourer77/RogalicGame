# Ловчий автомат — элита Подземья (акт 2), механизм, который ловил духов для лаборатории (~2.2 м).
# Тонкий и высокий, как механическая цапля: узкий корпус, очень длинные суставчатые ноги, сутулится.
# На спине стойка с тремя пустыми сферами в клетках и одной треснувшей. Правая рука — трубка
# сетемёта с цепной сетью у дула, левая — длинная клешня на телескопе. Голова — узкий держатель
# с одной бирюзовой линзой. Конечности чуть толще, чем на листе Gemini, — иначе не видно с камеры.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (сеть), Attack2 (клешня), Attack3 (сборка — зовёт сферников),
# Hit, Death.
# Запуск: python3 build_spirit_catcher.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))


def build_mesh():
    m = a2.mech_mats()
    glass = k.mat("Catch_Glass", (0.72, 0.84, 0.88), rough=0.1, emit=0.15)
    # Таз и узкий корпус
    k.box("Pelvis", (0.26, 0.18, 0.12), (0, 0, 1.12), m["iron_d"], "Hips")
    k.limb("SpineRod", (0, 0.02, 1.16), (0, 0.04, 1.46), 0.05, 0.05, m["iron"], "Spine", segs=6)
    for i, z in enumerate((1.22, 1.32, 1.42)):
        k.box(f"Rib{i}", (0.16, 0.12, 0.03), (0, 0.02, z), m["bronze_d"], "Spine")
    k.box("Chest", (0.3, 0.2, 0.3), (0, 0.02, 1.6), m["bronze"], "Chest")
    k.box("ChestPlate", (0.22, 0.04, 0.22), (0, -0.09, 1.6), m["bronze_d"], "Chest")
    k.limb("PipeSpine", (0.06, 0.12, 1.2), (0.06, 0.14, 1.72), 0.015, 0.015, m["copper"], "Chest", segs=4)
    k.limb("PipeSpine2", (-0.06, 0.12, 1.2), (-0.06, 0.14, 1.72), 0.015, 0.015, m["copper"], "Chest", segs=4)
    # Голова: узкий держатель с линзой
    k.limb("Neck", (0, -0.02, 1.74), (0, -0.08, 1.84), 0.03, 0.03, m["iron_d"], "Head", segs=5)
    k.box("HeadBox", (0.1, 0.16, 0.12), (0, -0.12, 1.88), m["iron"], "Head")
    k.limb("LensRim", (0, -0.2, 1.88), (0, -0.23, 1.88), 0.05, 0.05, m["iron_d"], "Head", segs=7)
    k.limb("Lens", (0, -0.23, 1.88), (0, -0.24, 1.88), 0.038, 0.038, m["lens"], "Head", segs=7)
    # Стойка со сферами на спине
    k.box("RackPost", (0.04, 0.04, 0.5), (0, 0.16, 1.82), m["iron_d"], "Chest")
    k.box("RackBar", (0.5, 0.04, 0.04), (0, 0.16, 1.9), m["iron_d"], "Chest")
    k.box("RackBar2", (0.36, 0.04, 0.04), (0, 0.16, 2.06), m["iron_d"], "Chest")
    for i, (x, z, r) in enumerate([(-0.22, 1.98, 0.09), (0.22, 1.98, 0.09), (-0.1, 2.14, 0.08), (0.11, 2.14, 0.08)]):
        a2.caged_sphere(f"Spare{i}", r, (x, 0.18, z), glass, m["iron_d"], "Chest", segs=6, rings_=4)
        if i == 3:   # треснувшая
            k.crack("SpareCrack", [(-0.05, 0.04), (0.0, 0.0), (-0.02, -0.03), (0.05, -0.05)], (x, 0.095, z),
                    (1, 0, 0), (0, 0, 1), m["rift"], "Chest", width=0.012, depth=0.012)
    for side, s in SIDES:
        # Плечи и руки
        k.sphere(f"Shoulder.{side}", 0.07, (0.19 * s, 0.02, 1.7), m["iron"], "Chest", segs=6, rings=4)
        k.limb(f"UpperArm.{side}", (0.2 * s, 0.02, 1.68), (0.24 * s, -0.02, 1.36), 0.04, 0.035, m["iron_d"], f"UpperArm.{side}", segs=6)
        k.sphere(f"Elbow.{side}", 0.045, (0.24 * s, -0.02, 1.36), m["bronze_d"], f"ForeArm.{side}", segs=5, rings=3)
        # Ноги: длинное бедро, колено вперёд, длинная голень
        k.sphere(f"HipJ.{side}", 0.06, (0.12 * s, 0, 1.1), m["iron"], "Hips", segs=6, rings=4)
        k.limb(f"Thigh.{side}", (0.12 * s, 0, 1.1), (0.14 * s, -0.14, 0.62), 0.045, 0.04, m["iron_d"], f"Thigh.{side}", segs=6)
        k.box(f"ThighPlate.{side}", (0.07, 0.06, 0.28), (0.13 * s, -0.09, 0.88), m["bronze_d"], f"Thigh.{side}", rot=(16, 0, 0))
        k.sphere(f"Knee.{side}", 0.055, (0.14 * s, -0.14, 0.62), m["bronze_d"], f"Shin.{side}", segs=6, rings=4)
        k.limb(f"Shin.{side}", (0.14 * s, -0.14, 0.62), (0.15 * s, 0.04, 0.1), 0.04, 0.03, m["iron_d"], f"Shin.{side}", segs=6)
        k.limb(f"ShinRod.{side}", (0.15 * s, -0.08, 0.5), (0.155 * s, 0.02, 0.2), 0.012, 0.012, m["copper"], f"Shin.{side}", segs=4)
        k.box(f"Foot.{side}", (0.08, 0.2, 0.04), (0.15 * s, -0.04, 0.03), m["iron"], f"Foot.{side}")
        k.box(f"Toe.{side}", (0.12, 0.05, 0.03), (0.15 * s, -0.16, 0.02), m["iron_d"], f"Foot.{side}")
    # Правая рука — сетемёт
    k.limb("ForeR", (-0.24, -0.02, 1.36), (-0.25, -0.2, 1.28), 0.035, 0.03, m["iron_d"], "ForeArm.R", segs=6)
    k.limb("Launcher", (-0.25, -0.12, 1.3), (-0.26, -0.56, 1.26), 0.055, 0.05, m["bronze"], "Hand.R", segs=7)
    k.limb("Muzzle", (-0.26, -0.56, 1.26), (-0.26, -0.62, 1.26), 0.07, 0.07, m["iron_d"], "Hand.R", segs=7)
    for i in range(5):   # свёрнутая цепная сеть у дула
        k.box(f"Net{i}", (0.06, 0.06, 0.06), (-0.26 + 0.04 * ((i % 3) - 1), -0.66, 1.22 - 0.05 * i), m["steel"], "Net",
              rot=(20 * i, 30 * i, 0))
    # Левая рука — клешня на телескопе
    k.limb("ForeL", (0.24, -0.02, 1.36), (0.25, -0.06, 1.1), 0.035, 0.03, m["iron_d"], "ForeArm.L", segs=6)
    k.limb("Tele1", (0.25, -0.06, 1.1), (0.25, -0.08, 0.84), 0.028, 0.028, m["steel"], "Hand.L", segs=6)
    k.limb("Tele2", (0.25, -0.08, 0.84), (0.25, -0.09, 0.66), 0.02, 0.02, m["steel"], "Hand.L", segs=6)
    k.box("ClawBase", (0.07, 0.07, 0.05), (0.25, -0.09, 0.64), m["iron_d"], "Hand.L")
    for i, ang in enumerate((-1, 1)):
        k.plate(f"Claw{i}", [(0, 0), (0.03, 0), (0.05, -0.12), (0.02, -0.18), (0.01, -0.1)], 0.025,
                (0.25, -0.09 + 0.03 * ang, 0.62), (0, ang, 0), (0, 0, 1), m["steel"], "Hand.L")
    return k.join_parts("SpiritCatcherMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.2), None),
    "Hips": ((0, 0, 1.1), (0, 0, 1.18), "Root"),
    "Spine": ((0, 0, 1.18), (0, 0, 1.46), "Hips"),
    "Chest": ((0, 0, 1.46), (0, 0, 1.76), "Spine"),
    "Head": ((0, -0.02, 1.74), (0, -0.02, 1.94), "Chest"),
    "Net": ((-0.26, -0.62, 1.26), (-0.26, -0.8, 1.26), "Hand.R"),
}
for _side, _s in SIDES:
    BONES.update({
        f"UpperArm.{_side}": ((0.2 * _s, 0.02, 1.68), (0.24 * _s, -0.02, 1.36), "Chest"),
        f"ForeArm.{_side}": ((0.24 * _s, -0.02, 1.36), (0.25 * _s, -0.12, 1.2), f"UpperArm.{_side}"),
        f"Thigh.{_side}": ((0.12 * _s, 0, 1.1), (0.14 * _s, -0.14, 0.62), "Hips"),
        f"Shin.{_side}": ((0.14 * _s, -0.14, 0.62), (0.15 * _s, 0.04, 0.1), f"Thigh.{_side}"),
        f"Foot.{_side}": ((0.15 * _s, 0.04, 0.1), (0.15 * _s, -0.12, 0.03), f"Shin.{_side}"),
    })
BONES["Hand.R"] = ((-0.25, -0.12, 1.3), (-0.26, -0.5, 1.26), "ForeArm.R")
BONES["Hand.L"] = ((0.25, -0.06, 1.1), (0.25, -0.09, 0.64), "ForeArm.L")

STANCE = {
    "Hips": (0, -6, 0), "Spine": (12, -4, 0), "Chest": (14, -4, 0), "Head": (-22, 8, 0),
    "Thigh.L": (-10, 0, -4), "Shin.L": (8, 0, 0), "Thigh.R": (6, 0, 6), "Shin.R": (6, 0, 0),
    "UpperArm.R": (-36, 0, 8), "ForeArm.R": (-30, 0, 0), "UpperArm.L": (-10, 0, -8), "ForeArm.L": (-20, 0, 0),
}
STANCE_LOC = {"Hips": (0, 0, -0.03)}
SCALED = ("Net",)


def stance():
    return Pose(STANCE, STANCE_LOC)


def idle(t):
    """Покой (3 сек): покачивается на длинных ногах, вертит линзой, целится, клешня пощёлкивает."""
    p = stance()
    sway = wave(t, 1)
    p.move("Hips", x=0.02 * sway, z=-0.01 * wave(t, 2))
    p.add("Hips", z=2 * sway)
    p.add("Spine", x=2 * wave(t, 2))
    look = k.track(t, [(0, 0), (0.15, 0), (0.2, -26), (0.45, -26), (0.5, 20), (0.75, 20), (0.8, 0), (1, 0)])
    p.add("Head", y=look, x=-4 * pulse(t, 0.48, 0.05))
    p.add("Chest", y=look * 0.3)
    p.add("UpperArm.R", x=-4 * wave(t, 1, 0.3), z=look * 0.1)
    p.add("Hand.L", x=-10 * (pulse(t, 0.62, 0.04) + pulse(t, 0.7, 0.04)))
    return p


def walk(t):
    """Длинный шаг (1.0 сек): высокие колени, корпус кивает вперёд, как цапля."""
    p = Pose(STANCE)
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bob = wave(t, 2, 0.1)
    p.move("Hips", z=-0.04 + 0.03 * bob)
    p.add("Hips", y=-6 + 4 * a)
    p.set("Thigh.R", -2 - 26 * a, 0, 6)
    p.set("Thigh.L", -2 + 26 * a, 0, -4)
    p.set("Shin.R", 6 + 30 * max(0.0, c), 0, 0)
    p.set("Shin.L", 6 + 30 * max(0.0, -c), 0, 0)
    p.add("Spine", x=4 * bob)
    p.add("Head", x=-6 * bob, y=4 * a)
    p.add("UpperArm.L", x=10 * a)
    p.add("UpperArm.R", x=-4 * a)
    return p


def attack(t):
    """Сеть (0.9 сек): целится, корпус подаётся вперёд → выстрел (к 0.4 сек), отдача, сеть
    разворачивается у дула → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.25, 0.4, 0.58, 1.0]
    for bone, *keys in [
        ("Spine", (16, 4, 0), (4, -6, 0), (8, -4, 0)),
        ("Chest", (16, 6, 0), (6, -6, 0), (10, -4, 0)),
        ("Head", (-26, -8, 0), (-16, 0, 0), (-20, 0, 0)),
        ("UpperArm.R", (-70, 0, 4), (-60, 0, 4), (-60, 0, 4)),
        ("ForeArm.R", (-14, 0, 0), (-4, 0, 0), (-8, 0, 0)),
        ("Thigh.L", (-16, 0, -4), (-8, 0, -4), (-10, 0, -4)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.size("Net", track(t, [(0, 1.0), (K[2] - 0.02, 1.0), (K[2] + 0.06, 3.0), (K[3], 2.4), (K[3] + 0.08, 0.2), (1, 1.0)]))
    p.move("Root", y=track(t, [(0, 0), (K[2], 0.0), (K[2] + 0.05, 0.06), (K[3], 0.04), (1, 0)]))
    return p


def attack2(t):
    """Клешня (0.9 сек): телескоп отведён → бросок клешни вперёд-вниз (к 0.4 сек), хватка → возврат."""
    p = Pose({}, {})
    K = [0.0, 0.24, 0.4, 0.6, 1.0]
    for bone, *keys in [
        ("Spine", (6, 14, 0), (22, -10, 0), (20, -8, 0)),
        ("Chest", (6, 12, 0), (18, -10, 0), (16, -8, 0)),
        ("UpperArm.L", (20, 0, -20), (-80, 0, -4), (-70, 0, -4)),
        ("ForeArm.L", (-60, 0, 0), (0, 0, 0), (-10, 0, 0)),
        ("Hand.L", (20, 0, 0), (-10, 0, 0), (-20, 0, 0)),
        ("Head", (-18, -10, 0), (-30, 6, 0), (-28, 4, 0)),
    ]:
        a2.keyed(p, t, K, STANCE, bone, *keys)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.04), (K[2], -0.1), (K[3], -0.08), (1, 0)]))
    return p


def attack3(t):
    """Сборка (1.0 сек): выпрямляется, руки в стороны, стойка со сферами трясётся, корпус гудит."""
    p = stance()
    up = track(t, [(0, 0), (0.3, 1), (0.75, 1), (1, 0)])
    buzz = up * wave(t, 10)
    p.add("Spine", x=-10 * up)
    p.add("Chest", x=-8 * up, z=3 * buzz)
    p.add("Head", x=10 * up, y=6 * buzz)
    p.add("UpperArm.R", z=30 * up, x=-10 * up)
    p.add("UpperArm.L", z=-30 * up, x=-10 * up)
    p.move("Hips", z=0.05 * up)
    return p


def hit(t):
    """Получил удар (0.5 сек): длинное тело складывается назад, голова мотается, руки отлетают."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.move("Root", y=0.08 * snap)
    p.add("Spine", x=-14 * snap, y=8 * snap)
    p.add("Chest", x=-10 * whip)
    p.add("Head", x=-20 * whip, z=10 * whip)
    p.add("UpperArm.R", x=20 * whip)
    p.add("UpperArm.L", x=24 * whip, z=-14 * whip)
    p.add("Shin.R", x=10 * snap)
    return p


def death(t):
    """Гибель (1.4 сек): колени подламываются, длинное тело складывается, валится набок; линза
    в конце дёргается."""
    p = Pose({}, {})
    K = [0.0, 0.2, 0.45, 0.72, 1.0]
    for bone, *keys in [
        ("Spine", (-10, 10, 0), (20, 0, 0), (26, 0, 0), (24, 0, 0)),
        ("Chest", (-8, 8, 0), (16, 0, 0), (20, 0, 0), (18, 0, 0)),
        ("Head", (-30, -20, 0), (10, 10, 0), (-20, 30, 0), (-16, 34, 0)),
        ("UpperArm.R", (10, 0, 30), (-10, 0, 20), (-60, 0, 60), (-60, 0, 64)),
        ("UpperArm.L", (16, 0, -30), (-6, 0, -20), (-40, 0, -50), (-40, 0, -54)),
        ("Thigh.L", (-10, 0, -6), (-70, 0, -8), (-40, 0, -8), (-30, 0, -8)),
        ("Shin.L", (12, 0, 0), (110, 0, 0), (60, 0, 0), (40, 0, 0)),
        ("Thigh.R", (-14, 0, 8), (-70, 0, 10), (-40, 0, 10), (-30, 0, 10)),
        ("Shin.R", (14, 0, 0), (110, 0, 0), (60, 0, 0), (40, 0, 0)),
    ]:
        a2.keyed_end(p, t, K, STANCE, bone, *keys)
    fall = track(t, [(0, 0), (K[2], 4), (K[3], 70), (K[3] + 0.06, 64), (K[3] + 0.12, 72), (1, 72)])
    p.set("Root", 0, 0, fall)
    p.move("Root", x=track(t, [(0, 0), (K[3], 0.3), (1, 0.3)]), z=track(t, [(0, 0), (K[3], 0.18), (1, 0.18)]))
    p.move("Hips", z=track(t, [(0, -0.03), (K[1], 0), (K[2], -0.5), (K[3], -0.3), (1, -0.3)]))
    p.add("Head", y=20 * pulse(t, 0.9, 0.05))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("SpiritCatcher")
    body = build_mesh()
    rig = k.build_armature("SpiritCatcher", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 30, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 27, attack, scale_bones=SCALED)
    k.bake(rig, "Attack2", 27, attack2, scale_bones=SCALED)
    k.bake(rig, "Attack3", 30, attack3, scale_bones=SCALED)
    k.bake(rig, "Hit", 15, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 42, death, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "spirit_catcher")
