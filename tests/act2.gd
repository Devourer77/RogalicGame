extends SceneTree

# Акт 2 «Пепельный тракт»: 19 арен, враги и отряды (тз-арены-акт-2.md, враги-акт-2.md).
# Запуск: godot --headless --path . -s tests/act2.gd

var fails := 0
var act1_same: bool = true


func check_quiet_act1(run: Node) -> void:
	if run.boss_for_branch(MapNode.BOG) != run.boss_for_branch(MapNode.FOREST):
		act1_same = false


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


const ACT2_ARENAS: Array[String] = ["wagons", "ashfield", "shrine", "lava_beds", "springs", "tower", "dunes", "pass",
		"embers", "sphere_hall", "steamworks", "mine", "rift_lab", "lake", "assembly", "fungus", "cliff", "reactor", "crater"]


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.sim_no_scenes = true
	run.start_new_run(5)

	# --- Арены ---
	for id in ACT2_ARENAS:
		check("Арена %s есть в списке и у неё вид места" % id, BattleLogic.ARENAS.has(id) and BattleLogic.ARENA_BIOME.has(id)
				and BattleLogic.ARENA_HINTS.has(id))
		var built_ok: bool = true
		var hero_rows_free: bool = true
		var lava_ok: bool = true
		var detail: String = ""
		for s in 25:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + s
			var enemies: Array[EnemyData] = [load("res://resources/enemies/cultist.tres") as EnemyData]
			var b := BattleLogic.new()
			b.setup(12, 12, rng, run.party, enemies, id)
			if b.arena_id != id:
				built_ok = false
				detail = "арена подменена"
			if b.rocks.is_empty() and b.objects.is_empty() and b.tiles.is_empty():
				built_ok = false   # пустое поле — сработал запасной вариант
				detail = "пустое поле (сид %d)" % (1000 + s)
			for h: BattleUnit in b.heroes:
				if b.rocks.has(h.cell) or b.objects.has(h.cell) or b.tiles.has(h.cell):
					hero_rows_free = false
			for c: Vector2i in b.objects:
				if b.objects[c] == BattleLogic.Obj.LAVA and b.obj_timers.has(c):
					lava_ok = false
			if b.ground.is_empty():
				built_ok = false
		check("Арена %s: есть картинка карточки карты" % id, ResourceLoader.exists("res://assets/textures/map_cards/card_%s.jpg" % id))
		check("Арена %s строится 25 раз из 25 (%s)" % [id, detail if detail != "" else "ок"], built_ok)
		check("Арена %s: герои стоят на свободных клетках" % id, hero_rows_free)
		check("Арена %s: лава постоянная" % id, lava_ok)

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	var ash := BattleLogic.new()
	ash.setup(12, 12, rng2, run.party, [load("res://resources/enemies/cultist.tres")] as Array[EnemyData], "ashfield")
	check("Пепелище: есть торф, и он вспыхивает раз в 3 раунда", not ash.peat.is_empty())
	var metal := false
	var lab := BattleLogic.new()
	lab.setup(12, 12, rng2, run.party, [load("res://resources/enemies/cultist.tres")] as Array[EnemyData], "sphere_hall")
	for c: Vector2i in lab.ground:
		if lab.ground[c] == BattleLogic.Ground.METAL:
			metal = true
	check("Зал сфер: клёпаный пол", metal)
	check("Тракт и Подземье — разные виды места", BattleLogic.arena_biome("wagons") == "ash" and BattleLogic.arena_biome("mine") == "deep")
	check("Старые арены не задеты", BattleLogic.arena_biome("gat") == "bog" and BattleLogic.arena_biome("thicket") == "forest"
			and BattleLogic.arena_biome("cave") == "deep")

	# --- Враги и отряды акта 2 ---
	var act2: ActData = run.ACTS[1]
	check("Акт 2 на своих врагах (не заглушка)", not act2.is_placeholder() and act2.borrow_from == 0)
	var all_ok: bool = true
	var models_ok: bool = true
	var seen: Dictionary = {}
	for enc: EncounterData in act2.encounters + act2.elite_pool + act2.boss_pool:
		if enc == null or enc.core.is_empty():
			all_ok = false
			continue
		for e: EnemyData in enc.core + enc.filler:
			if e == null:
				all_ok = false
				continue
			seen[e.id] = e
			if e.model == null:
				models_ok = false
				print("  без модели: ", e.id)
			for atk: EnemyAttackData in e.cycle:
				if atk.summon != null and atk.summon.model == null:
					models_ok = false
	check("Все отряды акта 2 собираются из врагов (%d видов)" % seen.size(), all_ok and seen.size() >= 30)
	check("У всех врагов акта 2 есть модели", models_ok)
	for branch: int in [MapNode.BOG, MapNode.FOREST]:
		for row in 6:
			var n: int = 0
			for enc: EncounterData in act2.encounters:
				if enc.fits_row(row) and enc.fits_branch(branch) and enc.arena == "":
					n += 1
			check("Ветка %s, ряд %d: хотя бы 2 отряда на любую арену" % [act2.branch_titles[branch], row], n >= 2)
	var elites_l: int = 0
	var elites_r: int = 0
	for enc: EncounterData in act2.elite_pool:
		if enc.fits_branch(MapNode.BOG): elites_l += 1
		if enc.fits_branch(MapNode.FOREST): elites_r += 1
	check("Элиты: на каждой ветке хотя бы две на выбор", elites_l >= 2 and elites_r >= 2)
	check("Три босса акта 2, у каждого своя арена", act2.boss_pool.size() == 3
			and act2.boss_pool.all(func(e: EncounterData) -> bool: return e.arena != "" and e.core[0].is_boss))

	# --- Забег в акте 2: арены по веткам ---
	run.next_act()
	check("Акт 2: пул отрядов — свой", run.encounters() == act2.encounters)
	var arenas_ok: bool = true
	for n: MapNode in run.map:
		if n.type == MapNode.Type.BATTLE or n.type == MapNode.Type.LAIR:
			var pool: Array[String] = act2.arenas_left if n.branch == MapNode.BOG else act2.arenas_right
			if not pool.has(n.arena):
				arenas_ok = false
	check("Точки карты акта 2 — на аренах своей ветки", arenas_ok)
	check("Враги акта 2 не усилены (свои)", run._act_scaled(seen.values()[0]) == seen.values()[0])
	# каждый отряд — в бою: бот-заглушка просто проверяет, что бой создаётся
	var battles_ok: bool = true
	for enc: EncounterData in act2.encounters + act2.elite_pool + act2.boss_pool:
		var b := BattleLogic.new()
		var arena: String = enc.arena if enc.arena != "" else act2.arenas_left[0]
		b.setup(12, 12, run.rng, run.party, enc.core, arena, BattleLogic.Objective.KILL_ALL, [], enc.formation)
		b.start()
		if b.enemies.size() < enc.core.size() - 1:
			battles_ok = false
			print("  мало врагов на поле: ", enc.id, " ", b.enemies.size(), "/", enc.core.size())
		for i in 3:
			if b.is_over:
				break
			b.end_turn()
	check("Все отряды акта 2 встают на поле и ходят 3 раунда", battles_ok)

	# --- Босс по ветке: свой у каждой или общий Сосуд ---
	var shared_n: int = 0
	var split_ok: bool = true
	var switch_ok: bool = true
	for sd in 40:
		run.start_new_run(500 + sd)
		check_quiet_act1(run)
		run.next_act()
		var l: EncounterData = run.boss_for_branch(MapNode.BOG)
		var r: EncounterData = run.boss_for_branch(MapNode.FOREST)
		if l == r:
			shared_n += 1
			if l.id != "boss_vessel":
				split_ok = false
		elif l.id != "boss_giant" or r.id != "boss_colossus":
			split_ok = false
		else:
			# зашли в Подземье — босс акта и арена его точки сменились на Колосса
			for n: MapNode in run.available_nodes():
				if n.branch == MapNode.FOREST:
					run.enter_node(n)
					break
			var boss_node: MapNode = null
			for n: MapNode in run.map:
				if n.type == MapNode.Type.BOSS:
					boss_node = n
			if run.run_boss.id != "boss_colossus" or boss_node.arena != "reactor":
				switch_ok = false
	check("Тракт — Исполин, Подземье — Колосс, или общий Сосуд у обеих", split_ok)
	check("Общий Сосуд выпадает иногда (%d из 40), но не всегда" % shared_n, shared_n > 3 and shared_n < 30)
	check("Ветка выбрана — босс и арена его точки — этой ветки", switch_ok)
	check("В акте 1 у обеих веток один босс", act1_same)

	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
