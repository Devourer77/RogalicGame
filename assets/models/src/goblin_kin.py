# Общее «тело гоблина» для гоблинов-специалистов (пращник, шаман): те же пропорции и кожа,
# что у обычного гоблина из build_goblin.py, но без тесака и щита — руки свободны под своё снаряжение.
# Здесь же общие движения ног, корпуса, головы и ушей; руки и снаряжение каждый скрипт двигает сам.
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

SIDES = (("R", -1), ("L", 1))


def materials(prefix):
    """Общие материалы гоблинов. Кожа светлее, чем в палитре мира, — иначе сливается с плитами."""
    return {
        "skin": k.mat(prefix + "_Skin", (0.50, 0.60, 0.40), rough=0.85),
        "dark": k.mat(prefix + "_DarkSkin", (0.34, 0.43, 0.28), rough=0.9),
        "leather": k.mat(prefix + "_Leather", (0.29, 0.21, 0.145), rough=0.9),
        "tooth": k.mat(prefix + "_Tooth", (0.82, 0.78, 0.64), rough=0.6),
        "rift": k.mat(prefix + "_Rift", (0.25, 0.85, 0.75), rough=0.4, emit=1.1),   # трещины Раскола и глаза
    }


def body(M, vest=True, ears=True):
    """Ноги, руки с кулаками, таз, пузо, жилетка, шея и большая голова."""
    skin, dark, leather, rift = M["skin"], M["dark"], M["leather"], M["rift"]
    for side, s in SIDES:
        x = 0.10 * s
        k.box(f"Foot.{side}", (0.10, 0.17, 0.06), (x, -0.035, 0.03), skin, f"Foot.{side}")
        for i in (-1, 1):
            k.limb(f"Claw.{side}{i}", (x + 0.03 * i, -0.11, 0.03), (x + 0.04 * i, -0.17, 0.012), 0.022, 0.004,
                   dark, f"Foot.{side}", segs=3)
        k.limb(f"Shin.{side}", (x, 0, 0.07), (x, -0.01, 0.22), 0.045, 0.06, skin, f"Shin.{side}")
        k.sphere(f"Knee.{side}", 0.058, (x, -0.015, 0.22), dark, f"Shin.{side}", segs=6, rings=4)
        k.limb(f"Thigh.{side}", (x, 0, 0.22), (x, 0, 0.40), 0.062, 0.08, skin, f"Thigh.{side}")
        ax = 0.19 * s
        k.sphere(f"Shoulder.{side}", 0.068, (ax, 0, 0.68), skin, f"UpperArm.{side}", segs=6, rings=4)
        k.limb(f"UpperArm.{side}", (ax, 0, 0.68), (0.22 * s, 0, 0.50), 0.052, 0.045, skin, f"UpperArm.{side}")
        k.sphere(f"Elbow.{side}", 0.05, (0.22 * s, 0.005, 0.50), dark, f"ForeArm.{side}", segs=6, rings=4)
        k.limb(f"ForeArm.{side}", (0.22 * s, 0, 0.50), (0.225 * s, -0.02, 0.33), 0.046, 0.058, skin, f"ForeArm.{side}")
        hx = 0.225 * s
        k.sphere(f"Fist.{side}", 0.056, (hx, -0.03, 0.28), skin, f"Hand.{side}", scale=(0.85, 1.05, 1.0), segs=6, rings=4)
        k.box(f"Fingers.{side}", (0.088, 0.04, 0.085), (hx, -0.072, 0.275), dark, f"Hand.{side}")
        k.box(f"Thumb.{side}", (0.035, 0.07, 0.035), (hx - 0.03 * s, -0.055, 0.325), skin, f"Hand.{side}", rot=(15, 0, 0))
    k.sphere("Pelvis", 0.15, (0, 0, 0.42), leather, "Hips", scale=(1.08, 0.85, 0.7), segs=6, rings=4)
    k.limb("Belt", (0, 0, 0.445), (0, 0, 0.50), 0.168, 0.165, leather, "Hips", segs=8)
    k.sphere("Belly", 0.158, (0, -0.012, 0.53), skin, "Spine", scale=(1.05, 0.92, 0.9), segs=7, rings=4)
    if vest:
        k.limb("Vest", (0, 0.012, 0.52), (0, 0.005, 0.70), 0.172, 0.15, leather, "Chest", segs=8)
    else:
        k.limb("Ribs", (0, 0.012, 0.52), (0, 0.005, 0.70), 0.165, 0.145, skin, "Chest", segs=8)
    k.limb("Neck", (0, 0, 0.68), (0, -0.02, 0.77), 0.075, 0.065, skin, "Chest")
    # Голова: череп, брови, крючковатый нос, светящиеся глаза, челюсть с клыками
    k.sphere("Skull", 0.16, (0, -0.02, 0.87), skin, "Head", scale=(1.15, 1.05, 0.9), segs=8, rings=4)
    k.box("BrowRidge", (0.24, 0.07, 0.04), (0, -0.155, 0.905), dark, "Head", rot=(14, 0, 0))
    for side, s in SIDES:
        eye = [(-0.035, 0.012), (0.035, 0.024), (0.03, -0.014), (-0.028, -0.012)]
        k.plate(f"Eye.{side}", eye if s > 0 else [(-a, b) for a, b in reversed(eye)], 0.02,
                (0.07 * s, -0.178, 0.868), (1, 0, 0), (0, 0, 1), rift, "Head")
        if ears:
            ear = [(0.0, -0.045), (0.0, 0.05), (0.14, 0.085), (0.30, 0.10), (0.17, 0.02), (0.13, -0.03)]
            k.plate(f"Ear.{side}", ear, 0.022, (0.155 * s, 0.0, 0.87), (s, 0.18, 0.28), (0, 0, 1), skin, f"Ear.{side}")
            k.plate(f"EarInner.{side}", [(0.02, -0.02), (0.02, 0.03), (0.2, 0.07), (0.12, 0.0)], 0.026,
                    (0.155 * s, -0.002, 0.872), (s, 0.18, 0.28), (0, 0, 1), dark, f"Ear.{side}")
    k.limb("Nose", (0, -0.16, 0.875), (0, -0.30, 0.79), 0.042, 0.012, skin, "Head", segs=5)
    k.box("Jaw", (0.21, 0.17, 0.06), (0, -0.085, 0.765), dark, "Jaw")
    for s in (-1, 1):
        k.limb(f"Tusk{s}", (0.075 * s, -0.155, 0.78), (0.085 * s, -0.165, 0.86), 0.02, 0.003, M["tooth"], "Jaw", segs=4)
    # Трещины Раскола
    k.crack("CrackBelly", [(0, 0.07), (0.03, 0.03), (-0.01, 0.0), (0.04, -0.05)], (-0.04, -0.148, 0.53),
            (1, 0, 0), (0, 0, 1), rift, "Spine", depth=0.035)
    k.crack("CrackArm", [(0, 0.06), (0.018, 0.02), (-0.02, -0.02), (0.01, -0.07)], (0.247, 0.0, 0.60),
            (0, 1, 0), (0, 0, 1), rift, "UpperArm.L", depth=0.03)
    k.crack("CrackLeg", [(0, 0.05), (0.02, 0.01), (-0.01, -0.04)], (-0.10, -0.066, 0.32),
            (1, 0, 0), (0, 0, 1), rift, "Thigh.R", depth=0.03)


