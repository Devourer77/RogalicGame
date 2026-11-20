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
const ACT_SCENE: String = "res://ui/act_screen.tscn"

# Акты забега по порядку (resources/acts/, мир.md, раздел 2). Звон открывается, только если пройден последний.
# Акты 2 и 3 пока на врагах и аренах акта 1, только крепче (ActData.borrow_from) — их собственные враги в работе.
const ACTS: Array[ActData] = [
	preload("res://resources/acts/act_1.tres"),
	preload("res://resources/acts/act_2.tres"),
	preload("res://resources/acts/act_3.tres"),
]
# Сколько актов в забеге. 1 — забег как раньше (только Гнилые топи), 3 — весь путь до Шпиля.
const FINAL_ACT: int = 3
const ACT_HEAL_PERCENT: float = 1.0   # сколько недостающего здоровья возвращается при переходе в новый акт
const BOSS_GOLD: Vector2i = Vector2i(35, 50)   # золото за босса, если забег на нём не кончается

const MAP_ROWS: int = 8        # последний ряд — босс, предпоследний — общий привал
# Две ветки рядом (мир.md, раздел 2): колонки 0–2 — Болота, 3–5 — Лес. Сходятся на привале перед боссом.
const BRANCH_COLS: int = 4     # дорожек-колонок в одной ветке (в ряду 2–4 точки — где прошли тропы)
const MAP_COLS: int = BRANCH_COLS * 2
const CROSS_ROW: int = 3       # с этого ряда — тропа-переход между ветками через мост (на ряд выше)
const PATHS_PER_BRANCH: int = 4   # сколько троп идёт снизу вверх в каждой ветке (сливаются и расходятся)
const FOG_SIGHT: int = 2          # туман: тип точки виден на столько рядов вперёд от текущей
const OBJECTIVE_FROM_ROW: int = 2     # с какого ряда карты бывают бои с особой целью
# Модификаторы врагов (тз-сложность-боя.md): сколько врагов в бою получают «характер»
const MODIFIERS_DIR: String = "res://resources/enemy_modifiers/"
const MODIFIER_IDS: Array[String] = ["frenzy", "rally", "spite", "faith", "tenacious", "rotten"]
const MOD_FROM_ROW: int = 2            # с какого ряда в обычных боях
const MOD_MORE_FROM_ROW: int = 4       # с этого ряда — двое
const MOD_BELL: int = 2                # с этого Звона — ещё один в каждом бою, начиная с ряда 0
const WAVE_BELL: int = 4               # с этого Звона в каждой волне подкрепления на 1 врага больше
const OBJECTIVE_CHANCE: float = 0.3   # шанс особой цели у обычного боя
const OBJECTIVE_GOLD: int = 15        # доплата золотом за бой с особой целью
const MAX_RELICS: int = 4             # больше порченых реликвий за забег не взять (обереги не в счёт)
const RELIC_CHOICES: int = 3          # из скольких выбирать после элиты
const RELIC_DIR: String = "res://resources/relics/"
const SPIRIT_DIR: String = "res://resources/spirits/"
const SPIRIT_IDS: Array[String] = ["tide", "storm", "wind"]   # обычные духи, которые встречаются в логове
const ALL_SPIRIT_IDS: Array[String] = ["tide", "storm", "wind", "bog", "fire", "forest"]   # все духи по порядку Святилища
# Тлеющая расщелина (секретный бой с Жаровиком, тз-дух-огня.md)
const CAVE_EVENT_CHANCE: float = 0.25   # шанс, что событие окажется расщелиной
const CAVE_ROWS: Vector2i = Vector2i(1, 4)   # в каких рядах карты она может встретиться
const CAVE_ECHOES: int = 10             # Отзвуки за победу в пещере
const MIN_DECK_SIZE: int = 5            # меньше стольких карт в колоде убрать нельзя (лавка, события)
const WOUND_CARD: String = "res://resources/cards/wound.tres"   # «Рана» павшему в бою (тз-сложность-боя.md)
const WOUNDS_PER_FALL: int = 1          # сколько Ран за одно падение
const SPIRIT_SLOTS: int = 2                            # духов на героя
const LAIR_ROW: int = 2                                # ряд карты с логовом духа (одна точка)
const SPIRIT_CARD_WEIGHT: float = 2.0                  # карты своих духов и смешанные выпадают чаще
const SLIME_CARD: String = "res://resources/cards/swamp_slime.tres"
const START_GOLD: int = 30
const REST_HEAL_PERCENT: float = 0.3
const REMOVE_CARD_PRICE: int = 40   # удаление в полтора раза дешевле прежнего (тз-карты.md)
const UPGRADE_PRICE: int = 50       # улучшение карты в лавке
const UPGRADE_CHOICES: int = 3      # сколько карт предлагают улучшить в награде
const SKIP_HEAL: int = 3            # пропустил награду — каждому герою столько HP

# Герои отряда: маг и рыцарь. Их карты и стартовые колоды — внутри этих ресурсов.
const HEROES: Array[HeroData] = [
	preload("res://resources/heroes/mage.tres"),
	preload("res://resources/heroes/knight.tres"),
]

# Отряды, элиты и боссы — в файле акта (resources/acts/act_N.tres), берутся через encounters(),
# elite_pool(), boss_pool(). Обычный бой берёт отряд своей ступени (ряды 0–1, 2–3, 4+), за акт отряд не повторяется.
const ELITES_PER_RUN: int = 1        # на ветку: одна обязательная элита перед привалом (вторая — только через событие)

var is_active: bool = false
var seed_value: int = 0
var rng := RandomNumberGenerator.new()   # ВСЯ случайность забега идёт через него

var party: Array[RunHero] = []   # герои отряда: их HP и колоды
var gold: int = 0

