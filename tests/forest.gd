extends SceneTree

# Густые леса и насосная: лоза, живое дерево, подлесок, улей, паровой клапан, выбор арен по ветке.
# Запуск: godot --headless --path . -s tests/forest.gd

func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)

var fails := 0
var run
const O := BattleLogic.Obj
const T := BattleLogic.Tile
const E := CardData.Element


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func fresh(enemy_ids: Array) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear(); l.obj_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i, 0)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(11)
	_vine_hero()
	_vine_enemy()
	_vine_burn()
	_live_tree()
	_hive()
	_valve()
	_arena_pick()
	_leshy()
	_keepers()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _vine_hero() -> void:
	print("--- Лоза держит героя ---")
	var l := fresh(["goblin"]); var m: BattleUnit = l.heroes[0]
	var v: Vector2i = m.cell + HexMath.DIRS[0]
	l.objects[v] = O.VINE
	var far: Vector2i = v + HexMath.DIRS[0]
	var targets := l.get_move_targets(m)
	check("На лозу встать можно", targets.has(v))
	var through_ok: bool = not targets.has(far) or targets[far].find(v) == -1
	check("Сквозь лозу пути нет", through_ok)
	m.moves_left = 4
	l.move_hero(m, v)
	check("Встал на лозу — шаги кончились", m.moves_left == 0)
	# Срубить лозу ударом
	var card := CardData.new(); card.damage = 3; card.shape = CardData.Shape.SINGLE
	l._hit_cells(card, 3, [v] as Array[Vector2i], m.cell)
	check("Удар картой срубает лозу", l.object_at(v) == O.NONE)
	# Толчок останавливается на лозе
	l = fresh(["goblin"]); var g: BattleUnit = l.enemies[0]
	g.cell = C(5, 4); var d: Vector2i = HexMath.DIRS[2]
	l.objects[g.cell + d] = O.VINE
	l._push(g, d, 3)
	check("Толкнутый враг застрял на лозе", g.cell == C(5, 4) + d)
	check("…и опутан", g.entangled > 0)


func _vine_enemy() -> void:
	print("--- Лоза держит врага ---")
	var l := fresh(["goblin"]); var g: BattleUnit = l.enemies[0]
	g.cell = C(5, 6); g.entangled = 0
	l._enemy_phase = true
	l._walked(g, [C(5, 5), C(5, 6)] as Array[Vector2i])
	check("Враг без лозы не опутан", g.entangled == 0)
	l.objects[C(5, 6)] = O.VINE
	l._walked(g, [C(5, 5), C(5, 6)] as Array[Vector2i])
	check("Враг вошёл на лозу — опутан", g.entangled > 0)
	var keeper := EnemyData.new(); keeper.vine_walker = true; keeper.title = "Хранитель"
	g.data = keeper; g.entangled = 0
	l._walked(g, [C(5, 5), C(5, 6)] as Array[Vector2i])
	check("Хранителя лоза не держит", g.entangled == 0)
	# Враг, вставший на лозу в свой ход, в следующий ход не двигается
	l = fresh(["goblin"]); g = l.enemies[0]
	for c: Vector2i in HexMath.rect_cells(12, 12):
		if c.y >= 2 and c.y <= 2:
			l.objects[c] = O.VINE
	g.cell = C(5, 0)
	l.end_turn()
	var after1: Vector2i = g.cell
	check("Гоблин не прошёл сквозь полосу лозы", after1.y <= 2)
	l.end_turn()
	check("В следующий ход опутанный гоблин не сдвинулся", g.cell == after1)


func _vine_burn() -> void:
	print("--- Пожар в лесу ---")
	var l := fresh(["goblin"])
	var a := C(4, 4)
	l.objects[a] = O.VINE
	l.objects[a + HexMath.DIRS[0]] = O.VINE
	l.objects[a + HexMath.DIRS[0] * 2] = O.BUSH
	l.objects[a + HexMath.DIRS[0] * 3] = O.LIVE_TREE
	l._apply_element(a, E.FIRE, C(4, 8))
	check("Лоза сгорела", l.object_at(a) == O.NONE and l.tile_at(a) == T.FIRE)
	check("Огонь прошёл по связанной лозе", l.object_at(a + HexMath.DIRS[0]) == O.NONE)
	check("…и по подлеску", l.object_at(a + HexMath.DIRS[0] * 2) == O.NONE)
	check("Живое дерево у пожара занялось", l.object_at(a + HexMath.DIRS[0] * 3) == O.BURNING_TREE)
	check("Счёт сгоревшей лозы (условие Лешего)", l.vines_burnt == 2)
	check("Счёт сгоревших деревьев", l.trees_burnt == 1)


