# Дождевая (~1.7 м) — Хранители Рощи, лесная ветка акта 1. Тело — grove_kin.py (длинная ряса вместо штанов).
# Высокая женщина в длинной серо-зелёной рясе с бурой лиственной накидкой, бледно-голубые ленты.
# Гладкая маска-капля орехового дерева, на лбу светится лист. Посох из живой ветви с моховым шаром
# наверху — с мха всё время капает вода, капли светятся голубым. Облик — claude/мир.md;
# референс Gemini 17 ноября (набор «А»). Смотрит в -Y.
#
# Анимации: Idle, Walk, Attack (Дождь: линия 4, лужа под целью), Attack2 (Гроза по мокрой цели), Hit, Death.
# Запуск: python3 build_grove_raincaller.py out/grove_raincaller.glb out/grove_raincaller.blend
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import Pose, wave, track, track3, pulse
import grove_kin as g
from mathutils import Vector

NAME = "GroveRaincaller"
g.setup(0.88, 0.97)
P = g.P

# Правая рука держит посох стоймя у плеча, левая поднята ладонью вверх.
SH_R, EL_R, WR_R = P(-0.24, 0.0, 1.33), P(-0.38, -0.04, 1.16), P(-0.36, -0.12, 1.34)
SH_L, EL_L, WR_L = P(0.24, 0.0, 1.33), P(0.36, -0.12, 1.16), P(0.3, -0.28, 1.24)
FIST_R = Vector(WR_R) + (Vector(WR_R) - Vector(EL_R)).normalized() * 0.05 * g.W
STAFF_A = Vector((FIST_R.x, FIST_R.y, 0.04))
STAFF_B = Vector((FIST_R.x + 0.02, FIST_R.y - 0.02, FIST_R.z + 0.66))
BALL = STAFF_B + Vector((0, 0, 0.08))


# ---------- Модель ----------

def build_mesh():
    M = g.materials("Raincaller")
    g.legs(M)
    g.robe(M)
    g.torso(M, skirt=False)
    g.arm_upper(M, "R", -1, SH_R, EL_R)
    g.arm_lower(M, "R", -1, EL_R, WR_R, fist_dir=(1, -0.3, 0))
    g.arm_upper(M, "L", 1, SH_L, EL_L)
    g.arm_lower(M, "L", 1, EL_L, WR_L, fist_dir=(0, -0.3, 1))
    g.hood_and_head(M)
    g.drop_mask(M)
    g.fur_mantle(M, big=0.95)
    g.vines(M, count=3)
    g.ribbons(M, [P(-0.12, -0.2, 0.9), P(0.1, -0.21, 0.9), P(0.2, -0.1, 0.9)], "FlapF", length=0.36)
    g.ribbons(M, [P(0.0, 0.21, 0.9), P(-0.16, 0.18, 0.9)], "FlapB", length=0.32)
    g.ribbons(M, [tuple(Vector(EL_L).lerp(Vector(WR_L), 0.5))], "ForeArm.L", length=0.2)

    # Посох (кость Staff): живая ветвь, моховой шар с травами наверху, листья
    n = 5
    pts = [STAFF_A.lerp(STAFF_B, i / n) + Vector((0.015 * math.sin(i * 2.1), 0.012 * math.cos(i * 1.7), 0)) for i in range(n + 1)]
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        k.limb(f"Staff{i}", tuple(a), tuple(b), 0.024 - 0.002 * i, 0.022 - 0.002 * i, M["wood"], "Staff", segs=6)
    k.sphere("MossBall", 0.12, tuple(BALL), M["moss"], "Staff", scale=(1.1, 1.1, 0.9), segs=7, rings=4)
    for i in range(7):
        a = math.tau * i / 7
        base = BALL + Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, 0.02))
        k.limb(f"Herb{i}", tuple(base), tuple(base + Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, 0.1 - 0.04 * (i % 2)))),
               0.022, 0.0, M["leaf"] if i % 2 else M["moss"], "Staff", segs=4)
    for i, h in enumerate((0.25, 0.5)):
        g.leaf_at(M, f"StaffLeaf{i}", tuple(STAFF_A.lerp(STAFF_B, 0.55 + h * 0.6)), "Staff", tilt=50 + 90 * i)
    # Капли (кость Drops смотрит вниз: её растяжение — капли «падают»)
    for i in range(6):
        a = math.tau * i / 6
        top = BALL + Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, -0.12 - 0.07 * (i % 3)))
        k.limb(f"Drop{i}", tuple(top), tuple(top + Vector((0, 0, -0.045))), 0.0, 0.018, M["drop"], "Drops", segs=4)
    return k.join_parts("GroveRaincallerMesh")


