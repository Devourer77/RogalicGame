# Знаки боссов акта 2 «Пепельный тракт»: предметы у края первых арен (ряды 0–1),
# по которым можно догадаться, кто ждёт в конце ветки. Как знаки акта 1 (build_topi.py, sign_*).
# Запуск:  python3 build_signs_act2.py [папка для .glb] [путь для .blend] [имя,имя — только эти]
# По умолчанию .glb пишутся в assets/models/ (там же, где знаки акта 1).
#
# Обозный Исполин — обугленный великан обоза: рука-колесо, голова-бочка.
# Колосс Сфер — механизм технарей с тремя сферами духов (вода, молния, огонь).
# Сосуд Венца — клетка с пленённым духом огня на цепях, над ней костяной венец.
# Стиль акта 2: пепел, уголь, тёмная бронза; раскалённое — оранжевым; бирюза — только Раскол.
import bpy, math, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import stylize
from build_topi import Model

ASH = (0.33, 0.33, 0.33)
ASH_D = (0.25, 0.25, 0.25)
CHAR = (0.13, 0.12, 0.11)
CHAR_L = (0.24, 0.21, 0.18)
WOOD_B = (0.30, 0.24, 0.19)      # обугленное дерево обоза
IRON = (0.22, 0.22, 0.24)
IRON_L = (0.34, 0.34, 0.36)
RUST = (0.36, 0.25, 0.18)
BRONZE = (0.44, 0.33, 0.21)
BRONZE_D = (0.30, 0.23, 0.16)
EMBER = (1.0, 0.42, 0.08)
BONE = (0.84, 0.81, 0.72)
WATER = (0.42, 0.62, 0.78)
STORM_GLASS = (0.95, 0.88, 0.35)
FIRE_GLASS = (1.0, 0.5, 0.12)
GLASS = (0.62, 0.70, 0.72)

MODELS = {}


def model(fn):
    MODELS[fn.__name__] = fn
    return fn


def ash_patch(m, r=0.5, sx=1.6, sy=1.3):
    """Пепельная насыпь под предметом"""
    m.blob(r, (0, 0, -0.06), ASH_D, scale=(sx, sy, 0.18), jit=0.07)


# ---------- Обозный Исполин ----------

def ring(m, r, w, h, pos, color, rot_z=0.0, n=12, tilt=(0, 0), **kw):
    """Кольцо из брусков (у Model нет тора): обод колеса, звено цепи"""
    for k in range(n):
        a = math.tau * k / n
        x, y = math.cos(a) * r, math.sin(a) * r
        m.box((2 * math.pi * r / n * 1.08, w, h), (pos[0] + x, pos[1] + y, pos[2]), color,
              rot=(tilt[0], tilt[1], math.degrees(a) + 90 + rot_z), **kw)


@model
def sign_giant_wheel(m):
    """Исполин: огромное колесо обоза лежит в пепле, обод погнут, спицы переломаны."""
    ash_patch(m, 0.55, 1.8, 1.4)
    ring(m, 0.68, 0.16, 0.12, (0, 0, 0.06), WOOD_B, n=12)             # деревянный обод
    ring(m, 0.76, 0.05, 0.08, (0, 0, 0.08), IRON, n=10, metal=0.4, rough=0.7)   # железная шина
    m.cyl(0.17, 0.17, 0.22, (0.0, 0.0, 0.0), WOOD_B, seg=8)            # ступица
    m.cyl(0.08, 0.08, 0.24, (0.0, 0.0, 0.0), IRON, seg=6, metal=0.4)
    for a, l in ((10, 0.55), (60, 0.3), (120, 0.55), (175, 0.2), (235, 0.55), (300, 0.35)):
        r = math.radians(a)
        m.box((l, 0.08, 0.07), (math.cos(r) * (0.15 + l / 2), math.sin(r) * (0.15 + l / 2), 0.1), CHAR_L, rot=(0, 0, a))
    m.box((0.5, 0.2, 0.1), (0.75, -0.55, 0.04), WOOD_B, rot=(0, 0, 50))   # отлетевший кусок обода
    m.blob(0.07, (0.4, -0.5, 0.12), EMBER, jit=0.03, emit=1.4)          # тлеющий угол


