class_name BarracksPanel
extends HubPanel
# Караульня: стартовые колоды героев. Заменять, добавлять и убирать карты можно,
# но колода никогда не меньше базовой. Правила — в scripts/hub/loadout.gd.
#
# Как менять: клик по карте колоды — выбрать её; клик по карте Запаса при выбранной карте — замена,
# без выбора — добавить; ПКМ по карте колоды или кнопка «Убрать» — убрать.

const DECK_SCALE: float = 0.52
const STOCK_SCALE: float = 0.52
const DECK_COLUMNS: int = 6
const STOCK_COLUMNS: int = 5

var _hero: HeroData
var _deck: Array[String] = []     # рабочая копия колоды выбранного героя (id карт)
var _selected: int = -1           # номер выбранной карты колоды
var _filter: String = "*"         # "*" — все наборы, "" — базовые, иначе id набора
var _message: Label


static func open(parent: Node, for_hero: String = "") -> HubPanel:
	var panel := BarracksPanel.new()
	panel.hero_id = for_hero if for_hero != "" else Run.HEROES[0].id
	create(parent, panel, "Караульня", 1080, false)
	panel._select_hero(panel.hero_id)
	return panel


func _select_hero(id: String) -> void:
	hero_id = id
	for h in Run.HEROES:
		if h.id == id:
			_hero = h
	_deck = Meta.current_deck_ids(_hero)
	_selected = -1
	_filter = "*"
	_rebuild()


# ---------- Данные героя ----------

func _base() -> Array[String]:
	return Loadout.ids_of(_hero.starter_deck)


func _rares() -> Array[String]:
	return Loadout.rare_ids(_hero)


func _limit() -> int:
	return Meta.deck_changes(_hero.id)


# Карты, из которых можно выбирать: базовые + Запас (без повторов, без редких)
func _stock_cards() -> Array[CardData]:
	var ids: Array[String] = []
	for id in _base():
		if not ids.has(id):
			ids.append(id)
	for id in Meta.stock_ids(_hero.id):
		if not ids.has(id) and not _rares().has(id):
			ids.append(id)
	var result: Array[CardData] = []
	for id in ids:
		var c: CardData = Loadout.find_card(_hero, id)
		if c != null:
			result.append(c)
	return result


func _save() -> void:
	var base: Array[String] = _base()
	if _deck == base:
		Meta.decks.erase(_hero.id)
	else:
		Meta.decks[_hero.id] = _deck.duplicate()
	Meta.save()


# ---------- Интерфейс ----------

func _rebuild() -> void:
	UiKit.clear(body)

	# Вкладки героев
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	for h in Run.HEROES:
		var t: Button = UiKit.make_button(h.title, _select_hero.bind(h.id), h.id if UiKit.has_icon(h.id) else "star")
		t.custom_minimum_size = Vector2(180, 40)
		if h.id == _hero.id:
			recolor_button(t, h.color.lightened(0.35), 3)
		tabs.add_child(t)

	# Счётчики
	var base: Array[String] = _base()
	var extras: int = Loadout.extras(base, _deck).size()
	var counters: Label = UiKit.make_label("Карт: %d · минимум %d        Изменений: %d / %d" % [_deck.size(), base.size(), extras, _limit()], 17, UiKit.TEXT, true)
	counters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(counters)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	body.add_child(columns)
	columns.add_child(_make_deck_column())
	columns.add_child(_make_stock_column())

	_message = UiKit.make_label(" ", 14, UiKit.BRASS.lightened(0.2))
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_message)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	body.add_child(actions)
	var remove: Button = UiKit.make_button("Убрать выбранную", _remove_selected, "discard")
	remove.custom_minimum_size.x = 220
	if _selected < 0:
		remove.disabled = true
		remove.tooltip_text = "Сначала выбери карту в колоде."
	elif not Loadout.can_remove(base, _deck, _selected):
		remove.disabled = true
		remove.tooltip_text = "Колода не может стать меньше базовой · замени карту или сначала добавь новую."
	actions.add_child(remove)
	var reset: Button = UiKit.make_button("Как было", _reset_deck)
	reset.custom_minimum_size.x = 160
	reset.disabled = _deck == base
	actions.add_child(reset)


