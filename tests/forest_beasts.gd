extends SceneTree
# Твари Раскола акта 1: Вепрь и Колючник (лес), элита болот Грозовой угорь.
# Числа и особенности, отряды на своей ветке, удары по правилам и прогноз хода без расхождений.
# Запуск: godot --headless --path . -s tests/forest_beasts.gd

var run: Node
var fails: int = 0
const T := BattleLogic.Tile


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func enemy(id: String) -> EnemyData:
	return load("res://resources/enemies/%s.tres" % id)


# Бой на чистом поле: маг на C(2, 9), рыцарь на C(8, 9), враги в верхнем ряду
func fresh(enemy_ids: Array) -> BattleLogic:
	run.start_new_run(5)
	var list: Array[EnemyData] = []
	for id in enemy_ids:
		list.append(enemy(id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i * 2 + 1, 0)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	_data()
	_squads()
	_boar()
	_thornbush()
	_eel()
	_fuzz()
	print("\nИтог: %s" % ("все проверки пройдены" if fails == 0 else "провалено: %d" % fails))
	quit(1 if fails > 0 else 0)


func _data() -> void:
	print("--- Данные ---")
	for id in ["rift_boar", "thornbush", "storm_eel"]:
		var d: EnemyData = enemy(id)
		check("%s: есть модель, имя и строка" % id, d.model != null and d.title != "" and d.description != "")
	check("Колючник не ходит и боится огня", enemy("thornbush").move_range == 0 and enemy("thornbush").fire_weak)
	var eel: EnemyData = enemy("storm_eel")
	check("Угорь — элита, ходит по трясине, всегда мокрый", eel.is_elite and eel.bog_walker and eel.always_wet and eel.aquatic)
	check("У угря три удара по кругу", eel.cycle.size() == 3)


func _squads() -> void:
	print("--- Отряды ---")
	var act: ActData = load("res://resources/acts/act_1.tres")
	var found: Dictionary = {}
	for enc: EncounterData in act.encounters + act.elite_pool:
		found[enc.id] = enc
	check("«Вепри Раскола» и «Колючая чаща» — в акте 1, только в Лесу",
			found.has("rift_boars") and found.has("thorn_thicket")
			and found["rift_boars"].branch == EncounterData.Branch.FOREST and found["thorn_thicket"].branch == EncounterData.Branch.FOREST)
	check("Элита «Грозовой угорь» — только на Болотах", found.has("elite_eel") and found["elite_eel"].branch == EncounterData.Branch.BOG
			and found["elite_eel"].kind == EncounterData.Kind.ELITE)
	# За 40 забегов угорь хоть раз выпадает элитой Болот и ни разу — Леса
	var bog_eel: int = 0
	var forest_eel: int = 0
	for s in range(1, 41):
		run.start_new_run(s)
		if run.elite_for_row(5, MapNode.BOG).id == "elite_eel":
			bog_eel += 1
		if run.elite_for_row(5, MapNode.FOREST).id == "elite_eel":
			forest_eel += 1
	check("Угорь — элита Болот в %d забегах из 40, Леса — ни разу" % bog_eel, bog_eel > 0 and forest_eel == 0)


func _boar() -> void:
	print("--- Вепрь Раскола ---")
	var l := fresh(["rift_boar"])
	var k: BattleUnit = l.heroes[1]
	var boar: BattleUnit = l.enemies[0]
	boar.cell = C(5, 5)
	k.cell = boar.cell + HexMath.DIRS[0]
	k.block = 0
	var hp: int = k.hp
	var from: Vector2i = k.cell
	l._enemies_act()
	check("Таран: 4 урона", k.hp == hp - 4)
	check("…и отбрасывает на 2 клетки", HexMath.distance(from, k.cell) == 2)


func _thornbush() -> void:
	print("--- Колючник ---")
	var l := fresh(["thornbush"])
	var bush: BattleUnit = l.enemies[0]
	bush.cell = C(5, 5)
	var m: BattleUnit = l.heroes[0]
	m.cell = bush.cell + HexMath.DIRS[2]
	m.block = 0
	var hp: int = m.hp
	l._enemies_act()
	check("Не сдвинулся с места", bush.cell == C(5, 5))
	check("Шипы ранят соседа на 2", m.hp == hp - 2)
	check("…и опутывают", m.entangled > 0)
	var far := fresh(["thornbush"])
	far.enemies[0].cell = C(5, 5)
	var fm: BattleUnit = far.heroes[0]
	var far_hp: int = fm.hp
	far._enemies_act()
	check("Героя не рядом не достаёт", fm.hp == far_hp and far.enemies[0].cell == C(5, 5))


func _eel() -> void:
	print("--- Грозовой угорь ---")
	var l := fresh(["storm_eel"])
	var eel: BattleUnit = l.enemies[0]
	eel.cell = C(5, 3)
	var m: BattleUnit = l.heroes[0]
	m.cell = C(5, 6)   # на линии в 3 клетках
	m.block = 0
	var hp: int = m.hp
	l.turn = 1
	l._enemies_act()
	check("Раунд 1, Разряд: попал (%d урона)" % (hp - m.hp), m.hp < hp)
	check("…под целью лужа", l.tile_at(m.cell) == T.WATER)
	# Раунд 2: ток по всем лужам, где стоят герои
	var l2 := fresh(["storm_eel"])
	l2.turn = 2
	var h: BattleUnit = l2.heroes[0]
	h.block = 0
	l2._set_tile(h.cell, T.WATER)
	l2._set_tile(h.cell + HexMath.DIRS[0], T.WATER)
	var dry: BattleUnit = l2.heroes[1]
	var h_hp: int = h.hp
	var dry_hp: int = dry.hp
	l2._enemies_act()
	check("Раунд 2, Ток по трясине: герой в луже ранен", h.hp < h_hp)
	check("…герой на сухом — нет", dry.hp == dry_hp)


# Случайные бои с тварями: прогноз хода врагов совпадает с настоящим ходом
func _fuzz() -> void:
	print("--- Прогноз (60 боёв) ---")
	var squads: Array = [["storm_eel", "leech", "leech", "drowned_walker"], ["thornbush", "thornbush", "rift_boar", "grove_huntress"],
			["rift_boar", "rift_boar", "wolf", "goblin"]]
	var arenas: Array[String] = ["gat", "thicket", "windfall"]
	var mismatches: int = 0
	for s in range(1, 61):
		run.start_new_run(s)
		var list: Array[EnemyData] = []
		for id in squads[s % 3]:
			list.append(enemy(id))
		var b := BattleLogic.new()
		b.setup(12, 12, run.rng, run.party, list, arenas[s % 3])
		b.start()
		for t in 8:
			if b.is_over:
				break
			for h in b.living_heroes():
				for tries in 4:
					if b.is_over or h.hand.is_empty() or not h.is_alive():
						break
					var idx: int = run.rng.randi_range(0, h.hand.size() - 1)
					var targets: Array[Vector2i] = b.get_card_targets(h, idx)
					if not targets.is_empty() and b.can_play(h, idx):
						b.play_card(h, idx, targets[run.rng.randi_range(0, targets.size() - 1)])
				var mv: Dictionary = b.get_move_targets(h)
				if not mv.is_empty() and not b.is_over:
					b.move_hero(h, mv.keys()[run.rng.randi_range(0, mv.size() - 1)])
			if b.is_over:
				break
			var sim: BattleLogic = b.clone()
			sim._enemies_act()
			var want: String = _sig(sim)
			b._enemies_act()
			if _sig(b) != want:
				mismatches += 1
			if not b._check_end():
				b._tick_objects()
				b._start_heroes_turn()
	check("Расхождений прогноза: %d" % mismatches, mismatches == 0)


func _sig(b: BattleLogic) -> String:
	var parts: PackedStringArray = []
	for u: BattleUnit in b.heroes + b.enemies:
		parts.append("%d:%s:%d:%d:%d:%d" % [u.id, u.cell, u.hp, u.block, u.entangled, u.wet])
	var cells: Array = b.tiles.keys()
	cells.sort()
	for c: Vector2i in cells:
		parts.append("%s=%d" % [c, b.tile_at(c)])
	return "|".join(parts)
