extends SceneTree
# Цели боя: «Ритуал», «Прорыв», «Вода прибывает» и выбор цели в забеге.
# Запуск: godot --headless --path . -s tests/objectives.gd

var run: Node
var fails: int = 0


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func fresh(enemy_ids: Array, objective: int) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list, "", objective)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i + 4, 1)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(7)
	_ritual()
	_breakthrough()
	_rising_water()
	_full_rounds()
	_pick()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _ritual() -> void:
	print("--- Ритуал ---")
	var l := fresh(["goblin_shaman", "goblin"], BattleLogic.Objective.RITUAL)
	var shaman: BattleUnit = l.enemies[0]
	check("Ритуалист — шаман, 4 раунда", l.ritual_caster_id == shaman.id and l.ritual_timer == BattleLogic.RITUAL_TURNS)
	var spawned: Array = []
	l.unit_spawned.connect(func(u: BattleUnit) -> void: spawned.append(u))
	for i in BattleLogic.RITUAL_TURNS - 1:
		l._objective_round_end()
	check("За 3 раунда ритуал не завершён", l.enemies.size() == 2 and l.ritual_timer == 1)
	l._objective_round_end()
	check("На 4-м раунде призваны 2 гоблина", l.enemies.size() == 4 and spawned.size() == 2)
	check("Враги стали сильнее на 2", l.ritual_power == BattleLogic.RITUAL_POWER)
	check("Счётчик пошёл заново", l.ritual_timer == BattleLogic.RITUAL_TURNS)
	var g: BattleUnit = l.enemies[1]
	check("Урон гоблина в намерении вырос", l.snapshot(g)["damage"] == l.enemy_attack(g).damage + BattleLogic.RITUAL_POWER)
	var free: bool = true
	for u in spawned:
		for other in l.heroes + l.enemies:
			if other != u and other.cell == u.cell:
				free = false
	check("Призванные встали на свободные клетки", free)
	# Убили ритуалиста — ритуал сорван
	var l2 := fresh(["goblin_shaman", "goblin"], BattleLogic.Objective.RITUAL)
	l2.enemies[0].hp = 0
	for i in BattleLogic.RITUAL_TURNS + 1:
		l2._objective_round_end()
	check("Ритуалист убит — никто не призван", l2.enemies.size() == 2 and l2.ritual_power == 0)
	check("Текст цели: ритуал сорван", l2.objective_text().begins_with("Ритуал сорван"))
	# Некому вести ритуал — обычный бой
	var l3 := fresh(["goblin", "wolf"], BattleLogic.Objective.RITUAL)
	check("Без шамана и культиста — обычный бой", l3.objective == BattleLogic.Objective.KILL_ALL)


func _breakthrough() -> void:
	print("--- Прорыв ---")
	var l := fresh(["goblin"], BattleLogic.Objective.BREAKTHROUGH)
	check("Подсвечен верхний ряд", l.objective_cells().size() == 12)
	l.heroes[0].cell = C(2, 0)
	check("Один герой наверху — ещё не победа", not l._check_end())
	l.heroes[1].cell = C(5, 0)
	check("Оба героя наверху — победа", l._check_end() and l.won)
	# Павший герой не мешает прорыву
	var l2 := fresh(["goblin"], BattleLogic.Objective.BREAKTHROUGH)
	l2.heroes[1].hp = 0
	l2.heroes[0].cell = C(3, 0)
	check("Живой герой наверху, второй пал — победа", l2._check_end() and l2.won)
	# Подкрепление раз в 2 раунда
	var l3 := fresh(["goblin"], BattleLogic.Objective.BREAKTHROUGH)
	l3.turn = 1; l3._objective_round_end()
	check("Нечётный раунд — без подкрепления", l3.enemies.size() == 1)
	l3.turn = 2; l3._objective_round_end()
	check("Чётный раунд — пришёл гоблин", l3.enemies.size() == 2)
	# В обычном бою верхний ряд победы не даёт
	var l4 := fresh(["goblin"], BattleLogic.Objective.KILL_ALL)
	l4.heroes[0].cell = C(2, 0); l4.heroes[1].cell = C(5, 0)
	check("Обычный бой: верхний ряд — не победа", not l4._check_end())


