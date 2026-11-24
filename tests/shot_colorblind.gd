extends SceneTree
# Снимок боя в режиме для дальтоников (угроза пурпурная и в полоску). Нужно окно:
# godot --path . --resolution 1280x720 -s tests/shot_colorblind.gd   (картинки — в SHOTS_DIR)
var _dir: String = "user://shots"


func _initialize() -> void:
	if OS.get_environment("SHOTS_DIR") != "":
		_dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	var settings: Node = root.get_node("Settings")
	settings.settings_path = "user://settings_shot.cfg"
	settings.colorblind = true
	change_scene_to_file("res://scenes/battle.tscn")
	await create_timer(5.0).timeout
	var b = current_scene
	b._on_hover(b.logic.enemies[0].cell)   # наведение на врага — его зона удара
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/colorblind.png" % _dir)
	print("shot colorblind")
	quit()
