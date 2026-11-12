extends SceneTree
# Снимки новых механик: замок удержания, руна на поле, значки «Мокрый» и «Яд», новые карты.
# Запуск (нужно окно):  godot --path . --resolution 1280x720 -s tests/shots_mechanics.gd
var _dir: String = "user://shots"


func _shot(name: String, wait: float = 0.4) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("shot ", name)


func _card(id: String) -> CardData:
	return load("res://resources/cards/%s.tres" % id)


func _initialize() -> void:
	if OS.get_environment("SHOTS_DIR") != "":
		_dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(11)
	run.pending_enemies = run._make_encounter(2, false)
	run.pending_arena = "gat"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 60:
		await process_frame
	var b = current_scene
	while b._mode == 0:
		await process_frame
	var logic: BattleLogic = b.logic
	var knight: BattleUnit = logic.heroes[1]
	var hand: Array[CardData] = [_card("k_rune_trap"), _card("k_rune_fire"), _card("k_rune_storm"),
			_card("k_rune_rot"), _card("k_diag"), _card("k_slash")]
	knight.hand = hand
	knight.mana = 5
	b._select_hero(knight)
	b._enter_idle()
	# Ставим сторожевую руну, вешаем руну гнили, удерживаем две карты
	var spot: Vector2i = logic.get_card_targets(knight, 0)[0]
	b._on_card_pressed(0)
	b._on_cell_clicked(spot)
	while b._mode == 0:
		await process_frame
	b._on_card_pressed(2)
	while b._mode == 0:
		await process_frame
	b._on_card_keep_toggled(0)
	b._on_card_keep_toggled(2)
	# Враги: один мокрый, один отравлен
	var foes: Array[BattleUnit] = logic.living_enemies()
	logic._set_wet(foes[0], 2)
	logic._set_poison(foes[1], 3)
	await b._play_queue()
	b._enter_idle()
	await _shot("m1_runes_keep")
	b.hud.show_enemy(foes[1], logic)
	await _shot("m2_enemy_card")
	var mage: BattleUnit = logic.heroes[0]
	var mhand: Array[CardData] = [_card("m_cross_bolt"), _card("m_spark"), _card("wave")]
	mage.hand = mhand
	b._select_hero(mage)
	b._enter_idle()
	b._on_card_pressed(0)
	b._on_hover(foes[0].cell)
	await _shot("m3_cross_bolt")
	quit()
