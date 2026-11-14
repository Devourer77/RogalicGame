# Модели хаба «Застава Колокола».
# Запуск из Blender 5.2 (вкладка Scripting → Open → Run Script) собирает и экспортирует всё,
# или из командной строки:
#   blender -b -P build_hub.py -- <папка_проекта> [имя ...]
#   имена — ключи BUILDERS внизу файла (bell, campfire, gate …)
# Каждая модель — своя функция build_<имя>(). Модель сохраняется в assets/models/hub/<имя>.glb,
# исходник — в assets/models/src/hub_<имя>.blend.
#
# Правила (из CLAUDE.md и тз-хаб.md):
# - 1 единица = 1 метр; origin модели — в центре основания на земле; перед смотрит в −Y (в игре это юг).
#   Место в игре: точка Godot (x, z) — это (x, −y) здесь.
# - Low-poly, грани видны (flat shading), материалы — цвет + шероховатость, свечение — Emission.
# - Материалы с именем tex_<имя> игра заменяет своими текстурами (assets/textures/hub/hub_<имя>.png).
# - Подвижные и сменные части — отдельные объекты со своей точкой опоры.
# - Красного нет.

import math
import sys
from pathlib import Path

import bpy   # bpy раньше bmesh: так скрипт работает и как модуль Python
import bmesh
from mathutils import Matrix, Vector

# --- Материалы ------------------------------------------------------------------------
# Цвета в sRGB (как в палитре мир.md); Blender хранит их линейными — переводим в _srgb().
# Значение: (цвет, шероховатость, металличность).

PALETTE: dict = {
	"tex_stone": ((0.34, 0.35, 0.34), 0.95, 0.0),      # заменяется текстурой hub_stone
	"tex_wood": ((0.32, 0.23, 0.16), 0.9, 0.0),        # hub_wood
	"tex_planks": ((0.3, 0.26, 0.2), 0.9, 0.0),        # hub_planks (кровля из досок)
	"tex_masonry": ((0.33, 0.34, 0.33), 0.95, 0.0),    # hub_masonry
	"tex_turf": ((0.2, 0.26, 0.13), 1.0, 0.0),         # hub_turf
	"tex_ground": ((0.22, 0.19, 0.13), 1.0, 0.0),      # hub_ground
	"brass": ((0.52, 0.45, 0.22), 0.45, 0.7),          # потемневшая латунь с прозеленью
	"brass_dark": ((0.26, 0.22, 0.11), 0.6, 0.6),
	"iron": ((0.16, 0.16, 0.17), 0.7, 0.6),
	"steel": ((0.5, 0.52, 0.55), 0.45, 0.8),           # тусклая сталь Стражи
	"rope": ((0.45, 0.38, 0.26), 1.0, 0.0),
	"candle": ((0.86, 0.8, 0.66), 0.7, 0.0),           # кремовый воск, не красный
	"charcoal": ((0.12, 0.09, 0.07), 1.0, 0.0),
	"ash": ((0.16, 0.15, 0.14), 1.0, 0.0),
	"wool": ((0.4, 0.36, 0.3), 1.0, 0.0),
	"paper": ((0.8, 0.74, 0.6), 0.9, 0.0),
	"map": ((0.62, 0.62, 0.46), 0.9, 0.0),
	"mustard": ((0.6, 0.45, 0.12), 0.95, 0.0),         # тёмно-жёлтое сукно Стражи
	"navy": ((0.12, 0.14, 0.26), 0.8, 0.0),            # Маг
	"violet": ((0.42, 0.3, 0.58), 0.5, 0.5),
	"straw": ((0.56, 0.46, 0.27), 1.0, 0.0),
	"dark_stone": ((0.14, 0.15, 0.15), 1.0, 0.0),      # вырезанные знаки
	"glass": ((0.25, 0.24, 0.2), 0.3, 0.0),            # стекло фонаря; игра зажигает его сама
	"orb": ((0.2, 0.2, 0.2), 0.4, 0.0),                # шар духа; цвет задаёт игра
	"cloth_grey": ((0.45, 0.46, 0.45), 1.0, 0.0),
}
# Светящиеся материалы: (цвет, сила свечения)
EMISSIVE: dict = {
	"flame": ((1.0, 0.72, 0.38), 6.0),       # свечи
	"fire": ((1.0, 0.55, 0.18), 8.0),        # костёр — оранжевый, без красного
	"lamp": ((1.0, 0.66, 0.3), 5.0),         # всегда горящие фонари (ворота, доска)
	"window": ((1.0, 0.68, 0.35), 3.0),
	"rune": ((0.55, 0.35, 0.95), 1.2),         # фиолетовые знаки Круга
	"chalk": ((0.42, 0.32, 0.62), 0.25),
	"crystal": ((0.25, 0.35, 1.0), 4.0),     # тёмно-синий, не бирюза
}


def _srgb(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name: str) -> bpy.types.Material:
	if name in bpy.data.materials:
		return bpy.data.materials[name]
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	key = name.rstrip("0123456789")   # flame0…flame5 — свой материал у каждой свечи
	if key in EMISSIVE:
		col, strength = EMISSIVE[key]
		bsdf.inputs["Emission Color"].default_value = (*[_srgb(c) for c in col], 1.0)
		bsdf.inputs["Emission Strength"].default_value = strength
		rough, metal = 1.0, 0.0
	else:
		col, rough, metal = PALETTE[key]
	bsdf.inputs["Base Color"].default_value = (*[_srgb(c) for c in col], 1.0)
	bsdf.inputs["Roughness"].default_value = rough
	bsdf.inputs["Metallic"].default_value = metal
	return mat


# --- Сборка мешей ---------------------------------------------------------------------

def _basis(d: Vector):
	"""Два вектора поперёк оси d, так что u × v = d (кольцо идёт против часовой вокруг d)."""
	d = d.normalized()
	ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
	u = ref.cross(d).normalized()
	v = d.cross(u)
	return u, v


class Part:
	"""Один объект модели: копит геометрию в bmesh, у каждой грани свой материал."""

	def __init__(self, name: str) -> None:
		self.name = name
		self.bm = bmesh.new()
		self.mats: list = []

	def _mat_index(self, mat_name: str) -> int:
		if mat_name not in self.mats:
			self.mats.append(mat_name)
		return self.mats.index(mat_name)

	def add(self, verts: list, faces: list, mat_name: str) -> None:
		idx = self._mat_index(mat_name)
		bv = [self.bm.verts.new(v) for v in verts]
		for f in faces:
			face = self.bm.faces.new([bv[i] for i in f])
			face.material_index = idx

	def box(self, center, size, mat_name: str, rot_y: float = 0.0, rot_z: float = 0.0,
			rot_x: float = 0.0) -> None:
		"""Коробка: center — центр, size — (x, y, z), повороты в градусах (сначала X, потом Y, потом Z)."""
		hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
		m = Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.radians(rot_z), 4, "Z") \
			@ Matrix.Rotation(math.radians(rot_y), 4, "Y") @ Matrix.Rotation(math.radians(rot_x), 4, "X")
		pts = [m @ Vector((x, y, z)) for z in (-hz, hz) for y in (-hy, hy) for x in (-hx, hx)]
		faces = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
		self.add(pts, faces, mat_name)

	def lathe_axis(self, profile: list, segments: int, mat_name: str, origin, axis,
			cap_top: bool = True, cap_bottom: bool = True, phase: float = 0.0) -> None:
		"""Тело вращения вокруг оси axis из точки origin: profile — [(радиус, расстояние вдоль оси)]."""
		o = Vector(origin)
		d = Vector(axis).normalized()
		u, v = _basis(d)
		verts = []
		for r, t in profile:
			for s in range(segments):
				a = 2 * math.pi * (s + phase) / segments
				verts.append(o + d * t + (u * math.cos(a) + v * math.sin(a)) * r)
		faces = []
		n = segments
		for i in range(len(profile) - 1):
			for s in range(n):
				a, b = i * n + s, i * n + (s + 1) % n
				faces.append((a, b, b + n, a + n))
		if cap_bottom and profile[0][0] > 0.0:
			faces.append(tuple(reversed(range(n))))
		if cap_top and profile[-1][0] > 0.0:
			last = (len(profile) - 1) * n
			faces.append(tuple(range(last, last + n)))
		self.add(verts, faces, mat_name)

	def lathe(self, profile: list, segments: int, mat_name: str, base=(0, 0, 0), cap_top: bool = True,
			cap_bottom: bool = True, phase: float = 0.0) -> None:
		"""Тело вращения вокруг вертикали: profile — [(радиус, высота)] снизу вверх."""
		self.lathe_axis(profile, segments, mat_name, base, (0, 0, 1), cap_top, cap_bottom, phase)

	def log(self, p0, p1, r: float, segments: int, mat_name: str, spike: float = 0.0,
			r1: float = -1.0, cap_bottom: bool = True) -> None:
		"""Бревно (или прут) от p0 до p1; spike > 0 — заострённый конец такой длины за p1."""
		p0, p1 = Vector(p0), Vector(p1)
		length = (p1 - p0).length
		r1 = r if r1 < 0.0 else r1
		prof = [(r, 0.0), (r1, length)]
		if spike > 0.0:
			prof.append((0.0, length + spike))
		self.lathe_axis(prof, segments, mat_name, p0, p1 - p0, cap_top=spike <= 0.0, cap_bottom=cap_bottom)

	def sphere(self, center, r: float, segments: int, rings: int, mat_name: str) -> None:
		prof = [(r * math.sin(math.pi * i / rings), -r * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
		self.lathe_axis(prof, segments, mat_name, center, (0, 0, 1))

	def build(self, origin=(0, 0, 0)) -> bpy.types.Object:
		"""Создаёт объект. origin — точка опоры в координатах модели (геометрия сдвигается)."""
		# Нормали не пересчитываем: порядок вершин в add/box/lathe уже даёт грани наружу
		bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0001)
		bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-Vector(origin))
		mesh = bpy.data.meshes.new(self.name)
		self.bm.to_mesh(mesh)
		self.bm.free()
		for p in mesh.polygons:
			p.use_smooth = False   # грани видны
		for m in self.mats:
			mesh.materials.append(material(m))
		obj = bpy.data.objects.new(self.name, mesh)
		obj.location = origin
		bpy.context.scene.collection.objects.link(obj)
		return obj


