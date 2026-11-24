extends SceneTree
# Снимки учебного боя по шагам. Запуск (нужно окно):
# godot --path . --resolution 1280x720 -s tests/shot_tutorial.gd   (картинки — в SHOTS_DIR)
var _dir: String = "user://shots"


func _shot(name: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("shot ", name)


func _initialize() -> void:
	if OS.get_environment("SHOTS_DIR") != "":
		_dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	root.get_node("Meta").save_path = "user://shot_tutorial.cfg"
	var run = root.get_node("Run")
	run.start_tutorial()
	await process_frame
	await _idle()
	var b = current_scene
	await _shot("tut_0_intro")
	b._on_tutor_next()
	await _shot("tut_1_forecast")
	b._on_tutor_next()
	await _shot("tut_2_move")
	b._on_cell_clicked(HexMath.from_column(6, 8))
	await _idle()
	await _shot("tut_3_card")
	var k = b.logic.heroes[1]
	for i in k.hand.size():
		if k.hand[i].id == "kb_sword":
			b._on_card_pressed(i)
			break
	b._on_hover(HexMath.from_column(6, 7))
	await _shot("tut_4_aim")
	b._on_cell_clicked(HexMath.from_column(6, 7))
	await _idle()
	await _shot("tut_5_mage")
	quit()


func _idle() -> void:
	for f in 900:
		await process_frame
		var b = current_scene
		if b != null and "_mode" in b and b._mode == b.Mode.IDLE and b._anim_queue.is_empty() and f > 30:
			return
