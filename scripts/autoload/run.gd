extends Node
# Состояние текущего забега: сид, общий генератор случайных чисел,
# отряд героев (их здоровье и колоды), золото и карта.
# Это autoload (синглтон): он живёт всё время игры и доступен
# из любого скрипта по имени Run (Проект → Настройки проекта → Глобальные).

const MAIN_MENU_SCENE: String = "res://ui/main_menu.tscn"
const MAP_SCENE: String = "res://ui/map_screen.tscn"
const BATTLE_SCENE: String = "res://scenes/battle.tscn"
const REWARD_SCENE: String = "res://ui/reward_screen.tscn"
const SHOP_SCENE: String = "res://ui/shop_screen.tscn"
const REST_SCENE: String = "res://ui/rest_screen.tscn"
const EVENT_SCENE: String = "res://ui/event_screen.tscn"
const GAME_OVER_SCENE: String = "res://ui/game_over.tscn"
const HUB_SCENE: String = "res://scenes/hub.tscn"
const START_PICK_SCENE: String = "res://ui/start_pick.tscn"
const TROPHY_SCENE: String = "res://ui/trophy_screen.tscn"

# Сколько актов в забеге. Звон открывается, только если пройден последний (пока акт один).
const FINAL_ACT: int = 1

const MAP_ROWS: int = 8        # последний ряд — босс, предпоследний — привал
const MAP_COLS: int = 3
const START_GOLD: int = 30
const REST_HEAL_PERCENT: float = 0.3
const REMOVE_CARD_PRICE: int = 60

# Герои отряда: маг и рыцарь. Их карты и стартовые колоды — внутри этих ресурсов.
const HEROES: Array[HeroData] = [
	preload("res://resources/heroes/mage.tres"),
	preload("res://resources/heroes/knight.tres"),
]

const NORMAL_ENEMIES: Array[EnemyData] = [
	preload("res://resources/enemies/goblin.tres"),
	preload("res://resources/enemies/wolf.tres"),
	preload("res://resources/enemies/cultist.tres"),
	preload("res://resources/enemies/goblin_slinger.tres"),
	preload("res://resources/enemies/bloated_toad.tres"),
	preload("res://resources/enemies/drowned_walker.tres"),
	preload("res://resources/enemies/goblin_shaman.tres"),
]
# Элитный враг акта: встречается один раз, в последнем бою перед привалом и боссом
const ELITE_ENEMY: EnemyData = preload("res://resources/enemies/mossy_treant.tres")
const ELITE_GUARDS: int = 3   # сколько обычных врагов сопровождает элитного
const BOSS_ENEMY: EnemyData = preload("res://resources/enemies/ogre.tres")
const BOSS_GUARD: EnemyData = preload("res://resources/enemies/goblin.tres")

var is_active: bool = false
var seed_value: int = 0
var rng := RandomNumberGenerator.new()   # ВСЯ случайность забега идёт через него

var party: Array[RunHero] = []   # герои отряда: их HP и колоды
var gold: int = 0

var map: Array[MapNode] = []
var current: MapNode = null              # где герой сейчас (null — ещё не вышел)
var pending_enemies: Array[EnemyData] = []  # враги для ближайшего боя
var pending_arena: String = ""               # арена ближайшего боя (ключ из BattleLogic.ARENAS)
var _last_arena: String = ""                 # прошлая арена — чтобы не повторялась подряд
var last_gold_reward: int = 0
var shop_stock: Array[Dictionary] = []   # {"hero": RunHero, "card": CardData}
var shop_removal_used: bool = false
var last_run_won: bool = false
var bell: int = 0                 # Звон (сложность) текущего забега
var act: int = 1
var rows_passed: int = 0         # сколько рядов карты пройдено (для Отзвуков)
var elite_kills: int = 0
var boss_kills: int = 0
var event_echoes: int = 0        # Отзвуки, полученные в событиях
var run_complete: bool = false   # забег пройден до конца (убит финальный босс)
var relics: Array[String] = []   # id оберегов этого забега (из хаба и из тайников)
var trophy_echoes: int = 0       # Отзвуки вместо трофея (когда все обереги открыты)
var trophy_choices: Array[RelicData] = []   # из чего выбирать трофей за босса
var cache_seen: bool = false     # «Тайник павшего дозорного» уже выпадал в этом забеге
var rest_used: bool = false      # первый привал уже был (для «Чистого бинта»)
var candle_used: bool = false    # «Свеча у колокола» уже сработала
var rerolled: bool = false       # «Знакомая тропа» уже использована
var last_battle_big: bool = false   # последний бой — элита или босс (для «Указа коменданта»)
var start_picks: Array[RunHero] = []   # кому предстоит выбор карты перед первой точкой («Заготовка»)
var fast_enemies: bool = false   # «Скорость ×2» во время хода врагов (выбор живёт весь забег)


