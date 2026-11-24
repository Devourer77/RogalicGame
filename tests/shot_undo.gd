extends SceneTree
# Снимки кнопки «Отменить · Z»: после шага (можно отменить) и после добора карты (замок).
# Запуск (нужно окно): godot --path . --resolution 1280x720 -s tests/shot_undo.gd
# Картинки — в SHOTS_DIR (по умолчанию user://shots).
var _dir: String = "user://shots"


func _shot(name: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("shot ", name)


func _initialize() -> void:
	if OS.get_environment("SHOTS_DIR") != "":
		_dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(5)
	run.pending_enemies = run._make_encounter(2, false, false)
	run.pending_arena = "mine"
	change_scene_to_file("res://scenes/battle.tscn")
	await _idle()
	var b = current_scene
	await _shot("undo_0_start")
	# Два шага героем — на кнопке «(2)»
	for i in 2:
		var h: BattleUnit = b._active
		var cells: Array = b.logic.get_move_targets(h).keys()
		if not cells.is_empty():
			var c: Vector2i = cells[cells.size() / 2]
			b._do(func() -> void: b.logic.move_hero(h, c))
			await _idle()
	await _shot("undo_1_two_steps")
	# Отмена одного шага — «(1)»
	b._on_undo_pressed()
	await _idle()
	await _shot("undo_2_after_undo")
	# Замок: как после карты, добравшей карту из колоды
	b._clear_undo("Нельзя отменить: открыта новая карта из колоды.")
	b._enter_idle()
	await _shot("undo_3_locked")
	quit()


func _idle() -> void:
	for f in 900:
		await process_frame
		var b = current_scene
		if b != null and "_mode" in b and b._mode == b.Mode.IDLE and b._anim_queue.is_empty() and f > 30:
			return
