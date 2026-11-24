class_name Board
extends Node3D
# Игровое поле: плиты, объекты топей, декор вокруг арены, подсветка клеток,
# огонь/вода/лёд. Правил не знает — только рисует то, что ему скажут.

# Поле из сот: размеры клетки задаёт HexMath (расстояние между центрами соседей, радиус гекса).
const CELL_STEP: float = HexMath.CELL_STEP                 # расстояние между центрами соседних клеток, м
const ROW_STEP: float = HexMath.HEX_SIZE * 1.5             # расстояние между рядами, м
const TILE_GAP: float = 0.97       # доля клетки, которую занимает плита-заглушка (остальное — щель)
const TILE_MODEL_SCALE: float = 1.013   # модели плит чуть шире своей заготовки: щели между ними уже
const TILE_THICKNESS: float = 0.2  # толщина плиты

# Цвета плит-заглушек (те же, что в assets/models/src/build_topi.py).
# Плиты — шестиугольные модели tile_hex_*.glb; если файла нет, рисуется простая призма этого цвета.
const TILE_COLORS: Dictionary[int, Color] = {
	BattleLogic.Ground.STONE: Color(0.30, 0.33, 0.33),
	BattleLogic.Ground.MOSS: Color(0.25, 0.33, 0.18),
	BattleLogic.Ground.MUD: Color(0.24, 0.20, 0.15),
	BattleLogic.Ground.PLANKS: Color(0.34, 0.26, 0.17),
	BattleLogic.Ground.BASALT: Color(0.21, 0.20, 0.20),   # Тлеющая пещера: тёмный базальт
	BattleLogic.Ground.PEAT: Color(0.27, 0.19, 0.13),     # торф (на нём снова вспыхивает огонь)
	BattleLogic.Ground.ASH: Color(0.33, 0.33, 0.33),      # акт 2, Тракт: пепельная плита
	BattleLogic.Ground.METAL: Color(0.30, 0.23, 0.16),    # акт 2, Подземье: клёпаный пол
}
const TILE_STONE_ALT: Color = Color(0.26, 0.29, 0.29)   # второй оттенок камня для разнообразия

# Все модели топей собраны скриптом assets/models/src/build_topi.py
const SUBTLE_SCALE: float = 0.9   # сдержанная подсветка: контур чуть внутри соты
const POOL_TILES: Array[int] = [BattleLogic.Tile.WATER, BattleLogic.Tile.SWAMP]   # клетки, которые сливаются с соседями
const PUDDLE_PART: float = 0.8    # лужа меньше плиты (доля радиуса соты)
const PUDDLE_Y: float = 0.025     # высота глади луж
const HIGHLIGHT_SHADER: Shader = preload("res://assets/shaders/cell_highlight.gdshader")   # подсветка клеток: контур + слабая заливка
const MIST_SHADER: Shader = preload("res://assets/shaders/ground_mist.gdshader")   # стелющийся туман
const WATER_SHADER: Shader = preload("res://assets/shaders/water.gdshader")   # вода вокруг поля и лужи
const DIR: String = "res://assets/models/topi/"

# Шестиугольные плиты по виду покрытия (build_topi.py, «tile_hex_*»), у каждого вида несколько
# вариантов — клетка берёт свой по координатам. Тёмный расколотый камень (stone_b) ставится там,
# где раньше был второй оттенок камня.
const TILE_MODELS: Dictionary[int, Array] = {
	# цельная плита чаще остальных — расколотые не должны рябить по всему полю
	BattleLogic.Ground.STONE: ["tile_hex_stone_a", "tile_hex_stone_d", "tile_hex_stone_a", "tile_hex_stone_c",
			"tile_hex_stone_a", "tile_hex_stone_e", "tile_hex_stone_d"],
	BattleLogic.Ground.MOSS: ["tile_hex_moss", "tile_hex_moss_b", "tile_hex_moss_c"],
	BattleLogic.Ground.MUD: ["tile_hex_mud", "tile_hex_mud_b", "tile_hex_mud_c"],
	BattleLogic.Ground.PLANKS: ["tile_hex_planks", "tile_hex_planks_b", "tile_hex_planks_c"],
	BattleLogic.Ground.BASALT: ["tile_hex_basalt", "tile_hex_basalt_b"],
	BattleLogic.Ground.PEAT: ["tile_hex_peat", "tile_hex_peat_b"],
	# акт 2 (assets/models/src/build_ash.py)
	BattleLogic.Ground.ASH: ["tile_hex_ash", "tile_hex_ash", "tile_hex_ash_b", "tile_hex_ash_c", "tile_hex_ash"],
	BattleLogic.Ground.METAL: ["tile_hex_metal", "tile_hex_metal", "tile_hex_metal_b"],
}
const TILE_STONE_ALT_MODEL: String = "tile_hex_stone_b"
# (квадратные плиты tile_*.glb от старой квадратной сетки не используются)

# Объекты на клетках (ключ — BattleLogic.Obj)
const OBJ_BOG: PackedScene = preload(DIR + "obj_bog.glb")
# Стыки покрытий (build_topi.py): полоса поверх щели между двумя клетками мха или грязи
const JOINT_MOSS: PackedScene = preload(DIR + "joint_moss.glb")
const JOINT_MUD: PackedScene = preload(DIR + "joint_mud.glb")
# Мох и грязь с соседней клетки на краю каменной плиты и гати
const EDGE_MOSS: Array[PackedScene] = [preload(DIR + "edge_moss_a.glb"), preload(DIR + "edge_moss_b.glb")]
const EDGE_MUD: Array[PackedScene] = [preload(DIR + "edge_mud_a.glb"), preload(DIR + "edge_mud_b.glb")]
const EDGE_TARGETS: Array[int] = [BattleLogic.Ground.STONE, BattleLogic.Ground.PLANKS]
# Бортик трясины на одну сторону соты: ставится только туда, где сосед — не трясина
const BOG_RIMS: Array[PackedScene] = [preload(DIR + "bog_rim_a.glb"), preload(DIR + "bog_rim_b.glb")]
# Клетки с водой трясины: сама трясина и то, что лежит поверх неё (мостки, настил)
const BOG_WATER_KINDS: Array[int] = [BattleLogic.Obj.BOG, BattleLogic.Obj.PLANKS, BattleLogic.Obj.BRIDGE]
const OBJ_TREES: Array[PackedScene] = [preload(DIR + "obj_tree_a.glb"), preload(DIR + "obj_tree_b.glb")]
const OBJ_BARREL: PackedScene = preload(DIR + "obj_barrel.glb")
const OBJ_PLANKS: PackedScene = preload(DIR + "obj_planks.glb")
const OBJ_REEDS: PackedScene = preload(DIR + "obj_reeds.glb")
const OBJ_ICE: PackedScene = preload(DIR + "obj_ice.glb")
const OBJ_STAKES: PackedScene = preload(DIR + "obj_stakes.glb")
const OBJ_BRIDGE: PackedScene = preload(DIR + "obj_bridge.glb")
# Густые леса и насосная
const OBJ_LIVE_TREES: Array[PackedScene] = [preload(DIR + "obj_live_tree_a.glb"), preload(DIR + "obj_live_tree_b.glb")]
const OBJ_VINE: PackedScene = preload(DIR + "obj_vine.glb")
const OBJ_BUSH: PackedScene = preload(DIR + "obj_bush.glb")
const OBJ_HIVE: PackedScene = preload(DIR + "obj_hive.glb")
const OBJ_VALVE: PackedScene = preload(DIR + "obj_valve.glb")
const ROCK_PIPE: PackedScene = preload(DIR + "rock_pipe.glb")
const ROCK_ROOT: PackedScene = preload(DIR + "rock_root.glb")
const ROCK_LOG: PackedScene = preload(DIR + "rock_log.glb")
const D_TREE_GREEN: PackedScene = preload(DIR + "decor_tree_green.glb")
const D_FERN: PackedScene = preload(DIR + "decor_fern.glb")
const D_PUMP: PackedScene = preload(DIR + "decor_pump.glb")
const COLOR_FOREST_FLOOR := Color(0.07, 0.085, 0.055)   # лесная земля вокруг лесных арен (вместо воды)
const COLOR_BURN_LIGHT := Color(1.0, 0.58, 0.22)       # горящая крона

# Неразрушимые преграды: у каждой арены свои
const ROCK_BOULDER: PackedScene = preload(DIR + "rock_boulder.glb")
const ROCK_PILLAR: PackedScene = preload(DIR + "rock_pillar.glb")
const ROCK_CRATES: PackedScene = preload(DIR + "rock_crates.glb")
const ROCK_MARKER: PackedScene = preload(DIR + "rock_marker.glb")
const ROCK_BONES: PackedScene = preload(DIR + "rock_bones.glb")
# Тлеющая пещера (assets/models/src/build_cave.py)
const ROCK_STALAGMITE: PackedScene = preload(DIR + "rock_stalagmite.glb")
# Куски топкого берега: ими обложен край островка с плитами, чтобы он не был ровным «столом»
const D_SHORE: Array[PackedScene] = [preload(DIR + "decor_shore_a.glb"), preload(DIR + "decor_shore_b.glb"),
		preload(DIR + "decor_shore_c.glb")]
