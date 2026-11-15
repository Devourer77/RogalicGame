extends Control
# Случайное событие: текст и несколько вариантов выбора.
#
# Большинство вариантов описаны данными — списком шагов «effects», которые разбирает общий код ниже
# (_apply_step). Так новое событие — это только текст и числа, без своего кода. Шаги:
#   {"hp": -7, "who": "knight"}      — HP герою: knight / mage / all (каждому) / random (случайному)
#   {"gold": -20}                    — золото (выбор нельзя нажать, если золота не хватает)
#   {"card": "mage", "rare": true}   — карта герою из его наград (базовый пул + карты духов);
#                                      rare — редкая ★, иначе обычная
#   {"remove": "mage"}               — игрок сам убирает 1 карту из колоды героя (как в лавке)
#   {"echoes": 6}                    — Отзвуки (получишь в хабе после забега)
#   {"relic": 1}                     — случайная порченая реликвия (нельзя, если места кончились)
# Случайный исход: «chance» (0..1), «win» и «lose» — у каждого свои effects и текст.
# «random» в одном выборе — один и тот же герой (кто потерял HP, тот и получает карту).
# Особые варианты (оберег, дух, бой в пещере) — через «action» и свой код в _special().
# Цена в HP не убивает: у героя остаётся хотя бы 1 HP (RunHero.lose_hp).

