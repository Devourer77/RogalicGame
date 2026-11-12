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

	# Общая мана
	check("мана общая: 4 в начале хода", mage.mana == BattleLogic.PARTY_MANA and knight.mana == BattleLogic.PARTY_MANA)
	mage.mana -= 1
	check("трата Мага уменьшает ману Рыцаря", knight.mana == BattleLogic.PARTY_MANA - 1)

	# Перегрев: можно уйти до −3, глубже нельзя
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
	check("на −3 платные карты не играются", not any_playable)

	# Расплата в конце хода
	var hp_before: int = mage.hp
	mage.block = 99
	mage.mana = -2
	l.end_turn()
	check("перегрев 2: Маг получил 8 урона мимо блока", mage.hp == hp_before - 8)
	check("после 2 стаков маны на ход меньше (3)", l.mana_pool.current == BattleLogic.PARTY_MANA - 1)

	# Без перегрева — без урона
	hp_before = mage.hp
	l.mana_pool.current = 1
	l.end_turn()
	check("без перегрева урона нет", mage.hp == hp_before)
	check("мана вернулась к 4", l.mana_pool.current == BattleLogic.PARTY_MANA)

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

	# Клон делит пул между своими героями
	var cl: BattleLogic = l3.clone()
	cl.heroes[0].mana -= 2
	check("в клоне мана общая", cl.heroes[1].mana == l3.heroes[1].mana - 2)
	check("клон не трогает оригинал", l3.heroes[0].mana == mana0)

	print("--- провалов: %d ---" % fails)
	quit(1 if fails > 0 else 0)
