# Твари Раскола акта 2 по старым заготовкам (`враги-акт-2.md`), собранные по описаниям облика
# (референсы Gemini для них в работу не попали). Один скрипт — восемь моделей:
#   ash_hound (Пепельная гончая), rift_grinder (Бирюзовый Жернов), glass_spitter (Стеклянный Плевун),
#   ash_scarab (Зольный Скарабей), spark_stalker (Искровой Скиталец), spark (Искра — обломок духа огня),
#   ember_slug (Головёшка), ash_moth (Пеплокрылка).
# Смотрят в -Y. Анимации: Idle, Walk, Attack, Hit, Death (у Плевуна ещё Attack2 — огненный плевок).
# Запуск: python3 build_beasts_act2.py — все; ONLY=ash_hound python3 build_beasts_act2.py — одну.
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2
import act2_human as hu

SIDES = (("R", -1), ("L", 1))


def std_hit(p, t, body="Body", head=None, amp=1.0):
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.move("Root", y=0.06 * snap * amp)
    p.add(body, x=-12 * snap * amp, z=6 * snap * amp)
    if head:
        p.add(head, x=-18 * whip * amp, z=8 * whip * amp)
    return p


def roll_death(p, t, side=1.0, lift=0.12):
    roll = track(t, [(0, 0), (0.2, -8), (0.55, 88), (0.65, 82), (1, 86)])
    p.set("Root", 0, 0, roll * side)
    p.move("Root", x=track(t, [(0, 0), (0.55, 0.15 * side), (1, 0.15 * side)]), z=track(t, [(0, 0), (0.55, lift), (1, lift)]))
    return p


# ---------- Четвероногие (гончая, жернов): ноги из двух костей, смотрят вниз ----------
def quad_bones(legs, hip_z, knee_z, extra):
    b = {"Root": ((0, 0, 0), (0, 0, 0.1), None)}
    b.update(extra)
    for name, x, y in legs:
        b[f"Thigh.{name}"] = ((x, y, hip_z), (x, y - 0.03, knee_z), "Body")
        b[f"Shin.{name}"] = ((x, y - 0.03, knee_z), (x, y, 0.04), f"Thigh.{name}")
    return b


def quad_legs(legs, hip_z, knee_z, r, mat, mat2, paw):
    for name, x, y in legs:
        k.limb(f"Thigh.{name}", (x, y, hip_z), (x, y - 0.03, knee_z), r, r * 0.8, mat, f"Thigh.{name}", segs=6)
        k.limb(f"Shin.{name}", (x, y - 0.03, knee_z), (x, y, 0.04), r * 0.75, r * 0.6, mat2, f"Shin.{name}", segs=6)
        k.box(f"Paw.{name}", (r * 2.2, r * 2.6, 0.05), (x, y - 0.03, 0.025), paw, f"Shin.{name}")


def quad_gait(p, t, legs, amp=26.0, speed=1):
    for name, x, y in legs:
        front = y < 0
        ph = 0.0 if (front == (x > 0)) else 0.5
        a = wave(t, speed, ph)
        p.add(f"Thigh.{name}", x=-amp * a)
        p.add(f"Shin.{name}", x=amp * 0.9 * max(0.0, wave(t, speed, ph + 0.25)) * (1 if front else -1))


# ---- Пепельная гончая ----
HOUND_LEGS = (("FL", 0.11, -0.26), ("FR", -0.11, -0.26), ("BL", 0.11, 0.24), ("BR", -0.11, 0.24))


def hound_mesh():
    v = a2.volcano_mats()
    fur = k.mat("AH_Fur", (0.2, 0.2, 0.21), rough=0.9)
    crust = k.mat("AH_Crust", (0.46, 0.45, 0.44), rough=0.95)
    k.sphere("Chest", 0.17, (0, -0.16, 0.62), fur, "Body", scale=(0.9, 1.1, 1.0), segs=8, rings=5)
    k.limb("Belly", (0, -0.1, 0.6), (0, 0.24, 0.6), 0.13, 0.11, fur, "Body", segs=8)
    k.sphere("Hip", 0.13, (0, 0.24, 0.6), fur, "Body", segs=7, rings=4)
    for i in range(5):   # наросты из шлака на спине
        a2.rock(f"Slag{i}", (0.09, 0.1, 0.08 + 0.02 * (i % 2)), (0.02 * (i % 2 - 0.5), -0.18 + 0.1 * i, 0.74), v["slag"], "Body",
                rot=(10 * i, 0, 20 * i), seed=40 + i)
    for i, (pts, o) in enumerate([([(0, 0), (0.05, 0.03), (0.1, -0.01), (0.16, 0.03)], (-0.08, -0.05, 0.705)),
                                  ([(0, 0), (0.04, -0.03), (0.08, 0.0)], (-0.04, 0.2, 0.71))]):
        k.crack(f"Rift{i}", pts, o, (1, 0, 0), (0, 1, 0), v["rift"], "Body", width=0.016, depth=0.014)
    k.sphere("CrustBack", 0.13, (0, 0.04, 0.68), crust, "Body", scale=(1.0, 2.0, 0.4), segs=7, rings=4)
    k.limb("Neck", (0, -0.26, 0.66), (0, -0.36, 0.74), 0.09, 0.08, fur, "Head", segs=6)
    k.sphere("Head", 0.1, (0, -0.4, 0.76), fur, "Head", scale=(0.9, 1.1, 0.9), segs=7, rings=4)
    k.limb("Snout", (0, -0.46, 0.74), (0, -0.6, 0.7), 0.06, 0.04, fur, "Head", segs=6)
    k.limb("Jaw", (0, -0.46, 0.69), (0, -0.58, 0.66), 0.04, 0.03, crust, "Head", segs=5)
    for s in (-1, 1):
        k.limb(f"Ear{s}", (0.05 * s, -0.38, 0.82), (0.08 * s, -0.34, 0.92), 0.03, 0.005, fur, "Head", segs=4)
        k.box(f"Eye{s}", (0.02, 0.02, 0.015), (0.045 * s, -0.48, 0.77), v["rift"], "Head")
    k.crack("HeadRift", [(0, 0), (0.03, 0.04), (0.06, 0.02)], (-0.03, -0.44, 0.83), (1, 0, 0), (0, 1, 0), v["rift"], "Head",
            width=0.01, depth=0.01)
    k.limb("Tail", (0, 0.32, 0.62), (0, 0.5, 0.5), 0.04, 0.01, fur, "Tail", segs=5)
    quad_legs(HOUND_LEGS, 0.58, 0.32, 0.06, fur, fur, crust)


