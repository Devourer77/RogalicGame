class_name Board
extends Node3D
# Игровое поле: плиты, объекты топей, декор вокруг арены, подсветка клеток,
# огонь/вода/лёд. Правил не знает — только рисует то, что ему скажут.

# Поле из сот: размеры клетки задаёт HexMath (расстояние между центрами соседей, радиус гекса).
const CELL_STEP: float = HexMath.CELL_STEP                 # расстояние между центрами соседних клеток, м
const ROW_STEP: float = HexMath.HEX_SIZE * 1.5             # расстояние между рядами, м
const TILE_GAP: float = 0.97       # доля клетки, которую занимает плита (остальное — щель)
const TILE_THICKNESS: float = 0.2  # толщина плиты

# Цвета плит-заглушек (те же, что в assets/models/src/build_topi.py).
# Пока нет шестиугольных моделей из Blender, плиты рисуются простыми шестигранными призмами.
const TILE_COLORS: Dictionary[int, Color] = {
	BattleLogic.Ground.STONE: Color(0.30, 0.33, 0.33),
	BattleLogic.Ground.MOSS: Color(0.25, 0.33, 0.18),
	BattleLogic.Ground.MUD: Color(0.24, 0.20, 0.15),
	BattleLogic.Ground.PLANKS: Color(0.34, 0.26, 0.17),
}
const TILE_STONE_ALT: Color = Color(0.26, 0.29, 0.29)   # второй оттенок камня для разнообразия

# Все модели топей собраны скриптом assets/models/src/build_topi.py
const DIR: String = "res://assets/models/topi/"

# (квадратные плиты tile_*.glb остались в проекте, но в бою не используются: нужны новые, шестиугольные)

# Объекты на клетках (ключ — BattleLogic.Obj)
const OBJ_BOG: PackedScene = preload(DIR + "obj_bog.glb")
const OBJ_TREES: Array[PackedScene] = [preload(DIR + "obj_tree_a.glb"), preload(DIR + "obj_tree_b.glb")]
const OBJ_BARREL: PackedScene = preload(DIR + "obj_barrel.glb")
const OBJ_PLANKS: PackedScene = preload(DIR + "obj_planks.glb")
const OBJ_REEDS: PackedScene = preload(DIR + "obj_reeds.glb")
const OBJ_ICE: PackedScene = preload(DIR + "obj_ice.glb")
const OBJ_STAKES: PackedScene = preload(DIR + "obj_stakes.glb")
const OBJ_BRIDGE: PackedScene = preload(DIR + "obj_bridge.glb")

# Неразрушимые преграды: у каждой арены свои
const ROCK_BOULDER: PackedScene = preload(DIR + "rock_boulder.glb")
const ROCK_PILLAR: PackedScene = preload(DIR + "rock_pillar.glb")
const ROCK_CRATES: PackedScene = preload(DIR + "rock_crates.glb")
const ROCK_MARKER: PackedScene = preload(DIR + "rock_marker.glb")
const ROCK_BONES: PackedScene = preload(DIR + "rock_bones.glb")
const ARENA_ROCKS: Dictionary[String, Array] = {
	"gat": [ROCK_BOULDER, ROCK_MARKER],
	"grove": [ROCK_BOULDER],
	"reeds": [ROCK_BOULDER],
	"camp": [ROCK_CRATES],
	"ruins": [ROCK_PILLAR, ROCK_PILLAR, ROCK_MARKER],
	"lair": [ROCK_BONES, ROCK_BOULDER],
}

# Декор вокруг арены
const D_TREE_BIG: PackedScene = preload(DIR + "decor_tree_big.glb")
const D_STUMP: PackedScene = preload(DIR + "decor_stump.glb")
const D_TUSSOCK: PackedScene = preload(DIR + "decor_tussock.glb")
const D_MUSHROOMS: PackedScene = preload(DIR + "decor_mushrooms.glb")
const D_LANTERN: PackedScene = preload(DIR + "decor_lantern.glb")
const D_BELL: PackedScene = preload(DIR + "decor_bell.glb")
const D_FENCE: PackedScene = preload(DIR + "decor_fence.glb")
const D_ARCH: PackedScene = preload(DIR + "decor_arch.glb")
const D_WALL: PackedScene = preload(DIR + "decor_wall.glb")
const D_BOAT: PackedScene = preload(DIR + "decor_boat.glb")
const D_TENT: PackedScene = preload(DIR + "decor_tent.glb")
const D_RIBS: PackedScene = preload(DIR + "decor_ribs.glb")
const D_TOTEM: PackedScene = preload(DIR + "decor_totem.glb")
const D_ROCK_BIG: PackedScene = preload(DIR + "decor_rock_big.glb")
const D_SPIRE: PackedScene = preload(DIR + "decor_spire.glb")

