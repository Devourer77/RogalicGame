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
const OBJECTIVE_FROM_ROW: int = 2     # с какого ряда карты бывают бои с особой целью
const OBJECTIVE_CHANCE: float = 0.3   # шанс особой цели у обычного боя
const OBJECTIVE_GOLD: int = 15        # доплата золотом за бой с особой целью
const MAX_RELICS: int = 4             # больше порченых реликвий за забег не взять (обереги не в счёт)
const RELIC_CHOICES: int = 3          # из скольких выбирать после элиты
const RELIC_DIR: String = "res://resources/relics/"
const SLIME_CARD: String = "res://resources/cards/swamp_slime.tres"
const START_GOLD: int = 30
const REST_HEAL_PERCENT: float = 0.3
const REMOVE_CARD_PRICE: int = 60

# Герои отряда: маг и рыцарь. Их карты и стартовые колоды — внутри этих ресурсов.
const HEROES: Array[HeroData] = [
	preload("res://resources/heroes/mage.tres"),
	preload("res://resources/heroes/knight.tres"),
]

# Отряды врагов акта (resources/encounters): обычные бои, элиты и боссы.
# Обычный бой берёт отряд своей ступени (ряды 0–1, 2–3, 4+), за забег отряд не повторяется.
const ENCOUNTERS: Array[EncounterData] = [
	preload("res://resources/encounters/gang.tres"),
	preload("res://resources/encounters/pack.tres"),
	preload("res://resources/encounters/choir.tres"),
	preload("res://resources/encounters/gas_ambush.tres"),
	preload("res://resources/encounters/shaman_guard.tres"),
	preload("res://resources/encounters/web.tres"),
	preload("res://resources/encounters/rift_mix.tres"),
	preload("res://resources/encounters/drivers.tres"),
	preload("res://resources/encounters/rising_bog.tres"),
]
# Пулы элит и боссов акта: в начале забега выбираются ELITES_PER_RUN разных элит и один босс
const ELITE_POOL: Array[EncounterData] = [
	preload("res://resources/encounters/elite_treant.tres"),
	preload("res://resources/encounters/elite_queen.tres"),
	preload("res://resources/encounters/elite_alpha.tres"),
]
const BOSS_POOL: Array[EncounterData] = [
	preload("res://resources/encounters/boss_ogre.tres"),
	preload("res://resources/encounters/boss_mother.tres"),
]
const ELITES_PER_RUN: int = 2        # необязательная элита на развилке + обязательная перед привалом
const OPTIONAL_ELITE_ROW: int = 3    # ряд карты с необязательной элитой (одна точка из трёх)

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
var pending_encounter: EncounterData = null  # отряд ближайшего боя (его название видно в начале боя)
var run_elites: Array[EncounterData] = []    # элиты этого забега: [на развилке, перед привалом]
var run_boss: EncounterData = null           # босс этого забега (виден на карте с самого начала)
var used_encounters: Array[String] = []      # какие обычные отряды уже были (не повторяются)
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
	pending_encounter = null
	used_encounters.clear()
	_pick_act_bosses()
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
			pending_arena = _encounter_arena(false)
			pending_objective = pick_objective(n.row, pending_enemies, pending_arena)
			goto(BATTLE_SCENE)
		MapNode.Type.ELITE:
			pending_enemies = _make_encounter(n.row, false, true)
			pending_arena = _encounter_arena(false)
			pending_objective = BattleLogic.Objective.KILL_ALL
			goto(BATTLE_SCENE)
		MapNode.Type.BOSS:
			pending_enemies = _make_encounter(n.row, true)
			pending_arena = _encounter_arena(true)
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


# Арена отряда, если у него своя (у боссов, у Прядильщицы), иначе — обычный выбор
func _encounter_arena(is_boss: bool) -> String:
	if pending_encounter != null and pending_encounter.arena != "":
		return pending_encounter.arena
	return pick_arena(is_boss)


# Выбирает арену для боя: у босса своя, обычные не повторяются два раза подряд
func pick_arena(is_boss: bool) -> String:
	if is_boss:
		if run_boss != null and run_boss.arena != "":
			return run_boss.arena
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
	_place_optional_elite()


# Необязательная элита: одна точка в ряду OPTIONAL_ELITE_ROW. Чтобы её всегда можно было
# обойти, из точки под ней обязательно есть дорожка вбок.
func _place_optional_elite() -> void:
	if OPTIONAL_ELITE_ROW <= 0 or OPTIONAL_ELITE_ROW >= MAP_ROWS - 3:
		return
	var col: int = rng.randi_range(0, MAP_COLS - 1)
	var node: MapNode = find_map_node(OPTIONAL_ELITE_ROW, col)
	if node == null:
		return
	node.type = MapNode.Type.ELITE
	for n in row_nodes(OPTIONAL_ELITE_ROW - 1):
		var others: bool = false
		for c in n.next:
			if c != col:
				others = true
		if not others:
			n.next.append(col + 1 if col + 1 < MAP_COLS else col - 1)


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


# Элиты и босс этого забега — один раз, в начале (через общий генератор забега)
func _pick_act_bosses() -> void:
	var elites: Array[EncounterData] = ELITE_POOL.duplicate()
	run_elites.clear()
	for i in mini(ELITES_PER_RUN, elites.size()):
		run_elites.append(elites.pop_at(rng.randi_range(0, elites.size() - 1)))
	run_boss = BOSS_POOL[rng.randi_range(0, BOSS_POOL.size() - 1)]


