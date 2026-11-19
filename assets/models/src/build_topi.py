# Набор моделей «Гнилые топи»: плиты, объекты на клетках, декор вокруг арены.
# Запуск:  python build_topi.py <папка для .glb> <путь для .blend>
# (нужен модуль bpy; в самом Blender: Scripting → Open → Run Script, пути поправить внизу)
#
# Правила стиля (из claude/мир.md): low-poly, однотонные материалы, без красного,
# 1 единица = 1 метр = 1 клетка, origin — в центре клетки на уровне земли.
import bpy, bmesh, math, random, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stylize   # запекание стилизации в текстуру (тени, кромки, градиент)
from mathutils import Matrix, Vector, Euler


def srgb(c):
    """Цвет «как на экране» -> линейный (так его хранит Blender)."""
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# --- Палитра: холодные приглушённые тона, яркое — только свечение ---
STONE = (0.30, 0.33, 0.33)
STONE_D = (0.22, 0.25, 0.25)
STONE_L = (0.37, 0.40, 0.38)
MOSS = (0.21, 0.30, 0.16)
MOSS_L = (0.29, 0.38, 0.19)
MUD = (0.26, 0.22, 0.16)
MUD_W = (0.18, 0.16, 0.13)
BOG = (0.06, 0.09, 0.07)
DUCKWEED = (0.17, 0.25, 0.12)
WOOD_ROT = (0.31, 0.26, 0.20)
WOOD_D = (0.21, 0.17, 0.13)
WOOD_F = (0.52, 0.42, 0.28)
DEAD = (0.40, 0.37, 0.33)
DEAD_D = (0.28, 0.26, 0.24)
REED = (0.52, 0.54, 0.28)
REED_D = (0.36, 0.40, 0.20)
CATTAIL = (0.27, 0.19, 0.12)
IRON = (0.20, 0.21, 0.23)
STEEL = (0.47, 0.49, 0.52)
CLOTH = (0.50, 0.40, 0.14)      # тёмно-жёлтый Стражи
ROPE = (0.45, 0.39, 0.28)
BONE = (0.72, 0.69, 0.60)
ICE = (0.72, 0.90, 1.0)
GAS = (0.42, 0.9, 0.25)        # болотный газ
RIFT = (0.2, 0.85, 0.75)       # бирюза Раскола
LAMP = (1.0, 0.72, 0.32)        # тёплый огонь фонаря

_mats = {}


def material(color, emit=0.0, rough=0.9, metal=0.0):
    key = (color, emit, rough, metal)
    if key not in _mats:
        m = bpy.data.materials.new("Topi_%02d" % len(_mats))
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        lin = srgb(color) + (1.0,)
        bsdf.inputs["Base Color"].default_value = lin
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        if emit > 0:
            bsdf.inputs["Emission Color"].default_value = lin
            bsdf.inputs["Emission Strength"].default_value = emit
        _mats[key] = m
    return _mats[key]