HOUND_BONES = quad_bones(HOUND_LEGS, 0.58, 0.32, {
    "Body": ((0, 0, 0.5), (0, 0, 0.76), "Root"),
    "Head": ((0, -0.3, 0.68), (0, -0.4, 0.86), "Body"),
    "Tail": ((0, 0.32, 0.62), (0, 0.5, 0.5), "Body"),
})


def hound_anims():
    S = {"Head": (6, 0, 0)}

    def idle(t):
        p = Pose(S)
        p.move("Body", z=0.006 * wave(t, 3))
        p.add("Head", z=k.track(t, [(0, 0), (0.3, 0), (0.35, -20), (0.6, -20), (0.65, 14), (0.9, 14), (1, 0)]),
              x=6 * pulse(t, 0.7, 0.06))
        p.add("Tail", z=10 * wave(t, 2))
        return p

    def walk(t):
        p = Pose(S)
        quad_gait(p, t, HOUND_LEGS, amp=34, speed=1)
        p.move("Body", z=0.03 * wave(t, 2))
        p.add("Head", x=-6 * wave(t, 2))
        p.add("Tail", z=12 * wave(t, 1))
        return p

    def attack(t):
        p = Pose(S)
        lunge = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.6, 0.6), (1, 0)])
        p.add("Body", x=10 * lunge)
        p.add("Head", x=-20 * max(0.0, lunge))
        p.move("Root", y=-0.14 * max(0.0, lunge) + 0.04 * max(0.0, -lunge))
        p.move("Body", z=-0.06 * max(0.0, -lunge))
        for name, x, y in HOUND_LEGS:
            p.add(f"Thigh.{name}", x=(-30 if y < 0 else 20) * max(0.0, lunge))
        return p

    def hit(t):
        return std_hit(Pose(S), t, head="Head")

    def death(t):
        return roll_death(Pose(S), t, lift=0.18)
    return [("Idle", 90, idle, True), ("Walk", 18, walk, True), ("Attack", 24, attack, False), ("Hit", 12, hit, False),
            ("Death", 33, death, False)]


# ---- Бирюзовый Жернов ----
GRIND_LEGS = (("FL", 0.2, -0.24), ("FR", -0.2, -0.24), ("BL", 0.2, 0.24), ("BR", -0.2, 0.24))


def grinder_mesh():
    v = a2.volcano_mats()
    stone = k.mat("RG_Stone", (0.42, 0.41, 0.4), rough=0.85)
    belly = k.mat("RG_Belly", (0.32, 0.3, 0.29), rough=0.9)
    glow = k.mat("RG_Glow", (0.30, 0.95, 0.85), rough=0.4, emit=1.4)
    k.sphere("Inner", 0.3, (0, 0.02, 0.5), glow, "Body", scale=(1.0, 1.4, 0.8), segs=7, rings=4)
    k.sphere("Belly", 0.28, (0, 0.02, 0.42), belly, "Body", scale=(1.0, 1.45, 0.7), segs=8, rings=4)
    for i in range(5):   # нахлёстывающиеся плиты спины
        y = -0.34 + 0.17 * i
        k.box(f"Plate{i}", (0.62, 0.2, 0.08), (0, y, 0.72 - 0.03 * abs(i - 2)), stone, "Body", rot=(-14 + 7 * i, 0, 0))
        for s in (-1, 1):
            k.box(f"PlateSide{i}{s}", (0.08, 0.2, 0.26), (0.32 * s, y, 0.56), stone, "Body", rot=(0, 26 * s, 0))
    k.box("Ram", (0.3, 0.14, 0.24), (0, -0.48, 0.48), stone, "Head", rot=(10, 0, 0))
    k.box("RamFace", (0.32, 0.04, 0.26), (0, -0.56, 0.47), belly, "Head")
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.03, 0.02, 0.02), (0.09 * s, -0.58, 0.52), glow, "Head")
    k.limb("Tail", (0, 0.44, 0.48), (0, 0.6, 0.36), 0.06, 0.02, stone, "Body", segs=5)
    quad_legs(GRIND_LEGS, 0.4, 0.22, 0.07, belly, stone, stone)


