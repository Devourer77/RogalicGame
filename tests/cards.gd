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
	check("Колья: врезался — 4 урона", g.hp == hp - 4 and g.cell == Vector2i(8, 7))
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
		and l.enemies[0].hp == hp - 4 and l.enemies[1].hp == hp - 4)
	# Пинок бочки
	l = fresh(["goblin"]); k = l.heroes[1]; g = l.enemies[0]
	l.objects[Vector2i(8, 8)] = O.BARREL; g.cell = Vector2i(8, 5); hp = g.hp
	give(k, ["k_kick_barrel", "k_kick_barrel"])
	l.play_card(k, 0, Vector2i(8, 8))
	check("Пинок бочки: докатилась до врага и взорвалась", l.object_at(Vector2i(8, 6)) == O.NONE and g.hp == hp - 4)
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
	check("У мага в пуле 24 карты", mage.card_pool.size() == 24)
	check("У рыцаря в пуле 28 карт", knight.card_pool.size() == 28)
	var rh: RunHero = run.party[0]
	for i in 4: rh.deck.append(card("m_spark"))
	var storm := 0; var total := 0
	for i in 300:
		for c in run.roll_cards(rh, 3):
			total += 1
			if c.card_set == "storm": storm += 1
	check("Собираешь «Бурю» — она выпадает чаще (%d из %d)" % [storm, total], float(storm) / total > 0.4)
