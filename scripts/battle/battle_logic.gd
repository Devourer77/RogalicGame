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
signal message(text: String)

# Что лежит на клетке поля (стихия на поверхности — по ней можно ходить)
enum Tile { NONE, FIRE, WATER, ICE }

# Объекты поля (Гнилые топи). Один объект на клетку.
enum Obj {
	NONE,
	BOG,     # трясина: не пройти; столкнул врага — он тонет; лёд её замораживает
	TREE,    # мёртвое дерево: преграда; удар или огонь — падает и бьёт линию из 3 клеток
	BARREL,  # бочка с болотным газом: преграда; удар или огонь — взрыв крестом и поджог
	PLANKS,  # гнилые мостки: проходимы, но ломаются в трясину, когда с них уходят
	REEDS,   # камыш: проходим, закрывает удары по линии, горит и поджигает соседний камыш
	ICE_BLOCK,  # ледяная глыба мага: преграда, тает от огня или сама через несколько ходов
	STAKES,     # частокол рыцаря: преграда; врезавшийся в него получает больше урона
	BRIDGE,     # крепкие мостки рыцаря поверх трясины: проходимы и не ломаются
}

const HAND_SIZE: int = 5        # сколько карт каждый герой берёт в начале хода
const MAX_HAND: int = 10
const BUMP_DAMAGE: int = 2      # урон, если толкнутый врезался в препятствие
const FIRE_DAMAGE: int = 2      # урон от огня в конце раунда
const FIRE_DURATION: int = 3    # сколько раундов горит огонь
const TREE_DAMAGE: int = 4      # урон от упавшего дерева
const TREE_LENGTH: int = 3      # на сколько клеток падает дерево
const BARREL_DAMAGE: int = 4    # урон от взрыва бочки
const BOSS_BOG_DAMAGE: int = 8  # босс не тонет, но трясина его ранит
const HERO_BOG_DAMAGE: int = 4  # герой не тонет: трясина для него как стена с таким уроном
const STAKES_BUMP_DAMAGE: int = 4  # урон, если толкнули в частокол
const MAX_CHARGE: int = 5          # обычный предел заряда мага
const MAX_CHARGE_OVERLOAD: int = 10  # предел заряда после «Перегрузки»
const MAX_MOMENTUM: int = 5        # предел натиска рыцаря
const ICE_WALL_TURNS: int = 3      # сколько раундов стоит ледяная глыба
const BOG_MAW_TURNS: int = 2       # сколько раундов держится трясина «Пасти топей»
const OUTPOST_DAMAGE: int = 4      # урон «Заставы» врагу на подходе
const EXECUTE_DAMAGE: int = 12     # урон «Добивания» по раненой цели
const CHAIN_JUMPS: int = 2         # сколько раз перескакивает цепная молния
const CHAIN_RADIUS: int = 2        # на какое расстояние она перескакивает
const PULL_HAZARD_BONUS: int = 6    # насколько врагу с притягиванием милее клетка, откуда он затянет героя в беду

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

const ENEMY_ROWS: int = 4        # враги появляются в верхних рядах
const HERO_ROWS: int = 3         # нижние ряды держим свободными для героев

var width: int = 12
var height: int = 12
var rng: RandomNumberGenerator   # общий генератор забега (из Run)

var heroes: Array[BattleUnit] = []
var enemies: Array[BattleUnit] = []
var rocks: Dictionary[Vector2i, bool] = {}     # клетки с камнями (непроходимые, неразрушимые)
var objects: Dictionary[Vector2i, int] = {}    # клетка -> Obj
var tiles: Dictionary[Vector2i, int] = {}      # клетка -> Tile (огонь/вода/лёд)
var fire_timers: Dictionary[Vector2i, int] = {}  # сколько раундов ещё горит клетка
var obj_timers: Dictionary[Vector2i, int] = {}   # сколько раундов ещё простоит временный объект
var ground: Dictionary[Vector2i, int] = {}     # клетка -> Ground (вид плиты)
var arena_id: String = ""                      # какая арена (ключ из ARENAS)

