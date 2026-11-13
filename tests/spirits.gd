extends SceneTree

# Духи этапа 3: Омутник, Грозовик, их пара, логово, Зов и пассивы (тз-духи.md, тз-карты.md 7–9).
# Запуск: godot --headless --path . -s tests/spirits.gd

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


# Карта духа по id: "tide_m1", "tide_m1+2", "mix_tide_storm_k2"
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
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i * 2, 0)
		l.enemies[i].block = 0
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
	run.start_new_run(31)
	_data()
	_run_side()
	_battle_side()
	_tide_cards()
	_storm_cards()
	_mixed_cards()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> void:
	print("--- Данные духов ---")
	for id in ["tide", "storm"]:
		var s: SpiritData = sp(id)
		check("%s: по 6 карт каждому, Зов и враг" % id, s.mage_cards.size() == 6 and s.knight_cards.size() == 6 \
				and s.call_card != null and s.call_card.is_call and s.enemy != null and s.enemy.tamable)
		var ok := true
		for c in s.mage_cards + s.knight_cards:
			ok = ok and c.upgrade_1 != null and c.upgrade_2 != null and c.spirit_ids.size() == 1 and c.spirit_ids[0] == id
		check("%s: у всех карт две ветки и метка духа" % id, ok)
	check("У Омутника смешанных: 3 пары × 4", sp("tide").mixed_cards.size() == 12)


func _run_side() -> void:
	print("--- Забег ---")
	var mage: RunHero = run.party[0]; var knight: RunHero = run.party[1]
	var lair := 0
	for n in run.map:
		if n.type == MapNode.Type.LAIR: lair += 1
	check("На карте одно логово", lair == 1)
	var before: int = mage.deck.size()
	check("Дух пришёл к Магу", run.add_spirit(mage, sp("tide")))
	check("Три карты духа сразу в колоде", mage.deck.size() == before + 3 and mage.deck.has(sp("tide").mage_cards[0]))
	check("Того же духа второй раз не взять", not run.add_spirit(knight, sp("tide")))
	check("Д4–Д6 в наградах Мага", run.spirit_reward_cards(mage).size() == 3)
	check("Смешанных нет, пока нет пары", run.spirit_reward_cards(knight).size() == 0)
	run.add_spirit(knight, sp("storm"))
	check("Пара открылась: Рыцарю 3 + 2 смешанные", run.spirit_reward_cards(knight).size() == 5)
	check("Пара открылась: Магу 3 + 2 смешанные", run.spirit_reward_cards(mage).size() == 5)
	var seen_spirit := false
	for i in 200:
		for c in run.roll_cards(mage, 3):
			if not c.spirit_ids.is_empty(): seen_spirit = true
	check("Карты духов выпадают в наградах", seen_spirit)
	mage.spirits.append(sp("storm"))
	check("Слотов 2: третьего не взять", not run.can_take_spirit(mage))
	mage.spirits.pop_back()


