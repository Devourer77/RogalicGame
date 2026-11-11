extends SceneTree
# Скриншоты новых карт: объекты на поле и рука с цветными наборами
func _shot(name: String, frames: int = 10) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/claude-0/shots/%s.png" % name)
	print("shot ", name)
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(11)
	run.pending_enemies = run._make_encounter(2, false)
	run.pending_arena = "gat"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 60: await process_frame
	var b = current_scene
	await _shot("cards_start", 2)
	while b._mode == 0: await process_frame
	var l: BattleLogic = b.logic
	var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	# Маг ставит ледяную стену, рыцарь — колья
	var hand: Array[CardData] = [load("res://resources/cards/m_ice_wall.tres"), load("res://resources/cards/m_spark.tres"),
		load("res://resources/cards/m_rift.tres"), load("res://resources/cards/m_swap.tres"), load("res://resources/cards/strike.tres")]
	m.hand = hand; m.mana = 10
	b._active = m
	var targets: Array[Vector2i] = l.get_card_targets(m, 0)
	var wall_t: Vector2i = m.cell + Vector2i(0, -2)
	if targets.has(wall_t):
		b._do(func() -> void: l.play_card(m, 0, wall_t))
		while b._mode == 0: await process_frame
	var khand: Array[CardData] = [load("res://resources/cards/k_stakes.tres"), load("res://resources/cards/k_spin.tres"),
		load("res://resources/cards/k_bell.tres"), load("res://resources/cards/k_hold.tres"), load("res://resources/cards/k_leap.tres")]
	k.hand = khand; k.mana = 10
	b._active = k
	var st: Array[Vector2i] = l.get_card_targets(k, 0)
	if not st.is_empty():
		var kk: Vector2i = st[0]
		b._do(func() -> void: l.play_card(k, 0, kk))
		while b._mode == 0: await process_frame
	# Настил на ближайшую трясину (ставим вручную для картинки)
	for c: Vector2i in l.objects.keys():
		if l.objects[c] == BattleLogic.Obj.BOG:
			l._set_object(c, BattleLogic.Obj.BRIDGE, Vector2i.ZERO)
			b._play_queue()
			break
	b._active = m
	await create_timer(3.0).timeout
	b._enter_idle()
	await create_timer(0.5).timeout
	await _shot("cards_field")
	b._active = k
	b._enter_idle()
	await create_timer(0.3).timeout
	await _shot("cards_knight")
	quit()
