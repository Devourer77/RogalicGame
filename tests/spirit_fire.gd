extends SceneTree

# Дух огня (claude/тз-дух-огня.md): Жаровик-враг, Тлеющая пещера, 12 карт духа, 12 смешанных,
# пассив, событие «Тлеющая расщелина» и путь «событие → бой → награда».
# Запуск: godot --headless --path . -s tests/spirit_fire.gd

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


func burn(l: BattleLogic, c: Vector2i) -> void:
	l._set_tile(c, T.FIRE)


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(43)
	_data()
	_mage()
	_knight()
	_pairs()
	_passive()
	_zharovik()
	_cave()
	_run_side()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> void:
	print("--- Данные ---")
	var s: SpiritData = sp("fire")
	check("Дух огня загружается", s != null)
	check("6 + 6 карт и 12 смешанных", s.mage_cards.size() == 6 and s.knight_cards.size() == 6 and s.mixed_cards.size() == 12)
	var ok := true
	for c in s.mage_cards + s.knight_cards + s.mixed_cards:
		ok = ok and c.upgrade_1 != null and c.upgrade_2 != null and c.description != ""
	check("У всех карт две ветки и текст", ok)
	check("Зов «Вспышка» есть", s.call_card != null and s.call_card.is_call)
	check("Уникальный, в логово не ходит", s.is_unique and not run.SPIRIT_IDS.has("fire") and run.ALL_SPIRIT_IDS.has("fire"))
	var e: EnemyData = s.enemy
	check("Жаровик: 70 HP, укрощаемый, огнеходец, боится воды", e.max_hp == 70 and e.tamable and e.fire_walker and e.water_weak and e.model != null)
	check("Цикл: плевок, вспышка, раздуть угли", e.cycle.size() == 3 and e.cycle[2].stoke == 2)


func _mage() -> void:
	print("--- Маг ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	var t: Vector2i = m.cell + UL * 3
	give(m, ["fire_m1"]); play(l, m, t)
	check("Поджог: клетка горит", l.tile_at(t) == T.FIRE)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; var e2: BattleUnit = l.enemies[1]
	e.cell = m.cell + UL * 3; e2.cell = e.cell + UR; burn(l, e2.cell)
	give(m, ["fire_m2+2"]); play(l, m, e.cell)
	check("Искра жара II: 2 урона, поджог, перескок на соседа в огне", e.hp == 58 and l.tile_at(e.cell) == T.FIRE and e2.hp == 58)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 4
	give(m, ["fire_m3"]); play(l, m, e.cell)
	check("Огненный шар: урон и круг горит", e.hp <= 56 and l.tile_at(e.cell + UL) == T.FIRE)
	l = fresh(); m = l.heroes[0]; t = m.cell + UL * 3; burn(l, t)
	var origin: Vector2i = m.cell
	give(m, ["fire_m4+2"]); play(l, m, t)
	check("Тяга II: маг на горящей клетке, откуда ушёл — горит", m.cell == t and l.tile_at(origin) == T.FIRE)
	l = fresh(); m = l.heroes[0]
	check("Тяга: на негорящую клетку нельзя", not l._special_target_ok("fire_step", m.cell + UL * 2))
	l = fresh(); m = l.heroes[0]; m.cell = C(5, 9); t = m.cell + UL * 4; l.objects[t + UL * 2] = O.BARREL
	give(m, ["fire_m6"]); play(l, m, t)
	check("Метеор: бочка в 2 клетках взорвалась", l.object_at(t + UL * 2) != O.BARREL)
	l = fresh(); m = l.heroes[0]; m.cell = C(5, 9); e = l.enemies[0]; t = m.cell + UL * 4; e.cell = t + UL * 2
	give(m, ["fire_m6+2"]); play(l, m, t)
	check("Метеор II: круг 2 — враг в 2 клетках ранен", e.hp == 55)


func _knight() -> void:
	print("--- Рыцарь ---")
	var l := fresh(); var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	e.cell = k.cell + UL; burn(l, e.cell)
	give(k, ["fire_k2"]); play(l, k, e.cell)
	check("Раскалённый клинок: по врагу в огне 3 + 3", e.hp == 54)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["fire_k2"]); play(l, k, e.cell)
	check("Раскалённый клинок: не в огне — 3", e.hp == 57)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 3
	give(k, ["fire_k3"]); play(l, k, e.cell)
	var burning_path: int = 0
	for c in l.fire_timers:
		burning_path += 1
	check("Огненный таран: враг ранен, путь горит", e.hp < 60 and burning_path >= 1 and l.tile_at(k.cell) != T.FIRE)
	l = fresh(); k = l.heroes[1]; burn(l, k.cell + UL); burn(l, k.cell + UR * 2)
	var mom: int = k.momentum
	give(k, ["fire_k4"]); play(l, k)
	check("Сквозь пламя: +2 натиска за 2 горящие клетки", k.momentum == mini(BattleLogic.MAX_MOMENTUM, mom + 2))
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]
	give(k, ["fire_k5"]); play(l, k)
	e.cell = k.cell + UL
	l._outpost_strike(e)
	check("Щит углей: блок 6, под подошедшим врагом огонь", k.block >= 6 and l.tile_at(e.cell) == T.FIRE)
	l = fresh(); k = l.heroes[1]; var m: BattleUnit = l.heroes[0]
	give(k, ["fire_k5+2"]); play(l, k)
	check("Щит углей II: защищает обоих", k.ember_guard and m.ember_guard)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 2
	give(k, ["fire_k6+2"]); play(l, k)
	check("Пламенный вихрь II: круг 2 задет и горит", e.hp == 55 and l.tile_at(e.cell) == T.FIRE)


