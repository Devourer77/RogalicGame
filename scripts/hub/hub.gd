extends Node3D
## Хаб «Застава Колокола»: пол, точки-заглушки, два героя, камера, интерфейс и панели.
## Пол, точки, стены и герои строятся кодом при запуске: сцена hub.tscn почти пустая.
## Север — в сторону -Z (от камеры). Размер площадки 24 × 16 метров.

signal active_hero_changed(hero_id: String)

const FLOOR_SIZE: Vector2 = Vector2(24.0, 16.0)
const WALL_HEIGHT: float = 3.0
const START_POS: Vector3 = Vector3(0.0, 0.0, 2.5)   # герои встают чуть южнее колокола
const FIRE_POS: Vector3 = Vector3(0.0, 0.0, 4.5)
const SHRINE_POS: Vector3 = Vector3(8.0, 0.0, -5.4)   # северо-восточный угол, напротив Караульни
const PERSONAL_STAY_DISTANCE: float = 3.0   # неактивный герой остаётся у личной точки, если стоит ближе
const SHELF_SLOTS: int = 10

# Цвета заглушек (по палитре из мир.md; красного нет).
const COL_STONE: Color = Color(0.36, 0.38, 0.38)
const COL_WOOD: Color = Color(0.3, 0.2, 0.13)
const COL_BRASS: Color = Color(0.62, 0.48, 0.16)
const COL_MOSS: Color = Color(0.2, 0.28, 0.16)
const COL_STEEL: Color = Color(0.5, 0.52, 0.55)
const COL_MUSTARD: Color = Color(0.6, 0.45, 0.1)
const COL_WARM: Color = Color(1.0, 0.65, 0.25)
const COL_OFF: Color = Color(0.2, 0.18, 0.15)
const COL_GROUND: Color = Color(0.22, 0.2, 0.15)

# Текстуры хаба (assets/textures/hub/, рисует assets/textures/src/build_hub_textures.py).
# Заглушка основного цвета получает свою текстуру сама: [имя файла, сколько метров на один повтор].
# Остальные цвета (кафедра, чучело, камни Круга) пока остаются однотонными.
const TEX_DIR: String = "res://assets/textures/hub/"
const TEXTURE_BY_COLOR: Dictionary = {
	COL_GROUND: ["hub_ground", 6.0],
	COL_STONE: ["hub_stone", 1.6],
	COL_WOOD: ["hub_wood", 1.2],
	COL_MOSS: ["hub_turf", 2.0],
}
const PATH_WIDTH: float = 1.4   # ширина тропинок из досок гати
# Сколько метров на повтор текстуры у моделей (у заглушек — в TEXTURE_BY_COLOR)
const MODEL_TEXTURE_REPEAT: Dictionary = {"hub_stone": 1.6, "hub_wood": 1.2, "hub_turf": 2.0, "hub_masonry": 2.0,
		"hub_planks": 1.4, "hub_ground": 3.0}

# Модели хаба (assets/models/hub/, собирает assets/models/src/build_hub.py)
const BELL_MODEL: PackedScene = preload("res://assets/models/hub/bell.glb")
const CAMPFIRE_MODEL: PackedScene = preload("res://assets/models/hub/campfire.glb")
const GATE_MODEL: PackedScene = preload("res://assets/models/hub/gate.glb")
const BARRACKS_MODEL: PackedScene = preload("res://assets/models/hub/barracks.glb")
const MAGE_CIRCLE_MODEL: PackedScene = preload("res://assets/models/hub/mage_circle.glb")
const ARMORY_MODEL: PackedScene = preload("res://assets/models/hub/armory.glb")
const NOTICE_BOARD_MODEL: PackedScene = preload("res://assets/models/hub/notice_board.glb")
const TROPHY_SHELF_MODEL: PackedScene = preload("res://assets/models/hub/trophy_shelf.glb")
const SHRINE_MODEL: PackedScene = preload("res://assets/models/hub/shrine.glb")
const LANTERN_POST_MODEL: PackedScene = preload("res://assets/models/hub/lantern_post.glb")
const PALISADE_INTACT_MODEL: PackedScene = preload("res://assets/models/hub/palisade_intact.glb")
const PALISADE_DAMAGED_MODEL: PackedScene = preload("res://assets/models/hub/palisade_damaged.glb")
const PALISADE_FALLEN_MODEL: PackedScene = preload("res://assets/models/hub/palisade_fallen.glb")
const PALISADE_CORNER_MODEL: PackedScene = preload("res://assets/models/hub/palisade_corner.glb")
const CHARMS_MODEL: PackedScene = preload("res://assets/models/hub/charms.glb")

# Точки взаимодействия. pos — центр зоны на земле, radius — размер зоны (у больших построек больше
# 1,8 м: герой не может встать вплотную), look — куда смотрит камера, hero_only — кто может открыть.
const POINTS: Array[Dictionary] = [
	{"id": "bell", "title": "Колокол Стражи", "pos": Vector3(0.0, 0.0, -0.5), "radius": 3.2, "look": Vector3(0.0, 1.4, -0.5)},
	{"id": "campfire", "title": "Костёр", "pos": Vector3(0.0, 0.0, 4.5), "radius": 2.6, "look": Vector3(0.0, 0.6, 4.5)},
	{"id": "gate", "title": "Ворота", "pos": Vector3(0.0, 0.0, -7.2), "radius": 2.6, "look": Vector3(0.0, 1.4, -7.2)},
	{"id": "barracks", "title": "Караульня", "pos": Vector3(-8.5, 0.0, -2.6), "radius": 1.9, "look": Vector3(-8.5, 1.0, -4.2)},
	{"id": "mage_circle", "title": "Круг ордена", "pos": Vector3(-8.5, 0.0, 1.2), "radius": 2.6, "look": Vector3(-8.5, 1.0, 1.2), "hero_only": "mage",
			"deny": "Эти записи прочтёт только ученик ордена", "deny_hint": "Только Маг · Tab — сменить героя"},
	{"id": "armory", "title": "Оружейная", "pos": Vector3(8.5, 0.0, 0.0), "radius": 2.8, "look": Vector3(8.5, 1.0, 0.0), "hero_only": "knight",
			"deny": "Латы Стражи. Здесь нужен рыцарь", "deny_hint": "Только Рыцарь · Tab — сменить героя"},
	{"id": "board", "title": "Доска дозора", "pos": Vector3(-8.5, 0.0, 5.2), "radius": 2.4, "look": Vector3(-8.5, 1.0, 5.2)},
	{"id": "shelf", "title": "Полка трофеев", "pos": Vector3(8.5, 0.0, 5.0), "radius": 2.4, "look": Vector3(8.5, 1.0, 5.0)},
	{"id": "shrine", "title": "Святилище духов", "pos": SHRINE_POS, "radius": 2.2, "look": SHRINE_POS + Vector3(0.0, 1.2, -0.6)},
]