class Model:
    """Одна модель: набор простых фигур, склеенных в один меш."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.slots = []
        self.rnd = random.Random(name)

    def _slot(self, color, **kw):
        m = material(color, **kw)
        if m not in self.slots:
            self.slots.append(m)
        return self.slots.index(m)

    def _place(self, verts, pos, rot, slot, scale=(1, 1, 1)):
        mat = Matrix.Translation(Vector(pos)) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() \
            @ Matrix.Diagonal(Vector(scale + (1,)))
        bmesh.ops.transform(self.bm, matrix=mat, verts=verts)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = slot

    def box(self, size, pos, color, rot=(0, 0, 0), **kw):
        """Брусок. pos — центр."""
        r = bmesh.ops.create_cube(self.bm, size=1.0)
        self._place(r["verts"], pos, rot, self._slot(color, **kw), tuple(size))

    def cyl(self, r1, r2, h, pos, color, rot=(0, 0, 0), seg=6, **kw):
        """Цилиндр/конус. r1 — радиус низа, r2 — верха. pos — центр основания (вращается вокруг него)."""
        r = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=True, segments=seg,
                                  radius1=r1, radius2=max(r2, 0.0001), depth=h)
        bmesh.ops.translate(self.bm, verts=r["verts"], vec=(0, 0, h / 2))
        self._place(r["verts"], pos, rot, self._slot(color, **kw))

    def prism(self, pts, z0, z1, color, chamfer=0.0, **kw):
        """Призма по многоугольнику pts (x, y против часовой) от z0 до z1, верхнее ребро скошено на chamfer."""
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        n = len(pts)

        def inset(p, d):
            dx, dy = cx - p[0], cy - p[1]
            ln = math.hypot(dx, dy) or 1.0
            return (p[0] + dx / ln * d, p[1] + dy / ln * d)

        bot = [self.bm.verts.new((x, y, z0)) for x, y in pts]
        mid = [self.bm.verts.new((x, y, z1 - chamfer)) for x, y in pts]
        top = [self.bm.verts.new((*inset(p, chamfer * 1.3), z1)) for p in pts]
        faces = [self.bm.faces.new(list(reversed(bot))), self.bm.faces.new(top)]
        for i in range(n):
            j = (i + 1) % n
            faces.append(self.bm.faces.new((bot[i], bot[j], mid[j], mid[i])))
            if chamfer > 0:
                faces.append(self.bm.faces.new((mid[i], mid[j], top[j], top[i])))
        slot = self._slot(color, **kw)
        for f in faces:
            f.material_index = slot

    def blob(self, r, pos, color, scale=(1, 1, 1), jit=0.12, rot=(0, 0, 0), **kw):
        """Неровный камень/кочка: икосфера со сдвинутыми вершинами."""
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=1, radius=r)
        for v in res["verts"]:
            v.co += Vector([self.rnd.uniform(-jit, jit) * r for _ in range(3)])
        self._place(res["verts"], pos, rot, self._slot(color, **kw), tuple(scale))

    def finish(self):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0001)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.slots:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


MODELS = {}


def model(fn):
    MODELS[fn.__name__] = fn
    return fn


# ======================= ПЛИТЫ (верх на высоте 0) =======================

def slab(m, color, top=0.0):
    m.box((0.96, 0.96, 0.2), (0, 0, top - 0.1), color)


@model
def tile_stone_a(m):
    """Цельная плита с трещиной и сколом."""
    slab(m, STONE)
    m.box((0.5, 0.03, 0.01), (-0.1, 0.12, 0.002), STONE_D, rot=(0, 0, 24))
    m.box((0.3, 0.03, 0.01), (0.2, -0.05, 0.002), STONE_D, rot=(0, 0, -38))
    m.box((0.2, 0.2, 0.06), (0.4, 0.4, -0.01), STONE_D, rot=(0, 0, 45))


@model
def tile_stone_b(m):
    """Четыре брусчатых камня разной высоты."""
    m.box((0.96, 0.96, 0.16), (0, 0, -0.12), STONE_D)
    for i, (x, y) in enumerate([(-0.24, -0.24), (0.24, -0.24), (-0.24, 0.24), (0.24, 0.24)]):
        h = [0.0, -0.015, -0.01, 0.0][i]
        m.box((0.44, 0.44, 0.08), (x, y, -0.04 + h), [STONE, STONE_L, STONE, STONE_D][i],
              rot=(0, 0, m.rnd.uniform(-2, 2)))


@model
def tile_moss(m):
    """Плита, заросшая мхом, с пучками травы."""
    slab(m, STONE_D)
    m.blob(0.3, (-0.18, 0.15, -0.01), MOSS, scale=(1.1, 0.9, 0.08))
    m.blob(0.22, (0.22, -0.2, -0.01), MOSS_L, scale=(1, 1.2, 0.08))
    m.blob(0.14, (0.3, 0.3, -0.01), MOSS, scale=(1, 1, 0.1))
    for x, y in [(-0.3, 0.3), (-0.25, 0.36), (0.36, -0.3)]:
        m.cyl(0.02, 0, 0.14, (x, y, 0), MOSS_L, rot=(m.rnd.uniform(-15, 15), m.rnd.uniform(-15, 15), 0), seg=3)


@model
def tile_mud(m):
    """Грязь: тёмная земля, мокрые пятна, пара камешков."""
    slab(m, MUD)
    m.blob(0.28, (0.1, 0.12, -0.005), MUD_W, scale=(1.2, 0.9, 0.05))
    m.blob(0.16, (-0.26, -0.24, -0.005), MUD_W, scale=(1, 1.3, 0.06))
    m.blob(0.05, (-0.3, 0.3, 0.01), STONE_D, scale=(1, 1, 0.6))
    m.blob(0.035, (0.32, -0.3, 0.008), STONE, scale=(1, 1, 0.6))
    m.cyl(0.018, 0, 0.12, (0.35, 0.33, 0), REED_D, rot=(10, -8, 0), seg=3)


@model
def tile_planks(m):
    """Гать: настил из брёвен, уложенных поперёк."""
    m.box((0.96, 0.96, 0.1), (0, 0, -0.15), MUD_W)
    for i in range(5):
        y = -0.384 + i * 0.192
        col = [WOOD_ROT, WOOD_D, WOOD_ROT, WOOD_ROT, WOOD_D][i]
        m.cyl(0.095, 0.09, 0.94 - m.rnd.uniform(0, 0.06), (-0.47, y, -0.09), col,
              rot=(0, 90, m.rnd.uniform(-1.5, 1.5)), seg=6)


# ======================= ШЕСТИУГОЛЬНЫЕ ПЛИТЫ (верх на высоте 0) =======================
# Соты «острым углом вверх»: углы шестиугольника на ±Y в Blender (это ±Z в Godot).
# Радиус = HexMath.HEX_SIZE × Board.TILE_GAP = 0.664 × 0.97. Толщина 0.2, как у призм в board.gd.
HEX_R = 1.15 / math.sqrt(3) * 0.97
BASALT = (0.21, 0.20, 0.20)
BASALT_D = (0.15, 0.14, 0.14)
PEAT = (0.27, 0.19, 0.13)
PEAT_D = (0.20, 0.14, 0.10)


def hex_pts(r, rot=0.0):
    return [(r * math.cos(math.radians(90 + 60 * k + rot)), r * math.sin(math.radians(90 + 60 * k + rot))) for k in range(6)]


def hex_base(m, color, top=0.0, chamfer=0.035):
    m.prism(hex_pts(HEX_R), top - 0.2, top, color, chamfer=chamfer)


@model
def tile_hex_stone_a(m):
    """Цельная каменная плита со скошенной кромкой, трещиной и сколом."""
    hex_base(m, STONE)
    m.box((0.46, 0.028, 0.012), (-0.08, 0.1, 0.0), STONE_D, rot=(0, 0, 24))
    m.box((0.26, 0.028, 0.012), (0.18, -0.06, 0.0), STONE_D, rot=(0, 0, -38))
    m.box((0.16, 0.16, 0.05), (0.36, 0.3, -0.015), STONE_D, rot=(0, 0, 30))


@model
def tile_hex_stone_b(m):
    """Второй камень: плита потемнее с длинным расколом и пятном мха.
    Плита цельная, раскол — тёмная полоса: куски из отдельных многоугольников издалека «веерили»."""
    hex_base(m, STONE_D)
    m.box((0.95, 0.03, 0.012), (0.02, 0.02, 0.0), (0.16, 0.18, 0.18), rot=(0, 0, 4))
    m.box((0.2, 0.025, 0.012), (0.12, 0.26, 0.0), (0.16, 0.18, 0.18), rot=(0, 0, -20))
    m.blob(0.07, (-0.3, -0.25, -0.01), MOSS, scale=(1.3, 1, 0.12))

@model
def tile_hex_moss(m):
    """Плита, заросшая мхом: моховой ковёр почти на всю плиту, по краю видно камень, пучки травы.
    Мох должен читаться издалека — по нему видно, где роща."""
    hex_base(m, STONE_D)
    m.prism(hex_pts(HEX_R - 0.07, 8), -0.05, 0.012, MOSS, chamfer=0.03)
    m.blob(0.2, (-0.12, 0.12, 0.004), MOSS_L, scale=(1.2, 0.9, 0.08))
    m.blob(0.15, (0.2, -0.16, 0.004), MOSS_L, scale=(1, 1.2, 0.08))
    m.blob(0.06, (0.3, 0.18, 0.01), STONE_D, scale=(1.2, 1, 0.5))   # камень проглядывает
    for x, y in [(-0.28, 0.24), (-0.22, 0.3), (0.3, -0.24), (0.05, 0.36)]:
        m.cyl(0.02, 0, 0.14, (x, y, 0.01), MOSS_L, rot=(m.rnd.uniform(-15, 15), m.rnd.uniform(-15, 15), 0), seg=3)


@model
def tile_hex_mud(m):
    """Грязь: тёмная земля, мокрые пятна, пара камешков. Ниже камня на 2 см."""
    hex_base(m, MUD, top=-0.02, chamfer=0.05)
    m.blob(0.27, (0.08, 0.1, -0.025), MUD_W, scale=(1.2, 0.9, 0.05), rough=0.35)
    m.blob(0.15, (-0.24, -0.2, -0.025), MUD_W, scale=(1, 1.3, 0.06), rough=0.35)
    m.blob(0.05, (-0.28, 0.24, -0.01), STONE_D, scale=(1, 1, 0.6))
    m.blob(0.035, (0.3, -0.26, -0.012), STONE, scale=(1, 1, 0.6))
    m.cyl(0.018, 0, 0.12, (0.32, 0.26, -0.02), REED_D, rot=(10, -8, 0), seg=3)


@model
def tile_hex_planks(m):
    """Гать: брёвна поперёк, обрезаны по форме соты, под ними грязь."""
    hex_base(m, MUD_W, top=-0.12, chamfer=0.0)
    for i in range(6):
        y = -0.48 + i * 0.192
        half = HEX_R * math.sqrt(3) / 2   # полуширина соты на этой высоте
        if abs(y) > HEX_R / 2:
            half *= (HEX_R - abs(y)) / (HEX_R / 2)
        ln = max(half * 2 - 0.06 - m.rnd.uniform(0, 0.05), 0.15)
        col = [WOOD_ROT, WOOD_D, WOOD_ROT, WOOD_ROT, WOOD_D, WOOD_ROT][i]
        m.cyl(0.092, 0.088, ln, (-ln / 2, y, -0.09), col, rot=(0, 90, m.rnd.uniform(-1.5, 1.5)), seg=6)


@model
def tile_hex_basalt(m):
    """Тлеющая пещера: столбы базальта разной высоты."""
    m.prism(hex_pts(HEX_R), -0.2, -0.05, BASALT_D)
    m.prism(hex_pts(0.3, 10), -0.1, 0.0, BASALT, chamfer=0.025)
    for k, h in zip(range(0, 6, 2), (-0.012, -0.004, -0.02)):
        a = math.radians(90 + 60 * k + 30)
        m.prism([(x + 0.37 * math.cos(a), y + 0.37 * math.sin(a)) for x, y in hex_pts(0.21, 20 * k)],
                -0.1, h, [BASALT_D, BASALT, BASALT][k // 2], chamfer=0.02)


@model
def tile_hex_peat(m):
    """Торф: бурая волокнистая земля с комьями (на нём снова вспыхивает огонь)."""
    hex_base(m, PEAT, top=-0.01, chamfer=0.05)
    for i in range(6):
        a = math.radians(30 + 60 * i + m.rnd.uniform(-15, 15))
        rr = m.rnd.uniform(0.15, 0.38)
        m.blob(m.rnd.uniform(0.06, 0.1), (rr * math.cos(a), rr * math.sin(a), -0.015), PEAT_D if i % 2 else PEAT,
               scale=(1.2, 1, 0.45), jit=0.3)
    for i in range(4):
        a = m.rnd.uniform(0, 6.28)
        m.box((0.22, 0.012, 0.01), (0.2 * math.cos(a), 0.2 * math.sin(a), -0.008), PEAT_D, rot=(0, 0, math.degrees(a) + 70))


# ---- Дополнительные варианты плит: чтобы одинаковые клетки не повторялись «под копирку».
# board.gd берёт вариант по клетке (TILE_MODELS — списки). Цвета те же, что у основных плит,
# чтобы вид покрытия читался одинаково.

@model
def tile_hex_stone_c(m):
    """Плита с двумя почти параллельными расколами и мхом в одном из них."""
    hex_base(m, STONE)
    m.box((0.9, 0.028, 0.012), (0.0, -0.2, 0.0), STONE_D, rot=(0, 0, 8))
    m.box((0.85, 0.028, 0.012), (0.0, 0.15, 0.0), STONE_D, rot=(0, 0, -6))
    m.box((0.18, 0.04, 0.014), (-0.2, 0.17, 0.0), MOSS, rot=(0, 0, -6))
    m.blob(0.03, (0.3, -0.05, 0.0), STONE_L, scale=(1, 1, 0.6))

@model
def tile_hex_stone_d(m):
    """Цельная плита: трава в трещине, мокрое пятно, пара камешков."""
    hex_base(m, STONE)
    m.box((0.5, 0.03, 0.012), (0.05, -0.05, 0.0), STONE_D, rot=(0, 0, -15))
    for x in (-0.15, 0.0, 0.14):
        m.cyl(0.015, 0, 0.1, (x, -0.05 + x * -0.27, 0.0), MOSS_L, rot=(m.rnd.uniform(-20, 20), m.rnd.uniform(-20, 20), 0), seg=3)
    m.blob(0.16, (-0.2, 0.22, -0.003), STONE_D, scale=(1.3, 1, 0.03), rough=0.35)   # сырое пятно
    m.blob(0.035, (0.3, 0.2, 0.0), STONE_L, scale=(1, 1, 0.6))
    m.blob(0.028, (0.24, 0.27, 0.0), STONE_D, scale=(1, 1, 0.6))


@model
def tile_hex_stone_e(m):
    """Плита с косым расколом и отбитым углом, на сколе мох."""
    hex_base(m, STONE)
    m.box((0.75, 0.03, 0.012), (0.08, 0.05, 0.0), STONE_D, rot=(0, 0, 55))
    m.box((0.2, 0.18, 0.05), (-0.36, -0.22, -0.02), STONE_D, rot=(0, 0, 30))
    m.blob(0.08, (-0.33, -0.2, 0.0), MOSS, scale=(1.4, 0.8, 0.15))

@model
def tile_hex_moss_b(m):
    """Камень, мох наполз с одного края; кочка травы."""
    hex_base(m, STONE)
    m.prism([(x, y) for x, y in hex_pts(HEX_R - 0.05)[1:5]] + [(0.1, -0.05)], -0.05, 0.012, MOSS, chamfer=0.025)
    m.blob(0.12, (-0.25, 0.0, 0.005), MOSS_L, scale=(1.2, 1, 0.4))
    for i in range(5):
        m.cyl(0.018, 0, m.rnd.uniform(0.1, 0.18), (-0.25 + m.rnd.uniform(-0.06, 0.06), m.rnd.uniform(-0.06, 0.06), 0.02),
              MOSS_L, rot=(m.rnd.uniform(-25, 25), m.rnd.uniform(-25, 25), 0), seg=3)


@model
def tile_hex_moss_c(m):
    """Сплошной мох буграми, сквозь него торчит угол старой плиты."""
    hex_base(m, MOSS)
    for i in range(5):
        a = math.radians(60 * i + m.rnd.uniform(-20, 20))
        rr = m.rnd.uniform(0.12, 0.35)
        m.blob(m.rnd.uniform(0.1, 0.16), (rr * math.cos(a), rr * math.sin(a), -0.02), MOSS_L if i % 2 else MOSS,
               scale=(1.3, 1.1, 0.25), jit=0.25)
    m.box((0.22, 0.18, 0.06), (0.22, -0.25, -0.01), STONE, rot=(4, -6, 25))


@model
def tile_hex_mud_b(m):
    """Грязь с корнями и мокрой колеёй."""
    hex_base(m, MUD, top=-0.02, chamfer=0.05)
    m.box((0.85, 0.12, 0.01), (0.0, 0.08, -0.022), MUD_W, rot=(0, 0, 8), rough=0.35)   # колея
    m.cyl(0.03, 0.012, 0.5, (-0.3, -0.2, -0.02), WOOD_D, rot=(88, 0, 70), seg=4)      # корень
    m.cyl(0.02, 0.008, 0.3, (0.1, -0.3, -0.02), WOOD_D, rot=(88, 0, 130), seg=4)
    m.blob(0.04, (0.3, 0.3, -0.01), STONE_D, scale=(1, 1, 0.6))


@model
def tile_hex_mud_c(m):
    """Грязь, пучки осоки и россыпь камешков."""
    hex_base(m, MUD, top=-0.02, chamfer=0.05)
    m.blob(0.2, (-0.15, -0.1, -0.025), MUD_W, scale=(1.1, 1.3, 0.05), rough=0.35)
    for x, y in [(0.25, 0.2), (0.3, 0.13), (-0.3, 0.3)]:
        m.cyl(0.018, 0, 0.16, (x, y, -0.02), REED_D, rot=(m.rnd.uniform(-20, 20), m.rnd.uniform(-20, 20), 0), seg=3)
    for i in range(5):
        m.blob(0.025, (m.rnd.uniform(-0.3, 0.3), m.rnd.uniform(-0.3, 0.3), -0.015), STONE_D, scale=(1, 1, 0.6))


def planks_row(m, broken=None, moss=None, tilt=1.5):
    hex_base(m, MUD_W, top=-0.12, chamfer=0.0)
    for i in range(6):
        y = -0.48 + i * 0.192
        half = HEX_R * math.sqrt(3) / 2
        if abs(y) > HEX_R / 2:
            half *= (HEX_R - abs(y)) / (HEX_R / 2)
        ln = max(half * 2 - 0.06 - m.rnd.uniform(0, 0.05), 0.15)
        x0 = -ln / 2
        if broken == i:   # бревно сломано: кусок короче, второй утоп ниже
            m.cyl(0.085, 0.08, ln * 0.45, (x0 + ln * 0.55, y, -0.13), WOOD_D, rot=(0, 90, 3), seg=6)
            ln *= 0.5
        col = [WOOD_ROT, WOOD_D, WOOD_ROT, WOOD_ROT, WOOD_D, WOOD_ROT][(i + 1) % 6]
        m.cyl(0.092, 0.088, ln, (x0, y, -0.09), col, rot=(0, 90, m.rnd.uniform(-tilt, tilt)), seg=6)
        if moss == i:
            m.blob(0.07, (x0 + ln * 0.3, y, -0.0), MOSS, scale=(1.6, 0.8, 0.3))


@model
def tile_hex_planks_b(m):
    """Гать: одно бревно сломано, на другом мох."""
    planks_row(m, broken=2, moss=4)


@model
def tile_hex_planks_c(m):
    """Гать: брёвна лежат неровно, перетянуты верёвкой."""
    planks_row(m, moss=1, tilt=4.0)
    for x in (-0.3, 0.32):
        m.box((0.03, 1.0, 0.02), (x, 0.0, 0.0), ROPE)


@model
def tile_hex_basalt_b(m):
    """Базальт: один широкий столб и мелкие рядом, в щелях пепел."""
    m.prism(hex_pts(HEX_R), -0.2, -0.05, BASALT_D)
    m.prism(hex_pts(0.36, 5), -0.1, -0.004, BASALT, chamfer=0.025)
    for k in (1, 4):
        a = math.radians(90 + 60 * k + 30)
        m.prism([(x + 0.43 * math.cos(a), y + 0.43 * math.sin(a)) for x, y in hex_pts(0.15, 15 * k)],
                -0.1, -0.02, BASALT_D, chamfer=0.02)
    m.blob(0.06, (0.32, 0.1, -0.04), (0.35, 0.33, 0.31), scale=(1.5, 1, 0.2))


@model
def tile_hex_peat_b(m):
    """Торф с пучками сухой травы и тёмными мокрыми пятнами."""
    hex_base(m, PEAT, top=-0.01, chamfer=0.05)
    m.blob(0.18, (0.15, -0.1, -0.012), PEAT_D, scale=(1.3, 1, 0.08))
    for cx, cy in [(-0.25, 0.15), (0.2, 0.28)]:
        for i in range(5):
            m.cyl(0.015, 0, m.rnd.uniform(0.1, 0.16), (cx + m.rnd.uniform(-0.05, 0.05), cy + m.rnd.uniform(-0.05, 0.05), 0.0),
                  REED_D, rot=(m.rnd.uniform(-30, 30), m.rnd.uniform(-30, 30), 0), seg=3)


# ======================= ОБЪЕКТЫ НА КЛЕТКАХ =======================

def bog_base(m):
    """Основа трясины по форме соты: чёрная вода в грязевом бортике."""
    m.prism(hex_pts(HEX_R - 0.035), -0.04, 0.02, BOG, rough=0.15)
    m.prism(hex_pts(HEX_R), -0.2, 0.0, MUD_W, chamfer=0.03)


@model
def bog_rim_a(m):
    """Бортик трясины на одну сторону соты (вдоль X, длина чуть больше стороны).
    -Y — сторона суши (плита), +Y — сторона воды. board.gd ставит его только туда,
    где соседняя клетка — не трясина, поэтому соседние трясины сливаются в одно болото."""
    m.blob(0.2, (0.0, -0.02, -0.035), MUD_W, scale=(2.0, 0.55, 0.28), jit=0.2)
    m.blob(0.16, (0.12, 0.06, -0.06), MUD, scale=(1.9, 0.5, 0.18), jit=0.25)
    m.blob(0.05, (-0.22, 0.02, -0.01), STONE_D, scale=(1.2, 1, 0.6))
    m.cyl(0.016, 0, 0.14, (0.25, -0.02, -0.01), REED_D, rot=(12, -8, 0), seg=3)


@model
def bog_rim_b(m):
    """Бортик трясины, второй вид: ниже, с мхом и корнем."""
    m.blob(0.19, (0.0, -0.02, -0.04), MUD_W, scale=(2.05, 0.5, 0.24), jit=0.25)
    m.blob(0.12, (-0.15, -0.03, -0.02), MOSS, scale=(1.8, 0.6, 0.2), jit=0.2)
    m.cyl(0.025, 0.01, 0.3, (0.1, -0.03, -0.02), WOOD_D, rot=(80, 0, 100), seg=4)


# ---- Стыки и переходы покрытий (board.gd ставит их между плитами) ----
# Шов вдоль X на y = 0, длина — сторона соты (~0.66 м). -Y — сторона соседней клетки.
MOSS_D = (0.16, 0.23, 0.12)


@model
def joint_moss(m):
    """Стык двух клеток мха: моховая полоса поверх щели, плиты сливаются в одну поляну.
    Тонкая тёмная линия посередине — чтобы клетки всё равно считались."""
    m.blob(0.3, (0.0, 0.0, 0.004), MOSS, scale=(1.12, 0.3, 0.05), jit=0.15)
    m.blob(0.1, (-0.18, 0.04, 0.01), MOSS_L, scale=(1.4, 0.7, 0.12), jit=0.2)
    m.blob(0.08, (0.2, -0.03, 0.01), MOSS_L, scale=(1.3, 0.8, 0.12), jit=0.2)
    m.box((0.56, 0.008, 0.004), (0.0, 0.0, 0.017), MOSS_D)


@model
def joint_mud(m):
    """Стык двух клеток грязи: грязь заливает щель, мокрое пятно, тонкая линия сетки."""
    m.blob(0.3, (0.0, 0.0, -0.02), MUD, scale=(1.12, 0.3, 0.05), jit=0.15)
    m.blob(0.09, (0.12, 0.02, -0.012), MUD_W, scale=(1.5, 0.8, 0.08), rough=0.35)
    m.box((0.56, 0.008, 0.004), (0.0, 0.0, -0.006), MUD_W)


def _edge_patch(m, colors, z, pebbles=0, grass=0):
    """Пятна вдоль края плиты, наползающие с соседней клетки (-Y — сосед)."""
    for i, x in enumerate((-0.22, -0.05, 0.13, 0.26)):
        r = m.rnd.uniform(0.07, 0.11)
        y = m.rnd.uniform(-0.02, 0.06)
        m.blob(r, (x, y, z), colors[i % len(colors)], scale=(1.5, m.rnd.uniform(0.7, 1.2), 0.1), jit=0.25)
    for i in range(pebbles):
        m.blob(0.025, (m.rnd.uniform(-0.25, 0.25), m.rnd.uniform(0.0, 0.12), z), STONE_D, scale=(1, 1, 0.6))
    for i in range(grass):
        m.cyl(0.015, 0, m.rnd.uniform(0.08, 0.14), (m.rnd.uniform(-0.2, 0.2), m.rnd.uniform(0.0, 0.08), z),
              MOSS_L, rot=(m.rnd.uniform(-25, 25), m.rnd.uniform(-25, 25), 0), seg=3)


@model
def edge_moss_a(m):
    """Мох с соседней клетки наползает на край каменной плиты."""
    _edge_patch(m, [MOSS, MOSS_L], 0.004, grass=2)


@model
def edge_moss_b(m):
    _edge_patch(m, [MOSS_L, MOSS, MOSS], 0.004, pebbles=1)


@model
def edge_mud_a(m):
    """Грязь с соседней клетки размазана по краю плиты."""
    _edge_patch(m, [MUD, MUD_W], 0.002, pebbles=2)


@model
def edge_mud_b(m):
    _edge_patch(m, [MUD_W, MUD, MUD], 0.002, grass=1)


def hex_half_height(x):
    """Сколько места по Y у соты на расстоянии x от центра (доски не должны вылезать за край)."""
    return max(HEX_R - abs(x) / math.sqrt(3), 0.0)


@model
def obj_bog(m):
    """Трясина: чёрная вода, кочки, ряска, пузырь газа."""
    # вода трясины и бортик рисуются в board.gd — общие для соседних клеток трясины
    m.blob(0.13, (0.26, -0.22, 0.03), MOSS, scale=(1.2, 1, 0.45))
    m.blob(0.09, (-0.3, 0.26, 0.03), MOSS_L, scale=(1, 1.2, 0.5))
    for x, y, r in [(-0.1, -0.05, 0.07), (0.05, 0.25, 0.05), (-0.28, -0.3, 0.045), (0.3, 0.12, 0.04)]:
        m.cyl(r, r, 0.006, (x, y, 0.021), DUCKWEED, seg=5)
    for dx in (-0.03, 0.02, 0.05):
        m.cyl(0.012, 0, 0.2, (0.26 + dx, -0.22 + dx, 0.06), REED_D, rot=(dx * 300, -dx * 250, 0), seg=3)
    m.blob(0.03, (0.02, -0.28, 0.025), GAS, scale=(1, 1, 0.6), jit=0, emit=1.2)


@model
def obj_planks(m):
    """Гнилые мостки: три кривые доски, одна уже треснула."""
    # вода трясины и бортик рисуются в board.gd — общие для соседних клеток трясины
    m.box((0.24, 0.94, 0.045), (-0.3, 0, 0.05), WOOD_ROT, rot=(0, 2, -4))
    m.box((0.24, 0.5, 0.045), (0.0, -0.2, 0.05), WOOD_D, rot=(3, 0, 3))
    m.box((0.24, 0.34, 0.045), (0.02, 0.3, 0.035), WOOD_D, rot=(-9, 4, -6))
    m.box((0.24, 0.92, 0.045), (0.3, 0, 0.05), WOOD_ROT, rot=(0, -3, 5))
    m.cyl(0.04, 0.035, 0.22, (-0.44, -0.28, -0.05), WOOD_D)
    m.cyl(0.04, 0.03, 0.16, (0.44, 0.28, -0.05), WOOD_D, rot=(8, 0, 0))


@model
def obj_bridge(m):
    """Крепкий настил рыцаря: свежие доски, поперечины, столбики по углам."""
    # вода трясины и бортик рисуются в board.gd — общие для соседних клеток трясины
    for i in range(4):
        x = -0.345 + i * 0.23
        ln = min(0.96, 2 * hex_half_height(abs(x) + 0.11) - 0.03)
        m.box((0.225, ln, 0.06), (x, 0, 0.06), WOOD_F if i % 2 == 0 else (0.46, 0.37, 0.25))
    for y in (-0.32, 0.32):
        m.box((0.98, 0.09, 0.05), (0, y, 0.11), WOOD_ROT)
    for x in (-0.45, 0.45):
        for y in (-0.3, 0.3):
            m.cyl(0.045, 0.04, 0.3, (x, y, -0.05), WOOD_D)
    m.box((0.05, 0.05, 0.03), (0.45, -0.3, 0.14), IRON)
    m.box((0.05, 0.05, 0.03), (-0.45, 0.3, 0.14), IRON)


def dead_tree(m, lean, branches, height=1.9):
    lx, ly = lean
    m.cyl(0.17, 0.11, height * 0.55, (0, 0, 0), DEAD, rot=(lx, ly, 0), seg=6)
    top = Euler((math.radians(lx), math.radians(ly), 0)).to_matrix() @ Vector((0, 0, height * 0.55))
    m.cyl(0.11, 0.05, height * 0.45, tuple(top), DEAD, rot=(lx * 2.2, ly * 2.2 - 6, 0), seg=5)
    for a in (20, 140, 260):   # корни
        r = math.radians(a + m.rnd.uniform(-20, 20))
        m.cyl(0.07, 0.02, 0.32, (math.cos(r) * 0.1, math.sin(r) * 0.1, 0.1), DEAD_D,
              rot=(0, 118, math.degrees(r)), seg=4)
    for z, ang, ln, tilt in branches:   # сучья
        base = Euler((math.radians(lx), math.radians(ly), 0)).to_matrix() @ Vector((0, 0, z))
        m.cyl(0.045, 0.012, ln, tuple(base), DEAD_D, rot=(0, tilt, ang), seg=4)
        tip = Vector(base) + Euler((0, math.radians(tilt), math.radians(ang))).to_matrix() @ Vector((0, 0, ln * 0.6))
        m.cyl(0.02, 0.006, ln * 0.5, tuple(tip), DEAD_D, rot=(0, tilt - 35, ang + 40), seg=3)
    m.blob(0.1, (0.1, -0.08, 0.02), MOSS, scale=(1.3, 1, 0.4))


@model
def obj_tree_a(m):
    """Мёртвое дерево: голый ствол с сучьями (падает от удара)."""
    dead_tree(m, (4, -5), [(0.95, 30, 0.55, 55), (1.25, 200, 0.5, 48), (1.5, 110, 0.35, 40)])


@model
def obj_tree_b(m):
    dead_tree(m, (-6, 3), [(0.8, 250, 0.5, 60), (1.15, 60, 0.6, 50), (1.45, 320, 0.3, 35), (1.6, 170, 0.3, 30)], 2.05)


@model
def obj_barrel(m):
    """Бочка с болотным газом: пузатая, из щелей бьёт зелёный свет."""
    m.cyl(0.22, 0.28, 0.24, (0, 0, 0), WOOD_D, seg=8)
    m.cyl(0.28, 0.28, 0.2, (0, 0, 0.24), WOOD_ROT, seg=8)
    m.cyl(0.28, 0.22, 0.24, (0, 0, 0.44), WOOD_D, seg=8)
    m.cyl(0.262, 0.286, 0.05, (0, 0, 0.1), IRON, seg=8, metal=0.6, rough=0.6)
    m.cyl(0.286, 0.262, 0.05, (0, 0, 0.53), IRON, seg=8, metal=0.6, rough=0.6)
    m.cyl(0.288, 0.288, 0.035, (0, 0, 0.325), GAS, seg=8, emit=1.0)        # светящийся пояс
    for a in (15, 135, 255):                                             # щели между клёпками
        r = math.radians(a)
        m.box((0.02, 0.012, 0.3), (math.cos(r) * 0.283, math.sin(r) * 0.283, 0.34), GAS, rot=(0, 0, a), emit=1.0)
    m.cyl(0.2, 0.2, 0.02, (0, 0, 0.68), WOOD_ROT, seg=8)
    m.cyl(0.05, 0.05, 0.03, (0.08, 0.04, 0.7), GAS, seg=5, emit=1.4)       # пробка, из-под которой сочится газ
    m.cyl(0.035, 0.035, 0.08, (-0.08, -0.05, 0.69), IRON, seg=5)


@model
def obj_reeds(m):
    """Камыш с рогозом: закрывает линию удара."""
    m.blob(0.3, (0, 0, -0.01), MUD_W, scale=(1.2, 1.2, 0.08))
    for i in range(12):
        a = math.tau * i / 12 + m.rnd.uniform(-0.2, 0.2)
        r = m.rnd.uniform(0.06, 0.36)
        h = m.rnd.uniform(0.7, 1.15)
        tilt = (m.rnd.uniform(-9, 9), m.rnd.uniform(-9, 9), 0)
        pos = (math.cos(a) * r, math.sin(a) * r, 0)
        m.cyl(0.02, 0.006, h, pos, REED if i % 3 else REED_D, rot=tilt, seg=3)
        if i % 3 == 0:   # коричневый «початок»
            top = Vector(pos) + Euler([math.radians(t) for t in tilt]).to_matrix() @ Vector((0, 0, h * 0.78))
            m.cyl(0.035, 0.035, 0.17, tuple(top), CATTAIL, rot=tilt, seg=5)


@model
def obj_stakes(m):
    """Частокол Стражи: заострённые брёвна, связанные верёвкой."""
    for i in range(5):
        x = -0.38 + i * 0.19
        h = 0.95 + m.rnd.uniform(-0.1, 0.12)
        rot = (m.rnd.uniform(-4, 4), m.rnd.uniform(-4, 4), 0)
        col = WOOD_ROT if i % 2 else WOOD_D
        m.cyl(0.085, 0.08, h, (x, 0, 0), col, rot=rot, seg=6)
        top = Vector((x, 0, 0)) + Euler([math.radians(t) for t in rot]).to_matrix() @ Vector((0, 0, h))
        m.cyl(0.08, 0, 0.22, tuple(top), DEAD, rot=rot, seg=6)
    m.box((0.96, 0.05, 0.07), (0, -0.09, 0.6), ROPE)
    m.box((0.96, 0.05, 0.07), (0, 0.09, 0.3), ROPE)
    m.cyl(0.05, 0, 0.5, (-0.2, -0.1, 0.25), DEAD, rot=(118, 0, 10), seg=5)   # колья наружу
    m.cyl(0.05, 0, 0.5, (0.22, -0.1, 0.25), DEAD, rot=(112, 0, -8), seg=5)


@model
def obj_ice(m):
    """Ледяная глыба мага: гранёные кристаллы льда."""
    spec = [(0, 0, 0.3, 1.0, (3, -4)), (0.2, 0.12, 0.2, 0.7, (-14, 16)), (-0.22, 0.08, 0.2, 0.62, (-10, -18)),
            (0.05, -0.22, 0.2, 0.5, (22, 4)), (-0.14, -0.2, 0.14, 0.36, (20, -22))]
    for x, y, r, h, (rx, ry) in spec:
        m.cyl(r, r * 0.75, h * 0.8, (x, y, 0), ICE, rot=(rx, ry, 30), seg=6, rough=0.12, emit=0.25)
        top = Vector((x, y, 0)) + Euler((math.radians(rx), math.radians(ry), 0)).to_matrix() @ Vector((0, 0, h * 0.8))
        m.cyl(r * 0.75, 0, h * 0.28, tuple(top), (0.86, 0.96, 1.0), rot=(rx, ry, 30), seg=6, rough=0.12, emit=0.35)


# --- Неразрушимые преграды («камни»), у каждой арены свои ---

@model
def rock_boulder(m):
    """Замшелый валун."""
    m.blob(0.42, (0, 0, 0.26), STONE, scale=(1, 0.9, 0.8), jit=0.2)
    m.blob(0.2, (0.3, 0.22, 0.1), STONE_D, scale=(1, 1, 0.8), jit=0.2)
    m.blob(0.26, (-0.05, 0, 0.5), MOSS, scale=(1.1, 1, 0.35))
    m.blob(0.12, (-0.32, -0.2, 0.06), STONE_D, jit=0.2)


@model
def rock_pillar(m):
    """Обломок колонны старой Марки."""
    m.box((0.8, 0.8, 0.14), (0, 0, 0.07), STONE_D)
    m.box((0.64, 0.64, 0.1), (0, 0, 0.19), STONE)
    m.cyl(0.26, 0.24, 1.05, (0, 0, 0.24), STONE_L, seg=8)
    m.cyl(0.24, 0.2, 0.22, (0, 0, 1.29), STONE, rot=(14, 8, 0), seg=8)   # скошенный излом
    m.cyl(0.24, 0.24, 0.3, (0.3, -0.3, 0.12), STONE, rot=(90, 0, 35), seg=8)  # упавший барабан
    m.blob(0.16, (-0.2, 0.2, 0.3), MOSS, scale=(1, 1, 0.3))


@model
def rock_crates(m):
    """Ящики и мешок со склада заставы."""
    m.box((0.6, 0.6, 0.5), (-0.08, 0.05, 0.25), WOOD_ROT, rot=(0, 0, 8))
    m.box((0.64, 0.06, 0.06), (-0.08, -0.26, 0.25), WOOD_D, rot=(0, 0, 8))
    m.box((0.06, 0.64, 0.06), (-0.38, 0.05, 0.4), WOOD_D, rot=(0, 0, 8))
    m.box((0.42, 0.42, 0.36), (0.0, 0.08, 0.68), WOOD_D, rot=(0, 0, -17))
    m.blob(0.2, (0.3, -0.26, 0.14), CLOTH, scale=(1, 0.8, 0.7))
    m.cyl(0.05, 0.03, 0.08, (0.3, -0.26, 0.26), ROPE, seg=5)


@model
def rock_marker(m):
    """Межевой камень Стражи с колоколом."""
    m.box((0.6, 0.4, 0.12), (0, 0, 0.06), STONE_D)
    m.box((0.44, 0.24, 1.0), (0, 0, 0.6), STONE, rot=(0, 5, 0))
    m.cyl(0.22, 0.22, 0.24, (-0.12, 0.12, 1.08), STONE, rot=(90, 5, 0), seg=8)
    m.cyl(0.05, 0.11, 0.16, (0.03, -0.135, 0.72), CLOTH, rot=(0, 0, 0), seg=6)   # колокол-герб
    m.box((0.2, 0.02, 0.025), (0.03, -0.135, 0.71), CLOTH)
    m.blob(0.14, (0.2, 0.1, 0.12), MOSS, scale=(1, 1, 0.5))


@model
def rock_bones(m):
    """Груда костей и черепов в логове огра."""
    m.blob(0.32, (0, 0, 0.1), MUD, scale=(1.2, 1.1, 0.4))
    for i in range(6):
        a = m.rnd.uniform(0, 360)
        m.cyl(0.04, 0.03, m.rnd.uniform(0.4, 0.7), (m.rnd.uniform(-0.25, 0.25), m.rnd.uniform(-0.25, 0.25), 0.16),
              BONE, rot=(m.rnd.uniform(55, 85), 0, a), seg=4)
    m.blob(0.15, (0.05, -0.05, 0.36), BONE, scale=(1, 1.15, 0.9), jit=0.05)
    m.box((0.05, 0.03, 0.05), (0.0, -0.2, 0.36), BOG)
    m.box((0.05, 0.03, 0.05), (0.1, -0.2, 0.36), BOG)
    m.blob(0.1, (-0.28, 0.15, 0.16), BONE, jit=0.05)


# ======================= ДЕКОР ВОКРУГ АРЕНЫ =======================

@model
def decor_tree_big(m):
    """Большое мёртвое дерево с космами мха."""
    m.cyl(0.38, 0.24, 1.8, (0, 0, -0.2), DEAD_D, rot=(3, 4, 0), seg=7)
    m.cyl(0.24, 0.12, 1.6, (0.1, -0.08, 1.55), DEAD_D, rot=(-6, 10, 0), seg=6)
    limbs = [(1.3, 20, 1.5, 62), (1.7, 150, 1.3, 55), (2.2, 260, 1.2, 50), (2.7, 80, 0.9, 40), (2.9, 310, 0.8, 35)]
    for z, ang, ln, tilt in limbs:
        m.cyl(0.1, 0.03, ln, (0.08, -0.05, z), DEAD, rot=(0, tilt, ang), seg=4)
        e = Euler((0, math.radians(tilt), math.radians(ang))).to_matrix()
        mid = Vector((0.08, -0.05, z)) + e @ Vector((0, 0, ln * 0.6))
        m.cyl(0.04, 0.01, ln * 0.6, tuple(mid), DEAD, rot=(0, tilt - 30, ang + 35), seg=3)
        for k in (0.45, 0.8):   # свисающий мох
            p = Vector((0.08, -0.05, z)) + e @ Vector((0, 0, ln * k))
            hl = m.rnd.uniform(0.3, 0.6)
            m.box((0.05, 0.02, hl), (p.x, p.y, p.z - hl / 2), MOSS if k < 0.5 else MOSS_L)
    for a in (0, 70, 150, 230, 300):
        r = math.radians(a)
        m.cyl(0.14, 0.03, 0.7, (math.cos(r) * 0.22, math.sin(r) * 0.22, 0.15), DEAD_D, rot=(0, 112, a), seg=4)


@model
def decor_stump(m):
    """Пень с грибами-трутовиками."""
    m.cyl(0.36, 0.28, 0.5, (0, 0, -0.1), DEAD_D, seg=7)
    m.cyl(0.28, 0.1, 0.25, (0.05, 0, 0.4), DEAD, rot=(0, 20, 0), seg=5)
    for a in (40, 170, 280):
        r = math.radians(a)
        m.cyl(0.12, 0.03, 0.5, (math.cos(r) * 0.25, math.sin(r) * 0.25, 0.08), DEAD_D, rot=(0, 110, a), seg=4)
    m.cyl(0.12, 0.1, 0.03, (0.3, 0.05, 0.22), BONE, seg=5)
    m.cyl(0.09, 0.07, 0.03, (0.27, -0.12, 0.32), BONE, seg=5)


@model
def decor_tussock(m):
    """Кочка с осокой."""
    m.blob(0.5, (0, 0, -0.05), MUD, scale=(1.3, 1.1, 0.35), jit=0.2)
    m.blob(0.36, (0.05, 0, 0.08), MOSS, scale=(1.2, 1, 0.3), jit=0.2)
    for i in range(9):
        a = m.rnd.uniform(0, math.tau)
        r = m.rnd.uniform(0, 0.3)
        m.cyl(0.025, 0, m.rnd.uniform(0.3, 0.6), (math.cos(a) * r, math.sin(a) * r, 0.12), MOSS_L if i % 2 else REED_D,
              rot=(m.rnd.uniform(-25, 25), m.rnd.uniform(-25, 25), 0), seg=3)


def shore_chunk(m, stones, roots, grass):
    """Кусок топкого берега вдоль края поля: грязевой склон уходит в воду, камни, корни, осока.
    Длина ~1.4 м вдоль X, к полю — сторона +Y (Blender), к воде — -Y; верх на высоте 0."""
    m.blob(0.55, (0, 0.05, -0.12), MUD_W, scale=(1.35, 0.75, 0.3), jit=0.25)     # склон в воду
    m.blob(0.45, (0.1, 0.22, -0.05), MUD, scale=(1.4, 0.6, 0.22), jit=0.22)      # верх берега
    m.blob(0.3, (-0.3, 0.25, -0.02), MOSS, scale=(1.3, 0.8, 0.18), jit=0.2)      # мох по кромке
    for x, y, r in stones:
        m.blob(r, (x, y, -0.04), m.rnd.choice((STONE, STONE_D, STONE_L)), scale=(1.2, 1, 0.6), jit=0.25)
    for x, ang in roots:   # корни торчат из склона к воде
        m.cyl(0.04, 0.01, 0.55, (x, 0.1, 0.0), WOOD_D, rot=(m.rnd.uniform(60, 80), 0, ang), seg=4)
    for i in range(grass):
        x = m.rnd.uniform(-0.6, 0.6)
        m.cyl(0.02, 0, m.rnd.uniform(0.25, 0.45), (x, m.rnd.uniform(0.0, 0.3), -0.02), MOSS_L if i % 2 else REED_D,
              rot=(m.rnd.uniform(-25, 25), m.rnd.uniform(-25, 25), 0), seg=3)


@model
def decor_shore_a(m):
    """Берег: два камня, корень, немного осоки."""
    shore_chunk(m, [(-0.45, -0.1, 0.16), (0.35, -0.2, 0.11)], [(0.1, 170)], 4)


@model
def decor_shore_b(m):
    """Берег: большой валун в воде, корни."""
    shore_chunk(m, [(0.2, -0.28, 0.24), (-0.5, 0.0, 0.08)], [(-0.3, 190), (0.55, 160)], 3)


@model
def decor_shore_c(m):
    """Берег: заросший осокой, мелкие камешки."""
    shore_chunk(m, [(-0.2, -0.25, 0.07), (0.15, -0.3, 0.06), (0.5, -0.15, 0.09)], [], 9)


@model
def decor_mushrooms(m):
    """Грибы Раскола: светятся бирюзой."""
    m.blob(0.3, (0, 0, -0.03), MUD_W, scale=(1.2, 1, 0.3))
    for x, y, h, r in [(0, 0, 0.42, 0.16), (0.2, 0.1, 0.26, 0.11), (-0.16, 0.14, 0.2, 0.09), (0.05, -0.2, 0.14, 0.07)]:
        m.cyl(0.035, 0.025, h, (x, y, 0), BONE, rot=(m.rnd.uniform(-8, 8), m.rnd.uniform(-8, 8), 0), seg=5)
        m.cyl(r, r * 0.25, r * 0.6, (x, y, h - 0.02), RIFT, seg=7, emit=0.8)


@model
def decor_lantern(m):
    """Фонарь Стражи на покосившемся столбе: тёплый огонёк надежды."""
    m.cyl(0.07, 0.055, 2.3, (0, 0, -0.2), WOOD_D, rot=(0, 5, 0), seg=6)
    m.box((0.7, 0.07, 0.07), (0.42, 0, 2.02), WOOD_D, rot=(0, -8, 0))
    m.box((0.4, 0.05, 0.05), (0.26, 0, 1.82), WOOD_ROT, rot=(0, 38, 0))
    m.box((0.015, 0.015, 0.22), (0.66, 0, 1.92), IRON)
    m.box((0.2, 0.2, 0.03), (0.66, 0, 1.8), IRON)
    m.box((0.14, 0.14, 0.2), (0.66, 0, 1.685), LAMP, emit=4.0)
    m.box((0.2, 0.2, 0.03), (0.66, 0, 1.57), IRON)
    for dx, dy in ((0.085, 0.085), (-0.085, 0.085), (0.085, -0.085), (-0.085, -0.085)):
        m.box((0.02, 0.02, 0.22), (0.66 + dx, dy, 1.685), IRON)
    m.blob(0.16, (0, 0, 0.0), MOSS, scale=(1.2, 1.2, 0.4))


@model
def decor_bell(m):
    """Колокол Стражи на деревянной раме."""
    for x in (-0.6, 0.6):
        m.cyl(0.08, 0.07, 2.2, (x, 0, -0.1), WOOD_D, rot=(0, -x * 5, 0), seg=6)
        m.box((0.07, 0.6, 0.07), (x, 0, 0.3), WOOD_ROT, rot=(40, 0, 0))
    m.box((1.5, 0.12, 0.12), (0, 0, 2.05), WOOD_ROT)
    m.box((0.04, 0.04, 0.25), (0, 0, 1.9), IRON)
    m.cyl(0.3, 0.16, 0.4, (0, 0, 1.38), CLOTH, seg=8, metal=0.7, rough=0.5)
    m.cyl(0.16, 0.08, 0.1, (0, 0, 1.78), CLOTH, seg=8, metal=0.7, rough=0.5)
    m.cyl(0.33, 0.3, 0.05, (0, 0, 1.34), (0.45, 0.36, 0.13), seg=8, metal=0.7, rough=0.5)
    m.blob(0.06, (0, 0, 1.3), IRON, jit=0)


@model
def decor_fence(m):
    """Остатки частокола: колья разной высоты, часть повалена."""
    hs = [1.5, 1.2, 1.7, 0.7, 1.4, 1.0]
    for i, h in enumerate(hs):
        x = -0.75 + i * 0.3
        rot = (m.rnd.uniform(-6, 6), m.rnd.uniform(-7, 7), 0)
        m.cyl(0.11, 0.1, h, (x, 0, -0.2), WOOD_D if i % 2 else WOOD_ROT, rot=rot, seg=6)
        top = Vector((x, 0, -0.2)) + Euler([math.radians(t) for t in rot]).to_matrix() @ Vector((0, 0, h))
        if h > 0.9:
            m.cyl(0.1, 0, 0.26, tuple(top), DEAD, rot=rot, seg=6)
    m.box((1.7, 0.05, 0.08), (0, -0.11, 0.55), ROPE, rot=(0, 3, 0))
    m.cyl(0.1, 0.09, 1.3, (0.4, -0.4, 0.05), WOOD_ROT, rot=(84, 0, 60), seg=6)


@model
def decor_arch(m):
    """Руины: две колонны и расколотая перемычка."""
    for x, h in ((-0.9, 2.3), (0.9, 1.5)):
        m.box((0.6, 0.6, 0.2), (x, 0, 0.0), STONE_D)
        m.cyl(0.22, 0.2, h, (x, 0, 0.1), STONE, seg=8)
        m.box((0.5, 0.5, 0.14), (x, 0, h + 0.15), STONE_L)
    m.box((1.5, 0.42, 0.3), (-0.4, 0, 2.6), STONE, rot=(0, 9, 0))
    m.box((0.9, 0.42, 0.3), (1.1, 0.3, 0.12), STONE_D, rot=(0, -6, 28))
    m.blob(0.2, (-0.9, 0, 2.75), MOSS, scale=(1.4, 1, 0.3))
    m.box((0.06, 0.03, 0.7), (-0.6, 0.2, 2.15), MOSS)
    m.box((0.06, 0.03, 0.45), (-0.2, -0.2, 2.25), MOSS_L)


@model
def decor_wall(m):
    """Руины: обломок стены, осевший в воду."""
    rows = [(2.0, 0.0), (1.8, 0.35), (1.3, 0.7), (0.7, 1.05)]
    for w, z in rows:
        m.box((w, 0.45, 0.36), (-(2.0 - w) / 2, 0, z + 0.05), STONE if int(z * 10) % 2 else STONE_D,
              rot=(0, 0, m.rnd.uniform(-1.5, 1.5)))
    m.box((0.5, 0.4, 0.3), (1.0, 0.5, 0.05), STONE_D, rot=(12, 0, 30))
    m.blob(0.25, (-0.6, 0, 1.45), MOSS, scale=(1.5, 1, 0.3))
    m.box((0.3, 0.05, 0.5), (-0.4, -0.24, 0.6), BOG)   # пустое окно


@model
def decor_boat(m):
    """Полузатонувшая лодка."""
    m.box((2.0, 0.7, 0.08), (0, 0, 0.0), WOOD_D, rot=(0, -10, 0))
    for y, tilt in ((-0.38, 22), (0.38, -22)):
        m.box((2.1, 0.06, 0.36), (0, y, 0.16), WOOD_ROT, rot=(tilt, -10, 0))
    m.box((0.3, 0.5, 0.36), (1.0, 0, 0.36), WOOD_D, rot=(0, -40, 0))
    m.box((0.06, 0.7, 0.06), (0.2, 0, 0.2), WOOD_ROT, rot=(0, -10, 0))
    m.cyl(0.03, 0.03, 1.4, (-0.3, 0.2, 0.15), DEAD, rot=(70, 0, 30), seg=4)   # весло
    m.box((0.14, 0.03, 0.4), (0.1, 1.0, 0.63), DEAD, rot=(70, 0, 30))


@model
def decor_tent(m):
    """Изодранная палатка Стражи."""
    m.box((1.5, 1.9, 0.04), (-0.52, 0, 0.72), CLOTH, rot=(0, -54, 0))
    m.box((1.5, 1.2, 0.04), (0.52, -0.3, 0.72), (0.48, 0.38, 0.14), rot=(0, 54, 0))
    m.box((0.7, 0.5, 0.04), (0.75, 0.75, 0.4), CLOTH, rot=(0, 54, 12))
    m.cyl(0.04, 0.04, 1.45, (0, -0.95, 0), WOOD_D, seg=5)
    m.cyl(0.04, 0.04, 1.45, (0, 0.95, 0), WOOD_D, seg=5)
    m.box((0.05, 2.0, 0.05), (0, 0, 1.36), WOOD_ROT)
    m.box((0.4, 0.02, 0.5), (0, -0.97, 1.05), (0.48, 0.38, 0.14))   # вымпел
    m.cyl(0.25, 0.25, 0.06, (1.3, -0.9, 0), STONE_D, seg=7)          # старое кострище
    m.cyl(0.04, 0.03, 0.4, (1.3, -0.9, 0.05), BOG, rot=(70, 0, 20), seg=4)
    m.cyl(0.04, 0.03, 0.4, (1.3, -0.9, 0.05), BOG, rot=(70, 0, 140), seg=4)


@model
def decor_ribs(m):
    """Рёбра огромного зверя — возле логова огра."""
    m.cyl(0.1, 0.07, 2.6, (-1.3, 0, 0.25), BONE, rot=(0, 90, 0), seg=5)
    for i in range(5):
        x = -1.0 + i * 0.5
        s = 1.0 - abs(i - 2) * 0.12
        for side in (1, -1):
            m.cyl(0.06, 0.045, 0.8 * s, (x, 0, 0.25), BONE, rot=(side * 50, 0, 0), seg=4)
            e = Euler((math.radians(side * 50), 0, 0)).to_matrix() @ Vector((0, 0, 0.8 * s))
            m.cyl(0.045, 0.012, 0.75 * s, (x + e.x, e.y, 0.25 + e.z), BONE, rot=(side * -8, 0, 0), seg=4)
    m.blob(0.3, (1.5, 0, 0.26), BONE, scale=(1.3, 0.9, 0.8), jit=0.08)
    m.cyl(0.07, 0.01, 0.3, (1.75, 0.12, 0.2), BONE, rot=(0, 110, 0), seg=4)
    m.cyl(0.07, 0.01, 0.3, (1.75, -0.12, 0.2), BONE, rot=(0, 110, 0), seg=4)


@model
def decor_totem(m):
    """Гоблинский тотем: черепа на шесте и светящаяся трещина Раскола."""
    m.cyl(0.1, 0.07, 2.4, (0, 0, -0.2), WOOD_D, rot=(4, -3, 0), seg=6)
    m.box((0.9, 0.07, 0.07), (0, 0, 1.6), WOOD_ROT, rot=(0, 6, 0))
    for x, z, r in ((0.02, 2.2, 0.17), (-0.4, 1.42, 0.12), (0.42, 1.38, 0.12)):
        m.blob(r, (x, 0, z), BONE, scale=(1, 1, 1.1), jit=0.05)
        m.box((r * 0.35, 0.03, r * 0.35), (x - r * 0.35, -r * 0.9, z), RIFT, emit=3.0)
        m.box((r * 0.35, 0.03, r * 0.35), (x + r * 0.35, -r * 0.9, z), RIFT, emit=3.0)
    m.box((0.03, 0.02, 0.9), (0.02, -0.085, 0.9), RIFT, rot=(4, 6, 0), emit=3.0)
    m.box((0.2, 0.02, 0.5), (0.3, 0.02, 1.3), (0.2, 0.26, 0.22), rot=(0, 10, 0))   # лохмотья


@model
def decor_rock_big(m):
    """Большой замшелый камень у края поля."""
    m.blob(0.9, (0, 0, 0.3), STONE_D, scale=(1.2, 0.9, 0.75), jit=0.22)
    m.blob(0.5, (0.8, 0.3, 0.1), STONE, scale=(1, 1, 0.7), jit=0.22)
    m.blob(0.55, (-0.1, 0, 0.85), MOSS, scale=(1.3, 1, 0.3), jit=0.15)
    m.blob(0.3, (-0.9, -0.3, 0.05), STONE, jit=0.2)


@model
def decor_spire(m):
    """Шпиль на горизонте: в небе над ним светится трещина Раскола (ставится далеко и крупно)."""
    m.cyl(1.6, 1.0, 6, (0, 0, 0), (0.16, 0.19, 0.22), seg=6)
    m.cyl(1.0, 0.5, 9, (0, 0, 6), (0.14, 0.17, 0.2), seg=6)
    m.cyl(0.5, 0, 7, (0, 0, 15), (0.12, 0.15, 0.18), seg=6)
    m.cyl(0.9, 0.2, 5, (2.4, 0, 0), (0.15, 0.18, 0.21), rot=(0, -6, 0), seg=5)
    m.cyl(0.7, 0.1, 3.5, (-2.2, 0.4, 0), (0.15, 0.18, 0.21), rot=(0, 8, 0), seg=5)
    pts = [(0.2, 22.5), (-0.5, 24.5), (0.6, 26.5), (-0.2, 28.5), (0.8, 30.5), (0.1, 32.5)]   # трещина в небе
    for (x1, z1), (x2, z2) in zip(pts, pts[1:]):
        ln = math.hypot(x2 - x1, z2 - z1)
        ang = math.degrees(math.atan2(x2 - x1, z2 - z1))
        m.box((0.28, 0.1, ln + 0.1), ((x1 + x2) / 2, 0, (z1 + z2) / 2), RIFT, rot=(0, ang, 0), emit=5.0)
    m.box((0.14, 0.1, 1.6), (1.3, 0, 28.2), RIFT, rot=(0, 60, 0), emit=5.0)
    m.box((0.14, 0.1, 1.2), (-1.0, 0, 25.6), RIFT, rot=(0, -55, 0), emit=5.0)


# ======================= ГУСТЫЕ ЛЕСА (объекты и декор) =======================
# Живое — зелёное и тёплое бурое; признак «с этим можно что-то сделать» — лента Хранителей
# с бледно светящимся знаком. Декоративные деревья вокруг поля — без ленты.

LEAF = (0.13, 0.22, 0.11)
LEAF_L = (0.19, 0.29, 0.13)
LEAF_D = (0.08, 0.15, 0.08)
BARK = (0.29, 0.23, 0.17)
BARK_D = (0.20, 0.16, 0.12)
RIBBON = (0.34, 0.44, 0.47)      # приглушённая лента Хранителей (холодная, не жёлтая и не красная)
SIGN = (0.72, 0.9, 0.78)         # знак на ленте: бледный серебристо-зелёный
VINE = (0.30, 0.29, 0.13)       # лоза: оливково-бурая, чтобы отличалась от мха на плитах
VINE_D = (0.21, 0.16, 0.09)
VINE_LEAF = (0.36, 0.42, 0.16)
HIVE = (0.36, 0.29, 0.19)        # плетёный улей
HIVE_D = (0.24, 0.19, 0.13)
RUST = (0.33, 0.22, 0.15)        # ржавчина насосной (бурая, не красная)
BRONZE = (0.30, 0.26, 0.18)


def crown(m, z, r, n, spread, tint=0):
    """Крона из нескольких неровных «шапок» листвы."""
    cols = [LEAF, LEAF_L, LEAF_D]
    for i in range(n):
        a = math.tau * i / n + m.rnd.uniform(-0.4, 0.4)
        d = spread * m.rnd.uniform(0.4, 1.0)
        rr = r * m.rnd.uniform(0.75, 1.05)
        m.blob(rr, (math.cos(a) * d, math.sin(a) * d, z + m.rnd.uniform(-0.12, 0.18)), cols[(i + tint) % 3],
               scale=(1, 1, 0.78), jit=0.22)
    m.blob(r * 1.05, (0, 0, z + r * 0.45), cols[(tint + 1) % 3], scale=(1, 1, 0.8), jit=0.2)


def live_trunk(m, h, lean):
    m.cyl(0.16, 0.1, h, (0, 0, 0), BARK, rot=(lean[0], lean[1], 0), seg=7)
    for a in (30, 150, 270):   # корни
        r = math.radians(a + m.rnd.uniform(-15, 15))
        m.cyl(0.08, 0.02, 0.34, (math.cos(r) * 0.1, math.sin(r) * 0.1, 0.08), BARK_D, rot=(0, 115, math.degrees(r)), seg=4)
    m.blob(0.1, (-0.1, 0.1, 0.03), MOSS, scale=(1.4, 1, 0.4))


def ribbon(m, z):
    """Лента Хранителей вокруг ствола: знак «это дерево — часть боя»."""
    m.cyl(0.165, 0.155, 0.1, (0, 0, z), RIBBON, seg=8)
    m.box((0.05, 0.03, 0.3), (0.12, -0.12, z - 0.12), RIBBON, rot=(0, 12, 45))
    m.box((0.06, 0.012, 0.06), (0.0, -0.166, z + 0.05), SIGN, emit=0.9)   # светящийся резной знак


@model
def obj_live_tree_a(m):
    """Живое дерево: преграда, закрывает линии. Огонь — крона горит, потом сухое дерево."""
    live_trunk(m, 1.25, (3, -2))
    ribbon(m, 0.55)
    crown(m, 1.45, 0.42, 4, 0.32)


@model
def obj_live_tree_b(m):
    """Второе живое дерево: выше и стройнее, крона ярусами."""
    live_trunk(m, 1.5, (-2, 3))
    ribbon(m, 0.5)
    crown(m, 1.2, 0.36, 3, 0.28, tint=1)
    crown(m, 1.85, 0.28, 3, 0.18, tint=2)


@model
def obj_vine(m):
    """Лоза на клетке: толстые колючие плети петлями над плитой (вошёл — опутан). Видна издалека:
    бурые петли поднимаются над землёй, этим лоза отличается от мха."""
    for i in range(5):
        a = math.tau * i / 5 + m.rnd.uniform(-0.3, 0.3)
        ln = m.rnd.uniform(0.5, 0.68)
        m.cyl(0.04, 0.022, ln, (0, 0, 0.04), VINE if i % 2 else VINE_D,
              rot=(0, 86 + m.rnd.uniform(-5, 5), math.degrees(a)), seg=5)
        for k in (0.4, 0.78):   # листья и шипы вдоль плети
            px, py = math.cos(a) * ln * k, math.sin(a) * ln * k
            m.box((0.13, 0.07, 0.016), (px, py, 0.08), VINE_LEAF, rot=(m.rnd.uniform(-25, 25), 0, math.degrees(a) + 40))
            m.cyl(0.016, 0, 0.11, (px, py, 0.06), BARK_D, rot=(m.rnd.uniform(-50, 50), m.rnd.uniform(-50, 50), 0), seg=3)
    for i in range(3):   # петли-арки над плитой
        a = math.tau * i / 3 + 0.4
        r = 0.28
        cx, cy = math.cos(a) * r, math.sin(a) * r
        for side in (-1, 1):
            m.cyl(0.03, 0.026, 0.3, (cx + side * 0.09 * math.sin(a), cy - side * 0.09 * math.cos(a), 0.0),
                  VINE_D, rot=(side * 28 * math.cos(a), side * 28 * math.sin(a), 0), seg=4)
        m.blob(0.05, (cx, cy, 0.27), VINE_LEAF, scale=(1.4, 1.4, 0.6))
    m.blob(0.16, (0, 0, 0.04), VINE_D, scale=(1.4, 1.4, 0.35))


@model
def obj_bush(m):
    """Подлесок: густой куст папоротника и молодых побегов. Закрывает линии, горит."""
    m.blob(0.3, (0, 0, -0.01), MUD_W, scale=(1.2, 1.2, 0.08))
    for i in range(5):
        a = math.tau * i / 5 + m.rnd.uniform(-0.3, 0.3)
        d = m.rnd.uniform(0.12, 0.26)
        m.blob(m.rnd.uniform(0.2, 0.26), (math.cos(a) * d, math.sin(a) * d, 0.28 + m.rnd.uniform(0, 0.12)),
               [LEAF, LEAF_L, LEAF_D][i % 3], scale=(1, 1, 1.15), jit=0.28)
    for i in range(8):   # листья папоротника торчат вверх и в стороны
        a = math.tau * i / 8
        m.box((0.07, 0.02, 0.5), (math.cos(a) * 0.22, math.sin(a) * 0.22, 0.42), LEAF_L,
              rot=(0, 30 + m.rnd.uniform(-8, 8), math.degrees(a)))


@model
def obj_hive(m):
    """Дикий улей: плетёный колокол на пне, вокруг пятна мёда. Удар или огонь — рой."""
    m.cyl(0.3, 0.26, 0.38, (0, 0, -0.05), BARK_D, seg=7)
    m.cyl(0.26, 0.24, 0.03, (0, 0, 0.33), BARK, seg=7)
    for k, (r1, r2) in enumerate([(0.26, 0.25), (0.25, 0.21), (0.21, 0.14), (0.14, 0.04)]):
        m.cyl(r1, r2, 0.14, (0, 0, 0.36 + k * 0.14), HIVE if k % 2 else HIVE_D, seg=8)
    m.box((0.08, 0.03, 0.06), (0, -0.24, 0.43), (0.05, 0.04, 0.03))   # леток
    for i in range(6):   # пчёлы — тёмные точки вокруг
        a = m.rnd.uniform(0, math.tau)
        m.box((0.035, 0.02, 0.02), (math.cos(a) * 0.36, math.sin(a) * 0.36, m.rnd.uniform(0.45, 0.85)), (0.12, 0.1, 0.06))
    m.blob(0.12, (0.2, 0.18, 0.02), MOSS, scale=(1.3, 1, 0.4))


@model
def obj_valve(m):
    """Паровой клапан брошенной насосной: ржавая труба из земли, вентиль, манометр. Удар — пар."""
    m.cyl(0.2, 0.2, 0.12, (0, 0, 0), IRON, seg=8, metal=0.5, rough=0.7)
    m.cyl(0.11, 0.11, 0.72, (0, 0, 0.1), RUST, seg=8, metal=0.4, rough=0.8)
    m.cyl(0.15, 0.15, 0.08, (0, 0, 0.42), BRONZE, seg=8, metal=0.6, rough=0.6)
    m.cyl(0.11, 0.11, 0.5, (0, 0, 0.75), RUST, rot=(90, 0, 0), seg=8, metal=0.4, rough=0.8)   # колено трубы
    m.cyl(0.035, 0.035, 0.2, (0, 0, 0.82), IRON, seg=5)
    m.cyl(0.17, 0.17, 0.03, (0, 0, 1.0), BRONZE, seg=10, metal=0.6, rough=0.5)              # вентиль
    m.box((0.32, 0.03, 0.03), (0, 0, 1.015), IRON)
    m.box((0.03, 0.32, 0.03), (0, 0, 1.015), IRON)
    m.cyl(0.08, 0.08, 0.04, (0.14, -0.06, 0.6), (0.7, 0.72, 0.68), rot=(0, 90, 0), seg=8)    # манометр
    m.cyl(0.05, 0.08, 0.1, (0, -0.34, 0.66), (0.72, 0.8, 0.82), rot=(90, 0, 0), seg=6, emit=0.4)  # струйка пара


@model
def rock_pipe(m):
    """Труба насосной на опорах: неразрушимая преграда."""
    for x in (-0.3, 0.3):
        m.box((0.12, 0.3, 0.42), (x, 0, 0.21), IRON, metal=0.4, rough=0.7)
    m.cyl(0.2, 0.2, 0.96, (-0.48, 0, 0.55), RUST, rot=(0, 90, 0), seg=8, metal=0.4, rough=0.8)
    for x in (-0.25, 0.25):
        m.cyl(0.22, 0.22, 0.06, (x, 0, 0.55), BRONZE, rot=(0, 90, 0), seg=8, metal=0.6, rough=0.6)
    m.blob(0.12, (0.1, 0.12, 0.72), MOSS, scale=(1.4, 1, 0.3))


@model
def rock_root(m):
    """Корни склона в Паучьей лощине: неразрушимая преграда."""
    m.blob(0.36, (0, 0, 0.12), MUD, scale=(1.2, 1.0, 0.45), jit=0.2)
    for i in range(5):
        a = m.rnd.uniform(0, 360)
        m.cyl(0.1, 0.03, m.rnd.uniform(0.6, 0.9), (m.rnd.uniform(-0.15, 0.15), m.rnd.uniform(-0.15, 0.15), 0.1),
              BARK_D if i % 2 else BARK, rot=(m.rnd.uniform(60, 80), 0, a), seg=5)
    m.blob(0.16, (0.15, -0.1, 0.3), MOSS, scale=(1.3, 1, 0.4))


@model
def rock_log(m):
    """Поваленный ствол у ручья: неразрушимая преграда."""
    m.cyl(0.24, 0.2, 0.95, (-0.47, 0, 0.22), BARK, rot=(0, 90, 0), seg=7)
    m.cyl(0.21, 0.21, 0.02, (0.48, 0, 0.22), WOOD_F, rot=(0, 90, 0), seg=7)   # спил
    m.cyl(0.06, 0.02, 0.4, (-0.1, 0.1, 0.4), BARK_D, rot=(40, 0, 30), seg=4)
    m.blob(0.18, (-0.15, 0, 0.42), MOSS, scale=(1.6, 1, 0.35))
    m.blob(0.1, (0.25, 0.12, 0.38), LEAF_L, scale=(1.2, 1, 0.5))


@model
def decor_tree_green(m):
    """Большое живое дерево вокруг лесной арены (декор, без ленты)."""
    m.cyl(0.42, 0.26, 2.4, (0, 0, -0.2), BARK, rot=(2, 3, 0), seg=8)
    m.cyl(0.26, 0.14, 1.4, (0.06, -0.04, 2.1), BARK, rot=(-4, 8, 0), seg=7)
    for a in (0, 70, 150, 230, 300):
        r = math.radians(a)
        m.cyl(0.15, 0.03, 0.8, (math.cos(r) * 0.25, math.sin(r) * 0.25, 0.15), BARK_D, rot=(0, 112, a), seg=4)
    for z, ang in ((1.9, 40), (2.4, 200), (2.8, 300)):
        m.cyl(0.09, 0.03, 1.0, (0.05, 0, z), BARK_D, rot=(0, 55, ang), seg=4)
    crown(m, 3.0, 0.85, 5, 0.85)
    crown(m, 3.8, 0.6, 3, 0.45, tint=1)


@model
def decor_fern(m):
    """Папоротник у края лесной арены."""
    for i in range(9):
        a = math.tau * i / 9 + m.rnd.uniform(-0.2, 0.2)
        m.box((0.09, 0.02, 0.6), (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.25), [LEAF, LEAF_L, LEAF_D][i % 3],
              rot=(0, 52 + m.rnd.uniform(-10, 10), math.degrees(a)))
    m.blob(0.12, (0, 0, 0.02), LEAF_D, scale=(1.3, 1.3, 0.4))


@model
def decor_pump(m):
    """Брошенный насос технарей: котёл, маховик, трубы в землю — след стимпанка в болотах."""
    m.box((1.6, 1.1, 0.3), (0, 0, 0.15), STONE_D)
    m.cyl(0.55, 0.55, 1.4, (-0.2, 0, 0.3), RUST, seg=10, metal=0.4, rough=0.8)        # котёл
    m.cyl(0.58, 0.58, 0.08, (-0.2, 0, 0.9), BRONZE, seg=10, metal=0.6, rough=0.6)
    m.cyl(0.4, 0.15, 0.4, (-0.2, 0, 1.7), RUST, seg=10, metal=0.4, rough=0.8)
    m.cyl(0.08, 0.08, 1.2, (-0.2, 0, 2.0), IRON, seg=6)                                # труба
    m.cyl(0.5, 0.5, 0.08, (0.62, -0.1, 1.0), IRON, rot=(90, 0, 0), seg=12, metal=0.5)  # маховик
    m.cyl(0.08, 0.08, 0.3, (0.62, 0.05, 1.0), BRONZE, rot=(90, 0, 0), seg=6)
    for a in (0, 60, 120):
        m.box((0.92, 0.04, 0.04), (0.62, -0.1, 1.0), IRON, rot=(0, a, 0))
    m.cyl(0.12, 0.12, 1.4, (0.2, 0.3, 0.35), RUST, rot=(0, 75, 30), seg=8, metal=0.4)  # труба в землю
    m.cyl(0.18, 0.18, 0.12, (-0.2, -0.56, 0.9), (0.7, 0.8, 0.82), rot=(90, 0, 0), seg=8, emit=0.35)  # окошко котла
    m.blob(0.3, (0.5, 0.4, 0.3), MOSS, scale=(1.4, 1, 0.4))


# ---------- Знаки босса: по ним на первых аренах можно догадаться, кто ждёт в конце акта ----------
TABARD = (0.36, 0.37, 0.28)     # выцветший серо-оливковый табард
PLUME = (0.48, 0.20, 0.16)      # выцветший плюмаж
TOAD = (0.31, 0.36, 0.20)       # жабья кожа


@model
def sign_captain_helm(m):
    """Капитан: ржавый шлем Стражи с выцветшим плюмажем, увяз в трясине."""
    m.blob(0.45, (0, 0, -0.05), MUD_W, scale=(1.6, 1.3, 0.25), jit=0.08)
    m.cyl(0.26, 0.22, 0.28, (0, 0, 0.02), RUST, rot=(14, 0, 0), seg=10, metal=0.4, rough=0.8)   # колпак
    m.blob(0.22, (0, 0.03, 0.3), RUST, scale=(1.0, 1.0, 0.7), jit=0.03, metal=0.4, rough=0.8)
    m.cyl(0.36, 0.34, 0.04, (0, 0, 0.05), RUST, rot=(14, 0, 0), seg=10, metal=0.4, rough=0.8)   # поля шлема
    m.box((0.05, 0.36, 0.06), (0, 0.05, 0.47), IRON, rot=(14, 0, 0))                           # гребень
    for i in range(5):
        m.box((0.05, 0.1, 0.24), (0, -0.1 + i * 0.07, 0.6 - i * 0.03), PLUME, rot=(14 - i * 18, 0, 0))
    m.blob(0.1, (0.3, -0.2, 0.0), MOSS, scale=(1.4, 1, 0.4))


@model
def sign_captain_bell(m):
    """Капитан: треснувший колокол Стражи, наполовину в воде."""
    m.blob(0.55, (0, 0, -0.05), BOG, scale=(1.5, 1.3, 0.12), jit=0.05)
    m.cyl(0.42, 0.2, 0.55, (0, 0, -0.05), CLOTH, rot=(0, 62, 15), seg=10, metal=0.7, rough=0.5)
    m.cyl(0.46, 0.43, 0.06, (-0.24, 0, -0.08), (0.45, 0.36, 0.13), rot=(0, 62, 15), seg=10, metal=0.7, rough=0.5)
    m.box((0.5, 0.03, 0.015), (0.08, -0.18, 0.28), BOG, rot=(0, 55, 20))   # трещина
    m.box((0.6, 0.08, 0.08), (0.45, 0.2, 0.02), WOOD_D, rot=(0, 4, 40))    # обломок рамы
    m.blob(0.12, (-0.4, 0.3, 0.0), DUCKWEED, scale=(1.5, 1.2, 0.3))


@model
def sign_captain_halberd(m):
    """Капитан: обломок алебарды с обрывком табарда, воткнут в кочку."""
    m.blob(0.3, (0, 0, 0.0), MOSS, scale=(1.3, 1.2, 0.45))
    m.cyl(0.035, 0.03, 1.2, (0, 0, 0.05), WOOD_D, rot=(12, 6, 0), seg=6)
    m.box((0.05, 0.36, 0.22), (0.02, -0.33, 1.15), STEEL, rot=(12, 6, 0), metal=0.5, rough=0.6)   # лезвие
    m.box((0.04, 0.08, 0.3), (0.0, -0.3, 1.38), STEEL, rot=(12, 6, 0), metal=0.5, rough=0.6)    # пика
    m.box((0.3, 0.02, 0.4), (0.12, 0.0, 0.8), TABARD, rot=(8, 6, 6))   # табард
    m.box((0.18, 0.02, 0.2), (0.14, 0.02, 0.5), TABARD, rot=(4, 2, 16))


@model
def sign_ogre_column(m):
    """Огр: обломок каменной колонны с каннелюрами."""
    m.cyl(0.38, 0.36, 0.9, (0, 0, -0.05), STONE, seg=12)
    for i in range(6):
        a = math.tau * i / 6
        m.box((0.06, 0.06, 0.8), (math.cos(a) * 0.37, math.sin(a) * 0.37, 0.38), STONE_D, rot=(0, 0, math.degrees(a)))
    m.cyl(0.36, 0.2, 0.25, (0.02, 0, 0.83), STONE_L, rot=(18, -10, 0), seg=7)   # скол сверху
    m.cyl(0.3, 0.3, 0.7, (0.75, 0.15, 0.25), STONE, rot=(0, 90, 20), seg=12)   # упавший кусок
    m.blob(0.15, (-0.3, 0.35, 0.0), MOSS, scale=(1.4, 1, 0.4))


@model
def sign_ogre_shackles(m):
    """Огр: разорванные кандалы с цепью, огромные — на ногу великана."""
    for x, ang in ((-0.35, 0), (0.45, 30)):
        m.cyl(0.26, 0.26, 0.14, (x, 0, 0.0), IRON, rot=(0, 0, ang), seg=10, metal=0.5, rough=0.7)
        m.cyl(0.18, 0.18, 0.16, (x, 0, -0.01), MUD_W, rot=(0, 0, ang), seg=10)
    for i in range(4):
        m.cyl(0.07, 0.07, 0.05, (-0.1 + i * 0.13, 0.25 + (i % 2) * 0.04, 0.03), IRON, rot=(0 if i % 2 else 90, 0, 0), seg=6, metal=0.5)
    m.box((0.06, 0.04, 0.12), (0.43, 0.32, 0.05), RUST, rot=(0, 0, 40))   # разорванное звено
    m.blob(0.3, (0, 0, -0.08), MUD, scale=(2.2, 1.4, 0.2), jit=0.06)


@model
def sign_ogre_print(m):
    """Огр: огромный след ноги, вдавленный в треснувшую плиту."""
    m.prism([(-0.9, -0.6), (0.9, -0.6), (0.9, 0.6), (-0.9, 0.6)], -0.1, 0.05, STONE_D, chamfer=0.03)
    m.blob(0.42, (0, 0, 0.0), MUD_W, scale=(1.3, 0.9, 0.12), jit=0.04)   # пятка и стопа
    for i, (x, y) in enumerate(((0.62, -0.25), (0.66, 0.0), (0.6, 0.25))):
        m.blob(0.12, (x, y, 0.02), MUD_W, scale=(1.2, 1, 0.3), jit=0.04)
    for a, l in ((20, 0.7), (-50, 0.5), (110, 0.6)):
        m.box((l, 0.03, 0.02), (-0.4 + math.cos(math.radians(a)) * l / 2, math.sin(math.radians(a)) * l / 2, 0.055), BOG, rot=(0, 0, a))


@model
def sign_mother_eggs(m):
    """Матерь Трясины: кладка икры с бирюзовым светом в луже."""
    m.blob(0.55, (0, 0, -0.04), BOG, scale=(1.5, 1.3, 0.1), jit=0.05)
    for i in range(11):
        a = m.rnd.uniform(0, math.tau)
        r = m.rnd.uniform(0.0, 0.42)
        m.blob(0.08, (math.cos(a) * r, math.sin(a) * r, 0.04), RIFT, jit=0.02, emit=1.2)
    m.blob(0.4, (0, 0, 0.0), (0.42, 0.5, 0.42), scale=(1.2, 1.0, 0.18), jit=0.06, rough=0.2)   # слизь
    m.box((0.04, 0.04, 0.5), (0.5, 0.35, 0.2), REED, rot=(10, 0, 0))
    m.box((0.04, 0.04, 0.4), (0.55, 0.28, 0.15), REED_D, rot=(-12, 8, 0))


@model
def sign_mother_skin(m):
    """Матерь Трясины: сброшенная жабья кожа, сморщенная и бугристая."""
    m.blob(0.5, (0, 0, 0.05), TOAD, scale=(1.6, 1.1, 0.25), jit=0.25)
    m.blob(0.3, (0.55, 0.1, 0.06), TOAD, scale=(1.2, 1.0, 0.3), jit=0.3)
    for i in range(7):
        a = m.rnd.uniform(0, math.tau)
        m.blob(0.07, (math.cos(a) * 0.45, math.sin(a) * 0.3, 0.15), DUCKWEED, jit=0.1)
    for y in (-0.3, 0.3):
        m.box((0.4, 0.15, 0.03), (-0.7, y, 0.02), TOAD, rot=(0, 0, y * 60))   # пустые лапы
    m.blob(0.3, (0, 0, -0.06), MUD_W, scale=(2.4, 1.6, 0.15), jit=0.06)


@model
def sign_mother_tracks(m):
    """Матерь Трясины: следы-перепонки размером с бочку, полные воды."""
    for k, (x, y, ang) in enumerate(((-0.6, -0.2, 10), (0.6, 0.25, -5))):
        m.blob(0.3, (x, y, -0.02), BOG, scale=(1.2, 1.0, 0.1), jit=0.04)
        for j in (-1, 0, 1):
            a = math.radians(ang + j * 32)
            m.box((0.55, 0.12, 0.02), (x + math.cos(a) * 0.38, y + math.sin(a) * 0.38, -0.01), BOG, rot=(0, 0, ang + j * 32))
            m.blob(0.06, (x + math.cos(a) * 0.66, y + math.sin(a) * 0.66, 0.0), MUD_W, jit=0.05)
    m.blob(0.5, (0, 0, -0.08), MUD, scale=(2.6, 1.4, 0.15), jit=0.06)


# ======================= СБОРКА И ЭКСПОРТ =======================

BIG = {"decor_spire", "decor_tree_big", "decor_wall", "decor_arch", "decor_rock_big", "decor_tree_green", "decor_pump"}   # крупный декор — текстура 1024


def build_all(out_dir, blend_path, only=None):
    """only — список имён: собрать и выгрузить только эти модели (для проб)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(out_dir, exist_ok=True)
    report = []
    for i, (name, fn) in enumerate(MODELS.items()):
        m = Model(name)
        fn(m)
        ob = m.finish()
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        report.append((name, tris))
        if only and name not in only:
            ob.location = ((i % 8) * 3.0, (i // 8) * 4.0, 0)
            continue
        # Стилизация: тени в складках, светлые рёбра, градиент (stylize.py). Плитам хватит 256,
        # крупному декору — 1024. Старые квадратные tile_* не используются — их не запекаем.
        if not (name.startswith("tile_") and not name.startswith("tile_hex")):
            size = 256 if name.startswith("tile_hex") else (1024 if name in BIG else 512)
            stylize.stylize(ob, os.path.join(os.path.dirname(os.path.abspath(__file__)), "baked"), size,
                            edge_radius=0.012 if name.startswith("tile_hex") else stylize.EDGE_RADIUS)
        ob.hide_set(False)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True)
        ob.location = ((i % 8) * 3.0, (i // 8) * 4.0, 0)   # в .blend раскладываем модели сеткой
    if blend_path:
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    for name, tris in report:
        print("%-18s %4d tris" % (name, tris))


if __name__ == "__main__":
    args = sys.argv[1:]
    build_all(args[0] if args else "out", args[1] if len(args) > 1 else "",
              args[2].split(",") if len(args) > 2 else None)