def jitter(i: int, amount: float) -> float:
	"""Детерминированный «случайный» сдвиг: модель собирается всегда одинаково."""
	return (math.sin(i * 12.9898 + 4.1) * 43758.5453 % 1.0 - 0.5) * 2.0 * amount


def g(x: float, z: float, h: float = 0.0) -> tuple:
	"""Точка из координат игры (x, z на земле, h — высота) в координаты Blender."""
	return (x, -z, h)


def clear_scene() -> None:
	bpy.ops.wm.read_factory_settings(use_empty=True)


def triangles() -> int:
	total = 0
	for o in bpy.context.scene.objects:
		if o.type == "MESH":
			o.data.calc_loop_triangles()
			total += len(o.data.loop_triangles)
	return total


def export(project: Path, name: str) -> None:
	out = project / "assets" / "models" / "hub"
	src = project / "assets" / "models" / "src"
	out.mkdir(parents=True, exist_ok=True)
	src.mkdir(parents=True, exist_ok=True)
	bpy.ops.wm.save_as_mainfile(filepath=str(src / f"hub_{name}.blend"))
	bpy.ops.export_scene.gltf(filepath=str(out / f"{name}.glb"), export_format="GLB",
		export_apply=True, export_yup=True, use_selection=False)
	print(f"{name}: {triangles()} треугольников → {out / (name + '.glb')}")


# --- Общие детали ---------------------------------------------------------------------

def candle_with_flame(index: int, x: float, y: float, z: float, h: float, name: str = "Candle",
		flame_mat: str = "flame") -> None:
	"""Свеча и её пламя отдельными объектами (Candle<i> и Flame<i>)."""
	candle = Part(f"{name}{index}")
	candle.lathe([(0.06, 0.0), (0.05, 0.03), (0.045, h)], 5, "candle", base=(x, y, z), cap_bottom=False)
	candle.build(origin=(x, y, z))
	flame = Part(f"Flame{index}")
	fz = z + h + 0.02
	flame.add([(x, y, fz), (x + 0.03, y, fz + 0.05), (x, y + 0.03, fz + 0.05), (x - 0.03, y, fz + 0.05),
		(x, y - 0.03, fz + 0.05), (x, y, fz + 0.15)],
		[(0, 2, 1), (0, 3, 2), (0, 4, 3), (0, 1, 4), (1, 2, 5), (2, 3, 5), (3, 4, 5), (4, 1, 5)],
		flame_mat)
	flame.build(origin=(x, y, fz))


def small_candle(part: Part, x: float, y: float, h: float = 0.14) -> None:
	"""Огарок прямо в объекте part (горит всегда)."""
	part.lathe([(0.04, 0.0), (0.035, h)], 5, "candle", base=(x, y, 0.0), cap_bottom=False)
	fz = h + 0.01
	part.add([(x, y, fz), (x + 0.025, y, fz + 0.04), (x, y + 0.025, fz + 0.04), (x - 0.025, y, fz + 0.04),
		(x, y - 0.025, fz + 0.04), (x, y, fz + 0.12)],
		[(0, 2, 1), (0, 3, 2), (0, 4, 3), (0, 1, 4), (1, 2, 5), (2, 3, 5), (3, 4, 5), (4, 1, 5)], "flame")


def lantern(part: Part, x: float, y: float, z: float, glass_mat: str, size: float = 0.22,
		glass_part: "Part | None" = None) -> None:
	"""Фонарь Стражи: z — низ фонаря. Стекло можно положить в отдельный объект glass_part."""
	s = size
	part.box((x, y, z + 0.02), (s, s, 0.04), "iron")                      # дно
	for dx in (-1, 1):
		for dy in (-1, 1):
			part.box((x + dx * s * 0.45, y + dy * s * 0.45, z + s * 0.65), (0.025, 0.025, s * 1.25), "iron")
	# крыша-пирамидка и колечко-колокольчик сверху
	top = z + s * 1.3
	part.add([(x - s * 0.55, y - s * 0.55, top), (x + s * 0.55, y - s * 0.55, top),
		(x + s * 0.55, y + s * 0.55, top), (x - s * 0.55, y + s * 0.55, top), (x, y, top + s * 0.4)],
		[(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)], "iron")
	gp = glass_part if glass_part is not None else part
	gp.box((x, y, z + s * 0.65), (s * 0.82, s * 0.82, s * 1.15), glass_mat)


def ragged_cloth(part: Part, x: float, y: float, top: float, w: float, h: float, mat: str,
		seed: int, teeth: int = 5, face_x: bool = False) -> None:
	"""Плоское полотнище с рваным низом (знамя, табард). face_x — смотрит вдоль X, а не −Y."""
	verts = []
	pts = [(-w / 2, top), (w / 2, top)]
	for i in range(teeth * 2 + 1):
		t = i / (teeth * 2)
		px = w / 2 - w * t
		pz = top - h + (0.0 if i % 2 == 0 else 0.12 + abs(jitter(seed + i, 0.06)))
		pts.append((px, pz))
	thick = 0.015
	for side in (-thick, thick):
		for px, pz in pts:
			verts.append((x + side, y + px, pz) if face_x else (x + px, y + side, pz))
	n = len(pts)
	# Каждая сторона полотнища смотрит наружу (иначе Godot её не нарисует)
	if face_x:
		faces = [tuple(range(n)), tuple(n + i for i in reversed(range(n)))]
	else:
		faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))]
	part.add(verts, faces, mat)


def bell_emblem(part: Part, x: float, y: float, z: float, s: float, mat: str, face_x: float = 0.0) -> None:
	"""Плоский герб-колокольчик на поверхности. face_x: 0 — смотрит в −Y, ±1 — в ±X."""
	shape = [(-0.5, 0.0), (0.5, 0.0), (0.42, 0.15), (0.3, 0.75), (0.12, 0.95), (-0.12, 0.95), (-0.3, 0.75),
		(-0.42, 0.15)]
	verts = []
	for depth in (0.0, 0.02):
		for px, pz in shape:
			if face_x == 0.0:
				verts.append((x + px * s, y - depth, z + pz * s))
			else:
				verts.append((x + face_x * depth, y - face_x * px * s, z + pz * s))
	n = len(shape)
	part.add(verts, [tuple(range(n, 2 * n)), tuple(reversed(range(n)))], mat)


