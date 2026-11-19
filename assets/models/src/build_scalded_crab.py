# Ошпаренный краб — тварь Кипящих ключей (акт 2, Тракт), ~0.8 м. Толстый куполообразный панцирь из мокрого
# серо-синего камня с коркой грязно-охристой серы, из трещин панциря валит пар, капает вода.
# Две неровные клешни (правая больше), шесть коротких каменных ног, глаза на стебельках, бирюзовые
# трещины по краю панциря. Не красный — это камень, а не варёный краб.
# Смотрит в -Y. Анимации: Idle, Walk, Attack (ошпаривает всё вокруг), Hit, Death.
# Запуск: python3 build_scalded_crab.py
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
import act2_kit as a2

LEGS = ((0, 0.24, -0.02), (1, 0.27, 0.12), (2, 0.24, 0.26))   # номер, x, y бедра (по стороне)
CLAWS = (("R", -1, 1.25), ("L", 1, 0.9))                       # правая клешня крупнее


def build_mesh():
    v = a2.volcano_mats()
    shell = k.mat("Crab_Shell", (0.38, 0.44, 0.50), rough=0.6)
    shell_d = k.mat("Crab_ShellDark", (0.27, 0.31, 0.36), rough=0.7)
    drip = k.mat("Crab_Drip", (0.55, 0.75, 0.92), rough=0.2, emit=0.3)
    # Панцирь-купол и брюхо
    k.sphere("Shell", 0.36, (0, 0.08, 0.36), shell, "Body", scale=(1.05, 1.0, 0.72), segs=9, rings=6)
    k.sphere("Belly", 0.3, (0, 0.06, 0.24), shell_d, "Body", scale=(1.0, 0.95, 0.45), segs=8, rings=4)
    k.box("Brow", (0.42, 0.1, 0.1), (0, -0.24, 0.36), shell_d, "Body", rot=(-14, 0, 0))
    # Корки серы
    for i, (x, y, z, r) in enumerate([(0.12, -0.02, 0.56, 0.09), (-0.16, 0.12, 0.55, 0.1), (0.2, 0.24, 0.47, 0.08),
                                      (-0.06, 0.3, 0.5, 0.07), (-0.26, -0.08, 0.43, 0.07)]):
        k.sphere(f"Sulfur{i}", r, (x, y, z), v["sulfur"], "Body", scale=(1.3, 1.1, 0.35), segs=6, rings=3)
    # Трещины Раскола по краю панциря
    for i, (pts, o) in enumerate([([(0, 0), (0.08, 0.03), (0.16, -0.01), (0.24, 0.02)], (-0.12, -0.27, 0.42)),
                                  ([(0, 0), (0.06, 0.04), (0.12, 0.0)], (0.2, -0.18, 0.44)),
                                  ([(0, 0), (0.1, 0.02), (0.18, -0.03)], (-0.3, 0.04, 0.42))]):
        k.crack(f"Rift{i}", pts, o, (1, 0, 0), (0, 0, 1), v["rift"], "Body", width=0.016, depth=0.02)
    # Пар из трещин (кость Steam) и капли
    for i, (x, y) in enumerate([(0.04, 0.0), (-0.14, 0.16), (0.16, 0.18)]):
        k.sphere(f"Steam{i}", 0.06 + 0.01 * i, (x, y, 0.7 + 0.04 * i), v["steam"], "Steam", segs=5, rings=3)
    for i, (x, y) in enumerate([(0.3, -0.04), (-0.32, 0.1), (0.1, -0.24)]):
        k.limb(f"Drip{i}", (x, y, 0.26), (x, y, 0.16), 0.018, 0.005, drip, "Body", segs=4)
    # Глаза на стебельках
    for side, s in (("R", -1), ("L", 1)):
        k.limb(f"Stalk.{side}", (0.08 * s, -0.24, 0.4), (0.1 * s, -0.28, 0.52), 0.02, 0.016, shell_d, f"Eye.{side}", segs=5)
        k.sphere(f"Eye.{side}", 0.03, (0.1 * s, -0.28, 0.54), v["rift"], f"Eye.{side}", segs=5, rings=3)
    # Клешни
    for side, s, sz in CLAWS:
        sh = (0.22 * s, -0.2, 0.3)
        el = (0.36 * s, -0.36, 0.3)
        k.limb(f"ClawArm.{side}", sh, el, 0.05 * sz, 0.05 * sz, shell_d, f"Claw.{side}", segs=6)
        k.sphere(f"ClawPalm.{side}", 0.09 * sz, (0.38 * s, -0.46, 0.32), shell, f"ClawHand.{side}",
                 scale=(0.8, 1.2, 0.75), segs=7, rings=4)
        k.plate(f"ClawFinger.{side}", [(0, 0), (0.05, -0.02), (0.07, -0.12), (0.03, -0.16), (0.0, -0.08)], 0.05 * sz,
                (0.38 * s, -0.54, 0.36), (0, 0, 1), (0, -1, 0), shell_d, f"Pincer.{side}")
        k.plate(f"ClawThumb.{side}", [(0, 0), (0.04, 0.0), (0.05, -0.1), (0.02, -0.12), (0.0, -0.06)], 0.045 * sz,
                (0.38 * s, -0.54, 0.26), (0, 0, -1), (0, -1, 0), v["sulfur"] if s < 0 else shell_d, f"ClawHand.{side}")
    # Шесть ног
    for side, s in (("R", -1), ("L", 1)):
        for i, x, y in LEGS:
            hip = (x * s, y, 0.26)
            kn = ((x + 0.14) * s, y + 0.02, 0.3)
            ft = ((x + 0.22) * s, y + 0.04, 0.02)
            k.limb(f"LegU{i}.{side}", hip, kn, 0.045, 0.04, shell_d, f"Coxa{i}.{side}", segs=6)
            k.limb(f"LegL{i}.{side}", kn, ft, 0.04, 0.012, shell, f"Knee{i}.{side}", segs=5)
    return k.join_parts("ScaldedCrabMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.12), None),
    "Body": ((0, 0.04, 0.2), (0, 0.04, 0.4), "Root"),
    "Steam": ((0, 0.1, 0.62), (0, 0.1, 0.9), "Body"),
}
for _side, _s in (("R", -1), ("L", 1)):
    BONES[f"Eye.{_side}"] = ((0.08 * _s, -0.24, 0.4), (0.1 * _s, -0.28, 0.54), "Body")
    for _i, _x, _y in LEGS:
        BONES[f"Coxa{_i}.{_side}"] = ((_x * _s, _y, 0.26), (_x * _s, _y, 0.36), "Body")
        BONES[f"Knee{_i}.{_side}"] = (((_x + 0.14) * _s, _y + 0.02, 0.3), ((_x + 0.14) * _s, _y + 0.02, 0.4), f"Coxa{_i}.{_side}")
