class_name FirstRunScreen
extends Control
# Экран первого запуска (поверх главного меню, один раз): язык, общая громкость, масштаб интерфейса.
# «Готово» — Settings.first_run_done = true, больше не показывается. Всё это потом меняется в «Настройках».
# Смена языка перезапускает главное меню — экран откроется снова уже на новом языке.


static func open_if_needed(parent: Node) -> void:
	if Settings.first_run_done:
		return
	parent.add_child(FirstRunScreen.new())


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 97
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.99), UiKit.BRASS, 2)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = 440
	panel.add_child(col)
	col.add_child(UiKit.make_title(Loc.t("Перед началом"), 30, UiKit.BRASS.lightened(0.2)))
	col.add_child(UiKit.make_divider(360))

	# Язык (если переводов больше одного)
	if Settings.languages().size() > 1:
		var lang_row := HBoxContainer.new()
		lang_row.add_theme_constant_override("separation", 10)
		var lang_label: Label = UiKit.make_label(Loc.t("Язык"), 16)
		lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lang_row.add_child(lang_label)
		var pick := OptionButton.new()
		for code: String in Settings.languages():
			pick.add_item(Settings.LANGUAGE_NAMES.get(code, code))
			pick.set_item_metadata(pick.item_count - 1, code)
			if code == Settings.language:
				pick.select(pick.item_count - 1)
		pick.item_selected.connect(func(index: int) -> void:
			Settings.set_value("language", str(pick.get_item_metadata(index)))
			get_tree().reload_current_scene())
		lang_row.add_child(pick)
		col.add_child(lang_row)

	# Общая громкость (по умолчанию 70%: на первом запуске игры обычно слишком громкие)
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	var vol_label: Label = UiKit.make_label(Loc.t("Громкость"), 16)
	vol_label.custom_minimum_size.x = 150
	vol_row.add_child(vol_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vol_value: Label = UiKit.make_label("", 15, UiKit.BRASS.lightened(0.2), true)
	vol_value.custom_minimum_size.x = 50
	slider.value_changed.connect(func(v: float) -> void:
		Sfx.set_bus_volume("Master", v)
		vol_value.text = "%d%%" % roundi(v * 100.0))
	slider.value = minf(Sfx.get_bus_volume("Master"), FIRST_VOLUME)
	vol_row.add_child(slider)
	vol_row.add_child(vol_value)
	col.add_child(vol_row)

	# Масштаб интерфейса
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 6)
	var scale_label: Label = UiKit.make_label(Loc.t("Размер интерфейса"), 16)
	scale_label.custom_minimum_size.x = 150
	scale_row.add_child(scale_label)
	for s: float in Settings.UI_SCALES:
		var b: Button = UiKit.make_button("%d%%" % roundi(s * 100.0), func() -> void:
			Settings.set_value("ui_scale", s)
			_sync_scale())
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(52, 32)
		b.set_meta("scale", s)
		scale_row.add_child(b)
		_scale_buttons.append(b)
	col.add_child(scale_row)
	_sync_scale()

	var note: Label = UiKit.make_label(Loc.t("Всё это и многое другое (скорость врагов, клавиши, подсказки) меняется потом в «Настройках»."), 13, UiKit.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 420
	col.add_child(note)
	var done_row := HBoxContainer.new()
	done_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var done: Button = UiKit.make_button(Loc.t("Готово"), _finish, "", true)
	done.custom_minimum_size = Vector2(180, 42)
	done_row.add_child(done)
	col.add_child(done_row)


const FIRST_VOLUME: float = 0.7
var _scale_buttons: Array[Button] = []


func _sync_scale() -> void:
	for b: Button in _scale_buttons:
		b.set_pressed_no_signal(is_equal_approx(float(b.get_meta("scale")), Settings.ui_scale))


func _finish() -> void:
	Settings.set_value("first_run_done", true)
	queue_free()
