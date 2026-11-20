# Набор моделей акта 2 «Пепельный тракт»: плиты, объекты клеток, преграды и декор арен
# Тракта и Подземья (тз-арены-акт-2.md). Собран на тех же деталях, что build_topi.py.
# Запуск:  python3 build_ash.py [папка для .glb] [путь для .blend] [имя,имя — только эти]
# По умолчанию модели пишутся в assets/models/topi/ — туда же, где модели топей (board.gd берёт их оттуда).
#
# Стиль: пепельно-серое, уголь, базальт, тёмная бронза; раскалённое — оранжевым, бирюза — только трещины Раскола.
# Красного, золота и фиолетового нет. 1 единица = 1 м = 1 клетка, origin — в центре клетки на земле.
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stylize
import build_topi as topi
from build_topi import Model, hex_pts, HEX_R

ASH = (0.33, 0.33, 0.33)
ASH_L = (0.41, 0.41, 0.41)
ASH_D = (0.25, 0.25, 0.25)
SOOT = (0.17, 0.16, 0.16)
CHAR = (0.13, 0.12, 0.11)
CHAR_L = (0.24, 0.21, 0.18)
WOOD_B = (0.30, 0.24, 0.19)     # обугленное дерево повозок
BASALT = (0.22, 0.21, 0.21)
BASALT_L = (0.30, 0.29, 0.28)
BRONZE = (0.44, 0.33, 0.21)
BRONZE_D = (0.30, 0.23, 0.16)
IRON = (0.22, 0.22, 0.24)
IRON_L = (0.34, 0.34, 0.36)
RUST = (0.36, 0.25, 0.18)
EMBER = (1.0, 0.42, 0.08)
EMBER_D = (0.55, 0.2, 0.05)
RIFT = (0.2, 0.85, 0.75)
SULFUR = (0.55, 0.48, 0.30)
BONE = (0.84, 0.81, 0.72)
CLOTH = (0.45, 0.44, 0.42)       # пепельно-серое знамя Культа
CLOTH_D = (0.30, 0.29, 0.28)
WATER = (0.42, 0.62, 0.78)
FIRE_GLASS = (1.0, 0.5, 0.12)
GAS = (0.46, 0.80, 0.42)
SHROOM = (0.62, 0.66, 0.58)
SHROOM_GLOW = (0.35, 0.92, 0.82)
STORM_GLASS = (0.95, 0.88, 0.35)   # грозовая сфера — заметно жёлтая

MODELS = {}


def model(fn):
    MODELS[fn.__name__] = fn
    return fn


def hex_base(m, color, top=0.0, chamfer=0.035):
    m.prism(hex_pts(HEX_R), top - 0.2, top, color, chamfer=chamfer)


# ======================= ПЛИТЫ =======================

@model
def tile_hex_ash(m):
    """Пепельная плита Тракта: серый камень в саже, трещина, горстка пепла."""
    hex_base(m, ASH)
    m.box((0.5, 0.03, 0.012), (-0.05, 0.08, 0.0), ASH_D, rot=(0, 0, 18))
    m.blob(0.12, (0.22, -0.2, -0.02), ASH_L, scale=(1.4, 1.1, 0.25), jit=0.2)
    m.blob(0.06, (-0.3, -0.18, 0.0), SOOT, scale=(1.3, 1, 0.15))


@model
def tile_hex_ash_b(m):
    """Плита в копоти: тёмное пятно гари и угольки."""
    hex_base(m, ASH_D)
    m.blob(0.22, (0.05, 0.05, -0.02), SOOT, scale=(1.3, 1.1, 0.08), jit=0.15)
    for x, y in ((0.12, 0.1), (-0.08, -0.04)):
        m.blob(0.03, (x, y, 0.0), EMBER_D, scale=(1, 1, 0.5))


@model
def tile_hex_ash_c(m):
    """Плита, расколотая жаром: два куска с тёмной щелью, пепел в щели."""
    hex_base(m, ASH)
    m.box((0.95, 0.04, 0.012), (0.0, -0.02, 0.0), CHAR, rot=(0, 0, -8))
    m.box((0.18, 0.03, 0.012), (0.2, 0.15, 0.0), CHAR, rot=(0, 0, 50))
    m.blob(0.08, (-0.25, 0.25, -0.01), ASH_L, scale=(1.3, 1, 0.3))


