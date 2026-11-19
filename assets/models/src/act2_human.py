# Общее тело людей акта 2 (Старатель, Огнеход, мародёры): скелет, базовая фигура, анимации.
# Каждый персонаж — свой скрипт build_*.py: материалы, одежда и предметы поверх этого тела,
# плюс стиль удара (swing — замах сверху, thrust — тычок шестом, aim — выстрел, throw — бросок).
# Смотрит в -Y, правая рука на -X. Рост задаётся H (метры), все точки масштабируются от 1.7 м.
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

SIDES = (("R", -1), ("L", 1))


class Body:
    def __init__(self, height=1.7, hunch=0.0):
        self.s = height / 1.7
        self.hunch = hunch   # сутулость в градусах (добавляется к спине и груди)

    def p(self, x, y, z):
        s = self.s
        return (x * s, y * s, z * s)

    # Ключевые точки
    @property
    def hand_r(self):
        return self.p(-0.26, -0.08, 0.84)

    @property
    def hand_l(self):
        return self.p(0.26, -0.08, 0.84)

    def bones(self, extra=None):
        p = self.p
        b = {
            "Root": ((0, 0, 0), p(0, 0, 0.15), None),
            "Hips": (p(0, 0, 0.9), p(0, 0, 1.0), "Root"),
            "Spine": (p(0, 0, 1.0), p(0, 0, 1.18), "Hips"),
            "Chest": (p(0, 0, 1.18), p(0, 0, 1.42), "Spine"),
            "Head": (p(0, 0, 1.42), p(0, 0, 1.74), "Chest"),
            "ClothF": (p(0, -0.14, 0.92), p(0, -0.16, 0.5), "Hips"),
            "ClothB": (p(0, 0.14, 0.92), p(0, 0.16, 0.5), "Hips"),
            "Weapon": (self.hand_r, p(-0.26, -0.3, 0.84), "Hand.R"),
            "Prop": (self.hand_l, p(0.26, -0.3, 0.84), "Hand.L"),
        }
        for side, sg in SIDES:
            b.update({
                f"UpperArm.{side}": (p(0.2 * sg, 0, 1.38), p(0.24 * sg, 0, 1.12), "Chest"),
                f"ForeArm.{side}": (p(0.24 * sg, 0, 1.12), p(0.26 * sg, -0.05, 0.9), f"UpperArm.{side}"),
                f"Hand.{side}": (p(0.26 * sg, -0.05, 0.9), p(0.26 * sg, -0.1, 0.78), f"ForeArm.{side}"),
                f"Thigh.{side}": (p(0.1 * sg, 0, 0.9), p(0.11 * sg, -0.02, 0.5), "Hips"),
                f"Shin.{side}": (p(0.11 * sg, -0.02, 0.5), p(0.11 * sg, 0, 0.1), f"Thigh.{side}"),
                f"Foot.{side}": (p(0.11 * sg, 0, 0.1), p(0.11 * sg, -0.16, 0.03), f"Shin.{side}"),
            })
        if extra:
            b.update(extra)
        return b

    def figure(self, skin, cloth, cloth2, boots, robe=False, sleeves=None, head=True):
        """Базовая фигура: торс, руки, кисти, ноги (штаны или ряса), обувь, голова (если head)."""
        p = self.p
        sl = sleeves or cloth
        k.barrel("Pelvis", 0.15 * self.s, 0.16 * self.s, p(0, 0, 0.86)[2], p(0, 0, 1.0)[2], cloth2, "Hips", segs=8, sy=0.75)
        k.barrel("Waist", 0.15 * self.s, 0.17 * self.s, p(0, 0, 1.0)[2], p(0, 0, 1.18)[2], cloth, "Spine", segs=8, sy=0.72)
        k.barrel("Torso", 0.17 * self.s, 0.2 * self.s, p(0, 0, 1.18)[2], p(0, 0, 1.4)[2], cloth, "Chest", segs=8, sy=0.7)
        k.sphere("Shoulders", 0.2 * self.s, p(0, 0, 1.38), cloth, "Chest", scale=(1.05, 0.7, 0.45), segs=8, rings=4)
        k.limb("Neck", p(0, 0, 1.4), p(0, -0.01, 1.48), 0.05 * self.s, 0.05 * self.s, skin, "Head", segs=6)
        if head:
            k.sphere("Head", 0.11 * self.s, p(0, -0.02, 1.58), skin, "Head", scale=(0.9, 1.0, 1.1), segs=8, rings=5)
        for side, sg in SIDES:
            k.limb(f"UpperArm.{side}", p(0.2 * sg, 0, 1.38), p(0.24 * sg, 0, 1.12), 0.055 * self.s, 0.045 * self.s, sl,
                   f"UpperArm.{side}", segs=6)
            k.limb(f"ForeArm.{side}", p(0.24 * sg, 0, 1.12), p(0.26 * sg, -0.05, 0.9), 0.045 * self.s, 0.038 * self.s, sl,
                   f"ForeArm.{side}", segs=6)
            k.sphere(f"Hand.{side}", 0.045 * self.s, p(0.26 * sg, -0.07, 0.86), skin, f"Hand.{side}", segs=6, rings=4)
            if robe:
                k.limb(f"Shin.{side}", p(0.11 * sg, -0.02, 0.4), p(0.11 * sg, 0, 0.1), 0.05 * self.s, 0.045 * self.s, cloth2,
                       f"Shin.{side}", segs=6)
            else:
                k.limb(f"Thigh.{side}", p(0.1 * sg, 0, 0.9), p(0.11 * sg, -0.02, 0.5), 0.075 * self.s, 0.06 * self.s, cloth2,
                       f"Thigh.{side}", segs=6)
                k.limb(f"Shin.{side}", p(0.11 * sg, -0.02, 0.5), p(0.11 * sg, 0, 0.12), 0.06 * self.s, 0.05 * self.s, cloth2,
                       f"Shin.{side}", segs=6)
            k.limb(f"Boot.{side}", p(0.11 * sg, 0, 0.22), p(0.11 * sg, 0, 0.06), 0.06 * self.s, 0.065 * self.s, boots,
                   f"Shin.{side}", segs=6)
            k.box(f"Foot.{side}", (0.11 * self.s, 0.22 * self.s, 0.07 * self.s), p(0.11 * sg, -0.05, 0.035), boots, f"Foot.{side}")
        if robe:
            # Ряса: юбка от пояса до голени, полы спереди и сзади на своих костях
            k.barrel("Skirt", 0.2 * self.s, 0.25 * self.s, p(0, 0, 0.52)[2], p(0, 0, 0.94)[2], cloth, "Hips", segs=8, sy=0.8)
            k.plate("ClothF", [(-0.15, 0), (0.15, 0), (0.13, -0.38), (0.0, -0.33), (-0.13, -0.4)], 0.025 * self.s,
                    p(0, -0.17, 0.9), (self.s, 0, 0), (0, -0.15 * self.s, 1 * self.s), cloth, "ClothF")
            k.plate("ClothB", [(-0.16, 0), (0.16, 0), (0.14, -0.4), (-0.02, -0.36), (-0.15, -0.38)], 0.025 * self.s,
                    p(0, 0.17, 0.9), (self.s, 0, 0), (0, 0.15 * self.s, 1 * self.s), cloth, "ClothB")


