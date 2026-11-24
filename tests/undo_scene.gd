extends SceneTree
# Отмена хода в сцене боя: после «Отменить» поле и фигурки совпадают с тем, что было до действия.
# Бои на аренах с бочками, деревьями, лужами, сферами, вагонетками; герои делают случайные
# действия через сцену (как клики игрока), после каждого — иногда отмена одного или
# нескольких шагов. Сравнивается «вид»: где стоят и видны ли фигурки, объекты, эффекты
# на клетках, преграды, журнал, — и полный снимок логики.
# Запуск: godot --headless --path . -s tests/undo_scene.gd

const ARENAS: Array[String] = ["grove", "ruins", "mine", "sphere_hall", "pump", "thicket", "crater", "assembly"]

var errors: int = 0
var checks: int = 0
var undone: int = 0


func check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		errors += 1
		if errors <= 15:
			print("  ОШИБКА: ", name)


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.fast_enemies = true
	for i in ARENAS.size():
		var arena: String = ARENAS[i]
		if OS.get_environment("ONLY") != "" and OS.get_environment("ONLY") != arena:
			continue   # ONLY=mine — только одна арена (для отладки)
		run.start_new_run(40 + i)
		run.pending_enemies = run._make_encounter(2 + i % 4, false, false)
		run.pending_arena = arena
		run.pending_objective = 0
		change_scene_to_file("res://scenes/battle.tscn")
		await wait_idle(600)
		var b = current_scene
		b.logic.heroes[0].hp = 999
		b.logic.heroes[1].hp = 999
		b._enter_idle()   # прогноз врагов — уже с новым здоровьем героев
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + i
		for turn in 3:
			if b.logic.is_over:
				break
			# Стек шагов: вид и логика перед каждым действием этого хода
			var stack: Array[Dictionary] = []
			for step in 6:
				if b.logic.is_over:
					break
				var act: Callable = pick_action(b, rng)
				if not act.is_valid():
					break
				var before: Dictionary = {"view": view_sign(b), "logic": b.logic.save_state()}
				var count_before: int = b._undo.size()
				b._do(act)
				await wait_idle(400)
				if b.logic.is_over:
					break
				if b._undo.size() > count_before:
					stack.append(before)
				elif b._undo.is_empty():
					stack.clear()   # действие закрыло отмену (добор карты)
				# Иногда — отмена: одного шага или сразу всех
				var roll: int = rng.randi_range(0, 9)
				if roll < 4 and not stack.is_empty():
					var times: int = stack.size() if roll == 0 else 1
					for k in times:
						var want: Dictionary = stack.pop_back()
						b._on_undo_pressed()
						await wait_idle(50)
						undone += 1
						compare(b, want, "%s ход %d шаг %d" % [arena, turn, step])
			if b.logic.is_over:
				break
			b._on_end_turn_pressed()
			await wait_idle(1500)
			check("%s: после конца хода стек пуст" % arena, b._undo.is_empty())
		# Кнопка, справка и замок существуют
		check("кнопка «Отменить» есть", b.hud._undo_button != null)
	print("арен: %d, отмен: %d, проверок: %d" % [ARENAS.size(), undone, checks])
	print("ошибок: %d" % errors)
	quit(1 if errors > 0 else 0)


func wait_idle(max_frames: int) -> void:
	for f in max_frames:
		await process_frame
		var b = current_scene
		if b != null and "_mode" in b and (b._mode == b.Mode.IDLE or b.logic.is_over) and b._anim_queue.is_empty():
			if f > 2:
				return


# Случайное законное действие выбранного героя — как клик игрока (через сцену)
func pick_action(b, rng: RandomNumberGenerator) -> Callable:
	var logic: BattleLogic = b.logic
	var heroes: Array[BattleUnit] = logic.living_heroes()
	var h: BattleUnit = heroes[rng.randi_range(0, heroes.size() - 1)]
	for attempt in 6:
		var roll: int = rng.randi_range(0, 9)
		if roll < 6 and not h.hand.is_empty():
			var idx: int = rng.randi_range(0, h.hand.size() - 1)
			if logic.can_play(h, idx):
				var targets: Array[Vector2i] = [h.cell]
				if h.hand[idx].shape != CardData.Shape.SELF:
					targets = logic.get_card_targets(h, idx)
				if not targets.is_empty():
					var t: Vector2i = targets[rng.randi_range(0, targets.size() - 1)]
					return func() -> void: logic.play_card(h, idx, t)
		elif roll < 9:
			var mv: Dictionary = logic.get_move_targets(h)
			if not mv.is_empty():
				var c: Vector2i = mv.keys()[rng.randi_range(0, mv.size() - 1)]
				return func() -> void: logic.move_hero(h, c)
		elif not h.hand.is_empty():
			var idx: int = rng.randi_range(0, h.hand.size() - 1)
			return func() -> void: logic.scrap_card(h, idx)
	return Callable()


# «Вид» боя: что видит игрок
func view_sign(b) -> Dictionary:
	var units: Dictionary = {}
	for u: BattleUnit in b._views:
		var v: Node3D = b._views[u]
		if not is_instance_valid(v):
			units[u.id] = "освобождена"
			continue
		var p: Vector3 = v.position
		units[u.id] = [v.visible, snappedf(p.x, 0.01), snappedf(p.z, 0.01)]
	var objects: Dictionary = {}
	for c: Vector2i in b.board._object_kinds:
		objects[c] = b.board._object_kinds[c]
	var effects: Dictionary = {}
	for c: Vector2i in b.board._effect_kinds:
		effects[c] = b.board._effect_kinds[c]
	var rocks: Array = b.board._rock_nodes.keys()
	rocks.sort()
	return {"units": units, "objects": objects, "effects": effects, "rocks": rocks, "log": b.hud.get_log()}


func compare(b, want: Dictionary, where: String) -> void:
	var now: Dictionary = view_sign(b)
	for key: String in ["units", "objects", "effects", "rocks", "log"]:
		check("%s: после отмены отличается %s: было %s, стало %s" % [where, key, want["view"][key], now[key]],
				now[key] == want["view"][key])
	var diff: PackedStringArray = StateCopy.diff(want["logic"], b.logic.save_state())
	check("%s: логика после отмены отличается %s" % [where, diff], diff.is_empty())
	if not diff.is_empty() and OS.get_environment("DEBUG") != "":
		for u: BattleUnit in want["logic"]["__units"]:
			var was: String = want["logic"]["__units"][u]["ai_reason"]
			if was != u.ai_reason:
				print("    ", u.title, ": было «", was, "», стало «", u.ai_reason, "»")
	check("%s: сцена ждёт ввода" % where, b._mode == b.Mode.IDLE)
