class_name HubPanel
extends Control
# Основа всех панелей хаба: затемнение, рамка, заголовок, Отзвуки справа, кнопка «Отойти».
# Панели ничего не знают о 3D-хабе: берут данные из Meta и могут открываться откуда угодно
# (например, из обычного меню). Esc закрывает панель.

signal closed

var body: VBoxContainer          # сюда панель складывает своё содержимое
var hero_id: String = ""         # герой, который подошёл к точке («mage» / «knight»)

var _echo_label: Label
var _close_button: Button


# Создаёт пустую панель в parent. Наследники зовут это из своего open().
static func create(parent: Node, panel: HubPanel, title_text: String, width: float = 640.0,
		show_echoes: bool = true) -> HubPanel:
	parent.add_child(panel)
	panel._build(title_text, width, show_echoes)
	return panel


func _build(title_text: String, width: float, show_echoes: bool) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # клики не проходят к игре под панелью
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.02, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = UiKit.make_panel(Color(0.06, 0.08, 0.08, 0.98), UiKit.BRASS_DARK, 2)
	panel.custom_minimum_size.x = width
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var head := HBoxContainer.new()
	column.add_child(head)
	var title: Label = UiKit.make_title(title_text, 28, UiKit.BRASS.lightened(0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if show_echoes:
		var chip: HBoxContainer = UiKit.chip("echo", "", UiKit.ECHO, "Отзвуки: память о пройденном пути. Тратятся здесь, в хабе.", 18, 22)
		_echo_label = UiKit.make_label("0", 20, UiKit.ECHO, true)
		chip.add_child(_echo_label)
		head.add_child(chip)
		Meta.changed.connect(_refresh_echoes)
		_refresh_echoes()

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)

	_close_button = UiKit.make_button("Отойти", close)
	_close_button.custom_minimum_size = Vector2(200, 40)
	column.add_child(_close_button)


func _refresh_echoes() -> void:
	if _echo_label != null:
		_echo_label.text = str(Meta.echoes)


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ---------- Общие детали ----------

# Иконка по имени; нет такого файла — звёздочка (чтобы не сыпались предупреждения)
static func ic(icon_name: String, size: float = 20.0, color: Color = UiKit.TEXT) -> TextureRect:
	return UiKit.icon_rect(icon_name if UiKit.has_icon(icon_name) else "star", size, color)


# Число Отзвуков со значком. affordable = false — приглушённое (не красное).
static func echo_cost(amount: int, affordable: bool = true) -> HBoxContainer:
	var color: Color = UiKit.ECHO if affordable else UiKit.TEXT_DIM.darkened(0.2)
	return UiKit.chip("echo", str(amount), color, "" if affordable else "Не хватает Отзвуков", 17, 18)


# Рамка карты/плитки другого цвета (выбранное, изменённое)
static func recolor_button(b: Button, border: Color, width: int = 3) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var frame: StyleBox = b.get_theme_stylebox(state).duplicate()
		if frame is StyleBoxFlat:
			(frame as StyleBoxFlat).border_color = border
			(frame as StyleBoxFlat).set_border_width_all(width)
		b.add_theme_stylebox_override(state, frame)


# Уменьшенная карта. Возвращает контейнер нужного размера; кнопка внутри — get_child(0).
static func mini_card(card: CardData, owner_color: Color, factor: float, on_click: Callable) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = CardView.CARD_SIZE * factor
	var b: Button = CardView.make_button(card, owner_color)
	b.pivot_offset = Vector2.ZERO
	b.scale = Vector2(factor, factor)
	b.position = Vector2.ZERO
	if on_click.is_valid():
		b.pressed.connect(on_click)
		Sfx.bind_button(b, "card_select")
	holder.add_child(b)
	return holder
