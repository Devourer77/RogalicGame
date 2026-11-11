class_name UiKit
extends RefCounted
# Мелкие помощники для экранов-меню, чтобы не повторять одно и то же в каждом скрипте.

const BG_COLOR := Color(0.08, 0.09, 0.12)


# Тёмный фон на весь экран + колонка по центру. Возвращает колонку,
# в которую экран добавляет свои надписи и кнопки.
static func make_screen(parent: Control) -> VBoxContainer:
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	return column


static func make_label(text: String, font_size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 800
	l.add_theme_font_size_override("font_size", font_size)
	return l


static func make_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 44)
	b.pressed.connect(on_pressed)
	return b


# Строка «HP героев / золото» для верха экранов
static func run_status() -> String:
	var parts: PackedStringArray = []
	for rh in Run.party:
		parts.append("%s %d/%d HP (%d карт)" % [rh.data.title, rh.hp, rh.data.max_hp, rh.deck.size()])
	parts.append("Золото: %d" % Run.gold)
	return "     ".join(parts)


static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
