extends SceneTree

# Три акта забега (Run.ACTS, resources/acts/): переход после босса, новая карта, передышка,
# заимствованные враги актов 2–3 крепче, ряды для Отзвуков считаются через все акты.
# Запуск: godot --headless --path . -s tests/acts.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func _boss_node(run: Node) -> MapNode:
	for n: MapNode in run.map:
		if n.type == MapNode.Type.BOSS:
			return n
	return null


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.sim_no_scenes = true

	# --- Данные актов ---
	check("В забеге три акта", run.ACTS.size() == 3 and run.FINAL_ACT == 3)
	for i in run.ACTS.size():
		var a: ActData = run.ACTS[i]
		check("Акт %d: номер, название и две ветки" % (i + 1), a.number == i + 1 and a.title != "" and a.branch_titles.size() == 2)
	check("Акт 1 на своих врагах", not run.ACTS[0].is_placeholder())
	check("Акт 2 на своих врагах, акт 3 пока берёт врагов у акта 2",
			not run.ACTS[1].is_placeholder() and run.ACTS[2].is_placeholder() and run.ACTS[2].borrow_from == 2)

	# --- Акт 1 ---
	run.final_act = run.FINAL_ACT
	run.start_new_run(321)
	check("Забег начинается с акта 1", run.act == 1 and not run.act_cleared)
	check("Ветки акта 1 — топи и леса", run.branch_titles() == run.ACTS[0].branch_titles)
	check("Пул отрядов — акта 1", run.encounters() == run.ACTS[0].encounters)
	var boss1: MapNode = _boss_node(run)
	check("На карте есть босс", boss1 != null)
	run.enter_node(boss1)
	var boss_enemy: EnemyData = run.pending_enemies[0]
	check("Босс акта 1 без усиления", boss_enemy.max_hp == run.run_boss.core[0].max_hp or run.bell >= 5)
	check("Ряды для Отзвуков в акте 1 — по номеру ряда", run.rows_passed == run.MAP_ROWS)
	run.party[0].hp = 5
	var gold_before: int = run.gold
	var hp_left: Array[int] = [5, run.party[1].hp]
	run.finish_battle(true, hp_left)
	check("После босса акта 1 забег не кончился", not run.run_complete and run.act_cleared)
	check("За босса — золото", run.gold > gold_before)
	check("Награда босса — большая, как у элиты", run.is_big_reward())

	# --- Переход в акт 2 ---
	var old_map: Array = run.map.duplicate()
	var deck_size: int = run.party[0].deck.size()
	run.next_act()
	check("Теперь акт 2", run.act == 2 and not run.act_cleared)
	check("Отряд перевёл дух: здоровье полное", run.party[0].hp == run.party[0].data.max_hp)
	check("Колода осталась с отрядом", run.party[0].deck.size() == deck_size)
	check("Новая карта, отряд в её начале", run.map != old_map and run.current == null and not run.available_nodes().is_empty())
	check("Ветки акта 2 — тракт и подземье", run.branch_titles()[0] == "Тракт" and run.branch_titles()[1] == "Подземье")
	check("Отряды и боссы акта 2 — свои", run.encounters() == run.ACTS[1].encounters and run.boss_pool() == run.ACTS[1].boss_pool)
	check("Рисунок карты есть всегда", ResourceLoader.exists(run.map_background()))
	check("Расщелины Жаровика в акте 2 нет", not run.cave_possible())
	var first: MapNode = run.available_nodes()[0]
	run.enter_node(first)
	check("Ряды для Отзвуков считаются через акты", run.rows_passed == run.MAP_ROWS + first.row + 1)
	var goblin: EnemyData = load("res://resources/enemies/goblin.tres") as EnemyData
	var g2: EnemyData = run._act_scaled(goblin)
	check("Враги акта 2 не усиливаются (свои)", g2 == goblin)
	check("Файл гоблина не изменился", (load("res://resources/enemies/goblin.tres") as EnemyData).max_hp == goblin.max_hp)

	# --- Акт 3 и конец забега ---
	var boss2: MapNode = _boss_node(run)
	run.enter_node(boss2)
	run.finish_battle(true, [10, 10] as Array[int])
	check("Босс акта 2 — ещё не конец", not run.run_complete and run.act_cleared)
	run.next_act()
	check("Теперь акт 3 — Ледяной Шпиль", run.act == 3 and run.act_data().title == "Ледяной Шпиль")
	var g3: EnemyData = run._act_scaled(goblin)
	check("В акте 3 (заглушка) враги крепче по данным акта", g3.max_hp == ceili(goblin.max_hp * run.act_data().enemy_hp_mult)
			and g3.damage == goblin.damage + run.act_data().enemy_damage_add)
	check("Акт 3 пока на отрядах акта 2", run.encounters() == run.ACTS[1].encounters)
	var boss3: MapNode = _boss_node(run)
	run.enter_node(boss3)
	run.finish_battle(true, [10, 10] as Array[int])
	check("Босс акта 3 — забег пройден", run.run_complete)

	# --- Повторяемость по сиду ---
	var bosses_a: Array[String] = _boss_ids(run, 777)
	var bosses_b: Array[String] = _boss_ids(run, 777)
	check("Один сид — те же боссы во всех актах", bosses_a == bosses_b and bosses_a.size() == 3)

	# --- Забег в один акт (замер как раньше) ---
	run.final_act = 1
	run.start_new_run(55)
	run.enter_node(_boss_node(run))
	run.finish_battle(true, [10, 10] as Array[int])
	check("final_act = 1: забег кончается на боссе акта 1", run.run_complete)
	run.final_act = run.FINAL_ACT

	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


# Боссы всех трёх актов одного забега (по сиду)
func _boss_ids(run: Node, seed_value: int) -> Array[String]:
	var ids: Array[String] = []
	run.start_new_run(seed_value)
	for i in 3:
		ids.append(run.run_boss.id)
		if i < 2:
			run.enter_node(_boss_node(run))
			run.finish_battle(true, [10, 10] as Array[int])
			run.next_act()
	return ids
