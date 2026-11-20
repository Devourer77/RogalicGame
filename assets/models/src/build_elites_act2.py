# Элиты и боссы акта 2 по старым заготовкам (`враги-акт-2.md`), собранные по описаниям облика
# (референсы Gemini для них в работу не попали). Один скрипт — четыре модели:
#   ash_serpent (элита Пепельная змея), rift_matriarch (элита Матка Разлома),
#   crown_vessel (босс Сосуд Венца), convoy_giant (босс Обозный Исполин).
# Модели помещаются в клетку; крупнее в бою — через `size` в `.tres`.
# Смотрят в -Y. Анимации: Idle, Walk, Attack, Attack2, Attack3, Hit, Death
# (Attack/2/3 — три удара цикла по порядку из `враги-акт-2.md`).
# Запуск: python3 build_elites_act2.py — все; ONLY=ash_serpent python3 build_elites_act2.py — одну.
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2
import act2_human as hu
from build_beasts_act2 import std_hit, roll_death, SIDES


# ---------- Пепельная змея ----------
# Кольца лежат на клетке, передняя часть поднята цепочкой из четырёх костей.
NECK = [(0, 0.06, 0.18), (0, 0.0, 0.55), (0, -0.08, 0.92), (0, -0.14, 1.22), (0, -0.18, 1.42)]


def serpent_mesh():
    v = a2.volcano_mats()
    slag = k.mat("SN_Slag", (0.17, 0.17, 0.18), rough=0.6)
    crust = k.mat("SN_Crust", (0.46, 0.45, 0.43), rough=0.95)
    belly = k.mat("SN_Belly", (0.36, 0.34, 0.31), rough=0.9)
    scale_d = k.mat("SN_Scale", (0.3, 0.29, 0.28), rough=0.9)
    # кольца на земле: две петли из отрезков
    n = 14
    for loop, (r, z, bone) in enumerate(((0.36, 0.1, "Coil"), (0.24, 0.26, "Coil"))):
        pts = []
        for i in range(n + 1):
            a = math.tau * i / n + loop * 0.6
            pts.append((r * math.cos(a), 0.05 + r * math.sin(a), z))
        for i in range(n):
            th = 0.11 - 0.012 * loop
            k.limb(f"Coil{loop}_{i}", pts[i], pts[i + 1], th, th, slag if i % 4 else scale_d, bone, segs=7)
    # хвост уходит с колец наружу — отдельной костью, для хлёста
    k.limb("Tail1", (0.36, 0.05, 0.1), (0.42, 0.34, 0.08), 0.08, 0.06, slag, "Tail", segs=6)
    k.limb("Tail2", (0.42, 0.34, 0.08), (0.3, 0.56, 0.06), 0.06, 0.015, crust, "Tail", segs=6)
    # поднятая шея
    for i in range(4):
        r0 = 0.14 - 0.014 * i
        k.limb(f"Neck{i}", NECK[i], NECK[i + 1], r0, r0 - 0.012, slag, f"Neck{i + 1}", segs=8)
        k.box(f"Belly{i}", (0.1, 0.03, 0.3), ((NECK[i][0] + NECK[i + 1][0]) / 2, (NECK[i][1] + NECK[i + 1][1]) / 2 - r0 + 0.01,
                                              (NECK[i][2] + NECK[i + 1][2]) / 2), belly, f"Neck{i + 1}", rot=(-10, 0, 0))
    # капюшон кобры — плоская пластина за головой, с бирюзовыми трещинами
    hood = [(0, -0.08), (0.18, 0.0), (0.3, 0.16), (0.24, 0.32), (0.09, 0.38), (0, 0.38)]
    hood = [(-x, y) for x, y in reversed(hood[1:])] + hood
    k.plate("Hood", hood, 0.035, (0, -0.08, 1.02), (1, 0, 0), (0, 0, 1), crust, "Neck4")
    for s in (-1, 1):
        k.crack(f"HoodRift{s}", [(0, 0), (0.04, 0.08), (0.02, 0.16), (0.06, 0.24)], (0.1 * s, -0.11, 1.06),
                (s, 0, 0), (0, 0, 1), v["rift"], "Neck4", width=0.016, depth=0.012)
    # голова и челюсть
    k.sphere("Head", 0.09, (0, -0.26, 1.44), slag, "Head", scale=(1.0, 1.4, 0.7), segs=8, rings=4)
    k.box("Brow", (0.16, 0.12, 0.03), (0, -0.28, 1.48), crust, "Head", rot=(-6, 0, 0))
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.025, 0.02, 0.018), (0.055 * s, -0.36, 1.47), v["rift"], "Head")
    k.limb("Jaw", (0, -0.22, 1.38), (0, -0.4, 1.38), 0.05, 0.025, belly, "Jaw", segs=6)
    for i in range(3):   # пепел из пасти
        k.box(f"Ash{i}", (0.02, 0.02, 0.02), (0.02 * (i - 1), -0.42 - 0.04 * i, 1.36 - 0.05 * i), crust, "Jaw",
              rot=(30 * i, 20 * i, 0))


