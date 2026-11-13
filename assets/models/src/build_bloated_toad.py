# Раздутая жаба — тварь Раскола (~0.8 м в высоту, шириной почти с клетку). Низкое шарообразное тело,
# огромный горловой мешок, широкие лапы, гранёные кристаллы-бородавки на спине.
# Оливковая спина, салатовое горло с бирюзовыми прожилками Раскола, бирюзовые глаза. Смотрит в -Y.
#
# Запуск: python3 build_bloated_toad.py out.glb out.blend (нужен модуль bpy)
# или в Blender: Scripting → Open → Run Script. Рядом должен лежать char_kit.py.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse

NAME = "BloatedToad"
SIDES = (("R", -1), ("L", 1))
SCALED = ("Body", "Sac", "Tongue")   # кости, у которых в анимациях меняется размер


def build_mesh():
    back = k.mat("Toad_Back", (0.38, 0.44, 0.30), rough=0.8)             # болотно-оливковая спина
    dark = k.mat("Toad_Dark", (0.26, 0.31, 0.21), rough=0.85)
    throat = k.mat("Toad_Throat", (0.60, 0.66, 0.46), rough=0.6)         # бледное оливковое горло
    mouth = k.mat("Toad_Mouth", (0.20, 0.13, 0.17), rough=0.7)
    tongue = k.mat("Toad_Tongue", (0.58, 0.64, 0.54), rough=0.5)         # бледно-серо-зелёный язык (лиловый — цвет Мага)
    wart = k.mat("Toad_Wart", (0.20, 0.50, 0.50), rough=0.35, emit=0.25) # кристаллы Раскола на спине
    rift = k.mat("Toad_Rift", (0.25, 0.85, 0.75), rough=0.4, emit=1.2)

    # Тело: сплюснутый шар; сзади бугор, спереди широкая голова без шеи
    k.sphere("Body", 0.36, (0, 0.06, 0.36), back, "Body", scale=(1.14, 1.12, 0.84), segs=10, rings=6)
    k.sphere("Rump", 0.25, (0, 0.27, 0.30), dark, "Body", scale=(1.25, 0.9, 0.8), segs=8, rings=4)
    k.sphere("Belly", 0.30, (0, 0.04, 0.24), throat, "Body", scale=(1.15, 1.15, 0.6), segs=8, rings=4)
    k.sphere("HeadTop", 0.25, (0, -0.24, 0.47), back, "Head", scale=(1.3, 1.0, 0.56), segs=9, rings=5)
    k.box("UpperLip", (0.52, 0.2, 0.05), (0, -0.33, 0.405), dark, "Head", rot=(-6, 0, 0))
    k.box("MouthRoof", (0.44, 0.24, 0.02), (0, -0.30, 0.385), mouth, "Head")
    # Глаза навыкате: тёмные бугры и светящиеся щели зрачков
    for side, s in SIDES:
        k.sphere(f"EyeBulge.{side}", 0.085, (0.17 * s, -0.27, 0.60), dark, "Head", segs=7, rings=4)
        k.sphere(f"Eye.{side}", 0.06, (0.185 * s, -0.315, 0.61), rift, "Head", scale=(0.9, 0.8, 0.5), segs=6, rings=3)
    # Нижняя челюсть (своя кость): широкая «лопата»
    k.box("Jaw", (0.50, 0.28, 0.06), (0, -0.30, 0.355), dark, "Jaw", rot=(4, 0, 0))
    k.box("JawInside", (0.42, 0.22, 0.02), (0, -0.29, 0.387), mouth, "Jaw")
    # Горловой мешок (кость Sac — раздувается): большой светлый шар под челюстью с прожилками
    k.sphere("Sac", 0.205, (0, -0.29, 0.215), throat, "Sac", scale=(1.15, 1.0, 0.95), segs=9, rings=5)
    k.crack("SacVeinA", [(-0.12, 0.05), (-0.06, 0.0), (-0.09, -0.06), (-0.03, -0.11)], (0, -0.488, 0.22),
            (1, 0, 0), (0, 0, 1), rift, "Sac", width=0.016, depth=0.035)
    k.crack("SacVeinB", [(0.02, 0.09), (0.07, 0.03), (0.04, -0.03), (0.11, -0.08)], (0, -0.487, 0.22),
            (1, 0, 0), (0, 0, 1), rift, "Sac", width=0.016, depth=0.035)
    k.crack("SacVeinC", [(0.0, 0.07), (0.04, 0.01), (0.0, -0.06)], (0.225, -0.33, 0.21),
            (0, 1, 0), (0, 0, 1), rift, "Sac", width=0.014, depth=0.03)
    # Язык (кость Tongue смотрит вперёд): в покое сжат до пары сантиметров и спрятан во рту
    k.limb("Tongue", (0, -0.24, 0.37), (0, -1.20, 0.37), 0.045, 0.03, tongue, "Tongue", segs=5)
    k.sphere("TongueTip", 0.075, (0, -1.24, 0.37), tongue, "Tongue", scale=(1.2, 1.0, 0.7), segs=6, rings=3)

    # Кристаллы-бородавки на спине и боках
    warts = [(-0.16, 0.02, 0.64, 0.10, (-0.3, 0.0, 1)), (0.12, 0.10, 0.66, 0.13, (0.2, 0.1, 1)),
             (0.0, 0.26, 0.58, 0.09, (0.0, 0.5, 1)), (-0.27, 0.20, 0.50, 0.09, (-0.8, 0.3, 0.8)),
             (0.30, 0.22, 0.47, 0.10, (0.9, 0.3, 0.7)), (0.22, -0.08, 0.60, 0.07, (0.5, -0.2, 1)),
             (-0.08, 0.38, 0.44, 0.08, (-0.2, 1.0, 0.6)), (-0.33, -0.02, 0.46, 0.07, (-1, -0.1, 0.6))]
    for i, (x, y, z, ln, d) in enumerate(warts):
        k.limb(f"Wart{i}", (x, y, z - 0.03), (x + d[0] * ln, y + d[1] * ln, z - 0.03 + d[2] * ln), 0.045, 0.004, wart, "Body", segs=4)

    for side, s in SIDES:
        # Передние лапы: короткие, косолапые, с растопыренными пальцами
        k.limb(f"FrontLeg.{side}", (0.27 * s, -0.16, 0.27), (0.35 * s, -0.27, 0.07), 0.075, 0.05, back, f"FrontLeg.{side}")
        k.sphere(f"FrontFoot.{side}", 0.06, (0.35 * s, -0.29, 0.035), dark, f"FrontFoot.{side}", scale=(1.2, 1.2, 0.5), segs=6, rings=3)
        for i in (-1, 0, 1):
            k.limb(f"FrontToe.{side}{i}", (0.35 * s + 0.03 * i, -0.31, 0.03), (0.35 * s + 0.07 * i, -0.42, 0.012), 0.025, 0.012,
                   dark, f"FrontFoot.{side}", segs=3)
        # Задние лапы: толстое бедро вперёд-вбок, голень назад, длинная ступня
        k.limb(f"HindThigh.{side}", (0.26 * s, 0.24, 0.25), (0.41 * s, 0.02, 0.19), 0.12, 0.085, back, f"HindThigh.{side}")
        k.sphere(f"HindKnee.{side}", 0.085, (0.41 * s, 0.02, 0.19), dark, f"HindShin.{side}", segs=6, rings=4)
        k.limb(f"HindShin.{side}", (0.41 * s, 0.02, 0.19), (0.40 * s, 0.26, 0.07), 0.075, 0.05, back, f"HindShin.{side}")
        k.box(f"HindFoot.{side}", (0.11, 0.26, 0.04), (0.42 * s, 0.14, 0.022), dark, f"HindFoot.{side}", rot=(0, 0, -8 * s))
        for i in (-1, 1):
            k.limb(f"HindToe.{side}{i}", (0.42 * s + 0.03 * i, 0.03, 0.022), (0.44 * s + 0.06 * i, -0.08, 0.012), 0.024, 0.01,
                   dark, f"HindFoot.{side}", segs=3)
    return k.join_parts("BloatedToadMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.15), None),
    "Body": ((0, 0.06, 0.20), (0, 0.06, 0.50), "Root"),
    "Head": ((0, -0.14, 0.40), (0, -0.14, 0.64), "Body"),
    "Jaw": ((0, -0.17, 0.37), (0, -0.44, 0.35), "Head"),
    "Sac": ((0, -0.24, 0.33), (0, -0.30, 0.10), "Body"),
    "Tongue": ((0, -0.24, 0.37), (0, -0.48, 0.37), "Head"),
}
for side, s in SIDES:
    BONES.update({
        f"FrontLeg.{side}": ((0.27 * s, -0.16, 0.27), (0.35 * s, -0.27, 0.07), "Body"),
        f"FrontFoot.{side}": ((0.35 * s, -0.27, 0.07), (0.35 * s, -0.40, 0.02), f"FrontLeg.{side}"),
        f"HindThigh.{side}": ((0.26 * s, 0.24, 0.25), (0.41 * s, 0.02, 0.19), "Body"),
        f"HindShin.{side}": ((0.41 * s, 0.02, 0.19), (0.40 * s, 0.26, 0.07), f"HindThigh.{side}"),
        f"HindFoot.{side}": ((0.40 * s, 0.26, 0.07), (0.44 * s, 0.0, 0.02), f"HindShin.{side}"),
    })