@model
def tile_hex_metal(m):
    """Клёпаный пол лаборатории: тёмная бронзовая плита, рамка и заклёпки."""
    hex_base(m, IRON, chamfer=0.02)
    m.prism(hex_pts(HEX_R - 0.08), -0.05, 0.008, BRONZE_D, chamfer=0.015, metal=0.5, rough=0.6)
    for k in range(6):
        a = math.radians(90 + 60 * k)
        m.cyl(0.025, 0.02, 0.02, ((HEX_R - 0.11) * math.cos(a), (HEX_R - 0.11) * math.sin(a), 0.0), IRON_L, seg=5, metal=0.6, rough=0.5)


@model
def tile_hex_metal_b(m):
    """Решётка над тёмной ямой: прутья поверх пола, снизу слабый отсвет жара."""
    hex_base(m, CHAR, top=-0.04, chamfer=0.0)
    m.prism(hex_pts(HEX_R - 0.12), -0.12, -0.05, EMBER_D, emit=0.6)
    for i in range(5):
        y = -0.36 + i * 0.18
        half = HEX_R * math.sqrt(3) / 2
        if abs(y) > HEX_R / 2:
            half *= (HEX_R - abs(y)) / (HEX_R / 2)
        m.box((half * 2 - 0.08, 0.05, 0.04), (0, y, -0.01), IRON, metal=0.6, rough=0.55)
    m.box((0.06, 0.9, 0.04), (0, 0, -0.01), IRON_L, metal=0.6, rough=0.55)


# ======================= ОБЪЕКТЫ КЛЕТОК (вид для арен акта 2) =======================

@model
def obj_oil_barrel(m):
    """Бочка лампового масла (механика бочки: удар или огонь — взрыв огнём)."""
    m.cyl(0.24, 0.27, 0.32, (0, 0, 0), CHAR_L, seg=8)
    m.cyl(0.27, 0.24, 0.32, (0, 0, 0.32), CHAR_L, seg=8)
    for z in (0.08, 0.32, 0.56):
        m.cyl(0.275, 0.275, 0.05, (0, 0, z), IRON, seg=8, metal=0.5, rough=0.6)
    m.cyl(0.24, 0.24, 0.02, (0, 0, 0.64), SOOT, seg=8)
    m.box((0.06, 0.06, 0.08), (0.12, 0.05, 0.66), IRON_L)
    m.blob(0.08, (0.0, -0.3, 0.0), SOOT, scale=(2.2, 1.2, 0.08))   # масляное пятно


@model
def obj_brazier(m):
    """Жаровня Культа на треноге, полная тлеющих углей."""
    for k in range(3):
        a = math.radians(90 + 120 * k)
        m.cyl(0.035, 0.03, 0.75, (0.22 * math.cos(a), 0.22 * math.sin(a), 0), IRON, rot=(math.degrees(-0.25) * math.sin(a), math.degrees(0.25) * math.cos(a), 0), seg=5)
    m.cyl(0.18, 0.34, 0.2, (0, 0, 0.62), IRON, seg=8, metal=0.5, rough=0.6)
    m.blob(0.26, (0, 0, 0.8), EMBER, scale=(1.1, 1.1, 0.4), emit=1.4)
    m.cyl(0.36, 0.36, 0.04, (0, 0, 0.8), BONE, seg=10)   # костяной обруч Венца по краю


@model
def obj_puffball(m):
    """Гриб-дождевик Грибной пещеры: вздутый шар с газом, светится бирюзово-зелёным."""
    m.cyl(0.12, 0.16, 0.16, (0, 0, 0), SHROOM, seg=7)
    m.blob(0.33, (0, 0, 0.42), SHROOM, scale=(1.0, 1.0, 0.85), jit=0.05)
    for x, y, z in ((0.15, -0.2, 0.55), (-0.2, -0.12, 0.42), (0.05, 0.22, 0.6), (0.24, 0.12, 0.35)):
        m.blob(0.07, (x, y, z), GAS, scale=(1, 1, 0.6), emit=0.8)
    m.blob(0.14, (0.3, 0.25, 0.05), SHROOM, scale=(1, 1, 0.9), jit=0.08)


