extends SceneTree

# Волны подкрепления (claude/тз-сложность-боя.md): вожак, Певчая, огр.
# Запуск: godot --headless --path . -s tests/waves.gd

var fails := 0
var run


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func enemy(id: String) -> EnemyData:
	return load("res://resources/enemies/%s.tres" % id)


func enc(id: String) -> EncounterData:
	return load("res://resources/encounters/%s.tres" % id)


# Бой на чистом поле: герои внизу с большим запасом HP, враги — в верхнем ряду
func fresh(list: Array[EnemyData], encounter: EncounterData, extra: int = 0) -> BattleLogic:
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.set_waves(encounter.waves, extra)
	l.start()
	l.heroes[0].cell = C(4, 10); l.heroes[1].cell = C(7, 10)
	for h in l.heroes:
		h.max_hp = 999; h.hp = 999
	for i in l.enemies.size():
		l.enemies[i].cell = C(3 + i, 0)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(5)
	_schedule()
	_alpha()
	_rules()
	_singer_and_ogre()
	_bell()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _schedule() -> void:
	print("--- Расписание ---")
	var w: WaveData = enc("boss_ogre").waves[0]
	var rounds: Array[int] = []
	for r in range(1, 13):
		if w.arrives_on(r):
			rounds.append(r)
	check("Огр: волны в конце 3, 7, 11 раунда", rounds == ([3, 7, 11] as Array[int]))
	check("Огр: первая волна 2 гоблина, потом по 1", w.count_on(3) == 2 and w.count_on(7) == 1)
	check("Ближайшая волна огра после 4-го раунда — 7-й", w.next_round(4) == 7 and w.next_round(1) == 3)
	var alpha: WaveData = enc("elite_alpha").waves[0]
	check("Вожак: одна волна в конце 2-го раунда", alpha.arrives_on(2) and not alpha.arrives_on(4) and alpha.next_round(3) == -1)
	check("Певчая: волны каждый 3-й раунд", enc("elite_singer").waves[0].arrives_on(3) and enc("elite_singer").waves[0].arrives_on(6))
	check("У обычных отрядов волн нет", enc("pack").waves.is_empty() and enc("elite_queen").waves.is_empty())


func _alpha() -> void:
	print("--- Седой вожак ---")
	var list: Array[EnemyData] = [enemy("grey_alpha"), enemy("wolf")]
	var l := fresh(list, enc("elite_alpha"))
	check("В 1-м раунде клеток прихода нет", l.wave_cells().is_empty())
	check("Подсказка: «Волк ×2 в конце раунда 2»", l.wave_text().begins_with("Волк ×2 в конце раунда 2"))
	l.end_turn()
	var cells: Array[Vector2i] = l.wave_cells()
	var sides := true
	for c in cells:
		sides = sides and (c == l._cell(0, c.y) or c == l._cell(l.width - 1, c.y))
	check("Во 2-м раунде видно 2 клетки прихода на боковых краях", cells.size() == 2 and sides)
	var fx: Array = (l.forecast_hazards()["effects"] as Array).filter(func(e: Dictionary) -> bool: return e["kind"] == "wave")
	check("Прогноз показывает эти же клетки", fx.size() == 1 and fx[0]["cells"] == cells)
	var said: Array[String] = []
	l.message.connect(func(t: String) -> void: said.append(t))
	var before: int = l.living_enemies().size()
	l.end_turn()
	var arrived := true
	for c in cells:
		var u: BattleUnit = l.unit_at(c)
		arrived = arrived and u != null and u.data.id == "wolf"
	check("В конце 2-го раунда пришли 2 волка", l.living_enemies().size() == before + 2)
	check("…ровно на показанные клетки", arrived)
	check("В журнале строка про подмогу", said.any(func(t: String) -> bool: return t.contains("из тумана выходят Волк ×2")))
	check("Больше волн нет — подсказка пуста", l.wave_text() == "")


func _rules() -> void:
	print("--- Правила ---")
	var list: Array[EnemyData] = [enemy("grey_alpha"), enemy("wolf")]
	# Главный погиб — волна не придёт
	var l := fresh(list, enc("elite_alpha"))
	l.end_turn()
	l._damage(l.enemies[0], 999)
	var before: int = l.living_enemies().size()
	check("Вожак погиб: клеток прихода нет, подсказка пуста", l.wave_cells().is_empty() and l.wave_text() == "")
	l.end_turn()
	check("…и волна не пришла", l.living_enemies().size() <= before and not l.is_over)
	# Всех перебили до волны — победа
	var l2 := fresh(list, enc("elite_alpha"))
	l2.end_turn()
	for e in l2.living_enemies():
		l2._damage(e, 999)
	l2._check_end()
	check("Всех перебили до волны — бой выигран", l2.is_over and l2.won)
	l2.end_turn()
	check("…и волна уже не приходит", l2.living_enemies().is_empty())
	# Занятая клетка края пропускается
	var l3 := fresh(list, enc("elite_alpha"))
	l3.end_turn()
	var first: Vector2i = l3.wave_cells()[0]
	l3.heroes[0].cell = first
	check("Герой на клетке прихода — волна приходит рядом", not l3.wave_cells().has(first) and l3.wave_cells().size() == 2)
	# Клон (прогноз) знает про волны
	check("Копия боя (прогноз) видит те же клетки", l3.clone().wave_cells() == l3.wave_cells())


func _singer_and_ogre() -> void:
	print("--- Певчая и огр ---")
	var l := fresh([enemy("choir_singer"), enemy("cultist")] as Array[EnemyData], enc("elite_singer"))
	var counts: Array[int] = []
	var top := true
	for r in 6:
		var cells: Array[Vector2i] = l.wave_cells()
		counts.append(cells.size())
		for c in cells:
			top = top and c.y == l._cell(0, 0).y
		l.end_turn()
		if l.is_over:
			break
	check("Певчая: по 1 послушнику в 3-м и 6-м раунде", counts == ([0, 0, 1, 0, 0, 1] as Array[int]))
	check("…приходят в верхний ряд", top)
	var novices: int = l.living_enemies().filter(func(e: BattleUnit) -> bool: return e.data.id == "cult_novice").size()
	check("На поле 2 послушника из волн", novices == 2)
	var o := fresh([enemy("ogre")] as Array[EnemyData], enc("boss_ogre"))
	o.end_turn(); o.end_turn()
	check("Огр: в 3-м раунде придут 2 гоблина", o.wave_cells().size() == 2)
	o.end_turn()
	check("…пришли", o.living_enemies().filter(func(e: BattleUnit) -> bool: return e.data.id == "goblin").size() == 2)


func _bell() -> void:
	print("--- Звон 4 ---")
	run.start_new_run(6, 4)
	check("Звон 4: +1 в волну", run.wave_extra() == 1)
	run.start_new_run(6, 3)
	check("Звон 3: без добавки", run.wave_extra() == 0)
	var l := fresh([enemy("grey_alpha")] as Array[EnemyData], enc("elite_alpha"), 1)
	l.end_turn()
	check("Звон 4: к вожаку приходят 3 волка", l.wave_cells().size() == 3)
	check("Описание Звона 4 обновлено", not (load("res://scripts/autoload/meta.gd").BELL_RULES[4] as String).contains("Пока не работает"))