# ---------- Стойки и анимации по стилю удара ----------

STANCES = {
    # обе руки держат оружие перед собой, правая сверху
    "swing": {"UpperArm.R": (-30, 0, 10), "ForeArm.R": (-50, 0, 0), "Weapon": (60, 0, 0),
              "UpperArm.L": (-30, 0, -10), "ForeArm.L": (-50, 0, 0), "Prop": (60, 0, 0)},
    # длинный шест вперёд, обе руки на древке
    "thrust": {"UpperArm.R": (-20, 0, 10), "ForeArm.R": (-50, 0, 0), "Weapon": (-55, 0, 0),
               "UpperArm.L": (-50, 0, -20), "ForeArm.L": (-30, 0, 0)},
    # самострел у плеча, целится
    "aim": {"UpperArm.R": (-50, 0, 14), "ForeArm.R": (-50, 0, 0), "Weapon": (-78, 0, 0),
            "UpperArm.L": (-70, 0, -30), "ForeArm.L": (-30, 0, 0)},
    # бутыль в поднятой руке
    "throw": {"UpperArm.R": (-30, 0, 115), "ForeArm.R": (-80, 0, 0), "Weapon": (-60, 0, 0),
              "UpperArm.L": (-30, 0, -20), "ForeArm.L": (-40, 0, 0)},
}
LEGS = {"Thigh.L": (-14, 0, -4), "Shin.L": (16, 0, 0), "Foot.L": (-2, 0, 0),
        "Thigh.R": (8, 0, 6), "Shin.R": (12, 0, 0), "Foot.R": (-18, 0, 0)}