const EVENTS: Array[Dictionary] = [
	{
		"title": "Заброшенный алтарь",
		"text": "В зарослях — каменный алтарь, покрытый рунами. Руны жадно светятся, когда ты подходишь.",
		"options": [
			{"label": "Пролить кровь", "effects": [{"hp": -6, "who": "random"}, {"card": "random", "rare": true}],
					"result": "Руны гаснут, и кровь уходит в камень. Взамен в памяти всплывает чужой приём."},
			{"label": "Уйти", "result": "Руны провожают отряд тусклым светом."},
		],
	},
	{
		"title": "Лесной родник",
		"text": "Среди корней бьёт чистый родник. Над водой кружатся светлячки.",
		"options": [
			{"label": "Напиться", "effects": [{"hp": 10, "who": "all"}], "result": "Вода прохладная и придаёт сил."},
			{"label": "Бросить монету", "effects": [{"gold": -15}, {"card": "random"}],
					"result": "Монета тонет, а в голове вдруг всплывает забытый приём."},
		],
	},
	{
		"title": "Утопленный идол",
		"text": "Из трясины торчит каменный идол. На шее у него — потемневший амулет.",
		"options": [
			{"label": "Снять амулет", "effects": [{"relic": 1}], "result": "Амулет холодный и тяжелее, чем кажется."},
			{"label": "Не трогать", "result": "Идол смотрит вслед пустыми глазами."},
		],
	},
	{
		"title": "Сундук на дороге",
		"text": "Посреди тропы стоит окованный сундук. Слишком удобно, чтобы быть правдой?",
		"options": [
			{"label": "Открыть", "chance": 0.5,
					"win": {"effects": [{"gold": 40}], "result": "Внутри — золото!"},
					"lose": {"effects": [{"hp": -6, "who": "random"}], "result": "Ловушка! Иглы впиваются в руку."}},
			{"label": "Пройти мимо", "result": "Отряд обходит сундук стороной."},
		],
	},
	# Появляется, только пока в отряде нет Грозовика или Вихоря (Run.cage_spirit())
	{
		"title": "Клетка Венца",
		"id": "cage",
		"text": "У дороги — кованая клетка-фонарь с костяным венцом на крышке. Внутри мечется дух: культисты поймали его и оставили сторожить. Если разбить замок, чары клетки ударят по всем рядом.",
		"options": [
			{"label": "Отбить духа", "hint": "каждому −5 HP → дух выбирает героя", "action": "cage_free"},
			{"label": "Пройти мимо", "result": "Дух провожает отряд взглядом, пока клетка не скрывается в тумане."},
		],
	},
	# Секрет: выпадает с шансом Run.CAVE_EVENT_CHANCE, раз за забег, пока нет духа огня (см. _pick_event)
	{
		"title": "Тлеющая расщелина",
		"id": "cave",
		"text": "Между кочками земля проседает, и из трещины тянет сухим жаром — в топях, где всё гниёт от сырости. Мох по краям обуглен, а внизу, в темноте, что-то медленно дышит оранжевым светом. Камни у входа горячие на ощупь.",
		"options": [
			{"label": "Спуститься", "hint": "бой с хозяином пещеры, награда — дух огня", "action": "cave_enter"},
			{"label": "Пройти мимо", "result": "Вы уходите, а трещина за спиной ещё долго дышит в спину теплом."},
		],
	},
	# Появляется, только пока есть закрытые обереги, и не чаще раза за забег (см. _pick_event)
	{
		"title": "Тайник павшего дозорного",
		"id": "cache",
		"text": "Под корнями мёртвого дерева — кости в остатках лат Стражи. Рядом ящик, окованный медью, наполовину ушедший в трясину, и сумка с размокшими записками.",
		"options": [
			{"label": "Рыцарь вытаскивает ящик", "hint": "Рыцарь −6 HP → оберег до конца забега", "action": "cache_chest"},
			{"label": "Маг читает записки дозорного", "effects": [{"hp": -4, "who": "mage"}, {"echoes": 6}],
					"result": "Размокшие листы рассыпаются в пальцах, но последние строки ученик успевает запомнить — и они звучат знакомо, будто писал кто-то из вас."},
			{"label": "Оставить ящик мёртвому",
					"result": "Вы закрываете крышку и уходите. Пусть хоть что-то в этих топях останется на своём месте."},
		],
	},
	# --- События топей (тексты.md, утверждены 11 ноября) ---
	{
		"title": "Затонувшая повозка Стражи",
		"text": "Из чёрной жижи у старой гати торчит прогнивший борт казённой повозки с гербом-колоколом. Внутри — запечатанные тубусы с уставами, но доски под ногами уходят в трясину. Кто-то один должен полезть в ледяную воду, пока второй держит верёвку.",
		"options": [
			{"label": "В трясину лезет Рыцарь", "effects": [{"hp": -7, "who": "knight"}, {"card": "knight", "rare": true}],
					"result": "Латы тянут ко дну, ледяная жижа сводит плечи судорогой, но стражник вытаскивает на берег старый устав."},
			{"label": "В воду спускается Маг", "effects": [{"hp": -5, "who": "mage"}, {"card": "mage"}, {"remove": "mage"}],
					"result": "Продрогший до костей ученик выбирается из трясины, оставив на дне размокшие черновики ради уцелевшего свитка стихий."},
			{"label": "Не лезть", "result": "Повозка уходит в жижу ещё на ладонь. Через год о ней никто не вспомнит."},
		],
	},
	{
		"title": "Фонарь у переправы",
		"text": "На покосившемся столбе посреди затопленных руин горит старый фонарь Стражи, а внутри вместо масла бьётся пойманный осколок бури. Его неровный свет режет глаза, но в тенях на мокрых плитах проступают забытые формулы ордена и строевые метки.",
		"options": [
			{"label": "Маг вглядывается в свет осколка", "effects": [{"hp": -6, "who": "mage"}, {"card": "mage", "rare": true}],
					"result": "От резкого сияния немеют виски, но в гуле стекла складывается чистая формула грозового разряда."},
			{"label": "Рыцарь чинит заслонку фонаря", "effects": [{"gold": -20}, {"card": "knight"}, {"hp": 7, "who": "knight"}],
					"result": "Заменив лопнувшее кольцо парой монет из кошеля, латник возвращает фонарю ровный свет и переводит дух у знакомого маяка."},
			{"label": "Обойти столб стороной",
					"result": "Вы оставляете гудящий фонарь догорать в тумане — в этих топях чужой свет редко светит даром."},
		],
	},
	{
		"title": "Склад болотного газа",
		"text": "За полусгнившим частоколом брошенной заставы темнеет навес, под которым свалены бочки со светящимися зелёными щелями. Между ними блестит рассыпанная казна гарнизона и лежат перевязочные сумки, но одна из бочек уже тихо шипит.",
		"options": [
			{"label": "Рыцарь выносит казну", "effects": [{"hp": -5, "who": "knight"}], "chance": 0.6,
					"win": {"effects": [{"gold": 35}, {"card": "knight"}],
							"result": "Задержав дыхание в едком пару, латник выволакивает ящик с жалованьем и прихватывает со стойки забытое оружие."},
					"lose": {"effects": [{"hp": -3, "who": "knight"}, {"gold": 15}],
							"result": "Гнилой обруч лопается с резким хлопком, обжигая руки сквозь перчатки, и в спешке удаётся унести лишь горсть монет."}},
			{"label": "Маг отводит газ от сумок лекаря",
					"effects": [{"hp": -4, "who": "mage"}, {"gold": -10}, {"hp": 8, "who": "knight"}, {"remove": "mage"}],
					"result": "Ученик разгоняет ядовитое облако и достаёт из-под навеса чистые бинты для напарника."},
			{"label": "Не трогать бочки и уйти",
					"result": "Вы благоразумно отступаете по гати, оставляя казённое серебро гнить в зелёном тумане."},
		],
	},
	{
		"title": "Круг грибов",
		"text": "На плоском камне среди камышей выросло кольцо бледно-бирюзовых грибов, от которых вода вокруг мелко дрожит. Воздух пахнет озоном и золой, как в день, когда рухнула башня ордена. Сила в камне избавит от старых ошибок, но даром не отпустит.",
		"options": [
			{"label": "В круг входит Маг", "effects": [{"hp": -6, "who": "mage"}, {"remove": "mage"}, {"card": "mage"}],
					"result": "Холодный ток прошивает пальцы до локтей, выжигая из памяти лишние школьные прописи и оставляя только ясную злость бури."},
			{"label": "Рыцарь выжигает грибницу смолой", "effects": [{"gold": -15}, {"remove": "knight"}, {"hp": 5, "who": "mage"}],
					"result": "Пропитанная смолой пакля сжигает светящиеся шляпки дотла, и дышать у камня сразу становится легче."},
			{"label": "Перешагнуть мимо круга",
					"result": "Споры тихо оседают на сапоги, но вы уходите прежде, чем камень под ногами начинает гудеть."},
		],
	},
	{
		"title": "Пост у колокола",
		"text": "На краю мёртвой рощи сохранилась каменная караулка с треснувшим малым колоколом на балке и сухим очагом внутри. На стене углём выведены имена последнего дозора, который так и не дождался смены.",
		"options": [
			{"label": "Развести огонь из старых щитов", "effects": [{"hp": 4, "who": "all"}],
					"result": "Рассохшиеся щиты дают неожиданно много тепла, и за час у очага уходит накопленная в болоте ломота."},
			{"label": "Рыцарь ударяет в малый колокол", "effects": [{"hp": -6, "who": "knight"}, {"card": "knight", "rare": true}],
					"result": "Глухой удар отдаётся в висках тяжёлым звоном, пробуждая ту самую злость, с которой когда-то шли на прорыв."},
			{"label": "Маг разбирает архив караулки",
					"effects": [{"hp": -4, "who": "mage"}, {"gold": -10}, {"card": "mage"}, {"card": "knight"}],
					"result": "Среди промокших донесений находятся записи о старых бродах и строевых приёмах местного гарнизона."},
		],
	},
]