# --- Колокол Стражи -------------------------------------------------------------------
# Размеры совпадают с заглушкой в hub.gd: площадка Ø 3,6 × 0,3 м, столбы 0,3 × 0,3 × 3 м
# с осями на x = ±0,9, балка сверху до 3,3 м, колокол Ø 1,2 × 1,4 м, ось качания — 2,9 м.
# Объекты: Platform, Frame, Bell (origin на оси качания), Candle0…5 и Flame0…5 (по Звону на свечу).

BELL_PIVOT_Z: float = 2.9
BELL_TOP_Z: float = 2.62
BELL_HEIGHT: float = 1.4
BELL_SEGMENTS: int = 12   # граней по кругу у колокола
CANDLE_XS: list = [-0.8 + 0.32 * i for i in range(6)]


def build_bell() -> None:
	clear_scene()

	# Площадка: утоптанный каменный круг и бордюр из 12 блоков, одного блока у края нет
	plat = Part("Platform")
	plat.lathe([(1.5, 0.0), (1.5, 0.24)], 12, "tex_stone", phase=0.5, cap_bottom=False)
	for i in range(12):
		if i == 7:
			continue   # выпавший камень
		a = 2 * math.pi * i / 12
		r = 1.62
		h = 0.3 + jitter(i, 0.03)
		plat.box((r * math.cos(a), r * math.sin(a), h / 2), (0.36, 0.78, h), "tex_stone",
			rot_z=math.degrees(a) + jitter(i + 20, 2.0))
	plat.build()

	# Рама: два столба, балка с выступами, две распорки, железные скобы
	frame = Part("Frame")
	for side in (-1, 1):
		x = 0.9 * side
		frame.box((x, 0, 1.5), (0.3, 0.3, 3.0), "tex_wood")
		frame.box((x, 0, 0.75), (0.34, 0.34, 0.1), "iron")      # нижняя скоба
		frame.box((x, 0, 2.55), (0.34, 0.34, 0.1), "iron")      # верхняя скоба
		# Распорка от столба к балке под 45°
		frame.box((x - 0.27 * side, 0, 2.73), (0.12, 0.16, 0.62), "tex_wood", rot_y=-40.0 * side)
	frame.box((0, 0, 3.15), (2.4, 0.32, 0.3), "tex_wood")       # балка шире рамы, как на эскизе
	for side in (-1, 1):
		frame.box((0.22 * side, 0, 3.0), (0.06, 0.36, 0.34), "iron")   # хомуты, держат ушко колокола
	frame.build()

	# Колокол: тело вращения из 14 граней, ушко, язык с верёвкой, трещина и герб спереди
	bell = Part("Bell")
	top = BELL_TOP_Z
	bot = top - BELL_HEIGHT
	profile = [
		(0.64, bot), (0.52, bot + 0.14), (0.43, bot + 0.5),
		(0.4, top - 0.22), (0.34, top - 0.06), (0.2, top),
	]
	bell.lathe(profile, BELL_SEGMENTS, "brass", cap_bottom=False, phase=0.5)
	# Изнанка: тёмная поверхность внутри, чтобы снизу не просвечивало
	inner = [(0.59, bot + 0.02), (0.35, top - 0.2), (0.0, top - 0.15)]
	bell.lathe(list(reversed(inner)), BELL_SEGMENTS, "brass_dark", cap_top=False, cap_bottom=False, phase=0.5)
	bell.lathe([(0.59, bot + 0.02), (0.64, bot)], BELL_SEGMENTS, "brass_dark", cap_top=False, cap_bottom=False, phase=0.5)
	# Пояс у края
	bell.lathe([(0.66, bot + 0.08), (0.66, bot + 0.15), (0.55, bot + 0.15)], BELL_SEGMENTS, "brass_dark",
		cap_top=False, cap_bottom=False, phase=0.5)
	# Ушко — две железные пластины к оси
	bell.box((0, 0, (top + BELL_PIVOT_Z) / 2 + 0.03), (0.32, 0.12, BELL_PIVOT_Z - top + 0.1), "iron")
	# Язык и верёвка
	bell.lathe([(0.03, bot + 0.1), (0.03, top - 0.1)], 5, "iron")
	bell.lathe([(0.0, bot - 0.05), (0.09, bot + 0.05), (0.0, bot + 0.2)], 5, "iron")
	rope_top = bot - 0.05
	bell.lathe([(0.035, rope_top - 0.72), (0.035, rope_top - 0.35), (0.03, rope_top)], 4, "rope")
	bell.lathe([(0.0, rope_top - 0.82), (0.06, rope_top - 0.72)], 4, "rope", cap_bottom=False)   # махровый конец
	# Трещина: ломаная тёмная полоса спереди, чуть поверх латуни
	crack = [(0.03, bot), (-0.02, bot + 0.18), (0.04, bot + 0.36), (-0.01, bot + 0.55)]
	for i in range(len(crack) - 1):
		(x0, z0), (x1, z1) = crack[i], crack[i + 1]
		r0 = _bell_radius(profile, z0) + 0.006
		r1 = _bell_radius(profile, z1) + 0.006
		w = 0.022
		bell.add([(x0 - w, -r0, z0), (x0 + w, -r0, z0), (x1 + w, -r1, z1), (x1 - w, -r1, z1)],
			[(0, 1, 2, 3)], "brass_dark")
	# Герб — маленький выпуклый колокольчик на груди
	emb_z = bot + 0.95
	emb_r = _bell_radius(profile, emb_z)
	bell.add([(-0.07, -emb_r - 0.02, emb_z - 0.07), (0.07, -emb_r - 0.02, emb_z - 0.07),
		(0.035, -emb_r - 0.02, emb_z + 0.06), (-0.035, -emb_r - 0.02, emb_z + 0.06),
		(-0.08, -emb_r + 0.01, emb_z - 0.08), (0.08, -emb_r + 0.01, emb_z - 0.08),
		(0.04, -emb_r + 0.01, emb_z + 0.07), (-0.04, -emb_r + 0.01, emb_z + 0.07)],
		[(0, 1, 2, 3), (4, 0, 3, 7), (1, 5, 6, 2), (3, 2, 6, 7), (4, 5, 1, 0)], "brass_dark")
	bell.build(origin=(0, 0, BELL_PIVOT_Z))

	# Свечи на балке: ровный ряд из шести, у каждой своё пламя (игра зажигает по одной)
	beam_top = 3.3
	for i, x in enumerate(CANDLE_XS):
		h = 0.2 + jitter(i + 40, 0.03)
		candle = Part(f"Candle{i}")
		candle.lathe([(0.06, 0.0), (0.05, 0.03), (0.045, h)], 5, "candle", base=(x, 0, beam_top),
			cap_bottom=False)   # внизу шире — натёк воска
		candle.build(origin=(x, 0, beam_top))
		flame = Part(f"Flame{i}")
		fz = beam_top + h + 0.02
		flame.add([(x, 0, fz), (x + 0.03, 0, fz + 0.05), (x, 0.03, fz + 0.05), (x - 0.03, 0, fz + 0.05),
			(x, -0.03, fz + 0.05), (x, 0, fz + 0.15)],
			[(0, 2, 1), (0, 3, 2), (0, 4, 3), (0, 1, 4), (1, 2, 5), (2, 3, 5), (3, 4, 5), (4, 1, 5)],
			f"flame{i}")
		flame.build(origin=(x, 0, fz))


def _bell_radius(profile: list, z: float) -> float:
	"""Радиус колокола на высоте z (линейно между точками профиля)."""
	for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
		if z0 <= z <= z1:
			t = (z - z0) / max(z1 - z0, 1e-6)
			return r0 + (r1 - r0) * t
	return profile[-1][0]




