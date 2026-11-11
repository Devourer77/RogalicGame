extends Control
# Награда после боя: золото и одна карта на выбор —
# по три варианта для каждого героя (берёшь только одну) или пропустить.


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 8)
	column.add_child(UiKit.make_label("Победа!  +%d золота" % Run.last_gold_reward, 26))
	column.add_child(UiKit.make_label(UiKit.run_status(), 16))

	for rh in Run.party:
		column.add_child(UiKit.make_label("Карта для героя: %s" % rh.data.title, 18))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		for card in Run.roll_cards(rh, 3):
			var b: Button = CardView.make_button(card, rh.data.color)
			b.pressed.connect(_take_card.bind(rh, card))
			row.add_child(b)

	column.add_child(UiKit.make_button("Пропустить", Run.goto.bind(Run.MAP_SCENE)))


func _take_card(rh: RunHero, card: CardData) -> void:
	rh.deck.append(card)
	Run.goto(Run.MAP_SCENE)
