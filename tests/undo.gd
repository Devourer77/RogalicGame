extends SceneTree
# Отмена хода: снимок боя должен быть полным.
# Случайные бои на всех аренах актов 1–2 (обычные отряды, элиты, боссы): герои играют
# случайные карты, ходят, сбрасывают «в ноги» и за ману. Перед каждым действием —
# save_state(), после — load_state() и сравнение ВСЕХ полей логики и юнитов с тем, что было.
# Потом то же действие ещё раз: результат должен совпасть (бой детерминирован).
# Заодно считает «точку невозврата»: какие действия тратят случайность или добирают карты.
# Запуск: godot --headless --path . -s tests/undo.gd   (BATTLES=N — сколько боёв, по умолчанию 120)

var errors: int = 0
var checks: int = 0
var barrier: Dictionary = {}   # что за действие -> [сколько раз, сколько тратило rng, сколько добирало]


var _extra: Dictionary = {}   # id героя -> карты духов и смешанных пар (их нет в card_pool)


# Карты духов и смешанных пар для героя: по суффиксу файла _m… (маг) или _k… (рыцарь)
func extra_cards(hero_id: String) -> Array[CardData]:
	if _extra.has(hero_id):
		return _extra[hero_id]
	var mark: String = "_m" if hero_id == "mage" else "_k"
	var list: Array[CardData] = []
	var dirs: Array[String] = ["res://resources/cards/mixed"]
	for d in DirAccess.get_directories_at("res://resources/cards/spirits"):
		dirs.append("res://resources/cards/spirits/" + d)
	for dir in dirs:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".tres") and f.get_basename().rsplit("_", true, 1)[-1].begins_with(mark.substr(1)):
				list.append(load(dir + "/" + f))
	_extra[hero_id] = list
	return list


func check(name: String, ok: bool) -> void:
	checks += 1
	if not ok:
		errors += 1
		if errors <= 12:
			print("  ОШИБКА: ", name)


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	var battles: int = int(OS.get_environment("BATTLES")) if OS.get_environment("BATTLES") != "" else 120
	var act2: ActData = load("res://resources/acts/act_2.tres")
	var act2_fights: Array[EncounterData] = act2.encounters + act2.elite_pool + act2.boss_pool
	var all_arenas: Array = BattleLogic.ARENAS.keys()
	var actions: int = 0
	var arenas_seen: Dictionary = {}
	for s in range(1, battles + 1):
		run.start_new_run(s)
		var b := BattleLogic.new()
		if s % 2 == 0:
			var enc: EncounterData = act2_fights[s % act2_fights.size()]
			var arena: String = enc.arena if enc.arena != "" else all_arenas[s % all_arenas.size()]
			b.setup(12, 12, run.rng, run.party, enc.core, arena, BattleLogic.Objective.KILL_ALL, [], enc.formation)
		else:
			var squad: Array[EnemyData] = run._make_encounter(s % 8, s % 10 == 1, s % 4 == 1)
			b.setup(12, 12, run.rng, run.party, squad, all_arenas[s % all_arenas.size()])
		arenas_seen[b.arena_id] = true
		b.start()
		for t in 8:
			if b.is_over:
				break
			if t % 2 == 1:
				# Через ход — случайная рука из всего набора героя (как в fuzz_enemies),
				# чтобы через снимок прошли все карты, а не только стартовые
				for h in b.living_heroes():
					var pool: Array[CardData] = h.hero_data.card_pool + extra_cards(h.hero_data.id)
					var hand: Array[CardData] = []
					for i in 5:
						hand.append(pool[run.rng.randi_range(0, pool.size() - 1)])
					h.hand = hand
					h.kept.clear()
					h.mana = 6
			for step in 10:
				if b.is_over:
					break
				var act: Dictionary = pick_action(b, run.rng)
				if act.is_empty():
					break
				actions += 1
				try_undo(b, run.rng, act, "бой %d ход %d" % [s, t])
			if b.is_over:
				break
			# «Конец хода» — тоже через снимок: ход врагов меняет больше всего (волны, огонь, призыв)
			try_undo(b, run.rng, {"kind": "end"}, "бой %d конец хода %d" % [s, t])
	print("боёв: %d, арен: %d, действий героев: %d, проверок: %d" % [battles, arenas_seen.size(), actions, checks])
	report_barrier()
	print("ошибок: %d" % errors)
	quit(1 if errors > 0 else 0)


