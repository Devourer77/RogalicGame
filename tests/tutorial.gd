extends SceneTree
# Учебный бой: сценарий проходится от начала до «Дальше сам», неправильные нажатия
# ничего не делают, после «Конца хода» всё разблокировано; бой можно довести до конца,
# и после него отметка «обучение пройдено» сохраняется.
# Запуск: godot --headless --path . -s tests/tutorial.gd

var errors: int = 0
var checks: int = 0


func check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		errors += 1
		print("  ОШИБКА: ", name)


func wait_idle(max_frames: int) -> void:
	for f in max_frames:
		await process_frame
		var b = current_scene
		if b != null and "_mode" in b and (b._mode == b.Mode.IDLE or b.logic.is_over) and b._anim_queue.is_empty():
			if f > 2:
				return


func cell(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func hand_index(h, id: String) -> int:
	for i in h.hand.size():
		if h.hand[i].id == id:
			return i
	return -1


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var meta = root.get_node("Meta")
	meta.save_path = "user://test_tutorial.cfg"
	meta.reset()
	run.fast_enemies = true
	run.start_tutorial()
	await process_frame
	await wait_idle(900)
	var b = current_scene
	check("сцена боя открылась", b != null and b.get("_tutor") != null)
	var logic = b.logic
	var mage = logic.heroes[0]
	var knight = logic.heroes[1]
	check("рука Рыцаря по сценарию", knight.hand.map(func(c): return c.id) == ["kb_sword", "kb_shield", "kb_lunge", "kb_runup", "kb_sword"])
	check("первым выбран Рыцарь", b._active == knight)
	check("окошко видно", b.hud.tutor.visible)
	check("шаг 1", b._tutor.step == 0)

	# Шаги «Дальше»: клик по полю ничего не делает
	var knight_cell: Vector2i = knight.cell
	b._on_cell_clicked(cell(6, 8))
	await wait_idle(100)
	check("на шаге «Дальше» Рыцарь не пошёл", knight.cell == knight_cell)
	b._on_tutor_next()
	b._on_tutor_next()
	check("дошли до шага с ходом", b._tutor.current()["do"] == "move")

	# Не та клетка, не тот герой, не та карта
	b._on_cell_clicked(cell(5, 9))
	await wait_idle(100)
	check("на чужую клетку не пошёл", knight.cell == knight_cell)
	b._on_hero_pressed(0)
	check("Мага выбрать нельзя", b._active == knight)
	b._on_card_pressed(hand_index(knight, "kb_shield"))
	check("щит раньше времени не выбрать", b._selected_card == -1)
	b._on_end_turn_pressed()
	await wait_idle(100)
	check("конец хода раньше времени не нажать", logic.turn == 1)
	b._on_undo_pressed()
	b._on_discard_toggled()
	check("сброс в ведении не включается", not b._discarding)

	# Правильный ход
	b._on_cell_clicked(cell(6, 8))
	await wait_idle(600)
	check("Рыцарь подошёл", knight.cell == cell(6, 8))
	check("шаг «карта»", b._tutor.current().get("card", "") == "kb_sword")

	b._on_card_pressed(hand_index(knight, "kb_sword"))
	check("меч выбран", b._selected_card >= 0)
	b._on_cell_clicked(cell(5, 7))
	check("по пустой клетке рядом не ударил, меч остался выбран", b._selected_card >= 0 and logic.enemies[0].hp == 11)
	b._on_cell_clicked(cell(6, 7))
	await wait_idle(600)
	check("гоблин ранен", logic.enemies[0].hp < 11)

	b._on_hero_pressed(0)
	check("выбран Маг", b._active == mage)
	b._on_card_pressed(hand_index(mage, "mb_spark"))
	b._on_cell_clicked(cell(6, 7))
	await wait_idle(600)
	check("заряд есть", mage.charge >= 1)
	b._on_card_pressed(hand_index(mage, "mb_discharge"))
	b._on_cell_clicked(cell(6, 7))
	await wait_idle(900)
	check("гоблин погиб", not logic.enemies[0].is_alive())
	check("шаг «прогноз меняется»", b._tutor.current()["do"] == "next")
	b._on_tutor_next()
	b._on_hero_pressed(1)
	check("выбран Рыцарь", b._active == knight)
	b._on_card_pressed(hand_index(knight, "kb_shield"))
	await wait_idle(600)
	check("щит поднят", knight.block > 0)
	check("шаг «Конец хода»", b._tutor.current()["do"] == "end_turn")
	check("кнопка «Конец хода» подсвечена", b.hud.tutor_end)
	b._on_end_turn_pressed()
	await wait_idle(2500)
	check("ход врагов прошёл", logic.turn == 2)
	check("Рыцарь не потерял HP: щит принял камень", knight.hp == knight.max_hp)
	check("ведение закончено", not b._tutor.guided())
	check("рука не приглушена", not b.hud.tutor_lock)
	b._on_panel_next()
	check("после «Понятно» — подсказка про удержание карт (второй ход)", b._hint_shown == "keep" and b.hud.tutor.visible)
	check("подсказка отмечена увиденной", meta.hints_seen.has("keep"))
	b._on_panel_skip()
	check("«Не показывать подсказки» выключило их", meta.hints_seen.has("__off") and not b.hud.tutor.visible)

	# Дальше — без ограничений: бьём, пока бой не кончится (герои бессмертны для проверки)
	mage.hp = 999
	knight.hp = 999
	for turn in 12:
		if logic.is_over:
			break
		for h in logic.living_heroes():
			for tries in 6:
				if logic.is_over:
					break
				var done: bool = false
				for i in h.hand.size():
					if not logic.can_play(h, i):
						continue
					var targets: Array = logic.get_card_targets(h, i)
					for e in logic.enemies:
						if e.is_alive() and targets.has(e.cell):
							b._do(func() -> void: logic.play_card(h, i, e.cell))
							await wait_idle(600)
							done = true
							break
					if done:
						break
				if not done:
					# Подойти к ближайшему врагу
					var best: Vector2i = h.cell
					var best_d: int = 99
					for c in logic.get_move_targets(h):
						for e in logic.enemies:
							if e.is_alive() and HexMath.distance(c, e.cell) < best_d:
								best_d = HexMath.distance(c, e.cell)
								best = c
					if best == h.cell:
						break
					b._do(func() -> void: logic.move_hero(h, best))
					await wait_idle(600)
		if not logic.is_over:
			b._on_end_turn_pressed()
			await wait_idle(2500)
	check("бой окончен победой", logic.is_over and logic.won)
	for i in 400:
		await process_frame
		if current_scene != b:
			break
	await process_frame
	check("после боя — хаб", current_scene != null and current_scene.scene_file_path == "res://scenes/hub.tscn")
	check("отметка «обучение пройдено»", meta.tutorial_done)
	check("забег не активен", not run.tutorial and not run.is_active)
	check("в учебном бою карточка врага отмечена", meta.hints_seen.has("enemy_card"))
	var cfg := ConfigFile.new()
	check("отметка в сохранении", cfg.load("user://test_tutorial.cfg") == OK and cfg.get_value("meta", "tutorial_done", false))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_tutorial.cfg"))
	print("Учебный бой: проверок %d, ошибок %d" % [checks, errors])
	quit(1 if errors > 0 else 0)
