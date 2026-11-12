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
const COLOR_GHOST_MOVE := Color(0.4, 0.8, 1.0, 0.55)   # куда встанут юниты после карты
const COLOR_GHOST_KILL := Color(0.96, 0.8, 0.36, 0.7)  # кто погибнет
const COLOR_INTENT := Color(1.0, 0.1, 0.1, 0.45)
const COLOR_HOVER_THREAT := Color(1.0, 0.0, 0.3, 0.6)
const COLOR_FLASH := Color(1.0, 0.95, 0.6, 0.8)
const COLOR_EXPLOSION := Color(1.0, 0.6, 0.15, 0.8)
const COLOR_TREE_FALL := Color(0.8, 0.75, 0.6, 0.7)
const COLOR_GAS := Color(0.6, 0.95, 0.4, 0.8)        # газовый хлопок жабы
const COLOR_STEAM := Color(0.9, 0.95, 1.0, 0.75)     # паровой взрыв
const COLOR_FREEZE := Color(0.5, 0.85, 1.0, 0.7)     # заморозка
const COLOR_SHATTER := Color(0.7, 0.95, 1.0, 0.8)    # ледяные осколки
const COLOR_LAVA := Color(1.0, 0.65, 0.1, 0.75)      # лава (оранжево-жёлтая, без красного)
const COLOR_CRUST := Color(0.6, 0.6, 0.62, 0.75)     # корка
const COLOR_SHOCK := Color(1.0, 0.95, 0.55, 0.8)     # молния по мокрому
const COLOR_RUNE := Color(0.9, 0.93, 1.0, 0.8)       # взрыв сторожевой руны (серебристо-белый)
const REACTION_KINDS: Array[String] = ["steam", "freeze", "shatter", "lava", "crust", "shock"]
const COLOR_BUFF := Color(0.37, 0.92, 0.83, 0.4)     # «зов» шамана: бирюза Раскола

# Ощущение удара от окружения (взрыв бочки, падение дерева). Всё можно подкрутить:
const SHAKE_TIME: float = 0.2             # сколько секунд трясётся камера
const SHAKE_POWER_EXPLOSION: float = 0.35  # сила тряски у взрыва (в метрах смещения)
const SHAKE_POWER_TREE: float = 0.2        # сила тряски у падения дерева
const HITSTOP_TIME: float = 0.08           # стоп-кадр: на столько секунд игра почти замирает
const HITSTOP_SCALE: float = 0.05          # …и идёт с такой скоростью (1.0 — без стоп-кадра)
const ENV_NUMBER_SIZE: int = 110           # размер цифры урона от окружения (Label3D font_size)
const COLOR_ENV_NUMBER := Color(1.0, 0.85, 0.4)

# Камера: смотрит на центр поля под наклоном, Q/E — поворот на 90°, колесо — зум
const CAM_PITCH_DEG: float = 60.0
const CAM_DIST_MIN: float = 8.0
const CAM_DIST_MAX: float = 24.0
const CAM_TURN_TIME: float = 0.3
const CAM_LOOK_SHIFT: float = 1.1   # на сколько клеток точка взгляда сдвинута от центра поля к камере

# Значок намерения врага на плашке — по форме его удара (EnemyData.Attack):
# вплотную, линия, размах по трём клеткам, «зов» (усиление своих)
const INTENT_ICONS: Array[String] = ["sword", "arrow", "slash", "buff"]

@onready var board: Board = $Board
@onready var camera: Camera3D = $Camera3D
@onready var hud: BattleHud = $HUD