# Случайное законное действие героя. Возвращает описание (по нему действие можно повторить).
func pick_action(b: BattleLogic, rng: RandomNumberGenerator) -> Dictionary:
	var heroes: Array[BattleUnit] = b.living_heroes()
	heroes.shuffle()
	for h in heroes:
		var hi: int = b.heroes.find(h)
		var roll: int = rng.randi_range(0, 9)
		if roll < 6 and not h.hand.is_empty():
			var idx: int = rng.randi_range(0, h.hand.size() - 1)
			if b.can_play(h, idx):
				var card: CardData = h.hand[idx]
				if card.shape == CardData.Shape.SELF:
					return {"kind": "card", "hero": hi, "index": idx, "target": h.cell, "id": card.id}
				var targets: Array[Vector2i] = b.get_card_targets(h, idx)
				if not targets.is_empty():
					return {"kind": "card", "hero": hi, "index": idx, "id": card.id,
							"target": targets[rng.randi_range(0, targets.size() - 1)]}
		if roll < 8:
			var mv: Dictionary = b.get_move_targets(h)
			if not mv.is_empty():
				return {"kind": "move", "hero": hi, "target": mv.keys()[rng.randi_range(0, mv.size() - 1)]}
		if roll == 8 and not h.hand.is_empty():
			var idx: int = rng.randi_range(0, h.hand.size() - 1)
			return {"kind": "scrap", "hero": hi, "index": idx, "id": h.hand[idx].id}
		if roll == 9 and not h.hand.is_empty() and b.discards_left(h) > 0:
			var idx: int = rng.randi_range(0, h.hand.size() - 1)
			if b.can_discard(h, idx):
				return {"kind": "discard", "hero": hi, "index": idx, "id": h.hand[idx].id}
	return {}


func run_action(b: BattleLogic, act: Dictionary) -> bool:
	match act["kind"]:
		"end":
			b.end_turn()
			return true
		"card":
			return b.play_card(b.heroes[act["hero"]], act["index"], act["target"])
		"move":
			return b.move_hero(b.heroes[act["hero"]], act["target"])
		"scrap":
			return b.scrap_card(b.heroes[act["hero"]], act["index"])
		"discard":
			return b.discard_card(b.heroes[act["hero"]], act["index"])
	return false


# Действие → откат → сравнение → повтор → сравнение. Бой остаётся в состоянии «после действия».
func try_undo(b: BattleLogic, rng: RandomNumberGenerator, act: Dictionary, where: String) -> void:
	var before: Dictionary = b.save_state()
	check("в снимке нет самого генератора и контекста", not before.has("rng") and not before.has("ctx"))
	var rng_before: int = rng.state
	var piles_before: Array[int] = []
	for h in b.heroes:
		piles_before.append(h.draw_pile.size())
	var ok: bool = run_action(b, act)
	var after: Dictionary = b.save_state()
	var rng_after: int = rng.state
	if ok and act["kind"] != "end":
		note_barrier(b, act, rng_before != rng_after, piles_before)
	# Копия боя (прогноз врагов, предпросмотр) — тоже полная: те же поля, свои юниты
	var twin: BattleLogic = b.clone()
	var twin_diff: PackedStringArray = StateCopy.diff(StateCopy.by_ids(after), StateCopy.by_ids(twin.save_state()))
	check("%s, %s: копия боя отличается %s" % [where, describe(act), twin_diff], twin_diff.is_empty())
	check("копия боя: свои юниты и свой генератор", twin.rng != b.rng and (b.heroes.is_empty() or twin.heroes[0] != b.heroes[0]))
	# Откат
	b.load_state(before)
	var back: PackedStringArray = StateCopy.diff(before, b.save_state())
	check("%s, %s: после отката отличается %s" % [where, describe(act), back], back.is_empty())
	check("%s, %s: генератор не вернулся" % [where, describe(act)], rng.state == rng_before)
	# Повтор того же действия — тот же итог
	var ok2: bool = run_action(b, act)
	var again: PackedStringArray = StateCopy.diff(StateCopy.by_ids(after), StateCopy.by_ids(b.save_state()))
	check("%s, %s: повтор дал другое %s" % [where, describe(act), again], ok == ok2 and again.is_empty())


func describe(act: Dictionary) -> String:
	return "%s %s" % [act["kind"], act.get("id", "")]


# Точка невозврата: действие потратило случайность или герой добрал карту из колоды
func note_barrier(b: BattleLogic, act: Dictionary, used_rng: bool, piles_before: Array[int]) -> void:
	var drew: bool = false
	for i in b.heroes.size():
		if b.heroes[i].draw_pile.size() < piles_before[i]:
			drew = true
	var key: String = act["kind"] if act["kind"] == "move" else "%s %s" % [act["kind"], act.get("id", "")]
	var row: Array = barrier.get(key, [0, 0, 0])
	row[0] += 1
	if used_rng:
		row[1] += 1
	if drew:
		row[2] += 1
	barrier[key] = row


func report_barrier() -> void:
	var total: int = 0
	var closed: int = 0
	var lines: Array[String] = []
	for key: String in barrier:
		var row: Array = barrier[key]
		total += row[0]
		var shut: int = maxi(row[1], row[2])
		closed += shut
		if row[1] > 0 or row[2] > 0:
			lines.append("  %-34s раз %4d  случайность %4d  добор %4d" % [key, row[0], row[1], row[2]])
	lines.sort()
	print("Точка невозврата: закрыли отмену примерно %d из %d действий (%.0f%%)" % [closed, total, 100.0 * closed / maxi(total, 1)])
	for l in lines:
		print(l)
