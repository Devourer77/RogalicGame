extends SceneTree

# Модификаторы врагов (claude/тз-сложность-боя.md): сколько выдаётся, кому, и что делает каждый.
# Запуск: godot --headless --path . -s tests/modifiers.gd

const UL := Vector2i(0, -1)
var fails := 0
var run


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func mod(id: String) -> EnemyModifier:
	return load("res://resources/enemy_modifiers/%s.tres" % id)


func with_mod(enemy_id: String, mod_id: String) -> EnemyData:
	var d: EnemyData = (load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData).duplicate()
	d.modifier = mod(mod_id) if mod_id != "" else null
	return d


# Бой на чистом поле: герои внизу, враги — где скажем
func fresh(list: Array[EnemyData]) -> BattleLogic:
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i * 2, 0)
		l.enemies[i].block = 0
	for h in l.heroes:
		h.mana = 10; h.block = 0
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(3)
	_counts()
	_frenzy()
	_rally()
	_spite()
	_faith()
	_tenacious()
	_rotten()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _modded(list: Array[EnemyData]) -> int:
	return list.filter(func(e: EnemyData) -> bool: return e.modifier != null).size()


func _counts() -> void:
	print("--- Сколько и кому ---")
	var ok_rows := true
	for s in 30:
		run.start_new_run(100 + s, 0)
		ok_rows = ok_rows and _modded(run._make_encounter(0, false)) == 0 and _modded(run._make_encounter(1, false)) == 0
		ok_rows = ok_rows and _modded(run._make_encounter(2, false)) == 1 and _modded(run._make_encounter(3, false)) == 1
		ok_rows = ok_rows and _modded(run._make_encounter(4, false)) == 2
	check("Ряды 0–1: никого, 2–3: один, 4: двое", ok_rows)
	var ok_big := true
	for s in 20:
		run.start_new_run(200 + s, 0)
		var elite: Array[EnemyData] = run._make_encounter(5, false, true)
		var boss: Array[EnemyData] = run._make_encounter(7, true)
		ok_big = ok_big and _modded(elite) == 1 and elite[0].modifier == null and _modded(boss) == 1 and boss[0].modifier == null
	check("Элита и босс: один из свиты, главный — без", ok_big)
	var ok_bell := true
	for s in 20:
		run.start_new_run(300 + s, 2)
		ok_bell = ok_bell and _modded(run._make_encounter(0, false)) == 1 and _modded(run._make_encounter(4, false)) == 3
	check("Звон 2: ещё один — с ряда 0", ok_bell)
	var wolf: EnemyData = load("res://resources/enemies/wolf.tres")
	check("Общий файл врага не меняется", wolf.modifier == null)
	var ok_fit := true
	var seen: Dictionary = {}
	for s in 120:
		run.start_new_run(400 + s, 2)
		for e in run._make_encounter(2 + s % 3, false) + run._make_encounter(5, false, true):
			if e.modifier != null:
				seen[e.modifier.id] = true
				ok_fit = ok_fit and e.modifier.fits(e)
				if e.modifier.needs_caller:
					pass
	check("Каждый модификатор подходит своему врагу", ok_fit)
	check("Встречаются все 6 модификаторов %s" % [seen.keys()], seen.size() == 6)
	check("«Вера» только у культа, «Бешенство» не у топляка", mod("faith").fits(load("res://resources/enemies/cultist.tres"))
			and not mod("faith").fits(wolf) and not mod("frenzy").fits(load("res://resources/enemies/drowned_walker.tres")))
	var d: EnemyData = with_mod("wolf", "frenzy")
	check("В карточке врага строка модификатора", d.traits().has(mod("frenzy").description))


func _frenzy() -> void:
	print("--- Бешенство ---")
	var l := fresh([with_mod("wolf", "frenzy")] as Array[EnemyData])
	var e: BattleUnit = l.enemies[0]
	var base_dmg: int = l.snapshot(e)["damage"]
	var base_steps: int = l.enemy_move_range(e)
	l._damage(e, 1)
	check("Пока HP больше половины — спит", not e.mod_on and l.snapshot(e)["damage"] == base_dmg)
	l._damage(e, e.hp - e.max_hp / 2)
	check("HP ≤ половины — удары +2 и +1 шаг", e.mod_on and l.snapshot(e)["damage"] == base_dmg + 2
			and l.enemy_move_range(e) == base_steps + 1)
	check("Значок на плашке горит", l.snapshot(e)["mod_on"] and l.snapshot(e)["mod"] == "mod_frenzy")


