extends SceneTree
# Снимки эффектов интерфейса (этап 7 ТЗ claude/тз-эффекты.md): карта рассыпается искрами
# при розыгрыше, блеск выбранной награды, карта по центру в лавке («Куплено»/«Улучшено»).
# Нужно окно:  godot --path . --resolution 1920x1080 -s tests/shots_ui_fx.gd
# Снимки — /tmp/claude-0/shots/uifx_*.png
const DIR: String = "/tmp/claude-0/shots"


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(DIR)
	var run = root.get_node("Run")
	run.start_new_run(5)

	# 1. Бой: настоящий розыгрыш карты «на себя» через сцену (как кликом по карте)
	var list: Array[EnemyData] = [load("res://resources/enemies/goblin.tres")]
	run.pending_enemies = list
	run.pending_arena = "gat"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	var knight = b.logic.heroes[1]
	b._select_hero(knight)
	b._enter_idle()
	await process_frame
	knight.hand.insert(0, load("res://resources/cards/base/kb_shield.tres"))
	knight.mana = 9
	b.hud.refresh(b.logic, knight, -1, false)
	await create_timer(0.3).timeout
	await _shot("uifx_hand_before", 0.0)
	b._on_card_pressed(0)
	await _shot("uifx_burst_a", 0.06)
	await _shot("uifx_burst_b", 0.2)
	while b._mode == 0: await process_frame

	# 2. Награда: блеск взятой карты
	run.current = run.available_nodes()[0]
	run.current.visited = true
	run.last_gold_reward = 18
	change_scene_to_file(run.REWARD_SCENE)
	for i in 10: await process_frame
	var reward = current_scene
	var buttons: Array = reward._all_buttons
	print("кнопок награды: ", buttons.size())
	if not buttons.is_empty():
		var first: Button = buttons[0]
		first.pressed.emit()
		await _shot("uifx_reward_a", 0.15)
		await _shot("uifx_reward_b", 0.3)

	# 3. Лавка: карта по центру «Улучшено»
	run.shop_stock.clear()
	change_scene_to_file(run.SHOP_SCENE)
	for i in 10: await process_frame
	var rh = run.party[0]
	UiFx_toast(current_scene, rh.deck[0], rh.data.color)
	await _shot("uifx_toast", 0.35)
	print("ui fx done")
	quit()


func UiFx_toast(parent, card, color) -> void:
	load("res://ui/ui_fx.gd").card_toast(parent, card, color, "Улучшено")


func _shot(name: String, wait: float) -> void:
	if wait > 0.0:
		await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [DIR, name])
	print("shot ", name)
