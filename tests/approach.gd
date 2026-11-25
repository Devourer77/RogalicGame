extends SceneTree
# «Подойти и ударить»: карта, которая не достаёт с места, играется на врага одним действием —
# герой сам подходит (своими шагами) и бьёт. Проверяем расчёт, предпросмотр, отмену и случайные бои.
# Запуск: godot --headless --path . -s tests/approach.gd
var fails: int = 0
var checks: int = 0


func check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", name)


func idx(h: BattleUnit, id: String) -> int:
	for i in h.hand.size():
		if h.hand[i].id == id:
			return i
	return -1


func tutorial_battle() -> BattleLogic:
	var rng := RandomNumberGenerator.new()
	rng.seed = TutorialBattle.SEED
	var l := BattleLogic.new()
	l.keep_deck_order = true
	l.setup(12, 12, rng, TutorialBattle.make_party(root.get_node("Run").HEROES), TutorialBattle.enemy_list(), TutorialBattle.ARENA)
	TutorialBattle.place_enemies(l)
	l.start()
	return l


func _initialize() -> void:
	await process_frame
	var l := tutorial_battle()
	var k: BattleUnit = l.heroes[1]
	var g: BattleUnit = l.enemies[0]
	var sword: int = idx(k, "kb_sword")
	check("Меч с места гоблина не достаёт", not l.get_card_targets(k, sword).has(g.cell))
	var plan: Dictionary = l.approach_targets(k, sword)
	check("Подход к гоблину найден", plan.has(g.cell))
	if plan.has(g.cell):
		check("Клетка подхода — вплотную к гоблину", HexMath.distance(plan[g.cell]["move"], g.cell) == 1)
		check("Путь короткий (не больше 3 шагов)", l.get_move_targets(k)[plan[g.cell]["move"]].size() - 1 <= k.moves_left)
	var preview: Dictionary = l.preview_approach(k, sword, g.cell)
	var state: Dictionary = l.save_state()
	var hp0: int = g.hp
	var cell0: Vector2i = k.cell
	check("Подошёл и ударил одним действием", l.approach_and_play(k, sword, g.cell))
	check("Гоблин ранен", g.hp < hp0)
	check("Рыцарь вплотную к гоблину", HexMath.distance(k.cell, g.cell) == 1)
	check("Предпросмотр совпал с итогом", preview.get("ok", false) and preview["units"][g.id]["hp_after"] == g.hp)
	check("Карта ушла из руки", idx(k, "kb_sword") != sword or k.hand.size() == 4)
	l.load_state(state)
	check("Отмена вернула всё назад", g.hp == hp0 and k.cell == cell0)
	# Без шагов подхода нет
	k.moves_left = 0
	check("Без шагов — подхода нет", l.approach_targets(k, sword).is_empty())

	# Случайные бои: подход никогда не ломает правила и всегда даёт удар
	var run = root.get_node("Run")
	var tried: int = 0
	var bad: int = 0
	for s in 40:
		run.start_new_run(500 + s)
		var b := BattleLogic.new()
		b.setup(12, 12, run.rng, run.party, run._make_encounter(s % 4, false), run.arena_pool(s % 2)[s % run.arena_pool(s % 2).size()])
		b.start()
		for h: BattleUnit in b.heroes:
			for i in h.hand.size():
				var p: Dictionary = b.approach_targets(h, i)
				for target: Vector2i in p:
					tried += 1
					var st: Dictionary = b.save_state()
					var pv: Dictionary = b.preview_approach(h, i, target)
					var ok: bool = b.approach_and_play(h, i, target)
					if not ok or not pv.get("ok", false):
						bad += 1
					b.load_state(st)
					break   # по одному подходу на карту — быстрее
	check("Случайные бои: подходов %d, сбоев %d" % [tried, bad], tried > 20 and bad == 0)
	print("Подойти и ударить: проверок %d, FAILS: %d" % [checks, fails])
	quit(1 if fails > 0 else 0)
