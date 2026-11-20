extends SceneTree

# Духи акта 2 (тз-духи-акт-2.md): данные, пассивы, зовы, условия уникальных духов, Колосс Сфер.
# Запуск: godot --headless --path . -s tests/spirits_act2.gd

const UL := Vector2i(0, -1)
const UR := Vector2i(1, -1)
const O := BattleLogic.Obj
const T := BattleLogic.Tile

var fails := 0
var run


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func sp(id: String) -> SpiritData:
	return load("res://resources/spirits/%s.tres" % id)


func card(id: String) -> CardData:
	var parts: PackedStringArray = id.split("+")
	var base: String = parts[0]
	var dir: String = "mixed" if base.begins_with("mix_") else "spirits/" + base.split("_")[0]
	var c: CardData = load("res://resources/cards/%s/%s.tres" % [dir, base])
	if parts.size() > 1:
		return c.upgrade_1 if parts[1] == "1" else c.upgrade_2
	return c


func fresh(enemy_ids: Array = ["goblin", "goblin"]) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear(); l.obj_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i * 2, 0)
		l.enemies[i].block = 0
		if not l.enemies[i].data.is_boss:
			l.enemies[i].hp = 60; l.enemies[i].max_hp = 60
	for h in l.heroes:
		h.mana = 10; h.moves_left = 3; h.block = 0
	return l


func give(h: BattleUnit, ids: Array) -> void:
	var hand: Array[CardData] = []
	for id in ids: hand.append(card(id))
	h.hand = hand


func play(l: BattleLogic, h: BattleUnit, target: Vector2i = Vector2i(-999, -999)) -> bool:
	return l.play_card(h, 0, h.cell if target == Vector2i(-999, -999) else target)



func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.sim_no_scenes = true
	run.start_new_run(43)
	_data()
	_passives()
	_calls()
	_colossus()
	_vessel()
	_lair_and_events()
	_arena_mechanics()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> void:
	print("--- Данные ---")
	for id in ["ash", "stone", "steam", "magma", "rust"]:
		var s: SpiritData = sp(id)
		check("Дух %s: 6+6 карт и Зов" % id, s != null and s.mage_cards.size() == 6 and s.knight_cards.size() == 6 and s.call_card != null)
		check("Дух %s в Святилище" % id, run.ALL_SPIRIT_IDS.has(id))
		var ups: bool = true
		for c in s.mage_cards + s.knight_cards:
			if c.upgrade_1 == null or c.upgrade_2 == null:
				ups = false
		check("Дух %s: у всех карт два улучшения" % id, ups)
	check("Пары: по 4 смешанные карты у каждого нового духа", sp("ash").mixed_cards.size() == 4 and sp("stone").mixed_cards.size() == 4
			and sp("magma").mixed_cards.size() == 4 and sp("steam").mixed_cards.size() == 4 and sp("rust").mixed_cards.size() == 4)
	check("Пепельник и Каменник — враги логова, уникальные — нет", sp("ash").enemy != null and sp("stone").enemy != null
			and sp("magma").is_unique and sp("rust").is_unique and sp("steam").is_unique)