var map: Array[MapNode] = []
var current: MapNode = null              # где герой сейчас (null — ещё не вышел)
var pending_enemies: Array[EnemyData] = []  # враги для ближайшего боя
var pending_spirit: SpiritData = null      # дух в логове (бой за него)
var last_drowned: int = 0                  # сколько врагов утонуло в последнем бою
var last_forest_burnt: int = 0             # сколько живых деревьев и клеток лозы сгорело в последнем бою (условие Лешего)
const BOG_SPIRIT_DROWNS: int = 2            # условие Хозяина трясины: утопить столько врагов в бою с корягачом
var tamed_spirit: SpiritData = null        # дух, покорённый в последнем бою (ждёт выбора героя)
var run_spirits: Array[String] = []        # кого покорили в этом забеге (для «Итога пути» и Летописи)
var known_spirits: Array[String] = []      # кого отряд покорял в прошлых забегах (для «Старой узды»)
const SPIRIT_START_CARDS: int = 3          # сколько карт дух даёт герою сразу
var pending_arena: String = ""               # арена ближайшего боя (ключ из BattleLogic.ARENAS)
var pending_objective: int = 0               # цель ближайшего боя (BattleLogic.Objective)
var pending_encounter: EncounterData = null  # отряд ближайшего боя (его название видно в начале боя)
var run_elites: Array[EncounterData] = []    # элиты забега: [Болота, Лес] — обязательные, ряд перед привалом
var pending_event_elite: EncounterData = null   # элита, которую позвало событие (бой прямо из события)
var forced_encounter: EncounterData = null      # обычный отряд, которого позвало событие
var keepers_calm: bool = false                  # Хранители приняли дар: до конца акта их удары на 1 слабее
var keepers_fewer: int = 0                      # в стольких следующих боях с Хранителями — на одного меньше
var gold_after_battle: int = 0                  # золото, обещанное событием за следующий бой («Дым над топью»)
var fog_bonus: int = 0                       # насколько дальше видно сквозь туман (события «запомнить следы», «рассказ дозорного»)
var run_boss: EncounterData = null           # босс акта на текущей ветке (виден на карте с ряда 5)
# Босс по ветке (MapNode.BOG / FOREST → отряд босса). В акте 1 у обеих веток один босс; в акте 2 —
# свой босс ветки (Исполин — Тракт, Колосс — Подземье) или, с шансом BOSS_SHARED_CHANCE, общий (Сосуд) у обеих.
var branch_bosses: Dictionary[int, EncounterData] = {}
const BOSS_SHARED_CHANCE: float = 1.0 / 3.0
var used_encounters: Array[String] = []      # какие обычные отряды уже были (не повторяются)
var _last_arena: String = ""                 # прошлая арена — чтобы не повторялась подряд
var last_gold_reward: int = 0
var shop_stock: Array[Dictionary] = []   # {"hero": RunHero, "card": CardData}
var shop_removal_used: bool = false
var shop_upgrade_used: bool = false   # в этой лавке уже улучшили карту
var last_run_won: bool = false
var bell: int = 0                 # Звон (сложность) текущего забега
var act: int = 1                 # текущий акт (1…FINAL_ACT)
var final_act: int = FINAL_ACT   # на каком акте кончается забег (замер ботом может взять 1 — только акт 1)
var act_cleared: bool = false    # босс акта побеждён, впереди награда, трофей и переход в следующий акт
var rows_passed: int = 0         # сколько рядов карты пройдено (для Отзвуков)
var elite_kills: int = 0
var boss_kills: int = 0
var event_echoes: int = 0        # Отзвуки, полученные в событиях
var run_complete: bool = false   # забег пройден до конца (убит финальный босс)
var relics: Array[String] = []   # id оберегов этого забега (из хаба и из тайников)
var trophy_echoes: int = 0       # Отзвуки вместо трофея (когда все обереги открыты)
var trophy_choices: Array[RelicData] = []   # из чего выбирать трофей за босса
var cache_seen: bool = false     # «Тайник павшего дозорного» уже выпадал в этом забеге
var last_wounded: Array[String] = []   # кто получил Рану в последнем бою (показать на экране награды)
var wounds_per_fall: int = WOUNDS_PER_FALL   # сколько Ран за падение (замер может выключить: 0)
var sim_no_scenes: bool = false        # замер забега ботом: goto() ничего не открывает
var events_seen: Array[String] = []   # названия событий, уже выпавших в этом забеге (не повторяются)
var cave_seen: bool = false      # «Тлеющая расщелина» уже встречалась в этом забеге
var in_cave: bool = false        # идёт бой в пещере Жаровика
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
	last_wounded.clear()
	events_seen.clear()
	cave_seen = false
	in_cave = false
	rest_used = false
	candle_used = false
	rerolled = false
	fog_bonus = 0
	pending_event_elite = null
	forced_encounter = null
	keepers_calm = false
	keepers_fewer = 0
	gold_after_battle = 0
	last_battle_big = false
	bell = Meta.bell_chosen if bell_level < 0 else bell_level
	act = 1
	act_cleared = false
	rows_passed = 0
	elite_kills = 0
	boss_kills = 0
	event_echoes = 0
	run_complete = false
	fast_enemies = false
	run_spirits.clear()
	known_spirits.clear()
	for id: String in Meta.spirits_tamed:
		if Meta.is_spirit_tamed(id):
			known_spirits.append(id)
	tamed_spirit = null
	pending_spirit = null
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
	if not card.spirit_ids.is_empty():
		return false   # карты духов приходят только вместе с духом — в Запас их не пишем
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
	if sim_no_scenes:
		return   # замер забега ботом (tests/balance_run.gd): экраны не открываем
	# call_deferred — сменить сцену после текущего кадра, а не посреди обработки
	get_tree().change_scene_to_file.call_deferred(scene_path)


# ---------- Акты ----------

func act_data() -> ActData:
	return ACTS[clampi(act, 1, ACTS.size()) - 1]


# Акт, у которого текущий берёт недостающее (сам он, если брать не у кого)
func _lender() -> ActData:
	var a: ActData = act_data()
	return ACTS[a.borrow_from - 1] if a.borrow_from > 0 and a.borrow_from <= ACTS.size() else a


func encounters() -> Array[EncounterData]:
	var a: ActData = act_data()
	return a.encounters if not a.encounters.is_empty() else _lender().encounters


func elite_pool() -> Array[EncounterData]:
	var a: ActData = act_data()
	return a.elite_pool if not a.elite_pool.is_empty() else _lender().elite_pool


func boss_pool() -> Array[EncounterData]:
	var a: ActData = act_data()
	return a.boss_pool if not a.boss_pool.is_empty() else _lender().boss_pool


# Названия двух веток карты текущего акта
func branch_titles() -> Array[String]:
	return act_data().branch_titles


# Арены обычных боёв ветки (MapNode.BOG — левая, MapNode.FOREST — правая)
func arena_pool(branch: int) -> Array[String]:
	var right: bool = branch == MapNode.FOREST
	for a: ActData in [act_data(), _lender()]:
		var pool: Array[String] = a.arenas_right if right else a.arenas_left
		if not pool.is_empty():
			return pool
	return BattleLogic.FOREST_ARENA_POOL if right else BattleLogic.ARENA_POOL