# Чем засыпать окрестности каждой арены: [модель, сколько штук]. Высокое ставится дальше от поля.
const ARENA_SCATTER: Dictionary[String, Array] = {
	"gat": [[D_TUSSOCK, 10], [OBJ_REEDS, 8], [D_STUMP, 3], [D_MUSHROOMS, 4], [D_TREE_BIG, 4], [D_ROCK_BIG, 2]],
	"grove": [[D_TREE_BIG, 9], [OBJ_TREES[0], 8], [OBJ_TREES[1], 6], [D_STUMP, 6], [D_MUSHROOMS, 5], [D_TUSSOCK, 5]],
	"reeds": [[OBJ_REEDS, 26], [D_TUSSOCK, 10], [D_MUSHROOMS, 3], [D_TREE_BIG, 3], [D_STUMP, 2]],
	"camp": [[D_TUSSOCK, 6], [D_STUMP, 4], [D_TREE_BIG, 4], [ROCK_CRATES, 3], [D_MUSHROOMS, 2], [OBJ_REEDS, 4]],
	"ruins": [[ROCK_PILLAR, 6], [D_ROCK_BIG, 4], [D_TUSSOCK, 6], [D_MUSHROOMS, 4], [D_TREE_BIG, 3], [OBJ_REEDS, 4]],
	"lair": [[ROCK_BONES, 6], [D_ROCK_BIG, 5], [D_TREE_BIG, 4], [D_MUSHROOMS, 6], [D_STUMP, 3], [D_TUSSOCK, 4]],
}

# На какой высоте рисовать каждый слой подсветки (чтобы они не «мерцали», налезая друг на друга)
const LAYER_HEIGHT: Dictionary = {
	"move": 0.13,     # куда можно пойти
	"target": 0.14,   # куда можно применить карту
	"buff": 0.145,    # кого враг усилит «зовом»
	"intent": 0.15,   # куда могут ударить враги
	"hover_threat": 0.155,  # зона врага под курсором
	"area": 0.16,     # что заденет карта под курсором
	"flash": 0.17,    # вспышка удара
	"routes": 0.2,    # линии маршрутов врагов
}

const IMPACT_FX_SCALE: float = 1.5   # во сколько раз крупнее частицы взрыва бочки и падения дерева (подкрути, если мало или много)
const COLOR_ROUTE := Color(1.0, 0.92, 0.55, 0.95)   # тёплый жёлтый: виден и на камне, и на воде
const COLOR_SWAMP_WATER := Color(0.05, 0.075, 0.065) # стоячая вода вокруг арены
const COLOR_BANK := Color(0.2, 0.18, 0.14)           # топкий берег, на котором лежат плиты
const COLOR_GAS_LIGHT := Color(0.55, 0.95, 0.35)     # болотный газ
const COLOR_LAMP_LIGHT := Color(1.0, 0.72, 0.35)     # фонарь Стражи
const COLOR_WISP := Color(0.6, 1.0, 0.75)            # болотные огоньки

@export var width: int = 12   # клеток по горизонтали
@export var height: int = 12  # клеток в глубину

var _layers: Dictionary[String, Node3D] = {}
var _effects: Dictionary[Vector2i, Node3D] = {}
var _flat_materials: Dictionary[Color, StandardMaterial3D] = {}
var _solid_materials: Dictionary[Color, StandardMaterial3D] = {}
var _highlight_mesh: CylinderMesh
var _tile_mesh: CylinderMesh
var _object_nodes: Dictionary[Vector2i, Node3D] = {}
var _object_kinds: Dictionary[Vector2i, int] = {}
var _arena: String = ""


# Строит арену: берег и воду, плиты по виду покрытия, декор вокруг.
# arena — ключ арены из BattleLogic.ARENAS, ground — клетка -> BattleLogic.Ground.
func build(layout_seed: int, arena: String = "", ground: Dictionary[Vector2i, int] = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	_arena = arena
	_build_shore()

	for cell: Vector2i in HexMath.rect_cells(width, height):
		var kind: int = ground.get(cell, BattleLogic.Ground.STONE)
		var color: Color = TILE_COLORS.get(kind, TILE_COLORS[BattleLogic.Ground.STONE])
		if kind == BattleLogic.Ground.STONE and rng.randf() > 0.6:
			color = TILE_STONE_ALT
		var tile := MeshInstance3D.new()
		tile.mesh = _get_tile_mesh()
		tile.material_override = _get_solid_material(color)
		# плиты чуть неровные по высоте
		tile.position = grid_to_world(cell) + Vector3(0.0, -TILE_THICKNESS / 2.0 - rng.randf() * 0.02, 0.0)
		add_child(tile)

	_build_decorations(rng)
	_build_wisps()


# Вода топей до горизонта и тёмный берег-островок под плитами
func _build_shore() -> void:
	var center: Vector3 = field_center()
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 220.0)
	water.mesh = plane
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = COLOR_SWAMP_WATER
	water_mat.roughness = 0.25
	water_mat.metallic = 0.3
	water.material_override = water_mat
	water.position = center + Vector3(0.0, -0.16, 0.0)
	add_child(water)

	var bank := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3((width + 0.5) * CELL_STEP, 0.3, (height - 1) * ROW_STEP + HexMath.HEX_SIZE * 2.0 + 0.4)
	bank.mesh = box
	var bank_mat := StandardMaterial3D.new()
	bank_mat.albedo_color = COLOR_BANK
	bank_mat.roughness = 1.0
	bank.material_override = bank_mat
	bank.position = center + Vector3(0.0, -0.21, 0.0)
	add_child(bank)


