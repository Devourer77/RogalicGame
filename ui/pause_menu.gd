class_name PauseMenu
extends Control
# Меню паузы: Esc в бою, в хабе и на экранах забега (кроме главного меню и итога забега),
# или кнопка «Меню» в бою. Игра стоит на паузе (get_tree().paused), пока меню открыто.
# Забег посреди не сохраняется (решение по хабу), поэтому выход в меню из забега — это «сдаться»:
# забег заканчивается, Отзвуки за пройденное начисляются как обычно.

static var _current: PauseMenu = null

# Экраны, где Esc паузу не открывает
const NO_PAUSE_SCENES: Array[String] = ["res://ui/main_menu.tscn", "res://ui/game_over.tscn"]

var _confirm: Control   # «Точно сдаться?»
var _confirm_restart: Control   # «Начать бой заново?»


static func open(parent: Node) -> PauseMenu:
	if is_open():
		return _current
	# Свой слой поверх интерфейса боя и хаба (они в своих CanvasLayer)
	var layer := CanvasLayer.new()
	layer.layer = 60
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var menu := PauseMenu.new()
	_current = menu
	layer.add_child(menu)
	return menu


static func is_open() -> bool:
	return _current != null and is_instance_valid(_current)


# Можно ли открыть паузу на текущем экране (зовёт Settings по необработанному Esc)
static func allowed(tree: SceneTree) -> bool:
	var scene: Node = tree.current_scene
	return scene != null and not NO_PAUSE_SCENES.has(scene.scene_file_path) \
			and not is_open() and not SettingsScreen.is_open()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.98), UiKit.BRASS, 2)
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title: Label = UiKit.make_title(Loc.t("Пауза"), 30, UiKit.BRASS.lightened(0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(UiKit.make_divider(260))
	col.add_child(_button(Loc.t("Продолжить"), _close, "", true))
	col.add_child(_button(Loc.t("Настройки"), func() -> void: SettingsScreen.open(self), "gear"))
	if _in_battle() and Run.is_active and not Run.tutorial:
		col.add_child(_button(Loc.t("Начать бой заново"), _ask_restart, "undo"))
	if Run.tutorial:
		col.add_child(_button(Loc.t("Пропустить обучение"), func() -> void:
			_unpause()
			Run.end_tutorial()))
	elif Run.is_active:
		col.add_child(_button(Loc.t("Сдаться и выйти в меню"), _ask_give_up))
	else:
		col.add_child(_button(Loc.t("Выйти в главное меню"), func() -> void:
			_unpause()
			Run.goto(Run.MAIN_MENU_SCENE)))
	col.add_child(_button(Loc.t("Выйти из игры"), func() -> void: get_tree().quit()))

	# Подтверждение «сдаться»: забег не сохраняется
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 8)
	_confirm.visible = false
	var warn: Label = UiKit.make_label(Loc.t("Забег посреди не сохраняется: он закончится здесь. Отзвуки за пройденный путь начислятся."), 14, UiKit.TEXT_DIM)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.custom_minimum_size.x = 300
	_confirm.add_child(warn)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(_button(Loc.t("Сдаться"), func() -> void:
		_unpause()
		Run.game_over(false)))
	row.add_child(_button(Loc.t("Отмена"), func() -> void: _confirm.visible = false))
	_confirm.add_child(row)
	col.add_child(_confirm)

	# Подтверждение «начать бой заново»: та же расстановка, всё сделанное в бою пропадёт
	_confirm_restart = VBoxContainer.new()
	_confirm_restart.add_theme_constant_override("separation", 8)
	_confirm_restart.visible = false
	var restart_warn: Label = UiKit.make_label(Loc.t("Бой начнётся сначала: те же враги и расстановка, здоровье героев — как перед боем."), 14, UiKit.TEXT_DIM)
	restart_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	restart_warn.custom_minimum_size.x = 300
	_confirm_restart.add_child(restart_warn)
	var restart_row := HBoxContainer.new()
	restart_row.alignment = BoxContainer.ALIGNMENT_CENTER
	restart_row.add_theme_constant_override("separation", 10)
	restart_row.add_child(_button(Loc.t("Начать заново"), func() -> void:
		_unpause()
		Run.restart_battle()))
	restart_row.add_child(_button(Loc.t("Отмена"), func() -> void: _confirm_restart.visible = false))
	_confirm_restart.add_child(restart_row)
	col.add_child(_confirm_restart)


func _button(text: String, on_pressed: Callable, icon_name: String = "", primary: bool = false) -> Button:
	var b: Button = UiKit.make_button(text, on_pressed, icon_name, primary)
	b.custom_minimum_size = Vector2(300, 42)
	return b


func _ask_give_up() -> void:
	_confirm_restart.visible = false
	_confirm.visible = true


func _ask_restart() -> void:
	_confirm.visible = false
	_confirm_restart.visible = true


# Пауза открыта в бою (не в хабе и не на экранах забега)
func _in_battle() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.scene_file_path == Run.BATTLE_SCENE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _confirm.visible or _confirm_restart.visible:
			_confirm.visible = false
			_confirm_restart.visible = false
		else:
			_close()


func _unpause() -> void:
	get_tree().paused = false
	if _current == self:
		_current = null


func _close() -> void:
	_unpause()
	get_parent().queue_free()   # вместе со слоем


func _exit_tree() -> void:
	# На случай смены сцены с открытым меню — не оставить игру на паузе
	if _current == self:
		_current = null
		get_tree().paused = false
