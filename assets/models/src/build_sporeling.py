# Споровик — тварь Раскола (~0.95 м), гриб Раскола, который не ходит. Толстая бледная серо-оливковая ножка,
# широкая каменистая шляпка с бирюзовыми трещинами, под ней светящиеся пластинки, по шляпке и у основания —
# вздутые споровые мешки, вокруг ножки по земле расходятся корни.
# Смотрит в -Y (после экспорта в glTF это +Z, как у остальных персонажей).
#
# Анимации: Idle, Walk (только покачивание: споровик не ходит), Attack (Споры), Attack2 (Рост), Hit, Death.
# Запуск: python3 build_sporeling.py out/sporeling.glb out/sporeling.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "Sporeling"
CAP_Z = 0.5


def build_mesh():
    stalk = k.mat("Spore_Stalk", (0.60, 0.62, 0.52), rough=0.9)
    cap = k.mat("Spore_Cap", (0.47, 0.49, 0.42), rough=0.9)
    cap_d = k.mat("Spore_CapDark", (0.32, 0.34, 0.29), rough=0.9)
    sac = k.mat("Spore_Sac", (0.52, 0.60, 0.54), rough=0.6, emit=0.06)
    root = k.mat("Spore_Root", (0.33, 0.29, 0.23), rough=1.0)
    moss = k.mat("Spore_Moss", (0.38, 0.46, 0.26), rough=1.0)
    rift = k.mat("Spore_Rift", (0.30, 0.92, 0.82), rough=0.4, emit=1.3)

    # Ножка: толстая, к низу шире
    k.barrel("Stalk", 0.27, 0.2, 0.05, CAP_Z - 0.02, stalk, "Stalk", segs=9)
    k.sphere("StalkBase", 0.3, (0, 0, 0.14), stalk, "Stalk", scale=(1.0, 1.0, 0.7), segs=8, rings=4)
    # Шляпка: широкий приплюснутый купол, снизу тёмная, светящиеся пластинки по кругу
    k.sphere("Cap", 0.5, (0, 0, CAP_Z + 0.1), cap, "Cap", scale=(1.0, 1.0, 0.5), segs=11, rings=6)
    k.barrel("CapUnder", 0.46, 0.2, CAP_Z - 0.02, CAP_Z + 0.06, cap_d, "Cap", segs=11)
    for i in range(10):
        a = math.tau * i / 10
        k.limb(f"Gill{i}", (0.17 * math.cos(a), 0.17 * math.sin(a), CAP_Z + 0.0),
               (0.43 * math.cos(a), 0.43 * math.sin(a), CAP_Z + 0.03), 0.012, 0.012, rift, "Cap", segs=3)
    # Трещины по шляпке
    for j, phi in enumerate([20, 100, 170, 250, 320]):
        pts = []
        for n, r in enumerate((0.06, 0.2, 0.33, 0.45)):
            a = math.radians(phi + (10 if n % 2 else -8))
            z = CAP_Z + 0.1 + 0.25 * math.sqrt(max(0.0, 1 - (r / 0.5) ** 2)) + 0.01
            pts.append((r * math.cos(a), r * math.sin(a), z))
        for n in range(len(pts) - 1):
            k.limb(f"CapRift{j}_{n}", pts[n], pts[n + 1], 0.013, 0.013, rift, "Cap", segs=4)
    k.sphere("CapMoss", 0.09, (-0.12, 0.14, CAP_Z + 0.27), moss, "Cap", scale=(1.3, 1.0, 0.3), segs=5, rings=3)
    # Споровые мешки: гроздья на шляпке (кость Sacs — пульсирует) и у основания (SacsLow)
    for i, (x, y, z, r) in enumerate([(0.18, -0.1, CAP_Z + 0.25, 0.08), (0.27, 0.02, CAP_Z + 0.2, 0.065),
                                      (0.12, 0.08, CAP_Z + 0.28, 0.06), (-0.22, -0.16, CAP_Z + 0.2, 0.07),
                                      (-0.28, 0.0, CAP_Z + 0.16, 0.055), (0.3, -0.14, CAP_Z + 0.14, 0.05)]):
        k.sphere(f"Sac{i}", r * 1.6, (x * 1.15, y * 1.15, z + 0.02), sac, "Sacs", segs=6, rings=4)
    for i, (x, y, z, r) in enumerate([(0.22, -0.08, 0.12, 0.08), (0.27, 0.06, 0.08, 0.06), (-0.2, -0.14, 0.1, 0.07),
                                      (-0.25, 0.04, 0.16, 0.055)]):
        k.sphere(f"SacLow{i}", r * 1.5, (x * 1.25, y * 1.25, z), sac, "SacsLow", segs=6, rings=4)
    # Корни по земле
    for i in range(7):
        a = math.tau * i / 7 + 0.3
        p0 = (0.18 * math.cos(a), 0.18 * math.sin(a), 0.05)
        p1 = (0.42 * math.cos(a + 0.15), 0.42 * math.sin(a + 0.15), 0.02)
        p2 = (0.6 * math.cos(a - 0.1), 0.6 * math.sin(a - 0.1), 0.01)
        k.limb(f"Root{i}a", p0, p1, 0.035, 0.022, root, "Root", segs=4)
        k.limb(f"Root{i}b", p1, p2, 0.022, 0.006, root, "Root", segs=3)
    return k.join_parts("SporelingMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.12), None),
    "Stalk": ((0, 0, 0.05), (0, 0, CAP_Z), "Root"),
    "Cap": ((0, 0, CAP_Z), (0, 0, CAP_Z + 0.3), "Stalk"),
    "Sacs": ((0, 0, CAP_Z + 0.2), (0, 0, CAP_Z + 0.3), "Cap"),
    "SacsLow": ((0, 0, 0.1), (0, 0, 0.2), "Stalk"),
}
SCALED = ("Cap", "Sacs", "SacsLow", "Stalk")


