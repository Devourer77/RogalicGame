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
		"title": "Утопленный идол",
		"text": "Из чёрной воды торчит голова каменного идола. На его шее — амулет, тёплый, как живой.",
		"options": [
			{"text": "Снять амулет (случайная порченая реликвия)", "action": "idol"},
			{"text": "Не трогать", "action": "leave"},
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
	# Появляется, только пока в отряде нет хотя бы одного обычного духа (см. _pick_event)
	{
		"title": "Клетка Венца",
		"id": "cage",
		"text": "По гати тащат телегу трое культистов. В клетке-фонаре на ней бьётся что-то живое — дух, пойманный для Венца. Охрана устала и не ждёт нападения.",
		"options": [
			{"text": "Отбить духа (каждому −5 HP, дух выбирает героя)", "action": "cage_free"},
			{"text": "Пройти мимо", "action": "leave"},
		],
	},
	# Появляется, только пока есть закрытые обереги, и не чаще раза за забег (см. _pick_event)
	{
		"title": "Тайник павшего дозорного",
		"id": "cache",
		"text": "Под вывороченными корнями мёртвого дуба темнеет окованный ящик Стражи, ключ всё ещё торчит в замке. Рядом в тине лежит тот, кто его прятал, — в таком же табарде, как у вас. Трясина вокруг уже пускает пузыри.",
		"options": [
			{"text": "Рыцарь вытаскивает ящик (Рыцарь −6 HP, оберег до конца забега)", "action": "cache_chest"},
			{"text": "Маг читает записки дозорного (Маг −4 HP, +6 Отзвуков)", "action": "cache_notes"},
			{"text": "Оставить ящик мёртвому", "action": "cache_leave"},
		],
	},
]

var _column: VBoxContainer
var _title: String = ""   # название события — показываем и на экране с итогом


func _ready() -> void:
	_column = UiKit.make_screen(self)
	var event: Dictionary = _pick_event()
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
		if action == "idol" and not Run.can_take_relic():
			b.disabled = true
			b.tooltip_text = "Больше реликвий не унести"
		if action == "coin" and Run.gold < 15:
			b.disabled = true
			b.tooltip_text = "Не хватает золота"
		_column.add_child(b)


# Случайное событие. «Тайник» — только если остались закрытые обереги и он ещё не выпадал в этом забеге.
func _pick_event() -> Dictionary:
	var pool: Array[Dictionary] = []
	for e in EVENTS:
		if e.get("id", "") == "cache" and (Run.cache_seen or Meta.closed_charms().is_empty()):
			continue
		if e.get("id", "") == "cage" and Run.cage_spirit() == null:
			continue
		pool.append(e)
	var event: Dictionary = pool[Run.rng.randi_range(0, pool.size() - 1)]
	if event.get("id", "") == "cache":
		Run.cache_seen = true
	return event


# Герой отряда по id («knight» / «mage»); если такого нет — случайный
func _hero(hero_id: String) -> RunHero:
	for rh in Run.party:
		if rh.data.id == hero_id:
			return rh
	return Run.random_hero()


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
			Sfx.play("hit", 0.06)
			var rh: RunHero = Run.random_hero()
			rh.lose_hp(6)
			var card: CardData = Run.random_rare_card(rh.data)
			Run.add_card(rh, card)
			result = "Руны гаснут. %s теряет 6 HP, но узнаёт новый приём: %s." % [rh.data.title, card.title]
		"drink":
			Sfx.play("heal", 0.04)
			for rh in Run.party:
				Run.heal_hero(rh, 10)
			result = "Вода прохладная и придаёт сил. +10 HP каждому."
		"coin":
			Sfx.play("coin", 0.05)
			Run.gold -= 15
			var rh: RunHero = Run.random_hero()
			var card: CardData = Run.roll_cards(rh, 1)[0]
			Run.add_card(rh, card)
			result = "Монета тонет, а %s вдруг вспоминает приём: %s." % [rh.data.title, card.title]
		"idol":
			Sfx.play("magic", 0.05)
			var offer: Array[RelicData] = Run.roll_relics(1)
			if offer.is_empty() or not Run.can_take_relic():
				result = "Амулет рассыпается в руках. Видно, больше идолу дать нечего."
			else:
				Run.take_relic(offer[0])
				result = "Ты надеваешь амулет: «%s».\n+ %s\n− %s" % [offer[0].title, offer[0].plus_text, offer[0].minus_text]
		"chest":
			if Run.rng.randf() < 0.5:
				Sfx.play("coin", 0.05)
				Run.gold += 40
				result = "Внутри — золото! +40 золота."
			else:
				Sfx.play("hit", 0.06)
				var rh: RunHero = Run.random_hero()
				rh.lose_hp(6)
				result = "Ловушка! Иглы впиваются в руку. %s теряет 6 HP." % rh.data.title
		"cache_chest":
			Sfx.play("magic", 0.05)
			_hero("knight").lose_hp(6)
			var closed: Array[RelicData] = Meta.closed_charms()
			var charm: RelicData = closed[Run.rng.randi_range(0, closed.size() - 1)]
			Run.relics.append(charm.id)   # действует сразу, сверх мест
			Meta.unlock_charm(charm.id)   # и открыт на Полке навсегда
			_show_result("Жижа тянет за поножи, но окованный ящик выходит из грязи вместе с латником — внутри, в промасленной тряпице, лежит вещь дозора.",
					"Оберег «%s»: %s\nОткрыт на Полке трофеев." % [charm.title, charm.desc])
			return
		"cache_notes":
			Sfx.play("magic", 0.05)
			_hero("mage").lose_hp(4)
			Run.event_echoes += 6
			_show_result("Размокшие листы рассыпаются в пальцах, но последние строки ученик успевает запомнить — и они звучат знакомо, будто писал кто-то из вас.",
					"+6 Отзвуков")
			return
		"cage_free":
			Sfx.play("hit", 0.06)
			for rh in Run.party:
				rh.lose_hp(5)
			Run.offer_spirit(Run.cage_spirit())
			Run.last_gold_reward = 0
			Run.goto(Run.REWARD_SCENE)   # там дух выбирает героя
			return
		"cache_leave":
			result = "Вы закрываете крышку и уходите. Пусть хоть что-то в этих топях останется на своём месте."
		_:
			result = "Отряд идёт дальше."
	_show_result(result)


func _show_result(text: String, reward_line: String = "") -> void:
	UiKit.clear(_column)
	_column.add_child(UiKit.make_title(_title, 38, UiKit.BRASS.lightened(0.25)))
	_column.add_child(_story(text))
	if reward_line != "":
		_column.add_child(UiKit.make_text(reward_line, 18, UiKit.BRASS.lightened(0.25), 640))
	_column.add_child(UiKit.party_bar())
	_column.add_child(UiKit.make_button("Дальше", Run.goto.bind(Run.MAP_SCENE), "", true))
