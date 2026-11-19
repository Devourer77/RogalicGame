# Котловая медуза — тварь Кипящих ключей (акт 2, Тракт), ~0.9 м. Купол из мутного бледно-серо-голубого
# студня с грязно-охристыми крапинами серы, сверху валит пар; под куполом короткие толстые щупальца
# в лужице горячей воды; внутри — бирюзовый узор трещин и тёплое ядро. Живёт в лужах, вне воды слабеет.
# Смотрит в -Y. Анимации: Idle (купол пульсирует), Walk (переползает), Attack (брызги кипятка), Hit, Death.
# Запуск: python3 build_kettle_jelly.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

TENT = 6


def build_mesh():
    v = a2.volcano_mats()
    jelly = k.mat("KJ_Jelly", (0.6, 0.74, 0.8), rough=0.15, emit=0.12, alpha=0.82)
    jelly_d = k.mat("KJ_JellyDark", (0.46, 0.6, 0.68), rough=0.2, emit=0.1)
    warm = k.mat("KJ_Core", (1.0, 0.55, 0.3), rough=0.4, emit=0.7)
    water = k.mat("KJ_Water", (0.24, 0.36, 0.44), rough=0.1, emit=0.05)
    # Лужица (остаётся на месте)
    k.barrel("Puddle", 0.42, 0.44, 0.0, 0.025, water, "Root", segs=10)
    for i in range(5):
        a = math.tau * i / 5 + 0.3
        k.sphere(f"Bubble{i}", 0.025, (0.3 * math.cos(a), 0.3 * math.sin(a), 0.03), jelly, "Root", segs=5, rings=3)
    # Купол
    k.sphere("Cap", 0.34, (0, 0, 0.36), jelly, "Cap", scale=(1.0, 1.0, 0.82), segs=10, rings=6)
    k.barrel("CapRim", 0.33, 0.3, 0.18, 0.24, jelly_d, "Cap", segs=10)
    k.sphere("Heart", 0.12, (0, 0, 0.32), warm, "Cap", scale=(1.2, 1.0, 0.8), segs=7, rings=4)
    for i, (pts, o, u) in enumerate([
        ([(0, 0), (0.06, 0.06), (0.1, 0.02), (0.16, 0.08)], (-0.1, -0.26, 0.36), (1, 0, 0)),
        ([(0, 0), (0.05, -0.05), (0.12, -0.02)], (0.02, -0.25, 0.46), (1, 0, 0)),
        ([(0, 0), (0.06, 0.05), (0.12, 0.0)], (0.26, -0.04, 0.38), (0, 1, 0)),
    ]):
        k.crack(f"Rift{i}", pts, o, u, (0, 0, 1), v["rift"], "Cap", width=0.012, depth=0.012)
    for i, (x, y, z) in enumerate([(0.12, -0.18, 0.56), (-0.18, -0.06, 0.58), (0.04, 0.16, 0.62), (0.22, 0.1, 0.48),
                                   (-0.1, 0.22, 0.48), (-0.24, -0.16, 0.42)]):
        k.box(f"Sulfur{i}", (0.05, 0.05, 0.035), (x, y, z), v["sulfur"], "Cap", rot=(20 * i, 30 * i, 0))
    # Пар над куполом
    for i, (x, z, r) in enumerate([(0.0, 0.72, 0.07), (0.05, 0.82, 0.055), (-0.03, 0.91, 0.045)]):
        k.sphere(f"Steam{i}", r, (x, 0.02, z), v["steam"], "Steam", segs=5, rings=3)
    # Щупальца
    for i in range(TENT):
        a = math.tau * (i + 0.5) / TENT
        x, y = 0.2 * math.cos(a), 0.2 * math.sin(a)
        k.limb(f"Tent{i}", (x, y, 0.22), (x * 1.6, y * 1.6, 0.03), 0.055, 0.025, jelly_d, f"Tent{i}", segs=6)
    return k.join_parts("KettleJellyMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Cap": ((0, 0, 0.18), (0, 0, 0.64), "Root"),
    "Steam": ((0, 0.02, 0.66), (0, 0.02, 0.94), "Cap"),
}
for _i in range(TENT):
    _a = math.tau * (_i + 0.5) / TENT
    _x, _y = 0.2 * math.cos(_a), 0.2 * math.sin(_a)
    BONES[f"Tent{_i}"] = ((_x, _y, 0.22), (_x * 1.6, _y * 1.6, 0.03), "Cap")