def sphere_on_pedestal(m, glow, crack=True):
    m.cyl(0.32, 0.26, 0.12, (0, 0, 0), IRON, seg=8, metal=0.5, rough=0.6)
    m.cyl(0.14, 0.12, 0.42, (0, 0, 0.12), BRONZE_D, seg=8, metal=0.5, rough=0.6)
    m.cyl(0.22, 0.2, 0.08, (0, 0, 0.54), BRONZE, seg=8, metal=0.6, rough=0.5)
    m.blob(0.26, (0, 0, 0.86), glow, scale=(1, 1, 1), jit=0.0, emit=1.1)
    for k in range(4):   # прутья клетки
        a = math.radians(45 + 90 * k)
        m.box((0.03, 0.03, 0.6), (0.27 * math.cos(a), 0.27 * math.sin(a), 0.88), IRON, metal=0.5)
    m.cyl(0.3, 0.3, 0.04, (0, 0, 0.6), IRON, seg=8)
    m.cyl(0.29, 0.06, 0.12, (0, 0, 1.16), IRON, seg=8)
    if crack:
        m.box((0.02, 0.12, 0.02), (0.0, -0.25, 0.9), RIFT, rot=(0, 0, 20), emit=1.5)


@model
def obj_sphere_fire(m):
    """Зал сфер: огненная сфера на постаменте (удар — взрыв огнём)."""
    sphere_on_pedestal(m, FIRE_GLASS)


@model
def obj_sphere_water(m):
    """Зал сфер: водяная сфера на постаменте (удар — пар и лужа, как клапан)."""
    sphere_on_pedestal(m, WATER)


@model
def obj_sphere_storm(m):
    """Зал сфер: грозовая сфера на постаменте (удар — разряд по соседям и по воде рядом)."""
    sphere_on_pedestal(m, STORM_GLASS)
    for k in range(3):   # искры-разряды по прутьям
        a = math.radians(20 + 120 * k)
        m.box((0.02, 0.02, 0.14), (0.2 * math.cos(a), 0.2 * math.sin(a), 0.95), STORM_GLASS, rot=(0, 30, 0), emit=1.6)


@model
def obj_basin(m):
    """Край жерла: каменная купель с водой (удар — вода плещет на соседей и тушит огонь)."""
    m.cyl(0.4, 0.34, 0.12, (0, 0, 0), BASALT, seg=8)
    m.cyl(0.36, 0.4, 0.34, (0, 0, 0.1), BASALT_L, seg=8)
    m.cyl(0.33, 0.33, 0.03, (0, 0, 0.4), WATER, seg=8, rough=0.15)
    for k in range(4):   # медные скобы
        a = math.radians(45 + 90 * k)
        m.box((0.06, 0.04, 0.3), (0.39 * math.cos(a), 0.39 * math.sin(a), 0.26), BRONZE, metal=0.6)
    m.blob(0.07, (0.3, -0.2, 0.45), ASH_L, jit=0.3)


@model
def obj_geyser(m):
    """Гейзер Кипящих ключей: каменное жерло в серной корке, из него сочится пар (удар — пар и лужа)."""
    m.cyl(0.42, 0.3, 0.2, (0, 0, -0.02), BASALT, seg=8)
    m.cyl(0.3, 0.2, 0.22, (0, 0, 0.16), BASALT_L, seg=8)
    m.cyl(0.18, 0.16, 0.02, (0, 0, 0.37), WATER, seg=8, rough=0.15)
    for k in range(5):
        a = math.radians(30 + 72 * k)
        m.blob(0.1, (0.33 * math.cos(a), 0.33 * math.sin(a), 0.1), SULFUR, scale=(1.2, 1, 0.5), jit=0.2)
    for z, r in ((0.55, 0.12), (0.78, 0.15), (1.0, 0.11)):
        m.blob(r, (0.02, 0.0, z), (0.86, 0.88, 0.88), scale=(1, 1, 0.8), jit=0.25)


