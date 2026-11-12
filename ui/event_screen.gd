extends Control
# Случайное событие: текст и несколько вариантов выбора.
# Пока события описаны прямо здесь, в списке EVENTS. Когда их станет много —
# стоит перенести их в ресурсы (.tres), как карты и врагов.

const EVENTS: Array[Dictionary] = [
	{
		"title": "Заброшенный алтарь",
		"text": "В зарослях — каменный алтарь, покрытый рунами. Руны жадно светятся, когда ты подходишь.",
		"options": [
			{"text": "Пролить кровь (случайный герой: −6 HP и редкая карта)", "action": "altar"},
			{"text": "Уйти", "action": "leave"},
		],
	},
	{
		"title": "Лесной родник",
		"text": "Чистая вода бьёт из-под корней. На дне блестят монеты — кто-то загадывал желания.",
		"options": [
			{"text": "Напиться (+10 HP каждому)", "action": "drink"},
			{"text": "Бросить монету (−15 золота, карта случайному герою)", "action": "coin"},
		],
	},
	{
		"title": "Сундук на дороге",
		"text": "Посреди дороги стоит окованный сундук. Подозрительно удобно.",
		"options": [
			{"text": "Открыть (повезёт или нет)", "action": "chest"},
			{"text": "Пройти мимо", "action": "leave"},
		],
	},
]

var _column: VBoxContainer
var _title: String = ""   # название события — показываем и на экране с итогом


func _ready() -> void:
	_column = UiKit.make_screen(self)
	var event: Dictionary = EVENTS[Run.rng.randi_range(0, EVENTS.size() - 1)]
	var sign: TextureRect = UiKit.icon_rect("event", 56, Color(0.62, 0.62, 1.0))
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(sign)
	_title = event["title"]
	_column.add_child(UiKit.make_title(_title, 38, UiKit.BRASS.lightened(0.25)))
	_column.add_child(_story(event["text"]))
	_column.add_child(UiKit.party_bar())
	for option: Dictionary in event["options"]:
		var action: String = option["action"]
		var b: Button = UiKit.make_button(option["text"], _choose.bind(action))
		b.custom_minimum_size.x = 560
		if action == "coin" and Run.gold < 15:
			b.disabled = true
			b.tooltip_text = "Не хватает золота"
		_column.add_child(b)


# Текст события в рамке
func _story(text: String) -> PanelContainer:
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.75), UiKit.LINE)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_child(UiKit.make_text(text, 19, UiKit.TEXT, 640))
	return panel


func _choose(action: String) -> void:
	var result: String = ""
	match action:
		"altar":
			var rh: RunHero = Run.random_hero()
			rh.lose_hp(6)
			var card: CardData = Run.random_rare_card(rh.data)
			rh.deck.append(card)
			result = "Руны гаснут. %s теряет 6 HP, но узнаёт новый приём: %s." % [rh.data.title, card.title]
		"drink":
			for rh in Run.party:
				rh.heal(10)
			result = "Вода прохладная и придаёт сил. +10 HP каждому."
		"coin":
			Run.gold -= 15
			var rh: RunHero = Run.random_hero()
			var card: CardData = Run.roll_cards(rh, 1)[0]
			rh.deck.append(card)
			result = "Монета тонет, а %s вдруг вспоминает приём: %s." % [rh.data.title, card.title]
		"chest":
			if Run.rng.randf() < 0.5:
				Run.gold += 40
				result = "Внутри — золото! +40 золота."
			else:
				var rh: RunHero = Run.random_hero()
				rh.lose_hp(6)
				result = "Ловушка! Иглы впиваются в руку. %s теряет 6 HP." % rh.data.title
		_:
			result = "Отряд идёт дальше."
	_show_result(result)


func _show_result(text: String) -> void:
	UiKit.clear(_column)
	_column.add_child(UiKit.make_title(_title, 38, UiKit.BRASS.lightened(0.25)))
	_column.add_child(_story(text))
	_column.add_child(UiKit.party_bar())
	_column.add_child(UiKit.make_button("Дальше", Run.goto.bind(Run.MAP_SCENE), "", true))
