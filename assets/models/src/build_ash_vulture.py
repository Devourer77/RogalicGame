# Пепельный падальщик — крупная птица-падальщик Тракта (акт 2, Пепелище и Дюны), ~1.0 м стоя, размах ~1.8 м.
# Рваные угольно-серые перья в пепле, голая морщинистая серая шея, тяжёлый тёмный крючковатый клюв,
# бирюзовые огоньки глаз и трещины вдоль костей крыльев; на кончиках перьев тлеют угли.
# Перелетает преграды, бьёт раненого; раненая — улетает на край поля.
# Смотрит в -Y. Анимации: Idle (сидит, крылья полураскрыты), Walk (перелёт, взмахи), Attack (клевок
# с налёта), Hit, Death.
# Запуск: python3 build_ash_vulture.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))


def build_mesh():
    v = a2.volcano_mats()
    feather = k.mat("AV_Feather", (0.27, 0.27, 0.28), rough=0.9)
    feather_l = k.mat("AV_FeatherLight", (0.5, 0.5, 0.5), rough=0.9)
    neck = k.mat("AV_Neck", (0.56, 0.52, 0.5), rough=0.8)
    beak = k.mat("AV_Beak", (0.24, 0.22, 0.2), rough=0.5)
    talon = k.mat("AV_Talon", (0.3, 0.27, 0.24), rough=0.6)
    # Тело и светлый «воротник»
    k.sphere("Body", 0.2, (0, 0.02, 0.62), feather, "Body", scale=(0.9, 1.25, 1.0), segs=8, rings=5)
    k.sphere("Breast", 0.15, (0, -0.12, 0.66), feather_l, "Body", scale=(0.95, 0.8, 1.0), segs=7, rings=4)
    k.sphere("Ruff", 0.14, (0, -0.1, 0.82), feather_l, "Body", scale=(1.2, 1.0, 0.6), segs=7, rings=4)
    # Голая шея и голова с клювом
    k.limb("Neck", (0, -0.12, 0.82), (0, -0.2, 0.98), 0.05, 0.04, neck, "Neck", segs=6)
    k.sphere("Head", 0.075, (0, -0.24, 1.02), neck, "Head", scale=(0.9, 1.2, 0.9), segs=7, rings=4)
    k.limb("Beak", (0, -0.3, 1.02), (0, -0.4, 0.98), 0.035, 0.012, beak, "Head", segs=6)
    k.limb("BeakHook", (0, -0.4, 0.98), (0, -0.41, 0.94), 0.012, 0.003, beak, "Head", segs=4)
    for s in (-1, 1):
        k.box(f"Eye{s}", (0.015, 0.02, 0.015), (0.045 * s, -0.28, 1.04), v["rift"], "Head")
    # Хвост
    k.plate("Tail", [(-0.1, 0), (0.1, 0), (0.12, 0.22), (0.04, 0.2), (0.0, 0.26), (-0.04, 0.2), (-0.12, 0.22)], 0.025,
            (0, 0.2, 0.56), (1, 0, 0), (0, 1, -0.4), feather, "Tail")
    for side, s in SIDES:
        # Крылья: внутренняя часть и маховые перья (на кости WingOut)
        k.plate(f"WingIn.{side}", [(0.0, 0.1), (0.36, 0.06), (0.4, -0.08), (0.2, -0.16), (0.0, -0.12)], 0.03,
                (0.14 * s, 0.0, 0.76), (s, 0, 0), (0, -1, 0.1), feather, f"WingIn.{side}")
        k.crack(f"WingRift.{side}", [(0.02, 0.04), (0.14, 0.02), (0.26, 0.04), (0.38, 0.0)], (0.14 * s, 0.0, 0.785),
                (s, 0, 0), (0, -1, 0), v["rift"], f"WingIn.{side}", width=0.014, depth=0.012)
        for j in range(5):
            x0 = 0.5 + 0.0 * j
            k.plate(f"Primary.{side}{j}", [(0.0, 0.03), (0.38 - 0.04 * j, 0.02), (0.42 - 0.04 * j, -0.01), (0.0, -0.03)],
                    0.02, (0.5 * s, 0.04 - 0.06 * j, 0.77), (s, -0.25 + 0.12 * j, 0), (0, -1, 0), feather,
                    f"WingOut.{side}")
            k.box(f"Ember.{side}{j}", (0.03, 0.03, 0.025), ((0.5 + 0.4 - 0.04 * j) * s, 0.04 - 0.06 * j - (0.1 - 0.05 * j), 0.77),
                  v["ember"], f"WingOut.{side}")
        k.plate(f"Covert.{side}", [(0.0, 0.08), (0.2, 0.04), (0.22, -0.12), (0.0, -0.1)], 0.03,
                (0.46 * s, 0.0, 0.78), (s, 0, 0), (0, -1, 0), feather_l, f"WingOut.{side}")
        # Лапы
        k.limb(f"Leg.{side}", (0.08 * s, 0.0, 0.48), (0.09 * s, -0.02, 0.12), 0.035, 0.025, neck, f"Leg.{side}", segs=5)
        for j in (-1, 0, 1):
            k.limb(f"Talon.{side}{j}", (0.09 * s, -0.02, 0.1), (0.09 * s + 0.05 * j, -0.1, 0.01), 0.012, 0.004, talon,
                   f"Leg.{side}", segs=4)
    return k.join_parts("AshVultureMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Body": ((0, 0.04, 0.48), (0, 0.04, 0.8), "Root"),
    "Neck": ((0, -0.12, 0.8), (0, -0.2, 0.98), "Body"),
    "Head": ((0, -0.2, 0.98), (0, -0.36, 1.02), "Neck"),
    "Tail": ((0, 0.2, 0.56), (0, 0.42, 0.48), "Body"),
}
for _side, _s in SIDES:
    BONES.update({
        f"WingIn.{_side}": ((0.14 * _s, 0.0, 0.76), (0.5 * _s, 0.0, 0.76), "Body"),
        f"WingOut.{_side}": ((0.5 * _s, 0.0, 0.76), (0.9 * _s, 0.0, 0.76), f"WingIn.{_side}"),
        f"Leg.{_side}": ((0.08 * _s, 0.0, 0.48), (0.09 * _s, -0.02, 0.1), "Body"),
    })