const CARD_SCALE: float = 0.72   # карты-награды на экране итога
const NAMES: Dictionary = {   # как называть героя: кто / кому / кого
	"knight": ["Рыцарь", "Рыцарю", "Рыцаря"],
	"mage": ["Маг", "Магу", "Мага"],
}

var _column: VBoxContainer
var _title: String = ""   # название события — показываем и на экране с итогом
# Что происходит сейчас (общий разбор шагов)
var _steps: Array = []                 # шаги, которые ещё не выполнены
var _story_text: String = ""           # текст итога
var _lines: Array[String] = []         # что получили и чем заплатили — строками под текстом
var _won_cards: Array[Dictionary] = [] # карты-награды: {"card", "color"} — показываем картинками
var _random: RunHero = null            # «случайный герой» этого выбора (один на все шаги)
var _last_remove: String = ""          # чью карту сейчас убирают (для тестов)


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
		var b: Button = UiKit.make_button(option_label(option), _choose.bind(option))
		b.custom_minimum_size.x = 640
		var why: String = blocked_reason(option)
		if why != "":
			b.disabled = true
			b.tooltip_text = why
		_column.add_child(b)


# Случайное событие. Секретная расщелина — по своему шансу; «Тайник» — только если остались закрытые
# обереги; одно и то же событие в забеге второй раз не выпадает, пока есть невиданные.
func _pick_event() -> Dictionary:
	if Run.cave_possible() and Run.rng.randf() < Run.CAVE_EVENT_CHANCE:
		Run.cave_seen = true
		return event_by_id("cave")
	var pool: Array[Dictionary] = []
	for e in EVENTS:
		if event_allowed(e) and not Run.events_seen.has(e["title"]):
			pool.append(e)
	if pool.is_empty():   # все уже были — пусть повторяются
		for e in EVENTS:
			if event_allowed(e):
				pool.append(e)
	var event: Dictionary = pool[Run.rng.randi_range(0, pool.size() - 1)]
	Run.events_seen.append(event["title"])
	if event.get("id", "") == "cache":
		Run.cache_seen = true
	return event


