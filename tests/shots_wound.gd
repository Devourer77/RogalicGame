extends SceneTree

# Снимки «Раны»: строка на экране награды, кнопка «Перевязка» на привале, карта в колоде.
# Запуск (нужно окно): godot --path . --resolution 1280x720 -s tests/shots_wound.gd
var _dir: String = "user://shots"


func _shot(name: String, wait: float = 0.5) -> void:
	await create_timer(wait).timeout
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
	run.current = run.map[0]
	var hp_left: Array[int] = [0, 20]
	run.finish_battle(true, hp_left)
	for i in 10: await process_frame
	await _shot("wound_reward")
	change_scene_to_file("res://ui/rest_screen.tscn")
	for i in 5: await process_frame
	await _shot("wound_rest")
	var rh = run.party[0]
	var sections: Array[Dictionary] = [{"title": rh.data.title, "color": rh.data.color, "cards": rh.deck}]
	load("res://ui/deck_overlay.gd").open(current_scene, "Колода: %s" % rh.data.title, sections)
	await _shot("wound_deck")
	quit()