var turn: int = 0
var is_over: bool = false
var won: bool = false
var _next_id: int = 0


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
		h.cell = Vector2i(start_x + i, height - 2)
		h.draw_pile = rh.deck.duplicate()
		_shuffle(h.draw_pile)
		heroes.append(h)

	_generate_field()

	# Враги — в верхних рядах, на свободных клетках
	for enemy_data: EnemyData in enemy_list:
		var c: Vector2i = _random_free_cell(0, ENEMY_ROWS - 1)
		if c.x < 0:
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
		if _field_is_open() and _free_enemy_cells() >= MIN_ENEMY_CELLS:
			_paint_ground()
			return
	# Не получилось (почти невозможно) — чистое поле
	rocks.clear()
	objects.clear()
	tiles.clear()
	ground.clear()
	_paint_ground()


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
			var c := Vector2i(x, row + dy)
			if gaps.has(x):
				continue
			objects[c] = Obj.PLANKS if x == plank_x else Obj.BOG
		if gaps.has(x):
			for y in range(row - 2, row + 4):
				ground[Vector2i(x, y)] = Ground.PLANKS   # бревенчатая дорога через топь
			# Бочка у входа на переправу со стороны врагов
			if not gaps.has(x - 1) and rng.randf() < 0.8:
				var side: int = 1 if x < width / 2 else -1
				if gaps.has(x + side):
					side = -side
				_put(Vector2i(x + side, row - 1), Obj.BARREL)
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
				_put(Vector2i(1 + gx * 2 + line % 2, gy), Obj.TREE)
		line += 1
	# Бочки — вплотную к деревьям: взрыв валит дерево
	var trees: Array[Vector2i] = _cells_with(Obj.TREE)
	for i in 3:
		if trees.is_empty():
			break
		var t: Vector2i = trees[rng.randi_range(0, trees.size() - 1)]
		_put(t + GridShapes.DIRS[rng.randi_range(0, 3)], Obj.BARREL)
	for c in _grow_from(Vector2i(0, rng.randi_range(3, 6)), 4, 1, 8):
		objects[c] = Obj.REEDS
	for c in _grow_from(Vector2i(width - 1, rng.randi_range(3, 6)), 4, 1, 8):
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
	var center := Vector2i(rng.randi_range(4, 7), rng.randi_range(4, 5))
	var pond: Array[Vector2i] = _grow_from(center, 11, 2, 7)
	for c in pond:
		tiles[c] = Tile.WATER
	# Топкое дно: середина пруда — трясина
	for i in mini(3, pond.size()):
		tiles.erase(pond[i])
		objects[pond[i]] = Obj.BOG
	for c in _grow_from(Vector2i(rng.randi_range(0, 1), rng.randi_range(3, 6)), 8, 1, 8):
		objects[c] = Obj.REEDS
	for c in _grow_from(Vector2i(width - 1 - rng.randi_range(0, 1), rng.randi_range(3, 6)), 8, 1, 8):
		objects[c] = Obj.REEDS
	for c in _grow_from(Vector2i(rng.randi_range(3, 8), 8), 4, 7, 8):
		objects[c] = Obj.REEDS
	# Бочки у самого камыша: один взрыв — и горит вся заросль
	var reeds: Array[Vector2i] = _cells_with(Obj.REEDS)
	for i in 2:
		if reeds.is_empty():
			break
		var r: Vector2i = reeds[rng.randi_range(0, reeds.size() - 1)]
		_put(r + GridShapes.DIRS[rng.randi_range(0, 3)], Obj.BARREL)
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
			objects[Vector2i(x, wall_row)] = Obj.STAKES
	for y in range(wall_row + 1, wall_row + 3):
		if rng.randf() < 0.8:
			objects[Vector2i(2, y)] = Obj.STAKES
		if rng.randf() < 0.8:
			objects[Vector2i(width - 3, y)] = Obj.STAKES
	for x in range(3, width - 3):
		for y in range(wall_row + 1, height - HERO_ROWS):
			ground[Vector2i(x, y)] = Ground.PLANKS   # помост внутри заставы
	for g in gates:
		ground[Vector2i(g, wall_row)] = Ground.PLANKS
	# Склад: бочки кучкой внутри, ящики у стен
	var store := Vector2i(rng.randi_range(4, 7), rng.randi_range(6, 7))
	_put(store, Obj.BARREL)
	_put(store + Vector2i(1 if rng.randf() < 0.5 else -1, 0), Obj.BARREL)
	_put(store + Vector2i(0, -1), Obj.BARREL)
	_put_rock(Vector2i(3, wall_row + 1))
	_put_rock(Vector2i(width - 4, wall_row + rng.randi_range(1, 2)))
	# Снаружи: бочка у ворот, ров-трясина сбоку, пара деревьев
	_put(Vector2i(gates[rng.randi_range(0, 1)] + 1, wall_row - 1), Obj.BARREL)
	var side_x: int = 0 if rng.randf() < 0.5 else width - 1
	for c in _grow_from(Vector2i(side_x, rng.randi_range(4, 6)), 4, 3, 8):
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
				rocks[Vector2i(x, y)] = true
	for y: int in [3, 6]:
		for x: int in [4, width - 5]:
			if rng.randf() < 0.6:
				rocks[Vector2i(x, y)] = true
	for i in 3:
		var start: Vector2i = _random_free_cell(2, 7)
		for c in _grow_from(start, rng.randi_range(5, 7), 1, 8):
			tiles[c] = Tile.WATER
	for c in _grow_from(Vector2i(0, rng.randi_range(4, 6)), 3, 3, 8):
		objects[c] = Obj.BOG
	for c in _grow_from(Vector2i(width - 1, rng.randi_range(4, 6)), 3, 3, 8):
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
		for c in _grow_from(Vector2i(side_x, rng.randi_range(3, 6)), 4, 2, 8):
			objects[c] = Obj.BOG
	for c: Vector2i in [Vector2i(3, 3), Vector2i(width - 4, 3), Vector2i(3, 7), Vector2i(width - 4, 7)]:
		_put(c + Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1)), Obj.TREE)
	for i in 3:
		_put(Vector2i(rng.randi_range(3, width - 4), rng.randi_range(4, 7)), Obj.BARREL)
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
	for y in ENEMY_ROWS:
		for x in width:
			if _is_empty(Vector2i(x, y)):
				n += 1
	return n