def tongue(part: Part, x: float, y: float, z: float, r: float, h: float, mat: str) -> None:
	"""Язык пламени: четырёхгранная «капля» от z вверх на h."""
	m = z + h * 0.3
	part.add([(x, y, z), (x + r, y, m), (x, y + r, m), (x - r, y, m), (x, y - r, m), (x, y, z + h)],
		[(0, 2, 1), (0, 3, 2), (0, 4, 3), (0, 1, 4), (1, 2, 5), (2, 3, 5), (3, 4, 5), (4, 1, 5)], mat)


def curb_ring(part: Part, radius: float, count: int, height: float, skip: int = -1, seed: int = 0) -> None:
	"""Бордюр из каменных блоков по кругу (как у площадки колокола)."""
	circ = 2 * math.pi * radius / count
	for i in range(count):
		if i == skip:
			continue
		a = 2 * math.pi * i / count
		h = height + jitter(seed + i, 0.03)
		part.box((radius * math.cos(a), radius * math.sin(a), h / 2), (0.34, circ * 0.92, h), "tex_stone",
			rot_z=math.degrees(a) + jitter(seed + i + 20, 2.0))


# --- Костёр ---------------------------------------------------------------------------
# Место в игре: FIRE_POS (0, 0, 4.5). Кольцо Ø 1,6 м; скамьи на x = ±1,8 (там садятся герои);
# за огнём (на север) — пень и подстилка: пустые места для будущих героев.

def build_campfire() -> None:
	clear_scene()
	ring = Part("Ring")
	for i in range(9):
		a = 2 * math.pi * i / 9
		h = 0.26 + jitter(i, 0.04)
		ring.box((0.68 * math.cos(a), 0.68 * math.sin(a), h / 2), (0.3, 0.44, h), "tex_stone",
			rot_z=math.degrees(a) + jitter(i + 9, 6.0))
	ring.lathe([(0.56, 0.0), (0.56, 0.03)], 9, "ash", cap_bottom=False)
	ring.build()

	logs = Part("Logs")
	for i, ang in enumerate((15, 75, 135, 195, 255, 315)):
		a = math.radians(ang)
		logs.log((0.42 * math.cos(a), 0.42 * math.sin(a), 0.05), (0.06 * math.cos(a), 0.06 * math.sin(a), 0.3),
			0.05, 5, "charcoal")
	logs.build()

	# Огонь — отдельно: на нём будут искры, и его можно «дышать» в игре
	flame = Part("Flame")
	tongue(flame, 0.0, 0.0, 0.12, 0.17, 0.62, "fire")
	tongue(flame, 0.13, 0.07, 0.1, 0.11, 0.42, "fire")
	tongue(flame, -0.12, 0.05, 0.1, 0.1, 0.38, "fire")
	tongue(flame, 0.02, -0.13, 0.1, 0.1, 0.36, "fire")
	flame.build(origin=(0, 0, 0.1))

	for name, side in (("BenchWest", -1), ("BenchEast", 1)):
		bench = Part(name)
		x = 1.8 * side
		# Верх скамьи на 0,42 м — под эту высоту сделана анимация Sit у героев
		bench.box((x, 0, 0.36), (0.42, 1.6, 0.12), "tex_wood", rot_z=jitter(side + 3, 3.0))
		for y in (-0.55, 0.55):
			bench.log((x, y, 0.0), (x, y, 0.3), 0.13, 6, "tex_wood", cap_bottom=False)
		bench.build(origin=(x, 0, 0))

	stump = Part("SeatStump")
	stump.log((-0.6, 1.7, 0.0), (-0.6, 1.7, 0.42), 0.24, 7, "tex_wood", r1=0.22, cap_bottom=False)
	stump.build(origin=(-0.6, 1.7, 0))
	blanket = Part("SeatBlanket")
	blanket.box((0.7, 1.7, 0.03), (0.9, 0.6, 0.06), "wool", rot_z=-6.0)
	blanket.box((0.66, 1.68, 0.075), (0.78, 0.5, 0.04), "wool", rot_z=-2.0)
	blanket.build(origin=(0.7, 1.7, 0))

	# Мелочи: котелок на рогатине, поленница, кружки
	props = Part("Props")
	for dx in (-0.28, 0.28):
		props.log((1.0 + dx, -0.85, 0.0), (1.0 + dx * 0.8, -0.85, 0.72), 0.02, 4, "iron")
	props.box((1.0, -0.85, 0.72), (0.6, 0.03, 0.03), "iron")
	props.box((1.0, -0.85, 0.55), (0.015, 0.015, 0.32), "iron")
	props.lathe([(0.0, 0.18), (0.13, 0.2), (0.16, 0.3), (0.13, 0.42)], 6, "iron", base=(1.0, -0.85, 0.0))
	for k in range(5):
		row, col = divmod(k, 3)
		y = -1.3 + 0.13 * col + 0.065 * row
		props.log((1.15, y, 0.07 + 0.12 * row), (1.6, y, 0.07 + 0.12 * row), 0.06, 5, "tex_wood")
	props.lathe([(0.045, 0.0), (0.05, 0.09)], 5, "tex_wood", base=(1.8, -0.45, 0.45))
	props.lathe([(0.045, 0.0), (0.05, 0.09)], 5, "brass", base=(0.85, 1.55, 0.0))
	props.build()


# --- Ворота «Тропа к Шпилю» -----------------------------------------------------------
# Место в игре: (0, 0, -7.2). Столбы 0,4 × 3,2 м на x = ±1,6; фонарь справа; знамя (Banner)
# появляется после первой победы над боссом.

def build_gate() -> None:
	clear_scene()
	posts = Part("Posts")
	for side in (-1, 1):
		x = 1.6 * side
		posts.box((x, 0, 1.6), (0.4, 0.4, 3.2), "tex_wood")
		posts.box((x, -0.205, 1.78), (0.24, 0.03, 0.32), "tex_wood")          # дощечка с гербом
		bell_emblem(posts, x, -0.225, 1.66, 0.22, "iron")
		posts.box((x, 0, 3.37), (0.16, 0.16, 0.34), "tex_wood")               # подпорка крыши
	for z in (0.7, 1.6, 2.5):
		posts.box((-1.38, -0.05, z), (0.06, 0.3, 0.07), "iron")              # петли от сорванных створок
	posts.box((0, 0, 2.95), (4.0, 0.36, 0.3), "tex_wood")
	posts.box((0, 0, 3.66), (4.5, 0.1, 0.1), "tex_wood")                    # конёк
	for s in (-1, 1):
		posts.box((0, s * 0.41, 3.41), (4.4, 0.95, 0.08), "tex_planks", rot_x=-30.0 * s)
	# Фонарь на шесте справа — горит всегда
	posts.box((1.95, 0, 2.45), (0.5, 0.08, 0.08), "tex_wood")
	posts.box((2.12, 0, 2.31), (0.02, 0.02, 0.2), "iron")
	lantern(posts, 2.12, 0, 1.92, "lamp", 0.2)
	posts.build()

	banner = Part("Banner")
	banner.box((0, 0, 2.75), (1.2, 0.05, 0.05), "iron")
	ragged_cloth(banner, 0, 0, 2.72, 1.0, 1.4, "mustard", 30)
	bell_emblem(banner, 0, -0.03, 1.95, 0.38, "steel")
	banner.build(origin=(0, 0, 2.75))


# --- Караульня ------------------------------------------------------------------------
# Место в игре: (-8.5, 0, -5.2). Дом 4 × 3 м, стены 2,5 м, дверь и окно смотрят на юг.
# Door — origin на левой петле: игра поворачивает её внутрь на 80°.
# Внутри (видно в проём): сундуки героев, стол со свечой и три стопки карт (CardsSmall/Medium/Large).

BARRACKS_DOOR_Y: float = -1.42