TONGUE_IN = (1.0, 0.03, 1.0)   # язык втянут: вдоль кости (Y) почти нулевой
STANCE = {"Body": (-6, 0, 0), "Head": (-4, 8, 0), "Jaw": (0, 0, 0)}


def base(sac=1.0, tongue=TONGUE_IN, body=(1.0, 1.0, 1.0)):
    p = Pose(STANCE)
    p.size("Sac", sac)
    p.size("Tongue", *tongue)
    p.size("Body", *body)
    return p


def plant(p, lift):
    """Тело поднялось/опустилось на lift метров — лапы тянутся или поджимаются, чтобы ступни остались на земле."""
    for side in ("R", "L"):
        p.add(f"FrontLeg.{side}", x=-70 * lift)
        p.add(f"FrontFoot.{side}", x=70 * lift)
        p.add(f"HindThigh.{side}", x=60 * lift)
        p.add(f"HindShin.{side}", x=-110 * lift)
        p.add(f"HindFoot.{side}", x=50 * lift)


def idle(t):
    """Покой (3.3 сек): медленно надувает мешок и с хлопком сдувает (кваканье), дышит боками, косится, переступает лапой."""
    swell = track(t, [(0, 1.0), (0.42, 1.38), (0.5, 1.42), (0.56, 0.96), (0.62, 1.06), (0.7, 1.0), (1, 1.0)])
    breath = wave(t, 3)
    p = base(sac=swell, body=(1 + 0.02 * breath, 1 - 0.015 * breath, 1 + 0.02 * breath))
    croak = pulse(t, 0.55, 0.06)
    p.move("Body", z=0.012 * (swell - 1) * 2 - 0.02 * croak)
    p.add("Body", x=-4 * (swell - 1) * 2 + 5 * croak)
    plant(p, 0.012 * (swell - 1) * 2 - 0.02 * croak)
    yaw = track(t, [(0, 0), (0.12, 0), (0.17, -16), (0.36, -16), (0.62, 0), (0.78, 14), (0.84, 14), (0.95, 0), (1, 0)])
    p.add("Head", x=3 * croak, y=yaw, z=yaw * 0.2)
    p.add("Jaw", x=10 * croak + 2 * (breath * 0.5 + 0.5))
    step = pulse(t, 0.8, 0.07)   # переставляет переднюю лапу
    p.add("FrontLeg.L", x=-22 * step, z=-8 * step)
    p.add("FrontFoot.L", x=24 * step)
    p.add("HindFoot.R", z=10 * pulse(t, 0.3, 0.06))
    return p