GRIND_BONES = quad_bones(GRIND_LEGS, 0.4, 0.22, {
    "Body": ((0, 0, 0.36), (0, 0, 0.76), "Root"),
    "Head": ((0, -0.4, 0.4), (0, -0.4, 0.6), "Body"),
})


def grinder_anims():
    S = {"Head": (6, 0, 0)}

    def idle(t):
        p = Pose(S)
        p.move("Body", z=0.006 * wave(t, 2))
        p.add("Head", z=6 * wave(t, 1), x=4 * pulse(t, 0.5, 0.08))
        return p

    def walk(t):
        p = Pose(S)
        quad_gait(p, t, GRIND_LEGS, amp=22, speed=1)
        p.move("Body", z=0.015 * wave(t, 2))
        p.add("Body", z=3 * wave(t, 1))
        return p

    def attack(t):
        # таран: присел → рывок вперёд мордой (к 0.4 сек)
        p = Pose(S)
        lunge = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.6, 0.7), (1, 0)])
        p.add("Body", x=6 * lunge)
        p.add("Head", x=14 * max(0.0, lunge))
        p.move("Root", y=-0.2 * max(0.0, lunge) + 0.05 * max(0.0, -lunge))
        return p

    def hit(t):
        return std_hit(Pose(S), t, head="Head", amp=0.6)

    def death(t):
        p = Pose(S)
        fall = track(t, [(0, 0), (0.4, 1), (1, 1)])
        p.move("Body", z=-0.18 * fall)
        for name, x, y in GRIND_LEGS:
            p.add(f"Thigh.{name}", z=(-50 if x > 0 else 50) * fall)
        p.add("Head", x=24 * fall)
        return p
    return [("Idle", 90, idle, True), ("Walk", 27, walk, True), ("Attack", 27, attack, False), ("Hit", 12, hit, False),
            ("Death", 33, death, False)]


# ---- Стеклянный Плевун ----
SPIT_LEGS = (("FL", 0.12, -0.12), ("FR", -0.12, -0.12), ("BL", 0.12, 0.14), ("BR", -0.12, 0.14))


def spitter_mesh():
    v = a2.volcano_mats()
    glass = k.mat("GS_Glass", (0.2, 0.22, 0.24), metallic=0.3, rough=0.15)
    glass_l = k.mat("GS_GlassLight", (0.32, 0.36, 0.38), metallic=0.3, rough=0.15)
    crop = k.mat("GS_Crop", (0.35, 0.9, 0.82), rough=0.2, emit=1.0, alpha=0.85)
    k.sphere("Body", 0.2, (0, 0.02, 0.92), glass, "Body", scale=(0.9, 1.4, 0.8), segs=8, rings=5)
    k.limb("Tail", (0, 0.26, 0.92), (0, 0.42, 0.98), 0.07, 0.01, glass, "Body", segs=5)
    k.limb("Neck1", (0, -0.2, 0.98), (0, -0.28, 1.28), 0.06, 0.05, glass_l, "Neck", segs=6)
    k.limb("Neck2", (0, -0.28, 1.28), (0, -0.3, 1.56), 0.05, 0.045, glass_l, "Neck2", segs=6)
    k.crack("NeckRift", [(0, 0), (0.01, 0.1), (-0.01, 0.2), (0.01, 0.3)], (0, -0.33, 1.24), (1, 0, 0), (0, 0, 1), v["rift"],
            "Neck2", width=0.014, depth=0.014)
    k.sphere("Head", 0.07, (0, -0.32, 1.62), glass, "Head", scale=(0.9, 1.3, 0.9), segs=6, rings=4)
    k.limb("Beak", (0, -0.38, 1.62), (0, -0.56, 1.58), 0.03, 0.005, glass_l, "Head", segs=5)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.015, 0.02, 0.015), (0.045 * s, -0.36, 1.65), v["rift"], "Head")
    k.sphere("Crop", 0.08, (0, -0.4, 1.52), crop, "Head", scale=(1.0, 1.1, 1.2), segs=7, rings=4)   # зоб
    for name, x, y in SPIT_LEGS:
        k.limb(f"Thigh.{name}", (x, y, 0.84), (x * 1.3, y - 0.06, 0.5), 0.03, 0.025, glass, f"Thigh.{name}", segs=5)
        k.limb(f"Shin.{name}", (x * 1.3, y - 0.06, 0.5), (x * 1.35, y, 0.03), 0.022, 0.015, glass_l, f"Shin.{name}", segs=5)
        k.box(f"Foot.{name}", (0.05, 0.1, 0.02), (x * 1.35, y - 0.03, 0.01), glass, f"Shin.{name}")


SPIT_BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Body": ((0, 0, 0.84), (0, 0, 1.04), "Root"),
              "Neck": ((0, -0.2, 0.98), (0, -0.28, 1.28), "Body"), "Neck2": ((0, -0.28, 1.28), (0, -0.3, 1.56), "Neck"),
              "Head": ((0, -0.3, 1.56), (0, -0.46, 1.62), "Neck2")}
