extends Control
# Награда после боя (тз-карты.md, раздел 10): золото и ОДНА награда на весь отряд.
# Три варианта на выбор: карта Магу (1 из 3), карта Рыцарю (1 из 3) или улучшение одной карты.
# Пропуск — каждому герою немного HP.
# После элиты карты — только редкие (★), сверху — ещё одно бесплатное улучшение и выбор порченой реликвии.

var _next_button: Button
var _note: Label                             # подпись под выбором («Записано в Караульню»)
var _picked: bool = false                    # главная награда выбрана (или пропущена)
var _all_buttons: Array[Button] = []         # кнопки главной награды — гаснут после выбора
var _bonus_done: bool = true                 # бесплатное улучшение после элиты (true — его нет)
var _bonus_buttons: Array[Button] = []
var _relic_done: bool = true                 # реликвия выбрана или отказались (true — выбора нет)


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 10)
	var elite: bool = Run.current != null and Run.current.type == MapNode.Type.ELITE

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	head.add_child(UiKit.make_title("Победа!", 40, UiKit.BRASS.lightened(0.25)))
	var gold: HBoxContainer = UiKit.chip("coin", "+%d" % Run.last_gold_reward, UiKit.GOLD, "", 22, 24)
	gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(gold)
	column.add_child(head)
	column.add_child(UiKit.party_bar())
	column.add_child(UiKit.make_text("Выбери одно на весь отряд: карту Магу, карту Рыцарю или улучшение карты.", 15, UiKit.TEXT_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	# Карта каждому герою
	for rh in Run.party:
		var cards: Array[CardData] = Run.roll_rare_cards(rh, 3) if elite else Run.roll_cards(rh, Run.reward_card_count())
		if cards.is_empty():
			cards = Run.roll_cards(rh, 3)
		var panel: PanelContainer = _panel("Карта: " + rh.data.title, rh.data.color)
		var box: HBoxContainer = _card_row(panel)
		for card in cards:
			var b: Button = _card_button(card, rh.data.color, box)
			b.pressed.connect(_take_card.bind(rh, card, b))
		row.add_child(panel)
	# Улучшение
	var ups: Array[Dictionary] = Run.roll_upgrades(Run.UPGRADE_CHOICES)
	if not ups.is_empty():
		column.add_child(_upgrade_block("Или улучши одну карту — выбери ветку:", ups, _all_buttons, _take_upgrade))

	if elite:
		var bonus: Array[Dictionary] = Run.roll_upgrades(Run.UPGRADE_CHOICES)
		if not bonus.is_empty():
			_bonus_done = false
			column.add_child(_upgrade_block("Награда элиты: ещё одно улучшение бесплатно", bonus, _bonus_buttons, _take_bonus))

	_note = UiKit.make_label(" ", 13, UiKit.BRASS.lightened(0.2))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)
	var skip: Button = UiKit.make_button("Пропустить (каждому +%d HP)" % Run.SKIP_HEAL, _skip)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_all_buttons.append(skip)
	column.add_child(skip)

	if elite and Run.can_take_relic():
		var offer: Array[RelicData] = Run.roll_relics(Run.RELIC_CHOICES)
		if not offer.is_empty():
			_relic_done = false
			column.add_child(_build_relic_choice(offer))

	_next_button = UiKit.make_button("Дальше", Run.goto.bind(Run.MAP_SCENE), "", true)
	_next_button.disabled = true
	column.add_child(_next_button)


# Панель с заголовком; карты кладутся в её строку
func _panel(title: String, color: Color) -> PanelContainer:
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.7), color.darkened(0.3))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var caption: Label = UiKit.make_label(title, 16, color.lightened(0.5), true)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	return panel


func _card_row(panel: PanelContainer) -> HBoxContainer:
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()   # «камень» маны выступает за край карты
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_child(cards)
	panel.get_child(0).add_child(margin)
	return cards


# Карта-кнопка уменьшенного размера (на экране сразу много карт)
func _card_button(card: CardData, color: Color, into: Container, list: Array[Button] = _all_buttons) -> Button:
	var b: Button = CardView.make_button(card, color)
	var holder := Control.new()
	holder.custom_minimum_size = CardView.CARD_SIZE * 0.8
	b.pivot_offset = Vector2.ZERO
	b.scale = Vector2(0.8, 0.8)
	holder.add_child(b)
	into.add_child(holder)
	list.append(b)
	return b


