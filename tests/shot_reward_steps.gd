extends SceneTree
# Снимки новой награды (окно Мага, окно Рыцаря) и привала с «Закалкой».
# Запуск (нужно окно): godot --path . -s tests/shot_reward_steps.gd → user://shots/reward_*.png

func _shot(name: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	root.get_texture().get_image().save_png("user://shots/%s.png" % name)
	print("снимок: ", ProjectSettings.globalize_path("user://shots/%s.png" % name))


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.get_node("/root/Meta").tutorial_done = true
	run.start_new_run(21)
	run.current = run.available_nodes()[0]
	run.current.visited = true
	run.last_gold_reward = 18
	change_scene_to_file(run.REWARD_SCENE)
	await _shot("reward_1_mage")
	var scr: Node = current_scene
	(scr.get("_all_buttons")[1] as Button).pressed.emit()
	await _shot("reward_1_mage_picked")
	scr._next_hero()
	await _shot("reward_2_knight")
	run.party[0].hp = 14
	change_scene_to_file(run.REST_SCENE)
	await _shot("rest_forge")
	current_scene._start_forge()
	await _shot("rest_forge_pick")
	quit()
