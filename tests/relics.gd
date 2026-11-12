extends SceneTree
# Порченые реликвии: у каждой проверяем и плюс, и минус. Плюс — выбор и учёт в забеге.
# Запуск: godot --headless --path . -s tests/relics.gd

var run: Node
var fails: int = 0
const T := BattleLogic.Tile


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


func relic(id: String) -> RelicData:
	return load("res://resources/relics/%s.tres" % id)


# Бой с нужными реликвиями. Поле чистое, маг на C(2, 9), рыцарь на C(8, 9), враги в верхнем ряду.
func fresh(enemy_ids: Array, relic_ids: Array) -> BattleLogic:
	var list: Array[EnemyData] = []
	for id in enemy_ids: list.append(load("res://resources/enemies/%s.tres" % id))
	var rl: Array[RelicData] = []
	for id in relic_ids: rl.append(relic(id))
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list, "", BattleLogic.Objective.KILL_ALL, rl)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i + 4, 0)
	return l


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	run.start_new_run(7)
	_drowned_heart()
	_warden_brand()
	_ash_lantern()
	_ogre_tooth()
	_bog_pollen()
	_vow_of_silence()
	_run_side()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _drowned_heart() -> void:
	print("--- Сердце утопленника ---")
	var l := fresh(["goblin"], ["drowned_heart"])
	var m: BattleUnit = l.heroes[0]; var k: BattleUnit = l.heroes[1]
	check("+1 мана магу каждый ход", m.mana == m.hero_data.mana_per_turn + 1)
	check("Рыцарю мана как обычно", k.mana == k.hero_data.mana_per_turn)
	run.start_new_run(7)
	var mage_rh: RunHero = run.party[0] if run.party[0].data.id == "mage" else run.party[1]
	var before: int = mage_rh.deck.size()
	run.take_relic(relic("drowned_heart"))
	check("Минус: в колоде мага появилась «Болотная тина»",
			mage_rh.deck.size() == before + 1 and mage_rh.deck.back().id == "swamp_slime")
	run.start_new_run(7)


func _warden_brand() -> void:
	print("--- Клеймо стража ---")
	var l := fresh(["goblin"], ["warden_brand"])
	var k: BattleUnit = l.heroes[1]
	k.rage = 0; k.mana = -2
	l._apply_overheat()
	check("Перегрев 2 — рыцарю +4 ярости", k.rage == 2 * BattleLogic.WARDEN_BRAND_RAGE)
	var m: BattleUnit = l.heroes[0]
	m.rage = 0; m.mana = -2
	l._apply_overheat()
	check("Магу ярость не даёт", m.rage == 0)
	run.start_new_run(7)
	run.take_relic(relic("warden_brand"))
	for rh: RunHero in run.party:
		rh.hp = 10
		run.heal_hero(rh, 10)
	var knight_rh: RunHero = run.party[1] if run.party[1].data.id == "knight" else run.party[0]
	var mage_rh: RunHero = run.party[0] if knight_rh == run.party[1] else run.party[1]
	check("Минус: рыцарь лечится вдвое слабее (10 → +5)", knight_rh.hp == 15)
	check("Маг лечится как обычно", mage_rh.hp == 20)
	run.start_new_run(7)


func _ash_lantern() -> void:
	print("--- Пепельный фонарь ---")
	var l := fresh(["goblin"], ["ash_lantern"])
	var m: BattleUnit = l.heroes[0]
	l._cur_hero = m
	l._set_tile(C(5, 5), T.FIRE)
	l._cur_hero = null
	check("Огонь от героя горит на раунд дольше", l.fire_timers[C(5, 5)] == BattleLogic.FIRE_DURATION + 1)
	l._set_tile(C(6, 5), T.FIRE)
	check("Огонь не от героя — как обычно", l.fire_timers[C(6, 5)] == BattleLogic.FIRE_DURATION)
	check("Минус: огонь жжёт героев вдвое", l.fire_damage_for(m) == BattleLogic.FIRE_DAMAGE * 2)
	check("Врагов огонь жжёт как обычно", l.fire_damage_for(l.enemies[0]) == BattleLogic.FIRE_DAMAGE)
	var plain := fresh(["goblin"], [])
	check("Без фонаря героев огонь жжёт как обычно", plain.fire_damage_for(plain.heroes[0]) == BattleLogic.FIRE_DAMAGE)


