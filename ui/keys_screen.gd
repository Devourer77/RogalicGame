class_name KeysScreen
extends Control
# Окно «Клавиши» (открывается из настроек): список действий из Settings.KEY_ACTIONS.
# Нажал кнопку с клавишей → «Нажми клавишу…» → следующая нажатая клавиша назначается.
# Esc — отменить ожидание или закрыть окно. Занятая клавиша меняется местами с другим действием.
# Цифры 1–9 (карта по номеру), Esc и F11 — не назначаются.

const RESERVED: Array[int] = [KEY_ESCAPE, KEY_F11, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]

var _buttons: Dictionary[String, Button] = {}
var _waiting: String = ""   # какому действию ждём клавишу ("" — не ждём)
var _note: Label


static func open(parent: Node) -> KeysScreen:
	var screen := KeysScreen.new()
	parent.add_child(screen)
	return screen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 98
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS   # работает и на паузе
	theme = UiKit.theme()

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.99), UiKit.BRASS, 2)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	panel.add_child(col)
	col.add_child(UiKit.make_title(Loc.t("Клавиши"), 26, UiKit.BRASS.lightened(0.2)))
	col.add_child(UiKit.make_divider(360))

	for item: Array in Settings.KEY_ACTIONS:
		var action: String = item[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var label: Label = UiKit.make_label(Loc.t(item[1]), 15)
		label.custom_minimum_size.x = 270
		row.add_child(label)
		var button: Button = UiKit.make_button("", _start_waiting.bind(action))
		button.custom_minimum_size = Vector2(120, 32)
		row.add_child(button)
		_buttons[action] = button
		col.add_child(row)

	_note = UiKit.make_label(Loc.t("Цифры 1–9 — карта по номеру, Esc — меню; их не переназначить."), 12, UiKit.TEXT_DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = 400
	col.add_child(_note)
	col.add_child(UiKit.make_divider(360))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.add_child(UiKit.make_button(Loc.t("Как было"), func() -> void:
		_waiting = ""
		Settings.reset_keys()
		_sync()))
	buttons.add_child(UiKit.make_button(Loc.t("Готово"), queue_free, "", true))
	col.add_child(buttons)
	_sync()


func _start_waiting(action: String) -> void:
	_waiting = action
	_sync()


func _sync() -> void:
	for action: String in _buttons:
		if action == _waiting:
			_buttons[action].text = Loc.t("Нажми клавишу…")
			_buttons[action].modulate = UiKit.BRASS.lightened(0.3)
		else:
			_buttons[action].text = Settings.key_label(action)
			_buttons[action].modulate = Color.WHITE


# _input, а не _unhandled_input: клавишу нужно поймать раньше боя, паузы и настроек
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if _waiting == "":
		if key.physical_keycode == KEY_ESCAPE:
			queue_free()
		return
	if key.physical_keycode == KEY_ESCAPE:
		_waiting = ""   # передумал
	elif RESERVED.has(key.physical_keycode):
		_note.text = Loc.t("Эта клавиша занята игрой — выбери другую.")
		return
	else:
		Settings.set_key(_waiting, key.physical_keycode)
		_waiting = ""
	_sync()