# Красит покрытие клеток: грязь у трясины, воды и камыша, мох под деревьями и местами
func _paint_ground() -> void:
	var moss_chance: float = 0.45 if arena_id == "grove" else (0.08 if arena_id == "ruins" else 0.22)
	for x in width:
		for y in height:
			var c := Vector2i(x, y)
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
				for d: Vector2i in GridShapes.DIRS:
					if object_at(c + d) == Obj.BOG or object_at(c + d) == Obj.PLANKS:
						kind = Ground.MUD
			ground[c] = kind


# Ставит что-то на случайную пустую клетку
func _place(min_row: int, max_row: int, put: Callable) -> void:
	var c: Vector2i = _random_free_cell(min_row, max_row)
	if c.x >= 0:
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
		var c: Vector2i = from + GridShapes.DIRS[rng.randi_range(0, 3)]
		if c.y >= min_row and c.y <= max_row and _is_empty(c) and not patch.has(c):
			patch.append(c)
	return patch


# Поле «открыто», если от героев можно дойти почти до всех проходимых клеток
func _field_is_open() -> bool:
	var walkable: int = 0
	for x in width:
		for y in height:
			if not _is_obstacle(Vector2i(x, y)):
				walkable += 1
	var reached: Dictionary[Vector2i, bool] = {heroes[0].cell: true}
	var frontier: Array[Vector2i] = [heroes[0].cell]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		for d: Vector2i in GridShapes.DIRS:
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
			"charge": u.charge, "momentum": u.momentum, "entangled": u.entangled}
	if u.data != null:
		# Что враг собирается сделать в этом раунде — для надписи над головой
		var atk: EnemyAttackData = enemy_attack(u)
		state["intent"] = atk.title
		state["damage"] = atk.damage + u.bonus_damage if atk.shape != EnemyData.Attack.AURA else 0
	return state


# ---------- Вопросы к полю ----------

func is_inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < width and c.y >= 0 and c.y < height


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
	return o == Obj.BOG or o == Obj.TREE or o == Obj.BARREL or o == Obj.ICE_BLOCK or o == Obj.STAKES


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
		for d: Vector2i in GridShapes.DIRS:
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
	h.cell = cell
	unit_moved.emit(h, path)
	_break_planks_behind(path)
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
	return not is_over and h.is_alive() and index >= 0 and index < h.hand.size() \
			and card_cost(h, index) <= h.mana


# Сколько маны реально стоит карта (с учётом скидки «Сосредоточения»)
func card_cost(h: BattleUnit, index: int) -> int:
	return maxi(0, h.hand[index].cost - h.discount)


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
			# Линия: любая клетка в одной из 4 сторон, до первой преграды
			for d: Vector2i in GridShapes.DIRS:
				result.append_array(_line_cells(h.cell, d, card.cast_range, pierce))
		CardData.Shape.ARC:
			# Дуга: выбираем соседнюю клетку — в ту сторону и замах
			for d: Vector2i in GridShapes.DIRS:
				if is_inside(h.cell + d):
					result.append(h.cell + d)
		CardData.Shape.CHARGE:
			for d: Vector2i in GridShapes.DIRS:
				if card.special == "pass_through":
					result.append_array(_pass_lane(h, d, card.cast_range))
					continue
				# Таран: клетки разбега в каждую сторону и то, во что врежется
				var charge: Dictionary = _charge_plan(h, d, card.cast_range)
				var path: Array[Vector2i] = charge["path"]
				for i in range(1, path.size()):
					result.append(path[i])
				var hit_cell: Vector2i = charge["hit_cell"]
				if hit_cell.x >= 0:
					result.append(hit_cell)
		CardData.Shape.ALLY:
			for other in living_heroes():
				if card.special == "swap" and other == h:
					continue
				if GridShapes.manhattan(h.cell, other.cell) <= card.cast_range:
					result.append(other.cell)
		CardData.Shape.LEAP:
			# Прыжок: любая свободная проходимая клетка в пределах дальности, сквозь преграды
			for x in width:
				for y in height:
					var c := Vector2i(x, y)
					var dist: int = GridShapes.manhattan(h.cell, c)
					if dist >= 1 and dist <= card.cast_range and not is_blocked(c):
						result.append(c)
		CardData.Shape.FELL:
			# Клетки рядом с соседним деревом: в сторону выбранной клетки оно и упадёт
			for t: Vector2i in _adjacent_trees(h):
				for d: Vector2i in GridShapes.DIRS:
					var c: Vector2i = t + d
					if c != h.cell and is_inside(c) and not result.has(c):
						result.append(c)
		_:
			for x in width:
				for y in height:
					var c := Vector2i(x, y)
					var dist: int = GridShapes.manhattan(h.cell, c)
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
		"stakes":
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
	for d: Vector2i in GridShapes.DIRS:
		if object_at(h.cell + d) == Obj.TREE:
			trees.append(h.cell + d)
	return trees


