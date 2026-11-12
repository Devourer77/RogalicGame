extends SceneTree

# Клетка по колонке и ряду (как раньше x, y): поле из сот хранит клетки осевой парой, см. HexMath
func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)

# Снимки всех экранов интерфейса — чтобы глазами проверить, что ничего не разъехалось.
# Запуск (нужно окно):  godot --path . --resolution 1280x720 -s tests/shots_ui.gd
# Картинки складываются в папку из переменной SHOTS_DIR (по умолчанию user://shots).
var _dir: String = "user://shots"


func _shot(name: String, wait: float = 0.3) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("shot ", name)


func _goto(run: Node, scene: String) -> void:
	change_scene_to_file(scene)
	for i in 8:
		await process_frame


func _initialize() -> void:
	if OS.get_environment("SHOTS_DIR") != "":
		_dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	var run = root.get_node("Run")

	# --- Главное меню ---
	await _goto(run, run.MAIN_MENU_SCENE)
	await _shot("01_menu")

	# --- Бой ---
	run.start_new_run(11)
	run.pending_enemies = run._make_encounter(2, false)
	run.pending_arena = "gat"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 60:
		await process_frame
	var b = current_scene
	while b._mode == 0:
		await process_frame
	await _shot("02_battle", 3.6)   # ждём, пока растает название арены
	var hud = b.hud   # без типа: в режиме -s автозагрузка Run подключается позже, чем читается этот скрипт
	# Наведение на карту: она выезжает целиком
	var slot: Control = hud._hand_box.get_child(1)
	(slot.get_child(0) as Button).mouse_entered.emit()
	await _shot("03_battle_card_hover")
	(slot.get_child(0) as Button).mouse_exited.emit()
	# Выбрана карта: прицеливание
	b._on_card_pressed(0)
	await _shot("04_battle_aiming")
	b._cancel_card()
	# Наведение на врага: карточка справа
	b._on_hover(b.logic.enemies[0].cell)
	await _shot("05_battle_enemy")
	b._on_hover(BattleLogic.NO_CELL)
	# Справка
	hud.toggle_help()
	await _shot("06_battle_help")
	hud.toggle_help()
	# Ход врагов и состояние «делать нечего»
	b._on_end_turn_pressed()
	await process_frame
	while b._mode == 0 and not b.logic.is_over:
		await process_frame
	for h: BattleUnit in b.logic.heroes:
		h.mana = 0
		h.moves_left = 0
		h.block = 5
	b.logic.heroes[1].rage = 3
	b.logic.heroes[1].taunt = true
	b.logic.heroes[0].charge = 4
	b._enter_idle()
	await _shot("07_battle_nothing_left")

	# --- Бой с элитой и боссом: карточки врагов ---
	for spec: Array in [["mossy_treant", "reeds", "08_battle_elite"], ["ogre", "lair", "09_battle_boss"]]:
		var list: Array[EnemyData] = [load("res://resources/enemies/%s.tres" % spec[0]),
				load("res://resources/enemies/goblin_shaman.tres"), load("res://resources/enemies/bloated_toad.tres")]
		run.pending_enemies = list
		run.pending_arena = spec[1]
		change_scene_to_file(run.BATTLE_SCENE)
		for i in 60:
			await process_frame
		b = current_scene
		while b._mode == 0:
			await process_frame
		b._on_hover(b.logic.enemies[0].cell)
		await _shot(spec[2], 3.6)

	# --- Экраны между боями ---
	run.gold = 130
	run.party[0].hp = 17
	await _goto(run, run.MAP_SCENE)
	await _shot("10_map")
	run.current = run.available_nodes()[0]   # «прошли» первую точку, не запуская сам бой
	run.current.visited = true
	run.last_gold_reward = 18
	await _goto(run, run.REWARD_SCENE)
	await _shot("11_reward")
	await _goto(run, run.MAP_SCENE)
	await _shot("12_map_progress")
	run.shop_stock.clear()
	for rh in run.party:
		for card in run.roll_cards(rh, 2):
			run.shop_stock.append({"hero": rh, "card": card})
	run.shop_removal_used = false
	await _goto(run, run.SHOP_SCENE)
	await _shot("13_shop")
	if current_scene.has_method("_start_removal"):
		current_scene._start_removal()
		await _shot("14_shop_removal")
	await _goto(run, run.REST_SCENE)
	await _shot("15_rest")
	await _goto(run, run.EVENT_SCENE)
	await _shot("16_event")
	current_scene._choose("drink")
	await _shot("16b_event_result")
	run.last_run_won = true
	await _goto(run, run.GAME_OVER_SCENE)
	await _shot("17_win")
	run.last_run_won = false
	await _goto(run, run.GAME_OVER_SCENE)
	await _shot("18_lose")
	quit()
