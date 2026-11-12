extends SceneTree

# Клетка по колонке и ряду (как раньше x, y): поле из сот хранит клетки осевой парой, см. HexMath
func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)

# Прямая через мага (он на осевой (-2, 9)): клетки с одной q лежат на одной линии.
# Колонка C(2, ...) в сотах идёт зигзагом, поэтому «прямо над магом» — это L(ряд).
func L(row: int) -> Vector2i:
	return Vector2i(-2, row)

const UP_LEFT := Vector2i(0, -1)   # шаг влево-вверх (по линии L к врагам)

# Реакции стихий: паровой взрыв, ледяные осколки, заморозка.
# Запуск: godot --headless --path . -s tests/reactions.gd

var fails := 0
var run
const O := BattleLogic.Obj
const T := BattleLogic.Tile
const E := CardData.Element


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func fresh(enemy_ids: Array) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i, 0)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(7)
	_steam()
	_shatter()
	_freeze()
	_lava()
	_crust()
	_wind()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _steam() -> void:
	print("--- Паровой взрыв ---")
	var l := fresh(["goblin"]); var g: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	g.cell = L(6); l.tiles[L(6)] = T.WATER
	var hp: int = g.hp
	l._apply_element(L(6), E.FIRE, m.cell)
	check("Огонь на луже: враг получил паровой урон", g.hp == hp - BattleLogic.STEAM_DAMAGE or not g.is_alive())
	check("Лужа исчезла, огня нет", l.tile_at(L(6)) == T.NONE)
	if g.is_alive():
		check("Врага отбросило от мага", g.cell == L(5))
	# Герой от своей карты не страдает, от бочки — страдает
	l = fresh(["goblin"]); m = l.heroes[0]
	m.cell = C(5, 5); l.tiles[C(5, 5)] = T.WATER
	hp = m.hp
	l._apply_element(C(5, 5), E.FIRE, C(5, 8))
	check("Герой на луже от своей карты цел", m.hp == hp)
	l.tiles[C(5, 5)] = T.WATER
	l._apply_element(C(5, 5), E.FIRE, C(5, 8), false)
	check("Герой на луже от взрыва бочки ранен", m.hp == hp - BattleLogic.STEAM_DAMAGE)


func _shatter() -> void:
	print("--- Ледяные осколки ---")
	var l := fresh(["goblin"]); var g: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	g.cell = C(4, 4); l.tiles[C(4, 4)] = T.ICE
	var hp: int = g.hp
	l._apply_element(C(4, 4), E.FIRE, m.cell)
	check("Огонь на льду: урон осколками", g.hp == hp - BattleLogic.ICE_SHATTER_DAMAGE or not g.is_alive())
	check("Лёд стал лужей", l.tile_at(C(4, 4)) == T.WATER)
	# Глыба
	l = fresh(["goblin"]); g = l.enemies[0]; m = l.heroes[0]
	l._set_object(C(6, 6), O.ICE_BLOCK, Vector2i.ZERO)
	g.cell = C(6, 5); m.cell = C(6, 7); hp = g.hp; var mhp: int = m.hp
	l._apply_element(C(6, 6), E.FIRE, C(6, 9))
	check("Глыба: сосед-враг ранен", g.hp == hp - BattleLogic.ICE_SHATTER_DAMAGE or not g.is_alive())
	check("Глыба: свой герой от своей карты цел", m.hp == mhp)
	check("Глыба: на месте лужа", l.object_at(C(6, 6)) == O.NONE and l.tile_at(C(6, 6)) == T.WATER)
	# Самотаяние без взрыва
	l = fresh(["goblin"]); g = l.enemies[0]
	l._set_object(C(6, 6), O.ICE_BLOCK, Vector2i.ZERO); l.obj_timers[C(6, 6)] = 1
	g.cell = C(6, 5); hp = g.hp
	l._tick_objects()
	check("Глыба тает сама: без осколков", g.hp == hp and l.tile_at(C(6, 6)) == T.WATER)


func _freeze() -> void:
	print("--- Заморозка ---")
	var l := fresh(["goblin", "ogre"]); var g: BattleUnit = l.enemies[0]; var o: BattleUnit = l.enemies[1]; var m: BattleUnit = l.heroes[0]
	g.cell = C(3, 3); l.tiles[C(3, 3)] = T.WATER
	o.cell = C(5, 3); l.tiles[C(5, 3)] = T.WATER
	l._apply_element(C(3, 3), E.ICE, m.cell)
	l._apply_element(C(5, 3), E.ICE, m.cell)
	check("Лёд на луже: клетка стала льдом", l.tile_at(C(3, 3)) == T.ICE)
	check("Гоблин вмёрз на 1 ход", g.entangled == 1)
	check("Огр не вмерзает", o.entangled == 0)
	l = fresh(["goblin"]); m = l.heroes[0]
	m.cell = C(4, 4); l.tiles[C(4, 4)] = T.WATER
	l._apply_element(C(4, 4), E.ICE, C(4, 8))
	check("Герой от своего льда не вмерзает", m.entangled == 0)
	l.tiles[C(4, 4)] = T.WATER
	l._apply_element(C(4, 4), E.ICE, C(4, 8), false)
	check("От чужого льда герой вмерзает", m.entangled == 1)