const D_CAVE_WALL: PackedScene = preload(DIR + "decor_cave_wall.glb")
const D_EMBERS: PackedScene = preload(DIR + "decor_embers.glb")
# Акт 2 «Пепельный тракт» (assets/models/src/build_ash.py). Пути, а не preload: нет файла — берётся замена.
const ASH_ROCKS: Dictionary[String, Array] = {
	"wagons": ["rock_wagon", "rock_wagon", "rock_slag"],
	"ashfield": ["rock_charred_log"],
	"shrine": ["rock_altar", "rock_banner"],
	"lava_beds": ["rock_basalt"],
	"springs": ["rock_basalt"],
	"tower": ["rock_tower_block"],
	"dunes": ["rock_slag", "rock_wagon"],
	"pass": ["rock_basalt", "rock_basalt", "rock_slag"],
	"embers": ["rock_stalagmite"],
	"sphere_hall": ["rock_pipe"],
	"steamworks": ["rock_pipe", "rock_pipe", "rock_boiler"],
	"mine": ["rock_basalt", "rock_basalt", "rock_cart"],
	"rift_lab": ["rock_machine", "rock_pipe"],
	"lake": ["rock_stalagmite"],
	"assembly": ["rock_machine", "rock_crates"],
	"fungus": ["rock_stalagmite"],
	"cliff": ["rock_wagon", "rock_basalt"],
	"reactor": ["rock_boiler"],
	"crater": ["rock_banner", "rock_basalt"],
}
# Вид объектов клеток на аренах акта 2: механика та же, модель другая (бочка — масло, жаровня, сфера, гриб…)
const ASH_SKINS: Dictionary[String, Dictionary] = {
	"wagons": {BattleLogic.Obj.BARREL: "obj_oil_barrel"},
	"ashfield": {BattleLogic.Obj.TREE: "obj_tree_charred"},
	"shrine": {BattleLogic.Obj.BARREL: "obj_brazier"},
	"springs": {BattleLogic.Obj.VALVE: "obj_geyser"},
	"tower": {BattleLogic.Obj.TREE: "obj_wall_cracked"},
	"dunes": {BattleLogic.Obj.BARREL: "obj_oil_barrel"},
	"pass": {BattleLogic.Obj.BARREL: "obj_oil_barrel"},
	"sphere_hall": {BattleLogic.Obj.BARREL: "obj_sphere_fire", BattleLogic.Obj.VALVE: "obj_sphere_water"},
	"mine": {BattleLogic.Obj.BARREL: "obj_oil_barrel"},
	"assembly": {BattleLogic.Obj.BARREL: "obj_oil_barrel"},
	"fungus": {BattleLogic.Obj.BARREL: "obj_puffball"},
	"cliff": {BattleLogic.Obj.BARREL: "obj_oil_barrel"},
}
# Россыпь вокруг арен акта 2: [имя модели, сколько]
const ASH_SCATTER: Dictionary[String, Array] = {
	"ash": [["decor_dune", 6], ["obj_tree_charred_a", 6], ["obj_tree_charred_b", 5], ["rock_slag", 5], ["decor_wheel", 3],
			["rock_basalt", 4], ["decor_embers", 5]],
	"deep": [["rock_stalagmite", 14], ["decor_embers", 6], ["rock_basalt", 4]],
	"fungus": [["decor_mushroom_giant", 8], ["rock_stalagmite", 10], ["decor_embers", 2]],
	"lab": [["rock_boiler", 4], ["rock_pipe", 6], ["rock_machine", 3], ["rock_stalagmite", 6], ["decor_embers", 3]],
}
const LAB_ARENAS: Array[String] = ["sphere_hall", "steamworks", "rift_lab", "assembly", "reactor"]
const COLOR_ASH_FLOOR := Color(0.15, 0.145, 0.14)       # пепельная земля вокруг полей Тракта
const COLOR_ASH_SAND := Color(0.42, 0.41, 0.4)        # сыпучий пепел Дюн (клетка «топи» на Тракте)
var _ash_scenes: Dictionary[String, PackedScene] = {}

const ARENA_ROCKS: Dictionary[String, Array] = {
	"gat": [ROCK_BOULDER, ROCK_MARKER],
	"grove": [ROCK_BOULDER],
	"reeds": [ROCK_BOULDER],
	"camp": [ROCK_CRATES],
	"ruins": [ROCK_PILLAR, ROCK_PILLAR, ROCK_MARKER],
	"lair": [ROCK_BONES, ROCK_BOULDER],
	"cave": [ROCK_STALAGMITE],
	"pond": [ROCK_BOULDER],
	"pump": [ROCK_PIPE, ROCK_PIPE, ROCK_CRATES],
	"thicket": [ROCK_BOULDER],
	"sanctum": [D_TOTEM, ROCK_BOULDER],
	"hollow": [ROCK_ROOT, ROCK_ROOT, ROCK_BOULDER],
	"windfall": [ROCK_LOG],
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
	"cave": [[ROCK_STALAGMITE, 14], [D_EMBERS, 8], [D_ROCK_BIG, 3]],
	"pond": [[OBJ_REEDS, 18], [D_TUSSOCK, 12], [D_MUSHROOMS, 4], [D_TREE_BIG, 4], [D_STUMP, 3]],
	"pump": [[ROCK_PIPE, 5], [ROCK_CRATES, 3], [D_TUSSOCK, 6], [D_TREE_BIG, 3], [OBJ_REEDS, 5], [D_MUSHROOMS, 2]],
	"thicket": [[D_TREE_GREEN, 14], [OBJ_LIVE_TREES[0], 8], [OBJ_BUSH, 10], [D_FERN, 12], [D_STUMP, 2], [D_MUSHROOMS, 3]],
	"sanctum": [[D_TREE_GREEN, 10], [D_TOTEM, 4], [D_FERN, 12], [OBJ_BUSH, 6], [D_MUSHROOMS, 4], [D_ROCK_BIG, 2]],
	"hollow": [[D_TREE_GREEN, 8], [D_TREE_BIG, 4], [ROCK_ROOT, 8], [D_FERN, 8], [D_ROCK_BIG, 3], [D_MUSHROOMS, 5]],
	"windfall": [[D_TREE_GREEN, 11], [ROCK_LOG, 6], [D_FERN, 10], [OBJ_BUSH, 6], [D_STUMP, 3], [OBJ_HIVE, 1]],
}

# На какой высоте рисовать каждый слой подсветки (чтобы они не «мерцали», налезая друг на друга)
const LAYER_HEIGHT: Dictionary = {
	"objective": 0.125,  # цель боя: верхний ряд «Прорыва», ряд, который зальёт вода
	"move": 0.13,     # куда можно пойти
	"target": 0.14,   # куда можно применить карту
	"buff": 0.145,    # кого враг усилит «зовом»
	"intent": 0.15,   # куда могут ударить враги
	"hover_threat": 0.155,  # зона врага под курсором
	"area": 0.16,     # что заденет карта под курсором
	"ghost_move": 0.165,  # куда «призрак» карты переставит юнитов
	"ghost_kill": 0.166,  # кто погибнет от карты
	"flash": 0.17,    # вспышка удара
	"routes": 0.2,    # линии маршрутов врагов
	"flow": 0.11,
	"belts": 0.11,     # стрелки ветра и лент конвейера (под подсветкой ходов)
}

const IMPACT_FX_SCALE: float = 1.5   # во сколько раз крупнее частицы взрыва бочки и падения дерева (подкрути, если мало или много)
const COLOR_ROUTE := Color(1.0, 0.92, 0.55, 0.95)   # тёплый жёлтый: виден и на камне, и на воде
const COLOR_SWAMP_WATER := Color(0.05, 0.075, 0.065) # стоячая вода вокруг арены
const COLOR_BANK := Color(0.2, 0.18, 0.14)           # топкий берег, на котором лежат плиты
const COLOR_GAS_LIGHT := Color(0.55, 0.95, 0.35)     # болотный газ
const COLOR_LAMP_LIGHT := Color(1.0, 0.72, 0.35)     # фонарь Стражи
const COLOR_WISP := Color(0.6, 1.0, 0.75)            # болотные огоньки
const COLOR_CAVE_FLOOR := Color(0.07, 0.06, 0.055)   # Тлеющая пещера: тёмный пол вместо воды
const COLOR_EMBER_LIGHT := Color(1.0, 0.55, 0.2)     # жар углей и искры (оранжевый, не красный)