# Декор за пределами сетки (на клики и правила не влияет).
# Общее для всех арен: Шпиль на горизонте, фонари Стражи, россыпь по списку арены.
func _build_decorations(rng: RandomNumberGenerator) -> void:
	var decor := Node3D.new()
	decor.name = "Decorations"
	add_child(decor)
	var w: float = width * CELL_STEP     # ширина поля в метрах
	var h: float = height * ROW_STEP     # глубина поля в метрах

	# Шпиль далеко на севере: цель всего пути. Трещина в небе над ним светится.
	var spire: Node3D = _spawn_prop(decor, D_SPIRE, Vector3(w * 0.5 + rng.randf_range(-6.0, 6.0), -1.0, -62.0), 0.0)
	spire.scale = Vector3(2.2, 2.2, 2.2)

	# Фонари Стражи у дальних углов и один сбоку — тёплые островки света
	for pos: Vector3 in [Vector3(-1.4, 0.0, -1.2), Vector3(w + 0.4, 0.0, -1.2), Vector3(-1.5, 0.0, h * 0.62)]:
		var lantern: Node3D = _spawn_prop(decor, D_LANTERN, pos, rng.randf_range(-0.4, 0.4) + (PI if pos.x > 0.0 else 0.0))
		_add_light(lantern, Vector3(0.66 * (-1.0 if pos.x > 0.0 else 1.0), 1.7, 0.0), COLOR_LAMP_LIGHT, 2.2, 6.0)

	# Особые постройки арены
	match _arena:
		"gat":
			_spawn_prop(decor, D_BOAT, Vector3(-2.6, -0.1, h * 0.45), 0.5)
			_spawn_prop(decor, D_FENCE, Vector3(w + 1.2, 0.0, h * 0.3), PI / 2.0)
		"camp":
			for fx: float in [1.0, 3.2, w - 4.2, w - 2.0]:
				_spawn_prop(decor, D_FENCE, Vector3(fx, 0.0, -1.3), rng.randf_range(-0.08, 0.08))
			for fz: float in [1.5, 4.0, 6.5]:
				_spawn_prop(decor, D_FENCE, Vector3(-1.4, 0.0, fz), PI / 2.0 + rng.randf_range(-0.08, 0.08))
				_spawn_prop(decor, D_FENCE, Vector3(w + 0.4, 0.0, fz), PI / 2.0 + rng.randf_range(-0.08, 0.08))
			_spawn_prop(decor, D_BELL, Vector3(w * 0.5 - 0.5, 0.0, -2.4), 0.0)
			_spawn_prop(decor, D_TENT, Vector3(w + 2.6, 0.0, h * 0.55), 0.3)
			_spawn_prop(decor, D_TENT, Vector3(-3.4, 0.0, h * 0.3), -0.5)
		"ruins":
			_spawn_prop(decor, D_ARCH, Vector3(w * 0.5 - 0.5, 0.0, -2.2), 0.0)
			_spawn_prop(decor, D_WALL, Vector3(-2.4, -0.1, 2.5), PI / 2.0)
			_spawn_prop(decor, D_WALL, Vector3(w + 1.6, -0.15, 6.5), -PI / 2.0 + 0.2)
			_spawn_prop(decor, D_ARCH, Vector3(w + 3.0, -0.3, 1.0), 1.0)
		"reeds":
			_spawn_prop(decor, D_BOAT, Vector3(w + 1.8, -0.12, h * 0.5), 1.9)
		"lair":
			_spawn_prop(decor, D_RIBS, Vector3(w * 0.5 - 0.5, -0.05, -2.6), 0.15)
			for pos: Vector3 in [Vector3(-1.6, 0.0, 2.0), Vector3(w + 0.6, 0.0, 3.5), Vector3(w * 0.5 + 3.0, 0.0, -1.6)]:
				_spawn_prop(decor, D_TOTEM, pos, rng.randf_range(-0.5, 0.5))

	# Россыпь по списку арены. Занятые места запоминаем, чтобы декор не слипался.
	var taken: Array[Vector3] = []
	for child in decor.get_children():
		taken.append((child as Node3D).position)
	for entry: Array in ARENA_SCATTER.get(_arena, ARENA_SCATTER["gat"]):
		var scene: PackedScene = entry[0]
		var tall: bool = scene == D_TREE_BIG or scene == D_ROCK_BIG
		for i: int in entry[1]:
			var pos: Vector3 = _scatter_spot(rng, tall, taken)
			if pos.y < -50.0:
				continue
			taken.append(pos)
			var prop: Node3D = _spawn_prop(decor, scene, pos, rng.randf() * TAU)
			var s: float = rng.randf_range(0.85, 1.25)
			prop.scale = Vector3(s, s, s)
			if scene == D_MUSHROOMS:
				_add_light(prop, Vector3(0.0, 0.4, 0.0), Color(0.35, 0.92, 0.82), 0.5, 2.5)


