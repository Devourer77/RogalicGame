# Леший — уникальный дух Густых лесов (~1.7 м). Высокая сутулая фигура из перевитых стволов и корней:
# ноги-корни, длинные руки-ветви до колен, плечи и спина в мху и листве. Голова — тёмное дупло-лицо
# с двумя бледно-зелёными огнями глаз, над ней рога из ветвей с листьями. Без бирюзовых трещин
# (это знак Раскола), без кости и без красного (мир.md, раздел 3).
# Смотрит в -Y (после экспорта в glTF это +Z).
#
# Анимации: Idle (покачивается, как дерево на ветру; рога шелестят), Walk (широкий тяжёлый шаг корнями),
# Attack (хлёст ветвями сверху вниз), Hit, Death (покорён: пускает корни и замирает деревом, оседая).
# Запуск: python3 build_spirit_forest.py out/spirit_forest.glb out/spirit_forest.blend
import os
import sys
import math
import random

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "SpiritForest"
HIP_Z = 0.72
CHEST_Z = 1.2
HEAD_Z = 1.5


def strand(name, pts, r0, r1, material, bone, segs=5):
    """Ветвь или корень по точкам, толщина от r0 к r1."""
    n = len(pts) - 1
    for i in range(n):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        k.limb(f"{name}_{i}", pts[i], pts[i + 1], ra, rb, material, bone, segs=segs)