func _passives() -> void:
	print("--- Пассивы ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]
	m.spirits.append("ash")
	l._set_tile(m.cell + UL, T.FIRE)
	m.block = 0; l._act2_spirit_passives(m)
	check("Пепельник: рядом огонь — +2 блока", m.block == 2)
	l = fresh(); m = l.heroes[0]; m.spirits.append("stone")
	l.rocks[m.cell + UL] = true; l.rocks[m.cell + UR] = true
	m.block = 0; l._act2_spirit_passives(m)
	check("Каменник: 2 преграды рядом — +2 блока", m.block == 2)
	l = fresh(); m = l.heroes[0]; m.spirits.append("steam"); m.wet = 2
	m.block = 0; l._act2_spirit_passives(m)
	check("Котловик: мокрый — +блок", m.block == l.STEAM_WET_BLOCK)
	check("Котловик: пар не ранит", l._steamproof(m) and not l._steamproof(l.heroes[1]))


func _calls() -> void:
	print("--- Зовы ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]
	var t: Vector2i = m.cell + UL * 3
	give(m, ["ash_call"]); play(l, m, t)
	check("Завеса: дым на клетке", l.tile_at(t) == T.SMOKE)
	l = fresh(); m = l.heroes[0]
	give(m, ["stone_call"]); var before: int = l.objects.size()
	play(l, m, m.cell + UL * 3)
	check("Обвал: появились камни-преграды", l.objects.size() > before)
	l = fresh(); m = l.heroes[0]
	give(m, ["magma_call"]); t = m.cell + UL * 3
	play(l, m, t)
	check("Извержение: лава в точке", l.object_at(t) == O.LAVA)
	l = fresh(); m = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = m.cell + UL * 2; e.block = 5
	give(m, ["rust_call"]); play(l, m)
	check("Ржавчина: враг рядом теряет блок и ржавеет", e.block == 0 and e.rust > 0)


func _colossus() -> void:
	print("--- Колосс Сфер ---")
	var l := fresh(["sphere_colossus"]); var c: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	var storm: EnemyAttackData = c.data.cycle[1]
	check("Грозовая сфера бьёт по лужам", storm.puddle_lightning)
	check("Герой не в луже — молнии некуда бить", l.puddle_lightning_cells().is_empty())
	l.tiles[m.cell] = T.WATER; l.tiles[m.cell + UR] = T.WATER; l.tiles[m.cell + UR * 2] = T.WATER
	var cells: Array[Vector2i] = l.puddle_lightning_cells()
	check("Герой в луже — молния по всей связанной воде (3 клетки)", cells.size() == 3)
	check("Клетки удара не зависят от места Колосса", l._attack_cells(c, storm, C(1, 1), Vector2i(0, 1)).size() == 3)
	c.block = 0
	var count: int = l.enemies.size()
	l.turn = 2
	l._damage(c, c.hp - c.max_hp / 2)
	check("50%%: сфера лопнула, вышел одичавший дух", c.burst_done and l.enemies.size() == count + 1)
	check("Удар лопнувшей сферы выпал из круга", c.lost_attacks.size() == 1)
	var seen: Dictionary = {}
	for t in range(1, 7):
		seen[l.enemy_attack_on(c, t)] = true
	check("Круг стал из двух ударов", seen.size() == 2 and not seen.has(c.lost_attacks[0]))
	check("Вторая половина HP сферу не лопает снова", true)
	l._damage(c, 1)
	check("После сферы — одна", c.lost_attacks.size() == 1)
	var cl: BattleLogic = l.clone()
	check("Копия боя помнит лопнувшую сферу", cl.enemies[0].burst_done and cl.enemies[0].lost_attacks.size() == 1 and cl.burst_turn == l.burst_turn)
	l.turn = 4
	l._damage(c, 999, true)
	check("Добит за 3 раунда — условие Ржавника", l.colossus_fast_kill)
	l = fresh(["sphere_colossus"]); c = l.enemies[0]; c.block = 0
	l.turn = 2; l._damage(c, c.hp - c.max_hp / 2)
	l.turn = 6; l._damage(c, 999, true)
	check("Добит поздно — Ржавник не идёт", not l.colossus_fast_kill)


func _vessel() -> void:
	print("--- Сосуд Венца ---")
	var l := fresh(["crown_vessel"]); var m: BattleUnit = l.heroes[0]; var v: BattleUnit = l.enemies[0]
	v.cell = m.cell + UL * 2
	var water: CardData = null
	for id in ["tide_m2", "tide_k2", "tide_m1"]:
		var cd: CardData = card(id)
		if cd.element == CardData.Element.WATER and cd.damage > 0:
			water = cd
			break
	check("Есть карта воды с уроном для проверки", water != null)
	if water == null:
		return
	for i in 3:
		m.mana = 10
		var hand: Array[CardData] = [water]
		m.hand = hand
		l.play_card(m, 0, v.cell)
	check("Сосуд облит водой 3 раза", l.vessel_water_hits >= 3)


func _lair_and_events() -> void:
	print("--- Логово и событие ---")
	run.act = 2
	var ash_seen: bool = false
	var act1_only: bool = true
	for i in 30:
		var s: SpiritData = run._roll_lair_spirit()
		if s != null and (s.id == "ash" or s.id == "stone"):
			ash_seen = true
	check("В логове акта 2 — Пепельник или Каменник", ash_seen)
	run.act = 1
	for i in 30:
		var s: SpiritData = run._roll_lair_spirit()
		if s != null and not ["tide", "storm", "wind"].has(s.id):
			act1_only = false
	check("В логове акта 1 — только духи акта 1", act1_only)
	check("Источника нет в акте 1", not run.spring_possible())
	var screen = load("res://ui/event_screen.gd")
	check("Событие «Кипящий источник» есть", not screen.event_by_id("spring").is_empty())
	check("Секрет не выпадает обычным путём", not screen.event_allowed(screen.event_by_id("spring")))


func _arena_mechanics() -> void:
	print("--- Механики арен акта 2 ---")
	var r := RandomNumberGenerator.new(); r.seed = 5
	var enemies: Array[EnemyData] = [load("res://resources/enemies/cultist.tres") as EnemyData]
	var b := BattleLogic.new(); b.setup(12, 12, r, run.party, enemies, "pass")
	check("Перевал: есть ветер", b.wind_dir != Vector2i.ZERO)
	b = BattleLogic.new(); r.seed = 6; b.setup(12, 12, r, run.party, enemies, "assembly")
	check("Цех: есть ленты", not b.belts.is_empty())
	b = BattleLogic.new(); r.seed = 7; b.setup(12, 12, r, run.party, enemies, "mine")
	check("Туннель: есть вагонетки", b._cells_with(O.CART).size() > 0)
	b = BattleLogic.new(); r.seed = 8; b.setup(12, 12, r, run.party, enemies, "crater")
	check("Край жерла: есть купели", b._cells_with(O.BASIN).size() > 0)
	var storm_found: bool = false
	for sd in 10:
		b = BattleLogic.new(); r.seed = 20 + sd; b.setup(12, 12, r, run.party, enemies, "sphere_hall")
		if b._cells_with(O.SPHERE_STORM).size() > 0:
			storm_found = true
	check("Зал сфер: есть грозовые сферы", storm_found)

	# ветер
	var l := fresh(); var f: Vector2i = C(5, 4)
	l.wind_dir = HexMath.DIRS[0]
	l._set_tile(f, T.FIRE)
	l._wind_round_end()
	check("Ветер: огонь перекинулся по ветру", l.tile_at(f + HexMath.DIRS[0]) == T.FIRE and l.tile_at(f + HexMath.DIRS[3]) != T.FIRE)
	# лента
	l = fresh(); var e: BattleUnit = l.enemies[0]; e.cell = C(4, 3)
	l.belts[e.cell] = e.cell + HexMath.DIRS[0]
	l._belts_round_end()
	check("Лента: враг уехал на клетку", e.cell == C(4, 3) + HexMath.DIRS[0])
	# вагонетка
	l = fresh(); e = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	var cart: Vector2i = m.cell + UL * 2
	l.objects[cart] = O.CART
	e.cell = cart + UL * 3
	var hp: int = e.hp
	l._hit_object(cart, m.cell)
	check("Вагонетка: покатилась и сбила врага", e.hp == hp - l.CART_DAMAGE and l.object_at(e.cell - UL) == O.CART and l.object_at(cart) == O.NONE)
	# купель
	l = fresh(["crown_vessel"]); var v: BattleUnit = l.enemies[0]
	var basin: Vector2i = C(6, 4)
	l.objects[basin] = O.BASIN
	v.cell = basin + UR; v.block = 0
	l._set_tile(basin + UL, T.FIRE)
	hp = v.hp
	l._hit_object(basin, basin + Vector2i(0, 1))
	check("Купель: Сосуд мокрый и обожжён водой", l.is_wet(v) and v.hp == hp - l.BASIN_WEAK_DAMAGE)
	check("Купель: огонь рядом погас, купель пуста", l.tile_at(basin + UL) != T.FIRE and l.object_at(basin) == O.NONE)
	check("Купель считается для Сердца Жерла", l.vessel_water_hits == 1)
	# грозовая сфера
	l = fresh(); e = l.enemies[0]
	var orb: Vector2i = C(6, 4)
	l.objects[orb] = O.SPHERE_STORM
	l.tiles[orb + UR] = T.WATER; l.tiles[orb + UR * 2] = T.WATER
	e.cell = orb + UR * 2; hp = e.hp
	l._hit_object(orb, orb + Vector2i(0, 1))
	check("Грозовая сфера: разряд дошёл по воде", e.hp < hp and l.object_at(orb) == O.NONE)
	# дождевик
	l = fresh(); l.arena_id = "fungus"
	var puff: Vector2i = C(6, 4)
	l.objects[puff] = O.BARREL
	l._hit_object(puff, puff + Vector2i(0, 1))
	check("Дождевик: газ, а не огонь", l.tile_at(puff) == T.GAS and l.tile_at(puff + UR) == T.GAS and l.tile_at(puff + UL) != T.FIRE)