func _rising_water() -> void:
	print("--- Вода прибывает ---")
	var l := fresh(["goblin"], BattleLogic.Objective.RISING_WATER)
	var T := BattleLogic.Tile
	l.objects[C(4, 11)] = BattleLogic.Obj.TREE
	l.turn = 2; l._objective_round_end()
	check("До 3-го раунда вода стоит", l.tile_at(C(0, 11)) == T.NONE and l.water_row == -1)
	l.turn = 3; l._objective_round_end()
	check("3-й раунд: нижний ряд стал трясиной (Swamp)", l.tile_at(C(0, 11)) == T.SWAMP and l.tile_at(C(11, 11)) == T.SWAMP)
	check("Дерево водой не залито", l.tile_at(C(4, 11)) == T.NONE and l.object_at(C(4, 11)) == BattleLogic.Obj.TREE)
	l.turn = 4; l._objective_round_end()
	check("4-й раунд: залит следующий ряд", l.tile_at(C(0, 10)) == T.SWAMP and l.water_row == 10)
	check("Подсвечен ряд, который зальёт следующим", l.objective_cells().has(C(0, 9)))
	# Вода гасит огонь
	l.tiles[C(3, 9)] = T.FIRE; l.fire_timers[C(3, 9)] = 3
	l.turn = 5; l._objective_round_end()
	check("Огонь в залитом ряду погас", l.tile_at(C(3, 9)) == T.SWAMP and not l.fire_timers.has(C(3, 9)))


# Несколько полных раундов с каждой целью: бой не падает, прогноз врагов работает
func _full_rounds() -> void:
	print("--- Полные раунды ---")
	for obj: int in [BattleLogic.Objective.RITUAL, BattleLogic.Objective.BREAKTHROUGH, BattleLogic.Objective.RISING_WATER]:
		var l := fresh(["goblin_shaman", "goblin"], obj)
		for h in l.heroes:
			h.hp = 999; h.max_hp = 999
		for i in 8:
			if l.is_over:
				break
			l.forecast_enemies()
			l.end_turn()
		check("%s: 8 раундов без сбоев" % BattleLogic.OBJECTIVE_TITLES[obj], l.turn >= 8 or l.is_over)


func _pick() -> void:
	print("--- Выбор цели в забеге ---")
	var no_caster: Array[EnemyData] = [load("res://resources/enemies/goblin.tres"), load("res://resources/enemies/wolf.tres")]
	var with_caster: Array[EnemyData] = [load("res://resources/enemies/goblin_shaman.tres")]
	var counts: Dictionary = {}
	var ritual_without_caster: bool = false
	var breakthrough_on_gat: bool = false
	for i in 400:
		var o: int = run.pick_objective(4, with_caster, "grove")
		counts[o] = counts.get(o, 0) + 1
		if run.pick_objective(4, no_caster, "grove") == BattleLogic.Objective.RITUAL:
			ritual_without_caster = true
		if run.pick_objective(4, with_caster, "gat") == BattleLogic.Objective.BREAKTHROUGH:
			breakthrough_on_gat = true
	var special: int = 400 - int(counts.get(BattleLogic.Objective.KILL_ALL, 0))
	check("Особая цель примерно в 30%% боёв (%d из 400)" % special, special > 80 and special < 160)
	check("Все три особые цели встречаются", counts.has(BattleLogic.Objective.RITUAL)
			and counts.has(BattleLogic.Objective.BREAKTHROUGH) and counts.has(BattleLogic.Objective.RISING_WATER))
	check("Ритуал — только если есть шаман или культист", not ritual_without_caster)
	check("На «Старой гати» прорыва нет", not breakthrough_on_gat)
	var early: bool = false
	for i in 100:
		if run.pick_objective(1, with_caster, "grove") != BattleLogic.Objective.KILL_ALL:
			early = true
	check("На первых рядах карты особых целей нет", not early)
