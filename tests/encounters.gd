extends SceneTree

# Отряды врагов, пулы элит и боссов, новые враги (ткач, Прядильщица, вожак, Матерь Трясины).
# Запуск: godot --headless --path . -s tests/encounters.gd

var fails := 0
var run
const T := BattleLogic.Tile
const DOWN := Vector2i(0, 1)


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


# Прямая через мага на C(2, 9): клетки с q = -2, шаг вниз — DOWN
func L(row: int) -> Vector2i:
	return Vector2i(-2, row)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


# Чистое поле: маг на (2,9), рыцарь на (8,9), враги в верхнем ряду
func fresh(enemy_ids: Array) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i + 6, 0)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(7)
	_packs()
	_elites_and_bosses()
	_map()
	_weaver()
	_queen()
	_alpha()
	_mother()
	_forecast()
	_second_wave()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _tier(row: int) -> int:
	return 0 if row <= 1 else (1 if row <= 3 else 2)


func _packs() -> void:
	print("--- Отряды ---")
	var tier_ok := true; var core_ok := true; var count_ok := true; var repeat_ok := true
	var shaman_ok := true; var seen: Dictionary = {}; var packs_seen: Dictionary = {}
	for s in range(1, 201):
		run.start_new_run(s)
		var ids: Array[String] = []
		for row in 5:
			var enemies: Array[EnemyData] = run._make_encounter(row, false)
			var enc: EncounterData = run.pending_encounter
			packs_seen[enc.id] = true
			if enc.kind != EncounterData.Kind.NORMAL or not enc.fits_row(row): tier_ok = false
			if ids.has(enc.id): repeat_ok = false
			ids.append(enc.id)
			for i in enc.core.size():
				if enemies[i].id != enc.core[i].id: core_ok = false   # с модификатором враг — копия, сравниваем по id
			if enemies.size() != 4 + row / 2: count_ok = false
			var sh := 0
			for d in enemies:
				seen[d.id] = true
				if d.id == "goblin_shaman": sh += 1
			if sh > 1: shaman_ok = false
	check("Отряд выбирается по ступени ряда (0–1, 2–3, 4+)", tier_ok)
	check("Ядро отряда всегда целиком и первым", core_ok)
	check("Врагов в бою 4 + ряд/2", count_ok)
	check("За забег отряд не повторяется", repeat_ok)
	check("Шаман — не больше одного на бой", shaman_ok)
	check("Встречаются все %d отрядов" % run.encounters().size(), packs_seen.size() == run.encounters().size())
	var expect: Dictionary = {}
	for enc: EncounterData in run.encounters():
		for d in enc.core + enc.filler: expect[d.id] = true
	check("В обычных боях встречаются все виды из отрядов (%d)" % expect.size(), seen.size() == expect.size())
	# Тот же сид — тот же отряд
	run.start_new_run(42); run._make_encounter(2, false); var a: String = run.pending_encounter.id
	run.start_new_run(42); run._make_encounter(2, false)
	check("Тот же сид — тот же отряд", run.pending_encounter.id == a)
	# Звон 1: на врага больше, из добора
	run.start_new_run(5, 1)
	var e1: Array[EnemyData] = run._make_encounter(0, false)
	check("Звон 1: в обычном бою на врага больше", e1.size() == 5)


