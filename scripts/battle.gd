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

const UNIT_LAYER: int = 2   # слой отрисовки фигурок (бит 2): видны камере, не попадают в зонд отражений
const VIGNETTE_SHADER: Shader = preload("res://assets/shaders/vignette.gdshader")   # края экрана в сумраке
const COLOR_MOVE := Color(0.72, 0.86, 0.88, 0.3)   # куда можно идти: бледный лунный контур (тонкий, без заливки)
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
const COLOR_OBJECTIVE := Color(0.84, 0.67, 0.34, 0.28)        # цель «Прорыв» — латунь
const COLOR_OBJECTIVE_WATER := Color(0.3, 0.55, 0.75, 0.35)   # ряд, который зальёт вода
const COLOR_PINCER := Color(0.84, 0.67, 0.34, 0.8)   # «Клещи» — латунь (UiKit.BRASS)
const REACTION_KINDS: Array[String] = ["steam", "freeze", "shatter", "lava", "crust", "shock", "pincer"]
const COLOR_BUFF := Color(0.37, 0.92, 0.83, 0.4)     # «зов» шамана: бирюза Раскола

# Ощущение удара от окружения (взрыв бочки, падение дерева). Всё можно подкрутить:
const SHAKE_TIME: float = 0.2             # сколько секунд трясётся камера
const SHAKE_POWER_EXPLOSION: float = 0.35  # сила тряски у взрыва (в метрах смещения)
const SHAKE_POWER_TREE: float = 0.2        # сила тряски у падения дерева
const HITSTOP_TIME: float = 0.08           # стоп-кадр: на столько секунд игра почти замирает
const HITSTOP_SCALE: float = 0.05          # …и идёт с такой скоростью (1.0 — без стоп-кадра)
const RAIN_CHANCE: float = 0.5             # в какой доле боёв идёт морось
const SHAKE_POWER_HERO_HIT: float = 0.06   # тряска, когда бьют героя
const SHAKE_POWER_BIG_HIT: float = 0.15    # …сильный удар (от VfxPlayer.BIG_HIT) или добивание
const SHAKE_POWER_BOSS: float = 0.3        # удар босса
# Цвет огонька при покорении духа (по id духа)
const SPIRIT_COLORS: Dictionary[String, Color] = {
	"spirit_tide": Color(0.45, 0.75, 1.0), "spirit_storm": Color(0.95, 0.95, 0.6),
	"spirit_wind": Color(0.72, 0.88, 0.76), "spirit_bog": Color(0.3, 0.5, 0.28),
	"spirit_fire": Color(1.0, 0.6, 0.2),
	"spirit_forest": Color(0.45, 0.75, 0.4),
	"spirit_ash": Color(0.74, 0.71, 0.66), "spirit_stone": Color(0.7, 0.64, 0.54),
	"spirit_steam": Color(0.88, 0.92, 0.95), "half_spirit": Color(0.45, 0.75, 1.0),
}

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
var _routes: Dictionary[BattleUnit, Array] = {}   # прогноз: путь каждого врага (клетки от него до места, куда встанет)
var _route_enemy: BattleUnit = null                # враг под курсором — его путь виден, даже если пути всех скрыты
var _anim_queue: Array[Callable] = []
var _cam_yaw_deg: float = 0.0     # поворот камеры вокруг поля
var _cam_dist: float = 15.0       # расстояние от центра поля
var _cam_tween: Tween
# Замер длины боя (пишется в Output в конце боя, см. _finish_battle)
var _battle_start_ms: int = 0     # когда начался бой
var _enemy_phase_ms: int = 0      # сколько всего длились ходы врагов (от «Конец хода» до конца анимаций)
var _start_hp: Array[int] = []    # здоровье героев в начале боя
var _start_enemies: int = 0       # сколько врагов было в начале (для журнала: сколько пришло потом)
var _cards_played: int = 0        # сыграно карт за бой (журнал боёв)
var _cards_scrapped: int = 0      # сброшено «в ноги» за шаги
var vfx: VfxPlayer                 # частицы, вспышки, цифры урона (scripts/vfx_player.gd)
var _last_hp: Dictionary[BattleUnit, int] = {}   # здоровье юнита на прошлом событии — чтобы заметить лечение
var _fire_forecast: Dictionary = {}   # прогноз огня: id юнита → урон в конце хода врагов
var _enemy_phase_running: bool = false   # идёт ход врагов (на нём работает «Скорость ×2»)
var _undo: Array[Dictionary] = []   # снимки боя перед каждым действием этого хода (последний — сверху)
var _undo_lock: String = ""          # почему отменить нельзя: "" — можно, иначе текст подсказки
var _fallen: Dictionary[BattleUnit, bool] = {}   # чья фигурка пала после начала хода (после отмены её пересоздаём)
var _boss_sign_hint: String = ""   # подсказка к знаку босса у края арены
var _impact_sound: String = "hit"        # какой звук удара прозвучит при уроне
var _last_chain_sounded: int = 0         # чтобы озвучить новый шаг «Цепи» один раз
# Учебный бой (scripts/tutorial/tutorial_battle.gd): null в обычном бою
var _tutor: TutorialBattle = null
var _tutor_pending: Array = []      # действие, которое засчитаем шагу после анимаций: [вид, герой, карта]
var _tutor_shown: int = -1          # какой шаг сейчас в окошке (чтобы не мигать им при каждом обновлении)
const COLOR_TUTOR := Color(0.95, 0.78, 0.35, 0.65)   # латунная метка «сюда»
# Подсказки при первой встрече (scripts/tutorial/hints.gd) — в том же окошке слева
var _hint_queue: Array[String] = []
var _hint_shown: String = ""        # какая подсказка сейчас в окошке ("" — окошко занято обучением или закрыто)


func _ready() -> void:
	Run.ensure_run()
	var layout_seed: int = Run.rng.randi()
	if Run.tutorial:
		_tutor = TutorialBattle.new()
		logic.keep_deck_order = true   # карты приходят в заданном порядке
	logic.setup(board.width, board.height, Run.rng, Run.party, Run.pending_enemies, Run.pending_arena,
			Run.pending_objective, Run.relics, Run.pending_formation())
	if _tutor != null:
		TutorialBattle.place_enemies(logic)
	if Run.pending_encounter != null:
		logic.set_waves(Run.pending_encounter.waves, Run.wave_extra())   # подкрепления (вожак, Певчая, огр)
	hud.relic_list = Run.relic_list()
	var sign: Array = Run.boss_sign_for(Run.current) if not Run.sim_no_scenes else []
	if not sign.is_empty():
		board.boss_sign = sign[0]
		_boss_sign_hint = Loc.t(sign[1])
	board.build(layout_seed, logic.arena_id, logic.ground)
	_show_flow_arrows()   # ветер Перевала и ленты Сборочного цеха
	var biome: String = BattleLogic.arena_biome(logic.arena_id)
	if biome == "deep":
		_warm_cave_light()   # Тлеющая пещера и всё Подземье акта 2
	elif biome == "ash":
		_ash_road_light()    # Пепельный тракт: бурая дымка, рыжий отсвет у горизонта
	_add_vignette()
	_add_reflection_probe()
	_update_camera()
	vfx = VfxPlayer.new()
	vfx.name = "Vfx"
	add_child(vfx)
	vfx.warm_up()
	board.vfx = vfx   # живой огонь, круги на воде, газ и т. п. на клетках
	# Атмосфера арены: огоньки, туман, мошкара; морось — в части боёв (выбор по сиду раскладки,
	# на правила и общий генератор случайностей не влияет)
	var rainy: bool = Settings.rain and posmod(hash(layout_seed), 100) < int(RAIN_CHANCE * 100.0)
	board.add_atmosphere(rainy)
	Sfx.enter_battle(logic.arena_id, _battle_kind(), rainy)
	_create_views()
	_connect_logic()
	hud.card_pressed.connect(_on_card_pressed)
	hud.card_keep_toggled.connect(_on_card_keep_toggled)
	hud.hero_pressed.connect(_on_hero_pressed)
	hud.end_turn_pressed.connect(_on_end_turn_pressed)
	hud.speed_toggled.connect(_apply_speed)
	hud.discard_toggled.connect(_on_discard_toggled)
	hud.undo_pressed.connect(_on_undo_pressed)
	# Поменяли настройки на паузе (дальтоники и т. п.) — перерисовать поле
	Settings.changed.connect(func() -> void:
		if _mode == Mode.IDLE and not logic.is_over:
			_show_forecast())
	hud.tutor.next_pressed.connect(_on_panel_next)
	hud.tutor.skip_pressed.connect(_on_panel_skip)
	if _tutor != null:
		Hints.mark_seen("enemy_card")   # про карточку врага рассказывает сам учебный бой

	# В начале боя — название арены и отряда врагов: «Старая гать · Стая»
	var start_title: String = logic.arena_title()
	if Run.pending_encounter != null and Run.pending_encounter.title != "":
		start_title += ("  ·  " if start_title != "" else "") + Run.pending_encounter.title
	hud.show_arena(start_title)
	_battle_start_ms = Time.get_ticks_msec()
	for h in logic.heroes:
		_start_hp.append(h.hp)
	_start_enemies = logic.enemies.size()
	logic.card_played.connect(func(_c: BattleUnit, _card: CardData, is_scrap: bool) -> void:
		if is_scrap: _cards_scrapped += 1
		else: _cards_played += 1)
	logic.party_has_rust = Run.party_has_spirit("rust")
	logic.party_has_magma = Run.party_has_spirit("magma")
	_mode = Mode.BUSY
	logic.start()
	if Run.is_elite_battle() and Run.bog_spirit_offered():
		logic.message.emit(Loc.t("В корнях корягача спит Хозяин трясины: утопи %d врагов в трясине — и он пойдёт с тобой.") % Run.BOG_SPIRIT_DROWNS)
	# Подсказка про новые объекты арены — одной строкой в журнале в начале боя
	if BattleLogic.is_forest_arena(logic.arena_id):
		logic.message.emit(Loc.t("Лес: лоза держит того, кто на неё встал (удар картой срубает), деревья с лентой закрывают линии и горят, улей — рой с ядом."))
	elif BattleLogic.ARENA_HINTS.has(logic.arena_id):
		logic.message.emit(BattleLogic.ARENA_HINTS[logic.arena_id])
	elif logic.arena_id == "pump":
		logic.message.emit(Loc.t("Насосная: удар по клапану — пар обжигает и отбрасывает соседей, вокруг разливается вода."))
	if Run.vessel_spirit_offered():
		logic.message.emit(Loc.t("В клетке Сосуда бьётся Сердце Жерла: облей Сосуд водой %d раза до победы — и оно пойдёт с тобой.") % BattleLogic.VESSEL_WATER_HITS)
	if Run.is_elite_battle() and Run.forest_spirit_offered():
		logic.message.emit(Loc.t("Леший смотрит из чащи: победи Голос Рощи, не спалив ни дерева, ни лозы, — и он пойдёт с тобой."))
	await _play_queue()
	# В обучении первым ходит Рыцарь (так задуман сценарий), обычно — первый живой герой
	_select_hero(logic.heroes[1] if _tutor != null else logic.living_heroes()[0])
	# Что особенного в этом бою — подсказки один раз за игру
	_offer_hint("enemy_card")
	if Run.is_elite_battle():
		_offer_hint("elite")
	if logic.objective != BattleLogic.Objective.KILL_ALL:
		_offer_hint("objective")
	if not logic.waves.is_empty():
		_offer_hint("waves")
	if logic.objects.values().has(BattleLogic.Obj.BARREL):
		_offer_hint("barrel")
	_enter_idle()