@export var width: int = 12   # клеток по горизонтали
@export var height: int = 12  # клеток в глубину

var _layers: Dictionary[String, Node3D] = {}
var _effects: Dictionary[Vector2i, Node3D] = {}
var _flat_materials: Dictionary[Color, StandardMaterial3D] = {}
var _highlight_materials: Dictionary[String, ShaderMaterial] = {}
var _solid_materials: Dictionary[Color, StandardMaterial3D] = {}
var _highlight_mesh: CylinderMesh
var _tile_mesh: CylinderMesh
var _hex_tile_meshes: Dictionary[String, Mesh] = {}
var _object_nodes: Dictionary[Vector2i, Node3D] = {}
var _object_kinds: Dictionary[Vector2i, int] = {}
var _rock_nodes: Dictionary[Vector2i, Node3D] = {}    # преграды на клетках (для сверки после отмены хода)
var _bog_water: Dictionary[Vector2i, Node3D] = {}
var _lava_links: Dictionary[Vector2i, Node3D] = {}    # перемычки между соседними клетками лавы
var _tile_drop: Dictionary[Vector2i, float] = {}      # на сколько плита клетки опущена (неровность пола)
var _swamp_mat: StandardMaterial3D     # вода и бортики трясины по клеткам
var _puddle_links: Dictionary[Vector2i, Node3D] = {}  # перемычки между соседними лужами
var _effect_kinds: Dictionary[Vector2i, int] = {}     # какой эффект лежит на клетке (BattleLogic.Tile)
var _bog_water_mat: ShaderMaterial
var _puddle_mat: ShaderMaterial
var _arena: String = ""
var boss_sign: String = ""                  # модель знака босса (Run.boss_sign_for), "" — знака нет. Задать до build()
var boss_sign_pos: Vector3 = Vector3.INF    # где стоит знак (для подсказки при наведении)
# Эффекты (частицы, свет). Сцена боя задаёт его до того, как ставит объекты и клетки.
# Пусто — клетки рисуются по-старому, простыми формами.
var vfx: VfxPlayer = null


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
		var variants: Array = TILE_MODELS.get(kind, TILE_MODELS[BattleLogic.Ground.STONE])
		# вариант — по клетке (не по общему генератору, чтобы не сдвинуть раскладку декора)
		var model_name: String = variants[posmod(cell.x * 17 + cell.y * 31 + cell.x * cell.y * 5, variants.size())]
		if kind == BattleLogic.Ground.STONE and rng.randf() > 0.6:
			color = TILE_STONE_ALT
			model_name = TILE_STONE_ALT_MODEL
		var tile := MeshInstance3D.new()
		var tile_mesh: Mesh = _get_hex_tile_mesh(model_name)
		var drop: float = rng.randf() * 0.02   # плиты чуть неровные по высоте
		if tile_mesh != null:
			tile.mesh = tile_mesh
			# плиты — пол: тень отбрасывать им некуда, а сами себе они давали полосы («зубцы» тени)
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Без упрощения издалека (LOD): у плит мало треугольников, а упрощение склеивает
			# расколы плит в «веер» из полос
			tile.lod_bias = 128.0
			# Поворот на 0/60/…/300° по клетке, чтобы одинаковые плиты не лежали «под копирку».
			# Гать — только 0 или 180°: брёвна идут поперёк дороги.
			var turns: int = posmod(cell.x * 7 + cell.y * 13, 6)
			if kind == BattleLogic.Ground.PLANKS:
				turns = (turns % 2) * 3
			tile.rotation.y = deg_to_rad(60.0 * turns)
			tile.position = grid_to_world(cell) + Vector3(0.0, -drop, 0.0)
			tile.scale = Vector3(TILE_MODEL_SCALE, 1.0, TILE_MODEL_SCALE)   # щели между плитами уже
		else:
			tile.mesh = _get_tile_mesh()
			tile.material_override = _get_solid_material(color)
			tile.position = grid_to_world(cell) + Vector3(0.0, -TILE_THICKNESS / 2.0 - drop, 0.0)
		add_child(tile)
		_tile_drop[cell] = drop

	_build_ground_joints(ground)
	_build_decorations(rng)
	if _biome() == "bog":
		_build_shore_edge(layout_seed)
	_build_wisps()


# Стыки покрытий, чтобы поле смотрелось одним местом, а не шахматной доской:
# — соседние клетки мха (или грязи) сливаются: моховая/грязевая полоса поверх щели,
#   посередине тонкая линия — клетки всё равно считаются;
# — у каменной плиты и гати рядом с мхом или грязью край зарастает мхом / пачкается грязью.
func _build_ground_joints(ground: Dictionary[Vector2i, int]) -> void:
	if ground.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "GroundJoints"
	add_child(holder)
	var apothem: float = CELL_STEP * 0.5
	var soft: Dictionary[int, PackedScene] = {BattleLogic.Ground.MOSS: JOINT_MOSS, BattleLogic.Ground.MUD: JOINT_MUD}
	var edges: Dictionary[int, Array] = {BattleLogic.Ground.MOSS: EDGE_MOSS, BattleLogic.Ground.MUD: EDGE_MUD}
	for cell: Vector2i in ground:
		var kind: int = ground[cell]
		for i in HexMath.DIRS.size():
			var d: Vector2i = HexMath.DIRS[i]
			var other: Vector2i = cell + d
			if not ground.has(other):
				continue
			var other_kind: int = ground[other]
			var v: Vector3 = HexMath.axial_to_world(d).normalized()
			var hash_value: int = posmod(cell.x * 29 + cell.y * 11 + i * 7, 101)
			if kind == other_kind and soft.has(kind) and i < 3:   # каждый стык — один раз
				var joint: Node3D = soft[kind].instantiate()
				var y: float = -(_tile_drop.get(cell, 0.0) + _tile_drop.get(other, 0.0)) * 0.5
				joint.position = grid_to_world(cell) + v * apothem + Vector3(0.0, y, 0.0)
				joint.rotation.y = atan2(v.x, v.z)
				if hash_value % 2 == 0:   # разворот на 180° — полоса не повторяется (отражать нельзя: темнеет)
					joint.rotation.y += PI
				holder.add_child(joint)
			elif EDGE_TARGETS.has(kind) and edges.has(other_kind):
				var list: Array = edges[other_kind]
				var edge: Node3D = (list[hash_value % list.size()] as PackedScene).instantiate()
				edge.position = grid_to_world(cell) + v * apothem * 0.82 + Vector3(0.0, -_tile_drop.get(cell, 0.0), 0.0)
				edge.rotation.y = atan2(v.x, v.z)   # сторона соседа модели (+Z) — к соседу
				holder.add_child(edge)
	for n in holder.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Вода топей до горизонта и тёмный берег-островок под плитами
func _build_shore() -> void:
	var center: Vector3 = field_center()
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 220.0)
	water.mesh = plane
	if _biome() != "bog":   # в пещере, в лесу и на Тракте вместо воды — сухая земля
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = {"forest": COLOR_FOREST_FLOOR, "ash": COLOR_ASH_FLOOR}.get(_biome(), COLOR_CAVE_FLOOR)
		floor_mat.roughness = 1.0
		water.material_override = floor_mat
	else:
		# Стоячая вода с рябью, отражает небо и арену (assets/shaders/water.gdshader)
		var water_mat := ShaderMaterial.new()
		water_mat.shader = WATER_SHADER
		water_mat.set_shader_parameter("deep_color", COLOR_SWAMP_WATER)
		water_mat.set_shader_parameter("shallow_color", COLOR_SWAMP_WATER * 1.8)
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


