extends SceneTree
# Случайные бои, где герои играют любые карты из пула в случайные цели.
# Ищем ошибки скрипта и расхождения прогноза с реальным ходом врагов.
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var mismatches := 0
	var played := 0
	for s in range(1, 121):
		run.start_new_run(s)
		var b := BattleLogic.new()
		b.setup(12, 12, run.rng, run.party, run._make_encounter(s % 8, s % 10 == 0))
		b.start()
		for t in 8:
			if b.is_over: break
			for h in b.living_heroes():
				var pool: Array[CardData] = h.hero_data.card_pool
				var hand: Array[CardData] = []
				for i in 5: hand.append(pool[run.rng.randi_range(0, pool.size() - 1)])
				h.hand = hand
				h.mana = 6
				for tries in 5:
					if b.is_over or h.hand.is_empty() or not h.is_alive(): break
					var idx: int = run.rng.randi_range(0, h.hand.size() - 1)
					var targets: Array[Vector2i] = b.get_card_targets(h, idx)
					if targets.is_empty() or not b.can_play(h, idx): continue
					if b.play_card(h, idx, targets[run.rng.randi_range(0, targets.size() - 1)]):
						played += 1
				var mv: Dictionary = b.get_move_targets(h)
				if not mv.is_empty() and not b.is_over:
					b.move_hero(h, mv.keys()[run.rng.randi_range(0, mv.size() - 1)])
			if b.is_over: break
			var fc: Array[Dictionary] = b.forecast_enemies()
			var expect: Dictionary = {}
			for f in fc:
				var p: Array = f["path"]
				expect[(f["enemy"] as BattleUnit).id] = p[p.size() - 1]
			var got: Dictionary = {}
			b.unit_moved.connect(func(u: BattleUnit, path: Array[Vector2i]) -> void:
				if not u.is_hero and not got.has(u.id): got[u.id] = path[path.size() - 1])
			var start_cells: Dictionary = {}
			for e in b.living_enemies(): start_cells[e.id] = e.cell
			b._enemies_act()
			for id in expect:
				var real: Vector2i = got.get(id, start_cells.get(id, expect[id]))
				if real != expect[id]: mismatches += 1
			if not b.is_over:
				# остаток хода: огонь, таймеры, новый ход (враги уже сходили)
				for c: Vector2i in b.fire_timers.keys():
					b.fire_timers[c] -= 1
					if b.fire_timers[c] <= 0: b._set_tile(c, BattleLogic.Tile.NONE)
				b._tick_objects()
				if not b._check_end(): b._start_heroes_turn()
	print("сыграно карт: %d, расхождений прогноза: %d" % [played, mismatches])
	quit()