# Арена босса: своя у отряда босса, иначе — арена босса акта
func boss_arena() -> String:
	if run_boss != null and run_boss.arena != "":
		return run_boss.arena
	for a: ActData in [act_data(), _lender()]:
		if a.boss_arena != "":
			return a.boss_arena
	return BattleLogic.BOSS_ARENA


# Рисунок карты пути текущего акта (своего ещё нет — рисунок акта 1)
func map_background() -> String:
	var path: String = act_data().map_bg
	return path if path != "" and ResourceLoader.exists(path) else ACTS[0].map_bg


# Копия врага для акта, который пока живёт на чужих врагах: крепче и бьёт сильнее (общий файл не меняется)
func _act_scaled(d: EnemyData) -> EnemyData:
	var a: ActData = act_data()
	if is_equal_approx(a.enemy_hp_mult, 1.0) and a.enemy_damage_add == 0:
		return d
	var copy: EnemyData = d.duplicate() as EnemyData
	copy.max_hp = ceili(d.max_hp * a.enemy_hp_mult)
	if copy.damage > 0:
		copy.damage += a.enemy_damage_add
	var cyc: Array[EnemyAttackData] = []
	for atk in d.cycle:
		var c: EnemyAttackData = atk.duplicate() as EnemyAttackData
		if c.damage > 0:
			c.damage += a.enemy_damage_add
		cyc.append(c)
	copy.cycle = cyc
	return copy


# После награды: босс акта побеждён — трофей и следующий акт, иначе — обратно на карту
func after_reward() -> void:
	if act_cleared:
		_offer_trophy()
	else:
		goto(MAP_SCENE)


# После трофея: финальный босс — итог забега, иначе — переход в следующий акт
func after_trophy() -> void:
	if run_complete:
		game_over(true)
	else:
		next_act()


# Переход в следующий акт: отряд переводит дух, новая карта, новые элиты и босс.
# Колоды, духи, золото, реликвии и Раны остаются.
func next_act() -> void:
	act_cleared = false
	act = mini(act + 1, mini(final_act, ACTS.size()))
	for rh in party:
		rh.heal(ceili((rh.data.max_hp - rh.hp) * ACT_HEAL_PERCENT))
	current = null
	pending_enemies.clear()
	pending_encounter = null
	pending_event_elite = null
	forced_encounter = null
	used_encounters.clear()
	_last_arena = ""
	fog_bonus = 0
	keepers_calm = false
	keepers_fewer = 0
	_pick_act_bosses()
	_generate_map()
	goto(ACT_SCENE)


# Награда после этого боя — большая (элита или босс акта): редкие карты, улучшение, реликвия
func is_big_reward() -> bool:
	return is_elite_battle() or act_cleared


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
	pending_event_elite = null   # бой из прошлого события позади
	forced_encounter = null
	current = n
	n.visited = true
	rows_passed = maxi(rows_passed, (act - 1) * MAP_ROWS + n.row + 1)   # ряды считаются через все акты
	if n.branch != MapNode.COMMON and branch_bosses.has(n.branch):
		_set_boss(branch_bosses[n.branch])   # ветка выбрана — в конце её ждёт свой босс
	match n.type:
		MapNode.Type.BATTLE:
			pending_enemies = _make_encounter(n.row, false)
			pending_arena = _encounter_arena(false)
			pending_objective = pick_objective(n.row, pending_enemies, pending_arena)
			goto(BATTLE_SCENE)
		MapNode.Type.ELITE:
			pending_enemies = _make_encounter(n.row, false, true)
			if bog_spirit_offered():
				Meta.mark_spirit_seen("bog")   # Хозяин трясины показался: Святилище откроет подсказку
			if forest_spirit_offered():
				Meta.mark_spirit_seen("forest")   # Леший показался у Голоса Рощи
			pending_arena = _encounter_arena(false)
			pending_objective = BattleLogic.Objective.KILL_ALL
			goto(BATTLE_SCENE)
		MapNode.Type.LAIR:
			pending_spirit = _roll_lair_spirit()
			pending_enemies = _make_encounter(n.row, false)
			pending_enemies.resize(mini(pending_enemies.size(), 2))   # дух и пара тварей
			if pending_spirit != null:
				pending_enemies.push_front(pending_spirit.enemy)
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
			shop_upgrade_used = false
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
# Знаки босса: предметы у края первых арен (ряды 0–1), по которым можно догадаться, кто ждёт в конце.
# У каждого босса три знака, на арене — один случайный. Подсказка без имени босса.
const BOSS_SIGN_ROWS: int = 1   # знаки стоят на аренах рядов 0..BOSS_SIGN_ROWS
const BOSS_SIGNS: Dictionary = {
	"boss_captain": [
		["sign_captain_helm", "Ржавый шлем Стражи с выцветшим плюмажем. Кто-то из офицеров ушёл в трясину — и, похоже, не до конца."],
		["sign_captain_bell", "Треснувший колокол Стражи в воде. Говорят, по ночам он звонит сам — сбор на поверку."],
		["sign_captain_halberd", "Обломок алебарды с клочком табарда. Стража здесь отступала — но приказа отступать не было."],
	],
	"boss_ogre": [
		["sign_ogre_column", "Колонну сломали пополам — не тараном, а голыми руками."],
		["sign_ogre_shackles", "Кандалы на ногу толщиной с бревно. Цепь не перепилена — разорвана."],
		["sign_ogre_print", "След босой ноги длиной в два шага, вдавленный в камень."],
	],
	"boss_mother": [
		["sign_mother_eggs", "Кладка икры светится бирюзой. Кто-то очень большой готовит потомство."],
		["sign_mother_skin", "Сброшенная жабья кожа — в неё поместилась бы телега."],
		["sign_mother_tracks", "Следы-перепонки размером с бочку уходят к дальней воде."],
	],
}


# Знак босса для боя на точке n: [модель, подсказка] или [] — если знака нет
func boss_sign_for(n: MapNode) -> Array:
	if n == null or run_boss == null or n.row > BOSS_SIGN_ROWS:
		return []
	if n.type != MapNode.Type.BATTLE and n.type != MapNode.Type.LAIR:
		return []
	var signs: Array = BOSS_SIGNS.get(run_boss.id, [])
	if signs.is_empty():
		return []
	# Один и тот же знак при повторном входе: выбор зависит от сида и точки, а не от общего генератора
	var pick: int = absi(hash([seed_value, n.row, n.col])) % signs.size()
	return signs[pick]


func _encounter_arena(is_boss: bool) -> String:
	if pending_encounter != null and pending_encounter.arena != "":
		return pending_encounter.arena
	if current != null and current.arena != "" and not is_boss:
		return current.arena   # арена, показанная на карточке точки
	return pick_arena(is_boss)


