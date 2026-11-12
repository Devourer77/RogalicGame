extends Control
# Награда после боя: золото и по одной карте каждому герою —
# у каждого свои три варианта; можно взять карту или пропустить. «Дальше» — когда оба решили.

var _next_button: Button
var _done: Dictionary[RunHero, bool] = {}   # герой -> уже выбрал (карту или пропуск)


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 12)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	head.add_child(UiKit.make_title("Победа!", 40, UiKit.BRASS.lightened(0.25)))
	var gold: HBoxContainer = UiKit.chip("coin", "+%d" % Run.last_gold_reward, UiKit.GOLD, "", 22, 24)
	gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(gold)
	column.add_child(head)
	column.add_child(UiKit.party_bar())
	column.add_child(UiKit.make_text("Возьми по карте каждому герою или пропусти. Наведи на карту, чтобы узнать подробности.", 15, UiKit.TEXT_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	for rh in Run.party:
		var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.7), rh.data.color.darkened(0.3))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 12)
		panel.add_child(box)
		var caption := HBoxContainer.new()
		caption.alignment = BoxContainer.ALIGNMENT_CENTER
		caption.add_theme_constant_override("separation", 8)
		caption.add_child(UiKit.icon_rect(rh.data.id if UiKit.has_icon(rh.data.id) else "star", 22, rh.data.color.lightened(0.4)))
		caption.add_child(UiKit.make_label(rh.data.title, 17, rh.data.color.lightened(0.5), true))
		box.add_child(caption)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 12)
		# поля: «камень» маны выступает за край карты
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 2)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_child(cards)
		box.add_child(margin)
		var buttons: Array[Button] = []
		var skip: Array[Button] = []   # сюда ляжет кнопка «Пропустить» (нужна обработчикам)
		for card in Run.roll_cards(rh, 3):
			var b: Button = CardView.make_button(card, rh.data.color)
			CardView.add_hover_grow(b)
			b.pressed.connect(_take_card.bind(rh, card, b, buttons, skip))
			cards.add_child(b)
			buttons.append(b)
		# своя кнопка «Пропустить» под картами этого героя
		skip.append(UiKit.make_button("Пропустить", _skip.bind(rh, buttons, skip)))
		box.add_child(skip[0])
		row.add_child(panel)

	_next_button = UiKit.make_button("Дальше", Run.goto.bind(Run.MAP_SCENE), "", true)
	_next_button.disabled = true
	column.add_child(_next_button)


# Герой взял карту: она остаётся яркой с латунной рамкой, остальные гаснут и не нажимаются
func _take_card(rh: RunHero, card: CardData, chosen: Button, buttons: Array[Button], skip: Array[Button]) -> void:
	if _done.has(rh):
		return
	rh.deck.append(card)
	for b in buttons:
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
	_finish_hero(rh, skip)


func _skip(rh: RunHero, buttons: Array[Button], skip: Array[Button]) -> void:
	if _done.has(rh):
		return
	for b in buttons:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.35)
	_finish_hero(rh, skip)


# У героя выбор сделан: его «Пропустить» гаснет, а «Дальше» оживает, когда решили оба
func _finish_hero(rh: RunHero, skip: Array[Button]) -> void:
	_done[rh] = true
	skip[0].disabled = true
	_next_button.disabled = _done.size() < Run.party.size()