func _live_tree() -> void:
	print("--- Живое дерево ---")
	var l := fresh(["goblin"]); var m: BattleUnit = l.heroes[0]
	var t := C(5, 5)
	l.objects[t] = O.LIVE_TREE
	check("Живое дерево — преграда", l._is_obstacle(t))
	check("Живое дерево закрывает линию", l._line_blocker(t) == "stop")
	check("Ударом не валится", not l._is_breakable(t))
	l._apply_element(t, E.FIRE, m.cell)
	check("Огонь: крона горит", l.object_at(t) == O.BURNING_TREE)
	var g: BattleUnit = l.enemies[0]
	g.cell = t + HexMath.DIRS[1]
	var hp: int = g.hp
	l._burning_trees_round_end()
	check("Горящее дерево обжигает соседа", g.hp == hp - BattleLogic.TREE_BURN_DAMAGE or not g.is_alive())
	for i in BattleLogic.TREE_BURN_TURNS:
		l._tick_objects()
	check("Прогорело — сухое дерево (его можно повалить)", l.object_at(t) == O.TREE)


func _hive() -> void:
	print("--- Дикий улей ---")
	var l := fresh(["goblin"]); var g: BattleUnit = l.enemies[0]
	var h := C(5, 4)
	l.objects[h] = O.HIVE
	g.cell = h + HexMath.DIRS[3]
	var hp: int = g.hp
	l._hit_object(h, C(5, 8))
	check("Улей разбит", l.object_at(h) == O.NONE)
	check("Рой ранит соседа", g.hp == hp - BattleLogic.HIVE_DAMAGE or not g.is_alive())
	check("…и травит", g.poison >= BattleLogic.HIVE_POISON or not g.is_alive())
	l.objects[h] = O.HIVE
	l._apply_element(h, E.FIRE, C(5, 8))
	check("Огонь тоже выпускает рой", l.object_at(h) == O.NONE)


func _valve() -> void:
	print("--- Паровой клапан ---")
	var l := fresh(["goblin"]); var g: BattleUnit = l.enemies[0]
	var v := C(5, 4)
	l.objects[v] = O.VALVE
	var near: Vector2i = v + HexMath.DIRS[0]
	g.cell = near
	var hp: int = g.hp
	l._hit_object(v, C(5, 8))
	check("Клапан сорван", l.object_at(v) == O.NONE)
	check("Пар ранит соседа", g.hp == hp - BattleLogic.VALVE_DAMAGE or not g.is_alive())
	check("…и отбрасывает", g.cell == near + HexMath.DIRS[0] or not g.is_alive())
	check("На месте клапана лужа", l.tile_at(v) == T.WATER)


func _arena_pick() -> void:
	print("--- Арены по ветке ---")
	run.start_new_run(5)
	var forest_node: MapNode = null
	var bog_node: MapNode = null
	for n: MapNode in run.map:
		if n.row == 0 and n.branch == MapNode.FOREST and forest_node == null: forest_node = n
		if n.row == 0 and n.branch == MapNode.BOG and bog_node == null: bog_node = n
	run.current = forest_node
	var ok_f: bool = true
	for i in 20:
		if not BattleLogic.FOREST_ARENA_POOL.has(run.pick_arena(false)): ok_f = false
	check("В лесу — лесные арены", ok_f)
	run.current = bog_node
	var ok_b: bool = true
	for i in 20:
		if not BattleLogic.ARENA_POOL.has(run.pick_arena(false)): ok_b = false
	check("На болотах — болотные арены", ok_b)
	var queen: EncounterData = load("res://resources/encounters/elite_queen.tres")
	check("Прядильщица дерётся в Паучьей лощине", queen.arena == "hollow")
	var mother: EncounterData = load("res://resources/encounters/boss_mother.tres")
	check("Матерь Трясины — в Гнилом пруду", mother.arena == "pond")