# Крылья полураскрыты и опущены (кости крыльев смотрят вбок: поворот вокруг оси Y кости — вверх/вниз,
# вокруг Z — вперёд/назад). Знаки проверены по листу поз.
STANCE = {"Body": (12, 0, 0), "Neck": (30, 0, 0), "Head": (-30, 0, 0)}
LOC_BONES = ("Root", "Body")


def wings(p, up=0.0, fold=0.0, tip=0.0):
    """Крылья: up — поднять (взмах), fold — сложить назад вдоль тела, tip — согнуть концы."""
    for side, s in SIDES:
        p.add(f"WingIn.{side}", x=up, z=fold * s)
        p.add(f"WingOut.{side}", x=tip, z=fold * 0.6 * s)
    return p


def stance():
    p = Pose(STANCE)
    wings(p, up=-55, fold=55, tip=-20)
    return p


def idle(t):
    """Сидит (3 сек): крылья полураскрыты и подрагивают, голова дёргается по сторонам, угли тлеют."""
    p = stance()
    p.move("Body", z=0.005 * wave(t, 2))
    look = k.track(t, [(0, 0), (0.15, 0), (0.18, -30), (0.4, -30), (0.43, 20), (0.7, 20), (0.73, 0), (1, 0)])
    p.add("Head", z=look)
    p.add("Neck", x=6 * pulse(t, 0.55, 0.05))
    wings(p, up=6 * pulse(t, 0.8, 0.08), tip=4 * wave(t, 3))
    p.add("Tail", x=4 * wave(t, 1))
    return p


def walk(t):
    """Перелёт (0.8 сек): тяжёлые взмахи, тело поднимается и опускается."""
    p = Pose(STANCE)
    flap = wave(t, 2)
    wings(p, up=50 * flap, fold=-10, tip=20 * wave(t, 2, -0.1))
    p.move("Body", z=0.25 + 0.06 * flap)
    p.add("Body", x=20)
    p.add("Leg.R", x=40)
    p.add("Leg.L", x=40)
    p.add("Tail", x=-10 * flap)
    return p


def attack(t):
    """Клевок с налёта (0.8 сек): крылья распахнуты вверх → бросок вниз, клюв бьёт (к 0.4 сек) → складывает."""
    p = stance()
    spread = track(t, [(0, 0), (0.22, 1), (0.4, 0.6), (0.6, 0.4), (1, 0)])
    wings(p, up=70 * spread, fold=-40 * spread)
    strike = track(t, [(0, 0), (0.25, -1), (0.4, 1), (0.55, 0.8), (1, 0)])
    p.add("Neck", x=30 * strike)
    p.add("Head", x=10 * strike)
    p.add("Body", x=14 * strike)
    p.move("Root", y=track(t, [(0, 0), (0.25, 0.05), (0.4, -0.14), (0.6, -0.1), (1, 0)]))
    p.move("Body", z=track(t, [(0, 0), (0.22, 0.12), (0.4, 0.0), (1, 0)]))
    return p


def hit(t):
    """Получил удар (0.4 сек): перья топорщатся, крылья взмётываются, голова мотается."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
    p.move("Root", y=0.06 * snap)
    p.add("Body", x=-14 * snap)
    p.add("Neck", x=-24 * whip)
    wings(p, up=50 * whip, fold=-30 * snap)
    return p


def death(t):
    """Гибель (1.2 сек): взмах, падает набок, крыло распластано по земле, судорога."""
    p = stance()
    roll = track(t, [(0, 0), (0.2, -10), (0.55, 85), (0.65, 80), (1, 84)])
    p.set("Root", 0, 0, roll)
    p.move("Root", x=track(t, [(0, 0), (0.55, 0.12), (1, 0.12)]), z=track(t, [(0, 0), (0.55, 0.14), (1, 0.14)]))
    flop = track(t, [(0, 0), (0.25, 1), (0.6, 0.3), (1, 0.4)])
    wings(p, up=40 * flop, fold=-30 * flop)
    p.add("Neck", x=-20 * track(t, [(0, 0), (0.6, 1), (1, 1)]))
    p.add("Leg.R", x=-30 * pulse(t, 0.88, 0.05))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("AshVulture")
    body = build_mesh()
    rig = k.build_armature("AshVulture", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LOC_BONES)
    k.bake(rig, "Walk", 24, walk, cyclic=True, loc_bones=LOC_BONES)
    k.bake(rig, "Attack", 24, attack, loc_bones=LOC_BONES)
    k.bake(rig, "Hit", 12, hit, loc_bones=LOC_BONES)
    k.bake(rig, "Death", 36, death, loc_bones=LOC_BONES)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "ash_vulture")