# Неровный берег: куски грязи с камнями, корнями и осокой вдоль всех четырёх краёв островка.
# Свой генератор от сида раскладки — порядок остального декора не меняется.
func _build_shore_edge(layout_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed + 7919
	var edge := Node3D.new()
	edge.name = "ShoreEdge"
	add_child(edge)
	var c: Vector3 = field_center()
	var hx: float = (width + 0.5) * CELL_STEP * 0.5
	var hz: float = ((height - 1) * ROW_STEP + HexMath.HEX_SIZE * 2.0 + 0.4) * 0.5
	# стороны: точка начала, направление вдоль стороны, длина, наружу (к воде)
	var sides: Array = [
		[Vector3(c.x - hx, 0.0, c.z - hz), Vector3.RIGHT, hx * 2.0, Vector3.FORWARD],
		[Vector3(c.x - hx, 0.0, c.z + hz), Vector3.RIGHT, hx * 2.0, Vector3.BACK],
		[Vector3(c.x - hx, 0.0, c.z - hz), Vector3.BACK, hz * 2.0, Vector3.LEFT],
		[Vector3(c.x + hx, 0.0, c.z - hz), Vector3.BACK, hz * 2.0, Vector3.RIGHT],
	]
	for side: Array in sides:
		var start: Vector3 = side[0]
		var along: Vector3 = side[1]
		var length: float = side[2]
		var out: Vector3 = side[3]
		var t: float = rng.randf_range(0.0, 0.5)
		while t < length + 0.3:
			var pos: Vector3 = start + along * t + out * rng.randf_range(0.05, 0.3)
			pos.y = c.y - 0.07
			var chunk: Node3D = _spawn_prop(edge, D_SHORE[rng.randi() % D_SHORE.size()], pos,
					atan2(out.x, out.z) + rng.randf_range(-0.3, 0.3))
			var s: float = rng.randf_range(0.9, 1.25)
			chunk.scale = Vector3(s, rng.randf_range(0.8, 1.1), s)
			t += rng.randf_range(0.8, 1.15)


# Декор за пределами сетки (на клики и правила не влияет).
# Общее для всех арен: Шпиль на горизонте, фонари Стражи, россыпь по списку арены.
func _build_decorations(rng: RandomNumberGenerator) -> void:
	var decor := Node3D.new()
	decor.name = "Decorations"
	add_child(decor)
	var w: float = width * CELL_STEP     # ширина поля в метрах
	var h: float = height * ROW_STEP     # глубина поля в метрах

	if _biome() == "deep":
		_build_cave_walls(decor, rng)   # под землёй Шпиля и фонарей Стражи не видно
	else:
		# Шпиль далеко на севере: цель всего пути. Трещина в небе над ним светится.
		var spire: Node3D = _spawn_prop(decor, D_SPIRE, Vector3(w * 0.5 + rng.randf_range(-6.0, 6.0), -1.0, -62.0), 0.0)
		spire.scale = Vector3(2.2, 2.2, 2.2)

		# Фонари Стражи у дальних углов и один сбоку — тёплые островки света (в глухом лесу их нет)
		var lanterns: Array[Vector3] = [Vector3(-1.4, 0.0, -1.2), Vector3(w + 0.4, 0.0, -1.2), Vector3(-1.5, 0.0, h * 0.62)]
		if _biome() != "bog":
			lanterns.clear()   # в глухом лесу и на выжженном тракте фонарей Стражи нет
		if _biome() == "ash":   # вулкан за полем — к нему ведёт тракт
			var volcano: PackedScene = _ash_scene("decor_volcano")
			if volcano != null:
				_spawn_prop(decor, volcano, Vector3(w * 0.5 + 22.0 + rng.randf_range(-4.0, 4.0), -0.5, -48.0), 0.0)
		for pos: Vector3 in lanterns:
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
		"pump":
			_spawn_prop(decor, D_PUMP, Vector3(w * 0.5 - 0.5, -0.05, -2.6), 0.1)
			_spawn_prop(decor, D_PUMP, Vector3(w + 2.8, -0.1, h * 0.35), -1.3)
			_spawn_prop(decor, D_BOAT, Vector3(-2.6, -0.1, h * 0.5), 0.4)
		"sanctum":
			for pos: Vector3 in [Vector3(-1.6, 0.0, 1.5), Vector3(w + 0.6, 0.0, 2.5), Vector3(w * 0.5 - 2.0, 0.0, -1.8),
					Vector3(w * 0.5 + 1.5, 0.0, -1.8)]:
				_spawn_prop(decor, D_TOTEM, pos, rng.randf_range(-0.5, 0.5))
		"shrine", "crater":
			var banner: PackedScene = _ash_scene("rock_banner")
			if banner != null:
				for pos: Vector3 in [Vector3(-1.5, 0.0, 1.2), Vector3(w + 0.5, 0.0, 2.0), Vector3(w * 0.5 - 2.5, 0.0, -1.8),
						Vector3(w * 0.5 + 2.0, 0.0, -1.8)]:
					_spawn_prop(decor, banner, pos, rng.randf_range(-0.4, 0.4))
		"tower":
			var bell_ruin: Node3D = _spawn_prop(decor, D_BELL, Vector3(w * 0.5 + 1.5, -0.1, -1.6), 0.6)
			bell_ruin.rotation.z = 0.5   # колокол лежит в обломках
		"lair":
			_spawn_prop(decor, D_RIBS, Vector3(w * 0.5 - 0.5, -0.05, -2.6), 0.15)
			for pos: Vector3 in [Vector3(-1.6, 0.0, 2.0), Vector3(w + 0.6, 0.0, 3.5), Vector3(w * 0.5 + 3.0, 0.0, -1.6)]:
				_spawn_prop(decor, D_TOTEM, pos, rng.randf_range(-0.5, 0.5))

	# Знак босса — у левого края, ближе к камере, чтобы его было видно с начала боя
	if boss_sign != "":
		var path: String = DIR + boss_sign + ".glb"
		if ResourceLoader.exists(path):
			boss_sign_pos = Vector3(-1.2, 0.0, h * 0.5)
			var sign_node: Node3D = _spawn_prop(decor, load(path) as PackedScene, boss_sign_pos, rng.randf_range(0.3, 0.9))
			sign_node.name = "BossSign"
			sign_node.scale = Vector3(1.4, 1.4, 1.4)

	# Россыпь по списку арены. Занятые места запоминаем, чтобы декор не слипался.
	var taken: Array[Vector3] = []
	for child in decor.get_children():
		taken.append((child as Node3D).position)
	var scatter: Array = ARENA_SCATTER.get(_arena, ARENA_SCATTER["gat"])
	if BattleLogic.ARENA_BIOME.has(_arena) and _arena != "cave":
		scatter = _ash_scatter()
	for entry: Array in scatter:
		var scene: PackedScene = entry[0]
		var tall: bool = scene == D_TREE_BIG or scene == D_ROCK_BIG or scene == D_TREE_GREEN or scene == D_PUMP
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
			if scene == D_EMBERS:
				_add_light(prop, Vector3(0.0, 0.4, 0.0), COLOR_EMBER_LIGHT, 1.2, 4.0)
			if scene.resource_path.ends_with("decor_mushroom_giant.glb"):
				_add_light(prop, Vector3(0.0, 1.3, 0.0), Color(0.35, 0.92, 0.82), 0.9, 4.0)


# Тлеющая пещера: кольцо базальтовых стен вокруг поля (кроме ближней к камере стороны)
func _build_cave_walls(decor: Node3D, rng: RandomNumberGenerator) -> void:
	var w: float = width * CELL_STEP
	var h: float = height * ROW_STEP
	var spots: Array[Vector3] = []
	for i in 9:   # дальняя стена
		spots.append(Vector3(-4.0 + (w + 8.0) * i / 8.0, 0.0, -4.5 - rng.randf() * 1.5))
	for i in 5:   # боковые
		spots.append(Vector3(-5.0 - rng.randf(), 0.0, -1.0 + h * i / 4.0))
		spots.append(Vector3(w + 4.0 + rng.randf(), 0.0, -1.0 + h * i / 4.0))
	for pos in spots:
		var wall: Node3D = _spawn_prop(decor, D_CAVE_WALL, pos, rng.randf() * TAU)
		var s: float = rng.randf_range(1.3, 1.9)
		wall.scale = Vector3(s, s * rng.randf_range(1.0, 1.4), s)
	for pos: Vector3 in [Vector3(-2.0, 0.0, -2.0), Vector3(w + 1.0, 0.0, h * 0.4), Vector3(-2.2, 0.0, h * 0.7)]:
		_add_light(decor, pos + Vector3(0.0, 1.0, 0.0), COLOR_EMBER_LIGHT, 2.0, 7.0)


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
	dot.material = _glow_material(COLOR_EMBER_LIGHT if _biome() == "deep" or _biome() == "ash" else COLOR_WISP, 3.0)   # в пещере и на Тракте — искры
	wisps.mesh = dot
	wisps.position = field_center() + Vector3(0.0, 0.9, 0.0)
	wisps.name = "Wisps"
	add_child(wisps)


# Атмосфера арены (эффекты, этап 6): мягкие огоньки вместо шариков, туман у краёв,
# мошкара у деревьев, морось. Зовётся сценой боя после того, как задан vfx.
# Стелющийся туман: два низких слоя над водой и краями поля (assets/shaders/ground_mist.gdshader).
# Над серединой поля почти прозрачный, чтобы бой читался.
func _add_ground_mist() -> void:
	var field_w: float = width * CELL_STEP
	var field_d: float = (height - 1) * ROW_STEP + HexMath.HEX_SIZE
	var c: Vector3 = field_center()
	var rect := Vector4(-CELL_STEP * 0.5, -HexMath.HEX_SIZE, field_w, field_d)
	for layer: Array in [[0.08, 0.6, 0.16], [0.32, 0.35, 0.11]]:   # высота, густота, размер клочьев
		var plane := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(field_w + 40.0, field_d + 40.0)
		plane.mesh = mesh
		plane.position = Vector3(c.x, layer[0], c.z)
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = MIST_SHADER
		mat.set_shader_parameter("field_rect", rect)
		mat.set_shader_parameter("density", layer[1])
		mat.set_shader_parameter("scale", layer[2])
		if _biome() == "deep":   # в пещере — бурый дым от тлеющего торфа, пореже
			mat.set_shader_parameter("mist_color", Color(0.3, 0.22, 0.16))
			mat.set_shader_parameter("density", layer[1] * 0.6)
		elif _biome() == "ash":   # на Тракте — серо-бурая пепельная дымка
			mat.set_shader_parameter("mist_color", Color(0.36, 0.31, 0.27))
			mat.set_shader_parameter("density", layer[1] * 0.7)
		plane.material_override = mat
		add_child(plane)


func add_atmosphere(rain: bool) -> void:
	_add_ground_mist()
	if vfx == null:
		return
	var center: Vector3 = field_center()
	var half := Vector3(width * CELL_STEP * 0.5, 0.0, height * ROW_STEP * 0.5)
	var old: Node = get_node_or_null("Wisps")
	if old != null:
		old.queue_free()
	var air := Node3D.new()
	air.name = "Atmosphere"
	add_child(air)
	if _biome() == "deep" or _biome() == "ash":
		# В пещере и на выжженном тракте вместо огоньков — искры углей, дождя и мошкары нет
		vfx.loop("wisp_loop", air, center + Vector3(0.0, 1.0, 0.0), 1.0, COLOR_EMBER_LIGHT,
			Vector3(half.x + 2.0, 0.8, half.z + 2.0))
		return
	vfx.loop("wisp_loop", air, center + Vector3(0.0, 1.0, 0.0), 1.0, Color(0, 0, 0, 0),
		Vector3(half.x + 4.0, 0.6, half.z + 4.0))
	# Туман: четыре полосы за краями поля, над водой — поле остаётся чистым
	var edge: float = 3.5
	for side: Array in [[Vector3(0.0, 0.0, -half.z - edge), Vector3(half.x + 6.0, 0.3, 2.0)],
			[Vector3(0.0, 0.0, half.z + edge), Vector3(half.x + 6.0, 0.3, 2.0)],
			[Vector3(-half.x - edge, 0.0, 0.0), Vector3(2.0, 0.3, half.z + 2.0)],
			[Vector3(half.x + edge, 0.0, 0.0), Vector3(2.0, 0.3, half.z + 2.0)]]:
		vfx.loop("mist_loop", air, center + side[0] + Vector3(0.0, 0.4, 0.0), 1.0, Color(0, 0, 0, 0), side[1])
	# Мошкара у больших деревьев (декор за краем поля)
	var decor: Node = get_node_or_null("Decorations")
	if decor != null:
		var swarms: int = 0
		for prop in decor.get_children():
			if swarms >= 4:
				break
			if prop is Node3D and String(prop.scene_file_path).contains("tree"):
				vfx.loop("midge_loop", air, (prop as Node3D).position + Vector3(0.4, 1.3, 0.3))
				swarms += 1
	if rain:
		vfx.loop("rain_loop", air, center + Vector3(0.0, 6.0, 0.0), 1.0, Color(0, 0, 0, 0),
			Vector3(half.x + 3.0, 0.5, half.z + 3.0))


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
# subtle = true — сдержанная подсветка: только тонкий контур чуть внутри соты, почти без заливки
# (клетки, куда можно идти: их много, они не должны застилать поле).
func show_cells(layer: String, cells: Array[Vector2i], color: Color, subtle: bool = false) -> void:
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
		m.material_override = _get_highlight_material(color, subtle)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if subtle:   # контур чуть внутри, чтобы у соседних клеток линии не сливались в толстую
			m.scale = Vector3(SUBTLE_SCALE, 1.0, SUBTLE_SCALE)
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
		if mark.has("text"):
			# Надпись над клеткой (номер звена цепочки в предпросмотре карты)
			var label := Label3D.new()
			label.text = mark["text"]
			label.font = UiKit.font_bold()
			label.font_size = 96
			label.pixel_size = 0.007
			label.outline_size = 20
			label.outline_modulate = Color(0, 0, 0, 0.9)
			label.modulate = mark.get("color", Color.WHITE)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.position = grid_to_world(mark["cell"]) + Vector3(0.0, 0.6, 0.0)
			holder.add_child(label)
			continue
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
	var was_pool: bool = POOL_TILES.has(_effect_kinds.get(cell, BattleLogic.Tile.NONE))
	_effect_kinds[cell] = tile
	if was_pool or POOL_TILES.has(tile):
		_refresh_puddles_around(cell)   # соседние лужи сливаются: перемычки пересобираются
	if tile == BattleLogic.Tile.NONE:
		_effect_kinds.erase(cell)
		return
	var root := Node3D.new()
	root.position = grid_to_world(cell)
	match tile:
		BattleLogic.Tile.WATER:
			# Лужа по форме соты: тёмное зеркало с рябью и голубым отсветом (стихия слегка светится).
			# Отражает небо и арену, как вода вокруг поля.
			var puddle := MeshInstance3D.new()
			puddle.mesh = _hex_prism(HexMath.HEX_SIZE * PUDDLE_PART, 0.01)   # край плиты виден — не путать с подсветкой хода
			puddle.position.y = PUDDLE_Y - 0.005
			puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			puddle.material_override = _get_puddle_material()   # общий материал — соседние лужи без шва
			root.add_child(puddle)
			if vfx != null:
				vfx.loop("ripple_loop", root, Vector3(0.0, 0.04, 0.0))   # круги на воде
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
			if vfx != null:
				vfx.loop("frost_loop", root, Vector3(0.0, 0.12, 0.0))   # блики инея
		BattleLogic.Tile.SWAMP:
			# Топь: тёмная болотная жижа с зеленоватым отсветом, по форме соты.
			# Соседние клетки топи сливаются (_refresh_puddle_links).
			var mud := MeshInstance3D.new()
			mud.mesh = _hex_prism(HexMath.HEX_SIZE * PUDDLE_PART, 0.01)
			mud.position.y = PUDDLE_Y - 0.005
			mud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mud.material_override = _get_swamp_material()
			root.add_child(mud)
			if vfx != null:
				vfx.loop("bubble_loop", root, Vector3(0.0, 0.035, 0.0))   # пузыри
		BattleLogic.Tile.GAS:
			# Ядовитый газ: полупрозрачное ядовито-зелёное облако над клеткой
			var cloud := _flat_disc(0.44 * CELL_STEP, Color(0.45, 0.85, 0.25, 0.45), 0.12)
			var cloud_mat: StandardMaterial3D = cloud.material_override
			cloud_mat.emission_enabled = true
			cloud_mat.emission = Color(0.4, 0.9, 0.2)
			cloud_mat.emission_energy_multiplier = 0.6
			root.add_child(cloud)
			if vfx != null:
				# Клубы газа над клеткой; плоский диск бледнее — клетку под газом видно
				cloud_mat.albedo_color.a = 0.25
				vfx.loop("gas_loop", root, Vector3(0.0, 0.45, 0.0))
		BattleLogic.Tile.SMOKE:
			# Дым Пепельника: густое серое облако, сквозь которое не видно
			var smoke := _flat_disc(0.46 * CELL_STEP, Color(0.42, 0.4, 0.38, 0.7), 0.4)
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(smoke)
			var puff := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = 0.42 * CELL_STEP
			ball.height = 0.5 * CELL_STEP
			ball.radial_segments = 8
			ball.rings = 4
			puff.mesh = ball
			puff.position.y = 0.55
			var puff_mat := StandardMaterial3D.new()
			puff_mat.albedo_color = Color(0.5, 0.48, 0.46, 0.55)
			puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			puff_mat.roughness = 1.0
			puff.material_override = puff_mat
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(puff)
			if vfx != null:
				vfx.loop("smoke_loop", root, Vector3(0.0, 0.7, 0.0))
		BattleLogic.Tile.FIRE:
			# Тлеющая земля, языки пламени из частиц и оранжевый свет
			var embers := _flat_disc(0.42 * CELL_STEP, Color(1.0, 0.4, 0.08, 0.75), 0.03)
			var e_mat: StandardMaterial3D = embers.material_override
			e_mat.emission_enabled = true
			e_mat.emission = Color(1.0, 0.35, 0.05)
			e_mat.emission_energy_multiplier = 2.0
			root.add_child(embers)
			var fire_light: OmniLight3D = _add_light(root, Vector3(0.0, 0.6, 0.0), Color(1.0, 0.55, 0.2), 1.6, 3.0)
			if vfx != null:
				# Живое пламя: языки огня (лист кадров), угольки, дым и мерцающий свет
				vfx.loop("fire_loop", root, Vector3(0.0, 0.3, 0.0))
				vfx.loop("ember_loop", root, Vector3(0.0, 0.4, 0.0))
				vfx.loop("smoke_loop", root, Vector3(0.0, 0.9, 0.0))
				vfx.flicker(fire_light, 1.6)
			else:
				root.add_child(_make_flames())
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
func add_rock(cell: Vector2i, model_name: String = "") -> void:
	if _rock_nodes.has(cell):
		return   # преграда уже стоит (например, вернулась после отмены хода)
	var options: Array = ARENA_ROCKS.get(_arena, [ROCK_BOULDER])
	var scene: PackedScene = options[posmod(cell.x * 7 + cell.y * 13, options.size())]
	if model_name != "":   # своя преграда (павший голем — куча шлака)
		var own: PackedScene = _ash_scene(model_name)
		if own != null:
			var p: Node3D = own.instantiate()
			p.position = grid_to_world(cell)
			add_child(p)
			_rock_nodes[cell] = p
			return
	if ASH_ROCKS.has(_arena):   # акт 2: своя преграда у каждой арены
		var names: Array = ASH_ROCKS[_arena]
		var ash: PackedScene = _ash_scene(names[posmod(cell.x * 7 + cell.y * 13, names.size())])
		scene = ash if ash != null else ROCK_BOULDER
	var prop: Node3D = scene.instantiate()
	prop.position = grid_to_world(cell)
	prop.rotation.y = posmod(cell.x * 3 + cell.y * 17, 4) * (PI / 2.0)
	add_child(prop)
	_rock_nodes[cell] = prop


# ---------- Сверка с логикой (отмена хода) ----------

# Привести поле к состоянию логики без анимаций: преграды, объекты, эффекты на клетках.
# Меняет только то, что отличается, — остальные модели не пересоздаются.
func resync(logic: BattleLogic) -> void:
	# Преграды: лишние убрать (появились после отменённого действия), недостающие поставить
	for c: Vector2i in _rock_nodes.keys():
		if not logic.rocks.has(c):
			_rock_nodes[c].queue_free()
			_rock_nodes.erase(c)
	for c: Vector2i in logic.rocks:
		if not _rock_nodes.has(c):
			add_rock(c, "rock_slag")   # посреди боя преграды появляются только от павшего голема
	# Объекты: бочки, деревья, лёд, мостки…
	var cells: Dictionary[Vector2i, bool] = {}
	for c: Vector2i in _object_kinds:
		cells[c] = true
	for c: Vector2i in logic.objects:
		cells[c] = true
	for c: Vector2i in cells:
		var want: int = logic.objects.get(c, BattleLogic.Obj.NONE)
		if _object_kinds.get(c, BattleLogic.Obj.NONE) == want and _object_nodes.has(c):
			continue
		if want == BattleLogic.Obj.NONE:
			_remove_object_node(c)
		else:
			add_object(c, want)
	# Эффекты на клетках: огонь, лужи, лёд, дым, яд…
	cells.clear()
	for c: Vector2i in _effect_kinds:
		cells[c] = true
	for c: Vector2i in logic.tiles:
		cells[c] = true
	for c: Vector2i in cells:
		var tile: int = logic.tiles.get(c, BattleLogic.Tile.NONE)
		if _effect_kinds.get(c, BattleLogic.Tile.NONE) != tile:
			set_tile_effect(c, tile)


# ---------- Вспомогательное ----------

# Шестиугольник подсветки: плоская шестигранная призма чуть меньше клетки.
# У CylinderMesh с 6 сегментами острый угол смотрит вдоль оси Z — как у наших сот.
func _get_highlight_mesh() -> CylinderMesh:
	if _highlight_mesh == null:
		_highlight_mesh = _hex_prism(HexMath.HEX_SIZE * 0.88, 0.01)
	return _highlight_mesh


# Шестигранная плита (общая для всех клеток поля)
# Меш шестиугольной плиты из tile_hex_*.glb (один на вид, общий для всех клеток). null — файла нет.
func _get_hex_tile_mesh(model_name: String) -> Mesh:
	if _hex_tile_meshes.has(model_name):
		return _hex_tile_meshes[model_name]
	var mesh: Mesh = null
	var path: String = DIR + model_name + ".glb"
	if ResourceLoader.exists(path):
		var scene: Node = (load(path) as PackedScene).instantiate()
		var found: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			mesh = (found[0] as MeshInstance3D).mesh
		scene.free()
	_hex_tile_meshes[model_name] = mesh
	return mesh


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
# Материал подсветки клетки: слабая заливка + яркий контур соты (с кешем по цвету)
func _get_highlight_material(color: Color, subtle: bool = false) -> ShaderMaterial:
	var key: String = str(color) + ("s" if subtle else "")
	if not _highlight_materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = HIGHLIGHT_SHADER
		mat.set_shader_parameter("color", color)
		mat.set_shader_parameter("apothem", HexMath.HEX_SIZE * 0.88 * 0.8660254)
		if subtle:
			mat.set_shader_parameter("fill_part", 0.08)
			mat.set_shader_parameter("edge_width", 0.045)
			mat.set_shader_parameter("edge_boost", 1.0)
		_highlight_materials[key] = mat
	return _highlight_materials[key]


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
	_refresh_bog_around(cell)
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
	_refresh_bog_around(cell)
	var burn_swap: bool = (old_kind == BattleLogic.Obj.LIVE_TREE and new_kind == BattleLogic.Obj.BURNING_TREE) \
			or (old_kind == BattleLogic.Obj.BURNING_TREE and new_kind == BattleLogic.Obj.TREE)
	if node != null and burn_swap:
		node.queue_free()   # дерево загорелось или прогорело: меняем модель на месте, без «ухода под землю»
		add_object(cell, new_kind)
		return
	if node != null:
		match old_kind:
			BattleLogic.Obj.TREE:
				await _fall_tree(node, dir)
				# Пыль и щепки по линии падения рисует VfxPlayer.tree_fall (сигнал effect_cells "tree")
				if vfx == null:
					burst(cell + dir, Color(0.4, 0.37, 0.33), roundi(14 * IMPACT_FX_SCALE), 2.5 * IMPACT_FX_SCALE, 0.0, IMPACT_FX_SCALE)   # щепки
			BattleLogic.Obj.BARREL:
				await _pop(node)
				# Сам огненный взрыв рисует VfxPlayer.explosion (сигнал effect_cells "explosion"),
				# здесь — то, что есть только у бочки: зелёный газ и щепки
				if vfx != null:
					vfx.burst("gas_blast", grid_to_world(cell) + Vector3(0.0, 0.5, 0.0))
					vfx.burst("splinters", grid_to_world(cell) + Vector3(0.0, 0.4, 0.0))
				else:
					burst(cell, COLOR_GAS_LIGHT, roundi(34 * IMPACT_FX_SCALE), 5.0 * IMPACT_FX_SCALE, 3.0, IMPACT_FX_SCALE)   # зелёная вспышка газа
					burst(cell, Color(1.0, 0.6, 0.15), roundi(20 * IMPACT_FX_SCALE), 3.5 * IMPACT_FX_SCALE, 3.0, IMPACT_FX_SCALE)
			BattleLogic.Obj.ICE_BLOCK:
				Sfx.play("ice", 0.07)
				if vfx != null:
					vfx.object_broken(grid_to_world(cell), "ice")
				else:
					burst(cell, Color(0.8, 0.95, 1.0), 16, 2.5, 1.0)          # осколки льда
				await _sink(node)
			_:
				if vfx != null:
					var broken: Dictionary = {BattleLogic.Obj.PLANKS: "planks", BattleLogic.Obj.REEDS: "reeds",
						BattleLogic.Obj.STAKES: "stakes", BattleLogic.Obj.BUSH: "reeds", BattleLogic.Obj.VINE: "reeds",
						BattleLogic.Obj.HIVE: "planks", BattleLogic.Obj.VALVE: "stakes"}
					if broken.has(old_kind):
						vfx.object_broken(grid_to_world(cell), broken[old_kind])
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
	_refresh_bog_around(from)
	_refresh_bog_around(to)
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
		_refresh_bog_around(cell)


# ---------- Трясина и лужи: соседние клетки сливаются в одну воду ----------
# Вода рисуется по каждой клетке общим шейдером в мировых координатах — на стыке шва не видно.
# Бортик (трясина) или край (лужа) — только с тех сторон, где соседняя клетка не такая же.

func _is_bog_water(cell: Vector2i) -> bool:
	return BOG_WATER_KINDS.has(_object_kinds.get(cell, BattleLogic.Obj.NONE))


func _refresh_bog_around(cell: Vector2i) -> void:
	_refresh_bog(cell)
	_refresh_lava_links(cell)
	for d: Vector2i in HexMath.DIRS:
		_refresh_bog(cell + d)
		_refresh_lava_links(cell + d)


# Соседние клетки лавы — одно озеро: между ними перемычки из тёмного края и жидкого огня,
# в углу, где сходятся три лавы, — заплатка. Свет и пузыри остаются у каждой клетки.
func _refresh_lava_links(cell: Vector2i) -> void:
	if _lava_links.has(cell):
		_lava_links[cell].queue_free()
		_lava_links.erase(cell)
	var lava: int = BattleLogic.Obj.LAVA
	if _object_kinds.get(cell, BattleLogic.Obj.NONE) != lava:
		return
	var root := Node3D.new()
	root.position = grid_to_world(cell)
	var apothem: float = CELL_STEP * 0.5
	var n: int = HexMath.DIRS.size()
	for i in n:
		var d: Vector2i = HexMath.DIRS[i]
		if _object_kinds.get(cell + d, BattleLogic.Obj.NONE) != lava:
			continue
		var v: Vector3 = HexMath.axial_to_world(d)
		var angle: float = atan2(v.x, v.z)
		for layer: Array in [[0.97, 0.1, Color(0.18, 0.12, 0.08), Color(0.9, 0.4, 0.05), 0.4, 0.05],
				[0.8, 0.14, Color(1.0, 0.7, 0.15), Color(1.0, 0.6, 0.1), 2.2, 0.07]]:
			var strip: MeshInstance3D = _glow_slab(Vector3(HexMath.HEX_SIZE * layer[0], layer[1], apothem + 0.02),
					layer[2], layer[3], layer[4], layer[5])
			strip.position += v.normalized() * apothem * 0.5
			strip.rotation.y = angle
			root.add_child(strip)
		var d2: Vector2i = HexMath.DIRS[(i + 1) % n]
		if _object_kinds.get(cell + d2, BattleLogic.Obj.NONE) == lava:
			var corner: MeshInstance3D = _glow_hex(0.6, 0.14, Color(1.0, 0.7, 0.15), Color(1.0, 0.6, 0.1), 2.2, 0.07)
			corner.position += (v + HexMath.axial_to_world(d2)) / 3.0
			root.add_child(corner)
	if root.get_child_count() == 0:
		root.free()
		return
	add_child(root)
	_lava_links[cell] = root


# Вода и бортики трясины на одной клетке (пересобираются целиком — их мало)
func _refresh_bog(cell: Vector2i) -> void:
	if _bog_water.has(cell):
		_bog_water[cell].queue_free()
		_bog_water.erase(cell)
	if not _is_bog_water(cell):
		return
	var root := Node3D.new()
	root.position = grid_to_world(cell)
	add_child(root)
	_bog_water[cell] = root
	var water := MeshInstance3D.new()
	water.mesh = _hex_prism(HexMath.HEX_SIZE, 0.02)   # полный размер соты: соседние воды смыкаются
	water.position.y = -0.02
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.material_override = _get_bog_water_material()
	root.add_child(water)
	var apothem: float = CELL_STEP * 0.5
	for i in HexMath.DIRS.size():
		var d: Vector2i = HexMath.DIRS[i]
		if _is_bog_water(cell + d):
			continue
		var v: Vector3 = HexMath.axial_to_world(d).normalized()
		var hash_value: int = posmod(cell.x * 13 + cell.y * 7 + i * 5, 97)
		var rim: Node3D = BOG_RIMS[hash_value % BOG_RIMS.size()].instantiate()
		rim.position = v * apothem
		rim.rotation.y = atan2(v.x, v.z)   # сторона суши модели (+Z) — к соседней плите
		root.add_child(rim)


func _get_bog_water_material() -> ShaderMaterial:
	if _bog_water_mat == null:
		_bog_water_mat = ShaderMaterial.new()
		_bog_water_mat.shader = WATER_SHADER
		_bog_water_mat.set_shader_parameter("deep_color", Color(0.025, 0.04, 0.03))
		_bog_water_mat.set_shader_parameter("shallow_color", Color(0.06, 0.08, 0.05))
		_bog_water_mat.set_shader_parameter("ripple_speed", 0.04)      # вязкая — рябь медленная
		_bog_water_mat.set_shader_parameter("ripple_strength", 0.07)
		_bog_water_mat.set_shader_parameter("roughness_value", 0.16)
	return _bog_water_mat


func _get_puddle_material() -> ShaderMaterial:
	if _puddle_mat == null:
		_puddle_mat = ShaderMaterial.new()
		_puddle_mat.shader = WATER_SHADER
		_puddle_mat.set_shader_parameter("deep_color", Color(0.02, 0.06, 0.1))
		_puddle_mat.set_shader_parameter("shallow_color", Color(0.06, 0.15, 0.22))
		_puddle_mat.set_shader_parameter("glow_color", Color(0.1, 0.35, 0.55))
		_puddle_mat.set_shader_parameter("glow_energy", 0.18)
		_puddle_mat.set_shader_parameter("ripple_scale", 1.8)
		_puddle_mat.set_shader_parameter("roughness_value", 0.08)
	return _puddle_mat


func _get_swamp_material() -> StandardMaterial3D:
	if _swamp_mat == null:
		_swamp_mat = StandardMaterial3D.new()
		_swamp_mat.albedo_color = Color(0.17, 0.22, 0.12)
		_swamp_mat.roughness = 0.2
		_swamp_mat.emission_enabled = true
		_swamp_mat.emission = Color(0.2, 0.32, 0.1)
		_swamp_mat.emission_energy_multiplier = 0.2
		if _biome() == "ash":   # на Тракте «топь» — сыпучий пепел: матовый, светлый, без отсвета
			_swamp_mat.albedo_color = COLOR_ASH_SAND
			_swamp_mat.roughness = 1.0
			_swamp_mat.emission_enabled = false
	return _swamp_mat


# Вид места вокруг поля (BattleLogic.arena_biome): "bog", "forest", "ash" или "deep"
func _biome() -> String:
	return BattleLogic.arena_biome(_arena)


# Модель акта 2 по имени (assets/models/topi/<имя>.glb); null — если её ещё нет
func _ash_scene(model_name: String) -> PackedScene:
	if _ash_scenes.has(model_name):
		return _ash_scenes[model_name]
	var path: String = DIR + model_name + ".glb"
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_ash_scenes[model_name] = scene
	return scene


# Россыпь вокруг арены акта 2: по виду места (Тракт, пещера, лаборатория, грибная пещера)
func _ash_scatter() -> Array:
	var key: String = "fungus" if _arena == "fungus" else ("lab" if LAB_ARENAS.has(_arena) else _biome())
	var result: Array = []
	for entry: Array in ASH_SCATTER.get(key, ASH_SCATTER["ash"]):
		var name: String = entry[0]
		var scene: PackedScene = D_EMBERS if name == "decor_embers" else _ash_scene(name)
		if scene != null:
			result.append([scene, entry[1]])
	return result


func _refresh_puddles_around(cell: Vector2i) -> void:
	_refresh_puddle_links(cell)
	for d: Vector2i in HexMath.DIRS:
		_refresh_puddle_links(cell + d)


# Перемычки между лужами: полоса до общей стороны с каждой соседней лужей и
# заплатка в углу, где сходятся три лужи. Сама лужа чуть меньше плиты — край плиты виден.
func _refresh_puddle_links(cell: Vector2i) -> void:
	if _puddle_links.has(cell):
		_puddle_links[cell].queue_free()
		_puddle_links.erase(cell)
	var kind: int = _effect_kinds.get(cell, BattleLogic.Tile.NONE)
	if not POOL_TILES.has(kind):
		return
	var mat: Material = _get_puddle_material() if kind == BattleLogic.Tile.WATER else _get_swamp_material()
	var root := Node3D.new()
	root.position = grid_to_world(cell)
	var width: float = HexMath.HEX_SIZE * PUDDLE_PART
	var apothem: float = CELL_STEP * 0.5
	var n: int = HexMath.DIRS.size()
	for i in n:
		var d: Vector2i = HexMath.DIRS[i]
		if _effect_kinds.get(cell + d, BattleLogic.Tile.NONE) != kind:
			continue
		var v: Vector3 = HexMath.axial_to_world(d)
		var strip := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(width, apothem + 0.02)
		strip.mesh = plane
		strip.position = v.normalized() * apothem * 0.5 + Vector3(0.0, PUDDLE_Y, 0.0)
		strip.rotation.y = atan2(v.x, v.z)
		strip.material_override = mat
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(strip)
		var d2: Vector2i = HexMath.DIRS[(i + 1) % n]   # следующая сторона — угол между ними
		if _effect_kinds.get(cell + d2, BattleLogic.Tile.NONE) == kind:
			var corner := MeshInstance3D.new()
			corner.mesh = _hex_prism(HexMath.HEX_SIZE * PUDDLE_PART * 0.75, 0.01)
			corner.position = (v + HexMath.axial_to_world(d2)) / 3.0 + Vector3(0.0, PUDDLE_Y - 0.005, 0.0)
			corner.material_override = mat
			corner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(corner)
	if root.get_child_count() == 0:
		root.free()
		return
	add_child(root)
	_puddle_links[cell] = root


# Модель объекта. Поворот «случайный», но одинаковый для клетки — чтобы объекты не выглядели копиями.
func _make_object(kind: int, cell: Vector2i) -> Node3D:
	var hash_value: int = posmod(cell.x * 37 + cell.y * 91, 360)
	var root: Node3D = null
	# Акт 2: та же механика, другой вид (масло, жаровня, сфера, гриб, гейзер, обугленный ствол, стена)
	var skin_name: String = (ASH_SKINS.get(_arena, {}) as Dictionary).get(kind, "")
	if skin_name == "obj_tree_charred":
		skin_name += "_a" if hash_value % 2 == 0 else "_b"
	var skin: PackedScene = _ash_scene(skin_name) if skin_name != "" else null
	if skin != null:
		root = skin.instantiate()
		root.rotation.y = deg_to_rad(float(hash_value))
		if skin_name == "obj_brazier" or skin_name == "obj_sphere_fire" or skin_name == "obj_oil_barrel":
			_add_light(root, Vector3(0.0, 0.8, 0.0), COLOR_EMBER_LIGHT, 0.8 if skin_name != "obj_oil_barrel" else 0.0, 2.6)
		elif skin_name == "obj_sphere_water":
			_add_light(root, Vector3(0.0, 0.9, 0.0), Color(0.5, 0.75, 1.0), 0.7, 2.4)
		elif skin_name == "obj_puffball":
			_add_light(root, Vector3(0.0, 0.5, 0.0), COLOR_GAS_LIGHT, 0.6, 2.2)
		return root
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
		BattleLogic.Obj.CART:
			var cart: PackedScene = _ash_scene("rock_cart")
			root = (cart if cart != null else ROCK_BOULDER).instantiate()
			root.rotation.y = (hash_value % 2) * PI
		BattleLogic.Obj.BASIN:
			var basin: PackedScene = _ash_scene("obj_basin")
			root = (basin if basin != null else OBJ_BARREL).instantiate()
			_add_light(root, Vector3(0.0, 0.6, 0.0), Color(0.5, 0.75, 1.0), 0.5, 2.0)
		BattleLogic.Obj.SPHERE_STORM:
			# Грозовой постамент — та же модель, что Спящая сфера, в позе сна: ловушку от него не отличить
			var decoy: PackedScene = SLEEPING_SPHERE if ResourceLoader.exists(SLEEPING_SPHERE_PATH) else null
			if decoy != null:
				root = decoy.instantiate()
				root.rotation.y = deg_to_rad(float(hash_value % 360))
				_play_sleep(root, hash_value)
			else:
				var orb: PackedScene = _ash_scene("obj_sphere_storm")
				root = (orb if orb != null else OBJ_BARREL).instantiate()
			_add_light(root, Vector3(0.0, 0.9, 0.0), Color(1.0, 0.92, 0.5), 0.8, 2.4)
		BattleLogic.Obj.STONE_WALL:
			var stone: PackedScene = _ash_scene("rock_basalt")   # камни Каменника
			root = (stone if stone != null else ROCK_BOULDER).instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
			root.scale = Vector3.ONE * 0.85
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
		BattleLogic.Obj.LIVE_TREE:
			root = OBJ_LIVE_TREES[hash_value % 2].instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
		BattleLogic.Obj.BURNING_TREE:
			root = OBJ_LIVE_TREES[hash_value % 2].instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
			var crown_fire: CPUParticles3D = _make_flames()
			crown_fire.position.y = 1.3
			crown_fire.emission_box_extents = Vector3(0.45, 0.3, 0.45)
			crown_fire.amount = 26
			root.add_child(crown_fire)
			_add_light(root, Vector3(0.0, 1.5, 0.0), COLOR_BURN_LIGHT, 1.6, 4.0)
		BattleLogic.Obj.VINE:
			root = OBJ_VINE.instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
		BattleLogic.Obj.BUSH:
			root = OBJ_BUSH.instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
		BattleLogic.Obj.HIVE:
			root = OBJ_HIVE.instantiate()
			root.rotation.y = deg_to_rad(float(hash_value))
		BattleLogic.Obj.VALVE:
			root = OBJ_VALVE.instantiate()
			root.rotation.y = (hash_value % 6) * PI / 3.0
	return root


const SLEEPING_SPHERE_PATH: String = "res://assets/models/sleeping_sphere.glb"
var SLEEPING_SPHERE: PackedScene:
	get:
		return _ash_scene_abs(SLEEPING_SPHERE_PATH)


func _ash_scene_abs(path: String) -> PackedScene:
	if not _ash_scenes.has(path):
		_ash_scenes[path] = load(path) as PackedScene if ResourceLoader.exists(path) else null
	return _ash_scenes[path]


# Постамент-приманка «дышит» анимацией сна, как настоящая Спящая сфера
func _play_sleep(root: Node, seed_value: int) -> void:
	var players: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	var anim: AnimationPlayer = players[0]
	if not anim.has_animation("Sleep"):
		return
	anim.get_animation("Sleep").loop_mode = Animation.LOOP_LINEAR
	anim.play("Sleep")
	anim.seek(float(seed_value % 100) / 100.0 * anim.get_animation("Sleep").length, true)


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


# То же, что _glow_slab, но шестигранное — по форме соты. part — доля радиуса клетки.
func _glow_hex(part: float, thickness: float, color: Color, glow: Color, energy: float, y: float) -> MeshInstance3D:
	var m: MeshInstance3D = _glow_slab(Vector3.ONE, color, glow, energy, y)
	m.mesh = _hex_prism(HexMath.HEX_SIZE * part, thickness)
	return m


# Лава: тёмный остывший бортик и густая оранжево-жёлтая масса с тёплым светом (красного нет)
func _make_lava_node() -> Node3D:
	var root := Node3D.new()
	root.add_child(_glow_hex(0.97, 0.1, Color(0.18, 0.12, 0.08), Color(0.9, 0.4, 0.05), 0.4, 0.05))
	root.add_child(_glow_hex(0.80, 0.14, Color(1.0, 0.7, 0.15), Color(1.0, 0.6, 0.1), 2.2, 0.07))
	root.add_child(_glow_hex(0.40, 0.17, Color(1.0, 0.85, 0.3), Color(1.0, 0.8, 0.2), 2.6, 0.09))
	var light: OmniLight3D = _add_light(root, Vector3(0.0, 0.5, 0.0), Color(1.0, 0.6, 0.15), 0.8, 2.4)
	if vfx != null:
		vfx.loop("lava_loop", root, Vector3(0.0, 0.17, 0.0))      # лопающиеся пузыри
		vfx.loop("ember_loop", root, Vector3(0.0, 0.3, 0.0), 0.8) # искры
		vfx.flicker(light, 0.8)
	return root


# Корка: тёмно-серая плита с оранжевыми трещинами
func _make_crust_node(hash_value: int) -> Node3D:
	var root := Node3D.new()
	root.rotation.y = (hash_value % 6) * PI / 3.0   # шаг 60°, чтобы сота не съезжала
	root.add_child(_glow_hex(0.94, 0.12, Color(0.25, 0.25, 0.27), Color(0.2, 0.1, 0.03), 0.2, 0.06))
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
# Плоские стрелки на полу: arrows — список пар [откуда, куда]. Ветер, ленты конвейера.
func show_flow_arrows(layer: String, arrows: Array, color: Color, size: float = 0.36) -> void:
	clear_layer(layer)
	var holder := Node3D.new()
	add_child(holder)
	_layers[layer] = holder
	var y: float = LAYER_HEIGHT.get(layer, 0.11)
	var mat: StandardMaterial3D = _get_flat_material(color)
	for pair: Array in arrows:
		var a: Vector3 = grid_to_world(pair[0])
		var heading: Vector3 = grid_to_world(pair[1]) - a
		var arrow := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(size * 0.85, size, 0.02)
		arrow.mesh = prism
		arrow.material_override = mat
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.position = a + heading * 0.18 + Vector3(0, y, 0)
		arrow.rotation = Vector3(-PI / 2.0, atan2(-heading.x, -heading.z), 0.0)
		holder.add_child(arrow)


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
