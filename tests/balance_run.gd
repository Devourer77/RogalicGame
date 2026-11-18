extends "res://tests/balance.gd"

var squad_losses: Dictionary = {}   # id отряда → [потеря HP, боёв, врагов]
# Замер ЦЕЛОГО забега ботом (тз-сложность-боя.md, задача 1): HP переносится между боями,
# павший встаёт с 1 HP и получает Рану, награды и привалы — по правилам Run. Бой играет тот же
# бот, что в tests/balance.gd (этот файл наследует его функции).
#
# Запуск (из папки проекта):
#   godot --headless --path . -s tests/balance_run.gd -- 100           — 100 забегов
#   godot --headless --path . -s tests/balance_run.gd -- 100 nowound   — то же без Ран (сравнить)
#   godot --headless --path . -s tests/balance_run.gd -- 100 bell3     — на Звоне 3
# Результат — в консоль и в user://balance_run.txt.
#
# Как бот ведёт забег (просто и одинаково до и после правок):
# - путь: случайная доступная точка;
# - награда за бой: случайная карта из трёх случайному герою;
# - логово: дух первому герою со свободным местом;
# - лавка и события: проходит мимо (ничего не берёт);
# - привал: если у героя 2+ Раны и HP у обоих не ниже половины — «Перевязка», иначе отдых.

