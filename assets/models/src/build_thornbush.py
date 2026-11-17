# Колючник (~1.0 м) — тварь Раскола, лесная ветка акта 1, не ходит. Неровный низкий ком спутанных
# чёрно-бурых колючих ветвей с тёмными листьями, шире внизу; в глубине пульсирует бирюзовое ядро —
# видно только в щелях; на ветках несколько бирюзовых трещин; по плите расходятся корни. Сначала куст,
# потом чудовище. Облик — claude/мир.md; референс Gemini 17 ноября (перерисованный): листья чуть светлее,
# в ширину — в пределах клетки. Смотрит в -Y.
#
# Анимации: Idle, Walk (только дрожь — он не ходит), Attack (шипы во все стороны, опутывает соседей), Hit, Death.
# Запуск: python3 build_thornbush.py out/thornbush.glb out/thornbush.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse
from mathutils import Vector

NAME = "Thornbush"
N_BR = 7                     # кластеров ветвей вокруг (у каждого своя кость)
CENTER = Vector((0, 0, 0.32))


def branch_dir(i):
    a = math.tau * i / N_BR + 0.3
    return Vector((math.cos(a), math.sin(a), 0.0)), a


# ---------- Модель ----------

def build_mesh():
    bark = k.mat("Thorn_Bark", (0.27, 0.2, 0.15), rough=0.95)       # чёрно-бурые ветви (чуть светлее природных)
    bark_d = k.mat("Thorn_BarkDark", (0.19, 0.14, 0.11), rough=0.95)
    thorn = k.mat("Thorn_Spike", (0.36, 0.3, 0.24), rough=0.8)
    leaf = k.mat("Thorn_Leaf", (0.3, 0.42, 0.24), rough=0.8)        # тёмные листья, но светлее плит
    leaf_d = k.mat("Thorn_LeafDark", (0.22, 0.32, 0.18), rough=0.8)
    rift = k.mat("Thorn_Rift", (0.25, 0.85, 0.75), rough=0.4, emit=1.4)

    # Плотная основа-ком (низ шире) и ядро внутри
    k.sphere("Mass", 0.25, (0, 0, 0.26), bark_d, "Bush", scale=(1.15, 1.1, 0.85), segs=7, rings=4)
    k.sphere("MassTop", 0.17, (0.03, 0.02, 0.48), bark_d, "Bush", scale=(1.0, 1.0, 0.9), segs=6, rings=4)
    k.sphere("Core", 0.1, (0.0, -0.2, 0.36), rift, "Core", scale=(1.0, 0.8, 1.0), segs=6, rings=4)
    # Корни по плите
    for i in range(8):
        a = math.tau * i / 8 + 0.2
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = d * 0.16 + Vector((0, 0, 0.1))
        p1 = d * 0.44 + Vector((0, 0, 0.015))
        k.limb(f"Root{i}", tuple(p0), tuple(p1), 0.04, 0.012, bark, "Root", segs=4)
    # Ветви: в каждом кластере две толстые ветки наружу-вверх с шипами и листьями
    for i in range(N_BR):
        d, a = branch_dir(i)
        bone = f"Branch{i}"
        for j, (up, out, ln) in enumerate(((0.05, 0.4, 0.42), (0.3, 0.3, 0.46), (0.7, 0.2, 0.42))):
            base = CENTER + d * 0.08 + Vector((0, 0, 0.08 * j - 0.1))
            tip = base + (d * out + Vector((0, 0, up))).normalized() * ln + Vector((0, 0, 0.02 * (i % 3)))
            mid = base.lerp(tip, 0.5) + Vector((-d.y, d.x, 0)) * 0.04 * (1 if (i + j) % 2 else -1)
            k.limb(f"Br{i}{j}a", tuple(base), tuple(mid), 0.035, 0.026, bark if j else bark_d, bone, segs=5)
            k.limb(f"Br{i}{j}b", tuple(mid), tuple(tip), 0.026, 0.008, bark, bone, segs=5)
            for q, f in enumerate((0.3, 0.6, 0.85)):   # шипы
                c = base.lerp(tip, f)
                side = Vector((-d.y, d.x, 0)) * (1 if q % 2 else -1)
                k.limb(f"Th{i}{j}{q}", tuple(c), tuple(c + (side + d * 0.5 + Vector((0, 0, 0.4))).normalized() * 0.07),
                       0.012, 0.0, thorn, bone, segs=3)
            for q, f in enumerate((0.45, 0.75)):        # листья
                c = base.lerp(tip, f)
                aa = a + 0.8 * q
                u = (math.cos(aa), math.sin(aa), 0.3)
                v = (-math.sin(aa) * 0.4, math.cos(aa) * 0.4, 1.0)
                pts = [(0, 0), (0.05, 0.07), (0, 0.15), (-0.05, 0.07)]
                k.plate(f"Lf{i}{j}{q}", pts, 0.006, tuple(c), u, v, leaf if (i + q) % 2 else leaf_d, bone)
        if i % 2 == 0:   # бирюзовая трещина по ветке
            base = CENTER + d * 0.15
            k.crack(f"Crack{i}", [(0, 0), (0.04, 0.01), (0.08, -0.01), (0.12, 0.015)], tuple(base + Vector((0, 0, 0.05))),
                    tuple(d), (0, 0, 1), rift, bone, width=0.014, depth=0.02)
    # Верхний пучок ветвей
    for j in range(3):
        a = 1.3 + 2.1 * j
        base = Vector((0.03, 0.0, 0.55))
        tip = base + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0.3 + 0.05 * j))
        k.limb(f"TopBr{j}", tuple(base), tuple(tip), 0.025, 0.006, bark, "Top", segs=5)
        k.limb(f"TopTh{j}", tuple(base.lerp(tip, 0.6)), tuple(base.lerp(tip, 0.6) + Vector((math.cos(a) * 0.07, math.sin(a) * 0.07, 0.03))),
               0.01, 0.0, thorn, "Top", segs=3)
    return k.join_parts("ThornbushMesh")