def bones(extra=None):
    """Скелет гоблина; extra — свои кости персонажа (оружие, плащ…)."""
    b = {
        "Root": ((0, 0, 0), (0, 0, 0.15), None),
        "Hips": ((0, 0, 0.40), (0, 0, 0.47), "Root"),
        "Spine": ((0, 0, 0.47), (0, 0, 0.58), "Hips"),
        "Chest": ((0, 0, 0.58), (0, 0, 0.72), "Spine"),
        "Head": ((0, 0, 0.72), (0, 0, 0.98), "Chest"),
        "Jaw": ((0, -0.02, 0.79), (0, -0.16, 0.76), "Head"),
    }
    for side, s in SIDES:
        b.update({
            f"Ear.{side}": ((0.155 * s, 0, 0.87), (0.42 * s, 0.05, 0.97), "Head"),
            f"UpperArm.{side}": ((0.19 * s, 0, 0.68), (0.22 * s, 0, 0.50), "Chest"),
            f"ForeArm.{side}": ((0.22 * s, 0, 0.50), (0.225 * s, -0.02, 0.33), f"UpperArm.{side}"),
            f"Hand.{side}": ((0.225 * s, -0.02, 0.33), (0.225 * s, -0.03, 0.24), f"ForeArm.{side}"),
            f"Thigh.{side}": ((0.10 * s, 0, 0.40), (0.10 * s, 0, 0.22), "Hips"),
            f"Shin.{side}": ((0.10 * s, 0, 0.22), (0.10 * s, 0, 0.07), f"Thigh.{side}"),
            f"Foot.{side}": ((0.10 * s, 0, 0.07), (0.10 * s, -0.12, 0.02), f"Shin.{side}"),
        })
    b.update(extra or {})
    return b