def build_barracks() -> None:
	clear_scene()
	walls = Part("Walls")
	t = 0.25
	walls.box((0, 1.5 - t / 2, 1.25), (4.0, t, 2.5), "tex_masonry")              # задняя
	for side in (-1, 1):
		walls.box((side * (2.0 - t / 2), 0, 1.25), (t, 3.0 - 2 * t, 2.5), "tex_masonry")
	# Передняя стена с проёмом под дверь (x от -0.45 до 0.45, высота 1,8)
	walls.box((-1.225, -1.5 + t / 2, 1.25), (1.55, t, 2.5), "tex_masonry")
	walls.box((1.225, -1.5 + t / 2, 1.25), (1.55, t, 2.5), "tex_masonry")
	walls.box((0, -1.5 + t / 2, 2.15), (0.9, t, 0.7), "tex_masonry")
	walls.box((0, 0, 0.02), (3.5, 2.5, 0.04), "tex_wood")                         # пол
	# Косяк, порог, ступенька
	for side in (-1, 1):
		walls.box((side * 0.5, -1.53, 0.95), (0.1, 0.08, 1.9), "tex_wood")
	walls.box((0, -1.53, 1.9), (1.1, 0.1, 0.12), "tex_wood")
	walls.box((0, -1.72, 0.06), (1.1, 0.36, 0.12), "tex_wood")
	# Рама окна и открытая ставня
	walls.box((1.3, -1.52, 0.78), (0.72, 0.06, 0.06), "tex_wood")
	walls.box((1.3, -1.52, 1.42), (0.72, 0.06, 0.06), "tex_wood")
	walls.box((1.3, -1.52, 1.1), (0.04, 0.05, 0.6), "tex_wood")
	walls.box((1.83, -1.6, 1.1), (0.34, 0.04, 0.62), "tex_wood", rot_z=-55.0)
	# Крюк для фонаря у двери
	walls.box((0.68, -1.56, 1.55), (0.04, 0.12, 0.04), "iron")
	# Крыша: дёрн на двух скатах, конёк вдоль фасада; концы балок торчат из-под карниза
	for s in (-1, 1):
		walls.box((0, s * 0.84, 2.86), (4.6, 1.95, 0.22), "tex_turf", rot_x=-30.0 * s)
	walls.box((0, 0, 3.34), (4.7, 0.14, 0.14), "tex_wood")
	for k in range(6):
		walls.box((-1.9 + 0.76 * k, -1.62, 2.42), (0.12, 0.3, 0.12), "tex_wood")
	for side in (-1, 1):
		x_out, x_in = side * 2.0, side * 1.75
		tri_out = [(x_out, -1.5, 2.5), (x_out, 1.5, 2.5), (x_out, 0, 3.3)]
		tri_in = [(x_in, -1.25, 2.5), (x_in, 1.25, 2.5), (x_in, 0, 3.15)]
		if side > 0:
			walls.add(tri_out, [(0, 1, 2)], "tex_wood")
			walls.add(tri_in, [(2, 1, 0)], "tex_wood")
		else:
			walls.add(tri_out, [(2, 1, 0)], "tex_wood")
			walls.add(tri_in, [(0, 1, 2)], "tex_wood")
	# Бочка с дождевой водой у угла
	walls.lathe([(0.2, 0.0), (0.25, 0.3), (0.2, 0.6)], 8, "tex_wood", base=(2.3, -1.15, 0.0), cap_bottom=False)
	for hz in (0.1, 0.5):
		walls.lathe([(0.23 + (0.02 if hz < 0.3 else 0.0), hz), (0.24, hz + 0.05)], 8, "iron",
			base=(2.3, -1.15, 0.0), cap_top=False, cap_bottom=False)
	walls.build()

	window = Part("Window")
	window.box((1.3, -1.51, 1.1), (0.58, 0.02, 0.6), "window")
	window.build(origin=(1.3, -1.51, 0.8))

	door = Part("Door")
	dy = BARRACKS_DOOR_Y
	door.box((0, dy, 0.9), (0.9, 0.06, 1.8), "tex_wood")
	for z in (0.35, 1.45):
		door.box((0, dy - 0.04, z), (0.86, 0.02, 0.08), "iron")
	bell_emblem(door, 0.08, dy - 0.04, 0.95, 0.3, "iron")
	door.box((0.33, dy - 0.05, 0.95), (0.04, 0.04, 0.12), "iron")                  # ручка-кольцо
	door.build(origin=(-0.45, dy, 0))

	# Мебель внутри
	mage = Part("ChestMage")
	mx, my = -0.6, 0.95
	mage.box((mx, my, 0.24), (0.8, 0.48, 0.44), "navy")
	for dx in (-1, 1):
		for dyy in (-1, 1):
			mage.box((mx + dx * 0.39, my + dyy * 0.23, 0.24), (0.06, 0.06, 0.46), "violet")
	mage.box((mx, my - 0.25, 0.36), (0.1, 0.03, 0.12), "violet")
	mage.box((mx + 0.1, my, 0.48), (0.5, 0.4, 0.04), "navy", rot_z=8.0)
	mage.build(origin=(mx, my, 0))

	knight = Part("ChestKnight")
	kx, ky = 0.5, 0.95
	knight.box((kx, ky, 0.26), (0.9, 0.52, 0.48), "tex_wood")
	for dx in (-0.32, 0.0, 0.32):
		knight.box((kx + dx, ky, 0.26), (0.06, 0.55, 0.51), "steel")
	knight.box((kx - 0.1, ky - 0.05, 0.515), (0.45, 0.6, 0.02), "mustard")
	ragged_cloth(knight, kx - 0.1, ky - 0.285, 0.51, 0.45, 0.32, "mustard", 50, teeth=3)
	bell_emblem(knight, kx - 0.1, ky - 0.3, 0.3, 0.14, "brass")
	knight.build(origin=(kx, ky, 0))

	table = Part("Table")
	tx, ty = 0.0, 0.15
	table.box((tx, ty, 0.75), (1.2, 0.7, 0.06), "tex_wood")
	for dx in (-0.5, 0.5):
		for dyy in (-0.27, 0.27):
			table.box((tx + dx, ty + dyy, 0.36), (0.07, 0.07, 0.72), "tex_wood")
	table.box((tx, ty, 0.25), (1.0, 0.05, 0.05), "tex_wood")
	for k, (px, py, rz) in enumerate(((-0.35, 0.05, 12), (-0.15, -0.12, -20), (0.2, 0.15, 30))):
		table.box((tx + px, ty + py, 0.785), (0.14, 0.18, 0.005), "paper", rot_z=rz)
	table.lathe([(0.06, 0.0), (0.06, 0.01)], 6, "brass", base=(tx + 0.42, ty + 0.12, 0.78))
	table.lathe([(0.025, 0.0), (0.022, 0.12)], 5, "candle", base=(tx + 0.42, ty + 0.12, 0.79), cap_bottom=False)
	tongue(table, tx + 0.42, ty + 0.12, 0.92, 0.02, 0.08, "flame")
	table.build(origin=(tx, ty, 0))
	for name, h in (("CardsSmall", 0.015), ("CardsMedium", 0.045), ("CardsLarge", 0.1)):
		cards = Part(name)
		cards.box((tx + 0.12, ty - 0.05, 0.78 + h / 2), (0.09, 0.13, h), "paper", rot_z=-8.0)
		cards.build(origin=(tx + 0.12, ty - 0.05, 0.78))


# --- Круг ордена (Маг) ----------------------------------------------------------------
# Место в игре: (-8.5, 0, 1.2). Пять камней по кругу радиусом 2 м (как в hub.gd: угол TAU·i/5),
# кафедра в центре, над ней Crystal (origin в центре — игра вращает его).

MAGE_STONE_HEIGHTS: list = [1.7, 1.5, 1.8, 1.55, 1.65]