var logic := BattleLogic.new()
var _views: Dictionary[BattleUnit, Unit] = {}   # логический юнит -> его 3D-фигурка
var _active: BattleUnit                         # выбранный герой
var _ring: MeshInstance3D                       # светящееся кольцо под выбранным героем
var _mode: Mode = Mode.BUSY
var _selected_card: int = -1
var _hover_cell: Vector2i = BattleLogic.NO_CELL
var _anim_queue: Array[Callable] = []
var _cam_yaw_deg: float = 0.0     # поворот камеры вокруг поля
var _cam_dist: float = 15.0       # расстояние от центра поля
var _cam_tween: Tween
# Замер длины боя (пишется в Output в конце боя, см. _finish_battle)
var _battle_start_ms: int = 0     # когда начался бой
var _enemy_phase_ms: int = 0      # сколько всего длились ходы врагов (от «Конец хода» до конца анимаций)
var _start_hp: Array[int] = []    # здоровье героев в начале боя
var _fire_forecast: Dictionary = {}   # прогноз огня: id юнита → урон в конце хода врагов
var _enemy_phase_running: bool = false   # идёт ход врагов (на нём работает «Скорость ×2»)


func _ready() -> void:
	Run.ensure_run()
	var layout_seed: int = Run.rng.randi()
	logic.setup(board.width, board.height, Run.rng, Run.party, Run.pending_enemies, Run.pending_arena)
	board.build(layout_seed, logic.arena_id, logic.ground)
	_update_camera()
	_create_views()
	_connect_logic()
	hud.card_pressed.connect(_on_card_pressed)
	hud.card_keep_toggled.connect(_on_card_keep_toggled)
	hud.hero_pressed.connect(_on_hero_pressed)
	hud.end_turn_pressed.connect(_on_end_turn_pressed)
	hud.speed_toggled.connect(_apply_speed)
	hud.discard_toggled.connect(_on_discard_toggled)

	hud.show_arena(logic.arena_title())
	_battle_start_ms = Time.get_ticks_msec()
	for h in logic.heroes:
		_start_hp.append(h.hp)
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
		view.face_dir(HexMath.FACE_UP)   # лицом к врагам
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
		view.face_dir(HexMath.direction_to(e.cell, logic.heroes[0].cell))
		view.setup_label(1.4 * e.data.size + 0.55)
		_views[e] = view

	for c: Vector2i in logic.rocks:
		board.add_rock(c)
	for c: Vector2i in logic.objects:
		board.add_object(c, logic.objects[c])
	for c: Vector2i in logic.tiles:
		board.set_tile_effect(c, logic.tiles[c])
	for u: BattleUnit in _views:
		_views[u].set_status(_plate_info(u, logic.snapshot(u)))

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


