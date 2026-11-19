# Общие детали врагов акта 2 «Пепельный тракт»: материалы механизмов и вулкана, кольца клеток,
# ключевые позы. Подключается после char_kit (bpy уже загружен).
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import char_kit as k
from char_kit import track3
import bmesh
from mathutils import Vector, Matrix


def ring(name, big_r, small_r, loc, axis, material, bone, seg=12, minor=3):
    """Тонкое кольцо (тор) — прутья клетки, обручи. axis — ось, вокруг которой кольцо."""
    bm = bmesh.new()
    rows = []
    for i in range(seg):
        a = math.tau * i / seg
        c = Vector((math.cos(a), math.sin(a), 0))
        rows.append([bm.verts.new(c * (big_r + small_r * math.cos(math.tau * j / minor))
                                  + Vector((0, 0, small_r * math.sin(math.tau * j / minor))))
                     for j in range(minor)])
    for i in range(seg):
        r0, r1 = rows[i], rows[(i + 1) % seg]
        for j in range(minor):
            j1 = (j + 1) % minor
            bm.faces.new([r0[j], r1[j], r1[j1], r0[j1]])
    q = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
    return k._finish(bm, name, material, bone, Matrix.Translation(loc) @ q.to_matrix().to_4x4(), hard=1.0)


def caged_sphere(prefix, r, c, glass, cage, bone, segs=7, rings_=5, cage_bone=None):
    """Стеклянная сфера в клетке из трёх колец (горизонтальное + два вертикальных).
    cage_bone — своя кость для клетки (сфера может «лопнуть», а клетка остаться)."""
    cb = cage_bone or bone
    k.sphere(prefix + "Glass", r, c, glass, bone, segs=segs, rings=rings_)
    ring(prefix + "CageH", r * 1.04, r * 0.09, c, (0, 0, 1), cage, cb)
    ring(prefix + "CageF", r * 1.04, r * 0.08, c, (1, 0, 0), cage, cb)
    ring(prefix + "CageS", r * 1.04, r * 0.08, c, (0, 1, 0), cage, cb)


# ---------- Материалы ----------
# Механизмы лаборатории: тусклая бронза, чернёное железо (чуть светлее, чтобы не сливаться с плитами).
def mech_mats():
    return dict(
        bronze=k.mat("M_Bronze", (0.52, 0.42, 0.29), metallic=0.55, rough=0.55),
        bronze_d=k.mat("M_BronzeDark", (0.40, 0.32, 0.22), metallic=0.55, rough=0.6),
        iron=k.mat("M_Iron", (0.30, 0.30, 0.31), metallic=0.5, rough=0.65),
        iron_d=k.mat("M_IronDark", (0.21, 0.21, 0.22), metallic=0.5, rough=0.7),
        steel=k.mat("M_Steel", (0.50, 0.50, 0.49), metallic=0.6, rough=0.5),
        copper=k.mat("M_Copper", (0.64, 0.40, 0.25), metallic=0.6, rough=0.45),
        steam=k.mat("M_Steam", (0.88, 0.9, 0.9), rough=0.95),
        lens=k.mat("M_Lens", (0.30, 0.95, 0.85), rough=0.3, emit=1.8),        # бирюзовая линза
        lamp=k.mat("M_Lamp", (1.0, 0.86, 0.66), rough=0.4, emit=2.0),         # бело-оранжевый свет
        hot=k.mat("M_Hot", (1.0, 0.5, 0.12), rough=0.4, emit=1.6),            # раскалённое
        gauge=k.mat("M_Gauge", (0.80, 0.77, 0.66), rough=0.6),
        rift=k.mat("M_Rift", (0.30, 0.95, 0.85), rough=0.4, emit=1.8),
    )


# Стихии в сферах (подобраны по снимкам: огонь оранжевый, вода голубая, молния жёлтая, ветер серебристо-зелёный)
def element_mats():
    return {
        "fire": (k.mat("E_Fire", (0.95, 0.3, 0.04), rough=0.3, emit=1.0),
                 k.mat("E_FireCore", (1.0, 0.55, 0.14), rough=0.3, emit=1.5)),
        "water": (k.mat("E_Water", (0.28, 0.55, 1.0), rough=0.25, emit=0.85),
                  k.mat("E_WaterSwirl", (0.7, 0.9, 1.0), rough=0.25, emit=1.5)),
        "storm": (k.mat("E_Volt", (0.95, 0.86, 0.2), rough=0.25, emit=0.8),
                  k.mat("E_Bolt", (1.0, 0.96, 0.62), rough=0.25, emit=2.4)),
        "wind": (k.mat("E_Wind", (0.46, 0.70, 0.52), rough=0.3, emit=0.32),
                 k.mat("E_WindSwirl", (0.80, 0.92, 0.82), rough=0.3, emit=0.8)),
    }


