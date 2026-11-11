# Волк — тварь Раскола. Тощий, рёбра наружу, шерсть клочьями, бирюзовые трещины на морде и спине.
# Низкий вытянутый силуэт (~0.72 м в холке) — отличается от всех двуногих.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Запуск в Blender: вкладка Scripting → Open → этот файл → Run Script. Рядом должен лежать char_kit.py.
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "Wolf"


# ---------- Модель ----------

def build_mesh():
    fur = k.mat("Wolf_Fur", (0.44, 0.45, 0.50), rough=0.9)
    dark = k.mat("Wolf_DarkFur", (0.20, 0.21, 0.26), rough=0.9)
    light = k.mat("Wolf_LightFur", (0.64, 0.65, 0.68), rough=0.9)
    rib = k.mat("Wolf_Rib", (0.74, 0.73, 0.70), rough=0.8)
    nose = k.mat("Wolf_Nose", (0.07, 0.07, 0.09), rough=0.5)
    fang = k.mat("Wolf_Fang", (0.90, 0.88, 0.78), rough=0.5)
    mouth = k.mat("Wolf_Mouth", (0.15, 0.10, 0.14), rough=0.8)
    rift = k.mat("Wolf_Rift", (0.25, 0.85, 0.75), rough=0.4, emit=1.1)

    # Туловище: костлявый таз, втянутый живот, глубокая грудная клетка
    k.limb("Pelvis", (0, 0.36, 0.56), (0, 0.16, 0.58), 0.085, 0.105, fur, "Hips", segs=7)
    for s in (-1, 1):
        k.sphere(f"HipBone{s}", 0.05, (0.075 * s, 0.27, 0.615), dark, "Hips", segs=5, rings=3)
    k.limb("Waist", (0, 0.18, 0.575), (0, -0.06, 0.565), 0.085, 0.12, fur, "Spine", segs=7)
    k.limb("Ribcage", (0, -0.04, 0.55), (0, -0.31, 0.55), 0.155, 0.135, fur, "Chest", segs=8)
    k.sphere("Keel", 0.10, (0, -0.2, 0.455), light, "Chest", scale=(0.85, 1.5, 0.8), segs=6, rings=3)
    # Рёбра наружу — светлые полоски на боках
    for s in (-1, 1):
        for i in range(4):
            y = -0.04 - i * 0.068
            k.box(f"Rib{s}{i}", (0.014, 0.022, 0.19 - i * 0.012), (0.146 * s - 0.004 * i * s, y, 0.545), rib, "Chest",
                  rot=(-14, 10 * s, 0))
        k.sphere(f"Blade{s}", 0.075, (0.085 * s, -0.25, 0.665), dark, "Chest", scale=(0.7, 1.1, 1.0), segs=5, rings=3)

    # Шерсть клочьями: загривок, хребет, бока
    tufts = [
        ((0, -0.36, 0.70), (0, -0.24, 0.79), 0.05, "Neck"), ((0, -0.28, 0.69), (0, -0.13, 0.775), 0.055, "Chest"),
        ((0, -0.17, 0.68), (0.02, -0.02, 0.745), 0.05, "Chest"), ((0, -0.04, 0.66), (-0.02, 0.10, 0.71), 0.04, "Spine"),
        ((0, 0.10, 0.655), (0.02, 0.22, 0.70), 0.035, "Spine"), ((0, 0.26, 0.64), (0, 0.37, 0.675), 0.03, "Hips"),
        ((0.11, -0.30, 0.60), (0.20, -0.18, 0.64), 0.05, "Chest"), ((-0.11, -0.30, 0.60), (-0.20, -0.18, 0.64), 0.05, "Chest"),
        ((0.10, -0.16, 0.46), (0.15, -0.04, 0.41), 0.04, "Chest"), ((-0.10, -0.2, 0.46), (-0.16, -0.08, 0.42), 0.04, "Chest"),
    ]
    for i, (a, b, r, bone) in enumerate(tufts):
        k.limb(f"Tuft{i}", a, b, r, 0.006, dark if i < 6 else fur, bone, segs=4)

    # Шея и голова
    k.limb("Neck", (0, -0.27, 0.585), (0, -0.43, 0.665), 0.105, 0.078, fur, "Neck", segs=7)
    k.limb("Throat", (0, -0.28, 0.50), (0, -0.42, 0.60), 0.06, 0.05, light, "Neck", segs=5)
    k.sphere("Skull", 0.098, (0, -0.45, 0.675), fur, "Head", scale=(1.0, 1.15, 0.9), segs=7, rings=4)
    k.limb("SnoutTop", (0, -0.49, 0.675), (0, -0.70, 0.635), 0.062, 0.036, dark, "Head", segs=6)
    k.box("NoseTip", (0.05, 0.04, 0.04), (0, -0.71, 0.64), nose, "Head")
    k.box("Palate", (0.07, 0.17, 0.014), (0, -0.595, 0.612), mouth, "Head", rot=(10, 0, 0))
    for side, s in (("R", -1), ("L", 1)):
        k.limb(f"Cheek.{side}", (0.07 * s, -0.45, 0.64), (0.15 * s, -0.36, 0.61), 0.05, 0.006, light, "Head", segs=4)
        k.box(f"Brow.{side}", (0.06, 0.06, 0.024), (0.055 * s, -0.525, 0.712), dark, "Head", rot=(16, -16 * s, 12 * s))
        k.box(f"Eye.{side}", (0.034, 0.04, 0.022), (0.066 * s, -0.53, 0.692), rift, "Head", rot=(14, -20 * s, 10 * s))
        k.limb(f"UpperFang.{side}", (0.03 * s, -0.665, 0.62), (0.03 * s, -0.67, 0.565), 0.013, 0.002, fang, "Head", segs=4)
        k.limb(f"UpperTooth.{side}", (0.04 * s, -0.60, 0.615), (0.04 * s, -0.60, 0.585), 0.01, 0.002, fang, "Head", segs=3)
        # Уши на своих костях; левое рваное
        ear = [(-0.038, 0.0), (0.038, 0.0), (0.012, 0.15)] if s < 0 else \
            [(-0.038, 0.0), (0.038, 0.0), (0.03, 0.08), (0.008, 0.06), (0.0, 0.13)]
        k.plate(f"Ear.{side}", ear, 0.02, (0.062 * s, -0.42, 0.745), (1, 0, 0), (0.25 * s, 0.1, 1), dark, f"Ear.{side}")
    # Нижняя челюсть
    k.limb("LowerJaw", (0, -0.46, 0.615), (0, -0.665, 0.588), 0.048, 0.026, light, "Jaw", segs=6)
    k.box("Tongue", (0.045, 0.16, 0.012), (0, -0.58, 0.612), mouth, "Jaw", rot=(8, 0, 0))
    for s in (-1, 1):
        k.limb(f"LowerFang{s}", (0.026 * s, -0.64, 0.60), (0.026 * s, -0.645, 0.645), 0.012, 0.002, fang, "Jaw", segs=4)

    # Трещины Раскола: на морде и вдоль хребта
    k.crack("CrackSnout", [(0, 0), (0.05, 0.022), (0.09, -0.012), (0.15, 0.018)], (0.012, -0.50, 0.732),
            (0, -1, -0.2), (1, 0, 0), rift, "Head", width=0.011, depth=0.02)
    k.crack("CrackBackA", [(0, 0), (0.07, 0.03), (0.13, -0.02), (0.2, 0.025)], (0.045, -0.06, 0.672),
            (0, -1, 0), (1, 0, 0), rift, "Chest", width=0.012, depth=0.024)
    k.crack("CrackBackB", [(0, 0), (0.07, -0.025), (0.14, 0.02), (0.2, -0.01)], (-0.04, 0.2, 0.662),
            (0, -1, 0), (1, 0, 0), rift, "Spine", width=0.012, depth=0.024)
    k.crack("CrackFlank", [(0, 0.08), (0.03, 0.03), (-0.02, -0.02), (0.02, -0.07)], (0.118, 0.27, 0.50),
            (0, 1, 0), (0, 0, 1), rift, "BackUpper.L", width=0.012, depth=0.024)

    # Хвост из двух частей — волной
    k.limb("TailBase", (0, 0.35, 0.565), (0, 0.55, 0.49), 0.042, 0.058, dark, "Tail1", segs=5)
    k.limb("TailTip", (0, 0.54, 0.495), (0, 0.80, 0.40), 0.06, 0.008, fur, "Tail2", segs=5)
    k.limb("TailTuft", (0.02, 0.60, 0.47), (0.06, 0.74, 0.37), 0.035, 0.005, dark, "Tail2", segs=4)

    # Длинные худые лапы
    for side, s in (("R", -1), ("L", 1)):
        fx = 0.12 * s
        k.limb(f"FrontUpper.{side}", (fx, -0.24, 0.57), (fx, -0.20, 0.34), 0.062, 0.04, fur, f"FrontUpper.{side}")
        k.sphere(f"Elbow.{side}", 0.04, (fx, -0.195, 0.34), dark, f"FrontLower.{side}", segs=5, rings=3)
        k.limb(f"FrontLower.{side}", (fx, -0.20, 0.34), (fx, -0.23, 0.07), 0.036, 0.028, light, f"FrontLower.{side}")
        k.box(f"FrontPaw.{side}", (0.075, 0.12, 0.05), (fx, -0.265, 0.025), light, f"FrontPaw.{side}")
        k.limb(f"FrontClaw.{side}", (fx, -0.32, 0.03), (fx, -0.37, 0.008), 0.03, 0.004, dark, f"FrontPaw.{side}", segs=3)

        bx = 0.115 * s
        k.limb(f"BackUpper.{side}", (bx, 0.28, 0.55), (bx, 0.18, 0.33), 0.078, 0.045, fur, f"BackUpper.{side}")
        k.sphere(f"Knee.{side}", 0.042, (bx, 0.175, 0.33), dark, f"BackLower.{side}", segs=5, rings=3)
        k.limb(f"BackLower.{side}", (bx, 0.18, 0.33), (bx, 0.36, 0.20), 0.04, 0.028, fur, f"BackLower.{side}")
        k.limb(f"BackHock.{side}", (bx, 0.36, 0.20), (bx, 0.33, 0.05), 0.028, 0.025, light, f"BackPaw.{side}")
        k.box(f"BackPaw.{side}", (0.07, 0.12, 0.05), (bx, 0.29, 0.025), light, f"BackPaw.{side}")

    return k.join_parts("WolfMesh")