# ---------- Создание фигурок ----------

# Фигурка врага: модель (или капсула-заглушка), лицом к героям, с плашкой над головой
# Светящиеся детали поверх моделей: [кость, точка в осях модели, радиус, растяжение]
const GLOW_PARTS: Dictionary = {
	"glass_spitter": ["Head", Vector3(0.0, 1.52, 0.4), 0.088, Vector3(1.0, 1.2, 1.1)],   # зоб Плевуна
}
const GLOW_WATER := Color(0.3, 0.6, 1.0)    # зоб полон воды — следующий плевок водяной
const GLOW_FIRE := Color(1.0, 0.42, 0.08)    # зоб раскалён — следующий плевок огненный


func _make_enemy_view(e: BattleUnit) -> Unit:
	var view: Unit = _spawn_view(e.data.id.capitalize(), e.cell)
	view.flier = e.data.flier   # падальщик перелетает, а не идёт
	if e.data.is_boss or e.data.size >= 1.25:
		view.step_pitch = 0.84
	elif e.data.size <= 0.8:
		view.step_pitch = 1.14
	if e.data.model != null:
		var model: Node3D = e.data.model.instantiate()
		view.add_child(model)
		view.setup_animations()   # Idle, Walk, Attack, Hit, Death из модели
		if GLOW_PARTS.has(e.data.id):
			var g: Array = GLOW_PARTS[e.data.id]
			view.add_glow_part(model, g[0], g[1], g[2], g[3])
	else:
		view.add_child(_make_capsule_model(e.data.color, e.data.size, false))
	view.face_dir(HexMath.direction_to(e.cell, logic.heroes[0].cell))
	if e.asleep:
		view.set_meta("no_rim", true)   # спящая сфера неотличима от постамента: каймы нет, пока не проснётся
	else:
		vfx.add_rim(view)   # светлая кайма по контуру — фигурка отделяется от плит
	_put_on_unit_layer(view)
	view.setup_label(1.4 * e.data.size + 0.55)
	view.set_status(_plate_info(e, logic.snapshot(e)))
	_views[e] = view
	_last_hp[e] = e.hp
	vfx.enemy_ambient(view, e.data.id if e.data != null else "", _unit_height(e))   # споры у споровика
	return view


# Фигурка героя: модель (или капсула-заглушка), лицом к врагам, с плашкой
func _make_hero_view(h: BattleUnit) -> Unit:
	var view: Unit = _spawn_view(h.hero_data.id.capitalize(), h.cell)
	if h.hero_data.model != null:
		view.add_child(h.hero_data.model.instantiate())
		view.setup_animations()   # если в модели есть анимации — включаем Idle
	else:
		view.add_child(_make_capsule_model(h.hero_data.color, 1.1, true))
	view.face_dir(HexMath.FACE_UP)   # лицом к врагам
	vfx.add_rim(view)   # светлая кайма по контуру
	_put_on_unit_layer(view)
	view.setup_label(2.0)
	view.visible = h.is_alive()
	_views[h] = view
	_last_hp[h] = h.hp
	return view


func _create_views() -> void:
	for h in logic.heroes:
		_make_hero_view(h)

	for e in logic.enemies:
		_make_enemy_view(e)

	for c: Vector2i in logic.rocks:
		board.add_rock(c)
	for c: Vector2i in logic.objects:
		board.add_object(c, logic.objects[c])
	for c: Vector2i in logic.tiles:
		board.set_tile_effect(c, logic.tiles[c])
	for u: BattleUnit in _views:
		_views[u].set_status(_plate_info(u, logic.snapshot(u)))
		vfx.set_auras(_views[u], _unit_height(u), logic.snapshot(u))   # капли, яд, руна и т. п.
		if u.is_hero and not u.spirits.is_empty():
			vfx.add_companions(_views[u], u.spirits, _unit_height(u))   # огоньки прирученных духов у плеча
	_update_ritual_circle()

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
		if state.get("holding_line", false):
			marks.append("hold_line")
	else:
		# Намерение врага: значок по форме удара и урон в этом раунде
		var shape: int = logic.enemy_attack(u).shape
		info["intent_icon"] = INTENT_ICONS[shape] if shape < INTENT_ICONS.size() else "sword"
		info["intent_value"] = state["damage"]
		info["intent_color"] = UiKit.RIFT if shape == EnemyData.Attack.AURA else UiKit.threat()
		# Тлеющая жаба: вместо обычного удара — фитиль (с уроном взрыва, если уже горит)
		if state.get("fuse", 0) > 0 or state.get("smoldering", false):
			info["intent_icon"] = "fuse"
			info["intent_color"] = UiKit.threat()
		# Спит (Спящая сфера) или «замыкание» механизма: в этот ход не ударит
		if state.get("asleep", false):
			info["intent_icon"] = "hourglass"
			info["intent_color"] = UiKit.TEXT_DIM
		elif state.get("stunned", 0) > 0:
			info["intent_icon"] = "bolt"
			info["intent_color"] = UiKit.TEXT_DIM
		if state.get("shell", 0) > 0:
			marks.append("num:orb:%d" % state["shell"])   # сколько ударов ещё держит сфера духа
		# Модификатор врага: значок бирюзы — тусклый, пока не сработал, яркий — когда сработал
		if state.get("mod", "") != "":
			marks.append(("mod_on:" if state.get("mod_on", false) else "mod:") + state["mod"])
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
	if state.get("brand", 0) > 0:
		marks.append("num:target:+%d" % BattleLogic.BRAND_BONUS)   # клеймо Культа
	if state.get("rust", 0) > 0:
		marks.append("num:drain:-%d" % BattleLogic.RUST_WEAKEN)   # ржавчина: удар слабее
	# «Ритуал»: над ритуалистом — сколько раундов до призыва
	if logic.objective == BattleLogic.Objective.RITUAL and u.id == logic.ritual_caster_id and u.is_alive():
		marks.append("ritual")
		info["ritual_turns"] = logic.ritual_timer
	info["marks"] = marks
	info["asleep"] = state.get("asleep", false)
	if not u.is_hero and GLOW_PARTS.has(u.data.id):
		# Зоб показывает, каким будет плевок в этом раунде
		var spit: EnemyAttackData = logic.enemy_attack(u)
		info["glow_color"] = GLOW_FIRE if spit.ignite else GLOW_WATER
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
	logic.rock_added.connect(func(c: Vector2i) -> void: _queue(func() -> void: board.add_rock(c, "rock_slag")))
	logic.object_moved.connect(_on_object_moved)
	logic.effect_cells.connect(_on_effect_cells)
	logic.reaction.connect(_on_reaction)
	logic.card_cast.connect(_on_card_cast)
	logic.enemy_attacked.connect(_on_enemy_attacked)
	logic.enemy_buffed.connect(_on_enemy_buffed)
	logic.message.connect(_on_message)
	logic.unit_spawned.connect(_on_unit_spawned)
	logic.objective_changed.connect(_on_objective_changed)
	logic.fx_hint.connect(_on_fx_hint)


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
	_queue(func() -> void:
		await view.play_push(path, bumped)
		if bumped:
			vfx.bump(view.global_position)   # врезался: кольцо, пыль, искры
	)