# Выбирает арену для боя: у босса своя, обычные не повторяются два раза подряд
func pick_arena(is_boss: bool) -> String:
	if is_boss:
		return boss_arena()
	# Арены по ветке карты (у каждого акта свои; в акте 1 справа — лесные, слева — болотные)
	var pool: Array[String] = arena_pool(current_branch())
	var options: Array[String] = pool.duplicate()
	options.erase(_last_arena)
	_last_arena = options[rng.randi_range(0, options.size() - 1)]
	return _last_arena


func _generate_map() -> void:
	# Тропы ветки: PATHS_PER_BRANCH троп снизу вверх, каждая шагает влево, вправо или прямо;
	# точки — там, где прошли тропы. Пересекаться внутри ветки тропам нельзя. Пробуем, пока в каждом
	# ряду ветки не окажется 2–4 точки (обычно с первой-второй попытки).
	for attempt in 40:
		map.clear()
		var ok: bool = true
		for branch in [MapNode.BOG, MapNode.FOREST]:
			if not _generate_branch(branch):
				ok = false
		if ok:
			break
	# Общий привал и босс
	for row in [MAP_ROWS - 2, MAP_ROWS - 1]:
		var n := MapNode.new()
		n.row = row
		n.col = 0
		n.branch = MapNode.COMMON
		n.type = _roll_node_type(row)
		n.pos = Vector2(0.49, 0.235) if row == MAP_ROWS - 2 else Vector2(0.43, 0.105)
		map.append(n)
	for n in row_nodes(MAP_ROWS - 3):
		n.next.append(0)   # все дороги сходятся на привале
	row_nodes(MAP_ROWS - 2)[0].next.append(0)   # с привала — к боссу
	_place_crossing()
	for branch in [MapNode.BOG, MapNode.FOREST]:
		_place_lair(branch)
	_place_positions()
	_assign_arenas()


# Арены боёв — заранее, при создании карты: их видно на карточке точки. Своя ветка; по возможности
# не та же, что у точки, из которой сюда ведёт дорожка. У элиты и босса — арена их отряда, если есть.
func _assign_arenas() -> void:
	if run_boss == null:
		_pick_act_bosses()
	for row in MAP_ROWS:
		for n in row_nodes(row):
			match n.type:
				MapNode.Type.BOSS:
					n.arena = boss_arena()
				MapNode.Type.ELITE:
					var enc: EncounterData = elite_for_row(row, n.branch)
					n.arena = enc.arena if enc.arena != "" else _arena_for(n)
				MapNode.Type.BATTLE, MapNode.Type.LAIR:
					n.arena = _arena_for(n)


func _arena_for(n: MapNode) -> String:
	var pool: Array[String] = arena_pool(n.branch)
	var options: Array[String] = pool.duplicate()
	for prev in row_nodes(n.row - 1):
		if prev.next.has(n.col):
			options.erase(prev.arena)
	if options.is_empty():
		options = pool.duplicate()
	return options[rng.randi_range(0, options.size() - 1)]


# Одна ветка: тропы по дорожкам-колонкам своей ветки. false — если в каком-то ряду меньше 2 точек.
func _generate_branch(branch: int) -> bool:
	var rows: int = MAP_ROWS - 2   # ряды ветки: 0 … MAP_ROWS - 3
	var first: int = branch * BRANCH_COLS
	var edges: Dictionary = {}     # ряд → массив пар [откуда, куда] (дорожки-колонки)
	var used: Dictionary = {}      # Vector2i(ряд, колонка) → true
	var starts: Array[int] = []
	for p in PATHS_PER_BRANCH:
		var lane: int = rng.randi_range(0, BRANCH_COLS - 1)
		if p < 2:   # первые две тропы начинаются в разных местах — развилка с первого шага
			while starts.has(lane):
				lane = rng.randi_range(0, BRANCH_COLS - 1)
		starts.append(lane)
		used[Vector2i(0, lane)] = true
		for row in rows - 1:
			var moves: Array[int] = [-1, 0, 1]
			var chosen: int = lane
			var tried: int = 0
			while not moves.is_empty():
				var m: int = moves.pop_at(rng.randi_range(0, moves.size() - 1))
				var to: int = lane + m
				tried += 1
				if to < 0 or to >= BRANCH_COLS or _crosses(edges.get(row, []), lane, to):
					continue
				chosen = to
				break
			if _crosses(edges.get(row, []), lane, chosen):
				chosen = lane   # прямо вверх не пересекает ничего, кроме такой же прямой
			var list: Array = edges.get(row, [])
			if not list.has([lane, chosen]):
				list.append([lane, chosen])
			edges[row] = list
			lane = chosen
			used[Vector2i(row + 1, lane)] = true
	for row in rows:
		var count: int = 0
		for lane in BRANCH_COLS:
			if used.has(Vector2i(row, lane)):
				count += 1
		if count < 2:
			return false
	for row in rows:
		for lane in BRANCH_COLS:
			if not used.has(Vector2i(row, lane)):
				continue
			var n := MapNode.new()
			n.row = row
			n.col = first + lane
			n.branch = branch
			n.type = _roll_node_type(row)
			for e: Array in edges.get(row, []):
				if e[0] == lane:
					n.next.append(first + int(e[1]))
			map.append(n)
	return true


# Пересекает ли дорожка a→b уже проложенные в этом ряду (крест-накрест)
func _crosses(list: Array, a: int, b: int) -> bool:
	for e: Array in list:
		var c: int = e[0]
		var d: int = e[1]
		if (a < c and b > d) or (a > c and b < d):
			return true
	return false


# Место точки на рисунке карты: Болота — левая половина, Лес — правая, ряды снизу вверх;
# лёгкий сдвиг от сида, чтобы карта не выглядела сеткой
func _place_positions() -> void:
	for n in map:
		if n.branch == MapNode.COMMON:
			continue
		var lane: int = n.col - n.branch * BRANCH_COLS
		var x0: float = 0.085 if n.branch == MapNode.BOG else 0.585
		var x: float = x0 + lane * 0.11 + rng.randf_range(-0.028, 0.028)
		var y: float = 0.895 - n.row * 0.104 + rng.randf_range(-0.02, 0.02)
		n.pos = Vector2(x, y)


# Видно ли, что за точка (туман): на FOG_SIGHT рядов вперёд от текущей (+ fog_bonus), пройденные — всегда.
# До первого шага видны ряды 0 … FOG_SIGHT - 1.
func node_revealed(n: MapNode) -> bool:
	if n.visited:
		return true
	var here: int = current.row if current != null else -1
	return n.row <= here + FOG_SIGHT + fog_bonus