# ---------- Скелет ----------
# Hips — кость «вверх» над тазом: двигает и наклоняет всё тело. От неё вперёд идут Spine → Chest → Neck → Head.

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Hips": ((0, 0.28, 0.50), (0, 0.28, 0.62), "Root"),
    "Spine": ((0, 0.20, 0.575), (0, -0.04, 0.56), "Hips"),
    "Chest": ((0, -0.04, 0.56), (0, -0.28, 0.555), "Spine"),
    "Neck": ((0, -0.28, 0.58), (0, -0.42, 0.66), "Chest"),
    "Head": ((0, -0.42, 0.66), (0, -0.66, 0.63), "Neck"),
    "Jaw": ((0, -0.45, 0.62), (0, -0.66, 0.59), "Head"),
    "Tail1": ((0, 0.35, 0.565), (0, 0.55, 0.49), "Hips"),
    "Tail2": ((0, 0.55, 0.49), (0, 0.80, 0.40), "Tail1"),
}
for side, s in (("R", -1), ("L", 1)):
    fx, bx = 0.12 * s, 0.115 * s
    BONES.update({
        f"Ear.{side}": ((0.062 * s, -0.42, 0.745), (0.085 * s, -0.40, 0.90), "Head"),
        f"FrontUpper.{side}": ((fx, -0.24, 0.57), (fx, -0.20, 0.34), "Chest"),
        f"FrontLower.{side}": ((fx, -0.20, 0.34), (fx, -0.23, 0.07), f"FrontUpper.{side}"),
        f"FrontPaw.{side}": ((fx, -0.23, 0.07), (fx, -0.31, 0.02), f"FrontLower.{side}"),
        f"BackUpper.{side}": ((bx, 0.28, 0.55), (bx, 0.18, 0.33), "Hips"),
        f"BackLower.{side}": ((bx, 0.18, 0.33), (bx, 0.36, 0.20), f"BackUpper.{side}"),
        f"BackPaw.{side}": ((bx, 0.36, 0.20), (bx, 0.33, 0.05), f"BackLower.{side}"),
    })

