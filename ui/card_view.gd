class_name CardView
extends RefCounted
# Как выглядит карта на экране (стиль утверждён 13.11.2026, скилл «дизайн карт»). Сверху вниз:
#   рисунок-иконка на фоне цвета набора, внизу язычок с названием набора, справа внизу схема клеток;
#   слева вверху гранёный «камень» маны; полоса с названием; значки с числами; описание.
# Рамка — цвет героя (рыцарь — сталь с горчичными уголками, маг — тёмно-синяя с фиолетовыми),
# у редких — латунная со свечением и звездой. Углы срезаны (фаски) — как грани low-poly моделей.
# Используется в бою, в наградах, в лавке и в просмотре колоды — поменяешь здесь, поменяется везде.

const CARD_SIZE := Vector2(152, 232)
const FRAME: int = 4                 # толщина рамки
const ART_HEIGHT: float = 102.0      # высота рисунка
const NAME_HEIGHT: float = 20.0      # высота полосы названия
const CHIPS_HEIGHT: float = 20.0     # высота ряда значков

# Наборы карт: название и цвет фона рисунка (красный не берём — он для угроз)
const SETS: Dictionary[String, Array] = {
	"storm": ["Буря Раскола", Color("5a5bb8")],
	"elements": ["Повелитель стихий", Color("6cc5c4")],
	"onslaught": ["Натиск", Color("b0602f")],
	"warden": ["Страж топей", Color("73818d")],
	"runes": ["Руны Стражи", Color("8f8a6c")],
	"redesign": ["Тактика отряда", Color("9a8550")],
	# Новая система карт: архетипы базовых пулов (тз-карты.md)
	"m_charge": ["Заряд", Color("3a4a8c")],
	"m_kinetic": ["Перестановка", Color("4d5f9e")],
	"m_flow": ["Направление", Color("2f6f86")],
	"k_onslaught": ["Разгон", Color("8a6a3a")],
	"k_warden": ["Страж", Color("73818d")],
	"k_rage": ["Ярость", Color("7a6a52")],
}
# Роли карт (значок-подпись рядом с архетипом)
const ROLE_NAMES: Array[String] = ["", "Ход", "Заготовка", "Связка", "Развязка"]
const BASIC_COLOR := Color("8d8c8a")

# Рамки героев: [основной цвет, цвет уголков]
const KNIGHT_FRAME: Array[Color] = [Color("5b6568"), Color("9a7a2a")]
const MAGE_FRAME: Array[Color] = [Color("2f3a55"), Color("6b4c9a")]
const RARE_FRAME: Array[Color] = [Color("8a7246"), Color("d8b468")]

const COLOR_PAPER := Color("1f272d")      # тело карты
const COLOR_NAME_BAR := Color("30383f")   # полоса названия
const COLOR_DARK := Color("151b20")       # подложки значков, схемы, язычка
const COLOR_TEXT := Color("d9dde0")
const COLOR_TEXT_DIM := Color("9aa3aa")
const COLOR_RARE_TITLE := Color("c9a55a")
const COLOR_DAMAGE := Color("eef1f3")     # урон на картах героев — светлый, не красный
const COLOR_MANA := Color("3f6fc0")
const COLOR_MANA_CHEAP := Color("4caf6a")

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
}
const SHAPE_NAMES: Dictionary[int, String] = {
	CardData.Shape.SELF: "на себя",
	CardData.Shape.SINGLE: "одна клетка",
	CardData.Shape.LINE: "линия от героя",
	CardData.Shape.CROSS: "клетка и 6 соседних",
	CardData.Shape.SQUARE: "клетка и 6 соседних",
	CardData.Shape.ARC: "дуга: три клетки перед героем",
	CardData.Shape.CHARGE: "таран по прямой",
	CardData.Shape.ALLY: "на союзника",
	CardData.Shape.WALL: "стена из трёх клеток",
	CardData.Shape.LEAP: "прыжок и удар вокруг",
	CardData.Shape.AROUND: "все клетки вокруг героя",
	CardData.Shape.FELL: "дерево падает на 3 клетки",
}


