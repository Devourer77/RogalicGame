# Строит low-poly модели окружения (пропсы и покрытия клеток) и экспортирует каждую в .glb и .blend.
# Масштаб: 1 единица = 1 метр = 1 клетка поля.
# У пропсов точка опоры (0, 0, 0) — внизу по центру.
# У плиток пола (tile_*) верхняя поверхность лежит на высоте z = 0 (от -0.20 до 0.0).
import os
import math
import bpy
import bmesh
from mathutils import Vector, Matrix


# ---------- Материалы ----------

def mat(name, color, metallic=0.0, rough=0.8, emission=None, emission_strength=2.5, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if alpha < 1.0 and "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = alpha
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    m.diffuse_color = (*color, alpha)
    return m


# ---------- Примитивы через bmesh ----------

PARTS = []


def _rot(r):
    return (Matrix.Rotation(math.radians(r[2]), 4, "Z")
            @ Matrix.Rotation(math.radians(r[1]), 4, "Y")
            @ Matrix.Rotation(math.radians(r[0]), 4, "X"))


def _finish(bm, name, material, matrix=None):
    if matrix is not None:
        bmesh.ops.transform(bm, matrix=matrix, verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    PARTS.append(ob)
    return ob


def box(name, size, loc, material, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    m = Matrix.Translation(loc) @ _rot(rot) @ Matrix.Diagonal((*size, 1.0))
    return _finish(bm, name, material, m)


def cyl(name, r1, r2, z0, z1, material, segs=8, loc=(0, 0), scale_xy=(1.0, 1.0), rot=(0, 0, 0)):
    bm = bmesh.new()
    depth = z1 - z0
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=depth)
    m = (Matrix.Translation((loc[0], loc[1], (z0 + z1) / 2.0))
         @ _rot(rot)
         @ Matrix.Diagonal((scale_xy[0], scale_xy[1], 1.0, 1.0)))
    return _finish(bm, name, material, m)


def limb(name, a, b, r1, r2, material, segs=6):
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=r2, depth=d.length)
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    m = Matrix.Translation((a + b) / 2.0) @ q.to_matrix().to_4x4()
    return _finish(bm, name, material, m)


def sphere(name, r, loc, material, scale=(1, 1, 1), segs=7, rings=5, cut_below=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    if cut_below is not None:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, cut_below), plane_no=(0, 0, 1), clear_inner=True)
        edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if edges:
            bmesh.ops.edgeloop_fill(bm, edges=edges)
    m = Matrix.Translation(loc) @ Matrix.Diagonal((*scale, 1.0))
    return _finish(bm, name, material, m)