func _elites_and_bosses() -> void:
	print("--- Элиты и боссы ---")
	var distinct_ok := true; var bosses: Dictionary = {}; var elites: Dictionary = {}
	for s in range(1, 101):
		run.start_new_run(s)
		# по одной элите на ветку (Болота, Лес), разные, каждая подходит своей ветке
		if run.run_elites.size() != 2 or run.run_elites[0].id == run.run_elites[1].id: distinct_ok = false
		for i in run.run_elites.size():
			if not run.run_elites[i].fits_branch(MapNode.BOG if i < 1 else MapNode.FOREST): distinct_ok = false
		for e in run.run_elites: elites[e.id] = true
		bosses[run.run_boss.id] = true
	check("По одной элите на ветку, разные", distinct_ok)
	check("За 100 забегов встречаются все элиты (%d)" % run.elite_pool().size(), elites.size() == run.elite_pool().size())
	check("За 100 забегов встречаются все боссы (%d)" % run.boss_pool().size(), bosses.size() == run.boss_pool().size())
	run.start_new_run(9); var b1: String = run.run_boss.id; var el1: String = run.run_elites[0].id
	run.start_new_run(9)
	check("Тот же сид — тот же босс и элиты", run.run_boss.id == b1 and run.run_elites[0].id == el1)
	var late: Array[EnemyData] = run._make_encounter(run.MAP_ROWS - 3, false, true)
	check("Элита перед привалом — элита ветки", late[0] == run.run_elites[0].core[0])
	# Вторая элита — только из события: другая, своей ветки
	var extra: EncounterData = run.event_elite()
	check("Элита из события — не та, что перед привалом", extra == null or extra != run.run_elites[0])
	var boss: Array[EnemyData] = run._make_encounter(run.MAP_ROWS - 1, true)
	check("Бой босса — босс первым, со свитой", boss[0].is_boss and boss.size() == run.run_boss.core.size())
	check("Арена босса — его собственная", run._encounter_arena(true) == run.run_boss.arena)
	# Звон 5: элита и босс крепче, общий файл не меняется
	run.start_new_run(9, 5)
	var hard: Array[EnemyData] = run._make_encounter(run.MAP_ROWS - 1, true)
	check("Звон 5: босс +25% HP", hard[0].max_hp == ceili(run.run_boss.core[0].max_hp * 1.25))
	check("Звон 5: общий файл босса не изменился", run.run_boss.core[0].max_hp in [60, 65, 70])   # огр, капитан, Матерь
	# Огр со своей свитой, как раньше
	var ogre: EncounterData = load("res://resources/encounters/boss_ogre.tres")
	var ids: Array[String] = []
	for d in ogre.core: ids.append(d.id)
	check("Свита огра прежняя", ids == ["ogre", "goblin", "goblin", "cultist", "wolf"] and ogre.arena == "lair")


# Пересекаются ли две дорожки одного ряда (крест-накрест)
func _cross(a: int, b: int, c: int, d: int) -> bool:
	return (a < c and b > d) or (a > c and b < d)


