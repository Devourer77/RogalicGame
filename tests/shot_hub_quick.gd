extends Node
# Быстрый снимок хаба (только старт и «всё открыто»): godot --path . res://tests/shot_hub_quick.tscn
# YAW=90 — повернуть камеру. Снимки — user://shots/quick_*.png.

func _ready() -> void:
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	Meta.save_path = "user://progress_quick.cfg"
	Meta.reset()
	Meta.echoes = 9999
	for c in Meta.CHARMS.slice(0, 4):
		Meta.unlock_charm(c.id)
	Meta.save()
	Run.goto(Run.HUB_SCENE)
	await _settle(150)
	_save("quick_start")
	var hub: Node = get_tree().current_scene
	hub.active.global_position = Vector3(8.5, 0, 6.8)
	await _settle(80)
	_save("quick_shelf")
	hub.camera.focus_on(Vector3(8.5, 0.9, 5.0))
	await _settle(90)
	_save("quick_shelf_close")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
	get_tree().quit()


func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://shots/%s.png" % name)
	print("снимок: ", name)
