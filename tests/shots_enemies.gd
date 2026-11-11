extends SceneTree
# Бой с новыми врагами «вживую»: сцена боя, несколько ходов врагов с анимациями, снимки экрана.
# Ловит ошибки в сцене (а не только в логике). Запуск с окном:
#   godot --path . --resolution 1280x720 -s tests/shots_enemies.gd
# Переменные: ENEMIES=id,id,... (по умолчанию все новые), ARENA=ключ арены, TURNS=сколько ходов.
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var ids: PackedStringArray = ["goblin_slinger", "bloated_toad", "drowned_walker", "goblin_shaman", "mossy_treant", "ogre"]
	if OS.get_environment("ENEMIES") != "":
		ids = OS.get_environment("ENEMIES").split(",")
	var arena: String = OS.get_environment("ARENA") if OS.get_environment("ARENA") != "" else "reeds"
	var turns: int = int(OS.get_environment("TURNS")) if OS.get_environment("TURNS") != "" else 4
	run.start_new_run(21)
	var list: Array[EnemyData] = []
	for id in ids: list.append(load("res://resources/enemies/%s.tres" % id))
	run.pending_enemies = list
	run.pending_arena = arena
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/claude-0/shots")
	# Наводим «курсор» на первого врага — проверяем подсказку и зону угрозы
	b._on_hover(b.logic.enemies[0].cell)
	await _shot("enemies_0")
	for t in turns:
		if b.logic.is_over: break
		b._on_end_turn_pressed()
		await process_frame
		while b._mode == 0 and not b.logic.is_over: await process_frame
		if b.logic.is_over: break
		b._on_hover(b.logic.living_enemies()[t % b.logic.living_enemies().size()].cell)
		await _shot("enemies_%d" % (t + 1))
	print("done, ход %d, бой окончен: %s" % [b.logic.turn, b.logic.is_over])
	quit()


func _shot(name: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/claude-0/shots/%s.png" % name)
	print("shot ", name)