def walk(t):
    """Прыжок (0.4 сек): присела → толчок задними лапами → летит, вытянувшись → плюхается и сплющивается."""
    up = track(t, [(0, -0.05), (0.2, -0.09), (0.45, 0.20), (0.62, 0.22), (0.85, -0.02), (0.92, -0.08), (1, -0.05)])
    pitch = track(t, [(0, -4), (0.2, 4), (0.45, -22), (0.62, -6), (0.85, 12), (1, -4)])
    squash = track(t, [(0, 1.0), (0.2, 0.9), (0.45, 1.12), (0.7, 1.05), (0.9, 0.84), (1, 1.0)])
    p = base(sac=1.0 + 0.2 * pulse(t, 0.9, 0.12), body=(2 - squash, 1.0, squash))
    p.move("Body", z=up)
    p.add("Body", x=pitch)
    kick = track(t, [(0, 0), (0.2, -0.3), (0.45, 1), (0.7, 0.5), (0.9, -0.2), (1, 0)])   # задние лапы выпрямляются назад
    tuck = track(t, [(0, 0), (0.2, 0.2), (0.45, -0.6), (0.7, 1), (0.9, 0.1), (1, 0)])    # передние тянутся вперёд к земле
    for side in ("R", "L"):
        p.add(f"HindThigh.{side}", x=70 * kick)
        p.add(f"HindShin.{side}", x=-100 * kick)
        p.add(f"HindFoot.{side}", x=60 * kick)
        p.add(f"FrontLeg.{side}", x=-46 * tuck + 20 * kick)
        p.add(f"FrontFoot.{side}", x=30 * tuck)
    p.add("Head", x=-pitch * 0.4)
    p.add("Jaw", x=8 * pulse(t, 0.9, 0.1))
    return p


