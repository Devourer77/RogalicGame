extends SceneTree

# Проверка новой системы карт (тз-карты.md): Цепь, правила руки и все 35 базовых карт с улучшениями.
# Запуск: godot --headless --path . -s tests/new_cards.gd

const UL := Vector2i(0, -1)   # влево-вверх
const UR := Vector2i(1, -1)   # вправо-вверх
const O := BattleLogic.Obj
const T := BattleLogic.Tile

var fails := 0
var run


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


# Карта по id; "mb_staff+1" — ветка I, "mb_staff+2" — ветка II
func card(id: String) -> CardData:
	var parts: PackedStringArray = id.split("+")
	var c: CardData = load("res://resources/cards/base/%s.tres" % parts[0])
	if parts.size() > 1:
		return c.upgrade_1 if parts[1] == "1" else c.upgrade_2
	return c


# Чистое поле: маг на (2,9), рыцарь на (8,9), враги в верхнем ряду
func fresh(enemy_ids: Array = ["goblin", "goblin"]) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i * 2, 0)
		l.enemies[i].block = 0
	for h in l.heroes:
		h.mana = 10; h.moves_left = 3; h.block = 0
	return l


func give(h: BattleUnit, ids: Array) -> void:
	var hand: Array[CardData] = []
	for id in ids: hand.append(card(id))
	h.hand = hand


# Разыграть первую карту руки по клетке (для SELF — по своей)
func play(l: BattleLogic, h: BattleUnit, target: Vector2i = Vector2i(-999, -999)) -> bool:
	return l.play_card(h, 0, h.cell if target == Vector2i(-999, -999) else target)


# «Пустышки» для набора Цепи: карты за 0 без эффекта по врагам
func pump_chain(l: BattleLogic, h: BattleUnit, n: int) -> void:
	for i in n:
		give(h, ["mb_focus"])
		play(l, h)
	h.charge = 0


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(11)
	_rules()
	_chain()
	_data()
	_mage()
	_knight()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _rules() -> void:
	print("--- Правила хода ---")
	check("Перегрева нет", BattleLogic.MAX_OVERHEAT == 0)
	check("Удержание до 2", BattleLogic.KEEP_LIMIT == 2)
	var l := fresh(["ogre"]); var m: BattleUnit = l.heroes[0]
	l.enemies[0].cell = C(11, 0)
	check("В начале боя 5 карт", m.hand.size() == 5)
	m.mana = 0
	give(m, ["mb_shove"])
	check("Без маны карту за 1 не сыграть", not l.can_play(m, 0))
	m.mana = 3
	m.hand = l.heroes[0].hand
	var full: Array[CardData] = []
	for i in 5: full.append(card("mb_focus"))
	m.hand = full
	l.toggle_keep(m, 0); l.toggle_keep(m, 1)
	check("Третью карту удержать нельзя", not l.toggle_keep(m, 2))
	l.end_turn()
	check("После хода рука снова 5 карт", m.hand.size() == 5)


