class_name DeckOverlay
extends RefCounted
# Окно поверх экрана со списком карт: посмотреть колоду героя или выбрать карту (например, чтобы убрать её в лавке).
# Пример:  DeckOverlay.open(self, "Колода мага", [{"title": "Маг", "color": цвет, "cards": колода}])

# sections — список словарей {"title": String, "color": Color, "cards": Array[CardData]}.
# on_pick — если задан, карты можно нажимать: вызовется on_pick(номер_раздела, номер_карты), и окно закроется.
# can_pick — можно ли выбирать карты в разделе (например, нельзя оставить меньше 5 карт): func(номер_раздела) -> bool.
static func open(parent: Control, title: String, sections: Array[Dictionary], note: String = "",
		on_pick: Callable = Callable(), can_pick: Callable = Callable()) -> Control:
	# Затемнение на весь экран: заодно не даёт нажать кнопки под окном
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.02, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel: PanelContainer = UiKit.make_panel(Color(0.06, 0.08, 0.08, 0.98), UiKit.BRASS_DARK, 2)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	column.add_child(UiKit.make_title(title, 26, UiKit.BRASS.lightened(0.2)))
	if note != "":
		column.add_child(UiKit.make_text(note, 14, UiKit.TEXT_DIM, 600))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(5 * (CardView.CARD_SIZE.x + 12) + 24, 486)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for s in sections.size():
		var section: Dictionary = sections[s]
		var cards: Array = section["cards"]
		var allowed: bool = on_pick.is_valid() and (not can_pick.is_valid() or can_pick.call(s))
		var caption: String = "%s — карт: %d" % [section["title"], cards.size()]
		if on_pick.is_valid() and not allowed:
			caption += " (меньше оставить нельзя)"
		list.add_child(UiKit.make_label(caption, 16, (section["color"] as Color).lightened(0.4), true))
		# Поля вокруг сетки: «камень» маны выступает за край карты, без полей его срежет
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		list.add_child(margin)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 14)
		margin.add_child(grid)
		for i in cards.size():
			var b: Button = CardView.make_button(cards[i], section["color"])
			CardView.add_hover_grow(b)
			if on_pick.is_valid():
				b.disabled = not allowed
				if b.disabled:
					b.modulate = Color(0.6, 0.62, 0.66)
				b.pressed.connect(func() -> void:
					shade.queue_free()
					on_pick.call(s, i)
				)
			grid.add_child(b)

	var close: Button = UiKit.make_button("Закрыть" if not on_pick.is_valid() else "Передумал", shade.queue_free)
	close.custom_minimum_size = Vector2(200, 40)
	column.add_child(close)
	return shade