SERPENT_BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Coil": ((0, 0.05, 0.0), (0, 0.05, 0.2), "Root"),
                 "Tail": ((0.36, 0.05, 0.1), (0.3, 0.56, 0.06), "Coil")}
_par = "Coil"
for _i in range(4):
    SERPENT_BONES[f"Neck{_i + 1}"] = (NECK[_i], NECK[_i + 1], _par)
    _par = f"Neck{_i + 1}"
SERPENT_BONES["Head"] = ((0, -0.18, 1.42), (0, -0.4, 1.46), "Neck4")
SERPENT_BONES["Jaw"] = ((0, -0.2, 1.38), (0, -0.42, 1.36), "Head")


def serpent_anims():
    S = {"Neck1": (-4, 0, 0), "Neck4": (8, 0, 0)}

    def sway(p, t, amp=1.0, speed=1):
        for i in range(4):
            p.add(f"Neck{i + 1}", z=5 * amp * wave(t, speed, -0.1 * i), x=2 * amp * wave(t, speed * 2, -0.1 * i))

    def idle(t):
        p = Pose(S)
        sway(p, t)
        p.add("Head", z=k.track(t, [(0, 0), (0.3, 0), (0.34, -18), (0.6, -18), (0.64, 14), (0.9, 14), (1, 0)]))
        p.add("Jaw", x=-14 * pulse(t, 0.75, 0.06))
        p.add("Tail", z=8 * wave(t, 1, 0.3))
        p.size("Coil", 1.0, 1.0, 1.0 + 0.03 * wave(t, 2))
        return p

    def walk(t):
        p = Pose(S)
        sway(p, t, amp=2.0, speed=2)
        p.add("Coil", z=6 * wave(t, 1))
        p.add("Tail", z=24 * wave(t, 1, 0.25))
        p.move("Root", x=0.03 * wave(t, 1))
        return p

    def strike(t):
        # Удушье: откинуться назад → бросок вперёд и вниз к 0.4 сек
        p = Pose(S)
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.65, 0.8), (1, 0)])
        p.add("Neck1", x=14 * a)
        p.add("Neck2", x=20 * a)
        p.add("Neck3", x=16 * a)
        p.add("Head", x=-10 * max(0.0, a))
        p.add("Jaw", x=-30 * pulse(t, 0.35, 0.12))
        return p

    def tail(t):
        # Хлёст хвостом: шея уклоняется, хвост бьёт по дуге
        p = Pose(S)
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.6, 0.6), (1, 0)])
        p.add("Coil", z=-30 * a)
        p.add("Tail", z=-60 * a)
        sway(p, t)
        p.add("Neck2", z=10 * a)
        return p

    def breath(t):
        # Пепельный выдох: голова назад, пасть настежь, выдох вперёд
        p = Pose(S)
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.75, 1), (1, 0)])
        p.add("Neck3", x=12 * a)
        p.add("Head", x=-14 * min(0.0, a) * -1 + 6 * max(0.0, a))
        p.add("Jaw", x=-40 * max(0.0, a))
        return p

    def hit(t):
        p = Pose(S)
        snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
        whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
        p.add("Neck2", x=-14 * snap)
        p.add("Neck3", x=-10 * whip, z=8 * whip)
        p.add("Head", x=-14 * whip)
        return p

    def death(t):
        p = Pose(S)
        f = track(t, [(0, 0), (0.2, -0.1), (0.6, 1), (0.7, 0.92), (0.8, 1), (1, 1)])
        p.add("Neck1", x=-30 * f, z=20 * f)
        p.add("Neck2", x=50 * f)
        p.add("Neck3", x=30 * f, z=-20 * f)
        p.add("Head", x=20 * f, z=30 * f)
        p.add("Jaw", x=-30 * f)
        p.add("Tail", z=20 * pulse(t, 0.85, 0.06))
        return p
    return [("Idle", 90, idle, True), ("Walk", 30, walk, True), ("Attack", 24, strike, False),
            ("Attack2", 24, tail, False), ("Attack3", 27, breath, False), ("Hit", 12, hit, False), ("Death", 39, death, False)]


# ---------- Матка Разлома ----------
MAT_LEGS = ((0, 0.34, -0.26), (1, 0.4, 0.0), (2, 0.34, 0.26))