# Случайное место в полосе вокруг поля. Высокий декор — только дальше 3 клеток
# от края и не с ближней к камере стороны, чтобы не загораживал бой.
func _scatter_spot(rng: RandomNumberGenerator, tall: bool, taken: Array[Vector3]) -> Vector3:
	for attempt in 12:
		var near: float = 3.0 if tall else 1.1
		var far: float = 8.0 if tall else 5.0
		var field_w: float = width * CELL_STEP
		var field_d: float = (height - 1) * ROW_STEP + HexMath.HEX_SIZE
		var x: float = rng.randf_range(-far, field_w + far)
		var z: float = rng.randf_range(-far, (field_d - 3.0) if tall else (field_d + 2.5))
		var dx: float = maxf(maxf(-CELL_STEP * 0.5 - x, x - field_w), 0.0)
		var dz: float = maxf(maxf(-HexMath.HEX_SIZE - z, z - field_d), 0.0)
		var dist: float = maxf(dx, dz)
		if dist < near or dist > far:
			continue
		var pos := Vector3(x, -0.08, z)
		var free: bool = true
		for t in taken:
			if t.distance_to(pos) < (1.6 if tall else 0.9):
				free = false
				break
		if free:
			return pos
	return Vector3(0.0, -100.0, 0.0)


func _spawn_prop(parent: Node3D, scene: PackedScene, pos: Vector3, rot_y: float) -> Node3D:
	var inst: Node3D = scene.instantiate()
	inst.position = pos
	inst.rotation.y = rot_y
	parent.add_child(inst)
	return inst