func _ready() -> void:
	# Общий вид кнопок, подсказок и шрифтов — один на всю игру (см. ui/ui_kit.gd)
	UiKit.apply_theme(get_tree())


# Новый забег. Сид 0 — выбрать случайный.
# bell_level -1 — взять Звон, выбранный в хабе.
func start_new_run(new_seed: int = 0, bell_level: int = -1) -> void:
	if new_seed == 0:
		var temp := RandomNumberGenerator.new()
		temp.randomize()
		new_seed = temp.randi_range(1, 999999)
	seed_value = new_seed
	rng.seed = seed_value
	party.clear()
	start_picks.clear()
	for hero_data in HEROES:
		# Копия описания героя: «Закалка» меняет здоровье только в этом забеге
		var data: HeroData = hero_data.duplicate() as HeroData
		data.max_hp += Meta.effect_total("hero_hp", hero_data.id)
		var rh := RunHero.new(data)
		rh.deck = Meta.start_deck(hero_data)   # своя выкладка из Караульни (или базовая)
		party.append(rh)
		if Meta.effect_total("start_pick", hero_data.id) > 0:
			start_picks.append(rh)
	relics = Meta.valid_chosen()
	gold = START_GOLD + Meta.effect_total("start_gold")
	if relics.has("charm_purse"):
		gold += 40
	trophy_echoes = 0
	trophy_choices.clear()
	cache_seen = false
	rest_used = false
	candle_used = false
	rerolled = false
	last_battle_big = false
	bell = Meta.bell_chosen if bell_level < 0 else bell_level
	act = 1
	rows_passed = 0
	elite_kills = 0
	boss_kills = 0
	event_echoes = 0
	run_complete = false
	fast_enemies = false
	current = null
	pending_enemies.clear()
	_generate_map()
	is_active = true
	print("Новый забег, сид: ", seed_value)


# Если сцену боя запустили напрямую (F6) — создаём забег и бой «для пробы»
func ensure_run() -> void:
	if not is_active:
		start_new_run()
	if pending_enemies.is_empty():
		pending_enemies = _make_encounter(0, false)


# Куда идти после старта забега: выбор «Заготовки» (если куплена) или сразу карта пути
func begin() -> void:
	if start_picks.is_empty():
		goto(MAP_SCENE)
	else:
		goto(START_PICK_SCENE)


func has_relic(id: String) -> bool:
	return relics.has(id)


# Положить карту в колоду героя и записать её в Запас Караульни.
# Возвращает true, если карта записана впервые (экран награды тогда пишет «Записано в Караульню»).
func add_card(rh: RunHero, card: CardData) -> bool:
	rh.deck.append(card)
	if card.is_rare or card.card_set == "":
		return false   # редкие в колоду не записываются, базовые есть в Запасе всегда
	return Meta.record_card(rh.data.id, card.id)