# Реплика героя при открытии общих точек (у личных своя запись, у остальных — молчание)
const HERO_LINES: Dictionary = {
	"bell": {"mage": "Маг касается колокола посохом — латунь отзывается низко.", "knight": "Рыцарь бьёт в колокол рукоятью меча. Гул уходит в туман."},
	"campfire": {"mage": "Здесь можно посидеть. Недолго.", "knight": "Огонь ещё держится. Хороший знак."},
	"gate": {"mage": "Дорога та же. Мы — уже нет.", "knight": "Дорога та же. Идём."},
	"barracks": {"mage": "Смена так и не пришла. Зато остались записи.", "knight": "Дозорные ушли, а сундуки стоят."},
	"shelf": {"mage": "Всё, что удалось вынести из топей. Немного.", "knight": "Немного. Но своё."},
}

@onready var camera: HubCamera = $Camera3D

var heroes: Array[HubHero] = []
var active: HubHero
var hud: HubHud

var _near: Dictionary = {}           # ближайшая точка с зоной вокруг активного героя
var _panel_open: bool = false
var _open_point: Dictionary = {}
var _last_bell: int = -1

var _candle_mats: Array[StandardMaterial3D] = []
var _candle_flames: Array[MeshInstance3D] = []     # пламя свечей на балке колокола
var _bell_pivot: Node3D
var _door_hinge: Node3D
var _door_tween: Tween
var _card_stacks: Array[Node3D] = []           # стопки карт на столе Караульни: мало / средне / много
var _lantern_mats: Array[StandardMaterial3D] = []
var _lantern_glass: Array[Node3D] = []             # стекло фонарей — у горящих кружат мотыльки
var _moths: Array[GPUParticles3D] = []
var _shrine_motes: Array[GPUParticles3D] = []     # огоньки над шарами покорённых духов
var _vfx: VfxPlayer                                 # частицы и мерцание (scripts/vfx_player.gd)
var _banner: Node3D
var _shelf_slots: Array[Node3D] = []        # места на полке: в каждом оберег, ткань и меловой контур
var _shelf_lights: Array[OmniLight3D] = []  # тёплый отсвет открытого оберега
var _shrine_orbs: Array[MeshInstance3D] = []          # шар на каждом камне Святилища (по Run.ALL_SPIRIT_IDS)
var _shrine_mats: Array[StandardMaterial3D] = []
var _shrine_light: OmniLight3D


func _ready() -> void:
	Meta.prune_stock(Run.HEROES)   # старые карты и карты духов не должны лежать в Запасе Караульни
	_setup_input()
	_build_floor()
	_build_paths()
	_build_walls()
	_build_palisade()
	_build_points()
	_build_lanterns()
	_build_atmosphere()
	_spawn_heroes()
	camera.flight_finished.connect(_on_flight_finished)
	hud = HubHud.new()
	add_child(hud)
	hud.menu_requested.connect(Run.goto.bind(Run.MAIN_MENU_SCENE))
	_set_active(heroes[0], false)
	Meta.changed.connect(refresh_world)
	refresh_world()
	_wake_up()


# Атмосфера заставы (эффекты, этап 6): живой костёр с искрами и дымом, мерцание свечей
# колокола, мотыльки у горящих фонарей, туман за частоколом, огоньки над шарами Святилища
func _build_atmosphere() -> void:
	_vfx = VfxPlayer.new()
	_vfx.name = "Vfx"
	add_child(_vfx)
	# Костёр: крупное пламя, угли вьются вверх, дым уходит в сумерки, свет дышит
	_vfx.loop("fire_loop", self, FIRE_POS + Vector3(0.0, 0.45, 0.0), 1.7)
	_vfx.loop("ember_loop", self, FIRE_POS + Vector3(0.0, 0.6, 0.0), 1.6)
	_vfx.loop("smoke_loop", self, FIRE_POS + Vector3(0.0, 1.6, 0.0), 1.8)
	var fire_light: OmniLight3D = get_node_or_null("FireLight") as OmniLight3D
	if fire_light != null:
		_vfx.flicker(fire_light, fire_light.light_energy)
	# Свечи на балке колокола чуть колышутся
	for flame in _candle_flames:
		var sway: Tween = flame.create_tween().set_loops()
		var t: float = randf_range(0.35, 0.6)
		sway.tween_property(flame, "rotation:z", 0.12, t).set_trans(Tween.TRANS_SINE)
		sway.tween_property(flame, "rotation:z", -0.1, t * 1.1).set_trans(Tween.TRANS_SINE)
	# Мотыльки у фонарей (горят не все — включаются в refresh_world)
	for glass in _lantern_glass:
		var moths: GPUParticles3D = _vfx.loop("moth_loop", self, glass.global_position)
		moths.emitting = false
		_moths.append(moths)
	# Туман за частоколом: полосы вокруг площадки, внутри чисто
	var hx: float = FLOOR_SIZE.x * 0.5
	var hz: float = FLOOR_SIZE.y * 0.5
	for side: Array in [[Vector3(0.0, 0.3, -hz - 4.0), Vector3(hx + 6.0, 0.3, 2.5)],
			[Vector3(0.0, 0.3, hz + 4.0), Vector3(hx + 6.0, 0.3, 2.5)],
			[Vector3(-hx - 4.0, 0.3, 0.0), Vector3(2.5, 0.3, hz + 3.0)],
			[Vector3(hx + 4.0, 0.3, 0.0), Vector3(2.5, 0.3, hz + 3.0)]]:
		_vfx.loop("mist_loop", self, side[0], 1.0, Color(0, 0, 0, 0), side[1])
	# Шпиль-задник (прикреплён к камере): у вершины кружат бирюзовые искры Раскола
	var spire: Node3D = camera.get_node_or_null("SpireBackdrop") as Node3D
	if spire != null:
		var sparks: GPUParticles3D = _vfx.loop("wisp_loop", spire, Vector3(0.0, 10.0, 0.0), 8.0,
			VfxPlayer.C_RIFT, Vector3(1.2, 5.0, 1.2))
		sparks.local_coords = true   # Шпиль едет вместе с камерой — искры тоже
	# Святилище: над шаром покорённого духа поднимаются огоньки его цвета
	for orb in _shrine_orbs:
		var motes: GPUParticles3D = _vfx.loop("rise", self, orb.global_position, 0.35)
		motes.emitting = false
		_shrine_motes.append(motes)


