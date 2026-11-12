class_name BattleLogic
extends RefCounted
# Вся логика боя: ходы, мана, колоды, карты, враги, клетки и объекты поля.
# Ничего не знает про 3D — только меняет числа и сообщает о событиях сигналами.
# Сцена боя (scripts/battle.gd) слушает сигналы и показывает анимации.
#
# Героев несколько (маг и рыцарь). У каждого свои колода, рука, мана и шаги.
# Игрок ходит ими в любом порядке, потом жмёт «Конец хода» — и ходят враги.
# Ход врагов можно заранее «проиграть» на копии боя — это прогноз (forecast_enemies).

signal unit_moved(unit: BattleUnit, path: Array[Vector2i])
signal unit_pushed(unit: BattleUnit, path: Array[Vector2i], bumped: bool)
signal unit_damaged(unit: BattleUnit, amount: int, state: Dictionary)
signal unit_died(unit: BattleUnit)
signal status_changed(unit: BattleUnit, state: Dictionary)   # блок, ярость, провокация
signal tile_changed(cell: Vector2i, tile: int)
signal object_changed(cell: Vector2i, old_kind: int, new_kind: int, dir: Vector2i)
signal object_moved(from: Vector2i, to: Vector2i)              # бочку откатили / перенесли
signal effect_cells(cells: Array[Vector2i], kind: String)    # вспышка: "explosion", "tree", "gas"
signal card_cast(caster: BattleUnit, card: CardData, cells: Array[Vector2i])
signal enemy_attacked(unit: BattleUnit, dir: Vector2i, cells: Array[Vector2i])
signal enemy_buffed(unit: BattleUnit, cells: Array[Vector2i])   # «зов»: враг усилил своих вокруг
signal reaction(cell: Vector2i, kind: String)   # реакция стихий: "steam", "freeze", "shatter", "lava", "crust"
signal message(text: String)
signal card_played(caster: BattleUnit, card: CardData, is_scrap: bool)   # для пассивок врагов и условий карт
signal overheated(hero: BattleUnit, stacks: int)   # в конце хода мана героя была в минусе

# Что лежит на клетке поля (стихия на поверхности — по ней можно ходить)
# SWAMP — проходимая трясина (вход отнимает шаг, проводит молнию); GAS — ядовитый газ (взрывается от огня)
enum Tile { NONE, FIRE, WATER, ICE, SWAMP, GAS }

# Объекты поля (Гнилые топи). Один объект на клетку.
enum Obj {
	NONE,
	BOG,     # трясина: не пройти; столкнул врага — он тонет; лёд её замораживает
	TREE,    # мёртвое дерево: преграда; удар или огонь — падает и бьёт линию из 3 клеток
	BARREL,  # бочка с болотным газом: преграда; удар или огонь — взрыв по клетке и 6 соседям и поджог
	PLANKS,  # гнилые мостки: проходимы, но ломаются в трясину, когда с них уходят
	REEDS,   # камыш: проходим, закрывает удары по линии, горит и поджигает соседний камыш
	ICE_BLOCK,  # ледяная глыба мага: преграда, тает от огня или сама через несколько ходов
	STAKES,     # частокол рыцаря: преграда; врезавшийся в него получает больше урона
	BRIDGE,     # крепкие мостки рыцаря поверх трясины: проходимы и не ломаются
	LAVA,       # лава: огонь на трясине. Стена на LAVA_TURNS раундов, потом снова трясина
	CRUST,      # корка: вода или лёд на лаве. Проходима, но ход на ней заканчивается; потом сухая земля
	RUNE,       # сторожевая руна рыцаря: проходима; взрывается, когда на неё наступил враг или по ней ударили
}

const LAVA_TURNS: int = 3        # сколько раундов держится лава
const LAVA_DAMAGE: int = 6       # урон тому, кого толкнули в лаву (и кто стоит в ней в конце раунда)
const CRUST_TURNS: int = 2       # сколько раундов держится корка

const HAND_SIZE: int = 5        # сколько карт каждый герой берёт в начале боя
const MAX_HAND: int = 7
const MAX_OVERHEAT: int = 2        # на сколько каждый герой может уйти в минус по мане (перегрев)
const OVERHEAT_MANA_PENALTY: int = 1   # при перегреве от 2: так меньше маны в следующий ход
const OVERHEAT_PENALTY_FROM: int = 2

# Как рука меняется между ходами:
#  DISCARD_ALL — старый режим: рука сбрасывается целиком, в начале хода берём 5
#  REFILL_5    — рука остаётся, после «Конец хода» добираем до 5 (минимум 1 карта)
#  PLUS_3      — рука остаётся, после «Конец хода» берём ещё 3
#  PLUS_2      — рука остаётся, после «Конец хода» берём ещё 2
#  KEEP_2      — рука сбрасывается, кроме отмеченных «удержать» (до KEEP_LIMIT карт), потом добираем TURN_DRAW (3)
# Чтобы сменить режим, поменяй значение DRAW_MODE ниже.
const DISCARDS_PER_TURN: int = 1   # сколько карт за ход герой может сбросить из руки

enum DrawMode { DISCARD_ALL, REFILL_5, PLUS_3, PLUS_2, KEEP_2 }
const DRAW_MODE: DrawMode = DrawMode.KEEP_2
const KEEP_LIMIT: int = 3          # сколько карт герой может удержать на следующий ход (режим KEEP_2)
const TURN_DRAW: int = 3           # сколько карт герой добирает в конце хода (режим KEEP_2); рука не больше MAX_HAND
const BUMP_DAMAGE: int = 4      # урон, если толкнутый врезался в препятствие
const STEAM_DAMAGE: int = 3        # урон от парового взрыва (огонь на луже)
const ICE_SHATTER_DAMAGE: int = 4  # урон от ледяных осколков (огонь на льду)
const HEAVY_IDS: Array[String] = ["ogre", "mossy_treant"]   # слишком массивны, чтобы вмёрзнуть в лёд
const FIRE_DAMAGE: int = 3      # урон от огня в конце раунда
const FIRE_DURATION: int = 3    # сколько раундов горит огонь
const TREE_DAMAGE: int = 7      # урон от упавшего дерева
const TREE_LENGTH: int = 3      # на сколько клеток падает дерево
const BARREL_DAMAGE: int = 6    # урон от взрыва бочки
const BOSS_BOG_DAMAGE: int = 8  # босс не тонет, но трясина его ранит
const HERO_BOG_DAMAGE: int = 4  # герой не тонет: трясина для него как стена с таким уроном
const STAKES_BUMP_DAMAGE: int = 6  # урон, если толкнули в частокол
const WET_SHOCK_BONUS: int = 3      # молния по мокрому юниту бьёт сильнее на столько
const WET_TURNS: int = 2            # сколько раундов юнит остаётся мокрым, выйдя из лужи
const INFLATION_MAX: int = 3        # стаков «Раздувания» до взрыва жабы
const INFLATION_DAMAGE: int = 12    # урон взрыва жабы
const INFLATION_POISON: int = 3     # яд от взрыва жабы
const SHAMAN_HEAL: int = 3          # «Поглощение магии»: лечение всех врагов за каждое Заклинание
const SHAMAN_BLOCK: int = 3         # …и блок самому шаману
const WOOD_ARMOR_DIVISOR: int = 2   # «Древесная броня» режет одиночную физическую атаку вдвое
const VULNERABLE_BONUS: int = 3     # «Уязвимость к магии»: +урон от следующего Заклинания
const RETAIN_MAX: int = 2           # сколько ходов карта копит бонус «Казни с выдержкой»
const AETHER_DAMAGE: int = 2        # «Перегрузка эфира»: +урон за каждую единицу перегрева
const GAS_DAMAGE: int = 3           # урон ядовитого газа тому, кто вошёл в него, протащен через него или стоит в нём в конце раунда
const GAS_POISON: int = 2           # сколько раундов яда даёт газ
const SWAMP_STEP_COST: int = 1      # вход в трясину (Swamp) отнимает столько шагов («Увяз»)
const POISON_DAMAGE: int = 2        # урон яда в конце раунда (мимо блока)
const POISON_TURNS: int = 3         # сколько раундов держится яд
const RUNE_HITS: int = 3            # на сколько ударов хватает руны на оружии рыцаря
const RUNE_TRAP_DAMAGE: int = 5     # урон сторожевой руны врагам на её клетке и четырёх соседних
const WATER_SHOCK_BONUS: int = WET_SHOCK_BONUS    # молния, попавшая в лужу, бьёт стоящих в луже на столько сильнее
const MAX_CHARGE: int = 5          # обычный предел заряда мага
const MAX_CHARGE_OVERLOAD: int = 10  # предел заряда после «Перегрузки»
const MAX_MOMENTUM: int = 5        # предел натиска рыцаря
const ICE_WALL_TURNS: int = 3      # сколько раундов стоит ледяная глыба
const BOG_MAW_TURNS: int = 2       # сколько раундов держится трясина «Пасти топей»
const OUTPOST_DAMAGE: int = 4      # урон «Заставы» врагу на подходе
const EXECUTE_DAMAGE: int = 12     # урон «Добивания» по раненой цели
const CHAIN_JUMPS: int = 2         # сколько раз перескакивает цепная молния
const CHAIN_RADIUS: int = 2        # на какое расстояние она перескакивает

# Покрытие клетки — только для вида (какую плиту рисовать), на правила не влияет
enum Ground {
	STONE,   # каменная плита
	MOSS,    # плита во мху
	MUD,     # грязь у воды и трясины
	PLANKS,  # деревянный настил (гать, помост заставы)
}

# Арены Гнилых топей: у каждой свой рисунок поля и своя тактика
const ARENAS: Dictionary[String, String] = {
	"gat": "Старая гать",           # полоса трясины поперёк поля и узкие переправы
	"grove": "Мёртвая роща",        # ряды сухих деревьев — цепочки падений
	"reeds": "Камышовая заводь",    # пруд в центре и стены камыша по бокам
	"camp": "Брошенная застава",    # частокол с воротами, помост и склад бочек
	"ruins": "Затопленные руины",   # колоннада и залитый водой пол — раздолье для молний
	"lair": "Логово огра",          # арена босса: открытый центр, трясина по краям
}
const ARENA_POOL: Array[String] = ["gat", "grove", "reeds", "camp", "ruins"]   # обычные бои
const BOSS_ARENA: String = "lair"
const MIN_ENEMY_CELLS: int = 12  # сколько свободных клеток оставить врагам в верхних рядах

const ENEMY_ROWS: int = 4        # враги появляются в стольких рядах…
const ENEMY_ROW_OFFSET: int = 1  # …начиная с этого ряда сверху (ряд 0 пустой: бой начинается ближе)
const HERO_ROWS: int = 3         # нижние ряды держим свободными для героев

# «Нет клетки». Раньше для этого брали (-1, -1), но в сотах у настоящих клеток
# бывают отрицательные координаты, поэтому нужен значок, которого на поле точно нет.
const NO_CELL: Vector2i = Vector2i(-9999, -9999)

var width: int = 12    # клеток в каждом ряду (ряды сдвинуты на пол-клетки, см. HexMath)
var height: int = 12   # рядов
var rng: RandomNumberGenerator   # общий генератор забега (из Run)

var _discards_left: Dictionary = {}   # герой -> сколько сбросов осталось в этот ход

var heroes: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var rocks: Dictionary[Vector2i, bool] = {}     # клетки с камнями (непроходимые, неразрушимые)
var objects: Dictionary[Vector2i, int] = {}    # клетка -> Obj
var tiles: Dictionary[Vector2i, int] = {}      # клетка -> Tile (огонь/вода/лёд)
var fire_timers: Dictionary[Vector2i, int] = {}  # сколько раундов ещё горит клетка
var obj_timers: Dictionary[Vector2i, int] = {}   # сколько раундов ещё простоит временный объект
var ground: Dictionary[Vector2i, int] = {}     # клетка -> Ground (вид плиты)
var arena_id: String = ""                      # какая арена (ключ из ARENAS)

var _cur_card: CardData = null     # карта, эффекты которой считаются сейчас (для пассивок врагов)
var _cur_attack: bool = false      # она считается «Атакой»
var _cur_spell: bool = false       # она считается «Заклинанием»
var _cur_straight: int = 0         # разгон героя по прямой перед этой картой
var _cur_moved: int = 0            # сколько клеток герой прошёл за ход до этой карты
var _cur_retain: int = 0           # сколько ходов эта карта лежала в руке
var _prev_owner: String = ""       # чья карта была сыграна перед этой
var _ignite_ok: bool = false       # «Токсичный розжиг»: цель стояла на болоте/газе или была отравлена
var _aether: bool = false          # «Перегрузка эфира» действует до конца хода
var ctx := TurnContext.new()       # что отряд сделал в этот ход
var _mana_penalty: Dictionary = {}  # номер героя -> штраф к мане на следующий ход (после сильного перегрева)
var turn: int = 0
var is_over: bool = false
var won: bool = false
var _next_id: int = 0
var _lightning_now: bool = false                    # урон текущей карты считается молнией (по мокрым +WET_SHOCK_BONUS)
var _hit_enemies: Array[BattleUnit] = []            # враги, которых задела текущая карта (для рун рыцаря)
var _shock_cells: Dictionary[Vector2i, bool] = {}   # клетки, где молния этой карты бьёт сильнее (лужа)


# ---------- Подготовка ----------

# Создаёт героев, врагов и всё поле. Ничего не показывает — только данные.
func setup(board_width: int, board_height: int, random: RandomNumberGenerator,
		party: Array[RunHero], enemy_list: Array[EnemyData], arena: String = "") -> void:
	arena_id = arena   # пусто — арена выберется случайно
	width = board_width
	height = board_height
	rng = random

	# Герои — рядом друг с другом во втором снизу ряду
	var start_x: int = floori(width / 2.0) - floori(party.size() / 2.0)
	for i in party.size():
		var rh: RunHero = party[i]
		var h := _new_unit(rh.data.title)
		h.is_hero = true
		h.hero_data = rh.data
		h.max_hp = rh.data.max_hp
		h.hp = rh.hp
		h.cell = _cell(start_x + i, height - 2)
		h.draw_pile = rh.deck.duplicate()
		_shuffle(h.draw_pile)
		heroes.append(h)

	_generate_field()

	# Враги — в верхних рядах, на свободных клетках
	for enemy_data: EnemyData in enemy_list:
		var c: Vector2i = _random_free_cell(ENEMY_ROW_OFFSET, _enemy_last_row())
		if c == NO_CELL:
			continue
		var e := _new_unit(enemy_data.title)
		e.data = enemy_data
		e.hp = enemy_data.max_hp
		e.max_hp = enemy_data.max_hp
		e.block = enemy_data.start_block
		e.cell = c
		enemies.append(e)


func _new_unit(title: String) -> BattleUnit:
	var u := BattleUnit.new()
	u.id = _next_id
	_next_id += 1
	u.title = title
	return u


# ---------- Арены ----------
# Поле не случайная россыпь, а «место»: у каждой арены свой рисунок и своя тактика.
# Внутри рисунка детали случайны (по сиду), поэтому одна и та же арена каждый раз чуть другая.

# Строит поле выбранной арены. Если оно вышло «запертым» — пробуем заново.
func _generate_field() -> void:
	if not ARENAS.has(arena_id):
		arena_id = ARENA_POOL[rng.randi_range(0, ARENA_POOL.size() - 1)]
	for attempt in 30:
		rocks.clear()
		objects.clear()
		tiles.clear()
		ground.clear()
		match arena_id:
			"gat": _arena_gat()
			"grove": _arena_grove()
			"reeds": _arena_reeds()
			"camp": _arena_camp()
			"ruins": _arena_ruins()
			_: _arena_lair()
		_sprinkle_swamp_gas()
		if _field_is_open() and _free_enemy_cells() >= MIN_ENEMY_CELLS:
			_paint_ground()
			return
	# Не получилось (почти невозможно) — чистое поле
	rocks.clear()
	objects.clear()
	tiles.clear()
	ground.clear()
	_paint_ground()


# Проходимая трясина и ядовитый газ: по пятну на каждой арене, кроме руин
func _sprinkle_swamp_gas() -> void:
	if arena_id == "ruins":
		return
	for pair: Array in [[Tile.SWAMP, 5], [Tile.GAS, 3]]:
		var kind: int = pair[0]
		for c in _grow_patch(pair[1], 3, 8):
			if is_inside(c) and not rocks.has(c) and object_at(c) == Obj.NONE and tile_at(c) == Tile.NONE:
				tiles[c] = kind