def prism_xy(name, points_xy, z0, z1, material, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Многоугольник в плоскости XY, выдавленный по Z от z0 до z1."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, z0)) for x, y in points_xy]
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [v for v in res["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=moved, vec=(0, 0, z1 - z0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    m = Matrix.Translation(loc) @ _rot(rot)
    return _finish(bm, name, material, m)


# ---------- Палитра материалов ----------

def palette():
    return {
        "wood": mat("Prop_Wood", (0.36, 0.20, 0.09), rough=0.82),
        "wood_dark": mat("Prop_WoodDark", (0.22, 0.12, 0.05), rough=0.88),
        "wood_light": mat("Prop_WoodLight", (0.48, 0.28, 0.13), rough=0.78),
        "iron": mat("Prop_Iron", (0.18, 0.20, 0.23), metallic=0.82, rough=0.42),
        "steel": mat("Prop_Steel", (0.42, 0.45, 0.50), metallic=0.85, rough=0.35),
        "brass": mat("Prop_Brass", (0.76, 0.54, 0.18), metallic=0.85, rough=0.35),
        "stone": mat("Prop_Stone", (0.34, 0.36, 0.40), rough=0.88),
        "stone_dark": mat("Prop_StoneDark", (0.22, 0.24, 0.27), rough=0.92),
        "stone_light": mat("Prop_StoneLight", (0.45, 0.47, 0.51), rough=0.85),
        "dirt": mat("Prop_Dirt", (0.28, 0.18, 0.10), rough=0.92),
        "dirt_dark": mat("Prop_DirtDark", (0.20, 0.13, 0.07), rough=0.95),
        "grass": mat("Prop_Grass", (0.22, 0.46, 0.15), rough=0.85),
        "leaf1": mat("Prop_Leaf1", (0.18, 0.42, 0.14), rough=0.82),
        "leaf2": mat("Prop_Leaf2", (0.26, 0.52, 0.18), rough=0.80),
        "leaf3": mat("Prop_Leaf3", (0.14, 0.34, 0.11), rough=0.85),
        "water": mat("Prop_Water", (0.14, 0.42, 0.78), metallic=0.25, rough=0.08, alpha=0.85),
        "water_foam": mat("Prop_WaterFoam", (0.55, 0.78, 0.95), rough=0.25),
        "flame": mat("Prop_Flame", (1.0, 0.55, 0.08), rough=0.2, emission=(1.0, 0.45, 0.04), emission_strength=3.5),
        "ember": mat("Prop_Ember", (0.85, 0.22, 0.04), rough=0.6, emission=(0.9, 0.18, 0.02), emission_strength=1.8),
        "lantern_glow": mat("Prop_LanternGlow", (1.0, 0.78, 0.28), rough=0.2, emission=(1.0, 0.70, 0.20), emission_strength=3.2),
        "crystal": mat("Prop_Crystal", (0.30, 0.78, 1.0), rough=0.15, emission=(0.22, 0.68, 1.0), emission_strength=2.8),
    }


# ---------- 1. Бочка (prop_barrel) ----------

def make_barrel(p):
    # Пузатая деревянная бочка из 3 секций + железные обручи + верхняя крышка и пробка
    cyl("BarrelBot", 0.23, 0.29, 0.0, 0.26, p["wood"], segs=10)
    cyl("BarrelMid", 0.29, 0.29, 0.26, 0.52, p["wood"], segs=10)
    cyl("BarrelTop", 0.29, 0.23, 0.52, 0.78, p["wood"], segs=10)
    # Углубление крышки сверху
    cyl("BarrelRim", 0.235, 0.235, 0.74, 0.80, p["wood_dark"], segs=10)
    cyl("BarrelLid", 0.21, 0.21, 0.75, 0.785, p["wood_light"], segs=10)
    # Дощатые швы на крышке и деревянная втулка-пробка
    for x in (-0.07, 0.07):
        box(f"LidSeam_{x}", (0.012, 0.38, 0.01), (x, 0, 0.786), p["wood_dark"])
    cyl("BarrelCork", 0.032, 0.026, 0.78, 0.825, p["wood_dark"], segs=6, loc=(0.06, -0.05))
    # 4 железных обруча
    for i, (z0, z1, r1, r2) in enumerate((
        (0.06, 0.12, 0.248, 0.260),
        (0.24, 0.30, 0.296, 0.298),
        (0.48, 0.54, 0.298, 0.296),
        (0.66, 0.72, 0.260, 0.248),
    )):
        cyl(f"Hoop_{i}", r1, r2, z0, z1, p["iron"], segs=10)
    # Боковая втулка сбоку
    limb("SideSpigot", (0, -0.27, 0.39), (0, -0.34, 0.38), 0.032, 0.022, p["brass"], segs=6)


# ---------- 2. Фонарь (prop_lantern) ----------

def make_lantern(p):
    # Каменное основание и кованый столб
    cyl("BaseStone", 0.22, 0.18, 0.0, 0.14, p["stone"], segs=8)
    cyl("BaseIron", 0.13, 0.08, 0.14, 0.32, p["iron"], segs=8)
    cyl("PostShaft", 0.045, 0.038, 0.30, 1.68, p["iron"], segs=6)
    cyl("PostCollar1", 0.062, 0.062, 0.90, 0.96, p["steel"], segs=6)
    cyl("PostCollar2", 0.060, 0.060, 1.56, 1.62, p["steel"], segs=6)
    limb("PostFinial", (0, 0, 1.68), (0, 0, 1.82), 0.052, 0.008, p["iron"], segs=6)

    # Верхний кронштейн, выходящий вперёд (-Y)
    limb("ArmHoriz", (0, 0, 1.64), (0, -0.38, 1.66), 0.030, 0.024, p["iron"], segs=6)
    limb("ArmBrace", (0, 0, 1.38), (0, -0.24, 1.65), 0.022, 0.020, p["iron"], segs=5)
    limb("Chain", (0, -0.35, 1.66), (0, -0.35, 1.52), 0.014, 0.014, p["steel"], segs=5)

    # Подвесной фонарь со светящимся янтарным ядром
    ly = -0.35
    cyl("LanternCap", 0.13, 0.03, 1.45, 1.54, p["iron"], segs=6, loc=(0, ly))
    cyl("LanternGlass", 0.075, 0.095, 1.24, 1.45, p["lantern_glow"], segs=6, loc=(0, ly))
    cyl("LanternBot", 0.03, 0.085, 1.17, 1.24, p["iron"], segs=6, loc=(0, ly))
    # Вертикальные прутья клетки фонаря
    for ang_deg in range(0, 360, 60):
        rad = math.radians(ang_deg)
        limb(f"CageBar_{ang_deg}",
             (math.cos(rad) * 0.078, ly + math.sin(rad) * 0.078, 1.24),
             (math.cos(rad) * 0.098, ly + math.sin(rad) * 0.098, 1.45),
             0.009, 0.009, p["iron"], segs=4)


# ---------- 3. Заборчик (prop_fence) ----------

def make_fence(p):
    # Секция забора шириной ~0.96 м вдоль оси X
    for side, s in (("L", -1), ("R", 1)):
        px = 0.42 * s
        box(f"PostStone_{side}", (0.16, 0.16, 0.18), (px, 0, 0.09), p["stone"])
        box(f"PostWood_{side}", (0.11, 0.11, 0.56), (px, 0, 0.38), p["wood_dark"], rot=(0, 2 * s, 0))
        limb(f"PostCap_{side}", (px, 0, 0.66), (px, 0, 0.75), 0.085, 0.008, p["iron"], segs=4)

    # Две горизонтальные перекладины
    box("RailLow", (0.88, 0.045, 0.065), (0, 0.02, 0.24), p["wood"], rot=(0, -1.5, 0))
    box("RailHigh", (0.88, 0.045, 0.065), (0, 0.02, 0.50), p["wood"], rot=(0, 1.0, 0))

    # 5 вертикальных планок штакетника с заострёнными верхушками
    for i, (x, h, tilt) in enumerate((
        (-0.26, 0.62, -2.0),
        (-0.13, 0.66, 1.5),
        (0.00, 0.64, -1.0),
        (0.13, 0.67, 2.0),
        (0.26, 0.61, -1.5),
    )):
        mat_use = p["wood_light"] if i % 2 == 0 else p["wood"]
        box(f"Picket_{i}", (0.075, 0.028, h), (x, -0.02, h / 2.0), mat_use, rot=(0, tilt, 0))
        box(f"NailLow_{i}", (0.018, 0.04, 0.018), (x, -0.025, 0.24), p["iron"])
        box(f"NailHigh_{i}", (0.018, 0.04, 0.018), (x, -0.025, 0.50), p["iron"])


# ---------- 4. Лестница (prop_stairs) ----------

def make_stairs(p):
    # Каменная лестница из 4 ступеней (ширина 0.94 м, глубина 0.94 м, высота 0.72 м)
    # Боковые каменные бортики (косоуры)
    side_pts = [(-0.46, 0.0), (0.46, 0.0), (0.46, 0.76), (-0.46, 0.22)]
    for side, s in (("L", -1), ("R", 1)):
        # Строим ступенчатые каменные боковины из блоков
        for step in range(4):
            y_pos = -0.35 + step * 0.23
            h_step = (step + 1) * 0.18 + 0.06
            box(f"SideWall_{side}_{step}", (0.11, 0.24, h_step), (0.415 * s, y_pos, h_step / 2.0), p["stone_dark"])
            box(f"SideCap_{side}_{step}", (0.13, 0.25, 0.035), (0.415 * s, y_pos, h_step + 0.01), p["stone_light"])

    # 4 широкие каменные ступени
    for step in range(4):
        y_pos = -0.35 + step * 0.23
        h_step = (step + 1) * 0.17
        box(f"StepRiser_{step}", (0.72, 0.23, h_step), (0, y_pos, h_step / 2.0), p["stone"])
        # Верхняя накладная плита ступени из двух каменных блоков
        box(f"StepTreadL_{step}", (0.35, 0.25, 0.04), (-0.18, y_pos - 0.01, h_step), p["stone_light"])
        box(f"StepTreadR_{step}", (0.35, 0.25, 0.04), (0.18, y_pos - 0.01, h_step), p["stone"])


# ---------- 5. Дерево (prop_tree) ----------

def make_tree(p):
    # Корни и извилистый гранёный ствол
    for ang_deg in (0, 90, 180, 270):
        rad = math.radians(ang_deg + 25)
        limb(f"Root_{ang_deg}", (0, 0, 0.18), (math.cos(rad) * 0.34, math.sin(rad) * 0.34, 0.0),
             0.11, 0.035, p["wood_dark"], segs=5)

    limb("TrunkLow", (0, 0, 0.0), (0.03, -0.02, 0.58), 0.19, 0.14, p["wood_dark"], segs=7)
    limb("TrunkMid", (0.03, -0.02, 0.55), (-0.04, 0.02, 1.15), 0.14, 0.10, p["wood"], segs=7)
    limb("TrunkTop", (-0.04, 0.02, 1.10), (0.02, 0.0, 1.55), 0.10, 0.05, p["wood"], segs=6)
    limb("BranchL", (-0.02, 0.0, 0.92), (-0.32, -0.08, 1.28), 0.075, 0.035, p["wood"], segs=5)
    limb("BranchR", (0.01, 0.0, 1.02), (0.30, 0.06, 1.35), 0.070, 0.032, p["wood"], segs=5)

    # Многоярусная гранёная крона (сферы и конические шапки с малым числом сегментов)
    sphere("CanopyMain", 0.48, (0.02, 0.0, 1.72), p["leaf1"], scale=(1.1, 1.05, 0.85), segs=7, rings=4)
    sphere("CanopyTop", 0.34, (0.0, 0.02, 2.08), p["leaf2"], scale=(1.0, 1.0, 0.90), segs=7, rings=4)
    sphere("CanopyL", 0.34, (-0.32, -0.08, 1.44), p["leaf2"], scale=(1.05, 1.0, 0.82), segs=6, rings=4)
    sphere("CanopyR", 0.32, (0.30, 0.08, 1.50), p["leaf3"], scale=(1.0, 1.05, 0.82), segs=6, rings=4)
    sphere("CanopyFront", 0.28, (0.04, -0.26, 1.52), p["leaf3"], scale=(1.0, 0.95, 0.78), segs=6, rings=4)


# ---------- 6. Покрытие: Камень (tile_stone) ----------

def make_tile_stone(p):
    # Основание плиты от z = -0.20 до z = -0.025, сверху — рельефные каменные блоки до z = 0.0
    box("Base", (0.97, 0.97, 0.175), (0, 0, -0.1125), p["stone_dark"])
    blocks = [
        ((-0.23, -0.24), (0.46, 0.44), p["stone"]),
        ((0.24, -0.24), (0.44, 0.44), p["stone_light"]),
        ((-0.26, 0.23), (0.40, 0.45), p["stone_light"]),
        ((0.20, 0.23), (0.48, 0.45), p["stone"]),
    ]
    for i, ((bx, by), (sx, sy), m_use) in enumerate(blocks):
        box(f"StoneSlab_{i}", (sx, sy, 0.035), (bx, by, -0.0175), m_use)


# ---------- 7. Покрытие: Дерево (tile_wood) ----------

def make_tile_wood(p):
    box("Base", (0.97, 0.97, 0.17), (0, 0, -0.115), p["wood_dark"])
    # 5 деревянных досок вдоль X с небольшими зазорами и железными заклёпками по краям
    mats = [p["wood"], p["wood_light"], p["wood"], p["wood_dark"], p["wood_light"]]
    for i in range(5):
        y = -0.38 + i * 0.19
        box(f"Plank_{i}", (0.95, 0.175, 0.035), (0, y, -0.0175), mats[i])
        for s in (-1, 1):
            box(f"Nail_{i}_{s}", (0.022, 0.022, 0.01), (0.41 * s, y, 0.002), p["iron"])


# ---------- 8. Покрытие: Земля (tile_dirt) ----------

def make_tile_dirt(p):
    box("Base", (0.97, 0.97, 0.18), (0, 0, -0.11), p["dirt_dark"])
    box("DirtTop", (0.95, 0.95, 0.03), (0, 0, -0.015), p["dirt"])
    # Рельефные кочки земли, мелкие камушки и пучки травы по краям
    for i, (x, y, sx, sy) in enumerate((
        (-0.22, -0.18, 0.36, 0.32),
        (0.24, 0.16, 0.38, 0.34),
        (-0.18, 0.26, 0.30, 0.26),
    )):
        box(f"Clod_{i}", (sx, sy, 0.022), (x, y, -0.004), p["dirt_dark"], rot=(0, 0, i * 25))
    for i, (gx, gy) in enumerate(((-0.34, -0.32), (0.35, -0.28), (-0.30, 0.34))):
        for b_idx, (dx, dy, h) in enumerate(((0, 0, 0.09), (0.03, 0.02, 0.07), (-0.03, 0.01, 0.08))):
            limb(f"Grass_{i}_{b_idx}", (gx, gy, 0.0), (gx + dx, gy + dy, h), 0.018, 0.003, p["grass"], segs=4)


# ---------- 9. Покрытие / эффект: Лужа (tile_puddle) ----------

def make_tile_puddle(p):
    # Каменная плита внизу + 3D-лужа неправильной гранёной формы на поверхности
    make_tile_stone(p)
    puddle_pts = [
        (-0.34, -0.18), (-0.16, -0.38), (0.20, -0.35), (0.38, -0.12),
        (0.35, 0.22), (0.12, 0.38), (-0.24, 0.34), (-0.40, 0.08),
    ]
    prism_xy("PuddleWater", puddle_pts, 0.0, 0.018, p["water"])
    ripple_pts = [(-0.14, -0.08), (0.10, -0.14), (0.18, 0.06), (-0.06, 0.14)]
    prism_xy("PuddleHighlight", ripple_pts, 0.018, 0.022, p["water_foam"])
    # Камушки у края лужи
    sphere("Pebble1", 0.045, (-0.32, 0.24, 0.01), p["stone_dark"], scale=(1.2, 0.9, 0.6), segs=5, rings=4)
    sphere("Pebble2", 0.035, (0.30, -0.26, 0.01), p["stone"], scale=(1.0, 1.1, 0.6), segs=5, rings=4)


# ---------- 10. Доп. пропс: Скальный валун с кристаллами (prop_rock) ----------

def make_rock(p):
    # Группа из 3 гранёных валунов + мшистая шапка + светящийся магический кристалл
    sphere("RockMain", 0.38, (0.04, 0.02, 0.30), p["stone"], scale=(1.05, 0.95, 1.15), segs=6, rings=4, cut_below=-0.28)
    sphere("RockSub1", 0.26, (-0.22, -0.12, 0.18), p["stone_dark"], scale=(1.1, 1.0, 0.95), segs=6, rings=4, cut_below=-0.16)
    sphere("RockSub2", 0.22, (0.20, -0.18, 0.14), p["stone_light"], scale=(1.0, 1.1, 0.85), segs=5, rings=4, cut_below=-0.12)
    # Мох сверху
    sphere("RockMoss", 0.24, (0.04, 0.02, 0.56), p["grass"], scale=(1.1, 1.0, 0.45), segs=6, rings=3, cut_below=0.0)
    # Светящийся кристалл сбоку
    limb("Crystal1", (-0.12, -0.18, 0.22), (-0.24, -0.32, 0.56), 0.055, 0.006, p["crystal"], segs=5)
    limb("Crystal2", (-0.05, -0.22, 0.18), (-0.10, -0.36, 0.42), 0.040, 0.005, p["crystal"], segs=5)


# ---------- 11. Доп. пропс: Окованный ящик (prop_crate) ----------

def make_crate(p):
    s = 0.68
    hs = s / 2.0
    # Внутренний куб из досок
    box("CrateCore", (s - 0.06, s - 0.06, s - 0.06), (0, 0, hs), p["wood"])
    # Рамка по всем 12 рёбрам ящика
    t = 0.065
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(f"EdgeZ_{sx}_{sy}", (t, t, s), (sx * (hs - t / 2), sy * (hs - t / 2), hs), p["wood_dark"])
    for sz, z_pos in ((-1, t / 2), (1, s - t / 2)):
        for sx in (-1, 1):
            box(f"EdgeY_{sz}_{sx}", (t, s, t), (sx * (hs - t / 2), 0, z_pos), p["wood_dark"])
            box(f"EdgeX_{sz}_{sx}", (s, t, t), (0, sx * (hs - t / 2), z_pos), p["wood_dark"])
        for sx in (-1, 1):
            for sy in (-1, 1):
                # Металлические уголки
                box(f"Corner_{sz}_{sx}_{sy}", (0.11, 0.11, 0.11),
                    (sx * (hs - 0.045), sy * (hs - 0.045), z_pos), p["iron"])
    # Диагональные распорки на гранях
    for sy in (-1, 1):
        box(f"BraceY_{sy}", (s * 0.85, 0.03, 0.065), (0, sy * (hs - 0.02), hs), p["wood_light"], rot=(0, 45, 0))
    for sx in (-1, 1):
        box(f"BraceX_{sx}", (0.03, s * 0.85, 0.065), (sx * (hs - 0.02), 0, hs), p["wood_light"], rot=(45, 0, 0))


# ---------- 12. Доп. пропс: Огненная жаровня (prop_brazier) ----------

def make_brazier(p):
    cyl("PedestalBase", 0.28, 0.22, 0.0, 0.16, p["stone_dark"], segs=8)
    cyl("PedestalColumn", 0.15, 0.13, 0.16, 0.52, p["stone"], segs=8)
    # Чугунная чаша на 3 лапах
    cyl("BowlBot", 0.14, 0.30, 0.50, 0.68, p["iron"], segs=8)
    cyl("BowlRim", 0.32, 0.32, 0.66, 0.74, p["steel"], segs=8)
    # Раскалённые угли и яркие языки пламени
    sphere("Embers", 0.25, (0, 0, 0.70), p["ember"], scale=(1.0, 1.0, 0.35), segs=7, rings=4, cut_below=0.0)
    limb("FlameMain", (0, 0, 0.72), (0.02, -0.02, 1.24), 0.14, 0.01, p["flame"], segs=5)
    limb("FlameL", (-0.08, -0.04, 0.72), (-0.14, 0.02, 1.08), 0.09, 0.008, p["flame"], segs=5)
    limb("FlameR", (0.08, 0.04, 0.72), (0.13, -0.03, 1.05), 0.085, 0.008, p["flame"], segs=5)


# ---------- 13. Доп. пропс: Разрушенная руническая колонна (prop_pillar) ----------

def make_pillar(p):
    box("Plinth1", (0.64, 0.64, 0.12), (0, 0, 0.06), p["stone_dark"])
    box("Plinth2", (0.52, 0.52, 0.10), (0, 0, 0.17), p["stone"])
    cyl("ShaftLow", 0.22, 0.20, 0.22, 0.85, p["stone"], segs=8)
    # Верхний обломок колонны со скошенным верхом
    cyl("ShaftTop", 0.20, 0.19, 0.85, 1.32, p["stone_light"], segs=8, loc=(0.02, -0.01), rot=(8, -6, 0))
    # Светящиеся магические руны на гранях колонны
    for ang_deg in (0, 90, 180, 270):
        rad = math.radians(ang_deg)
        rx, ry = math.sin(rad) * 0.202, -math.cos(rad) * 0.202
        box(f"Rune_{ang_deg}", (0.035, 0.015, 0.28), (rx, ry, 0.62), p["crystal"], rot=(0, 0, ang_deg))
    # Упавший обломок у подножия
    cyl("FallenChunk", 0.16, 0.15, -0.14, 0.14, p["stone"], segs=8, loc=(0.24, -0.22), rot=(72, 25, 40))
    for v in bpy.data.objects["FallenChunk"].data.vertices:
        v.co.z += 0.14


# ---------- Список всех моделей ----------

MODELS = {
    "prop_barrel": ("Barrel", make_barrel),
    "prop_lantern": ("Lantern", make_lantern),
    "prop_fence": ("Fence", make_fence),
    "prop_stairs": ("Stairs", make_stairs),
    "prop_tree": ("Tree", make_tree),
    "tile_stone": ("TileStone", make_tile_stone),
    "tile_wood": ("TileWood", make_tile_wood),
    "tile_dirt": ("TileDirt", make_tile_dirt),
    "tile_puddle": ("TilePuddle", make_tile_puddle),
    "prop_rock": ("Rock", make_rock),
    "prop_crate": ("Crate", make_crate),
    "prop_brazier": ("Brazier", make_brazier),
    "prop_pillar": ("Pillar", make_pillar),
}


def build_one(key_name, models_dir, src_dir):
    scene_title, builder = MODELS[key_name]
    scene = bpy.context.scene
    for obj in list(scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene.name = scene_title
    PARTS.clear()

    pal = palette()
    builder(pal)

    bpy.ops.object.select_all(action="DESELECT")
    for ob in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    mesh_ob = bpy.context.view_layer.objects.active
    mesh_ob.name = scene_title
    mesh_ob.data.name = f"{scene_title}Mesh"

    # Сбрасываем origin в (0, 0, 0) в мировых координатах!
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

    glb_path = os.path.join(models_dir, f"{key_name}.glb")
    blend_path = os.path.join(src_dir, f"{key_name}.blend")

    bpy.ops.object.select_all(action="DESELECT")
    mesh_ob.select_set(True)
    bpy.context.view_layer.objects.active = mesh_ob
    bpy.ops.export_scene.gltf(
        filepath=glb_path, export_format="GLB", use_selection=True,
        export_apply=True,
    )
    datablocks = {scene, mesh_ob, mesh_ob.data} | set(mesh_ob.data.materials)
    bpy.data.libraries.write(blend_path, datablocks, fake_user=True, compress=True)
    return scene, mesh_ob


def build_all(models_dir, src_dir):
    results = {}
    for k in MODELS:
        scene, ob = build_one(k, models_dir, src_dir)
        results[k] = (len(ob.data.vertices), len(ob.data.polygons))
        print(f"Exported {k}: verts={results[k][0]}, faces={results[k][1]}")
    return results
