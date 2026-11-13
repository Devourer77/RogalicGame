extends SceneTree

# Духи этапа 4: Вихорь, Хозяин трясины, 5 смешанных пар, передача и замена духа, «Клетка Венца».
# Запуск: godot --headless --path . -s tests/spirits2.gd

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
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
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
	run.start_new_run(41)
	_data()
	_wind()
	_bog()
	_pairs()
	_run_side()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _data() -> void:
	print("--- Данные ---")
	var total := 0
	for id in ["tide", "storm", "wind", "bog"]:
		var s: SpiritData = sp(id)
		total += s.mage_cards.size() + s.knight_cards.size() + s.mixed_cards.size()
		var ok := true
		for c in s.mage_cards + s.knight_cards + s.mixed_cards:
			ok = ok and c.upgrade_1 != null and c.upgrade_2 != null
		check("%s: у всех карт две ветки" % id, ok)
	check("Карт духов и смешанных — 48 + 24 = 72", total == 72)
	check("Хозяин трясины — уникальный", sp("bog").is_unique)


func _wind() -> void:
	print("--- Вихорь ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	e.cell = m.cell + UL * 2
	give(m, ["wind_m1"]); play(l, m, m.cell + UL * 3)
	check("Порыв: толчок 2", e.cell == m.cell + UL * 4)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; var e2: BattleUnit = l.enemies[1]
	var t: Vector2i = m.cell + UL * 4; e.cell = t + UL * 2; e2.cell = t + UR * 2
	give(m, ["wind_m3"]); play(l, m, t)
	check("Смерч: враги ближе к центру и ранены", HexMath.distance(e.cell, t) == 1 and e.hp == 59)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL; l.rocks[m.cell + UL * 2] = true
	give(m, ["wind_m6"]); play(l, m)
	check("Буря: столкновение вдвое (8)", e.hp == 52)
	l = fresh(); m = l.heroes[0]; var g: Vector2i = m.cell + UL * 3; l.tiles[g] = T.GAS
	give(m, ["wind_m5"]); play(l, m, g)
	check("Сдуть: газ снесло на 2", l.tile_at(g) != T.GAS and l.tile_at(g + UL * 2) == T.GAS)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["wind_k4"]); play(l, k, e.cell)
	check("Отбросить: 2 урона, толчок 3", e.hp == 58 and e.cell == k.cell + UL * 4)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; var land: Vector2i = k.cell + UL * 3; e.cell = land + UL
	give(k, ["wind_k6"]); play(l, k, land)
	check("Небесный таран: удар и толчок 2", e.hp == 57 and e.cell == land + UL * 3)
	l = fresh(); k = l.heroes[1]
	give(k, ["wind_k5"]); play(l, k)
	check("Вихрь вокруг: блок и защита", k.block == 4 and k.gust_guard == 2)


func _bog() -> void:
	print("--- Хозяин трясины ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	var t: Vector2i = m.cell + UL * 3
	give(m, ["bog_m1"]); play(l, m, t)
	check("Топь: круг стал топью", l.tile_at(t) == T.SWAMP and l.tile_at(t + UL) == T.SWAMP)
	e.cell = m.cell + UL * 4
	give(m, ["bog_m2"]); play(l, m, e.cell)
	check("Хватка тины: опутан", e.entangled >= 1)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3; l.tiles[e.cell] = T.SWAMP
	give(m, ["bog_m3"]); play(l, m)
	check("Засасывание: 3 урона и опутан", e.hp == 57 and e.entangled >= 1)
	l = fresh(); m = l.heroes[0]; t = m.cell + UL * 3; l.tiles[t] = T.SWAMP; l.tiles[t + UL] = T.SWAMP
	give(m, ["bog_m5"]); play(l, m, t)
	check("Болотный газ: топь стала газом", l.tile_at(t) == T.GAS and l.tile_at(t + UL) == T.GAS)
	l = fresh(); k = l.heroes[1]
	give(k, ["bog_k1"]); play(l, k)
	check("Тяжёлая поступь: вокруг топь, блок 4", l.tile_at(k.cell + UL) == T.SWAMP and k.block == 4)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; l.objects[k.cell + UL * 3] = O.BOG
	give(k, ["bog_k3"]); play(l, k, e.cell)
	check("Утопить: толчок в трясину — утонул, счёт утопленных", not e.is_alive() and l.drowned_count == 1)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["bog_k6"]); play(l, k, e.cell)
	check("Трясина под ним: обычный враг тонет", not e.is_alive())
	l = fresh(["ogre"]); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL; var hp: int = e.hp
	give(k, ["bog_k6"]); play(l, k, e.cell)
	check("Трясина под ним: огр не тонет, 8 урона и опутан", e.is_alive() and e.hp == hp - 8 and e.entangled >= 1)
	l = fresh(); k = l.heroes[1]; l.tiles[k.cell + UL] = T.SWAMP; l.tiles[k.cell + UR] = T.WATER
	give(k, ["bog_k5"]); play(l, k)
	check("Болотный панцирь: 4 + 2×2", k.block == 8)