for _n, _x, _y in SPIT_LEGS:
    SPIT_BONES[f"Thigh.{_n}"] = ((_x, _y, 0.84), (_x * 1.3, _y - 0.06, 0.5), "Body")
    SPIT_BONES[f"Shin.{_n}"] = ((_x * 1.3, _y - 0.06, 0.5), (_x * 1.35, _y, 0.03), f"Thigh.{_n}")


def spitter_anims():
    S = {"Neck": (-10, 0, 0)}

    def idle(t):
        p = Pose(S)
        p.add("Neck", x=4 * wave(t, 1), y=8 * wave(t, 1, 0.3))
        p.add("Head", z=k.track(t, [(0, 0), (0.25, 0), (0.3, -24), (0.55, -24), (0.6, 18), (0.85, 18), (0.9, 0), (1, 0)]))
        p.size("Head", 1.0 + 0.04 * wave(t, 3))
        return p

    def walk(t):
        p = Pose(S)
        for name, x, y in SPIT_LEGS:
            ph = 0.0 if ((y < 0) == (x > 0)) else 0.5
            p.add(f"Thigh.{name}", x=-24 * wave(t, 1, ph))
        p.move("Body", z=0.02 * wave(t, 2))
        p.add("Neck", x=8 * wave(t, 2))
        return p

    def spit(t):
        p = Pose(S)
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.6, 0.5), (1, 0)])
        p.add("Neck", x=-20 * min(0.0, a) * -1 + 30 * max(0.0, a))
        p.add("Neck2", x=20 * max(0.0, a) - 16 * max(0.0, -a))
        p.size("Head", 1.0 + 0.2 * pulse(t, 0.3, 0.1))
        return p

    def hit(t):
        return std_hit(Pose(S), t, head="Neck")

    def death(t):
        return roll_death(Pose(S), t, lift=0.2)
    return [("Idle", 90, idle, True), ("Walk", 24, walk, True), ("Attack", 24, spit, False), ("Attack2", 24, spit, False),
            ("Hit", 12, hit, False), ("Death", 36, death, False)]


# ---------- Шестиногие (скарабей): ноги-шарниры как у краба ----------
def hex_legs_mesh(legs, z, r, mat, mat2, reach=0.18):
    for side, s in SIDES:
        for i, x, y in legs:
            hip = (x * s, y, z)
            kn = ((x + reach * 0.6) * s, y + 0.02, z + 0.06)
            ft = ((x + reach) * s, y + 0.04, 0.02)
            k.limb(f"LegU{i}.{side}", hip, kn, r, r * 0.8, mat, f"Coxa{i}.{side}", segs=5)
            k.limb(f"LegL{i}.{side}", kn, ft, r * 0.8, r * 0.3, mat2, f"Knee{i}.{side}", segs=5)


def hex_legs_bones(b, legs, z, reach=0.18):
    for side, s in SIDES:
        for i, x, y in legs:
            b[f"Coxa{i}.{side}"] = ((x * s, y, z), (x * s, y, z + 0.1), "Body")
            kx = (x + reach * 0.6) * s
            b[f"Knee{i}.{side}"] = ((kx, y + 0.02, z + 0.06), (kx, y + 0.02, z + 0.16), f"Coxa{i}.{side}")


def hex_gait(p, t, legs, amp=16.0, lift=10.0):
    for side in ("R", "L"):
        s = 1 if side == "L" else -1
        for i, _, _ in legs:
            ph = i * 0.33 + (0.5 if side == "L" else 0.0)
            p.add(f"Coxa{i}.{side}", y=-amp * wave(t, 1, ph) * s, z=lift * max(0.0, wave(t, 1, ph + 0.25)) * s)


SCARAB_LEGS = ((0, 0.14, -0.12), (1, 0.16, 0.02), (2, 0.14, 0.16))


def scarab_mesh():
    v = a2.volcano_mats()
    shell = k.mat("SC_Shell", (0.22, 0.24, 0.24), metallic=0.2, rough=0.3)
    gas = k.mat("SC_Gas", (0.42, 0.75, 0.62), rough=0.3, emit=0.6, alpha=0.75)
    k.sphere("Belly", 0.22, (0, 0.02, 0.26), shell, "Body", scale=(1.0, 1.25, 0.5), segs=8, rings=4)
    for s in (-1, 1):   # раздвинутые надкрылья
        k.sphere(f"Elytra{s}", 0.2, (0.12 * s, 0.06, 0.34), shell, "Body", scale=(0.6, 1.2, 0.35), segs=7, rings=4)
        k.crack(f"ShellNet{s}", [(0, 0), (0.04, 0.06), (0.0, 0.12), (0.05, 0.18)], (0.12 * s, -0.08, 0.41), (1, 0, 0),
                (0, 1, 0), v["rift"], "Body", width=0.012, depth=0.01)
    k.sphere("GasBubble", 0.12, (0, 0.1, 0.42), gas, "Gas", segs=7, rings=4)
    k.sphere("Head", 0.08, (0, -0.24, 0.26), shell, "Body", scale=(1.3, 1.0, 0.7), segs=6, rings=4)
    for s in (-1, 1):
        k.limb(f"Mandible{s}", (0.05 * s, -0.3, 0.24), (0.02 * s, -0.38, 0.22), 0.02, 0.005, shell, "Body", segs=4)
        k.box(f"Eye{s}", (0.02, 0.02, 0.015), (0.06 * s, -0.31, 0.28), v["rift"], "Body")
    hex_legs_mesh(SCARAB_LEGS, 0.24, 0.025, shell, shell)