def matriarch_mesh():
    v = a2.volcano_mats()
    stone = k.mat("RM_Stone", (0.4, 0.39, 0.38), rough=0.85)
    stone_d = k.mat("RM_StoneDark", (0.27, 0.26, 0.26), rough=0.9)
    glow = k.mat("RM_Glow", (0.30, 0.95, 0.85), rough=0.4, emit=1.4)
    cocoon = k.mat("RM_Cocoon", (0.42, 0.78, 0.7), rough=0.5, emit=0.55, alpha=0.9)
    k.sphere("Inner", 0.36, (0, 0, 0.42), glow, "Body", scale=(0.7, 1.1, 0.75), segs=8, rings=4)
    k.sphere("Under", 0.4, (0, 0, 0.3), stone_d, "Body", scale=(1.05, 1.1, 0.35), segs=10, rings=4)
    # купол из двух половин — между ними зигзагом светится трещина; половины расходятся при ударах
    for side, s in SIDES:
        k.sphere(f"Dome.{side}", 0.44, (0.07 * -s * -1, 0, 0.36), stone, f"Shell.{side}", scale=(0.62, 1.1, 0.85),
                 segs=10, rings=5)
        for i in range(4):
            a2.rock(f"Knob.{side}{i}", (0.1, 0.12, 0.07), (0.22 * -s * -1, -0.28 + 0.18 * i, 0.58 - 0.06 * abs(i - 1.5)),
                    stone_d, f"Shell.{side}", rot=(10 * i, 0, 15 * s), seed=80 + i + (4 if s > 0 else 0))
    k.crack("Zigzag", [(0, 0), (0.06, 0.12), (-0.05, 0.24), (0.06, 0.36), (-0.04, 0.48), (0.04, 0.6), (0, 0.72)],
            (0, -0.36, 0.73), (1, 0, 0), (0, 1, 0), glow, "Body", width=0.05, depth=0.04)
    # «лицо»: каменный козырёк и щель с глазами спереди
    k.box("Brow", (0.36, 0.1, 0.1), (0, -0.48, 0.42), stone_d, "Front", rot=(18, 0, 0))
    for i, x in enumerate((-0.1, -0.035, 0.035, 0.1)):
        k.box(f"Eye{i}", (0.03, 0.02, 0.025), (x, -0.5, 0.35 + 0.015 * (i % 2)), v["rift"], "Front")
    # коконы по нижнему краю
    for i in range(6):
        a = math.tau * (i + 0.5) / 6
        x, y = 0.42 * math.cos(a), 0.46 * math.sin(a)
        k.limb(f"Thread{i}", (x, y, 0.24), (x * 1.05, y * 1.05, 0.14), 0.01, 0.008, cocoon, "Cocoons", segs=4)
        k.sphere(f"Cocoon{i}", 0.055, (x * 1.06, y * 1.06, 0.1), cocoon, "Cocoons", scale=(0.8, 0.8, 1.3), segs=6, rings=4)
    # шесть коротких лап-подпорок
    for side, s in SIDES:
        for i, x, y in MAT_LEGS:
            hip = (x * -s * -1 * 1.0, y, 0.24)
            ft = (x * 1.35 * -s * -1, y * 1.15, 0.02)
            k.limb(f"Leg{i}.{side}", hip, ft, 0.06, 0.04, stone_d, f"Leg{i}.{side}", segs=6)
            k.box(f"Toe{i}.{side}", (0.08, 0.08, 0.04), (ft[0], ft[1], 0.02), stone, f"Leg{i}.{side}")


MATRIARCH_BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Body": ((0, 0, 0.1), (0, 0, 0.5), "Root"),
                   "Front": ((0, -0.4, 0.3), (0, -0.4, 0.5), "Body"), "Cocoons": ((0, 0, 0.24), (0, 0, 0.4), "Body")}
for _side, _s in SIDES:
    MATRIARCH_BONES[f"Shell.{_side}"] = ((0.04 * _s, 0, 0.3), (0.04 * _s, 0, 0.6), "Body")
    for _i, _x, _y in MAT_LEGS:
        MATRIARCH_BONES[f"Leg{_i}.{_side}"] = ((_x * _s, _y, 0.24), (_x * 1.35 * _s, _y * 1.15, 0.02), "Body")