def element_marks(prefix, kind, c, r, mat2, bone):
    """Знак стихии внутри сферы (на передней стороне): молния — зигзаг, вода и ветер — завиток, огонь — язык."""
    o = (c[0], c[1] - r * 0.86, c[2])
    if kind == "storm":
        pts = [(-0.5, 0.5), (-0.1, 0.1), (-0.3, -0.05), (0.25, -0.5), (0.1, -0.15), (0.45, -0.3)]
    elif kind == "fire":
        pts = [(-0.3, -0.5), (-0.1, 0.1), (0.0, -0.1), (0.15, 0.5)]
    else:
        pts = [(-0.5, -0.1), (-0.2, 0.3), (0.25, 0.25), (0.45, -0.15), (0.1, -0.4)]
    k.crack(prefix + "Mark", [(x * r * 0.7, y * r * 0.7) for x, y in pts], o, (1, 0, 0), (0, 0, 1), mat2, bone,
            width=r * 0.1, depth=r * 0.08)


# Вулкан и пепел: шлак, базальт, пепел, лава
def volcano_mats():
    return dict(
        slag=k.mat("V_Slag", (0.24, 0.23, 0.24), metallic=0.2, rough=0.5),      # стеклянистый чёрный шлак (светлее)
        basalt=k.mat("V_Basalt", (0.34, 0.33, 0.33), rough=0.85),
        ash=k.mat("V_Ash", (0.52, 0.51, 0.50), rough=0.95),
        ash_d=k.mat("V_AshDark", (0.36, 0.35, 0.35), rough=0.95),
        burnt=k.mat("V_Burnt", (0.36, 0.27, 0.20), rough=0.9),
        lava=k.mat("V_Lava", (1.0, 0.36, 0.04), rough=0.4, emit=1.05),
        ember=k.mat("V_Ember", (1.0, 0.5, 0.12), rough=0.4, emit=1.5),
        rift=k.mat("V_Rift", (0.30, 0.95, 0.85), rough=0.4, emit=1.8),
        sulfur=k.mat("V_Sulfur", (0.56, 0.49, 0.32), rough=0.9),               # грязная охра
        steam=k.mat("V_Steam", (0.86, 0.88, 0.88), rough=0.95),
    )


def keyed(p, t, K, stance, bone, *keys):
    """Поза кости по ключам: стойка → keys[0] → ... → стойка (времена K, первый и последний — стойка)."""
    s = stance.get(bone, (0, 0, 0))
    p.set(bone, *track3(t, [(K[0], s)] + list(zip(K[1:-1], keys)) + [(K[-1], s)]))


def keyed_end(p, t, K, stance, bone, *keys):
    """То же, но без возврата в стойку (для гибели): ключей на один больше."""
    s = stance.get(bone, (0, 0, 0))
    p.set(bone, *track3(t, [(K[0], s)] + list(zip(K[1:], keys))))


def main(build, default_name):
    here = os.path.dirname(os.path.abspath(__file__))
    args = [a for a in sys.argv[1:] if a.endswith((".glb", ".blend"))]
    glb = args[0] if args else os.path.join(here, "..", default_name + ".glb")
    blend = args[1] if len(args) > 1 else os.path.join(here, default_name + ".blend")
    build(glb, blend)


def rock(name, size, loc, material, bone, rot=(0, 0, 0), seed=0):
    """Каменная глыба: гранёная икосфера размером size (как у k.box), чуть неровная —
    для шлака, базальта, камня. Рёбра жёсткие, чтобы читалась как камень."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.5)
    for i, vtx in enumerate(bm.verts):
        n = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453
        j = (n - math.floor(n)) * 0.22 - 0.11
        vtx.co *= 1.0 + j
    m = Matrix.Translation(loc) @ k._rot(rot) @ Matrix.Diagonal((size[0] * 1.35, size[1] * 1.35, size[2] * 1.35, 1.0))
    return k._finish(bm, name, material, bone, m, hard=1.0)