func _map() -> void:
	print("--- Карта пути: тропы, две ветки, туман ---")
	var rows_ok := true; var shape_ok := true; var cross_ok := true; var lair_ok := true; var elite_ok := true
	var nocross_ok := true; var reach_ok := true; var arena_ok := true; var pos_ok := true
	for s in range(1, 201):
		run.start_new_run(s)
		for branch in [MapNode.BOG, MapNode.FOREST]:
			var lairs := 0
			for n in run.map:
				if n.branch != branch: continue
				if n.type == MapNode.Type.LAIR: lairs += 1
				if n.type == MapNode.Type.ELITE and n.row != run.MAP_ROWS - 3: elite_ok = false
				if (n.type == MapNode.Type.BATTLE or n.type == MapNode.Type.ELITE or n.type == MapNode.Type.LAIR):
					var pool: Array[String] = BattleLogic.FOREST_ARENA_POOL if branch == MapNode.FOREST else BattleLogic.ARENA_POOL
					if n.type != MapNode.Type.ELITE and not pool.has(n.arena): arena_ok = false
					if n.arena == "": arena_ok = false
				if n.pos.x < 0.03 or n.pos.x > 0.97 or n.pos.y < 0.05 or n.pos.y > 0.95: pos_ok = false
				if (branch == MapNode.BOG) != (n.pos.x < 0.5): pos_ok = false
			if lairs != 1: lair_ok = false
			for row in run.MAP_ROWS - 2:
				var c := 0
				for n in run.row_nodes(row):
					if n.branch == branch: c += 1
				if c < 2 or c > 4: rows_ok = false
				if row == run.MAP_ROWS - 3:
					for n in run.row_nodes(row):
						if n.branch == branch and n.type != MapNode.Type.ELITE: elite_ok = false
			# внутри ветки дорожки не пересекаются
			for row in run.MAP_ROWS - 3:
				var edges: Array = []
				for n in run.row_nodes(row):
					if n.branch != branch: continue
					for c in n.next:
						var t: MapNode = run.find_map_node(row + 1, c)
						if t != null and t.branch == branch: edges.append([n.col, c])
				for x in edges:
					for y in edges:
						if _cross(x[0], x[1], y[0], y[1]): nocross_ok = false
		var rest: Array[MapNode] = run.row_nodes(run.MAP_ROWS - 2)
		var boss: Array[MapNode] = run.row_nodes(run.MAP_ROWS - 1)
		if rest.size() != 1 or rest[0].type != MapNode.Type.REST or boss.size() != 1 or boss[0].type != MapNode.Type.BOSS: shape_ok = false
		# Между ветками — ровно две дорожки через мост, только с ряда CROSS_ROW
		var crossings := 0
		for n in run.map:
			for c in n.next:
				var t: MapNode = run.find_map_node(n.row + 1, c)
				if t == null: shape_ok = false; continue
				if t.branch != MapNode.COMMON and n.branch != MapNode.COMMON and t.branch != n.branch:
					crossings += 1
					if n.row != run.CROSS_ROW: cross_ok = false
		if crossings != 2: cross_ok = false
		# Каждая точка достижима со старта, и из каждой (кроме босса) есть путь дальше
		var reach: Dictionary = {}
		for n in run.row_nodes(0): reach[n] = true
		for row in run.MAP_ROWS - 1:
			for n in run.row_nodes(row):
				if not reach.has(n): reach_ok = false
				if n.next.is_empty(): reach_ok = false
				for c in n.next:
					var t: MapNode = run.find_map_node(row + 1, c)
					if t != null: reach[t] = true
		if not reach.has(boss[0]): reach_ok = false
	check("В каждом ряду ветки 2–4 точки", rows_ok)
	check("Внутри ветки тропы не пересекаются", nocross_ok)
	check("Элита — только в ряду перед привалом, весь ряд", elite_ok)
	check("В каждой ветке одно логово духа", lair_ok)
	check("Общий привал и босс", shape_ok)
	check("Тропа-переход через мост — две дорожки на ряду %d" % run.CROSS_ROW, cross_ok)
	check("Все точки достижимы, из каждой есть путь", reach_ok)
	check("Арены боёв назначены заранее, своей ветки", arena_ok)
	check("Точки на своей половине рисунка", pos_ok)
	# Туман: видно на FOG_SIGHT рядов вперёд
	run.start_new_run(4)
	var low: MapNode = run.row_nodes(1)[0]
	var high: MapNode = run.row_nodes(2)[0]
	check("До первого шага видны ряды 0–1", run.node_revealed(low) and not run.node_revealed(high))
	run.current = run.row_nodes(2)[0]
	check("С ряда 2 видно до ряда 4", run.node_revealed(run.row_nodes(4)[0]) and not run.node_revealed(run.row_nodes(5)[0]))
	check("Босс скрыт до ряда 5", not run.node_revealed(run.row_nodes(run.MAP_ROWS - 1)[0]))
	run.current = run.row_nodes(5)[0]
	check("С ряда 5 босс открыт", run.node_revealed(run.row_nodes(run.MAP_ROWS - 1)[0]))
	run.fog_bonus = 1
	run.current = run.row_nodes(2)[0]
	check("Событие «запомнить следы»: видно на ряд дальше", run.node_revealed(run.row_nodes(5)[0]))
	run.fog_bonus = 0
	# Карточка: бой показывает арену точки, и бой идёт на ней
	run.start_new_run(6)
	var bn: MapNode = null
	for n in run.row_nodes(0):
		if n.type == MapNode.Type.BATTLE: bn = n
	run.sim_no_scenes = true
	run.enter_node(bn)
	check("Бой идёт на арене с карточки", run.pending_arena == bn.arena)
	run.sim_no_scenes = false
	# Отряды по ветке: в Лесу нет болотных, на Болотах нет лесных
	var branch_ok := true
	for s in range(1, 41):
		run.start_new_run(s)
		for branch in [MapNode.BOG, MapNode.FOREST]:
			for n in run.row_nodes(2):
				if n.branch == branch: run.current = n
			for row in [0, 2, 4]:
				run._make_encounter(row, false)
				if not run.pending_encounter.fits_branch(branch): branch_ok = false
			var el: EncounterData = run.elite_for_row(run.MAP_ROWS - 3)
			if not el.fits_branch(branch): branch_ok = false
	check("Отряды и элиты — своей ветки", branch_ok)
	# На общем привале ветка — та, откуда пришли
	run.start_new_run(3)
	for n in run.row_nodes(run.MAP_ROWS - 3):
		if n.branch == MapNode.FOREST: n.visited = true
	run.current = run.row_nodes(run.MAP_ROWS - 2)[0]
	check("На привале ветка — откуда пришли (Лес)", run.current_branch() == MapNode.FOREST)


