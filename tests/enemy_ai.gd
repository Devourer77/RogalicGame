extends SceneTree

# Проверка ИИ врагов (scripts/battle/enemy_ai.gd): оценка удара, место, характеры, порядок ходов,
# причины для игрока и скорость прогноза.
# Запуск: godot --headless --path . -s tests/enemy_ai.gd

var fails := 0
var run
const O := BattleLogic.Obj
const T := BattleLogic.Tile

# Мага ставит fresh() в осевую (-2, 9), рыцаря в (4, 9). Клетки задаём осевыми парами: Q(q, r).
func Q(q: int, r: int) -> Vector2i:
	return Vector2i(q, r)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


# Чистое поле: маг (-2, 9), рыцарь (4, 9); враги стоят в верхнем ряду, дальше их расставляет тест
func fresh(enemy_ids: Array) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = HexMath.from_column(2, 9); l.heroes[1].cell = HexMath.from_column(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = HexMath.from_column(i + 6, 0)
	return l


func plan_of(l: BattleLogic, e: BattleUnit) -> Dictionary:
	for f in l.forecast_enemies():
		if f["enemy"] == e: return f
	return {}


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(7)
	_scoring()
	_place()
	_styles()
	_order()
	_reasons()
	_speed()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


# Задача 1: оценка удара
func _scoring() -> void:
	print("--- Оценка удара ---")
	# Добивание: гоблин ближе к рыцарю, но у мага 4 HP — бьёт мага
	var l := fresh(["goblin"]); var e: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	e.cell = Q(2, 8); m.hp = 4
	var msgs: Array[String] = []
	l.message.connect(func(t: String) -> void: msgs.append(t))
	l._enemies_act()
	check("Добивание: гоблин убивает мага (4 HP), хотя рыцарь ближе", not m.is_alive() and k.hp == 45)
	check("Журнал: заметная причина записана", msgs.has("Гоблин: добьёт Мага"))

	# Контроль: у мага полное HP — гоблин идёт к ближайшему рыцарю, как раньше
	l = fresh(["goblin"]); e = l.enemies[0]; m = l.heroes[0]; k = l.heroes[1]
	e.cell = Q(2, 8)
	l._enemies_act()
	check("Контроль: оба героя целы по HP — гоблин бьёт ближнего рыцаря", k.hp < 45 and m.hp == 30)

	# Оба героя: культист стоит на линии, где один за другим маг и рыцарь
	l = fresh(["cultist"]); e = l.enemies[0]; m = l.heroes[0]; k = l.heroes[1]
	e.cell = Q(-2, 6); k.cell = Q(-2, 10)
	var plan: Dictionary = plan_of(l, e)
	l._enemies_act()
	check("Оба героя: линия культиста задела мага и рыцаря", m.hp < 30 and k.hp < 45)
	check("Оба героя: причина «Заденет обоих»", plan["reason"] == "Заденет обоих")

	# Не бьёт своих сильнее, чем героев: на линии свой гоблин с 3 HP
	l = fresh(["cultist", "goblin"]); e = l.enemies[0]; m = l.heroes[0]
	var g: BattleUnit = l.enemies[1]
	e.cell = Q(-2, 5); e.entangled = 1; g.cell = Q(-2, 7); g.entangled = 1; g.hp = 3
	l._enemies_act()
	check("Свои: линия убила бы своего гоблина — культист не бьёт", m.hp == 30 and g.hp == 3)
	l = fresh(["cultist"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = Q(-2, 5); e.entangled = 1
	l._enemies_act()
	check("Контроль: без гоблина на линии тот же культист бьёт мага", m.hp < 30)

	# Бочка: культист не достаёт мага, но линия попадает в бочку рядом с ним
	l = fresh(["cultist"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = Q(-2, 4); e.entangled = 1; l.objects[Q(-2, 8)] = O.BARREL
	plan = plan_of(l, e)
	l._enemies_act()
	check("Бочка: взрыв ранил мага (6 урона)", m.hp == 24 and l.object_at(Q(-2, 8)) == O.NONE)
	check("Бочка: причина «Подорвёт бочку у Мага»", plan["reason"] == "Подорвёт бочку у Мага")

	# Толчок в трясину: топляк выбирает сторону, откуда маг упрётся в трясину
	l = fresh(["drowned_walker"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = Q(-3, 8); l.objects[Q(-2, 10)] = O.BOG
	plan = plan_of(l, e)
	check("Трясина: причина «Толкнёт Мага в трясину»", plan["reason"] == "Толкнёт Мага в трясину")
	l._enemies_act()
	check("Трясина: маг получил урон от трясины", m.hp < 30 - e.data.damage and m.cell == Q(-2, 9))

	# Толчок в огонь
	l = fresh(["drowned_walker"]); e = l.enemies[0]; m = l.heroes[0]
	e.cell = Q(-3, 8); l.tiles[Q(-2, 10)] = T.FIRE; l.fire_timers[Q(-2, 10)] = 3
	plan = plan_of(l, e)
	l._enemies_act()
	check("Огонь: топляк толкнул мага в огонь", m.cell == Q(-2, 10) and plan["reason"] == "Толкнёт Мага в огонь")

	# Провокация сильнее добивания «чужого»: у мага 4 HP, но рыцарь с провокацией достижим
	l = fresh(["goblin"]); e = l.enemies[0]; m = l.heroes[0]; k = l.heroes[1]
	e.cell = Q(2, 8); m.hp = 4; k.taunt = true
	plan = plan_of(l, e)
	l._enemies_act()
	check("Провокация: гоблин бьёт рыцаря, а не добивает мага", k.hp < 45 and m.hp == 4)
	check("Провокация: причина «Провокация: бьёт Рыцаря»", plan["reason"] == "Провокация: бьёт Рыцаря")


# Задача 2: место
func _place() -> void:
	print("--- Место ---")
	var l := fresh(["goblin", "bloated_toad"]); var e: BattleUnit = l.enemies[0]; var toad: BattleUnit = l.enemies[1]
	l.objects[Q(0, 5)] = O.BARREL
	l.tiles[Q(3, 3)] = T.GAS
	l.tiles[Q(4, 3)] = T.FIRE; l.fire_timers[Q(4, 3)] = 3
	toad.cell = Q(5, 5); toad.inflation = 2
	var ctx: Dictionary = EnemyAI._context(l, e)
	check("Место: рядом с бочкой −%d" % EnemyAI.AI_NEAR_BARREL, EnemyAI._place_value(l, Q(0, 6), ctx) == -EnemyAI.AI_NEAR_BARREL)
	check("Место: газ −%d" % EnemyAI.AI_ON_GAS, EnemyAI._place_value(l, Q(3, 3), ctx) == -EnemyAI.AI_ON_GAS)
	check("Место: огонь −%d" % EnemyAI.AI_FIRE_UNDER, EnemyAI._place_value(l, Q(4, 3), ctx) == -EnemyAI.AI_FIRE_UNDER)
	check("Место: рядом с раздутой жабой −%d" % EnemyAI.AI_NEAR_TOAD, EnemyAI._place_value(l, Q(5, 6), ctx) == -EnemyAI.AI_NEAR_TOAD)
	check("Место: чистая клетка 0", EnemyAI._place_value(l, Q(8, 3), ctx) == 0)
	toad.inflation = 1
	check("Место: жаба с одним стаком не пугает", EnemyAI._place_value(l, Q(5, 6), EnemyAI._context(l, e)) == 0)

	# Единственные клетки для удара рядом с бочкой — гоблин всё равно встаёт и бьёт
	l = fresh(["goblin"]); e = l.enemies[0]
	var m: BattleUnit = l.heroes[0]
	e.cell = Q(-2, 6); l.objects[Q(-1, 8)] = O.BARREL
	l._enemies_act()
	check("Место: ради удара гоблин встал и рядом с бочкой", m.hp < 30)

	# Клещи
	l = fresh(["goblin", "goblin"]); e = l.enemies[1]; m = l.heroes[0]
	var a: BattleUnit = l.enemies[0]
	a.cell = Q(-2, 8); e.cell = Q(-2, 6)
	var atk: EnemyAttackData = l.enemy_attack(e)
	check("Клещи: с противоположной стороны от своего — бонус", EnemyAI._flank(l, e, atk, Q(-1, 9), [m.cell] as Array[Vector2i]) == EnemyAI.AI_FLANK)
	check("Клещи: рядом со своим — без бонуса", EnemyAI._flank(l, e, atk, Q(-1, 8), [m.cell] as Array[Vector2i]) == 0)


# Задача 3: характеры
func _styles() -> void:
	print("--- Характеры ---")
	# Охотник идёт к самому раненому
	var l := fresh(["wolf"]); var e: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	e.cell = Q(2, 8); m.hp = 10
	var plan: Dictionary = plan_of(l, e)
	l._enemies_act()
	check("Охотник: волк бьёт раненого мага, хотя рыцарь ближе", m.hp < 10 and k.hp == 45)
	check("Охотник: причина про раненого мага", plan["reason"] == "Охотник: бьёт раненого Мага")
	# Подход
	l = fresh(["wolf", "goblin"]); e = l.enemies[0]; m = l.heroes[0]; k = l.heroes[1]
	var g: BattleUnit = l.enemies[1]
	e.cell = Q(5, 3); g.cell = Q(5, 2); m.hp = 10
	var wolf_to_mage_before: int = HexMath.distance(e.cell, m.cell)
	var goblin_to_knight_before: int = HexMath.distance(g.cell, k.cell)
	plan = plan_of(l, e)
	l._enemies_act()
	check("Охотник: не достаёт — волк идёт к раненому магу", HexMath.distance(e.cell, m.cell) < wolf_to_mage_before \
			and HexMath.distance(e.cell, m.cell) < HexMath.distance(e.cell, k.cell))
	check("Обычный гоблин рядом идёт к ближайшему рыцарю", HexMath.distance(g.cell, k.cell) < goblin_to_knight_before)
	check("Охотник: причина «к раненому Магу»", plan["reason"] == "Охотник: к раненому Магу")
	# Провокация сильнее характера
	l = fresh(["wolf"]); e = l.enemies[0]; m = l.heroes[0]; k = l.heroes[1]
	e.cell = Q(2, 8); m.hp = 10; k.taunt = true
	l._enemies_act()
	check("Провокация сильнее охотника: волк бьёт рыцаря", k.hp < 45 and m.hp == 10)

	# Телохранитель держится у стрелка
	l = fresh(["goblin_slinger", "mossy_treant"]); var sl: BattleUnit = l.enemies[0]; var tr: BattleUnit = l.enemies[1]
	m = l.heroes[0]
	sl.cell = Q(0, 5); sl.entangled = 1; tr.cell = Q(0, 6)
	plan = plan_of(l, tr)
	l._enemies_act()
	check("Телохранитель: корягач остался вплотную к пращнику", HexMath.distance(tr.cell, sl.cell) == 1)
	check("Телохранитель: причина «Телохранитель: …»", String(plan["reason"]).begins_with("Телохранитель: прикрывает"))
	# Без подопечного — обычный подход к героям
	l = fresh(["mossy_treant"]); tr = l.enemies[0]; m = l.heroes[0]
	tr.cell = Q(0, 6)
	var before: int = HexMath.distance(tr.cell, m.cell)
	l._enemies_act()
	check("Корягач без подопечного идёт к героям", HexMath.distance(tr.cell, m.cell) < before)
	# Подопечный дальше 3 клеток не считается
	l = fresh(["goblin_slinger", "mossy_treant"]); sl = l.enemies[0]; tr = l.enemies[1]
	sl.cell = Q(0, 1); tr.cell = Q(0, 6)
	check("Телохранитель: подопечный дальше 3 клеток не замечен", EnemyAI._ward(l, tr) == null)
	sl.cell = Q(0, 4)
	check("Телохранитель: подопечный в 2 клетках замечен", EnemyAI._ward(l, tr) == sl)
	# Данные
	check("В данных: у волка охотник, у корягача телохранитель, у гоблина обычный",
		(load("res://resources/enemies/wolf.tres") as EnemyData).ai_style == EnemyData.AiStyle.HUNTER \
		and (load("res://resources/enemies/mossy_treant.tres") as EnemyData).ai_style == EnemyData.AiStyle.GUARD \
		and (load("res://resources/enemies/goblin.tres") as EnemyData).ai_style == EnemyData.AiStyle.NORMAL)


# Задача 4: порядок ходов
func _order() -> void:
	print("--- Порядок ходов ---")
	var l := fresh(["goblin", "goblin"])
	l.enemies[0].cell = Q(0, 1); l.enemies[1].cell = Q(-2, 6)
	var order: Array[BattleUnit] = EnemyAI.turn_order(l)
	check("Порядок: ближний к героям ходит первым, хотя в списке второй", order[0] == l.enemies[1] and order[1] == l.enemies[0])
	# Шаман: в раунд «зова» — последним, в раунд луча — по расстоянию
	l = fresh(["goblin_shaman", "goblin"])
	var sh: BattleUnit = l.enemies[0]; var g: BattleUnit = l.enemies[1]
	sh.cell = Q(0, 6); g.cell = Q(0, 2)
	l.turn = 1
	check("Порядок: шаман в раунд луча идёт по расстоянию — первым", EnemyAI.turn_order(l)[0] == sh)
	l.turn = 2
	check("Порядок: шаман в раунд «зова» — последним", EnemyAI.turn_order(l)[1] == sh)
	# Мёртвых в порядке нет
	g.hp = 0
	check("Порядок: павшие не ходят", EnemyAI.turn_order(l).size() == 1)

	# «Зов» считает тех, кто ударит: гоблин с ударом и гоблин рядом с шаманом — шаман встаёт к тем, кто бьёт
	l = fresh(["goblin_shaman", "goblin", "goblin"])
	sh = l.enemies[0]; l.turn = 2
	l.enemies[1].cell = Q(0, 4); l.enemies[2].cell = Q(0, 5); sh.cell = Q(0, 3)
	var plan: Dictionary = plan_of(l, sh)
	check("«Зов»: причина называет число союзников", String(plan["reason"]).begins_with("Зов: усилит"))


# Задача 5: причины для игрока
func _reasons() -> void:
	print("--- Причины ---")
	var l := fresh(["goblin"]); var e: BattleUnit = l.enemies[0]
	e.cell = Q(0, 1)
	var plan: Dictionary = plan_of(l, e)
	check("Причина: не достаёт — «Не достаёт — идёт к …»", String(plan["reason"]).begins_with("Не достаёт — идёт к "))
	check("Прогноз не пишет причину в настоящего врага", e.ai_reason == "")
	l._enemies_act()
	check("Настоящий ход пишет причину во врага", e.ai_reason != "")
	check("Падежи: Маг→Мага, Рыцарь→Рыцаря, Маг→Магу, Рыцарь→Рыцарю",
		EnemyAI._acc("Маг") == "Мага" and EnemyAI._acc("Рыцарь") == "Рыцаря" \
		and EnemyAI._dat("Маг") == "Магу" and EnemyAI._dat("Рыцарь") == "Рыцарю")


# Скорость прогноза: бой на 8 врагов
func _speed() -> void:
	print("--- Скорость ---")
	var l := fresh(["goblin", "goblin", "goblin", "wolf", "wolf", "cultist", "cultist", "goblin_slinger"])
	var cells: Array[Vector2i] = [Q(-4, 4), Q(-2, 4), Q(0, 4), Q(2, 4), Q(-3, 3), Q(0, 2), Q(2, 2), Q(-1, 1)]
	for i in l.enemies.size(): l.enemies[i].cell = cells[i]
	var t0: int = Time.get_ticks_usec()
	var rounds: int = 10
	for i in rounds:
		l.forecast_enemies()
		l.forecast_hazards()
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / rounds
	print("Прогноз (forecast_enemies + forecast_hazards), 8 врагов: %.1f мс" % ms)
	check("Скорость: прогноз 8 врагов быстрее 60 мс", ms < 60.0)
