extends Node3D
## Хаб «Застава Колокола»: пол, точки-заглушки, два героя, камера, интерфейс и панели.
## Пол, точки, стены и герои строятся кодом при запуске: сцена hub.tscn почти пустая.
## Север — в сторону -Z (от камеры). Размер площадки 24 × 16 метров.

signal active_hero_changed(hero_id: String)

const FLOOR_SIZE: Vector2 = Vector2(24.0, 16.0)
const WALL_HEIGHT: float = 3.0
const START_POS: Vector3 = Vector3(0.0, 0.0, 2.5)   # герои встают чуть южнее колокола
const FIRE_POS: Vector3 = Vector3(0.0, 0.0, 4.5)
const PERSONAL_STAY_DISTANCE: float = 3.0   # неактивный герой остаётся у личной точки, если стоит ближе
const LANTERN_COUNT: int = 21                # по числу ступеней улучшений: каждая зажигает фонарь
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
var _bell_pivot: Node3D
var _door_hinge: Node3D
var _door_tween: Tween
var _lantern_mats: Array[StandardMaterial3D] = []
var _banner: Node3D
var _shelf_items: Array[MeshInstance3D] = []
var _shelf_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	_setup_input()
	_build_floor()
	_build_walls()
	_build_points()
	_build_lanterns()
	_spawn_heroes()
	camera.flight_finished.connect(_on_flight_finished)
	hud = HubHud.new()
	add_child(hud)
	hud.menu_requested.connect(Run.goto.bind(Run.MAIN_MENU_SCENE))
	_set_active(heroes[0], false)
	Meta.changed.connect(refresh_world)
	refresh_world()
	_wake_up()


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
	var path: Array[Vector3] = [Vector3(side * 3.0, 0.0, 3.0), Vector3(side * 3.0, 0.0, 4.5)]
	return path


# Tab: следующий герой. Камера перелетает за 0,4 с; быстрые нажатия просто отменяют прошлый перелёт.
func switch_hero() -> void:
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
	h.go_to(_seat_path(h.hero_id), FIRE_POS)


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

	# Знамя над воротами — после первой победы над боссом
	if _banner != null:
		_banner.visible = Meta.first_boss_killed

	# Полка трофеев: открытый светится, покупаемый под тканью, «только из пути» — меловой контур
	for i in _shelf_items.size():
		if i >= Meta.CHARMS.size():
			break
		var c: RelicData = Meta.CHARMS[i]
		var sm: StandardMaterial3D = _shelf_mats[i]
		var item: MeshInstance3D = _shelf_items[i]
		sm.emission_enabled = false
		if Meta.is_charm_open(c.id):
			item.scale = Vector3.ONE
			sm.albedo_color = COL_BRASS.lightened(0.2)
			sm.emission_enabled = true
			sm.emission = COL_WARM
			sm.emission_energy_multiplier = 1.2
		elif c.buyable:
			item.scale = Vector3(1.3, 0.5, 1.0)   # ткань
			sm.albedo_color = Color(0.4, 0.42, 0.42)
		else:
			item.scale = Vector3(1.0, 1.0, 0.2)   # меловой контур
			sm.albedo_color = Color(0.75, 0.75, 0.7, 0.9)


func _swing_bell() -> void:
	if _bell_pivot == null:
		return
	var tween: Tween = create_tween()
	for angle in [6.0, -6.0, 3.0, 0.0]:
		tween.tween_property(_bell_pivot, "rotation:z", deg_to_rad(angle), 0.18).set_trans(Tween.TRANS_SINE)


# --- Пол и стены -----------------------------------------------------------------------

func _build_floor() -> void:
	# Земля внутри заставы.
	_add_block("Floor", Vector3(0.0, -0.2, 0.0), Vector3(FLOOR_SIZE.x, 0.2, FLOOR_SIZE.y), Color(0.22, 0.2, 0.15))
	# Тёмная вода вокруг, до горизонта.
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(300.0, 300.0)
	water.mesh = plane
	var water_mat: StandardMaterial3D = _make_material(Color(0.07, 0.12, 0.12), 0.0)
	# Вода рисуется в «прозрачном» проходе: тогда Шпиль-задник (render_priority выше) ляжет поверх неё.
	# Без этого вода закрывает Шпиль: он прикреплён к камере и по высоте оказывается ниже воды.
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.render_priority = 0
	water.material_override = water_mat
	water.position.y = -0.35
	add_child(water)


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


