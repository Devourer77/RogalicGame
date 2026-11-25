extends SceneTree
# Снимок «подойти и ударить»: выбрана карта ближнего боя, курсор на враге за пределами удара.
# xvfb-run godot --path . --resolution 1280x720 --rendering-driver opengl3 -s tests/shot_approach.gd
func _initialize() -> void:
	var dir: String = OS.get_environment("SHOTS_DIR") if OS.get_environment("SHOTS_DIR") != "" else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(42)
	run.pending_enemies = [load("res://resources/enemies/goblin.tres"), load("res://resources/enemies/goblin.tres"), load("res://resources/enemies/goblin_slinger.tres")] as Array[EnemyData]
	run.pending_arena = "grove"
	change_scene_to_file("res://scenes/battle.tscn")
	await create_timer(6.0).timeout
	var b = current_scene
	var done := false
	for k in [b.logic.heroes[1], b.logic.heroes[0]]:
		for i in k.hand.size():
			if not done and not b.logic.approach_targets(k, i).is_empty():
				b._pick_hero(k)
				b._on_card_pressed(i)
				print("card ", k.hand[i].title)
				done = true
	if not b._approach.is_empty():
		b._on_hover(b._approach.keys()[0])
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir + "/approach.png")
	print("shot approach ", b._approach.size())
	quit()