SCARAB_BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Body": ((0, 0, 0.18), (0, 0, 0.4), "Root"),
                "Gas": ((0, 0.1, 0.32), (0, 0.1, 0.54), "Body")}
hex_legs_bones(SCARAB_BONES, SCARAB_LEGS, 0.24)


def scarab_anims():
    def idle(t):
        p = Pose({})
        p.size("Gas", 1.0 + 0.08 * wave(t, 2))
        p.move("Body", z=0.004 * wave(t, 3))
        return p

    def walk(t):
        p = Pose({})
        hex_gait(p, t, SCARAB_LEGS)
        p.size("Gas", 1.0 + 0.05 * wave(t, 2))
        return p

    def attack(t):
        p = Pose({})
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.6, 0.5), (1, 0)])
        p.add("Body", x=10 * a)
        p.size("Gas", 1.0 + 0.5 * max(0.0, a))
        p.move("Root", y=-0.06 * max(0.0, a))
        return p

    def hit(t):
        return std_hit(Pose({}), t)

    def death(t):
        p = Pose({})
        flip = track(t, [(0, 0), (0.5, 1), (1, 1)])
        p.set("Root", 0, 0, 170 * flip)
        p.move("Root", z=track(t, [(0, 0), (0.3, 0.2), (0.5, 0.3), (1, 0.3)]))
        p.size("Gas", track(t, [(0, 1), (0.3, 1.4), (0.4, 0.05), (1, 0.05)]))
        return p
    return [("Idle", 90, idle, True), ("Walk", 18, walk, True), ("Attack", 24, attack, False), ("Hit", 12, hit, False),
            ("Death", 30, death, False)]


# ---------- Искровой Скиталец: человеческое тело из поленьев и камня, длинные руки ----------
def stalker_mesh():
    v = a2.volcano_mats()
    log = k.mat("SS_Log", (0.22, 0.19, 0.17), rough=0.9)
    stone = k.mat("SS_Stone", (0.34, 0.33, 0.33), rough=0.85)
    B = hu.Body(1.9)
    p = B.p
    k.limb("Pelvis", p(0, 0, 0.86), p(0, 0, 1.0), 0.12, 0.13, stone, "Hips", segs=6)
    k.limb("Torso", p(0, 0, 1.0), p(0, 0.02, 1.4), 0.13, 0.17, log, "Spine", segs=6)
    k.limb("Chest", p(0, 0.02, 1.3), p(0, 0.02, 1.46), 0.19, 0.16, log, "Chest", segs=6)
    k.crack("ChestVein", [(0, 0), (0.03, 0.08), (-0.02, 0.16), (0.02, 0.24)], p(0, -0.155, 1.18), (1, 0, 0), (0, 0, 1),
            v["rift"], "Chest", width=0.018, depth=0.02)
    k.sphere("Head", 0.11 * B.s, p(0, -0.04, 1.58), stone, "Head", scale=(0.9, 1.1, 0.9), segs=6, rings=4)
    for s in (-1, 1):
        k.limb(f"Horn{s}", p(0.06 * s, -0.02, 1.66), p(0.14 * s, 0.04, 1.78), 0.03, 0.005, log, "Head", segs=4)
        k.box(f"Eye{s}", (0.03, 0.02, 0.02), p(0.04 * s, -0.12, 1.59), v["rift"], "Head")
    for side, sg in hu.SIDES:
        # руки очень длинные — до колен
        k.limb(f"UpperArm.{side}", p(0.2 * sg, 0, 1.38), p(0.26 * sg, 0, 1.0), 0.05, 0.045, log, f"UpperArm.{side}", segs=6)
        k.limb(f"ForeArm.{side}", p(0.26 * sg, 0, 1.0), p(0.28 * sg, -0.05, 0.62), 0.045, 0.04, stone, f"ForeArm.{side}", segs=6)
        for j in (-1, 0, 1):
            k.plate(f"Claw.{side}{j}", [(0, 0), (0.025, 0), (0.05, -0.12), (0.02, -0.2), (0.0, -0.1)], 0.015,
                    p(0.28 * sg + 0.03 * j, -0.06, 0.6), (0, -1, 0), (0, 0, 1), v["lava"], f"Hand.{side}")
        k.limb(f"Thigh.{side}", p(0.1 * sg, 0, 0.9), p(0.11 * sg, -0.02, 0.5), 0.065, 0.055, log, f"Thigh.{side}", segs=6)
        k.limb(f"Shin.{side}", p(0.11 * sg, -0.02, 0.5), p(0.11 * sg, 0, 0.08), 0.055, 0.05, stone, f"Shin.{side}", segs=6)
        k.box(f"Foot.{side}", (0.12, 0.2, 0.06), p(0.11 * sg, -0.05, 0.03), log, f"Foot.{side}")
    return B