# ---------- Скелет ----------

BONES = g.bones(SH_R, EL_R, WR_R, SH_L, EL_L, WR_L, extra={
    "Staff": (tuple(FIST_R), tuple(FIST_R + Vector((0, 0, 0.2))), "Hand.R"),
    "Drops": (tuple(BALL - Vector((0, 0, 0.1))), tuple(BALL - Vector((0, 0, 0.4))), "Staff"),
})


# ---------- Анимации ----------
STANCE = dict(g.LEG_STANCE)
STANCE.update({"Spine": (2, -6, 0), "Chest": (-2, -4, 0), "Head": (-8, 8, 0),
               "Thigh.L": (-12, 0, -4), "Shin.L": (14, 0, 0), "Thigh.R": (4, 0, 6), "Shin.R": (8, 0, 0),
               "FlapF": (-4, 0, 0), "FlapB": (2, 0, 0)})
STANCE_LOC = {"Hips": (0, 0, -0.015)}


def stance():
    return Pose(STANCE, STANCE_LOC)


def drops(p, t, speed=3.0, amp=1.0):
    """Капли падают: кость тянется вниз и сбрасывается (несколько раз за анимацию)."""
    f = (t * speed) % 1.0
    p.size("Drops", 1.0, 1.0 + 1.6 * f * amp, 1.0)


def idle(t):
    """Покой (3.3 сек): спокойно дышит, левая ладонь покачивается, будто ловит дождь, капли падают с посоха.
    Характерное: поднимает лицо к небу и замирает."""
    p = stance()
    breath, sway = g.idle_body(p, t)
    sky = track(t, [(0, 0), (0.5, 0), (0.6, 1), (0.78, 1), (0.88, 0), (1, 0)])
    p.add("Head", x=-28 * sky + 8 * wave(t, 1, 0.2) * (1 - sky), y=10 * wave(t, 1, 0.45) * (1 - sky))
    p.add("UpperArm.L", x=-6 * wave(t, 1, 0.3) - 10 * sky, z=-8 * sky)
    p.add("Hand.L", x=8 * wave(t, 2, 0.1))
    p.add("Staff", x=2 * wave(t, 1, 0.15))
    drops(p, t, speed=3.0)
    return p


def walk(t):
    """Шаг (0.8 сек): плавный, ряса колышется, посох в такт."""
    p = Pose(STANCE, STANCE_LOC)
    a = g.walk_body(p, t)
    p.add("Thigh.R", x=6).add("Thigh.L", x=6)
    p.add("UpperArm.L", x=-8 * a)
    p.add("Staff", x=4 * wave(t, 2, 0.2))
    drops(p, t, speed=2.0)
    return p