for _side, _s, _ in CLAWS:
    BONES[f"Claw.{_side}"] = ((0.22 * _s, -0.2, 0.26), (0.22 * _s, -0.2, 0.36), "Body")
    BONES[f"ClawHand.{_side}"] = ((0.36 * _s, -0.4, 0.26), (0.36 * _s, -0.4, 0.36), f"Claw.{_side}")
    BONES[f"Pincer.{_side}"] = ((0.38 * _s, -0.54, 0.31), (0.38 * _s, -0.54, 0.41), f"ClawHand.{_side}")

STANCE = {"Body": (0, -8, 0)}
LOC_BONES = ("Root", "Body")
SCALED = ("Steam",)


class CrabPose(Pose):
    def leg(self, i, side, swing=0.0, lift=0.0):
        s = 1 if side == "L" else -1
        self.add(f"Coxa{i}.{side}", y=-swing * s, z=lift * s)
        self.add(f"Knee{i}.{side}", z=-lift * 0.6 * s)
        return self

    def claw(self, side, raise_=0.0, out=0.0, snap=0.0):
        s = 1 if side == "L" else -1
        self.add(f"Claw.{side}", x=-raise_, z=-out * s)
        self.add(f"ClawHand.{side}", x=-raise_ * 0.5)
        self.add(f"Pincer.{side}", x=snap)
        return self


def stance():
    p = CrabPose(STANCE)
    p.claw("R", raise_=14, snap=10).claw("L", raise_=10, snap=6)
    return p