# Точечный источник света без теней (фонарь, газ, грибы)
func _add_light(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = pos
	parent.add_child(light)
	return light


# Болотные огоньки: редкие светящиеся точки, медленно плывущие над ареной
func _build_wisps() -> void:
	var wisps := CPUParticles3D.new()
	wisps.amount = 36
	wisps.lifetime = 7.0
	wisps.preprocess = 7.0
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wisps.emission_box_extents = Vector3(width * CELL_STEP * 0.5 + 4.0, 0.5, height * ROW_STEP * 0.5 + 4.0)
	wisps.direction = Vector3(0.3, 1.0, 0.1)
	wisps.spread = 60.0
	wisps.gravity = Vector3.ZERO
	wisps.initial_velocity_min = 0.05
	wisps.initial_velocity_max = 0.2
	wisps.scale_amount_min = 0.5
	wisps.scale_amount_max = 1.2
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.3, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	wisps.scale_amount_curve = fade
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	dot.material = _glow_material(COLOR_WISP, 3.0)
	wisps.mesh = dot
	wisps.position = field_center() + Vector3(0.0, 0.9, 0.0)
	add_child(wisps)


# Светящийся материал без теней (для частиц и огня)
func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


# Переводит координаты клетки (x, y) в позицию в 3D-мире
func grid_to_world(cell: Vector2i) -> Vector3:
	return HexMath.axial_to_world(cell)


# Обратное действие: из точки в 3D-мире получает клетку, в которую она попадает
func world_to_grid(point: Vector3) -> Vector2i:
	return HexMath.world_to_axial(point)


# Проверяет, что клетка лежит внутри поля
func is_inside(cell: Vector2i) -> bool:
	return HexMath.in_rect(cell, width, height)


# Центр поля в мире (середина между крайними клетками)
func field_center() -> Vector3:
	return Vector3((width - 0.5) * CELL_STEP / 2.0, 0.0, (height - 1) * ROW_STEP / 2.0)


# ---------- Подсветка клеток ----------

# Подсвечивает клетки цветом. Слой (layer) — это группа подсветки:
# новый вызов с тем же слоем заменяет старую подсветку этого слоя.
func show_cells(layer: String, cells: Array[Vector2i], color: Color) -> void:
	clear_layer(layer)
	var holder := Node3D.new()
	add_child(holder)
	_layers[layer] = holder
	var y: float = LAYER_HEIGHT.get(layer, 0.13)
	for c in cells:
		if not is_inside(c):
			continue
		var m := MeshInstance3D.new()
		m.mesh = _get_highlight_mesh()
		m.material_override = _get_flat_material(color)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = grid_to_world(c) + Vector3(0.0, y, 0.0)
		holder.add_child(m)


# Значки над клетками (взрыв бочки, падающее дерево в прогнозе хода врагов).
# marks — список {"cell": Vector2i, "icon": имя иконки, "color": Color}.
func show_markers(layer: String, marks: Array[Dictionary]) -> void:
	clear_layer(layer)
	var holder := Node3D.new()
	add_child(holder)
	_layers[layer] = holder
	for mark: Dictionary in marks:
		var tex: Texture2D = UiKit.icon(mark["icon"])
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.pixel_size = 0.55 / maxf(float(tex.get_width()), 1.0)   # значок примерно в полклетки
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.no_depth_test = true
		sprite.modulate = mark.get("color", Color.WHITE)
		sprite.position = grid_to_world(mark["cell"]) + Vector3(0.0, 0.9, 0.0)
		holder.add_child(sprite)


func clear_layer(layer: String) -> void:
	if _layers.has(layer):
		_layers[layer].queue_free()
		_layers.erase(layer)


# ---------- Огонь, вода, лёд, камни ----------

# Показывает на клетке эффект (значения — BattleLogic.Tile)
func set_tile_effect(cell: Vector2i, tile: int) -> void:
	if _effects.has(cell):
		_effects[cell].queue_free()
		_effects.erase(cell)
	if tile == BattleLogic.Tile.NONE:
		return
	var root := Node3D.new()
	root.position = grid_to_world(cell)
	match tile:
		BattleLogic.Tile.WATER:
			# Лужа: тёмное зеркало с голубым отсветом (стихия слегка светится)
			var puddle := _flat_disc(0.41 * CELL_STEP, Color(0.1, 0.26, 0.38, 0.92), 0.02)
			var mat: StandardMaterial3D = puddle.material_override
			mat.roughness = 0.05
			mat.metallic = 0.4
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.35, 0.55)
			mat.emission_energy_multiplier = 0.25
			puddle.scale = Vector3(1.0, 1.0, 0.8 + 0.2 * float(posmod(cell.x * 5 + cell.y * 3, 3)) / 2.0)
			puddle.rotation.y = float(posmod(cell.x * 37 + cell.y * 91, 360))
			root.add_child(puddle)
		BattleLogic.Tile.ICE:
			var ice := MeshInstance3D.new()
			var slab := CylinderMesh.new()   # шестигранная льдина по форме клетки
			slab.top_radius = HexMath.HEX_SIZE * 0.97
			slab.bottom_radius = HexMath.HEX_SIZE * 0.97
			slab.height = 0.05
			slab.radial_segments = 6
			slab.rings = 1
			ice.mesh = slab
			ice.position.y = 0.025
			var ice_mat := StandardMaterial3D.new()
			ice_mat.albedo_color = Color(0.78, 0.93, 1.0, 0.9)
			ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ice_mat.roughness = 0.08
			ice_mat.emission_enabled = true
			ice_mat.emission = Color(0.6, 0.85, 1.0)
			ice_mat.emission_energy_multiplier = 0.35
			ice.material_override = ice_mat
			ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(ice)
		BattleLogic.Tile.FIRE:
			# Тлеющая земля, языки пламени из частиц и оранжевый свет
			var embers := _flat_disc(0.42 * CELL_STEP, Color(1.0, 0.4, 0.08, 0.75), 0.03)
			var e_mat: StandardMaterial3D = embers.material_override
			e_mat.emission_enabled = true
			e_mat.emission = Color(1.0, 0.35, 0.05)
			e_mat.emission_energy_multiplier = 2.0
			root.add_child(embers)
			root.add_child(_make_flames())
			_add_light(root, Vector3(0.0, 0.6, 0.0), Color(1.0, 0.55, 0.2), 1.6, 3.0)
	add_child(root)
	_effects[cell] = root


# Плоский диск на плите (лужа, угли)
func _flat_disc(radius: float, color: Color, y: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 9
	disc.rings = 1
	m.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = y
	return m


# Языки пламени: частицы летят вверх, уменьшаясь и желтея
func _make_flames() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.7
	p.preprocess = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.3, 0.02, 0.3)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.0, 1.5, 0.0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var flame := PrismMesh.new()
	flame.size = Vector3(0.16, 0.3, 0.16)
	flame.material = _glow_material(Color(1.0, 0.55, 0.12), 3.0)
	p.mesh = flame
	p.position.y = 0.05
	return p


