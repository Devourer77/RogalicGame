extends SceneTree
# Снимок Караульни с рядом пресетов (третий закрыт, потом открыт).
# Запуск (нужно окно): godot --path . -s tests/shot_presets.gd → user://shots/presets_*.png

func _shot(name: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	root.get_texture().get_image().save_png("user://shots/%s.png" % name)
	print("снимок: ", ProjectSettings.globalize_path("user://shots/%s.png" % name))


func _initialize() -> void:
	await process_frame
	var meta = root.get_node("Meta")
	meta.save_path = "user://test_shot_presets.cfg"
	meta.reset()
	meta.tutorial_done = true
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var panel: Node = load("res://ui/hub/barracks_panel.gd").open(host, "mage")
	await _shot("presets_locked")
	meta.note_act2_boss()
	meta.choose_preset(root.get_node("Run").HEROES[1], "rage")
	panel._select_hero("knight")
	await _shot("presets_knight_rage")
	meta.reset()
	quit()
