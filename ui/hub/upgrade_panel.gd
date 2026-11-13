class_name UpgradePanel
extends HubPanel
# Постоянные улучшения за Отзвуки. Одна панель на три доски: Доска дозора, Круг ордена, Оружейная.
# Строку улучшения (make_row) берёт и Святилище духов.

var board: MetaUpgradeData.Desk = MetaUpgradeData.Desk.PARTY


static func open(parent: Node, for_board: MetaUpgradeData.Desk, for_hero: String = "") -> HubPanel:
	var panel := UpgradePanel.new()
	panel.board = for_board
	panel.hero_id = for_hero
	var titles: Dictionary = {
		MetaUpgradeData.Desk.PARTY: "Доска дозора",
		MetaUpgradeData.Desk.MAGE: "Круг ордена",
		MetaUpgradeData.Desk.KNIGHT: "Оружейная",
	}
	create(parent, panel, titles[for_board], 720)
	Meta.changed.connect(panel._rebuild)
	panel._rebuild()
	return panel


func _rebuild() -> void:
	UiKit.clear(body)
	var notes: Dictionary = {
		MetaUpgradeData.Desk.PARTY: "Записки дозорных: что заставе нужно всем.",
		MetaUpgradeData.Desk.MAGE: "Записи ордена. Больше выбора, а не больше силы.",
		MetaUpgradeData.Desk.KNIGHT: "Стойка и чучело. Больше выбора, а не больше силы.",
	}
	body.add_child(UiKit.make_text(notes[board], 15, UiKit.TEXT_DIM, 660))
	for u in Meta.UPGRADES:
		if u.board == board:
			body.add_child(make_row(u))


static func make_row(u: MetaUpgradeData) -> Control:
	var maxed: bool = Meta.is_maxed(u.id)
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL_LIGHT, 0.6), UiKit.BRASS_DARK if maxed else UiKit.LINE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(ic(u.icon, 30, UiKit.BRASS.lightened(0.15) if maxed else UiKit.TEXT))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.add_child(UiKit.make_label(u.title, 18, UiKit.TEXT, true))
	var desc: Label = UiKit.make_label(u.desc, 14, UiKit.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 380
	info.add_child(desc)
	row.add_child(info)
	# Ступени точками: ● куплено, ○ ещё нет
	var steps: int = u.costs.size()
	var dots: String = ""
	for i in steps:
		dots += "●" if i < Meta.level(u.id) else "○"
		if i < steps - 1:
			dots += " "
	var dots_label: Label = UiKit.make_label(dots, 18, UiKit.BRASS.lightened(0.15))
	dots_label.tooltip_text = "Ступень %d из %d" % [Meta.level(u.id), steps]
	dots_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(dots_label)
	if maxed:
		var done: HBoxContainer = UiKit.chip("star", "Изучено", UiKit.BRASS.lightened(0.15), "", 16, 18)
		done.custom_minimum_size.x = 130
		row.add_child(done)
	else:
		var cost: int = Meta.next_cost(u.id)
		var buy := Button.new()
		buy.focus_mode = Control.FOCUS_NONE
		buy.custom_minimum_size = Vector2(130, 40)
		buy.text = "Изучить  %d" % cost
		buy.icon = UiKit.icon("echo")
		buy.disabled = not Meta.can_buy(u.id)
		if buy.disabled:
			buy.tooltip_text = "Не хватает Отзвуков"
		buy.pressed.connect(Meta.buy.bind(u.id))
		Sfx.bind_button(buy, "coin")
		row.add_child(buy)
	return panel