def build_mesh():
    rnd = random.Random(9)
    bark = k.mat("Forest_Bark", (0.33, 0.26, 0.19), rough=0.9)
    bark_d = k.mat("Forest_BarkDark", (0.22, 0.17, 0.12), rough=0.9)
    moss = k.mat("Forest_Moss", (0.17, 0.27, 0.13), rough=0.95)
    moss_l = k.mat("Forest_MossLight", (0.25, 0.36, 0.17), rough=0.95)
    leaf = k.mat("Forest_Leaf", (0.2, 0.33, 0.14), rough=0.8)
    hollow = k.mat("Forest_Hollow", (0.04, 0.05, 0.03), rough=1.0)
    eye = k.mat("Forest_Eye", (0.7, 1.0, 0.6), rough=0.3, emit=3.0)
    sign = k.mat("Forest_Glow", (0.6, 0.85, 0.55), rough=0.4, emit=1.2)

    # Ноги-корни: ствол бедра → колено → корневище, у стопы расходятся пальцами-корнями
    for side, pre in ((-1, "R"), (1, "L")):
        hip = (0.14 * side, 0.0, HIP_Z)
        knee = (0.18 * side, -0.05, 0.38)
        foot = (0.2 * side, 0.02, 0.04)
        strand(f"Thigh{pre}", [hip, knee], 0.09, 0.075, bark, f"Thigh{pre}")
        strand(f"ThighB{pre}", [(hip[0] + 0.04 * side, hip[1] + 0.03, hip[2]), (knee[0] + 0.03 * side, knee[1] + 0.02, knee[2])],
               0.04, 0.035, bark_d, f"Thigh{pre}")
        strand(f"Shin{pre}", [knee, foot], 0.075, 0.06, bark, f"Shin{pre}")
        for j, (dx, dy) in enumerate(((-0.1, -0.12), (0.03, -0.16), (0.12, -0.05), (0.0, 0.12))):
            strand(f"Toe{pre}{j}", [foot, (foot[0] + dx * 0.6, foot[1] + dy * 0.6, 0.03), (foot[0] + dx, foot[1] + dy, 0.0)],
                   0.035, 0.012, bark_d, f"Foot{pre}", segs=4)

    # Туловище: перевитые стволы, сутулое; спереди — светящийся знак-сердцевина в трещине коры
    k.barrel("Pelvis", 0.17, 0.15, HIP_Z - 0.06, HIP_Z + 0.12, bark, "Hips", segs=9)
    for i, (dx, r0, mat_) in enumerate(((-0.07, 0.11, bark), (0.07, 0.11, bark), (0.0, 0.08, bark_d))):
        strand(f"Trunk{i}", [(dx, 0.0, HIP_Z + 0.05), (dx * 1.4, -0.03, (HIP_Z + CHEST_Z) / 2), (dx * 1.6, -0.06, CHEST_Z)],
               r0, r0 * 0.95, mat_, "Spine")
    k.sphere("Chest", 0.2, (0, -0.04, CHEST_Z), bark, "Chest", scale=(1.25, 0.9, 0.95), segs=9, rings=6)
    k.sphere("Heart", 0.035, (0, -0.21, CHEST_Z - 0.06), sign, "Chest", scale=(0.8, 0.5, 1.6), segs=6, rings=4)
    # Мох и листва на плечах и спине
    for i, (x, y, z, s) in enumerate([(-0.2, 0.04, CHEST_Z + 0.1, 0.14), (0.2, 0.04, CHEST_Z + 0.1, 0.14),
                                      (0.0, 0.12, CHEST_Z + 0.06, 0.17), (-0.08, 0.14, CHEST_Z - 0.15, 0.12),
                                      (0.1, 0.12, CHEST_Z - 0.2, 0.1)]):
        k.sphere(f"Moss{i}", s, (x, y, z), moss if i % 2 else moss_l, "Chest", scale=(1.3, 1.0, 0.7), segs=7, rings=4)
    for i in range(9):   # свисающий мох со спины и плеч
        x = rnd.uniform(-0.22, 0.22)
        hl = rnd.uniform(0.15, 0.35)
        k.box(f"Hang{i}", (0.04, 0.02, hl), (x, 0.16 + rnd.uniform(-0.03, 0.03), CHEST_Z - 0.05 - hl / 2), moss, "Chest")

    # Голова: вытянутый чурбак, дупло-лицо, огни глаз, рога из ветвей
    k.sphere("Head", 0.14, (0, -0.07, HEAD_Z), bark, "Head", scale=(0.95, 0.9, 1.25), segs=9, rings=6)
    k.sphere("Face", 0.085, (0, -0.17, HEAD_Z - 0.01), hollow, "Head", scale=(1.1, 0.45, 1.25), segs=8, rings=5)
    for side in (-1, 1):
        k.sphere(f"Eye{side}", 0.02, (0.04 * side, -0.205, HEAD_Z + 0.02), eye, "Head", scale=(1.2, 0.6, 0.9), segs=6, rings=3)
        strand(f"Brow{side}", [(0.01 * side, -0.19, HEAD_Z + 0.08), (0.1 * side, -0.16, HEAD_Z + 0.07), (0.15 * side, -0.08, HEAD_Z + 0.02)],
               0.022, 0.015, bark_d, "Head", segs=4)
        # Рога-ветви: две развилки с листьями
        r0 = (0.07 * side, -0.04, HEAD_Z + 0.12)
        r1 = (0.2 * side, -0.02, HEAD_Z + 0.32)
        r2 = (0.3 * side, 0.03, HEAD_Z + 0.5)
        strand(f"Antler{side}", [r0, r1, r2], 0.03, 0.012, bark_d, "Antlers", segs=4)
        strand(f"AntlerB{side}", [r1, (0.34 * side, -0.05, HEAD_Z + 0.36)], 0.018, 0.008, bark_d, "Antlers", segs=4)
        strand(f"AntlerC{side}", [(0.14 * side, -0.03, HEAD_Z + 0.24), (0.1 * side, -0.08, HEAD_Z + 0.42)], 0.016, 0.006, bark_d, "Antlers", segs=4)
        for j, p in enumerate((r2, (0.34 * side, -0.05, HEAD_Z + 0.36), (0.1 * side, -0.08, HEAD_Z + 0.42))):
            k.sphere(f"Leaf{side}_{j}", 0.045, p, leaf, "Antlers", scale=(1.4, 0.6, 0.9), segs=5, rings=3)

    # Руки-ветви: плечо → локоть → кисть ниже колена, пальцы — длинные сучья
    for side, pre in ((-1, "R"), (1, "L")):
        sh = (0.26 * side, -0.03, CHEST_Z + 0.06)
        el = (0.34 * side, -0.1, 0.86)
        hd = (0.36 * side, -0.16, 0.5)
        strand(f"Arm{pre}", [sh, el], 0.06, 0.05, bark, f"Arm{pre}")
        strand(f"Fore{pre}", [el, hd], 0.05, 0.04, bark, f"Fore{pre}")
        strand(f"ForeB{pre}", [(el[0] + 0.02 * side, el[1] + 0.02, el[2]), (hd[0] + 0.03 * side, hd[1] + 0.03, hd[2] + 0.05)],
               0.025, 0.02, bark_d, f"Fore{pre}", segs=4)
        k.sphere(f"Elbow{pre}", 0.05, el, moss_l, f"Arm{pre}", scale=(1.2, 1.0, 0.8), segs=6, rings=4)
        for j, (dx, dy) in enumerate(((-0.05, -0.04), (0.0, -0.07), (0.05, -0.04))):
            strand(f"Finger{pre}{j}", [hd, (hd[0] + dx, hd[1] + dy, hd[2] - 0.12), (hd[0] + dx * 1.4, hd[1] + dy * 1.6, hd[2] - 0.24)],
                   0.022, 0.006, bark_d, f"Hand{pre}", segs=4)
    return k.join_parts("SpiritForestMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Hips": ((0, 0, HIP_Z - 0.05), (0, 0, HIP_Z + 0.1), "Root"),
    "Spine": ((0, 0, HIP_Z + 0.1), (0, -0.04, CHEST_Z - 0.1), "Hips"),
    "Chest": ((0, -0.04, CHEST_Z - 0.1), (0, -0.06, CHEST_Z + 0.15), "Spine"),
    "Head": ((0, -0.06, CHEST_Z + 0.15), (0, -0.07, HEAD_Z + 0.15), "Chest"),
    "Antlers": ((0, -0.05, HEAD_Z + 0.1), (0, -0.05, HEAD_Z + 0.4), "Head"),
    "ThighR": ((-0.14, 0, HIP_Z), (-0.18, -0.05, 0.38), "Hips"),
    "ShinR": ((-0.18, -0.05, 0.38), (-0.2, 0.02, 0.06), "ThighR"),
    "FootR": ((-0.2, 0.02, 0.06), (-0.2, -0.12, 0.0), "ShinR"),
    "ThighL": ((0.14, 0, HIP_Z), (0.18, -0.05, 0.38), "Hips"),
    "ShinL": ((0.18, -0.05, 0.38), (0.2, 0.02, 0.06), "ThighL"),
    "FootL": ((0.2, 0.02, 0.06), (0.2, -0.12, 0.0), "ShinL"),
    "ArmR": ((-0.26, -0.03, CHEST_Z + 0.06), (-0.34, -0.1, 0.86), "Chest"),
    "ForeR": ((-0.34, -0.1, 0.86), (-0.36, -0.16, 0.5), "ArmR"),
    "HandR": ((-0.36, -0.16, 0.5), (-0.4, -0.2, 0.26), "ForeR"),
    "ArmL": ((0.26, -0.03, CHEST_Z + 0.06), (0.34, -0.1, 0.86), "Chest"),
    "ForeL": ((0.34, -0.1, 0.86), (0.36, -0.16, 0.5), "ArmL"),
    "HandL": ((0.36, -0.16, 0.5), (0.4, -0.2, 0.26), "ForeL"),
}