# Для «Свалить дерево»: какое дерево и в какую сторону упадёт, если выбрать клетку c
func _fell_choice(h: BattleUnit, c: Vector2i) -> Dictionary:
	for t: Vector2i in _adjacent_trees(h):
		if GridShapes.manhattan(t, c) == 1 and c != h.cell:
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
	var d: Vector2i = GridShapes.cardinal_dir(h.cell, target)
	match card.shape:
		CardData.Shape.SELF:
			cells.append(h.cell)
		CardData.Shape.SINGLE, CardData.Shape.ALLY:
			cells.append(target)
		CardData.Shape.LINE:
			cells = _line_cells(h.cell, d, card.cast_range, card.special == "pierce")
		CardData.Shape.CROSS:
			cells = GridShapes.cross_cells(target)
		CardData.Shape.SQUARE:
			cells = GridShapes.square_cells(target)
		CardData.Shape.ARC:
			var side: Vector2i = GridShapes.perpendicular(d)
			cells.append(target)
			cells.append(target + side)
			cells.append(target - side)
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
				if hit_cell.x >= 0:
					cells.append(hit_cell)
		CardData.Shape.WALL:
			var side: Vector2i = GridShapes.perpendicular(d)
			cells.append(target)
			cells.append(target + side)
			cells.append(target - side)
		CardData.Shape.LEAP:
			for n: Vector2i in GridShapes.DIRS:
				cells.append(target + n)
		CardData.Shape.AROUND:
			for c in GridShapes.square_cells(h.cell):
				if c != h.cell:
					cells.append(c)
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
	var area: Array[Vector2i] = get_card_area(h, index, target)
	h.mana -= card_cost(h, index)
	h.discount = 0   # скидка действует на одну карту
	h.hand.remove_at(index)
	h.discard_pile.append(card)
	message.emit("%s: %s" % [h.title, card.title])
	_resolve_card(h, card, area, target)
	_check_end()
	return true


# Применяет эффекты карты по порядку:
# бонусы урона → движение (таран, прыжок) → урон и объекты → стихия → толчок →
# особые действия → защита и прочее → «Неудержимый»
func _resolve_card(h: BattleUnit, card: CardData, area: Array[Vector2i], target: Vector2i) -> void:
	var hit_cells: Array[Vector2i] = area
	if card.element == CardData.Element.LIGHTNING:
		hit_cells = _spread_through_water(area)
	var dir: Vector2i = GridShapes.cardinal_dir(h.cell, target)
	var from: Vector2i = h.cell
	var alive_before: Array[BattleUnit] = living_enemies()

	# Ярость, заряд и натиск, накопленные до этой карты, усиливают её урон и сгорают
	var damage: int = card.damage
	if damage > 0:
		damage += _spend_bonuses(h, card)

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
					return GridShapes.manhattan(a.cell, from) > GridShapes.manhattan(b.cell, from))
				for u in targets:
					if u.is_alive():
						_push(u, GridShapes.cardinal_dir(from, u.cell), card.push)

	if card.special != "":
		_resolve_special(h, card, area, target, dir)

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
			_damage(u, dealt, card.pierce_block)
		elif _is_breakable(c) and card.special != "pierce":
			_hit_object(c, from)


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
	card_cast.emit(h, card, hit_cells)
	var hit_cell: Vector2i = charge["hit_cell"]
	var victim: BattleUnit = unit_at(hit_cell) if hit_cell.x >= 0 else null
	if victim != null and not victim.is_hero:
		_damage(victim, damage, card.pierce_block)
		if card.push > 0 and victim.is_alive():
			_push(victim, dir, card.push)
	elif hit_cell.x >= 0 and _is_breakable(hit_cell):
		_hit_object(hit_cell, h.cell)
	_add_momentum(h, path.size() - 1)