# Колонка → ветка
func branch_of_col(col: int) -> int:
	return MapNode.BOG if col < BRANCH_COLS else MapNode.FOREST


# Ветка, по которой сейчас идёт отряд (на общем привале и у босса — та, откуда пришли)
func current_branch() -> int:
	if current == null:
		return MapNode.COMMON
	if current.branch != MapNode.COMMON:
		return current.branch
	for row in range(current.row - 1, -1, -1):
		for n in row_nodes(row):
			if n.visited and n.branch != MapNode.COMMON:
				return n.branch
	return MapNode.COMMON


# Тропа-переход через мост: с ряда CROSS_ROW — от самой правой точки Болот к самой левой точке Леса
# на ряд выше и наоборот (крест-накрест, это и есть мост). Сменить ветку можно только здесь.
func _place_crossing() -> void:
	var bog_inner: MapNode = _edge_node(CROSS_ROW, MapNode.BOG, true)
	var forest_inner: MapNode = _edge_node(CROSS_ROW, MapNode.FOREST, false)
	var bog_up: MapNode = _edge_node(CROSS_ROW + 1, MapNode.BOG, true)
	var forest_up: MapNode = _edge_node(CROSS_ROW + 1, MapNode.FOREST, false)
	if bog_inner == null or forest_inner == null or bog_up == null or forest_up == null:
		return
	bog_inner.next.append(forest_up.col)
	forest_inner.next.append(bog_up.col)


# Крайняя точка ветки в ряду: inner_right — самая правая (для Болот это край у оврага), иначе самая левая
func _edge_node(row: int, branch: int, rightmost: bool) -> MapNode:
	var best: MapNode = null
	for n in row_nodes(row):
		if n.branch != branch:
			continue
		if best == null or (n.col > best.col if rightmost else n.col < best.col):
			best = n
	return best


# Логово духа: одна точка в ряду LAIR_ROW в каждой ветке (обычный бой рядом всегда есть — в ряду 2+ точки)
func _place_lair(branch: int) -> void:
	var options: Array[MapNode] = []
	for n in row_nodes(LAIR_ROW):
		if n.branch == branch:
			options.append(n)
	if not options.is_empty():
		options[rng.randi_range(0, options.size() - 1)].type = MapNode.Type.LAIR


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
	if row == 1:   # сразу после старта — бой или событие: привал и лавка рано не нужны
		return MapNode.Type.BATTLE if roll < 0.65 else MapNode.Type.EVENT
	if roll < 0.5:
		return MapNode.Type.BATTLE
	if roll < 0.7:
		return MapNode.Type.EVENT
	if roll < 0.85:
		return MapNode.Type.SHOP
	return MapNode.Type.REST


# Элиты и босс этого забега — один раз, в начале (через общий генератор забега).
# У каждой ветки своя элита перед привалом (общие, как Певчая, годятся обеим); одна элита не попадёт
# в обе ветки, пока хватает кандидатов.
func _pick_act_bosses() -> void:
	run_elites.clear()
	var taken: Array[String] = []
	for branch in [MapNode.BOG, MapNode.FOREST]:
		var pool: Array[EncounterData] = []
		for enc in elite_pool():
			if enc.fits_branch(branch) and not taken.has(enc.id):
				pool.append(enc)
		for i in ELITES_PER_RUN:
			if pool.is_empty():   # кандидатов мало — берём из своей ветки повторно
				for enc in elite_pool():
					if enc.fits_branch(branch):
						pool.append(enc)
			var picked: EncounterData = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			run_elites.append(picked)
			taken.append(picked.id)
	_pick_branch_bosses()


# Босс каждой ветки: свой или общий (EncounterData.branch: ANY — общий, BOG/FOREST — только своей ветки)
func _pick_branch_bosses() -> void:
	var bosses: Array[EncounterData] = boss_pool()
	var common: Array[EncounterData] = bosses.filter(func(e: EncounterData) -> bool: return e.branch == EncounterData.Branch.ANY)
	var own: Dictionary[int, Array] = {MapNode.BOG: [], MapNode.FOREST: []}
	for enc in bosses:
		if enc.branch == EncounterData.Branch.BOG:
			own[MapNode.BOG].append(enc)
		elif enc.branch == EncounterData.Branch.FOREST:
			own[MapNode.FOREST].append(enc)
	branch_bosses.clear()
	var no_own: bool = own[MapNode.BOG].is_empty() and own[MapNode.FOREST].is_empty()
	if not common.is_empty() and (no_own or rng.randf() < BOSS_SHARED_CHANCE):
		var shared: EncounterData = common[rng.randi_range(0, common.size() - 1)]   # общий босс у обеих веток
		branch_bosses[MapNode.BOG] = shared
		branch_bosses[MapNode.FOREST] = shared
	else:
		for branch: int in [MapNode.BOG, MapNode.FOREST]:
			var pool: Array = own[branch] if not own[branch].is_empty() else (common if not common.is_empty() else bosses)
			branch_bosses[branch] = pool[rng.randi_range(0, pool.size() - 1)]
	run_boss = branch_bosses[MapNode.BOG]


# Сменить босса акта (переход на другую ветку): арена точки босса — его
func _set_boss(enc: EncounterData) -> void:
	if enc == run_boss:
		return
	run_boss = enc
	for m: MapNode in map:
		if m.type == MapNode.Type.BOSS:
			m.arena = boss_arena()


# Босс, который ждёт в конце этой ветки
func boss_for_branch(branch: int) -> EncounterData:
	return branch_bosses.get(branch, run_boss)


# У веток разные боссы (акт 2 без общего босса)
func bosses_differ() -> bool:
	return branch_bosses.get(MapNode.BOG) != branch_bosses.get(MapNode.FOREST)


# Элита ветки (ряд перед привалом). Ветка — текущая (вне карты считаем Болота).
func elite_for_row(_row: int, branch: int = -2) -> EncounterData:
	if run_elites.is_empty():
		_pick_act_bosses()
	if branch == -2:
		branch = current_branch()
	if branch == MapNode.COMMON:
		branch = MapNode.BOG
	if pending_event_elite != null:
		return pending_event_elite   # бой из события «Следы вожака»
	return run_elites[branch * ELITES_PER_RUN]