def matriarch_anims():
    def open_(p, a):
        # Shell.L — на +X; Z+ наклоняет кость к -X, значит левую половину раскрываем минусом
        p.add("Shell.L", z=-14 * a)
        p.add("Shell.R", z=14 * a)

    def idle(t):
        p = Pose({})
        br = wave(t, 1)
        p.move("Body", z=0.008 * br)
        open_(p, 0.15 + 0.15 * br)
        p.size("Cocoons", 1.0 + 0.05 * wave(t, 3))
        p.add("Front", x=4 * pulse(t, 0.6, 0.1))
        return p

    def walk(t):
        # стоит на месте (шаги 0); переминается на лапах
        p = idle(t)
        for side in ("R", "L"):
            for i, _, _ in MAT_LEGS:
                p.add(f"Leg{i}.{side}", x=8 * wave(t, 1, i * 0.33 + (0.5 if side == "L" else 0)))
        return p

    def summon(t):
        # Кладка: раскрыться, коконы набухают и вздрагивают
        p = Pose({})
        a = track(t, [(0, 0), (0.3, 1), (0.7, 1), (1, 0)])
        open_(p, a)
        p.move("Body", z=0.05 * a)
        p.size("Cocoons", 1.0 + 0.4 * a + 0.1 * pulse(t, 0.45, 0.08))
        return p

    def gas(t):
        # Газовый выдох: присесть, затем распахнуться
        p = Pose({})
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.7, 0.8), (1, 0)])
        open_(p, max(0.0, a) * 1.3)
        p.move("Body", z=-0.05 * max(0.0, -a) + 0.03 * max(0.0, a))
        return p

    def beam(t):
        # Луч Разлома: перед поднимается, «лицо» нацеливается
        p = Pose({})
        a = track(t, [(0, 0), (0.25, -0.5), (0.4, 1), (0.75, 1), (1, 0)])
        p.add("Body", x=-10 * max(0.0, a) + 6 * max(0.0, -a))
        p.add("Front", x=-14 * max(0.0, a))
        open_(p, 0.5 * max(0.0, a))
        return p

    def hit(t):
        p = Pose({})
        snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
        p.add("Body", x=-6 * snap, z=4 * snap)
        open_(p, -0.2 * snap)
        p.size("Cocoons", 1.0 + 0.1 * snap)
        return p

    def death(t):
        p = Pose({})
        f = track(t, [(0, 0), (0.3, -0.2), (0.7, 1), (0.8, 0.9), (1, 1)])
        open_(p, 2.2 * max(0.0, f))
        p.move("Body", z=-0.12 * max(0.0, f))
        for side in ("R", "L"):
            for i, _, _ in MAT_LEGS:
                p.add(f"Leg{i}.{side}", z=(40 if side == "R" else -40) * max(0.0, f))
        p.size("Cocoons", max(0.05, 1.0 - max(0.0, f)))
        return p
    return [("Idle", 90, idle, True), ("Walk", 30, walk, True), ("Attack", 30, summon, False),
            ("Attack2", 27, gas, False), ("Attack3", 27, beam, False), ("Hit", 12, hit, False), ("Death", 39, death, False)]


# ---------- Сосуд Венца ----------
CAGE_R = 0.36
CAGE_Z0, CAGE_Z1 = 0.3, 1.36
VESSEL_LEGS = (("FL", 0.3, -0.3), ("FR", -0.3, -0.3), ("BL", 0.3, 0.3), ("BR", -0.3, 0.3))


