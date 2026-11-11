extends Node3D
# Сцена боя: создаёт логику боя (BattleLogic), показывает её в 3D
# и передаёт ей клики игрока. Сама правил не считает.
#
# Как это работает: логика меняет числа мгновенно и шлёт сигналы
# («юнит пошёл», «получил урон»…). Сцена складывает анимации этих событий
# в очередь и проигрывает по одной, дожидаясь каждой через await.
# Пока очередь играет, ввод игрока отключён (режим BUSY).
#
# Героев двое: в каждый момент один из них «активный» — его рука карт
# внизу экрана, и именно он ходит и колдует. Переключение — Tab или клик.
#
# Прогноз: после каждого действия игрока бой «проигрывается» на копии,
# и мы рисуем, куда пойдёт каждый враг (линия) и куда ударит (красные клетки).

enum Mode {
	BUSY,    # идут анимации или ход врагов — клики игнорируем
	IDLE,    # ход героев, карта не выбрана: клик по полю — идти
	AIMING,  # выбрана карта: клик по полю — применить
}

const COLOR_MOVE := Color(0.3, 0.6, 1.0, 0.35)
const COLOR_TARGET := Color(1.0, 0.9, 0.3, 0.3)
const COLOR_AREA := Color(1.0, 0.5, 0.1, 0.6)
const COLOR_INTENT := Color(1.0, 0.1, 0.1, 0.45)
const COLOR_HOVER_THREAT := Color(1.0, 0.0, 0.3, 0.6)
const COLOR_FLASH := Color(1.0, 0.95, 0.6, 0.8)
const COLOR_EXPLOSION := Color(1.0, 0.6, 0.15, 0.8)
const COLOR_TREE_FALL := Color(0.8, 0.75, 0.6, 0.7)
const COLOR_GAS := Color(0.6, 0.95, 0.4, 0.8)        # газовый хлопок жабы
const COLOR_BUFF := Color(0.37, 0.92, 0.83, 0.4)     # «зов» шамана: бирюза Раскола

# Камера: смотрит на центр поля под наклоном, Q/E — поворот на 90°, колесо — зум
const CAM_PITCH_DEG: float = 60.0
const CAM_DIST_MIN: float = 8.0
const CAM_DIST_MAX: float = 24.0
const CAM_TURN_TIME: float = 0.3

@onready var board: Board = $Board
@onready var camera: Camera3D = $Camera3D
@onready var hud: BattleHud = $HUD

var logic := BattleLogic.new()
var _views: Dictionary[BattleUnit, Unit] = {}   # логический юнит -> его 3D-фигурка
var _active: BattleUnit                         # выбранный герой
var _ring: MeshInstance3D                       # светящееся кольцо под выбранным героем
var _mode: Mode = Mode.BUSY
var _selected_card: int = -1
var _hover_cell := Vector2i(-1, -1)
var _anim_queue: Array[Callable] = []
var _cam_yaw_deg: float = 0.0     # поворот камеры вокруг поля
var _cam_dist: float = 15.0       # расстояние от центра поля
var _cam_tween: Tween


func _ready() -> void:
	Run.ensure_run()
	var layout_seed: int = Run.rng.randi()
	logic.setup(board.width, board.height, Run.rng, Run.party, Run.pending_enemies, Run.pending_arena)
	board.build(layout_seed, logic.arena_id, logic.ground)
	_update_camera()
	_create_views()
	_connect_logic()
	hud.card_pressed.connect(_on_card_pressed)
	hud.hero_pressed.connect(_on_hero_pressed)
	hud.end_turn_pressed.connect(_on_end_turn_pressed)

	hud.show_arena(logic.arena_title())
	_mode = Mode.BUSY
	logic.start()
	await _play_queue()
	_select_hero(logic.living_heroes()[0])
	_enter_idle()


# ---------- Создание фигурок ----------