# Вторая элита забега (событие «Следы вожака»): своей ветки, не та, что ждёт перед привалом,
# и не встреченная. null — если такой нет.
func event_elite() -> EncounterData:
	var branch: int = current_branch()
	if branch == MapNode.COMMON:
		branch = MapNode.BOG
	var options: Array[EncounterData] = []
	for enc in elite_pool():
		if enc.fits_branch(branch) and not run_elites.has(enc) and not used_encounters.has(enc.id):
			options.append(enc)
	if options.is_empty():
		return null
	return options[rng.randi_range(0, options.size() - 1)]


# Бой элиты: точка-элита на карте или элита, которую позвало событие («Следы вожака»)
func is_elite_battle() -> bool:
	return pending_event_elite != null or (current != null and current.type == MapNode.Type.ELITE)


# Бой прямо из события: элита (elite = true, отряд — event_elite()) или обычный отряд enc.
# После боя — обычная награда (у элиты — с реликвией) и обратно на карту.
func start_event_battle(enc: EncounterData, elite: bool) -> void:
	if elite:
		pending_event_elite = enc
		pending_enemies = _make_encounter(current.row if current != null else 1, false, true)
	else:
		forced_encounter = enc
		pending_enemies = _make_encounter(current.row if current != null else 1, false)
	pending_arena = enc.arena if enc.arena != "" else pick_arena(false)
	pending_objective = BattleLogic.Objective.KILL_ALL
	goto(BATTLE_SCENE)


# Обычный отряд по id (для боёв из событий)
func encounter_by_id(id: String) -> EncounterData:
	for enc in encounters():
		if enc.id == id:
			return enc
	for a: ActData in ACTS:   # событие может звать отряд другого акта
		for enc in a.encounters:
			if enc.id == id:
				return enc
	return null


# Хранители этого боя слабее (дар у дуба) и их меньше (отвели Саженца домой)
func _keeper_adjust(result: Array[EnemyData]) -> void:
	var has_keepers: bool = false
	for d in result:
		if d.vine_walker:
			has_keepers = true
	if not has_keepers:
		return
	if keepers_fewer > 0 and result.size() > 2:
		for i in range(result.size() - 1, 0, -1):
			if result[i].vine_walker:
				result.remove_at(i)
				keepers_fewer -= 1
				break
	if keepers_calm:
		for i in result.size():
			if result[i].vine_walker:
				result[i] = _calmer(result[i])


# Копия Хранителя с ударами на 1 слабее (общий файл не меняется)
func _calmer(d: EnemyData) -> EnemyData:
	var copy: EnemyData = d.duplicate() as EnemyData
	copy.damage = maxi(1, d.damage - 1)
	var cyc: Array[EnemyAttackData] = []
	for atk in d.cycle:
		var a: EnemyAttackData = atk.duplicate() as EnemyAttackData
		if a.damage > 0:
			a.damage = maxi(1, a.damage - 1)
		cyc.append(a)
	copy.cycle = cyc
	return copy


# Обычный отряд для ряда: своей ступени, своей ветки и ещё не встреченный в этом забеге
func _pick_encounter(row: int) -> EncounterData:
	if forced_encounter != null:
		return forced_encounter
	var branch: int = current_branch()
	var pool: Array[EncounterData] = encounters()
	var options: Array[EncounterData] = []
	for enc in pool:
		var arena_ok: bool = enc.arena == "" or current == null or current.arena == "" or enc.arena == current.arena
		if enc.fits_row(row) and enc.fits_branch(branch) and not used_encounters.has(enc.id) and arena_ok:
			options.append(enc)
	if options.is_empty():   # все отряды ступени и ветки уже были — можно повторить
		for enc in pool:
			if enc.fits_row(row) and enc.fits_branch(branch):
				options.append(enc)
	if options.is_empty():
		options = pool.duplicate()
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
	if enc.kind != EncounterData.Kind.BOSS:
		_keeper_adjust(result)
	for i in result.size():
		result[i] = _act_scaled(result[i])   # акт на чужих врагах — они крепче
	_apply_modifiers(result, row, enc.kind != EncounterData.Kind.NORMAL)
	return result


# Строй врагов в ближайшем бою (у логова, пещеры и боёв без отряда — свободный)
func pending_formation() -> BattleLogic.Formation:
	return pending_encounter.formation if pending_encounter != null else BattleLogic.Formation.FREE


# Звон 4: сколько врагов добавить в каждую волну подкрепления
func wave_extra() -> int:
	return 1 if bell >= WAVE_BELL else 0


# Сколько врагов в бою получают модификатор: ряды 0–1 — никто, 2–3 — один, 4+ — двое;
# элита и босс — один из свиты (сам главный — нет). Звон 2 — ещё один, с первого ряда.
func modifier_count(row: int, big: bool) -> int:
	var n: int = 1 if big else (2 if row >= MOD_MORE_FROM_ROW else (1 if row >= MOD_FROM_ROW else 0))
	if bell >= MOD_BELL:
		n += 1
	return n


# Выдаёт модификаторы: случайным подходящим врагам (не главному элиты или босса, не духу),
# каждому — случайный из подходящих ему. Враг получает свою копию данных, общий файл не меняется.
func _apply_modifiers(list: Array[EnemyData], row: int, big: bool) -> void:
	var mods: Array[EnemyModifier] = all_modifiers()
	var caller: bool = false   # есть ли в бою, кто зовёт (тогда годится «Отклик на зов»)
	for e in list:
		for atk in e.cycle:
			caller = caller or (atk.shape == EnemyData.Attack.AURA and (atk.ally_damage > 0 or atk.ally_block > 0))
	var slots: Array[int] = []
	for i in list.size():
		var e: EnemyData = list[i]
		if (big and i == 0) or e.is_boss or e.tamable or e.modifier != null:
			continue
		if not _mods_for(e, mods, caller).is_empty():
			slots.append(i)
	for k in modifier_count(row, big):
		if slots.is_empty():
			return
		var i: int = slots.pop_at(rng.randi_range(0, slots.size() - 1))
		var options: Array[EnemyModifier] = _mods_for(list[i], mods, caller)
		var copy: EnemyData = list[i].duplicate() as EnemyData
		copy.modifier = options[rng.randi_range(0, options.size() - 1)]
		list[i] = copy


func _mods_for(e: EnemyData, mods: Array[EnemyModifier], caller: bool) -> Array[EnemyModifier]:
	return mods.filter(func(m: EnemyModifier) -> bool: return m.fits(e) and (caller or not m.needs_caller))


