extends SceneTree
# Скриншоты всех арен. Запуск с окном:
#   godot --path . --resolution 1280x720 -s tests/shots_arenas.gd
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var only: String = OS.get_environment("ARENA")
	for arena: String in BattleLogic.ARENAS:
		if only != "" and not only.split(",").has(arena): continue   # ARENA=wagons,mine — несколько через запятую
		run.start_new_run(21)
		if BattleLogic.ARENA_BIOME.has(arena) and arena != "cave":
			run.sim_no_scenes = true
			run.next_act()   # арены акта 2 — с врагами акта 2
			run.sim_no_scenes = false
		run.pending_enemies = run._make_encounter(4, arena == "lair")
		var squad: String = OS.get_environment("ENEMIES")   # ENEMIES=sleeping_sphere,glass_spitter — свой состав
		if squad != "":
			run.pending_enemies.clear()
			for id in squad.split(","):
				run.pending_enemies.append(load("res://resources/enemies/%s.tres" % id) as EnemyData)
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
