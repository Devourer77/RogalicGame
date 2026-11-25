extends Node
# Настройки игры (кроме громкости — она живёт в Sfx, файл audio.cfg).
# Хранятся в user://settings.cfg, меняются в окне «Настройки» (ui/settings_screen.gd).
# Кто зависит от настройки — читает её отсюда (Settings.shake) или ловит сигнал changed.

signal changed

var settings_path: String = "user://settings.cfg"   # var, чтобы тесты могли подменить путь

var fullscreen: bool = true         # полный экран или окно (F11 / Alt+Enter переключают и запоминают)
var shake: float = 1.0              # сила тряски камеры: 0 — выключена, 1 — как задумано
var full_effects: bool = true       # false — «упрощённые эффекты»: частиц вдвое меньше
var rain: bool = true               # морось над частью боёв
var enemy_speed: int = 1            # скорость хода врагов: 1, 2 или 3 (кнопка в бою и клавиша F меняют то же самое)
const ENEMY_SPEEDS: Array[int] = [1, 2, 3]
var all_routes: bool = false        # пути всех врагов на поле; выкл. — только путь врага под курсором
var warn_end_turn: bool = true      # «Конец хода» при несыгранных картах — сначала переспросить
var colorblind: bool = false        # режим для дальтоников (палитра угрозы и узоры)
var language: String = "ru"         # язык интерфейса (TranslationServer)
var ui_scale: float = 1.0           # масштаб интерфейса (content_scale_factor окна), шаги — UI_SCALES
const UI_SCALES: Array[float] = [0.8, 0.9, 1.0, 1.1, 1.2]
var first_run_done: bool = false    # экран первого запуска (язык, громкость, масштаб) уже пройден

# Переназначаемые клавиши (окно «Клавиши» в настройках, ui/keys_screen.gd).
# Действие → [название, клавиша по умолчанию]. Клавиши физические — работают на любой раскладке
# (на русской Z — та же клавиша, что «Я»). Цифры 1–9 (карта по номеру), F11, Esc — не переназначаются.
const KEY_ACTIONS: Array[Array] = [
	["cam_left", "Повернуть камеру влево", KEY_Q],
	["cam_right", "Повернуть камеру вправо", KEY_E],
	["undo", "Отменить действие", KEY_Z],
	["discard", "Сбросить карту", KEY_X],
	["next_hero", "Другой герой", KEY_TAB],
	["enemy_speed", "Скорость хода врагов", KEY_F],
	["speed_hold", "Ускорить ход врагов (держать)", KEY_SPACE],
	["help", "Справка в бою", KEY_F1],
	["mute", "Выключить звук", KEY_M],
]
var keys: Dictionary[String, int] = {}   # действие → физическая клавиша (то, что выбрал игрок)


func _ready() -> void:
	load_settings()
	apply_keys()
	apply_window()
	apply_language()
	apply_ui_scale()


# Esc, который никто не забрал (выбор карты, окно колоды и т. п.), — открыть паузу
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and PauseMenu.allowed(get_tree()):
		get_viewport().set_input_as_handled()
		var scene: Node = get_tree().current_scene
		PauseMenu.open(scene)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	# Файл настроек уже был — значит, игру запускали раньше: экран первого запуска не нужен
	first_run_done = bool(cfg.get_value("screen", "first_run_done", true))
	ui_scale = float(cfg.get_value("screen", "ui_scale", ui_scale))
	if not UI_SCALES.has(ui_scale):
		ui_scale = 1.0
	for item: Array in KEY_ACTIONS:
		if cfg.has_section_key("keys", item[0]):
			keys[item[0]] = int(cfg.get_value("keys", item[0]))
	fullscreen = bool(cfg.get_value("screen", "fullscreen", fullscreen))
	shake = clampf(float(cfg.get_value("battle", "shake", shake)), 0.0, 1.0)
	full_effects = bool(cfg.get_value("battle", "full_effects", full_effects))
	rain = bool(cfg.get_value("battle", "rain", rain))
	# Раньше была только галочка «×2» — старое сохранение переводим в скорость 2
	var old_fast: bool = bool(cfg.get_value("battle", "fast_enemies", false))
	enemy_speed = int(cfg.get_value("battle", "enemy_speed", 2 if old_fast else enemy_speed))
	if not ENEMY_SPEEDS.has(enemy_speed):
		enemy_speed = 1
	all_routes = bool(cfg.get_value("battle", "all_routes", all_routes))
	warn_end_turn = bool(cfg.get_value("battle", "warn_end_turn", warn_end_turn))
	colorblind = bool(cfg.get_value("screen", "colorblind", colorblind))
	language = str(cfg.get_value("screen", "language", language))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("screen", "fullscreen", fullscreen)
	cfg.set_value("screen", "colorblind", colorblind)
	cfg.set_value("screen", "language", language)
	cfg.set_value("battle", "shake", shake)
	cfg.set_value("battle", "full_effects", full_effects)
	cfg.set_value("battle", "rain", rain)
	cfg.set_value("battle", "enemy_speed", enemy_speed)
	cfg.set_value("battle", "all_routes", all_routes)
	cfg.set_value("battle", "warn_end_turn", warn_end_turn)
	cfg.set_value("screen", "ui_scale", ui_scale)
	cfg.set_value("screen", "first_run_done", first_run_done)
	for action: String in keys:
		cfg.set_value("keys", action, keys[action])
	cfg.save(settings_path)


