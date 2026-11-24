class_name TutorPanel
extends PanelContainer
# Окошко обучения слева, под панелями героев (сверху по центру оно закрывало врагов): «Обучение · 3 / 12», заголовок, текст шага
# и кнопки «Дальше» / «Пропустить обучение». Само ничего не решает — только показывает
# и сообщает о нажатиях сигналами. Его же используют подсказки при первой встрече (Hints).

signal next_pressed   # «Дальше» / «Понятно» (или Enter)
signal skip_pressed   # «Пропустить обучение» / «Не показывать подсказки»

const WIDTH: float = 330.0
const TOP: float = 252.0   # под двумя панелями героев

var _counter: Label
var _title: Label
var _text: Label
var _next_button: Button
var _skip_button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.07, 0.07, 0.95), UiKit.BRASS, 2, 10, 16, 12))
	custom_minimum_size = Vector2(WIDTH, 0)
	position = Vector2(14, TOP)
	mouse_filter = Control.MOUSE_FILTER_STOP   # клик по окошку не уходит в поле

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UiKit.icon_rect("help", 20, UiKit.BRASS.lightened(0.2)))
	_title = UiKit.make_label("", 18, UiKit.BRASS.lightened(0.25), true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_counter = UiKit.make_label("", 13, UiKit.TEXT_DIM)
	head.add_child(_counter)
	column.add_child(head)

	_text = UiKit.make_label("", 15)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 32.0, 0)
	column.add_child(_text)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	# «Пропустить» — скромная ссылка, а не большая кнопка: главное в окошке — текст шага
	_skip_button = Button.new()
	_skip_button.flat = true
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.add_theme_font_size_override("font_size", 13)
	_skip_button.add_theme_color_override("font_color", UiKit.TEXT_DIM)
	_skip_button.add_theme_color_override("font_hover_color", UiKit.BRASS)
	_skip_button.pressed.connect(skip_pressed.emit)
	buttons.add_child(_skip_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_next_button = UiKit.make_button(Loc.t("Дальше"), next_pressed.emit, "", true)
	_next_button.custom_minimum_size = Vector2(120, 34)
	buttons.add_child(_next_button)
	column.add_child(buttons)


# Показать шаг. next_text пустой — кнопки «Дальше» нет (шаг засчитается действием на поле).
# skip_text — подпись нижней ссылки слева («Пропустить обучение», «Не показывать подсказки»), пусто — нет.
func show_step(counter: String, title: String, text: String, next_text: String, skip_text: String) -> void:
	_counter.text = counter
	_counter.visible = counter != ""
	_title.text = title
	_text.text = text
	_next_button.text = next_text
	_next_button.visible = next_text != ""
	_skip_button.text = skip_text
	_skip_button.visible = skip_text != ""
	_skip_button.get_parent().visible = next_text != "" or skip_text != ""
	visible = true
	# Новый шаг — мягкое появление, чтобы смену текста было заметно
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func close() -> void:
	visible = false


# Enter или пробел — то же, что «Дальше»
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not _next_button.visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.is_echo() \
			and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		next_pressed.emit()