func _ogre_tooth() -> void:
	print("--- Зуб огра ---")
	var l := fresh(["goblin"], ["ogre_tooth"])
	var m: BattleUnit = l.heroes[0]; var g: BattleUnit = l.enemies[0]
	g.cell = C(5, 5); l.rocks[C(5, 5) + Vector2i(1, 0)] = true
	var hp: int = g.hp
	l._cur_hero = m
	l._push(g, Vector2i(1, 0), 2)
	l._cur_hero = null
	check("Враг, отброшенный героем в камень, — 6 урона", g.hp == hp - BattleLogic.OGRE_TOOTH_BUMP)
	m.cell = C(2, 5); l.rocks[C(2, 5) + Vector2i(-1, 0)] = true
	m.block = 0; hp = m.hp
	l._push(m, Vector2i(-1, 0), 1)
	check("Минус: герой, врезавшийся в камень, — тоже 6", m.hp == hp - BattleLogic.OGRE_TOOTH_BUMP)
	g.cell = C(8, 4); l.rocks[C(8, 4) + Vector2i(1, 0)] = true
	hp = g.hp
	l._push(g, Vector2i(1, 0), 1)
	check("Враг врезался не от героя — обычные 4", g.hp == hp - BattleLogic.BUMP_DAMAGE)


func _bog_pollen() -> void:
	print("--- Болотная пыльца ---")
	var a := _gas_count(["bog_pollen"])
	var b := _gas_count([])
	check("Минус: газа на поле на 2 клетки больше (%d против %d)" % [a, b], a == b + BattleLogic.POLLEN_EXTRA_GAS)
	var l := fresh(["goblin"], ["bog_pollen"])
	var m: BattleUnit = l.heroes[0]; var g: BattleUnit = l.enemies[0]
	l._gas_hit(m)
	check("Газ не отравляет героя", m.poison == 0)
	l._gas_hit(g)
	check("Врага газ отравляет", g.poison == BattleLogic.GAS_POISON)


# Сколько газа на поле в начале боя при одинаковом сиде
func _gas_count(relic_ids: Array) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var rl: Array[RelicData] = []
	for id in relic_ids: rl.append(relic(id))
	var list: Array[EnemyData] = [load("res://resources/enemies/goblin.tres")]
	var l := BattleLogic.new()
	l.setup(12, 12, rng, run.party, list, "grove", BattleLogic.Objective.KILL_ALL, rl)
	var n: int = 0
	for c: Vector2i in l.tiles:
		if l.tiles[c] == T.GAS:
			n += 1
	return n


func _vow_of_silence() -> void:
	print("--- Обет тишины ---")
	for with_vow: bool in [true, false]:
		var l := fresh(["goblin_shaman", "wolf"], ["vow_of_silence"] if with_vow else [])
		var m: BattleUnit = l.heroes[0]; var w: BattleUnit = l.enemies[1]
		w.cell = m.cell + Vector2i(0, -2); w.hp = 3
		var hand: Array[CardData] = [load("res://resources/cards/m_spark.tres")]
		m.hand = hand; m.mana = 5
		l.play_card(m, 0, w.cell)
		if with_vow:
			check("Заклинание мага не лечит врагов шаманом", w.hp == 1)
		else:
			check("Без обета шаман лечит врагов", w.hp > 1)
	var l2 := fresh(["goblin"], ["vow_of_silence"])
	var m2: BattleUnit = l2.heroes[0]; var k2: BattleUnit = l2.heroes[1]
	check("Минус: маг не может удерживать карты", l2.keep_limit(m2) == 0 and not l2.toggle_keep(m2, 0))
	check("Рыцарь удерживает как обычно", l2.keep_limit(k2) == BattleLogic.KEEP_LIMIT and l2.toggle_keep(k2, 0))


func _run_side() -> void:
	print("--- Реликвии в забеге ---")
	run.start_new_run(7)
	check("В игре 6 реликвий", run.all_relics().size() == 6)
	var offer: Array[RelicData] = run.roll_relics(3)
	check("Выбор из трёх разных", offer.size() == 3 and offer[0].id != offer[1].id and offer[1].id != offer[2].id)
	run.take_relic(offer[0])
	check("Взятую реликвию больше не предлагают", not run.roll_relics(6).any(
			func(r: RelicData) -> bool: return r.id == offer[0].id))
	for r in run.roll_relics(6):
		run.take_relic(r)
	check("Больше 4 реликвий не взять", run.relics.size() == run.MAX_RELICS and not run.can_take_relic())
	run.start_new_run(7)
	check("Новый забег — без реликвий", run.relics.is_empty())