# Знаки осей для костей, смотрящих вперёд (хребет, шея, голова, челюсть) и назад (хвост)
UP = -1.0     # поднять передний конец кости: X * UP
LEFT = -1.0   # повернуть влево: Z * LEFT


class WolfPose(Pose):
    def lift(self, bone, deg):
        """Поднять морду/грудь (минус — опустить)."""
        return self.add(bone, x=UP * deg)

    def turn(self, bone, deg):
        """Повернуть влево (минус — вправо)."""
        return self.add(bone, z=LEFT * deg)

    def roll(self, bone, deg):
        return self.add(bone, y=deg)

    def tail(self, up=0.0, left=0.0, tip_up=0.0, tip_left=0.0):
        self.add("Tail1", x=up, z=-left)
        self.add("Tail2", x=tip_up, z=-tip_left)
        return self

    def ears(self, fwd_l=0.0, fwd_r=0.0, out=0.0):
        self.add("Ear.L", x=fwd_l, z=-out)
        self.add("Ear.R", x=fwd_r, z=out)
        return self

    def leg(self, name, upper=0.0, lower=0.0, paw=0.0):
        """Лапа: плюс — вперёд. name: FrontL, FrontR, BackL, BackR."""
        base, side = name[:-1], name[-1]
        self.add(f"{base}Upper.{side}", x=-upper)
        self.add(f"{base}Lower.{side}", x=-lower)
        self.add(f"{base}Paw.{side}", x=-paw)
        return self