func _leshy() -> void:
	print("--- Леший ---")
	var sp: SpiritData = run.spirit_data("forest")
	check("Дух загружается", sp != null and sp.is_unique)
	check("12 карт и Зов", sp.mage_cards.size() == 6 and sp.knight_cards.size() == 6 and sp.call_card != null)
	check("В Святилище есть Леший", run.ALL_SPIRIT_IDS.has("forest"))
	var l := fresh(["goblin"]); var m: BattleUnit = l.heroes[0]
	m.spirits.append("forest")
	var v: Vector2i = m.cell + HexMath.DIRS[0]
	l.objects[v] = O.VINE
	m.moves_left = 4
	l.move_hero(m, v)
	check("Лоза не держит героя с Лешим", m.moves_left > 0)
	# Пассив: рядом живое дерево — +блок в начале хода
	l.objects[m.cell + HexMath.DIRS[2]] = O.LIVE_TREE
	m.block = 0
	l.end_turn()
	check("Рядом дерево — блок в начале хода", m.block >= BattleLogic.LESHY_BLOCK or not m.is_alive())
	# Зов «Чаща»: деревья вокруг цели
	l = fresh(["goblin"]); m = l.heroes[0]
	var call: CardData = sp.call_card
	m.hand.append(call); m.mana = 5
	var target: Vector2i = C(2, 7)
	var played: bool = l.play_card(m, m.hand.size() - 1, target)
	check("Зов сыгран", played)
	var grown: int = 0
	for c in HexMath.cluster(target):
		if l.object_at(c) == O.LIVE_TREE: grown += 1
	check("Зов «Чаща»: выросло 3 дерева", grown == 3)
	for i in BattleLogic.GROWN_TREE_TURNS:
		l._tick_objects()
	var left: int = 0
	for c in HexMath.cluster(target):
		if l.object_at(c) == O.LIVE_TREE: left += 1
	check("…и через 3 раунда исчезли", left == 0)
	# «Шипы»: по стоящему на лозе сильнее
	l = fresh(["goblin"]); m = l.heroes[0]; var g: BattleUnit = l.enemies[0]
	g.cell = C(2, 6); l.objects[g.cell] = O.VINE; g.hp = 50; g.max_hp = 50; g.block = 0
	var thorn: CardData = sp.mage_cards[1]
	m.hand.append(thorn); m.mana = 5
	l.play_card(m, m.hand.size() - 1, g.cell)
	check("«Шипы» по врагу на лозе: 4 + 4", g.hp == 42)
	# Условие Лешего: у Голоса Рощи и без пожара
	run.pending_encounter = load("res://resources/encounters/elite_voice.tres")
	check("Леший живёт у Голоса Рощи", run.forest_spirit_offered())
	check("Голос Рощи — элита леса", run.pending_encounter.branch == EncounterData.Branch.FOREST)


func _keepers() -> void:
	print("--- Хранители Рощи ---")
	var ids: Array[String] = ["grove_warden", "grove_huntress", "grove_poisoner", "grove_beekeeper", "grove_shieldbearer",
		"grove_skinwearer", "grove_raincaller", "grove_sapling", "grove_voice"]
	var all_ok: bool = true
	for id in ids:
		var d: EnemyData = load("res://resources/enemies/%s.tres" % id)
		if d == null or d.model == null or not d.vine_walker or d.cycle.is_empty():
			all_ok = false
			print("  нет данных: ", id)
	check("У всех 9 Хранителей есть данные, модель и удары; лоза их не держит", all_ok)
	# Саженец, погибая, становится деревом
	var l := fresh(["grove_sapling"]); var s: BattleUnit = l.enemies[0]
	s.cell = C(5, 5)
	l._damage(s, 99)
	check("Саженец погиб — на клетке живое дерево", l.object_at(C(5, 5)) == O.LIVE_TREE)
	# Отряды леса берутся только в лесу
	var forest: int = 0
	for enc: EncounterData in run.ENCOUNTERS:
		if enc.branch == EncounterData.Branch.FOREST:
			forest += 1
			if not enc.fits_branch(MapNode.FOREST) or enc.fits_branch(MapNode.BOG):
				all_ok = false
	check("Отрядов леса не меньше 10", forest >= 10)
	check("Лесные отряды не попадают на болота", all_ok)
	# Пасечник: удар вокруг себя травит
	l = fresh(["grove_beekeeper"])
	check("Пасечник: два удара в цикле, второй — вокруг себя", l.enemies[0].data.cycle.size() == 2 and l.enemies[0].data.cycle[1].shape == 4)