def stalker_bones():
    B = hu.Body(1.9)
    b = B.bones()
    for side, sg in hu.SIDES:   # руки длиннее обычных
        b[f"UpperArm.{side}"] = (B.p(0.2 * sg, 0, 1.38), B.p(0.26 * sg, 0, 1.0), "Chest")
        b[f"ForeArm.{side}"] = (B.p(0.26 * sg, 0, 1.0), B.p(0.28 * sg, -0.05, 0.62), f"UpperArm.{side}")
        b[f"Hand.{side}"] = (B.p(0.28 * sg, -0.05, 0.62), B.p(0.28 * sg, -0.1, 0.44), f"ForeArm.{side}")
    return b


# ---------- Искра ----------
def spark_mesh():
    v = a2.volcano_mats()
    flame = k.mat("SP_Flame", (0.95, 0.3, 0.04), rough=0.4, emit=0.9)
    core = k.mat("SP_Core", (1.0, 0.62, 0.2), rough=0.4, emit=1.1)
    iron = k.mat("SP_Iron", (0.24, 0.24, 0.25), metallic=0.5, rough=0.6)
    k.sphere("Flame", 0.16, (0, 0, 0.5), flame, "Flame", scale=(1.0, 1.0, 1.2), segs=7, rings=5)
    k.limb("Tip", (0, 0.02, 0.62), (0, 0.08, 0.82), 0.1, 0.005, flame, "Flame", segs=6)
    k.sphere("Core", 0.08, (0, -0.06, 0.48), core, "Flame", segs=6, rings=4)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.03, 0.02, 0.025), (0.05 * s, -0.155, 0.54), v["rift"], "Flame")
    k.crack("Rift", [(0, 0), (0.03, 0.05), (0.0, 0.1)], (0.06, -0.15, 0.42), (1, 0, 0), (0, 0, 1), v["rift"], "Flame",
            width=0.012, depth=0.012)
    a2.ring("Shackle", 0.06, 0.016, (0, 0, 0.36), (0, 0, 1), iron, "Flame", seg=10)
    for i in range(3):
        a2.ring(f"Link{i}", 0.03, 0.008, (0, 0.04 * i, 0.3 - 0.08 * i), (1 if i % 2 else 0, 0, 0 if i % 2 else 1), iron, "Chain",
                seg=8)


SPARK_BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Flame": ((0, 0, 0.36), (0, 0, 0.8), "Root"),
               "Chain": ((0, 0, 0.36), (0, 0.1, 0.1), "Flame")}


def spark_anims():
    def idle(t):
        p = Pose({}, {"Flame": (0, 0, 0.1)})
        p.move("Flame", z=0.1 + 0.03 * wave(t, 2))
        p.size("Flame", 1.0 + 0.06 * wave(t, 4), 1.0 + 0.06 * wave(t, 4, 0.25), 1.0 + 0.1 * wave(t, 4, 0.5))
        p.add("Chain", x=10 * wave(t, 2, 0.2))
        return p

    def walk(t):
        p = idle(t)
        p.add("Flame", x=16)
        p.add("Chain", x=30)
        return p

    def attack(t):
        p = idle(t)
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.6, 0.4), (1, 0)])
        p.move("Root", y=-0.2 * max(0.0, a))
        p.size("Flame", 1.0 + 0.3 * max(0.0, a))
        return p

    def hit(t):
        p = idle(t)
        snap = track(t, [(0, 0), (0.15, 1), (1, 0)])
        p.size("Flame", 1.0 - 0.3 * snap)
        p.move("Root", y=0.08 * snap)
        return p

    def death(t):
        p = Pose({}, {})
        p.move("Flame", z=0.1 - 0.1 * track(t, [(0, 0), (1, 1)]))
        p.size("Flame", max(0.02, 1.0 - track(t, [(0, 0), (0.2, -0.3), (1, 1)])))
        return p
    return [("Idle", 60, idle, True), ("Walk", 18, walk, True), ("Attack", 24, attack, False), ("Hit", 12, hit, False),
            ("Death", 24, death, False)]


# ---------- Головёшка ----------
SLUG_SEG = (("Seg1", -0.18, 0.2, 0.22), ("Seg2", 0.06, 0.18, 0.2), ("Seg3", 0.28, 0.14, 0.15))


def slug_mesh():
    v = a2.volcano_mats()
    crust = k.mat("ES_Crust", (0.44, 0.43, 0.42), rough=0.95)
    for i, (name, y, r, h) in enumerate(SLUG_SEG):
        k.sphere(f"Under{i}", r, (0, y, h * 0.55), v["lava"], name, scale=(1.0, 1.3, 0.7), segs=7, rings=4)
        a2.rock(f"Crust{i}", (r * 1.9, r * 2.2, h * 0.9), (0, y + 0.01, h * 0.75), crust, name, seed=60 + i)
        k.crack(f"Rift{i}", [(0, 0), (0.04, 0.05), (0.08, 0.0)], (-0.04, y - 0.04, h * 1.1), (1, 0, 0), (0, 1, 0), v["rift"],
                name, width=0.014, depth=0.014)
    k.sphere("Head", 0.15, (0, -0.36, 0.17), crust, "Head", scale=(1.0, 1.1, 0.8), segs=7, rings=4)
    for s in (-1, 1):
        k.limb(f"Horn{s}", (0.06 * s, -0.4, 0.26), (0.08 * s, -0.44, 0.38), 0.025, 0.012, crust, "Head", segs=4)
        k.box(f"HornTip{s}", (0.03, 0.03, 0.03), (0.08 * s, -0.44, 0.39), v["ember"], "Head")
    for i in range(4):   # след из угольков
        k.box(f"Trail{i}", (0.04, 0.04, 0.02), (0.05 * (i % 2 - 0.5), 0.4 + 0.08 * i, 0.01), v["ember"], "Seg3",
              rot=(0, 0, 30 * i))


