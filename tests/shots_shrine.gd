extends Node
# Снимки Святилища духов (1280×720): пустое, дух встречен, дух покорён, уникальный.
# Запуск (не headless, нужна видеокарта):
#   godot --path . res://tests/shots_shrine.tscn
# Снимки — в user://shots/shrine_*.png. Настоящее сохранение не трогает.

func _ready() -> void:
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	Meta.save_path = "user://progress_shots.cfg"
	Meta.reset()
	Run.goto(Run.HUB_SCENE)
	await _settle(120)
	var hub: Node = get_tree().current_scene
	var panel: ShrinePanel = ShrinePanel.open(hub.hud.panel_root, "mage") as ShrinePanel
	await _settle(20)
	_save("shrine_empty")
	Meta.mark_spirit_seen("wind")
	Meta.mark_spirit_seen("bog")
	panel._select("wind")
	await _settle(20)
	_save("shrine_seen")
	panel._select("bog")
	await _settle(20)
	_save("shrine_unique_seen")
	Meta.echoes = 999
	Meta.buy("spirit_bait")
	Meta.buy("spirit_bond")
	Meta.record_spirit_tamed("storm")
	Meta.choose_bait("storm")
	panel._select("storm")
	await _settle(20)
	_save("shrine_tamed")
	panel.close()
	await _settle(10)
	hub.active.global_position = Vector3(7.5, 0, -2.8)
	await _settle(60)
	_save("shrine_world")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
	get_tree().quit()


func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://shots/%s.png" % name)
	print("снимок: ", name)
