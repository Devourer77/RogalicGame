class_name BellPanel
extends HubPanel
# Колокол: выбор сложности (Звон 0–5). Закрытые Звоны — с замком.

var _detail: Label


static func open(parent: Node, for_hero: String = "") -> HubPanel:
	var panel := BellPanel.new()
	panel.hero_id = for_hero
	create(parent, panel, "Колокол Стражи", 760)
	Meta.changed.connect(panel._rebuild)
	panel._rebuild()
	return panel


func _rebuild() -> void:
	UiKit.clear(body)
	body.add_child(UiKit.make_text("Каждый звон — новое возвращение к началу пути, и путь каждый раз тяжелее. Звоны накапливаются: Звон 3 включает правила 1, 2 и 3.", 15, UiKit.TEXT_DIM, 700))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)
	for bell in range(Meta.MAX_BELL + 1):
		row.add_child(_make_bell_button(bell))
	_detail = UiKit.make_text("", 16, UiKit.TEXT, 700)
	_detail.custom_minimum_size.y = 150
	body.add_child(_detail)
	_show_detail(Meta.bell_chosen)


func _make_bell_button(bell: int) -> Button:
	var is_open: bool = Meta.is_bell_open(bell)
	var chosen: bool = bell == Meta.bell_chosen
	var b := Button.new()
	b.custom_minimum_size = Vector2(104, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.text = "Звон %d" % bell
	b.icon = UiKit.icon("bell" if is_open else "lock")
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 40)
	if is_open:
		b.tooltip_text = "Звон %d. Отзвуки: +%d%%." % [bell, roundi(Meta.BELL_ECHO_BONUS * bell * 100.0)]
		b.pressed.connect(Meta.choose_bell.bind(bell))
		if chosen:
			recolor_button(b, UiKit.BRASS.lightened(0.2), 3)
	else:
		b.tooltip_text = "Закрыт. Пройди забег до конца на Звоне %d." % (bell - 1)
		b.modulate = Color(1, 1, 1, 0.5)
		b.pressed.connect(_show_detail.bind(bell))   # нажатие на закрытый просто показывает условие
	b.mouse_entered.connect(_show_detail.bind(bell))
	b.mouse_exited.connect(_show_detail.bind(Meta.bell_chosen))
	return b


func _show_detail(bell: int) -> void:
	if _detail == null:
		return
	var lines: PackedStringArray = []
	var head: String = "Звон %d" % bell
	if bell == Meta.bell_chosen and Meta.is_bell_open(bell):
		head += "  ·  выбран на следующий забег"
	lines.append(head)
	if not Meta.is_bell_open(bell):
		lines.append("Закрыт. Пройди забег до конца на Звоне %d." % (bell - 1))
	if bell == 0:
		lines.append(Meta.BELL_RULES[0])
	for i in range(1, bell + 1):
		lines.append("%d. %s" % [i, Meta.BELL_RULES[i]])
	if bell > 0:
		lines.append("Отзвуков за забег: +%d%%." % roundi(Meta.BELL_ECHO_BONUS * bell * 100.0))
	_detail.text = "\n".join(lines)