func _battle_side() -> void:
	print("--- Бой ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	var calls := 0
	for c in m.hand: if c.is_call: calls += 1
	check("Зов Омутника в руке Мага с начала боя", calls == 1 and m.hand.size() == 6)
	var call_i: int = -1
	for i in m.hand.size(): if m.hand[i].is_call: call_i = i
	check("Зов «в ноги» не сбросить", not l.scrap_card(m, call_i))
	l.play_card(m, call_i, m.cell + UL * 3)
	check("Зов: лужи и Цепь не выросла", l.tile_at(m.cell + UL * 3) == T.WATER and l.chain_value() == 0)
	check("Зов не ушёл в сброс", not m.discard_pile.any(func(c: CardData) -> bool: return c.is_call))
	l.enemies[0].cell = C(11, 0); l.enemies[1].cell = C(10, 0)
	l.tiles[m.cell] = T.WATER
	l.end_turn()
	check("Пассив Омутника: в луже +3 блока", m.block >= 3)
	# Грозовик: по врагу в луже +2
	l = fresh(); k = l.heroes[1]; var e: BattleUnit = l.enemies[0]; e.cell = k.cell + UL
	l.tiles[e.cell] = T.WATER
	k.hand = [load("res://resources/cards/base/kb_sword.tres")] as Array[CardData]
	l.play_card(k, 0, e.cell)
	check("Пассив Грозовика: 6 + 2 по врагу в луже", e.hp == 52)
	# Логово: покорил духа — победа
	l = fresh(["spirit_tide", "goblin"]); m = l.heroes[0]
	l.enemies[0].hp = 1
	l.enemies[0].cell = m.cell + UL
	m.hand = [load("res://resources/cards/base/mb_staff.tres")] as Array[CardData]
	l.play_card(m, 0, l.enemies[0].cell)
	check("Дух покорён — бой выигран, гоблин ещё жив", l.is_over and l.won and l.enemies[1].is_alive())


func _tide_cards() -> void:
	print("--- Омутник ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	var t: Vector2i = m.cell + UL * 3
	l.tiles[t] = T.WATER
	give(m, ["tide_m1"]); play(l, m, t)
	check("Разлив: старая лужа → топь, вокруг лужи", l.tile_at(t) == T.SWAMP and l.tile_at(t + UL) == T.WATER)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3
	give(m, ["tide_m2"]); play(l, m, e.cell)
	check("Водяная плеть: 3 урона и мокнет", e.hp == 57 and l.is_wet(e))
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3
	give(m, ["tide_m4", "tide_m4", "tide_m2"]); play(l, m); play(l, m)
	play(l, m, e.cell)
	check("Водяная плеть, Цепь 2: притянула на 1", e.cell == m.cell + UL * 2)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 2; l.tiles[e.cell] = T.WATER
	give(m, ["tide_m3"]); play(l, m)
	check("Волна: враг в луже — 2 урона и толчок", e.hp == 58 and e.cell == m.cell + UL * 3)
	l = fresh(); m = l.heroes[0]; m.moves_left = 0
	l.tiles[m.cell + UL] = T.WATER; l.tiles[m.cell + UR] = T.WATER
	give(m, ["tide_m4"]); play(l, m)
	check("Течение: +1 шаг за лужу рядом", m.moves_left == 2)
	l = fresh(); m = l.heroes[0]; l.tiles[m.cell] = T.WATER
	give(m, ["tide_m5"]); play(l, m, m.cell)
	check("Пузырь: в луже 5 + 4", m.block == 9)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; t = m.cell + UL * 4; e.cell = t + UL * 2
	give(m, ["tide_m6"]); play(l, m, t)
	check("Водоворот: враг притянут, центр — трясина", HexMath.distance(e.cell, t) == 1 and l.object_at(t) == O.BOG and l.is_wet(e))
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["tide_k1", "tide_k2"]); play(l, k)
	play(l, k, e.cell)
	check("Клинок омута + Брызги: враг мокрый и отброшен", l.is_wet(e) and e.cell == k.cell + UL * 2)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 4
	give(k, ["tide_k3"]); play(l, k, e.cell)
	check("Удар прилива: позади лужи, враг ранен и мокнет", e.hp < 60 and l.is_wet(e) and l.tile_at(C(8, 9) + UL) == T.WATER)
	l = fresh(); k = l.heroes[1]; l.tiles[k.cell] = T.WATER
	give(k, ["tide_k4"]); play(l, k)
	check("Стоять в воде: 6 + 6 и провокация", k.block == 12 and k.taunt)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 4
	give(k, ["tide_k5"]); play(l, k, e.cell)
	check("Тянущая вода: притянула на 3, урона без Цепи нет", e.cell == k.cell + UL and e.hp == 60)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["tide_k6"]); play(l, k)
	check("Девятый вал: 4 урона, толчок 2, мокнет", e.hp == 56 and e.cell == k.cell + UL * 3 and l.is_wet(e))


