extends Control
# Лавка: купить карты (по две на каждого героя) или за золото
# убрать одну карту из колоды любого героя.
# Убирать слабые карты полезно: сильные будут приходить в руку чаще.

var _column: VBoxContainer
var _removing: bool = false   # показываем ли сейчас список колод для удаления


func _ready() -> void:
	_column = UiKit.make_screen(self)
	_rebuild()


# Экран перестраивается целиком после каждой покупки — так проще, чем обновлять кусочки
func _rebuild() -> void:
	UiKit.clear(_column)
	_column.add_child(UiKit.make_label("Лавка", 40))
	_column.add_child(UiKit.make_label(UiKit.run_status(), 16))

	if _removing:
		_build_removal_list()
		return

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_column.add_child(row)
	for item: Dictionary in Run.shop_stock:
		var rh: RunHero = item["hero"]
		var card: CardData = item["card"]
		var slot := VBoxContainer.new()
		var b: Button = CardView.make_button(card, rh.data.color)
		var price: int = Run.card_price(card)
		b.disabled = Run.gold < price
		if b.disabled:
			b.modulate = Color(0.55, 0.55, 0.6)
		b.pressed.connect(_buy.bind(item))
		slot.add_child(b)
		var price_label := Label.new()
		price_label.text = "%s · %d золота" % [rh.data.title, price]
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(price_label)
		row.add_child(slot)
	if Run.shop_stock.is_empty():
		_column.add_child(UiKit.make_label("Карты раскуплены", 18))

	var remove: Button = UiKit.make_button("Убрать карту из колоды (%d золота)" % Run.REMOVE_CARD_PRICE, _start_removal)
	remove.disabled = Run.shop_removal_used or Run.gold < Run.REMOVE_CARD_PRICE
	_column.add_child(remove)
	_column.add_child(UiKit.make_button("Уйти", Run.goto.bind(Run.MAP_SCENE)))


func _buy(item: Dictionary) -> void:
	var card: CardData = item["card"]
	var price: int = Run.card_price(card)
	if Run.gold < price:
		return
	Run.gold -= price
	(item["hero"] as RunHero).deck.append(card)
	Run.shop_stock.erase(item)
	_rebuild()


func _start_removal() -> void:
	_removing = true
	_rebuild()


# Колоды героев: нажми на карту, которую убрать. Меньше 5 карт оставить нельзя.
func _build_removal_list() -> void:
	_column.add_child(UiKit.make_label("Какую карту убрать?", 22))
	for rh in Run.party:
		_column.add_child(UiKit.make_label(rh.data.title, 18))
		var grid := GridContainer.new()
		grid.columns = 5
		_column.add_child(grid)
		for i in rh.deck.size():
			var b := Button.new()
			b.text = rh.deck[i].title
			b.custom_minimum_size = Vector2(150, 34)
			b.disabled = rh.deck.size() <= 5
			b.pressed.connect(_remove_card.bind(rh, i))
			grid.add_child(b)
	_column.add_child(UiKit.make_button("Передумал", _cancel_removal))


func _remove_card(rh: RunHero, index: int) -> void:
	Run.gold -= Run.REMOVE_CARD_PRICE
	rh.deck.remove_at(index)
	Run.shop_removal_used = true
	_removing = false
	_rebuild()


func _cancel_removal() -> void:
	_removing = false
	_rebuild()