func _rally() -> void:
	print("--- Отклик на зов ---")
	var l := fresh([load("res://resources/enemies/goblin_shaman.tres"), with_mod("goblin", "rally"), load("res://resources/enemies/goblin.tres")] as Array[EnemyData])
	var shaman: BattleUnit = l.enemies[0]
	var g: BattleUnit = l.enemies[1]
	var plain: BattleUnit = l.enemies[2]
	g.cell = shaman.cell + Vector2i(1, 0)
	plain.cell = shaman.cell + Vector2i(1, -1) if l.is_inside(shaman.cell + Vector2i(1, -1)) else shaman.cell + Vector2i(0, 1)
	var aura: EnemyAttackData = null
	for atk in shaman.data.cycle:
		if atk.shape == EnemyData.Attack.AURA:
			aura = atk
	var steps: int = l.enemy_move_range(g)
	l._enemy_aura(shaman, aura)
	check("Откликнулся: удар сильнее обычного зова на 2", g.bonus_damage == plain.bonus_damage + 2 and g.mod_step_next)
	l._start_enemy_phase()
	check("…и на следующий ход +1 шаг", l.enemy_move_range(g) == steps + 1)
	l._start_enemy_phase()
	check("…только на один ход", l.enemy_move_range(g) == steps)


func _spite() -> void:
	print("--- Злопамятный ---")
	var l := fresh([with_mod("drowned_walker", "spite")] as Array[EnemyData])
	var e: BattleUnit = l.enemies[0]
	var k: BattleUnit = l.heroes[1]
	e.max_hp = 60; e.hp = 60
	e.cell = k.cell + UL
	var hand: Array[CardData] = [load("res://resources/cards/base/kb_boot.tres"), load("res://resources/cards/base/kb_boot.tres")]
	k.hand = hand
	var hp: int = k.hp
	l.play_card(k, 0, e.cell)
	check("Ударили вплотную — ответ на 2", k.hp == hp - 2 and e.mod_used)
	e.cell = k.cell + UL
	var hp2: int = k.hp
	l.play_card(k, 0, e.cell)
	check("Второй раз за ход — не отвечает", k.hp == hp2)
	l._start_heroes_turn()
	check("В новый ход героев снова готов", not e.mod_used)
	var m: BattleUnit = l.heroes[0]
	e.cell = m.cell + UL * 3
	var hand2: Array[CardData] = [load("res://resources/cards/base/mb_spark.tres")]
	m.hand = hand2
	var hpm: int = m.hp
	l.play_card(m, 0, e.cell)
	check("Издалека — не отвечает", m.hp == hpm)


func _faith() -> void:
	print("--- Вера в Венец ---")
	var l := fresh([with_mod("cultist", "faith"), load("res://resources/enemies/goblin.tres"), load("res://resources/enemies/goblin.tres")] as Array[EnemyData])
	var c: BattleUnit = l.enemies[0]
	var g1: BattleUnit = l.enemies[1]
	var g2: BattleUnit = l.enemies[2]
	g1.cell = c.cell + Vector2i(1, 0)
	g2.cell = C(10, 5)
	var dmg: int = l.snapshot(c)["damage"]
	l._damage(g1, 99)
	check("Рядом погиб свой — +3 блока и удары +1", c.mod_stacks == 1 and c.block == 3 and l.snapshot(c)["damage"] == dmg + 1)
	l._damage(g2, 99)
	check("Погиб далеко — не считается", c.mod_stacks == 1)


func _tenacious() -> void:
	print("--- Цепкий ---")
	var l := fresh([with_mod("goblin", "tenacious")] as Array[EnemyData])
	var e: BattleUnit = l.enemies[0]
	l._damage(e, 99)
	check("Первый раз встаёт с 4 HP", e.is_alive() and e.hp == 4)
	l._damage(e, 99)
	check("Второй раз — падает", not e.is_alive())


func _rotten() -> void:
	print("--- Гнилое нутро ---")
	var l := fresh([with_mod("goblin", "rotten"), load("res://resources/enemies/goblin.tres")] as Array[EnemyData])
	var e: BattleUnit = l.enemies[0]
	var g: BattleUnit = l.enemies[1]
	var k: BattleUnit = l.heroes[1]
	e.cell = k.cell + UL
	g.cell = e.cell + Vector2i(1, -1) if l.is_inside(e.cell + Vector2i(1, -1)) else e.cell + Vector2i(-1, 0)
	var hpk: int = k.hp
	var hpg: int = g.hp
	l._damage(e, 99)
	check("Лопается: соседнему герою 3 и своему 3", k.hp == hpk - 3 and g.hp == hpg - 3)
	var l2 := fresh([with_mod("goblin", "rotten")] as Array[EnemyData])
	var e2: BattleUnit = l2.enemies[0]
	e2.cell = l2.heroes[1].cell + UL
	var hp2: int = l2.heroes[1].hp
	l2._kill(e2)
	check("Утонул — не лопается", l2.heroes[1].hp == hp2)