func _pairs() -> void:
	print("--- Пары ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	var f: Vector2i = m.cell + UR * 2; burn(l, f)
	give(m, ["mix_fire_wind_m1"]); play(l, m, m.cell + UL)
	check("Раздуть пламя: огонь перешёл на соседнюю клетку в сторону", l.tile_at(f + UL) == T.FIRE)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; var t: Vector2i = m.cell + UL * 4; e.cell = t + UL * 2
	give(m, ["mix_fire_wind_m2"]); play(l, m, t)
	check("Огненный смерч: враг стянут на 1 и ранен, центр горит", HexMath.distance(e.cell, t) == 1 and e.hp == 58 and l.tile_at(t) == T.FIRE)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 2
	give(k, ["mix_fire_wind_k1"]); play(l, k, k.cell + UL)
	check("Горящий порыв: урон, толчок, клетки горят", e.hp == 58 and e.cell == k.cell + UL * 3 and l.tile_at(k.cell + UL) == T.FIRE)

	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; var w: Vector2i = m.cell + UL * 2; e.cell = w; l.tiles[w] = T.WATER
	give(m, ["mix_fire_tide_m1"]); play(l, m)
	check("Паровой котёл: 3 урона, отброс, лужа исчезла", e.hp == 57 and e.cell != w and l.tile_at(w) != T.WATER)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3
	check("Кипяток: сухого врага не выбрать", not l._special_target_ok("scald", e.cell))
	e.wet = 2
	give(m, ["mix_fire_tide_m2"]); play(l, m, e.cell)
	check("Кипяток: мокрому 3 урона и отброс", e.hp == 57 and e.cell == m.cell + UL * 4)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; l.tiles[k.cell] = T.WATER
	give(k, ["mix_fire_tide_k1", "fire_k2"]); play(l, k)
	check("Закалка в пару: в луже +4 к следующему удару", k.temper == 4 and k.block == 6)
	play(l, k, e.cell)
	check("…клинок бьёт 3 + 4", e.hp == 53 and k.temper == 0)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; var e2: BattleUnit = l.enemies[1]
	e.cell = k.cell + UL; e.wet = 2; e2.cell = e.cell + UL
	give(k, ["mix_fire_tide_k2"]); play(l, k, e.cell)
	check("Паровой удар: по мокрому — пар бьёт соседа", e.hp == 57 and e2.hp == 57)

	l = fresh(); m = l.heroes[0]; t = m.cell + UL * 4; l.tiles[t] = T.SWAMP; l.objects[t + UL] = O.BOG
	give(m, ["mix_fire_bog_m1"]); play(l, m, t)
	check("Разбудить недра: топь и трясина — лава на 2 раунда", l.object_at(t) == O.LAVA and l.object_at(t + UL) == O.LAVA and l.obj_timers.get(t, 0) == 2)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; l.objects[k.cell + UL * 3] = O.LAVA
	give(k, ["mix_fire_bog_k1"]); play(l, k, e.cell)
	check("Вдавить в лаву: 2 + лава 6 + ещё 6", e.hp <= 46)
	l = fresh(); k = l.heroes[1]; l.objects[k.cell + UL] = O.BOG
	give(k, ["mix_fire_bog_k2"]); play(l, k)
	check("Горячая трясина: трясина рядом — лава, вокруг огонь", l.object_at(k.cell + UL) == O.LAVA and l.tile_at(k.cell + UR) == T.FIRE)


func _passive() -> void:
	print("--- Пассив духа ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	m.spirits.append("fire")
	check("Огонь не ранит героя с духом огня", l.fire_damage_for(m) == 0 and l.fire_damage_for(k) > 0)
	var hp: int = m.hp
	l.objects[m.cell + UL * 2] = O.LAVA
	l._push(m, UL, 3)
	check("Толчок в лаву: стоит у края, без урона", m.cell == C(2, 9) + UL and m.hp == hp)
	burn(l, m.cell)
	var hp2: int = m.hp
	l.end_turn()
	check("Конец раунда в огне — без урона", m.hp >= hp2)


func _zharovik() -> void:
	print("--- Жаровик ---")
	var l := fresh(["spirit_fire", "goblin"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	check("Огонь и лава его не ранят", l.fire_damage_for(e) == 0)
	l.objects[C(5, 3)] = O.LAVA
	check("Лава для него не преграда", not l._is_obstacle_for(e, C(5, 3)) and l._is_obstacle_for(l.enemies[1], C(5, 3)))
	e.cell = m.cell + UL * 3; e.wet = 2
	var hp: int = e.hp
	give(m, ["mix_fire_tide_m2"]); play(l, m, e.cell)
	check("Кипяток по нему вдвое (6)", e.hp == hp - 6)
	l = fresh(["spirit_fire"]); e = l.enemies[0]; e.cell = C(6, 3); l.tiles[e.cell] = T.WATER
	l._start_enemy_phase()
	check("Лужа под ним вскипает: мокрый, без брони", l.tile_at(e.cell) != T.WATER and l.is_wet(e) and e.block == 0)
	l = fresh(["spirit_fire"]); e = l.enemies[0]; e.cell = C(6, 3)
	l._start_enemy_phase()
	check("Сухой — броня 4", e.block == 4)
	burn(l, e.cell + UL * 2); var c: Vector2i = e.cell + UL * 2
	var before: int = l.fire_timers[c]
	l._enemy_aura(e, e.data.cycle[2])
	check("Раздуть угли: огонь горит на 2 раунда дольше", l.fire_timers[c] == before + 2)
	var ai_ctx: Dictionary = EnemyAI._context(l, e)
	check("ИИ не боится огня под Жаровиком", ai_ctx.get("fireproof", false))


func _cave() -> void:
	print("--- Тлеющая пещера ---")
	var list: Array[EnemyData] = [sp("fire").enemy]
	for id in ["torch_goblin", "torch_goblin", "goblin", "goblin"]:
		list.append(load("res://resources/enemies/%s.tres" % id))
	var ok_lava := true; var ok_peat := true; var ok_gas := true; var ok_rocks := true
	for s in 12:
		var r := RandomNumberGenerator.new(); r.seed = 100 + s
		var l := BattleLogic.new()
		l.setup(12, 12, r, run.party, list, "cave")
		var lava := 0; var gas := 0; var burning := 0
		for c in l.objects:
			if l.objects[c] == O.LAVA:
				lava += 1
				ok_lava = ok_lava and not l.obj_timers.has(c)
		for c in l.tiles:
			gas += 1 if l.tiles[c] == T.GAS else 0
			burning += 1 if l.tiles[c] == T.FIRE else 0
		ok_lava = ok_lava and lava >= 4
		ok_peat = ok_peat and l.peat.size() >= 6 and burning >= 3
		ok_gas = ok_gas and gas >= 2
		ok_rocks = ok_rocks and l.rocks.size() >= 5
	check("Лава постоянная (без таймера), 2 озерца", ok_lava)
	check("Торф есть, часть тлеет", ok_peat)
	check("Газ есть", ok_gas)
	check("Сталагмиты есть", ok_rocks)
	var r2 := RandomNumberGenerator.new(); r2.seed = 7
	var l2 := BattleLogic.new()
	l2.setup(12, 12, r2, run.party, list, "cave")
	for c in l2.peat:
		if l2.tile_at(c) == T.FIRE:
			l2._set_tile(c, T.NONE)
	l2.turn = BattleLogic.CAVE_PEAT_EVERY
	var will: Array[Vector2i] = l2.peat_flare_cells()
	l2._cave_round_end()
	check("Раз в 3 раунда вспыхивают 2 клетки торфа", will.size() == 2 and l2.tile_at(will[0]) == T.FIRE and l2.tile_at(will[1]) == T.FIRE)
	l2.turn = BattleLogic.CAVE_PEAT_EVERY + 1
	check("В другие раунды — нет", l2.peat_flare_cells().is_empty())
	var cl: BattleLogic = l2.clone()
	check("Копия боя помнит арену и торф", cl.arena_id == "cave" and cl.peat.size() == l2.peat.size())
	check("Пещеры нет в обычном выборе арен", not BattleLogic.ARENA_POOL.has("cave"))


func _run_side() -> void:
	print("--- Забег ---")
	run.start_new_run(44)
	var node: MapNode = null
	for n in run.map:
		if n.row == 2:
			node = n
			break
	run.current = node
	check("Расщелина возможна в ряду 2", run.cave_possible())
	run.current = null
	for n in run.map:
		if n.row == 7:
			run.current = n
			break
	check("…но не в ряду 7", not run.cave_possible())
	run.current = node
	run.cave_seen = true
	check("…и не второй раз за забег", not run.cave_possible())
	run.cave_seen = false
	run.add_spirit(run.party[0], sp("fire"))
	check("…и не если дух огня уже есть", not run.cave_possible())
	run.release_spirit(run.party[0], sp("fire"))
	run.party[0].spirits.erase(sp("fire"))
	# Вход в пещеру собирает бой (саму сцену боя не грузим — подменяем переход)
	run.in_cave = true
	run.pending_enemies.clear()
	var echoes: int = run.event_echoes
	var hp_left: Array[int] = []
	for rh in run.party: hp_left.append(rh.hp)
	run.current = node
	run.finish_battle(true, hp_left)
	check("Победа в пещере: дух огня ждёт героя", run.tamed_spirit != null and run.tamed_spirit.id == "fire")
	check("+10 Отзвуков и бой считается крупным", run.event_echoes == echoes + run.CAVE_ECHOES and run.last_battle_big)
	check("Флаг пещеры снят", not run.in_cave)