def vessel_mesh():
    v = a2.volcano_mats()
    c = hu.cult_mats()
    flame = k.mat("CV_Flame", (0.95, 0.3, 0.04), rough=0.4, emit=0.95)
    core = k.mat("CV_Core", (1.0, 0.6, 0.18), rough=0.4, emit=1.2)
    # пленный дух — внутри клетки
    k.sphere("SpiritBody", 0.24, (0, 0, 0.78), flame, "Spirit", scale=(1.0, 0.9, 1.25), segs=8, rings=5)
    k.limb("SpiritTip", (0, 0.02, 1.0), (0, 0.06, 1.24), 0.16, 0.01, flame, "Spirit", segs=7)
    k.sphere("SpiritCore", 0.11, (0, -0.1, 0.78), core, "Spirit", segs=7, rings=4)
    for s in (-1, 1):
        k.box(f"SpiritEye{s}", (0.04, 0.02, 0.03), (0.07 * s, -0.215, 0.86), v["rift"], "Spirit")
        k.crack(f"SpiritRift{s}", [(0, 0), (0.03, 0.06), (0.0, 0.12)], (0.1 * s, -0.21, 0.66), (1, 0, 0), (0, 0, 1),
                v["rift"], "Spirit", width=0.014, depth=0.014)
    for side, s in SIDES:   # огненные «ладони» давят на прутья
        k.limb(f"SpiritArm.{side}", (0.16 * -s * -1, -0.04, 0.82), (0.3 * -s * -1, -0.12, 0.92), 0.07, 0.05, flame,
               f"SpiritArm.{side}", segs=6)
        k.sphere(f"SpiritHand.{side}", 0.06, (0.31 * -s * -1, -0.13, 0.93), core, f"SpiritArm.{side}", segs=6, rings=4)
    # клетка-реликварий: дно, крыша, прутья
    k.barrel("CageFloor", CAGE_R + 0.06, CAGE_R + 0.04, 0.22, CAGE_Z0, c["iron_d"], "Cage", segs=10)
    k.barrel("CageRoof", CAGE_R + 0.06, 0.12, CAGE_Z1, CAGE_Z1 + 0.18, c["iron_d"], "Cage", segs=10)
    a2.ring("RoofBand", CAGE_R + 0.03, 0.025, (0, 0, CAGE_Z1), (0, 0, 1), c["iron"], "Cage", seg=12)
    a2.ring("MidBand", CAGE_R + 0.01, 0.02, (0, 0, 0.82), (0, 0, 1), c["iron"], "Cage", seg=12)
    for i in range(10):
        a = math.tau * i / 10
        x, y = CAGE_R * math.cos(a), CAGE_R * math.sin(a)
        k.limb(f"Bar{i}", (x, y, CAGE_Z0), (x, y, CAGE_Z1), 0.018, 0.018, c["iron"], "Cage", segs=4)
    # костяной венец на крыше
    a2.ring("Crown", 0.16, 0.022, (0, 0, CAGE_Z1 + 0.3), (0, 0, 1), c["bone"], "Crown", seg=14)
    for i in range(7):
        a = math.tau * i / 7
        k.limb(f"Spike{i}", (0.16 * math.cos(a), 0.16 * math.sin(a), CAGE_Z1 + 0.3),
               (0.19 * math.cos(a), 0.19 * math.sin(a), CAGE_Z1 + 0.46), 0.02, 0.004, c["bone"], "Crown", segs=4)
    k.limb("CrownPost", (0, 0, CAGE_Z1 + 0.16), (0, 0, CAGE_Z1 + 0.3), 0.03, 0.02, c["iron"], "Crown", segs=5)
    # рвущиеся цепи — свисают с крыши на плиты
    for j, (cx, cy) in enumerate(((0.32, -0.22), (-0.34, -0.12), (0.2, 0.32))):
        for i in range(4):
            a2.ring(f"Chain{j}_{i}", 0.04, 0.011, (cx * (1 + 0.08 * i), cy * (1 + 0.08 * i), 1.3 - 0.13 * i),
                    (1 if i % 2 else 0, 0, 0 if i % 2 else 1) if j != 1 else (0, 1 if i % 2 else 0, 0 if i % 2 else 1),
                    c["iron_d"], f"Chain{j}", seg=8)
    # короткие лапы-опоры
    for name, x, y in VESSEL_LEGS:
        k.limb(f"Leg.{name}", (x * 0.8, y * 0.8, 0.26), (x * 1.15, y * 1.15, 0.04), 0.06, 0.045, c["iron_d"], f"Leg.{name}",
               segs=6)
        k.box(f"Claw.{name}", (0.12, 0.12, 0.05), (x * 1.18, y * 1.18, 0.025), c["iron"], f"Leg.{name}",
              rot=(0, 0, 45))


VESSEL_BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Cage": ((0, 0, 0.2), (0, 0, 0.6), "Root"),
                "Spirit": ((0, 0, 0.5), (0, 0, 1.1), "Cage"), "Crown": ((0, 0, CAGE_Z1 + 0.16), (0, 0, CAGE_Z1 + 0.5), "Cage")}
for _side, _s in SIDES:
    VESSEL_BONES[f"SpiritArm.{_side}"] = ((0.16 * _s, -0.04, 0.82), (0.3 * _s, -0.12, 0.92), "Spirit")
for _j, (_cx, _cy) in enumerate(((0.32, -0.22), (-0.34, -0.12), (0.2, 0.32))):
    VESSEL_BONES[f"Chain{_j}"] = ((_cx, _cy, 1.34), (_cx * 1.2, _cy * 1.2, 0.9), "Cage")
for _n, _x, _y in VESSEL_LEGS:
    VESSEL_BONES[f"Leg.{_n}"] = ((_x * 0.8, _y * 0.8, 0.26), (_x * 1.15, _y * 1.15, 0.04), "Cage")