def charred_tree(m, lean, stubs):
    m.cyl(0.17, 0.08, 1.7, (0, 0, -0.05), CHAR, rot=lean, seg=6)
    for h, ang, ln in stubs:
        a = math.radians(ang)
        m.cyl(0.05, 0.02, ln, (0.06 * math.cos(a), 0.06 * math.sin(a), h), CHAR, rot=(math.sin(a) * -60, math.cos(a) * 60, 0), seg=4)
    for k in range(3):   # тлеющие трещины в коре
        m.box((0.03, 0.02, 0.18), (0.13 * math.cos(k * 2.1), 0.13 * math.sin(k * 2.1), 0.35 + k * 0.28), EMBER, emit=1.0)
    m.blob(0.25, (0, 0, 0.0), CHAR_L, scale=(1.2, 1.2, 0.25), jit=0.25)   # корни в пепле


@model
def obj_tree_charred_a(m):
    """Пепелище: обугленный ствол, тлеющие трещины (механика мёртвого дерева: удар — падает)."""
    charred_tree(m, (5, -4, 0), [(0.9, 30, 0.4), (1.25, 200, 0.35)])


@model
def obj_tree_charred_b(m):
    """Обугленный ствол, обломанный выше, с одним суком."""
    charred_tree(m, (-6, 3, 0), [(1.05, 120, 0.45)])


@model
def obj_wall_cracked(m):
    """Павшая башня: треснувший кусок стены, кренится (механика дерева: удар — падает на линию)."""
    m.box((0.85, 0.32, 1.25), (0.0, 0.0, 0.6), ASH_D, rot=(6, 0, 0))
    for i in range(3):
        m.box((0.42, 0.34, 0.2), (-0.21 + (i % 2) * 0.42, 0.0, 0.18 + i * 0.4), ASH, rot=(6, 0, 0))
    m.box((0.04, 0.35, 0.9), (0.08, 0.02, 0.62), CHAR, rot=(6, 0, 12))   # трещина
    m.blob(0.15, (0.3, -0.3, 0.05), ASH, scale=(1.2, 1, 0.6))   # обломки у подножия
    m.blob(0.1, (-0.32, -0.28, 0.03), ASH_D, scale=(1.2, 1, 0.6))


# ======================= ПРЕГРАДЫ (неразрушимые) =======================

@model
def rock_wagon(m):
    """Перевёрнутая обугленная повозка: короб вверх дном, задранное колесо."""
    m.box((0.95, 0.62, 0.42), (0, 0, 0.21), WOOD_B, rot=(0, 0, 8))
    for i in range(4):
        m.box((0.97, 0.04, 0.44), (0, -0.28 + i * 0.19, 0.21), CHAR, rot=(0, 0, 8))
    topi_wheel(m, (0.42, 0.34, 0.5), (75, 0, 20), 0.3)
    m.box((0.06, 0.06, 0.8), (-0.48, -0.05, 0.28), CHAR, rot=(0, 70, 8))   # оглобля
    m.blob(0.05, (0.1, -0.33, 0.44), EMBER, scale=(1.6, 1, 0.5), emit=1.0)


def topi_wheel(m, pos, rot, r):
    m.cyl(r, r, 0.07, pos, CHAR, rot=rot, seg=10)
    m.cyl(r * 0.8, r * 0.8, 0.075, pos, WOOD_B, rot=rot, seg=10)
    m.cyl(r * 0.22, r * 0.22, 0.12, pos, IRON, rot=rot, seg=6)


@model
def rock_basalt(m):
    """Глыба чёрного базальта с оплавленной макушкой."""
    m.blob(0.36, (0, 0, 0.3), BASALT, scale=(1.1, 1.0, 1.0), jit=0.22)
    m.blob(0.22, (0.18, 0.12, 0.62), BASALT_L, scale=(1.0, 0.9, 0.7), jit=0.25)
    m.blob(0.14, (-0.28, -0.2, 0.1), BASALT, jit=0.3)


