extends SceneTree

# Клетка по колонке и ряду (как раньше x, y): поле из сот хранит клетки осевой парой, см. HexMath
func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)

# Проверка новых врагов акта 1: пращник, топляк, жаба, шаман, корягач и цикл огра.
# Запуск: godot --headless --path . -s tests/enemies.gd

var fails := 0
var run
const O := BattleLogic.Obj
const T := BattleLogic.Tile
const DOWN := Vector2i(0, 1)


# Прямая через мага (он на C(2, 9) = осевая (-2, 9)). В сотах колонка C(2, ...) идёт
# зигзагом, а настоящая прямая «сверху вниз» — это клетки с одной и той же q.
# Шаг по ней вниз — как раз DOWN = (0, 1) (вправо-вниз).
func L(row: int) -> Vector2i:
	return Vector2i(-2, row)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


# Чистое поле: маг на (2,9), рыцарь на (8,9), враги в верхнем ряду
func fresh(enemy_ids: Array) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i + 6, 0)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(7)
	_bog_rule()
	_slinger()
	_drowned()
	_toad()
	_toad_fuse()
	_shaman()
	_treant()
	_ogre()
	_forecast_hazards()
	_run_changes()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _bog_rule() -> void:
	print("--- Герой и трясина ---")
	var l := fresh(["drowned_walker"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = L(8); l.objects[L(10)] = O.BOG
	l._enemies_act()
	check("Героя толкнули в трясину: жив и остался на краю", m.is_alive() and m.cell == C(2, 9))
	check("Героя толкнули в трясину: 4 от удара + 4 от трясины", m.hp == 30 - 4 - 4)


func _slinger() -> void:
	print("--- Гоблин-пращник ---")
	var l := fresh(["goblin_slinger"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = L(5)
	l._enemies_act()
	check("Пращник: подошёл на дальность 3 и попал на 3", e.cell == L(6) and m.hp == 27)
	l = fresh(["goblin_slinger"]); m = l.heroes[0]; e = l.enemies[0]
	e.cell = L(8)
	l._enemies_act()
	check("Пращник: герой вплотную — отступил и бросил", e.cell == L(7) and m.hp == 27)
	l = fresh(["goblin_slinger", "goblin"]); e = l.enemies[0]
	l.enemies[1].cell = L(8)
	var atk: EnemyAttackData = l.enemy_attack(e)
	var cells: Array[Vector2i] = l._attack_cells(e, atk, L(6), DOWN)
	check("Пращник: камень останавливается на первом, в кого попал", cells == [L(7), L(8)])
	l = fresh(["goblin_slinger"]); e = l.enemies[0]
	l.objects[L(8)] = O.REEDS
	check("Пращник: камыш закрывает героя", not l._attack_cells(e, l.enemy_attack(e), L(6), DOWN).has(L(9)))
	l = fresh(["goblin_slinger"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = L(6); l.objects[L(7)] = O.TREE
	l._enemy_strike(e, l.enemy_attack(e), DOWN)
	check("Пращник: камень в дерево — оно падает от него (урон дерева на линии)", l.object_at(L(7)) == O.NONE and m.hp == 30 - BattleLogic.TREE_DAMAGE)
	l = fresh(["goblin_slinger"]); e = l.enemies[0]
	e.cell = L(5); l.objects[L(6)] = O.BARREL
	l._enemy_strike(e, l.enemy_attack(e), DOWN)
	check("Пращник: камень в бочку — взрыв", l.object_at(L(6)) == O.NONE and l.tile_at(L(6)) == T.FIRE)


func _drowned() -> void:
	print("--- Топляк ---")
	var l := fresh(["drowned_walker", "goblin"]); var e: BattleUnit = l.enemies[0]; var g: BattleUnit = l.enemies[1]
	for x in 12: l.objects[C(x, 5)] = O.BOG
	e.cell = C(2, 3); g.cell = C(8, 3)
	l._enemies_act()
	# В сотах «вниз» идёт наискосок, поэтому проверяем ряд, а не колонку: за 2 шага
	# топляк спустился на 2 ряда (напрямик) и стоит в трясине живой
	var bog_cell: Vector2i = e.cell
	check("Топляк: идёт напрямик через трясину и не тонет", e.cell.y == 5 and l.object_at(e.cell) == O.BOG and e.is_alive())
	check("Топляк: клетка, с которой ушёл, стала лужей", l.tile_at(C(2, 3)) == T.WATER)
	check("Гоблин через трясину не идёт", g.cell.y < 5)
	l._enemies_act()
	check("Топляк: с трясины лужи не остаётся", l.tile_at(bog_cell) == T.NONE and l.object_at(bog_cell) == O.BOG)
	l = fresh(["drowned_walker"]); e = l.enemies[0]
	e.cell = C(5, 5); l.objects[C(5, 5) + DOWN] = O.BOG
	l._push(e, DOWN, 1)
	check("Топляк: толчок в трясину — просто встал в неё", e.is_alive() and e.cell == C(5, 5) + DOWN and e.hp == 16)
	l = fresh(["drowned_walker"]); e = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	e.cell = L(8)
	l._enemies_act()
	check("Топляк: 4 урона и отталкивает на 1", m.hp == 26 and m.cell == L(10))
	l = fresh(["drowned_walker"]); e = l.enemies[0]; m = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	e.cell = L(8); k.cell = L(10)
	l._enemies_act()
	check("Топляк: толкнул героя в героя — обоим урон удара о препятствие", m.hp == 30 - 4 - BattleLogic.BUMP_DAMAGE and k.hp == 45 - BattleLogic.BUMP_DAMAGE and m.cell == L(9))
	l = fresh(["goblin", "drowned_walker"]); g = l.enemies[0]; e = l.enemies[1]
	l.objects[C(5, 5) + DOWN] = O.BOG; e.cell = C(5, 5) + DOWN; g.cell = C(5, 5)
	l._push(g, DOWN, 1)
	check("Гоблин врезался в топляка, стоящего в трясине: обычный урон удара, не тонет", g.is_alive() and g.hp == 11 - BattleLogic.BUMP_DAMAGE and e.hp == 16 - BattleLogic.BUMP_DAMAGE)


func _toad() -> void:
	print("--- Раздутая жаба ---")
	var l := fresh(["bloated_toad"]); var e: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	e.cell = L(7)
	l._enemies_act()
	check("Жаба: язык — 2 урона и притягивает на 1", m.hp == 28 and m.cell == L(8) and e.cell == L(7))
	l = fresh(["bloated_toad"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = L(8); e.entangled = 1
	l._enemies_act()
	check("Жаба: вплотную кусает на 2 без притягивания", m.hp == 28 and m.cell == L(9))
	l = fresh(["bloated_toad"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = L(7); l.objects[L(8)] = O.BOG
	l._enemies_act()
	check("Жаба: тянет героя в трясину — 2 + 4 урона, герой на краю", m.hp == 24 and m.cell == L(9))
	# Из двух одинаково близких клеток выбирает ту, откуда затянет в огонь.
	# Жаба на (-1, 7): в шаге от неё две клетки, откуда язык достаёт мага по прямой, —
	# (-2, 7) (тянет влево-вверх) и (0, 7) (тянет вправо-вверх).
	l = fresh(["bloated_toad"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = Vector2i(-1, 7); l._set_tile(Vector2i(-2, 8), T.FIRE)
	l._enemies_act()
	check("Жаба: встаёт так, чтобы затянуть в огонь (слева-сверху)", e.cell == Vector2i(-2, 7) and m.cell == Vector2i(-2, 8))
	l = fresh(["bloated_toad"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = Vector2i(-1, 7); l._set_tile(Vector2i(-1, 8), T.FIRE)
	l._enemies_act()
	check("Жаба: встаёт так, чтобы затянуть в огонь (справа-сверху)", e.cell == Vector2i(0, 7) and m.cell == Vector2i(-1, 8))
	# Посмертный взрыв (редизайн, «Нестабильная слизь»): 12 урона и 3 яда всем вокруг —
	# и своим, и героям; деревья рядом падают. Лужи больше нет.
	l = fresh(["bloated_toad", "goblin"]); e = l.enemies[0]; var g: BattleUnit = l.enemies[1]; m = l.heroes[0]
	e.cell = C(5, 5); g.cell = C(5, 4); m.cell = C(5, 6)
	l.objects[C(4, 5)] = O.TREE
	l._damage(e, 99)
	check("Жаба: взрыв — 12 урона соседям, гоблин погиб, маг ранен и отравлен",
			not g.is_alive() and m.hp == 30 - BattleLogic.INFLATION_DAMAGE and m.poison == BattleLogic.INFLATION_POISON)
	check("Жаба: взрыв валит соседнее дерево", l.object_at(C(4, 5)) == O.NONE)
	l = fresh(["bloated_toad", "bloated_toad"]); e = l.enemies[0]; var e2: BattleUnit = l.enemies[1]
	e.cell = C(5, 5); e2.cell = C(6, 5); e2.hp = 3
	l._damage(e, 99)
	check("Жаба: взрыв убивает соседнюю жабу — цепочка без зависания", not e.is_alive() and not e2.is_alive())
	l = fresh(["bloated_toad", "goblin"]); e = l.enemies[0]; g = l.enemies[1]
	e.cell = C(5, 5); g.cell = C(5, 4); l.objects[C(5, 5) + DOWN] = O.BOG
	l._push(e, DOWN, 1)
	check("Жаба: утонула в трясине — взрыва нет", not e.is_alive() and g.hp == 11 and l.tile_at(C(5, 5)) == T.NONE)
	l = fresh(["bloated_toad"]); e = l.enemies[0]
	e.cell = C(5, 5); e.hp = 2; e.entangled = 1; l._set_tile(C(5, 5), T.FIRE)
	l.end_turn()
	check("Жаба: сгорела в конце раунда — взрыв, бой окончен, игра не падает",
			not e.is_alive() and l.is_over)
	l = fresh(["bloated_toad", "goblin"]); e = l.enemies[0]; g = l.enemies[1]
	e.cell = C(5, 5); g.cell = C(7, 6); l.tiles[C(5, 6)] = T.WATER; l.tiles[C(6, 6)] = T.WATER
	var hit: Array[Vector2i] = l._spread_through_water([C(6, 6)] as Array[Vector2i])
	check("Жаба: молния по соседней луже бьёт и её, гоблина рядом — нет", hit.has(C(5, 5)) and not hit.has(C(7, 6)))


# Жаба с фитилём: раненая (HP ≤ 4) или раздутая (2+ стака) жаба не бьёт, а прыгает
# к героям и поджигает фитиль; в начале следующего хода врагов взрывается.
func _toad_fuse() -> void:
	print("--- Жаба с фитилём ---")
	var l := fresh(["bloated_toad"]); var e: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	check("Целая жаба не тлеет", not l.is_smoldering(e))
	e.inflation = BattleLogic.TOAD_FUSE_STACKS
	check("Жаба с 2 стаками «Раздувания» тлеет", l.is_smoldering(e))
	e.inflation = 0; e.hp = BattleLogic.TOAD_FUSE_HP
	check("Жаба с 4 HP тлеет", l.is_smoldering(e))

	# Прыжок: с L(5) до мага на L(9) — 3 шага (обычные 2 + 1 прыжка), вплотную, без укуса
	e.cell = L(5)
	l._enemies_act()
	check("Тлеющая жаба прыгнула вплотную к магу и не укусила",
			HexMath.distance(e.cell, m.cell) == 1 and m.hp == 30 and e.fuse == 1)
	check("Намерение тлеющей жабы — взрыв", l.snapshot(e)["intent"] == "Взрыв!" and l.snapshot(e)["damage"] == BattleLogic.INFLATION_DAMAGE)
	l._enemies_act()
	check("Фитиль догорел: взрыв — 12 урона и яд магу",
			not e.is_alive() and m.hp == 30 - BattleLogic.INFLATION_DAMAGE and m.poison == BattleLogic.INFLATION_POISON)

	# Оттолкнули тлеющую жабу — взорвалась далеко от героев
	l = fresh(["bloated_toad"]); e = l.enemies[0]; m = l.heroes[0]
	e.hp = 3; e.cell = L(5)
	l._enemies_act()
	l._push(e, Vector2i(0, -1), 3)
	l._enemies_act()
	check("Оттолкнули тлеющую жабу — взрыв никого не задел", not e.is_alive() and m.hp == 30)

	# Ледяное копьё гасит фитиль: в этот ход взрыва нет, жаба снова прыгает и зажигает его
	l = fresh(["bloated_toad"]); e = l.enemies[0]; m = l.heroes[0]
	e.hp = 3; e.cell = L(5)
	l._enemies_act()
	var lance: Array[CardData] = [load("res://resources/cards/ice_lance.tres")]
	m.hand = lance
	var hp_before: int = e.hp
	e.hp = 99   # копьё не должно её убить — проверяем только лёд
	l.play_card(m, 0, e.cell)
	e.hp = hp_before
	check("Ледяное копьё погасило фитиль", e.fuse == 0)
	l._enemies_act()
	check("После льда взрыва нет: жаба жива, фитиль горит снова", e.is_alive() and e.fuse == 1 and m.hp == 30)

	# Утонула с горящим фитилём — взрыва нет
	l = fresh(["bloated_toad", "goblin"]); e = l.enemies[0]; var g: BattleUnit = l.enemies[1]
	e.hp = 3; e.fuse = 1; e.cell = C(5, 5); g.cell = C(5, 4); l.objects[C(5, 5) + DOWN] = O.BOG
	l._push(e, DOWN, 1)
	l._enemies_act()
	check("Утонула с горящим фитилём — взрыва нет", not e.is_alive() and g.hp == g.max_hp)


func _shaman() -> void:
	print("--- Гоблин-шаман ---")
	var l := fresh(["goblin_shaman"]); var e: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	check("Шаман: начинает бой с блоком 2", e.block == 2)
	e.cell = C(2, 6)
	check("Шаман: в нечётный раунд — луч", l.enemy_attack(e).title == "Болотный луч")
	l._enemies_act()
	check("Шаман: луч — 3 урона и лужа под целью", m.hp == 27 and l.tile_at(C(2, 9)) == T.WATER)
	check("Шаман: стартовый блок сгорел в начале хода врагов", e.block == 0)
	l = fresh(["goblin_shaman", "goblin", "goblin"]); e = l.enemies[0]
	var g1: BattleUnit = l.enemies[1]; var g2: BattleUnit = l.enemies[2]
	e.cell = C(0, 0); g1.cell = C(3, 0); g2.cell = C(4, 0)
	g1.entangled = 2; g2.entangled = 2   # чтобы гоблины стояли на месте
	l.turn = 2
	check("Шаман: в чётный раунд — зов", l.enemy_attack(e).title == "Зов Раскола")
	var plan: Dictionary = {}
	for f in l.forecast_enemies():
		if (f["enemy"] as BattleUnit) == e: plan = f
	check("Шаман: прогноз показывает зов, а не удар", (plan["buff"] as Array).size() > 0 and (plan["attack"] as Array).is_empty())
	check("Шаман: в раунд зова зоны угрозы нет", l.get_threat_cells(e).is_empty())
	l._enemies_act()
	check("Шаман: встал так, чтобы накрыть обоих гоблинов", e.cell == C(2, 0))
	check("Шаман: зов даёт +3 блока своим и себе", g1.block == 3 and g2.block == 3 and e.block == 3)
	check("Шаман: зов усиливает следующий удар на 1", g1.bonus_damage == 1 and l.snapshot(g1)["damage"] == 5)
	l._enemies_act()
	check("Шаман: блок не копится (второй зов подряд — снова 3)", g1.block == 3 and e.block == 3)
	# Усиленный удар тратит усиление
	l = fresh(["goblin"]); var g: BattleUnit = l.enemies[0]; m = l.heroes[0]
	g.cell = C(2, 8); g.bonus_damage = 1
	l._enemies_act()
	check("Усиленный гоблин бьёт на 5, потом снова на 4", m.hp == 25 and g.bonus_damage == 0)


func _treant() -> void:
	print("--- Мшистый корягач ---")
	var l := fresh(["mossy_treant"]); var e: BattleUnit = l.enemies[0]
	var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	e.cell = L(8)
	l._enemies_act()
	check("Корягач: броня +3 в начале хода", e.block == 3)
	check("Корягач: размах — 5 урона и отталкивает на 1", m.hp == 25 and m.cell == L(10))
	l._enemies_act()
	check("Корягач: броня не копится", e.block == 3)
	l = fresh(["mossy_treant"]); e = l.enemies[0]; m = l.heroes[0]; k = l.heroes[1]
	# Дуга вниз от (-2, 8): маг (-2, 9) и две клетки рядом с ним, что тоже вплотную
	# к корягачу, — (-3, 9) слева от мага и (-1, 8). Рыцаря ставим слева от мага.
	e.cell = L(8); k.cell = L(9) + Vector2i(-1, 0)
	l._enemy_strike(e, l.enemy_attack(e), DOWN)
	check("Корягач: размах задевает три клетки — обоих героев", m.hp == 25 and k.hp == 40
			and m.cell == L(10) and k.cell == Vector2i(-3, 10))
	l = fresh(["mossy_treant"]); e = l.enemies[0]; m = l.heroes[0]; k = l.heroes[1]
	e.cell = L(6); l.objects[L(7)] = O.TREE; l.objects[L(8)] = O.REEDS
	l.turn = 2
	check("Корягач: в чётный раунд — корни", l.enemy_attack(e).title == "Подземные корни")
	l._enemies_act()
	check("Корягач: корни — 4 урона сквозь дерево и камыш, преграды целы",
			m.hp == 26 and l.object_at(L(7)) == O.TREE and l.object_at(L(8)) == O.REEDS)
	check("Корягач: корни опутывают", m.entangled == 1)
	l._start_heroes_turn()
	check("Опутанный герой: шагов нет, мана и карты на месте", m.moves_left == 0 and m.mana == 3 and m.hand.size() >= 5)
	check("Опутывание: второй герой ходит как обычно", k.moves_left == 3)
	l._enemies_act(); l._start_heroes_turn()
	check("Опутывание длится один ход", m.entangled == 0)
	l = fresh(["mossy_treant"]); e = l.enemies[0]
	check("Корягач: броня есть с первого хода (блок 3)", e.block == 3)
	e.cell = C(5, 5); l.objects[C(5, 5) + DOWN] = O.BOG
	l._push(e, DOWN, 1)
	check("Корягач: в трясине не тонет, 6 урона (3 в броню, 3 по здоровью)", e.is_alive() and e.cell == C(5, 5) and e.hp == 35 and e.block == 0)
	l = fresh(["mossy_treant"]); e = l.enemies[0]
	e.cell = C(5, 5); e.block = 3
	l._set_tile(C(5, 5), T.FIRE)
	check("Корягач: огонь под ногами сжигает броню", e.block == 0)
	e.entangled = 1   # чтобы не ушёл с огня
	l.end_turn()
	check("Корягач: в огне брони нет и урон от огня двойной", e.block == 0 and e.hp == 38 - 2 * BattleLogic.FIRE_DAMAGE)
	l = fresh(["mossy_treant"]); e = l.enemies[0]
	e.cell = C(5, 5); e.block = 3; l.objects[C(5, 6)] = O.BARREL
	l._explode_barrel(C(5, 6))
	check("Корягач: взрыв бочки срывает броню — весь урон проходит", e.hp == 38 - BattleLogic.BARREL_DAMAGE and e.block == 0)


func _ogre() -> void:
	print("--- Огр: цикл ударов ---")
	var l := fresh(["ogre"]); var e: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	e.cell = C(2, 8)
	check("Огр: нечётный раунд — размах колонной", l.enemy_attack(e).title == "Размах колонной")
	l._enemies_act()
	check("Огр: размах — 6 урона", m.hp == 24)
	l = fresh(["ogre"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = L(6); e.entangled = 1; l.turn = 2
	check("Огр: чётный раунд — хлёст цепью", l.enemy_attack(e).title == "Хлёст цепью")
	l._enemies_act()
	check("Огр: цепь — 4 урона с трёх клеток и притягивает на 1", m.hp == 26 and m.cell == L(8))
	# Третий раунд — круговой удар. Огр стоит рядом с магом (вправо-вверх).
	l = fresh(["ogre"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = C(3, 8); e.entangled = 1; l.turn = 3
	check("Огр: третий раунд — круговой удар", l.enemy_attack(e).title == "Круговой удар")
	var spin_cells: Array[Vector2i] = []
	for f in l.forecast_enemies():
		if f["enemy"] == e: spin_cells = f["attack"]
	check("Огр: прогноз кругового удара — 6 клеток вокруг, клетка мага среди них",
		spin_cells.size() == 6 and spin_cells.has(m.cell) and not spin_cells.has(e.cell))
	l._enemies_act()
	check("Огр: круговой удар достаёт соседа — 5 урона", m.hp == 25 and m.cell == C(2, 9))
	check("Огр: рыцарь вдали не задет", l.heroes[1].hp == 45)
	# Круговой удар задевает и своих — это механика удара. ИИ сам такой удар не выберет
	# (тест «не бьёт своих сильнее, чем героев» — в tests/enemy_ai.gd), поэтому бьём напрямую.
	l = fresh(["ogre", "goblin"]); e = l.enemies[0]; m = l.heroes[0]
	var g: BattleUnit = l.enemies[1]
	e.cell = C(3, 8); g.cell = C(4, 8); l.turn = 3
	l._enemy_strike(e, l.enemy_attack(e), HexMath.direction_to(e.cell, m.cell))
	check("Огр: круговой удар задевает и своих", g.hp == 11 - 5 and m.hp == 25)
	l = fresh(["ogre"]); e = l.enemies[0]; l.turn = 4
	check("Огр: четвёртый раунд — цикл пошёл заново, размах колонной", l.enemy_attack(e).title == "Размах колонной")
	l = fresh(["ogre"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = C(2, 6); l.turn = 3
	l._enemies_act()
	check("Огр: в раунд кругового удара сам подходит и бьёт", m.hp == 25)
	l = fresh(["ogre"]); e = l.enemies[0]
	e.cell = C(5, 5); l.objects[C(5, 5) + DOWN] = O.BOG
	l._push(e, DOWN, 1)
	check("Огр: трясина по-прежнему как стена, 8 урона", e.is_alive() and e.hp == 52 and e.cell == C(5, 5))


# Прогноз окружения: взрыв бочки от удара врага и огонь в конце раунда
func _forecast_hazards() -> void:
	print("--- Прогноз окружения ---")
	# Культист бьёт линией по бочке рядом с магом: взрыв заденет мага. Культист опутан — стоит на месте.
	var l := fresh(["cultist"]); var e: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	e.cell = Vector2i(-2, 4); e.entangled = 1
	var barrel: Vector2i = Vector2i(-2, 8)   # четвёртая клетка линии, соседняя с магом
	l.objects[barrel] = O.BARREL
	l.tiles[C(2, 9)] = T.FIRE; l.fire_timers[C(2, 9)] = 3   # маг стоит в огне
	var hp_before: int = m.hp
	var hz: Dictionary = l.forecast_hazards()
	var blast_found := false
	for fx: Dictionary in hz["effects"]:
		if fx["kind"] == "explosion" and (fx["cells"] as Array).has(barrel): blast_found = true
	check("Прогноз: удар культиста по бочке рядом — крест взрыва есть в прогнозе", blast_found)
	check("Прогноз: маг в огне — в конце раунда минус урон огня", hz["fire"].get(m.id, 0) == BattleLogic.FIRE_DAMAGE)
	check("Прогноз ничего не менял в настоящем бою", m.hp == hp_before and l.object_at(barrel) == O.BARREL)


func _run_changes() -> void:
	print("--- Модели ---")
	var models_ok := true
	for id in ["goblin_slinger", "bloated_toad", "drowned_walker", "goblin_shaman", "mossy_treant"]:
		if (load("res://resources/enemies/%s.tres" % id) as EnemyData).model == null: models_ok = false
	check("У всех пяти новых врагов подключена модель", models_ok)
	print("--- Забег ---")
	var shamans_ok := true; var treants_ok := true; var seen: Dictionary = {}
	for s in range(1, 201):
		run.start_new_run(s)
		for row in 6:
			var enc: Array[EnemyData] = run._make_encounter(row, false)
			var sh := 0
			for d in enc:
				seen[d.id] = true
				if d.id == "goblin_shaman": sh += 1
				if d.is_elite: treants_ok = false
			if sh > 1: shamans_ok = false
			if enc.size() != 4 + row / 2: treants_ok = false
		var elite: Array[EnemyData] = run._make_encounter(5, false, true)
		if elite.size() != 4 or elite[0].id != "mossy_treant": treants_ok = false
		for n in run.row_nodes(run.MAP_ROWS - 3):
			if n.type != MapNode.Type.ELITE: treants_ok = false
		for n in run.map:
			if n.type == MapNode.Type.ELITE and n.row != run.MAP_ROWS - 3: treants_ok = false
	check("В обычных боях встречаются все 7 видов врагов", seen.size() == 7)
	check("Шаман — не больше одного на бой", shamans_ok)
	check("Корягач — только в элитном бою (ряд перед привалом), с тремя спутниками", treants_ok)