def vessel_anims():
    LOC = {"Spirit": (0, 0, 0)}

    def base(t, press=0.0):
        p = Pose({}, dict(LOC))
        p.size("Spirit", 1.0 + 0.05 * wave(t, 4), 1.0 + 0.05 * wave(t, 4, 0.25), 1.0 + 0.08 * wave(t, 4, 0.5))
        for side, s in SIDES:
            p.add(f"SpiritArm.{side}", y=10 * wave(t, 2, 0.3 if s > 0 else 0.8) + 20 * press)
        for j in range(3):
            p.add(f"Chain{j}", x=5 * wave(t, 1, 0.3 * j), z=4 * wave(t, 1, 0.3 * j + 0.2))
        p.add("Crown", y=6 * wave(t, 1))
        p.add("Cage", x=6)   # по референсу клетка наклонена вперёд — дух её толкает
        return p

    def idle(t):
        # дух бьётся о прутья: два рывка за цикл
        p = base(t)
        jolt = pulse(t, 0.3, 0.05) + pulse(t, 0.72, 0.05)
        p.move("Spirit", y=-0.05 * jolt)
        p.add("Cage", x=2 * jolt)
        return p

    def walk(t):
        p = base(t)
        for name, x, y in VESSEL_LEGS:
            ph = 0.0 if ((y < 0) == (x > 0)) else 0.5
            p.add(f"Leg.{name}", x=-14 * wave(t, 1, ph))
        p.add("Cage", z=3 * wave(t, 1), x=2 * wave(t, 2))
        p.move("Cage", z=0.02 * wave(t, 2))
        return p

    def burst(t):
        # Выплеск пламени: дух сжимается → вспыхивает во все стороны
        p = base(t)
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.7, 0.6), (1, 0)])
        p.size("Spirit", 1.0 + 0.35 * a)
        p.move("Cage", z=0.04 * max(0.0, a))
        return p

    def chains(t):
        # Цепи лопаются: клетку трясёт, цепи разлетаются
        p = base(t)
        a = track(t, [(0, 0), (0.3, 1), (0.6, 0.6), (1, 0)])
        shake = wave(t, 6) * a
        p.add("Cage", z=4 * shake)
        for j in range(3):
            p.add(f"Chain{j}", x=-50 * a, z=(30 if j % 2 else -30) * a)
        return p

    def roar(t):
        # Рёв из клетки: дух бросается к передним прутьям
        p = base(t, press=1.0)
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.75, 1), (1, 0)])
        p.move("Spirit", y=-0.1 * max(0.0, a) + 0.05 * max(0.0, -a))
        p.size("Spirit", 1.0 + 0.15 * max(0.0, a))
        p.add("Cage", x=5 * max(0.0, a))
        return p

    def hit(t):
        p = base(t)
        snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
        p.add("Cage", x=-5 * snap)
        p.size("Spirit", 1.0 - 0.2 * snap)
        p.move("Root", y=0.04 * snap)
        return p

    def death(t):
        p = Pose({}, dict(LOC))
        f = track(t, [(0, 0), (0.3, 0.2), (0.6, 1), (1, 1)])
        p.size("Spirit", max(0.02, 1.0 + 0.3 * track(t, [(0, 0), (0.3, 1), (0.6, 0)]) - track(t, [(0, 0), (0.4, 0), (0.8, 1)])))
        p.add("Cage", z=-18 * f, x=6 * f)
        p.move("Cage", z=-0.12 * f)
        for name, x, y in VESSEL_LEGS:
            p.add(f"Leg.{name}", x=(-30 if x > 0 else 20) * f)
        for j in range(3):
            p.add(f"Chain{j}", x=-40 * f)
        p.add("Crown", x=30 * track(t, [(0, 0), (0.6, 0), (0.75, 1), (0.85, 0.85), (1, 1)]))
        return p
    return [("Idle", 90, idle, True), ("Walk", 30, walk, True), ("Attack", 27, burst, False),
            ("Attack2", 27, chains, False), ("Attack3", 30, roar, False), ("Hit", 12, hit, False), ("Death", 42, death, False)]