func _create_views() -> void:
	for h in logic.heroes:
		var view: Unit = _spawn_view(h.hero_data.id.capitalize(), h.cell)
		if h.hero_data.model != null:
			view.add_child(h.hero_data.model.instantiate())
			view.setup_animations()   # если в модели есть анимации — включаем Idle
		else:
			view.add_child(_make_capsule_model(h.hero_data.color, 1.1, true))
		view.face_dir(Vector2i(0, -1))   # лицом к врагам
		view.setup_label(2.0)
		view.visible = h.is_alive()
		_views[h] = view

	for e in logic.enemies:
		var view: Unit = _spawn_view(e.data.id.capitalize(), e.cell)
		if e.data.model != null:
			view.add_child(e.data.model.instantiate())
			view.setup_animations()   # Idle, Walk, Attack, Hit, Death из модели
		else:
			view.add_child(_make_capsule_model(e.data.color, e.data.size, false))
		view.face_dir(GridShapes.cardinal_dir(e.cell, logic.heroes[0].cell))
		view.setup_label(1.4 * e.data.size + 0.55)
		_views[e] = view

	for c: Vector2i in logic.rocks:
		board.add_rock(c)
	for c: Vector2i in logic.objects:
		board.add_object(c, logic.objects[c])
	for c: Vector2i in logic.tiles:
		board.set_tile_effect(c, logic.tiles[c])
	for u: BattleUnit in _views:
		_views[u].set_status(_status_text(u, logic.snapshot(u)))

	# Кольцо выбора: плоский цилиндр, который «приклеиваем» к выбранному герою
	_ring = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.45
	disc.bottom_radius = 0.45
	disc.height = 0.02
	_ring.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.9, 0.4, 0.55)
	_ring.material_override = mat
	_ring.position.y = 0.02


func _spawn_view(node_name: String, cell: Vector2i) -> Unit:
	var view := Unit.new()
	view.name = node_name
	add_child(view)
	view.board = board
	view.place_at(cell)
	return view


# Заглушка: капсула нужного цвета и «нос», чтобы было видно, куда фигурка смотрит.
# У героя-заглушки (рыцаря) ещё плоский «щит» сбоку.
func _make_capsule_model(color: Color, size: float, with_shield: bool) -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28 * size
	capsule.height = 1.1 * size
	body.mesh = capsule
	body.material_override = mat
	body.position.y = capsule.height / 2.0
	root.add_child(body)

	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.15, 0.2) * size
	nose.mesh = box
	nose.material_override = mat
	nose.position = Vector3(0.0, capsule.height * 0.75, capsule.radius)
	root.add_child(nose)

	if with_shield:
		var shield := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = Vector3(0.06, 0.55, 0.4) * size
		shield.mesh = plate
		var shield_mat := StandardMaterial3D.new()
		shield_mat.albedo_color = Color(0.7, 0.72, 0.78)
		shield_mat.metallic = 0.6
		shield.material_override = shield_mat
		shield.position = Vector3(-capsule.radius - 0.05, capsule.height * 0.5, 0.1)
		root.add_child(shield)
	return root


# Надпись над головой. state — снимок из логики (HP, блок, ярость, провокация).
func _status_text(u: BattleUnit, state: Dictionary) -> String:
	var text: String = "%s  %d/%d" % [u.title, state["hp"], u.max_hp]
	if state["block"] > 0:
		text += "  Блок %d" % state["block"]
	if u.is_hero:
		if u.hero_data.gains_rage and state["rage"] > 0:
			text += "\nЯрость %d" % state["rage"]
		if u.hero_data.uses_charge and state["charge"] > 0:
			text += "\nЗаряд %d" % state["charge"]
		if u.hero_data.gains_momentum and state["momentum"] > 0:
			text += "\nНатиск %d" % state["momentum"]
		if state["taunt"]:
			text += "\nПровокация"
	elif state["damage"] > 0:
		text += "\n%s: %d" % [state["intent"], state["damage"]]
	else:
		text += "\n%s" % state["intent"]   # «зов» — удара в этом раунде нет
	if state["entangled"] > 0:
		text += "\nОпутан"
	return text


# ---------- События логики → очередь анимаций ----------

func _connect_logic() -> void:
	logic.unit_moved.connect(_on_unit_moved)
	logic.unit_pushed.connect(_on_unit_pushed)
	logic.unit_damaged.connect(_on_unit_damaged)
	logic.unit_died.connect(_on_unit_died)
	logic.status_changed.connect(_on_status_changed)
	logic.tile_changed.connect(_on_tile_changed)
	logic.object_changed.connect(_on_object_changed)
	logic.object_moved.connect(_on_object_moved)
	logic.effect_cells.connect(_on_effect_cells)
	logic.card_cast.connect(_on_card_cast)
	logic.enemy_attacked.connect(_on_enemy_attacked)
	logic.enemy_buffed.connect(_on_enemy_buffed)
	logic.message.connect(_on_message)


func _queue(step: Callable) -> void:
	_anim_queue.append(step)


# Проигрывает накопленные анимации по очереди, дожидаясь каждой
func _play_queue() -> void:
	while not _anim_queue.is_empty():
		var step: Callable = _anim_queue.pop_front()
		await step.call()


func _on_unit_moved(unit: BattleUnit, path: Array[Vector2i]) -> void:
	var view: Unit = _views[unit]
	_queue(func() -> void: await view.follow_path(path))


