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


func apply_language() -> void:
	TranslationServer.set_locale(language)
