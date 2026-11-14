# Набор «Тлеющая пещера» (секретная арена Жаровика): сталагмит-преграда, стена из базальтовых
# столбов вокруг поля и куча тлеющих углей. Детали и материалы — из build_topi.py.
# Запуск:  python build_cave.py <папка для .glb> <путь для .blend>
# (в Blender: Scripting → Open → Run Script; build_topi.py должен лежать рядом)
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
from build_topi import Model  # noqa: E402

# --- Палитра пещеры: тёмный базальт, бурый торф, оранжевый жар (без красного) ---
BASALT = (0.17, 0.16, 0.16)
BASALT_D = (0.11, 0.10, 0.10)
BASALT_L = (0.24, 0.22, 0.21)
ASH = (0.36, 0.33, 0.30)
PEAT = (0.22, 0.15, 0.10)
EMBER = (1.0, 0.5, 0.15)        # жар в трещинах — как пламя факельщика
EMBER_D = (0.85, 0.36, 0.08)

MODELS = {}


def model(fn):
    MODELS[fn.__name__] = fn
    return fn


@model
def rock_stalagmite(m):
    """Сталагмит — преграда на клетке. У основания тлеет трещина."""
    m.cyl(0.36, 0.05, 1.5, (0, 0, 0), BASALT, seg=6)
    m.cyl(0.22, 0.02, 0.9, (0.26, 0.12, 0), BASALT_L, rot=(0, 8, 0), seg=5)
    m.cyl(0.16, 0.02, 0.6, (-0.22, -0.18, 0), BASALT_D, rot=(-6, -10, 0), seg=5)
    m.blob(0.3, (0, 0, 0.06), BASALT_D, scale=(1.3, 1.2, 0.4), jit=0.2)
    m.box((0.05, 0.03, 0.42), (0.05, -0.31, 0.2), EMBER, rot=(0, 12, 0), emit=4.0)
    m.box((0.18, 0.03, 0.04), (0.12, -0.3, 0.05), EMBER_D, emit=3.0)
    m.box((0.03, 0.2, 0.03), (0.33, 0.0, 0.05), EMBER_D, emit=3.0)


@model
def decor_cave_wall(m):
    """Стена пещеры за краем поля: пучок базальтовых шестигранных столбов разной высоты."""
    spots = [(-1.2, 0.2, 3.2), (-0.6, -0.3, 4.1), (0.0, 0.1, 3.6), (0.6, -0.2, 4.6), (1.2, 0.2, 3.0),
             (-0.9, 0.6, 2.6), (0.3, 0.6, 2.9), (0.9, -0.7, 2.2), (-0.3, -0.8, 2.0)]
    for i, (x, y, h) in enumerate(spots):
        m.cyl(0.36, 0.33, h, (x, y, -0.2), (BASALT, BASALT_D, BASALT_L)[i % 3], rot=(0, 0, 15 * i), seg=6)
    m.blob(0.7, (0.2, -0.4, 0.1), BASALT_D, scale=(1.6, 1.0, 0.5), jit=0.25)
    m.box((0.05, 0.03, 1.4), (-0.15, -0.66, 0.8), EMBER, rot=(0, 6, 0), emit=3.5)   # жила жара
    m.box((0.04, 0.03, 0.6), (0.55, -0.55, 0.4), EMBER_D, rot=(0, -20, 0), emit=3.0)


@model
def decor_embers(m):
    """Куча тлеющих углей и пепла у стены."""
    m.blob(0.45, (0, 0, 0.0), ASH, scale=(1.3, 1.1, 0.35), jit=0.25)
    for i in range(7):
        a = i * 2 * math.pi / 7
        m.blob(0.13, (0.33 * math.cos(a), 0.28 * math.sin(a), 0.1), PEAT if i % 2 else BASALT_D, jit=0.3)
    m.blob(0.14, (0.0, 0.05, 0.16), EMBER, jit=0.3, emit=3.5)
    m.blob(0.09, (0.22, -0.1, 0.1), EMBER_D, jit=0.3, emit=3.0)
    m.blob(0.08, (-0.2, 0.15, 0.1), EMBER, jit=0.3, emit=3.0)


def build_all(out_dir, blend_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(out_dir, exist_ok=True)
    for i, (name, fn) in enumerate(MODELS.items()):
        m = Model(name)
        fn(m)
        ob = m.finish()
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        print("%-18s %4d tris" % (name, tris))
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"), export_format="GLB",
                                  use_selection=True, export_apply=True, export_yup=True)
        ob.location = (i * 4.0, 0, 0)
    if blend_path:
        bpy.ops.wm.save_as_mainfile(filepath=blend_path)


if __name__ == "__main__":
    args = sys.argv[1:]
    build_all(args[0] if args else "out", args[1] if len(args) > 1 else "")
