# Болотная пиявка — тварь Раскола (~1 м длиной, перед поднят на ~0.45 м). Толстое кольчатое тело
# лежит вдоль клетки, тёмно-оливковая спина, бледное серо-зелёное брюхо, бирюзовые кольца-прожилки
# между сегментами, хвост — плоская лопасть. Перед поднят и загнут к цели: круглая пасть-присоска
# с кольцом мелких зубов и две бирюзовые точки-глаза. Облик — claude/мир.md, «Будущие враги»;
# референс Gemini — 14 ноября. Смотрит в -Y (после экспорта в glTF это +Z).
#
# Анимации: Idle (покачивает поднятым передом, «принюхивается»), Walk (волна по телу и змейкой вбок),
# Attack (Присосаться: перед откидывается назад → бросок вперёд около 0.4 сек → пасть пульсирует),
# Hit, Death (сворачивается набок, опадает плашмя, короткая судорога).
# Запуск: python3 build_leech.py out/leech.glb out/leech.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, pulse

NAME = "Leech"

# Сегменты тела от хвоста к голове: (y, z, радиус, кость). Каждый — вытянутая «бусина»;
# бусины перекрываются, поэтому тело выглядит кольчатым.
SEGS = [
    (0.44, 0.06, 0.07, "Tail"),
    (0.33, 0.085, 0.105, "Back"),
    (0.2, 0.115, 0.14, "Back"),
    (0.06, 0.135, 0.162, "Mid"),
    (-0.08, 0.145, 0.158, "Mid"),
    (-0.2, 0.185, 0.14, "Front"),
    (-0.27, 0.29, 0.125, "Neck"),
]
HEAD = (0.0, -0.31, 0.405)


def build_mesh():
    back = k.mat("Leech_Back", (0.3, 0.35, 0.21), rough=0.3)
    back_d = k.mat("Leech_BackDark", (0.24, 0.28, 0.17), rough=0.3)
    belly = k.mat("Leech_Belly", (0.56, 0.63, 0.5), rough=0.35)
    mouth = k.mat("Leech_Mouth", (0.09, 0.11, 0.07), rough=0.6)
    teeth = k.mat("Leech_Teeth", (0.72, 0.75, 0.64), rough=0.5)
    rift = k.mat("Leech_Rift", (0.3, 0.95, 0.82), rough=0.3, emit=1.4)
    eye = k.mat("Leech_Eye", (0.55, 1.0, 0.92), rough=0.3, emit=2.5)

    pts = [(0.0, y, z) for y, z, _, _ in SEGS] + [HEAD]
    for i, (y, z, r, bone) in enumerate(SEGS):
        nxt = pts[i + 1]
        prv = pts[i - 1] if i > 0 else (0.0, y + 0.1, z - 0.02)
        dy, dz = nxt[1] - prv[1], nxt[2] - prv[2]
        ang = math.degrees(math.atan2(dz, dy))
        length = r * 1.05
        k.sphere(f"Seg{i}", r, (0, y, z), back if i % 2 else back_d, bone, scale=(1.0, length / r, 0.9),
                 rot=(ang, 0, 0), segs=9, rings=6)
        # брюхо: чуть ниже и шире, выглядывает снизу и с боков
        k.sphere(f"Belly{i}", r * 0.9, (0, y, z - r * 0.42), belly, bone, scale=(1.0, length / r * 0.92, 0.6),
                 rot=(ang, 0, 0), segs=8, rings=4)
        # бирюзовое кольцо-прожилка на стыке с следующим сегментом
        if i < len(SEGS) - 1:
            ny, nz, nr, _ = SEGS[i + 1]
            cy, cz = (y + ny) / 2, (z + nz) / 2
            ux, uy = ny - y, nz - z
            n = math.hypot(ux, uy)
            ux, uy = ux / n * 0.004, uy / n * 0.004
            rr = (r + nr) / 2 * 0.955
            k.limb(f"Ring{i}", (0, cy - ux, cz - uy), (0, cy + ux, cz + uy), rr, rr, rift, bone, segs=9)

    # Ветвистые прожилки по бокам от колец (как трещины на референсе)
    for i, side in ((2, 1), (3, -1), (4, 1), (1, -1)):
        y, z, r, bone = SEGS[i]
        x0 = side * r * 0.97
        k.limb(f"Crack{i}a", (x0, y + 0.03, z + 0.02), (x0 * 1.02, y - 0.02, z - 0.04), 0.008, 0.006, rift, bone, segs=3)
        k.limb(f"Crack{i}b", (x0 * 1.02, y - 0.02, z - 0.04), (x0 * 0.98, y - 0.05, z - 0.08), 0.006, 0.004, rift, bone, segs=3)

    # Хвост — плоская лопасть
    k.plate("TailFin", [(0, 0.0), (0.09, 0.05), (0.07, 0.15), (0.0, 0.2), (-0.07, 0.15), (-0.09, 0.05)], 0.03,
            (0, 0.44, 0.03), (1, 0, 0), (0, 1, -0.1), back_d, "Tail")

    # Голова: шар, пасть-присоска смотрит вперёд и чуть вниз
    hx, hy, hz = HEAD
    k.sphere("Head", 0.125, HEAD, back, "Head", scale=(1.0, 1.0, 0.95), segs=9, rings=6)
    k.sphere("HeadBelly", 0.1, (0, hy - 0.02, hz - 0.06), belly, "Head", scale=(0.95, 0.95, 0.7), segs=8, rings=5)
    d = (0.0, -0.96, -0.28)
    lip0 = (hx, hy + d[1] * 0.06, hz + d[2] * 0.06)
    lip1 = (hx, hy + d[1] * 0.12, hz + d[2] * 0.12)
    k.limb("Lip", lip0, lip1, 0.105, 0.09, belly, "Head", segs=10)   # мягкая светлая губа присоски
    k.limb("MouthHole", (hx, hy + d[1] * 0.09, hz + d[2] * 0.09), (hx, hy + d[1] * 0.124, hz + d[2] * 0.124),
           0.066, 0.066, mouth, "Head", segs=10)
    # кольцо зубов по краю присоски (ось u — вбок, ось v — вверх по плоскости пасти)
    cy_, cz_ = hy + d[1] * 0.124, hz + d[2] * 0.124
    for j in range(10):
        a = 2 * math.pi * j / 10
        ox = 0.054 * math.cos(a)
        oz = 0.054 * math.sin(a)
        k.sphere(f"Tooth{j}", 0.01, (ox, cy_ - oz * 0.28, cz_ + oz * 0.96), teeth, "Head", segs=4, rings=3)
    for side in (-1, 1):
        k.sphere(f"Eye{side}", 0.014, (0.05 * side, hy - 0.06, hz + 0.09), eye, "Head", segs=6, rings=3)
    k.limb("HeadVein", (0.0, hy + 0.02, hz + 0.12), (0.0, hy + 0.09, hz + 0.06), 0.006, 0.005, rift, "Head", segs=3)
    return k.join_parts("LeechMesh")


BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.1), None),
    "Mid": ((0, 0.12, 0.13), (0, -0.12, 0.155), "Root"),
    "Back": ((0, 0.12, 0.13), (0, 0.38, 0.075), "Mid"),
    "Tail": ((0, 0.38, 0.075), (0, 0.6, 0.03), "Back"),
    "Front": ((0, -0.12, 0.155), (0, -0.25, 0.23), "Mid"),
    "Neck": ((0, -0.25, 0.23), (0, -0.3, 0.37), "Front"),
    "Head": ((0, -0.3, 0.37), (0, -0.42, 0.42), "Neck"),
}
SCALED = ("Mid", "Head", "Neck")

# Знаки осей (проверено по кадрам): у костей вдоль тела X+ опускает их конец (поэтому UP = -1), Z — уводит вбок.
UP = -1.0
SIDE = 1.0


def base():
    """Стойка: перед поднят и чуть повёрнут к цели, хвост лежит на земле."""
    p = Pose({}, {})
    p.add("Neck", x=4 * UP)
    p.add("Head", x=-6 * UP, z=6 * SIDE)
    p.add("Tail", x=-4 * UP, z=-8 * SIDE)
    return p


def idle(t):
    """Покой (3 сек): тело дышит (раздувается и опадает), перед покачивается вбок и «принюхивается»
    кивками; хвост лениво бьёт; посередине — пасть раскрывается (пульс головы)."""
    p = base()
    b = wave(t, 1)
    p.size("Mid", 1 + 0.05 * b, 1.0, 1 + 0.05 * b)
    p.add("Front", z=8 * SIDE * wave(t, 1, 0.1), x=3 * UP * wave(t, 2))
    p.add("Neck", z=10 * SIDE * wave(t, 1, 0.2), x=4 * UP * wave(t, 2, 0.15))
    sniff = pulse(t, 0.3, 0.06) + pulse(t, 0.4, 0.06) + pulse(t, 0.78, 0.06)
    p.add("Head", z=12 * SIDE * wave(t, 1, 0.32), x=-10 * UP * sniff)
    gape = pulse(t, 0.6, 0.1)
    p.size("Head", 1 + 0.12 * gape)
    p.add("Back", z=-4 * SIDE * wave(t, 1, 0.45))
    p.add("Tail", z=-14 * SIDE * wave(t, 1, 0.55), x=4 * UP * wave(t, 2, 0.6))
    return p


