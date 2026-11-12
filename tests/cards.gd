extends SceneTree
# Проверка всех карт наборов: каждая карта делает то, что написано.
# Запуск: godot --headless --path . -s tests/cards.gd

var fails := 0
var run
const O := BattleLogic.Obj
const T := BattleLogic.Tile


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func card(id: String) -> CardData:
	return load("res://resources/cards/%s.tres" % id)


# Чистое поле: маг на (2,9), рыцарь на (8,9), враги вдали в верхнем ряду
func fresh(enemy_ids: Array) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = Vector2i(2, 9); l.heroes[1].cell = Vector2i(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = Vector2i(i, 0)
	for h in l.heroes:
		h.mana = 10; h.moves_left = 3
	return l


func give(h: BattleUnit, ids: Array) -> void:
	var hand: Array[CardData] = []
	for id in ids: hand.append(card(id))
	h.hand = hand


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(7)
	_storm()
	_elements()
	_onslaught()
	_warden()
	_pools()
	_hand_draw()
	_discard()
	_keep()
	_diagonal()
	_wet()
	_runes()
	_trap()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _storm() -> void:
	print("--- Буря Раскола ---")
	var l := fresh(["ogre"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = Vector2i(2, 6)
	give(m, ["m_spark", "m_spark"])
	var hp: int = e.hp
	l.play_card(m, 0, e.cell)
	check("Искра: 2 урона и +1 заряд", e.hp == hp - 2 and m.charge == 1)
	# Молния в луже: каждый, кто в луже, получает урон карты + WATER_SHOCK_BONUS; на суше — обычный
	l = fresh(["goblin", "goblin"]); m = l.heroes[0]
	l.enemies[0].cell = Vector2i(2, 6); l.enemies[1].cell = Vector2i(3, 6)
	l.tiles[Vector2i(2, 6)] = T.WATER; l.tiles[Vector2i(3, 6)] = T.WATER
	give(m, ["m_spark"]); hp = l.enemies[0].hp
	l.play_card(m, 0, Vector2i(2, 6))
	check("Искра по луже: каждому в луже 2 + бонус воды", l.enemies[0].hp == hp - 2 - BattleLogic.WATER_SHOCK_BONUS
			and l.enemies[1].hp == hp - 2 - BattleLogic.WATER_SHOCK_BONUS)
	l = fresh(["goblin", "goblin"]); m = l.heroes[0]
	l.enemies[0].cell = Vector2i(2, 6); l.enemies[1].cell = Vector2i(6, 6)
	l.tiles[Vector2i(6, 6)] = T.WATER
	give(m, ["m_spark"])
	l.play_card(m, 0, Vector2i(2, 6))
	check("Искра по суше: обычные 2, лужа в стороне не задета", l.enemies[0].hp == hp - 2 and l.enemies[1].hp == hp)
	# Копьё бури сквозь дерево, дерево цело
	l = fresh(["ogre"]); m = l.heroes[0]; e = l.enemies[0]
	e.cell = Vector2i(2, 4); l.objects[Vector2i(2, 7)] = O.TREE; l.objects[Vector2i(2, 6)] = O.REEDS
	give(m, ["m_storm_spear"]); hp = e.hp
	check("Копьё бури: цель за деревом доступна", l.get_card_targets(m, 0).has(Vector2i(2, 4)))
	l.play_card(m, 0, Vector2i(2, 8))
	check("Копьё бури: 4 урона сквозь дерево и камыш", e.hp == hp - 4)
	check("Копьё бури: дерево и камыш целы", l.object_at(Vector2i(2, 7)) == O.TREE and l.object_at(Vector2i(2, 6)) == O.REEDS)
	# Сосредоточение: +2 заряда и скидка
	l = fresh(["goblin"]); m = l.heroes[0]
	give(m, ["m_focus", "fireball"]); m.mana = 3
	l.play_card(m, 0, m.cell)
	check("Сосредоточение: +2 заряда", m.charge == 2)
	check("Сосредоточение: огненный шар стоит 1", l.card_cost(m, 0) == 1)
	l.play_card(m, 0, Vector2i(2, 5))
	check("Сосредоточение: потрачено 2 маны всего", m.mana == 1 and m.discount == 0)
	# Цепная молния
	l = fresh(["ogre", "ogre", "ogre", "ogre"]); m = l.heroes[0]
	var es: Array[BattleUnit] = l.enemies
	es[0].cell = Vector2i(2, 6); es[1].cell = Vector2i(3, 5); es[2].cell = Vector2i(5, 5); es[3].cell = Vector2i(11, 0)
	give(m, ["m_chain"]); hp = es[0].hp
	l.play_card(m, 0, es[0].cell)
	check("Цепная молния: 5/4/3 по цепочке", es[0].hp == hp - 5 and es[1].hp == hp - 4 and es[2].hp == hp - 3)
	check("Цепная молния: дальний не задет", es[3].hp == hp)
	# Шаровая молния тратит заряд
	l = fresh(["ogre"]); m = l.heroes[0]; e = l.enemies[0]; e.cell = Vector2i(2, 6)
	m.charge = 3; give(m, ["m_ball_lightning"]); hp = e.hp
	l.play_card(m, 0, e.cell)
	check("Шаровая молния: 3+3 урона, заряд 0", e.hp == hp - 6 and m.charge == 0)
	# Разлом сквозь блок
	l = fresh(["ogre"]); m = l.heroes[0]; e = l.enemies[0]; e.cell = Vector2i(2, 6); e.block = 10
	m.charge = 2; give(m, ["m_rift"]); hp = e.hp
	l.play_card(m, 0, e.cell)
	check("Разлом: 6+6 урона сквозь блок", e.hp == hp - 12 and e.block == 10)
	# Перегрузка
	l = fresh(["goblin"]); m = l.heroes[0]; m.charge = 4
	give(m, ["m_overload"]); var mhp: int = m.hp
	l.play_card(m, 0, m.cell)
	check("Перегрузка: заряд удвоен", m.charge == 8 and m.overloaded)
	l.end_turn()
	check("Перегрузка: не потратил — 8 урона магу", m.hp <= mhp - 8 and m.charge == 0)
	m.charge = 6; give(m, ["m_overload"])
	l.play_card(m, 0, m.cell)
	check("Перегрузка: предел 10", m.charge == 10)


func _elements() -> void:
	print("--- Повелитель стихий ---")
	var l := fresh(["goblin"]); var m: BattleUnit = l.heroes[0]
	give(m, ["m_ice_wall"])
	l.play_card(m, 0, Vector2i(2, 6))
	var wall: Array[Vector2i] = [Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6)]
	var ok := true
	for c in wall: ok = ok and l.object_at(c) == O.ICE_BLOCK
	check("Ледяная стена: 3 глыбы поперёк", ok)
	check("Ледяная стена: преграда", l.is_blocked(Vector2i(2, 6)))
	l._apply_element(Vector2i(1, 6), CardData.Element.FIRE, m.cell)
	check("Ледяная стена: огонь топит глыбу в лужу", l.object_at(Vector2i(1, 6)) == O.NONE and l.tile_at(Vector2i(1, 6)) == T.WATER)
	l.enemies[0].cell = Vector2i(11, 0)
	for i in 3:
		l.end_turn()
	check("Ледяная стена: тает через 3 раунда", l.object_at(Vector2i(2, 6)) == O.NONE)
	# Разлив
	l = fresh(["goblin"]); m = l.heroes[0]
	l.tiles[Vector2i(3, 5)] = T.WATER; l.tiles[Vector2i(2, 5)] = T.FIRE; l.fire_timers[Vector2i(2, 5)] = 3
	give(m, ["m_flood"])
	l.play_card(m, 0, Vector2i(2, 5))
	check("Разлив: лужи вокруг", l.tile_at(Vector2i(1, 4)) == T.WATER)
	check("Разлив: старая лужа → трясина", l.object_at(Vector2i(3, 5)) == O.BOG)
	check("Разлив: огонь потушен", l.tile_at(Vector2i(2, 5)) == T.NONE)
	# Осушение
	l = fresh(["goblin"]); m = l.heroes[0]
	l.objects[Vector2i(2, 6)] = O.BOG
	give(m, ["m_drain", "m_drain"])
	check("Осушение: на пустую землю нельзя", not l.get_card_targets(m, 0).has(Vector2i(2, 5)))
	l.play_card(m, 0, Vector2i(2, 6))
	check("Осушение: трясина стала землёй", l.object_at(Vector2i(2, 6)) == O.NONE)
	l.tiles[l.heroes[1].cell] = T.WATER; l.heroes[1].cell = Vector2i(4, 9); l.tiles[Vector2i(4, 9)] = T.WATER
	l.play_card(m, 0, Vector2i(4, 9))
	check("Осушение: союзник в луже получил 4 блока", l.heroes[1].block == 4 and l.tile_at(Vector2i(4, 9)) == T.NONE)
	# Поросль
	l = fresh(["goblin"]); m = l.heroes[0]
	give(m, ["m_overgrowth"])
	l.play_card(m, 0, Vector2i(2, 6))
	check("Поросль: камыш крестом", l.object_at(Vector2i(2, 6)) == O.REEDS and l.object_at(Vector2i(1, 6)) == O.REEDS)
	# Перенос бочки и огня
	l = fresh(["goblin"]); m = l.heroes[0]
	l.objects[Vector2i(2, 7)] = O.BARREL; l.tiles[Vector2i(4, 9)] = T.FIRE; l.fire_timers[Vector2i(4, 9)] = 2
	give(m, ["m_transfer", "m_transfer"])
	l.play_card(m, 0, Vector2i(2, 7))
	check("Перенос: бочка сдвинута от мага", l.object_at(Vector2i(2, 6)) == O.BARREL and l.object_at(Vector2i(2, 7)) == O.NONE)
	l.play_card(m, 0, Vector2i(4, 9))
	check("Перенос: огонь сдвинут", l.tile_at(Vector2i(5, 9)) == T.FIRE and l.tile_at(Vector2i(4, 9)) == T.NONE)
	# Обмен
	l = fresh(["goblin"]); m = l.heroes[0]; var k: BattleUnit = l.heroes[1]; k.cell = Vector2i(5, 9)
	give(m, ["m_swap"])
	check("Обмен: себя выбрать нельзя", not l.get_card_targets(m, 0).has(m.cell))
	l.play_card(m, 0, k.cell)
	check("Обмен: поменялись местами", m.cell == Vector2i(5, 9) and k.cell == Vector2i(2, 9))
	# Пасть топей
	l = fresh(["goblin"]); m = l.heroes[0]; var g: BattleUnit = l.enemies[0]; g.cell = Vector2i(2, 5)
	give(m, ["m_bog_maw"])
	l.play_card(m, 0, Vector2i(2, 5))
	check("Пасть топей: вокруг трясина", l.object_at(Vector2i(1, 4)) == O.BOG and l.object_at(Vector2i(3, 6)) == O.BOG)
	check("Пасть топей: враг опутан", g.entangled == 1)
	var before: Vector2i = g.cell
	l.end_turn()
	check("Пасть топей: опутанный враг не сдвинулся", g.cell == before and g.entangled == 0)
	l.end_turn()
	check("Пасть топей: трясина ушла через 2 раунда", l.object_at(Vector2i(1, 4)) == O.NONE)


func _onslaught() -> void:
	print("--- Натиск ---")
	var l := fresh(["ogre"]); var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	give(k, ["k_runup", "k_spin"])
	l.play_card(k, 0, k.cell)
	check("Разбег: +2 шага, +2 натиска", k.moves_left == 5 and k.momentum == 2)
	l.move_hero(k, Vector2i(8, 6))
	check("Натиск копится от шагов (до 5)", k.momentum == 5)
	e.cell = Vector2i(8, 5); var hp: int = e.hp
	l.play_card(k, 0, e.cell)
	check("Удар с разворота: 4+5 урона, натиск сгорел", e.hp == hp - 9 and k.momentum == 0)
	# Добивание
	l = fresh(["ogre", "goblin"]); k = l.heroes[1]
	var o: BattleUnit = l.enemies[0]; var g: BattleUnit = l.enemies[1]
	o.cell = Vector2i(8, 8); g.cell = Vector2i(9, 9); g.hp = 5
	give(k, ["k_execute", "k_execute"]); hp = o.hp
	l.play_card(k, 0, o.cell)
	check("Добивание: по здоровому 5", o.hp == hp - 5)
	o.hp = 30
	l.play_card(k, 0, o.cell)
	check("Добивание: по раненому 12", o.hp == 18)
	# Сквозной таран
	l = fresh(["goblin", "goblin"]); k = l.heroes[1]
	var a: BattleUnit = l.enemies[0]; var b: BattleUnit = l.enemies[1]
	a.cell = Vector2i(8, 7); b.cell = Vector2i(8, 5); hp = a.hp
	give(k, ["k_pass_ram"])
	l.play_card(k, 0, Vector2i(8, 4))
	check("Сквозной таран: оба ранены", a.hp == hp - 3 and b.hp == hp - 3)
	check("Сквозной таран: враги отлетели вбок", a.cell.x != 8 and b.cell.x != 8)
	check("Сквозной таран: рыцарь пробежал 5", k.cell == Vector2i(8, 4) and k.momentum == 5)
	# Прыжок с ударом
	l = fresh(["goblin", "goblin"]); k = l.heroes[1]
	a = l.enemies[0]; b = l.enemies[1]
	l.objects[Vector2i(8, 8)] = O.BOG; l.objects[Vector2i(8, 7)] = O.TREE
	a.cell = Vector2i(7, 6); b.cell = Vector2i(9, 6); hp = a.hp
	give(k, ["k_leap"])
	check("Прыжок: через трясину и дерево", l.get_card_targets(k, 0).has(Vector2i(8, 6)))
	l.play_card(k, 0, Vector2i(8, 6))
	check("Прыжок: на месте и бьёт крестом", k.cell == Vector2i(8, 6) and a.hp == hp - 4 and b.hp == hp - 4)
	check("Прыжок: натиска не даёт", k.momentum == 0)
	# Вихрь стали
	l = fresh(["goblin", "goblin", "goblin"]); k = l.heroes[1]
	l.enemies[0].cell = Vector2i(7, 8); l.enemies[1].cell = Vector2i(9, 10); l.enemies[2].cell = Vector2i(8, 6)
	give(k, ["k_whirl"]); hp = l.enemies[0].hp; var rage: int = k.rage
	l.play_card(k, 0, k.cell)
	check("Вихрь стали: двое рядом ранены, дальний нет",
		l.enemies[0].hp == hp - 5 and l.enemies[1].hp == hp - 5 and l.enemies[2].hp == hp)
	check("Вихрь стали: +2 ярости", k.rage == rage + 2)
	# Неудержимый
	l = fresh(["goblin", "goblin"]); k = l.heroes[1]
	l.enemies[0].cell = Vector2i(8, 8); l.enemies[0].hp = 3
	give(k, ["k_unstoppable", "k_slash"]); k.mana = 3; k.moves_left = 0
	l.play_card(k, 0, k.cell)
	l.play_card(k, 0, Vector2i(8, 8))
	check("Неудержимый: убийство вернуло ману и шаги", k.mana == 3 - 1 - 1 + 1 and k.moves_left == 2)


func _warden() -> void:
	print("--- Страж топей ---")
	var l := fresh(["goblin"]); var k: BattleUnit = l.heroes[1]; var m: BattleUnit = l.heroes[0]
	var g: BattleUnit = l.enemies[0]
	give(k, ["k_stakes"])
	l.play_card(k, 0, Vector2i(8, 8))
	check("Вбить колья: частокол поставлен", l.object_at(Vector2i(8, 8)) == O.STAKES and l.is_blocked(Vector2i(8, 8)))
	g.cell = Vector2i(8, 6); m.cell = Vector2i(8, 4)
	var hp: int = g.hp
	l._push(g, Vector2i(0, 1), 3)
	check("Колья: врезался — урон кольев", g.hp == hp - BattleLogic.STAKES_BUMP_DAMAGE and g.cell == Vector2i(8, 7))
	l._apply_element(Vector2i(8, 8), CardData.Element.FIRE, k.cell)
	check("Колья горят", l.object_at(Vector2i(8, 8)) == O.NONE and l.tile_at(Vector2i(8, 8)) == T.FIRE)
	# Настил
	l = fresh(["goblin"]); k = l.heroes[1]
	l.objects[Vector2i(8, 8)] = O.BOG
	give(k, ["k_bridge"])
	var bt: Array[Vector2i] = l.get_card_targets(k, 0)
	check("Настил: только на трясину", bt.size() == 1 and bt[0] == Vector2i(8, 8))
	l.play_card(k, 0, Vector2i(8, 8))
	l.move_hero(k, Vector2i(8, 7))
	check("Настил: прошли, не сломался", l.object_at(Vector2i(8, 8)) == O.BRIDGE and k.cell == Vector2i(8, 7))
	# Свалить дерево
	l = fresh(["goblin", "goblin"]); k = l.heroes[1]
	l.objects[Vector2i(8, 8)] = O.TREE
	l.enemies[0].cell = Vector2i(9, 8); l.enemies[1].cell = Vector2i(11, 8); hp = l.enemies[0].hp
	give(k, ["k_fell"])
	var targets: Array[Vector2i] = l.get_card_targets(k, 0)
	check("Свалить дерево: свою клетку выбрать нельзя", not targets.has(k.cell) and targets.has(Vector2i(9, 8)))
	l.play_card(k, 0, Vector2i(9, 8))
	check("Свалить дерево: упало вправо, оба ранены", l.object_at(Vector2i(8, 8)) == O.NONE
		and l.enemies[0].hp == hp - BattleLogic.TREE_DAMAGE and l.enemies[1].hp == hp - BattleLogic.TREE_DAMAGE)
	check("Свалить дерево: выжившие сбиты с ног на 1 ход", l.enemies[0].entangled == 1 and l.enemies[1].entangled == 1)
	l = fresh(["ogre", "mossy_treant"]); k = l.heroes[1]
	l.objects[Vector2i(8, 8)] = O.TREE
	l.enemies[0].cell = Vector2i(9, 8); l.enemies[1].cell = Vector2i(10, 8)
	l._fell_tree(Vector2i(8, 8), Vector2i(1, 0))
	check("Дерево не сбивает с ног босса и корягача", l.enemies[0].entangled == 0 and l.enemies[1].entangled == 0)
	# Пинок бочки
	l = fresh(["goblin"]); k = l.heroes[1]; g = l.enemies[0]
	l.objects[Vector2i(8, 8)] = O.BARREL; g.cell = Vector2i(8, 5); hp = g.hp
	give(k, ["k_kick_barrel", "k_kick_barrel"])
	l.play_card(k, 0, Vector2i(8, 8))
	check("Пинок бочки: докатилась до врага и взорвалась", l.object_at(Vector2i(8, 6)) == O.NONE and g.hp == hp - BattleLogic.BARREL_DAMAGE)
	l.objects[Vector2i(7, 9)] = O.BARREL; g.cell = Vector2i(0, 0)
	l.play_card(k, 0, Vector2i(7, 9))
	check("Пинок бочки: в пустоту — катится 4 и стоит", l.object_at(Vector2i(3, 9)) == O.BARREL)
	# Держать строй
	l = fresh(["goblin"]); k = l.heroes[1]; k.moves_left = 2
	give(k, ["k_hold"])
	l.play_card(k, 0, k.cell)
	check("Держать строй: 4 + 3×2 блока", k.block == 10)
	# Застава
	l = fresh(["goblin"]); k = l.heroes[1]; g = l.enemies[0]; g.cell = Vector2i(8, 6); hp = g.hp
	l.heroes[0].cell = Vector2i(0, 11)
	give(k, ["k_outpost"])
	l.play_card(k, 0, k.cell)
	var khp: int = k.hp
	l.end_turn()
	check("Застава: подошедший гоблин получил 4", g.hp == hp - 4)
	l = fresh(["goblin", "goblin"]); k = l.heroes[1]; g = l.enemies[0]; g.cell = Vector2i(8, 6); g.hp = 3
	l.enemies[1].cell = Vector2i(0, 0)
	l.heroes[0].cell = Vector2i(0, 11)
	give(k, ["k_outpost"]); khp = k.hp
	l.play_card(k, 0, k.cell)
	l.end_turn()
	check("Застава: погибший на подходе не ударил", not g.is_alive() and k.hp == khp)
	check("Застава: снимается в новый ход", not k.outpost)
	# Колокол Стражи
	l = fresh(["goblin", "goblin", "goblin"]); k = l.heroes[1]
	l.enemies[0].cell = Vector2i(8, 8); l.enemies[1].cell = Vector2i(8, 7); l.enemies[2].cell = Vector2i(2, 2)
	give(k, ["k_bell"])
	l.play_card(k, 0, k.cell)
	check("Колокол: оба ближних отлетели", l.enemies[0].cell == Vector2i(8, 7) and l.enemies[1].cell == Vector2i(8, 6))
	check("Колокол: дальний на месте", l.enemies[2].cell == Vector2i(2, 2))
	check("Колокол: провокация и 6 блока", k.taunt and k.block == 6)


func _pools() -> void:
	print("--- Наборы и награды ---")
	var mage: HeroData = load("res://resources/heroes/mage.tres")
	var knight: HeroData = load("res://resources/heroes/knight.tres")
	check("У мага в пуле 25 карт", mage.card_pool.size() == 25)
	check("У рыцаря в пуле 33 карты", knight.card_pool.size() == 33)
	var rh: RunHero = run.party[0]
	for i in 4: rh.deck.append(card("m_spark"))
	var storm := 0; var total := 0
	for i in 300:
		for c in run.roll_cards(rh, 3):
			total += 1
			if c.card_set == "storm": storm += 1
	check("Собираешь «Бурю» — она выпадает чаще (%d из %d)" % [storm, total], float(storm) / total > 0.4)


func _hand_draw() -> void:
	print("--- Рука и добор ---")
	var l := fresh(["ogre"]); var m: BattleUnit = l.heroes[0]
	l.enemies[0].cell = Vector2i(11, 0)
	check("Лимит руки: %d" % BattleLogic.MAX_HAND, BattleLogic.MAX_HAND == 7)
	check("В начале боя рука — 5 карт", m.hand.size() == BattleLogic.HAND_SIZE)
	var mode: int = BattleLogic.DRAW_MODE
	var kept: Array[CardData] = m.hand.duplicate()
	var before: int = m.hand.size()
	l.end_turn()
	if mode == BattleLogic.DrawMode.KEEP_2:
		check("KEEP_2: без отметок — новая рука из 5 карт", m.hand.size() == BattleLogic.HAND_SIZE)
	elif mode == BattleLogic.DrawMode.DISCARD_ALL:
		check("DISCARD_ALL: новая рука из 5 карт", m.hand.size() == BattleLogic.HAND_SIZE)
	else:
		var want: int = 0
		match mode:
			BattleLogic.DrawMode.REFILL_5: want = maxi(1, BattleLogic.HAND_SIZE - before)
			BattleLogic.DrawMode.PLUS_3: want = 3
			BattleLogic.DrawMode.PLUS_2: want = 2
		want = mini(before + want, BattleLogic.MAX_HAND)
		check("Рука после конца хода: %d (ждали %d)" % [m.hand.size(), want], m.hand.size() == want)
		var same := true
		for c in kept: same = same and m.hand.has(c)
		check("Карты прошлого хода остались в руке", same)
	# Пустая рука в REFILL_5 пополняется до 5
	if mode == BattleLogic.DrawMode.REFILL_5:
		m.hand.clear()
		l.end_turn()
		check("REFILL_5: пустая рука → 5 карт", m.hand.size() == BattleLogic.HAND_SIZE)
		m.hand.clear()
		for i in 5: m.hand.append(card("strike"))
		l.end_turn()
		check("REFILL_5: полная рука → +1 карта", m.hand.size() == 6)
	# Лимит и павший герой
	for i in 6:
		l.end_turn()
	check("Рука не больше лимита", m.hand.size() <= BattleLogic.MAX_HAND)
	var k: BattleUnit = l.heroes[1]
	k.hp = 0
	var kn: int = k.hand.size()
	l.end_turn()
	check("Павший герой карт не берёт", k.hand.size() == kn or k.hand.is_empty())


func _discard() -> void:
	print("--- Сброс карты ---")
	var l := fresh(["ogre"]); var m: BattleUnit = l.heroes[0]
	l.enemies[0].cell = Vector2i(11, 0)
	if BattleLogic.DRAW_MODE == BattleLogic.DrawMode.DISCARD_ALL or BattleLogic.DRAW_MODE == BattleLogic.DrawMode.KEEP_2:
		check("Сброс всей руки каждый ход: отдельный сброс не нужен", not l.can_discard(m, 0))
		return
	var n: int = m.hand.size(); var pile: int = m.discard_pile.size()
	check("Сбросов за ход: %d" % BattleLogic.DISCARDS_PER_TURN, l.discards_left(m) == BattleLogic.DISCARDS_PER_TURN)
	check("Сброс карты удался", l.discard_card(m, 0))
	check("Карта ушла из руки в сброс", m.hand.size() == n - 1 and m.discard_pile.size() == pile + 1)
	check("Второй сброс в этот ход нельзя", not l.discard_card(m, 0) and m.hand.size() == n - 1)
	check("Неверный номер карты — отказ", not l.can_discard(l.heroes[1], 99))
	l.end_turn()
	check("В новый ход сброс снова доступен", l.discards_left(m) == BattleLogic.DISCARDS_PER_TURN)


func _keep() -> void:
	print("--- Удержание карт (KEEP_2) ---")
	if BattleLogic.DRAW_MODE != BattleLogic.DrawMode.KEEP_2:
		return
	var l := fresh(["ogre"]); var m: BattleUnit = l.heroes[0]
	l.enemies[0].cell = Vector2i(11, 0)
	give(m, ["m_spark", "strike", "wave", "guard", "shove"])
	check("Отметить первую карту", l.toggle_keep(m, 1) and l.is_kept(m, 1))
	check("Отметить вторую карту", l.toggle_keep(m, 3))
	check("Третью отметить нельзя", not l.toggle_keep(m, 4) and not l.is_kept(m, 4))
	check("Снять и вернуть отметку", l.toggle_keep(m, 3) and not l.is_kept(m, 3) and l.toggle_keep(m, 3))
	check("Неверный номер — отказ", not l.toggle_keep(m, 9))
	# Сыграли карту левее — отметки сдвинулись вместе с картами
	l.play_card(m, 0, l.enemies[0].cell if false else Vector2i(2, 8))
	check("После розыгрыша отметки остались на тех же картах",
			l.is_kept(m, 0) and l.is_kept(m, 2) and m.hand[0].id == "strike" and m.hand[2].id == "guard")
	l.end_turn()
	check("После хода в руке удержанные + 5 новых", m.hand.size() == 7)
	check("Удержанные карты на месте", m.hand[0].id == "strike" and m.hand[1].id == "guard")
	check("Отметки сброшены", not l.is_kept(m, 0) and not l.is_kept(m, 1))
	l.toggle_keep(m, 0)
	l.end_turn()
	check("Одна удержанная + 5 новых", m.hand.size() == 6 and m.hand[0].id == "strike")
	# Маленькая колода: сброс замешивается обратно
	m.draw_pile.clear(); m.discard_pile.clear(); m.kept.clear()
	give(m, ["strike", "guard", "wave"])
	l.end_turn()
	check("Колода кончилась — сброс замешан, рука из тех же 3 карт", m.hand.size() == 3)
	var k: BattleUnit = l.heroes[1]
	l.toggle_keep(k, 0)
	k.hp = 0
	l.end_turn()
	check("Павший герой ничего не удерживает", k.hand.is_empty())


func _diagonal() -> void:
	print("--- Удары наискосок ---")
	var l := fresh(["ogre", "goblin"]); var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	e.cell = Vector2i(9, 8)
	give(k, ["k_diag"])
	var t: Array[Vector2i] = l.get_card_targets(k, 0)
	check("Косой выпад: 4 цели наискосок", t.size() == 4 and t.has(Vector2i(9, 8)) and t.has(Vector2i(7, 10))
			and not t.has(Vector2i(8, 8)))
	var hp: int = e.hp
	check("Косой выпад: сосед по прямой — не цель", not l.play_card(k, 0, Vector2i(8, 8)))
	l.play_card(k, 0, e.cell)
	check("Косой выпад: 6 урона", e.hp == hp - 6)
	k.cell = Vector2i(11, 11)
	give(k, ["k_diag"])
	check("Косой выпад у угла поля: одна цель", l.get_card_targets(k, 0).size() == 1)
	# Перекрёстный разряд
	l = fresh(["goblin", "goblin", "goblin"]); var m: BattleUnit = l.heroes[0]
	l.enemies[0].cell = Vector2i(2, 6); l.enemies[1].cell = Vector2i(3, 5); l.enemies[2].cell = Vector2i(3, 6)
	give(m, ["m_cross_bolt"]); hp = l.enemies[0].hp
	var area: Array[Vector2i] = l.get_card_area(m, 0, Vector2i(2, 6))
	check("Перекрёстный разряд: 5 клеток косым крестом", area.size() == 5 and area.has(Vector2i(3, 5))
			and area.has(Vector2i(1, 7)) and not area.has(Vector2i(3, 6)))
	l.play_card(m, 0, Vector2i(2, 6))
	check("Перекрёстный разряд: 4 урона по центру и наискосок, сосед по прямой цел",
			l.enemies[0].hp == hp - 4 and l.enemies[1].hp == hp - 4 and l.enemies[2].hp == hp and m.charge == 1)
	l = fresh(["goblin", "goblin"]); m = l.heroes[0]
	l.enemies[0].cell = Vector2i(2, 6); l.enemies[1].cell = Vector2i(2, 5)
	l.tiles[Vector2i(2, 6)] = T.WATER; l.tiles[Vector2i(2, 5)] = T.WATER
	give(m, ["m_cross_bolt"]); hp = l.enemies[1].hp
	l.play_card(m, 0, Vector2i(2, 6))
	check("Перекрёстный разряд по луже расходится по воде", l.enemies[1].hp == hp - 4 - BattleLogic.WET_SHOCK_BONUS)


func _wet() -> void:
	print("--- Статус «Мокрый» ---")
	var l := fresh(["ogre"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = Vector2i(2, 6)
	give(m, ["wave", "m_spark", "m_spark"])
	l.play_card(m, 0, Vector2i(2, 6))
	check("Волна намочила врага", l.is_wet(e) and e.wet == BattleLogic.WET_TURNS)
	l.tiles.clear()   # лужи убираем: враг мокрый сам по себе
	var hp: int = e.hp
	l.play_card(m, 0, e.cell)
	check("Искра по мокрому вне лужи: 2 + 3", e.hp == hp - 2 - BattleLogic.WET_SHOCK_BONUS)
	e.cell = Vector2i(11, 0)
	l.end_turn()
	check("Через раунд срок «Мокрого» уменьшился", e.wet == BattleLogic.WET_TURNS - 1)
	l.end_turn()
	check("Через два раунда враг высох", e.wet == 0 and not l.is_wet(e))
	# В луже срок не идёт, бонус один
	l = fresh(["ogre"]); m = l.heroes[0]; e = l.enemies[0]
	e.cell = Vector2i(2, 6); l._set_tile(Vector2i(2, 6), T.WATER)
	check("Вода под ногами мочит", e.wet == BattleLogic.WET_TURNS)
	give(m, ["m_spark"]); hp = e.hp
	l.play_card(m, 0, e.cell)
	check("В луже прибавка одна, а не две", e.hp == hp - 2 - BattleLogic.WET_SHOCK_BONUS)
	# Толчок через лужу мочит
	l = fresh(["ogre"]); m = l.heroes[0]; e = l.enemies[0]
	e.cell = Vector2i(2, 8); l.tiles[Vector2i(2, 7)] = T.WATER
	give(m, ["shove"])
	l.play_card(m, 0, e.cell)
	check("Толчок через лужу мочит", e.cell == Vector2i(2, 6) and e.wet == BattleLogic.WET_TURNS)
	# Шаг героя через лужу
	l = fresh(["ogre"]); m = l.heroes[0]
	l.tiles[Vector2i(2, 8)] = T.WATER
	l.move_hero(m, Vector2i(2, 7))
	check("Герой прошёл через лужу — мокрый", m.wet == BattleLogic.WET_TURNS)
	# Огонь сушит
	l = fresh(["ogre"]); m = l.heroes[0]; e = l.enemies[0]
	e.cell = Vector2i(2, 6); e.wet = 2
	give(m, ["fireball"])
	l.play_card(m, 0, e.cell)
	check("Огонь сушит", e.wet == 0)
	# Лёд по мокрому сковывает (обычного врага), «Мокрый» снимается
	l = fresh(["goblin"]); m = l.heroes[0]; e = l.enemies[0]
	e.cell = Vector2i(2, 7); e.wet = 2
	give(m, ["ice_lance"])
	l.play_card(m, 0, Vector2i(2, 8))
	check("Лёд по мокрому: опутан на ход, высох", e.entangled == 1 and e.wet == 0)
	# Всегда мокрые: топляк и жаба
	l = fresh(["drowned_walker", "bloated_toad", "goblin"]); m = l.heroes[0]
	check("Топляк и жаба всегда мокрые, гоблин — нет",
			l.is_wet(l.enemies[0]) and l.is_wet(l.enemies[1]) and not l.is_wet(l.enemies[2]))
	e = l.enemies[0]; e.cell = Vector2i(2, 6)
	give(m, ["m_chain"]); hp = e.hp
	l.enemies[2].cell = Vector2i(2, 5); var ghp: int = l.enemies[2].hp
	l.play_card(m, 0, e.cell)
	check("Цепная молния: прибавка только мокрому", e.hp == hp - 5 - BattleLogic.WET_SHOCK_BONUS
			and l.enemies[2].hp == ghp - 4)
	var pr: Array[Dictionary] = []
	give(m, ["m_spark"])
	pr = l.predict_reactions(m, 0, e.cell)
	check("Подсказка: молния по мокрому помечена", pr.size() == 1 and pr[0]["kind"] == "shock")


func _runes() -> void:
	print("--- Яд и руны на оружие ---")
	var l := fresh(["ogre", "goblin", "goblin"]); var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	e.cell = Vector2i(8, 8)
	give(k, ["k_rune_rot", "k_slash", "k_slash"])
	l.play_card(k, 0, k.cell)
	check("Руна гнили: на клинке, 3 удара", k.rune == "rot" and k.rune_hits == BattleLogic.RUNE_HITS)
	l.play_card(k, 0, e.cell)
	check("Удар с руной гнили отравил, осталось 2 удара", e.poison == BattleLogic.POISON_TURNS and k.rune_hits == 2)
	e.block = 50
	var hp: int = e.hp
	l.play_card(k, 0, e.cell)
	check("Удар в блок тоже тратит руну", k.rune_hits == 1 and e.hp == hp)
	e.cell = Vector2i(11, 0); l.enemies[1].cell = Vector2i(10, 0); l.enemies[2].cell = Vector2i(9, 0)
	l.end_turn()
	e.block = 50; hp = e.hp
	l._tick_statuses()
	check("Яд идёт мимо блока: 2 урона", e.hp == hp - BattleLogic.POISON_DAMAGE and e.block == 50)
	check("Срок яда уменьшается", e.poison == BattleLogic.POISON_TURNS - 2)
	l._set_poison(e, BattleLogic.POISON_TURNS)
	check("Повторный яд обновляет срок, не складывается", e.poison == BattleLogic.POISON_TURNS)
	var hz: Dictionary = l.forecast_hazards()
	check("Прогноз показывает урон ядом", hz["poison"].get(e.id, 0) == BattleLogic.POISON_DAMAGE)
	# Смерть от яда: жаба лопается
	l = fresh(["bloated_toad", "goblin"]); e = l.enemies[0]
	e.cell = Vector2i(5, 5); l.enemies[1].cell = Vector2i(5, 4); e.hp = 1; e.poison = 1
	hp = l.enemies[1].hp
	l._tick_statuses()
	check("Смерть от яда: жаба лопнула и задела соседа", not e.is_alive() and l.enemies[1].hp < hp)
	# Дуга по трём врагам тратит один удар руны
	l = fresh(["ogre", "ogre", "ogre"]); k = l.heroes[1]
	l.enemies[0].cell = Vector2i(7, 8); l.enemies[1].cell = Vector2i(8, 8); l.enemies[2].cell = Vector2i(9, 8)
	give(k, ["k_rune_rot", "k_cleave", "k_rune_fire", "k_shield"])
	l.play_card(k, 0, k.cell)
	l.play_card(k, 0, Vector2i(8, 8))
	check("Дуга: отравлены все трое, потрачен один удар", k.rune_hits == 2 and l.enemies[0].poison > 0
			and l.enemies[1].poison > 0 and l.enemies[2].poison > 0)
	l.play_card(k, 0, k.cell)
	check("Новая руна заменяет старую", k.rune == "fire" and k.rune_hits == BattleLogic.RUNE_HITS)
	l.play_card(k, 0, k.cell)
	check("Карта без урона руну не тратит", k.rune_hits == BattleLogic.RUNE_HITS)
	# Руна огня: огонь там, куда врага оттолкнуло
	l = fresh(["ogre"]); k = l.heroes[1]; e = l.enemies[0]
	e.cell = Vector2i(8, 8)
	give(k, ["k_rune_fire", "k_crush"])
	l.play_card(k, 0, k.cell)
	l.play_card(k, 0, e.cell)
	check("Руна огня: горит клетка, куда враг отлетел", e.cell == Vector2i(8, 5) and l.tile_at(Vector2i(8, 5)) == T.FIRE
			and l.tile_at(Vector2i(8, 8)) != T.FIRE)
	# Руна бури: по мокрому +3, по сухому — нет
	l = fresh(["ogre", "ogre"]); k = l.heroes[1]
	l.enemies[0].cell = Vector2i(8, 8); l.enemies[0].wet = 2; l.enemies[1].cell = Vector2i(9, 9)
	give(k, ["k_rune_storm", "k_slash", "k_slash"])
	l.play_card(k, 0, k.cell)
	hp = l.enemies[0].hp
	l.play_card(k, 0, Vector2i(8, 8))
	check("Руна бури: по мокрому +3", l.enemies[0].hp == hp - 6 - BattleLogic.WET_SHOCK_BONUS)
	hp = l.enemies[1].hp
	l.play_card(k, 0, Vector2i(9, 9))
	check("Руна бури: по сухому обычный урон", l.enemies[1].hp == hp - 6 and k.rune_hits == 1)


func _trap() -> void:
	print("--- Сторожевая руна ---")
	var l := fresh(["goblin", "goblin"]); var k: BattleUnit = l.heroes[1]; var m: BattleUnit = l.heroes[0]
	give(k, ["k_rune_trap", "k_rune_trap"])
	l.objects[Vector2i(8, 8)] = O.BARREL
	var t: Array[Vector2i] = l.get_card_targets(k, 0)
	check("Руну нельзя ставить на занятую клетку", not t.has(Vector2i(8, 8)) and t.has(Vector2i(9, 9)))
	l.play_card(k, 0, Vector2i(9, 9))
	check("Руна стоит на поле, клетка проходима", l.object_at(Vector2i(9, 9)) == O.RUNE and not l.is_blocked(Vector2i(9, 9)))
	k.moves_left = 3
	l.move_hero(k, Vector2i(9, 9))
	check("Герой на руне её не активирует", l.object_at(Vector2i(9, 9)) == O.RUNE)
	# Подрыв «Искрой»: врагам рядом 5 урона, герои целы
	l = fresh(["goblin", "goblin"]); k = l.heroes[1]; m = l.heroes[0]
	k.cell = Vector2i(4, 9)
	l.objects[Vector2i(4, 8)] = O.RUNE
	l.enemies[0].cell = Vector2i(4, 7); l.enemies[1].cell = Vector2i(5, 8)
	var hp: int = l.enemies[0].hp; var khp: int = k.hp
	give(m, ["m_spark"])
	l.play_card(m, 0, Vector2i(4, 8))
	check("Искра подрывает руну: соседним врагам по 5", l.enemies[0].hp == hp - 5 and l.enemies[1].hp == hp - 5
			and l.object_at(Vector2i(4, 8)) == O.NONE)
	check("Взрыв руны героя не ранит", k.hp == khp)
	# Толчок на руну
	l = fresh(["ogre"]); m = l.heroes[0]
	l.enemies[0].cell = Vector2i(2, 8); l.objects[Vector2i(2, 7)] = O.RUNE
	hp = l.enemies[0].hp
	give(m, ["shove"])
	l.play_card(m, 0, Vector2i(2, 8))
	check("Толчок через руну: взрыв, 2 + 5 урона", l.enemies[0].hp == hp - 2 - 5 and l.object_at(Vector2i(2, 7)) == O.NONE)
	# Враг наступил сам: получил урон и пошёл дальше
	l = fresh(["ogre"]); m = l.heroes[0]
	l.heroes[1].cell = Vector2i(11, 11)
	l.enemies[0].cell = Vector2i(2, 5); l.objects[Vector2i(2, 6)] = O.RUNE
	hp = l.enemies[0].hp
	var plan: Array[Dictionary] = l.forecast_enemies()
	var hz: Dictionary = l.forecast_hazards()
	var seen := false
	for fx: Dictionary in hz["effects"]: seen = seen or fx["kind"] == "rune"
	check("Прогноз показывает взрыв руны на пути врага", seen)
	l.end_turn()
	check("Враг прошёл по руне: 5 урона, руна исчезла, он дошёл", l.enemies[0].hp == hp - 5
			and l.object_at(Vector2i(2, 6)) == O.NONE and l.enemies[0].cell != Vector2i(2, 5))
	# Враг погиб на руне и не ударил
	l = fresh(["wolf"]); m = l.heroes[0]
	l.heroes[1].cell = Vector2i(11, 11)
	l.enemies[0].cell = Vector2i(2, 6); l.enemies[0].hp = 3; l.objects[Vector2i(2, 7)] = O.RUNE
	hp = m.hp
	l.end_turn()
	check("Враг погиб на руне посреди пути и не ударил", m.hp == hp and l.won)
	# Удар врага по клетке руны подрывает её
	l = fresh(["goblin"]); m = l.heroes[0]
	l.heroes[1].cell = Vector2i(11, 11)
	l.enemies[0].cell = Vector2i(2, 8); l.objects[Vector2i(2, 9)] = O.RUNE
	hp = l.enemies[0].hp
	l.end_turn()
	check("Удар врага по герою на руне подрывает её", l.object_at(Vector2i(2, 9)) == O.NONE and l.enemies[0].hp == hp - 5)
