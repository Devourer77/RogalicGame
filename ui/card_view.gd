class_name CardView
extends RefCounted
# Как выглядит карта на экране. Сверху вниз:
#   рисунок-иконка на фоне цвета набора, слева «камень» маны, справа схема клеток, куда карта бьёт;
#   название; значки с числами (урон, блок, дальность…); описание.
# Рамка — цвета героя, у редких карт — латунная.
# Используется в бою, в наградах, в лавке и в просмотре колоды — поменяешь здесь, поменяется везде.

const CARD_SIZE := Vector2(152, 232)
const ART_HEIGHT: float = 66.0

# Наборы карт: название и цвет (красный не берём — он для угроз)
const SETS: Dictionary[String, Array] = {
	"storm": ["Буря Раскола", Color(0.55, 0.45, 1.0)],
	"elements": ["Повелитель стихий", Color(0.3, 0.8, 0.75)],
	"onslaught": ["Натиск", Color(1.0, 0.65, 0.2)],
	"warden": ["Страж топей", Color(0.6, 0.7, 0.8)],
	"runes": ["Руны Стражи", Color(0.88, 0.9, 0.86)],
}
const BASIC_COLOR := Color(0.5, 0.52, 0.56)
const COLOR_PAPER := Color(0.085, 0.105, 0.105)    # тёмный фон карты
const COLOR_TEXT := Color(0.86, 0.88, 0.84)

# Схема области для каждой формы (иконки shape_*.svg) и её название для подсказки
const SHAPE_ICONS: Dictionary[int, String] = {
	CardData.Shape.SELF: "shape_self",
	CardData.Shape.SINGLE: "shape_single",
	CardData.Shape.LINE: "shape_line",
	CardData.Shape.CROSS: "shape_cross",
	CardData.Shape.SQUARE: "shape_square",
	CardData.Shape.ARC: "shape_arc",
	CardData.Shape.CHARGE: "shape_charge",
	CardData.Shape.ALLY: "shape_ally",
	CardData.Shape.WALL: "shape_wall",
	CardData.Shape.LEAP: "shape_leap",
	CardData.Shape.AROUND: "shape_around",
	CardData.Shape.FELL: "shape_fell",
	CardData.Shape.DIAG: "shape_diag",
	CardData.Shape.XCROSS: "shape_xcross",
}
const SHAPE_NAMES: Dictionary[int, String] = {
	CardData.Shape.SELF: "на себя",
	CardData.Shape.SINGLE: "одна клетка",
	CardData.Shape.LINE: "линия от героя",
	CardData.Shape.CROSS: "крест: клетка и 4 соседние",
	CardData.Shape.SQUARE: "квадрат 3×3",
	CardData.Shape.ARC: "дуга: три клетки перед героем",
	CardData.Shape.CHARGE: "таран по прямой",
	CardData.Shape.ALLY: "на союзника",
	CardData.Shape.WALL: "стена из трёх клеток",
	CardData.Shape.LEAP: "прыжок и удар вокруг",
	CardData.Shape.AROUND: "все клетки вокруг героя",
	CardData.Shape.FELL: "дерево падает на 3 клетки",
	CardData.Shape.DIAG: "клетка наискосок от героя",
	CardData.Shape.XCROSS: "косой крест: клетка и 4 наискосок",
}