def base():
    p = Pose({}, {})
    p.add("Spine", x=8)
    p.add("Chest", x=6)
    p.add("Head", x=-8)
    return p


def idle(t):
    """Покой (3 сек): медленно покачивается, как дерево на ветру; рога шелестят с опозданием,
    голова поворачивается к отряду и обратно; пальцы-сучья подрагивают."""
    p = base()
    sway = wave(t, 1)
    p.add("Spine", z=3 * sway)
    p.add("Chest", z=2 * sway, x=2 * wave(t, 1, 0.25))
    look = track(t, [(0, 0), (0.3, 0), (0.38, -14), (0.7, -14), (0.78, 0), (1, 0)])
    p.add("Head", y=look, z=-2 * sway)
    p.add("Antlers", z=-5 * wave(t, 1, -0.15), x=3 * wave(t, 2, 0.1))
    p.add("ArmR", x=-3 * wave(t, 1, 0.3), z=-2 * sway)
    p.add("ArmL", x=-3 * wave(t, 1, 0.8), z=-2 * sway)
    p.add("HandR", x=-10 * pulse(t, 0.5, 0.08))
    p.move("Root", z=0.01 * wave(t, 2))
    return p


def walk(t):
    """Шаг (1.2 сек): широкий тяжёлый шаг корнями, корпус перекатывается, руки-ветви волочатся."""
    p = base()
    s = wave(t, 1)
    p.add("ThighR", x=-26 * s)
    p.add("ThighL", x=26 * s)
    p.add("ShinR", x=24 * max(0.0, s))
    p.add("ShinL", x=24 * max(0.0, -s))
    p.add("Spine", z=4 * s, x=4)
    p.add("Chest", y=-5 * s)
    p.add("Head", y=4 * s)
    p.add("Antlers", z=-6 * wave(t, 1, -0.15))
    p.add("ArmR", x=12 * s)
    p.add("ArmL", x=-12 * s)
    p.move("Root", z=0.03 * abs(wave(t, 1)))
    return p