func _storm_cards() -> void:
	print("--- Грозовик ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	e.cell = m.cell + UL * 4
	give(m, ["storm_m1", "storm_m2"]); play(l, m)
	play(l, m, e.cell)
	check("Грозовой заряд + Искра молнии: 2 + 2, заряд 3", e.hp == 56 and m.charge == 3)
	l = fresh(); m = l.heroes[0]; var e1: BattleUnit = l.enemies[0]; var e2: BattleUnit = l.enemies[1]
	e1.cell = m.cell + UL * 3; e2.cell = e1.cell + UL
	give(m, ["storm_m3"]); play(l, m, e1.cell)
	check("Цепная молния: 5 и перескок 4", e1.hp == 55 and e2.hp == 56)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 2
	give(m, ["storm_m4"]); play(l, m, m.cell + UL * 4)
	check("Шаг молнии: 3 урона и маг в конце линии", e.hp == 57 and m.cell == C(2, 9) + UL * 4)
	l = fresh(); m = l.heroes[0]; e1 = l.enemies[0]; e2 = l.enemies[1]
	var w: Vector2i = m.cell + UL * 4
	for c in [w, w + UL, w + UL * 2]: l.tiles[c] = T.WATER
	e1.cell = w + UL; e2.cell = w + UL * 2
	give(m, ["storm_m5"])
	check("Разряд в воду: только по воде", not l.get_card_targets(m, 0).has(m.cell + UR))
	play(l, m, w)
	check("Разряд в воду: бьёт всех в луже (3 + 3 мокрым)", e1.hp == 54 and e2.hp == 54)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3; e.block = 5; m.charge = 2
	give(m, ["storm_m6"]); play(l, m, e.cell)
	check("Разлом неба: 6 + 3×2 сквозь блок", e.hp == 48)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; l.tiles[e.cell] = T.WATER
	give(k, ["storm_k1"])
	play(l, k)
	k.hand = [load("res://resources/cards/base/kb_sword.tres")] as Array[CardData]
	l.play_card(k, 0, e.cell)
	check("Руна бури: удар мечом по мокрому +3 (и +2 пассив в луже)", e.hp == 60 - 6 - 3 - 2)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["storm_k2"]); play(l, k, e.cell)
	check("Громовой удар: 3", e.hp == 57)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["storm_k3"]); play(l, k)
	check("Гром и сталь: 3 вокруг", e.hp == 57)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; e.wet = 2; k.moves_left = 0
	give(k, ["storm_k4"]); play(l, k)
	k.hand = [load("res://resources/cards/base/kb_sword.tres")] as Array[CardData]
	l.play_card(k, 0, e.cell)
	check("Буревой разбег: +3 шага, удар стал молнией (+3 мокрому)", k.moves_left == 3 and e.hp == 51)
	l = fresh(); k = l.heroes[1]
	give(k, ["storm_k5"]); play(l, k)
	check("Щит-громоотвод: блок 6 и застава", k.block == 6 and k.outpost)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; var land: Vector2i = k.cell + UL * 3; e.cell = land + UL
	give(k, ["storm_k6"]); play(l, k, land)
	check("Небесный клинок: прыжок и 8 молнией", k.cell == land and e.hp == 52)


func _mixed_cards() -> void:
	print("--- Гроза над омутом ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	var t: Vector2i = m.cell + UL * 4; e.cell = t
	give(m, ["mix_tide_storm_m1"]); play(l, m, t)
	check("Половодье с грозой: лужи и молния 3 + 3", l.tile_at(t + UL) == T.WATER and e.hp == 54)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3; e.wet = 2
	give(m, ["mix_tide_storm_m2"]); play(l, m)
	check("Грозовая капель: мокрому 1 + 3", e.hp == 56)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 2; l.tiles[e.cell] = T.WATER
	give(k, ["mix_tide_storm_k1"]); play(l, k)
	check("Шоковая волна: враг в луже 4 + 3 (+2 пассив Грозовика у рыцаря)", e.hp == 60 - 4 - 3 - 2)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["mix_tide_storm_k2", "mix_tide_storm_k2"]); play(l, k, e.cell)
	var hp1: int = e.hp
	play(l, k, e.cell)
	check("Мокрая сталь: первый удар 3, второй по мокрому молнией 3 + 3 (+2 в луже)", hp1 == 57 and e.hp == hp1 - 8)