# Блок улучшений: для каждой карты — обе ветки рядом
func _upgrade_block(title: String, ups: Array[Dictionary], list: Array[Button], on_pick: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var head: Label = UiKit.make_label(title, 15, UiKit.BRASS, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for up: Dictionary in ups:
		var rh: RunHero = up["hero"]
		var card: CardData = rh.deck[int(up["index"])]
		var panel: PanelContainer = _panel("%s (%s)" % [card.title, rh.data.title], rh.data.color)
		var cards: HBoxContainer = _card_row(panel)
		for branch in [1, 2]:
			var shown: CardData = card.upgrade_1 if branch == 1 else card.upgrade_2
			var b: Button = _card_button(shown, rh.data.color, cards, list)
			b.tooltip_text = ("Ветка I «Сила»" if branch == 1 else "Ветка II «Приём»") + "\n" + shown.description
			b.pressed.connect(on_pick.bind(rh, int(up["index"]), branch, b))
		row.add_child(panel)
	return box


func _take_card(rh: RunHero, card: CardData, chosen: Button) -> void:
	if _picked:
		return
	Sfx.play("card_select", 0.05)
	if Run.add_card(rh, card):
		_note.text = "Записано в Караульню"
	_finish(chosen, _all_buttons)
	_picked = true
	_update_next()


func _take_upgrade(rh: RunHero, index: int, branch: int, chosen: Button) -> void:
	if _picked or not Run.can_upgrade(rh.deck[index]):
		return
	Sfx.play("magic", 0.05)
	Run.upgrade_card(rh, index, branch)
	_note.text = "Улучшено: %s" % rh.deck[index].title
	_finish(chosen, _all_buttons)
	_picked = true
	_update_next()


func _take_bonus(rh: RunHero, index: int, branch: int, chosen: Button) -> void:
	if _bonus_done or not Run.can_upgrade(rh.deck[index]):
		return
	Sfx.play("magic", 0.05)
	Run.upgrade_card(rh, index, branch)
	_finish(chosen, _bonus_buttons)
	_bonus_done = true
	_update_next()


func _skip() -> void:
	if _picked:
		return
	for rh in Run.party:
		Run.heal_hero(rh, Run.SKIP_HEAL)
	_note.text = "Отдохнули: каждому +%d HP" % Run.SKIP_HEAL
	_finish(null, _all_buttons)
	_picked = true
	_update_next()


# Выбранная кнопка — с латунной рамкой, остальные гаснут
func _finish(chosen: Button, list: Array[Button]) -> void:
	for b in list:
		if b == chosen:
			var frame: StyleBox = b.get_theme_stylebox("normal").duplicate()
			if frame is StyleBoxFlat:
				(frame as StyleBoxFlat).border_color = UiKit.BRASS.lightened(0.25)
				(frame as StyleBoxFlat).set_border_width_all(4)
			b.add_theme_stylebox_override("normal", frame)
			b.add_theme_stylebox_override("hover", frame)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.35)


func _update_next() -> void:
	_next_button.disabled = not _picked or not _bonus_done or not _relic_done


# ---------- Реликвия после элиты ----------

func _build_relic_choice(offer: Array[RelicData]) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var head: Label = UiKit.make_label("Порченая реликвия: сила с ценой. Можно не брать.", 16, UiKit.BRASS, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var buttons: Array[Button] = []
	var refuse: Array[Button] = []
	for r in offer:
		var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.8), UiKit.BRASS_DARK)
		panel.custom_minimum_size.x = 250
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		panel.add_child(col)
		var title_row := HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 6)
		title_row.add_child(UiKit.icon_rect(r.icon, 22, UiKit.BRASS))
		title_row.add_child(UiKit.make_label(r.title, 16, UiKit.BRASS.lightened(0.2), true))
		col.add_child(title_row)
		if r.hero_id != "":
			col.add_child(UiKit.make_label("Для: " + ("мага" if r.hero_id == "mage" else "рыцаря"), 13, UiKit.TEXT_DIM))
		# Плюс — светлым, минус — приглушённым (красный в интерфейсе только про врагов)
		col.add_child(UiKit.make_text("+ " + r.plus_text, 14, UiKit.TEXT, 230))
		col.add_child(UiKit.make_text("− " + r.minus_text, 14, UiKit.TEXT_DIM, 230))
		var take: Button = UiKit.make_button("Взять", func() -> void: pass)
		take.custom_minimum_size.x = 200
		take.pressed.connect(_take_relic.bind(r, take, buttons, refuse))
		col.add_child(take)
		buttons.append(take)
		row.add_child(panel)
	var no: Button = UiKit.make_button("Без реликвии", func() -> void: pass)
	no.pressed.connect(_take_relic.bind(null, no, buttons, refuse))
	no.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	refuse.append(no)
	box.add_child(no)
	return box


# Взяли реликвию (или отказались — r == null): остальные кнопки гаснут
func _take_relic(r: RelicData, pressed: Button, buttons: Array[Button], refuse: Array[Button]) -> void:
	if _relic_done:
		return
	if r != null:
		Sfx.play("magic", 0.05)
		Run.take_relic(r)
	for b in buttons + refuse:
		b.disabled = true
	pressed.text = "Взята" if r != null else "Отказались"
	_relic_done = true
	_update_next()