# ---------- Скелет ----------

BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.12), None),
    "Bush": ((0, 0, 0.05), (0, 0, 0.5), "Root"),
    "Core": ((0, -0.2, 0.3), (0, -0.2, 0.44), "Bush"),
    "Top": ((0.03, 0.0, 0.55), (0.03, 0.0, 0.85), "Bush"),
}
for i in range(N_BR):
    d, a = branch_dir(i)
    BONES[f"Branch{i}"] = (tuple(CENTER + d * 0.12), tuple(CENTER + d * 0.4 + Vector((0, 0, 0.2))), "Bush")
SCALED = ("Core",) + tuple(f"Branch{i}" for i in range(N_BR))


# ---------- Анимации ----------
# Ветви «вбок-вверх»: X- отклоняет ветку наружу-вниз, X+ прижимает к кусту (проверено по снимкам).

def branches(p, x=0.0, scale=1.0, t=0.0, jitter=0.0):
    for i in range(N_BR):
        p.add(f"Branch{i}", x=x + jitter * wave(t, 3, i * 0.13), z=jitter * 0.6 * wave(t, 2, i * 0.29))
        p.size(f"Branch{i}", 1.0, scale, 1.0)


def idle(t):
    """Покой (3 сек): куст медленно колышется, ветви шевелятся вразнобой, ядро пульсирует, как сердце.
    Характерное: короткая дрожь всех ветвей — будто куст встряхнулся."""
    p = Pose({}, {})
    p.add("Bush", z=2 * wave(t, 1), x=1.5 * wave(t, 1, 0.3))
    shiver = pulse(t, 0.7, 0.06) * wave(t, 14)
    branches(p, t=t, jitter=3.0 + 6 * abs(shiver))
    p.add("Top", z=6 * wave(t, 1, 0.4), x=3 * wave(t, 2))
    p.size("Core", 1.0 + 0.12 * pulse(t, 0.2, 0.06) + 0.08 * pulse(t, 0.28, 0.05) + 0.12 * pulse(t, 0.7, 0.06) + 0.08 * pulse(t, 0.78, 0.05))
    return p


def walk(t):
    """Он не ходит: если игра всё же двигает — куст мелко трясётся."""
    p = Pose({}, {})
    p.add("Bush", z=3 * wave(t, 4), x=2 * wave(t, 4, 0.25))
    branches(p, t=t, jitter=6.0)
    return p


def attack(t):
    """Шипы (0.8 сек): ветви сжимаются к ядру, ядро разгорается → ветви выстреливают во все стороны
    (к 0.4 сек) и опутывают соседей → медленно возвращаются."""
    p = Pose({}, {})
    K = [0.0, 0.3, 0.48, 0.62, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    branches(p, x=tr([0, 18, -34, -28, 0]), scale=tr([1, 0.85, 1.45, 1.35, 1]))
    p.add("Top", x=tr([0, 10, -20, -16, 0]))
    p.size("Top", tr([1, 0.9, 1.3, 1.2, 1]))
    p.size("Core", tr([1, 1.4, 1.8, 1.3, 1]))
    p.add("Bush", x=tr([0, 0, 0, 0, 0]))
    p.size("Bush", tr([1, 0.94, 1.06, 1.03, 1]))
    return p


def hit(t):
    """Получил удар (0.45 сек): куст качнулся, ветви хлестнули, ядро мигнуло."""
    p = Pose({}, {})
    snap = track(t, [(0, 0), (0.18, 1), (0.5, 0.3), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.34, 1), (0.6, -0.3), (0.82, 0.08), (1, 0)])
    p.add("Bush", x=-10 * snap, z=6 * whip)
    branches(p, x=10 * whip, t=t, jitter=8 * snap)
    p.add("Top", x=-20 * whip)
    p.size("Core", 1.0 - 0.4 * snap)
    return p


def death(t):
    """Гибель (1.2 сек): ядро гаснет, ветви опадают к земле, куст оседает и сохнет."""
    p = Pose({}, {})
    K = [0.0, 0.25, 0.6, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.size("Core", tr([1, 1.5, 0.3, 0.05]))
    branches(p, x=tr([0, -10, -50, -60]), scale=tr([1, 1.1, 0.9, 0.85]))
    p.add("Top", x=tr([0, -10, -60, -80]))
    p.size("Bush", tr([1, 1.02, 0.8, 0.7]))
    p.add("Bush", x=24 * pulse(t, 0.9, 0.05))
    return p


def build_actions(rig):
    sc = SCALED + ("Top", "Bush")
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=sc)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=sc)
    k.bake(rig, "Attack", 24, attack, scale_bones=sc)
    k.bake(rig, "Hit", 14, hit, scale_bones=sc)
    k.bake(rig, "Death", 36, death, scale_bones=sc)


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
    glb = args[0] if args else os.path.join(here, "..", "thornbush.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "thornbush.blend")
    build(glb, blend)