func _on_unit_damaged(unit: BattleUnit, amount: int, state: Dictionary) -> void:
	var view: Unit = _views[unit]
	var info: Dictionary = _plate_info(unit, state)
	_last_hp[unit] = state.get("hp", unit.hp)
	# Что показать (собираем сейчас: к моменту анимации юнит может быть уже другим)
	var source: String = state.get("source", "")
	var absorbed: int = state.get("absorbed", 0)
	var hit_info: Dictionary = {
		"dealt": amount, "absorbed": absorbed, "source": source,
		"element": state.get("element", -1),
		"broke": absorbed > 0 and state.get("block", 0) == 0,
		"killed": state.get("hp", 1) <= 0,
		"material": VfxPlayer.material_of(unit.data.id if unit.data != null else "",
				unit.hero_data.id if unit.hero_data != null else ""),
	}
	var height: float = _unit_height(unit)
	var big: bool = amount >= VfxPlayer.BIG_HIT or hit_info["killed"]
	# Урон «тиками» конца раунда (огонь, лава, яд, газ) — без тряски и стоп-кадра, иначе раунд дёргается
	var tick: bool = source in ["fire", "lava", "poison", "gas"]
	var is_hero: bool = unit.is_hero
	if amount <= 0 and absorbed <= 0:
		_queue(func() -> void: _show_status(unit, view, info, state))
		return
	_queue(func() -> void:
		if tick:
			var tick_snd: String = "gas_cloud" if (source == "poison" or source == "gas") else ("lava" if source == "lava" else "fire")
			Sfx.play(tick_snd, 0.08, -6.5)
		elif amount <= 0:
			Sfx.play("block", 0.08)
		else:
			if hit_info["broke"]:
				Sfx.play("shield_break", 0.06)
			Sfx.play("heavy_hit" if big else _impact_sound, 0.08)
		_show_status(unit, view, info, state)
		vfx.hit(view, height, hit_info)
		if not tick and amount > 0:
			if big:
				_shake(SHAKE_POWER_BIG_HIT)
				await _hit_stop()
			elif is_hero:
				_shake(SHAKE_POWER_HERO_HIT)
		await view.play_hit()
	)


# Рост фигурки в метрах — куда ставить искры и цифры
func _unit_height(unit: BattleUnit) -> float:
	if unit.is_hero:
		return 1.65
	return 1.4 * unit.data.size if unit.data != null else 1.4


func _on_unit_died(unit: BattleUnit) -> void:
	var view: Unit = _views[unit]
	_fallen[unit] = true
	var height: float = _unit_height(unit)
	_queue(func() -> void: vfx.clear_auras(view))   # капли, яд и прочее гаснут
	if logic.object_at(unit.cell) == BattleLogic.Obj.BOG:
		_queue(func() -> void:
			Sfx.play("sink", 0.06)
			vfx.sink(view)
			await view.play_sink()
		)   # утонул в трясине
	elif unit.is_hero:
		_queue(func() -> void:
			Sfx.play("death_hero", 0.05)
			vfx.burst("dust", view.global_position + Vector3(0.0, 0.2, 0.0), 1.5)
			await view.play_death()
		)
	elif unit.data != null and unit.data.tamable:
		# Дух не гибнет, а покоряется: вспышка цвета его стихии
		var color: Color = SPIRIT_COLORS.get(unit.data.id, VfxPlayer.C_RIFT)
		_queue(func() -> void:
			Sfx.play("spirit_tame", 0.04)
			vfx.death(view, height, "spirit", color)
			await view.play_death()
		)
	else:
		# Враг: падает (если есть анимация) и растворяется — твари бирюзой, Культ пеплом.
		# Очередь ждёт только начало растворения, остальное доигрывает фоном.
		var kind: String = _death_kind(unit)
		_queue(func() -> void:
			Sfx.play("death", 0.07)
			if view.start_death():
				await get_tree().create_timer(0.35).timeout
			vfx.death(view, height, kind)
			await get_tree().create_timer(0.3).timeout
		)


# Как исчезает павший враг (VfxPlayer.death): твари — бирюзой Раскола (вулканические — ещё и пеплом),
# Культ — пеплом, механизмы разваливаются с искрами и паром, мародёры — в клубе пыли
func _death_kind(unit: BattleUnit) -> String:
	if unit.data == null:
		return "rift"
	if unit.data.cult:
		return "cult"
	if unit.data.machine:
		return "machine"
	if unit.data.id.begins_with("scav_"):
		return "scav"
	if VfxPlayer.material_of(unit.data.id) == "cinder":
		return "cinder"
	return "rift"