SLUG_BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Body": ((0, 0, 0.02), (0, 0, 0.2), "Root")}
_par = "Body"
for _n, _y, _r, _h in SLUG_SEG:
    SLUG_BONES[_n] = ((0, _y, 0.02), (0, _y, 0.3), _par if _n == "Seg1" else "Body")
SLUG_BONES["Head"] = ((0, -0.3, 0.1), (0, -0.3, 0.36), "Seg1")


def slug_anims():
    def idle(t):
        p = Pose({})
        for i, (n, *_) in enumerate(SLUG_SEG):
            p.size(n, 1.0 + 0.03 * wave(t, 2, i * 0.2))
        p.add("Head", z=10 * wave(t, 1), x=-4 * pulse(t, 0.5, 0.1))
        return p

    def walk(t):
        p = Pose({})
        for i, (n, *_) in enumerate(SLUG_SEG):
            p.size(n, 1.0 + 0.08 * wave(t, 1, i * 0.25), 1.0 - 0.06 * wave(t, 1, i * 0.25), 1.0)
        p.add("Head", x=6 * wave(t, 1))
        return p

    def attack(t):
        p = Pose({})
        a = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.6, 0.5), (1, 0)])
        p.add("Head", x=-24 * min(0.0, a) * -1 + 20 * max(0.0, a))
        p.add("Seg1", x=10 * max(0.0, a))
        p.move("Root", y=-0.08 * max(0.0, a))
        return p

    def hit(t):
        p = Pose({})
        snap = track(t, [(0, 0), (0.15, 1), (1, 0)])
        p.add("Head", x=-20 * snap)
        p.size("Seg1", 1.0 - 0.1 * snap)
        p.move("Root", y=0.05 * snap)
        return p

    def death(t):
        p = Pose({})
        f = track(t, [(0, 0), (1, 1)])
        for i, (n, *_) in enumerate(SLUG_SEG):
            p.size(n, 1.0 + 0.2 * f, 1.0 + 0.1 * f, max(0.3, 1.0 - 0.7 * f))
        p.add("Head", x=30 * f)
        return p
    return [("Idle", 90, idle, True), ("Walk", 30, walk, True), ("Attack", 24, attack, False), ("Hit", 12, hit, False),
            ("Death", 33, death, False)]


# ---------- Пеплокрылка ----------
def moth_mesh():
    v = a2.volcano_mats()
    fur = k.mat("AM_Fur", (0.42, 0.4, 0.38), rough=0.95)
    wing = k.mat("AM_Wing", (0.5, 0.49, 0.47), rough=0.95)
    wing_d = k.mat("AM_WingDark", (0.3, 0.29, 0.28), rough=0.95)
    flake = k.mat("AM_Flake", (0.78, 0.76, 0.72), rough=0.9)
    k.sphere("Thorax", 0.08, (0, -0.04, 0.62), fur, "Body", segs=6, rings=4)
    k.sphere("Abdomen", 0.07, (0, 0.12, 0.6), fur, "Body", scale=(0.9, 1.7, 0.9), segs=6, rings=4)
    k.sphere("Head", 0.05, (0, -0.14, 0.64), fur, "Body", segs=6, rings=4)
    stripe = k.mat("AM_Stripe", (0.33, 0.25, 0.19), rough=0.95)   # бурые полосы на брюшке (по референсу, без рыжего)
    for i, y in enumerate((0.1, 0.18)):
        a2.ring(f"Stripe{i}", 0.058, 0.014, (0, y, 0.6), (0, 1, 0), stripe, "Body", seg=8)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.02, 0.02, 0.02), (0.035 * s, -0.18, 0.65), v["rift"], "Body")
        k.limb(f"Antenna{s}", (0.02 * s, -0.17, 0.68), (0.1 * s, -0.28, 0.76), 0.008, 0.003, fur, "Body", segs=3)
    for side, s in SIDES:
        k.plate(f"WingF.{side}", [(0, 0.04), (0.2, 0.08), (0.5, 0.0), (0.46, -0.16), (0.2, -0.14), (0, -0.04)], 0.012,
                (0.06 * s, -0.04, 0.64), (s, 0, 0), (0, -1, 0), wing, f"WingF.{side}")
        k.sphere(f"Spot.{side}", 0.05, (0.36 * s, 0.02, 0.646), v["rift"], f"WingF.{side}", scale=(1, 1, 0.2), segs=6, rings=3)
        k.plate(f"WingB.{side}", [(0, 0.0), (0.3, -0.04), (0.34, -0.18), (0.14, -0.24), (0, -0.1)], 0.012,
                (0.05 * s, 0.06, 0.62), (s, 0, 0), (0, -1, 0), wing_d, f"WingB.{side}")
    for i in range(6):
        a = math.tau * i / 6
        k.box(f"Ash{i}", (0.025, 0.025, 0.008), (0.25 * math.cos(a), 0.25 * math.sin(a), 0.2 + 0.06 * (i % 3)), flake,
              "Ash", rot=(20 * i, 40 * i, 0))


