extends SceneTree

# Проверка этапа 1 редизайна боя: общая мана, перегрев, контекст хода, сброс «в ноги».
# Запуск: godot --headless --path . -s tests/redesign.gd

var fails := 0
var run


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func fresh() -> BattleLogic:
	var list: Array[EnemyData] = []
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(7)

	var l := fresh()
	var mage: BattleUnit = l.heroes[0]
	var knight: BattleUnit = l.heroes[1]

	# Мана у каждого героя своя
	var per_turn: int = mage.hero_data.mana_per_turn
	check("мана своя: каждый начинает с mana_per_turn", mage.mana == per_turn and knight.mana == knight.hero_data.mana_per_turn)
	mage.mana -= 1
	check("трата Мага не трогает ману Рыцаря", knight.mana == knight.hero_data.mana_per_turn)

	# Перегрев: можно уйти до −2, глубже нельзя
	mage.mana = 0
	var cheap: int = -1
	for i in mage.hand.size():
		if l.card_cost(mage, i) == 1:
			cheap = i
	if cheap >= 0:
		check("карта за 1 при мане 0 играется (перегрев)", l.can_play(mage, cheap))
	mage.mana = -BattleLogic.MAX_OVERHEAT
	var any_playable: bool = false
	for i in mage.hand.size():
		if l.can_play(mage, i) and l.card_cost(mage, i) > 0:
			any_playable = true
	check("на предельном минусе платные карты не играются", not any_playable)

	# Конец хода: урона нет, штраф к мане только у перегретого
	var hp_before: int = mage.hp
	mage.block = 0
	mage.mana = -2
	knight.mana = 1
	l.end_turn()
	check("перегрев не наносит урона", mage.hp == hp_before)
	check("после 2 минусов у Мага маны на ход меньше", mage.mana == per_turn - 1)
	check("у Рыцаря без перегрева мана полная", knight.mana == knight.hero_data.mana_per_turn)

	# Перегрев 1 — без штрафа
	mage.mana = -1
	l.end_turn()
	check("перегрев 1 штрафа не даёт", mage.mana == per_turn)

	# Контекст хода
	var l2 := fresh()
	var m2: BattleUnit = l2.heroes[0]
	m2.moves_left = 5
	var t: Dictionary = l2.get_move_targets(m2)
	var far: Vector2i = C(2, 7)
	if t.has(far):
		l2.move_hero(m2, far)
		check("ctx считает пройденные клетки", l2.ctx.moved("mage") == HexMath.distance(C(2, 9), far))
	else:
		check("клетка для хода недоступна — проверь вручную", false)

	# Сброс в ноги
	var l3 := fresh()
	var m3: BattleUnit = l3.heroes[0]
	var played: Array = []
	l3.card_played.connect(func(_c: BattleUnit, _card: CardData, scrap: bool) -> void: played.append(scrap))
	var moves0: int = m3.moves_left
	var mana0: int = m3.mana
	var hand0: int = m3.hand.size()
	check("scrap_card успешен", l3.scrap_card(m3, 0))
	check("«в ноги» не тратит ману", m3.mana == mana0)
	check("«в ноги» даёт шаг", m3.moves_left == moves0 + 1)
	check("карта ушла из руки", m3.hand.size() == hand0 - 1)
	check("сигнал card_played с is_scrap=true", played == [true])
	check("scrap не считается розыгрышем", l3.ctx.played("mage") == 0)

	# Клон не трогает оригинал
	var cl: BattleLogic = l3.clone()
	cl.heroes[0].mana -= 2
	check("клон не трогает оригинал", l3.heroes[0].mana == mana0)

	_tiles()
	_passives()

	print("--- провалов: %d ---" % fails)
	quit(1 if fails > 0 else 0)