const RUN_SEED_BASE: int = 70000


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var runs: int = 100
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		runs = maxi(1, args[0].to_int())
	var bell: int = 0
	for a in args:
		if a.begins_with("bell"):
			bell = a.trim_prefix("bell").to_int()
	run.sim_no_scenes = true
	run.wounds_per_fall = 0 if args.has("nowound") else run.WOUNDS_PER_FALL

	var started: int = Time.get_ticks_msec()
	var won: int = 0
	var reached_elite: int = 0      # дошли до обязательной элиты
	var reached_boss: int = 0
	var died_rows: Dictionary = {}  # ряд → сколько забегов кончилось там
	var died_kind: Dictionary = {}  # тип точки → сколько поражений
	var hp_before_elite: float = 0.0
	var hp_before_boss: float = 0.0
	var falls: int = 0
	var bandages: int = 0
	var wounds_end: int = 0
	var losses: Dictionary = {"бой": [0, 0], "бой в лесу": [0, 0], "логово": [0, 0], "элита": [0, 0], "босс": [0, 0]}   # [сумма потерь, боёв]
	var stuck: int = 0
	for i in runs:
		var res: Dictionary = _play_run(run, RUN_SEED_BASE + i, bell)
		stuck += res["stuck"]
		falls += res["falls"]
		bandages += res["bandages"]
		wounds_end += res["wounds_end"]
		for k: String in res["losses"]:
			losses[k][0] += res["losses"][k][0]
			losses[k][1] += res["losses"][k][1]
		if res.has("hp_elite"):
			reached_elite += 1
			hp_before_elite += res["hp_elite"]
		if res.has("hp_boss"):
			reached_boss += 1
			hp_before_boss += res["hp_boss"]
		if res["won"]:
			won += 1
		else:
			died_rows[res["row"]] = died_rows.get(res["row"], 0) + 1
			died_kind[res["kind"]] = died_kind.get(res["kind"], 0) + 1

	var n: float = float(runs)
	var lines: PackedStringArray = []
	lines.append("Замер забега: %d забегов, Звон %d, Раны: %s" % [runs, bell, "нет" if run.wounds_per_fall == 0 else "%d за падение" % run.wounds_per_fall])
	lines.append("Выиграно забегов: %.0f%%   (цель 40–60%%)" % (100.0 * won / n))
	lines.append("Дошли до обязательной элиты (ряд 5): %.0f%%, до босса: %.0f%%" % [100.0 * reached_elite / n, 100.0 * reached_boss / n])
	lines.append("HP отряда перед элитой: %.1f из 75, перед боссом: %.1f из 75" % [
			hp_before_elite / maxf(1.0, reached_elite), hp_before_boss / maxf(1.0, reached_boss)])
	var rows_text: PackedStringArray = []
	for r in range(8):
		if died_rows.has(r):
			rows_text.append("ряд %d: %d" % [r, died_rows[r]])
	lines.append("Где кончились проигранные: %s" % (", ".join(rows_text) if not rows_text.is_empty() else "—"))
	var kind_text: PackedStringArray = []
	for k: String in died_kind:
		kind_text.append("%s: %d" % [k, died_kind[k]])
	lines.append("На чём проиграли: %s" % (", ".join(kind_text) if not kind_text.is_empty() else "—"))
	var loss_text: PackedStringArray = []
	for k: String in losses:
		if losses[k][1] > 0:
			loss_text.append("%s %.1f" % [k, float(losses[k][0]) / losses[k][1]])
	lines.append("Потеря HP за бой на двоих: %s   (цель: бой 12–20, элита 25–35)" % ", ".join(loss_text))
	lines.append("Падений героев за забег: %.2f, перевязок: %.2f, Ран в колодах к концу: %.2f" % [falls / n, bandages / n, wounds_end / n])
	lines.append("Зависших боёв: %d. Время: %.1f с" % [stuck, (Time.get_ticks_msec() - started) / 1000.0])
	if OS.get_environment("SQUADS") != "":
		var keys: Array = squad_losses.keys()
		keys.sort()
		for k: String in keys:
			var v: Array = squad_losses[k]
			lines.append("  %s: потеря %.1f, врагов %.1f, боёв %d" % [k, float(v[0]) / v[1], float(v[2]) / v[1], v[1]])
	var text: String = "\n".join(lines)
	print("\n===== ЗАБЕГ =====\n" + text + "\n=================")
	var f := FileAccess.open("user://balance_run.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text + "\n")
		f.close()
	quit(0)


# Один забег от первой точки до босса или поражения
func _play_run(run: Node, seed_value: int, bell: int) -> Dictionary:
	run.start_new_run(seed_value, bell)
	bot_rng.seed = seed_value
	var res: Dictionary = {"won": false, "row": 0, "kind": "", "falls": 0, "bandages": 0, "wounds_end": 0,
			"stuck": 0, "losses": {}}
	while true:
		var options: Array[MapNode] = run.available_nodes()
		if options.is_empty():
			break
		var node: MapNode = options[bot_rng.randi_range(0, options.size() - 1)]
		var party_hp: int = 0
		for rh in run.party:
			party_hp += rh.hp
		if node.type == MapNode.Type.ELITE and node.row == run.MAP_ROWS - 3:
			res["hp_elite"] = party_hp
		if node.type == MapNode.Type.BOSS:
			res["hp_boss"] = party_hp
		run.enter_node(node)
		match node.type:
			MapNode.Type.BATTLE, MapNode.Type.ELITE, MapNode.Type.LAIR, MapNode.Type.BOSS:
				var kind: String = {MapNode.Type.BATTLE: "бой", MapNode.Type.ELITE: "элита",
						MapNode.Type.LAIR: "логово", MapNode.Type.BOSS: "босс"}[node.type]
				var battle: Dictionary = _run_battle(run)
				res["stuck"] += 1 if battle["stuck"] else 0
				res["falls"] += battle["falls"]
				var l: Array = res["losses"].get(kind, [0, 0])
				res["losses"][kind] = [l[0] + battle["lost"], l[1] + 1]
				if node.type == MapNode.Type.BATTLE and run.pending_encounter != null:
					var key: String = "отряд " + run.pending_encounter.id   # потери по отрядам (печать — SQUADS=1)
					var ls: Array = squad_losses.get(key, [0, 0, 0])
					squad_losses[key] = [ls[0] + battle["lost"], ls[1] + 1, ls[2] + run.pending_enemies.size()]
				if node.type == MapNode.Type.BATTLE and node.branch == MapNode.FOREST:
					var lf: Array = res["losses"].get("бой в лесу", [0, 0])   # отдельно — лес (Хранители)
					res["losses"]["бой в лесу"] = [lf[0] + battle["lost"], lf[1] + 1]
				if not battle["won"]:
					res["row"] = node.row
					res["kind"] = kind
					break
				run.finish_battle(true, battle["hp_left"])
				if node.type == MapNode.Type.BOSS:
					res["won"] = true
					break
				_take_reward(run)
			MapNode.Type.REST:
				_rest(run, res)
			_:
				pass   # лавка и события: бот проходит мимо
	for rh in run.party:
		res["wounds_end"] += run.wound_count(rh)
	return res


# Бой по текущим pending_* забега тем же ботом, что в balance.gd
func _run_battle(run: Node) -> Dictionary:
	var b := BattleLogic.new()
	b.setup(12, 12, run.rng, run.party, run.pending_enemies, run.pending_arena, run.pending_objective, run.relics, (BattleLogic.Formation.FREE if OS.get_environment("NOFORM") != "" else run.pending_formation()))   # NOFORM=1 — без строя
	if run.pending_encounter != null and OS.get_environment("NOWAVES") == "":   # NOWAVES=1 — замер без волн
		b.set_waves(run.pending_encounter.waves, run.wave_extra())
	b.start()
	var hp_start: int = 0
	for h in b.heroes:
		hp_start += h.hp
	var fallen: Dictionary = {}
	var stuck: bool = false
	while not b.is_over:
		if b.turn >= MAX_TURNS:
			stuck = true
			var left: Array[String] = []
			for e in b.living_enemies():
				left.append("%s@%s" % [e.data.id, e.cell])
			print("Завис бой: арена %s, остались %s" % [b.arena_id, ", ".join(left)])
			break
		for h in b.living_heroes():
			_leave_blast_zone(b, h)
		for h in b.living_heroes():
			_play_hero(b, h)
			if b.is_over:
				break
		if b.is_over:
			break
		for h in b.living_heroes():
			_keep_best(b, h)
		b.end_turn()
		for h in b.heroes:
			if not h.is_alive():
				fallen[h] = true
	var hp_left: Array[int] = []
	var hp_end: int = 0
	for h in b.heroes:
		hp_left.append(maxi(0, h.hp))
		hp_end += maxi(0, h.hp)
		if not h.is_alive():
			fallen[h] = true
	return {"won": b.won and not stuck, "stuck": stuck, "hp_left": hp_left, "falls": fallen.size(),
			"lost": hp_start - hp_end}


# Награда: дух из логова — первому герою с местом; иначе случайная карта случайному герою
func _take_reward(run: Node) -> void:
	if run.tamed_spirit != null:
		for rh in run.party:
			if run.can_take_spirit(rh):
				run.add_spirit(rh, run.tamed_spirit)
				break
		run.tamed_spirit = null
		return
	var rh = run.party[bot_rng.randi_range(0, run.party.size() - 1)]
	var cards: Array[CardData] = run.roll_cards(rh, 3)
	if not cards.is_empty():
		run.add_card(rh, cards[bot_rng.randi_range(0, cards.size() - 1)])


func _rest(run: Node, res: Dictionary) -> void:
	var healthy: bool = true
	for rh in run.party:
		healthy = healthy and rh.hp * 2 >= rh.data.max_hp
	for rh in run.party:
		if healthy and run.wound_count(rh) >= 2:
			run.bandage(rh)
			res["bandages"] += 1
			return
	for rh in run.party:
		run.heal_hero(rh, ceili(rh.data.max_hp * run.rest_percent()))