# Пробуждение: герои проявляются из темноты; если пришли из забега — «Итог пути»
func _wake_up() -> void:
	hud.fade_in()
	if not Meta.last_result.is_empty():
		await get_tree().create_timer(1.3).timeout
		var summary: HubPanel = RunSummary.open(hud.panel_root, active.hero_id)
		_panel_open = true
		active.can_move = false
		summary.closed.connect(func() -> void:
			Meta.last_result = {}
			_panel_open = false
			active.can_move = true)


# --- Клавиши ---------------------------------------------------------------------------
# Действия (названия клавиш для кода) заводим здесь, чтобы не трогать project.godot.
# Позже их можно перенести в «Проект → Настройки проекта → Список действий».

func _setup_input() -> void:
	_add_action("hub_up", [KEY_W, KEY_UP])
	_add_action("hub_down", [KEY_S, KEY_DOWN])
	_add_action("hub_left", [KEY_A, KEY_LEFT])
	_add_action("hub_right", [KEY_D, KEY_RIGHT])
	_add_action("hub_turn_left", [KEY_Q])
	_add_action("hub_turn_right", [KEY_R])
	_add_action("hub_switch", [KEY_TAB])
	_add_action("hub_use", [KEY_E])


func _add_action(action_name: String, keys: Array[Key]) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action_name, event)


func _unhandled_input(event: InputEvent) -> void:
	if _panel_open:
		return
	if event.is_action_pressed("hub_switch"):
		get_viewport().set_input_as_handled()
		switch_hero()
	elif event.is_action_pressed("hub_use"):
		get_viewport().set_input_as_handled()
		_use()


# --- Герои и Tab -----------------------------------------------------------------------

func _spawn_heroes() -> void:
	var ids: Array[String] = ["mage", "knight"]
	for i in ids.size():
		var h := HubHero.new()
		h.name = "Hero_" + ids[i]
		h.hero_id = ids[i]
		var data: HeroData = _hero_data(ids[i])
		if data != null:
			h.model_scene = data.model   # та же модель, что в бою; нет модели — капсула
		h.position = START_POS + Vector3(-0.8 + 1.6 * float(i), 0.0, 0.0)
		h.camera = camera
		add_child(h)
		heroes.append(h)
	camera.target = heroes[0]
	camera.snap_to_target()


# Путь к месту у костра: сперва в обход скамей, потом само место. Seat3 и Seat4 пустуют:
# там сядут будущие герои (шаман, некромант).
func _seat_path(hero_id: String) -> Array[Vector3]:
	var side: float = -1.0 if hero_id == "mage" else 1.0   # Seat1 — запад, Seat2 — восток
	var path: Array[Vector3] = [Vector3(side * 3.0, 0.0, 3.0), Vector3(side * 2.55, 0.0, 4.5)]
	return path


# Середина скамьи героя у костра: Seat1 — запад (маг), Seat2 — восток (рыцарь)
func _seat_spot(hero_id: String) -> Vector3:
	var side: float = -1.0 if hero_id == "mage" else 1.0
	return FIRE_POS + Vector3(side * 1.8, 0.0, 0.0)


# Tab: следующий герой. Камера перелетает за 0,4 с; быстрые нажатия просто отменяют прошлый перелёт.
func switch_hero() -> void:
	Sfx.play("ui_click", 0.05)
	var next: HubHero = heroes[(heroes.find(active) + 1) % heroes.size()]
	_set_active(next, true)


func _set_active(hero: HubHero, fly: bool) -> void:
	for h in heroes:
		if h != hero:
			_send_to_rest(h)
	active = hero
	hero.set_active(true)
	hero.can_move = not fly
	if fly:
		camera.fly_to(hero)   # управление вернётся, когда камера долетит (_on_flight_finished)
	else:
		camera.target = hero
	var data: HeroData = _hero_data(hero.hero_id)
	if data != null:
		hud.set_hero(data)
	active_hero_changed.emit(hero.hero_id)


func _on_flight_finished() -> void:
	if active != null and not _panel_open:
		active.can_move = true


# Неактивный герой: остаётся у своей личной точки (ближе 3 м) или идёт к костру
func _send_to_rest(h: HubHero) -> void:
	h.set_active(false)
	for p in POINTS:
		if p.get("hero_only", "") == h.hero_id:
			var d: Vector3 = h.global_position - (p["pos"] as Vector3)
			d.y = 0.0
			if d.length() < PERSONAL_STAY_DISTANCE:
				return
	h.go_to(_seat_path(h.hero_id), FIRE_POS, _seat_spot(h.hero_id))


func _hero_data(hero_id: String) -> HeroData:
	for d in Run.HEROES:
		if d.id == hero_id:
			return d
	return null


# --- Точки: подсказка и E --------------------------------------------------------------

func _process(_delta: float) -> void:
	if hud == null or active == null:
		return
	if _panel_open:
		hud.hide_prompt()
		return
	_near = _nearest_point()
	if _near.is_empty():
		hud.hide_prompt()
		return
	var label_pos: Vector3 = (_near["look"] as Vector3) + Vector3(0.0, 1.4, 0.0)
	if camera.is_position_behind(label_pos):
		hud.hide_prompt()
		return
	var wrong_hero: bool = _near.get("hero_only", "") != "" and _near["hero_only"] != active.hero_id
	var text: String = "[E] " + _near["title"]
	if wrong_hero:
		text = _near["deny_hint"]
	hud.show_prompt(text, camera.unproject_position(label_pos), wrong_hero)


