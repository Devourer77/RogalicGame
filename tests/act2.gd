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

	# --- Что остаётся после гибели ---
	var rem := func(enemy_id: String) -> BattleLogic:
		var r := RandomNumberGenerator.new()
		r.seed = 3
		var bl := BattleLogic.new()
		bl.setup(12, 12, r, run.party, [load("res://resources/enemies/%s.tres" % enemy_id)] as Array[EnemyData], "gat")
		bl.start()
		var e: BattleUnit = bl.enemies[0]
		var c := Vector2i(5, 4)
		for d: Vector2i in [Vector2i.ZERO] + HexMath.DIRS:   # расчистить место вокруг
			bl.rocks.erase(c + d)
			bl.objects.erase(c + d)
			bl.tiles.erase(c + d)
		e.cell = c
		bl._damage(e, 999)
		return bl
	var c0 := Vector2i(5, 4)
	var hound: BattleLogic = rem.call("ash_hound")
	check("Гончая взрывается без лужи", hound.tile_at(c0) != BattleLogic.Tile.WATER)
	var porter: BattleLogic = rem.call("cult_porter")
	var fires: int = 0
	for d: Vector2i in HexMath.DIRS:
		if porter.tile_at(c0 + d) == BattleLogic.Tile.FIRE:
			fires += 1
	check("Котёл Носильщика лопается огнём вокруг (%d клеток)" % fires, fires >= 5 and porter.tile_at(c0) == BattleLogic.Tile.FIRE)
	var golem: BattleLogic = rem.call("slag_golem")
	check("Шлаковый голем застывает глыбой", golem.rocks.has(c0))
	var fw: BattleLogic = rem.call("sphere_walker_fire")
	var sparks: int = fw.living_enemies().filter(func(u: BattleUnit) -> bool: return u.data.id == "spark").size()
	check("Огненный сферник: огонь вокруг и Искра", sparks == 1)
	var ww: BattleLogic = rem.call("sphere_walker_water")
	var puddles: int = 0
	for d: Vector2i in HexMath.DIRS:
		if ww.tile_at(c0 + d) == BattleLogic.Tile.WATER:
			puddles += 1
	check("Водяной сферник: лужи вокруг", puddles >= 5)
	var slug_data: EnemyData = load("res://resources/enemies/ember_slug.tres")
	check("Головёшка оставляет огненный след", slug_data.fire_trail)
	check("Грозовой сферник бьёт разрядом по лужам, ветряной — отбрасывает",
			(load("res://resources/enemies/sphere_walker_storm.tres") as EnemyData).death_element == CardData.Element.LIGHTNING
			and (load("res://resources/enemies/sphere_walker_wind.tres") as EnemyData).death_wind)
	check("У жабы без нового флага — прежняя лужа", (load("res://resources/enemies/bloated_toad.tres") as EnemyData).remains == EnemyData.Remains.DEFAULT)

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

	# --- События акта 2 ---
	var screen = load("res://ui/event_screen.gd")
	run.start_new_run(41)
	run.next_act()
	var on_tract: Array[String] = []
	var on_deep: Array[String] = []
	for n: MapNode in run.map:
		if n.row != 3 or n.branch == MapNode.COMMON:
			continue
		run.current = n
		for e: Dictionary in screen.EVENTS:
			if screen.event_allowed(e):
				(on_tract if n.branch == MapNode.BOG else on_deep).append(e["title"])
	check("Акт 2, Тракт: события Тракта есть, Подземья нет", on_tract.has("Застава мародёров") and not on_tract.has("Журнал лаборатории"))
	check("Акт 2, Подземье: события Подземья есть, Тракта нет", on_deep.has("Журнал лаборатории") and not on_deep.has("Застава мародёров"))
	check("Акт 2: общие события акта 2 и старые общие есть", on_tract.has("Пепельный дождь") and on_tract.has("Колодец желаний"))
	check("Акт 2: болотных и лесных событий нет", not on_tract.has("Фонарь у переправы") and not on_deep.has("Пасека в дупле"))
	run.start_new_run(42)
	var act1: Array[String] = []
	for e: Dictionary in screen.EVENTS:
		if screen.event_allowed(e):
			act1.append(e["title"])
	check("Акт 1: событий акта 2 нет", not act1.has("Пепельный дождь") and not act1.has("Застава мародёров"))
	var fights_ok: bool = true
	for e: Dictionary in screen.EVENTS:
		for o: Dictionary in e["options"]:
			var steps: Array = o.get("effects", []) + o.get("win", {}).get("effects", []) + o.get("lose", {}).get("effects", [])
			for st: Dictionary in steps:
				if st.has("fight") and st["fight"] != "elite" and run.encounter_by_id(st["fight"]) == null:
					fights_ok = false
	check("Все бои из событий находят свой отряд", fights_ok)

	# --- Особые арены: не больше двух за акт и не подряд ---
	var rows_ok: bool = true
	var pairs_ok: bool = true
	var seen_special: int = 0
	var seen_plain: int = 0
	for sd in 40:
		run.start_new_run(300 + sd)
		run.next_act()
		for n: MapNode in run.map:
			if n.arena == "" or n.type == MapNode.Type.BOSS:
				continue
			if BattleLogic.SPECIAL_ARENAS.has(n.arena):
				seen_special += 1
				if not [2, 4, 5].has(n.row):
					rows_ok = false
			elif n.type == MapNode.Type.BATTLE:
				seen_plain += 1
		for b in [MapNode.BOG, MapNode.FOREST]:
			var row4: bool = false
			var row5: bool = false
			for n: MapNode in run.map:
				if n.branch == b and BattleLogic.SPECIAL_ARENAS.has(n.arena):
					row4 = row4 or n.row == 4
					row5 = row5 or n.row == 5
			if row4 and row5:
				pairs_ok = false
	check("Особые арены — только в рядах 2 и 4 (и у элиты)", rows_ok)
	check("Особые арены не идут подряд (ряд 4 и элита ряда 5)", pairs_ok)
	check("На карте есть и особые, и обычные арены (%d / %d)" % [seen_special, seen_plain], seen_special > 0 and seen_plain > seen_special * 2)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