def ears(p, up=0.0, back=0.0):
    """Уши: up — приподнять, back — прижать назад (у правого уха ось Z зеркальна)."""
    p.add("Ear.L", x=up, z=back)
    p.add("Ear.R", x=up, z=-back)


def idle_base(p, t):
    """Покой: дыхание, перенос веса, резкие повороты головы с паузами, уши с запаздыванием."""
    breath = wave(t, 2)
    sway = wave(t, 1)
    p.move("Hips", x=0.014 * sway, z=-0.012 * (breath * 0.5 + 0.5))
    p.add("Hips", z=2.5 * sway)
    p.add("Thigh.L", z=-2.5 * sway, x=-2 * breath)
    p.add("Thigh.R", z=-2.5 * sway, x=-1.5 * breath)
    p.add("Shin.L", x=3 * (breath * 0.5 + 0.5))
    p.add("Shin.R", x=3 * (breath * 0.5 + 0.5))
    p.add("Spine", x=2.5 * breath, z=-2.0 * sway)
    p.add("Chest", x=2.5 * wave(t, 2, -0.08))
    yaw = track(t, [(0, 0), (0.1, 0), (0.16, 24), (0.4, 24), (0.47, -6), (0.66, -22), (0.74, -22), (0.9, 0), (1, 0)])
    nod = track(t, [(0, 0), (0.16, -3), (0.4, -3), (0.47, 5), (0.74, 2), (1, 0)])
    p.add("Head", x=nod - 2 * breath, y=yaw, z=-yaw * 0.12)
    lag = track(t, [(0, 0), (0.1, 0), (0.16, -12), (0.26, 0), (0.4, 0), (0.47, 10), (0.57, 0), (1, 0)])
    p.add("Ear.L", x=10 * (pulse(t, 0.27, 0.05) + pulse(t, 0.8, 0.04)) + 2 * breath, z=lag)
    p.add("Ear.R", x=13 * pulse(t, 0.31, 0.05) + 9 * pulse(t, 0.6, 0.04) + 2 * breath, z=lag)
    p.add("Jaw", x=-9 * pulse(t, 0.52, 0.1) - 2 * (breath * 0.5 + 0.5))
    return breath, sway


def walk_base(p, t, lean=22):
    """Бег вприпрыжку: наклон вперёд, таз крутится, уши болтаются. Возвращает (a, bounce) для рук."""
    a = wave(t, 1)
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.1)
    p.move("Hips", z=-0.035 + 0.028 * bounce, x=0.012 * a)
    p.add("Hips", y=10 * a, z=4 * a)
    p.set("Thigh.R", -20 - 42 * a, 0, 6)
    p.set("Thigh.L", -20 + 42 * a, 0, -6)
    p.set("Shin.R", 30 + 46 * max(0.0, c) + 8 * a, 0, 0)
    p.set("Shin.L", 30 + 46 * max(0.0, -c) - 8 * a, 0, 0)
    p.set("Foot.R", 14 - 22 * a, 0, 0)
    p.set("Foot.L", 14 + 22 * a, 0, 0)
    p.set("Spine", lean, -6 - 10 * a, 0)
    p.set("Chest", 12, -6 - 6 * a, 0)
    p.set("Head", -26 + 4 * bounce, 10 + 12 * a, 0)
    ears(p, up=-12 * wave(t, 2, -0.12), back=16)
    p.add("Jaw", x=-6 - 4 * bounce)
    return a, bounce