@model
def rock_tower_block(m):
    """Обломок кладки башни: тёсаные блоки грудой."""
    m.box((0.6, 0.42, 0.42), (0, 0, 0.21), ASH_D, rot=(0, 0, 14))
    m.box((0.45, 0.38, 0.36), (0.1, 0.05, 0.6), ASH, rot=(8, 4, -10))
    m.box((0.3, 0.28, 0.25), (-0.3, -0.2, 0.12), ASH, rot=(0, 10, 30))


@model
def rock_altar(m):
    """Алтарь Капища: плоская каменная плита на двух опорах, на ней костяной обруч."""
    for x in (-0.28, 0.28):
        m.box((0.2, 0.45, 0.45), (x, 0, 0.22), ASH_D)
    m.box((0.95, 0.6, 0.14), (0, 0, 0.5), ASH)
    m.cyl(0.22, 0.22, 0.04, (0, 0, 0.57), BONE, seg=10)
    m.cyl(0.18, 0.18, 0.05, (0, 0, 0.57), ASH, seg=10)
    m.blob(0.05, (0.3, 0.15, 0.6), EMBER, scale=(1, 1, 0.5), emit=1.0)


@model
def rock_banner(m):
    """Знамя Культа: высокий шест, рваное пепельное полотнище с пустым костяным кругом."""
    m.cyl(0.05, 0.04, 2.3, (0, 0, 0), CHAR, seg=5)
    m.box((0.6, 0.03, 0.05), (0.27, 0, 2.2), CHAR)
    m.box((0.55, 0.03, 1.05), (0.3, 0, 1.62), CLOTH)
    m.box((0.2, 0.031, 0.25), (0.42, 0, 1.0), CLOTH_D, rot=(0, 12, 0))   # рваный край
    m.cyl(0.15, 0.15, 0.035, (0.3, -0.018, 1.7), BONE, rot=(90, 0, 0), seg=12)
    m.cyl(0.11, 0.11, 0.04, (0.3, -0.02, 1.7), CLOTH, rot=(90, 0, 0), seg=12)
    m.blob(0.18, (0, 0, 0.0), ASH_D, scale=(1.2, 1.2, 0.4))   # камни у основания


@model
def rock_slag(m):
    """Куча шлака: чёрные стеклянистые комья, внутри тлеет."""
    m.blob(0.4, (0, 0, 0.18), SOOT, scale=(1.2, 1.1, 0.6), jit=0.3)
    m.blob(0.22, (0.15, -0.1, 0.42), CHAR_L, jit=0.3)
    m.blob(0.06, (-0.1, -0.32, 0.2), EMBER, scale=(1.5, 1, 0.5), emit=1.0)


@model
def rock_cart(m):
    """Ржавая рудная вагонетка на рельсах."""
    for x in (-0.18, 0.18):
        m.box((0.06, 1.0, 0.05), (x, 0, 0.03), IRON_L, metal=0.6)
    m.box((0.62, 0.7, 0.4), (0, 0, 0.42), RUST, metal=0.4, rough=0.7)
    m.box((0.66, 0.74, 0.06), (0, 0, 0.63), IRON, metal=0.5)
    m.blob(0.25, (0, 0, 0.66), BASALT, scale=(1.1, 1.3, 0.5), jit=0.3)   # руда
    for x in (-0.24, 0.24):
        for y in (-0.22, 0.22):
            m.cyl(0.1, 0.1, 0.06, (x * 1.15, y, 0.12), IRON, rot=(0, 90, 0), seg=8)


@model
def rock_boiler(m):
    """Клёпаный котёл технарей с мёртвым манометром."""
    m.cyl(0.36, 0.36, 0.95, (0, 0, 0), BRONZE_D, seg=10, metal=0.6, rough=0.55)
    for z in (0.15, 0.5, 0.85):
        m.cyl(0.37, 0.37, 0.05, (0, 0, z), IRON, seg=10, metal=0.6)
    m.cyl(0.36, 0.1, 0.25, (0, 0, 0.95), BRONZE, seg=10, metal=0.6, rough=0.5)
    m.cyl(0.08, 0.08, 0.04, (0, -0.37, 0.6), (0.8, 0.8, 0.75), rot=(90, 0, 0), seg=8)   # манометр
    m.cyl(0.05, 0.05, 0.5, (0.2, 0.0, 1.0), IRON, seg=6)


