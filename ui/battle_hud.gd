class_name BattleHud
extends CanvasLayer
# Интерфейс боя поверх 3D: карточки героев, рука выбранного героя,
# кнопка «Конец хода», журнал. Узлы создаются в коде.
# Сам ничего не решает — только показывает и сообщает о нажатиях сигналами.

signal card_pressed(index: int)
signal hero_pressed(index: int)
signal end_turn_pressed

const LOG_LINES: int = 8

var _hero_box: VBoxContainer
var _hand_box: HBoxContainer
var _end_button: Button
var _log: Label
var _banner: Label
var _enemy_info: Label   # подсказка о враге под курсором
var _log_lines: PackedStringArray = []


func _ready() -> void:
	# Корневой узел на весь экран. MOUSE_FILTER_IGNORE — пропускает клики
	# сквозь себя в 3D-сцену, иначе по полю было бы не кликнуть.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Карточки героев — слева сверху. Нажми, чтобы выбрать героя.
	_hero_box = VBoxContainer.new()
	_hero_box.position = Vector2(16, 16)
	_hero_box.add_theme_constant_override("separation", 6)
	root.add_child(_hero_box)

	# Журнал событий — справа сверху
	_log = Label.new()
	_log.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_log.offset_left = -380
	_log.offset_right = -16
	_log.offset_top = 16
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log.add_theme_color_override("font_outline_color", Color.BLACK)
	_log.add_theme_constant_override("outline_size", 6)
	root.add_child(_log)

	# Рука выбранного героя — по центру снизу
	_hand_box = HBoxContainer.new()
	_hand_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hand_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hand_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hand_box.offset_bottom = -12
	_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_box.add_theme_constant_override("separation", 8)
	root.add_child(_hand_box)

	# Кнопка конца хода — справа снизу
	_end_button = Button.new()
	_end_button.text = "Конец хода"
	_end_button.focus_mode = Control.FOCUS_NONE
	_end_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_end_button.offset_left = -180
	_end_button.offset_top = -70
	_end_button.offset_right = -16
	_end_button.offset_bottom = -16
	_end_button.pressed.connect(end_turn_pressed.emit)
	root.add_child(_end_button)

	# Подсказка — слева, под карточками героев
	var hint := Label.new()
	hint.text = "Tab или клик по герою — выбрать героя\nЛКМ по синей клетке — идти\nЛКМ по карте, потом по клетке — применить\nПКМ / Esc — отменить карту\nЛинии — куда пойдут враги\nКрасное — куда они ударят\nНаведи на врага — его зона и описание\nQ / E — повернуть камеру, колесо — зум"
	hint.position = Vector2(16, 190)
	hint.add_theme_font_size_override("font_size", 13)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.modulate = Color(1, 1, 1, 0.7)
	root.add_child(hint)

	# Подсказка о враге под курсором — справа, под журналом событий
	_enemy_info = Label.new()
	_enemy_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_enemy_info.offset_left = -340
	_enemy_info.offset_right = -16
	_enemy_info.offset_top = 230
	_enemy_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_enemy_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enemy_info.add_theme_font_size_override("font_size", 14)
	_enemy_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_enemy_info.add_theme_constant_override("outline_size", 6)
	_enemy_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_enemy_info)

	# Большая надпись «Победа!/Поражение» — по центру, пока скрыта
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	root.add_child(_banner)


# Перерисовывает карточки героев и руку активного героя.
# selected — номер выбранной карты (-1 — нет), busy — идут анимации.
func refresh(logic: BattleLogic, active: BattleUnit, selected: int, busy: bool) -> void:
	UiKit.clear(_hero_box)
	for i in logic.heroes.size():
		var h: BattleUnit = logic.heroes[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(330, 0)
		b.text = _hero_text(h)
		b.disabled = busy or not h.is_alive()
		b.add_theme_stylebox_override("normal", _hero_style(h, h == active))
		b.add_theme_stylebox_override("hover", _hero_style(h, true))
		b.add_theme_stylebox_override("pressed", _hero_style(h, true))
		b.add_theme_stylebox_override("disabled", _hero_style(h, h == active))
		b.pressed.connect(hero_pressed.emit.bind(i))
		_hero_box.add_child(b)

	UiKit.clear(_hand_box)
	if active != null and active.is_alive():
		for i in active.hand.size():
			var card_button: Button = CardView.make_button(active.hand[i], active.hero_data.color, logic.card_cost(active, i))
			card_button.disabled = busy or not logic.can_play(active, i)
			if card_button.disabled:
				card_button.modulate = Color(0.55, 0.55, 0.6)   # не хватает маны — карта тусклая
			if i == selected:
				card_button.modulate = Color(1.0, 0.85, 0.35)
				card_button.position.y -= 14
			card_button.pressed.connect(card_pressed.emit.bind(i))
			_hand_box.add_child(card_button)
	_end_button.disabled = busy


func _hero_text(h: BattleUnit) -> String:
	if not h.is_alive():
		return "%s — пал в бою" % h.title
	var text: String = "%s: %d / %d HP   Блок: %d" % [h.title, h.hp, h.max_hp, h.block]
	text += "\nМана: %d / %d   Шаги: %d   Колода: %d   Сброс: %d" % [
		h.mana, h.hero_data.mana_per_turn, h.moves_left, h.draw_pile.size(), h.discard_pile.size()]
	var extra: Array[String] = []
	if h.hero_data.gains_rage:
		extra.append("Ярость: %d" % h.rage)
	if h.hero_data.gains_momentum:
		extra.append("Натиск: %d" % h.momentum)
	if h.hero_data.uses_charge:
		extra.append("Заряд: %d%s" % [h.charge, " (перегрузка!)" if h.overloaded else ""])
	if h.taunt:
		extra.append("Провокация")
	if h.outpost:
		extra.append("Застава")
	if h.unstoppable:
		extra.append("Неудержимый")
	if h.discount > 0:
		extra.append("Скидка −%d" % h.discount)
	if h.entangled > 0:
		extra.append("Опутан")
	if not extra.is_empty():
		text += "\n" + "   ".join(extra)
	return text


# Рамка цвета героя; у выбранного — толще и ярче
func _hero_style(h: BattleUnit, highlighted: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.13, 0.85)
	box.border_color = h.hero_data.color if highlighted else h.hero_data.color.darkened(0.5)
	box.set_border_width_all(3 if highlighted else 1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func add_log(text: String) -> void:
	_log_lines.append(text)
	if _log_lines.size() > LOG_LINES:
		_log_lines.remove_at(0)
	_log.text = "\n".join(_log_lines)


# Название арены в начале боя: появляется сверху по центру и тает
func show_arena(title: String) -> void:
	if title == "":
		return
	var label := Label.new()
	label.text = title
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 70
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.86, 0.92, 0.84))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.04))
	label.add_theme_constant_override("outline_size", 10)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.get_parent().add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_interval(2.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)


# Подсказка о враге под курсором (пустая строка — убрать)
func show_enemy_info(text: String) -> void:
	_enemy_info.text = text


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
