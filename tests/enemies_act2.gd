extends SceneTree

# Особое поведение врагов акта 2: черты фракций и одиночки (статус.md, «Враги без упрощений»).
# Запуск: godot --headless --path . -s tests/enemies_act2.gd

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
	run.start_new_run(77)
	_machines()
	_sleeper()
	_blind()
	_vulture()
	_jelly()
	_brand()
	_lob_and_shock()
	_half_spirit()
	_fuzz_like()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _machines() -> void:
	print("--- Механизмы: замыкание ---")
	var l := fresh(["sphere_walker_fire", "goblin"]); var m: BattleUnit = l.heroes[0]; var e: BattleUnit = l.enemies[0]
	e.cell = m.cell + UL * 3; e.wet = 2
	var bolt: CardData = null
	for id in ["storm_m2", "storm_m3", "storm_k2"]:
		var c: CardData = card(id)
		if c.element == CardData.Element.LIGHTNING and c.damage > 0:
			bolt = c
			break
	check("Есть карта молнии", bolt != null)
	if bolt == null:
		return
	var hand: Array[CardData] = [bolt]
	m.hand = hand
	l.play_card(m, 0, e.cell)
	check("Мокрый механизм от молнии — замыкание", e.stunned == 1 or not e.is_alive())
	if e.is_alive():
		var cl: BattleLogic = l.clone()
		check("Копия боя помнит замыкание", cl.enemies[0].stunned == 1)
		var plan: Dictionary = EnemyAI.choose(l, e, l.enemy_attack(e))
		check("Замкнутый не ходит и не бьёт", plan["cell"] == e.cell and plan["dir"] == Vector2i.ZERO)
		var at: Vector2i = e.cell
		l.end_turn()
		check("После хода врагов замыкание прошло, враг стоял", e.stunned == 0 and e.cell == at)
	l = fresh(["sphere_walker_fire"]); e = l.enemies[0]; e.wet = 0
	l._lightning_now = true; l._card_damage(e, 1, false); l._lightning_now = false
	check("Сухой механизм не замыкает", e.stunned == 0)
	l = fresh(["goblin"]); e = l.enemies[0]; e.wet = 2
	l._short_circuit(e)
	check("Не механизм — не замыкает", e.stunned == 0)
	l = fresh(["repair_bot", "sphere_walker_fire"]); var bot: BattleUnit = l.enemies[0]; var w: BattleUnit = l.enemies[1]
	w.cell = bot.cell + Vector2i(1, 0); w.hp = 3
	l._enemy_aura(bot, bot.data.cycle[0])
	check("Ремонтник чинит механизм (+4 HP)", w.hp == 7)


func _sleeper() -> void:
	print("--- Спящая сфера ---")
	var l := fresh(["sleeping_sphere"]); var e: BattleUnit = l.enemies[0]
	check("Спит с начала боя", e.asleep)
	var at: Vector2i = e.cell
	l.end_turn()
	check("Спит: не ходит", e.cell == at and e.asleep)
	l._damage(e, 1)
	check("Удар будит", not e.asleep)
	l = fresh(["sleeping_sphere"]); e = l.enemies[0]
	l.heroes[0].cell = e.cell + Vector2i(0, 1)
	l._start_enemy_phase()
	check("Герой вплотную — просыпается", not e.asleep)
	var hidden_ok: bool = true
	for sd in 10:
		var r := RandomNumberGenerator.new(); r.seed = 500 + sd
		var list: Array[EnemyData] = [load("res://resources/enemies/sleeping_sphere.tres") as EnemyData,
				load("res://resources/enemies/sleeping_sphere.tres") as EnemyData, load("res://resources/enemies/repair_bot.tres") as EnemyData]
		var b := BattleLogic.new(); b.setup(12, 12, r, run.party, list, "sphere_hall")
		for u in b.enemies:
			if not u.asleep:
				continue
			var near: bool = false
			for n in HexMath.neighbors(u.cell):
				if b.object_at(n) != O.NONE:
					near = true
			if not near:
				hidden_ok = false
	check("В Зале сфер спящие встают среди постаментов", hidden_ok)
	check("В снимке намерение «Спит», пока спит", fresh(["sleeping_sphere"]).snapshot(fresh(["sleeping_sphere"]).enemies[0])["intent"] == "Спит")