func _make_deck_column() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UiKit.make_label("Стартовая колода", 16, _hero.color.lightened(0.4), true))
	box.add_child(UiKit.make_label("Латунная рамка — изменение сверх базовой колоды.", 13, UiKit.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(DECK_COLUMNS * (CardView.CARD_SIZE.x * DECK_SCALE + 6) + 18, 290)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = DECK_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	margin.add_child(grid)
	# какие карты — «изменения»: по количеству копий, с конца колоды
	var extra_left: Dictionary = {}
	for id in Loadout.extras(_base(), _deck):
		extra_left[id] = extra_left.get(id, 0) + 1
	for i in _deck.size():
		var card: CardData = Loadout.find_card(_hero, _deck[i])
		if card == null:
			continue
		var holder: Control = mini_card(card, _hero.color, DECK_SCALE, _on_deck_card.bind(i))
		var b: Button = holder.get_child(0)
		b.gui_input.connect(_on_deck_input.bind(i))
		var is_extra: bool = false
		# последняя из копий считается изменением
		if extra_left.get(_deck[i], 0) > 0 and _deck.rfind(_deck[i]) == i:
			is_extra = true
			extra_left[_deck[i]] -= 1
		if is_extra:
			recolor_button(b, UiKit.BRASS.lightened(0.2), 3)
		if i == _selected:
			recolor_button(b, Color.WHITE, 4)
		grid.add_child(holder)
	return box


func _make_stock_column() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UiKit.make_label("Запас", 16, _hero.color.lightened(0.4), true))
	box.add_child(UiKit.make_label("Базовые карты и обычные, которые герой уже брал в забегах.", 13, UiKit.TEXT_DIM))
	# Фильтр по набору
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	box.add_child(filters)
	filters.add_child(_filter_button("Все", "*", UiKit.TEXT))
	filters.add_child(_filter_button("Базовые", "", CardView.BASIC_COLOR))
	for key: String in CardView.SETS:
		var has_any: bool = false
		for c in _stock_cards():
			if c.card_set == key:
				has_any = true
		if has_any:
			filters.add_child(_filter_button(CardView.SETS[key][0], key, CardView.SETS[key][1]))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(STOCK_COLUMNS * (CardView.CARD_SIZE.x * STOCK_SCALE + 6) + 18, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	scroll.add_child(margin)
	var grid := GridContainer.new()
	grid.columns = STOCK_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	margin.add_child(grid)
	for card in _stock_cards():
		if _filter != "*" and card.card_set != _filter:
			continue
		var reason: String = _block_reason(card.id)
		var holder: Control = mini_card(card, _hero.color, STOCK_SCALE, _on_stock_card.bind(card.id))
		var b: Button = holder.get_child(0)
		if reason != "":
			b.modulate = Color(1, 1, 1, 0.4)
			b.tooltip_text += "\n\n" + reason
		grid.add_child(holder)
	return box


func _filter_button(text: String, key: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", color.lightened(0.2))
	if _filter == key:
		recolor_button(b, color.lightened(0.2), 2)
	b.pressed.connect(_set_filter.bind(key))
	return b


func _set_filter(key: String) -> void:
	_filter = key
	_rebuild()


# ---------- Действия ----------

# Почему эту карту сейчас нельзя положить (пусто — можно)
func _block_reason(card_id: String) -> String:
	var base: Array[String] = _base()
	var stock: Array[String] = Meta.stock_ids(_hero.id)
	var allowed: bool
	if _selected >= 0:
		allowed = Loadout.can_replace(base, _deck, _selected, card_id, stock, _rares(), _limit())
	else:
		allowed = Loadout.can_add(base, _deck, card_id, stock, _rares(), _limit())
	if allowed:
		return ""
	var next: Array[String] = _deck.duplicate()
	if _selected >= 0:
		next.remove_at(_selected)
	if Loadout.copies(next, card_id) >= Loadout.MAX_COPIES:
		return "Уже %d копии в колоде." % Loadout.MAX_COPIES
	return "Все изменения заняты · убери добавленную карту или изучи «Свою выкладку»."


func _on_deck_card(index: int) -> void:
	_selected = -1 if _selected == index else index
	_rebuild()


# ПКМ по карте колоды — убрать
func _on_deck_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_selected = index
		_remove_selected()


func _on_stock_card(card_id: String) -> void:
	var base: Array[String] = _base()
	var stock: Array[String] = Meta.stock_ids(_hero.id)
	if _selected >= 0:
		if Loadout.can_replace(base, _deck, _selected, card_id, stock, _rares(), _limit()):
			_deck.remove_at(_selected)
			_deck.insert(_selected, card_id)   # на то же место
			_selected = -1
			_save()
			_rebuild()
			return
	elif Loadout.can_add(base, _deck, card_id, stock, _rares(), _limit()):
		_deck.append(card_id)
		_save()
		_rebuild()
		return
	_say(_block_reason(card_id))


func _remove_selected() -> void:
	if _selected < 0:
		return
	if not Loadout.can_remove(_base(), _deck, _selected):
		_say("Колода не может стать меньше базовой · замени карту или сначала добавь новую.")
		return
	_deck.remove_at(_selected)
	_selected = -1
	_save()
	_rebuild()


func _reset_deck() -> void:
	_deck = _base()
	_selected = -1
	_save()
	_rebuild()


func _say(text: String) -> void:
	if _message != null and text != "":
		_message.text = text