def hit_base(p, t):
    """Удар по гоблину: корпус отбрасывает сразу, голова мотается позже. Возвращает (snap, whip) для рук."""
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.18, 0.4), (0.32, 1), (0.55, -0.35), (0.78, 0.1), (1, 0)])
    p.move("Root", y=0.12 * snap)
    p.move("Hips", z=-0.03 * snap)
    p.add("Spine", x=-30 * snap, y=14 * snap)
    p.add("Chest", x=-14 * snap)
    p.add("Head", x=-30 * whip, y=-20 * snap, z=8 * whip)
    p.add("Jaw", x=-28 * snap)
    p.add("Thigh.L", x=14 * snap)
    p.add("Thigh.R", x=-16 * snap)
    p.add("Shin.R", x=14 * snap)
    ears(p, up=22 * whip, back=-34 * whip)
    return snap, whip


DEATH_K = [0.0, 0.2, 0.42, 0.68, 1.0]   # стойка, отшатнулся, на коленях, упал, затих


def death_base(p, t, S):
    """Гибель: пошатнулся, колени подломились, рухнул на спину, судорога. Руки задаёт сам персонаж через tr()."""
    K = DEATH_K

    def tr(bone, stagger, kneel, fall, rest):
        p.set(bone, *track3(t, [(K[0], S.get(bone, (0, 0, 0))), (K[1], stagger), (K[2], kneel), (K[3], fall), (K[4], rest)]))

    tr("Spine", (-22, 12, 0), (10, 0, 6), (-12, 0, 0), (-8, 0, 0))
    tr("Chest", (-12, 6, 0), (14, 0, 4), (-6, 0, 0), (-4, 0, 0))
    tr("Head", (-34, -20, 0), (26, 10, 10), (-22, 24, 0), (-14, 30, 0))
    tr("Jaw", (-30, 0, 0), (-12, 0, 0), (-26, 0, 0), (-18, 0, 0))
    tr("Thigh.L", (-10, 0, -9), (-60, 0, -12), (-30, 0, -16), (-18, 0, -18))
    tr("Shin.L", (30, 0, 0), (118, 0, 0), (60, 0, 0), (28, 0, 0))
    tr("Thigh.R", (-30, 0, 12), (-40, 0, 14), (-14, 0, 18), (-6, 0, 20))
    tr("Shin.R", (40, 0, 0), (112, 0, 0), (40, 0, 0), (12, 0, 0))
    tr("Foot.L", (8, 0, 0), (40, 0, 0), (30, 0, 0), (30, 0, 0))
    tr("Foot.R", (20, 0, 0), (40, 0, 0), (30, 0, 0), (30, 0, 0))
    lean = track(t, [(0, 0), (K[1], -6), (K[2], 6), (K[3], -86), (K[3] + 0.06, -80), (K[3] + 0.12, -88), (1, -88)])
    p.set("Root", lean, 0, 0)
    p.move("Root", y=track(t, [(0, 0), (K[1], 0.1), (K[2], 0.12), (K[3], 0.22), (1, 0.22)]),
           z=track(t, [(0, 0), (K[2], 0), (K[3], 0.1), (1, 0.1)]))
    p.move("Hips", z=track(t, [(0, -0.045), (K[1], -0.03), (K[2], -0.2), (K[3], -0.06), (1, -0.06)]))
    flop = track(t, [(0, 0), (K[1], -30), (K[2], 20), (K[3], -40), (K[3] + 0.08, 14), (K[3] + 0.16, -6), (1, 0)])
    spasm = pulse(t, 0.86, 0.05)
    settle = k.smooth((t - K[3]) / (1.0 - K[3]))
    p.set("Ear.L", 4 - 30 * settle + 12 * spasm, 0, flop)
    p.set("Ear.R", 4 - 30 * settle, 0, -flop)
    p.add("Shin.L", x=16 * spasm)
    return tr, spasm
