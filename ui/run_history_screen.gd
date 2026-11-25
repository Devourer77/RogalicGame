class_name RunHistoryScreen
extends Control
# Окно «История забегов» (главное меню, экран конца забега): последние забеги, новые сверху.
# Строка забега: дата, победа или где пал отряд, Звон, бои, урон, лучший удар, путь значками.
# Наведи на строку — колоды героев в конце забега. Esc или «Закрыть» — назад.
# Здесь же stats_block() — блок итогов одного забега (его показывает и экран конца забега).

# Значки точек пути по MapNode.Type: BATTLE, EVENT, SHOP, REST, BOSS, ELITE, LAIR
const PATH_ICONS: Array[String] = ["map_battle", "map_event", "map_shop", "map_rest", "map_boss", "map_elite", "map_lair"]


static func open(parent: Node) -> RunHistoryScreen:
	var screen := RunHistoryScreen.new()
	parent.add_child(screen)
	return screen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 96
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.99), UiKit.BRASS, 2)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UiKit.make_title(Loc.t("История забегов"), 28, UiKit.BRASS.lightened(0.2)))
	col.add_child(UiKit.make_divider(500))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(760, minf(480.0, get_viewport_rect().size.y - 170.0))
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var runs: Array = RunHistory.load_all()
	if runs.is_empty():
		list.add_child(UiKit.make_label(Loc.t("Пока ни одного законченного забега."), 15, UiKit.TEXT_DIM))
	for i in range(runs.size() - 1, -1, -1):
		if runs[i] is Dictionary:
			list.add_child(_run_row(runs[i]))

	var close_row := HBoxContainer.new()
	close_row.alignment = BoxContainer.ALIGNMENT_CENTER
	close_row.add_child(UiKit.make_button(Loc.t("Закрыть"), queue_free, "", true))
	col.add_child(close_row)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


# Строка одного забега
func _run_row(run: Dictionary) -> PanelContainer:
	var victory: bool = run.get("victory", false)
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL_LIGHT, 0.8),
			UiKit.BRASS if victory else Color(UiKit.LINE, 0.8))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.tooltip_text = _decks_text(run)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiKit.chip("boss" if victory else "bell", Loc.t("Победа") if victory else Loc.t("Поражение"),
			UiKit.BRASS.lightened(0.2) if victory else UiKit.TEXT, "", 15, 17))
	head.add_child(UiKit.make_label(str(run.get("date", "")).replace("T", " ").left(16), 13, UiKit.TEXT_DIM))
	head.add_child(UiKit.make_label(Loc.t("Звон %d · акт %d · ряд %d") % [int(run.get("bell", 0)), int(run.get("act", 1)), int(run.get("rows", 0))], 13, UiKit.TEXT))
	col.add_child(_numbers_row(run, 13))
	col.add_child(path_row(run.get("path", [])))
	return panel


# Строка чисел: бои, раунды, урон героев, лучший удар, Цепь, кто кого уложил
static func _numbers_row(run: Dictionary, font_size: int) -> Control:
	var parts: PackedStringArray = []
	parts.append(Loc.t("Боёв: %d") % int(run.get("battles", 0)))
	var damage: Dictionary = run.get("damage", {})
	for hero: String in damage:
		parts.append(Loc.t("урон %s: %d") % [Loc.t(hero), int(damage[hero])])
	if int(run.get("best_hit", 0)) > 0:
		parts.append(Loc.t("лучший удар: %d («%s»)") % [int(run["best_hit"]), str(run.get("best_card", ""))])
	if int(run.get("max_chain", 0)) > 0:
		parts.append(Loc.t("Цепь до %d") % int(run["max_chain"]))
	var falls: Array = run.get("falls", [])
	if not falls.is_empty():
		parts.append(Loc.t("пал: %s") % str(falls.back()))
	var label: Label = UiKit.make_label(" · ".join(parts), font_size, UiKit.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 700
	return label


# Путь по карте значками точек
static func path_row(path: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t: Variant in path:
		var i: int = int(t)
		if i >= 0 and i < PATH_ICONS.size() and UiKit.has_icon(PATH_ICONS[i]):
			row.add_child(UiKit.icon_rect(PATH_ICONS[i], 16, UiKit.TEXT_DIM))
	return row


static func _decks_text(run: Dictionary) -> String:
	var lines: PackedStringArray = []
	var decks: Dictionary = run.get("decks", {})
	for hero: String in decks:
		var titles: PackedStringArray = []
		for t: Variant in decks[hero]:
			titles.append(Loc.t(str(t)))
		lines.append(Loc.t("%s (%d): %s") % [Loc.t(hero), titles.size(), ", ".join(titles)])
	lines.append(Loc.t("Сид: %d") % int(run.get("seed", 0)))
	return "\n".join(lines)


# Блок итогов одного забега для экрана конца забега: числа, путь, размер колод (наведи — состав)
static func stats_block(run: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var numbers: Control = _numbers_row(run, 15)
	(numbers as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numbers.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(numbers)
	var path: HBoxContainer = path_row(run.get("path", []))
	path.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(path)
	var decks: Dictionary = run.get("decks", {})
	var sizes: PackedStringArray = []
	for hero: String in decks:
		sizes.append(Loc.t("%s — %d карт") % [Loc.t(hero), (decks[hero] as Array).size()])
	if not sizes.is_empty():
		var deck_label: Label = UiKit.make_label(Loc.t("Колоды: ") + ", ".join(sizes), 14, UiKit.TEXT_DIM)
		deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		deck_label.tooltip_text = _decks_text(run)
		deck_label.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(deck_label)
	return box