func _on_unit_pushed(unit: BattleUnit, path: Array[Vector2i], bumped: bool) -> void:
	var view: Unit = _views[unit]
	_queue(func() -> void: await view.play_push(path, bumped))


func _on_unit_damaged(unit: BattleUnit, _amount: int, state: Dictionary) -> void:
	var view: Unit = _views[unit]
	var text: String = _status_text(unit, state)
	_queue(func() -> void:
		view.set_status(text)
		await view.play_hit()
	)


func _on_unit_died(unit: BattleUnit) -> void:
	var view: Unit = _views[unit]
	if logic.object_at(unit.cell) == BattleLogic.Obj.BOG:
		_queue(func() -> void: await view.play_sink())   # утонул в трясине
	else:
		_queue(func() -> void: await view.play_death())


func _on_status_changed(unit: BattleUnit, state: Dictionary) -> void:
	var view: Unit = _views[unit]
	var text: String = _status_text(unit, state)
	_queue(func() -> void: view.set_status(text))


func _on_tile_changed(cell: Vector2i, tile: int) -> void:
	_queue(func() -> void: board.set_tile_effect(cell, tile))


func _on_object_changed(cell: Vector2i, old_kind: int, new_kind: int, dir: Vector2i) -> void:
	_queue(func() -> void: await board.change_object(cell, old_kind, new_kind, dir))


func _on_object_moved(from: Vector2i, to: Vector2i) -> void:
	_queue(func() -> void: await board.move_object(from, to))


func _on_effect_cells(cells: Array[Vector2i], kind: String) -> void:
	var color: Color = COLOR_TREE_FALL
	if kind == "explosion":
		color = COLOR_EXPLOSION
	elif kind == "gas":
		color = COLOR_GAS
	_queue(func() -> void:
		board.show_cells("flash", cells, color)
		await get_tree().create_timer(0.25).timeout
		board.clear_layer("flash")
	)


func _on_card_cast(caster: BattleUnit, card: CardData, cells: Array[Vector2i]) -> void:
	var view: Unit = _views[caster]
	var from_cell: Vector2i = caster.cell
	var dir: Vector2i = Vector2i.ZERO
	if not cells.is_empty():
		dir = GridShapes.cardinal_dir(from_cell, cells[0])
	var is_mage: bool = caster.is_hero and caster.hero_data != null and caster.hero_data.id == "mage"
	_queue(func() -> void:
		view.face_dir(dir)
		# Выбираем анимацию героя под тип карты:
		# Маг: CastSky (Метеор, Молния, Рывок), Cast (направленные заклинания), Block (Щит), Attack (Удар посохом)
		# Рыцарь: Attack (удары), Block (щит и провокация)
		if (card.block > 0 or card.taunt) and view.has_anim("Block"):
			await view.play_block()
		elif is_mage and card.id in ["meteor", "lightning", "dash"] and view.has_anim("CastSky"):
			await view.play_cast_sky(dir)
		elif is_mage and card.id != "strike" and view.has_anim("Cast"):
			await view.play_cast(dir)
		elif card.damage > 0 and view.has_anim("Attack") and dir != Vector2i.ZERO:
			await view.play_attack(dir)

		board.show_cells("flash", cells, COLOR_FLASH)
		if is_mage or card.element != CardData.Element.NONE:
			await SpellFx.play(board, card, from_cell, cells)
		else:
			await get_tree().create_timer(0.25).timeout   # короткая пауза, чтобы вспышку было видно
		board.clear_layer("flash")
	)


func _on_enemy_attacked(unit: BattleUnit, dir: Vector2i, cells: Array[Vector2i]) -> void:
	var view: Unit = _views[unit]
	var anim_name: String = logic.enemy_attack(unit).anim   # у ударов из цикла может быть своя анимация
	_queue(func() -> void:
		board.show_cells("flash", cells, COLOR_INTENT)
		await view.play_attack(dir, anim_name)
		board.clear_layer("flash")
	)


# «Зов»: враг не бьёт, а усиливает своих — бирюзовая вспышка по квадрату
func _on_enemy_buffed(unit: BattleUnit, cells: Array[Vector2i]) -> void:
	var view: Unit = _views[unit]
	_queue(func() -> void:
		board.show_cells("flash", cells, COLOR_BUFF)
		await view.play_cast(Vector2i.ZERO)
		await get_tree().create_timer(0.25).timeout
		board.clear_layer("flash")
	)


func _on_message(text: String) -> void:
	_queue(func() -> void: hud.add_log(text))