MOTH_BONES = {"Root": ((0, 0, 0), (0, 0, 0.1), None), "Body": ((0, 0, 0.56), (0, 0, 0.7), "Root"),
              "Ash": ((0, 0, 0.1), (0, 0, 0.4), "Body")}
for _side, _s in SIDES:
    MOTH_BONES[f"WingF.{_side}"] = ((0.06 * _s, -0.04, 0.64), (0.5 * _s, -0.04, 0.64), "Body")
    MOTH_BONES[f"WingB.{_side}"] = ((0.05 * _s, 0.06, 0.62), (0.35 * _s, 0.06, 0.62), "Body")


def moth_anims():
    def flap(p, t, speed=4, amp=40.0):
        for side, s in SIDES:
            a = wave(t, speed)
            p.add(f"WingF.{side}", x=amp * a)
            p.add(f"WingB.{side}", x=amp * 0.8 * wave(t, speed, -0.05))

    def idle(t):
        p = Pose({})
        flap(p, t, speed=4, amp=30)
        p.move("Body", z=0.03 * wave(t, 2))
        p.add("Ash", y=360 * t)
        return p

    def walk(t):
        p = Pose({})
        flap(p, t, speed=4, amp=45)
        p.add("Body", x=14)
        p.add("Ash", y=360 * t)
        return p

    def attack(t):
        p = Pose({})
        flap(p, t, speed=3, amp=60)
        p.move("Body", z=-0.2 * pulse(t, 0.4, 0.2))
        p.size("Ash", 1.0 + 1.2 * pulse(t, 0.45, 0.25))
        return p

    def hit(t):
        p = Pose({})
        flap(p, t, speed=4, amp=20)
        snap = track(t, [(0, 0), (0.15, 1), (1, 0)])
        p.move("Root", y=0.08 * snap)
        p.add("Body", x=-20 * snap)
        return p

    def death(t):
        p = Pose({})
        f = track(t, [(0, 0), (1, 1)])
        flap(p, t, speed=2, amp=40 * (1 - f))
        p.move("Body", z=-0.55 * track(t, [(0, 0), (0.6, 1), (1, 1)]))
        p.add("Body", z=70 * f)
        p.size("Ash", max(0.02, 1 - f))
        return p
    return [("Idle", 48, idle, True), ("Walk", 24, walk, True), ("Attack", 24, attack, False), ("Hit", 12, hit, False),
            ("Death", 30, death, False)]


# ---------- Сборка ----------
def build_simple(name, mesh_fn, bones, anims, loc_bones, scale_bones):
    k.start_scene(name)
    mesh_fn()
    body = k.join_parts(name + "Mesh")
    rig = k.build_armature(name, bones)
    body.parent = rig
    for act, frames, fn, cyc in anims():
        k.bake(rig, act, frames, fn, cyclic=cyc, loc_bones=loc_bones, scale_bones=scale_bones)
    return rig, body


def build_stalker(name):
    k.start_scene(name)
    stalker_mesh()
    body = k.join_parts(name + "Mesh")
    rig = k.build_armature(name, stalker_bones())
    body.parent = rig
    anim = hu.Anim("swing", hunch=24, crouch=0.15,
                   extra_stance={"UpperArm.R": (-20, 0, 16), "UpperArm.L": (-20, 0, -16), "ForeArm.R": (-20, 0, 0),
                                 "ForeArm.L": (-20, 0, 0), "Weapon": (0, 0, 0), "Prop": (0, 0, 0)})
    anim.bake_all(rig)
    return rig, body


MODELS = {
    "ash_hound": lambda n: build_simple(n, hound_mesh, HOUND_BONES, hound_anims, ("Root", "Body"), ()),
    "rift_grinder": lambda n: build_simple(n, grinder_mesh, GRIND_BONES, grinder_anims, ("Root", "Body"), ()),
    "glass_spitter": lambda n: build_simple(n, spitter_mesh, SPIT_BONES, spitter_anims, ("Root", "Body"), ("Head",)),
    "ash_scarab": lambda n: build_simple(n, scarab_mesh, SCARAB_BONES, scarab_anims, ("Root", "Body"), ("Gas",)),
    "spark_stalker": build_stalker,
    "spark": lambda n: build_simple(n, spark_mesh, SPARK_BONES, spark_anims, ("Root", "Flame"), ("Flame",)),
    "ember_slug": lambda n: build_simple(n, slug_mesh, SLUG_BONES, slug_anims, ("Root",), ("Seg1", "Seg2", "Seg3")),
    "ash_moth": lambda n: build_simple(n, moth_mesh, MOTH_BONES, moth_anims, ("Root", "Body"), ("Ash",)),
}

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    only = os.environ.get("ONLY")
    for name, fn in MODELS.items():
        if only and name not in only.split(","):
            continue
        rig, body = fn(name)
        k.export(rig, body, os.path.join(here, "..", name + ".glb"), os.path.join(here, name + ".blend"))