def attack(t):
    """Хлёсткий язык (0.87 сек): откидывается и раздувается → пасть настежь, язык выстреливает (к 0.4 сек) → втягивает, мешок опадает."""
    K = [0.0, 0.22, 0.36, 0.46, 0.64, 1.0]
    sac = track(t, [(0, 1.0), (K[1], 1.5), (K[2], 1.55), (K[3], 0.9), (K[4], 0.95), (1, 1.0)])
    reach = track(t, [(0, 0.03), (K[2], 0.03), (K[3], 1.45), (K[3] + 0.06, 1.5), (K[4] + 0.06, 0.03), (1, 0.03)])
    p = base(sac=sac, tongue=(1.0, reach, 1.0))
    lean = track(t, [(0, 0), (K[1], -16), (K[2], -20), (K[3], 16), (K[4], 10), (1, 0)])
    p.add("Body", x=lean)
    p.move("Body", y=track(t, [(0, 0), (K[1], 0.07), (K[2], 0.09), (K[3], -0.14), (K[4], -0.10), (1, 0)]),
           z=track(t, [(0, 0), (K[1], 0.03), (K[3], -0.03), (1, 0)]))
    p.add("Head", x=track(t, [(0, 0), (K[1], -10), (K[2], -24), (K[3], -16), (K[4], -4), (1, 0)]), y=-8 * k.smooth(t / K[1]) * (1 - k.smooth((t - K[4]) / (1 - K[4]))))
    p.add("Jaw", x=track(t, [(0, 0), (K[1], 4), (K[2], 34), (K[3], 46), (K[4] + 0.06, 30), (K[4] + 0.14, -2), (1, 0)]))
    brace = track(t, [(0, 0), (K[1], -1), (K[2], -1.2), (K[3], 1), (K[4], 0.6), (1, 0)])
    for side in ("R", "L"):
        p.add(f"FrontLeg.{side}", x=16 * brace)
        p.add(f"FrontFoot.{side}", x=-14 * brace)
        p.add(f"HindThigh.{side}", x=-10 * brace)
        p.add(f"HindShin.{side}", x=16 * brace)
    return p