# Ближайшая точка, в зоне которой стоит активный герой
func _nearest_point() -> Dictionary:
	var best: Dictionary = {}
	var best_ratio: float = 1.0
	for p in POINTS:
		var d: Vector3 = active.global_position - (p["pos"] as Vector3)
		d.y = 0.0
		var ratio: float = d.length() / float(p["radius"])
		if ratio <= best_ratio:
			best_ratio = ratio
			best = p
	return best


func _use() -> void:
	if _near.is_empty() or active == null or not active.can_move:
		return
	var only: String = _near.get("hero_only", "")
	if only != "" and only != active.hero_id:
		Sfx.play("card_cancel", 0.05)
		hud.say(_near["deny"])   # строка-отказ: панель не открывается
		return
	_open_point_panel(_near)


func _open_point_panel(point: Dictionary) -> void:
	_panel_open = true
	_open_point = point
	active.can_move = false
	active.face_toward(point["pos"])
	camera.focus_on(point["look"])
	var lines: Dictionary = HERO_LINES.get(point["id"], {})
	if lines.has(active.hero_id):
		hud.say(lines[active.hero_id])
	if point["id"] == "barracks":
		_swing_door(true)
	elif point["id"] == "bell":
		Sfx.play("bell", 0.03)
	elif point["id"] == "campfire":
		Sfx.play("fire", 0.06)
	elif point["id"] == "shrine":
		Sfx.play("magic", 0.05)
	else:
		Sfx.play("ui_click", 0.05)
	var panel: HubPanel = _make_panel(point["id"])
	panel.closed.connect(_on_panel_closed)


func _make_panel(id: String) -> HubPanel:
	var parent: Node = hud.panel_root
	var hero: String = active.hero_id
	match id:
		"bell":
			return BellPanel.open(parent, hero)
		"campfire":
			return ChroniclePanel.open(parent, hero)
		"gate":
			return GatePanel.open(parent, hero)
		"barracks":
			return BarracksPanel.open(parent, hero)
		"mage_circle":
			return UpgradePanel.open(parent, MetaUpgradeData.Desk.MAGE, hero)
		"armory":
			return UpgradePanel.open(parent, MetaUpgradeData.Desk.KNIGHT, hero)
		"board":
			return UpgradePanel.open(parent, MetaUpgradeData.Desk.PARTY, hero)
		"shrine":
			return ShrinePanel.open(parent, hero)
		_:
			return CharmPanel.open(parent, hero)


func _on_panel_closed() -> void:
	_panel_open = false
	if _open_point.get("id", "") == "barracks":
		_swing_door(false)
	_open_point = {}
	camera.release_focus()
	active.can_move = true


# Дверь Караульни открывается внутрь на 80° (0,3 с)
func _swing_door(open: bool) -> void:
	if _door_hinge == null:
		return
	Sfx.play("door", 0.05)
	if _door_tween != null and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_property(_door_hinge, "rotation:y", deg_to_rad(80.0) if open else 0.0, 0.3)


# --- Живой хаб -------------------------------------------------------------------------
# Зовётся при входе в хаб и после любого изменения в Meta: зажигает то, что открыто.

func refresh_world() -> void:
	# Свечи на балке колокола: открытые горят, выбранная ярче
	for i in _candle_mats.size():
		var m: StandardMaterial3D = _candle_mats[i]
		var lit: bool = Meta.is_bell_open(i)
		m.albedo_color = COL_WARM if lit else Color(0.5, 0.48, 0.42)
		m.emission_enabled = lit
		m.emission = COL_WARM
		m.emission_energy_multiplier = 6.0 if i == Meta.bell_chosen else 2.5
		if i < _candle_flames.size():
			_candle_flames[i].visible = lit   # у закрытого Звона свеча стоит холодной
			_candle_flames[i].scale = Vector3.ONE * (1.4 if i == Meta.bell_chosen else 1.0)
	if _last_bell >= 0 and _last_bell != Meta.bell_chosen:
		_swing_bell()
	_last_bell = Meta.bell_chosen

	# Фонари вдоль частокола: по одному за каждую купленную ступень
	var bought: int = mini(Meta.steps_bought(), _lantern_mats.size())
	for i in _lantern_mats.size():
		var lm: StandardMaterial3D = _lantern_mats[i]
		var on: bool = i < bought
		lm.albedo_color = COL_WARM if on else COL_OFF
		lm.emission_enabled = on
		lm.emission = COL_WARM
		lm.emission_energy_multiplier = 3.0
		if i < _moths.size():
			_moths[i].emitting = on   # мотыльки летят только на свет

	# Стопка карт на столе Караульни растёт с Запасом обоих героев (до 5 карт / до 15 / больше)
	var stock: int = 0
	for hero_id in Meta.card_stock:
		stock += (Meta.card_stock[hero_id] as Array).size()
	var stack: int = -1 if stock == 0 else (0 if stock <= 5 else (1 if stock <= 15 else 2))
	for i in _card_stacks.size():
		_card_stacks[i].visible = i == stack

	# Знамя над воротами — после первой победы над боссом
	if _banner != null:
		_banner.visible = Meta.first_boss_killed

	# Полка трофеев: открытый оберег стоит и светится, покупаемый — под тканью с биркой,
	# «только из пути» — меловой контур на доске
	for i in _shelf_slots.size():
		var slot: Node3D = _shelf_slots[i]
		var c: RelicData = Meta.CHARMS[i]
		var open: bool = Meta.is_charm_open(c.id)
		var charm: Node3D = slot.get_node_or_null(NodePath(c.id)) as Node3D
		if charm != null:
			charm.visible = open
		(slot.get_node("Cloth") as Node3D).visible = not open and c.buyable
		(slot.get_node("Chalk") as Node3D).visible = not open and not c.buyable
		_shelf_lights[i].visible = open

	# Святилище: шар покорённого духа светится его цветом, встреченного — тускло, неизвестного нет
	var any_tamed: bool = false
	for i in _shrine_orbs.size():
		var sp: SpiritData = Run.spirit_data(Run.ALL_SPIRIT_IDS[i])
		var om: StandardMaterial3D = _shrine_mats[i]
		var seen: bool = sp != null and Meta.is_spirit_seen(sp.id)
		var tamed: bool = sp != null and Meta.is_spirit_tamed(sp.id)
		_shrine_orbs[i].visible = seen
		if not seen:
			continue
		om.albedo_color = sp.color if tamed else sp.color.darkened(0.6)
		om.emission_enabled = tamed
		om.emission = sp.color
		om.emission_energy_multiplier = 2.5
		any_tamed = any_tamed or tamed
		if i < _shrine_motes.size():
			_shrine_motes[i].emitting = tamed
			_shrine_motes[i].process_material = _vfx.loop_material("rise", sp.color)
	if _shrine_light != null:
		_shrine_light.visible = any_tamed


