extends Control
# Награда после боя: золото и по одной карте каждому герою —
# у каждого свои три варианта; можно взять карту или пропустить. «Дальше» — когда оба решили.
# После элиты — ещё выбор порченой реликвии (одна из трёх или отказ).

var _next_button: Button
var _done: Dictionary[RunHero, bool] = {}   # герой -> уже выбрал (карту или пропуск)
var _notes: Dictionary[RunHero, Label] = {}  # подпись «Записано в Караульню» под картами героя
var _relic_done: bool = true                # реликвия выбрана или отказались (true — выбора нет)


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
		var count: int = Run.reward_card_count()
		for card in Run.roll_cards(rh, count):
			var b: Button = CardView.make_button(card, rh.data.color)
			b.pressed.connect(_take_card.bind(rh, card, b, buttons, skip))
			if count > 3:
				# «Указ коменданта»: 4 карты не влезают в экран — делаем их мельче (80%)
				var holder := Control.new()
				holder.custom_minimum_size = CardView.CARD_SIZE * 0.8
				b.pivot_offset = Vector2.ZERO
				b.scale = Vector2(0.8, 0.8)
				holder.add_child(b)
				cards.add_child(holder)
			else:
				CardView.add_hover_grow(b)
				cards.add_child(b)
			buttons.append(b)
		# своя кнопка «Пропустить» под картами этого героя
		var note: Label = UiKit.make_label(" ", 13, UiKit.BRASS.lightened(0.2))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_notes[rh] = note
		box.add_child(note)
		skip.append(UiKit.make_button("Пропустить", _skip.bind(rh, buttons, skip)))
		box.add_child(skip[0])
		row.add_child(panel)

	if Run.current != null and Run.current.type == MapNode.Type.ELITE and Run.can_take_relic():
		var offer: Array[RelicData] = Run.roll_relics(Run.RELIC_CHOICES)
		if not offer.is_empty():
			_relic_done = false
			column.add_child(_build_relic_choice(offer))

	_next_button = UiKit.make_button("Дальше", Run.goto.bind(Run.MAP_SCENE), "", true)
	_next_button.disabled = true
	column.add_child(_next_button)


# Герой взял карту: она остаётся яркой с латунной рамкой, остальные гаснут и не нажимаются
func _take_card(rh: RunHero, card: CardData, chosen: Button, buttons: Array[Button], skip: Array[Button]) -> void:
	if _done.has(rh):
		return
	if Run.add_card(rh, card):
		_notes[rh].text = "Записано в Караульню"
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
	_update_next()


func _update_next() -> void:
	_next_button.disabled = _done.size() < Run.party.size() or not _relic_done


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
		Run.take_relic(r)
	for b in buttons + refuse:
		b.disabled = true
	pressed.text = "Взята" if r != null else "Отказались"
	_relic_done = true
	_update_next()