# 21 фонарь вдоль края площадки: каждая купленная ступень улучшения зажигает следующий.
func _build_lanterns() -> void:
	var half_x: float = FLOOR_SIZE.x * 0.5 - 0.3
	var half_z: float = FLOOR_SIZE.y * 0.5 - 0.3
	var perimeter: float = 2.0 * (half_x + half_z) * 2.0
	for i in LANTERN_COUNT:
		var t: float = perimeter * float(i) / float(LANTERN_COUNT)
		var pos: Vector3 = _perimeter_point(t, half_x, half_z)
		var lamp: StaticBody3D = _add_block("Lantern%d" % i, pos, Vector3(0.22, 0.3, 0.22), COL_OFF, 0.0, false)
		lamp.position.y += 1.4   # фонарь на шесте: сам шест ниже
		_add_block("LanternPost%d" % i, pos, Vector3(0.1, 1.4, 0.1), COL_WOOD, 0.0, false)
		_lantern_mats.append((lamp.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D)


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


# Колокол — центр. На балке шесть свечей по числу звонов (горят открытые Звоны, выбранный ярче).
func _build_bell() -> void:
	var c: Vector3 = Vector3(0.0, 0.0, -0.5)
	_add_cylinder("BellPlatform", c, 1.8, 0.3, COL_STONE)
	_add_block("BellPostL", c + Vector3(-0.9, 0.0, 0.0), Vector3(0.3, 3.0, 0.3), COL_WOOD)
	_add_block("BellPostR", c + Vector3(0.9, 0.0, 0.0), Vector3(0.3, 3.0, 0.3), COL_WOOD)
	_add_block("BellBeam", c + Vector3(0.0, 3.0, 0.0), Vector3(2.1, 0.3, 0.3), COL_WOOD, 0.0, false)
	# Колокол качается на оси под балкой при смене звона
	_bell_pivot = Node3D.new()
	_bell_pivot.name = "BellPivot"
	_bell_pivot.position = c + Vector3(0.0, 2.9, 0.0)
	add_child(_bell_pivot)
	var bell_body: StaticBody3D = _add_cylinder("BellBody", c + Vector3(0.0, 1.2, 0.0), 0.6, 1.4, COL_BRASS, 0.0, false)
	bell_body.reparent(_bell_pivot)   # по умолчанию сохраняет место в мире
	for i in 6:
		var x: float = -0.8 + 0.32 * float(i)
		var candle: StaticBody3D = _add_block("Candle%d" % i, c + Vector3(x, 3.3, 0.0), Vector3(0.08, 0.22, 0.08), COL_WARM, 3.0, false)
		_candle_mats.append((candle.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D)
	_add_label("Колокол", c + Vector3(0.0, 4.3, 0.0))


# Костёр — на юг от колокола, самый яркий свет хаба.
func _build_campfire() -> void:
	var c: Vector3 = FIRE_POS
	_add_cylinder("FireRing", c, 0.8, 0.25, COL_STONE)
	_add_block("FireFlame", c + Vector3(0.0, 0.25, 0.0), Vector3(0.4, 0.6, 0.4), COL_WARM, 4.0, false)
	_add_block("BenchWest", c + Vector3(-1.8, 0.0, 0.0), Vector3(0.5, 0.4, 1.6), COL_WOOD)
	_add_block("BenchEast", c + Vector3(1.8, 0.0, 0.0), Vector3(0.5, 0.4, 1.6), COL_WOOD)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 3.5
	light.omni_range = 11.0
	light.position = c + Vector3(0.0, 1.2, 0.0)
	add_child(light)
	_add_label("Костёр", c + Vector3(0.0, 2.0, 0.0))


# Ворота «Тропа к Шпилю» — на севере.
func _build_gate() -> void:
	var c: Vector3 = Vector3(0.0, 0.0, -7.2)
	_add_block("GatePostL", c + Vector3(-1.6, 0.0, 0.0), Vector3(0.4, 3.2, 0.4), COL_WOOD)
	_add_block("GatePostR", c + Vector3(1.6, 0.0, 0.0), Vector3(0.4, 3.2, 0.4), COL_WOOD)
	_add_block("GateBeam", c + Vector3(0.0, 3.2, 0.0), Vector3(3.6, 0.35, 0.4), COL_WOOD, 0.0, false)
	_add_block("GateLantern", c + Vector3(1.6, 2.2, 0.35), Vector3(0.25, 0.3, 0.25), COL_WARM, 3.0, false)
	# Знамя Стражи: появляется после первой победы над боссом
	var banner: StaticBody3D = _add_block("GateBanner", c + Vector3(0.0, 1.8, 0.0), Vector3(1.0, 1.4, 0.05), COL_MUSTARD, 0.0, false)
	banner.visible = false
	_banner = banner
	_add_label("Ворота", c + Vector3(0.0, 4.2, 0.0))


# Караульня — северо-западный угол. Дверь и окно смотрят на юг.
func _build_barracks() -> void:
	var c: Vector3 = Vector3(-8.5, 0.0, -5.2)
	_add_block("BarracksWalls", c, Vector3(4.0, 2.5, 3.0), COL_STONE)
	_add_block("BarracksRoof", c + Vector3(0.0, 2.5, 0.0), Vector3(4.4, 0.4, 3.4), COL_MOSS, 0.0, false)
	# Дверь вращается на петле у левого края
	_door_hinge = Node3D.new()
	_door_hinge.name = "DoorHinge"
	_door_hinge.position = c + Vector3(-0.45, 0.0, 1.55)
	add_child(_door_hinge)
	var door: StaticBody3D = _add_block("BarracksDoor", c + Vector3(0.0, 0.0, 1.55), Vector3(0.9, 1.8, 0.06), COL_WOOD, 0.0, false)
	door.reparent(_door_hinge)
	_add_block("BarracksWindow", c + Vector3(1.3, 1.1, 1.52), Vector3(0.6, 0.6, 0.06), COL_WARM, 3.0, false)
	var light := OmniLight3D.new()
	light.name = "BarracksLight"
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = c + Vector3(1.3, 1.1, 2.4)
	add_child(light)
	_add_label("Караульня", c + Vector3(0.0, 3.6, 0.0))


# Круг ордена (Маг) — запад: пять камней вокруг кафедры с кристаллом.
func _build_mage_circle() -> void:
	# Чуть южнее середины западной стороны: так зона Круга не накрывает дверь Караульни
	var c: Vector3 = Vector3(-8.5, 0.0, 1.2)
	_add_block("Lectern", c, Vector3(0.8, 1.1, 0.6), Color(0.2, 0.15, 0.3))
	_add_block("CrystalShard", c + Vector3(0.0, 1.5, 0.0), Vector3(0.22, 0.4, 0.22), Color(0.2, 0.3, 1.0), 3.0, false)
	for i in 5:
		var angle: float = TAU * float(i) / 5.0
		var pos: Vector3 = c + Vector3(cos(angle), 0.0, sin(angle)) * 2.0
		_add_cylinder("Stone%d" % i, pos, 0.3, 1.7, Color(0.38, 0.36, 0.45))
	_add_label("Круг ордена · Маг", c + Vector3(0.0, 2.6, 0.0))


# Оружейная (Рыцарь) — восток.
func _build_armory() -> void:
	var c: Vector3 = Vector3(8.5, 0.0, 0.0)
	_add_block("ArmorStand", c + Vector3(0.0, 0.0, -1.2), Vector3(0.6, 1.7, 0.6), COL_STEEL)
	_add_block("WeaponRack", c + Vector3(1.8, 0.0, 0.8), Vector3(0.3, 1.4, 1.6), COL_WOOD)
	_add_block("Dummy", c + Vector3(-0.2, 0.0, 1.6), Vector3(0.5, 1.5, 0.5), Color(0.55, 0.45, 0.22))
	_add_block("Banner", c + Vector3(2.2, 0.0, -1.8), Vector3(0.1, 2.6, 1.0), COL_MUSTARD)
	_add_label("Оружейная · Рыцарь", c + Vector3(0.0, 2.6, 0.0))


# Доска дозора — юго-запад.
func _build_notice_board() -> void:
	var c: Vector3 = Vector3(-8.5, 0.0, 5.2)
	_add_block("NoticeBoard", c, Vector3(2.2, 1.6, 0.25), COL_WOOD)
	_add_block("NoticeLantern", c + Vector3(0.0, 1.7, 0.3), Vector3(0.22, 0.28, 0.22), COL_WARM, 3.0, false)
	_add_label("Доска дозора", c + Vector3(0.0, 2.6, 0.0))


# Полка трофеев (обереги) — юго-восток. Десять мест в два яруса на южной стороне полки.
func _build_trophy_shelf() -> void:
	var c: Vector3 = Vector3(8.5, 0.0, 5.0)
	_add_block("TrophyShelf", c, Vector3(2.4, 1.8, 0.8), COL_WOOD)
	_add_block("ShelfAwning", c + Vector3(0.0, 1.9, 0.0), Vector3(2.8, 0.15, 1.3), COL_WOOD, 0.0, false)
	for i in SHELF_SLOTS:
		var col: int = i % 5
		var tier: int = i / 5
		var pos: Vector3 = c + Vector3(-0.95 + 0.475 * float(col), 0.55 + 0.7 * float(tier), 0.42)
		var item: StaticBody3D = _add_block("ShelfItem%d" % i, pos, Vector3(0.24, 0.24, 0.1), COL_BRASS, 0.0, false)
		_shelf_items.append(item.get_child(0) as MeshInstance3D)
		_shelf_mats.append((item.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D)
	_add_label("Полка трофеев", c + Vector3(0.0, 2.8, 0.0))


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


func _make_material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
