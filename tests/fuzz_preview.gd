extends SceneTree
# Предпросмотр карты = настоящий розыгрыш.
# Случайные бои на всех аренах, случайные руки из всех карт (наборы, духи, смешанные пары):
# перед каждой картой — preview_card(), потом та же карта по-настоящему. Совпасть должны
# здоровье, блок, гибель и клетки юнитов, реакции и цепочки по порядку, клетки и объекты поля.
# Запуск: godot --headless --path . -s tests/fuzz_preview.gd   (BATTLES=N, по умолчанию 120)

var errors: int = 0
var checks: int = 0
var plays: int = 0
var with_chain: int = 0
var with_self: int = 0
var _extra: Dictionary = {}


func check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		errors += 1
		if errors <= 15:
			print("  РАСХОЖДЕНИЕ: ", name)


func extra_cards(hero_id: String) -> Array[CardData]:
	if _extra.has(hero_id):
		return _extra[hero_id]
	var mark: String = "m" if hero_id == "mage" else "k"
	var list: Array[CardData] = []
	var dirs: Array[String] = ["res://resources/cards/mixed"]
	for d in DirAccess.get_directories_at("res://resources/cards/spirits"):
		dirs.append("res://resources/cards/spirits/" + d)
	for dir in dirs:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".tres") and f.get_basename().rsplit("_", true, 1)[-1].begins_with(mark):
				list.append(load(dir + "/" + f))
	_extra[hero_id] = list
	return list


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var battles: int = int(OS.get_environment("BATTLES")) if OS.get_environment("BATTLES") != "" else 120
	var act2: ActData = load("res://resources/acts/act_2.tres")
	var act2_fights: Array[EncounterData] = act2.encounters + act2.elite_pool + act2.boss_pool
	var all_arenas: Array = BattleLogic.ARENAS.keys()
	for s in range(1, battles + 1):
		run.start_new_run(s)
		var b := BattleLogic.new()
		if s % 2 == 0:
			var enc: EncounterData = act2_fights[s % act2_fights.size()]
			var arena: String = enc.arena if enc.arena != "" else all_arenas[s % all_arenas.size()]
			b.setup(12, 12, run.rng, run.party, enc.core, arena, BattleLogic.Objective.KILL_ALL, [], enc.formation)
		else:
			b.setup(12, 12, run.rng, run.party, run._make_encounter(s % 8, s % 10 == 1, s % 4 == 1),
					all_arenas[s % all_arenas.size()])
		b.start()
		# Что случилось на самом деле — теми же сигналами, что собирает предпросмотр
		var real: Dictionary = {}
		b.reaction.connect(func(c: Vector2i, kind: String) -> void: real["reactions"].append({"cell": c, "kind": kind}))
		b.effect_cells.connect(func(cells: Array[Vector2i], kind: String) -> void: real["chain"].append(kind))
		for t in 6:
			if b.is_over:
				break
			for h in b.living_heroes():
				var pool: Array[CardData] = h.hero_data.card_pool + extra_cards(h.hero_data.id)
				var hand: Array[CardData] = []
				for i in 5:
					hand.append(pool[run.rng.randi_range(0, pool.size() - 1)])
				h.hand = hand
				h.kept.clear()
				h.mana = 6
			for step in 8:
				if b.is_over:
					break
				var heroes: Array[BattleUnit] = b.living_heroes()
				var h: BattleUnit = heroes[run.rng.randi_range(0, heroes.size() - 1)]
				if h.hand.is_empty():
					continue
				var idx: int = run.rng.randi_range(0, h.hand.size() - 1)
				if not b.can_play(h, idx):
					continue
				var targets: Array[Vector2i] = [h.cell]
				if h.hand[idx].shape != CardData.Shape.SELF:
					targets = b.get_card_targets(h, idx)
				if targets.is_empty():
					continue
				var target: Vector2i = targets[run.rng.randi_range(0, targets.size() - 1)]
				var card_id: String = h.hand[idx].id
				var p: Dictionary = b.preview_card(h, idx, target)
				var units_before: Array[BattleUnit] = b.heroes + b.enemies
				var was: Dictionary = {}   # id -> [здоровье, клетка, жив]
				for u in units_before:
					was[u.id] = [u.hp, u.cell, u.is_alive()]
				real["reactions"] = [] as Array[Dictionary]
				real["chain"] = [] as Array[String]
				var ok: bool = b.play_card(h, idx, target)
				plays += 1
				var where: String = "бой %d (%s), карта %s" % [s, b.arena_id, card_id]
				check(where + ": сыграна ли", ok == p["ok"])
				compare(b, p, real, units_before, was, where)
			if not b.is_over:
				b.end_turn()
	print("боёв: %d, карт: %d, с цепочкой: %d, с уроном по своим: %d, проверок: %d" % [battles, plays, with_chain, with_self, checks])
	print("расхождений: %d" % errors)
	quit(1 if errors > 0 else 0)


func compare(b: BattleLogic, p: Dictionary, real: Dictionary, units_before: Array[BattleUnit], was: Dictionary, where: String) -> void:
	if not (p["chain"] as Array).is_empty():
		with_chain += 1
	var self_hit: bool = false
	for u in units_before:
		var info: Dictionary = p["units"].get(u.id, {})
		if info.is_empty():
			# Предпросмотр говорит «не изменится» — так и должно быть
			if was[u.id][2]:
				check("%s: %s изменился, а показано «без изменений»" % [where, u.title],
						u.hp == was[u.id][0] and u.cell == was[u.id][1] and u.is_alive())
			continue
		check("%s: %s здоровье %d, а показано %d" % [where, u.title, u.hp, info["hp_after"]], u.hp == info["hp_after"])
		check("%s: %s блок %d, а показано %d" % [where, u.title, u.block, info["block_after"]],
				info["block_after"] >= info["block"] or u.block == info["block_after"])
		check("%s: %s гибель" % [where, u.title], (not u.is_alive()) == info["killed"])
		if u.is_alive():
			check("%s: %s клетка" % [where, u.title], u.cell == info["cell"])
		if u.is_hero and info["dealt"] > 0:
			self_hit = true
	if self_hit:
		with_self += 1
	check("%s: реакции %s, показано %s" % [where, real["reactions"], p["reactions"]], real["reactions"] == p["reactions"])
	var kinds: Array[String] = []
	for c: Dictionary in p["chain"]:
		kinds.append(c["kind"])
	check("%s: цепочка %s, показано %s" % [where, real["chain"], kinds], real["chain"] == kinds)
	for c: Vector2i in p["tiles"]:
		check("%s: клетка %s" % [where, c], b.tiles.get(c, BattleLogic.Tile.NONE) == p["tiles"][c])
	for c: Vector2i in p["objects"]:
		check("%s: объект %s" % [where, c], b.objects.get(c, BattleLogic.Obj.NONE) == p["objects"][c])