# owner_color — цвет героя, чья это карта (рамка).
# cost — сколько маны стоит сейчас (со скидкой); -1 — обычная цена карты.
# hotkey — цифра на клавиатуре, которой карта играется в бою (0 — не показывать).
static func make_button(card: CardData, owner_color: Color = Color.GRAY, cost: int = -1, hotkey: int = 0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.size = CARD_SIZE
	b.pivot_offset = Vector2(CARD_SIZE.x / 2.0, CARD_SIZE.y)   # увеличивается «от нижнего края»
	b.focus_mode = Control.FOCUS_NONE   # чтобы пробел/Enter не «нажимали» карту
	b.clip_contents = false
	b.tooltip_text = describe(card, cost)
	var border: Color = UiKit.BRASS if card.is_rare else owner_color
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var frame: StyleBoxFlat = UiKit.box(COLOR_PAPER, border, 2, 10, 0, 0)
		if state == "hover":
			frame.bg_color = COLOR_PAPER.lightened(0.05)
			frame.border_color = border.lightened(0.3)
		elif state == "disabled":
			frame.border_color = border.darkened(0.5)
		frame.shadow_color = Color(0, 0, 0, 0.5)
		frame.shadow_size = 6
		frame.shadow_offset = Vector2(0, 2)
		b.add_theme_stylebox_override(state, frame)

	var tint: Color = set_color(card)

	# --- Рисунок: панель цвета набора и крупная иконка ---
	var art := Panel.new()
	var art_box := StyleBoxFlat.new()
	art_box.bg_color = tint.darkened(0.72)
	art_box.corner_radius_top_left = 8
	art_box.corner_radius_top_right = 8
	art_box.border_color = tint.darkened(0.25)
	art_box.border_width_bottom = 2
	art.add_theme_stylebox_override("panel", art_box)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(2, 2)
	art.size = Vector2(CARD_SIZE.x - 4, ART_HEIGHT)
	b.add_child(art)

	var picture: TextureRect = UiKit.icon_rect(icon_name(card), 42, tint.lightened(0.45))
	picture.position = Vector2((CARD_SIZE.x - 42) / 2.0 - 2, 5)
	art.add_child(picture)

	# Название набора — мелкой строкой по низу рисунка
	var set_label := _label(set_name(card), 10, tint.lightened(0.3))
	set_label.position = Vector2(0, ART_HEIGHT - 17)
	set_label.size = Vector2(art.size.x, 14)
	art.add_child(set_label)

	# Схема клеток, куда попадёт карта, — в правом верхнем углу
	var shape: TextureRect = UiKit.icon_rect(SHAPE_ICONS.get(card.shape, "shape_single"), 30, Color(1, 1, 1, 0.92))
	shape.position = Vector2(art.size.x - 34, 4)
	art.add_child(shape)

	# --- «Камень» маны в левом верхнем углу, слегка выступает за край ---
	var current: int = card.cost if cost < 0 else cost
	var gem := Panel.new()
	var gem_color: Color = UiKit.MANA_CHEAP if current < card.cost else UiKit.MANA
	var gem_box: StyleBoxFlat = UiKit.box(gem_color.darkened(0.25), gem_color.lightened(0.55), 2, 16, 0, 0)
	gem.add_theme_stylebox_override("panel", gem_box)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.position = Vector2(-8, -8)
	gem.size = Vector2(32, 32)
	b.add_child(gem)
	var gem_text := _label(str(current), 18, Color.WHITE, true)
	gem_text.size = Vector2(32, 32)
	gem_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	gem_text.add_theme_constant_override("outline_size", 3)
	gem.add_child(gem_text)

	# --- Название ---
	var title := _label(card.title, 14 if card.title.length() <= 15 else 13,
			UiKit.BRASS.lightened(0.25) if card.is_rare else Color.WHITE, true)
	title.position = Vector2(4, ART_HEIGHT + 4)
	title.size = Vector2(CARD_SIZE.x - 8, 20)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	b.add_child(title)
	if card.is_rare:
		var rare: TextureRect = UiKit.icon_rect("star", 13, UiKit.BRASS)
		rare.position = Vector2(CARD_SIZE.x - 19, ART_HEIGHT - 13)
		b.add_child(rare)

	# --- Значки с числами: урон, блок, дальность… ---
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 9)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.position = Vector2(4, ART_HEIGHT + 25)
	stats.size = Vector2(CARD_SIZE.x - 8, 20)
	for s: Array in stat_list(card):
		stats.add_child(UiKit.chip(s[0], s[1], s[2], "", 14, 15))
	if stats.get_child_count() == 0:
		# Чисел нет — пишем словами, на что действует карта («на себя», «на союзника»…)
		stats.add_child(_label(SHAPE_NAMES.get(card.shape, ""), 12, UiKit.TEXT_DIM))
	b.add_child(stats)

	# --- Описание ---
	var length: int = card.description.length()
	var text := _label(card.description, 12 if length <= 100 else 11, COLOR_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_constant_override("line_spacing", -1)
	text.position = Vector2(8, ART_HEIGHT + 47)
	text.size = Vector2(CARD_SIZE.x - 16, CARD_SIZE.y - text.position.y - 7)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(text)

	# --- Цифра-клавиша (в бою) ---
	if hotkey > 0:
		var key := _label(str(hotkey), 11, UiKit.TEXT_DIM, true)
		var key_bg := Panel.new()
		key_bg.add_theme_stylebox_override("panel", UiKit.box(Color(0.03, 0.04, 0.04, 0.95), UiKit.LINE, 1, 5, 0, 0))
		key_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_bg.size = Vector2(18, 16)
		key_bg.position = Vector2((CARD_SIZE.x - 18) / 2.0, -9)
		key.size = key_bg.size
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_bg.add_child(key)
		b.add_child(key_bg)

	return b


# Карта чуть увеличивается при наведении и встаёт поверх соседних (награды, лавка, колода).
# В бою рука устроена по-своему (карта выезжает снизу) — там это не включаем.
static func add_hover_grow(b: Button) -> void:
	b.pivot_offset = CARD_SIZE / 2.0
	b.mouse_entered.connect(_on_hover.bind(b, true))
	b.mouse_exited.connect(_on_hover.bind(b, false))


static func _on_hover(b: Button, inside: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	var big: bool = inside and not b.disabled
	b.z_index = 2 if big else 0
	var tween: Tween = b.create_tween()
	tween.tween_property(b, "scale", Vector2.ONE * (1.07 if big else 1.0), 0.08)


static func _label(text: String, font_size: int, color: Color, bold: bool = false) -> Label:
	var l: Label = UiKit.make_label(text, font_size, color, bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# Значки под названием: [иконка, текст, цвет]. Показываем только то, что у карты есть.
static func stat_list(card: CardData) -> Array[Array]:
	var list: Array[Array] = []
	if card.damage > 0:
		list.append(["sword", str(card.damage), Color(1.0, 0.9, 0.78)])
	if card.block > 0:
		list.append(["shield", str(card.block), UiKit.BLOCK])
	if card.push > 0:
		list.append(["push", str(card.push), UiKit.TEXT])
	if card.bonus_moves > 0:
		list.append(["boot", "+%d" % card.bonus_moves, UiKit.TEXT])
	if card.draw > 0:
		list.append(["deck", "+%d" % card.draw, UiKit.TEXT])
	var aimed: bool = card.shape != CardData.Shape.SELF and card.shape != CardData.Shape.AROUND
	if aimed and card.cast_range > 1:
		list.append(["target", str(card.cast_range), UiKit.TEXT_DIM])
	return list


# Какой рисунок у карты: свой (поле icon в .tres) или подобранный по стихии и действию
static func icon_name(card: CardData) -> String:
	if card.icon != "" and UiKit.has_icon(card.icon):
		return card.icon
	match card.element:
		CardData.Element.FIRE:
			return "fire"
		CardData.Element.WATER:
			return "drop"
		CardData.Element.ICE:
			return "snow"
		CardData.Element.LIGHTNING:
			return "bolt"
	if card.block > 0:
		return "shield"
	if card.bonus_moves > 0:
		return "dash"
	if card.push > 0 and card.damage == 0:
		return "push"
	if card.shape == CardData.Shape.LINE:
		return "spear"
	return "sword"


# Карта одним текстом (подсказка при наведении)
static func describe(card: CardData, cost: int = -1) -> String:
	var mana: String = str(card.cost)
	if cost >= 0 and cost != card.cost:
		mana = "%d (было %d)" % [cost, card.cost]
	var text: String = "%s%s\n%s · мана: %s\nОбласть: %s" % [
		card.title, "  ★ редкая" if card.is_rare else "", set_name(card), mana, SHAPE_NAMES.get(card.shape, "")]
	if card.shape != CardData.Shape.SELF and card.shape != CardData.Shape.AROUND and card.cast_range > 1:
		text += ", дальность %d" % card.cast_range
	return text + "\n\n" + card.description


static func set_name(card: CardData) -> String:
	if SETS.has(card.card_set):
		return SETS[card.card_set][0]
	return "Базовая"


static func set_color(card: CardData) -> Color:
	if SETS.has(card.card_set):
		return SETS[card.card_set][1]
	return BASIC_COLOR