# Сквозной таран: герой бежит насквозь, каждого врага на пути ранит
# и откидывает на клетку в сторону. Не отлетел — герой останавливается перед ним.
func _pass_through_charge(h: BattleUnit, card: CardData, dir: Vector2i, damage: int, hit_cells: Array[Vector2i]) -> void:
	card_cast.emit(h, card, hit_cells)
	var path: Array[Vector2i] = [h.cell]
	var side: Vector2i = GridShapes.perpendicular(dir)
	for c in _pass_lane(h, dir, card.cast_range):
		var u: BattleUnit = unit_at(c)
		if u != null and not u.is_hero:
			_damage(u, damage, card.pierce_block)
			if u.is_alive():
				var push_dir: Vector2i = side if not is_blocked(c + side) else -side
				_push(u, push_dir, 1)
			if u.is_alive() and u.cell == c:
				break   # враг не отлетел — дальше не пробежать
		path.append(c)
	if path.size() > 1:
		h.cell = path[path.size() - 1]
		unit_moved.emit(h, path)
		_break_planks_behind(path)
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
			var dist: int = GridShapes.manhattan(last.cell, e.cell)
			if not chain.has(e) and dist <= CHAIN_RADIUS and dist < best_dist:
				best = e
				best_dist = dist
		if best == null:
			break
		chain.append(best)
	return chain


func _chain_damage(chain: Array[BattleUnit], damage: int, pierce: bool) -> void:
	for i in chain.size():
		_damage(chain[i], maxi(1, damage - i), pierce)   # каждый прыжок слабее на 1


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
				if GridShapes.manhattan(h.cell, e.cell) <= 3:
					near.append(e)
			near.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
				return GridShapes.manhattan(a.cell, h.cell) > GridShapes.manhattan(b.cell, h.cell))
			message.emit("Звон Колокола Стражи!")
			for e in near:
				if e.is_alive():
					_push(e, GridShapes.cardinal_dir(h.cell, e.cell), 1)


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
# Возвращает {"path": путь от его клетки, "hit_cell": клетка удара или (-1, -1)}.
# Врезаться можно в юнита, дерево или бочку; трясину и камни таран не бьёт.
func _charge_plan(h: BattleUnit, dir: Vector2i, max_steps: int) -> Dictionary:
	var path: Array[Vector2i] = [h.cell]
	var hit_cell := Vector2i(-1, -1)
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
			_fell_tree(c, GridShapes.cardinal_dir(from, c))
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
		if _is_breakable(t):
			_hit_object(t, c)


# Бочка взрывается: урон крестом и поджог
func _explode_barrel(c: Vector2i) -> void:
	_set_object(c, Obj.NONE, Vector2i.ZERO)
	message.emit("Бочка с газом взрывается!")
	var cells: Array[Vector2i] = []
	for t in GridShapes.cross_cells(c):
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
		_apply_element(t, CardData.Element.FIRE, c)