# Все модификаторы (порядок постоянный — для повторяемости по сиду)
func all_modifiers() -> Array[EnemyModifier]:
	var result: Array[EnemyModifier] = []
	for id: String in MODIFIER_IDS:
		result.append(load(MODIFIERS_DIR + id + ".tres") as EnemyModifier)
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
	last_wounded.clear()
	for i in party.size():
		if hp_left[i] <= 0:
			add_wounds(party[i], wounds_per_fall)   # пал в бою — Рана в колоду
			if wounds_per_fall > 0:
				last_wounded.append(party[i].data.title)
	last_battle_big = false
	tamed_spirit = null
	if in_cave:
		in_cave = false
		offer_spirit(spirit_data("fire"))   # Жаровик сломлен: идёт к герою
		event_echoes += CAVE_ECHOES
		last_battle_big = true
	if current != null and current.type == MapNode.Type.LAIR:
		offer_spirit(pending_spirit)
		pending_spirit = null
	if is_elite_battle() and bog_spirit_offered() \
			and last_drowned >= BOG_SPIRIT_DROWNS:
		offer_spirit(spirit_data("bog"))   # уникальный дух: условие выполнено
	if is_elite_battle() and forest_spirit_offered() \
			and last_forest_burnt == 0:
		offer_spirit(spirit_data("forest"))   # Леший: Роща не горела — он идёт с отрядом
	if is_elite_battle():
		elite_kills += 1
		last_battle_big = true
	if current != null and current.type == MapNode.Type.BOSS:
		boss_kills += 1
		last_battle_big = true
		run_complete = act >= final_act
		if run_complete:
			_offer_trophy()   # финальный босс: трофей и итог забега
			return
		# Босс акта: золото и большая награда, потом трофей и переход в следующий акт (after_reward)
		act_cleared = true
		last_gold_reward = rng.randi_range(BOSS_GOLD.x, BOSS_GOLD.y)
		gold += last_gold_reward
		goto(REWARD_SCENE)
	else:
		last_gold_reward = rng.randi_range(12, 20)
		if pending_objective != BattleLogic.Objective.KILL_ALL:
			last_gold_reward += OBJECTIVE_GOLD   # за бой с особой целью
		pending_objective = BattleLogic.Objective.KILL_ALL
		last_gold_reward += gold_after_battle   # обещанное событием («Дым над топью»)
		gold_after_battle = 0
		gold += last_gold_reward
		goto(REWARD_SCENE)


# Трофей за босса: выбор 1 из 3 закрытых оберегов. Закрытых нет — +15 Отзвуков вместо него.
func _offer_trophy() -> void:
	var closed: Array[RelicData] = Meta.closed_charms()
	if closed.is_empty():
		trophy_echoes += Meta.TROPHY_FALLBACK_ECHOES   # за каждого босса без трофея
		after_trophy()
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
		"victory": victory, "seed": seed_value, "spirits": run_spirits.duplicate(),
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
	for c in rh.data.card_pool + spirit_reward_cards(rh):
		if locked.has(c.id):
			continue
		if c.is_rare and (no_rare or rng.randf() > 0.4):
			continue
		pool.append(c)
	for c in spirit_reward_cards(rh):
		weights[c.card_set] = maxf(weights.get(c.card_set, 1.0), SPIRIT_CARD_WEIGHT)
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


# ---------- Духи (тз-духи.md) ----------

func spirit_data(id: String) -> SpiritData:
	var path: String = SPIRIT_DIR + id + ".tres"
	return load(path) as SpiritData if ResourceLoader.exists(path) else null


# Есть ли дух у кого-то в отряде
func party_has_spirit(id: String) -> bool:
	for rh in party:
		for sp in rh.spirits:
			if sp.id == id:
				return true
	return false


# Дух сломлен и ждёт, к кому из героев пойти (экран награды). Святилище его запоминает.
func offer_spirit(sp: SpiritData) -> void:
	tamed_spirit = sp
	if sp != null:
		Meta.mark_spirit_seen(sp.id)


# Дух для логова: «Приманка» из хаба или случайный обычный, которого ещё нет в отряде (null — все уже есть)
func _roll_lair_spirit() -> SpiritData:
	var bait: String = Meta.bait_spirit()
	if bait != "" and SPIRIT_IDS.has(bait) and not party_has_spirit(bait):
		Meta.mark_spirit_seen(bait)
		return spirit_data(bait)
	var free: Array[SpiritData] = []
	for id in SPIRIT_IDS:
		var sp: SpiritData = spirit_data(id)
		if sp != null and not party_has_spirit(id):
			free.append(sp)
	if free.is_empty():
		return null
	var picked: SpiritData = free[rng.randi_range(0, free.size() - 1)]
	Meta.mark_spirit_seen(picked.id)
	return picked


# Может ли событие оказаться «Тлеющей расщелиной»: ряды 1–4, духа огня нет, раз за забег
func cave_possible() -> bool:
	var row: int = current.row if current != null else 0
	return act == 1 and not cave_seen and not party_has_spirit("fire") and spirit_data("fire") != null \
			and row >= CAVE_ROWS.x and row <= CAVE_ROWS.y


# Спуск в расщелину: сразу бой в пещере (Жаровик, 2 факельщика, 2 гоблина). Карта стоит на месте.
func enter_cave() -> void:
	in_cave = true
	pending_spirit = null
	pending_encounter = null
	pending_enemies.clear()
	pending_enemies.append(spirit_data("fire").enemy)
	for id: String in ["torch_goblin", "torch_goblin", "goblin", "goblin"]:
		pending_enemies.append(load("res://resources/enemies/%s.tres" % id) as EnemyData)
	pending_arena = "cave"
	pending_objective = BattleLogic.Objective.KILL_ALL
	Meta.mark_spirit_seen("fire")   # Святилище: «Говорят, под топью что-то горит»
	goto(BATTLE_SCENE)


# В этом элитном бою живёт Хозяин трясины (бой с корягачом, а духа ещё нет)
func bog_spirit_offered() -> bool:
	if party_has_spirit("bog") or pending_encounter == null:
		return false
	for e in pending_encounter.core:
		if e.id == "mossy_treant":
			return true
	return false


# В этом элитном бою живёт Леший (бой с Голосом Рощи, а Лешего ещё нет)
func forest_spirit_offered() -> bool:
	if party_has_spirit("forest") or pending_encounter == null:
		return false
	for e in pending_encounter.core:
		if e.id == "grove_voice":
			return true
	return false


# Отпустить духа: его карты и смешанные карты его пар уходят из колод
func release_spirit(rh: RunHero, sp: SpiritData) -> void:
	rh.spirits.erase(sp)
	for h in party:
		var keep: Array[CardData] = []
		for c in h.deck:
			if not c.spirit_ids.has(sp.id):
				keep.append(c)
		h.deck = keep