# ---------- Анимации ----------

def stance():
    """Крадётся: грудь припала к земле, голова низко и вытянута вперёд, хвост опущен, лапы вразнобой."""
    p = WolfPose({}, {})
    p.move("Hips", z=-0.03)
    p.add("Hips", x=7)                    # перед ниже зада
    p.lift("Spine", 3).lift("Chest", -2)
    p.lift("Neck", -26).lift("Head", 18)  # шея вниз, морда смотрит вперёд
    p.add("Jaw", x=-UP * -8)
    p.tail(up=-10, tip_up=-8)
    p.leg("FrontL", upper=22, lower=-30, paw=10)
    p.leg("FrontR", upper=-16, lower=-22, paw=30)
    p.leg("BackL", upper=-14, lower=6, paw=2)
    p.leg("BackR", upper=10, lower=-4, paw=-12)
    p.ears(fwd_l=10, fwd_r=10)
    return p


def jaw(p, deg):
    """Открыть пасть на deg градусов."""
    p.lift("Jaw", -deg)


def idle(t):
    """Покой (3 сек): часто дышит, водит мордой и принюхивается, уши крутятся по отдельности, рычит, хвост ходит волной."""
    p = stance()
    breath = wave(t, 4)
    sway = wave(t, 1)
    p.move("Hips", x=0.012 * sway, z=0.006 * breath)
    p.add("Hips", z=1.5 * sway)
    p.lift("Spine", 1.5 * breath).lift("Chest", -1.5 * breath)
    # Морда: медленно ведёт влево-вправо, с остановками принюхивается (частые мелкие кивки)
    look = track(t, [(0, 0), (0.1, 0), (0.26, 24), (0.44, 24), (0.62, -20), (0.8, -20), (0.94, 0), (1, 0)])
    sniff = (pulse(t, 0.35, 0.09) + pulse(t, 0.71, 0.09)) * wave(t, 14)
    p.turn("Neck", look * 0.6).turn("Head", look * 0.5).roll("Head", look * 0.25)
    p.lift("Neck", -3 * abs(sniff) - 2 * sway).lift("Head", 5 * sniff)
    # Пасть: тяжёлое дыхание, а в середине — оскал с рычанием (голова мелко дрожит)
    growl = pulse(t, 0.53, 0.09)
    jaw(p, 7 + 4 * breath + 12 * growl)
    p.turn("Head", 3 * growl * wave(t, 20))
    # Уши живут своей жизнью
    p.ears(fwd_l=14 * pulse(t, 0.2, 0.05) - 22 * growl + 10 * pulse(t, 0.86, 0.04),
           fwd_r=16 * pulse(t, 0.4, 0.05) - 22 * growl + 12 * pulse(t, 0.67, 0.04),
           out=10 * growl)
    # Хвост: кончик запаздывает за основанием
    p.tail(left=12 * wave(t, 1, 0.1), tip_left=18 * wave(t, 1, -0.08), up=3 * breath, tip_up=5 * wave(t, 2, 0.3))
    # Правая передняя лапа нетерпеливо скребёт землю
    scrape = pulse(t, 0.86, 0.07)
    p.leg("FrontR", upper=20 * scrape, lower=-34 * scrape, paw=-20 * scrape)
    return p