def build_mage_circle() -> None:
	clear_scene()
	for i in range(5):
		a = 2 * math.pi * i / 5
		x, y, _ = g(2.0 * math.cos(a), 2.0 * math.sin(a))
		h = MAGE_STONE_HEIGHTS[i]
		stone = Part(f"Stone{i}")
		stone.lathe([(0.34, 0.0), (0.3, h * 0.7), (0.19, h)], 5, "tex_stone", base=(x, y, 0.0),
			cap_bottom=False, phase=jitter(i, 0.5))
		# Руны — на стороне к камере (на юг), три светящихся штриха
		ry = y - 0.31
		for k, (dz, rot) in enumerate(((0.95, 20.0), (0.78, -25.0), (0.62, 10.0))):
			stone.box((x + jitter(i * 7 + k, 0.05), ry, h * dz * 0.7), (0.035, 0.03, 0.2), "rune", rot_y=rot)
		stone.build(origin=(x, y, 0))

	lect = Part("Lectern")
	lect.box((0, 0, 0.04), (0.62, 0.12, 0.08), "tex_wood")
	lect.box((0, 0, 0.04), (0.12, 0.62, 0.08), "tex_wood")
	lect.box((0, 0, 0.5), (0.14, 0.14, 0.95), "tex_wood")
	lect.box((0, 0, 1.03), (0.62, 0.46, 0.06), "tex_wood", rot_x=20.0)
	lect.box((-0.1, 0.02, 1.1), (0.3, 0.38, 0.07), "navy", rot_x=20.0, rot_z=4.0)
	lect.box((-0.08, 0.0, 1.16), (0.26, 0.32, 0.05), "navy", rot_x=20.0, rot_z=-6.0)
	lect.box((0.17, -0.02, 1.08), (0.18, 0.26, 0.01), "paper", rot_x=20.0, rot_z=10.0)
	lect.box((-0.08, 0.0, 1.21), (0.08, 0.07, 0.05), "tex_stone", rot_z=25.0)
	lect.build()

	crystal = Part("Crystal")
	cz = 1.62
	ring = [(0.09 * math.cos(2 * math.pi * k / 6), 0.09 * math.sin(2 * math.pi * k / 6), cz) for k in range(6)]
	verts = ring + [(0, 0, cz + 0.24), (0, 0, cz - 0.2)]
	faces = [(k, (k + 1) % 6, 6) for k in range(6)] + [((k + 1) % 6, k, 7) for k in range(6)]
	crystal.add(verts, faces, "crystal")
	for sx in (-1, 1):
		px, pz = 0.22 * sx, cz + 0.08 * sx
		crystal.add([(px, 0.03, pz), (px + 0.04, -0.03, pz), (px - 0.04, -0.03, pz), (px, 0, pz + 0.06)],
			[(0, 1, 3), (1, 2, 3), (2, 0, 3), (0, 2, 1)], "tex_stone")
	crystal.build(origin=(0, 0, cz))

	chalk = Part("ChalkCircle")
	seg = 20
	verts = []
	for k in range(seg):
		a = 2 * math.pi * k / seg
		verts += [(1.38 * math.cos(a), 1.38 * math.sin(a), 0.012), (1.3 * math.cos(a), 1.3 * math.sin(a), 0.012)]
	faces = [(2 * k, 2 * ((k + 1) % seg), 2 * ((k + 1) % seg) + 1, 2 * k + 1) for k in range(seg)]
	chalk.add(verts, faces, "chalk")
	for k, ang in enumerate((200, 300, 40)):
		a = math.radians(ang)
		small_candle(chalk, 1.05 * math.cos(a), 1.05 * math.sin(a), 0.1 + 0.04 * k)
	chalk.build()


# --- Оружейная (Рыцарь) ---------------------------------------------------------------
# Место в игре: (8.5, 0, 0). Детали стоят там же, где заглушки в hub.gd (координаты игры через g()).

def build_armory() -> None:
	clear_scene()
	ax, ay, _ = g(0.0, -1.2)
	armor = Part("ArmorStand")
	armor.box((ax, ay, 0.04), (0.7, 0.1, 0.08), "tex_wood")
	armor.box((ax, ay, 0.04), (0.1, 0.7, 0.08), "tex_wood")
	armor.box((ax, ay, 0.72), (0.1, 0.1, 1.45), "tex_wood")
	armor.box((ax, ay, 1.3), (0.95, 0.08, 0.08), "tex_wood")
	armor.lathe([(0.2, 0.0), (0.25, 0.3), (0.22, 0.55)], 6, "steel", base=(ax, ay, 0.75), phase=0.5)
	armor.box((ax, ay, 0.72), (0.42, 0.3, 0.16), "steel")
	for sx in (-1, 1):
		armor.box((ax + 0.3 * sx, ay, 1.26), (0.18, 0.26, 0.12), "steel", rot_y=-18.0 * sx)
	ragged_cloth(armor, ax, ay - 0.27, 1.27, 0.34, 0.68, "mustard", 60, teeth=3)
	bell_emblem(armor, ax, ay - 0.29, 0.9, 0.14, "steel")
	armor.lathe([(0.12, 0.0), (0.14, 0.12), (0.12, 0.24), (0.0, 0.29)], 6, "steel", base=(ax, ay, 1.33),
		phase=0.5)
	armor.box((ax, ay - 0.135, 1.47), (0.16, 0.02, 0.025), "iron")
	armor.build(origin=(ax, ay, 0))

	rx, ry, _ = g(1.8, 0.8)
	rack = Part("WeaponRack")
	for end in (-0.75, 0.75):
		for lean in (-1, 1):
			rack.box((rx + 0.1 * lean, ry + end, 0.6), (0.07, 0.07, 1.25), "tex_wood", rot_y=-8.0 * lean)
	for z in (0.35, 1.05):
		rack.box((rx, ry, z), (0.08, 1.6, 0.07), "tex_wood")
	# меч
	sy = ry - 0.45
	rack.box((rx - 0.08, sy, 0.62), (0.012, 0.07, 0.86), "steel")
	rack.box((rx - 0.08, sy, 1.07), (0.04, 0.26, 0.04), "iron")
	rack.box((rx - 0.08, sy, 1.17), (0.035, 0.035, 0.16), "tex_wood")
	# копьё
	rack.log((rx - 0.08, ry, 0.0), (rx - 0.08, ry, 1.7), 0.022, 4, "tex_wood")
	rack.log((rx - 0.08, ry, 1.7), (rx - 0.08, ry, 1.75), 0.04, 4, "steel", spike=0.2)
	# топор
	axy = ry + 0.4
	rack.log((rx - 0.08, axy, 0.0), (rx - 0.08, axy, 1.05), 0.022, 4, "tex_wood")
	rack.box((rx - 0.08, axy + 0.1, 0.95), (0.025, 0.2, 0.18), "steel")
	# щит прислонён к стойке, смотрит к центру заставы (на запад)
	shield_c = Vector((rx - 0.32, ry - 0.2, 0.36))
	axis = Vector((-1.0, 0.0, 0.3)).normalized()
	rack.lathe_axis([(0.0, 0.0), (0.33, 0.0), (0.33, 0.05), (0.0, 0.05)], 10, "tex_wood", shield_c, axis)
	rack.lathe_axis([(0.345, -0.005), (0.345, 0.06)], 10, "steel", shield_c, axis, cap_top=False, cap_bottom=False)
	rack.lathe_axis([(0.08, 0.05), (0.06, 0.09), (0.0, 0.1)], 6, "steel", shield_c, axis, cap_bottom=False)
	rack.build(origin=(rx, ry, 0))

	dx_, dy_, _ = g(-0.2, 1.6)
	dummy = Part("Dummy")
	dummy.log((dx_, dy_, 0.0), (dx_, dy_, 1.3), 0.045, 5, "tex_wood")
	dummy.lathe([(0.18, 0.6), (0.24, 0.92), (0.2, 1.24)], 6, "straw", base=(dx_, dy_, 0.0))
	dummy.lathe([(0.0, 1.26), (0.13, 1.33), (0.12, 1.48), (0.0, 1.56)], 6, "straw", base=(dx_, dy_, 0.0))
	dummy.box((dx_, dy_, 1.12), (0.92, 0.1, 0.1), "straw")
	dummy.lathe([(0.15, 1.44), (0.15, 1.5), (0.1, 1.6), (0.0, 1.63)], 6, "steel", base=(dx_, dy_, 0.0))
	for k in range(3):
		dummy.box((dx_ + jitter(k + 70, 0.08), dy_ - 0.235, 0.85 + 0.12 * k), (0.12, 0.01, 0.015), "charcoal",
			rot_y=25.0 * (1 if k % 2 else -1))
	dummy.build(origin=(dx_, dy_, 0))

	bx, by, _ = g(2.2, -1.8)
	banner = Part("Banner")
	banner.log((bx, by, 0.0), (bx, by, 2.75), 0.04, 5, "tex_wood")
	banner.log((bx, by, 2.75), (bx, by, 2.8), 0.05, 4, "steel", spike=0.2)
	banner.box((bx, by - 0.05, 2.58), (0.9, 0.04, 0.04), "tex_wood")
	ragged_cloth(banner, bx, by - 0.07, 2.56, 0.8, 1.3, "mustard", 80)
	bell_emblem(banner, bx, by - 0.09, 1.9, 0.32, "steel")
	banner.build(origin=(bx, by, 0))

	gx, gy, _ = g(-1.3, 0.0)
	grind = Part("Grindstone")
	for lx in (-0.25, 0.25):
		for ly in (-0.18, 0.18):
			grind.box((gx + lx, gy + ly, 0.27), (0.06, 0.06, 0.54), "tex_wood")
	for ly in (-0.18, 0.18):
		grind.box((gx, gy + ly, 0.55), (0.62, 0.07, 0.07), "tex_wood")
	grind.box((gx + 0.38, gy - 0.18, 0.55), (0.18, 0.03, 0.03), "iron")             # рукоятка
	grind.build(origin=(gx, gy, 0))
	wheel = Part("GrindWheel")
	wheel.lathe_axis([(0.0, -0.05), (0.3, -0.05), (0.3, 0.05), (0.0, 0.05)], 10, "tex_stone",
		(gx, gy, 0.62), (0, 1, 0))
	wheel.lathe_axis([(0.025, -0.24), (0.025, 0.24)], 5, "iron", (gx, gy, 0.62), (0, 1, 0))
	wheel.build(origin=(gx, gy, 0.62))

	extras = Part("Candles")
	small_candle(extras, ax + 0.45, ay + 0.3)
	small_candle(extras, rx - 0.45, ry + 0.75, 0.18)
	extras.build()