func arena_title() -> String:
	return ARENAS.get(arena_id, "")


# «Старая гать»: трясина делит поле пополам. Перейти можно по сухим проходам
# (бревенчатая гать) и по гнилым мосткам, которые выдержат только один переход.
# Тактика: держать переправы, взрывать бочки у входа, сталкивать врагов в трясину.
func _arena_gat() -> void:
	var gaps: Array[int] = [rng.randi_range(1, 3), rng.randi_range(8, 10)]
	if rng.randf() < 0.5:
		gaps.append(gaps[rng.randi_range(0, 1)] + 1)   # одна из переправ шире
	var plank_x: int = rng.randi_range(5, 6)
	var row: int = rng.randi_range(4, 5)
	for x in width:
		if x > 0 and rng.randf() < 0.35:
			row = clampi(row + (1 if rng.randf() < 0.5 else -1), 4, 6)   # берег извивается
		for dy in 2:
			var c := _cell(x, row + dy)
			if gaps.has(x):
				continue
			objects[c] = Obj.PLANKS if x == plank_x else Obj.BOG
		if gaps.has(x):
			for y in range(row - 2, row + 4):
				ground[_cell(x, y)] = Ground.PLANKS   # бревенчатая дорога через топь
			# Бочка у входа на переправу со стороны врагов
			if not gaps.has(x - 1) and rng.randf() < 0.8:
				var side: int = 1 if x < width / 2 else -1
				if gaps.has(x + side):
					side = -side
				_put(_cell(x + side, row - 1), Obj.BARREL)
	for i in 3:
		_place(1, 3, func(c: Vector2i) -> void: objects[c] = Obj.TREE)
	_place(7, 8, func(c: Vector2i) -> void: objects[c] = Obj.TREE)
	for c in _grow_patch(4, 7, 8):
		objects[c] = Obj.REEDS
	for c in _grow_patch(3, 1, 3):
		objects[c] = Obj.REEDS
	for i in 3:
		_place(2, 8, func(c: Vector2i) -> void: tiles[c] = Tile.WATER)
	for i in 2:
		_place(1, 8, func(c: Vector2i) -> void: rocks[c] = true)


# «Мёртвая роща»: сухие деревья стоят рядами в шахматном порядке.
# Тактика: ронять деревья на врагов и друг на друга, не стоять на линии падения.
func _arena_grove() -> void:
	var line: int = 0
	for gy: int in [2, 4, 6, 8]:
		for gx in 5:
			if rng.randf() < 0.6:
				_put(_cell(1 + gx * 2 + line % 2, gy), Obj.TREE)
		line += 1
	# Бочки — вплотную к деревьям: взрыв валит дерево
	var trees: Array[Vector2i] = _cells_with(Obj.TREE)
	for i in 3:
		if trees.is_empty():
			break
		var t: Vector2i = trees[rng.randi_range(0, trees.size() - 1)]
		_put(t + HexMath.DIRS[rng.randi_range(0, 5)], Obj.BARREL)
	for c in _grow_from(_cell(0, rng.randi_range(3, 6)), 4, 1, 8):
		objects[c] = Obj.REEDS
	for c in _grow_from(_cell(width - 1, rng.randi_range(3, 6)), 4, 1, 8):
		objects[c] = Obj.REEDS
	var bog: Array[Vector2i] = _grow_patch(3, 3, 7)
	for c in bog:
		objects[c] = Obj.BOG
	for i in 2:
		_place(1, 8, func(c: Vector2i) -> void: tiles[c] = Tile.WATER)
	for i in 2:
		_place(1, 8, func(c: Vector2i) -> void: rocks[c] = true)


# «Камышовая заводь»: в центре пруд с топким дном, по бокам — стены камыша.
# Тактика: камыш прячет от ударов по линии, но горит весь сразу; молния бьёт по всему пруду.
func _arena_reeds() -> void:
	var center := _cell(rng.randi_range(4, 7), rng.randi_range(4, 5))
	var pond: Array[Vector2i] = _grow_from(center, 11, 2, 7)
	for c in pond:
		tiles[c] = Tile.WATER
	# Топкое дно: середина пруда — трясина
	for i in mini(3, pond.size()):
		tiles.erase(pond[i])
		objects[pond[i]] = Obj.BOG
	for c in _grow_from(_cell(rng.randi_range(0, 1), rng.randi_range(3, 6)), 8, 1, 8):
		objects[c] = Obj.REEDS
	for c in _grow_from(_cell(width - 1 - rng.randi_range(0, 1), rng.randi_range(3, 6)), 8, 1, 8):
		objects[c] = Obj.REEDS
	for c in _grow_from(_cell(rng.randi_range(3, 8), 8), 4, 7, 8):
		objects[c] = Obj.REEDS
	# Бочки у самого камыша: один взрыв — и горит вся заросль
	var reeds: Array[Vector2i] = _cells_with(Obj.REEDS)
	for i in 2:
		if reeds.is_empty():
			break
		var r: Vector2i = reeds[rng.randi_range(0, reeds.size() - 1)]
		_put(r + HexMath.DIRS[rng.randi_range(0, 5)], Obj.BARREL)
	for i in 2:
		_place(1, 8, func(c: Vector2i) -> void: objects[c] = Obj.TREE)
	for i in 2:
		_place(1, 8, func(c: Vector2i) -> void: rocks[c] = true)


# «Брошенная застава»: старый частокол Стражи с двумя воротами, за ним помост и склад бочек.
# Тактика: держать ворота, толкать врагов на колья; огонь сжигает частокол и добирается до бочек.
func _arena_camp() -> void:
	var wall_row: int = 4
	var gates: Array[int] = [rng.randi_range(3, 4), rng.randi_range(7, 8)]
	for x in range(2, width - 2):
		if not gates.has(x) and rng.randf() < 0.92:   # кое-где колья уже сгнили
			objects[_cell(x, wall_row)] = Obj.STAKES
	for y in range(wall_row + 1, wall_row + 3):
		if rng.randf() < 0.8:
			objects[_cell(2, y)] = Obj.STAKES
		if rng.randf() < 0.8:
			objects[_cell(width - 3, y)] = Obj.STAKES
	for x in range(3, width - 3):
		for y in range(wall_row + 1, height - HERO_ROWS):
			ground[_cell(x, y)] = Ground.PLANKS   # помост внутри заставы
	for g in gates:
		ground[_cell(g, wall_row)] = Ground.PLANKS
	# Склад: бочки кучкой внутри, ящики у стен
	var store := _cell(rng.randi_range(4, 7), rng.randi_range(6, 7))
	_put(store, Obj.BARREL)
	_put(store + Vector2i(1 if rng.randf() < 0.5 else -1, 0), Obj.BARREL)
	_put(store + Vector2i(0, -1), Obj.BARREL)
	_put_rock(_cell(3, wall_row + 1))
	_put_rock(_cell(width - 4, wall_row + rng.randi_range(1, 2)))
	# Снаружи: бочка у ворот, ров-трясина сбоку, пара деревьев
	_put(_cell(gates[rng.randi_range(0, 1)] + 1, wall_row - 1), Obj.BARREL)
	var side_x: int = 0 if rng.randf() < 0.5 else width - 1
	for c in _grow_from(_cell(side_x, rng.randi_range(4, 6)), 4, 3, 8):
		objects[c] = Obj.BOG
	for i in 2:
		_place(1, 3, func(c: Vector2i) -> void: objects[c] = Obj.TREE)
	for i in 2:
		_place(1, 3, func(c: Vector2i) -> void: tiles[c] = Tile.WATER)


# «Затопленные руины»: остатки колоннады, пол залит водой.
# Тактика: колонны закрывают от ударов по линии, а молния по воде достаёт сразу многих.
func _arena_ruins() -> void:
	for y: int in [2, 5, 8]:
		for x: int in [2, width - 3]:
			if rng.randf() < 0.8:
				rocks[_cell(x, y)] = true
	for y: int in [3, 6]:
		for x: int in [4, width - 5]:
			if rng.randf() < 0.6:
				rocks[_cell(x, y)] = true
	for i in 3:
		var start: Vector2i = _random_free_cell(2, 7)
		for c in _grow_from(start, rng.randi_range(5, 7), 1, 8):
			tiles[c] = Tile.WATER
	for c in _grow_from(_cell(0, rng.randi_range(4, 6)), 3, 3, 8):
		objects[c] = Obj.BOG
	for c in _grow_from(_cell(width - 1, rng.randi_range(4, 6)), 3, 3, 8):
		objects[c] = Obj.BOG
	for i in 2:
		_place(1, 8, func(c: Vector2i) -> void: objects[c] = Obj.BARREL)
	_place(1, 8, func(c: Vector2i) -> void: objects[c] = Obj.TREE)
	for c in _grow_patch(3, 1, 8):
		objects[c] = Obj.REEDS


# «Логово огра» (босс): открытый центр, по краям — ямы трясины, по углам — деревья.
# Тактика: огр в трясине не тонет, но получает большой урон; деревья и бочки — по одному разу.
func _arena_lair() -> void:
	for side_x: int in [0, width - 1]:
		for c in _grow_from(_cell(side_x, rng.randi_range(3, 6)), 4, 2, 8):
			objects[c] = Obj.BOG
	for c: Vector2i in [_cell(3, 3), _cell(width - 4, 3), _cell(3, 7), _cell(width - 4, 7)]:
		_put(c + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1)), Obj.TREE)
	for i in 3:
		_put(_cell(rng.randi_range(3, width - 4), rng.randi_range(4, 7)), Obj.BARREL)
	for i in 3:
		_place(1, 8, func(c: Vector2i) -> void: rocks[c] = true)
	for i in 3:
		_place(2, 8, func(c: Vector2i) -> void: tiles[c] = Tile.WATER)


# Ставит объект, только если клетка пустая и не в рядах героев
func _put(c: Vector2i, kind: int) -> bool:
	if not _is_empty(c) or c.y > height - HERO_ROWS - 1:
		return false
	objects[c] = kind
	return true


func _put_rock(c: Vector2i) -> bool:
	if not _is_empty(c) or c.y > height - HERO_ROWS - 1:
		return false
	rocks[c] = true
	return true