# Передать духа другому герою (на привале): его карты меняются на парные карты нового героя
func transfer_spirit(from: RunHero, to: RunHero, sp: SpiritData) -> bool:
	if from == to or not from.spirits.has(sp) or not can_take_spirit(to):
		return false
	from.spirits.erase(sp)
	to.spirits.append(sp)
	var target_cards: Array[CardData] = sp.cards_for(to.data.id)
	var keep: Array[CardData] = []
	for c in from.deck:
		var single: bool = c.spirit_ids.size() == 1 and c.spirit_ids[0] == sp.id and c.spirit_slot > 0
		if not single:
			keep.append(c)
			continue
		var twin: CardData = target_cards[c.spirit_slot - 1]
		if c.upgrade_level == 1:
			twin = twin.upgrade_1
		elif c.upgrade_level == 2:
			twin = twin.upgrade_2
		to.deck.append(twin)
	from.deck = keep
	return true


# Дух для события «Клетка Венца»: Грозовик или Вихорь, которого ещё нет в отряде
func cage_spirit() -> SpiritData:
	for id in ["storm", "wind"]:
		if not party_has_spirit(id):
			return spirit_data(id)
	return null


func can_take_spirit(rh: RunHero) -> bool:
	return rh.spirits.size() < SPIRIT_SLOTS


# Сколько карт дух даёт герою сразу: 3, а со «Старой уздой» — 4, если отряд уже покорял его раньше
func spirit_start_count(sp: SpiritData) -> int:
	var count: int = SPIRIT_START_CARDS
	if sp != null and known_spirits.has(sp.id):
		count += Meta.effect_total("spirit_start_cards")
	return count


# Дух приходит к герою: его первые карты сразу в колоду (обычно три)
func add_spirit(rh: RunHero, sp: SpiritData) -> bool:
	if sp == null or not can_take_spirit(rh) or party_has_spirit(sp.id):
		return false
	rh.spirits.append(sp)
	var cards: Array[CardData] = sp.cards_for(rh.data.id)
	for i in mini(spirit_start_count(sp), cards.size()):
		rh.deck.append(cards[i])
	if not run_spirits.has(sp.id):
		run_spirits.append(sp.id)
	Meta.record_spirit_tamed(sp.id)
	return true


# Карты духов, которые могут выпасть герою в награде: оставшиеся карты своих духов (обычно Д4–Д6) и смешанные открытых пар
func spirit_reward_cards(rh: RunHero) -> Array[CardData]:
	var result: Array[CardData] = []
	for sp in rh.spirits:
		var cards: Array[CardData] = sp.cards_for(rh.data.id)
		for i in range(spirit_start_count(sp), cards.size()):
			result.append(cards[i])
	for other in party:
		for sp in other.spirits:
			for c in sp.mixed_cards:
				if c.owner_hero != rh.data.id:
					continue
				var open: bool = true
				for sid in c.spirit_ids:
					open = open and party_has_spirit(sid)
				if open:
					result.append(c)
	return result


# ---------- Улучшения карт (тз-карты.md, раздел 4) ----------

# Можно ли улучшить карту: у неё есть ветки и она ещё не улучшена
static func can_upgrade(card: CardData) -> bool:
	return card != null and card.upgrade_level == 0 and card.upgrade_1 != null and card.upgrade_2 != null


# Номера карт колоды героя, которые можно улучшить
func upgradable(rh: RunHero) -> Array[int]:
	var result: Array[int] = []
	for i in rh.deck.size():
		if can_upgrade(rh.deck[i]):
			result.append(i)
	return result


# Случайные карты отряда для награды «Улучшение»: [{"hero": RunHero, "index": int}]
# Одинаковые карты одного героя предлагаются один раз.
func roll_upgrades(count: int) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for rh in party:
		var seen: Dictionary = {}
		for i in upgradable(rh):
			if seen.has(rh.deck[i].id):
				continue
			seen[rh.deck[i].id] = true
			all.append({"hero": rh, "index": i})
	var result: Array[Dictionary] = []
	while result.size() < count and not all.is_empty():
		result.append(all.pop_at(rng.randi_range(0, all.size() - 1)))
	return result


# Улучшить карту колоды: branch 1 — ветка I «Сила», 2 — ветка II «Приём»
func upgrade_card(rh: RunHero, index: int, branch: int) -> void:
	var card: CardData = rh.deck[index]
	if not can_upgrade(card):
		return
	rh.deck[index] = card.upgrade_1 if branch == 1 else card.upgrade_2


# Только редкие карты героя (награда за элиту)
func roll_rare_cards(rh: RunHero, count: int) -> Array[CardData]:
	var rares: Array[CardData] = []
	var locked: Dictionary = Meta.locked_card_ids()
	for c in rh.data.card_pool:
		if c.is_rare and not locked.has(c.id) and not rh.deck.has(c):
			rares.append(c)
	var result: Array[CardData] = []
	while result.size() < count and not rares.is_empty():
		result.append(rares.pop_at(rng.randi_range(0, rares.size() - 1)))
	return result


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


# Карта герою из события: из того же, из чего его награды (базовый пул + карты его духов).
# rare — только редкие ★ (закрытые в хабе не выпадают), иначе только обычные.
func event_card(rh: RunHero, rare: bool) -> CardData:
	if not rare:
		var normal: Array[CardData] = roll_cards(rh, 1, true)
		return normal[0] if not normal.is_empty() else null
	var locked: Dictionary = Meta.locked_card_ids()
	var rares: Array[CardData] = []
	for c in rh.data.card_pool + spirit_reward_cards(rh):
		if c.is_rare and not locked.has(c.id):
			rares.append(c)
	if rares.is_empty():
		return random_rare_card(rh.data)
	return rares[rng.randi_range(0, rares.size() - 1)]


# ---------- Раны ----------

# Рана в колоду: сыграть нельзя, только занимает место в руке. Не пишется в Запас Караульни.
func add_wounds(rh: RunHero, count: int) -> void:
	var wound: CardData = load(WOUND_CARD)
	for i in count:
		rh.deck.append(wound)


func wound_count(rh: RunHero) -> int:
	return rh.deck.filter(func(c: CardData) -> bool: return c.unplayable).size()


# «Перевязка» на привале: убирает все Раны героя (вместо отдыха)
func bandage(rh: RunHero) -> int:
	var n: int = wound_count(rh)
	rh.deck.assign(rh.deck.filter(func(c: CardData) -> bool: return not c.unplayable))
	return n


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