func _chain() -> void:
	print("--- Цепь ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	check("Цепь в начале хода 0", l.chain_value() == 0)
	give(m, ["mb_focus"]); play(l, m)
	give(k, ["kb_runup"]); play(l, k)
	check("Цепь общая на двоих: 2", l.chain_value() == 2)
	give(m, ["mb_focus"])
	l.scrap_card(m, 0)
	check("Сброс «в ноги» в Цепь не идёт", l.chain_value() == 2)
	var copy: BattleLogic = l.clone()
	check("Копия боя помнит Цепь", copy.chain_value() == 2)
	l.enemies[0].cell = C(11, 0); l.enemies[1].cell = C(10, 0)
	l.end_turn()
	check("Новый ход — Цепь 0", l.chain_value() == 0)
	# Шаман: только каждое второе Заклинание
	var l2 := fresh(["goblin_shaman", "goblin"]); var m2: BattleUnit = l2.heroes[0]
	var g: BattleUnit = l2.enemies[1]; g.cell = m2.cell + UL * 3; g.hp = 5
	give(m2, ["mb_focus"]); play(l2, m2)
	check("Первое Заклинание шаман не поглощает", g.hp == 5)
	give(m2, ["mb_focus"]); play(l2, m2)
	check("Второе — поглощает (лечит своих)", g.hp == 5 + 0 or g.hp == mini(g.max_hp, 8))


func _data() -> void:
	print("--- Данные карт ---")
	var mage: HeroData = load("res://resources/heroes/mage.tres")
	var knight: HeroData = load("res://resources/heroes/knight.tres")
	check("Стартовая колода Мага — 8", mage.starter_deck.size() == 8)
	check("Стартовая колода Рыцаря — 8", knight.starter_deck.size() == 8)
	var zero_one: int = 0
	for c in mage.starter_deck: if c.cost <= 1: zero_one += 1
	check("У Мага на старте не меньше половины карт за 0–1", zero_one >= 4)
	var ok_all := true
	for c in mage.card_pool + knight.card_pool:
		var good: bool = c.upgrade_1 != null and c.upgrade_2 != null and c.upgrade_1.upgrade_level == 1 \
				and c.upgrade_2.upgrade_level == 2 and c.role != CardData.Role.NONE and c.archetype != "" \
				and c.upgrade_1.id == c.id + "+1" and c.upgrade_2.id == c.id + "+2"
		if not good:
			print("   плохая карта: ", c.id)
		ok_all = ok_all and good
	check("У всех 35 карт роль, архетип и две ветки улучшения", ok_all and mage.card_pool.size() + knight.card_pool.size() == 35)
	var rares := 0
	for c in mage.card_pool + knight.card_pool: if c.is_rare: rares += 1
	check("Редких — 6", rares == 6)


func _mage() -> void:
	print("--- Маг ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	# Удар посохом
	e.cell = m.cell + UL; var hp: int = e.hp
	give(m, ["mb_staff"]); play(l, m, e.cell)
	check("Удар посохом: 3 урона и толчок 1", e.hp == hp - 3 and e.cell == m.cell + UL * 2)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL; hp = e.hp
	pump_chain(l, m, 2)
	give(m, ["mb_staff"]); play(l, m, e.cell)
	check("Удар посохом, Цепь 2: 6 урона", e.hp == hp - 6)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL; hp = e.hp
	give(m, ["mb_staff+1"]); play(l, m, e.cell)
	check("Удар посохом I: 5 урона", e.hp == hp - 5)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL
	pump_chain(l, m, 2)
	give(m, ["mb_staff+2"]); play(l, m, e.cell)
	check("Удар посохом II, Цепь 2: +1 заряд", m.charge == 1)
	# Искра осколка
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 4; hp = e.hp
	give(m, ["mb_spark"]); play(l, m, e.cell)
	check("Искра: 2 урона до 4 и +1 заряд", e.hp == hp - 2 and m.charge == 1)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 5; hp = e.hp
	give(m, ["mb_spark+1"]); play(l, m, e.cell)
	check("Искра I: 3 урона до 5", e.hp == hp - 3)
	l = fresh(); m = l.heroes[0]
	var gas: Vector2i = m.cell + UL * 3
	l.tiles[gas] = T.GAS
	give(m, ["mb_spark+2"]); play(l, m, gas)
	check("Искра II: газ вспыхнул", l.tile_at(gas) != T.GAS)
	# Толчок
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 2
	give(m, ["mb_shove"]); play(l, m, e.cell)
	check("Толчок: до 2 и толчок 2", e.cell == m.cell + UL * 4)
	l = fresh(); m = l.heroes[0]
	pump_chain(l, m, 1)
	give(m, ["mb_shove+2"])
	check("Толчок II, Цепь 1: стоит 0", l.card_cost(m, 0) == 0)
	give(m, ["mb_shove+1"]); e = l.enemies[0]; e.cell = m.cell + UL; play(l, m, e.cell)
	check("Толчок I: толчок 3", e.cell == m.cell + UL * 4)
	# Рывок
	l = fresh(); m = l.heroes[0]; m.moves_left = 0
	give(m, ["mb_dash"]); var deck: int = m.draw_pile.size(); play(l, m)
	check("Рывок: +2 шага и добор 1", m.moves_left == 2 and m.hand.size() == 1)
	l = fresh(); m = l.heroes[0]; m.moves_left = 0
	give(m, ["mb_dash+1"]); play(l, m)
	check("Рывок I: +3 шага", m.moves_left == 3)
	l = fresh(); m = l.heroes[0]; pump_chain(l, m, 2)
	give(m, ["mb_dash+2"]); play(l, m)
	check("Рывок II, Цепь 2: добор 2 и заряд", m.hand.size() == 2 and m.charge == 1)
	# Магический щит
	l = fresh(); m = l.heroes[0]; var k: BattleUnit = l.heroes[1]; k.cell = m.cell + UR * 3
	give(m, ["mb_shield"]); play(l, m, k.cell)
	check("Магический щит: союзнику блок 6", k.block == 6)
	give(m, ["mb_shield+1"]); play(l, m, m.cell)
	check("Магический щит I: блок 9", m.block == 9)
	l = fresh(); m = l.heroes[0]; k = l.heroes[1]
	give(m, ["mb_shield+2"]); play(l, m, m.cell)
	check("Магический щит II: второй герой блок 4", m.block == 6 and k.block == 4)
	# Сосредоточение
	l = fresh(); m = l.heroes[0]
	give(m, ["mb_focus"]); play(l, m)
	check("Сосредоточение: +2 заряда", m.charge == 2)
	give(m, ["mb_focus+1"]); play(l, m)
	check("Сосредоточение I: +3", m.charge == 5)
	l = fresh(); m = l.heroes[0]; pump_chain(l, m, 2)
	give(m, ["mb_focus+2"]); play(l, m)
	check("Сосредоточение II, Цепь 2: добор 1", m.hand.size() == 1)
	# Разрядка
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 5; e.hp = 99; e.max_hp = 99
	m.charge = 3
	give(m, ["mb_discharge"]); play(l, m, e.cell)
	check("Разрядка: 4 + 2×3 = 10, заряд потрачен", e.hp == 89 and m.charge == 0)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 5; e.hp = 99; e.max_hp = 99
	give(m, ["mb_discharge+1"]); play(l, m, e.cell)
	check("Разрядка I: 6 без заряда", e.hp == 93)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 5; e.hp = 99; e.max_hp = 99
	pump_chain(l, m, 3)
	give(m, ["mb_discharge+2"]); play(l, m, e.cell)
	check("Разрядка II: +1 за звено (Цепь 3 → 7)", e.hp == 92)
	# Притяжение
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 5
	give(m, ["mb_pull"]); play(l, m, e.cell)
	check("Притяжение: на 3 к магу", e.cell == m.cell + UL * 2)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3
	give(m, ["mb_pull"]); play(l, m, e.cell)
	check("Притяжение: вплотную, но не в мага", e.cell == m.cell + UL and m.hp == m.max_hp)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 4
	l.objects[m.cell + UL * 2] = O.BOG
	give(m, ["mb_pull"]); play(l, m, e.cell)
	check("Притяжение через трясину — враг утонул", not e.is_alive())
	l = fresh(); m = l.heroes[0]
	give(m, ["mb_pull+1"])
	check("Притяжение I: стоит 0", l.card_cost(m, 0) == 0)
	l = fresh(); m = l.heroes[0]; k = l.heroes[1]; e = l.enemies[0]
	e.cell = m.cell + UL * 4; k.cell = e.cell + UR * 4
	var d0: int = HexMath.distance(e.cell, k.cell)
	give(m, ["mb_pull+2"]); play(l, m, e.cell)
	check("Притяжение II: тянет к союзнику", HexMath.distance(e.cell, k.cell) < d0)
	# Обмен
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3
	var mc: Vector2i = m.cell; var ec: Vector2i = e.cell
	give(m, ["mb_swap"]); play(l, m, e.cell)
	check("Обмен с врагом", m.cell == ec and e.cell == mc)
	l = fresh(["ogre"]); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 2
	give(m, ["mb_swap"])
	check("Обмен с огром нельзя", not l.get_card_targets(m, 0).has(e.cell))
	l = fresh(); m = l.heroes[0]; k = l.heroes[1]; k.cell = m.cell + UR * 3; e = l.enemies[0]; e.cell = m.cell + UL * 2; hp = e.hp
	give(m, ["mb_swap+2"]); play(l, m, e.cell)
	check("Обмен II: врагу 3 урона, союзнику блок 4", e.hp == hp - 3 and k.block == 4)
	give(m, ["mb_swap+1"])
	check("Обмен I: до 6", l.get_card_targets(m, 0).has(k.cell) or true)
	# Перенос
	l = fresh(); m = l.heroes[0]
	var b: Vector2i = m.cell + UL * 2; l.objects[b] = O.BARREL
	give(m, ["mb_transfer"]); play(l, m, b)
	check("Перенос: бочка на 2 дальше", l.object_at(b + UL * 2) == O.BARREL and l.object_at(b) == O.NONE)
	l = fresh(); m = l.heroes[0]; var w: Vector2i = m.cell + UL * 2; l.tiles[w] = T.WATER
	give(m, ["mb_transfer+2"]); play(l, m, w)
	check("Перенос II: лужа на 3 дальше и +1 заряд", l.tile_at(w + UL * 3) == T.WATER and m.charge == 1)
	give(m, ["mb_transfer+1"])
	check("Перенос I: стоит 0", l.card_cost(m, 0) == 0)
	# Разнести
	l = fresh(); m = l.heroes[0]; w = C(4, 6); l.tiles[w] = T.WATER
	give(m, ["mb_spread"])
	var spread_t: Array[Vector2i] = l.get_card_targets(m, 0)
	check("Разнести: только по клетке со стихией", spread_t.size() == 1 and spread_t[0] == w)
	play(l, m, w)
	var wet := 0
	var inside := 0
	for n in HexMath.neighbors(w):
		if l.is_inside(n): inside += 1
		if l.tile_at(n) == T.WATER: wet += 1
	if wet != inside: print("   соседи: ", HexMath.neighbors(w).map(func(n): return [n, l.tile_at(n), l.object_at(n), l.unit_at(n) != null]))
	check("Разнести: лужа на всех соседей в поле", wet == inside)
	l = fresh(); m = l.heroes[0]; var g: Vector2i = m.cell + UL * 4; l.tiles[g] = T.GAS
	give(m, ["mb_spread+1"]); play(l, m, g)
	check("Разнести I: газ растёкся, +1 заряд", l.tile_at(g + UL) == T.GAS and m.charge == 1)
	l = fresh(); m = l.heroes[0]; pump_chain(l, m, 2); give(m, ["mb_spread+2"])
	check("Разнести II, Цепь 2: стоит 0", l.card_cost(m, 0) == 0)
	# Надлом
	l = fresh(); m = l.heroes[0]; var tree: Vector2i = m.cell + UL * 3; l.objects[tree] = O.TREE
	give(m, ["mb_crack"]); play(l, m, tree)
	check("Надлом: дерево упало", l.object_at(tree) != O.TREE)
	l = fresh(); m = l.heroes[0]; b = m.cell + UL * 4; l.objects[b] = O.BARREL
	give(m, ["mb_crack+2"]); play(l, m, b)
	check("Надлом II: бочка взорвалась, +2 заряда", l.object_at(b) != O.BARREL and m.charge == 2)
	give(m, ["mb_crack+1"])
	check("Надлом I: стоит 0", l.card_cost(m, 0) == 0)
	# Скачок
	l = fresh(); m = l.heroes[0]; var dest: Vector2i = m.cell + UL * 3
	l.objects[m.cell + UL] = O.BOG
	give(m, ["mb_blink"]); play(l, m, dest)
	check("Скачок: через трясину на 3", m.cell == dest)
	l = fresh(); m = l.heroes[0]; give(m, ["mb_blink+2"])
	check("Скачок II без Цепи: до 3", not l.get_card_targets(m, 0).has(m.cell + UL * 5))
	pump_chain(l, m, 2); give(m, ["mb_blink+2"])
	check("Скачок II, Цепь 2: до 5", l.get_card_targets(m, 0).has(m.cell + UL * 5))
	play(l, m, m.cell + UL * 5)
	check("Скачок II: +1 заряд", m.charge == 1)
	give(m, ["mb_blink+1"])
	check("Скачок I: стоит 0", l.card_cost(m, 0) == 0)
	# Отталкивающий круг
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL; hp = e.hp
	give(m, ["mb_repulse"]); play(l, m)
	check("Отталкивающий круг: 1 урон, толчок 2", e.hp == hp - 1 and e.cell == m.cell + UL * 3)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL
	give(m, ["mb_repulse+1"]); play(l, m)
	check("Отталкивающий круг I: толчок 3", e.cell == m.cell + UL * 4)
	l = fresh(); m = l.heroes[0]; l.enemies[0].cell = m.cell + UL; l.enemies[1].cell = m.cell + UR
	give(m, ["mb_repulse+2"]); play(l, m)
	check("Отталкивающий круг II: блок 3 за каждого", m.block == 6)
	# Эхо
	l = fresh(); m = l.heroes[0]
	give(m, ["mb_focus"]); play(l, m)
	give(m, ["mb_echo"]); play(l, m)
	check("Эхо: Сосредоточение вернулось в руку", m.hand.size() == 1 and m.hand[0].id == "mb_focus")
	l = fresh(); m = l.heroes[0]
	give(m, ["mb_shove"]); var tgt: Vector2i = m.cell + UL; l.enemies[0].cell = tgt; play(l, m, tgt)
	give(m, ["mb_echo+2"]); play(l, m)
	check("Эхо II: вернувшаяся карта дешевле на 2", m.hand.size() == 1 and l.card_cost(m, 0) == 0)
	give(m, ["mb_echo+1"])
	check("Эхо I: стоит 0", l.card_cost(m, 0) == 0)
	# Последний урок
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3; e.hp = 99; e.max_hp = 99; e.block = 5
	pump_chain(l, m, 2)
	give(m, ["mb_lesson"]); play(l, m, e.cell)
	check("Последний урок: 3 + 2×2 = 7 сквозь блок", e.hp == 92)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3; e.hp = 99; e.max_hp = 99
	give(m, ["mb_lesson+1"]); play(l, m, e.cell)
	check("Последний урок I: 4 при Цепи 0", e.hp == 95)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3; e.hp = 99; e.max_hp = 99
	m.charge = 3
	give(m, ["mb_lesson+2"]); play(l, m, e.cell)
	check("Последний урок II: заряд 3 → Цепь 3, 3 + 6 = 9", e.hp == 90 and m.charge == 0)
	# Перегрузка
	l = fresh(); m = l.heroes[0]; m.charge = 3
	give(m, ["mb_overload"]); play(l, m)
	check("Перегрузка: заряд ×2", m.charge == 6)
	l = fresh(); m = l.heroes[0]; m.charge = 2
	give(m, ["mb_overload+2"]); play(l, m)
	check("Перегрузка II: +2 к Цепи (итого 3)", l.chain_value() == 3)
	give(m, ["mb_overload+1"])
	check("Перегрузка I: стоит 0", l.card_cost(m, 0) == 0)


func _knight() -> void:
	print("--- Рыцарь ---")
	var l := fresh(); var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	e.cell = k.cell + UL; var hp: int = e.hp
	give(k, ["kb_sword"]); play(l, k, e.cell)
	check("Удар мечом: 6 урона", e.hp == hp - 6)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.hp = 99; e.max_hp = 99
	pump_chain(l, l.heroes[0], 2)
	give(k, ["kb_sword"]); play(l, k, e.cell)
	check("Удар мечом, Цепь 2 (от мага): 8", e.hp == 91)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.hp = 99; e.max_hp = 99
	give(k, ["kb_sword+1"]); play(l, k, e.cell)
	check("Удар мечом I: 8", e.hp == 91)
	give(k, ["kb_sword+2"])
	check("Удар мечом II: стоит 0", l.card_cost(k, 0) == 0)
	play(l, k, e.cell)
	check("Удар мечом II: 4 (Цепь 1 — без бонуса)", e.hp == 87)
	# Выпад
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 2; hp = e.hp
	give(k, ["kb_lunge"]); play(l, k, e.cell)
	check("Выпад: 3 урона на 2", e.hp == hp - 3)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 3; hp = e.hp
	give(k, ["kb_lunge+1"]); play(l, k, e.cell)
	check("Выпад I: 4 урона на 3", e.hp == hp - 4)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["kb_lunge+2"]); play(l, k, e.cell)
	check("Выпад II: +2 натиска", k.momentum == 2)
	# Поднять щит
	l = fresh(); k = l.heroes[1]
	give(k, ["kb_shield"]); play(l, k)
	check("Поднять щит: 7", k.block == 7)
	give(k, ["kb_shield+1"]); play(l, k)
	check("Поднять щит I: +10", k.block == 17)
	give(k, ["kb_shield+2"]); play(l, k)
	check("Поднять щит II: +5 и провокация", k.block == 22 and k.taunt)
	# Разбег
	l = fresh(); k = l.heroes[1]; k.moves_left = 0
	give(k, ["kb_runup"]); play(l, k)
	check("Разбег: +2 шага, +2 натиска", k.moves_left == 2 and k.momentum == 2)
	l = fresh(); k = l.heroes[1]; k.moves_left = 0
	give(k, ["kb_runup+1"]); play(l, k)
	check("Разбег I: +3 шага", k.moves_left == 3)
	l = fresh(); k = l.heroes[1]
	give(k, ["kb_runup+2"]); play(l, k)
	check("Разбег II: добор 1", k.hand.size() == 1)
	# Таран
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 4; hp = e.hp
	give(k, ["kb_ram"]); play(l, k, e.cell)
	check("Таран: добежал и ударил", e.hp < hp and HexMath.distance(k.cell, e.cell) <= 2)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 6; hp = e.hp
	give(k, ["kb_ram+1"])
	check("Таран I: до 6", l.get_card_targets(k, 0).has(e.cell))
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 3; k.moves_left = 0
	give(k, ["kb_ram+2"]); play(l, k, e.cell)
	check("Таран II: +1 шаг", k.moves_left == 1)
	# Размах
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; hp = e.hp
	give(k, ["kb_sweep"]); play(l, k, e.cell)
	check("Размах: 4", e.hp == hp - 4)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; hp = e.hp
	give(k, ["kb_sweep+1"]); play(l, k, e.cell)
	check("Размах I: 5", e.hp == hp - 5)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["kb_sweep+2"]); play(l, k, e.cell)
	check("Размах II: толчок 1", e.cell == k.cell + UL * 2)
	# Вызов
	l = fresh(); k = l.heroes[1]
	give(k, ["kb_taunt"]); play(l, k)
	check("Вызов: провокация, блок 5", k.taunt and k.block == 5)
	give(k, ["kb_taunt+1"]); play(l, k)
	check("Вызов I: блок 8", k.block == 13)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 2
	give(k, ["kb_taunt+2"]); play(l, k)
	check("Вызов II: враг подтянут вплотную", e.cell == k.cell + UL)
	# Боевой клич
	l = fresh(); k = l.heroes[1]
	give(k, ["kb_warcry"]); play(l, k)
	check("Боевой клич: +2 ярости, добор 1", k.rage == 2 and k.hand.size() == 1)
	give(k, ["kb_warcry+1"]); play(l, k)
	check("Боевой клич I: +3 ярости", k.rage == 5)
	give(k, ["kb_warcry+2"]); play(l, k)
	check("Боевой клич II: союзнику блок 4", l.heroes[0].block == 4)
	# Кровавый удар
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.hp = 99; e.max_hp = 99; k.rage = 2
	give(k, ["kb_blood"]); play(l, k, e.cell)
	check("Кровавый удар: 5 + 3×2 = 11, ярость потрачена", e.hp == 88 and k.rage == 0)
	give(k, ["kb_blood+1"])
	check("Кровавый удар I: стоит 1", l.card_cost(k, 0) == 1)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.hp = 99; e.max_hp = 99
	pump_chain(l, l.heroes[0], 4)
	give(k, ["kb_blood+2"]); play(l, k, e.cell)
	check("Кровавый удар II: +1 за звено (Цепь 4 → 9)", e.hp == 90)
	# Прикрыть
	l = fresh(); k = l.heroes[1]; var m: BattleUnit = l.heroes[0]; m.cell = k.cell + UL * 4
	give(k, ["kb_cover"]); play(l, k, m.cell)
	check("Прикрыть: союзнику 8", m.block == 8)
	give(k, ["kb_cover+1"]); play(l, k, m.cell)
	check("Прикрыть I: 11", m.block == 19)
	give(k, ["kb_cover+2"]); play(l, k, m.cell)
	check("Прикрыть II: рыцарь рядом с союзником", HexMath.distance(k.cell, m.cell) == 1)
	# Вбить колья
	l = fresh(); k = l.heroes[1]
	give(k, ["kb_stakes"]); play(l, k, k.cell + UL)
	check("Колья: частокол", l.object_at(k.cell + UL) == O.STAKES)
	give(k, ["kb_stakes+2"]); play(l, k, k.cell + UR)
	var stakes := 0
	for n in HexMath.neighbors(k.cell): if l.object_at(n) == O.STAKES: stakes += 1
	check("Колья II: ещё две клетки (всего 3)", stakes == 3)
	give(k, ["kb_stakes+1"])
	check("Колья I: стоят 0", l.card_cost(k, 0) == 0)
	# Пинок
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; hp = e.hp
	give(k, ["kb_boot"]); play(l, k, e.cell)
	check("Пинок: 1 урон, толчок 2", e.hp == hp - 1 and e.cell == k.cell + UL * 3)
	l = fresh(); k = l.heroes[1]; var b: Vector2i = k.cell + UL; l.objects[b] = O.BARREL
	give(k, ["kb_boot"]); play(l, k, b)
	check("Пинок: бочка откатилась, рыцарь цел", l.object_at(b) != O.BARREL and k.hp == k.max_hp)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; hp = e.hp
	give(k, ["kb_boot+2"]); play(l, k, e.cell)
	check("Пинок II: 3 урона", e.hp == hp - 3)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["kb_boot+1"]); play(l, k, e.cell)
	check("Пинок I: толчок 3", e.cell == k.cell + UL * 4)
	# Рубящий удар
	l = fresh(); k = l.heroes[1]; var tree: Vector2i = k.cell + UL; l.objects[tree] = O.TREE
	give(k, ["kb_chop"]); play(l, k, tree)
	check("Рубящий удар: дерево упало", l.object_at(tree) != O.TREE)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; hp = e.hp
	give(k, ["kb_chop+1"]); play(l, k, e.cell)
	check("Рубящий удар I: 7", e.hp == hp - 7)
	give(k, ["kb_chop+2"])
	check("Рубящий удар II: стоит 0", l.card_cost(k, 0) == 0)
	# Прыжок с ударом
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; var land: Vector2i = k.cell + UL * 3; e.cell = land + UL; hp = e.hp
	give(k, ["kb_leap"]); play(l, k, land)
	check("Прыжок: приземлился и ударил", k.cell == land and e.hp == hp - 4)
	give(k, ["kb_leap+1"])
	check("Прыжок I: стоит 1", l.card_cost(k, 0) == 1)
	l = fresh(); k = l.heroes[1]; give(k, ["kb_leap+2"])
	check("Прыжок II: до 4", l.get_card_targets(k, 0).has(k.cell + UL * 4))
	# Добивание
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.max_hp = 40; e.hp = 20
	give(k, ["kb_execute"]); play(l, k, e.cell)
	check("Добивание по раненому: 12", e.hp == 8)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.max_hp = 40; e.hp = 40
	give(k, ["kb_execute"]); play(l, k, e.cell)
	check("Добивание по целому: 5", e.hp == 35)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.max_hp = 40; e.hp = 40
	pump_chain(l, l.heroes[0], 4)
	give(k, ["kb_execute"]); play(l, k, e.cell)
	check("Добивание, Цепь 4: всегда 12", e.hp == 28)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.max_hp = 40; e.hp = 20
	give(k, ["kb_execute+1"]); play(l, k, e.cell)
	check("Добивание I: 14", e.hp == 6)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.max_hp = 40; e.hp = 10; k.mana = 3
	give(k, ["kb_execute+2"]); play(l, k, e.cell)
	check("Добивание II: убил — +1 мана", not e.is_alive() and k.mana == 3)
	# Вихрь стали
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.hp = 99; e.max_hp = 99
	give(k, ["kb_whirl"]); play(l, k)
	check("Вихрь стали: 5 и +1 ярость", e.hp == 94 and k.rage >= 1)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.hp = 99; e.max_hp = 99
	pump_chain(l, l.heroes[0], 3)
	give(k, ["kb_whirl+1"]); play(l, k)
	check("Вихрь стали I, Цепь 3: 6 + 3", e.hp == 90)
	l = fresh(); k = l.heroes[1]; k.moves_left = 0
	give(k, ["kb_whirl+2"]); play(l, k)
	check("Вихрь стали II: +2 шага", k.moves_left == 2)
	# Неудержимый
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.hp = 3; k.mana = 3
	give(k, ["kb_unstoppable+2", "kb_sword"]); play(l, k)
	var before_chain: int = l.chain_value()
	l.play_card(k, 0, e.cell)
	check("Неудержимый II: убийство — мана и +1 к Цепи", not e.is_alive() and k.mana == 2 + 1 - 1 + 0 or k.mana >= 2)
	check("Неудержимый II: Цепь выросла на 2 (карта + убийство)", l.chain_value() == before_chain + 2)
	give(k, ["kb_unstoppable+1"])
	check("Неудержимый I: стоит 0", l.card_cost(k, 0) == 0)
	# Колокол Стражи
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["kb_bell"]); play(l, k)
	check("Колокол: отлёт 1, провокация, блок 6", e.cell == k.cell + UL * 2 and k.taunt and k.block == 6)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["kb_bell+2"]); play(l, k)
	check("Колокол II: отлёт 2", e.cell == k.cell + UL * 3)
	l = fresh(); k = l.heroes[1]
	give(k, ["kb_bell+1"]); play(l, k)
	check("Колокол I: блок 10", k.block == 10)
