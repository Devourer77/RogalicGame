extends SceneTree
# Проверка арен: каждая строится, проходима, врагам есть место. Печатает схемы.
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var sym := {BattleLogic.Obj.BOG: "~", BattleLogic.Obj.TREE: "T", BattleLogic.Obj.BARREL: "B",
		BattleLogic.Obj.PLANKS: "=", BattleLogic.Obj.REEDS: "\"", BattleLogic.Obj.STAKES: "#"}
	var fails := 0
	for arena: String in BattleLogic.ARENAS:
		var empty_fields := 0
		for s in range(1, 61):
			run.start_new_run(s)
			var b := BattleLogic.new()
			b.setup(12, 12, run.rng, run.party, run._make_encounter(6, arena == "lair"), arena)
			if b.objects.is_empty(): empty_fields += 1
			if not b._field_is_open(): fails += 1
			if b.enemies.size() < 5: fails += 1
			if s == 1 or s == 2:
				print("--- %s (%s), сид %d ---" % [b.arena_title(), arena, s])
				for y in 12:
					var line := ""
					for x in 12:
						var c := Vector2i(x, y)
						var ch := "."
						if b.ground.get(c, 0) == BattleLogic.Ground.PLANKS: ch = "_"
						if b.tiles.has(c): ch = "o"
						if b.rocks.has(c): ch = "R"
						if b.objects.has(c): ch = sym.get(b.objects[c], "?")
						var u: BattleUnit = b.unit_at(c)
						if u != null: ch = "H" if u.is_hero else "e"
						line += ch + " "
					print(line)
		print("%s: пустых полей (запасной вариант) %d из 60" % [arena, empty_fields])
		if empty_fields > 0: fails += 1
	print("FAILS: %d" % fails)
	quit()