# --- Доска дозора ---------------------------------------------------------------------
# Место в игре: (-8.5, 0, 5.2). Доска 2,2 × 1,4 м на двух столбах, под крышей, фонарь над картой.

def build_notice_board() -> None:
	clear_scene()
	board = Part("Board")
	for sx in (-1, 1):
		board.box((1.15 * sx, 0, 1.15), (0.18, 0.18, 2.3), "tex_wood")
		board.box((1.15 * sx, 0, 0.55), (0.2, 0.2, 0.06), "iron")
	board.box((0, 0, 1.15), (2.2, 0.1, 1.4), "tex_planks")
	board.box((0, 0, 2.46), (2.8, 0.08, 0.08), "tex_wood")
	for s in (-1, 1):
		board.box((0, s * 0.27, 2.36), (2.7, 0.6, 0.06), "tex_planks", rot_x=-25.0 * s)
	# Записки и карта Марки
	board.box((0.15, -0.056, 1.2), (0.62, 0.01, 0.46), "map", rot_y=2.0)
	notes = [(-0.85, 1.6, 4), (-0.62, 1.42, -6), (-0.9, 1.05, 8), (-0.6, 0.82, -3), (-0.78, 0.6, 5),
		(0.75, 1.62, -7), (0.95, 1.3, 4), (0.7, 0.95, -2), (0.92, 0.7, 9), (0.3, 0.75, -5)]
	for k, (nx, nz, rot) in enumerate(notes):
		board.box((nx, -0.056, nz), (0.17, 0.01, 0.22 + 0.04 * (k % 2)), "paper", rot_y=rot)
	# Фонарь на кронштейне над картой — горит всегда
	board.box((0.15, -0.22, 2.0), (0.04, 0.4, 0.04), "iron")
	board.box((0.15, -0.4, 1.92), (0.015, 0.015, 0.14), "iron")
	lantern(board, 0.15, -0.4, 1.58, "lamp", 0.17)
	# Ведро со свитками
	board.lathe([(0.15, 0.0), (0.17, 0.3)], 7, "tex_wood", base=(-0.9, -0.4, 0.0), cap_top=False)
	board.lathe([(0.175, 0.22), (0.18, 0.26)], 7, "iron", base=(-0.9, -0.4, 0.0), cap_top=False, cap_bottom=False)
	for k in range(3):
		board.log((-0.95 + 0.05 * k, -0.4 + 0.04 * (k - 1), 0.1), (-0.98 + 0.08 * k, -0.42 + 0.05 * (k - 1), 0.55),
			0.035, 5, "paper")
	board.build()


# --- Полка трофеев --------------------------------------------------------------------
# Место в игре: (8.5, 0, 5.0). Полка 2,4 × 0,8 × 1,8 м, 10 мест: 2 яруса по 5 (полы на 0,53 и 1,23 м,
# как у мест в hub.gd), навес 2,8 × 1,3 м. Сами обереги, ткань и меловые контуры ставит игра.

def build_trophy_shelf() -> None:
	clear_scene()
	shelf = Part("Shelf")
	for sx in (-1, 1):
		shelf.box((1.2 * sx, 0, 0.9), (0.08, 0.8, 1.8), "tex_wood")
		shelf.box((1.22 * sx, -0.38, 0.92), (0.1, 0.1, 1.85), "tex_wood")
	shelf.box((0, 0.37, 0.9), (2.4, 0.06, 1.8), "tex_wood")
	for z in (0.08, 0.505, 1.205, 1.8):
		shelf.box((0, 0, z), (2.4, 0.8, 0.05), "tex_wood")
	for x in (-0.7125, -0.2375, 0.2375, 0.7125):
		shelf.box((x, 0.02, 0.855), (0.04, 0.74, 0.65), "tex_wood")
		shelf.box((x, 0.02, 1.5), (0.04, 0.74, 0.55), "tex_wood")
	for sx in (-1, 1):
		shelf.box((1.2 * sx, 0.12, 0.3), (0.1, 0.12, 0.05), "iron")
	shelf.build()
	awning = Part("Awning")
	for sx in (-1, 1):
		awning.box((1.36 * sx, 0.42, 1.12), (0.1, 0.1, 2.24), "tex_wood")
		awning.box((1.36 * sx, -0.6, 1.0), (0.1, 0.1, 2.0), "tex_wood")
		awning.box((1.36 * sx, -0.09, 2.08), (0.08, 1.15, 0.08), "tex_wood", rot_x=12.0)
	awning.box((0, -0.1, 2.15), (2.85, 1.3, 0.06), "tex_planks", rot_x=12.0)
	awning.build()


# --- Святилище духов ------------------------------------------------------------------
# Место в игре: SHRINE_POS (8, 0, -5.4). Пятак Ø 3,8 м, алтарь, 4 камня полукругом с севера
# (угол PI + PI·(i + 0,5)/4, радиус 1,5 — как в hub.gd). Порядок — Run.ALL_SPIRIT_IDS:
# 0 Омутник (волна), 1 Грозовик (молния), 2 Вихорь (спираль), 3 Хозяин трясины (камыш).
# Orb0…3 — шары, origin в центре: игра прячет их и красит цветом духа.

def _sign(part: Part, kind: str, x: float, y: float, z: float) -> None:
	"""Вырезанный знак духа (тёмные штрихи) на южной стороне камня."""
	if kind == "tide":
		for k in range(3):
			part.box((x - 0.08 + 0.08 * k, y, z), (0.09, 0.02, 0.025), "dark_stone", rot_y=25.0 * (1 if k % 2 else -1))
	elif kind == "storm":
		for k, (dx, dz, rot) in enumerate(((0.03, 0.1, 35), (-0.01, 0.0, -35), (0.03, -0.1, 35))):
			part.box((x + dx, y, z + dz), (0.025, 0.02, 0.13), "dark_stone", rot_y=rot)
	elif kind == "wind":
		for k, (dx, dz, w, h) in enumerate(((0, 0.07, 0.14, 0.025), (0.07, 0, 0.025, 0.14), (0, -0.07, 0.14, 0.025),
				(-0.06, -0.02, 0.025, 0.1), (-0.02, 0.02, 0.07, 0.025))):
			part.box((x + dx, y, z + dz), (w, 0.02, h), "dark_stone")
	else:
		part.box((x, y, z), (0.025, 0.02, 0.26), "dark_stone")
		part.box((x - 0.05, y, z - 0.02), (0.02, 0.02, 0.14), "dark_stone", rot_y=-30.0)
		part.box((x + 0.05, y, z + 0.02), (0.02, 0.02, 0.14), "dark_stone", rot_y=30.0)


