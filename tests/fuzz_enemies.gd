extends SceneTree
# Случайные бои с новыми врагами (обычные, элитные и с боссом): герои играют случайные
# карты и ходят куда попало. Перед каждым ходом врагов этот ход «проигрывается» на копии
# боя (как это делает прогноз), и результат сравнивается с настоящим: клетки, здоровье,
# блок, опутывание, объекты и стихии. Любое отличие — прогноз соврал бы игроку.
# Запуск: godot --headless --path . -s tests/fuzz_enemies.gd

# Всё состояние боя одной строкой — чтобы сравнить копию и оригинал
func signature(b: BattleLogic) -> String:
	var parts: PackedStringArray = []
	for u: BattleUnit in b.heroes + b.enemies:
		parts.append("%d:%s:%d:%d:%d:%d" % [u.id, u.cell, u.hp, u.block, u.entangled, u.bonus_damage])
	var cells: Array = b.objects.keys() + b.tiles.keys()
	cells.sort()
	for c: Vector2i in cells:
		parts.append("%s=%d/%d" % [c, b.object_at(c), b.tile_at(c)])
	return "|".join(parts)


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var mismatches := 0
	var route_mismatches := 0
	var played := 0
	var enemy_turns := 0
	var seen: Dictionary = {}
	var hero_bog_deaths := 0
	for s in range(1, 301):
		run.start_new_run(s)
		var b := BattleLogic.new()
		var elite: bool = s % 4 == 0
		b.setup(12, 12, run.rng, run.party, run._make_encounter(s % 8, s % 10 == 0, elite))
		for e in b.enemies: seen[e.data.id] = true
		b.start()
		for t in 10:
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
			# Прогноз (как в игре): куда встанет каждый враг
			var expect: Dictionary = {}
			for f in b.forecast_enemies():
				var p: Array = f["path"]
				expect[(f["enemy"] as BattleUnit).id] = p[p.size() - 1]
			# Полная копия хода врагов
			var sim: BattleLogic = b.clone()
			sim._enemies_act()
			var want: String = signature(sim)
			var got: Dictionary = {}
			var on_move := func(u: BattleUnit, path: Array[Vector2i]) -> void:
				if not u.is_hero: got[u.id] = path[path.size() - 1]
			b.unit_moved.connect(on_move)
			var start_cells: Dictionary = {}
			for e in b.living_enemies(): start_cells[e.id] = e.cell
			b._enemies_act()
			b.unit_moved.disconnect(on_move)
			enemy_turns += 1
			if signature(b) != want:
				mismatches += 1
				if mismatches <= 3: print("РАСХОЖДЕНИЕ сид %d ход %d\n  копия: %s\n  бой:   %s" % [s, t, want, signature(b)])
			for id in expect:
				if got.get(id, start_cells.get(id, expect[id])) != expect[id]: route_mismatches += 1
			# Никто из живых не должен стоять в трясине, кроме топляка
			for u: BattleUnit in b.living_heroes() + b.living_enemies():
				if b.object_at(u.cell) == BattleLogic.Obj.BOG and not b._walks_bog(u):
					hero_bog_deaths += 1
			if not b.is_over:
				# остаток хода: огонь, таймеры, новый ход (враги уже сходили)
				for c: Vector2i in b.fire_timers.keys():
					if not b.fire_timers.has(c): continue
					var u: BattleUnit = b.unit_at(c)
					if u != null: b._damage(u, BattleLogic.FIRE_DAMAGE)
					if not b.fire_timers.has(c): continue
					b.fire_timers[c] -= 1
					if b.fire_timers[c] <= 0: b._set_tile(c, BattleLogic.Tile.NONE)
				b._tick_objects()
				if not b._check_end(): b._start_heroes_turn()
	print("виды врагов в боях: %d из 9" % seen.size())
	print("сыграно карт: %d, ходов врагов: %d" % [played, enemy_turns])
	print("расхождений полного состояния: %d, расхождений маршрутов: %d, кто-то стоит в трясине: %d" % [mismatches, route_mismatches, hero_bog_deaths])
	quit(1 if mismatches + route_mismatches + hero_bog_deaths > 0 else 0)