func _swing_bell() -> void:
	if _bell_pivot == null:
		return
	Sfx.play("bell", 0.03)
	var tween: Tween = create_tween()
	for angle in [6.0, -6.0, 3.0, 0.0]:
		tween.tween_property(_bell_pivot, "rotation:z", deg_to_rad(angle), 0.18).set_trans(Tween.TRANS_SINE)


# --- Пол и стены -----------------------------------------------------------------------

func _build_floor() -> void:
	# Земля внутри заставы.
	_add_block("Floor", Vector3(0.0, -0.2, 0.0), Vector3(FLOOR_SIZE.x, 0.2, FLOOR_SIZE.y), COL_GROUND)
	# Тёмная вода вокруг, до горизонта.
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(300.0, 300.0)
	water.mesh = plane
	var water_mat: StandardMaterial3D = _make_material(Color.WHITE, 0.0, "hub_water", 6.0)
	water_mat.roughness = 0.35   # стоячая вода чуть блестит в свете фонарей
	water_mat.normal_scale = 0.5
	# Вода рисуется в «прозрачном» проходе: тогда Шпиль-задник (render_priority выше) ляжет поверх неё.
	# Без этого вода закрывает Шпиль: он прикреплён к камере и по высоте оказывается ниже воды.
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.render_priority = 0
	water.material_override = water_mat
	water.position.y = -0.35
	add_child(water)


# Тропинки из досок гати: от костра через колокол к воротам и поперёк — к Кругу ордена и Оружейной.
# Доски лежат поверх земли (4 см), сквозь них можно ходить: столкновений нет.
func _build_paths() -> void:
	_add_path("PathFireBell", Vector3(0.0, 0.0, 2.5), 2.6, 0.0)       # костёр → колокол
	_add_path("PathBellGate", Vector3(0.0, 0.0, -5.0), 5.4, 0.0)      # колокол → ворота и за них
	_add_path("PathWest", Vector3(-3.55, 0.0, 2.2), 5.7, 90.0)         # к Кругу ордена
	_add_path("PathEast", Vector3(3.55, 0.0, 2.2), 5.7, 90.0)          # к Оружейной


# Полоса досок. length — длина вдоль тропы; angle — поворот вокруг вертикали (0 — с юга на север).
# Доски в текстуре идут вдоль X, поэтому у тропы с юга на север они лежат поперёк — как в настоящей гати.
func _add_path(path_name: String, pos: Vector3, length: float, angle: float) -> void:
	var body: StaticBody3D = _add_block(path_name, pos, Vector3(PATH_WIDTH, 0.04, length), COL_WOOD, 0.0, false)
	body.rotation.y = deg_to_rad(angle)
	_set_texture(body, "hub_planks", 1.4)


# Невидимые стены по краю площадки, чтобы герой не ушёл в воду.
func _build_walls() -> void:
	var half_x: float = FLOOR_SIZE.x * 0.5
	var half_z: float = FLOOR_SIZE.y * 0.5
	_add_wall("WallNorth", Vector3(0.0, 0.0, -half_z - 0.5), Vector3(FLOOR_SIZE.x + 2.0, WALL_HEIGHT, 1.0))
	_add_wall("WallSouth", Vector3(0.0, 0.0, half_z + 0.5), Vector3(FLOOR_SIZE.x + 2.0, WALL_HEIGHT, 1.0))
	_add_wall("WallWest", Vector3(-half_x - 0.5, 0.0, 0.0), Vector3(1.0, WALL_HEIGHT, FLOOR_SIZE.y))
	_add_wall("WallEast", Vector3(half_x + 0.5, 0.0, 0.0), Vector3(1.0, WALL_HEIGHT, FLOOR_SIZE.y))


func _add_wall(wall_name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)


# Фонари вдоль края площадки — по одному на каждую ступень улучшений (Meta.steps_total()):
# каждая купленная ступень зажигает следующий. Кронштейн фонаря смотрит к центру заставы.
func _build_lanterns() -> void:
	var lantern_count: int = Meta.steps_total()
	var half_x: float = FLOOR_SIZE.x * 0.5 - 0.3
	var half_z: float = FLOOR_SIZE.y * 0.5 - 0.3
	var perimeter: float = 2.0 * (half_x + half_z) * 2.0
	for i in lantern_count:
		var t: float = perimeter * float(i) / float(lantern_count)
		var pos: Vector3 = _perimeter_point(t, half_x, half_z)
		var to_center: Vector3 = -pos.normalized()
		# В модели фонарь висит в сторону −X; поворачиваем так, чтобы −X смотрел к центру
		var angle: float = atan2(to_center.z, -to_center.x)
		var model: Node3D = _place_model(LANTERN_POST_MODEL, "Lantern%d" % i, pos, angle)
		var glass: MeshInstance3D = model.get_node("Glass") as MeshInstance3D
		var mat := StandardMaterial3D.new()
		glass.material_override = mat
		_lantern_mats.append(mat)
		_lantern_glass.append(glass)