# Что показать на плашке над головой. state — снимок из логики (HP, блок, намерение…).
# Собираем сразу, в момент события: к тому времени, как дойдёт очередь анимации,
# числа в логике уже могут быть другими.
func _plate_info(u: BattleUnit, state: Dictionary) -> Dictionary:
	var info: Dictionary = {
		"hp": state["hp"], "max_hp": u.max_hp, "block": state["block"],
		"is_hero": u.is_hero, "color": Color.WHITE, "marks": [],
	}
	var marks: Array[String] = []
	if u.is_hero:
		info["color"] = u.hero_data.color
		if state["taunt"]:
			marks.append("taunt")
	else:
		# Намерение врага: значок по форме удара и урон в этом раунде
		var shape: int = logic.enemy_attack(u).shape
		info["intent_icon"] = INTENT_ICONS[shape] if shape < INTENT_ICONS.size() else "sword"
		info["intent_value"] = state["damage"]
		info["intent_color"] = UiKit.RIFT if shape == EnemyData.Attack.AURA else UiKit.THREAT
		if u.data.ai_style == EnemyData.AiStyle.HUNTER:
			marks.append("ai_hunter")
		elif u.data.ai_style == EnemyData.AiStyle.GUARD:
			marks.append("ai_guard")
	if state["entangled"] > 0:
		marks.append("entangled")
	if state.get("wet", 0) > 0:
		marks.append("wet")
	if state.get("poison", 0) > 0:
		marks.append("poison")
	info["marks"] = marks
	if _fire_forecast.has(u.id):
		info["fire"] = _fire_forecast[u.id]
	return info


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
	logic.reaction.connect(_on_reaction)
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
	var info: Dictionary = _plate_info(unit, state)
	_queue(func() -> void:
		view.set_status(info)
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
	var info: Dictionary = _plate_info(unit, state)
	_queue(func() -> void: view.set_status(info))


func _on_tile_changed(cell: Vector2i, tile: int) -> void:
	_queue(func() -> void: board.set_tile_effect(cell, tile))


func _on_object_changed(cell: Vector2i, old_kind: int, new_kind: int, dir: Vector2i) -> void:
	_queue(func() -> void: await board.change_object(cell, old_kind, new_kind, dir))


func _on_object_moved(from: Vector2i, to: Vector2i) -> void:
	_queue(func() -> void: await board.move_object(from, to))


# Реакция стихий: короткая цветная вспышка на клетке
func _on_reaction(cell: Vector2i, kind: String) -> void:
	var color: Color = COLOR_STEAM
	if kind == "freeze":
		color = COLOR_FREEZE
	elif kind == "shatter":
		color = COLOR_SHATTER
	elif kind == "lava":
		color = COLOR_LAVA
	elif kind == "crust":
		color = COLOR_CRUST
	elif kind == "shock":
		color = COLOR_SHOCK
	var cells: Array[Vector2i] = [cell]
	_queue(func() -> void:
		board.show_cells("flash", cells, color)
		await get_tree().create_timer(0.2).timeout
		board.clear_layer("flash")
	)


func _on_effect_cells(cells: Array[Vector2i], kind: String) -> void:
	var color: Color = COLOR_TREE_FALL
	var damage: int = BattleLogic.TREE_DAMAGE
	if kind == "explosion":
		color = COLOR_EXPLOSION
		damage = BattleLogic.BARREL_DAMAGE
	elif kind == "gas":
		color = COLOR_GAS
		damage = 0
	elif kind == "rune":
		color = COLOR_RUNE
		damage = BattleLogic.RUNE_TRAP_DAMAGE
	# Кто стоит в зоне удара — запоминаем сейчас: к моменту анимации юниты уже сдвинуться могут
	var victims: Array[Vector2i] = []
	if damage > 0:
		for c in cells:
			var hit_unit: BattleUnit = logic.unit_at(c)
			# Руна рыцаря героев не ранит — цифру над ними не показываем
			if hit_unit != null and not (kind == "rune" and hit_unit.is_hero):
				victims.append(c)
	_queue(func() -> void:
		board.show_cells("flash", cells, color)
		if kind != "gas":
			_shake(SHAKE_POWER_EXPLOSION if kind == "explosion" else SHAKE_POWER_TREE)
			for c in victims:
				_floating_number(c, "-%d" % damage)
			await _hit_stop()
		await get_tree().create_timer(0.25).timeout
		board.clear_layer("flash")
	)


# Тряска камеры: смещаем «объектив» (h_offset / v_offset), поворот и зум камеры не трогаем
func _shake(power: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		var k: float = (1.0 - t) * power
		camera.h_offset = randf_range(-k, k)
		camera.v_offset = randf_range(-k, k), 0.0, 1.0, SHAKE_TIME)
	tween.tween_callback(func() -> void:
		camera.h_offset = 0.0
		camera.v_offset = 0.0)


# Стоп-кадр: игра на миг почти замирает. Таймер считает реальное время (не зависит от скорости игры),
# после него возвращаем ту скорость, что была (обычную или «×2» во время хода врагов).
func _hit_stop() -> void:
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(HITSTOP_TIME, true, false, true).timeout
	_apply_speed()


# Цифра урона над клеткой: всплывает вверх и тает
func _floating_number(cell: Vector2i, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UiKit.font_bold()
	label.font_size = ENV_NUMBER_SIZE
	label.pixel_size = 0.006
	label.outline_size = 14
	label.modulate = COLOR_ENV_NUMBER
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = board.grid_to_world(cell) + Vector3(0.0, 1.5, 0.0)
	add_child(label)
	var tween: Tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.9, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.tween_callback(label.queue_free)


func _on_card_cast(caster: BattleUnit, card: CardData, cells: Array[Vector2i]) -> void:
	var view: Unit = _views[caster]
	var from_cell: Vector2i = caster.cell
	var dir: Vector2i = Vector2i.ZERO
	if not cells.is_empty():
		dir = HexMath.direction_to(from_cell, cells[0])
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


# «Зов»: враг не бьёт, а усиливает своих — бирюзовая вспышка по кругу вокруг зовущего
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
	elif event is InputEventKey and event.pressed and not event.is_echo() and (event as InputEventKey).keycode == KEY_X:
		# X, затем карта — сбросить её «в ноги»: бесплатно, шаг или блок вместо эффекта
		_scrapping = not _scrapping
		_discarding = false
		_selected_card = -1
		_enter_idle()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_TAB:
		_select_hero(_next_hero())
		_enter_idle()
	elif event is InputEventKey and event.pressed and not event.is_echo() \
			and (event as InputEventKey).keycode >= KEY_1 and (event as InputEventKey).keycode <= KEY_9:
		# Цифры 1–9 — карта из руки по номеру (та же цифра написана на самой карте)
		var card_index: int = (event as InputEventKey).keycode - KEY_1
		if card_index < _active.hand.size():
			if (event as InputEventKey).shift_pressed:
				_on_card_keep_toggled(card_index)   # Shift + цифра — удержать карту
			else:
				_on_card_pressed(card_index)
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
		# «Призрак»: куда встанут юниты и кто погибнет, если сыграть карту сюда
		var ghost: Dictionary = logic.ghost_preview(_active, _selected_card, cell)
		var landing: Array[Vector2i] = []
		for mv: Dictionary in ghost["moves"]:
			landing.append(mv["to"])
		board.show_cells("ghost_move", landing, COLOR_GHOST_MOVE)
		board.show_cells("ghost_kill", ghost["deaths"], COLOR_GHOST_KILL)
		# Реакции стихий, которые сработают от этой карты, — подсвечены своим цветом
		var by_kind: Dictionary = {}
		for k: String in REACTION_KINDS:
			by_kind[k] = [] as Array[Vector2i]
		for r: Dictionary in logic.predict_reactions(_active, _selected_card, cell):
			by_kind[r["kind"]].append(r["cell"])
		var colors: Dictionary = {"steam": COLOR_STEAM, "freeze": COLOR_FREEZE, "shatter": COLOR_SHATTER,
				"lava": COLOR_LAVA, "crust": COLOR_CRUST, "shock": COLOR_SHOCK}
		for k: String in REACTION_KINDS:
			board.show_cells("reaction_" + k, by_kind[k], colors[k])
	else:
		board.clear_layer("area")
		board.clear_layer("ghost_move")
		board.clear_layer("ghost_kill")
		for k: String in REACTION_KINDS:
			board.clear_layer("reaction_" + k)


# Навёл на врага — его зона угрозы подсвечивается ярче
func _show_hovered_enemy_threat(cell: Vector2i) -> void:
	var u: BattleUnit = logic.unit_at(cell)
	if u != null and not u.is_hero:
		board.show_cells("hover_threat", logic.get_threat_cells(u), COLOR_HOVER_THREAT)
		hud.show_enemy(u, logic)   # карточка врага справа: кто это, чем бьёт, особенности
	else:
		board.clear_layer("hover_threat")
		hud.show_enemy(null, logic)


# Режим сброса: следующая нажатая карта уходит в сброс (одна за ход)
var _discarding: bool = false
var _scrapping: bool = false   # включён режим «в ноги» (клавиша X): следующая карта сбрасывается бесплатно


func _on_discard_toggled() -> void:
	if _mode == Mode.BUSY:
		return
	if not _discarding and (_active == null or not logic.can_discard(_active, 0)):
		hud.update_discard_button(logic, _active, false, false)
		return
	_discarding = not _discarding
	_selected_card = -1
	_enter_idle()


func _on_card_pressed(index: int) -> void:
	if _mode == Mode.BUSY:
		return
	if _scrapping:
		var sh: BattleUnit = _active
		_scrapping = false
		_do(func() -> void: logic.scrap_card(sh, index))
		return
	if _discarding:
		var h: BattleUnit = _active
		_discarding = false
		_do(func() -> void: logic.discard_card(h, index))
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
	if _discarding:
		_discarding = false
		_enter_idle()
		return
	if _mode == Mode.AIMING:
		_enter_idle()


func _on_end_turn_pressed() -> void:
	if _mode != Mode.BUSY:
		_do(logic.end_turn)


# Выполняет действие в логике и проигрывает все анимации, которые оно вызвало
func _do(action: Callable) -> void:
	_mode = Mode.BUSY
	_selected_card = -1
	for layer: String in ["move", "target", "area", "hover_threat", "intent", "buff", "routes", "hazard_marks"]:
		board.clear_layer(layer)
	for k: String in REACTION_KINDS:
		board.clear_layer("reaction_" + k)
	_set_fire_forecast({})   # пока идут анимации, предупреждений об огне на плашках нет
	hud.show_enemy(null, logic)
	hud.refresh(logic, _active, -1, true)
	_discarding = false
	hud.update_discard_button(logic, _active, false, true)
	var is_end_turn: bool = action == logic.end_turn
	var action_start_ms: int = Time.get_ticks_msec()
	_enemy_phase_running = is_end_turn
	_apply_speed()
	action.call()
	await _play_queue()
	if is_end_turn:
		_enemy_phase_ms += Time.get_ticks_msec() - action_start_ms
	_enemy_phase_running = false
	_apply_speed()
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
	for k: String in REACTION_KINDS:
		board.clear_layer("reaction_" + k)
	var move_cells: Array[Vector2i] = []
	for c: Vector2i in logic.get_move_targets(_active):
		move_cells.append(c)
	board.show_cells("move", move_cells, COLOR_MOVE)
	_show_forecast()
	hud.refresh(logic, _active, -1, false)
	hud.update_discard_button(logic, _active, _discarding, false)


# Прогноз: линии — куда пойдёт каждый враг, красные клетки — куда он ударит,
# если прямо сейчас нажать «Конец хода». Пересчитывается после каждого действия.
func _show_forecast() -> void:
	var paths: Array = []
	var seen: Dictionary[Vector2i, bool] = {}
	var hits: Array[Vector2i] = []
	var buffs: Array[Vector2i] = []
	for plan: Dictionary in logic.forecast_enemies():
		(plan["enemy"] as BattleUnit).ai_reason = plan["reason"]   # карточка врага покажет, почему он так ходит
		paths.append(plan["path"])
		for c: Vector2i in plan["buff"]:
			if not buffs.has(c):
				buffs.append(c)
		for c: Vector2i in plan["attack"]:
			if not seen.has(c):
				seen[c] = true
				hits.append(c)
	# Остальное, что случится в ход врагов: взрывы бочек, падающие деревья, газ, огонь в конце раунда
	var hazards: Dictionary = logic.forecast_hazards()
	var marks: Array[Dictionary] = []
	for fx: Dictionary in hazards["effects"]:
		var fx_cells: Array[Vector2i] = fx["cells"]
		for c: Vector2i in fx_cells:
			if not seen.has(c):
				seen[c] = true
				hits.append(c)
		if fx["kind"] == "explosion":
			marks.append({"cell": _blast_center(fx_cells), "icon": "barrel", "color": Color(1.0, 0.85, 0.7)})
		elif fx["kind"] == "tree":
			marks.append({"cell": fx_cells[0], "icon": "tree", "color": Color(1.0, 0.85, 0.7)})
		elif fx["kind"] == "rune":
			marks.append({"cell": _blast_center(fx_cells), "icon": "rune_trap", "color": Color(0.9, 0.93, 1.0)})
	board.show_markers("hazard_marks", marks)
	_set_fire_forecast(hazards["fire"])
	board.show_routes(paths)
	board.show_cells("intent", hits, COLOR_INTENT)
	board.show_cells("buff", buffs, COLOR_BUFF)   # бирюзовое — кого шаман усилит «зовом»


# Центр взрыва: клетка, у которой в этом наборе все шесть соседей
func _blast_center(cells: Array[Vector2i]) -> Vector2i:
	for c in cells:
		var neighbours: int = 0
		for d: Vector2i in HexMath.DIRS:
			if cells.has(c + d):
				neighbours += 1
		if neighbours == 6:
			return c
	return cells[0]


# Запоминает прогноз огня и обновляет плашки тех, у кого предупреждение появилось или исчезло
func _set_fire_forecast(forecast: Dictionary) -> void:
	var changed: Array = _fire_forecast.keys() + forecast.keys()
	_fire_forecast = forecast
	for u: BattleUnit in logic.heroes + logic.enemies:
		if changed.has(u.id) and u.is_alive() and _views.has(u):
			_views[u].set_status(_plate_info(u, logic.snapshot(u)))


func _finish_battle() -> void:
	_print_battle_stats()
	board.clear_layer("intent")
	board.clear_layer("buff")
	board.clear_layer("routes")
	hud.show_banner("Победа!" if logic.won else "Поражение…")
	await get_tree().create_timer(1.5).timeout
	var hp_left: Array[int] = []
	for h in logic.heroes:
		hp_left.append(h.hp)
	Run.finish_battle(logic.won, hp_left)


# Скорость игры: ×2 только пока идёт ход врагов и включена кнопка, в остальное время обычная
func _apply_speed() -> void:
	Engine.time_scale = 2.0 if _enemy_phase_running and Run.fast_enemies else 1.0


# При выходе из боя скорость всегда возвращаем к обычной
func _exit_tree() -> void:
	Engine.time_scale = 1.0


# Одна строка в Output: сколько длился бой. «Секунд» включает и время на раздумья игрока,
# а «ход врагов» — только анимации после «Конец хода», по нему видно, сколько уходит на ожидание.
func _print_battle_stats() -> void:
	var row: int = Run.current.row if Run.current != null else -1
	var hp_text: PackedStringArray = []
	for i in logic.heroes.size():
		var h: BattleUnit = logic.heroes[i]
		hp_text.append("%s %d→%d" % [h.title, _start_hp[i] if i < _start_hp.size() else h.hp, h.hp])
	print("Бой: арена %s, ряд %d, раундов %d, секунд %.0f, из них ход врагов %.0f, HP: %s" % [
			logic.arena_title(), row, logic.turn,
			(Time.get_ticks_msec() - _battle_start_ms) / 1000.0, _enemy_phase_ms / 1000.0,
			", ".join(hp_text)])


# Переводит точку на экране в клетку поля:
# пускаем луч из камеры через курсор и смотрим, где он пересёк пол (высота 0)
func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var ray_from: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	var floor_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = floor_plane.intersects_ray(ray_from, ray_dir)
	if hit == null:
		return BattleLogic.NO_CELL  # луч ушёл в небо — клетки нет
	return board.world_to_grid(hit)



# ---------- Камера ----------

# Ставит камеру на «сферу» вокруг центра поля: угол поворота, наклон, расстояние
func _update_camera() -> void:
	# Точка взгляда чуть ближе к камере, чем центр поля: так поле встаёт выше и рука карт его не закрывает.
	# Число подобрано так, чтобы сверху влезали плашки дальних врагов, а снизу поле не уходило под карты.
	var look_shift := Vector3(0.0, 0.0, CAM_LOOK_SHIFT).rotated(Vector3.UP, deg_to_rad(_cam_yaw_deg))
	var center: Vector3 = board.field_center() + look_shift
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


# ПКМ по карте в руке (или Shift + цифра): отметить «удержать на следующий ход» или снять отметку
func _on_card_keep_toggled(index: int) -> void:
	if _mode == Mode.BUSY or _active == null or logic.is_over:
		return
	if not logic.toggle_keep(_active, index) and logic.can_keep(_active, index):
		hud.add_log("Удержать можно не больше %d карт" % BattleLogic.KEEP_LIMIT)
	hud.refresh(logic, _active, _selected_card, false)