def walk(t):
    """Рысь (0.53 сек): лапы по диагонали, хребет изгибается, голова ныряет, хвост и уши летят следом."""
    p = WolfPose({}, {})
    a = wave(t, 1)            # +1: левая передняя и правая задняя впереди
    c = wave(t, 1, 0.25)
    bounce = wave(t, 2, 0.05)
    p.move("Hips", z=-0.02 + 0.022 * bounce)
    p.add("Hips", x=5 + 3 * bounce, z=3 * a)
    p.lift("Spine", 2 - 4 * bounce).turn("Spine", 5 * a)
    p.lift("Chest", -2 + 2 * bounce).turn("Chest", -4 * a)
    p.lift("Neck", -20 + 5 * wave(t, 2, -0.1)).lift("Head", 14 - 4 * wave(t, 2, -0.2)).turn("Head", -3 * a)
    jaw(p, 10 + 5 * bounce)
    for name, ph in (("FrontL", a), ("FrontR", -a)):
        lift = max(0.0, c if name == "FrontL" else -c)
        p.leg(name, upper=30 * ph, lower=-10 - 42 * lift + 8 * ph, paw=12 + 30 * lift)
    for name, ph in (("BackR", a), ("BackL", -a)):
        lift = max(0.0, c if name == "BackR" else -c)
        p.leg(name, upper=30 * ph, lower=-26 * lift - 6 * ph, paw=-6 + 26 * lift)
    p.ears(fwd_l=-22 + 8 * wave(t, 2, -0.2), fwd_r=-22 + 8 * wave(t, 2, -0.3))
    p.tail(up=14 + 8 * wave(t, 2, -0.15), tip_up=10 * wave(t, 2, -0.35), left=8 * a, tip_left=14 * wave(t, 1, -0.15))
    return p


def attack(t):
    """Укус (0.8 сек): припал к земле → бросок с распахнутой пастью → щёлк клыков и рывок головой (к 0.4 сек) → отскок."""
    p = WolfPose({}, {})
    K = [0.0, 0.22, 0.38, 0.5, 0.66, 1.0]   # стойка, присел, бросок, укус, треплет, стойка
    s = stance()

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.move("Root", y=tr([0, 0.08, -0.2, -0.36, -0.3, 0]))
    p.move("Hips", z=tr([-0.03, -0.12, 0.03, -0.06, -0.04, -0.03]))
    p.add("Hips", x=tr([7, 16, -5, 9, 8, 7]))
    p.lift("Spine", tr([3, -8, 5, 0, 3, 3]))
    p.lift("Chest", tr([-2, 4, 2, -4, -2, -2]))
    p.lift("Neck", tr([-26, -34, -4, -20, -18, -26]))
    p.lift("Head", tr([18, 30, 12, 14, 16, 18]))
    jaw(p, tr([8, 16, 50, 4, 12, 8]))
    # Треплет добычу: рывки головой после укуса
    shake = track(t, [(0, 0), (K[3], 0), (K[3] + 0.05, 20), (K[3] + 0.1, -18), (K[4], 10), (K[4] + 0.08, 0), (1, 0)])
    p.turn("Neck", shake * 0.7).turn("Head", shake).roll("Head", shake * 0.6)
    p.leg("FrontL", upper=tr([22, -20, 70, 40, 26, 22]), lower=tr([-30, -70, -20, -40, -32, -30]), paw=tr([10, 50, -30, 0, 8, 10]))
    p.leg("FrontR", upper=tr([-16, -24, 60, 30, -6, -16]), lower=tr([-22, -70, -10, -36, -26, -22]), paw=tr([30, 50, -30, 6, 26, 30]))
    p.leg("BackL", upper=tr([-14, 30, -46, -10, -12, -14]), lower=tr([6, -40, 20, 0, 4, 6]), paw=tr([2, 30, -30, 0, 2, 2]))
    p.leg("BackR", upper=tr([10, 34, -50, 14, 12, 10]), lower=tr([-4, -44, 22, -8, -6, -4]), paw=tr([-12, 30, -30, -10, -12, -12]))
    ear = tr([10, -30, -40, -34, -10, 10])
    p.ears(fwd_l=ear, fwd_r=ear, out=tr([0, 10, 14, 10, 0, 0]))
    p.tail(up=tr([-10, 24, 34, 6, -4, -10]), tip_up=tr([-8, 10, 30, 30, 4, -8]), tip_left=shake * -0.8)
    return p