SHRINE_SPIRITS: list = ["tide", "storm", "wind", "bog"]


def build_shrine() -> None:
	clear_scene()
	base = Part("Base")
	curb_ring(base, 1.75, 14, 0.24, seed=100)
	base.lathe([(1.58, 0.0), (1.58, 0.1)], 14, "tex_ground", cap_bottom=False)
	base.build()

	altar = Part("Altar")
	ax, ay, _ = g(0.0, -0.4)
	for sx in (-1, 1):
		altar.box((ax + 0.3 * sx, ay, 0.24), (0.18, 0.45, 0.46), "tex_stone")
	altar.box((ax, ay, 0.53), (0.95, 0.6, 0.12), "tex_stone")
	altar.lathe([(0.12, 0.0), (0.22, 0.12)], 8, "tex_stone", base=(ax, ay, 0.59), cap_top=False)
	altar.lathe([(0.22, 0.12), (0.0, 0.06)], 8, "dark_stone", base=(ax, ay, 0.59), cap_bottom=False)
	for k in range(3):
		altar.log((ax - 0.42, ay - 0.15 + 0.03 * k, 0.61), (ax - 0.2, ay - 0.12 + 0.03 * k, 0.62), 0.015, 4, "straw")
	altar.lathe([(0.0, 0.0), (0.05, 0.01), (0.0, 0.04)], 5, "paper", base=(ax + 0.32, ay - 0.15, 0.59))
	altar.box((ax + 0.3, ay + 0.12, 0.6), (0.2, 0.04, 0.01), "paper", rot_z=30.0)
	altar.build(origin=(ax, ay, 0))

	n = len(SHRINE_SPIRITS)
	for i in range(n):
		a = math.pi + math.pi * (i + 0.5) / n
		x, y, _ = g(1.5 * math.cos(a), 1.5 * math.sin(a))
		h = 1.3 + 0.25 * (i % 2)
		stone = Part(f"Stone{i}")
		stone.lathe([(0.25, 0.0), (0.23, h - 0.12), (0.2, h), (0.2, h + 0.06), (0.15, h + 0.06), (0.1, h + 0.02)],
			6, "tex_stone", base=(x, y, 0.0), cap_bottom=False, phase=0.5)
		_sign(stone, SHRINE_SPIRITS[i], x, y - 0.24, h * 0.55)
		stone.build(origin=(x, y, 0))
		orb = Part(f"Orb{i}")
		center = (x, y, h + 0.05 + 0.17)
		orb.sphere(center, 0.17, 8, 5, "orb")
		orb.build(origin=center)


# --- Фонарь Стражи на шесте (×21 вдоль частокола) ------------------------------------
# Glass — отдельный объект: игра зажигает стекло, когда куплена очередная ступень улучшений.
# Кронштейн смотрит в −X: игра поворачивает фонарь к центру заставы.

def build_lantern_post() -> None:
	clear_scene()
	post = Part("Post")
	post.lathe([(0.35, 0.0), (0.2, 0.07), (0.0, 0.1)], 7, "tex_ground", cap_bottom=False)
	post.box((0, 0, 0.92), (0.12, 0.12, 1.85), "tex_wood")
	post.box((-0.2, 0, 1.75), (0.55, 0.1, 0.1), "tex_wood")
	post.box((-0.13, 0, 1.55), (0.06, 0.06, 0.4), "tex_wood", rot_y=45.0)
	post.box((0, 0, 1.75), (0.14, 0.14, 0.05), "iron")
	post.box((-0.4, 0, 1.63), (0.015, 0.015, 0.14), "iron")
	glass = Part("Glass")
	lantern(post, -0.4, 0, 1.25, "glass", 0.22, glass_part=glass)
	post.build()
	glass.build(origin=(-0.4, 0, 1.25))


# --- Частокол ------------------------------------------------------------------------
# Секция 2 м вдоль X, смотрит в −Y (внутрь заставы). Четыре вида — четыре файла:
# palisade_intact, palisade_damaged, palisade_fallen, palisade_corner. Игра расставляет их по краю.

def _stake(part: Part, x: float, h: float, k: int, broken: bool = False) -> None:
	if broken:
		part.log((x, 0, 0.0), (x, 0, h), 0.11, 5, "tex_wood", cap_bottom=False)
		part.add([(x - 0.1, -0.05, h), (x + 0.1, -0.03, h), (x, 0.06, h + 0.2)], [(0, 1, 2)], "tex_wood")
	else:
		part.log((x, 0, 0.0), (x, 0, h - 0.3), 0.11, 5, "tex_wood", spike=0.3, cap_bottom=False)


def _palisade(kind: str) -> None:
	clear_scene()
	sec = Part("Section")
	xs = [-0.89 + 0.2225 * k for k in range(9)]
	if kind == "intact":
		for k, x in enumerate(xs):
			_stake(sec, x, 2.1 + jitter(k, 0.15), k)
		for z in (0.55, 1.5):
			sec.box((0, -0.14, z), (2.05, 0.1, 0.14), "tex_wood")
	elif kind == "damaged":
		for k, x in enumerate(xs):
			if k in (3, 4):
				continue
			_stake(sec, x, 0.9 if k == 5 else 2.1 + jitter(k + 9, 0.15), k, broken=(k == 5))
		sec.box((-0.55, -0.14, 1.5), (0.95, 0.1, 0.14), "tex_wood")
		sec.box((0.6, -0.14, 1.45), (0.8, 0.1, 0.14), "tex_wood", rot_y=8.0)
		sec.box((0, -0.14, 0.55), (2.05, 0.1, 0.14), "tex_wood")
		sec.log((0.05, -0.3, 0.06), (0.4, -1.1, 0.08), 0.1, 5, "tex_wood", spike=0.25)   # упавший кол
	elif kind == "fallen":
		# Колья упали наружу, в воду: лежат от края заставы
		for k in range(7):
			x = -0.8 + 0.27 * k
			sec.log((x, 0.05, 0.12), (x + jitter(k + 30, 0.15), 1.7 + jitter(k + 40, 0.2), 0.0), 0.11, 5,
				"tex_wood", spike=0.3)
		sec.box((0, 0.9, 0.2), (1.8, 0.12, 0.12), "tex_wood", rot_z=6.0)
		for k in (0, 8):
			_stake(sec, xs[k], 0.5 + 0.2 * (k % 3), k, broken=True)
	else:   # corner — угловой столб с гербом
		sec.box((0, 0, 1.2), (0.36, 0.36, 2.4), "tex_wood")
		for dx in (-0.12, 0.12):
			sec.box((dx, 0, 2.47), (0.1, 0.36, 0.15), "tex_wood")
		for z in (0.6, 2.2):
			sec.box((0, 0, z), (0.4, 0.4, 0.06), "iron")
		bell_emblem(sec, 0, -0.185, 1.3, 0.22, "iron")
	sec.build()


def build_palisade_intact() -> None:
	_palisade("intact")


def build_palisade_damaged() -> None:
	_palisade("damaged")


def build_palisade_fallen() -> None:
	_palisade("fallen")


def build_palisade_corner() -> None:
	_palisade("corner")


BUILDERS: dict = {
	"bell": build_bell,
	"campfire": build_campfire,
	"gate": build_gate,
	"barracks": build_barracks,
	"mage_circle": build_mage_circle,
	"armory": build_armory,
	"notice_board": build_notice_board,
	"trophy_shelf": build_trophy_shelf,
	"shrine": build_shrine,
	"lantern_post": build_lantern_post,
	"palisade_intact": build_palisade_intact,
	"palisade_damaged": build_palisade_damaged,
	"palisade_fallen": build_palisade_fallen,
	"palisade_corner": build_palisade_corner,
}


def main() -> None:
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	project = Path(argv[0]) if argv else Path(bpy.path.abspath("//")).parents[2]
	names = argv[1:] or list(BUILDERS)
	for name in names:
		BUILDERS[name]()
		export(project, name)


if __name__ == "__main__":
	main()