def base():
    p = Pose({}, {})
    p.add("Cap", x=-4, z=3)   # шляпка чуть набок и назад
    return p


def idle(t):
    """Покой (3 сек): медленно «дышит» — ножка и шляпка раздуваются, мешки пульсируют не в такт, шляпка покачивается."""
    p = base()
    breath = wave(t, 1)
    p.size("Stalk", 1 + 0.03 * breath, 1 + 0.03 * breath, 1 - 0.02 * breath)
    p.add("Cap", x=3 * wave(t, 1, 0.2), z=2 * wave(t, 1, -0.1))
    p.size("Sacs", 1 + 0.07 * wave(t, 2, 0.3))
    p.size("SacsLow", 1 + 0.08 * wave(t, 2, -0.1) + 0.12 * pulse(t, 0.7, 0.06))
    p.add("Stalk", x=2 * wave(t, 1, 0.4))
    return p


def walk(t):
    """Споровик не ходит: при «ходьбе» (на месте) просто покачивается."""
    p = base()
    p.add("Stalk", z=3 * wave(t, 1))
    p.add("Cap", z=-3 * wave(t, 1, -0.15))
    return p


def attack(t):
    """Споры (0.8 сек): шляпка приседает, мешки набухают → выдох: шляпка подпрыгивает, мешки опадают (к 0.4 сек)."""
    p = base()
    K = [0.0, 0.3, 0.45, 0.6, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.size("Stalk", 1.0, 1.0, tr([1, 0.82, 1.1, 1.02, 1]))
    p.size("Sacs", tr([1, 1.35, 0.7, 0.85, 1]))
    p.size("SacsLow", tr([1, 1.3, 0.7, 0.85, 1]))
    p.size("Cap", 1.0, 1.0, tr([1, 0.9, 1.12, 1.04, 1]))
    p.add("Cap", x=tr([0, 6, -6, -2, 0]))
    return p


def attack2(t):
    """Рост (0.8 сек): гриб вытягивается и расправляет шляпку — нарастает каменная кора."""
    p = base()
    K = [0.0, 0.35, 0.55, 1.0]
    grow = track(t, [(K[0], 0), (K[1], 1), (K[2], 0.8), (K[3], 0)])
    p.size("Stalk", 1 + 0.06 * grow, 1 + 0.06 * grow, 1 + 0.15 * grow)
    p.size("Cap", 1 + 0.14 * grow, 1 + 0.14 * grow, 1 + 0.05 * grow)
    p.add("Cap", x=-6 * grow)
    p.size("Sacs", 1 + 0.1 * grow)
    return p


def hit(t):
    """Получил удар (0.47 сек): шляпку мотает, ножка гнётся, мешки сжимаются."""
    p = base()
    snap = track(t, [(0, 0), (0.18, 1), (0.45, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.4), (0.35, 1), (0.6, -0.4), (0.82, 0.1), (1, 0)])
    p.add("Stalk", x=-10 * snap, z=6 * snap)
    p.add("Cap", x=-14 * whip, z=-8 * whip)
    p.size("Sacs", 1 - 0.2 * snap)
    p.size("SacsLow", 1 - 0.2 * snap)
    return p


def death(t):
    """Гибель (1.2 сек): мешки лопаются, ножка подламывается, шляпка вянет и падает набок."""
    p = base()
    K = [0.0, 0.2, 0.5, 0.75, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.size("Sacs", tr([1, 1.3, 0.2, 0.05, 0.05]))
    p.size("SacsLow", tr([1, 1.3, 0.2, 0.05, 0.05]))
    p.size("Stalk", 1.0, 1.0, tr([1, 1.05, 0.7, 0.45, 0.42]))
    p.add("Stalk", x=tr([0, -6, 10, 30, 32]), z=tr([0, 4, -10, -20, -22]))
    p.add("Cap", x=tr([0, -10, 30, 50, 52]), z=tr([0, 0, 10, 16, 16]))
    p.size("Cap", 1.0, 1.0, tr([1, 1, 0.85, 0.7, 0.7]))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, scale_bones=SCALED)
    k.bake(rig, "Attack2", 24, attack2, scale_bones=SCALED)
    k.bake(rig, "Hit", 14, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 36, death, scale_bones=SCALED)


def build(glb_path, blend_path=None):
    k.start_scene(NAME)
    body = build_mesh()
    rig = k.build_armature(NAME, BONES)
    body.parent = rig
    build_actions(rig)
    k.export(rig, body, glb_path, blend_path)
    print("%s: треугольников %d" % (NAME, sum(len(p.vertices) - 2 for p in body.data.polygons)))
    return rig, body


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    glb = args[0] if args else os.path.join(here, "..", "sporeling.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "sporeling.blend")
    build(glb, blend)