# Все клетки с объектом такого вида
func _cells_with(kind: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for c: Vector2i in objects:
		if objects[c] == kind:
			cells.append(c)
	return cells


# Сколько свободных клеток осталось врагам в верхних рядах
func _free_enemy_cells() -> int:
	var n: int = 0
	for y in range(ENEMY_ROW_OFFSET, _enemy_last_row() + 1):
		for x in width:
			if _is_empty(_cell(x, y)):
				n += 1
	return n


# Последний ряд, где могут появиться враги. На «Старой гати» они стоят до полосы трясины,
# а не на переправах и не за ней.
func _enemy_last_row() -> int:
	var last: int = ENEMY_ROW_OFFSET + ENEMY_ROWS - 1
	if arena_id == "gat":
		for c: Vector2i in objects:
			if objects[c] == Obj.BOG or objects[c] == Obj.PLANKS:
				last = mini(last, c.y - 1)
	return last


# Красит покрытие клеток: грязь у трясины, воды и камыша, мох под деревьями и местами
func _paint_ground() -> void:
	var moss_chance: float = 0.45 if arena_id == "grove" else (0.08 if arena_id == "ruins" else 0.22)
	for c: Vector2i in HexMath.rect_cells(width, height):
		var kind: int = ground.get(c, Ground.STONE)
		var roll: float = rng.randf()
		if kind == Ground.STONE and roll < moss_chance:
			kind = Ground.MOSS
		var o: int = object_at(c)
		if o == Obj.REEDS or tiles.has(c):
			kind = Ground.MUD
		elif o == Obj.TREE and kind != Ground.PLANKS:
			kind = Ground.MOSS
		elif kind != Ground.PLANKS:
			for d: Vector2i in HexMath.DIRS:
				if object_at(c + d) == Obj.BOG or object_at(c + d) == Obj.PLANKS:
					kind = Ground.MUD
		ground[c] = kind


# Ставит что-то на случайную пустую клетку
func _place(min_row: int, max_row: int, put: Callable) -> void:
	var c: Vector2i = _random_free_cell(min_row, max_row)
	if c != NO_CELL:
		put.call(c)


# Пятно из size соседних пустых клеток (растёт от случайной клетки в стороны)
func _grow_patch(size: int, min_row: int, max_row: int) -> Array[Vector2i]:
	return _grow_from(_random_free_cell(min_row, max_row), size, min_row, max_row)


# То же, но пятно растёт от заданной клетки
func _grow_from(start: Vector2i, size: int, min_row: int, max_row: int) -> Array[Vector2i]:
	var patch: Array[Vector2i] = []
	if not _is_empty(start) or start.y < min_row or start.y > max_row:
		return patch
	patch.append(start)
	for i in size * 5:
		if patch.size() >= size:
			break
		var from: Vector2i = patch[rng.randi_range(0, patch.size() - 1)]
		var c: Vector2i = from + HexMath.DIRS[rng.randi_range(0, 5)]
		if c.y >= min_row and c.y <= max_row and _is_empty(c) and not patch.has(c):
			patch.append(c)
	return patch


# Поле «открыто», если от героев можно дойти почти до всех проходимых клеток
func _field_is_open() -> bool:
	var walkable: int = 0
	for c: Vector2i in HexMath.rect_cells(width, height):
		if not _is_obstacle(c):
			walkable += 1
	var reached: Dictionary[Vector2i, bool] = {heroes[0].cell: true}
	var frontier: Array[Vector2i] = [heroes[0].cell]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		for d: Vector2i in HexMath.DIRS:
			var n: Vector2i = cur + d
			if is_inside(n) and not reached.has(n) and not _is_obstacle(n):
				reached[n] = true
				frontier.append(n)
	return reached.size() >= walkable * 0.95


# Начало боя: герои ходят первыми
func start() -> void:
	_start_heroes_turn()


# Текущее состояние юнита одним словарём — его кладём в сигналы,
# чтобы надпись над головой показала цифры именно на этот момент
func snapshot(u: BattleUnit) -> Dictionary:
	var state: Dictionary = {"hp": u.hp, "block": u.block, "rage": u.rage, "taunt": u.taunt,
			"charge": u.charge, "momentum": u.momentum, "entangled": u.entangled,
			"wet": wet_turns(u), "poison": u.poison, "rune": u.rune, "rune_hits": u.rune_hits}
	if u.data != null:
		# Что враг собирается сделать в этом раунде — для надписи над головой
		var atk: EnemyAttackData = enemy_attack(u)
		state["intent"] = atk.title
		state["damage"] = atk.damage + u.bonus_damage if atk.shape != EnemyData.Attack.AURA else 0
	return state


# ---------- Вопросы к полю ----------

# Клетка по номеру колонки (слева направо) и ряда (сверху вниз). Арены и расстановка
# думают «колонками», а в логике клетка — осевая пара (q, r), см. HexMath.
func _cell(column: int, row: int) -> Vector2i:
	return HexMath.from_column(column, row)


func is_inside(c: Vector2i) -> bool:
	return HexMath.in_rect(c, width, height)


func unit_at(c: Vector2i) -> BattleUnit:
	for h in heroes:
		if h.is_alive() and h.cell == c:
			return h
	for e in enemies:
		if e.is_alive() and e.cell == c:
			return e
	return null


func object_at(c: Vector2i) -> int:
	return objects.get(c, Obj.NONE)


# Преграда без учёта юнитов: край поля, камень, трясина, дерево, бочка
func _is_obstacle(c: Vector2i) -> bool:
	if not is_inside(c) or rocks.has(c):
		return true
	var o: int = object_at(c)
	return o == Obj.BOG or o == Obj.TREE or o == Obj.BARREL or o == Obj.ICE_BLOCK or o == Obj.STAKES or o == Obj.LAVA


# Клетка занята: преграда или кто-то стоит
func is_blocked(c: Vector2i) -> bool:
	return _is_obstacle(c) or unit_at(c) != null


# Топляк ходит по трясине, как по земле
func _walks_bog(u: BattleUnit) -> bool:
	return u != null and u.data != null and u.data.bog_walker


# Преграда для конкретного юнита: для топляка трясина — не преграда
func _is_obstacle_for(u: BattleUnit, c: Vector2i) -> bool:
	if _walks_bog(u) and is_inside(c) and not rocks.has(c) and object_at(c) == Obj.BOG:
		return false
	return _is_obstacle(c)


# Тонет ли юнит, если его столкнуть в трясину. Не тонут: герои, босс,
# «тяжёлые» враги (bog_damage > 0) и те, кто ходит по трясине.
func _sinks(u: BattleUnit) -> bool:
	return not u.is_hero and not u.data.is_boss and u.data.bog_damage <= 0 and not u.data.bog_walker


# Сколько урона получает тот, кто не тонет, когда его толкают в трясину
func _bog_damage(u: BattleUnit) -> int:
	if u.is_hero:
		return HERO_BOG_DAMAGE
	if u.data.bog_damage > 0:
		return u.data.bog_damage
	return BOSS_BOG_DAMAGE


# Можно ли разбить объект ударом (дерево, бочка)
func _is_breakable(c: Vector2i) -> bool:
	var o: int = object_at(c)
	return o == Obj.TREE or o == Obj.BARREL


# Что останавливает удар по линии: камень, дерево, бочка, камыш.
# Возвращает "stop" (дальше не летит, саму клетку не задевает),
# "hit" (задевает эту клетку и останавливается) или "" (летит дальше).
func _line_blocker(c: Vector2i) -> String:
	if not is_inside(c) or rocks.has(c):
		return "stop"
	var o: int = object_at(c)
	if o == Obj.TREE or o == Obj.BARREL:
		return "hit"
	if o == Obj.REEDS or o == Obj.ICE_BLOCK or o == Obj.STAKES:
		return "stop"   # камыш, лёд и частокол закрывают: кто за ними — того линия не достанет
	return ""


func _is_empty(c: Vector2i) -> bool:
	return is_inside(c) and not rocks.has(c) and not objects.has(c) and not tiles.has(c) and unit_at(c) == null


func tile_at(c: Vector2i) -> int:
	return tiles.get(c, Tile.NONE)


func living_enemies() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for e in enemies:
		if e.is_alive():
			result.append(e)
	return result


func living_heroes() -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for h in heroes:
		if h.is_alive():
			result.append(h)
	return result


# Клетки линии от from в направлении dir длиной до length с учётом преград.
# pierce = true — линия летит сквозь объекты (останавливают только камни и край поля).
func _line_cells(from: Vector2i, dir: Vector2i, length: int, pierce: bool = false) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(1, length + 1):
		var c: Vector2i = from + dir * i
		if pierce:
			if not is_inside(c) or rocks.has(c):
				break
			cells.append(c)
			continue
		var b: String = _line_blocker(c)
		if b == "stop":
			break
		cells.append(c)
		if b == "hit":
			break
	return cells


# Все клетки, куда юнит дойдёт за steps шагов, и путь до каждой.
# Поиск в ширину (BFS): сначала соседние клетки, потом их соседи и так далее,
# поэтому до каждой клетки находится самый короткий путь.
# ignore_heroes = true — считать клетки героев проходимыми (нужно для зоны
# угрозы: герои за ход сдвинутся, и враг сможет пройти).
func reachable_cells(unit: BattleUnit, steps: int, ignore_heroes: bool = false) -> Dictionary[Vector2i, Array]:
	var result: Dictionary[Vector2i, Array] = {}
	var start_path: Array[Vector2i] = [unit.cell]
	result[unit.cell] = start_path
	var frontier: Array[Vector2i] = [unit.cell]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var path: Array[Vector2i] = result[current]
		if path.size() - 1 >= steps:
			continue
		for d: Vector2i in HexMath.DIRS:
			var next: Vector2i = current + d
			if result.has(next):
				continue
			var blocker: BattleUnit = unit_at(next)
			if _is_obstacle_for(unit, next):
				continue
			if blocker != null and not (ignore_heroes and blocker.is_hero):
				continue
			var new_path: Array[Vector2i] = path.duplicate()
			new_path.append(next)
			result[next] = new_path
			if object_at(next) != Obj.CRUST:   # на корке ход заканчивается: дальше не идём
				frontier.append(next)
	return result


# Юнит прошёл по пути: мостки, с которых он ушёл, ломаются в трясину
func _break_planks_behind(path: Array[Vector2i]) -> void:
	for i in path.size() - 1:
		if object_at(path[i]) == Obj.PLANKS:
			_set_object(path[i], Obj.BOG, Vector2i.ZERO)
			message.emit("Мостки проваливаются в трясину")


# ---------- Ходьба героя ----------

func get_move_targets(h: BattleUnit) -> Dictionary[Vector2i, Array]:
	var result: Dictionary[Vector2i, Array] = {}
	if is_over or not h.is_alive():
		return result
	result = reachable_cells(h, h.moves_left)
	result.erase(h.cell)
	return result


func move_hero(h: BattleUnit, cell: Vector2i) -> bool:
	var targets := get_move_targets(h)
	if not targets.has(cell):
		return false
	var path: Array[Vector2i] = targets[cell]
	h.moves_left -= path.size() - 1
	if object_at(cell) == Obj.CRUST:
		h.moves_left = 0   # корка: шаги кончились
	h.cell = cell
	ctx.note_move(h.hero_data.id, path)
	unit_moved.emit(h, path)
	_break_planks_behind(path)
	_walked(h, path)
	_add_momentum(h, path.size() - 1)
	return true


# Натиск рыцаря: +1 за каждую пройденную клетку (шаги, таран), не больше MAX_MOMENTUM
func _add_momentum(h: BattleUnit, steps: int) -> void:
	if steps <= 0 or not h.is_hero or not h.hero_data.gains_momentum:
		return
	var before: int = h.momentum
	h.momentum = mini(MAX_MOMENTUM, h.momentum + steps)
	if h.momentum != before:
		status_changed.emit(h, snapshot(h))


# ---------- Карты ----------

func can_play(h: BattleUnit, index: int) -> bool:
	if is_over or not h.is_alive() or index < 0 or index >= h.hand.size():
		return false
	var card: CardData = h.hand[index]
	if card.special == "kick" and ctx.attacks(h.hero_data.id) >= 2:
		return false   # анти-спам: после двух Атак пинок недоступен
	if card.special == "vent" and h.mana >= 0:
		return false   # вентиляция только при перегреве
	return card_cost(h, index) <= h.mana + MAX_OVERHEAT


# Сколько маны реально стоит карта (с учётом скидки «Сосредоточения»)
func card_cost(h: BattleUnit, index: int) -> int:
	var card: CardData = h.hand[index]
	var cost: int = card.cost - h.discount
	match card.special:
		"steel_ring":
			# дешевле, если вокруг ≥ 2 врагов или Рыцарь стоит в трясине
			var around: int = 0
			for n in HexMath.neighbors(h.cell):
				var u: BattleUnit = unit_at(n)
				if u != null and not u.is_hero:
					around += 1
			if around >= 2 or tile_at(h.cell) == Tile.SWAMP:
				cost -= 1
		"patient":
			cost -= int(h.retain_turns.get(card, 0))
	return maxi(0, cost)


# Клетки, которые можно выбрать целью для карты из руки героя
func get_card_targets(h: BattleUnit, index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if index < 0 or index >= h.hand.size():
		return result
	var card: CardData = h.hand[index]
	var pierce: bool = card.special == "pierce"
	match card.shape:
		CardData.Shape.SELF, CardData.Shape.AROUND:
			result.append(h.cell)
		CardData.Shape.LINE:
			# Линия: любая клетка в одной из 6 сторон, до первой преграды
			for d: Vector2i in HexMath.DIRS:
				result.append_array(_line_cells(h.cell, d, card.cast_range, pierce))
		CardData.Shape.ARC:
			# Дуга: выбираем соседнюю клетку — в ту сторону и замах
			for d: Vector2i in HexMath.DIRS:
				if is_inside(h.cell + d):
					result.append(h.cell + d)
		CardData.Shape.CHARGE:
			for d: Vector2i in HexMath.DIRS:
				if card.special == "pass_through":
					result.append_array(_pass_lane(h, d, card.cast_range))
					continue
				# Таран: клетки разбега в каждую сторону и то, во что врежется
				var charge: Dictionary = _charge_plan(h, d, card.cast_range)
				var path: Array[Vector2i] = charge["path"]
				for i in range(1, path.size()):
					result.append(path[i])
				var hit_cell: Vector2i = charge["hit_cell"]
				if hit_cell != NO_CELL:
					result.append(hit_cell)
		CardData.Shape.ALLY:
			for other in living_heroes():
				if card.special == "swap" and other == h:
					continue
				if HexMath.distance(h.cell, other.cell) <= card.cast_range:
					result.append(other.cell)
		CardData.Shape.LEAP:
			# Прыжок: любая свободная проходимая клетка в пределах дальности, сквозь преграды
			for c: Vector2i in HexMath.rect_cells(width, height):
				var dist: int = HexMath.distance(h.cell, c)
				if dist >= 1 and dist <= card.cast_range and not is_blocked(c):
					result.append(c)
		CardData.Shape.FELL:
			# Клетки рядом с соседним деревом: в сторону выбранной клетки оно и упадёт
			for t: Vector2i in _adjacent_trees(h):
				for d: Vector2i in HexMath.DIRS:
					var c: Vector2i = t + d
					if c != h.cell and is_inside(c) and not result.has(c):
						result.append(c)
		_:
			for c: Vector2i in HexMath.rect_cells(width, height):
				var dist: int = HexMath.distance(h.cell, c)
				if dist >= 1 and dist <= card.cast_range:
					result.append(c)
	# Некоторым картам подходят только особые клетки (трясина, бочка, пустая земля…)
	if card.special != "":
		var filtered: Array[Vector2i] = []
		for c in result:
			if _special_target_ok(card.special, c):
				filtered.append(c)
		result = filtered
	return result


# Подходит ли клетка как цель для карты с особым действием
func _special_target_ok(special: String, c: Vector2i) -> bool:
	match special:
		"stakes", "rune_trap":
			return _can_build(c)
		"bridge":
			return object_at(c) == Obj.BOG
		"kick_barrel":
			return object_at(c) == Obj.BARREL
		"transfer":
			return object_at(c) == Obj.BARREL or (tile_at(c) != Tile.NONE and not _is_obstacle(c))
		"drain":
			var o: int = object_at(c)
			return o == Obj.BOG or o == Obj.PLANKS or o == Obj.BRIDGE or tile_at(c) == Tile.WATER
	return true


# Можно ли что-то поставить на клетку: внутри поля, без камня, объекта и юнита
func _can_build(c: Vector2i) -> bool:
	return is_inside(c) and not rocks.has(c) and not objects.has(c) and unit_at(c) == null


# Соседние с героем деревья
func _adjacent_trees(h: BattleUnit) -> Array[Vector2i]:
	var trees: Array[Vector2i] = []
	for d: Vector2i in HexMath.DIRS:
		if object_at(h.cell + d) == Obj.TREE:
			trees.append(h.cell + d)
	return trees


# Для «Свалить дерево»: какое дерево и в какую сторону упадёт, если выбрать клетку c
func _fell_choice(h: BattleUnit, c: Vector2i) -> Dictionary:
	for t: Vector2i in _adjacent_trees(h):
		if HexMath.distance(t, c) == 1 and c != h.cell:
			return {"tree": t, "dir": c - t}
	return {}


# Клетки сквозного тарана: по прямой сквозь врагов до первой преграды или союзника
func _pass_lane(h: BattleUnit, dir: Vector2i, length: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in range(1, length + 1):
		var c: Vector2i = h.cell + dir * i
		if _is_obstacle(c):
			break
		var u: BattleUnit = unit_at(c)
		if u != null and u.is_hero:
			break
		cells.append(c)
	return cells


# Клетки, по которым ударит карта, если выбрать цель target
func get_card_area(h: BattleUnit, index: int, target: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if index < 0 or index >= h.hand.size():
		return cells
	var card: CardData = h.hand[index]
	var d: Vector2i = HexMath.direction_to(h.cell, target)
	match card.shape:
		CardData.Shape.SELF:
			cells.append(h.cell)
		CardData.Shape.SINGLE, CardData.Shape.ALLY:
			cells.append(target)
		CardData.Shape.LINE:
			cells = _line_cells(h.cell, d, card.cast_range, card.special == "pierce")
		CardData.Shape.CROSS:
			cells = HexMath.cluster(target)
		CardData.Shape.SQUARE:
			cells = HexMath.cluster(target)   # в сотах «квадрат 3×3» — это центр и 6 соседей
		CardData.Shape.ARC:
			cells = HexMath.arc(h.cell, target)
		CardData.Shape.CHARGE:
			if card.special == "pass_through":
				cells = _pass_lane(h, d, card.cast_range)
			else:
				# Путь разбега плюс клетка, в которую врежется герой
				var charge: Dictionary = _charge_plan(h, d, card.cast_range)
				var path: Array[Vector2i] = charge["path"]
				for i in range(1, path.size()):
					cells.append(path[i])
				var hit_cell: Vector2i = charge["hit_cell"]
				if hit_cell != NO_CELL:
					cells.append(hit_cell)
		CardData.Shape.WALL:
			cells = HexMath.wall(target, d)
		CardData.Shape.LEAP:
			for n: Vector2i in HexMath.DIRS:
				cells.append(target + n)
		CardData.Shape.AROUND:
			cells = HexMath.neighbors(h.cell)   # все 6 клеток вокруг героя
		CardData.Shape.FELL:
			var choice: Dictionary = _fell_choice(h, target)
			if not choice.is_empty():
				for i in range(1, TREE_LENGTH + 1):
					cells.append((choice["tree"] as Vector2i) + (choice["dir"] as Vector2i) * i)
	var inside: Array[Vector2i] = []
	for c in cells:
		if is_inside(c):
			inside.append(c)
	return inside


func play_card(h: BattleUnit, index: int, target: Vector2i) -> bool:
	if not can_play(h, index):
		return false
	var card: CardData = h.hand[index]
	if card.shape != CardData.Shape.SELF and not get_card_targets(h, index).has(target):
		return false
	target = _intercept(card, target)
	var area: Array[Vector2i] = get_card_area(h, index, target)
	h.mana -= card_cost(h, index)
	h.discount = 0   # скидка действует на одну карту
	h.hand.remove_at(index)
	_forget_kept(h, index)
	if card.special != "slime":
		h.discard_pile.append(card)   # «Тина» сгорает навсегда, остальные идут в сброс
	message.emit("%s: %s" % [h.title, card.title])
	var as_spell: bool = is_spell_card(h, card)
	var as_attack: bool = is_attack_card(h, card)
	_cur_straight = ctx.straight(h.hero_data.id)
	_cur_moved = ctx.moved(h.hero_data.id)
	_prev_owner = ctx.last_card_owner
	_ignite_ok = card.special == "toxic_ignition" and _ignitable(target)
	_cur_retain = int(h.retain_turns.get(card, 0))
	h.retain_turns.erase(card)
	ctx.note_card(h.hero_data.id, as_attack, as_spell)
	card_played.emit(h, card, false)
	if as_spell:
		_absorb_magic()
	_cur_card = card
	_cur_attack = as_attack
	_cur_spell = as_spell
	_resolve_card(h, card, area, target)
	if as_spell and card.damage > 0 and card.special != "prism":
		_fire_prism(card)
	_cur_card = null
	_cur_attack = false
	_cur_spell = false
	_check_end()
	return true


# Теги карты. Пока не размечены в .tres: карты Мага — заклинания, карты Рыцаря с уроном — атаки.
func is_spell_card(h: BattleUnit, card: CardData) -> bool:
	return card.is_spell or h.hero_data.id == "mage"


func is_attack_card(h: BattleUnit, card: CardData) -> bool:
	return card.is_attack or (card.damage > 0 and h.hero_data.id == "knight")


# «Поглощение магии»: каждое сыгранное Заклинание лечит врагов и даёт шаману блок
func _absorb_magic() -> void:
	for e in living_enemies():
		if e.data.absorbs_magic:
			for o in living_enemies():
				o.hp = mini(o.max_hp, o.hp + SHAMAN_HEAL)
				status_changed.emit(o, snapshot(o))
			e.block += SHAMAN_BLOCK
			message.emit("%s поглощает магию: враги лечатся" % e.title)
			status_changed.emit(e, snapshot(e))
			return


# Сброс карты «в ноги»: бесплатно, даёт шаги/блок/ману, но не считается Атакой или Заклинанием,
# поэтому пассивки врагов на розыгрыш карт его не видят.
func scrap_card(h: BattleUnit, index: int) -> bool:
	if is_over or not h.is_alive() or index < 0 or index >= h.hand.size():
		return false
	var card: CardData = h.hand[index]
	h.hand.remove_at(index)
	_forget_kept(h, index)
	h.discard_pile.append(card)
	h.moves_left += card.scrap_moves
	if card.scrap_block > 0:
		h.block += card.scrap_block
	h.mana += card.scrap_mana
	message.emit("%s: «%s» в ноги" % [h.title, card.title])
	ctx.note_scrap(h.hero_data.id)
	card_played.emit(h, card, true)
	status_changed.emit(h, snapshot(h))
	return true


# Применяет эффекты карты по порядку:
# бонусы урона → движение (таран, прыжок) → урон и объекты → стихия → толчок →
# особые действия → защита и прочее → «Неудержимый»
func _resolve_card(h: BattleUnit, card: CardData, area: Array[Vector2i], target: Vector2i) -> void:
	var hit_cells: Array[Vector2i] = area
	_shock_cells.clear()
	_hit_enemies.clear()
	# Молния (или удар рыцаря с «Руной бури») бьёт по мокрым сильнее
	_lightning_now = card.element == CardData.Element.LIGHTNING \
			or (card.damage > 0 and h.rune == "storm" and h.rune_hits > 0)
	if card.element == CardData.Element.LIGHTNING:
		hit_cells = _spread_through_water(area)
	var dir: Vector2i = HexMath.direction_to(h.cell, target)
	var from: Vector2i = h.cell
	var alive_before: Array[BattleUnit] = living_enemies()

	# Ярость, заряд и натиск, накопленные до этой карты, усиливают её урон и сгорают
	var damage: int = card.damage
	if damage > 0:
		damage += _spend_bonuses(h, card)
		damage += _special_damage_bonus(h, card)

	# Цепная молния: заранее находим, куда она перескочит (чтобы показать вспышку)
	var chain: Array[BattleUnit] = []
	if card.special == "chain" and damage > 0:
		chain = _chain_targets(hit_cells)
		for u in chain:
			if not hit_cells.has(u.cell):
				hit_cells.append(u.cell)

	match card.shape:
		CardData.Shape.CHARGE:
			if card.special == "pass_through":
				_pass_through_charge(h, card, dir, damage, hit_cells)
			else:
				_charge_attack(h, card, dir, damage, hit_cells)
		CardData.Shape.LEAP:
			var path: Array[Vector2i] = [h.cell, target]
			h.cell = target
			unit_moved.emit(h, path)
			_break_planks_behind(path)
			_walked(h, [target])
			card_cast.emit(h, card, hit_cells)
			_hit_cells(card, damage, hit_cells, target)
		CardData.Shape.FELL:
			card_cast.emit(h, card, hit_cells)
			var choice: Dictionary = _fell_choice(h, target)
			if not choice.is_empty():
				_fell_tree(choice["tree"], choice["dir"])
		_:
			card_cast.emit(h, card, hit_cells)
			if card.special == "whirl_rage":
				for c in hit_cells:
					var u: BattleUnit = unit_at(c)
					if u != null and not u.is_hero:
						h.rage += 1
			if damage > 0:
				if card.special == "chain":
					_chain_damage(chain, damage, card.pierce_block)
				else:
					_hit_cells(card, damage, hit_cells, from)
					_shock_cells.clear()
			# Стихия меняет клетки (огонь поджигает объекты, лёд замораживает трясину)
			if card.element != CardData.Element.NONE and card.special != "flood":
				for c in hit_cells:
					_apply_element(c, card.element, from)
			# Толчок от героя: сначала самых дальних, чтобы они не мешали ближним
			if card.push > 0:
				var targets: Array[BattleUnit] = []
				for c in area:
					var u: BattleUnit = unit_at(c)
					if u != null and not u.is_hero:
						targets.append(u)
				targets.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
					return HexMath.distance(a.cell, from) > HexMath.distance(b.cell, from))
				for u in targets:
					if u.is_alive():
						_push(u, HexMath.direction_to(from, u.cell), card.push)
			# Ветер раздувает огонь: горящие клетки линии поджигают следующую по ветру
			if card.special == "gust":
				_fan_fire(area, dir, from)

	if card.special != "":
		_resolve_special(h, card, area, target, dir)
	_apply_weapon_rune(h, card, from)
	_lightning_now = false

	# Блок: на союзника (форма ALLY) или на себя
	if card.block > 0:
		var receiver: BattleUnit = h
		if card.shape == CardData.Shape.ALLY:
			var ally: BattleUnit = unit_at(target)
			if ally != null and ally.is_hero:
				receiver = ally
		var block: int = card.block
		if card.special == "hold":
			block += 3 * h.moves_left   # «Держать строй»: каждый неиспользованный шаг — ещё блок
		receiver.block += block
		status_changed.emit(receiver, snapshot(receiver))
	if card.taunt:
		h.taunt = true
		message.emit("%s вызывает врагов на себя" % h.title)
	if card.rage_gain > 0:
		h.rage += card.rage_gain
	if card.charge_gain > 0:
		h.charge = mini(maxi(MAX_CHARGE, h.charge), h.charge + card.charge_gain)
	if card.momentum_gain > 0:
		h.momentum = mini(MAX_MOMENTUM, h.momentum + card.momentum_gain)
	if card.bonus_moves > 0:
		h.moves_left += card.bonus_moves
	if card.draw > 0:
		_draw_cards(h, card.draw)
	status_changed.emit(h, snapshot(h))

	# «Неудержимый»: за каждое убийство этой картой — мана и шаги обратно
	if h.unstoppable:
		var kills: int = 0
		for e in alive_before:
			if not e.is_alive():
				kills += 1
		if kills > 0:
			h.mana += kills
			h.moves_left += 2 * kills
			message.emit("Неудержимый: +%d маны, +%d шагов" % [kills, 2 * kills])


# Урон по клеткам карты: врагам — урон, деревьям и бочкам — удар.
# «Добивание» бьёт сильнее по раненым, «пронзающие» карты объекты не ломают.
func _hit_cells(card: CardData, damage: int, cells: Array[Vector2i], from: Vector2i) -> void:
	if damage <= 0:
		return
	for c in cells:
		var u: BattleUnit = unit_at(c)
		if u != null and not u.is_hero:
			var dealt: int = damage
			if card.special == "execute" and u.hp * 2 <= u.max_hp:
				dealt = damage - card.damage + EXECUTE_DAMAGE
				message.emit("Добивание!")
			_card_damage(u, dealt, card.pierce_block)
		elif _is_breakable(c) and card.special != "pierce":
			_hit_object(c, from)
		if object_at(c) == Obj.RUNE and card.special != "pierce":
			_trigger_rune(c)   # удар по клетке подрывает сторожевую руну


# Тратит ярость, заряд и натиск на эту карту. Возвращает прибавку к урону.
func _spend_bonuses(h: BattleUnit, card: CardData) -> int:
	var bonus: int = 0
	if card.rage_bonus > 0 and h.rage > 0:
		bonus += h.rage * card.rage_bonus
		message.emit("Ярость: +%d урона" % (h.rage * card.rage_bonus))
		h.rage = 0
	if card.charge_bonus > 0 and h.charge > 0:
		bonus += h.charge * card.charge_bonus
		message.emit("Разрядка: +%d урона" % (h.charge * card.charge_bonus))
		h.charge = 0
		h.overloaded = false
	if h.hero_data.gains_momentum and h.momentum > 0:
		bonus += h.momentum
		message.emit("Натиск: +%d урона" % h.momentum)
		h.momentum = 0
	return bonus


# Обычный таран: герой бежит по прямой и бьёт то, во что врезался
func _charge_attack(h: BattleUnit, card: CardData, dir: Vector2i, damage: int, hit_cells: Array[Vector2i]) -> void:
	var charge: Dictionary = _charge_plan(h, dir, card.cast_range)
	var path: Array[Vector2i] = charge["path"]
	if path.size() > 1:
		h.cell = path[path.size() - 1]
		unit_moved.emit(h, path)
		_break_planks_behind(path)
		_walked(h, path)
	card_cast.emit(h, card, hit_cells)
	var hit_cell: Vector2i = charge["hit_cell"]
	var victim: BattleUnit = unit_at(hit_cell) if hit_cell != NO_CELL else null
	if victim != null and not victim.is_hero:
		_card_damage(victim, damage, card.pierce_block)
		if card.push > 0 and victim.is_alive():
			_push(victim, dir, card.push)
	elif hit_cell != NO_CELL and _is_breakable(hit_cell):
		_hit_object(hit_cell, h.cell)
	_add_momentum(h, path.size() - 1)


# Сквозной таран: герой бежит насквозь, каждого врага на пути ранит
# и откидывает на клетку в сторону. Не отлетел — герой останавливается перед ним.
func _pass_through_charge(h: BattleUnit, card: CardData, dir: Vector2i, damage: int, hit_cells: Array[Vector2i]) -> void:
	card_cast.emit(h, card, hit_cells)
	var path: Array[Vector2i] = [h.cell]
	# «Вбок» в сотах — на 120° от бега: так враг отлетает подальше от следующей клетки пробега
	var side: Vector2i = HexMath.rotate_dir(dir, 2)
	var other_side: Vector2i = HexMath.rotate_dir(dir, -2)
	for c in _pass_lane(h, dir, card.cast_range):
		var u: BattleUnit = unit_at(c)
		if u != null and not u.is_hero:
			_card_damage(u, damage, card.pierce_block)
			if u.is_alive():
				var push_dir: Vector2i = side if not is_blocked(c + side) else other_side
				_push(u, push_dir, 1)
			if u.is_alive() and u.cell == c:
				break   # враг не отлетел — дальше не пробежать
		path.append(c)
	if path.size() > 1:
		h.cell = path[path.size() - 1]
		unit_moved.emit(h, path)
		_break_planks_behind(path)
		_walked(h, path)
		_add_momentum(h, path.size() - 1)


# Цепная молния: от первой цели перескакивает на ближайших врагов (до CHAIN_JUMPS раз)
func _chain_targets(cells: Array[Vector2i]) -> Array[BattleUnit]:
	var chain: Array[BattleUnit] = []
	for c in cells:
		var u: BattleUnit = unit_at(c)
		if u != null and not u.is_hero:
			chain.append(u)
			break
	if chain.is_empty():
		return chain
	for j in CHAIN_JUMPS:
		var last: BattleUnit = chain[chain.size() - 1]
		var best: BattleUnit = null
		var best_dist: int = CHAIN_RADIUS + 1
		for e in living_enemies():
			var dist: int = HexMath.distance(last.cell, e.cell)
			if not chain.has(e) and dist <= CHAIN_RADIUS and dist < best_dist:
				best = e
				best_dist = dist
		if best == null:
			break
		chain.append(best)
	return chain


func _chain_damage(chain: Array[BattleUnit], damage: int, pierce: bool) -> void:
	for i in chain.size():
		_card_damage(chain[i], maxi(1, damage - i), pierce)   # каждый прыжок слабее на 1


# Особые действия карт (поле, объекты, состояния героя)
func _resolve_special(h: BattleUnit, card: CardData, area: Array[Vector2i], target: Vector2i, dir: Vector2i) -> void:
	match card.special:
		"focus":
			h.discount = 1
		"overload":
			h.charge = mini(MAX_CHARGE_OVERLOAD, h.charge * 2)
			h.overloaded = h.charge > 0
			message.emit("Перегрузка! Заряд: %d" % h.charge)
		"unstoppable":
			h.unstoppable = true
		"rune_fire", "rune_storm", "rune_rot":
			# Руна на оружие: одна активная, новая заменяет старую
			h.rune = card.special.trim_prefix("rune_")
			h.rune_hits = RUNE_HITS
			message.emit("%s: руна на клинке (%d удара)" % [h.title, RUNE_HITS])
		"rune_trap":
			if _can_build(target):
				_set_object(target, Obj.RUNE, Vector2i.ZERO)
		"outpost":
			h.outpost = true
			message.emit("%s держит заставу" % h.title)
		"ice_wall":
			for c in area:
				if _can_build(c) and object_at(c) == Obj.NONE:
					_set_tile(c, Tile.NONE)
					_set_object(c, Obj.ICE_BLOCK, Vector2i.ZERO)
					obj_timers[c] = ICE_WALL_TURNS
		"flood":
			# Где вода уже была — трясина; на остальных клетках появляются лужи
			for c in area:
				if not is_inside(c) or rocks.has(c):
					continue
				if tile_at(c) == Tile.WATER and object_at(c) == Obj.NONE and unit_at(c) == null:
					_set_tile(c, Tile.NONE)
					_set_object(c, Obj.BOG, Vector2i.ZERO)
				else:
					_apply_element(c, CardData.Element.WATER, h.cell)
		"drain":
			var o: int = object_at(target)
			if o == Obj.BOG or o == Obj.PLANKS or o == Obj.BRIDGE:
				obj_timers.erase(target)
				_set_object(target, Obj.NONE, Vector2i.ZERO)
			if tile_at(target) == Tile.WATER:
				_set_tile(target, Tile.NONE)
			var ally: BattleUnit = unit_at(target)
			if ally != null and ally.is_hero:
				ally.block += 4
				status_changed.emit(ally, snapshot(ally))
		"grow_reeds":
			for c in area:
				if is_inside(c) and not rocks.has(c) and object_at(c) == Obj.NONE and tile_at(c) != Tile.FIRE:
					_set_object(c, Obj.REEDS, Vector2i.ZERO)
		"transfer":
			var dest: Vector2i = target + dir
			if object_at(target) == Obj.BARREL:
				if is_inside(dest) and not is_blocked(dest) and object_at(dest) == Obj.NONE:
					_move_object(target, dest)
			elif tile_at(target) != Tile.NONE and is_inside(dest) and not _is_obstacle(dest):
				var tile: int = tile_at(target)
				var timer: int = fire_timers.get(target, FIRE_DURATION)
				_set_tile(target, Tile.NONE)
				_set_tile(dest, tile)
				if tile == Tile.FIRE:
					fire_timers[dest] = timer
		"axis_ram":
			# Осевая инерция: толкаем цель на столько клеток, сколько прошли перед ударом
			var victim: BattleUnit = unit_at(target)
			if victim != null and not victim.is_hero and victim.is_alive() and _cur_straight > 0:
				_push(victim, dir, _cur_straight)
		"crescent":
			# Прошёл ≥ 2 гексов — задетые враги уязвимы к магии
			if _cur_moved >= 2:
				for c in area:
					var v: BattleUnit = unit_at(c)
					if v != null and not v.is_hero and v.is_alive():
						v.vulnerable = VULNERABLE_BONUS
						status_changed.emit(v, snapshot(v))
		"harpoon":
			# Притягивает первого врага на линии к Рыцарю вплотную; болото и газ срабатывают по пути
			for c in area:
				var v2: BattleUnit = unit_at(c)
				if v2 != null and not v2.is_hero and v2.is_alive():
					var gap: int = HexMath.distance(h.cell, v2.cell) - 1
					if gap > 0:
						_push(v2, HexMath.direction_to(v2.cell, h.cell), gap)
					break
		"ricochet":
			# Рикошет: до 2 других врагов в 1–2 клетках от цели
			var first: BattleUnit = unit_at(target)
			var bounce: int = card.damage + h.block
			var jumped: int = 0
			for e in living_enemies():
				if jumped >= 2:
					break
				if e != first and first != null and HexMath.distance(e.cell, first.cell) <= 2:
					_card_damage(e, bounce, false)
					jumped += 1
		"kick":
			# Награда за геометрию: враг врезался (не пролетел 2 клетки) или влетел в газ — берём карту
			var kicked: BattleUnit = unit_at(target)
			var pushed_to: Vector2i = target + dir * 2
			if kicked != null and kicked.is_alive() and kicked.cell != pushed_to:
				_draw_cards(h, 1)
			elif kicked != null and tile_at(kicked.cell) == Tile.GAS:
				_draw_cards(h, 1)
		"slam":
			# Стяжка: враги внешнего кольца подтягиваются на 1 клетку к эпицентру
			for e in living_enemies():
				if HexMath.distance(e.cell, target) == 2:
					_push(e, HexMath.direction_to(e.cell, target), 1)
		"bastion":
			# Рядом с Магом (до 2 клеток): Маг получает половину блока, а Рыцарь до следующего хода
			# принимает на себя половину урона по Магу
			for other in living_heroes():
				if other != h and HexMath.distance(h.cell, other.cell) <= 2:
					other.block += card.block / 2
					h.guarding = true
					status_changed.emit(other, snapshot(other))
		"prism":
			var carrier: BattleUnit = unit_at(target)
			if carrier != null and carrier.is_hero:
				carrier.prism = true
				message.emit("%s несёт магическую призму" % carrier.title)
				status_changed.emit(carrier, snapshot(carrier))
		"toxic_ignition":
			if _ignite_ok:
				message.emit("Взрыв болота!")
				var boom: Array[Vector2i] = []
				for c in HexMath.cluster(target):
					if is_inside(c):
						boom.append(c)
				effect_cells.emit(boom, "explosion")
				for c in boom:
					var v3: BattleUnit = unit_at(c)
					if v3 != null and not v3.is_hero:
						_card_damage(v3, 8, false)
					if tile_at(c) == Tile.SWAMP or tile_at(c) == Tile.GAS:
						_set_tile(c, Tile.NONE)
		"arc":
			_arc_discharge(h, card, target)
		"gravity":
			for n in HexMath.neighbors(target):
				var v4: BattleUnit = unit_at(n)
				if v4 != null and not v4.is_hero and v4.is_alive():
					_push(v4, HexMath.direction_to(n, target), 1)
		"acid":
			# Луч: клетки становятся трясиной, враги на линии сдвигаются на 1 вдоль луча
			var resonance: bool = _prev_owner != "" and _prev_owner != h.hero_data.id
			for c in area:
				var v5: BattleUnit = unit_at(c)
				if v5 != null and not v5.is_hero and v5.is_alive():
					if resonance:
						_set_poison(v5, 2)
					_push(v5, dir, 1)
				if _can_build(c) and object_at(c) == Obj.NONE:
					_set_tile(c, Tile.SWAMP)
		"kinetic":
			# Маг разгоняет напарника: до 3 клеток по прямой от Мага; во враге — 6 урона вместо урона себе
			var buddy: BattleUnit = unit_at(target)
			if buddy != null and buddy != h and buddy.is_hero:
				var kdir: Vector2i = HexMath.direction_to(h.cell, buddy.cell)
				var cur: Vector2i = buddy.cell
				var kpath: Array[Vector2i] = [cur]
				for i in 3:
					var nxt: Vector2i = cur + kdir
					var blocker: BattleUnit = unit_at(nxt)
					if is_blocked(nxt) or blocker != null:
						if blocker != null and not blocker.is_hero:
							_card_damage(blocker, 6, false)
						break
					cur = nxt
					kpath.append(cur)
				if kpath.size() > 1:
					buddy.cell = cur
					unit_moved.emit(buddy, kpath)
					_walked(buddy, kpath)
					ctx.add_straight(buddy.hero_data.id, kpath.size() - 1)
		"aether":
			# Намеренный перегрев: −2 маны, +2 карты, до конца хода карты бьют сильнее
			h.mana -= 2
			_aether = true
			_draw_cards(h, 2)
			message.emit("Перегрузка эфира: карты бьют сильнее за каждый перегрев")
		"vent":
			_thermal_vent(h)
		"astral":
			_astral_beam(h, card, dir)
		"swap":
			var other: BattleUnit = unit_at(target)
			if other != null and other.is_hero and other != h:
				var a: Vector2i = h.cell
				var path_h: Array[Vector2i] = [a, other.cell]
				var path_o: Array[Vector2i] = [other.cell, a]
				h.cell = path_h[1]
				other.cell = a
				unit_moved.emit(h, path_h)
				unit_moved.emit(other, path_o)
				if card.id == "warrior_tactical_swap":
					h.block += card.block         # блок получает и напарник (обычным путём), и сам Рыцарь
					other.discount = 1            # следующая карта напарника дешевле на 1
		"bog_maw":
			for c in area:
				if _can_build(c) and object_at(c) == Obj.NONE:
					_set_tile(c, Tile.NONE)
					_set_object(c, Obj.BOG, Vector2i.ZERO)
					obj_timers[c] = BOG_MAW_TURNS
				var u: BattleUnit = unit_at(c)
				if u != null and not u.is_hero:
					u.entangled = 1
					message.emit("%s опутан" % u.title)
					status_changed.emit(u, snapshot(u))
		"stakes":
			if _can_build(target):
				_set_object(target, Obj.STAKES, Vector2i.ZERO)
		"bridge":
			if object_at(target) == Obj.BOG:
				obj_timers.erase(target)
				_set_object(target, Obj.BRIDGE, Vector2i.ZERO)
		"kick_barrel":
			if object_at(target) == Obj.BARREL:
				_roll_barrel(target, dir)
		"bell":
			var near: Array[BattleUnit] = []
			for e in living_enemies():
				if HexMath.distance(h.cell, e.cell) <= 3:
					near.append(e)
			near.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
				return HexMath.distance(a.cell, h.cell) > HexMath.distance(b.cell, h.cell))
			message.emit("Звон Колокола Стражи!")
			for e in near:
				if e.is_alive():
					_push(e, HexMath.direction_to(h.cell, e.cell), 1)


# Перемещает объект с клетки на клетку (бочку откатили, перенесли)
func _move_object(from: Vector2i, to: Vector2i) -> void:
	var kind: int = object_at(from)
	objects.erase(from)
	objects[to] = kind
	object_moved.emit(from, to)


# «Пинок бочки»: катится до 4 клеток и взрывается, во что-то врезавшись
func _roll_barrel(c: Vector2i, dir: Vector2i) -> void:
	var pos: Vector2i = c
	var crashed: bool = false
	for i in 4:
		var n: Vector2i = pos + dir
		var o: int = object_at(n)
		if is_blocked(n) or not (o == Obj.NONE or o == Obj.REEDS or o == Obj.PLANKS or o == Obj.BRIDGE):
			crashed = true
			break
		pos = n
	if pos != c:
		_move_object(c, pos)
	if crashed:
		_explode_barrel(pos)


# Куда добежит герой тараном в направлении dir и во что врежется
# (врезаться можно и после последнего шага — в то, что стоит прямо перед ним).
# Возвращает {"path": путь от его клетки, "hit_cell": клетка удара или NO_CELL}.
# Врезаться можно в юнита, дерево или бочку; трясину и камни таран не бьёт.
func _charge_plan(h: BattleUnit, dir: Vector2i, max_steps: int) -> Dictionary:
	var path: Array[Vector2i] = [h.cell]
	var hit_cell: Vector2i = NO_CELL
	var pos: Vector2i = h.cell
	for i in max_steps + 1:
		var next: Vector2i = pos + dir
		if unit_at(next) != null or _is_breakable(next):
			hit_cell = next
			break
		if _is_obstacle(next) or i == max_steps:
			break
		pos = next
		path.append(pos)
	return {"path": path, "hit_cell": hit_cell}


# ---------- Объекты ----------

func _set_object(c: Vector2i, kind: int, dir: Vector2i) -> void:
	var old: int = object_at(c)
	if old == kind:
		return
	obj_timers.erase(c)   # временный объект сменился — его таймер больше не нужен
	if kind == Obj.NONE:
		objects.erase(c)
	else:
		objects[c] = kind
	object_changed.emit(c, old, kind, dir)


# Удар по дереву или бочке. from — откуда пришёл удар (дерево падает от него).
func _hit_object(c: Vector2i, from: Vector2i) -> void:
	match object_at(c):
		Obj.TREE:
			_fell_tree(c, HexMath.direction_to(from, c))
		Obj.BARREL:
			_explode_barrel(c)


# Дерево падает в сторону dir и бьёт всех на TREE_LENGTH клетках
func _fell_tree(c: Vector2i, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		dir = Vector2i(0, 1)
	_set_object(c, Obj.NONE, dir)   # убираем сразу, чтобы цепочки не зацикливались
	message.emit("Дерево падает!")
	var cells: Array[Vector2i] = []
	for i in range(1, TREE_LENGTH + 1):
		var t: Vector2i = c + dir * i
		if is_inside(t):
			cells.append(t)
	effect_cells.emit(cells, "tree")
	for t in cells:
		var u: BattleUnit = unit_at(t)
		if u != null:
			_damage(u, TREE_DAMAGE)
			# Выживший сбит с ног: на 1 ход опутан (враг не ходит, но бьёт; герой без шагов)
			if u.is_alive() and _can_be_knocked_down(u):
				u.entangled = maxi(u.entangled, 1)
				message.emit("%s сбит с ног" % u.title)
				status_changed.emit(u, snapshot(u))
		if _is_breakable(t):
			_hit_object(t, c)
		if object_at(t) == Obj.RUNE:
			_trigger_rune(t)


# Босс и «тяжёлые» враги (корягач) слишком массивны, чтобы дерево сбило их с ног
func _can_be_knocked_down(u: BattleUnit) -> bool:
	return u.is_hero or (not u.data.is_boss and u.data.bog_damage <= 0)


# Бочка взрывается: урон по клетке и 6 соседям, поджог
func _explode_barrel(c: Vector2i) -> void:
	_set_object(c, Obj.NONE, Vector2i.ZERO)
	message.emit("Бочка с газом взрывается!")
	var cells: Array[Vector2i] = []
	for t in HexMath.cluster(c):
		if is_inside(t):
			cells.append(t)
	effect_cells.emit(cells, "explosion")
	for t in cells:
		var u: BattleUnit = unit_at(t)
		if u != null:
			_burn_off_block(u)
			_damage(u, BARREL_DAMAGE)
	for t in cells:
		if _is_breakable(t):
			_hit_object(t, c)
		if object_at(t) == Obj.RUNE:
			_trigger_rune(t)
		_apply_element(t, CardData.Element.FIRE, c, false)


# Проводит ли клетка электричество: лужа и трясина (цепочкой смежных клеток)
func _conducts(c: Vector2i) -> bool:
	var t: int = tile_at(c)
	return t == Tile.WATER or t == Tile.SWAMP


# Молния: если попала в лужу или трясину — бьёт по всем клеткам этой цепочки
func _spread_through_water(area: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = area.duplicate()
	var queue: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for c in area:
		if _conducts(c):
			queue.append(c)
			seen[c] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if not result.has(c):
			result.append(c)
		for d: Vector2i in HexMath.DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and _conducts(n):
				seen[n] = true
				queue.append(n)
	# «Водные» враги (жаба): молния в соседней луже достаёт и их
	for e in living_enemies():
		if not e.data.aquatic or result.has(e.cell):
			continue
		for d: Vector2i in HexMath.DIRS:
			if seen.has(e.cell + d):
				result.append(e.cell)
				break
	return result


# Правила стихий: огонь испаряет воду, топит лёд и поджигает объекты,
# вода и лёд тушат огонь, лёд замораживает трясину (по ней можно пройти).
# from — откуда пришла стихия (нужно, чтобы горящее дерево упало от героя).
# hero_card — стихия пришла от карты героя: реакции такой стихии не ранят и не
# опутывают героев. Взрыв бочки и удары врагов (hero_card = false) бьют по всем.
func _apply_element(c: Vector2i, element: CardData.Element, from: Vector2i, hero_card: bool = true) -> void:
	if not is_inside(c) or rocks.has(c):
		return
	var obj: int = object_at(c)
	if obj == Obj.LAVA:
		if element == CardData.Element.WATER or element == CardData.Element.ICE:
			_cool_lava(c)
		return   # огню лава не страшна и не нужна
	if obj == Obj.CRUST:
		return
	if element == CardData.Element.FIRE:
		if obj == Obj.BOG:
			_make_lava(c)   # трясина закипает лавой
			return
		if obj == Obj.TREE or obj == Obj.BARREL:
			_hit_object(c, from)
			return
		if obj == Obj.REEDS:
			_burn_reeds(c)
			return
		if obj == Obj.PLANKS or obj == Obj.BRIDGE:
			return   # мокрое не горит
		if obj == Obj.ICE_BLOCK:
			_set_object(c, Obj.NONE, Vector2i.ZERO)
			_set_tile(c, Tile.WATER)
			message.emit("Ледяная глыба тает")
			_ice_shatter(c, true, hero_card)
			return
		if obj == Obj.STAKES:
			_set_object(c, Obj.NONE, Vector2i.ZERO)
			_set_tile(c, Tile.FIRE)
			message.emit("Колья горят")
			return
	if element == CardData.Element.ICE and (obj == Obj.BOG or obj == Obj.PLANKS):
		_set_object(c, Obj.NONE, Vector2i.ZERO)
		_set_tile(c, Tile.ICE)
		message.emit("Трясина замерзает")
		return
	if obj == Obj.BOG or obj == Obj.TREE or obj == Obj.BARREL or obj == Obj.ICE_BLOCK or obj == Obj.STAKES:
		return   # на трясину и преграды вода и лёд не ложатся
	var old: int = tile_at(c)
	var new_tile: int = old
	match element:
		CardData.Element.FIRE:
			if old == Tile.WATER:
				_set_tile(c, Tile.NONE)   # лужа вскипает: паровой взрыв
				_steam_burst(c, from, hero_card)
				return
			elif old == Tile.ICE:
				_set_tile(c, Tile.WATER)  # лёд тает и раскалывается
				_ice_shatter(c, false, hero_card)
				return
			else:
				new_tile = Tile.FIRE
		CardData.Element.WATER:
			new_tile = Tile.NONE if old == Tile.FIRE else Tile.WATER
		CardData.Element.ICE:
			new_tile = Tile.NONE if old == Tile.FIRE else Tile.ICE
			if old == Tile.WATER:
				_set_tile(c, new_tile)
				_freeze_unit(c, hero_card)
				return
			# Мокрый юнит не в луже: лёд сковывает его так же, «Мокрый» снимается
			var soaked: BattleUnit = unit_at(c)
			if soaked != null and soaked.wet > 0 and not _always_wet(soaked) and not (hero_card and soaked.is_hero):
				soaked.wet = 0
				_set_tile(c, new_tile)
				_freeze_unit(c, hero_card)
				return
		_:
			return
	_set_tile(c, new_tile)


# Огонь на трясине: лава на LAVA_TURNS раундов, потом снова трясина
func _make_lava(c: Vector2i) -> void:
	_set_object(c, Obj.LAVA, Vector2i.ZERO)
	obj_timers[c] = LAVA_TURNS
	reaction.emit(c, "lava")
	message.emit("Трясина вскипает лавой!")


# Вода или лёд на лаве: остывает в корку на CRUST_TURNS раундов.
# Кто стоял в лаве — вмерзает в корку (опутан на 2 хода).
func _cool_lava(c: Vector2i) -> void:
	_set_object(c, Obj.CRUST, Vector2i.ZERO)
	obj_timers[c] = CRUST_TURNS
	reaction.emit(c, "crust")
	message.emit("Лава застывает коркой")
	var u: BattleUnit = unit_at(c)
	if u != null and u.is_alive():
		u.entangled = maxi(u.entangled, 2)
		message.emit("%s увяз в корке" % u.title)
		status_changed.emit(u, snapshot(u))


# Ветер: каждая горящая клетка линии поджигает соседнюю по ветру (через правила стихий)
func _fan_fire(area: Array[Vector2i], dir: Vector2i, from: Vector2i) -> void:
	var burning: Array[Vector2i] = []
	for c in area:
		if tile_at(c) == Tile.FIRE:
			burning.append(c)
	for c in burning:
		var next: Vector2i = c + dir
		if is_inside(next) and tile_at(next) != Tile.FIRE:
			_apply_element(next, CardData.Element.FIRE, from)
			message.emit("Ветер раздувает огонь")


# Урон от реакции: герои от собственной карты не страдают
func _reaction_hurt(u: BattleUnit, amount: int, hero_card: bool) -> void:
	if u == null or (hero_card and u.is_hero):
		return
	_damage(u, amount)


# Паровой взрыв: кто стоял на луже — получает урон и отлетает на клетку от центра заклинания
func _steam_burst(c: Vector2i, from: Vector2i, hero_card: bool) -> void:
	reaction.emit(c, "steam")
	var u: BattleUnit = unit_at(c)
	if u == null or (hero_card and u.is_hero):
		return
	message.emit("Паровой взрыв!")
	_damage(u, STEAM_DAMAGE)
	if u.is_alive():
		_push(u, HexMath.direction_to(from, c), 1)


# Ледяные осколки: юнит на тающем льду получает урон; глыба (is_block) бьёт 6 соседей
func _ice_shatter(c: Vector2i, is_block: bool, hero_card: bool) -> void:
	reaction.emit(c, "shatter")
	if not is_block:
		_reaction_hurt(unit_at(c), ICE_SHATTER_DAMAGE, hero_card)
		return
	message.emit("Глыба раскалывается!")
	for t in HexMath.cluster(c):
		if t != c and is_inside(t):
			_reaction_hurt(unit_at(t), ICE_SHATTER_DAMAGE, hero_card)


# Заморозка: лёд на луже вмораживает того, кто в ней стоит, на 1 ход
func _freeze_unit(c: Vector2i, hero_card: bool) -> void:
	reaction.emit(c, "freeze")
	var u: BattleUnit = unit_at(c)
	if u == null or (hero_card and u.is_hero) or not u.is_alive():
		return
	if not u.is_hero and (u.data.is_boss or u.data.bog_damage > 0 or HEAVY_IDS.has(u.data.id)):
		return
	u.entangled = maxi(u.entangled, 1)
	message.emit("%s вмёрз в лёд" % u.title)
	status_changed.emit(u, snapshot(u))


# Камыш сгорает и поджигает соседний камыш — пожар бежит по зарослям
func _burn_reeds(c: Vector2i) -> void:
	var queue: Array[Vector2i] = [c]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if object_at(cur) != Obj.REEDS:
			continue
		_set_object(cur, Obj.NONE, Vector2i.ZERO)
		_set_tile(cur, Tile.FIRE)
		for d: Vector2i in HexMath.DIRS:
			if object_at(cur + d) == Obj.REEDS:
				queue.append(cur + d)


func _set_tile(c: Vector2i, tile: int) -> void:
	if tile_at(c) == tile and tile != Tile.FIRE:
		return
	if tile == Tile.FIRE and tile_at(c) == Tile.GAS:
		_explode_gas(c)   # газ взрывается и превращается в обычную землю
		return
	if tile == Tile.NONE:
		tiles.erase(c)
	else:
		tiles[c] = tile
	if tile == Tile.FIRE:
		fire_timers[c] = FIRE_DURATION
		_burn_off_block(unit_at(c))
		_set_wet(unit_at(c), 0)          # огонь сушит
	else:
		fire_timers.erase(c)
	if tile == Tile.WATER:
		_set_wet(unit_at(c), WET_TURNS)  # вода под ногами мочит
	tile_changed.emit(c, tile)


# Ядовитый газ вспыхнул: взрыв на клетке (урон стоящему в ней), газ исчезает
func _explode_gas(c: Vector2i) -> void:
	tiles.erase(c)
	message.emit("Ядовитый газ взрывается!")
	effect_cells.emit([c] as Array[Vector2i], "explosion")
	tile_changed.emit(c, Tile.NONE)
	var u: BattleUnit = unit_at(c)
	if u != null:
		_damage(u, GAS_DAMAGE)


# Юнит попал в газ: урон и яд
func _gas_hit(u: BattleUnit) -> void:
	message.emit("%s дышит ядом" % u.title)
	_damage(u, GAS_DAMAGE)
	if u.is_alive():
		_set_poison(u, GAS_POISON)


# Огонь сжигает блок у тех, кто его боится (корягач)
func _burn_off_block(u: BattleUnit) -> void:
	if u == null or u.data == null or not u.data.fire_weak or u.block <= 0:
		return
	u.block = 0
	message.emit("%s: огонь сжигает броню" % u.title)
	status_changed.emit(u, snapshot(u))


# Толкает юнита. Если упёрся в камень, край поля, дерево, бочку или другого
# юнита — урон обоим (а дерево падает, бочка взрывается). По льду скользит
# дальше. Толкнули в трясину — враг тонет. Герои, босс и «тяжёлые» враги
# не тонут: трясина для них как стена, только урона больше. Топляк по ней ходит.
func _push(unit: BattleUnit, dir: Vector2i, distance: int) -> void:
	if dir == Vector2i.ZERO:
		return
	var path: Array[Vector2i] = [unit.cell]
	var bumped: bool = false
	var drowned: bool = false
	var bump_cell: Vector2i = NO_CELL
	var steps_left: int = distance
	while steps_left > 0 or tile_at(unit.cell) == Tile.ICE:
		var next: Vector2i = unit.cell + dir
		var into_bog: bool = object_at(next) == Obj.BOG and unit_at(next) == null
		if into_bog and _sinks(unit):
			unit.cell = next
			path.append(next)
			drowned = true
			break
		if is_blocked(next) and not (into_bog and _walks_bog(unit)):
			bumped = true
			bump_cell = next
			break
		unit.cell = next
		path.append(next)
		steps_left -= 1
		if object_at(next) == Obj.CRUST:
			break   # корка: толкнутый останавливается на ней
	unit_pushed.emit(unit, path, bumped)
	_break_planks_behind(path)
	if drowned:
		message.emit("%s тонет в трясине!" % unit.title)
		_kill(unit)
		return
	_walked(unit, path)
	if not unit.is_alive():
		return
	if bumped:
		message.emit("%s врезается!" % unit.title)
		var bump_damage: int = BUMP_DAMAGE
		var other: BattleUnit = unit_at(bump_cell)
		if other == null and object_at(bump_cell) == Obj.LAVA:
			bump_damage = LAVA_DAMAGE
			message.emit("%s обжигается о лаву" % unit.title)
		elif other == null and object_at(bump_cell) == Obj.BOG:
			bump_damage = _bog_damage(unit)
			message.emit("%s вязнет на краю трясины" % unit.title)
		elif object_at(bump_cell) == Obj.STAKES:
			bump_damage = STAKES_BUMP_DAMAGE
			message.emit("%s насаживается на колья!" % unit.title)
		_damage(unit, bump_damage)
		if other != null:
			_damage(other, BUMP_DAMAGE)
		elif _is_breakable(bump_cell):
			_hit_object(bump_cell, unit.cell)


# ignore_block — удар проходит сквозь блок («Разлом»)
func _damage(unit: BattleUnit, amount: int, ignore_block: bool = false) -> void:
	if amount <= 0 or not unit.is_alive():
		return
	# «Живой бастион»: Рыцарь рядом принимает половину урона по напарнику вместо него
	if unit.is_hero and not unit.guarding:
		for g in living_heroes():
			if g != unit and g.guarding and HexMath.distance(g.cell, unit.cell) <= 1:
				message.emit("%s прикрывает %s" % [g.title, unit.title])
				_damage(g, amount / 2, ignore_block)
				return
	# Древесная броня корягача: огонь сжигает её, одиночная физическая атака режется вдвое
	if unit.data != null and unit.data.wood_armor and _cur_card != null and not unit.armor_burnt:
		if _cur_card.element == CardData.Element.FIRE:
			unit.armor_burnt = true
			message.emit("%s: древесная броня сгорела" % unit.title)
		elif _cur_attack and _cur_card.shape == CardData.Shape.SINGLE:
			amount = maxi(1, amount / WOOD_ARMOR_DIVISOR)
	# «Уязвимость к магии»: следующее Заклинание бьёт сильнее
	if _cur_spell and unit.vulnerable > 0:
		amount += unit.vulnerable
		unit.vulnerable = 0
		status_changed.emit(unit, snapshot(unit))
	# Рыцарь злится от каждого удара, даже если блок его поглотил
	if unit.is_hero and unit.hero_data.gains_rage:
		unit.rage += 1
	var absorbed: int = 0 if ignore_block else mini(unit.block, amount)
	unit.block -= absorbed
	var dealt: int = amount - absorbed
	unit.hp = maxi(0, unit.hp - dealt)
	unit_damaged.emit(unit, dealt, snapshot(unit))
	if absorbed > 0:
		message.emit("%s: −%d HP (блок поглотил %d)" % [unit.title, dealt, absorbed])
	else:
		message.emit("%s: −%d HP" % [unit.title, dealt])
	if not unit.is_alive():
		unit_died.emit(unit)
		message.emit("%s падает" % unit.title)
		_death_blast(unit)
	elif unit.data != null and unit.data.inflation and _cur_attack and _cur_card != null \
			and _cur_card.special != "harpoon":
		unit.inflation += 1
		status_changed.emit(unit, snapshot(unit))
		if unit.inflation >= INFLATION_MAX:
			_kill(unit)
			_inflation_burst(unit)


# Жаба, погибая, лопается: урон четырём соседям (и своим, и чужим), удар по
# деревьям и бочкам рядом, на её клетке остаётся лужа. Утонула — взрыва нет
# (тогда вызывается _kill, а не _damage).
func _death_blast(unit: BattleUnit) -> void:
	if unit.data != null and unit.data.inflation:
		_inflation_burst(unit)
		return
	if unit.data == null or unit.data.death_blast <= 0:
		return
	message.emit("%s лопается: газовый хлопок!" % unit.title)
	var cells: Array[Vector2i] = []
	for d: Vector2i in HexMath.DIRS:
		if is_inside(unit.cell + d):
			cells.append(unit.cell + d)
	effect_cells.emit(cells, "gas")
	for t in cells:
		var u: BattleUnit = unit_at(t)
		if u != null:
			_damage(u, unit.data.death_blast)
	for t in cells:
		if _is_breakable(t):
			_hit_object(t, unit.cell)
	if object_at(unit.cell) == Obj.NONE:
		_apply_element(unit.cell, CardData.Element.WATER, unit.cell)


# Взрыв раздутой жабы: 12 урона и яд всем вокруг; при 2+ стаках — в два кольца (18 клеток)
func _inflation_burst(unit: BattleUnit) -> void:
	message.emit("%s лопается: ядовитый взрыв!" % unit.title)
	var cells: Array[Vector2i] = HexMath.ring(unit.cell, 1)
	if unit.inflation >= 2:
		cells.append_array(HexMath.ring(unit.cell, 2))
	var inside: Array[Vector2i] = []
	for c in cells:
		if is_inside(c):
			inside.append(c)
	effect_cells.emit(inside, "gas")
	var saved_card: CardData = _cur_card
	_cur_card = null   # взрыв — не карта игрока
	for c in inside:
		var u: BattleUnit = unit_at(c)
		if u != null and u != unit:
			_damage(u, INFLATION_DAMAGE)
			if u.is_alive():
				_set_poison(u, INFLATION_POISON)
	_cur_card = saved_card
	for c in inside:
		if _is_breakable(c):
			_hit_object(c, unit.cell)


# Мгновенная смерть (утонул)
func _kill(unit: BattleUnit) -> void:
	unit.hp = 0
	unit.block = 0
	unit_damaged.emit(unit, 0, snapshot(unit))
	unit_died.emit(unit)



# ---------- Новые карты: расчёты ----------

# Прибавка к урону от особых условий карты (минус — уменьшение)
func _special_damage_bonus(h: BattleUnit, card: CardData) -> int:
	var bonus: int = 0
	match card.special:
		"axis_ram":
			bonus += 3 * _cur_straight   # +3 за каждую клетку разгона по прямой
		"crescent":
			if _cur_moved == 0:
				bonus -= card.damage / 2   # стоял на месте — вдвое слабее
		"patient":
			bonus += 7 * _cur_retain       # копит +7 урона за каждый ход в руке
		"ricochet":
			bonus += h.block               # сила броска равна блоку Рыцаря
	if _aether:
		bonus += AETHER_DAMAGE * _party_overheat()
	return bonus


func _party_overheat() -> int:
	var most: int = 0
	for hero in living_heroes():
		most = maxi(most, overheat_stacks(hero))
	return most


# Цель «Токсичного розжига» стоит на болоте/газе или отравлена
func _ignitable(c: Vector2i) -> bool:
	var t: int = tile_at(c)
	if t == Tile.SWAMP or t == Tile.GAS:
		return true
	var u: BattleUnit = unit_at(c)
	return u != null and u.poison > 0


# «Дуговой разряд»: в перегреве бьёт цепочку соседних врагов и стоящих в трясине, иначе прыгает на соседа
func _arc_discharge(h: BattleUnit, card: CardData, target: Vector2i) -> void:
	if h.mana < 0:
		var chain: Array[BattleUnit] = []
		var queue: Array[Vector2i] = [target]
		var seen: Dictionary[Vector2i, bool] = {target: true}
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			for n in HexMath.neighbors(c):
				var u: BattleUnit = unit_at(n)
				if not seen.has(n) and u != null and not u.is_hero:
					seen[n] = true
					chain.append(u)
					queue.append(n)
		for e in living_enemies():
			if tile_at(e.cell) == Tile.SWAMP and not chain.has(e) and e.cell != target:
				chain.append(e)
		for e in chain:
			if e.is_alive():
				_card_damage(e, 9, false)
		return
	var near: Array[BattleUnit] = []
	for n in HexMath.neighbors(target):
		var u2: BattleUnit = unit_at(n)
		if u2 != null and not u2.is_hero:
			near.append(u2)
	if not near.is_empty():
		_card_damage(near[rng.randi_range(0, near.size() - 1)], 4, false)


# «Термический сброс»: снимает перегрев, щит обоим героям и кольцо огня вокруг Мага
func _thermal_vent(h: BattleUnit) -> void:
	var stacks: int = overheat_stacks(h)
	if stacks <= 0:
		return
	h.mana = 0
	for hero in living_heroes():
		hero.block += 4 * stacks
		status_changed.emit(hero, snapshot(hero))
	var ring: Array[Vector2i] = []
	for n in HexMath.neighbors(h.cell):
		if is_inside(n):
			ring.append(n)
	effect_cells.emit(ring, "explosion")
	for n in ring:
		var u: BattleUnit = unit_at(n)
		if u != null and not u.is_hero:
			_card_damage(u, 5 * stacks, false)
		_apply_element(n, CardData.Element.FIRE, h.cell)


# «Астральный луч»: каждая цель на линии усиливает луч на +4; Рыцарь на линии не ранится, а получает блок
func _astral_beam(h: BattleUnit, card: CardData, dir: Vector2i) -> void:
	var bonus: int = 0
	var cells: Array[Vector2i] = _line_cells(h.cell, dir, card.cast_range, true)
	effect_cells.emit(cells, "explosion")
	for c in cells:
		var u: BattleUnit = unit_at(c)
		if u == null:
			continue
		if u.is_hero:
			u.block += 4
			bonus += 4
			status_changed.emit(u, snapshot(u))
		else:
			var dealt: int = 7 + bonus
			if _aether:
				dealt += AETHER_DAMAGE * _party_overheat()
			_card_damage(u, dealt, _cur_retain >= 1)
			bonus += 4



# «Магическая призма»: Заклинание Мага разделяется на 3 луча от Рыцаря (оси с самым большим числом врагов), +3 урона
func _fire_prism(card: CardData) -> void:
	for carrier in living_heroes():
		if not carrier.prism:
			continue
		carrier.prism = false
		var scored: Array[Dictionary] = []
		for d: Vector2i in HexMath.DIRS:
			var n: int = 0
			for c in HexMath.ray(carrier.cell, d, 8):
				var u: BattleUnit = unit_at(c)
				if u != null and not u.is_hero:
					n += 1
			scored.append({"dir": d, "n": n})
		scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["n"] > b["n"])
		var hit: Dictionary[BattleUnit, bool] = {}
		for i in mini(3, scored.size()):
			for c in HexMath.ray(carrier.cell, scored[i]["dir"], 8):
				var u2: BattleUnit = unit_at(c)
				if u2 != null and not u2.is_hero and not hit.has(u2):
					hit[u2] = true
		message.emit("Призма разделяет заклинание на лучи")
		for u3: BattleUnit in hit.keys():
			if u3.is_alive():
				_card_damage(u3, card.damage + 3, false)
		return


# ---------- Враги: синергии ----------

func _slime_count(h: BattleUnit) -> int:
	var n: int = 0
	for c in h.hand:
		if c.special == "slime":
			n += 1
	return n


# «Живой щит»: одиночная дальняя атака или заклинание по врагу рядом с корягачом бьёт корягача
func _intercept(card: CardData, target: Vector2i) -> Vector2i:
	if card.shape != CardData.Shape.SINGLE or card.cast_range <= 1 or card.damage <= 0 or card.special == "ricochet":
		return target
	var victim: BattleUnit = unit_at(target)
	if victim == null or victim.is_hero or (victim.data != null and victim.data.living_shield):
		return target
	for e in living_enemies():
		if e.data.living_shield and HexMath.distance(e.cell, target) == 1:
			message.emit("%s перехватывает удар" % e.title)
			return e.cell
	return target


# Топляк ударил: клетки вокруг становятся трясиной, а герою в руку падает «Болотная тина»
func _make_swamp_around(e: BattleUnit, victims: Array[BattleUnit]) -> void:
	for n in HexMath.neighbors(e.cell):
		if is_inside(n) and not rocks.has(n) and object_at(n) == Obj.NONE and tile_at(n) == Tile.NONE:
			_set_tile(n, Tile.SWAMP)
	var slime: CardData = load("res://resources/cards/swamp_slime.tres")
	for u in victims:
		if u.is_hero and u.is_alive() and slime != null:
			if u.hand.size() < MAX_HAND:
				u.hand.append(slime)
			else:
				u.discard_pile.append(slime)
			message.emit("%s: в руке «Болотная тина»" % u.title)
			status_changed.emit(u, snapshot(u))
			break


# Пращник: если жаба далеко от героев — бьёт по ней камнем (+1 раздувание) и толкает к героям
func _slinger_assist(e: BattleUnit) -> bool:
	for t in living_enemies():
		if not t.data.inflation or t == e or HexMath.distance(e.cell, t.cell) > e.data.attack_range:
			continue
		var near: BattleUnit = null
		for h in living_heroes():
			if near == null or HexMath.distance(h.cell, t.cell) < HexMath.distance(near.cell, t.cell):
				near = h
		if near == null or HexMath.distance(near.cell, t.cell) < 3:
			continue
		message.emit("%s швыряет камень в жабу" % e.title)
		_damage(t, 1)
		if t.is_alive():
			t.inflation += 1
			status_changed.emit(t, snapshot(t))
			if t.inflation >= INFLATION_MAX:
				_kill(t)
				_inflation_burst(t)
			else:
				_push(t, HexMath.direction_to(t.cell, near.cell), 1)
		return true
	return false


# ---------- Колода ----------

func _draw_cards(h: BattleUnit, count: int) -> void:
	for i in count:
		if h.hand.size() >= MAX_HAND:
			return
		if h.draw_pile.is_empty():
			if h.discard_pile.is_empty():
				return
			# Колода кончилась — перемешиваем сброс и берём из него
			h.draw_pile = h.discard_pile.duplicate()
			h.discard_pile.clear()
			_shuffle(h.draw_pile)
		h.hand.append(h.draw_pile.pop_back())


# Сколько сбросов осталось у героя в этот ход
func discards_left(h: BattleUnit) -> int:
	return _discards_left.get(h, 0)


# Можно ли сбросить карту: в режиме «сброс всей руки» сброс не нужен
func can_discard(h: BattleUnit, index: int) -> bool:
	return DRAW_MODE != DrawMode.DISCARD_ALL and DRAW_MODE != DrawMode.KEEP_2 and not is_over and h.is_alive() \
		and discards_left(h) > 0 and index >= 0 and index < h.hand.size()


# Сбросить карту из руки в сброс (без розыгрыша). Добор не даётся.
func discard_card(h: BattleUnit, index: int) -> bool:
	if not can_discard(h, index):
		return false
	var card: CardData = h.hand[index]
	h.hand.remove_at(index)
	_forget_kept(h, index)
	h.discard_pile.append(card)
	_discards_left[h] = discards_left(h) - 1
	message.emit("%s сбрасывает «%s»" % [h.title, card.title])
	status_changed.emit(h, snapshot(h))
	return true


# Перемешивание через общий генератор забега (а не встроенный shuffle(),
# который берёт случайность «откуда-то» и ломает повторяемость по сиду)
func _shuffle(cards: Array[CardData]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: CardData = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


# ---------- Ходы ----------

func _start_heroes_turn() -> void:
	turn += 1
	ctx.reset()
	_aether = false
	for h in living_heroes():
		if h.block > 0 or h.taunt:
			h.block = 0
			h.taunt = false
			status_changed.emit(h, snapshot(h))
		h.guarding = false
		h.prism = false
		h.mana = maxi(0, h.hero_data.mana_per_turn - int(_mana_penalty.get(h.id, 0)))
		_mana_penalty[h.id] = 0
		h.moves_left = maxi(0, h.hero_data.moves_per_turn - _slime_count(h))
		h.discount = 0
		_discards_left[h] = DISCARDS_PER_TURN
		h.outpost = false
		h.momentum = 0
		if h.entangled > 0:
			h.moves_left = 0   # опутан: шагов нет, но карты играть можно
			h.entangled -= 1
			message.emit("%s опутан: в этот ход без шагов" % h.title)
		status_changed.emit(h, snapshot(h))
		# Рука целиком сбрасывается — берём новую; в остальных режимах
		# карты добираются в end_turn(), а в бою рука стартует с 5 карт
		if DRAW_MODE == DrawMode.DISCARD_ALL or turn == 1:
			_draw_cards(h, HAND_SIZE)
	# У врагов с циклом ударов в новом раунде другой удар — обновляем надписи
	for e in living_enemies():
		if e.data.cycle.size() > 1:
			status_changed.emit(e, snapshot(e))
	message.emit("— Ход %d —" % turn)


# Мана героя ушла в минус: урона нет, но если в минусе 2 или больше —
# в следующий ход у этого героя маны на единицу меньше.
func _apply_overheat() -> void:
	for h in living_heroes():
		var stacks: int = overheat_stacks(h)
		if stacks <= 0:
			continue
		message.emit("%s: перегрев %d" % [h.title, stacks])
		overheated.emit(h, stacks)
		if stacks >= OVERHEAT_PENALTY_FROM:
			_mana_penalty[h.id] = OVERHEAT_MANA_PENALTY
		h.mana = 0


func overheat_stacks(h: BattleUnit) -> int:
	return maxi(0, -h.mana)


# Герои закончили ход: враги подходят и бьют, потом жжёт огонь, потом новый ход
func end_turn() -> void:
	if is_over:
		return
	for h in heroes:
		if DRAW_MODE == DrawMode.DISCARD_ALL:
			h.discard_pile.append_array(h.hand)
			h.hand.clear()
		elif DRAW_MODE == DrawMode.KEEP_2:
			_discard_unkept(h)
		h.unstoppable = false
		# «Перегрузка»: заряд не потрачен — бьёт по самому магу
		if h.is_alive() and h.overloaded and h.charge > 0:
			message.emit("Перегрузка бьёт по %s!" % h.title)
			var overload: int = h.charge
			h.charge = 0
			h.overloaded = false
			_damage(h, overload)
			status_changed.emit(h, snapshot(h))
		h.overloaded = false
	_apply_overheat()
	if _check_end():
		return
	# Добор сразу после «Конец хода», ещё до хода врагов
	if DRAW_MODE != DrawMode.DISCARD_ALL:
		for h in living_heroes():
			_draw_cards(h, _end_turn_draw_count(h))
	if _enemies_act():
		return

	# Огонь жжёт всех, кто в нём стоит, и постепенно гаснет
	for c: Vector2i in fire_timers.keys():
		if not fire_timers.has(c):
			continue   # огонь уже потушили (например, лужа от лопнувшей жабы)
		var u: BattleUnit = unit_at(c)
		if u != null:
			message.emit("%s горит" % u.title)
			var weak: bool = u.data != null and u.data.fire_weak
			_damage(u, FIRE_DAMAGE * 2 if weak else FIRE_DAMAGE)
		if not fire_timers.has(c):
			continue
		fire_timers[c] -= 1
		if fire_timers[c] <= 0:
			_set_tile(c, Tile.NONE)
	# Лава жжёт всех, кто в ней стоит (например, топляка)
	for c: Vector2i in obj_timers.keys():
		if object_at(c) == Obj.LAVA:
			var lu: BattleUnit = unit_at(c)
			if lu != null:
				message.emit("%s жарится в лаве" % lu.title)
				_damage(lu, LAVA_DAMAGE)
	_tick_statuses()
	_tick_objects()
	if _check_end():
		return

	_start_heroes_turn()


# Сколько карт герой добирает после «Конец хода» (не считая лимита руки)
func _end_turn_draw_count(h: BattleUnit) -> int:
	match DRAW_MODE:
		DrawMode.REFILL_5:
			return maxi(1, HAND_SIZE - h.hand.size())
		DrawMode.PLUS_3:
			return 3
		DrawMode.PLUS_2:
			return 2
		DrawMode.KEEP_2:
			return TURN_DRAW
	return 0


# Временные объекты (ледяные глыбы, «Пасть топей») исчезают по таймеру
func _tick_objects() -> void:
	for c: Vector2i in obj_timers.keys():
		obj_timers[c] -= 1
		if obj_timers[c] <= 0:
			var kind: int = object_at(c)
			if kind == Obj.LAVA:
				_set_object(c, Obj.BOG, Vector2i.ZERO)   # лава остыла — снова трясина
				continue
			_set_object(c, Obj.NONE, Vector2i.ZERO)
			if kind == Obj.ICE_BLOCK:
				_set_tile(c, Tile.WATER)   # глыба растаяла — осталась лужа


# Враги по очереди: подойти и ударить, если герой в досягаемости.
# Возвращает true, если бой закончился.
func _enemies_act() -> bool:
	_start_enemy_phase()
	for e in EnemyAI.turn_order(self):
		if not e.is_alive():
			continue
		var atk: EnemyAttackData = enemy_attack(e)
		var start: Vector2i = e.cell
		var dir: Vector2i = _enemy_move(e, atk)
		if not e.is_alive():
			# Погиб по дороге (сторожевая руна) — не дошёл и не ударил
			if _check_end():
				return true
			continue
		if e.cell != start and e.data.wet_trail:
			_leave_puddle(start)
		if e.entangled > 0:
			e.entangled -= 1
			status_changed.emit(e, snapshot(e))
		if e.cell != start and _outpost_strike(e):
			if _check_end():
				return true
			continue
		if atk.shape == EnemyData.Attack.AURA:
			_enemy_aura(e, atk)
			continue
		if e.data.feeds_toad and _slinger_assist(e):
			continue
		if dir == Vector2i.ZERO:
			continue
		_enemy_strike(e, atk, dir)
		if _check_end():
			return true
	return false


# Какой удар у врага в этом раунде (у врагов с циклом они чередуются)
func enemy_attack(e: BattleUnit) -> EnemyAttackData:
	return e.data.attack_on_turn(turn)


# Начало хода врагов: старый блок сгорает (как у героев в начале их хода),
# а у кого есть «броня» (turn_block) — получает её заново. Блок не копится.
func _start_enemy_phase() -> void:
	for e in living_enemies():
		var block: int = e.data.turn_block
		if e.data.fire_weak and tile_at(e.cell) == Tile.FIRE:
			block = 0   # стоит в огне — брони нет
		if e.block != block:
			e.block = block
			status_changed.emit(e, snapshot(e))


# Удар врага: урон всем в клетках удара, потом — лужа, опутывание, толчок или притягивание
func _enemy_strike(e: BattleUnit, atk: EnemyAttackData, dir: Vector2i) -> void:
	var cells: Array[Vector2i] = _attack_cells(e, atk, e.cell, dir)
	enemy_attacked.emit(e, dir, cells)
	if atk.title != "Удар":
		message.emit("%s: %s" % [e.title, atk.title])
	var damage: int = atk.damage + e.bonus_damage
	if e.bonus_damage > 0:
		e.bonus_damage = 0   # усиление «Зова» — на один удар
		status_changed.emit(e, snapshot(e))
	var victims: Array[BattleUnit] = []
	for c in cells:
		var u: BattleUnit = unit_at(c)
		if u != null and u != e:
			victims.append(u)
			_damage(u, damage)          # по пути можно задеть и других
		elif _is_breakable(c) and not atk.pierce:
			_hit_object(c, e.cell)      # промах по бочке — тоже взрыв
		if object_at(c) == Obj.RUNE and not atk.pierce:
			_trigger_rune(c)   # удар врага по клетке руны тоже её подрывает
	for u in victims:
		if not u.is_alive():
			continue
		if atk.puddle and object_at(u.cell) == Obj.NONE:
			_apply_element(u.cell, CardData.Element.WATER, e.cell)
		if atk.entangle > 0:
			u.entangled = maxi(u.entangled, atk.entangle)
			message.emit("%s опутан" % u.title)
			status_changed.emit(u, snapshot(u))
	if e.data.swamp_on_hit:
		_make_swamp_around(e, victims)
	if atk.push > 0:
		# Сначала дальних, чтобы они не мешали ближним
		victims.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return HexMath.distance(a.cell, e.cell) > HexMath.distance(b.cell, e.cell))
		for u in victims:
			if u.is_alive() and e.is_alive():
				_push(u, dir, atk.push)
	elif atk.pull > 0:
		# Притягивание — тот же толчок, только к себе. Сначала ближних.
		victims.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return HexMath.distance(a.cell, e.cell) < HexMath.distance(b.cell, e.cell))
		for u in victims:
			var gap: int = HexMath.distance(u.cell, e.cell) - 1   # свободных клеток между ними
			if u.is_alive() and e.is_alive() and gap > 0:
				_push(u, -dir, mini(atk.pull, gap))


# «Зов»: враги в круге радиусом 2 вокруг (и сам зовущий) получают блок, их следующий удар сильнее
func _enemy_aura(e: BattleUnit, atk: EnemyAttackData) -> void:
	var cells: Array[Vector2i] = _aura_cells(e.cell, atk.attack_range)
	enemy_buffed.emit(e, cells)
	message.emit("%s: %s" % [e.title, atk.title])
	for ally in living_enemies():
		if cells.has(ally.cell):
			ally.block += atk.ally_block
			ally.bonus_damage = maxi(ally.bonus_damage, atk.ally_damage)
			status_changed.emit(ally, snapshot(ally))


# Круг из сот радиусом radius вокруг клетки (центр и все клетки не дальше radius шагов)
func _aura_cells(center: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for c in HexMath.in_range(center, radius):
		if is_inside(c):
			cells.append(c)
	return cells


# «Сырой след» топляка: сухая клетка, с которой он ушёл, становится лужей
func _leave_puddle(c: Vector2i) -> void:
	if object_at(c) == Obj.NONE and not rocks.has(c):
		_apply_element(c, CardData.Element.WATER, c)


# «Застава»: враг подошёл вплотную к рыцарю — получает удар. Возвращает true, если погиб.
func _outpost_strike(e: BattleUnit) -> bool:
	for h in living_heroes():
		if h.outpost and HexMath.distance(h.cell, e.cell) == 1:
			message.emit("Застава: %s получает удар" % e.title)
			_damage(e, OUTPOST_DAMAGE)
			if not e.is_alive():
				return true
	return false


# Проверка конца боя. Бой проигран, только если пали все герои.
func _check_end() -> bool:
	if is_over:
		return true
	if living_heroes().is_empty():
		is_over = true
		won = false
		message.emit("Отряд пал…")
	elif living_enemies().is_empty():
		is_over = true
		won = true
		message.emit("Все враги повержены!")
	return is_over


# ---------- Прогноз хода врагов ----------

# Копия боя: те же юниты, поле и огонь. Сигналы копии никуда не подключены,
# поэтому на ней можно «проиграть» ход врагов, не трогая настоящий бой.
func clone() -> BattleLogic:
	var c := BattleLogic.new()
	c.width = width
	c.height = height
	c.rng = RandomNumberGenerator.new()
	c.rng.seed = rng.seed
	c.rng.state = rng.state
	c._mana_penalty = _mana_penalty.duplicate()
	for h in heroes:
		c.heroes.append(h.copy())
	for e in enemies:
		c.enemies.append(e.copy())
	c.rocks = rocks.duplicate()
	c.objects = objects.duplicate()
	c.tiles = tiles.duplicate()
	c.fire_timers = fire_timers.duplicate()
	c.obj_timers = obj_timers.duplicate()
	c.turn = turn
	c.is_over = is_over
	return c


# Что сделает каждый живой враг, если нажать «Конец хода» прямо сейчас.
# Возвращает массив {"enemy": BattleUnit, "path": путь, "attack": клетки удара,
# "buff": клетки «зова» (кого враг усилит), "reason": почему враг так ходит}.
func forecast_enemies() -> Array[Dictionary]:
	var sim: BattleLogic = clone()
	var by_id: Dictionary[int, Dictionary] = {}
	for e in living_enemies():
		var start_path: Array[Vector2i] = [e.cell]
		var empty: Array[Vector2i] = []
		var no_buff: Array[Vector2i] = []
		by_id[e.id] = {"enemy": e, "path": start_path, "attack": empty, "buff": no_buff, "reason": ""}
	sim.unit_moved.connect(func(u: BattleUnit, path: Array[Vector2i]) -> void:
		if by_id.has(u.id):
			by_id[u.id]["path"] = path)
	sim.enemy_attacked.connect(func(u: BattleUnit, _dir: Vector2i, cells: Array[Vector2i]) -> void:
		if by_id.has(u.id):
			by_id[u.id]["attack"] = cells)
	sim.enemy_buffed.connect(func(u: BattleUnit, cells: Array[Vector2i]) -> void:
		if by_id.has(u.id):
			by_id[u.id]["buff"] = cells)
	sim._enemies_act()
	for u in sim.enemies:
		if by_id.has(u.id):
			by_id[u.id]["reason"] = u.ai_reason   # почему враг так ходит — для карточки врага
	var result: Array[Dictionary] = []
	result.assign(by_id.values())
	return result


# Что ещё случится в ход врагов, кроме их ударов: взрывы бочек, падения деревьев, газ жабы
# («effects»: [{cells, kind}]) и кто будет стоять в огне к концу раунда («fire»: id юнита → урон).
# Проигрывается на копии, как и forecast_enemies(): настоящий бой не меняется.
func forecast_hazards() -> Dictionary:
	var sim: BattleLogic = clone()
	var effects: Array[Dictionary] = []
	sim.effect_cells.connect(func(cells: Array[Vector2i], kind: String) -> void:
		effects.append({"cells": cells.duplicate(), "kind": kind}))
	sim._enemies_act()
	var fire: Dictionary = {}
	var poison: Dictionary = {}
	if not sim.is_over:
		# Огонь жжёт тех, кто к концу хода врагов остался в горящей клетке
		for c: Vector2i in sim.fire_timers.keys():
			var u: BattleUnit = sim.unit_at(c)
			if u != null and u.is_alive():
				var weak: bool = u.data != null and u.data.fire_weak
				fire[u.id] = FIRE_DAMAGE * 2 if weak else FIRE_DAMAGE
		# Яд ранит отравленных в конце раунда (после огня)
		for u in sim.living_enemies() + sim.living_heroes():
			if u.poison > 0:
				poison[u.id] = POISON_DAMAGE
	return {"effects": effects, "fire": fire, "poison": poison}


# ---------- Враги ----------

# Зона угрозы врага: все клетки, по которым он сможет ударить в свой ход,
# если сначала подойдёт. Показывается при наведении на врага.
func get_threat_cells(e: BattleUnit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not e.is_alive():
		return result
	var atk: EnemyAttackData = enemy_attack(e)
	if atk.shape == EnemyData.Attack.AURA:
		return result   # в этом раунде враг не бьёт, а усиливает своих
	var seen: Dictionary[Vector2i, bool] = {}
	for pos: Vector2i in reachable_cells(e, e.data.move_range, true):
		for d: Vector2i in HexMath.DIRS:
			for c in _attack_cells(e, atk, pos, d):
				if not seen.has(c) and c != e.cell:
					seen[c] = true
					result.append(c)
	return result


# Клетки, по которым придётся удар atk врага e, если он встанет на from и ударит в сторону dir
func _attack_cells(e: BattleUnit, atk: EnemyAttackData, from: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match atk.shape:
		EnemyData.Attack.MELEE:
			cells.append(from + dir)
		EnemyData.Attack.SWEEP:
			cells = HexMath.arc(from, from + dir)   # клетка перед врагом и две по бокам от неё
		EnemyData.Attack.AROUND:
			# Круговой удар: все 6 клеток вокруг, сторона удара не важна
			cells = HexMath.neighbors(from)
		EnemyData.Attack.LINE:
			cells = _line_cells(from, dir, atk.attack_range, atk.pierce)
			if atk.first_only:
				# Камень из пращи летит до первого, в кого попадёт (сам стрелок не в счёт)
				for i in cells.size():
					var u: BattleUnit = unit_at(cells[i])
					if u != null and u != e:
						cells = cells.slice(0, i + 1)
						break
	var inside: Array[Vector2i] = []
	for c in cells:
		if is_inside(c) and not rocks.has(c):
			inside.append(c)
	return inside


# ИИ врага (scripts/battle/enemy_ai.gd): враг оценивает удары по тому, что они сделают,
# выбирает цель и встаёт на лучшую клетку. Здесь — только само перемещение.
# Возвращает направление удара (ZERO — ударить не получится).
func _enemy_move(e: BattleUnit, atk: EnemyAttackData) -> Vector2i:
	var plan: Dictionary = EnemyAI.choose(self, e, atk)
	var best_cell: Vector2i = plan["cell"]
	var best_dir: Vector2i = plan["dir"]
	e.ai_reason = plan["reason"]
	if plan["notable"]:
		var text: String = plan["reason"]
		message.emit("%s: %s" % [e.title, text.left(1).to_lower() + text.substr(1)])
	if best_cell != e.cell:
		var path: Array[Vector2i] = plan["path"]
		e.cell = best_cell
		unit_moved.emit(e, path)
		_break_planks_behind(path)
		var walked: Array[Vector2i] = []
		walked.assign(path)
		_walked(e, walked)
	return best_dir


# Сколько шагов от каждой клетки до ближайшего из героев, в обход преград
# (поиск в ширину сразу от всех героев). Юниты не мешают — они сдвинутся.
# walker — для кого считаем: топляку трясина не преграда.
func _distance_map(from_units: Array[BattleUnit], walker: BattleUnit = null) -> Dictionary[Vector2i, int]:
	var dist: Dictionary[Vector2i, int] = {}
	var frontier: Array[Vector2i] = []
	for u in from_units:
		dist[u.cell] = 0
		frontier.append(u.cell)
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		for d: Vector2i in HexMath.DIRS:
			var n: Vector2i = cur + d
			if not dist.has(n) and not _is_obstacle_for(walker, n):
				dist[n] = dist[cur] + 1
				frontier.append(n)
	return dist


# Случайная пустая клетка в рядах от min_row до max_row
func _random_free_cell(min_row: int, max_row: int) -> Vector2i:
	var free: Array[Vector2i] = []
	for y in range(min_row, max_row + 1):
		for x in width:
			var c: Vector2i = _cell(x, y)
			if _is_empty(c):
				free.append(c)
	if free.is_empty():
		return NO_CELL
	return free[rng.randi_range(0, free.size() - 1)]


# «Призрак»: проигрывает карту на копии боя и говорит, что изменится.
# Возвращает {"moves": [{"from": клетка, "to": клетка}], "deaths": [клетки], "damage": {клетка: урон}}.
func ghost_preview(h: BattleUnit, index: int, target: Vector2i) -> Dictionary:
	var result: Dictionary = {"moves": [] as Array[Dictionary], "deaths": [] as Array[Vector2i], "damage": {}}
	if not can_play(h, index):
		return result
	var sim: BattleLogic = clone()
	var sim_h: BattleUnit = null
	for hero in sim.heroes:
		if hero.id == h.id:
			sim_h = hero
	if sim_h == null:
		return result
	sim_h.hand = h.hand.duplicate()
	sim_h.discount = h.discount
	for key: String in ctx.hex_moved:
		sim.ctx.hex_moved[key] = ctx.hex_moved[key]
	for key: String in ctx.straight_moved:
		sim.ctx.straight_moved[key] = ctx.straight_moved[key]
	for key: String in ctx.attack_cards:
		sim.ctx.attack_cards[key] = ctx.attack_cards[key]
	sim.ctx.last_card_owner = ctx.last_card_owner
	sim._aether = _aether
	var units_before: Array[BattleUnit] = heroes + enemies
	var cells_before: Dictionary = {}
	var hp_before: Dictionary = {}
	for u in units_before:
		cells_before[u.id] = u.cell
		hp_before[u.id] = u.hp
	if not sim.play_card(sim_h, index, target):
		return result
	for u in sim.heroes + sim.enemies:
		if not cells_before.has(u.id):
			continue
		var old_cell: Vector2i = cells_before[u.id]
		var lost: int = hp_before[u.id] - u.hp
		if not u.is_alive():
			(result["deaths"] as Array[Vector2i]).append(old_cell)
		elif u.cell != old_cell:
			(result["moves"] as Array[Dictionary]).append({"from": old_cell, "to": u.cell})
		if lost > 0 and not u.is_hero:
			(result["damage"] as Dictionary)[old_cell] = lost
	return result


# Какие реакции стихий сработают, если сыграть карту в клетку target (для значков при наведении).
# Возвращает [{cell, kind}] — kind: "steam", "freeze", "shatter", "lava", "crust".
func predict_reactions(h: BattleUnit, index: int, target: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if index < 0 or index >= h.hand.size():
		return result
	var card: CardData = h.hand[index]
	# Молния (или «Руна бури») по мокрому врагу: +WET_SHOCK_BONUS
	var shocking: bool = card.damage > 0 and (card.element == CardData.Element.LIGHTNING \
			or (h.rune == "storm" and h.rune_hits > 0))
	if shocking:
		var shock_area: Array[Vector2i] = get_card_area(h, index, target)
		if card.element == CardData.Element.LIGHTNING:
			shock_area = _spread_through_water(shock_area)
		for c in shock_area:
			var wet_unit: BattleUnit = unit_at(c)
			if wet_unit != null and not wet_unit.is_hero and is_wet(wet_unit):
				result.append({"cell": c, "kind": "shock"})
	if card.element == CardData.Element.NONE or card.special == "flood":
		return result
	for c in get_card_area(h, index, target):
		if not is_inside(c) or rocks.has(c):
			continue
		var obj: int = object_at(c)
		var tile: int = tile_at(c)
		if obj == Obj.LAVA and card.element != CardData.Element.FIRE:
			result.append({"cell": c, "kind": "crust"})
		elif obj == Obj.BOG and card.element == CardData.Element.FIRE:
			result.append({"cell": c, "kind": "lava"})
		elif card.element == CardData.Element.FIRE:
			if obj == Obj.ICE_BLOCK or (obj == Obj.NONE and tile == Tile.ICE):
				result.append({"cell": c, "kind": "shatter"})
			elif obj == Obj.NONE and tile == Tile.WATER:
				result.append({"cell": c, "kind": "steam"})
		elif card.element == CardData.Element.ICE and obj == Obj.NONE and tile == Tile.WATER:
			var u: BattleUnit = unit_at(c)
			if u != null and not u.is_hero:
				result.append({"cell": c, "kind": "freeze"})
	return result


# ---------- Статусы, руны, удержание карт ----------

# Юнит прошёл по клеткам path (ход, толчок, таран, прыжок): лужа мочит,
# сторожевая руна взрывается под врагом. Вызывается после любого перемещения.
func _walked(u: BattleUnit, path: Array[Vector2i]) -> void:
	if u == null:
		return
	for c in path:
		if tile_at(c) == Tile.WATER:
			_set_wet(u, WET_TURNS)
	# Трясина и газ: срабатывают на каждой клетке пути, куда вошли (начальную не считаем)
	for i in range(1, path.size()):
		if not u.is_alive():
			return
		var t: int = tile_at(path[i])
		if t == Tile.SWAMP and u.is_hero and u.moves_left > 0:
			u.moves_left = maxi(0, u.moves_left - SWAMP_STEP_COST)
			message.emit("%s увяз в трясине" % u.title)
		elif t == Tile.GAS:
			_gas_hit(u)
	if u.is_hero:
		return
	for i in range(1, path.size()):
		if not u.is_alive():
			return
		if object_at(path[i]) == Obj.RUNE:
			_trigger_rune(path[i], u)


func _always_wet(u: BattleUnit) -> bool:
	return u.data != null and u.data.always_wet


# Мокрый ли юнит: статус, лужа под ногами или «всегда мокрый» враг (топляк, жаба)
func is_wet(u: BattleUnit) -> bool:
	return u.wet > 0 or tile_at(u.cell) == Tile.WATER or _always_wet(u)


# Сколько раундов «Мокрого» показывать на плашке (0 — сухой)
func wet_turns(u: BattleUnit) -> int:
	if tile_at(u.cell) == Tile.WATER or _always_wet(u):
		return WET_TURNS
	return u.wet


func _set_wet(u: BattleUnit, turns: int) -> void:
	if u == null or not u.is_alive() or u.wet == turns:
		return
	u.wet = turns
	status_changed.emit(u, snapshot(u))


# Урон карты героя по врагу: молния по мокрому сильнее; запоминаем задетых для рун
func _card_damage(u: BattleUnit, amount: int, pierce: bool) -> void:
	if _lightning_now and is_wet(u):
		amount += WET_SHOCK_BONUS
		reaction.emit(u.cell, "shock")
	if not _hit_enemies.has(u):
		_hit_enemies.append(u)
	_damage(u, amount, pierce)


# Руна на оружии рыцаря срабатывает после карты с уроном, задевшей врага.
# Одна карта — один удар руны, сколько бы врагов она ни задела.
func _apply_weapon_rune(h: BattleUnit, card: CardData, from: Vector2i) -> void:
	if h.rune == "" or h.rune_hits <= 0 or card.damage <= 0 or _hit_enemies.is_empty():
		return
	for e in _hit_enemies:
		if not e.is_alive():
			continue
		match h.rune:
			"fire":
				_apply_element(e.cell, CardData.Element.FIRE, from)
			"rot":
				_set_poison(e, POISON_TURNS)
	h.rune_hits -= 1
	if h.rune_hits <= 0:
		h.rune = ""
		message.emit("Руна на клинке погасла")
	status_changed.emit(h, snapshot(h))


func _set_poison(u: BattleUnit, turns: int) -> void:
	if u == null or not u.is_alive():
		return
	u.poison = maxi(u.poison, turns)
	message.emit("%s отравлен" % u.title)
	status_changed.emit(u, snapshot(u))


# Конец раунда: яд ранит мимо блока; «Мокрый» высыхает (в луже — нет, в огне — сразу)
func _tick_statuses() -> void:
	for u in living_enemies() + living_heroes():
		if not u.is_alive():
			continue
		if tile_at(u.cell) == Tile.GAS:
			_gas_hit(u)   # закончил раунд в газу
			if not u.is_alive():
				continue
		if u.poison > 0:
			u.poison -= 1
			message.emit("%s страдает от яда" % u.title)
			_damage(u, POISON_DAMAGE, true)
			if u.is_alive():
				status_changed.emit(u, snapshot(u))
		if not u.is_alive() or u.wet <= 0:
			continue
		if tile_at(u.cell) == Tile.FIRE:
			_set_wet(u, 0)
		elif tile_at(u.cell) != Tile.WATER:
			_set_wet(u, u.wet - 1)


# Сторожевая руна взрывается: урон врагам на её клетке и четырёх соседних.
# Героев не ранит, деревья и бочки не трогает. walker — враг, который на неё наступил
# (он уже мог уйти дальше по пути, но урон получает).
func _trigger_rune(c: Vector2i, walker: BattleUnit = null) -> void:
	if object_at(c) != Obj.RUNE:
		return
	_set_object(c, Obj.NONE, Vector2i.ZERO)
	message.emit("Сторожевая руна срабатывает!")
	var cells: Array[Vector2i] = []
	for t in HexMath.cluster(c):
		if is_inside(t):
			cells.append(t)
	effect_cells.emit(cells, "rune")
	var victims: Array[BattleUnit] = []
	if walker != null and walker.is_alive():
		victims.append(walker)
	for t in cells:
		var u: BattleUnit = unit_at(t)
		if u != null and not u.is_hero and not victims.has(u):
			victims.append(u)
	for u in victims:
		_damage(u, RUNE_TRAP_DAMAGE)


# --- Удержание карт (режим KEEP_2) ---

func is_kept(h: BattleUnit, index: int) -> bool:
	return h.kept.has(index)


func can_keep(h: BattleUnit, index: int) -> bool:
	return DRAW_MODE == DrawMode.KEEP_2 and not is_over and h.is_alive() \
			and index >= 0 and index < h.hand.size()


# Отметить карту «удержать на следующий ход» или снять отметку.
# Возвращает false, если отметить нельзя (уже KEEP_LIMIT карт или неверный номер).
func toggle_keep(h: BattleUnit, index: int) -> bool:
	if not can_keep(h, index):
		return false
	if h.kept.has(index):
		h.kept.erase(index)
	elif h.kept.size() >= KEEP_LIMIT:
		return false
	else:
		h.kept.append(index)
	status_changed.emit(h, snapshot(h))
	return true


# Карта ушла из руки: её отметка пропадает, номера карт правее сдвигаются
func _forget_kept(h: BattleUnit, index: int) -> void:
	var updated: Array[int] = []
	for k in h.kept:
		if k < index:
			updated.append(k)
		elif k > index:
			updated.append(k - 1)
	h.kept = updated


# Конец хода в режиме KEEP_2: в сброс уходит всё, кроме отмеченных карт
func _discard_unkept(h: BattleUnit) -> void:
	var stay: Array[CardData] = []
	for i in h.hand.size():
		if h.is_alive() and h.kept.has(i):
			stay.append(h.hand[i])
		else:
			h.discard_pile.append(h.hand[i])
	h.hand = stay
	h.kept.clear()
	# OnRetain: карты, оставшиеся в руке, копят бонус
	var retained: Dictionary = {}
	for c in stay:
		retained[c] = mini(RETAIN_MAX, int(h.retain_turns.get(c, 0)) + 1)
	h.retain_turns = retained