def attack(t):
    """Хлёст ветвями (0.9 сек): выпрямляется, обе руки-ветви поднимаются над рогами → хлещут вниз и вперёд
    (около 0.45 сек), пальцы-сучья впиваются → медленно возвращается."""
    p = base()
    K = [0.0, 0.35, 0.5, 0.65, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Spine", x=tr([0, -12, 14, 10, 0]))
    p.add("Chest", x=tr([0, -10, 12, 8, 0]))
    p.add("Head", x=tr([0, -6, 10, 6, 0]))
    p.add("Antlers", x=tr([0, 8, -12, -6, 0]))
    swing = tr([0, -140, -55, -60, 0])   # у костей «вниз» X− — вперёд: руки вверх над рогами → вниз перед собой
    p.add("ArmR", x=swing)
    p.add("ArmL", x=swing)
    p.add("ForeR", x=tr([0, -20, -10, -15, 0]))
    p.add("ForeL", x=tr([0, -20, -10, -15, 0]))
    p.add("HandR", x=tr([0, 0, -30, -35, 0]))
    p.add("HandL", x=tr([0, 0, -30, -35, 0]))
    p.add("ThighR", x=tr([0, 0, -12, -10, 0]))
    p.add("ShinR", x=tr([0, 0, 12, 10, 0]))
    return p


def hit(t):
    """Получил удар (0.47 сек): корпус откидывается, голова и рога мотаются с опозданием."""
    p = base()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.25, 0.3), (0.4, 1), (0.62, -0.4), (0.85, 0.1), (1, 0)])
    p.add("Spine", x=-10 * snap)
    p.add("Chest", x=-6 * snap)
    p.add("Head", x=-14 * whip)
    p.add("Antlers", x=-18 * whip)
    p.add("ArmR", x=14 * whip, z=-8 * whip)
    p.add("ArmL", x=14 * whip, z=8 * whip)
    return p


def death(t):
    """Покорён (1.6 сек): вздрагивает, руки-ветви опускаются и раскидываются, как ветви дерева,
    сам оседает и врастает в землю; рога поднимаются кроной."""
    p = base()
    K = [0.0, 0.15, 0.45, 0.8, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Spine", x=tr([0, -10, -4, -4, -4]))
    p.add("Head", x=tr([0, -15, 10, 14, 14]))
    p.add("Antlers", x=tr([0, 10, -10, -16, -16]))
    p.add("ArmR", x=tr([0, -20, 30, 60, 60]), z=tr([0, 0, -40, -70, -70]))
    p.add("ArmL", x=tr([0, -20, 30, 60, 60]), z=tr([0, 0, 40, 70, 70]))
    p.add("ThighR", x=tr([0, 0, -20, -30, -30]))
    p.add("ThighL", x=tr([0, 0, -20, -30, -30]))
    p.add("ShinR", x=tr([0, 0, 35, 50, 50]))
    p.add("ShinL", x=tr([0, 0, 35, 50, 50]))
    p.move("Root", z=tr([0, 0.02, -0.15, -0.3, -0.32]))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True)
    k.bake(rig, "Walk", 36, walk, cyclic=True)
    k.bake(rig, "Attack", 27, attack)
    k.bake(rig, "Hit", 14, hit)
    k.bake(rig, "Death", 48, death)


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
    glb = args[0] if args else os.path.join(here, "..", "spirit_forest.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "spirit_forest.blend")
    build(glb, blend)