static func event_allowed(e: Dictionary) -> bool:
	match e.get("id", ""):
		"cave":
			return false   # расщелина — только по шансу в _pick_event
		"cache":
			return not Run.cache_seen and not Meta.closed_charms().is_empty()
		"cage":
			return Run.cage_spirit() != null
	return true


static func event_by_id(id: String) -> Dictionary:
	for e in EVENTS:
		if e.get("id", "") == id:
			return e
	return {}


# ---------- Подписи выборов ----------

# Надпись на кнопке: «В трясину лезет Рыцарь (Рыцарь −7 HP → Рыцарю редкая карта)»
static func option_label(option: Dictionary) -> String:
	var hint: String = option.get("hint", "")
	if hint == "":
		hint = describe(option.get("effects", []))
		if option.has("chance"):
			var win: int = roundi(float(option["chance"]) * 100.0)
			var parts: PackedStringArray = []
			if hint != "":
				parts.append(hint)
			parts.append("%d%%: %s" % [win, _gains_only(option["win"].get("effects", []))])
			parts.append("%d%%: %s" % [100 - win, _gains_only(option["lose"].get("effects", []))])
			hint = "; ".join(parts)
	return option["label"] if hint == "" else "%s  (%s)" % [option["label"], hint]


# «цена → награда» одной строкой
static func describe(steps: Array) -> String:
	var costs: PackedStringArray = []
	var gains: PackedStringArray = []
	for s: Dictionary in steps:
		var text: String = step_text(s)
		if text == "":
			continue
		if int(s.get("hp", 0)) < 0 or int(s.get("gold", 0)) < 0:
			costs.append(text)
		else:
			gains.append(text)
	if costs.is_empty():
		return " и ".join(gains)
	if gains.is_empty():
		return ", ".join(costs)
	return "%s → %s" % [", ".join(costs), " и ".join(gains)]


static func _gains_only(steps: Array) -> String:
	var parts: PackedStringArray = []
	for s: Dictionary in steps:
		parts.append(step_text(s))
	return " и ".join(parts)


# Один шаг словами
static func step_text(s: Dictionary) -> String:
	if s.has("hp"):
		var n: int = int(s["hp"])
		var amount: String = ("+%d HP" % n) if n > 0 else ("−%d HP" % -n)
		match s.get("who", "random"):
			"all":
				return "каждому %s" % amount if n < 0 else "%s каждому" % amount
			"random":
				return "случайный герой %s" % amount
			var who:
				return "%s %s" % [NAMES[who][0], amount]
	if s.has("gold"):
		var g: int = int(s["gold"])
		return ("+%d золота" % g) if g > 0 else ("−%d золота" % -g)
	if s.has("card"):
		var kind: String = "редкая карта" if s.get("rare", false) else "карта"
		if s["card"] == "random":
			return "%s случайному герою" % kind
		return "%s %s" % [NAMES[s["card"]][1], kind]
	if s.has("remove"):
		return "убрать 1 карту %s" % NAMES[s["remove"]][2]
	if s.has("echoes"):
		return "+%d Отзвуков" % int(s["echoes"])
	if s.has("relic"):
		return "порченая реликвия"
	return ""


