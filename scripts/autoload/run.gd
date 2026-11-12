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

const MAP_ROWS: int = 8        # последний ряд — босс, предпоследний — привал
const MAP_COLS: int = 3
const OBJECTIVE_FROM_ROW: int = 2     # с какого ряда карты бывают бои с особой целью
const OBJECTIVE_CHANCE: float = 0.3   # шанс особой цели у обычного боя
const OBJECTIVE_GOLD: int = 15        # доплата золотом за бой с особой целью
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
var pending_objective: int = 0               # цель ближайшего боя (BattleLogic.Objective)
var _last_arena: String = ""                 # прошлая арена — чтобы не повторялась подряд
var last_gold_reward: int = 0
var shop_stock: Array[Dictionary] = []   # {"hero": RunHero, "card": CardData}
var shop_removal_used: bool = false
var last_run_won: bool = false
var fast_enemies: bool = false   # «Скорость ×2» во время хода врагов (выбор живёт весь забег)


func _ready() -> void:
	# Общий вид кнопок, подсказок и шрифтов — один на всю игру (см. ui/ui_kit.gd)
	UiKit.apply_theme(get_tree())


# Новый забег. Сид 0 — выбрать случайный.
func start_new_run(new_seed: int = 0) -> void:
	if new_seed == 0:
		var temp := RandomNumberGenerator.new()
		temp.randomize()
		new_seed = temp.randi_range(1, 999999)
	seed_value = new_seed
	rng.seed = seed_value
	party.clear()
	for hero_data in HEROES:
		party.append(RunHero.new(hero_data))
	gold = START_GOLD
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
	match n.type:
		MapNode.Type.BATTLE:
			pending_enemies = _make_encounter(n.row, false)
			pending_arena = pick_arena(false)
			pending_objective = pick_objective(n.row, pending_enemies, pending_arena)
			goto(BATTLE_SCENE)
		MapNode.Type.ELITE:
			pending_enemies = _make_encounter(n.row, false, true)
			pending_arena = pick_arena(false)
			pending_objective = BattleLogic.Objective.KILL_ALL
			goto(BATTLE_SCENE)
		MapNode.Type.BOSS:
			pending_enemies = _make_encounter(n.row, true)
			pending_arena = pick_arena(true)
			pending_objective = BattleLogic.Objective.KILL_ALL
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


# Особая цель обычного боя: с OBJECTIVE_FROM_ROW ряда карты, с шансом OBJECTIVE_CHANCE.
# «Ритуал» — только если среди врагов есть шаман или культист; «Прорыв» — не на «Старой гати»
# (через узкие переправы до верха почти не дойти).
func pick_objective(row: int, enemies: Array[EnemyData], arena: String) -> int:
	if row < OBJECTIVE_FROM_ROW or rng.randf() >= OBJECTIVE_CHANCE:
		return BattleLogic.Objective.KILL_ALL
	var options: Array[int] = [BattleLogic.Objective.RISING_WATER]
	if arena != "gat":
		options.append(BattleLogic.Objective.BREAKTHROUGH)
	for e in enemies:
		if BattleLogic.RITUAL_CASTERS.has(e.id):
			options.append(BattleLogic.Objective.RITUAL)
			break
	return options[rng.randi_range(0, options.size() - 1)]


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
		result.append(BOSS_ENEMY)
		result.append(BOSS_GUARD)
		result.append(BOSS_GUARD)
		result.append(NORMAL_ENEMIES[2])   # и культист
		result.append(NORMAL_ENEMIES[1])   # и волк
		return result
	var count: int = 4 + floori(row / 2.0)
	if elite:
		result.append(ELITE_ENEMY)
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
		party[i].hp = maxi(1, hp_left[i])   # павший в бою встаёт с 1 HP
	if current != null and current.type == MapNode.Type.BOSS:
		game_over(true)
	else:
		last_gold_reward = rng.randi_range(12, 20)
		if pending_objective != BattleLogic.Objective.KILL_ALL:
			last_gold_reward += OBJECTIVE_GOLD   # за бой с особой целью
		pending_objective = BattleLogic.Objective.KILL_ALL
		gold += last_gold_reward
		goto(REWARD_SCENE)


func game_over(victory: bool) -> void:
	last_run_won = victory
	is_active = false
	goto(GAME_OVER_SCENE)


# Случайные разные карты героя для награды/лавки. Редкие попадаются реже.
# Карты из набора, который игрок уже собирает, выпадают чаще: за каждую взятую
# карту набора (сверх стартовой колоды) её «вес» растёт на SET_WEIGHT_STEP.
const SET_WEIGHT_STEP: float = 0.5
const SET_WEIGHT_MAX: float = 3.0


func roll_cards(rh: RunHero, count: int) -> Array[CardData]:
	var weights: Dictionary[String, float] = set_weights(rh)
	var pool: Array[CardData] = []
	for c in rh.data.card_pool:
		if c.is_rare and rng.randf() > 0.4:
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