# Трясина (Swamp) и ядовитый газ (GAS)
func _tiles() -> void:
	var l := fresh()
	var m: BattleUnit = l.heroes[0]
	m.cell = C(2, 9)
	m.moves_left = 4
	var swamp: Vector2i = m.cell + HexMath.DIRS[4]   # соседняя клетка
	l.tiles[swamp] = BattleLogic.Tile.SWAMP
	l.move_hero(m, swamp)
	check("Трясина: вход отнял лишний шаг (4 − 1 путь − 1 увяз)", m.moves_left == 2)

	# Молния по трясине идёт по цепочке
	var l2 := fresh()
	l2.tiles[C(5, 5)] = BattleLogic.Tile.SWAMP
	l2.tiles[C(5, 5) + HexMath.DIRS[0]] = BattleLogic.Tile.SWAMP
	var area: Array[Vector2i] = [C(5, 5)]
	var spread: Array[Vector2i] = l2._spread_through_water(area)
	check("Молния в трясине бьёт по всей цепочке смежных клеток", spread.has(C(5, 5) + HexMath.DIRS[0]))

	# Газ: вход даёт урон и яд
	var l3 := fresh()
	var h3: BattleUnit = l3.heroes[1]
	h3.cell = C(8, 9)
	h3.moves_left = 3
	var gas: Vector2i = h3.cell + HexMath.DIRS[4]
	l3.tiles[gas] = BattleLogic.Tile.GAS
	var hp0: int = h3.hp
	l3.move_hero(h3, gas)
	check("Газ: вход ранит на %d" % BattleLogic.GAS_DAMAGE, h3.hp == hp0 - BattleLogic.GAS_DAMAGE)
	check("Газ: вход отравляет", h3.poison >= BattleLogic.GAS_POISON)

	# Огонь взрывает газ и убирает его
	var l4 := fresh()
	l4.tiles[C(5, 5)] = BattleLogic.Tile.GAS
	l4._set_tile(C(5, 5), BattleLogic.Tile.FIRE)
	check("Огонь по газу: газ исчез, огня на клетке нет", l4.tile_at(C(5, 5)) == BattleLogic.Tile.NONE)


func enemy(id: String) -> EnemyData:
	return load("res://resources/enemies/%s.tres" % id)


func _passives() -> void:
	# Жаба: 3 удара Атакой — взрыв
	var l := fresh()
	var k: BattleUnit = l.heroes[1]
	k.cell = C(5, 9)
	var list: Array[EnemyData] = [enemy("bloated_toad")]
	var toad: BattleUnit = l._new_unit("Жаба")
	toad.data = list[0]
	toad.hp = 100; toad.max_hp = 100
	toad.cell = k.cell + HexMath.DIRS[4]
	l.enemies.append(toad)
	l._cur_card = load("res://resources/cards/k_slash.tres")
	l._cur_attack = true
	l._damage(toad, 1)
	l._damage(toad, 1)
	check("Жаба: 2 удара — 2 стака", toad.inflation == 2)
	var hp0: int = k.hp
	k.block = 0
	l._damage(toad, 1)
	check("Жаба: на 3 стаках взорвалась", not toad.is_alive())
	check("Жаба: взрыв ранил соседнего героя на 12 + яд", k.hp <= hp0 - BattleLogic.INFLATION_DAMAGE and k.poison > 0)

	# Шаман: Заклинание Мага лечит врагов
	var l2 := fresh()
	var sh: BattleUnit = l2._new_unit("Шаман")
	sh.data = enemy("goblin_shaman")
	sh.hp = 3; sh.max_hp = 20
	sh.cell = C(5, 2)
	l2.enemies.append(sh)
	var m2: BattleUnit = l2.heroes[0]
	m2.mana = 10
	m2.hand = [load("res://resources/cards/m_spark.tres")] as Array[CardData]
	var cards: Array[Vector2i] = l2.get_card_targets(m2, 0)
	var ok: bool = cards.size() > 0 and l2.play_card(m2, 0, cards[0])
	check("Шаман: Заклинание Мага вылечило шамана на %d" % BattleLogic.SHAMAN_HEAL, ok and sh.hp >= 3 + BattleLogic.SHAMAN_HEAL)

	# Сброс «в ноги» шамана не лечит
	var l3 := fresh()
	var sh3: BattleUnit = l3._new_unit("Шаман")
	sh3.data = enemy("goblin_shaman")
	sh3.hp = 3; sh3.max_hp = 20
	sh3.cell = C(5, 2)
	l3.enemies.append(sh3)
	l3.scrap_card(l3.heroes[0], 0)
	check("Шаман: сброс в ноги не лечит", sh3.hp == 3)

	# Корягач: одиночная атака вдвое слабее, огонь сжигает броню
	var l4 := fresh()
	var tr: BattleUnit = l4._new_unit("Корягач")
	tr.data = enemy("mossy_treant")
	tr.hp = 40; tr.max_hp = 40
	tr.cell = C(5, 2)
	l4.enemies.append(tr)
	l4._cur_card = load("res://resources/cards/k_slash.tres")
	l4._cur_attack = true
	l4._damage(tr, 10)
	check("Корягач: одиночная атака 10 → 5", tr.hp == 35)
	l4._cur_card = load("res://resources/cards/fireball.tres")
	l4._damage(tr, 4)
	check("Корягач: огонь сжёг броню", tr.armor_burnt)
	l4._cur_card = load("res://resources/cards/k_slash.tres")
	l4._damage(tr, 10)
	check("Корягач: после огня удары идут полностью", tr.hp == 35 - 4 - 10)