@model
def rock_machine(m):
    """Недособранная машина на ленте конвейера: корпус, пустая сфера, торчащие трубки."""
    m.box((0.6, 0.6, 0.35), (0, 0, 0.18), BRONZE_D, metal=0.5, rough=0.6)
    m.blob(0.22, (0, 0, 0.55), (0.6, 0.7, 0.72), scale=(1, 1, 1), jit=0.0, rough=0.1)
    for k in range(3):
        m.cyl(0.03, 0.03, 0.4, (0.25 * math.cos(k * 2), 0.25 * math.sin(k * 2), 0.3), IRON, rot=(30 * math.sin(k * 2), 30 * math.cos(k * 2), 0), seg=5)


@model
def rock_charred_log(m):
    """Упавший обугленный ствол поперёк клетки."""
    m.cyl(0.18, 0.16, 1.1, (-0.55, 0, 0.17), CHAR, rot=(0, 90, 0), seg=7)
    m.box((0.04, 0.3, 0.03), (0.0, 0.0, 0.34), EMBER, emit=0.8)
    m.blob(0.12, (0.2, 0.2, 0.05), ASH_L, scale=(1.5, 1, 0.3))


# ======================= ДЕКОР ВОКРУГ АРЕН =======================

@model
def decor_wheel(m):
    """Брошенное тележное колесо в пепле."""
    topi_wheel(m, (0, 0, 0.05), (8, 0, 0), 0.38)


@model
def decor_dune(m):
    """Дюна пепла: пологий холм серого пепла."""
    m.blob(0.9, (0, 0, -0.25), ASH, scale=(1.5, 1.0, 0.5), jit=0.12)
    m.blob(0.5, (0.5, 0.2, 0.05), ASH_L, scale=(1.3, 1, 0.45), jit=0.15)


@model
def decor_mushroom_giant(m):
    """Огромный светящийся гриб Раскола."""
    m.cyl(0.12, 0.18, 1.2, (0, 0, 0), SHROOM, seg=7)
    m.blob(0.55, (0, 0, 1.3), SHROOM_GLOW, scale=(1.0, 1.0, 0.45), jit=0.08, emit=0.9)
    m.blob(0.15, (0.35, 0.25, 0.1), SHROOM_GLOW, scale=(1, 1, 0.7), emit=0.9)


@model
def decor_volcano(m):
    """Вулкан вдали: тёмный конус, жерло светится."""
    m.cyl(9.0, 2.2, 7.0, (0, 0, 0), BASALT, seg=9)
    m.cyl(2.2, 1.8, 0.4, (0, 0, 7.0), EMBER_D, seg=9, emit=1.5)
    m.cyl(1.6, 0.4, 0.3, (0, 0, 7.15), EMBER, seg=9, emit=2.0)


BIG = {"decor_volcano", "rock_banner", "decor_mushroom_giant"}


def build_all(out_dir, blend_path, only=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(out_dir, exist_ok=True)
    here = os.path.dirname(os.path.abspath(__file__))
    for i, (name, fn) in enumerate(MODELS.items()):
        m = Model(name)
        fn(m)
        ob = m.finish()
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        if only and name not in only:
            ob.location = ((i % 8) * 3.0, (i // 8) * 4.0, 0)
            continue
        size = 256 if name.startswith("tile_hex") else (1024 if name in BIG else 512)
        stylize.stylize(ob, os.path.join(here, "baked"), size,
                        edge_radius=0.012 if name.startswith("tile_hex") else stylize.EDGE_RADIUS)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True)
        ob.location = ((i % 8) * 3.0, (i // 8) * 4.0, 0)
        print("%-22s %4d tris" % (name, tris))
    if blend_path:
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = sys.argv[1:]
    build_all(args[0] if args else os.path.join(here, "..", "topi"),
              args[1] if len(args) > 1 else os.path.join(here, "ash_kit.blend"),
              args[2].split(",") if len(args) > 2 else None)