def walk(t):
    """Ползёт (0.8 сек): по телу бежит волна сжатия от хвоста к голове, тело изгибается змейкой,
    перед поднимается и опускается в такт."""
    p = base()
    s = wave(t, 1)
    p.add("Back", z=12 * SIDE * wave(t, 1, 0.5))
    p.add("Tail", z=-18 * SIDE * wave(t, 1, 0.65))
    p.add("Front", z=-10 * SIDE * s, x=6 * UP * wave(t, 2, 0.1))
    p.add("Neck", z=-6 * SIDE * wave(t, 1, -0.1), x=-4 * UP * wave(t, 2, 0.2))
    p.add("Head", z=8 * SIDE * wave(t, 1, -0.2))
    p.size("Mid", 1 + 0.06 * wave(t, 2, 0.25), 1 - 0.08 * wave(t, 2, 0.25), 1 + 0.06 * wave(t, 2, 0.25))
    p.move("Root", z=0.01 * abs(wave(t, 2)))
    return p


def attack(t):
    """Присосаться (0.8 сек): перед откидывается назад и вверх, пасть раскрыта → бросок вперёд и вниз
    (удар около 0.4 сек) → присоска пульсирует, тянет → отпускает и возвращается."""
    p = base()
    K = [0.0, 0.3, 0.45, 0.62, 0.78, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Front", x=UP * tr([0, 18, -12, -10, -6, 0]))
    p.add("Neck", x=UP * tr([0, 30, -30, -26, -14, 0]))
    p.add("Head", x=UP * tr([0, 20, -24, -20, -10, 0]), z=SIDE * tr([6, 0, 0, 0, 0, 6]) - 6 * SIDE)
    p.move("Root", y=tr([0, 0.06, -0.16, -0.14, -0.06, 0]))
    suck = pulse(t, 0.55, 0.06) + pulse(t, 0.68, 0.06)
    p.size("Head", tr([1, 1.15, 1.1, 1.0, 1.0, 1]) - 0.1 * suck)
    p.size("Mid", 1.0, tr([1, 0.92, 1.1, 1.06, 1.0, 1]), 1.0)
    p.add("Tail", x=UP * tr([0, -6, 8, 6, 2, 0]))
    return p


def hit(t):
    """Получил удар (0.47 сек): тело сжимается и отдёргивается назад, голова мотается с опозданием."""
    p = base()
    snap = track(t, [(0, 0), (0.15, 1), (0.45, 0.35), (1, 0)])
    whip = track(t, [(0, 0), (0.2, 0.3), (0.38, 1), (0.6, -0.4), (0.82, 0.1), (1, 0)])
    p.move("Root", y=0.05 * snap)
    p.size("Mid", 1 + 0.08 * snap, 1 - 0.12 * snap, 1 + 0.08 * snap)
    p.add("Front", x=UP * 12 * snap)
    p.add("Neck", x=UP * 18 * whip, z=SIDE * 10 * whip)
    p.add("Head", x=UP * 14 * whip)
    p.add("Tail", z=-SIDE * 20 * whip)
    return p


def death(t):
    """Гибель (1.4 сек): вздрагивает, перед заваливается набок, тело сворачивается дугой
    и опадает плашмя; в конце — короткая судорога хвоста."""
    p = base()
    K = [0.0, 0.15, 0.4, 0.7, 0.9, 1.0]

    def tr(vals):
        return track(t, list(zip(K, vals)))

    p.add("Front", x=UP * tr([0, 14, -10, -16, -16, -16]), z=SIDE * tr([0, 0, 20, 30, 30, 30]))
    p.add("Neck", x=UP * tr([0, 20, -20, -40, -42, -42]), z=SIDE * tr([0, 0, 18, 26, 26, 26]))
    p.add("Head", x=UP * tr([0, 10, -10, -20, -20, -20]))
    p.add("Back", z=SIDE * tr([0, 0, 18, 28, 28, 28]))
    twitch = pulse(t, 0.93, 0.04)
    p.add("Tail", z=SIDE * (tr([0, 0, 30, 40, 40, 40]) + 18 * twitch))
    p.add("Mid", y=tr([0, 0, 30, 70, 75, 75]))   # заваливается на бок (поворот вдоль тела)
    p.size("Mid", 1.0, 1.0, tr([1, 1.05, 0.9, 0.8, 0.78, 0.78]))
    p.move("Root", z=tr([0, 0.02, 0.0, -0.03, -0.04, -0.04]))
    return p


def build_actions(rig):
    k.bake(rig, "Idle", 90, idle, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=SCALED)
    k.bake(rig, "Attack", 24, attack, scale_bones=SCALED)
    k.bake(rig, "Hit", 14, hit, scale_bones=SCALED)
    k.bake(rig, "Death", 42, death, scale_bones=SCALED)


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
    glb = args[0] if args else os.path.join(here, "..", "leech.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "leech.blend")
    build(glb, blend)
