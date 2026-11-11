extends SceneTree
# Скриншоты всех арен. Запуск с окном:
#   godot --path . --resolution 1280x720 -s tests/shots_arenas.gd
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var only: String = OS.get_environment("ARENA")
	for arena: String in BattleLogic.ARENAS:
		if only != "" and only != arena: continue
		run.start_new_run(21)
		run.pending_enemies = run._make_encounter(4, arena == "lair")
		run.pending_arena = arena
		change_scene_to_file(run.BATTLE_SCENE)
		for i in 40: await process_frame
		var b = current_scene
		while b._mode == 0: await process_frame
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/claude-0/shots/arena_%s.png" % arena)
		print("shot ", arena)
	quit()