LOC_BONES = ("Root", "Cap")
SCALED = ("Cap", "Steam")


def stance():
    return Pose({})


def tentacles(p, t, amp=8.0, speed=2.0):
    for i in range(TENT):
        p.add(f"Tent{i}", x=amp * wave(t, speed, i / TENT), z=amp * 0.6 * wave(t, speed, i / TENT + 0.25))


def idle(t):
    """Покой (3 сек): купол медленно пульсирует, щупальца шевелятся, пар толчками."""
    p = stance()
    pulse_ = wave(t, 2)
    p.size("Cap", 1.0 + 0.05 * pulse_, 1.0 + 0.05 * pulse_, 1.0 - 0.05 * pulse_)
    p.move("Cap", z=0.01 * pulse_)
    tentacles(p, t, amp=6)
    p.size("Steam", 0.7 + 0.5 * pulse(t, 0.3, 0.12) + 0.4 * pulse(t, 0.75, 0.1))
    return p


def walk(t):
    """Переползает (0.8 сек): купол толчками сжимается и вытягивается, щупальца гребут."""
    p = stance()
    pulse_ = wave(t, 2)
    p.size("Cap", 1.0 + 0.08 * pulse_, 1.0 + 0.08 * pulse_, 1.0 - 0.1 * pulse_)
    p.add("Cap", x=6 * wave(t, 2, 0.25))
    tentacles(p, t, amp=16, speed=2)
    p.size("Steam", 0.8)
    return p


def attack(t):
    """Брызги кипятка (0.8 сек): купол сжимается → резко раздувается (к 0.4 сек), передние щупальца
    взлетают, пар вырывается → опадает."""
    p = stance()
    s = track(t, [(0, 1.0), (0.25, 0.85), (0.4, 1.2), (0.6, 1.1), (1, 1.0)])
    p.size("Cap", s, s, 2.0 - s)
    p.add("Cap", x=track(t, [(0, 0), (0.25, -8), (0.4, 14), (1, 0)]))
    lift = track(t, [(0, 0), (0.25, -0.4), (0.4, 1), (0.6, 0.6), (1, 0)])
    for i in range(TENT):
        front = math.sin(math.tau * (i + 0.5) / TENT) < 0
        p.add(f"Tent{i}", x=(-50 if front else 10) * lift)
    p.size("Steam", track(t, [(0, 0.7), (0.4, 1.8), (0.6, 1.5), (1, 0.7)]))
    return p


def hit(t):
    """Получил удар (0.4 сек): купол сминается и колышется, щупальца дёргаются."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, -0.4), (0.7, 0.15), (1, 0)])
    p.size("Cap", 1.0 + 0.15 * snap, 1.0 + 0.15 * snap, 1.0 - 0.2 * snap)
    p.add("Cap", x=-12 * snap)
    tentacles(p, t, amp=14 * abs(snap), speed=3)
    p.size("Steam", 0.7 + 0.6 * abs(snap))
    return p


def death(t):
    """Гибель (1.2 сек): купол оседает и растекается в лужу, ядро гаснет, пар уходит."""
    p = stance()
    melt = track(t, [(0, 0), (0.2, -0.1), (0.8, 1), (1, 1)])
    p.size("Cap", 1.0 + 0.5 * melt, 1.0 + 0.5 * melt, max(0.12, 1.0 - 0.88 * melt))
    p.move("Cap", z=-0.3 * melt)
    for i in range(TENT):
        p.add(f"Tent{i}", x=-40 * melt)
    p.size("Steam", track(t, [(0, 0.7), (0.3, 1.4), (1, 0.01)]))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("KettleJelly")
    body = build_mesh()
    rig = k.build_armature("KettleJelly", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Hit", 12, hit, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Death", 36, death, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "kettle_jelly")
