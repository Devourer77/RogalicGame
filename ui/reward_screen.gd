extends Control
# Награда после боя (тз-карты.md, раздел 10): золото и ОДНА награда на весь отряд.
# Три варианта на выбор: карта Магу (1 из 3), карта Рыцарю (1 из 3) или улучшение одной карты.
# Пропуск — каждому герою немного HP.
# После элиты карты — только редкие (★). Награда элиты (ещё одно бесплатное улучшение и выбор
# порченой реликвии) — вторым шагом на том же экране: всё сразу не помещается в окно 720 px по высоте.

var _column: VBoxContainer                   # колонка экрана — во втором шаге её содержимое меняется
var _elite: bool = false                     # бой был с элитой
var _next_button: Button
var _note: Label                             # подпись под выбором («Записано в Караульню»)
var _picked: bool = false                    # главная награда выбрана (или пропущена)
var _all_buttons: Array[Button] = []         # кнопки главной награды — гаснут после выбора
var _bonus_done: bool = true                 # бесплатное улучшение после элиты (true — его нет)
var _bonus_buttons: Array[Button] = []
var _relic_done: bool = true                 # реликвия выбрана или отказались (true — выбора нет)
var _refuse_relic: Button                    # «Без реликвии» — стоит в нижней строке рядом с «Дальше»

const CARD_SCALE: float = 0.7                # карты на экране уменьшены, чтобы всё влезло в 720 px


func _ready() -> void:
	_column = UiKit.make_screen(self)
	_column.add_theme_constant_override("separation", 10)
	_elite = Run.current != null and Run.current.type == MapNode.Type.ELITE
	_build_head()
	if Run.tamed_spirit != null:
		_build_spirit_choice(_column, Run.tamed_spirit)
		return
	_build_main()


# Шапка: «Победа!», золото и полоса отряда
func _build_head() -> void:
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	head.add_child(UiKit.make_title("Победа!", 40, UiKit.BRASS.lightened(0.25)))
	var gold: HBoxContainer = UiKit.chip("coin", "+%d" % Run.last_gold_reward, UiKit.GOLD, "", 22, 24)
	gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(gold)
	_column.add_child(head)
	_column.add_child(UiKit.party_bar())


# Шаг 1: главная награда — карта одному из героев, улучшение или пропуск
func _build_main() -> void:
	var column: VBoxContainer = _column
	column.add_child(UiKit.make_text("Выбери одно на весь отряд: карту Магу, карту Рыцарю или улучшение карты.", 15, UiKit.TEXT_DIM))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	# Карта каждому герою
	for rh in Run.party:
		var cards: Array[CardData] = Run.roll_rare_cards(rh, 3) if _elite else Run.roll_cards(rh, Run.reward_card_count())
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

	var skip: Button = UiKit.make_button("Пропустить (каждому +%d HP)" % Run.SKIP_HEAL, _skip)
	_all_buttons.append(skip)
	# После элиты «Дальше» ведёт ко второму шагу, иначе — на карту
	var go: Callable = _build_elite_step if _elite else Run.goto.bind(Run.MAP_SCENE)
	_next_button = UiKit.make_button("Дальше: награда элиты" if _elite else "Дальше", go, "", true)
	_next_button.disabled = true
	column.add_child(_bottom_row(skip))


# Шаг 2 (только после элиты): бесплатное улучшение и порченая реликвия.
# Улучшения тянутся заново — карта, улучшенная на шаге 1, сюда уже не попадёт.
func _build_elite_step() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	# Без большой шапки «Победа!» (золото уже показано на шаге 1) — иначе снова не влезает
	_column.add_child(UiKit.party_bar())
	var bonus: Array[Dictionary] = Run.roll_upgrades(Run.UPGRADE_CHOICES)
	if not bonus.is_empty():
		_bonus_done = false
		_column.add_child(_upgrade_block("Награда элиты: ещё одно улучшение бесплатно", bonus, _bonus_buttons, _take_bonus))
	if Run.can_take_relic():
		var offer: Array[RelicData] = Run.roll_relics(Run.RELIC_CHOICES)
		if not offer.is_empty():
			_relic_done = false
			_column.add_child(_build_relic_choice(offer))
	_next_button = UiKit.make_button("Дальше", Run.goto.bind(Run.MAP_SCENE), "", true)
	_column.add_child(_bottom_row(_refuse_relic))
	_update_next()


# Нижняя строка: слева кнопка отказа (пропуск или «Без реликвии»), в центре подпись, справа «Дальше».
# Одна строка вместо трёх — экономит место по высоте.
func _bottom_row(left: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	if left != null:
		row.add_child(left)
	_note = UiKit.make_label(" ", 13, UiKit.BRASS.lightened(0.2))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.custom_minimum_size.x = 260
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_note)
	row.add_child(_next_button)
	return row


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
	holder.custom_minimum_size = CardView.CARD_SIZE * CARD_SCALE
	b.pivot_offset = Vector2.ZERO
	b.scale = Vector2(CARD_SCALE, CARD_SCALE)
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
	UiFx.shine(chosen)
	_picked = true
	_update_next()


