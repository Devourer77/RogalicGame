extends Control
# Лавка: купить карты (по две на каждого героя) или за золото
# убрать одну карту из колоды любого героя.
# Убирать слабые карты полезно: сильные будут приходить в руку чаще.

var _column: VBoxContainer


func _ready() -> void:
	_column = UiKit.make_screen(self)
	_column.add_theme_constant_override("separation", 12)
	_rebuild()


# Экран перестраивается целиком после каждой покупки — так проще, чем обновлять кусочки
func _rebuild() -> void:
	UiKit.clear(_column)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	head.add_child(UiKit.icon_rect("shop", 34, UiKit.GOLD))
	head.add_child(UiKit.make_title("Лавка", 40, UiKit.BRASS.lightened(0.25)))
	_column.add_child(head)
	_column.add_child(UiKit.make_text("«Бродячий торговец не спрашивает, откуда золото».", 15, UiKit.TEXT_DIM))
	_column.add_child(UiKit.party_bar(_show_deck))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	_column.add_child(row)
	for item: Dictionary in Run.shop_stock:
		var rh: RunHero = item["hero"]
		var card: CardData = item["card"]
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 8)
		var price: int = Run.card_price(card)
		var affordable: bool = Run.gold >= price
		var owner_row := HBoxContainer.new()
		owner_row.alignment = BoxContainer.ALIGNMENT_CENTER
		owner_row.add_theme_constant_override("separation", 6)
		owner_row.add_child(UiKit.icon_rect(rh.data.id if UiKit.has_icon(rh.data.id) else "star", 16, rh.data.color.lightened(0.4)))
		owner_row.add_child(UiKit.make_label(rh.data.title, 13, rh.data.color.lightened(0.5)))
		slot.add_child(owner_row)
		var b: Button = CardView.make_button(card, rh.data.color)
		CardView.add_hover_grow(b)
		b.disabled = not affordable
		if b.disabled:
			b.modulate = Color(0.6, 0.62, 0.66)
		b.pressed.connect(_buy.bind(item))
		slot.add_child(b)
		# Ценник: монета и цена; если не хватает золота — тусклый
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL_LIGHT, UiKit.BRASS_DARK if affordable else UiKit.LINE, 1, 12, 12, 3))
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tag.add_child(UiKit.chip("coin", str(price), UiKit.GOLD if affordable else UiKit.TEXT_DIM.darkened(0.2),
				"" if affordable else "Не хватает золота", 17, 18))
		slot.add_child(tag)
		row.add_child(slot)
	if Run.shop_stock.is_empty():
		_column.add_child(UiKit.make_text("Карты раскуплены.", 18, UiKit.TEXT_DIM))

	var remove: Button = UiKit.make_button("Убрать карту из колоды  ·  %d" % Run.REMOVE_CARD_PRICE, _start_removal, "discard")
	remove.custom_minimum_size.x = 320
	remove.disabled = Run.shop_removal_used or Run.gold < Run.REMOVE_CARD_PRICE
	remove.tooltip_text = "Меньше слабых карт — сильные приходят в руку чаще. Один раз за лавку."
	if Run.shop_removal_used:
		remove.text = "Карта уже убрана"
	_column.add_child(remove)
	var leave: Button = UiKit.make_button("Уйти", Run.goto.bind(Run.MAP_SCENE), "", true)
	leave.custom_minimum_size.x = 320
	_column.add_child(leave)


func _buy(item: Dictionary) -> void:
	var card: CardData = item["card"]
	var price: int = Run.card_price(card)
	if Run.gold < price:
		return
	Run.gold -= price
	Run.add_card(item["hero"] as RunHero, card)   # заодно запишет карту в Запас Караульни
	Run.shop_stock.erase(item)
	_rebuild()


# Окно с колодами героев: нажми на карту, которую убрать. Меньше 5 карт оставить нельзя.
func _start_removal() -> void:
	var sections: Array[Dictionary] = []
	for rh in Run.party:
		sections.append({"title": rh.data.title, "color": rh.data.color, "cards": rh.deck})
	DeckOverlay.open(self, "Какую карту убрать?", sections,
			"Нажми на карту — она навсегда уйдёт из колоды. Цена: %d золота." % Run.REMOVE_CARD_PRICE,
			_remove_card, func(section: int) -> bool: return Run.party[section].deck.size() > 5)


func _remove_card(section: int, index: int) -> void:
	Run.gold -= Run.REMOVE_CARD_PRICE
	Run.party[section].deck.remove_at(index)
	Run.shop_removal_used = true
	_rebuild()


func _show_deck(rh: RunHero) -> void:
	var sections: Array[Dictionary] = [{"title": rh.data.title, "color": rh.data.color, "cards": rh.deck}]
	DeckOverlay.open(self, "Колода: %s" % rh.data.title, sections)