# Почему выбор нельзя нажать (пусто — можно)
static func blocked_reason(option: Dictionary) -> String:
	var gold_cost: int = 0
	for s: Dictionary in option.get("effects", []):
		gold_cost -= mini(0, int(s.get("gold", 0)))
		if s.has("relic") and not Run.can_take_relic():
			return "Больше реликвий не унести"
	if gold_cost > Run.gold:
		return "Не хватает золота (нужно %d)" % gold_cost
	return ""


# ---------- Выбор ----------

func _choose(option: Dictionary) -> void:
	if option.has("action"):
		_special(option["action"])
		return
	_random = Run.random_hero()
	_lines.clear()
	_won_cards.clear()
	_steps = (option.get("effects", []) as Array).duplicate()
	_story_text = option.get("result", "Отряд идёт дальше.")
	if option.has("chance"):
		var outcome: Dictionary = option["win"] if Run.rng.randf() < float(option["chance"]) else option["lose"]
		_steps.append_array(outcome.get("effects", []))
		_story_text = outcome.get("result", _story_text)
	_sound(_steps)
	_next_step()


# Выполняет шаги по очереди. «Убрать карту» ждёт выбора игрока, потом продолжает.
func _next_step() -> void:
	while not _steps.is_empty():
		var s: Dictionary = _steps.pop_front()
		if s.has("remove"):
			var rh: RunHero = _hero(s["remove"])
			if rh.deck.size() <= Run.MIN_DECK_SIZE:
				_lines.append("%s: колода и так тонкая — убирать нечего" % NAMES[rh.data.id][0])
				continue
			_last_remove = rh.data.id
			var overlay: Control = DeckOverlay.open(self, "Какую карту %s убрать?" % NAMES[rh.data.id][2],
					[{"title": rh.data.title, "color": rh.data.color, "cards": rh.deck}],
					"Нажми на карту — она навсегда уйдёт из колоды.",
					func(_section: int, index: int) -> void: _remove(rh, index))
			# «Передумал» закрывает окно без выбора — тогда карта остаётся, а событие идёт дальше
			overlay.tree_exiting.connect(_removal_skipped.bind(rh))
			return
		_apply_step(s)
	_show_result(_story_text)


func _remove(rh: RunHero, index: int) -> void:
	_last_remove = ""
	_lines.append("%s забывает «%s»" % [NAMES[rh.data.id][0], rh.deck[index].title])
	rh.deck.remove_at(index)
	_next_step()


func _removal_skipped(rh: RunHero) -> void:
	if _last_remove == "":
		return   # карту уже выбрали
	_last_remove = ""
	_lines.append("%s: карту не убрали" % NAMES[rh.data.id][0])
	_next_step.call_deferred()


# Один шаг награды или цены
func _apply_step(s: Dictionary) -> void:
	if s.has("hp"):
		var n: int = int(s["hp"])
		for rh in _targets(s.get("who", "random")):
			var before: int = rh.hp
			if n < 0:
				rh.lose_hp(-n)
			else:
				Run.heal_hero(rh, n)
			var diff: int = rh.hp - before
			if diff != 0:
				_lines.append("%s: %s%d HP" % [rh.data.title, "+" if diff > 0 else "−", absi(diff)])
	elif s.has("gold"):
		var g: int = int(s["gold"])
		Run.gold = maxi(0, Run.gold + g)
		_lines.append(("+%d золота" % g) if g > 0 else ("−%d золота" % -g))
	elif s.has("card"):
		var rh: RunHero = _random if s["card"] == "random" else _hero(s["card"])
		var card: CardData = Run.event_card(rh, s.get("rare", false))
		if card != null:
			Run.add_card(rh, card)
			_lines.append("%s: новая карта «%s»" % [NAMES[rh.data.id][1], card.title])
			_won_cards.append({"card": card, "color": rh.data.color})
	elif s.has("echoes"):
		Run.event_echoes += int(s["echoes"])
		_lines.append("+%d Отзвуков" % int(s["echoes"]))
	elif s.has("relic"):
		var offer: Array[RelicData] = Run.roll_relics(1)
		if offer.is_empty() or not Run.can_take_relic():
			_lines.append("Амулет рассыпается в руках — больше взять нечего")
		else:
			Run.take_relic(offer[0])
			_lines.append("Реликвия «%s»\n+ %s\n− %s" % [offer[0].title, offer[0].plus_text, offer[0].minus_text])