# Привал: доля лечения. Звон 3 урезает, «Лекарские сумки» добавляют, «Чистый бинт» удваивает первый привал.
func rest_percent() -> float:
	var percent: float = REST_HEAL_PERCENT
	if bell >= 3:
		percent -= 0.1
	percent += Meta.effect_total("rest_heal") / 100.0
	if relics.has("charm_bandage") and not rest_used:
		percent *= 2.0
	return percent


# «Знакомая тропа»: один раз за забег перебросить карту до первого шага
func can_reroll_map() -> bool:
	return Meta.effect_total("map_reroll") > 0 and not rerolled and current == null


func reroll_map() -> void:
	rerolled = true
	seed_value += 1
	rng.seed = seed_value
	_generate_map()
	goto(MAP_SCENE)


# Сколько карт в награде каждому герою
func reward_card_count() -> int:
	return 4 if relics.has("charm_decree") and last_battle_big else 3


# Копия врага с другим здоровьем (Звон 5: элита и босс крепче)
func _tougher(enemy: EnemyData, factor: float) -> EnemyData:
	var copy: EnemyData = enemy.duplicate() as EnemyData
	copy.max_hp = ceili(enemy.max_hp * factor)
	return copy


func goto(scene_path: String) -> void:
	# call_deferred — сменить сцену после текущего кадра, а не посреди обработки
	get_tree().change_scene_to_file.call_deferred(scene_path)


# ---------- Карта ----------

func find_map_node(row: int, col: int) -> MapNode:
	for n in map:
		if n.row == row and n.col == col:
			return n
	return null


