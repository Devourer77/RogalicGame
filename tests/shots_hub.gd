extends Node
# Снимки хаба (1280×720): обычный и «всё открыто».
# Запуск (не headless, нужна видеокарта):
#   godot --path . res://tests/shots_hub.tscn
# Снимки — в user://shots/hub_*.png. Настоящее сохранение не трогает.

func _ready() -> void:
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	get_window().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	Meta.save_path = "user://progress_shots.cfg"
	Meta.reset()

	await _shot("hub_start")
	# Всё открыто: все ступени, все обереги, знамя, звоны
	Meta.echoes = 9999
	for u in Meta.UPGRADES:
		while Meta.can_buy(u.id):
			Meta.buy(u.id)
	for c in Meta.CHARMS:
		Meta.unlock_charm(c.id)
	Meta.first_boss_killed = true
	Meta.bell_max = Meta.MAX_BELL
	Meta.bell_chosen = 3
	Meta.save()
	await _shot("hub_full")
	# У точки: подсказка над Караульней
	var hub: Node = get_tree().current_scene
	hub.active.global_position = Vector3(-8.5, 0, -1.5)
	await _settle(40)
	_save("hub_prompt")
	# Все панели по очереди
	for point in hub.POINTS:
		var only: String = point.get("hero_only", "")
		if only != "" and hub.active.hero_id != only:
			hub.switch_hero()
			await _settle(40)
		hub._open_point_panel(point)
		await _settle(40)
		_save("panel_" + point["id"])
		var panel: HubPanel = hub.hud.panel_root.get_child(0)
		panel.close()
		await _settle(30)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
	get_tree().quit()


func _shot(name: String) -> void:
	Run.goto(Run.HUB_SCENE)
	await _settle(150)
	_save(name)


func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://shots/%s.png" % name)
	print("снимок: ", name)