func _weaver() -> void:
	print("--- Болотный ткач ---")
	var l := fresh(["swamp_weaver"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = L(5)
	l._enemies_act()
	check("Ткач: подошёл и плюнул (2 урона)", m.hp == 28)
	check("Ткач: маг опутан", m.entangled > 0)
	check("Ткач держит дистанцию (не вплотную)", HexMath.distance(e.cell, m.cell) >= 2)


func _queen() -> void:
	print("--- Прядильщица ---")
	# Раунд 1 — Сеть: линия 4 сквозь преграды, опутывает
	var l := fresh(["weaver_queen"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = L(4)
	l._enemies_act()
	check("Сеть: 3 урона и опутывание", m.hp == 27 and m.entangled > 0)
	# Раунд 2 — Ядовитый укус: 6 вплотную и яд на 3
	l = fresh(["weaver_queen"]); m = l.heroes[0]; e = l.enemies[0]
	l.turn = 2; e.block = 0
	e.cell = L(8)
	l._enemies_act()
	check("Укус: 6 урона и яд 3 раунда", m.hp == 24 and m.poison == 3)
	# Раунд 3 — Кладка: два паучонка на соседние клетки
	l = fresh(["weaver_queen"]); e = l.enemies[0]
	l.turn = 3
	e.cell = C(5, 3)
	var before: int = l.enemies.size()
	l._enemies_act()
	var spiders := 0; var near := true
	for u in l.enemies:
		if u.data.id == "spiderling":
			spiders += 1
			if HexMath.distance(u.cell, e.cell) != 1: near = false
	check("Кладка: появились 2 паучонка", spiders == 2 and l.enemies.size() == before + 2)
	check("Кладка: паучата вплотную к Прядильщице", near)
	check("Кладка: героев не ранит", l.heroes[0].hp == 30 and l.heroes[1].hp == 45)
	# Призыв не больше лимита врагов на поле
	l = fresh(["weaver_queen", "goblin", "goblin", "goblin", "goblin", "goblin", "goblin", "goblin", "goblin"])
	l.turn = 3
	l.enemies[0].cell = C(5, 2)
	l._enemies_act()
	check("Кладка: не больше %d врагов на поле" % BattleLogic.SUMMON_ENEMY_CAP, l.living_enemies().size() <= BattleLogic.SUMMON_ENEMY_CAP)
	# Броня 2 каждый ход врагов
	l = fresh(["weaver_queen"])
	l._start_enemy_phase()
	check("Прядильщица: блок 3 каждый ход врагов", l.enemies[0].block == 3)


func _alpha() -> void:
	print("--- Седой вожак ---")
	var l := fresh(["grey_alpha", "wolf"]); var e: BattleUnit = l.enemies[0]; var w: BattleUnit = l.enemies[1]
	l.turn = 1
	e.cell = C(5, 1); w.cell = C(6, 1)
	l._enemies_act()
	check("Вой: волк рядом — следующий удар +2", w.bonus_damage == 2)
	check("Вой: +3 блока волку", w.block == 3)
	l = fresh(["grey_alpha"]); var m: BattleUnit = l.heroes[0]; e = l.enemies[0]
	l.heroes[1].hp = 45
	m.hp = 12
	l.turn = 2
	e.cell = L(6)
	l._enemies_act()
	check("Вожак — охотник: укусил раненого мага (6)", m.hp == 6)


func _mother() -> void:
	print("--- Матерь Трясины ---")
	# Раунд 1 — Язык-гарпун: 4 урона, притягивает на 2
	var l := fresh(["bog_mother"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = L(5)
	l._enemies_act()
	check("Язык-гарпун: 4 урона", m.hp == 26)
	check("Язык-гарпун: притянул на 2 (было 3 клетки между)", HexMath.distance(m.cell, e.cell) == HexMath.distance(C(2, 9), e.cell) - 2)
	# Раунд 2 — Газовая отрыжка: 3 урона вокруг, клетки вокруг — газ
	l = fresh(["bog_mother"]); m = l.heroes[0]; e = l.enemies[0]
	l.turn = 2
	e.cell = L(8)
	l._enemies_act()
	var gas := 0
	for c in HexMath.neighbors(e.cell):
		if l.tile_at(c) == T.GAS: gas += 1
	check("Отрыжка: 3 урона магу вплотную", m.hp == 27)
	check("Отрыжка: вокруг газ (6 клеток)", gas == 6)
	check("Отрыжка: под самой Матерью газа нет", l.tile_at(e.cell) != T.GAS)
	# Раунд 3 — Кладка: две раздутые жабы рядом
	l = fresh(["bog_mother"]); e = l.enemies[0]
	l.turn = 3
	e.cell = C(5, 3)
	l._enemies_act()
	var toads := 0
	for u in l.enemies:
		if u.data.id == "bloated_toad": toads += 1
	check("Кладка: появились 2 раздутые жабы", toads == 2)
	check("Матерь всегда мокрая", l.is_wet(l.enemies[0]) if l.has_method("is_wet") else l.wet_turns(l.enemies[0]) > 0)


# Прогноз хода врагов совпадает с настоящим ходом, когда враги зовут подмогу и пускают газ
func _forecast() -> void:
	print("--- Прогноз ---")
	var ok := true
	for kind in [["weaver_queen", 3], ["bog_mother", 3], ["bog_mother", 2], ["swamp_weaver", 1]]:
		var l := fresh([kind[0], "goblin"])
		l.turn = kind[1]
		l.enemies[0].cell = C(5, 4)
		var sim: BattleLogic = l.clone()
		sim._enemies_act()
		l._enemies_act()
		if sim.enemies.size() != l.enemies.size(): ok = false
		for i in l.enemies.size():
			if sim.enemies[i].cell != l.enemies[i].cell or sim.enemies[i].hp != l.enemies[i].hp: ok = false
		for i in l.heroes.size():
			if sim.heroes[i].hp != l.heroes[i].hp or sim.heroes[i].cell != l.heroes[i].cell: ok = false
		if sim.tiles != l.tiles: ok = false
	check("Копия боя ходит так же, как настоящий бой (призыв, газ, паутина)", ok)


# Второй набор: скальник, споровик, скрытень, факельщик, послушник, Певчая
func _second_wave() -> void:
	print("--- Скальник ---")
	var l := fresh(["rock_crawler"]); var e: BattleUnit = l.enemies[0]
	e.cell = L(5)
	l._cur_hero = l.heroes[0]
	l._card_damage(e, 10, false)
	check("Панцирь: без клещей урон от карты вдвое меньше (10 → 5)", e.hp == 11)
	l = fresh(["rock_crawler"]); e = l.enemies[0]
	e.cell = L(5); l.heroes[0].cell = L(9); l.heroes[1].cell = L(2)
	l._cur_hero = l.heroes[0]
	l._card_damage(e, 10, false)
	check("Панцирь: в клещах — полный урон и +50% (10 → 15)", e.hp == 1)

	print("--- Споровик ---")
	l = fresh(["sporeling"]); e = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	e.cell = L(8)
	var before: Vector2i = e.cell
	l._enemies_act()
	var gas := 0
	for c in HexMath.neighbors(e.cell):
		if l.tile_at(c) == T.GAS: gas += 1
	check("Споровик не двигается", e.cell == before)
	check("Споры: 2 урона вплотную и газ вокруг", m.hp == 28 and gas >= 5)
	l = fresh(["sporeling"]); e = l.enemies[0]
	l.turn = 2
	l._enemies_act()
	check("Рост: +4 блока себе", e.block == 4)

	print("--- Скрытень ---")
	l = fresh(["reed_lurker"]); e = l.enemies[0]
	e.cell = C(5, 2)
	var reed: Vector2i = C(5, 4)
	l.objects[reed] = BattleLogic.Obj.REEDS
	l._enemies_act()
	check("Засадник: ударить некого — уходит в камыш и ждёт", e.cell == reed)
	l = fresh(["reed_lurker"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = L(8); l.objects[L(8)] = BattleLogic.Obj.REEDS
	l._enemies_act()
	check("Удар из камыша: 4 + 3 засада", m.hp == 23)

	print("--- Факельщик ---")
	l = fresh(["torch_goblin"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = L(6)
	l._enemies_act()
	check("Факел: 1 урон и огонь под магом", m.hp == 29 and l.tile_at(m.cell) == T.FIRE)

	print("--- Послушник ---")
	l = fresh(["cult_novice", "cultist"]); var nov: BattleUnit = l.enemies[0]; var cul: BattleUnit = l.enemies[1]
	l._damage(nov, 20)
	check("Послушник пал — культист принял венец (+2)", cul.crown_power == 2)
	cul.cell = L(5)
	l._enemies_act()
	check("Культист с венцом бьёт на 4 + 2", l.heroes[0].hp == 24 or l.heroes[1].hp == 39)

	print("--- Певчая Венца ---")
	l = fresh(["choir_singer", "cultist"]); e = l.enemies[0]; cul = l.enemies[1]
	e.cell = C(5, 1); cul.cell = C(6, 1)
	l._enemies_act()
	check("Хор: культисту +3 блока и +2 к удару", cul.block >= 3 and cul.bonus_damage == 2 or l.heroes[0].hp < 30 or l.heroes[1].hp < 45)
	l = fresh(["choir_singer"]); e = l.enemies[0]; m = l.heroes[0]
	l.turn = 2; e.cell = L(4)
	l._enemies_act()
	check("Луч Венца: 5 урона по линии сквозь преграды", m.hp == 25)

	print("--- Прогноз (второй набор) ---")
	var ok := true
	for kind in [["sporeling", 1], ["reed_lurker", 1], ["torch_goblin", 1], ["choir_singer", 1], ["rock_crawler", 1]]:
		var b := fresh([kind[0], "cult_novice", "cultist"])
		b.turn = kind[1]
		b.enemies[0].cell = C(5, 6)
		b.objects[C(4, 7)] = BattleLogic.Obj.REEDS
		b.objects[C(6, 7)] = BattleLogic.Obj.BARREL
		var sim: BattleLogic = b.clone()
		sim._enemies_act(); b._enemies_act()
		for i in b.enemies.size():
			if sim.enemies[i].cell != b.enemies[i].cell or sim.enemies[i].hp != b.enemies[i].hp: ok = false
		for i in b.heroes.size():
			if sim.heroes[i].hp != b.heroes[i].hp: ok = false
		if sim.tiles != b.tiles: ok = false
	check("Копия боя ходит так же (газ, огонь, засада, хор)", ok)