@model
def sign_giant_rut(m):
    """Исполин: две колеи в пепле шириной в шаг, между ними — вдавленные доски."""
    m.blob(0.6, (0, 0, -0.05), ASH, scale=(2.2, 1.6, 0.14), jit=0.05)
    for y in (-0.42, 0.42):
        m.box((2.0, 0.28, 0.06), (0, y, 0.0), CHAR, rot=(0, 0, 4))
        for x in (-0.8, -0.3, 0.2, 0.7):
            m.blob(0.1, (x, y + 0.2, 0.04), ASH_D, scale=(1.3, 0.8, 0.5), jit=0.06)   # выдавленный вал
    for x, a in ((-0.4, 12), (0.3, -8)):
        m.box((0.5, 0.18, 0.04), (x, 0.0, 0.0), WOOD_B, rot=(0, 3, a))
    m.box((0.18, 0.05, 0.05), (0.05, -0.1, 0.05), IRON, rot=(0, 0, 40), metal=0.4)


@model
def sign_giant_barrel(m):
    """Исполин: смятая великанской рукой обручная бочка, обруч лопнул."""
    ash_patch(m, 0.45)
    m.cyl(0.4, 0.34, 0.7, (0, 0, 0.0), WOOD_B, rot=(0, 78, 10), seg=10)
    m.blob(0.3, (0.05, 0.0, 0.42), CHAR_L, scale=(1.3, 1.1, 0.4), jit=0.18)     # вмятина
    for x in (-0.24, 0.24):
        m.cyl(0.42, 0.42, 0.05, (x, 0, 0.3), IRON, rot=(0, 90, 10), seg=10, metal=0.4, rough=0.7)
    m.box((0.5, 0.05, 0.03), (0.6, 0.3, 0.02), IRON, rot=(0, 0, 30), metal=0.4)  # лопнувший обруч
    for i in range(3):
        m.box((0.32, 0.1, 0.03), (-0.55 + i * 0.12, -0.35 - i * 0.05, 0.02), WOOD_B, rot=(0, 0, 20 + i * 35))


# ---------- Колосс Сфер ----------

@model
def sign_colossus_gear(m):
    """Колосс: огромная бронзовая шестерня, наполовину ушедшая в землю."""
    ash_patch(m, 0.45, 1.5, 1.0)
    m.cyl(0.62, 0.62, 0.14, (0, 0, -0.15), BRONZE, rot=(90, 0, 15), seg=16, metal=0.6, rough=0.55)
    m.cyl(0.2, 0.2, 0.18, (0, 0, -0.15), BRONZE_D, rot=(90, 0, 15), seg=8, metal=0.6)
    for i in range(10):
        a = math.radians(i * 36)
        x, z = math.cos(a) * 0.68, math.sin(a) * 0.68 - 0.15
        if z > -0.2:
            m.box((0.16, 0.14, 0.14), (x * math.cos(math.radians(15)), x * math.sin(math.radians(15)), z),
                  BRONZE, rot=(0, -math.degrees(a), 15), metal=0.6, rough=0.55)
    m.box((0.05, 0.3, 0.02), (0.2, 0.0, 0.25), CHAR, rot=(0, 30, 15))   # трещина


@model
def sign_colossus_shards(m):
    """Колосс: осколки стеклянных сфер трёх цветов и бронзовый обруч сферы."""
    ash_patch(m, 0.5)
    m.cyl(0.42, 0.42, 0.06, (0, 0, 0.02), BRONZE, rot=(70, 0, 20), seg=14, metal=0.6, rough=0.5)   # обруч
    for (x, y, col, k) in ((-0.35, -0.2, WATER, 0.6), (0.3, 0.25, STORM_GLASS, 0.7), (0.4, -0.3, FIRE_GLASS, 0.9)):
        for j in range(3):
            m.cyl(0.06, 0.0, 0.18 + j * 0.05, (x + j * 0.08, y - j * 0.05, 0.0), col,
                  rot=(20 - j * 15, 10 + j * 20, j * 50), seg=3, emit=k, rough=0.2)
    m.blob(0.06, (0.0, 0.05, 0.06), (0.2, 0.85, 0.75), jit=0.02, emit=1.0)   # искра Раскола из разбитой сферы


@model
def sign_colossus_bolt(m):
    """Колосс: вырванный заклёпочный болт размером с бревно, с куском брони."""
    ash_patch(m, 0.45)
    m.prism([(-0.55, -0.4), (0.5, -0.45), (0.6, 0.35), (-0.45, 0.45)], -0.05, 0.05, IRON_L, chamfer=0.02)   # лист брони
    for x, y in ((-0.35, -0.25), (0.35, -0.28), (-0.3, 0.28)):
        m.cyl(0.06, 0.06, 0.05, (x, y, 0.05), IRON, seg=6, metal=0.5)       # заклёпки
    m.cyl(0.13, 0.13, 0.9, (0.15, 0.1, 0.05), RUST, rot=(0, 70, 25), seg=6, metal=0.4, rough=0.8)   # болт
    m.cyl(0.22, 0.22, 0.14, (-0.2, -0.06, 0.12), IRON, rot=(0, 70, 25), seg=6, metal=0.5)           # гайка
    m.box((0.3, 0.06, 0.02), (0.55, 0.3, 0.06), EMBER, rot=(0, 0, -20), emit=0.6)   # раскалённый край разрыва