func _blind() -> void:
	print("--- Слепыш ---")
	var l := fresh(["blind_lurker"]); var e: BattleUnit = l.enemies[0]
	l.heroes[0].moved_cells = 0; l.heroes[1].moved_cells = 3
	check("Идёт к тому, кто прошёл больше", EnemyAI._prey(l, e) == l.heroes[1])
	l.heroes[0].moved_cells = 4
	check("Шумнее стал другой — к нему", EnemyAI._prey(l, e) == l.heroes[0])
	var m: BattleUnit = l.heroes[0]
	m.moves_left = 3; m.moved_cells = 0
	var targets: Dictionary = l.get_move_targets(m)
	var far: Vector2i = m.cell
	for c: Vector2i in targets:
		if targets[c].size() > targets.get(far, [m.cell]).size():
			far = c
	l.move_hero(m, far)
	check("Шаги героя считаются", m.moved_cells == targets[far].size() - 1)


func _vulture() -> void:
	print("--- Падальщик ---")
	var l := fresh(["ash_vulture", "goblin"]); var v: BattleUnit = l.enemies[0]
	v.cell = C(5, 2)
	for d in HexMath.DIRS:
		l.rocks[v.cell + d] = true
	var walker: Dictionary = l.reachable_cells(l.enemies[1], 4)
	var fly: Dictionary = l.reachable_cells(v, 4)
	check("Окружён камнями — всё равно взлетает", fly.size() > 5)
	var lands_ok: bool = true
	for c: Vector2i in fly:
		if c != v.cell and (l.rocks.has(c) or l.unit_at(c) != null):
			lands_ok = false
	check("Садится только на свободные клетки", lands_ok)
	check("Падальщик — тактик (раненый отходит)", v.data.tactician and v.data.ai_style == EnemyData.AiStyle.HUNTER)


func _jelly() -> void:
	print("--- Медуза ---")
	var l := fresh(["kettle_jelly"]); var j: BattleUnit = l.enemies[0]
	l.tiles[j.cell] = T.WATER
	l.tiles[j.cell + Vector2i(0, 1)] = T.WATER
	var cells: Dictionary = l.reachable_cells(j, 3)
	var only_water: bool = true
	for c: Vector2i in cells:
		if not l._is_water_cell(c):
			only_water = false
	check("Ходит только по воде", only_water and cells.size() == 2)
	var r := RandomNumberGenerator.new(); r.seed = 3
	var list: Array[EnemyData] = [load("res://resources/enemies/kettle_jelly.tres") as EnemyData]
	var b := BattleLogic.new(); b.setup(12, 12, r, run.party, list, "ashfield")
	check("В начале боя сидит в луже", b._is_water_cell(b.enemies[0].cell))
	l = fresh(["kettle_jelly"]); j = l.enemies[0]; l.tiles.erase(j.cell)
	var hp: int = j.hp
	l.end_turn()
	check("На суше сохнет (−2 HP за раунд)", j.hp <= hp - l.JELLY_DRY_DAMAGE)


func _brand() -> void:
	print("--- Клеймо Культа ---")
	var l := fresh(["cult_brander", "goblin"]); var b: BattleUnit = l.enemies[0]; var g: BattleUnit = l.enemies[1]; var m: BattleUnit = l.heroes[0]
	var atk: EnemyAttackData = b.data.cycle[0]
	check("У Клеймителя удар ставит клеймо", atk.brand)
	b.cell = m.cell + UL * 2
	m.block = 0; var hp: int = m.hp
	l._enemy_strike(b, atk, UL * -1)
	check("Клеймо поставлено", m.brand == 1)
	g.cell = m.cell + UR
	hp = m.hp
	l._enemy_strike(g, l.enemy_attack(g), -UR)
	check("Следующий удар по клеймёному сильнее на %d, метка сгорела" % l.BRAND_BONUS,
			hp - m.hp == l.enemy_attack(g).damage + l.BRAND_BONUS and m.brand == 0)


