class_name CharmPanel
extends HubPanel
# Полка трофеев: обереги на следующий забег. Открытый — в место (клик), закрытый покупаемый —
# купить за Отзвуки, «только из пути» — найти трофеем за босса или в тайнике.

static func open(parent: Node, for_hero: String = "") -> HubPanel:
	var panel := CharmPanel.new()
	panel.hero_id = for_hero
	create(parent, panel, "Полка трофеев", 860)
	Meta.changed.connect(panel._rebuild)
	panel._rebuild()
	return panel


func _rebuild() -> void:
	UiKit.clear(body)
	var slots: int = Meta.charm_slots()
	body.add_child(UiKit.make_text("Вещи Стражи, которые удалось вынести из топей. Мест для оберегов: %d. Нажми на открытый оберег, чтобы взять или снять его." % slots, 15, UiKit.TEXT_DIM, 800))

	# Места
	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 12)
	body.add_child(slot_row)
	var chosen: Array[String] = Meta.valid_chosen()
	for i in range(2):
		var frame: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL_LIGHT, 0.5), UiKit.BRASS_DARK if i < slots else UiKit.LINE.darkened(0.3), 2)
		frame.custom_minimum_size = Vector2(300, 48)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		frame.add_child(line)
		if i >= slots:
			line.add_child(ic("lock", 20, UiKit.TEXT_DIM))
			line.add_child(UiKit.make_label("Закрыто · улучшение «Второй оберег»", 14, UiKit.TEXT_DIM))
		elif i < chosen.size():
			var c: RelicData = Meta.charm_data(chosen[i])
			line.add_child(ic(c.icon, 22, UiKit.BRASS.lightened(0.2)))
			line.add_child(UiKit.make_label(c.title, 16, UiKit.TEXT, true))
		else:
			line.add_child(UiKit.make_label("Не выбран", 15, UiKit.TEXT_DIM))
			frame.tooltip_text = "Выбери открытый оберег ниже — он пойдёт в следующий забег."
		slot_row.add_child(frame)

	# Сетка оберегов: 2 ряда по 5
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for c in Meta.CHARMS:
		grid.add_child(_make_tile(c))
	body.add_child(UiKit.make_label("Открыто: %d / %d" % [Meta.opened_count(), Meta.CHARMS.size()], 14, UiKit.TEXT_DIM))


func _make_tile(c: RelicData) -> Button:
	var is_open: bool = Meta.is_charm_open(c.id)
	var picked: bool = Meta.charms_chosen.has(c.id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(160, 132)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	b.add_child(box)
	var icon_name: String = c.icon if is_open else ("lock" if c.buyable else "star")
	var icon: TextureRect = ic(icon_name, 28, UiKit.BRASS.lightened(0.15) if is_open else UiKit.TEXT_DIM)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var name_label: Label = UiKit.make_label(c.title if (is_open or c.buyable) else "???", 14, UiKit.TEXT if is_open else UiKit.TEXT_DIM, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = 140
	box.add_child(name_label)
	if is_open:
		var state: Label = UiKit.make_label("В месте" if picked else "Открыт", 13, UiKit.BRASS.lightened(0.2) if picked else UiKit.TEXT_DIM)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(state)
		b.tooltip_text = "%s\n%s\n\nНажми, чтобы %s." % [c.title, c.desc, "снять" if picked else "взять в забег"]
		b.pressed.connect(Meta.toggle_charm.bind(c.id))
		if picked:
			recolor_button(b, UiKit.BRASS.lightened(0.2), 3)
	elif c.buyable:
		var afford: bool = Meta.echoes >= c.unlock_cost
		var price: HBoxContainer = echo_cost(c.unlock_cost, afford)
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(price)
		b.modulate = Color(1, 1, 1, 0.8 if afford else 0.55)
		b.tooltip_text = "%s\n%s\n\nПод тканью. Открыть за %d Отзвуков." % [c.title, c.desc, c.unlock_cost]
		b.pressed.connect(Meta.buy_charm.bind(c.id))
	else:
		var hint: Label = UiKit.make_label("Ещё не найден", 13, UiKit.TEXT_DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hint)
		b.modulate = Color(1, 1, 1, 0.55)
		b.tooltip_text = "Ещё не найден · трофей за босса или тайник в пути."
	return b