# Следующая скорость хода врагов по кругу: ×1 → ×2 → ×3 → ×1
func next_enemy_speed() -> int:
	var i: int = ENEMY_SPEEDS.find(enemy_speed)
	return ENEMY_SPEEDS[(i + 1) % ENEMY_SPEEDS.size()]


# Поменять настройку по имени, сохранить и сообщить всем
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	save()
	if key == "fullscreen":
		apply_window()
	elif key == "language":
		apply_language()
	elif key == "ui_scale":
		apply_ui_scale()
	changed.emit()


# ---------- Масштаб интерфейса ----------

# Весь 2D-интерфейс крупнее или мельче (3D-поле не меняется). Экраны свёрстаны под 100%:
# при 110–120% на мелких окнах часть экранов может не поместиться.
func apply_ui_scale() -> void:
	if not is_inside_tree():
		return
	get_tree().root.content_scale_factor = ui_scale


func next_ui_scale() -> float:
	var i: int = UI_SCALES.find(ui_scale)
	return UI_SCALES[(i + 1) % UI_SCALES.size()]


# ---------- Клавиши ----------

# Физическая клавиша действия: своя или по умолчанию
func key_for(action: String) -> int:
	if keys.has(action):
		return keys[action]
	for item: Array in KEY_ACTIONS:
		if item[0] == action:
			return item[2]
	return KEY_NONE


# Название клавиши для подписей («Z», «Tab», «F1»)
func key_label(action: String) -> String:
	var code: int = key_for(action)
	if code == KEY_NONE:
		return "—"
	return OS.get_keycode_string(code)


# Записать все действия в InputMap (Project → Project Settings → Input Map — то же самое, только из кода)
func apply_keys() -> void:
	for item: Array in KEY_ACTIONS:
		var action: String = item[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = key_for(action)
		InputMap.action_add_event(action, ev)


# Назначить клавишу. Если она уже занята другим действием — они меняются клавишами.
func set_key(action: String, code: int) -> void:
	var old: int = key_for(action)
	for item: Array in KEY_ACTIONS:
		if item[0] != action and key_for(item[0]) == code:
			keys[item[0]] = old
	keys[action] = code
	apply_keys()
	save()
	changed.emit()


# Все клавиши — как по умолчанию (save() пишет файл заново, секция keys пропадёт)
func reset_keys() -> void:
	keys.clear()
	apply_keys()
	save()
	changed.emit()


func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen == is_full:
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Окно не больше рабочей области монитора (на мониторе 1920×1080 мешает панель задач)
		var area: Rect2i = DisplayServer.screen_get_usable_rect()
		var size: Vector2i = Vector2i(1920, 1080).min(area.size)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(area.position + (area.size - size) / 2)


# Названия языков для окна настроек (новый язык — просто положить locale/<код>.po)
const LANGUAGE_NAMES: Dictionary[String, String] = {
	"ru": "Русский", "en": "English", "zh_CN": "简体中文", "de": "Deutsch", "pl": "Polski",
	"fr": "Français", "es": "Español", "pt_BR": "Português (Brasil)", "ja": "日本語", "uk": "Українська",
}
const LOCALE_DIR: String = "res://locale/"
var _loaded: Array[String] = []


# Языки: русский (исходный) и все, для которых есть locale/<код>.po
func languages() -> Array[String]:
	var list: Array[String] = ["ru"]
	for file: String in ResourceLoader.list_directory(LOCALE_DIR):
		if file.get_extension() == "po":
			list.append(file.get_basename())
	return list


func apply_language() -> void:
	if not languages().has(language):
		language = "ru"
	if language != "ru" and not _loaded.has(language):
		var tr: Translation = load(LOCALE_DIR + language + ".po") as Translation
		if tr != null:
			TranslationServer.add_translation(tr)
			_loaded.append(language)
	TranslationServer.set_locale(language)