func _take_upgrade(rh: RunHero, index: int, branch: int, chosen: Button) -> void:
	if _picked or not Run.can_upgrade(rh.deck[index]):
		return
	Sfx.play("magic", 0.05)
	Run.upgrade_card(rh, index, branch)
	_note.text = "Улучшено: %s" % rh.deck[index].title
	_finish(chosen, _all_buttons)
	UiFx.shine(chosen)
	_picked = true
	_update_next()


func _take_bonus(rh: RunHero, index: int, branch: int, chosen: Button) -> void:
	if _bonus_done or not Run.can_upgrade(rh.deck[index]):
		return
	Sfx.play("magic", 0.05)
	Run.upgrade_card(rh, index, branch)
	_note.text = "Улучшено: %s" % rh.deck[index].title
	_finish(chosen, _bonus_buttons)
	UiFx.shine(chosen)
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


# ---------- Логово: покорённый дух выбирает героя ----------

func _build_spirit_choice(column: VBoxContainer, sp: SpiritData) -> void:
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.8), sp.color)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 8)
	title.add_child(UiKit.icon_rect(sp.icon, 28, sp.color))
	title.add_child(UiKit.make_title("Покорён: " + sp.title, 28, sp.color.lightened(0.3)))
	box.add_child(title)
	box.add_child(UiKit.make_text(sp.description, 14, UiKit.TEXT_DIM, 520))
	box.add_child(UiKit.make_text("Пассив: " + sp.passive_text, 15, UiKit.TEXT, 520))
	if sp.call_card != null:
		box.add_child(UiKit.make_text("Зов (раз в бой): " + sp.call_card.description, 15, UiKit.TEXT, 520))
	box.add_child(UiKit.make_text("К кому пойдёт дух? Его три карты сразу войдут в колоду героя.", 15, UiKit.BRASS, 520))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var buttons: Array[Button] = []
	for rh in Run.party:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 6)
		var cl: Array[CardData] = sp.cards_for(rh.data.id)
		for i in mini(Run.spirit_start_count(sp), cl.size()):
			var cb: Button = CardView.make_button(cl[i], rh.data.color)
			cb.mouse_filter = Control.MOUSE_FILTER_PASS
			var holder := Control.new()
			holder.custom_minimum_size = CardView.CARD_SIZE * 0.7
			cb.pivot_offset = Vector2.ZERO
			cb.scale = Vector2(0.7, 0.7)
			holder.add_child(cb)
			cards.add_child(holder)
		col.add_child(cards)
		var free: bool = Run.can_take_spirit(rh)
		# Места заняты — можно заменить одного из своих духов (его карты уйдут из колоды)
		if not free:
			for old: SpiritData in rh.spirits:
				var swap: Button = UiKit.make_button("%s: заменить «%s»" % [rh.data.title, old.title], func() -> void: pass)
				swap.tooltip_text = "«%s» уйдёт вместе со своими картами." % old.title
				swap.pressed.connect(func() -> void:
					if _picked:
						return
					Run.release_spirit(rh, old)
					Run.add_spirit(rh, sp)
					_note.text = "%s отпускает «%s» и берёт «%s»" % [rh.data.title, old.title, sp.title]
					for x in buttons: x.disabled = true
					_picked = true
					_update_next())
				buttons.append(swap)
				col.add_child(swap)
		var b: Button = UiKit.make_button(("Отдать: " + rh.data.title) if free else (rh.data.title + ": места заняты"), func() -> void: pass)
		b.disabled = not free
		b.pressed.connect(func() -> void:
			if _picked:
				return
			Sfx.play("magic", 0.05)
			Run.add_spirit(rh, sp)
			_note.text = "%s теперь с духом «%s»" % [rh.data.title, sp.title]
			for x in buttons: x.disabled = true
			_picked = true
			_update_next())
		buttons.append(b)
		col.add_child(b)
		row.add_child(col)
	var no: Button = UiKit.make_button("Отпустить духа", func() -> void:
		if _picked:
			return
		for x in buttons: x.disabled = true
		_note.text = "Дух ушёл в туман"
		_picked = true
		_update_next())
	buttons.append(no)
	box.add_child(no)
	column.add_child(panel)
	_note = UiKit.make_label(" ", 14, UiKit.BRASS.lightened(0.2))
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)
	# После элиты (Хозяин трясины) дальше — обычная награда элиты
	var after_elite: bool = Run.current != null and Run.current.type == MapNode.Type.ELITE
	_next_button = UiKit.make_button("Дальше", func() -> void:
		Run.tamed_spirit = null
		Run.goto(Run.REWARD_SCENE if after_elite else Run.MAP_SCENE), "", true)
	_next_button.disabled = true
	column.add_child(_next_button)


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
	refuse.append(no)
	_refuse_relic = no   # сама кнопка встанет в нижнюю строку (см. _bottom_row)
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
	if r != null:
		UiFx.shine(pressed)
	_update_next()