def attack(t):
    """Дождь (0.8 сек): поднимает посох и наклоняет его к цели (к 0.4 сек) — капли срываются
    вперёд; левая рука указывает на цель."""
    p = stance()
    K = [0.0, 0.3, 0.5, 0.62, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("UpperArm.R", x=tr([0, -40, -70, -64, 0]), z=tr([0, 10, -6, -4, 0]))
    p.add("ForeArm.R", x=tr([0, -10, 20, 16, 0]))
    p.add("Staff", x=tr([0, -20, 40, 34, 0]))
    p.add("UpperArm.L", x=tr([0, -30, -70, -60, 0]))
    p.add("Spine", x=tr([0, -8, 10, 8, 0]))
    p.add("Head", x=tr([0, -10, 4, 2, 0]))
    drops(p, t, speed=1.0, amp=tr([1, 0.3, 2.5, 2.0, 1]))
    return p


def attack2(t):
    """Гроза (0.9 сек): вскидывает обе руки к небу, посох высоко → резко опускает посох вниз
    (к 0.4 сек), будто бьёт молнией."""
    p = stance()
    K = [0.0, 0.3, 0.46, 0.6, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("UpperArm.R", x=tr([0, -120, -60, -50, 0]), z=tr([0, 20, 10, 8, 0]))
    p.add("ForeArm.R", x=tr([0, 10, 30, 26, 0]))
    p.add("Staff", x=tr([0, 0, 50, 46, 0]))
    p.add("UpperArm.L", x=tr([0, -130, -40, -30, 0]), z=tr([0, -20, -10, -8, 0]))
    p.add("Spine", x=tr([0, -14, 14, 12, 0]))
    p.add("Head", x=tr([0, -30, 10, 8, 0]))
    p.move("Hips", z=tr([-0.015, 0.02, -0.06, -0.05, -0.015]))
    drops(p, t, speed=1.0, amp=tr([1, 0.2, 3.0, 2.0, 1]))
    return p


def hit(t):
    """Получила удар (0.5 сек): отшатнулась, посох качнулся, ленты взлетели."""
    p = stance()
    snap, whip = g.hit_body(p, t)
    p.add("UpperArm.R", x=14 * snap).add("UpperArm.L", x=24 * snap, z=-14 * snap)
    p.add("Staff", x=-14 * whip)
    drops(p, t)
    return p


def death(t):
    """Гибель (1.3 сек): посох выпал, опустилась на колени, ряса осела, упала набок; капли иссякли."""
    p = stance()
    K = [0.0, 0.2, 0.45, 0.75, 1.0]

    def tr(keys):
        return track(t, list(zip(K, keys)))

    p.add("Spine", x=tr([0, -14, 16, 22, 22]))
    p.add("Head", x=tr([0, -30, 20, 30, 30]), y=tr([0, 10, 0, 20, 24]))
    p.add("Thigh.L", x=tr([0, 6, -70, -40, -36])).add("Shin.L", x=tr([0, -6, 100, 70, 66]))
    p.add("Thigh.R", x=tr([0, -6, -64, -36, -32])).add("Shin.R", x=tr([0, 4, 110, 76, 70]))
    p.move("Hips", z=tr([-0.015, -0.02, -0.4, -0.45, -0.46]))
    p.set("Root", 0, 0, tr([0, 0, -6, -78, -84]))
    p.move("Root", x=tr([0, 0, 0, 0.3, 0.32]), z=tr([0, 0, 0, 0.1, 0.1]))
    p.add("UpperArm.R", x=tr([0, 20, 30, 10, 10]), z=tr([0, 10, 20, 30, 30]))
    p.add("Staff", x=tr([0, 30, 70, 90, 90]))
    p.add("UpperArm.L", x=tr([0, -20, 20, -30, -34]))
    p.add("FlapF", x=tr([0, -10, -50, -40, -40])).add("FlapB", x=tr([0, 0, 30, 20, 20]))
    p.size("Drops", 1.0, tr([1, 1.5, 0.6, 0.001, 0.001]), 1.0)
    p.add("ForeArm.L", x=-14 * pulse(t, 0.93, 0.04))
    return p


def build_actions(rig):
    sc = ("Drops",)
    k.bake(rig, "Idle", 100, idle, cyclic=True, scale_bones=sc)
    k.bake(rig, "Walk", 24, walk, cyclic=True, scale_bones=sc)
    k.bake(rig, "Attack", 24, attack, scale_bones=sc)
    k.bake(rig, "Attack2", 27, attack2, scale_bones=sc)
    k.bake(rig, "Hit", 15, hit, scale_bones=sc)
    k.bake(rig, "Death", 40, death, scale_bones=sc)


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
    glb = args[0] if args else os.path.join(here, "..", "grove_raincaller.glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, "grove_raincaller.blend")
    build(glb, blend)
