extends SceneTree

# Строй отрядов (EncounterData.formation): где враги стоят в начале боя.
# Запуск: godot --headless --path . -s tests/formations.gd

var fails := 0
var run


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func enc(id: String) -> EncounterData:
	return load("res://resources/encounters/%s.tres" % id)


# Столбец клетки (0 — левый край) в смещённых координатах
func col(l: BattleLogic, c: Vector2i) -> int:
	for x in l.width:
		if l._cell(x, c.y) == c:
			return x
	return -1


# Бой отрядом id со строем; seed — свой для каждого повтора
func battle(id: String, seed: int) -> BattleLogic:
	run.start_new_run(seed)
	var e: EncounterData = enc(id)
	var list: Array[EnemyData] = []
	list.assign(e.core)
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list, "grove", BattleLogic.Objective.KILL_ALL, [] as Array[String], e.formation)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	var tries: int = 20
	var ok_all: Dictionary[String, int] = {}
	for s in tries:
		# Стая — фланги: враги у левого и правого края, никого в середине
		var l := battle("pack", 100 + s)
		var sides := l.enemies.size() == 4
		var left := 0
		for e in l.enemies:
			var x: int = col(l, e.cell)
			sides = sides and (x <= 3 or x >= l.width - 4)
			if x <= 3: left += 1
		_count(ok_all, "flank", sides and left == 2)
		# Шайка — заслон: пращник выше всех гоблинов
		l = battle("gang", 200 + s)
		var sling_y := 99
		var gob_y := 99
		for e in l.enemies:
			if e.data.keep_distance > 0: sling_y = e.cell.y
			else: gob_y = mini(gob_y, e.cell.y)
		_count(ok_all, "screen", l.enemies.size() == 4 and sling_y < gob_y)
		# Облава — засада: один волк в 3–4 рядах от героев у края
		l = battle("hunt", 300 + s)
		var close := 0
		for e in l.enemies:
			if e.cell.y >= l.height - 6 and (col(l, e.cell) <= 2 or col(l, e.cell) >= l.width - 3):
				close += 1
				_count(ok_all, "ambush_wolf", e.data.id == "wolf")
		_count(ok_all, "ambush", close == 1)
		# Жабья кочка — куча: каждый рядом хотя бы с одним своим
		l = battle("toad_mound", 400 + s)
		var tight := l.enemies.size() == 4
		for e in l.enemies:
			tight = tight and l.enemies.any(func(o: BattleUnit) -> bool: return o != e and HexMath.adjacent(o.cell, e.cell))
		_count(ok_all, "cluster", tight)
		# Хор — россыпь: никто не стоит вплотную к другому
		l = battle("choir", 500 + s)
		var apart := true
		for e in l.enemies:
			apart = apart and not l.enemies.any(func(o: BattleUnit) -> bool: return o != e and HexMath.distance(o.cell, e.cell) <= 2)
		_count(ok_all, "spread", apart)
		# Никто не стоит в рядах героев и все на свободных клетках
		for id in ["pack", "gang", "hunt", "toad_mound", "choir", "bog_folk", "novices", "reed_ambush"]:
			l = battle(id, 600 + s)
			var fine := true
			for e in l.enemies:
				fine = fine and e.cell.y < l.height - 3 and not l.rocks.has(e.cell) and not l.objects.has(e.cell)
			if not fine and OS.get_environment("DEBUG") != "":
				print("  safe: ", id, " ", l.enemies.map(func(e): return [e.data.id, e.cell, l.rocks.has(e.cell), l.objects.get(e.cell, -1)]))
			_count(ok_all, "safe", fine)
	check("Фланги: по двое у левого и правого края (%d/%d)" % [ok_all.get("flank", 0), tries], ok_all.get("flank", 0) == tries)
	check("Заслон: пращник за гоблинами (%d/%d)" % [ok_all.get("screen", 0), tries], ok_all.get("screen", 0) == tries)
	check("Засада: ровно один враг сбоку у героев (%d/%d)" % [ok_all.get("ambush", 0), tries], ok_all.get("ambush", 0) == tries)
	check("…и это волк", ok_all.get("ambush_wolf", 0) == ok_all.get("ambush", 0))
	check("Куча: каждый рядом со своим (%d/%d)" % [ok_all.get("cluster", 0), tries], ok_all.get("cluster", 0) == tries)
	check("Россыпь: между врагами больше 2 клеток (%d/%d)" % [ok_all.get("spread", 0), tries], ok_all.get("spread", 0) == tries)
	check("Все строи: враги не в рядах героев и не в камнях", ok_all.get("safe", 0) == tries * 8)
	# Без строя — как раньше: верхние ряды
	run.start_new_run(7)
	var free := BattleLogic.new()
	var list: Array[EnemyData] = []
	list.assign(enc("pack").core)
	free.setup(12, 12, run.rng, run.party, list, "grove")
	check("Без строя враги в верхних рядах", free.enemies.all(func(e: BattleUnit) -> bool: return e.cell.y <= free._enemy_last_row()))
	# Ранние отряды получили строй, новые отряды в пуле
	var early: Array[String] = []
	for e: EncounterData in run.encounters():
		if e.max_row <= 1 and e.formation == BattleLogic.Formation.FREE:
			early.append(e.id)
	check("У всех отрядов рядов 0–1 есть строй " + str(early), early.is_empty())
	check("Облава и Жабья кочка в пуле обычных боёв", run.encounters().has(enc("hunt")) and run.encounters().has(enc("toad_mound")))
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _count(d: Dictionary[String, int], key: String, ok: bool) -> void:
	if ok:
		d[key] = d.get(key, 0) + 1