def hit(t):
    """Получил удар (0.47 сек): взвизгнул, тело отбросило и скрутило, голова мотнулась, хвост поджат, уши прижаты."""
    p = stance()
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.34, 1), (0.58, -0.3), (0.8, 0.1), (1, 0)])
    p.move("Root", y=0.12 * snap)
    p.move("Hips", z=-0.05 * snap, x=0.03 * snap)
    p.add("Hips", x=-8 * snap, y=8 * snap, z=10 * snap)
    p.lift("Spine", -8 * snap).turn("Spine", -14 * snap)
    p.lift("Neck", 30 * whip).turn("Neck", 26 * whip)
    p.lift("Head", -10 * whip).turn("Head", 20 * whip).roll("Head", 24 * whip)
    jaw(p, 34 * snap)
    p.ears(fwd_l=-44 * snap, fwd_r=-44 * snap, out=14 * snap)
    p.tail(up=-34 * snap, tip_up=-40 * whip, tip_left=20 * whip)
    p.leg("FrontL", upper=-24 * snap, lower=-10 * snap)
    p.leg("FrontR", upper=14 * snap, lower=-30 * snap, paw=-20 * snap)
    p.leg("BackL", upper=18 * snap, lower=-24 * snap)
    p.leg("BackR", upper=20 * snap, lower=-28 * snap)
    return p


def death(t):
    """Гибель (1.2 сек): пошатнулся, передние лапы подломились, завалился на бок; лапы и хвост дёргаются напоследок."""
    p = WolfPose({}, {})
    K = [0.0, 0.2, 0.42, 0.66, 1.0]   # стойка, отшатнулся, осел на грудь, на боку, затих

    def tr(vals):
        return track(t, list(zip(K, vals)))

    side = track(t, [(0, 0), (K[2], 8), (K[3], 88), (K[3] + 0.07, 82), (K[3] + 0.14, 88), (1, 88)])
    p.set("Root", 0, side, 0)                       # валится на бок
    p.move("Root", y=tr([0, 0.1, 0.12, 0.12, 0.12]), z=tr([0, 0, 0, 0.13, 0.13]), x=tr([0, 0, 0, -0.1, -0.1]))
    p.move("Hips", z=tr([-0.03, 0.0, -0.16, -0.32, -0.32]))
    p.add("Hips", x=tr([7, -6, 20, 2, 0]))
    p.lift("Spine", tr([3, -6, 8, 0, 0]))
    p.lift("Neck", tr([-26, 20, -34, -14, -20])).turn("Neck", tr([0, -20, 14, 6, 0]))
    p.lift("Head", tr([18, -10, 24, 4, 8])).roll("Head", tr([0, -16, 10, 0, 0]))
    jaw(p, tr([8, 36, 12, 26, 18]))
    spasm = pulse(t, 0.85, 0.05)
    p.leg("FrontL", upper=tr([22, -20, 70, 30, 24]), lower=tr([-30, -20, -120, -46, -30]), paw=tr([10, 0, 50, 30, 30]))
    p.leg("FrontR", upper=tr([-16, 20, 60, 10, 6]) + 14 * spasm, lower=tr([-22, -40, -116, -50, -34]) - 24 * spasm, paw=tr([30, 0, 50, 30, 30]))
    p.leg("BackL", upper=tr([-14, 10, -10, -30, -24]), lower=tr([6, -20, -30, 10, 6]), paw=tr([2, 0, 10, -20, -20]))
    p.leg("BackR", upper=tr([10, 26, 20, -6, -12]) + 18 * spasm, lower=tr([-4, -30, -40, -10, 0]) - 20 * spasm, paw=tr([-12, 0, 10, -20, -20]))
    ear = tr([10, -40, -20, -36, -30])
    p.ears(fwd_l=ear, fwd_r=ear + 16 * spasm)
    p.tail(up=tr([-10, 30, -20, -6, -14]), tip_up=tr([-8, 20, -30, 10, -10]) + 14 * spasm, tip_left=tr([0, 20, -20, 10, 0]))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 16, walk, cyclic=True)
    k.bake(rig, "Attack", 24, attack)
    k.bake(rig, "Hit", 14, hit)
    k.bake(rig, "Death", 36, death)


# ---------- Сборка и экспорт ----------

def build(glb_path, blend_path=None):
    k.start_scene(NAME)
    body = build_mesh()
    rig = k.build_armature(NAME, BONES)
    body.parent = rig
    build_actions(rig)
    k.export(rig, body, glb_path, blend_path)
    return rig, body


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    glb = args[0] if args else os.path.join(here, "..", "wolf.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "wolf.blend")
    build(glb, blend)