# ---------- Обозный Исполин ----------
def giant_mesh(B):
    v = a2.volcano_mats()
    wood = k.mat("CG_Wood", (0.27, 0.22, 0.18), rough=0.9)   # обугленное, не свежее
    wood_d = k.mat("CG_WoodDark", (0.17, 0.15, 0.13), rough=0.9)
    hoop = k.mat("CG_Hoop", (0.34, 0.27, 0.22), metallic=0.4, rough=0.7)
    p = B.p
    # таз и ноги — брёвна, стянутые шлаком
    k.barrel("Pelvis", 0.17 * B.s, 0.19 * B.s, p(0, 0, 0.82)[2], p(0, 0, 1.0)[2], wood_d, "Hips", segs=8, sy=0.8)
    a2.rock("SlagHip", (0.2 * B.s, 0.14 * B.s, 0.1 * B.s), p(0.05, -0.08, 0.96), v["slag"], "Hips", seed=3)
    for side, sg in hu.SIDES:
        k.limb(f"Thigh.{side}", p(0.11 * sg, 0, 0.9), p(0.12 * sg, -0.02, 0.5), 0.085, 0.075, wood, f"Thigh.{side}", segs=6)
        a2.ring(f"KneeHoop.{side}", 0.08 * B.s, 0.016, p(0.12 * sg, -0.02, 0.52), (0, 0, 1), hoop, f"Thigh.{side}", seg=10)
        k.limb(f"Shin.{side}", p(0.12 * sg, -0.02, 0.5), p(0.12 * sg, 0, 0.1), 0.075, 0.085, wood_d, f"Shin.{side}", segs=6)
        k.box(f"Foot.{side}", (0.16 * B.s, 0.24 * B.s, 0.08), p(0.12 * sg, -0.05, 0.04), wood, f"Foot.{side}")
    # корпус — короб телеги из досок с ржавыми обручами
    k.box("Crate", (0.5 * B.s, 0.34 * B.s, 0.44 * B.s), p(0, 0.01, 1.22), wood, "Chest")
    for i in range(3):
        k.box(f"Plank{i}", (0.52 * B.s, 0.025, 0.08 * B.s), p(0, -0.105, 1.08 + 0.13 * i), wood_d, "Chest",
              rot=(0, 4 * (i - 1), 0))
    for z in (1.04, 1.4):
        k.box(f"Band{z}", (0.53 * B.s, 0.36 * B.s, 0.03 * B.s), p(0, 0.01, z), hoop, "Chest")
    k.crack("ChestRift", [(0, 0), (0.04, 0.06), (0.0, 0.12), (0.05, 0.2)], p(-0.08, -0.108, 1.12), (1, 0, 0), (0, 0, 1),
            v["rift"], "Chest", width=0.022, depth=0.02)
    a2.rock("SlagShoulder", (0.2 * B.s, 0.2 * B.s, 0.12 * B.s), p(0.2, 0.02, 1.44), v["slag"], "Chest", seed=7)
    k.limb("Spine", p(0, 0, 0.98), p(0, 0, 1.06), 0.12, 0.14, wood_d, "Spine", segs=6)
    # голова — перевёрнутая бочка с бирюзовым светом в щелях
    k.barrel("Barrel", 0.13 * B.s, 0.11 * B.s, p(0, 0, 1.46)[2], p(0, 0, 1.74)[2], wood, "Head", segs=8, loc=(0, p(0, -0.02, 0)[1]))
    for z in (1.5, 1.7):
        a2.ring(f"BarrelHoop{z}", 0.125 * B.s if z < 1.6 else 0.115 * B.s, 0.014, p(0, -0.02, z), (0, 0, 1), hoop, "Head", seg=10)
    for i, (x, z) in enumerate(((-0.06, 1.6), (0.04, 1.62), (0.0, 1.56))):
        k.box(f"Slit{i}", (0.02, 0.02, 0.1 if i < 2 else 0.04), p(x, -0.128, z), v["rift"], "Head",
              rot=(0, 90 if i == 2 else 0, 0))
    # левая рука — бревно с кулаком из шлака
    k.limb("UpperArm.L", p(0.28, 0, 1.38), p(0.32, 0, 1.1), 0.075, 0.07, wood_d, "UpperArm.L", segs=6)
    k.limb("ForeArm.L", p(0.32, 0, 1.1), p(0.34, -0.05, 0.88), 0.07, 0.065, wood, "ForeArm.L", segs=6)
    for i in range(4):   # кулак из досок, стянутый обручем
        k.box(f"FistPlank{i}", (0.05 * B.s, 0.18 * B.s, 0.16 * B.s), p(0.3 + 0.028 * i, -0.08, 0.8 - 0.01 * (i % 2)), wood,
              "Hand.L", rot=(0, 6 * (i - 1.5), 0))
    a2.ring("FistHoop", 0.085 * B.s, 0.014, p(0.34, -0.08, 0.84), (0, 0, 1), hoop, "Hand.L", seg=10)
    for i, (x, z) in enumerate(((0.06, 0.95), (-0.1, 1.0), (0.22, 1.4))):   # угольки в шлаке
        k.box(f"Ember{i}", (0.035, 0.03, 0.03), p(x, -0.16 if i < 2 else -0.06, z), v["ember"], "Hips" if i < 2 else "Chest")
    # правая рука — тележное колесо
    k.limb("UpperArm.R", p(-0.28, 0, 1.38), p(-0.32, 0, 1.1), 0.075, 0.07, wood_d, "UpperArm.R", segs=6)
    k.limb("ForeArm.R", p(-0.32, 0, 1.1), p(-0.34, -0.05, 0.88), 0.07, 0.065, wood, "ForeArm.R", segs=6)
    wc = p(-0.37, -0.08, 0.78)
    wr = 0.3 * B.s
    a2.ring("Wheel", wr, 0.035, wc, (1, 0, 0), wood_d, "Hand.R", seg=14)
    a2.ring("WheelTire", wr + 0.02, 0.016, wc, (1, 0, 0), hoop, "Hand.R", seg=14)
    for i in range(6):
        a = math.tau * i / 6
        k.limb(f"Spoke{i}", wc, (wc[0], wc[1] + wr * math.cos(a), wc[2] + wr * math.sin(a)), 0.02, 0.016, wood, "Hand.R",
               segs=4)
    k.limb("Hub", (wc[0] - 0.05, wc[1], wc[2]), (wc[0] + 0.06, wc[1], wc[2]), 0.05, 0.05, hoop, "Hand.R", segs=6)


