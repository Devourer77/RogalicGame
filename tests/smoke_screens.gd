extends SceneTree
# Прогон экранов без окна: бой с каждой особой целью и реликвиями (5 раундов),
# награда после элиты с выбором реликвии, событие «Утопленный идол».
# Ловит ошибки в скриптах сцен, которые тесты логики не задевают.
# Запуск: godot --headless --path . -s tests/smoke_screens.gd
# Смотреть, нет ли в выводе строк SCRIPT ERROR.
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	for obj in [1, 2, 3]:
		run.start_new_run(11)
		run.take_relic(load("res://resources/relics/ogre_tooth.tres"))
		run.take_relic(load("res://resources/relics/drowned_heart.tres"))
		run.pending_enemies = [load("res://resources/enemies/goblin_shaman.tres"), load("res://resources/enemies/bloated_toad.tres")] as Array[EnemyData]
		run.pending_arena = "grove"
		run.pending_objective = obj
		change_scene_to_file("res://scenes/battle.tscn")
		for i in 240: await process_frame
		var b = current_scene
		print("battle obj=", obj, " objective=", b.logic.objective, " relics=", b.logic.charms.size(), " text=", b.logic.objective_text())
		# конец хода — проверка призыва/воды/фитиля в сцене
		b.logic.heroes[0].hp = 999; b.logic.heroes[1].hp = 999
		for t in 5:
			b._on_end_turn_pressed()
			for i in 200: await process_frame
		print("  after 5 rounds: turn=", b.logic.turn, " enemies=", b.logic.enemies.size(), " views=", b._views.size())
	# награда после элиты
	run.start_new_run(11)
	run.current = run.map[0]
	run.current.type = MapNode.Type.ELITE
	change_scene_to_file("res://ui/reward_screen.tscn")
	for i in 30: await process_frame
	print("reward ok, relic_done=", current_scene._relic_done)
	change_scene_to_file("res://ui/event_screen.tscn")
	for i in 30: await process_frame
	current_scene._choose(load("res://ui/event_screen.gd").EVENTS[2]["options"][0])   # Утопленный идол: снять амулет
	for i in 10: await process_frame
	print("event idol ok, relics=", run.relics.size())
	# Босс акта 1: награда босса → трофей → экран акта 2 → карта акта 2
	run.start_new_run(12)
	for n: MapNode in run.map:
		if n.type == MapNode.Type.BOSS:
			run.current = n
	run.finish_battle(true, [20, 20] as Array[int])
	for i in 30: await process_frame
	print("boss reward ok, act_cleared=", run.act_cleared, " elite_step=", current_scene._elite)
	run.next_act()
	for i in 30: await process_frame
	print("act screen ok: ", current_scene.name, " act=", run.act)
	change_scene_to_file("res://ui/map_screen.tscn")
	for i in 30: await process_frame
	print("act 2 map ok, nodes=", run.map.size())
	quit()
