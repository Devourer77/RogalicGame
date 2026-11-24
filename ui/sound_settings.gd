class_name SoundSettings
extends Control
## Модальное окно настроек звука (громкость шин Master / Music / Ambience / SFX / UI и кнопка «Без звука»).
## Открывается с главного экрана, из хаба или в бою: SoundSettings.open(self)

static var _current: SoundSettings = null

var _sliders: Dictionary[String, HSlider] = {}
var _values: Dictionary[String, Label] = {}
var _mute_button: Button


static func open(parent: Node) -> SoundSettings:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	var modal := SoundSettings.new()
	_current = modal
	parent.add_child(modal)
	return modal


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.98), UiKit.BRASS, 2)
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	title_row.add_child(UiKit.icon_rect("bell", 26, UiKit.BRASS))
	title_row.add_child(UiKit.make_title("Звук", 30, UiKit.BRASS.lightened(0.2)))
	col.add_child(title_row)
	col.add_child(UiKit.make_divider(300))

	var rows: Array[Array] = [
		["Master", "Общая громкость"],
		["Music", "Музыка локаций"],
		["Ambience", "Атмосфера и дождь"],
		["SFX", "Бой, шаги и магия"],
		["UI", "Карты и меню"],
	]
	for item: Array in rows:
		col.add_child(_make_slider_row(item[0], item[1]))

	_mute_button = UiKit.make_button("", func() -> void:
		Sfx.toggle_mute()
		_sync(), "bell")
	_mute_button.custom_minimum_size = Vector2(300, 42)
	col.add_child(_mute_button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	var test_btn: Button = UiKit.make_button("Звон колокола", func() -> void: Sfx.play("bell", 0.02))
	test_btn.custom_minimum_size = Vector2(180, 42)
	actions.add_child(test_btn)
	var close_btn: Button = UiKit.make_button("Закрыть", _close, "", true)
	close_btn.custom_minimum_size = Vector2(160, 42)
	actions.add_child(close_btn)
	col.add_child(actions)

	var hint: Label = UiKit.make_label("Горячая клавиша M — быстро выключить или вернуть звук", 13, UiKit.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	Sfx.settings_changed.connect(_sync)
	_sync()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _make_slider_row(bus: String, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label: Label = UiKit.make_label(title, 15, UiKit.TEXT)
	label.custom_minimum_size.x = 175
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.02
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = Sfx.get_bus_volume(bus)
	slider.value_changed.connect(func(v: float) -> void:
		Sfx.set_bus_volume(bus, v))
	row.add_child(slider)
	_sliders[bus] = slider

	var val: Label = UiKit.make_label("100%", 14, UiKit.BRASS.lightened(0.2), true)
	val.custom_minimum_size.x = 46
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)
	_values[bus] = val
	return row


func _sync() -> void:
	for bus: String in _sliders:
		var v: float = Sfx.get_bus_volume(bus)
		_sliders[bus].set_value_no_signal(v)
		_values[bus].text = "%d%%" % roundi(v * 100.0)
	_mute_button.text = "Звук выключен (включить)" if Sfx.muted else "Выключить весь звук"


func _close() -> void:
	if _current == self:
		_current = null
	queue_free()