def hit(t):
    """Получила удар (0.47 сек): сплющивается и отъезжает назад, мешок колышется, пасть хлопает."""
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.35), (1, 0)])
    wob = track(t, [(0, 0), (0.18, -0.3), (0.34, 1), (0.55, -0.5), (0.78, 0.2), (1, 0)])
    p = base(sac=1.0 + 0.3 * wob, body=(1 + 0.12 * snap, 1.0, 1 - 0.16 * snap))
    p.move("Root", y=0.10 * snap)
    p.move("Body", z=-0.04 * snap)
    plant(p, -0.04 * snap)
    p.add("Body", x=-14 * snap, z=6 * wob)
    p.add("Head", x=-12 * wob, y=-14 * snap)
    p.add("Jaw", x=26 * snap)
    for side, s in SIDES:
        p.add(f"FrontLeg.{side}", z=-14 * s * snap)
    return p


def death(t):
    """Гибель (1.2 сек): раздувается до предела → хлопок: мешок лопается, тело оседает лепёшкой, лапы разъезжаются, одна дёргается."""
    K = [0.0, 0.3, 0.42, 0.5, 0.72, 1.0]
    sac = track(t, [(0, 1.0), (K[1], 1.7), (K[2], 1.95), (K[3], 0.12), (1, 0.1)])
    bw = track(t, [(0, 1.0), (K[1], 1.1), (K[2], 1.18), (K[3], 1.0), (K[4], 1.2), (1, 1.22)])
    bz = track(t, [(0, 1.0), (K[1], 1.12), (K[2], 1.2), (K[3], 0.9), (K[4], 0.5), (1, 0.46)])
    p = base(sac=sac, body=(bw, bw, bz))
    p.move("Body", z=track(t, [(0, 0), (K[2], 0.07), (K[3], 0.02), (K[4], -0.07), (1, -0.08)]))
    p.add("Body", x=track(t, [(0, 0), (K[2], -18), (K[3], 6), (K[4], 10), (1, 10)]),
          z=track(t, [(0, 0), (K[3], 0), (K[4], 10), (1, 12)]))
    p.add("Head", x=track(t, [(0, 0), (K[2], -20), (K[3], 10), (K[4], 22), (1, 24)]), y=track(t, [(0, 0), (K[4], 20), (1, 24)]))
    p.add("Jaw", x=track(t, [(0, 0), (K[2], 6), (K[3], 50), (K[4], 34), (1, 30)]))
    p.size("Tongue", 1.0, track(t, [(0, 0.03), (K[3], 0.03), (K[4], 0.3), (1, 0.32)]), 1.0)   # язык вываливается
    splay = track(t, [(0, 0), (K[2], -0.3), (K[3], 0.2), (K[4], 1), (1, 1)])
    spasm = pulse(t, 0.88, 0.05)
    for side, s in SIDES:
        p.add(f"FrontLeg.{side}", x=20 * splay, z=-50 * s * splay)
        p.add(f"FrontFoot.{side}", x=-30 * splay)
        p.add(f"HindThigh.{side}", x=24 * splay, z=-16 * s * splay)
        p.add(f"HindShin.{side}", x=-40 * splay)
        p.add(f"HindFoot.{side}", x=20 * splay)
    p.add("HindShin.L", x=-24 * spasm)
    p.add("HindFoot.L", x=20 * spasm)
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 100, idle, cyclic=True, loc_bones=("Root", "Body"), scale_bones=SCALED)
    k.bake(rig, "Walk", 12, walk, cyclic=True, loc_bones=("Root", "Body"), scale_bones=SCALED)
    k.bake(rig, "Attack", 26, attack, loc_bones=("Root", "Body"), scale_bones=SCALED)
    k.bake(rig, "Hit", 14, hit, loc_bones=("Root", "Body"), scale_bones=SCALED)
    k.bake(rig, "Death", 36, death, loc_bones=("Root", "Body"), scale_bones=SCALED)


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
    glb = args[0] if args else os.path.join(here, "..", "bloated_toad.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "bloated_toad.blend")
    build(glb, blend)