# Частокол по краю: секции по 2 м. С юга (у камеры) он повален — не закрывает заставу,
# на севере проход у ворот. Буквы: I — целая секция, D — сломанная, F — поваленная, пусто — нет секции.
const PALISADE_NORTH: Array[String] = ["I", "D", "I", "F", "I", "", "", "I", "F", "D", "I", "I"]
const PALISADE_SOUTH: Array[String] = ["F", "", "F", "", "", "F", "", "F", "", "", "F", ""]
const PALISADE_WEST: Array[String] = ["I", "I", "D", "I", "F", "I", "D", "I"]
const PALISADE_EAST: Array[String] = ["I", "D", "I", "I", "F", "I", "I", "D"]
const PALISADE_OFFSET: float = 0.15   # колья стоят чуть за краем площадки


func _build_palisade() -> void:
	var models: Dictionary = {"I": PALISADE_INTACT_MODEL, "D": PALISADE_DAMAGED_MODEL, "F": PALISADE_FALLEN_MODEL}
	var hx: float = FLOOR_SIZE.x * 0.5 + PALISADE_OFFSET
	var hz: float = FLOOR_SIZE.y * 0.5 + PALISADE_OFFSET
	# Секция в модели смотрит на юг (+Z); поворот — чтобы она смотрела внутрь заставы
	for i in PALISADE_NORTH.size():
		var x: float = -FLOOR_SIZE.x * 0.5 + 1.0 + 2.0 * float(i)
		_add_palisade(models, PALISADE_NORTH[i], Vector3(x, 0.0, -hz), 0.0, "N%d" % i)
		_add_palisade(models, PALISADE_SOUTH[i], Vector3(x, 0.0, hz), PI, "S%d" % i)
	for i in PALISADE_WEST.size():
		var z: float = -FLOOR_SIZE.y * 0.5 + 1.0 + 2.0 * float(i)
		_add_palisade(models, PALISADE_WEST[i], Vector3(-hx, 0.0, z), PI * 0.5, "W%d" % i)
		_add_palisade(models, PALISADE_EAST[i], Vector3(hx, 0.0, z), -PI * 0.5, "E%d" % i)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_place_model(PALISADE_CORNER_MODEL, "PalisadeCorner", Vector3(sx * hx, 0.0, sz * hz))


func _add_palisade(models: Dictionary, kind: String, pos: Vector3, angle: float, tag: String) -> void:
	if kind == "":
		return
	_place_model(models[kind], "Palisade" + tag, pos, angle)


# Точка на границе прямоугольника: t — путь вдоль края от юго-западного угла по часовой стрелке
func _perimeter_point(t: float, half_x: float, half_z: float) -> Vector3:
	var w: float = half_x * 2.0
	var h: float = half_z * 2.0
	t = fposmod(t, 2.0 * (w + h))
	if t < h:
		return Vector3(-half_x, 0.0, half_z - t)             # западный край: с юга на север
	t -= h
	if t < w:
		return Vector3(-half_x + t, 0.0, -half_z)            # северный край: с запада на восток
	t -= w
	if t < h:
		return Vector3(half_x, 0.0, -half_z + t)             # восточный край: с севера на юг
	t -= h
	return Vector3(half_x - t, 0.0, half_z)                  # южный край: с востока на запад


# --- Точки хаба (заглушки) -------------------------------------------------------------

func _build_points() -> void:
	_build_bell()
	_build_campfire()
	_build_gate()
	_build_barracks()
	_build_mage_circle()
	_build_armory()
	_build_notice_board()
	_build_trophy_shelf()
	_build_shrine()


# Колокол — центр. Модель assets/models/hub/bell.glb (собирает assets/models/src/build_hub.py).
# На балке шесть свечей по числу Звонов: у открытых горит пламя, у выбранного ярче.
func _build_bell() -> void:
	var c: Vector3 = Vector3(0.0, 0.0, -0.5)
	var model: Node3D = BELL_MODEL.instantiate()
	model.name = "Bell"
	model.position = c
	add_child(model)
	_texture_model(model)
	# Столкновения — невидимые, по тем же размерам, что у модели
	_add_collider("BellPlatformCol", c, Vector3(3.6, 0.3, 3.6), 1.8)
	_add_collider("BellPostLCol", c + Vector3(-0.9, 0.0, 0.0), Vector3(0.3, 3.0, 0.3))
	_add_collider("BellPostRCol", c + Vector3(0.9, 0.0, 0.0), Vector3(0.3, 3.0, 0.3))
	# Колокол качается вокруг своей точки опоры — она в модели на оси под балкой (2,9 м)
	_bell_pivot = model.get_node("Bell") as Node3D
	for i in 6:
		var flame: MeshInstance3D = model.get_node("Flame%d" % i) as MeshInstance3D
		var mat := StandardMaterial3D.new()   # своё пламя у каждой свечи: зажигаются по одной
		flame.material_override = mat
		_candle_mats.append(mat)
		_candle_flames.append(flame)
	_add_label("Колокол", c + Vector3(0.0, 4.3, 0.0))