# Молния: если попала в лужу — бьёт по всем клеткам этой лужи
func _spread_through_water(area: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = area.duplicate()
	var queue: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for c in area:
		if tile_at(c) == Tile.WATER:
			queue.append(c)
			seen[c] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if not result.has(c):
			result.append(c)
		for d: Vector2i in GridShapes.DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and tile_at(n) == Tile.WATER:
				seen[n] = true
				queue.append(n)
	# «Водные» враги (жаба): молния в соседней луже достаёт и их
	for e in living_enemies():
		if not e.data.aquatic or result.has(e.cell):
			continue
		for d: Vector2i in GridShapes.DIRS:
			if seen.has(e.cell + d):
				result.append(e.cell)
				break
	return result


# Правила стихий: огонь испаряет воду, топит лёд и поджигает объекты,
# вода и лёд тушат огонь, лёд замораживает трясину (по ней можно пройти).
# from — откуда пришла стихия (нужно, чтобы горящее дерево упало от героя).
func _apply_element(c: Vector2i, element: CardData.Element, from: Vector2i) -> void:
	if not is_inside(c) or rocks.has(c):
		return
	var obj: int = object_at(c)
	if element == CardData.Element.FIRE:
		if obj == Obj.TREE or obj == Obj.BARREL:
			_hit_object(c, from)
			return
		if obj == Obj.REEDS:
			_burn_reeds(c)
			return
		if obj == Obj.BOG or obj == Obj.PLANKS or obj == Obj.BRIDGE:
			return   # мокрое не горит
		if obj == Obj.ICE_BLOCK:
			_set_object(c, Obj.NONE, Vector2i.ZERO)
			_set_tile(c, Tile.WATER)
			message.emit("Ледяная глыба тает")
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
				new_tile = Tile.NONE   # пар
			elif old == Tile.ICE:
				new_tile = Tile.WATER  # лёд тает
			else:
				new_tile = Tile.FIRE
		CardData.Element.WATER:
			new_tile = Tile.NONE if old == Tile.FIRE else Tile.WATER
		CardData.Element.ICE:
			new_tile = Tile.NONE if old == Tile.FIRE else Tile.ICE
		_:
			return
	_set_tile(c, new_tile)


# Камыш сгорает и поджигает соседний камыш — пожар бежит по зарослям
func _burn_reeds(c: Vector2i) -> void:
	var queue: Array[Vector2i] = [c]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if object_at(cur) != Obj.REEDS:
			continue
		_set_object(cur, Obj.NONE, Vector2i.ZERO)
		_set_tile(cur, Tile.FIRE)
		for d: Vector2i in GridShapes.DIRS:
			if object_at(cur + d) == Obj.REEDS:
				queue.append(cur + d)


func _set_tile(c: Vector2i, tile: int) -> void:
	if tile_at(c) == tile and tile != Tile.FIRE:
		return
	if tile == Tile.NONE:
		tiles.erase(c)
	else:
		tiles[c] = tile
	if tile == Tile.FIRE:
		fire_timers[c] = FIRE_DURATION
		_burn_off_block(unit_at(c))
	else:
		fire_timers.erase(c)
	tile_changed.emit(c, tile)


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
	var bump_cell := Vector2i(-1, -1)
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
	unit_pushed.emit(unit, path, bumped)
	_break_planks_behind(path)
	if drowned:
		message.emit("%s тонет в трясине!" % unit.title)
		_kill(unit)
		return
	if bumped:
		message.emit("%s врезается!" % unit.title)
		var bump_damage: int = BUMP_DAMAGE
		var other: BattleUnit = unit_at(bump_cell)
		if other == null and object_at(bump_cell) == Obj.BOG:
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


# Жаба, погибая, лопается: урон четырём соседям (и своим, и чужим), удар по
# деревьям и бочкам рядом, на её клетке остаётся лужа. Утонула — взрыва нет
# (тогда вызывается _kill, а не _damage).
func _death_blast(unit: BattleUnit) -> void:
	if unit.data == null or unit.data.death_blast <= 0:
		return
	message.emit("%s лопается: газовый хлопок!" % unit.title)
	var cells: Array[Vector2i] = []
	for d: Vector2i in GridShapes.DIRS:
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


# Мгновенная смерть (утонул)
func _kill(unit: BattleUnit) -> void:
	unit.hp = 0
	unit.block = 0
	unit_damaged.emit(unit, 0, snapshot(unit))
	unit_died.emit(unit)


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
	for h in living_heroes():
		if h.block > 0 or h.taunt:
			h.block = 0
			h.taunt = false
			status_changed.emit(h, snapshot(h))
		h.mana = h.hero_data.mana_per_turn
		h.moves_left = h.hero_data.moves_per_turn
		h.discount = 0
		h.outpost = false
		h.momentum = 0
		if h.entangled > 0:
			h.moves_left = 0   # опутан: шагов нет, но карты играть можно
			h.entangled -= 1
			message.emit("%s опутан: в этот ход без шагов" % h.title)
		status_changed.emit(h, snapshot(h))
		_draw_cards(h, HAND_SIZE)
	# У врагов с циклом ударов в новом раунде другой удар — обновляем надписи
	for e in living_enemies():
		if e.data.cycle.size() > 1:
			status_changed.emit(e, snapshot(e))
	message.emit("— Ход %d —" % turn)


# Герои закончили ход: враги подходят и бьют, потом жжёт огонь, потом новый ход
func end_turn() -> void:
	if is_over:
		return
	for h in heroes:
		h.discard_pile.append_array(h.hand)
		h.hand.clear()
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
	if _check_end():
		return
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
	_tick_objects()
	if _check_end():
		return

	_start_heroes_turn()


# Временные объекты (ледяные глыбы, «Пасть топей») исчезают по таймеру
func _tick_objects() -> void:
	for c: Vector2i in obj_timers.keys():
		obj_timers[c] -= 1
		if obj_timers[c] <= 0:
			var kind: int = object_at(c)
			_set_object(c, Obj.NONE, Vector2i.ZERO)
			if kind == Obj.ICE_BLOCK:
				_set_tile(c, Tile.WATER)   # глыба растаяла — осталась лужа


# Враги по очереди: подойти и ударить, если герой в досягаемости.
# Возвращает true, если бой закончился.
func _enemies_act() -> bool:
	_start_enemy_phase()
	for e in enemies:
		if not e.is_alive():
			continue
		var atk: EnemyAttackData = enemy_attack(e)
		var start: Vector2i = e.cell
		var dir: Vector2i = _enemy_move(e, atk)
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
	for u in victims:
		if not u.is_alive():
			continue
		if atk.puddle and object_at(u.cell) == Obj.NONE:
			_apply_element(u.cell, CardData.Element.WATER, e.cell)
		if atk.entangle > 0:
			u.entangled = maxi(u.entangled, atk.entangle)
			message.emit("%s опутан" % u.title)
			status_changed.emit(u, snapshot(u))
	if atk.push > 0:
		# Сначала дальних, чтобы они не мешали ближним
		victims.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return GridShapes.manhattan(a.cell, e.cell) > GridShapes.manhattan(b.cell, e.cell))
		for u in victims:
			if u.is_alive() and e.is_alive():
				_push(u, dir, atk.push)
	elif atk.pull > 0:
		# Притягивание — тот же толчок, только к себе. Сначала ближних.
		victims.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
			return GridShapes.manhattan(a.cell, e.cell) < GridShapes.manhattan(b.cell, e.cell))
		for u in victims:
			var gap: int = GridShapes.manhattan(u.cell, e.cell) - 1   # свободных клеток между ними
			if u.is_alive() and e.is_alive() and gap > 0:
				_push(u, -dir, mini(atk.pull, gap))


