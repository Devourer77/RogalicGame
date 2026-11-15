extends SceneTree

# Снимки экрана события: выбор, окно «убрать карту», итог с новыми картами.
# Запуск (нужно окно): godot --path . --resolution 1280x720 -s tests/shots_events.gd
# Картинки — в SHOTS_DIR (по умолчанию user://shots).
var _dir: String = "user://shots"


func _shot(name: String, wait: float = 0.4) -> void:
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
	run.start_new_run(21)
	run.gold = 30
	var events: Array = load("res://ui/event_screen.gd").EVENTS
	# Каждое событие топей по очереди: экран выбора
	for idx in [7, 8, 9, 10, 11]:
		run.cave_seen = true
		run.events_seen.clear()
		for e: Dictionary in events:
			if e != events[idx]:
				run.events_seen.append(e["title"])
		change_scene_to_file("res://ui/event_screen.tscn")
		await process_frame
		await process_frame
		await _shot("event_%d" % idx)
	# Повозка: Маг лезет в воду — новая карта и убрать карту
	var s = current_scene
	s._choose(events[11]["options"][2])   # Пост у колокола: архив — две карты
	await _shot("event_result_two_cards")
	run.events_seen.clear()
	for e: Dictionary in events:
		if e != events[7]:
			run.events_seen.append(e["title"])
	change_scene_to_file("res://ui/event_screen.tscn")
	await process_frame
	await process_frame
	s = current_scene
	s._choose(events[7]["options"][1])
	await _shot("event_remove")
	var overlays: Array = s.get_children().filter(func(c): return c is ColorRect)
	s._remove(s._hero("mage"), 0)
	for c in overlays:
		c.queue_free()
	await _shot("event_result")
	quit()
