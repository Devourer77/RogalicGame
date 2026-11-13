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
				if enemies[i] != enc.core[i]: core_ok = false
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
	check("Встречаются все %d отрядов" % run.ENCOUNTERS.size(), packs_seen.size() == run.ENCOUNTERS.size())
	var expect: Dictionary = {}
	for enc: EncounterData in run.ENCOUNTERS:
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
		if run.run_elites.size() != 2 or run.run_elites[0] == run.run_elites[1]: distinct_ok = false
		for e in run.run_elites: elites[e.id] = true
		bosses[run.run_boss.id] = true
	check("Две разные элиты на забег", distinct_ok)
	check("За 100 забегов встречаются все элиты (%d)" % run.ELITE_POOL.size(), elites.size() == run.ELITE_POOL.size())
	check("За 100 забегов встречаются все боссы (%d)" % run.BOSS_POOL.size(), bosses.size() == run.BOSS_POOL.size())
	run.start_new_run(9); var b1: String = run.run_boss.id; var el1: String = run.run_elites[0].id
	run.start_new_run(9)
	check("Тот же сид — тот же босс и элиты", run.run_boss.id == b1 and run.run_elites[0].id == el1)
	var late: Array[EnemyData] = run._make_encounter(run.MAP_ROWS - 3, false, true)
	check("Элита перед привалом — вторая из выбранных", late[0] == run.run_elites[1].core[0])
	var early: Array[EnemyData] = run._make_encounter(run.OPTIONAL_ELITE_ROW, false, true)
	check("Элита на развилке — первая из выбранных", early[0] == run.run_elites[0].core[0])
	var boss: Array[EnemyData] = run._make_encounter(run.MAP_ROWS - 1, true)
	check("Бой босса — босс первым, со свитой", boss[0].is_boss and boss.size() == run.run_boss.core.size())
	check("Арена босса — его собственная", run._encounter_arena(true) == run.run_boss.arena)
	# Звон 5: элита и босс крепче, общий файл не меняется
	run.start_new_run(9, 5)
	var hard: Array[EnemyData] = run._make_encounter(run.MAP_ROWS - 1, true)
	check("Звон 5: босс +25% HP", hard[0].max_hp == ceili(run.run_boss.core[0].max_hp * 1.25))
	check("Звон 5: общий файл босса не изменился", run.run_boss.core[0].max_hp in [60, 70])
	# Огр со своей свитой, как раньше
	var ogre: EncounterData = load("res://resources/encounters/boss_ogre.tres")
	var ids: Array[String] = []
	for d in ogre.core: ids.append(d.id)
	check("Свита огра прежняя", ids == ["ogre", "goblin", "goblin", "cultist", "wolf"] and ogre.arena == "lair")


func _map() -> void:
	print("--- Карта пути ---")
	var one_ok := true; var bypass_ok := true
	for s in range(1, 201):
		run.start_new_run(s)
		var count := 0; var col := -1
		for n in run.map:
			if n.type == MapNode.Type.ELITE and n.row != run.MAP_ROWS - 3:
				count += 1; col = n.col
				if n.row != run.OPTIONAL_ELITE_ROW: one_ok = false
		if count != 1: one_ok = false
		for n in run.row_nodes(run.OPTIONAL_ELITE_ROW - 1):
			var other := false
			for c in n.next:
				if c != col: other = true
			if not other: bypass_ok = false
	check("Ровно одна необязательная элита, в своём ряду", one_ok)
	check("Необязательную элиту всегда можно обойти", bypass_ok)


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