# owner_color — цвет героя, чья это карта (по нему выбирается рамка: синеватый — маг, остальное — рыцарь).
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

	var colors: Array[Color] = frame_colors(card, owner_color)
	var frame_color: Color = colors[0]
	var accent: Color = colors[1]
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var frame: StyleBoxFlat = _chamfer_box(COLOR_PAPER, frame_color, FRAME, 8)
		frame.shadow_color = Color(0, 0, 0, 0.55)
		frame.shadow_size = 6
		frame.shadow_offset = Vector2(0, 2)
		if card.is_rare:
			# Мягкое латунное свечение вокруг редкой карты
			frame.shadow_color = Color(accent, 0.45)
			frame.shadow_size = 7
			frame.shadow_offset = Vector2.ZERO
		if state == "hover":
			frame.border_color = frame_color.lightened(0.25)
		elif state == "disabled":
			frame.border_color = frame_color.darkened(0.4)
		b.add_theme_stylebox_override(state, frame)

	var inner_width: float = CARD_SIZE.x - FRAME * 2
	var tint: Color = set_color(card)

	# --- Рисунок: панель цвета набора и крупная иконка ---
	var art := Panel.new()
	var art_box := StyleBoxFlat.new()
	art_box.bg_color = tint.darkened(0.3)
	art_box.border_color = accent
	art_box.border_width_bottom = 2
	art_box.corner_radius_top_left = 5
	art_box.corner_radius_top_right = 5
	art_box.corner_detail = 1    # срезанные углы вместо скруглённых
	art.add_theme_stylebox_override("panel", art_box)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(FRAME, FRAME)
	art.size = Vector2(inner_width, ART_HEIGHT)
	b.add_child(art)

	var picture: TextureRect = UiKit.icon_rect(icon_name(card), 64, tint.lightened(0.82))
	picture.position = Vector2((inner_width - 64) / 2.0, 14)
	art.add_child(picture)

	# Язычок с названием набора — по центру низа рисунка (ширина подстраивается под текст)
	var set_label := _label(set_name(card).to_upper(), 8, COLOR_TEXT_DIM, true)
	var set_tab := PanelContainer.new()
	var tab_box: StyleBoxFlat = UiKit.box(Color(COLOR_DARK, 0.92), Color(0, 0, 0, 0), 0, 0, 7, 0)
	tab_box.corner_radius_top_left = 3
	tab_box.corner_radius_top_right = 3
	tab_box.corner_detail = 1
	set_tab.add_theme_stylebox_override("panel", tab_box)
	set_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_tab.add_child(set_label)
	var set_center := CenterContainer.new()
	set_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_center.position = Vector2(0, ART_HEIGHT - 14)
	set_center.size = Vector2(inner_width, 12)
	set_center.add_child(set_tab)
	art.add_child(set_center)

	# Схема клеток, куда попадёт карта, — в правом верхнем углу рисунка, на тёмной подложке
	var shape_bg := Panel.new()
	var shape_box: StyleBoxFlat = UiKit.box(Color(COLOR_DARK, 0.85), Color(1, 1, 1, 0.12), 1, 3, 0, 0)
	shape_box.corner_detail = 1
	shape_bg.add_theme_stylebox_override("panel", shape_box)
	shape_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shape_bg.size = Vector2(30, 30)
	shape_bg.position = Vector2(inner_width - 33, 3)
	var shape: TextureRect = UiKit.icon_rect(SHAPE_ICONS.get(card.shape, "shape_single"), 26, Color(1, 1, 1, 0.95))
	shape.position = Vector2(2, 2)
	shape_bg.add_child(shape)
	art.add_child(shape_bg)

	# --- Уголки цвета героя (три угла; в левом верхнем стоит камень маны) ---
	for corner: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		b.add_child(_corner_line(corner, accent))

	# --- Полоса названия ---
	var name_bar := Panel.new()
	name_bar.add_theme_stylebox_override("panel", UiKit.box(COLOR_NAME_BAR, Color(0, 0, 0, 0), 0, 0, 0, 0))
	name_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_bar.position = Vector2(FRAME, FRAME + ART_HEIGHT)
	name_bar.size = Vector2(inner_width, NAME_HEIGHT)
	b.add_child(name_bar)

	var title_text: String = card.title + (" ★" if card.is_rare else "")
	var title_size: int = _fit_font_size(UiKit.font_title(), title_text, inner_width - 8, 13, 9)
	var title := _label(title_text, title_size, COLOR_RARE_TITLE if card.is_rare else COLOR_TEXT)
	title.add_theme_font_override("font", UiKit.font_title())
	title.size = name_bar.size
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	name_bar.add_child(title)

	# --- Значки с числами: урон, блок, дальность… («таблетки» на тёмной подложке) ---
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 4)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.position = Vector2(FRAME, FRAME + ART_HEIGHT + NAME_HEIGHT + 3)
	stats.size = Vector2(inner_width, CHIPS_HEIGHT)
	var list: Array[Array] = stat_list(card)
	for s: Array in list.slice(0, 4):   # больше четырёх в ширину не влезает
		stats.add_child(_pill(UiKit.chip(s[0], s[1], s[2], "", 11, 12)))
	if stats.get_child_count() == 0:
		# Чисел нет — пишем словами, на что действует карта («на себя», «на союзника»…)
		stats.add_child(_pill(UiKit.make_label(SHAPE_NAMES.get(card.shape, ""), 10, COLOR_TEXT_DIM, true)))
	b.add_child(stats)

	# --- Описание: размер шрифта подбирается, чтобы длинный текст влез целиком ---
	var text_top: float = FRAME + ART_HEIGHT + NAME_HEIGHT + CHIPS_HEIGHT + 6
	var text_area := Vector2(inner_width - 10, CARD_SIZE.y - FRAME - 3 - text_top)
	var text_size: int = _fit_text_size(card.description, text_area, 11, 8)
	var text := _label(card.description, text_size, COLOR_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_constant_override("line_spacing", -2)
	text.position = Vector2(FRAME + 5, text_top)
	text.size = text_area
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_child(text)

	# --- «Камень» маны: гранёный ромб в левом верхнем углу поверх рамки ---
	var current: int = card.cost if cost < 0 else cost
	var gem_color: Color = COLOR_MANA_CHEAP if current < card.cost else COLOR_MANA
	var gem := Panel.new()
	var gem_box: StyleBoxFlat = UiKit.box(gem_color, gem_color.darkened(0.55), 2, 2, 0, 0)
	gem_box.shadow_color = Color(0, 0, 0, 0.6)
	gem_box.shadow_size = 2
	gem.add_theme_stylebox_override("panel", gem_box)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.size = Vector2(20, 20)
	gem.pivot_offset = gem.size / 2.0
	gem.rotation = PI / 4.0
	gem.position = Vector2(16, 16) - gem.size / 2.0
	b.add_child(gem)
	# Блик на верхней грани камня
	var shine := Panel.new()
	shine.add_theme_stylebox_override("panel", UiKit.box(Color(gem_color.lightened(0.45), 0.9), Color(0, 0, 0, 0), 0, 1, 0, 0))
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.size = Vector2(8, 8)
	shine.position = Vector2(3, 3)
	gem.add_child(shine)
	var gem_text := _label(str(current), 16, Color.WHITE, true)
	gem_text.size = Vector2(32, 32)
	gem_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	gem_text.add_theme_constant_override("outline_size", 4)
	b.add_child(gem_text)

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


# Цвета рамки: [основной, уголки]. Редкая — латунь, иначе по цвету героя.
static func frame_colors(card: CardData, owner_color: Color) -> Array[Color]:
	if card.is_rare:
		return RARE_FRAME
	if owner_color.b > owner_color.r + 0.15:
		return MAGE_FRAME
	return KNIGHT_FRAME


# Прямоугольник со срезанными углами (фаски вместо скруглений)
static func _chamfer_box(bg: Color, border: Color, width: int, cut: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = UiKit.box(bg, border, width, cut, 0, 0)
	box.corner_detail = 1
	return box


# Уголок-«скобка» цвета героя: линия вдоль двух краёв и среза угла.
# corner — какой угол: (1, 0) правый верхний, (0, 1) левый нижний, (1, 1) правый нижний.
static func _corner_line(corner: Vector2, color: Color) -> Line2D:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	var arm: float = 20.0
	var cut: float = 8.0
	var o: float = 1.5   # линия идёт по середине рамки
	# Точки для правого верхнего угла, остальные — зеркально
	var points: PackedVector2Array = [Vector2(-arm, o), Vector2(-cut, o), Vector2(-o, cut), Vector2(-o, arm)]
	for i: int in points.size():
		var p: Vector2 = points[i]
		var x: float = CARD_SIZE.x + p.x if corner.x > 0 else -p.x
		var y: float = CARD_SIZE.y - p.y if corner.y > 0 else p.y
		points[i] = Vector2(x, y)
	line.points = points
	return line


# Значок с числом в тёмной «таблетке»
static func _pill(content: Control) -> PanelContainer:
	var pill := PanelContainer.new()
	var box: StyleBoxFlat = UiKit.box(COLOR_DARK, Color(1, 1, 1, 0.11), 1, 9, 5, 1)
	pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(content)
	return pill


# Самый крупный размер шрифта (от big до small), при котором строка влезает в ширину
static func _fit_font_size(font: Font, text: String, width: float, big: int, small: int) -> int:
	for size: int in range(big, small - 1, -1):
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			return size
	return small


# Самый крупный размер шрифта, при котором абзац с переносами влезает в область
static func _fit_text_size(text: String, area: Vector2, big: int, small: int) -> int:
	var font: Font = ThemeDB.fallback_font
	for size: int in range(big, small - 1, -1):
		var h: float = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, area.x, size,
				-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE).y
		var lines: int = int(round(h / font.get_height(size)))
		if h - lines * 2 <= area.y:   # line_spacing -2 у метки
			return size
	return small


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
	if big:
		Sfx.play("ui_hover", 0.05)
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
		list.append(["sword", str(card.damage), COLOR_DAMAGE])
	if card.block > 0:
		list.append(["shield", str(card.block), UiKit.BLOCK])
	if card.push > 0:
		list.append(["push", str(card.push), UiKit.TEXT])
	if card.bonus_moves > 0:
		list.append(["boot", "+%d" % card.bonus_moves, UiKit.TEXT])
	if card.draw > 0:
		list.append(["deck", "+%d" % card.draw, UiKit.TEXT])
	if card.rage_gain > 0:
		list.append(["rage", "+%d" % card.rage_gain, UiKit.RAGE])
	if card.momentum_gain > 0:
		list.append(["momentum", "+%d" % card.momentum_gain, UiKit.MOMENTUM])
	if card.charge_gain > 0:
		list.append(["bolt", "+%d" % card.charge_gain, UiKit.CHARGE])
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
	var scrap: PackedStringArray = []
	if card.scrap_moves > 0:
		scrap.append("шагов: %d" % card.scrap_moves)
	if card.scrap_block > 0:
		scrap.append("блок: %d" % card.scrap_block)
	if card.scrap_mana > 0:
		scrap.append("мана: +%d" % card.scrap_mana)
	if not scrap.is_empty():
		text += "\n\n«В ноги» (X, бесплатно): " + ", ".join(scrap)
	return text + "\n\n" + card.description


static func set_name(card: CardData) -> String:
	if SETS.has(card.card_set):
		var n: String = SETS[card.card_set][0]
		if card.role != CardData.Role.NONE:
			n += " · " + ROLE_NAMES[card.role]
		return n
	return "Базовая"


static func set_color(card: CardData) -> Color:
	if SETS.has(card.card_set):
		return SETS[card.card_set][1]
	return BASIC_COLOR