func _lob_and_shock() -> void:
	print("--- Бутыль Поджигателя и разряд сферника ---")
	var l := fresh(["scav_arsonist"]); var a: BattleUnit = l.enemies[0]; var m: BattleUnit = l.heroes[0]
	var atk: EnemyAttackData = a.data.cycle[0]
	a.cell = m.cell + UL * 3
	var cells: Array[Vector2i] = l._attack_cells(a, atk, a.cell, -UL)
	check("Бутыль бьёт цель и клетки вокруг (7)", cells.size() == 7 and cells.has(m.cell))
	l.objects[m.cell + UR] = O.BARREL
	l._enemy_strike(a, atk, -UL)
	check("Бочка рядом с целью вспыхнула", l.object_at(m.cell + UR) == O.NONE)
	l = fresh(["sphere_walker_storm"]); var s: BattleUnit = l.enemies[0]; m = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	s.cell = m.cell + UL * 3
	l.tiles[m.cell] = T.WATER
	k.cell = m.cell + UR
	l.tiles[k.cell] = T.WATER
	var hit: Array[Vector2i] = l._attack_cells(s, s.data.cycle[0], s.cell, -UL)
	check("Разряд уходит по луже на соседа", hit.has(k.cell) and hit.has(m.cell))


func _half_spirit() -> void:
	print("--- Полусвободный дух ---")
	var l := fresh(["half_spirit", "goblin"]); var h: BattleUnit = l.enemies[0]
	h.hp = 14; h.max_hp = 14
	check("Сфера держит 3 удара", h.shell_hits == 3)
	l._damage(h, 2); l._damage(h, 2)
	check("Два удара — сфера ещё цела", h.shell_hits == 1)
	l._damage(h, 2)
	check("Третий — сфера разбита", h.shell_hits == 0)
	l._damage(h, 99)
	check("Разбил сферу и победил духа — он свободен", l.freed_spirit)
	l = fresh(["half_spirit"]); h = l.enemies[0]
	l._damage(h, 99)
	check("Убит одним ударом — улетает", not l.freed_spirit)
	run.party[0].spirits.clear(); run.party[1].spirits.clear()
	check("Полусвободный дух — Омутник, если его нет в отряде", run._freed_spirit_pick() != null and run._freed_spirit_pick().id == "tide")


# Короткая проверка: бои с новыми врагами доигрываются без ошибок, прогноз совпадает с ходом
func _fuzz_like() -> void:
	print("--- Бои с новыми врагами ---")
	var squads: Array = [["sleeping_sphere", "sphere_walker_storm", "repair_bot"], ["blind_lurker", "glass_spitter"],
			["ash_vulture", "scav_arsonist", "scav_crossbow"], ["kettle_jelly", "cult_brander", "cultist"], ["half_spirit", "sphere_walker_water"]]
	var ok: bool = true
	var mismatch: int = 0
	for sq in squads:
		for sd in 4:
			var r := RandomNumberGenerator.new(); r.seed = 900 + sd
			var list: Array[EnemyData] = []
			for id in sq: list.append(load("res://resources/enemies/%s.tres" % id))
			var b := BattleLogic.new(); b.setup(12, 12, r, run.party, list, "springs" if sq.has("kettle_jelly") else "")
			b.start()
			for rnd in 8:
				if b.is_over:
					break
				var forecast: BattleLogic = b.clone()
				forecast.end_turn()
				b.end_turn()
				for i in mini(b.enemies.size(), forecast.enemies.size()):
					if b.enemies[i].cell != forecast.enemies[i].cell or b.enemies[i].hp != forecast.enemies[i].hp:
						mismatch += 1
	check("Бои с новыми врагами идут, прогноз совпадает (расхождений %d)" % mismatch, ok and mismatch == 0)