# ---------- Выбор героя ----------

func _select_hero(h: BattleUnit) -> void:
	if h == null or not h.is_alive():
		return
	_active = h
	if _ring.get_parent() != null:
		_ring.get_parent().remove_child(_ring)
	_views[h].add_child(_ring)   # кольцо — ребёнок фигурки, поэтому ходит вместе с ней


# Следующий живой герой по кругу (для Tab)
func _next_hero() -> BattleUnit:
	var alive: Array[BattleUnit] = logic.living_heroes()
	if alive.is_empty():
		return null
	var i: int = alive.find(_active)
	return alive[(i + 1) % alive.size()]


func _on_hero_pressed(index: int) -> void:
	if _mode == Mode.BUSY:
		return
	_select_hero(logic.heroes[index])
	_enter_idle()


# ---------- Ввод игрока ----------

func _unhandled_input(event: InputEvent) -> void:
	# Камерой можно крутить всегда, даже пока идут анимации
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var wheel := event as InputEventMouseButton
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-1.0)
			return
		if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.0)
			return
	if event is InputEventKey and event.pressed and not event.is_echo():
		var key := event as InputEventKey
		if key.keycode == KEY_Q:
			_turn_camera(-90.0)
			return
		if key.keycode == KEY_E:
			_turn_camera(90.0)
			return
	if _mode == Mode.BUSY:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_on_hover(_screen_to_cell(motion.position))
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if not click.pressed:
			return
		if click.button_index == MOUSE_BUTTON_LEFT:
			_on_cell_clicked(_screen_to_cell(click.position))
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_card()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_TAB:
		_select_hero(_next_hero())
		_enter_idle()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_card()


func _on_cell_clicked(cell: Vector2i) -> void:
	match _mode:
		Mode.IDLE:
			var clicked: BattleUnit = logic.unit_at(cell)
			if clicked != null and clicked.is_hero:
				_select_hero(clicked)   # клик по герою — выбрать его
				_enter_idle()
			elif logic.get_move_targets(_active).has(cell):
				var h: BattleUnit = _active
				_do(func() -> void: logic.move_hero(h, cell))
		Mode.AIMING:
			if logic.get_card_targets(_active, _selected_card).has(cell):
				var h: BattleUnit = _active
				var index: int = _selected_card
				_do(func() -> void: logic.play_card(h, index, cell))
			else:
				_cancel_card()


func _on_hover(cell: Vector2i) -> void:
	_hover_cell = cell
	_show_hovered_enemy_threat(cell)
	if _mode == Mode.AIMING and logic.get_card_targets(_active, _selected_card).has(cell):
		board.show_cells("area", logic.get_card_area(_active, _selected_card, cell), COLOR_AREA)
	else:
		board.clear_layer("area")


# Навёл на врага — его зона угрозы подсвечивается ярче
func _show_hovered_enemy_threat(cell: Vector2i) -> void:
	var u: BattleUnit = logic.unit_at(cell)
	if u != null and not u.is_hero:
		board.show_cells("hover_threat", logic.get_threat_cells(u), COLOR_HOVER_THREAT)
		hud.show_enemy_info(_enemy_info(u))
	else:
		board.clear_layer("hover_threat")
		hud.show_enemy_info("")


# Текст подсказки о враге под курсором: кто это, чем бьёт сейчас и потом, особенности
func _enemy_info(e: BattleUnit) -> String:
	var d: EnemyData = e.data
	var text: String = d.title
	if d.is_boss:
		text += " — босс"
	elif d.is_elite:
		text += " — элита"
	if d.description != "":
		text += "\n«%s»" % d.description
	text += "\nСейчас — %s" % logic.enemy_attack(e).describe()
	if d.cycle.size() > 1:
		text += "\nПотом — %s" % d.attack_on_turn(logic.turn + 1).describe()
	for t: String in d.traits():
		text += "\n• %s" % t
	return text


func _on_card_pressed(index: int) -> void:
	if _mode == Mode.BUSY:
		return
	if _selected_card == index:
		_cancel_card()
		return
	if not logic.can_play(_active, index):
		return
	var card: CardData = _active.hand[index]
	if card.shape == CardData.Shape.SELF or card.shape == CardData.Shape.AROUND:
		var h: BattleUnit = _active
		_do(func() -> void: logic.play_card(h, index, h.cell))
		return
	_selected_card = index
	_mode = Mode.AIMING
	board.clear_layer("move")
	board.show_cells("target", logic.get_card_targets(_active, index), COLOR_TARGET)
	hud.refresh(logic, _active, _selected_card, false)
	_on_hover(_hover_cell)


