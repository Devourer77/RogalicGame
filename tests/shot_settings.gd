extends SceneTree
# Снимки меню паузы и окна настроек (в бою и в главном меню). Нужно окно:
# godot --path . --resolution 1280x720 -s tests/shot_settings.gd   (картинки — в SHOTS_DIR)
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
	change_scene_to_file("res://scenes/battle.tscn")
	await create_timer(4.0).timeout
	print("frames ok")
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	print("esc sent")
	await process_frame
	print("after frame")
	await _shot("pause_battle")
	print("paused: ", paused)
	load("res://ui/settings_screen.gd").open(load("res://ui/pause_menu.gd")._current)
	await _shot("settings_battle")
	quit()
