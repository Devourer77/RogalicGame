class_name CardView
extends RefCounted
# Как выглядит карта на экране: шапка цвета набора с названием, круглый «камень» маны
# в углу, название набора и описание. Рамка — цвета героя, у редких карт — латунная.
# Используется в бою, в наградах и в лавке — поменяешь здесь, поменяется везде.

const CARD_SIZE := Vector2(146, 190)

# Наборы карт: название и цвет шапки (красный не берём — он для угроз)
const SETS: Dictionary[String, Array] = {
	"storm": ["Буря Раскола", Color(0.55, 0.45, 1.0)],
	"elements": ["Повелитель стихий", Color(0.3, 0.8, 0.75)],
	"onslaught": ["Натиск", Color(1.0, 0.65, 0.2)],
	"warden": ["Страж топей", Color(0.6, 0.7, 0.8)],
}
const BASIC_COLOR := Color(0.45, 0.45, 0.5)
const COLOR_PAPER := Color(0.1, 0.12, 0.12)        # тёмный фон карты
const COLOR_TEXT := Color(0.86, 0.88, 0.84)
const COLOR_MANA := Color(0.2, 0.42, 0.85)
const COLOR_MANA_CHEAP := Color(0.2, 0.7, 0.45)   # карта подешевела
const COLOR_RARE := Color(0.85, 0.68, 0.3)        # латунь редких карт


# owner_color — цвет героя, чья это карта (рамка).
# cost — сколько маны стоит сейчас (со скидкой); -1 — обычная цена карты.
static func make_button(card: CardData, owner_color: Color = Color.GRAY, cost: int = -1) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_NONE   # чтобы пробел/Enter не «нажимали» карту
	b.clip_contents = false
	b.tooltip_text = describe(card, cost)
	var border: Color = COLOR_RARE if card.is_rare else owner_color
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = COLOR_PAPER if state != "hover" else COLOR_PAPER.lightened(0.08)
		box.border_color = border if state != "disabled" else border.darkened(0.55)
		box.set_border_width_all(3)
		box.set_corner_radius_all(9)
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 5
		b.add_theme_stylebox_override(state, box)

	var tint: Color = set_color(card)

	# Шапка цвета набора с названием карты
	var header := Panel.new()
	var header_box := StyleBoxFlat.new()
	header_box.bg_color = tint.darkened(0.55)
	header_box.corner_radius_top_left = 6
	header_box.corner_radius_top_right = 6
	header_box.border_color = tint
	header_box.border_width_bottom = 2
	header.add_theme_stylebox_override("panel", header_box)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.anchor_right = 1.0
	header.offset_left = 3
	header.offset_top = 3
	header.offset_right = -3
	header.offset_bottom = 45
	b.add_child(header)

	var title := _label(card.title + ("  ★" if card.is_rare else ""), 13, COLOR_RARE if card.is_rare else Color.WHITE)
	title.anchor_right = 1.0
	title.offset_left = 30
	title.offset_top = 4
	title.offset_right = -6
	title.offset_bottom = 44
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(title)

	# «Камень» маны в левом верхнем углу, слегка выступает за край
	var current: int = card.cost if cost < 0 else cost
	var gem := Panel.new()
	var gem_box := StyleBoxFlat.new()
	gem_box.bg_color = COLOR_MANA_CHEAP if current < card.cost else COLOR_MANA
	gem_box.set_corner_radius_all(15)
	gem_box.border_color = Color(0.85, 0.92, 1.0)
	gem_box.set_border_width_all(2)
	gem.add_theme_stylebox_override("panel", gem_box)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.position = Vector2(-7, -7)
	gem.size = Vector2(30, 30)
	b.add_child(gem)
	var gem_text := _label(str(current), 16, Color.WHITE)
	gem_text.size = Vector2(30, 30)
	gem_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem.add_child(gem_text)

	# Название набора
	var set_label := _label(set_name(card), 10, tint.lightened(0.25))
	set_label.anchor_right = 1.0
	set_label.offset_top = 48
	set_label.offset_bottom = 62
	b.add_child(set_label)

	# Описание
	var text := _label(card.description, 12 if card.description.length() <= 100 else (11 if card.description.length() <= 122 else 10), COLOR_TEXT)
	text.anchor_right = 1.0
	text.anchor_bottom = 1.0
	text.offset_left = 8
	text.offset_top = 64
	text.offset_right = -8
	text.offset_bottom = -6
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.clip_text = false
	b.add_child(text)
	return b


static func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# Карта одним текстом (подсказка при наведении)
static func describe(card: CardData, cost: int = -1) -> String:
	var rare: String = "  ★" if card.is_rare else ""
	var mana: String = str(card.cost)
	if cost >= 0 and cost != card.cost:
		mana = "%d (было %d)" % [cost, card.cost]
	return "%s%s\n%s\nМана: %s\n\n%s" % [card.title, rare, set_name(card), mana, card.description]


static func set_name(card: CardData) -> String:
	if SETS.has(card.card_set):
		return SETS[card.card_set][0]
	return "Базовая"


static func set_color(card: CardData) -> Color:
	if SETS.has(card.card_set):
		return SETS[card.card_set][1]
	return BASIC_COLOR