class Anim:
    def __init__(self, style, hunch=0.0, crouch=0.0, extra_stance=None):
        st = dict(LEGS)
        st.update(STANCES[style])
        st.update({"Hips": (2, -8, 0), "Spine": (6 + hunch * 0.5, -4, 0), "Chest": (6 + hunch * 0.5, -6, 0),
                   "Head": (-6 - hunch * 0.6, 8, 0), "ClothF": (-4, 0, 0), "ClothB": (4, 0, 0)})
        if crouch:
            st["Thigh.L"] = (-14 - 30 * crouch, 0, -4)
            st["Shin.L"] = (16 + 50 * crouch, 0, 0)
            st["Thigh.R"] = (8 - 30 * crouch, 0, 6)
            st["Shin.R"] = (12 + 50 * crouch, 0, 0)
        if extra_stance:
            st.update(extra_stance)
        self.style = style
        self.stance = st
        self.loc = {"Hips": (0, 0, -0.03 - 0.12 * crouch)}

    def base(self):
        return Pose(self.stance, self.loc)

    def cloth(self, p, fwd=0.0, side=0.0):
        p.add("ClothF", x=fwd, z=side)
        p.add("ClothB", x=fwd * 0.8, z=side)

    def idle(self, t):
        p = self.base()
        br = wave(t, 2)
        sway = wave(t, 1)
        p.move("Hips", x=0.012 * sway, z=-0.008 * (br * 0.5 + 0.5))
        p.add("Hips", z=2 * sway)
        p.add("Spine", x=1.5 * br)
        p.add("Chest", x=1.5 * wave(t, 2, -0.1))
        p.add("Head", y=k.track(t, [(0, 0), (0.2, 0), (0.26, -20), (0.5, -20), (0.56, 14), (0.8, 14), (0.86, 0), (1, 0)]),
              x=-2 * br)
        p.add("UpperArm.R", x=-2 * br)
        p.add("UpperArm.L", x=2 * wave(t, 1, 0.3))
        p.add("Weapon", x=4 * pulse(t, 0.4, 0.06))
        self.cloth(p, fwd=3 * wave(t, 1, -0.2))
        return p

    def walk(self, t):
        p = Pose(self.stance)
        a = wave(t, 1)
        c = wave(t, 1, 0.25)
        bob = wave(t, 2, 0.1)
        p.move("Hips", z=self.loc["Hips"][2] - 0.01 + 0.025 * bob, x=0.025 * a)
        p.add("Hips", y=6 * a)
        st = self.stance
        p.set("Thigh.R", st["Thigh.R"][0] - 26 * a, 0, 6)
        p.set("Thigh.L", st["Thigh.L"][0] + 26 * a, 0, -4)
        p.set("Shin.R", st["Shin.R"][0] + 30 * max(0.0, c), 0, 0)
        p.set("Shin.L", st["Shin.L"][0] + 30 * max(0.0, -c), 0, 0)
        p.add("Chest", y=-6 * a, x=2 * bob)
        p.add("Head", y=4 * a, x=-2 * bob)
        p.add("UpperArm.R", x=-6 * a)
        p.add("UpperArm.L", x=6 * a)
        self.cloth(p, fwd=-10 * abs(a))
        return p

    def attack(self, t):
        p = Pose({}, {})
        K = [0.0, 0.25, 0.4, 0.58, 1.0]
        st = self.stance
        if self.style == "swing":
            keys = [("Spine", (-10, 10, 0), (22, -8, 0), (20, -6, 0)), ("Chest", (-10, 10, 0), (16, -8, 0), (14, -6, 0)),
                    ("UpperArm.R", (-170, 0, 14), (-60, 0, 6), (-50, 0, 6)), ("ForeArm.R", (-30, 0, 0), (-10, 0, 0), (-14, 0, 0)),
                    ("UpperArm.L", (-170, 0, -14), (-60, 0, -6), (-50, 0, -6)), ("ForeArm.L", (-30, 0, 0), (-10, 0, 0), (-14, 0, 0)),
                    ("Weapon", (80, 0, 0), (20, 0, 0), (10, 0, 0)), ("Prop", (80, 0, 0), (20, 0, 0), (10, 0, 0))]
        elif self.style == "thrust":
            keys = [("Spine", (-4, 16, 0), (14, -10, 0), (12, -8, 0)), ("Chest", (-4, 14, 0), (10, -12, 0), (8, -10, 0)),
                    ("UpperArm.R", (0, 0, 14), (-70, 0, 6), (-60, 0, 6)), ("ForeArm.R", (-80, 0, 0), (-6, 0, 0), (-10, 0, 0)),
                    ("UpperArm.L", (-30, 0, -20), (-80, 0, -10), (-74, 0, -10)), ("ForeArm.L", (-60, 0, 0), (-10, 0, 0), (-14, 0, 0)),
                    ("Weapon", (-40, 0, 0), (-8, 0, 0), (-12, 0, 0))]
        elif self.style == "aim":
            keys = [("Chest", (6, 0, 0), (-10, 4, 0), (-6, 2, 0)), ("Head", (-6, 8, 0), (-14, 8, 0), (-10, 8, 0)),
                    ("UpperArm.R", (-60, 0, 14), (-40, 0, 16), (-46, 0, 14)), ("UpperArm.L", (-80, 0, -30), (-60, 0, -32), (-66, 0, -30)),
                    ("Weapon", (-76, 0, 0), (-64, 0, 0), (-70, 0, 0))]
        else:   # throw
            keys = [("Spine", (-14, 20, 0), (16, -20, 0), (12, -14, 0)), ("Chest", (-10, 20, 0), (14, -16, 0), (10, -12, 0)),
                    ("UpperArm.R", (-150, 0, 40), (-90, 0, 10), (-40, 0, 4)), ("ForeArm.R", (-80, 0, 0), (-10, 0, 0), (-30, 0, 0)),
                    ("Weapon", (-60, 0, 0), (0, 0, 0), (20, 0, 0)),
                    ("UpperArm.L", (-60, 0, -30), (-10, 0, -20), (0, 0, -14))]
        for bone, *kk in keys:
            a2.keyed(p, t, K, st, bone, *kk)
        for bone in st:
            if bone not in p.rot:
                p.set(bone, *st[bone])
        lunge = 0.1 if self.style in ("swing", "thrust") else 0.03
        p.move("Root", y=track(t, [(0, 0), (K[1], 0.04), (K[2], -lunge), (K[3], -lunge * 0.8), (1, 0)]))
        p.move("Hips", z=self.loc["Hips"][2] + track(t, [(0, 0), (K[2], -0.05), (1, 0)]))
        self.cloth(p, fwd=track(t, [(0, 0), (K[1], 8), (K[2], -14), (1, 0)]))
        return p

    def hit(self, t):
        p = self.base()
        snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
        whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.3), (1, 0)])
        p.move("Root", y=0.07 * snap)
        p.add("Spine", x=-14 * snap, y=8 * snap)
        p.add("Chest", x=-8 * whip)
        p.add("Head", x=-22 * whip, z=8 * whip)
        p.add("UpperArm.R", x=16 * whip, z=10 * whip)
        p.add("UpperArm.L", x=18 * whip, z=-14 * whip)
        p.add("Thigh.R", x=-8 * snap)
        self.cloth(p, fwd=14 * whip)
        return p

    def death(self, t):
        p = Pose({}, {})
        K = [0.0, 0.2, 0.45, 0.72, 1.0]
        for bone, *kk in [
            ("Spine", (-14, 10, 0), (20, 0, 0), (28, 0, 0), (26, 0, 0)),
            ("Chest", (-10, 6, 0), (16, 0, 0), (18, 0, 0), (16, 0, 0)),
            ("Head", (-30, -20, 0), (10, 10, 0), (-30, 30, 0), (-24, 36, 0)),
            ("UpperArm.R", (10, 0, 40), (10, 0, 20), (-150, 0, 30), (-160, 0, 34)),
            ("UpperArm.L", (10, 0, -40), (16, 0, -20), (-140, 0, -30), (-150, 0, -34)),
            ("ForeArm.R", (-40, 0, 0), (-20, 0, 0), (-16, 0, 0), (-10, 0, 0)),
            ("ForeArm.L", (-40, 0, 0), (-30, 0, 0), (-20, 0, 0), (-10, 0, 0)),
            ("Weapon", (40, 0, 0), (-40, 0, 30), (-60, 0, 50), (-60, 0, 50)),
            ("Thigh.L", (-10, 0, -8), (-80, 0, -10), (-30, 0, -10), (-20, 0, -10)),
            ("Shin.L", (20, 0, 0), (110, 0, 0), (40, 0, 0), (20, 0, 0)),
            ("Thigh.R", (-20, 0, 10), (-80, 0, 12), (-30, 0, 12), (-20, 0, 12)),
            ("Shin.R", (24, 0, 0), (110, 0, 0), (40, 0, 0), (20, 0, 0)),
            ("Foot.L", (0, 0, 0), (40, 0, 0), (40, 0, 0), (40, 0, 0)),
            ("Foot.R", (0, 0, 0), (40, 0, 0), (40, 0, 0), (40, 0, 0)),
            ("ClothF", (-20, 0, 0), (-40, 0, 0), (-10, 0, 0), (-10, 0, 0)),
            ("ClothB", (10, 0, 0), (40, 0, 0), (50, 0, 0), (50, 0, 0)),
        ]:
            a2.keyed_end(p, t, K, self.stance, bone, *kk)
        fall = track(t, [(0, 0), (K[1], -6), (K[2], 8), (K[3], 84), (K[3] + 0.06, 78), (K[3] + 0.12, 86), (1, 86)])
        p.set("Root", fall, 0, 0)
        p.move("Root", y=track(t, [(0, 0), (K[1], 0.06), (K[2], -0.05), (K[3], -0.2), (1, -0.2)]),
               z=track(t, [(0, 0), (K[2], 0), (K[3], 0.22), (1, 0.22)]))
        p.move("Hips", z=track(t, [(0, self.loc["Hips"][2]), (K[1], -0.02), (K[2], -0.45), (K[3], -0.12), (1, -0.12)]))
        p.add("ForeArm.L", x=-26 * pulse(t, 0.88, 0.05))
        return p

    def bake_all(self, rig, scale_bones=(), extra=None):
        k.bake(rig, "Idle", 90, self.idle, cyclic=True, scale_bones=scale_bones)
        k.bake(rig, "Walk", 24, self.walk, cyclic=True, scale_bones=scale_bones)
        k.bake(rig, "Attack", 24, self.attack, scale_bones=scale_bones)
        k.bake(rig, "Hit", 14, self.hit, scale_bones=scale_bones)
        k.bake(rig, "Death", 39, self.death, scale_bones=scale_bones)
        for name, frames, fn in (extra or []):
            k.bake(rig, name, frames, fn, scale_bones=scale_bones)
