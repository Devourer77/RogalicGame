class_name GatePanel
extends HubPanel
# Ворота «Тропа к Шпилю»: сводка перед забегом и кнопка «Выступить».

var _seed_input: LineEdit


static func open(parent: Node, for_hero: String = "") -> HubPanel:
	var panel := GatePanel.new()
	panel.hero_id = for_hero
	create(parent, panel, "Тропа к Шпилю", 700, false)
	panel._rebuild()
	return panel


func _rebuild() -> void:
	UiKit.clear(body)
	body.add_child(UiKit.make_text("Дорога та же. Вы — уже нет. Вот с чем отряд выходит на тропу.", 15, UiKit.TEXT_DIM, 640))

	# Звон
	var bell_row: HBoxContainer = UiKit.chip("bell", "Звон %d" % Meta.bell_chosen, UiKit.BRASS.lightened(0.2),
			"\n".join(_bell_rules(Meta.bell_chosen)), 20, 26)
	bell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(bell_row)

	# Обереги
	var chosen: Array[String] = Meta.valid_chosen()
	var charm_text: String = "Не выбран"
	if not chosen.is_empty():
		var names: PackedStringArray = []
		for id in chosen:
			names.append(Meta.charm_data(id).title)
		charm_text = ", ".join(names)
	var charms: Label = UiKit.make_label("Обереги: " + charm_text, 17, UiKit.TEXT if not chosen.is_empty() else UiKit.TEXT_DIM)
	charms.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if chosen.is_empty():
		charms.tooltip_text = "Обереги берут на Полке трофеев."
		charms.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_child(charms)

	# Колоды героев
	var decks := HBoxContainer.new()
	decks.alignment = BoxContainer.ALIGNMENT_CENTER
	decks.add_theme_constant_override("separation", 14)
	body.add_child(decks)
	for h in Run.HEROES:
		decks.add_child(_deck_summary(h))

	# Для проверки: сид
	var toggle: Button = UiKit.make_button("Для проверки ▾", _toggle_seed)
	toggle.custom_minimum_size = Vector2(200, 34)
	body.add_child(toggle)
	_seed_input = LineEdit.new()
	_seed_input.placeholder_text = "Сид (пусто — случайный)"
	_seed_input.tooltip_text = "Сид — число, из которого получается вся случайность забега.\nОдинаковый сид — та же карта, враги и награды."
	_seed_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_input.custom_minimum_size = Vector2(300, 38)
	_seed_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_seed_input.visible = false
	_seed_input.text_submitted.connect(func(_t: String) -> void: _go())
	body.add_child(_seed_input)

	var go: Button = UiKit.make_button("Выступить", _go, "battle", true)
	go.custom_minimum_size = Vector2(280, 52)
	body.add_child(go)


func _toggle_seed() -> void:
	_seed_input.visible = not _seed_input.visible


func _bell_rules(bell: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	if bell == 0:
		lines.append(Meta.BELL_RULES[0])
	for i in range(1, bell + 1):
		lines.append("%d. %s" % [i, Meta.BELL_RULES[i]])
	return lines


func _deck_summary(h: HeroData) -> Control:
	var base: Array[String] = Loadout.ids_of(h.starter_deck)
	var deck: Array[String] = Meta.current_deck_ids(h)
	var extras: Array[String] = Loadout.extras(base, deck)
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL_LIGHT, 0.6), h.color.darkened(0.35))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(ic(h.id, 22, h.color.lightened(0.4)))
	head.add_child(UiKit.make_label(h.title, 17, UiKit.TEXT, true))
	box.add_child(head)
	var hp: int = h.max_hp + Meta.effect_total("hero_hp", h.id)
	box.add_child(UiKit.make_label("Здоровье: %d" % hp, 14, UiKit.TEXT_DIM))
	if extras.is_empty() and deck.size() == base.size() and deck == base:
		box.add_child(UiKit.make_label("Колода: базовая · %d карт" % deck.size(), 14, UiKit.TEXT))
	else:
		var line: Label = UiKit.make_label("Колода: своя · %d карт, изменений: %d" % [deck.size(), extras.size()], 14, UiKit.TEXT)
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		var diff: PackedStringArray = []
		for id in extras:
			var c: CardData = Loadout.find_card(h, id)
			diff.append("+ " + (c.title if c != null else id))
		line.tooltip_text = "Отличия от базовой колоды:\n" + "\n".join(diff)
		box.add_child(line)
	return panel


func _go() -> void:
	var text: String = _seed_input.text.strip_edges()
	var new_seed: int = int(text) if text.is_valid_int() else 0
	Run.start_new_run(new_seed, Meta.bell_chosen)
	Run.begin()