# ---------- Сосуд Венца ----------

@model
def sign_vessel_chain(m):
    """Сосуд: обрывок толстой цепи с оковой, последние звенья ещё раскалены."""
    ash_patch(m, 0.5, 1.9, 1.2)
    for i in range(5):
        x = -0.62 + i * 0.27
        hot = i >= 3
        col = EMBER if hot else IRON
        kw = {"emit": 1.0} if hot else {"metal": 0.5, "rough": 0.6}
        if i % 2 == 0:
            ring(m, 0.13, 0.05, 0.05, (x, 0.0, 0.03), col, n=6, **kw)                 # звено плашмя
        else:
            ring(m, 0.13, 0.05, 0.05, (x, 0.0, 0.12), col, n=6, tilt=(90, 0), **kw)   # звено на ребре
    ring(m, 0.24, 0.08, 0.16, (-0.95, 0.0, 0.06), IRON, n=8, metal=0.5, rough=0.7)   # окова
    m.box((0.12, 0.1, 0.1), (-0.72, 0.0, 0.06), IRON, metal=0.5)


@model
def sign_vessel_crown(m):
    """Сосуд: обломок костяного венца с пустыми гнёздами, опалённый."""
    ash_patch(m, 0.45)
    for i in range(5):
        a = math.radians(-60 + i * 30)
        x, y = math.cos(a) * 0.45, math.sin(a) * 0.45
        m.box((0.2, 0.08, 0.1), (x, y, 0.05), BONE, rot=(0, 0, math.degrees(a) + 90))
        m.cyl(0.05, 0.0, 0.3 + (i % 2) * 0.12, (x, y, 0.1), BONE, rot=(0, 0, 0), seg=4)   # зубцы венца
        if i % 2 == 0:
            m.cyl(0.035, 0.035, 0.03, (x * 0.96, y * 0.96, 0.11), CHAR, rot=(0, 90, math.degrees(a)), seg=6)   # пустое гнездо
    m.blob(0.1, (0.0, 0.1, 0.02), CHAR_L, scale=(2.0, 1.0, 0.3), jit=0.1)   # копоть


@model
def sign_vessel_bars(m):
    """Сосуд: два погнутых прута клетки, на них — бирюзовые трещины и следы жара."""
    ash_patch(m, 0.5)
    m.box((0.9, 0.14, 0.08), (0, -0.05, 0.02), IRON, rot=(0, 0, 8), metal=0.5)   # обломок обода клетки
    for x, bend in ((-0.25, 25), (0.25, -35)):
        m.cyl(0.04, 0.04, 0.6, (x, 0.0, 0.05), IRON, rot=(bend, 10, 0), seg=6, metal=0.5)
        m.cyl(0.04, 0.03, 0.45, (x + math.sin(math.radians(bend)) * 0.05, -math.sin(math.radians(bend)) * 0.5, 0.58),
              EMBER, rot=(bend * 2.2, 10, 0), seg=6, emit=0.9)   # раскалённый конец
    m.box((0.3, 0.02, 0.015), (0.0, 0.05, 0.07), (0.2, 0.85, 0.75), rot=(0, 0, 30), emit=1.0)   # трещина Раскола


def build_all(out_dir, blend_path, only=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(out_dir, exist_ok=True)
    report = []
    for i, (name, fn) in enumerate(MODELS.items()):
        m = Model(name)
        fn(m)
        ob = m.finish()
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        report.append((name, tris))
        if not only or name in only:
            stylize.stylize(ob, os.path.join(os.path.dirname(os.path.abspath(__file__)), "baked"), 512)
            ob.hide_set(False)
            bpy.ops.object.select_all(action="DESELECT")
            ob.select_set(True)
            bpy.context.view_layer.objects.active = ob
            bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB",
                                      use_selection=True, export_apply=True, export_yup=True)
        ob.location = ((i % 3) * 3.0, (i // 3) * 3.0, 0)   # в .blend — сеткой 3×3
    if blend_path:
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    for name, tris in report:
        print("%-22s %4d tris" % (name, tris))


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    args = sys.argv[1:]
    build_all(args[0] if args else os.path.join(here, ".."), args[1] if len(args) > 1 else os.path.join(here, "signs_act2.blend"),
              args[2].split(",") if len(args) > 2 else None)
