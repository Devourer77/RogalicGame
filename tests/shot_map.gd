extends SceneTree
# Снимок экрана карты пути: туман, тропы, карточка у доступной точки.
# godot --path . --resolution 1920x1080 -s tests/shot_map.gd   (STEPS=2 — пройти 2 шага, SEED=…, ACT=2 — карта акта 2 и снимок экрана перехода)
const OUT: String = "/tmp/claude-0/shots/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var run = root.get_node("Run")
	run.sim_no_scenes = true
	var sd: int = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7
	run.start_new_run(sd)
	var to_act: int = int(OS.get_environment("ACT")) if OS.get_environment("ACT") != "" else 1
	while run.act < to_act:
		run.next_act()
	if to_act > 1:   # экран перехода в акт
		run.sim_no_scenes = false
		change_scene_to_file(run.ACT_SCENE)
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "act%d.png" % to_act)
		run.sim_no_scenes = true
	var steps: int = int(OS.get_environment("STEPS")) if OS.get_environment("STEPS") != "" else 0
	for i in steps:
		var opts: Array = run.available_nodes()
		var n = opts[0]
		run.current = n
		n.visited = true
	run.sim_no_scenes = false
	change_scene_to_file(run.MAP_SCENE)
	for i in 30: await process_frame
	var screen = current_scene
	var opts2: Array = run.available_nodes()
	if not opts2.is_empty() and OS.get_environment("NOCARD") == "":
		screen._show_card(opts2[opts2.size() / 2])
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "map_a%d_s%d.png" % [to_act, steps])
	print("map shot")
	quit()