func _pairs() -> void:
	print("--- Смешанные пары ---")
	var l := fresh(); var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]; var e: BattleUnit = l.enemies[0]
	e.cell = m.cell + UL * 2; l.tiles[e.cell] = T.WATER
	give(m, ["mix_tide_bog_m1"]); play(l, m)
	check("Зыбун: лужа → топь, враг опутан", l.tile_at(e.cell) == T.SWAMP and e.entangled >= 1)
	give(m, ["mix_tide_bog_m2"]); play(l, m, e.cell)
	check("Утянуть на дно: опутанному вдвое (2×(5+2))", e.hp == 60 - 14)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 2
	give(m, ["mix_tide_wind_m1"]); play(l, m, m.cell + UL * 3)
	check("Ливень: толчок и лужи на линии", e.cell == m.cell + UL * 4 and l.tile_at(m.cell + UL) == T.WATER)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 4
	give(m, ["mix_storm_bog_m2", "mix_storm_bog_m1"]); play(l, m, e.cell)
	play(l, m, e.cell)
	check("Гнилая гроза + огонёк: молния по опутанному вдвое (6)", e.hp == 54)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 2; e.entangled = 1
	give(k, ["mix_storm_bog_k2"]); play(l, k, e.cell)
	check("Разряд по корням: опутанному 2 + 2", e.hp == 56)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL * 4
	give(k, ["mix_storm_wind_k2"]); play(l, k, e.cell)
	check("Громовой рывок: 4 молнией", e.hp == 56)
	l = fresh(); m = l.heroes[0]; e = l.enemies[0]; e.cell = m.cell + UL * 3; l.tiles[e.cell] = T.GAS
	give(m, ["mix_bog_wind_m2"]); play(l, m)
	check("Гнилой ветер: газ растёкся, враг ранен и отравлен", l.tile_at(e.cell + UL) == T.GAS and e.hp < 60 and e.poison > 0)
	l = fresh(); k = l.heroes[1]; e = l.enemies[0]; e.cell = k.cell + UL
	give(k, ["mix_bog_wind_k2"]); play(l, k)
	check("Болотный вихрь: отлёт и топь", e.cell == k.cell + UL * 2 and l.tile_at(k.cell + UL) == T.SWAMP)


func _run_side() -> void:
	print("--- Забег ---")
	var mage: RunHero = run.party[0]; var knight: RunHero = run.party[1]
	run.add_spirit(mage, sp("tide"))
	run.add_spirit(knight, sp("wind"))
	check("Пара «Шторм» открыта: у Рыцаря 3 + 2", run.spirit_reward_cards(knight).size() == 5)
	var up: int = mage.deck.find(sp("tide").mage_cards[0])
	run.upgrade_card(mage, up, 2)
	check("Передача духа Рыцарю", run.transfer_spirit(mage, knight, sp("tide")))
	check("Карты Мага ушли, Рыцарь получил свои (улучшение сохранилось)",
			not mage.deck.has(sp("tide").mage_cards[0]) and knight.deck.has(sp("tide").knight_cards[0].upgrade_2) and knight.deck.has(sp("tide").knight_cards[1]))
	run.release_spirit(knight, sp("tide"))
	check("Отпустил — карт духа не осталось", knight.deck.all(func(c: CardData) -> bool: return not c.spirit_ids.has("tide")))
	check("Клетка Венца предлагает духа, которого нет", run.cage_spirit() != null and not run.party_has_spirit(run.cage_spirit().id))
	run.pending_encounter = load("res://resources/encounters/elite_treant.tres")
	check("Хозяин трясины живёт в элите с корягачом", run.bog_spirit_offered())