func _cancel_card() -> void:
	if _mode == Mode.AIMING:
		_enter_idle()


func _on_end_turn_pressed() -> void:
	if _mode != Mode.BUSY:
		_do(logic.end_turn)


# Выполняет действие в логике и проигрывает все анимации, которые оно вызвало
func _do(action: Callable) -> void:
	_mode = Mode.BUSY
	_selected_card = -1
	for layer: String in ["move", "target", "area", "hover_threat", "intent", "buff", "routes"]:
		board.clear_layer(layer)
	hud.show_enemy_info("")
	hud.refresh(logic, _active, -1, true)
	action.call()
	await _play_queue()
	if logic.is_over:
		await _finish_battle()
		return
	if not _active.is_alive():
		_select_hero(_next_hero())   # выбранный герой пал — переключаемся на живого
	_enter_idle()


# Ход героев, ничего не выбрано: куда может идти выбранный герой и что сделают враги
func _enter_idle() -> void:
	_mode = Mode.IDLE
	_selected_card = -1
	board.clear_layer("target")
	board.clear_layer("area")
	var move_cells: Array[Vector2i] = []
	for c: Vector2i in logic.get_move_targets(_active):
		move_cells.append(c)
	board.show_cells("move", move_cells, COLOR_MOVE)
	_show_forecast()
	hud.refresh(logic, _active, -1, false)


# Прогноз: линии — куда пойдёт каждый враг, красные клетки — куда он ударит,
# если прямо сейчас нажать «Конец хода». Пересчитывается после каждого действия.
func _show_forecast() -> void:
	var paths: Array = []
	var seen: Dictionary[Vector2i, bool] = {}
	var hits: Array[Vector2i] = []
	var buffs: Array[Vector2i] = []
	for plan: Dictionary in logic.forecast_enemies():
		paths.append(plan["path"])
		for c: Vector2i in plan["buff"]:
			if not buffs.has(c):
				buffs.append(c)
		for c: Vector2i in plan["attack"]:
			if not seen.has(c):
				seen[c] = true
				hits.append(c)
	board.show_routes(paths)
	board.show_cells("intent", hits, COLOR_INTENT)
	board.show_cells("buff", buffs, COLOR_BUFF)   # бирюзовое — кого шаман усилит «зовом»


func _finish_battle() -> void:
	board.clear_layer("intent")
	board.clear_layer("buff")
	board.clear_layer("routes")
	hud.show_banner("Победа!" if logic.won else "Поражение…")
	await get_tree().create_timer(1.5).timeout
	var hp_left: Array[int] = []
	for h in logic.heroes:
		hp_left.append(h.hp)
	Run.finish_battle(logic.won, hp_left)


# Переводит точку на экране в клетку поля:
# пускаем луч из камеры через курсор и смотрим, где он пересёк пол (высота 0)
func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var ray_from: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	var floor_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = floor_plane.intersects_ray(ray_from, ray_dir)
	if hit == null:
		return Vector2i(-1, -1)  # луч ушёл в небо — клетки нет
	return board.world_to_grid(hit)



# ---------- Камера ----------

# Ставит камеру на «сферу» вокруг центра поля: угол поворота, наклон, расстояние
func _update_camera() -> void:
	# Точка взгляда чуть ближе к камере, чем центр поля: так поле встаёт выше и рука карт его не закрывает
	var look_shift := Vector3(0.0, 0.0, 2.6).rotated(Vector3.UP, deg_to_rad(_cam_yaw_deg))
	var center := Vector3((board.width - 1) / 2.0, 0.0, (board.height - 1) / 2.0) + look_shift
	var pitch: float = deg_to_rad(CAM_PITCH_DEG)
	var offset := Vector3(0.0, sin(pitch), cos(pitch)) * _cam_dist
	offset = offset.rotated(Vector3.UP, deg_to_rad(_cam_yaw_deg))
	camera.position = center + offset
	camera.look_at(center, Vector3.UP)


func _turn_camera(delta_deg: float) -> void:
	if _cam_tween != null and _cam_tween.is_running():
		return
	_cam_tween = create_tween()
	_cam_tween.tween_method(func(yaw: float) -> void:
		_cam_yaw_deg = yaw
		_update_camera(), _cam_yaw_deg, _cam_yaw_deg + delta_deg, CAM_TURN_TIME).set_ease(Tween.EASE_IN_OUT)


func _zoom_camera(direction: float) -> void:
	_cam_dist = clampf(_cam_dist + direction * 1.2, CAM_DIST_MIN, CAM_DIST_MAX)
	_update_camera()