def idle(t):
    """Покой (3 сек): клешни пощёлкивают, глаза-стебельки вертятся, пар валит толчками."""
    p = stance()
    p.move("Body", z=0.006 * wave(t, 2))
    p.claw("R", snap=18 * (pulse(t, 0.3, 0.04) + pulse(t, 0.38, 0.04)), raise_=4 * wave(t, 1))
    p.claw("L", snap=12 * pulse(t, 0.7, 0.05), raise_=3 * wave(t, 1, 0.4))
    p.add("Eye.R", z=12 * wave(t, 1, 0.1), x=6 * pulse(t, 0.55, 0.06))
    p.add("Eye.L", z=-12 * wave(t, 1, 0.3))
    p.size("Steam", 0.6 + 0.5 * pulse(t, 0.2, 0.12) + 0.6 * pulse(t, 0.65, 0.14))
    return p


def walk(t):
    """Боком-вперёд (0.7 сек): ноги волной, корпус покачивается, клешни перед собой."""
    p = stance()
    p.move("Body", z=0.012 * wave(t, 2))
    p.add("Body", z=4 * wave(t, 1))
    for side in ("R", "L"):
        for i, _, _ in LEGS:
            ph = wave(t, 1, i * 0.33 + (0.5 if side == "L" else 0))
            p.leg(i, side, swing=16 * ph, lift=10 * max(0.0, wave(t, 1, i * 0.33 + 0.25 + (0.5 if side == "L" else 0))))
    p.claw("R", raise_=4 * wave(t, 2))
    p.size("Steam", 0.7)
    return p


def attack(t):
    """Ошпаривает (0.9 сек): поднимается на ногах, клешни разведены → резко приседает (к 0.4 сек),
    из панциря вырывается пар во все стороны → возврат."""
    p = stance()
    up = track(t, [(0, 0), (0.25, 1), (0.4, -1), (0.6, -0.8), (1, 0)])
    p.move("Body", z=0.06 * up)
    for side in ("R", "L"):
        for i, _, _ in LEGS:
            p.leg(i, side, lift=-14 * up)
    out = track(t, [(0, 0), (0.25, 1), (0.4, 0.6), (1, 0)])
    p.claw("R", raise_=30 * out, out=30 * out, snap=30 * out)
    p.claw("L", raise_=24 * out, out=30 * out, snap=24 * out)
    p.size("Steam", track(t, [(0, 0.6), (0.35, 0.8), (0.45, 1.6), (0.65, 1.4), (1, 0.6)]))
    return p


def hit(t):
    """Получил удар (0.4 сек): панцирь отбрасывает, клешни прижимаются, глаза втягиваются."""
    p = stance()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.3), (1, 0)])
    p.move("Root", y=0.05 * snap)
    p.add("Body", x=-10 * snap, z=6 * snap)
    p.claw("R", raise_=-14 * snap, out=-10 * snap)
    p.claw("L", raise_=-10 * snap, out=-10 * snap)
    p.add("Eye.R", x=30 * snap)
    p.add("Eye.L", x=30 * snap)
    p.size("Steam", 0.6 + 0.8 * snap)
    return p


def death(t):
    """Гибель (1.1 сек): ноги подгибаются, панцирь падает и заваливается набок, пар стихает,
    в конце дёргается клешня."""
    p = stance()
    fall = track(t, [(0, 0), (0.35, 1), (1, 1)])
    tilt = track(t, [(0, 0), (0.3, 0), (0.6, 1), (0.7, 0.9), (1, 1)])
    p.move("Body", z=-0.16 * fall)
    p.add("Body", z=34 * tilt, x=8 * tilt)
    for side in ("R", "L"):
        for i, _, _ in LEGS:
            p.leg(i, side, lift=-24 * fall)
    p.claw("R", raise_=-30 * fall, out=20 * fall)
    p.claw("L", raise_=-30 * fall, out=20 * fall, snap=20 * pulse(t, 0.88, 0.05))
    p.add("Eye.R", x=50 * fall)
    p.add("Eye.L", x=50 * fall)
    p.size("Steam", track(t, [(0, 0.6), (0.3, 1.6), (0.7, 0.8), (1, 0.15)]))
    return p


def build(glb_path, blend_path=None):
    k.start_scene("ScaldedCrab")
    body = build_mesh()
    rig = k.build_armature("ScaldedCrab", BONES)
    body.parent = rig
    k.bake(rig, "Idle", 90, idle, cyclic=True, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Walk", 21, walk, cyclic=True, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Attack", 27, attack, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Hit", 12, hit, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.bake(rig, "Death", 33, death, loc_bones=LOC_BONES, scale_bones=SCALED)
    k.export(rig, body, glb_path, blend_path)


if __name__ == "__main__":
    a2.main(build, "scalded_crab")