# «Зов»: враги в квадрате вокруг (и сам зовущий) получают блок, их следующий удар сильнее
func _enemy_aura(e: BattleUnit, atk: EnemyAttackData) -> void:
	var cells: Array[Vector2i] = _aura_cells(e.cell, atk.attack_range)
	enemy_buffed.emit(e, cells)
	message.emit("%s: %s" % [e.title, atk.title])
	for ally in living_enemies():
		if cells.has(ally.cell):
			ally.block += atk.ally_block
			ally.bonus_damage = maxi(ally.bonus_damage, atk.ally_damage)
			status_changed.emit(ally, snapshot(ally))


# Квадрат со стороной (2 × radius + 1) вокруг клетки
func _aura_cells(center: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var c := center + Vector2i(dx, dy)
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
		if h.outpost and GridShapes.manhattan(h.cell, e.cell) == 1:
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
# "buff": клетки «зова» (кого враг усилит)}.
func forecast_enemies() -> Array[Dictionary]:
	var sim: BattleLogic = clone()
	var by_id: Dictionary[int, Dictionary] = {}
	for e in living_enemies():
		var start_path: Array[Vector2i] = [e.cell]
		var empty: Array[Vector2i] = []
		var no_buff: Array[Vector2i] = []
		by_id[e.id] = {"enemy": e, "path": start_path, "attack": empty, "buff": no_buff}
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
	var result: Array[Dictionary] = []
	result.assign(by_id.values())
	return result


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
		for d: Vector2i in GridShapes.DIRS:
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
			var front: Vector2i = from + dir
			var side: Vector2i = GridShapes.perpendicular(dir)
			cells.append(front)
			cells.append(front + side)
			cells.append(front - side)
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


# Попадает ли удар хотя бы по одному из героев-целей
func _hits_any(cells: Array[Vector2i], targets: Array[BattleUnit]) -> bool:
	for t in targets:
		if cells.has(t.cell):
			return true
	return false


# ИИ врага: найти ближайшую клетку, откуда удар заденет героя, и встать туда.
# Провокация: если враг может достать героя с провокацией — бьёт только его.
# Если ударить некого — подходит к ближайшему герою (по реальному пути, в обход
# трясины и деревьев). Огня избегает. Стрелки держат дистанцию (keep_distance).
# В раунд «зова» враг встаёт так, чтобы накрыть побольше своих.
# Возвращает направление удара (ZERO — ударить не получится).
func _enemy_move(e: BattleUnit, atk: EnemyAttackData) -> Vector2i:
	# Опутанный враг стоит на месте, но ударить может
	var options: Dictionary[Vector2i, Array] = reachable_cells(e, 0 if e.entangled > 0 else e.data.move_range)
	var targets: Array[BattleUnit] = living_heroes()
	var best_cell: Vector2i = e.cell
	var best_dir: Vector2i = Vector2i.ZERO

	if atk.shape == EnemyData.Attack.AURA:
		best_cell = _best_aura_spot(e, atk, options)
	else:
		var taunters: Array[BattleUnit] = []
		for h in targets:
			if h.taunt:
				taunters.append(h)
		var best: Dictionary = _best_attack_spot(e, atk, options, taunters)
		if best["dir"] == Vector2i.ZERO:
			best = _best_attack_spot(e, atk, options, targets)
		best_cell = best["cell"]
		best_dir = best["dir"]

		if best_dir == Vector2i.ZERO:
			var chase: Array[BattleUnit] = taunters if not taunters.is_empty() else targets
			var dist_map: Dictionary[Vector2i, int] = _distance_map(chase, e)
			var best_score: int = 1000000
			for c: Vector2i in options:
				var dist: int = dist_map.get(c, 999)
				var score: int = dist * 10 + options[c].size()
				if tile_at(c) == Tile.FIRE:
					score += 100
				if dist < e.data.keep_distance:
					score += 50   # стрелок вплотную не лезет
				if score < best_score:
					best_score = score
					best_cell = c

	if best_cell != e.cell:
		var path: Array[Vector2i] = options[best_cell]
		e.cell = best_cell
		unit_moved.emit(e, path)
		_break_planks_behind(path)
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
		for d: Vector2i in GridShapes.DIRS:
			var n: Vector2i = cur + d
			if not dist.has(n) and not _is_obstacle_for(walker, n):
				dist[n] = dist[cur] + 1
				frontier.append(n)
	return dist


# Лучшая клетка, откуда враг заденет кого-то из targets. Чем меньше очков, тем лучше:
# 4 очка за шаг, огонь под ногами — 80, стрелку вплотную к герою — 40.
# Тому, кто притягивает, милее клетка, откуда герой влетит в трясину, на мостки или в огонь.
func _best_attack_spot(e: BattleUnit, atk: EnemyAttackData, options: Dictionary[Vector2i, Array],
		targets: Array[BattleUnit]) -> Dictionary:
	var result: Dictionary = {"cell": e.cell, "dir": Vector2i.ZERO}
	if targets.is_empty():
		return result
	var max_bonus: int = PULL_HAZARD_BONUS if atk.pull > 0 else 0
	var best_score: int = 1000000
	for c: Vector2i in options:
		var base: int = (options[c].size() - 1) * 4
		if tile_at(c) == Tile.FIRE:
			base += 80
		if e.data.keep_distance > 0:
			var near: int = 999
			for h in living_heroes():
				near = mini(near, GridShapes.manhattan(c, h.cell))
			if near < e.data.keep_distance:
				base += 40
			base -= mini(near, atk.attack_range)   # при прочих равных — подальше
		if base - max_bonus >= best_score:
			continue
		for d: Vector2i in GridShapes.DIRS:
			var cells: Array[Vector2i] = _attack_cells(e, atk, c, d)
			if not _hits_any(cells, targets):
				continue
			var score: int = base
			if max_bonus > 0 and _pull_into_hazard(c, d, cells, targets):
				score -= max_bonus
			if score < best_score:
				best_score = score
				result = {"cell": c, "dir": d}
	return result


# Затянет ли притягивание героя в беду: между врагом (на клетке from) и героем
# трясина, гнилые мостки или огонь
func _pull_into_hazard(from: Vector2i, dir: Vector2i, cells: Array[Vector2i], targets: Array[BattleUnit]) -> bool:
	for t in targets:
		if not cells.has(t.cell) or GridShapes.manhattan(from, t.cell) < 2:
			continue
		var mid: Vector2i = t.cell - dir
		var o: int = object_at(mid)
		if o == Obj.BOG or o == Obj.PLANKS or tile_at(mid) == Tile.FIRE:
			return true
	return false


# Клетка для «зова»: откуда квадрат накроет больше всего других врагов.
# При равенстве — та, до которой ближе идти; огня избегает.
func _best_aura_spot(e: BattleUnit, atk: EnemyAttackData, options: Dictionary[Vector2i, Array]) -> Vector2i:
	var best_cell: Vector2i = e.cell
	var best_score: int = -1000000
	for c: Vector2i in options:
		var allies: int = 0
		for other in living_enemies():
			if other != e and absi(other.cell.x - c.x) <= atk.attack_range \
					and absi(other.cell.y - c.y) <= atk.attack_range:
				allies += 1
		var score: int = allies * 100 - (options[c].size() - 1)
		if tile_at(c) == Tile.FIRE:
			score -= 50
		if score > best_score:
			best_score = score
			best_cell = c
	return best_cell


# Случайная пустая клетка в рядах от min_row до max_row
func _random_free_cell(min_row: int, max_row: int) -> Vector2i:
	var free: Array[Vector2i] = []
	for y in range(min_row, max_row + 1):
		for x in width:
			var c := Vector2i(x, y)
			if _is_empty(c):
				free.append(c)
	if free.is_empty():
		return Vector2i(-1, -1)
	return free[rng.randi_range(0, free.size() - 1)]