# Разовый выброс частиц: взрыв бочки, щепки дерева, брызги. Сам удаляется.
# size — во сколько раз крупнее кусочки (взрыв бочки и падение дерева делаем крупнее)
func burst(cell: Vector2i, color: Color, amount: int = 24, speed: float = 4.0, glow: float = 3.0, size: float = 1.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 75.0
	p.gravity = Vector3(0.0, -7.0, 0.0)
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = shrink
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.1, 0.1, 0.1) * size
	chunk.material = _glow_material(color, glow)
	p.mesh = chunk
	p.position = grid_to_world(cell) + Vector3(0.0, 0.35, 0.0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# Неразрушимая преграда на клетке. Какая — зависит от арены:
# в руинах колонны, на заставе ящики, в логове кости, в остальных местах валуны.
func add_rock(cell: Vector2i) -> void:
	var options: Array = ARENA_ROCKS.get(_arena, [ROCK_BOULDER])
	var scene: PackedScene = options[posmod(cell.x * 7 + cell.y * 13, options.size())]
	var prop: Node3D = scene.instantiate()
	prop.position = grid_to_world(cell)
	prop.rotation.y = posmod(cell.x * 3 + cell.y * 17, 4) * (PI / 2.0)
	add_child(prop)


# ---------- Вспомогательное ----------

# Шестиугольник подсветки: плоская шестигранная призма чуть меньше клетки.
# У CylinderMesh с 6 сегментами острый угол смотрит вдоль оси Z — как у наших сот.
func _get_highlight_mesh() -> CylinderMesh:
	if _highlight_mesh == null:
		_highlight_mesh = _hex_prism(HexMath.HEX_SIZE * 0.88, 0.01)
	return _highlight_mesh


# Шестигранная плита (общая для всех клеток поля)
func _get_tile_mesh() -> CylinderMesh:
	if _tile_mesh == null:
		_tile_mesh = _hex_prism(HexMath.HEX_SIZE * TILE_GAP, TILE_THICKNESS)
	return _tile_mesh


func _hex_prism(radius: float, thickness: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = thickness
	m.radial_segments = 6
	m.rings = 1
	return m


# Матовый материал одного цвета (с кешем)
func _get_solid_material(color: Color) -> StandardMaterial3D:
	if not _solid_materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.95
		_solid_materials[color] = mat
	return _solid_materials[color]


# Полупрозрачный материал без освещения. Кешируем: один цвет — один материал.
func _get_flat_material(color: Color) -> StandardMaterial3D:
	if not _flat_materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color
		_flat_materials[color] = mat
	return _flat_materials[color]


# ---------- Объекты топей (значения — BattleLogic.Obj) ----------

# Ставит 3D-модель объекта на клетку (без анимации — при старте боя)
func add_object(cell: Vector2i, kind: int) -> void:
	_remove_object_node(cell)
	var node: Node3D = _make_object(kind, cell)
	if node == null:
		return
	node.position = grid_to_world(cell)
	add_child(node)
	_object_nodes[cell] = node
	_object_kinds[cell] = kind
	if kind == BattleLogic.Obj.STAKES:
		_orient_stakes(cell)
		for d: Vector2i in HexMath.DIRS:
			_orient_stakes(cell + d)


# Частокол встаёт вдоль стены: поворачиваем модель вдоль той из трёх осей сот,
# по которой рядом стоят другие колья (ряд слева-направо — в первую очередь)
func _orient_stakes(cell: Vector2i) -> void:
	if _object_kinds.get(cell, BattleLogic.Obj.NONE) != BattleLogic.Obj.STAKES:
		return
	var stakes: int = BattleLogic.Obj.STAKES
	var angle: float = 0.0
	for axis in 3:
		var d: Vector2i = HexMath.DIRS[axis]
		if _object_kinds.get(cell + d, -1) == stakes or _object_kinds.get(cell - d, -1) == stakes:
			var v: Vector3 = HexMath.axial_to_world(d)
			angle = atan2(-v.z, v.x)   # модель лежит вдоль оси X; поворот вокруг Y кладёт её вдоль v
			break
	_object_nodes[cell].rotation.y = angle


# Объект поменялся. Показываем красиво: дерево падает, бочка лопается,
# мостки уходят под воду, камыш сгорает. dir — куда падает дерево.
func change_object(cell: Vector2i, old_kind: int, new_kind: int, dir: Vector2i) -> void:
	var node: Node3D = _object_nodes.get(cell)
	_object_nodes.erase(cell)
	_object_kinds.erase(cell)
	if node != null:
		match old_kind:
			BattleLogic.Obj.TREE:
				await _fall_tree(node, dir)
				burst(cell + dir, Color(0.4, 0.37, 0.33), roundi(14 * IMPACT_FX_SCALE), 2.5 * IMPACT_FX_SCALE, 0.0, IMPACT_FX_SCALE)   # щепки
			BattleLogic.Obj.BARREL:
				await _pop(node)
				burst(cell, COLOR_GAS_LIGHT, roundi(34 * IMPACT_FX_SCALE), 5.0 * IMPACT_FX_SCALE, 3.0, IMPACT_FX_SCALE)   # зелёная вспышка газа
				burst(cell, Color(1.0, 0.6, 0.15), roundi(20 * IMPACT_FX_SCALE), 3.5 * IMPACT_FX_SCALE, 3.0, IMPACT_FX_SCALE)
			BattleLogic.Obj.ICE_BLOCK:
				burst(cell, Color(0.8, 0.95, 1.0), 16, 2.5, 1.0)          # осколки льда
				await _sink(node)
			_:
				await _sink(node)
	if new_kind != BattleLogic.Obj.NONE:
		add_object(cell, new_kind)
		await _grow(_object_nodes.get(cell))


# Объект переехал (бочку откатили или перенесли)
func move_object(from: Vector2i, to: Vector2i) -> void:
	var node: Node3D = _object_nodes.get(from)
	if node == null:
		return
	_object_nodes.erase(from)
	_object_nodes[to] = node
	_object_kinds[to] = _object_kinds.get(from, BattleLogic.Obj.NONE)
	_object_kinds.erase(from)
	var tween: Tween = create_tween()
	var steps: int = HexMath.distance(from, to)
	tween.tween_property(node, "position", grid_to_world(to), 0.12 * steps)
	await tween.finished


# Новый объект «вырастает» из земли
func _grow(node: Node3D) -> void:
	if node == null:
		return
	node.scale = Vector3(1.0, 0.1, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT)
	await tween.finished


func _remove_object_node(cell: Vector2i) -> void:
	if _object_nodes.has(cell):
		_object_nodes[cell].queue_free()
		_object_nodes.erase(cell)
		_object_kinds.erase(cell)


# Модель объекта. Поворот «случайный», но одинаковый для клетки — чтобы объекты не выглядели копиями.
func _make_object(kind: int, cell: Vector2i) -> Node3D:
	var hash_value: int = posmod(cell.x * 37 + cell.y * 91, 360)
	var root: Node3D = null
	match kind:
		BattleLogic.Obj.BOG:
			root = OBJ_BOG.instantiate()
			root.rotation.y = (hash_value % 4) * PI / 2.0
		BattleLogic.Obj.TREE:
			root = OBJ_TREES[hash_value % 2].instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
		BattleLogic.Obj.BARREL:
			root = OBJ_BARREL.instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
			_add_light(root, Vector3(0.0, 0.5, 0.0), COLOR_GAS_LIGHT, 0.7, 2.4)   # газ подсвечивает соседние плиты
		BattleLogic.Obj.PLANKS:
			root = OBJ_PLANKS.instantiate()
			root.rotation.y = (hash_value % 2) * PI
		BattleLogic.Obj.REEDS:
			root = OBJ_REEDS.instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
		BattleLogic.Obj.ICE_BLOCK:
			root = OBJ_ICE.instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
		BattleLogic.Obj.STAKES:
			root = OBJ_STAKES.instantiate()
		BattleLogic.Obj.BRIDGE:
			root = OBJ_BRIDGE.instantiate()
		BattleLogic.Obj.LAVA:
			root = _make_lava_node()
		BattleLogic.Obj.CRUST:
			root = _make_crust_node(hash_value)
		BattleLogic.Obj.RUNE:
			root = _make_rune_node()
	return root


# Плоская плита с самоподсветкой (для лавы и корки)
func _glow_slab(size: Vector3, color: Color, glow: Color, energy: float, y: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	m.position.y = y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = glow
	mat.emission_energy_multiplier = energy
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


# Лава: тёмный остывший бортик и густая оранжево-жёлтая масса с тёплым светом (красного нет)
func _make_lava_node() -> Node3D:
	var root := Node3D.new()
	root.add_child(_glow_slab(Vector3(0.98, 0.1, 0.98), Color(0.18, 0.12, 0.08), Color(0.9, 0.4, 0.05), 0.4, 0.05))
	root.add_child(_glow_slab(Vector3(0.82, 0.14, 0.82), Color(1.0, 0.7, 0.15), Color(1.0, 0.6, 0.1), 2.2, 0.07))
	root.add_child(_glow_slab(Vector3(0.4, 0.17, 0.4), Color(1.0, 0.85, 0.3), Color(1.0, 0.8, 0.2), 2.6, 0.09))
	_add_light(root, Vector3(0.0, 0.5, 0.0), Color(1.0, 0.6, 0.15), 0.8, 2.4)
	return root


# Корка: тёмно-серая плита с оранжевыми трещинами
func _make_crust_node(hash_value: int) -> Node3D:
	var root := Node3D.new()
	root.rotation.y = (hash_value % 4) * PI / 2.0
	root.add_child(_glow_slab(Vector3(0.94, 0.12, 0.94), Color(0.25, 0.25, 0.27), Color(0.2, 0.1, 0.03), 0.2, 0.06))
	root.add_child(_glow_slab(Vector3(0.7, 0.13, 0.06), Color(0.3, 0.2, 0.1), Color(1.0, 0.5, 0.1), 1.2, 0.065))
	var crack := _glow_slab(Vector3(0.06, 0.13, 0.55), Color(0.3, 0.2, 0.1), Color(1.0, 0.5, 0.1), 1.2, 0.065)
	crack.position.x = 0.15
	root.add_child(crack)
	return root


# Дерево валится в сторону dir (поворот вокруг основания), потом исчезает
func _fall_tree(node: Node3D, dir: Vector2i) -> void:
	var pivot := Node3D.new()
	pivot.position = node.position
	add_child(pivot)
	node.reparent(pivot)
	var fall: Vector3 = HexMath.axial_to_world(dir)   # куда падает: вектор в мире
	var axis := Vector3(fall.z, 0.0, -fall.x).normalized()   # ось, перпендикулярная падению
	if axis == Vector3.ZERO:
		axis = Vector3.RIGHT
	var tween: Tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		pivot.basis = Basis(axis, t * PI * 0.5), 0.0, 1.0, 0.35).set_ease(Tween.EASE_IN)
	await tween.finished
	var fade: Tween = create_tween()
	fade.tween_property(pivot, "scale", Vector3(0.05, 0.05, 0.05), 0.4).set_delay(0.3)
	fade.finished.connect(pivot.queue_free)


# Бочка раздувается и лопается
func _pop(node: Node3D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector3(1.4, 1.2, 1.4), 0.12)
	tween.tween_property(node, "scale", Vector3(0.05, 0.05, 0.05), 0.08)
	await tween.finished
	node.queue_free()


# Объект уходит вниз (мостки тонут, камыш сгорает, трясина замерзает)
func _sink(node: Node3D) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(node, "position:y", node.position.y - 0.25, 0.25)
	tween.parallel().tween_property(node, "scale", Vector3(1.0, 0.1, 1.0), 0.25)
	await tween.finished
	node.queue_free()


# ---------- Маршруты врагов ----------

# Рисует пути врагов тонкими линиями со стрелкой на конце.
# paths — массив путей (каждый — массив клеток от врага до точки, куда он встанет).
func show_routes(paths: Array) -> void:
	clear_layer("routes")
	var holder := Node3D.new()
	add_child(holder)
	_layers["routes"] = holder
	var y: float = LAYER_HEIGHT["routes"]
	var mat: StandardMaterial3D = _get_flat_material(COLOR_ROUTE)
	for path: Array in paths:
		if path.size() < 2:
			continue
		for i in range(1, path.size()):
			var a: Vector3 = grid_to_world(path[i - 1])
			var b: Vector3 = grid_to_world(path[i])
			if i == path.size() - 1:
				b = a.lerp(b, 0.55)   # последний отрезок короче — дальше рисуем стрелку
			var seg := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.09, 0.02, a.distance_to(b) + 0.09)
			seg.mesh = box
			seg.material_override = mat
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			seg.position = (a + b) / 2.0 + Vector3(0, y, 0)
			seg.rotation.y = atan2(b.x - a.x, b.z - a.z)
			holder.add_child(seg)
		# Стрелка: плоский треугольник, остриём в сторону последнего шага
		var last: Vector2i = path[path.size() - 1]
		var prev: Vector2i = path[path.size() - 2]
		var arrow := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.34, 0.32, 0.02)
		arrow.mesh = prism
		arrow.material_override = mat
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.position = grid_to_world(prev).lerp(grid_to_world(last), 0.62) + Vector3(0, y, 0)
		# Сначала кладём треугольник на пол (остриё смотрит в -Z), потом поворачиваем к цели
		var heading: Vector3 = grid_to_world(last) - grid_to_world(prev)
		arrow.rotation = Vector3(-PI / 2.0, atan2(-heading.x, -heading.z), 0.0)
		holder.add_child(arrow)


# Сторожевая руна рыцаря: плоский светящийся знак на плите (заглушка до модели obj_rune.glb).
# Серебристо-белая: не жёлтая (маршруты врагов) и не красная (угроза).
func _make_rune_node() -> Node3D:
	var root := Node3D.new()
	var silver := Color(0.86, 0.9, 0.96)
	var glow := Color(0.8, 0.88, 1.0)
	var ring: MeshInstance3D = _glow_slab(Vector3(0.6, 0.02, 0.6), Color(0.2, 0.22, 0.26), glow, 0.25, 0.03)
	root.add_child(ring)
	var bar_a: MeshInstance3D = _glow_slab(Vector3(0.5, 0.025, 0.07), silver, glow, 1.6, 0.05)
	bar_a.rotation.y = PI / 4.0
	root.add_child(bar_a)
	var bar_b: MeshInstance3D = _glow_slab(Vector3(0.5, 0.025, 0.07), silver, glow, 1.6, 0.05)
	bar_b.rotation.y = -PI / 4.0
	root.add_child(bar_b)
	var stem: MeshInstance3D = _glow_slab(Vector3(0.07, 0.025, 0.5), silver, glow, 1.6, 0.05)
	root.add_child(stem)
	return root