# Враг появился посреди боя (ритуал, подкрепление): фигурка возникает в очереди анимаций
func _on_unit_spawned(unit: BattleUnit) -> void:
	# Фигурку создаём сразу (логика может тут же прислать для неё status_changed),
	# а показываем в свою очередь анимаций
	var view: Unit = _make_enemy_view(unit)
	view.visible = false
	view.set_status(_plate_info(unit, logic.snapshot(unit)))
	_queue(func() -> void:
		# Призыв: бирюзовый разрыв в земле, враг поднимается из него
		Sfx.play("summon", 0.06)
		view.visible = true
		vfx.summon(view.global_position)
		view.scale = Vector3.ONE * 0.3
		var tween: Tween = view.create_tween()
		tween.tween_property(view, "scale", Vector3.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	)


# Цель боя обновилась: подсветка верхнего ряда («Прорыв») или ряда, который зальёт вода
func _on_objective_changed() -> void:
	var cells: Array[Vector2i] = logic.objective_cells()
	var color: Color = COLOR_OBJECTIVE_WATER if logic.objective == BattleLogic.Objective.RISING_WATER else COLOR_OBJECTIVE
	_queue(func() -> void: board.show_cells("objective", cells, color))
	_update_ritual_circle()


# Круг ритуала под ритуалистом: ярче и шире с каждым раундом до призыва (VfxPlayer.set_ritual)
func _update_ritual_circle() -> void:
	if logic.objective != BattleLogic.Objective.RITUAL:
		return
	var caster: BattleUnit = null
	for e in logic.enemies:
		if e.id == logic.ritual_caster_id:
			caster = e
	if caster == null or not _views.has(caster):
		return
	var view: Unit = _views[caster]
	var progress: float = -1.0
	if caster.is_alive():
		progress = clampf(1.0 - float(logic.ritual_timer - 1) / float(BattleLogic.RITUAL_TURNS - 1), 0.0, 1.0)
	_queue(func() -> void: vfx.set_ritual(view, progress))


# Подсказки логики для эффектов: шаман поглощает магию, сгорела броня корягача, послушник отдал венец
func _on_fx_hint(kind: String, unit: BattleUnit, other: BattleUnit) -> void:
	if not _views.has(unit):
		return
	var view: Unit = _views[unit]
	var height: float = _unit_height(unit)
	# Позиции — по клеткам логики: фигурки к этому моменту ещё могут догонять ход
	var other_at: Vector3 = board.grid_to_world(other.cell) if other != null else view.global_position
	match kind:
		"absorb":
			_queue(func() -> void:
				Sfx.play("absorb_magic", 0.06)
				await vfx.absorb(other_at + Vector3(0.0, 1.1, 0.0), view, height))
		"armor_burnt":
			_queue(func() -> void:
				Sfx.play("fire", 0.07, -3.0)
				vfx.armor_burn(view, height))
		"modifier":   # сработал модификатор врага — вспышка бирюзы Раскола
			_queue(func() -> void:
				Sfx.play("magic", 0.08, -4.0)
				vfx.flash(view, UiKit.RIFT, 1.2))
		"bequest":
			_queue(func() -> void:
				Sfx.play("absorb_magic", 0.06)
				await vfx.bequest(other_at, view, height))
		# Механики акта 2: свой эффект в момент, когда состояние легло
		"short":   # замыкание механизма — треск разрядов и мигание
			_queue(func() -> void:
				Sfx.play("lightning", 0.08, -6.0)
				vfx.short_circuit(view, height))
		"rust":    # ржавчина — бурые хлопья осыпаются, броня тускнеет
			_queue(func() -> void:
				Sfx.play("ice_break", 0.1, -8.0, 0.7)
				vfx.rust_burst(view, height))
		"brand":   # клеймо Культа — бледный знак вспыхивает над головой
			_queue(func() -> void:
				Sfx.play("rune_cast", 0.08, -4.0)
				vfx.brand_mark(view, height))
		"wake":    # Спящая сфера просыпается — кольцо бирюзы и блики
			_queue(func() -> void:
				Sfx.play("magic", 0.08, -2.0, 0.8)
				vfx.wake_up(view, height))


func _on_status_changed(unit: BattleUnit, state: Dictionary) -> void:
	var view: Unit = _views[unit]
	if view.has_meta("no_rim") and not state.get("asleep", false):
		view.remove_meta("no_rim")
		vfx.add_rim(view)   # сфера проснулась — теперь видна как враг
	var info: Dictionary = _plate_info(unit, state)
	var hp: int = state.get("hp", unit.hp)
	var healed: int = hp - _last_hp.get(unit, hp)
	_last_hp[unit] = hp
	# Лечение (шаман, карты, «Встань» после победы) — тёплые искры и «+N»
	if healed > 0 and view.visible:
		var height: float = _unit_height(unit)
		_queue(func() -> void:
			Sfx.play("heal", 0.05, -5.0)
			_show_status(unit, view, info, state)
			vfx.heal(view, height, healed)
		)
		return
	_queue(func() -> void: _show_status(unit, view, info, state))


# Плашка над фигуркой и постоянные эффекты состояний (капли, яд, тина, руна, провокация, фитиль)
func _show_status(unit: BattleUnit, view: Unit, info: Dictionary, state: Dictionary) -> void:
	view.set_status(info)
	if state.get("hp", 1) <= 0:
		vfx.clear_auras(view)
	else:
		vfx.set_auras(view, _unit_height(unit), state)


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
	elif kind == "pincer":
		color = COLOR_PINCER
	elif kind == "tree_fire":
		color = COLOR_LAVA
	var cells: Array[Vector2i] = [cell]
	var sound: String = "steam"
	match kind:
		"steam":
			sound = "steam"
		"lava":
			sound = "lava"
		"crust":
			sound = "crust"
		"freeze":
			sound = "ice"
		"shatter":
			sound = "ice_break"
		"shock":
			sound = "lightning"
		"pincer":
			sound = "pincer_hit"
		_:
			sound = "fire"
	var at: Vector3 = board.grid_to_world(cell)
	_queue(func() -> void:
		Sfx.play(sound, 0.07)
		board.show_cells("flash", cells, color)
		vfx.reaction(at, kind)
		await get_tree().create_timer(0.2).timeout
		board.clear_layer("flash")
	)


# Стрелки на полу: куда дует ветер (Перевал) и куда везут ленты (Сборочный цех)
func _show_flow_arrows() -> void:
	var arrows: Array = []
	if logic.wind_dir != Vector2i.ZERO:
		for row: int in [1, 4, 7]:
			for col: int in [2, 6, 10]:
				var c: Vector2i = HexMath.from_column(col, row)
				if logic.rocks.has(c):
					continue
				arrows.append([c, c + logic.wind_dir])
	if not arrows.is_empty():   # ветер — крупные тёмные стрелки, на светлом пепле так виднее
		board.show_flow_arrows("flow", arrows, Color(0.2, 0.24, 0.3), 0.75)
	arrows = []
	for c: Vector2i in logic.belts:
		arrows.append([c, logic.belts[c]])
	if not arrows.is_empty():
		board.show_flow_arrows("belts", arrows, Color(0.62, 0.7, 0.78))


func _on_effect_cells(cells: Array[Vector2i], kind: String) -> void:
	var color: Color = COLOR_TREE_FALL
	if kind == "explosion":
		color = COLOR_EXPLOSION
	elif kind == "gas":
		color = COLOR_GAS
	elif kind == "rune":
		color = COLOR_RUNE
	elif kind == "swarm":
		color = COLOR_GAS
	elif kind == "steam_vent":
		color = COLOR_STEAM
	elif kind == "lightning":
		color = Color(0.95, 0.92, 0.55)
	elif kind == "wind":
		color = Color(0.75, 0.88, 0.78)
	elif kind == "splash":
		color = COLOR_STEAM
	# Цифры урона над задетыми теперь показывает сам урон (_on_unit_damaged → VfxPlayer)
	var world: Array[Vector3] = []
	for c in cells:
		world.append(board.grid_to_world(c))
	_queue(func() -> void:
		board.show_cells("flash", cells, color)
		_effect_vfx(kind, world)
		match kind:
			"gas":
				Sfx.play("gas_cloud", 0.08)
			"explosion":
				Sfx.play("explosion", 0.06)
				_shake(SHAKE_POWER_EXPLOSION)
				await _hit_stop()
			"tree":
				Sfx.play("tree_crash", 0.06)
				_shake(SHAKE_POWER_TREE)
				await _hit_stop()
			"rune":
				Sfx.play("rune_trap", 0.06)
				_shake(SHAKE_POWER_TREE)
				await _hit_stop()
			_:
				Sfx.play("magic", 0.06)
		await get_tree().create_timer(0.25).timeout
		board.clear_layer("flash")
	)


# Эффект на поле: взрыв, падение дерева, газ, руна (VfxPlayer)
func _effect_vfx(kind: String, world: Array[Vector3]) -> void:
	if world.is_empty():
		return
	match kind:
		"explosion":
			var center: Vector3 = Vector3.ZERO
			for w in world:
				center += w
			center /= world.size()
			var radius: float = 2.0 if world.size() > 7 else 1.0
			if world.size() <= 1:
				radius = 0.6
			vfx.explosion(center, radius)
		"tree":
			vfx.tree_fall(world)
		"gas":
			vfx.gas_cloud(world)
		"swarm":   # рой из улья: тёмные точки над клетками
			for w in world:
				vfx.burst("glints", w + Vector3(0.0, 0.6, 0.0), 0.8, 0, Color(0.45, 0.38, 0.2))
		"steam_vent":   # клапан насосной: пар во все стороны
			for w in world:
				vfx.reaction(w, "steam")
		"rune":
			for w in world:
				vfx.burst("glints", w + Vector3(0.0, 0.5, 0.0), 1.0, 0, VfxCards.TINTS["rage"])
				vfx.ring(w + Vector3(0.0, 0.05, 0.0), VfxCards.TINTS["rage"], 1.3, 0.35, 1.8)


# Тряска камеры: смещаем «объектив» (h_offset / v_offset), поворот и зум камеры не трогаем
func _shake(power: float) -> void:
	power *= Settings.shake   # сила из настроек: 0 — без тряски
	if power <= 0.0:
		return
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


func _on_card_cast(caster: BattleUnit, card: CardData, cells: Array[Vector2i]) -> void:
	var view: Unit = _views[caster]
	var from_cell: Vector2i = caster.cell
	var dir: Vector2i = Vector2i.ZERO
	if not cells.is_empty():
		dir = HexMath.direction_to(from_cell, cells[0])
	var is_mage: bool = caster.is_hero and caster.hero_data != null and caster.hero_data.id == "mage"
	# Эффект карты (VfxCards): подбираем звук каста, звук попадания и отклик Цепи
	var picked: Array[String] = VfxCards.pick(card)
	var form: String = picked[0]
	var tint: String = picked[1]
	var cast_sound: String = "card_play"
	var impact: String = "hit"
	if card.id == "k_bell" or card.id.begins_with("kb_bell"):
		cast_sound = "bell"
		impact = "heavy_hit"
	elif card.special.begins_with("rune_"):
		cast_sound = "rune_cast"
		impact = "sword_hit"
	elif tint == "fire":
		cast_sound = "fire"
		impact = "heavy_hit" if card.damage >= 8 else "hit"
	elif tint == "water":
		cast_sound = "water"
		impact = "hit"
	elif tint == "lightning":
		cast_sound = "lightning"
		impact = "heavy_hit" if card.damage >= 8 else "hit"
	elif tint == "steam":
		cast_sound = "steam"
		impact = "hit"
	elif tint == "wind":
		cast_sound = "wind_gust"
		impact = "hit"
	elif tint == "bog":
		cast_sound = "bog_cast"
		impact = "hit"
	elif form == "guard":
		cast_sound = "block"
		impact = "sword_hit"
	elif form == "melee" or form == "bash":
		cast_sound = "sword_swing" if card.damage > 0 else "push"
		impact = "sword_hit"
	elif form == "dash":
		cast_sound = "push"
		impact = "sword_hit"
	elif form == "staff":
		cast_sound = "card_play"
		impact = "staff_hit"
	elif is_mage or form == "buff" or tint == "arcane":
		cast_sound = "magic"
		impact = "staff_hit"

	var world_cells: Array[Vector3] = []
	for c in cells:
		world_cells.append(board.grid_to_world(c))
	var chain_now: int = logic.chain_value()
	var chain_rose: bool = chain_now > _last_chain_sounded and chain_now > 0
	if chain_rose:
		_last_chain_sounded = chain_now
	var sky: bool = picked[1] == "lightning" or card.special == "meteor"
	_queue(func() -> void:
		_impact_sound = impact
		Sfx.play(cast_sound, 0.06)
		if chain_rose:
			Sfx.play("chain_up", 0.02, -5.5, 1.0 + minf(float(chain_now), 5.0) * 0.06)
		view.face_dir(dir)
		# Выбираем анимацию героя под эффект карты:
		# Маг: CastSky (молния, метеор, рывок), Cast (заклинания), Block (щит), Attack (посох)
		# Рыцарь: Attack (удары), Block (щит и провокация)
		if form == "guard" and view.has_anim("Block"):
			await view.play_block()
		elif is_mage and (sky or form == "dash") and view.has_anim("CastSky"):
			await view.play_cast_sky(dir)
		elif is_mage and form != "staff" and view.has_anim("Cast"):
			await view.play_cast(dir)
		elif (card.damage > 0 or form == "melee" or form == "bash" or form == "staff") and view.has_anim("Attack") and dir != Vector2i.ZERO:
			await view.play_attack(dir)

		board.show_cells("flash", cells, COLOR_FLASH)
		await VfxCards.play(vfx, card, view, world_cells, chain_now)
		board.clear_layer("flash")
	)


func _on_enemy_attacked(unit: BattleUnit, dir: Vector2i, cells: Array[Vector2i]) -> void:
	var view: Unit = _views[unit]
	var anim_name: String = logic.enemy_attack(unit).anim   # у ударов из цикла может быть своя анимация
	var is_boss: bool = unit.data != null and unit.data.is_boss
	var eid: String = unit.data.id if unit.data != null else ""
	var atk_sound: String = _enemy_attack_sound(eid)
	_queue(func() -> void:
		_impact_sound = "heavy_hit" if is_boss else "hit"
		Sfx.play(atk_sound, 0.08, 0.0, 0.85 if is_boss else 1.0)
		board.show_cells("flash", cells, COLOR_INTENT)
		await view.play_attack(dir, anim_name)
		if is_boss:
			_shake(SHAKE_POWER_BOSS)
		board.clear_layer("flash")
	)


# «Зов»: враг не бьёт, а усиливает своих — бирюзовая вспышка по кругу вокруг зовущего
func _on_enemy_buffed(unit: BattleUnit, cells: Array[Vector2i]) -> void:
	var view: Unit = _views[unit]
	_queue(func() -> void:
		Sfx.play("enemy_buff", 0.05)
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
	_pick_hero(logic.heroes[index])


# Выбрать героя по просьбе игрока (клик, панель, Tab) — с проверкой обучения
func _pick_hero(h: BattleUnit) -> void:
	if h == null:
		return
	if _tutor != null and h != _active and not _tutor.allows_hero(h.hero_data.id):
		_tutor_nudge()
		return
	_select_hero(h)
	if _tutor != null:
		_tutor.action_done("hero", h.hero_data.id)
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
	if event is InputEventMouseMotion and _boss_sign_hint != "":
		_check_boss_sign((event as InputEventMouseMotion).position)
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
		if _tutor != null and not _tutor.allows_extra():
			_tutor_nudge()
			return
		_scrapping = not _scrapping
		_discarding = false
		_selected_card = -1
		_enter_idle()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_Z:
		_on_undo_pressed()   # Z или Ctrl+Z — отменить последнее действие (держать — отменять дальше)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_TAB:
		_pick_hero(_next_hero())
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
		# Esc сначала отменяет выбор карты или сброс; если отменять нечего — откроется пауза (Settings)
		if _discarding or _scrapping or _mode == Mode.AIMING:
			get_viewport().set_input_as_handled()
			if _scrapping and not _discarding and _mode != Mode.AIMING:
				_scrapping = false
				Sfx.play("card_cancel", 0.05)
				_enter_idle()
			else:
				_scrapping = false
				_cancel_card()


func _on_cell_clicked(cell: Vector2i) -> void:
	match _mode:
		Mode.IDLE:
			var clicked: BattleUnit = logic.unit_at(cell)
			if clicked != null and clicked.is_hero:
				_pick_hero(clicked)   # клик по герою — выбрать его
			elif logic.get_move_targets(_active).has(cell):
				var h: BattleUnit = _active
				if _tutor != null:
					if not _tutor.allows_move(h.hero_data.id, cell):
						_tutor_nudge()
						return
					_tutor_pending = ["move", h.hero_data.id, ""]
				_do(func() -> void: logic.move_hero(h, cell))
		Mode.AIMING:
			if logic.get_card_targets(_active, _selected_card).has(cell):
				var h: BattleUnit = _active
				var index: int = _selected_card
				if _tutor != null:
					if not _tutor.allows_target(cell):
						_tutor_nudge()   # не та клетка: карта остаётся выбранной
						return
					_tutor_pending = ["card", h.hero_data.id, h.hand[index].id]
				hud.burst_hand_card(index, h.hand[index])   # карта рассыпается искрами
				_do(func() -> void: logic.play_card(h, index, cell))
			else:
				_cancel_card()


func _on_hover(cell: Vector2i) -> void:
	_hover_cell = cell
	_show_hovered_enemy_threat(cell)
	if _mode == Mode.AIMING and logic.get_card_targets(_active, _selected_card).has(cell):
		board.show_cells("area", logic.get_card_area(_active, _selected_card, cell), COLOR_AREA)
		_show_card_preview(cell)
	else:
		board.clear_layer("area")
		_clear_preview()


# ---------- Точный предпросмотр карты ----------
# Карта «проигрывается» на копии боя (BattleLogic.preview_card) — показано ровно то,
# что случится: урон и гибель на плашках, сдвиги, реакции, цепочка бочек и разрядов
# по порядку, новые огонь, вода, лёд и дым, урон по своим, итог справа внизу.

const PREVIEW_TILE_COLORS: Dictionary = {   # клетки, которые станут огнём, водой… — бледно
	BattleLogic.Tile.FIRE: Color(1.0, 0.55, 0.15, 0.32), BattleLogic.Tile.WATER: Color(0.3, 0.6, 1.0, 0.32),
	BattleLogic.Tile.ICE: Color(0.75, 0.92, 1.0, 0.32), BattleLogic.Tile.SMOKE: Color(0.62, 0.62, 0.64, 0.32),
	BattleLogic.Tile.GAS: Color(0.6, 0.95, 0.4, 0.32),
}
const COLOR_CHAIN := Color(1.0, 0.6, 0.15, 0.4)       # клетки цепочки (взрывы, газ, разряды)
const COLOR_CHAIN_NUMBER := Color(1.0, 0.86, 0.5)     # номер звена цепочки
const COLOR_SELF_HIT := Color(1.0, 0.62, 0.2)         # урон по своим — оранжевое предупреждение
const REACTION_NAMES: Dictionary = {"steam": "пар", "freeze": "заморозка", "shatter": "осколки льда",
	"lava": "лава", "crust": "корка", "shock": "молния по мокрому", "pincer": "клещи", "tree_fire": "горит дерево"}
const CHAIN_NAMES: Dictionary = {"explosion": "взрыв", "gas": "газ", "tree": "дерево падает", "lightning": "разряд",
	"rune": "руна", "splash": "купель", "steam_vent": "пар клапана", "swarm": "рой", "wind": "ветер"}
const STATUS_NAMES: Dictionary = {"wet": "мокрые", "poison": "яд", "entangled": "опутаны", "rust": "ржавчина",
	"stunned": "замыкание", "brand": "клеймо"}
const PREVIEW_LAYERS: Array[String] = ["ghost_move", "ghost_kill", "chain_cells", "chain_numbers",
	"ghost_tile_1", "ghost_tile_2", "ghost_tile_3", "ghost_tile_5", "ghost_tile_6"]

var _preview_key: String = ""          # для чего посчитан предпросмотр (герой, карта, клетка)
var _preview: Dictionary = {}
var _previewed: Array[BattleUnit] = []  # у кого на плашке сейчас предпросмотр


func _show_card_preview(cell: Vector2i) -> void:
	var key: String = "%d:%d:%s" % [_active.id, _selected_card, cell]
	if key == _preview_key:
		return   # мышь двигается по той же клетке — всё уже показано
	_clear_preview()
	_preview_key = key
	_preview = logic.preview_card(_active, _selected_card, cell)
	if not _preview["ok"]:
		return
	var units: Dictionary = _preview["units"]
	# Поле: куда встанут, кто падёт
	var landing: Array[Vector2i] = []
	var deaths: Array[Vector2i] = []
	for id: int in units:
		var info: Dictionary = units[id]
		if info["killed"]:
			deaths.append(info["from"])
		elif info["cell"] != info["from"]:
			landing.append(info["cell"])
	board.show_cells("ghost_move", landing, COLOR_GHOST_MOVE)
	board.show_cells("ghost_kill", deaths, COLOR_GHOST_KILL)
	# Реакции — своими цветами
	var by_kind: Dictionary = {}
	for k: String in REACTION_KINDS:
		by_kind[k] = [] as Array[Vector2i]
	for r: Dictionary in _preview["reactions"]:
		if r["kind"] == "pincer" and Hints.wanted("pincer"):
			_offer_hint("pincer")
			_flush_hints()   # про клещи — сразу, пока игрок целится
		var kind: String = "lava" if r["kind"] == "tree_fire" else r["kind"]
		if by_kind.has(kind) and not by_kind[kind].has(r["cell"]):
			by_kind[kind].append(r["cell"])
	var colors: Dictionary = {"steam": COLOR_STEAM, "freeze": COLOR_FREEZE, "shatter": COLOR_SHATTER,
			"lava": COLOR_LAVA, "crust": COLOR_CRUST, "shock": COLOR_SHOCK, "pincer": COLOR_PINCER}
	for k: String in REACTION_KINDS:
		board.show_cells("reaction_" + k, by_kind[k], colors[k])
	# Цепочка: клетки взрывов и разрядов, номера звеньев по порядку
	var chain: Array[Dictionary] = _preview["chain"]
	var chain_cells: Array[Vector2i] = []
	var numbers: Array[Dictionary] = []
	for i in chain.size():
		var cells: Array[Vector2i] = chain[i]["cells"]
		for c in cells:
			if not chain_cells.has(c):
				chain_cells.append(c)
		if chain.size() > 1 and not cells.is_empty():
			numbers.append({"cell": _blast_center(cells), "text": str(i + 1), "color": COLOR_CHAIN_NUMBER})
	board.show_cells("chain_cells", chain_cells, COLOR_CHAIN)
	board.show_markers("chain_numbers", numbers)
	# Новые огонь, вода, лёд, дым, газ — бледным слоем своего цвета
	var by_tile: Dictionary = {}
	for c: Vector2i in _preview["tiles"]:
		var tile: int = _preview["tiles"][c]
		if PREVIEW_TILE_COLORS.has(tile) and logic.tiles.get(c, BattleLogic.Tile.NONE) != tile:
			if not by_tile.has(tile):
				by_tile[tile] = [] as Array[Vector2i]
			by_tile[tile].append(c)
	for tile: int in by_tile:
		board.show_cells("ghost_tile_%d" % tile, by_tile[tile], PREVIEW_TILE_COLORS[tile])
	# Плашки над фигурками
	for u: BattleUnit in _views:
		if units.has(u.id) and is_instance_valid(_views[u]):
			_views[u].set_preview(units[u.id])
			_previewed.append(u)
	hud.show_preview(_preview_lines(_preview))


# Итог карты словами — строки [текст, цвет] для правого нижнего угла
func _preview_lines(p: Dictionary) -> Array:
	var lines: Array = []
	var hurt: Array[String] = []
	var self_hurt: Array[String] = []
	var healed: Array[String] = []
	var moved: int = 0
	var statuses: Dictionary = {}
	var woke: Array[String] = []
	for id: int in p["units"]:
		var info: Dictionary = p["units"][id]
		var loss: int = info["hp"] - info["hp_after"]
		if info["is_hero"]:
			if loss > 0:
				self_hurt.append("%s −%d%s" % [info["title"], loss, Loc.t(", падёт") if info["killed"] else ""])
			elif loss < 0:
				healed.append("%s +%d" % [info["title"], -loss])
		elif loss > 0 or info["killed"] or info["absorbed"] > 0:
			var text: String = "%s −%d" % [info["title"], loss]
			if info["absorbed"] > 0:
				text += Loc.t(" (блок −%d)") % info["absorbed"]
			if info["killed"]:
				text += Loc.t(", падёт")
			hurt.append(text)
		if not info["killed"] and info["cell"] != info["from"]:
			moved += 1
		for key: String in info["new"]:
			if key == "woke":
				woke.append(info["title"])
			elif not info["is_hero"]:
				statuses[key] = int(statuses.get(key, 0)) + 1
	if not hurt.is_empty():
		var shown: Array[String] = hurt.slice(0, 4)
		var tail: String = Loc.t("; ещё %d") % (hurt.size() - 4) if hurt.size() > 4 else ""
		lines.append([Loc.t("Урон: ") + "; ".join(shown) + tail, UiKit.TEXT])
	if not self_hurt.is_empty():
		lines.append([Loc.t("Своим: ") + "; ".join(self_hurt), COLOR_SELF_HIT])
	if not healed.is_empty():
		lines.append([Loc.t("Лечение: ") + ", ".join(healed), UiKit.HP])
	var reactions: Dictionary = {}
	for r: Dictionary in p["reactions"]:
		var name: String = REACTION_NAMES.get(r["kind"], r["kind"])
		reactions[name] = int(reactions.get(name, 0)) + 1
	if not reactions.is_empty():
		var parts: Array[String] = []
		for name: String in reactions:
			parts.append(name if reactions[name] == 1 else "%s ×%d" % [name, reactions[name]])
		lines.append([Loc.t("Реакции: ") + ", ".join(parts), UiKit.TEXT_DIM])
	if not (p["chain"] as Array).is_empty():
		var links: Array[String] = []
		for c: Dictionary in p["chain"]:
			links.append(CHAIN_NAMES.get(c["kind"], c["kind"]))
		lines.append([Loc.t("Цепочка: ") + " → ".join(links), UiKit.TEXT_DIM])
	if not statuses.is_empty():
		var parts: Array[String] = []
		for key: String in statuses:
			parts.append("%s: %d" % [STATUS_NAMES.get(key, key), statuses[key]])
		lines.append([Loc.t("Состояния: ") + ", ".join(parts), UiKit.TEXT_DIM])
	if not woke.is_empty():
		lines.append([Loc.t("Проснётся: ") + ", ".join(woke), UiKit.TEXT_DIM])
	if moved > 0:
		lines.append([Loc.t("Сдвинутся: %d") % moved, UiKit.TEXT_DIM])
	if int(p["spawned"]) > 0:
		lines.append([Loc.t("Появится врагов: %d") % p["spawned"], UiKit.TEXT_DIM])
	return lines


func _clear_preview() -> void:
	_preview_key = ""
	_preview = {}
	for layer: String in PREVIEW_LAYERS:
		board.clear_layer(layer)
	for k: String in REACTION_KINDS:
		board.clear_layer("reaction_" + k)
	for u: BattleUnit in _previewed:
		if _views.has(u) and is_instance_valid(_views[u]):
			_views[u].set_preview({})
	_previewed.clear()
	hud.show_preview([])


# Навёл на врага — его зона угрозы подсвечивается ярче
func _show_hovered_enemy_threat(cell: Vector2i) -> void:
	var u: BattleUnit = logic.unit_at(cell)
	if u != null and not u.is_hero:
		board.show_cells("hover_threat", logic.get_threat_cells(u), COLOR_HOVER_THREAT)
		hud.show_enemy(u, logic)   # карточка врага справа: кто это, чем бьёт, особенности
	else:
		board.clear_layer("hover_threat")
		hud.show_enemy(null, logic)
	var enemy: BattleUnit = u if u != null and not u.is_hero else null
	if enemy != _route_enemy:
		_route_enemy = enemy
		_refresh_routes()


# Пути врагов на поле: все (настройка «Пути всех врагов») или только того, кто под курсором.
# Во время анимаций путей нет — прогноз ещё не пересчитан.
func _refresh_routes() -> void:
	if _mode == Mode.BUSY or _routes.is_empty():
		board.clear_layer("routes")
		return
	var shown: Array = []
	if Settings.all_routes:
		shown = _routes.values()
	elif _route_enemy != null and _routes.has(_route_enemy):
		shown = [_routes[_route_enemy]]
	if shown.is_empty():
		board.clear_layer("routes")
	else:
		board.show_routes(shown)


# Режим сброса: следующая нажатая карта уходит в сброс (одна за ход)
var _discarding: bool = false
var _scrapping: bool = false   # включён режим «в ноги» (клавиша X): следующая карта сбрасывается бесплатно


func _on_discard_toggled() -> void:
	if _mode == Mode.BUSY:
		return
	if _tutor != null and not _tutor.allows_extra():
		_tutor_nudge()
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
		Sfx.play("card_scrap", 0.05)
		_do(func() -> void: logic.scrap_card(sh, index))
		return
	if _discarding:
		var h: BattleUnit = _active
		_discarding = false
		Sfx.play("card_cancel", 0.05)
		_do(func() -> void: logic.discard_card(h, index))
		return
	if _selected_card == index:
		_cancel_card()
		return
	if _tutor != null and not _tutor.allows_card(_active.hero_data.id, _active.hand[index].id):
		_tutor_nudge()
		return
	if not logic.can_play(_active, index):
		Sfx.play("card_cancel", 0.05)
		return
	var card: CardData = _active.hand[index]
	if card.shape == CardData.Shape.SELF or card.shape == CardData.Shape.AROUND:
		var h: BattleUnit = _active
		hud.burst_hand_card(index, card)   # карта рассыпается искрами
		if _tutor != null:
			_tutor_pending = ["card", h.hero_data.id, card.id]
		_do(func() -> void: logic.play_card(h, index, h.cell))
		return
	Sfx.play("card_select", 0.05)
	_selected_card = index
	_mode = Mode.AIMING
	board.clear_layer("move")
	board.show_cells("target", logic.get_card_targets(_active, index), COLOR_TARGET)
	hud.refresh(logic, _active, _selected_card, false)
	_on_hover(_hover_cell)


func _cancel_card() -> void:
	if _discarding:
		_discarding = false
		Sfx.play("card_cancel", 0.05)
		_enter_idle()
		return
	if _mode == Mode.AIMING:
		Sfx.play("card_cancel", 0.05)
		_enter_idle()


func _on_end_turn_pressed() -> void:
	if _tutor != null and _mode != Mode.BUSY:
		if not _tutor.allows_end_turn():
			_tutor_nudge()
			return
		_tutor_pending = ["end_turn", "", ""]
	if _mode != Mode.BUSY:
		_last_chain_sounded = 0
		Sfx.play("turn", 0.03)
		_do(logic.end_turn)


# Выполняет действие в логике и проигрывает все анимации, которые оно вызвало
func _do(action: Callable) -> void:
	_mode = Mode.BUSY
	_selected_card = -1
	for layer: String in ["move", "target", "area", "hover_threat", "intent", "buff", "routes", "hazard_marks"]:
		board.clear_layer(layer)
	for k: String in REACTION_KINDS:
		board.clear_layer("reaction_" + k)
	_clear_preview()
	_routes.clear()   # старый прогноз путей больше не верен
	_route_enemy = null
	_set_fire_forecast({})   # пока идут анимации, предупреждений об огне на плашках нет
	hud.show_enemy(null, logic)
	hud.refresh(logic, _active, -1, true)
	_discarding = false
	hud.update_discard_button(logic, _active, false, true)
	hud.update_undo_button(_undo.size(), _undo_lock, true)
	var is_end_turn: bool = action == logic.end_turn
	var action_start_ms: int = Time.get_ticks_msec()
	_enemy_phase_running = is_end_turn
	_apply_speed()
	var snap: Dictionary = {} if is_end_turn else _make_undo_snapshot()
	action.call()
	await _play_queue()
	if is_end_turn:
		_enemy_phase_ms += Time.get_ticks_msec() - action_start_ms
	_enemy_phase_running = false
	_apply_speed()
	if is_end_turn or logic.is_over:
		_clear_undo("")   # новый ход (или бой окончен) — отменять нечего
		_fallen.clear()
	else:
		_after_action(snap)
	if _tutor != null and not _tutor_pending.is_empty():
		_tutor.action_done(_tutor_pending[0], _tutor_pending[1], _tutor_pending[2])
		_tutor_pending.clear()
	if logic.is_over:
		await _finish_battle()
		return
	if not _active.is_alive():
		_select_hero(_next_hero())   # выбранный герой пал — переключаемся на живого
	_enter_idle()


# ---------- Отмена хода (клавиша Z) ----------
# Перед каждым действием героев (шаг, карта, сброс) — снимок боя. «Отменить» возвращает
# бой к последнему снимку и мгновенно переставляет поле и фигурки. Отмена бесплатная,
# до начала хода. Нельзя отменить действие, которое открыло новое — добрало карту из колоды
# или дало случайный исход: иначе отменой можно подсматривать колоду.

func _make_undo_snapshot() -> Dictionary:
	var piles: Array[int] = []
	for h in logic.heroes:
		piles.append(h.draw_pile.size())
	return {
		"logic": logic.save_state(),
		"rng": Run.rng.state,
		"piles": piles,
		"played": _cards_played,
		"scrapped": _cards_scrapped,
		"log": hud.get_log(),
		"active": _active,
	}


# После действия: открыло новое — снимки до него закрепляются, иначе снимок ложится в стек.
# Действие, которое ничего не поменяло (не сработало), в стек не идёт.
func _after_action(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	for i in logic.heroes.size():
		if logic.heroes[i].draw_pile.size() < snap["piles"][i]:
			_clear_undo(Loc.t("Нельзя отменить: открыта новая карта из колоды."))
			return
	if Run.rng.state != snap["rng"]:
		_clear_undo(Loc.t("Нельзя отменить: выпал случайный исход."))
		return
	if snap["logic"] == logic.save_state():
		return
	_undo.append(snap)
	_undo_lock = ""


func _clear_undo(reason: String) -> void:
	_undo.clear()
	_undo_lock = reason


func _on_undo_pressed() -> void:
	if _tutor != null and not _tutor.allows_extra() and _mode != Mode.AIMING:
		_tutor_nudge()
		return
	if _mode == Mode.AIMING or _discarding or _scrapping:
		_scrapping = false
		_cancel_card()   # сначала Z снимает выбор карты, как ПКМ
		_enter_idle()
		return
	if _mode != Mode.IDLE or _undo.is_empty():
		if _mode == Mode.IDLE:
			Sfx.play("card_cancel", 0.05)
		return
	var snap: Dictionary = _undo.pop_back()
	logic.load_state(snap["logic"])
	_cards_played = snap["played"]
	_cards_scrapped = snap["scrapped"]
	hud.set_log(snap["log"])
	_resync_views()
	var was: BattleUnit = snap["active"]
	_select_hero(was if was != null and was.is_alive() else logic.living_heroes()[0])
	Sfx.play("card_select", 0.05)
	_enter_idle()


# Поле и фигурки — как в логике, без анимаций (после отмены хода)
func _resync_views() -> void:
	# Кольцо выбора снимаем заранее: его фигурка может быть пересоздана
	if _ring.get_parent() != null:
		_ring.get_parent().remove_child(_ring)
	var present: Dictionary[BattleUnit, bool] = {}
	for u in logic.heroes + logic.enemies:
		present[u] = true
	for u: BattleUnit in _views.keys():
		var view: Unit = _views[u]
		var alive_view: bool = is_instance_valid(view)
		var stale: bool = not alive_view or not present.has(u) \
				or (_fallen.has(u) and u.is_alive()) \
				or (not u.is_hero and u.asleep != view.has_meta("no_rim"))
		if not stale:
			continue
		# Призванный после снимка — убрать; павший и оживший или проснувшийся — собрать заново
		if alive_view:
			vfx.clear_auras(view)
			view.queue_free()
		_views.erase(u)
		_last_hp.erase(u)
		_fallen.erase(u)
		if present.has(u):
			var fresh: Unit = _make_hero_view(u) if u.is_hero else _make_enemy_view(u)
			if u.is_hero and not u.spirits.is_empty():
				vfx.add_companions(fresh, u.spirits, _unit_height(u))
	for u: BattleUnit in _views:
		var view: Unit = _views[u]
		view.visible = u.is_alive()
		view.place_at(u.cell)
		_last_hp[u] = u.hp
		var state: Dictionary = logic.snapshot(u)
		view.set_status(_plate_info(u, state))
		if u.is_alive():
			vfx.set_auras(view, _unit_height(u), state)
		else:
			vfx.clear_auras(view)
	board.resync(logic)
	board.show_cells("objective", logic.objective_cells(),
			COLOR_OBJECTIVE_WATER if logic.objective == BattleLogic.Objective.RISING_WATER else COLOR_OBJECTIVE)
	_update_ritual_circle()
	_play_queue()   # круг ритуала ставится через очередь — проигрываем сразу


# Ход героев, ничего не выбрано: куда может идти выбранный герой и что сделают враги
func _enter_idle() -> void:
	_mode = Mode.IDLE
	_selected_card = -1
	_clear_preview()
	board.clear_layer("target")
	board.clear_layer("area")
	for k: String in REACTION_KINDS:
		board.clear_layer("reaction_" + k)
	var move_cells: Array[Vector2i] = []
	for c: Vector2i in logic.get_move_targets(_active):
		move_cells.append(c)
	board.show_cells("move", move_cells, COLOR_MOVE, true)
	_show_forecast()
	_show_tutor()
	_check_hints()
	hud.refresh(logic, _active, -1, false)
	hud.update_discard_button(logic, _active, _discarding, false)
	hud.update_undo_button(_undo.size(), _undo_lock, false)


# Прогноз: пути — куда пойдёт каждый враг (все или только под курсором), красные клетки — куда он ударит,
# если прямо сейчас нажать «Конец хода». Пересчитывается после каждого действия.
func _show_forecast() -> void:
	_routes.clear()
	var seen: Dictionary[Vector2i, bool] = {}
	var hits: Array[Vector2i] = []
	var buffs: Array[Vector2i] = []
	for plan: Dictionary in logic.forecast_enemies():
		(plan["enemy"] as BattleUnit).ai_reason = plan["reason"]   # карточка врага покажет, почему он так ходит
		_routes[plan["enemy"] as BattleUnit] = plan["path"]
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
		if fx["kind"] == "wave":
			# Сюда в конце раунда придёт подмога: песочные часы, удара по клетке нет
			for wc: Vector2i in fx_cells:
				marks.append({"cell": wc, "icon": "hourglass", "color": Color(1.0, 0.62, 0.55)})
			continue
		for c: Vector2i in fx_cells:
			if not seen.has(c):
				seen[c] = true
				hits.append(c)
		if fx["kind"] == "explosion":
			marks.append({"cell": _blast_center(fx_cells), "icon": "barrel", "color": Color(1.0, 0.85, 0.7)})
		elif fx["kind"] == "tree":
			marks.append({"cell": fx_cells[0], "icon": "tree", "color": Color(1.0, 0.85, 0.7)})
		elif fx["kind"] == "peat":
			for pc: Vector2i in fx_cells:
				marks.append({"cell": pc, "icon": "fire", "color": Color(1.0, 0.7, 0.4)})
		elif fx["kind"] == "rune":
			marks.append({"cell": _blast_center(fx_cells), "icon": "rune_trap", "color": Color(0.9, 0.93, 1.0)})
	board.show_markers("hazard_marks", marks)
	_set_fire_forecast(hazards["fire"])
	_refresh_routes()   # по умолчанию — только путь врага под курсором
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
	Sfx.play("victory" if logic.won else "defeat", 0.0)
	if _tutor != null:
		hud.tutor.close()
		hud.show_banner(Loc.t("Обучение пройдено!") if logic.won else Loc.t("Обучение окончено"))
	else:
		hud.show_banner(Loc.t("Победа!") if logic.won else Loc.t("Поражение…"))
	await get_tree().create_timer(1.5).timeout
	var hp_left: Array[int] = []
	for h in logic.heroes:
		hp_left.append(h.hp)
	Run.last_vessel_water = logic.vessel_water_hits   # условие Сердца Жерла
	Run.last_colossus_fast = logic.colossus_fast_kill   # условие Ржавника
	Run.last_freed_spirit = logic.freed_spirit   # Полусвободный дух вырвался из сферы
	Run.last_drowned = logic.drowned_count   # условие уникального духа (Хозяин трясины)
	Run.last_forest_burnt = logic.trees_burnt + logic.vines_burnt   # условие Лешего: Роща не должна гореть
	Run.finish_battle(logic.won, hp_left)


# ---------- Учебный бой ----------
# Окошко сверху говорит, что сделать; нужная карта светится, нужная клетка — латунная.
# Пока ведём за руку, всё остальное не нажимается (короткое «нет» — окошко вспыхивает).

func _show_tutor() -> void:
	if _tutor == null:
		return
	var s: Dictionary = _tutor.current()
	var kind: String = s["do"]
	hud.tutor_lock = _tutor.guided()
	hud.tutor_card = s["card"] if kind == "card" and _active != null and _active.hero_data.id == s["hero"] else ""
	hud.tutor_end = kind == "end_turn"
	var marks: Array[Vector2i] = []
	if _tutor.target_cell() != Vector2i(-1, -1):
		marks.append(_tutor.target_cell())
	elif kind == "hero":
		for h: BattleUnit in logic.heroes:
			if h.hero_data.id == s["hero"]:
				marks.append(h.cell)
	board.show_cells("tutor", marks, COLOR_TUTOR)
	if _tutor_shown == _tutor.step:
		return
	_tutor_shown = _tutor.step
	var next_text: String = Loc.t("Дальше") if kind == "next" else (Loc.t("Понятно") if kind == "free" else "")
	hud.tutor.show_step(_tutor.number_text(), s["title"], s["text"], next_text,
			Loc.t("Пропустить обучение") if _tutor.guided() else "")


# ---------- Подсказки при первой встрече ----------

func _offer_hint(id: String) -> void:
	if Hints.wanted(id) and not _hint_queue.has(id) and _hint_shown != id:
		_hint_queue.append(id)


# После каждого действия: не появилось ли на поле что-то новое для игрока
func _check_hints() -> void:
	if Hints.is_off() or (_tutor != null and _tutor.guided()):
		return
	if logic.chain_value() >= 2:
		_offer_hint("chain")
	if logic.turn >= 2:
		_offer_hint("keep")
	if logic.tiles.values().has(BattleLogic.Tile.FIRE):
		_offer_hint("fire")
	for u: BattleUnit in logic.heroes + logic.enemies:
		if u.is_alive() and logic.wet_turns(u) > 0:
			_offer_hint("wet")
		if u.is_hero and u.is_alive() and u.taunt:
			_offer_hint("taunt")
		if u.is_hero and not u.is_alive():
			_offer_hint("fallen")
	_flush_hints()


# Показать первую подсказку из очереди, если окошко свободно
func _flush_hints() -> void:
	if _hint_queue.is_empty() or hud.tutor.visible or logic.is_over:
		return
	if _tutor != null and _tutor.guided():
		return
	_hint_shown = _hint_queue.pop_front()
	Hints.show_in(hud.tutor, _hint_shown)


func _on_panel_next() -> void:
	if _hint_shown != "":
		_hint_shown = ""
		hud.tutor.close()
		_flush_hints()
	else:
		_on_tutor_next()


func _on_panel_skip() -> void:
	if _hint_shown != "":
		Hints.turn_off()   # «Не показывать подсказки»
		_hint_shown = ""
		_hint_queue.clear()
		hud.tutor.close()
	else:
		Run.end_tutorial()


func _on_tutor_next() -> void:
	if _tutor == null or _mode == Mode.BUSY:
		return
	if _tutor.current()["do"] == "free":
		hud.tutor.close()
		board.clear_layer("tutor")
		_flush_hints()
		return
	if _tutor.action_done("next"):
		_enter_idle()


# Нажали не то: окошко коротко вспыхивает, звучит «нет»
func _tutor_nudge() -> void:
	Sfx.play("card_cancel", 0.05)
	var panel: TutorPanel = hud.tutor
	if not panel.visible:
		return
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate", Color(1.5, 1.3, 0.85), 0.08)
	tween.tween_property(panel, "modulate", Color.WHITE, 0.3)


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
	_write_journal()


# Строка в журнал боёв user://battles.csv (scripts/battle_journal.gd). При замере ботом не пишем.
func _write_journal() -> void:
	if Run.sim_no_scenes or _tutor != null:
		return   # учебный бой в журнал баланса не пишем
	var kinds: Dictionary = {MapNode.Type.BATTLE: Loc.t("бой"), MapNode.Type.ELITE: Loc.t("элита"),
			MapNode.Type.BOSS: Loc.t("босс"), MapNode.Type.LAIR: Loc.t("логово"), MapNode.Type.EVENT: Loc.t("событие")}
	var kind: String = Loc.t("пещера") if Run.in_cave else (kinds.get(Run.current.type, "?") if Run.current != null else "?")
	var hp_start: Array[int] = []
	var hp_end: Array[int] = []
	var lost: int = 0
	var falls: int = 0
	for i in logic.heroes.size():
		var h: BattleUnit = logic.heroes[i]
		var start: int = _start_hp[i] if i < _start_hp.size() else h.hp
		hp_start.append(start)
		hp_end.append(maxi(h.hp, 0))
		lost += maxi(start - maxi(h.hp, 0), 0)
		if h.hp <= 0:
			falls += 1
	var mods: int = 0
	for e in logic.enemies:
		if e.data != null and e.data.modifier != null:
			mods += 1
	var enc: EncounterData = Run.pending_encounter
	BattleJournal.write({
		"date": Time.get_datetime_string_from_system(false, true),
		"seed": Run.seed_value, "bell": Run.bell,
		"row": Run.current.row if Run.current != null else -1, "kind": kind,
		"squad": enc.title if enc != null else "", "arena": logic.arena_title(),
		"objective": logic.objective_title() if logic.objective != BattleLogic.Objective.KILL_ALL else "",
		"formation": BattleLogic.Formation.keys()[Run.pending_formation()].to_lower(),
		"enemies": _start_enemies, "modifiers": mods,
		"arrived": maxi(logic.enemies.size() - _start_enemies, 0),
		"rounds": logic.turn, "won": 1 if logic.won else 0,
		"seconds": roundi((Time.get_ticks_msec() - _battle_start_ms) / 1000.0),
		"enemy_seconds": roundi(_enemy_phase_ms / 1000.0),
		"mage_start": hp_start[0] if hp_start.size() > 0 else 0, "mage_end": hp_end[0] if hp_end.size() > 0 else 0,
		"knight_start": hp_start[1] if hp_start.size() > 1 else 0, "knight_end": hp_end[1] if hp_end.size() > 1 else 0,
		"hp_lost": lost, "falls": falls, "cards": _cards_played, "scraps": _cards_scrapped,
	})
	print("Журнал боёв: строка записана в %s" % BattleJournal.full_path())


# Переводит точку на экране в клетку поля:
# пускаем луч из камеры через курсор и смотрим, где он пересёк пол (высота 0)
# Мышь над знаком босса — подсказка-строка у курсора
func _check_boss_sign(screen_pos: Vector2) -> void:
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
	var near: bool = hit != null and Vector2((hit as Vector3).x - board.boss_sign_pos.x, (hit as Vector3).z - board.boss_sign_pos.z).length() < 1.1
	hud.show_tip(_boss_sign_hint if near else "", screen_pos)


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
	if _tutor != null and not _tutor.allows_extra():
		_tutor_nudge()
		return
	var before: int = _active.kept.size()
	if not logic.toggle_keep(_active, index):
		if logic.can_keep(_active, index):
			hud.add_log(Loc.t("Удержать можно не больше %d карт") % BattleLogic.KEEP_LIMIT)
		Sfx.play("card_cancel", 0.05)
	else:
		Sfx.play("card_keep" if _active.kept.size() > before else "card_cancel", 0.04)
	hud.refresh(logic, _active, _selected_card, false)


# Зонд отражений над полем: один раз снимает арену (фонари, туман, деревья, свечение бочек),
# и блестящие поверхности — вода, лужи, лёд, сталь, мокрое — отражают её.
# Фигурки на слое 2 и в снимок не попадают (иначе в лужах навсегда остались бы их старые места).
func _add_reflection_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "ReflectionProbe"
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.size = Vector3(board.width * Board.CELL_STEP + 14.0, 10.0, board.height * Board.ROW_STEP + 14.0)
	probe.position = board.field_center() + Vector3(0.0, 2.0, 0.0)
	probe.box_projection = true
	probe.max_distance = 60.0
	probe.cull_mask = 1
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED   # общую заливку не трогаем
	add_child(probe)


# Ставит всем мешам модели фигурки слой 2: камера их видит, зонд отражений — нет
func _put_on_unit_layer(view: Node3D) -> void:
	for n in view.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = UNIT_LAYER


# Затемнение по краям экрана (виньетка): взгляд держится в центре поля, края уходят в сумрак.
# Слой ниже интерфейса (HUD — слой 1), мышь сквозь него проходит.
func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = VIGNETTE_SHADER
	rect.material = mat
	layer.add_child(rect)


# Пепельный тракт (акт 2): пепельно-бурый воздух, тусклое солнце сквозь дым, рыжее зарево у горизонта
func _ash_road_light() -> void:
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		var env: Environment = we.environment.duplicate() as Environment
		env.background_color = Color(0.13, 0.1, 0.08)
		env.ambient_light_color = Color(0.58, 0.56, 0.55)
		env.fog_light_color = Color(0.36, 0.29, 0.23)
		if env.sky != null:
			env.sky = env.sky.duplicate(true) as Sky
			var sky_mat: ShaderMaterial = env.sky.sky_material as ShaderMaterial
			sky_mat.set_shader_parameter("zenith_color", Color(0.12, 0.1, 0.09))
			sky_mat.set_shader_parameter("horizon_color", Color(0.48, 0.28, 0.13))
		we.environment = env
	var sun: DirectionalLight3D = get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(0.92, 0.86, 0.8)   # тусклое солнце сквозь дым: чуть тёплое, но плиты остаются серыми
		sun.light_energy = 0.8


# Тлеющая пещера: вместо зелёного болотного тумана — тёплый тёмный воздух и рыжий свет
func _warm_cave_light() -> void:
	var we: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		var env: Environment = we.environment.duplicate() as Environment
		env.background_color = Color(0.06, 0.045, 0.04)
		env.ambient_light_color = Color(0.62, 0.5, 0.42)
		env.fog_light_color = Color(0.26, 0.17, 0.11)
		# Цветокоррекция пещеры: тени тёпло-бурые, светлое — янтарное
		var grade := Gradient.new()
		grade.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		grade.colors = PackedColorArray([Color(0.015, 0.005, 0.0), Color(0.27, 0.24, 0.21), Color(0.52, 0.49, 0.46),
				Color(0.8, 0.75, 0.68), Color(1.0, 0.96, 0.88)])
		var grade_tex := GradientTexture1D.new()
		grade_tex.gradient = grade
		env.adjustment_color_correction = grade_tex
		if env.sky != null:   # и в отражениях — тёплый тёмный свод вместо болотного неба
			env.sky = env.sky.duplicate(true) as Sky
			var sky_mat: ShaderMaterial = env.sky.sky_material as ShaderMaterial
			sky_mat.set_shader_parameter("zenith_color", Color(0.04, 0.025, 0.02))
			sky_mat.set_shader_parameter("horizon_color", Color(0.3, 0.17, 0.08))
			sky_mat.set_shader_parameter("rift_strength", 0.0)
		we.environment = env
	var sun: DirectionalLight3D = get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(0.95, 0.78, 0.6)
		sun.light_energy = 0.9


func _battle_kind() -> String:
	if Run.in_cave:
		return "cave"
	if Run.current != null:
		match Run.current.type:
			MapNode.Type.BOSS:
				return "boss"
			MapNode.Type.ELITE:
				return "elite"
			MapNode.Type.LAIR:
				return "lair"
	return "normal"


func _enemy_attack_sound(eid: String) -> String:
	match eid:
		"spirit_fire", "torch_goblin":
			return "fire"
		"spirit_tide":
			return "water"
		"spirit_storm":
			return "lightning"
		"spirit_wind":
			return "wind_gust"
		"spirit_bog":
			return "bog_cast"
		"goblin_slinger", "goblin_shaman", "swamp_weaver", "sporeling":
			return "enemy_spit"
		"wolf", "grey_alpha", "leech", "spiderling", "reed_lurker", "bloated_toad", "rock_crawler", "bog_mother":
			return "enemy_bite"
		_:
			return "enemy_club"