def build_giant(name):
    B = hu.Body(2.2)
    k.start_scene(name)
    giant_mesh(B)
    body = k.join_parts(name + "Mesh")
    bones = B.bones()
    for side, sg in hu.SIDES:   # плечи шире обычных
        bones[f"UpperArm.{side}"] = (B.p(0.28 * sg, 0, 1.38), B.p(0.32 * sg, 0, 1.1), "Chest")
        bones[f"ForeArm.{side}"] = (B.p(0.32 * sg, 0, 1.1), B.p(0.34 * sg, -0.05, 0.88), f"UpperArm.{side}")
        bones[f"Hand.{side}"] = (B.p(0.34 * sg, -0.05, 0.88), B.p(0.34 * sg, -0.1, 0.76), f"ForeArm.{side}")
    rig = k.build_armature(name, bones)
    body.parent = rig
    # по референсу: сгорблен, широкая стойка, рука-колесо поднята для замаха
    anim = hu.Anim("swing", hunch=26, crouch=0.25,
                   extra_stance={"UpperArm.R": (-60, 0, 34), "UpperArm.L": (-14, 0, -18), "ForeArm.L": (-30, 0, 0),
                                 "ForeArm.R": (-40, 0, 0), "Weapon": (0, 0, 0)})

    def hail(t):
        # Град шлака: обе руки вверх → удар оземь
        p = anim.base()
        a = track(t, [(0, 0), (0.25, 1), (0.4, -0.4), (0.7, -0.4), (1, 0)])
        up = max(0.0, a)
        dn = max(0.0, -a)
        for side, sg in (("R", 1), ("L", -1)):
            p.add(f"UpperArm.{side}", x=-150 * up - 40 * dn, z=10 * sg * up)
        p.add("Chest", x=-14 * up + 24 * dn)
        p.add("Spine", x=-6 * up + 12 * dn)
        p.move("Hips", z=-0.1 * dn)
        return p

    def throw(t):
        # Швырок колеса: правая рука уходит назад и выбрасывается вперёд
        p = anim.base()
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.65, 0.8), (1, 0)])
        p.add("UpperArm.R", x=50 * min(0.0, a) * -1 * -1 - 100 * max(0.0, a), z=-10 * max(0.0, a))
        p.add("ForeArm.R", x=-30 * max(0.0, -a))
        p.add("Chest", y=-20 * min(0.0, a) * -1 * -1 + 24 * max(0.0, a))
        p.add("Spine", y=10 * max(0.0, a))
        return p
    anim.bake_all(rig, extra=[("Attack2", 27, hail), ("Attack3", 24, throw)])
    return rig, body


def build_simple(name, mesh_fn, bones, anims, loc_bones, scale_bones):
    k.start_scene(name)
    mesh_fn()
    body = k.join_parts(name + "Mesh")
    rig = k.build_armature(name, bones)
    body.parent = rig
    for act, frames, fn, cyc in anims():
        k.bake(rig, act, frames, fn, cyclic=cyc, loc_bones=loc_bones, scale_bones=scale_bones)
    return rig, body


MODELS = {
    "ash_serpent": lambda n: build_simple(n, serpent_mesh, SERPENT_BONES, serpent_anims, ("Root",), ("Coil",)),
    "rift_matriarch": lambda n: build_simple(n, matriarch_mesh, MATRIARCH_BONES, matriarch_anims, ("Root", "Body"),
                                             ("Cocoons",)),
    "crown_vessel": lambda n: build_simple(n, vessel_mesh, VESSEL_BONES, vessel_anims, ("Root", "Cage", "Spirit"),
                                           ("Spirit",)),
    "convoy_giant": build_giant,
}

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    only = os.environ.get("ONLY")
    for name, fn in MODELS.items():
        if only and name not in only.split(","):
            continue
        rig, body = fn(name)
        k.export(rig, body, os.path.join(here, "..", name + ".glb"), os.path.join(here, name + ".blend"))