func row_nodes(row: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for n in map:
		if n.row == row:
			result.append(n)
	return result


# Куда можно пойти сейчас
func available_nodes() -> Array[MapNode]:
	if current == null:
		return row_nodes(0)
	var result: Array[MapNode] = []
	for c in current.next:
		var n: MapNode = find_map_node(current.row + 1, c)
		if n != null:
			result.append(n)
	return result


func enter_node(n: MapNode) -> void:
	current = n
	n.visited = true
	rows_passed = maxi(rows_passed, n.row + 1)
	match n.type:
		MapNode.Type.BATTLE:
			pending_enemies = _make_encounter(n.row, false)
			pending_arena = pick_arena(false)
			goto(BATTLE_SCENE)
		MapNode.Type.ELITE:
			pending_enemies = _make_encounter(n.row, false, true)
			pending_arena = pick_arena(false)
			goto(BATTLE_SCENE)
		MapNode.Type.BOSS:
			pending_enemies = _make_encounter(n.row, true)
			pending_arena = pick_arena(true)
			goto(BATTLE_SCENE)
		MapNode.Type.SHOP:
			shop_stock.clear()
			for rh in party:   # по 2 карты каждому герою
				for card in roll_cards(rh, 2):
					shop_stock.append({"hero": rh, "card": card})
			shop_removal_used = false
			goto(SHOP_SCENE)
		MapNode.Type.REST:
			goto(REST_SCENE)
		MapNode.Type.EVENT:
			goto(EVENT_SCENE)


# Выбирает арену для боя: у босса своя, обычные не повторяются два раза подряд
func pick_arena(is_boss: bool) -> String:
	if is_boss:
		return BattleLogic.BOSS_ARENA
	var options: Array[String] = BattleLogic.ARENA_POOL.duplicate()
	options.erase(_last_arena)
	_last_arena = options[rng.randi_range(0, options.size() - 1)]
	return _last_arena


func _generate_map() -> void:
	map.clear()
	for row in MAP_ROWS:
		var cols: int = 1 if row == MAP_ROWS - 1 else MAP_COLS
		for col in cols:
			var n := MapNode.new()
			n.row = row
			n.col = col
			n.type = _roll_node_type(row)
			map.append(n)
	# Дорожки: из каждой точки — прямо вверх, иногда ещё и вбок
	for row in MAP_ROWS - 1:
		for n in row_nodes(row):
			if row + 1 == MAP_ROWS - 1:
				n.next.append(0)   # все дороги ведут к боссу
				continue
			n.next.append(n.col)
			var side: int = n.col + (1 if rng.randf() < 0.5 else -1)
			if side >= 0 and side < MAP_COLS and rng.randf() < 0.6:
				n.next.append(side)


func _roll_node_type(row: int) -> MapNode.Type:
	if row == 0:
		return MapNode.Type.BATTLE
	if row == MAP_ROWS - 1:
		return MapNode.Type.BOSS
	if row == MAP_ROWS - 2:
		return MapNode.Type.REST
	if row == MAP_ROWS - 3:
		return MapNode.Type.ELITE   # последний бой перед привалом и боссом — элитный
	var roll: float = rng.randf()
	if roll < 0.5:
		return MapNode.Type.BATTLE
	if roll < 0.7:
		return MapNode.Type.EVENT
	if roll < 0.85:
		return MapNode.Type.SHOP
	return MapNode.Type.REST


# Враги для боя: чем выше по карте, тем их больше (отряд из двух героев — врагов тоже больше)
func _make_encounter(row: int, boss: bool, elite: bool = false) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	if boss:
		result.append(_tougher(BOSS_ENEMY, 1.25) if bell >= 5 else BOSS_ENEMY)
		result.append(BOSS_GUARD)
		result.append(BOSS_GUARD)
		result.append(NORMAL_ENEMIES[2])   # и культист
		result.append(NORMAL_ENEMIES[1])   # и волк
		return result
	var count: int = 4 + floori(row / 2.0)
	if bell >= 1 and not elite:
		count += 1   # Звон 1: в обычном бою на врага больше
	if elite:
		result.append(_tougher(ELITE_ENEMY, 1.25) if bell >= 5 else ELITE_ENEMY)
		count = ELITE_GUARDS
	for i in count:
		result.append(_roll_enemy(result))
	return result


# Случайный обычный враг. Некоторых (шаман) в одном бою не больше max_per_battle:
# если лимит выбран — бросаем кубик ещё раз.
func _roll_enemy(taken: Array[EnemyData]) -> EnemyData:
	for attempt in 10:
		var e: EnemyData = NORMAL_ENEMIES[rng.randi_range(0, NORMAL_ENEMIES.size() - 1)]
		if e.max_per_battle <= 0 or taken.count(e) < e.max_per_battle:
			return e
	return NORMAL_ENEMIES[0]


# ---------- Бой и награды ----------

# hp_left — здоровье героев после боя по порядку отряда
func finish_battle(won: bool, hp_left: Array[int]) -> void:
	pending_enemies.clear()
	if not won:
		game_over(false)
		return
	for i in party.size():
		var wake_hp: int = 1   # павший в бою встаёт с 1 HP
		if hp_left[i] <= 0 and relics.has("charm_candle") and not candle_used:
			wake_hp = 5        # «Свеча у колокола»: в первый раз — с 5 HP
			candle_used = true
		party[i].hp = maxi(wake_hp, hp_left[i])
	last_battle_big = false
	if current != null and current.type == MapNode.Type.ELITE:
		elite_kills += 1
		last_battle_big = true
	if current != null and current.type == MapNode.Type.BOSS:
		boss_kills += 1
		last_battle_big = true
		run_complete = act >= FINAL_ACT
		_offer_trophy()
	else:
		last_gold_reward = rng.randi_range(12, 20)
		gold += last_gold_reward
		goto(REWARD_SCENE)


# Трофей за босса: выбор 1 из 3 закрытых оберегов. Закрытых нет — +15 Отзвуков вместо него.
func _offer_trophy() -> void:
	var closed: Array[RelicData] = Meta.closed_charms()
	if closed.is_empty():
		trophy_echoes = Meta.TROPHY_FALLBACK_ECHOES
		game_over(true)
		return
	trophy_choices.clear()
	while trophy_choices.size() < 3 and not closed.is_empty():
		var i: int = rng.randi_range(0, closed.size() - 1)
		trophy_choices.append(closed[i])
		closed.remove_at(i)
	goto(TROPHY_SCENE)


func game_over(victory: bool) -> void:
	last_run_won = victory
	is_active = false
	# Отзвуки дают за любой забег, даже проигранный: чем дальше дошли, тем больше
	Meta.add_run_result({
		"rows": rows_passed, "elites": elite_kills, "bosses": boss_kills,
		"event_echoes": event_echoes, "trophy_echoes": trophy_echoes, "bell": bell, "complete": run_complete,
		"victory": victory, "seed": seed_value,
	})
	goto(GAME_OVER_SCENE)


# Случайные разные карты героя для награды/лавки. Редкие попадаются реже.
# Карты из набора, который игрок уже собирает, выпадают чаще: за каждую взятую
# карту набора (сверх стартовой колоды) её «вес» растёт на SET_WEIGHT_STEP.
const SET_WEIGHT_STEP: float = 0.5
const SET_WEIGHT_MAX: float = 3.0


func roll_cards(rh: RunHero, count: int, no_rare: bool = false) -> Array[CardData]:
	var weights: Dictionary[String, float] = set_weights(rh)
	var pool: Array[CardData] = []
	var locked: Dictionary = Meta.locked_card_ids()   # редкие, ещё не открытые в хабе
	for c in rh.data.card_pool:
		if locked.has(c.id):
			continue
		if c.is_rare and (no_rare or rng.randf() > 0.4):
			continue
		pool.append(c)
	var result: Array[CardData] = []
	while result.size() < count and not pool.is_empty():
		# Выбор с весами: чем больше вес, тем больше шанс
		var total: float = 0.0
		for c in pool:
			total += weights.get(c.card_set, 1.0)
		var roll: float = rng.randf() * total
		var pick: int = pool.size() - 1
		for i in pool.size():
			roll -= weights.get(pool[i].card_set, 1.0)
			if roll <= 0.0:
				pick = i
				break
		result.append(pool[pick])
		pool.remove_at(pick)
	return result


# Вес каждого набора для героя: 1 + 0.5 за каждую карту набора, взятую в забеге
func set_weights(rh: RunHero) -> Dictionary[String, float]:
	var counts: Dictionary[String, int] = {}
	for c in rh.deck:
		counts[c.card_set] = counts.get(c.card_set, 0) + 1
	for c in rh.data.starter_deck:
		counts[c.card_set] = counts.get(c.card_set, 0) - 1
	var weights: Dictionary[String, float] = {}
	for key: String in counts:
		if key != "" and counts[key] > 0:
			weights[key] = minf(SET_WEIGHT_MAX, 1.0 + SET_WEIGHT_STEP * counts[key])
	return weights


func random_rare_card(hero_data: HeroData) -> CardData:
	var rares: Array[CardData] = []
	var locked: Dictionary = Meta.locked_card_ids()
	for c in hero_data.card_pool:
		if c.is_rare and not locked.has(c.id):
			rares.append(c)
	if rares.is_empty():   # на всякий случай: все редкие закрыты
		for c in hero_data.card_pool:
			if c.is_rare:
				rares.append(c)
	return rares[rng.randi_range(0, rares.size() - 1)]


func random_hero() -> RunHero:
	return party[rng.randi_range(0, party.size() - 1)]


func card_price(card: CardData) -> int:
	return 75 if card.is_rare else 45


func total_cards() -> int:
	var n: int = 0
	for rh in party:
		n += rh.deck.size()
	return n


# Перемешивание через общий генератор (повторяемо по сиду)
func shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


# Список колоды героя для подсказки: «Удар ×4, Щит ×3…»
func deck_summary(rh: RunHero) -> String:
	var counts: Dictionary[String, int] = {}
	for c in rh.deck:
		counts[c.title] = counts.get(c.title, 0) + 1
	var parts: PackedStringArray = []
	for title: String in counts:
		parts.append("%s ×%d" % [title, counts[title]])
	return "\n".join(parts)