# Меняет в модели материалы tex_<имя> на текстуры хаба (hub_<имя>.png), остальные оставляет как есть.
# Так у моделей и заглушек одна и та же земля, камень и дерево.
func _texture_model(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			if mat == null or not mat.resource_name.begins_with("tex_"):
				continue
			var tex: String = "hub_" + mat.resource_name.trim_prefix("tex_")
			var repeat: float = MODEL_TEXTURE_REPEAT.get(tex, 1.5)
			mi.set_surface_override_material(s, _make_material(Color.WHITE, 0.0, tex, repeat))


# Невидимое препятствие: pos — точка на земле под центром. radius > 0 — цилиндр вместо коробки.
func _add_collider(col_name: String, pos: Vector3, size: Vector3, radius: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = col_name
	body.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	var shape := CollisionShape3D.new()
	if radius > 0.0:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = size.y
		shape.shape = cylinder
	else:
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
	body.add_child(shape)
	add_child(body)


# Костёр — на юг от колокола, самый яркий свет хаба. Скамьи на x = ±1,8 — там садятся герои,
# пень и подстилка за огнём — места для будущих героев.
func _build_campfire() -> void:
	var c: Vector3 = FIRE_POS
	_place_model(CAMPFIRE_MODEL, "Campfire", c)
	_add_collider("FireRingCol", c, Vector3(1.7, 0.3, 1.7), 0.85)
	_add_collider("BenchWestCol", c + Vector3(-1.8, 0.0, 0.0), Vector3(0.5, 0.45, 1.6))
	_add_collider("BenchEastCol", c + Vector3(1.8, 0.0, 0.0), Vector3(0.5, 0.45, 1.6))
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 3.5
	light.omni_range = 11.0
	light.position = c + Vector3(0.0, 1.2, 0.0)
	add_child(light)
	_add_label("Костёр", c + Vector3(0.0, 2.0, 0.0))


# Ворота «Тропа к Шпилю» — на севере. Знамя Стражи (узел Banner) — после первой победы над боссом.
func _build_gate() -> void:
	var c: Vector3 = Vector3(0.0, 0.0, -7.2)
	var model: Node3D = _place_model(GATE_MODEL, "Gate", c)
	_add_collider("GatePostLCol", c + Vector3(-1.6, 0.0, 0.0), Vector3(0.4, 3.2, 0.4))
	_add_collider("GatePostRCol", c + Vector3(1.6, 0.0, 0.0), Vector3(0.4, 3.2, 0.4))
	_banner = model.get_node("Banner") as Node3D
	_banner.visible = false
	_add_label("Ворота", c + Vector3(0.0, 4.2, 0.0))


# Караульня — северо-западный угол. Дверь и окно смотрят на юг. Дверь (узел Door) вращается
# на своей петле; внутри — сундуки, стол и стопки карт (видны, когда дверь открыта).
func _build_barracks() -> void:
	var c: Vector3 = Vector3(-8.5, 0.0, -5.2)
	var model: Node3D = _place_model(BARRACKS_MODEL, "Barracks", c)
	_add_collider("BarracksCol", c, Vector3(4.0, 2.5, 3.0))
	_door_hinge = model.get_node("Door") as Node3D
	for stack_name in ["CardsSmall", "CardsMedium", "CardsLarge"]:
		_card_stacks.append(model.get_node(stack_name) as Node3D)
	var light := OmniLight3D.new()
	light.name = "BarracksLight"
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = c + Vector3(1.3, 1.1, 2.4)
	add_child(light)
	var inner := OmniLight3D.new()   # свеча на столе внутри: видна в дверной проём
	inner.name = "BarracksCandle"
	inner.light_color = Color(1.0, 0.72, 0.4)
	inner.light_energy = 0.8
	inner.omni_range = 2.5
	inner.position = c + Vector3(0.4, 1.2, -0.1)
	add_child(inner)
	_add_label("Караульня", c + Vector3(0.0, 3.8, 0.0))


# Круг ордена (Маг) — запад: пять камней с рунами вокруг кафедры, над ней парит кристалл.
func _build_mage_circle() -> void:
	# Чуть южнее середины западной стороны: так зона Круга не накрывает дверь Караульни
	var c: Vector3 = Vector3(-8.5, 0.0, 1.2)
	var model: Node3D = _place_model(MAGE_CIRCLE_MODEL, "MageCircle", c)
	_add_collider("LecternCol", c, Vector3(0.7, 1.1, 0.6))
	for i in 5:
		var angle: float = TAU * float(i) / 5.0
		_add_collider("Stone%dCol" % i, c + Vector3(cos(angle), 0.0, sin(angle)) * 2.0, Vector3(0.6, 1.7, 0.6), 0.3)
	# Кристалл медленно вращается и покачивается
	var crystal: Node3D = model.get_node("Crystal") as Node3D
	var spin: Tween = create_tween().set_loops()
	spin.tween_property(crystal, "rotation:y", TAU, 8.0).from(0.0)
	var bob: Tween = create_tween().set_loops()
	bob.tween_property(crystal, "position:y", crystal.position.y + 0.08, 1.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(crystal, "position:y", crystal.position.y, 1.6).set_trans(Tween.TRANS_SINE)
	var glow := OmniLight3D.new()
	glow.name = "CrystalLight"
	glow.light_color = Color(0.35, 0.4, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 3.5
	glow.position = c + Vector3(0.0, 1.7, 0.0)
	add_child(glow)
	_add_label("Круг ордена · Маг", c + Vector3(0.0, 2.6, 0.0))


# Оружейная (Рыцарь) — восток: доспех на стойке, стойка оружия, чучело, знамя, точило.
func _build_armory() -> void:
	var c: Vector3 = Vector3(8.5, 0.0, 0.0)
	_place_model(ARMORY_MODEL, "Armory", c)
	_add_collider("ArmorStandCol", c + Vector3(0.0, 0.0, -1.2), Vector3(0.7, 1.7, 0.7))
	_add_collider("WeaponRackCol", c + Vector3(1.8, 0.0, 0.8), Vector3(0.5, 1.4, 1.7))
	_add_collider("DummyCol", c + Vector3(-0.2, 0.0, 1.6), Vector3(0.5, 1.5, 0.5))
	_add_collider("BannerCol", c + Vector3(2.2, 0.0, -1.8), Vector3(0.2, 2.6, 0.2))
	_add_collider("GrindstoneCol", c + Vector3(-1.3, 0.0, 0.0), Vector3(0.7, 0.9, 0.6))
	_add_label("Оружейная · Рыцарь", c + Vector3(0.0, 2.6, 0.0))


# Доска дозора — юго-запад.
func _build_notice_board() -> void:
	var c: Vector3 = Vector3(-8.5, 0.0, 5.2)
	_place_model(NOTICE_BOARD_MODEL, "NoticeBoard", c)
	_add_collider("NoticeBoardCol", c, Vector3(2.5, 1.9, 0.3))
	_add_label("Доска дозора", c + Vector3(0.0, 2.8, 0.0))


# Полка трофеев (обереги) — юго-восток. Десять мест в два яруса по порядку Meta.CHARMS.
# В каждом месте — копия charms.glb, где оставлены только свой оберег (узел с его id), ткань (Cloth)
# и меловой контур (Chalk); какой из них виден, решает refresh_world.
func _build_trophy_shelf() -> void:
	var c: Vector3 = Vector3(8.5, 0.0, 5.0)
	_place_model(TROPHY_SHELF_MODEL, "TrophyShelf", c)
	_add_collider("TrophyShelfCol", c, Vector3(2.5, 1.8, 0.85))
	for i in mini(SHELF_SLOTS, Meta.CHARMS.size()):
		var col: int = i % 5
		var tier: int = i / 5
		# Полы ярусов в модели полки — на 0,53 и 1,23 м; оберег стоит ближе к краю полки
		var pos: Vector3 = c + Vector3(-0.95 + 0.475 * float(col), 0.53 + 0.7 * float(tier), 0.05)
		var slot: Node3D = _place_model(CHARMS_MODEL, "ShelfSlot%d" % i, pos)
		var keep: Array[String] = [Meta.CHARMS[i].id, "Cloth", "Chalk"]
		for child in slot.get_children():
			if not keep.has(String(child.name)):
				child.queue_free()
		_shelf_slots.append(slot)
		var glow := OmniLight3D.new()
		glow.name = "ShelfGlow%d" % i
		glow.light_color = Color(1.0, 0.8, 0.55)
		glow.light_energy = 0.5
		glow.omni_range = 0.7
		glow.position = pos + Vector3(0.0, 0.25, 0.15)
		add_child(glow)
		_shelf_lights.append(glow)
	_add_label("Полка трофеев", c + Vector3(0.0, 2.8, 0.0))


# Святилище духов — северо-восток. Камни полукругом с севера, по камню на духа (Run.ALL_SPIRIT_IDS).
# Шар на камне (узлы Orb0…3) появляется, когда дух встречен, и горит его цветом, когда покорён.
func _build_shrine() -> void:
	var c: Vector3 = SHRINE_POS
	var model: Node3D = _place_model(SHRINE_MODEL, "Shrine", c)
	_add_collider("ShrineAltarCol", c + Vector3(0.0, 0.0, -0.4), Vector3(0.95, 0.7, 0.6))
	var n: int = Run.ALL_SPIRIT_IDS.size()
	for i in n:
		var angle: float = PI + PI * (float(i) + 0.5) / float(n)
		_add_collider("ShrineStone%dCol" % i, c + Vector3(cos(angle), 0.0, sin(angle)) * 1.5, Vector3(0.5, 1.5, 0.5), 0.25)
		var orb: MeshInstance3D = model.get_node_or_null("Orb%d" % i) as MeshInstance3D
		if orb == null:
			continue   # духов больше, чем камней в модели: пересобрать build_shrine()
		var mat := StandardMaterial3D.new()
		orb.material_override = mat
		_shrine_orbs.append(orb)
		_shrine_mats.append(mat)
	_shrine_light = OmniLight3D.new()
	_shrine_light.name = "ShrineLight"
	_shrine_light.light_color = Color(0.6, 0.8, 0.95)
	_shrine_light.light_energy = 1.0
	_shrine_light.omni_range = 4.5
	_shrine_light.position = c + Vector3(0.0, 1.8, -0.4)
	_shrine_light.visible = false
	add_child(_shrine_light)
	_add_label("Святилище духов", c + Vector3(0.0, 2.8, 0.0))


# Ставит модель в точку pos и кладёт на неё текстуры хаба
func _place_model(scene: PackedScene, model_name: String, pos: Vector3, angle: float = 0.0) -> Node3D:
	var model: Node3D = scene.instantiate()
	model.name = model_name
	model.position = pos
	model.rotation.y = angle
	add_child(model)
	_texture_model(model)
	return model


# --- Помощники для заглушек ------------------------------------------------------------
# pos — точка на земле под центром предмета; предмет растёт вверх от неё.

func _add_block(block_name: String, pos: Vector3, size: Vector3, color: Color,
		glow: float = 0.0, collide: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = block_name
	body.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, glow)
	body.add_child(mesh_instance)
	if collide:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
	add_child(body)
	return body


func _add_cylinder(cyl_name: String, pos: Vector3, radius: float, height: float, color: Color,
		glow: float = 0.0, collide: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = cyl_name
	body.position = pos + Vector3(0.0, height * 0.5, 0.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, glow)
	body.add_child(mesh_instance)
	if collide:
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = height
		shape.shape = cylinder
		body.add_child(shape)
	add_child(body)
	return body


# Шар без столкновений (pos — нижняя точка шара)
func _add_sphere(sphere_name: String, pos: Vector3, radius: float, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = sphere_name
	body.position = pos + Vector3(0.0, radius, 0.0)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, 0.0)
	body.add_child(mesh_instance)
	add_child(body)
	return body


# Временная подпись над заглушкой, чтобы понимать, что есть что. В настоящем хабе её не будет.
func _add_label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.008
	label.font_size = 48
	label.outline_size = 8
	label.modulate = Color(0.9, 0.85, 0.7)
	add_child(label)


# Материал заглушки. Светящимся текстура не нужна. Если текстура не указана явно,
# она берётся по цвету из TEXTURE_BY_COLOR (камень, дерево, дёрн, земля).
func _make_material(color: Color, glow: float, tex: String = "", repeat: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
		return material
	if tex == "" and TEXTURE_BY_COLOR.has(color):
		tex = TEXTURE_BY_COLOR[color][0]
		repeat = TEXTURE_BY_COLOR[color][1]
	if tex != "":
		_apply_texture(material, tex, repeat)
	return material


# Меняет текстуру уже созданной заглушки (например, кладка вместо дикого камня у Караульни)
func _set_texture(body: StaticBody3D, tex: String, repeat: float) -> void:
	var material: StandardMaterial3D = (body.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	_apply_texture(material, tex, repeat)


# Кладёт текстуру и карту нормалей (рельеф при свете костра).
# Triplanar — текстура «проецируется» на предмет сверху и с боков, поэтому у коробок и цилиндров
# не нужна развёртка (UV), а повтор считается в метрах самого предмета: доска на двери и на столбе
# одного размера. Проекция в координатах предмета, а не мира — у двери и колокола
# рисунок не «плывёт», когда они поворачиваются.
func _apply_texture(material: StandardMaterial3D, tex: String, repeat: float) -> void:
	material.albedo_color = Color.WHITE   # цвет уже в текстуре
	material.albedo_texture = load(TEX_DIR + tex + ".png")
	material.normal_enabled = true
	material.normal_texture = load(TEX_DIR + tex + "_n.png")
	material.roughness = 0.95
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / repeat
