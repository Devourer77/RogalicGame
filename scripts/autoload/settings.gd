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
var fast_enemies: bool = false      # ход врагов ×2 (кнопка в бою меняет то же самое)
var all_routes: bool = false        # пути всех врагов на поле; выкл. — только путь врага под курсором
var warn_end_turn: bool = true      # «Конец хода» при несыгранных картах — сначала переспросить
var colorblind: bool = false        # режим для дальтоников (палитра угрозы и узоры)
var language: String = "ru"         # язык интерфейса (TranslationServer)


func _ready() -> void:
	load_settings()
	apply_window()
	apply_language()


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
	fullscreen = bool(cfg.get_value("screen", "fullscreen", fullscreen))
	shake = clampf(float(cfg.get_value("battle", "shake", shake)), 0.0, 1.0)
	full_effects = bool(cfg.get_value("battle", "full_effects", full_effects))
	rain = bool(cfg.get_value("battle", "rain", rain))
	fast_enemies = bool(cfg.get_value("battle", "fast_enemies", fast_enemies))
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
	cfg.set_value("battle", "fast_enemies", fast_enemies)
	cfg.set_value("battle", "all_routes", all_routes)
	cfg.set_value("battle", "warn_end_turn", warn_end_turn)
	cfg.save(settings_path)


# Поменять настройку по имени, сохранить и сообщить всем
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	save()
	if key == "fullscreen":
		apply_window()
	elif key == "language":
		apply_language()
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
