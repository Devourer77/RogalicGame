extends Control
# «Заготовка» (улучшение из хаба): в начале забега герой берёт 1 обычную карту на выбор из 3.
# Выбор у каждого героя с этим улучшением; «Вперёд» оживает, когда выбрали все.

var _next_button: Button
var _chosen: Dictionary[RunHero, bool] = {}


func _ready() -> void:
	var column: VBoxContainer = UiKit.make_screen(self)
	column.add_theme_constant_override("separation", 12)
	column.add_child(UiKit.make_title("Заготовка", 40, UiKit.BRASS.lightened(0.25)))
	column.add_child(UiKit.make_text("Перед дорогой герой припас одну карту. Выбери, какую.", 16, UiKit.TEXT_DIM))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	column.add_child(row)
	for rh in Run.start_picks:
		var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.7), rh.data.color.darkened(0.3))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		box.add_child(UiKit.make_label(rh.data.title, 17, rh.data.color.lightened(0.5), true))
		var cards := HBoxContainer.new()
		cards.add_theme_constant_override("separation", 12)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_child(cards)
		box.add_child(margin)
		var buttons: Array[Button] = []
		for card in Run.roll_cards(rh, 3, true):   # только обычные карты
			var b: Button = CardView.make_button(card, rh.data.color)
			CardView.add_hover_grow(b)
			b.pressed.connect(_pick.bind(rh, card, b, buttons))
			cards.add_child(b)
			buttons.append(b)
		row.add_child(panel)
	_next_button = UiKit.make_button("Вперёд", Run.goto.bind(Run.MAP_SCENE), "", true)
	_next_button.disabled = true
	column.add_child(_next_button)
	if Run.start_picks.is_empty():
		Run.goto(Run.MAP_SCENE)


func _pick(rh: RunHero, card: CardData, chosen: Button, buttons: Array[Button]) -> void:
	if _chosen.has(rh):
		return
	Run.add_card(rh, card)
	_chosen[rh] = true
	for b in buttons:
		if b != chosen:
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.35)
		else:
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_button.disabled = _chosen.size() < Run.start_picks.size()