func _lava() -> void:
	print("--- Лава ---")
	var l := fresh(["goblin"])
	var m: BattleUnit = l.heroes[0]; var g: BattleUnit = l.enemies[0]
	var c := C(5, 5)
	l.objects[c] = O.BOG
	l._apply_element(c, E.FIRE, m.cell)
	check("Огонь на трясине → лава", l.object_at(c) == O.LAVA)
	check("Лава — стена", l.is_blocked(c))
	# Планки и мостки не плавятся
	l.objects[C(6, 5)] = O.PLANKS; l.objects[C(7, 5)] = O.BRIDGE
	l._apply_element(C(6, 5), E.FIRE, m.cell); l._apply_element(C(7, 5), E.FIRE, m.cell)
	check("Мостки не плавятся", l.object_at(C(6, 5)) == O.PLANKS and l.object_at(C(7, 5)) == O.BRIDGE)
	# Толчок в лаву
	g.cell = c - UP_LEFT; var hp: int = g.hp
	l._push(g, UP_LEFT, 2)
	check("Толкнули в лаву: %d урона, стоит на краю" % BattleLogic.LAVA_DAMAGE, g.cell == c - UP_LEFT and g.hp == hp - BattleLogic.LAVA_DAMAGE)
	# Лава остывает в трясину через LAVA_TURNS раундов
	l.enemies[0].cell = C(11, 0)
	for i in BattleLogic.LAVA_TURNS:
		l.end_turn()
	check("Через %d раунда лава снова трясина" % BattleLogic.LAVA_TURNS, l.object_at(c) == O.BOG)
	# Взрыв бочки рядом с трясиной
	l = fresh(["goblin"]); l.objects[C(5, 5)] = O.BARREL; l.objects[C(5, 4)] = O.BOG
	l._explode_barrel(C(5, 5))
	check("Взрыв бочки: соседняя трясина — лава", l.object_at(C(5, 4)) == O.LAVA)
	# Стоящий в лаве получает урон в конце раунда
	l = fresh(["goblin"]); g = l.enemies[0]
	g.cell = C(5, 5); l.objects[C(5, 5)] = O.BOG
	l._apply_element(C(5, 5), E.FIRE, l.heroes[0].cell)
	g.entangled = 5   # не уйдёт с места
	hp = g.hp
	l.end_turn()
	check("Стоящий в лаве: урон в конце раунда", g.hp <= hp - BattleLogic.LAVA_DAMAGE)


func _crust() -> void:
	print("--- Корка ---")
	var l := fresh(["goblin"])
	var m: BattleUnit = l.heroes[0]; var g: BattleUnit = l.enemies[0]
	# Корка на 3-м шаге от мага, клетка за ней — на 4-м. В сотах одну клетку можно
	# обойти за лишний шаг, так что обход занял бы 5 шагов — больше, чем есть.
	var c := L(6)
	l.objects[c] = O.LAVA; l.obj_timers[c] = BattleLogic.LAVA_TURNS
	l._apply_element(c, E.WATER, m.cell)
	check("Вода на лаве → корка", l.object_at(c) == O.CRUST)
	check("Корка проходима", not l.is_blocked(c))
	m.moves_left = 4
	var targets := l.get_move_targets(m)
	check("На корку можно встать", targets.has(c))
	check("Дальше корки не пройти", not targets.has(L(5)))
	l.move_hero(m, c)
	check("На корке шаги кончаются", m.moves_left == 0)
	# Корка исчезает, под ней сухая земля
	g.cell = C(11, 0)
	for i in BattleLogic.CRUST_TURNS:
		l.end_turn()
	check("Через %d раунда корка исчезла, трясины нет" % BattleLogic.CRUST_TURNS, l.object_at(c) == O.NONE)
	# Лёд на лаве, юнит внутри — опутан на 2 хода
	l = fresh(["goblin"]); g = l.enemies[0]
	g.cell = C(4, 4); l.objects[C(4, 4)] = O.LAVA
	l._apply_element(C(4, 4), E.ICE, l.heroes[0].cell)
	check("Стоявший в лаве опутан на 2 хода", g.entangled == 2 and l.object_at(C(4, 4)) == O.CRUST)
	# Толкнутый останавливается на корке
	l = fresh(["goblin"]); g = l.enemies[0]
	g.cell = C(4, 8); l.objects[C(4, 8) + UP_LEFT * 2] = O.CRUST
	l._push(g, UP_LEFT, 4)
	check("Толкнутый встал на корке", g.cell == C(4, 8) + UP_LEFT * 2)


func _wind() -> void:
	print("--- Ветер раздувает огонь ---")
	var l := fresh(["goblin"]); var m: BattleUnit = l.heroes[0]
	m.mana = 10
	var hand: Array[CardData] = [load("res://resources/cards/gust.tres")]
	m.hand = hand
	l.tiles[L(7)] = T.FIRE; l.fire_timers[L(7)] = 3
	l.objects[L(5)] = O.BOG
	l.enemies[0].cell = C(11, 0)
	l.play_card(m, 0, L(6))
	check("Ветер: огонь перекинулся на следующую клетку", l.tile_at(L(6)) == T.FIRE)
	check("Ветер: дальше одной клетки не бежит", l.object_at(L(5)) == O.BOG)