# Элита для точки на этом ряду: перед привалом — последняя из выбранных, на развилке — первая
func elite_for_row(row: int) -> EncounterData:
	if run_elites.is_empty():
		_pick_act_bosses()
	return run_elites[-1] if row >= MAP_ROWS - 3 else run_elites[0]


# Обычный отряд для ряда: своей ступени и ещё не встреченный в этом забеге
func _pick_encounter(row: int) -> EncounterData:
	var options: Array[EncounterData] = []
	for enc in ENCOUNTERS:
		if enc.fits_row(row) and not used_encounters.has(enc.id):
			options.append(enc)
	if options.is_empty():   # все отряды ступени уже были — можно повторить
		for enc in ENCOUNTERS:
			if enc.fits_row(row):
				options.append(enc)
	if options.is_empty():
		options = ENCOUNTERS.duplicate()
	var picked: EncounterData = options[rng.randi_range(0, options.size() - 1)]
	used_encounters.append(picked.id)
	return picked


# Враги для боя: ядро отряда целиком, а до 4 + ряд/2 (отряд из двух героев — врагов тоже
# больше) — добор из списка отряда. У элиты и босса — ровно их состав.
func _make_encounter(row: int, boss: bool, elite: bool = false) -> Array[EnemyData]:
	if run_boss == null:
		_pick_act_bosses()
	var enc: EncounterData = run_boss if boss else (elite_for_row(row) if elite else _pick_encounter(row))
	pending_encounter = enc
	var result: Array[EnemyData] = []
	for i in enc.core.size():
		var d: EnemyData = enc.core[i]
		if i == 0 and enc.kind != EncounterData.Kind.NORMAL and bell >= 5:
			d = _tougher(d, 1.25)   # Звон 5: элита и босс крепче
		result.append(d)
	if enc.kind == EncounterData.Kind.NORMAL:
		var count: int = maxi(result.size(), 4 + floori(row / 2.0))
		if bell >= 1:
			count += 1   # Звон 1: в обычном бою на врага больше
		while result.size() < count:
			result.append(_roll_filler(enc, result))
	return result


# Случайный враг из добора отряда. Некоторых (шаман) в одном бою не больше max_per_battle.
func _roll_filler(enc: EncounterData, taken: Array[EnemyData]) -> EnemyData:
	var pool: Array[EnemyData] = enc.filler if not enc.filler.is_empty() else enc.core
	for attempt in 10:
		var e: EnemyData = pool[rng.randi_range(0, pool.size() - 1)]
		if e.max_per_battle <= 0 or taken.count(e) < e.max_per_battle:
			return e
	return pool[0]


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
		if pending_objective != BattleLogic.Objective.KILL_ALL:
			last_gold_reward += OBJECTIVE_GOLD   # за бой с особой целью
		pending_objective = BattleLogic.Objective.KILL_ALL
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


# ---------- Порченые реликвии ----------
# Лежат в resources/relics/ рядом с оберегами (RelicData.Kind.CORRUPTED), в забеге —
# тем же списком id `relics`, что и обереги; эффекты проверяют has_relic("id").

# Лечение героя между боями (привал, события). «Клеймо стража»: рыцарь лечится вдвое слабее.
func heal_hero(rh: RunHero, amount: int) -> void:
	if rh.data.id == "knight" and has_relic("warden_brand"):
		amount = amount / 2
	rh.heal(amount)


# Описание оберега или реликвии по id (для значков и подсказок). null — нет такого.
func relic_data(id: String) -> RelicData:
	var path: String = RELIC_DIR + id + ".tres"
	return load(path) as RelicData if ResourceLoader.exists(path) else null


# Описания всех оберегов и реликвий этого забега
func relic_list() -> Array[RelicData]:
	var result: Array[RelicData] = []
	for id in relics:
		var r: RelicData = relic_data(id)
		if r != null:
			result.append(r)
	return result


func corrupted_count() -> int:
	var n: int = 0
	for r in relic_list():
		if r.kind == RelicData.Kind.CORRUPTED:
			n += 1
	return n


func can_take_relic() -> bool:
	return corrupted_count() < MAX_RELICS


# Все порченые реликвии из resources/relics/ (новую достаточно положить туда .tres с kind = 0)
func all_relics() -> Array[RelicData]:
	var result: Array[RelicData] = []
	var dir := DirAccess.open(RELIC_DIR)
	if dir == null:
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()   # порядок файлов на разных ПК разный — сортируем, чтобы сид давал то же самое
	for file_name: String in names:
		var clean: String = file_name.trim_suffix(".remap")   # в собранной игре файлы лежат как *.tres.remap
		if clean.ends_with(".tres"):
			var r: RelicData = load(RELIC_DIR + clean) as RelicData
			if r != null and r.kind == RelicData.Kind.CORRUPTED:
				result.append(r)
	return result


# Случайные реликвии, которых ещё нет в забеге
func roll_relics(count: int) -> Array[RelicData]:
	var pool: Array[RelicData] = []
	for r in all_relics():
		if not has_relic(r.id):
			pool.append(r)
	shuffle(pool)
	return pool.slice(0, count)


# Взять реликвию. Минус «Сердца утопленника» — тина в колоду мага навсегда.
func take_relic(r: RelicData) -> void:
	if r == null or has_relic(r.id) or not can_take_relic():
		return
	relics.append(r.id)
	if r.id == "drowned_heart":
		for rh in party:
			if rh.data.id == "mage":
				rh.deck.append(load(SLIME_CARD))


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
