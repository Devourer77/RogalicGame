class_name SettingsScreen
extends Control
# Окно «Настройки» поверх любого экрана: слева экран, бой и подсказки, справа громкость.
# Открывается из главного меню, хаба и меню паузы: SettingsScreen.open(родитель).
# Значения хранят Settings (settings.cfg) и Sfx (audio.cfg); окно только показывает и меняет их.

static var _current: SettingsScreen = null

const SOUND_ROWS: Array[Array] = [
	["Master", "Общая громкость"],
	["Music", "Музыка"],
	["Ambience", "Атмосфера и дождь"],
	["SFX", "Бой, шаги и магия"],
	["UI", "Карты и меню"],
]

var _sliders: Dictionary[String, HSlider] = {}
var _values: Dictionary[String, Label] = {}
var _toggles: Dictionary[String, Button] = {}   # ключ настройки → кнопка «Вкл/Выкл»
var _shake_slider: HSlider
var _shake_value: Label
var _mute_button: Button
var _hints_button: Button


static func open(parent: Node) -> SettingsScreen:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	var modal := SettingsScreen.new()
	_current = modal
	parent.add_child(modal)
	return modal


static func is_open() -> bool:
	return _current != null and is_instance_valid(_current)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 95
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS   # работает и на паузе
	theme = UiKit.theme()

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.98), UiKit.BRASS, 2)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	title_row.add_child(UiKit.icon_rect("gear", 26, UiKit.BRASS))
	title_row.add_child(UiKit.make_title("Настройки", 30, UiKit.BRASS.lightened(0.2)))
	col.add_child(title_row)
	col.add_child(UiKit.make_divider(420))

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	col.add_child(columns)

	# --- Левая колонка: экран, бой, подсказки ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.custom_minimum_size.x = 380
	columns.add_child(left)
	left.add_child(_section("Экран"))
	left.add_child(_toggle_row("fullscreen", "Полный экран (F11)"))
	left.add_child(_section("Бой"))
	left.add_child(_shake_row())
	left.add_child(_toggle_row("full_effects", "Полные эффекты (выкл. — меньше частиц)"))
	left.add_child(_toggle_row("rain", "Морось над полем"))
	left.add_child(_toggle_row("fast_enemies", "Ход врагов ×2"))
	left.add_child(_section("Подсказки"))
	var hints_row := HBoxContainer.new()
	hints_row.add_theme_constant_override("separation", 10)
	_hints_button = UiKit.make_button("", _toggle_hints)
	_hints_button.custom_minimum_size = Vector2(185, 36)
	hints_row.add_child(_hints_button)
	var again: Button = UiKit.make_button("Показать все заново", _reset_hints)
	again.custom_minimum_size = Vector2(185, 36)
	hints_row.add_child(again)
	left.add_child(hints_row)

	# --- Правая колонка: звук ---
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size.x = 380
	columns.add_child(right)
	right.add_child(_section("Звук"))
	for item: Array in SOUND_ROWS:
		right.add_child(_slider_row(item[0], item[1]))
	_mute_button = UiKit.make_button("", func() -> void:
		Sfx.toggle_mute()
		_sync(), "bell")
	_mute_button.custom_minimum_size = Vector2(0, 36)
	right.add_child(_mute_button)
	var hint: Label = UiKit.make_label("M — быстро выключить или вернуть звук", 13, UiKit.TEXT_DIM)
	right.add_child(hint)

	col.add_child(UiKit.make_divider(420))
	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var close_btn: Button = UiKit.make_button("Закрыть", _close, "", true)
	close_btn.custom_minimum_size = Vector2(180, 42)
	close_row.add_child(close_btn)
	col.add_child(close_row)

	Sfx.settings_changed.connect(_sync)
	Settings.changed.connect(_sync)
	_sync()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _section(title: String) -> Label:
	var l: Label = UiKit.make_label(title, 17, UiKit.BRASS.lightened(0.2), true)
	return l


# Строка «название — [Вкл]»: key — имя поля в Settings
func _toggle_row(key: String, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label: Label = UiKit.make_label(title, 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	var button: Button = UiKit.make_button("", func() -> void:
		Settings.set_value(key, not bool(Settings.get(key))))
	button.custom_minimum_size = Vector2(84, 32)
	row.add_child(button)
	_toggles[key] = button
	return row


func _shake_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label: Label = UiKit.make_label("Тряска камеры", 15)
	label.custom_minimum_size.x = 150
	row.add_child(label)
	_shake_slider = HSlider.new()
	_shake_slider.min_value = 0.0
	_shake_slider.max_value = 1.0
	_shake_slider.step = 0.1
	_shake_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shake_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shake_slider.value_changed.connect(func(v: float) -> void: Settings.set_value("shake", v))
	row.add_child(_shake_slider)
	_shake_value = UiKit.make_label("", 14, UiKit.BRASS.lightened(0.2), true)
	_shake_value.custom_minimum_size.x = 46
	_shake_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_shake_value)
	return row


func _slider_row(bus: String, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label: Label = UiKit.make_label(title, 15)
	label.custom_minimum_size.x = 160
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.02
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float) -> void: Sfx.set_bus_volume(bus, v))
	row.add_child(slider)
	_sliders[bus] = slider
	var val: Label = UiKit.make_label("", 14, UiKit.BRASS.lightened(0.2), true)
	val.custom_minimum_size.x = 46
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	_values[bus] = val
	return row


func _toggle_hints() -> void:
	if Hints.is_off():
		Meta.hints_seen.erase(Hints.OFF)
		Meta.save()
	else:
		Hints.turn_off()
	_sync()


func _reset_hints() -> void:
	Meta.hints_seen.clear()
	Meta.save()
	_sync()


func _sync() -> void:
	for bus: String in _sliders:
		var v: float = Sfx.get_bus_volume(bus)
		_sliders[bus].set_value_no_signal(v)
		_values[bus].text = "%d%%" % roundi(v * 100.0)
	_mute_button.text = "Звук выключен (включить)" if Sfx.muted else "Выключить весь звук"
	for key: String in _toggles:
		var on: bool = bool(Settings.get(key))
		_toggles[key].text = "Вкл" if on else "Выкл"
		_toggles[key].modulate = Color.WHITE if on else Color(0.62, 0.62, 0.66)
	_shake_slider.set_value_no_signal(Settings.shake)
	_shake_value.text = "Выкл" if Settings.shake <= 0.0 else "%d%%" % roundi(Settings.shake * 100.0)
	_hints_button.text = "Подсказки: выкл" if Hints.is_off() else "Подсказки: вкл"


func _close() -> void:
	if _current == self:
		_current = null
	queue_free()