# Кого касается шаг: knight / mage / all / random
func _targets(who: String) -> Array[RunHero]:
	var result: Array[RunHero] = []
	match who:
		"all":
			result.assign(Run.party)
		"random":
			result.append(_random)
		_:
			result.append(_hero(who))
	return result


# Звук по главному в выборе: карта или реликвия — магия, золото — монеты, лечение, иначе удар
func _sound(steps: Array) -> void:
	var kind: String = "hit"
	for s: Dictionary in steps:
		if s.has("card") or s.has("relic") or s.has("echoes") or s.has("remove"):
			kind = "magic"
			break
		if int(s.get("gold", 0)) > 0:
			kind = "coin"
		elif int(s.get("hp", 0)) > 0 and kind == "hit":
			kind = "heal"
	if steps.is_empty():
		return
	Sfx.play(kind, 0.05)


# Особые выборы со своим кодом
func _special(action: String) -> void:
	match action:
		"cache_chest":
			Sfx.play("magic", 0.05)
			_hero("knight").lose_hp(6)
			var closed: Array[RelicData] = Meta.closed_charms()
			var charm: RelicData = closed[Run.rng.randi_range(0, closed.size() - 1)]
			Run.relics.append(charm.id)   # действует сразу, сверх мест
			Meta.unlock_charm(charm.id)   # и открыт на Полке навсегда
			_lines.assign(["Рыцарь: −6 HP", "Оберег «%s»: %s\nОткрыт на Полке трофеев." % [charm.title, charm.desc]])
			_won_cards.clear()
			_show_result("Жижа тянет за поножи, но окованный ящик выходит из грязи вместе с латником — внутри, в промасленной тряпице, лежит вещь дозора.")
		"cage_free":
			Sfx.play("hit", 0.06)
			for rh in Run.party:
				rh.lose_hp(5)
			Run.offer_spirit(Run.cage_spirit())
			Run.last_gold_reward = 0
			Run.goto(Run.REWARD_SCENE)   # там дух выбирает героя
		"cave_enter":
			Sfx.play("magic", 0.05)
			UiKit.clear(_column)
			_column.add_child(UiKit.make_title(_title, 38, UiKit.BRASS.lightened(0.25)))
			_column.add_child(_story("Чем глубже, тем суше воздух. Вода, что стекала по стенам, шипит и исчезает, не долетев до пола."))
			_column.add_child(UiKit.make_button("В бой", Run.enter_cave, "", true))


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


# Экран итога: текст, что получили и чем заплатили, новые карты картинками, отряд, «Дальше»
func _show_result(text: String) -> void:
	UiKit.clear(_column)
	_column.add_child(UiKit.make_title(_title, 38, UiKit.BRASS.lightened(0.25)))
	_column.add_child(_story(text))
	if not _lines.is_empty():
		_column.add_child(UiKit.make_text("\n".join(_lines), 18, UiKit.BRASS.lightened(0.25), 640))
	if not _won_cards.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		for w: Dictionary in _won_cards:
			var b: Button = CardView.make_button(w["card"], w["color"])
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.pivot_offset = Vector2.ZERO
			b.scale = Vector2(CARD_SCALE, CARD_SCALE)
			var holder := Control.new()
			holder.custom_minimum_size = CardView.CARD_SIZE * CARD_SCALE
			holder.add_child(b)
			row.add_child(holder)
		_column.add_child(row)
	_column.add_child(UiKit.party_bar())
	_column.add_child(UiKit.make_button("Дальше", Run.goto.bind(Run.MAP_SCENE), "", true))
