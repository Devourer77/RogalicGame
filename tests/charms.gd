extends SceneTree
# Обереги хаба (resources/relics/charm_*.tres): у каждого проверяем, что он делает в бою или в забеге,
# и что без него этого нет. Для «Точильного камня» — ещё и что точный предпросмотр карты показывает +3.
# Запуск: godot --headless --path . -s tests/charms.gd

var run: Node
var meta: Node
var fails: int = 0


func C(col: int, row: int) -> Vector2i:
	return HexMath.from_column(col, row)


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		fails += 1


# Бой с нужными оберегами. Поле чистое, маг на C(2, 9), рыцарь на C(8, 9), враги в верхнем ряду.
func fresh(enemy_ids: Array, charm_ids: Array) -> BattleLogic:
	run.start_new_run(7)   # одинаковый сид — одинаковые руки с оберегом и без
	var list: Array[EnemyData] = []
	for id in enemy_ids:
		list.append(load("res://resources/enemies/%s.tres" % id))
	var ids: Array[String] = []
	ids.assign(charm_ids)
	var l := BattleLogic.new()
	l.setup(12, 12, run.rng, run.party, list, "", BattleLogic.Objective.KILL_ALL, ids)
	l.rocks.clear(); l.tiles.clear(); l.objects.clear(); l.fire_timers.clear()
	l.start()
	l.heroes[0].cell = C(2, 9); l.heroes[1].cell = C(8, 9)
	for i in l.enemies.size():
		l.enemies[i].cell = C(i + 4, 0)
	return l


func hero(l: BattleLogic, id: String) -> BattleUnit:
	for h in l.heroes:
		if h.hero_data.id == id:
			return h
	return null


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	meta = root.get_node("Meta")
	_all_charms_listed()
	_amulet()
	_flint()
	_bell()
	_horn()
	_shard()
	_whetstone()
	_run_charms()
	print("\nИтог: %s" % ("все проверки пройдены" if fails == 0 else "провалено: %d" % fails))
	quit(1 if fails > 0 else 0)


func _all_charms_listed() -> void:
	print("--- Список оберегов ---")
	check("Оберегов 10", meta.CHARMS.size() == 10)
	for c: RelicData in meta.CHARMS:
		check("%s: есть название, описание и значок" % c.id, c.title != "" and c.desc != "" and c.icon != "")


func _amulet() -> void:
	print("--- Ладанка ученика ---")
	check("С ладанкой маг начинает бой с 1 зарядом", hero(fresh(["goblin"], ["charm_amulet"]), "mage").charge == 1)
	check("Без неё — 0", hero(fresh(["goblin"], []), "mage").charge == 0)


func _flint() -> void:
	print("--- Огниво ордена ---")
	var l := fresh(["goblin"], ["charm_flint"])
	var m: BattleUnit = hero(l, "mage")
	var plain := fresh(["goblin"], [])
	var pm: BattleUnit = hero(plain, "mage")
	var i: int = -1
	for n in m.hand.size():
		if m.hand[n].cost > 0:
			i = n
			break
	check("В руке мага есть карта с ценой", i >= 0)
	if i < 0:
		return
	check("Первая карта мага дешевле на 1", l.card_cost(m, i) == plain.card_cost(pm, i) - 1)
	check("Рыцарю огниво не помогает", l.card_cost(hero(l, "knight"), 0) == plain.card_cost(hero(plain, "knight"), 0))


func _bell() -> void:
	print("--- Медный бубенец ---")
	var l := fresh(["goblin"], ["charm_bell"])
	var plain := fresh(["goblin"], [])
	for id in ["mage", "knight"]:
		check("%s: в 1-м раунде +1 шаг" % id, hero(l, id).moves_left == hero(plain, id).moves_left + 1)


func _horn() -> void:
	print("--- Рог дозорного ---")
	var l := fresh(["goblin"], ["charm_horn"])
	var plain := fresh(["goblin"], [])
	check("Рыцарь начинает бой с +4 блока", hero(l, "knight").block == hero(plain, "knight").block + 4)
	check("Магу рог блока не даёт", hero(l, "mage").block == hero(plain, "mage").block)


func _shard() -> void:
	print("--- Осколок ученика ---")
	var l := fresh(["goblin"], ["charm_shard"])
	var plain := fresh(["goblin"], [])
	check("Маг в 1-м раунде берёт на 1 карту больше",
			hero(l, "mage").hand.size() == hero(plain, "mage").hand.size() + 1)
	check("Рыцарь — как обычно", hero(l, "knight").hand.size() == hero(plain, "knight").hand.size())


# Первая карта рыцаря с уроном, которую можно сыграть по врагу enemy. Возвращает [индекс, клетка] или [].
func _knight_hit(l: BattleLogic, k: BattleUnit, enemy: BattleUnit) -> Array:
	for i in k.hand.size():
		if k.hand[i].damage <= 0 or not l.can_play(k, i):
			continue
		for d: Vector2i in HexMath.DIRS:
			for step in range(1, 5):
				var target: Vector2i = k.cell + d * step
				if l.get_card_area(k, i, target).has(enemy.cell):
					var p: Dictionary = l.preview_card(k, i, target)
					if p["ok"] and (p["units"] as Dictionary).has(enemy.id):
						return [i, target]
	return []


# Сколько урона по здоровью покажет точный предпросмотр (блок врага снят — считаем чистый урон)
func _shown(l: BattleLogic, k: BattleUnit, enemy: BattleUnit, hit: Array) -> int:
	var p: Dictionary = l.preview_card(k, hit[0], hit[1])
	var info: Dictionary = (p["units"] as Dictionary).get(enemy.id, {})
	return int(info.get("dealt", 0)) + int(info.get("absorbed", 0))


func _whetstone() -> void:
	print("--- Точильный камень ---")
	var l := fresh(["ogre"], ["charm_whetstone"])
	var plain := fresh(["ogre"], [])
	for b: BattleLogic in [l, plain]:
		var k: BattleUnit = hero(b, "knight")
		k.cell = C(5, 5)
		b.enemies[0].cell = k.cell + HexMath.DIRS[0]   # огр вплотную: его 60 HP хватит на два удара
		b.enemies[0].block = 0
		k.mana = 9   # хватит на две карты
	var k: BattleUnit = hero(l, "knight")
	var ogre: BattleUnit = l.enemies[0]
	var hit: Array = _knight_hit(l, k, ogre)
	var plain_hit: Array = _knight_hit(plain, hero(plain, "knight"), plain.enemies[0])
	check("У рыцаря есть удар по огру", not hit.is_empty() and not plain_hit.is_empty())
	if hit.is_empty() or plain_hit.is_empty():
		return
	var with_stone: int = _shown(l, k, ogre, hit)
	var without: int = _shown(plain, hero(plain, "knight"), plain.enemies[0], plain_hit)
	check("Предпросмотр первой карты показывает +3 (%d против %d)" % [with_stone, without], with_stone == without + 3)
	var hp: int = ogre.hp
	l.play_card(k, hit[0], hit[1])
	check("Настоящий удар совпал с предпросмотром", hp - ogre.hp == with_stone)
	ogre.block = 0
	var second: Array = _knight_hit(l, k, ogre)
	if second.is_empty():
		print("     (второй карты с уроном в руке нет — проверка повтора пропущена)")
		return
	var card: CardData = k.hand[second[0]]
	var shown: int = _shown(l, k, ogre, second)
	check("Вторая карта уже без +3 (%d, в карте %d)" % [shown, l.card_base_damage(card)], shown < l.card_base_damage(card) + 3 or l.card_base_damage(card) == 0)


func _run_charms() -> void:
	print("--- Обереги забега ---")
	meta.save_path = "user://progress_test_charms.cfg"
	meta.reset()
	run.start_new_run(7)
	var gold: int = run.gold   # без оберегов
	for c: RelicData in meta.CHARMS:
		meta.unlock_charm(c.id)
	meta.charms_chosen = ["charm_purse"] as Array[String]
	run.start_new_run(7)
	check("Кошель дозорного: +40 золота на старте", run.gold == gold + 40)

	meta.charms_chosen = ["charm_bandage"] as Array[String]
	run.start_new_run(7)
	var first: float = run.rest_percent()
	run.rest_used = true
	check("Чистый бинт: первый привал лечит вдвое больше", is_equal_approx(first, run.rest_percent() * 2.0))

	meta.charms_chosen = ["charm_decree"] as Array[String]
	run.start_new_run(7)
	run.last_battle_big = true
	check("Указ коменданта: после элиты 4 карты", run.reward_card_count() == 4)
	run.last_battle_big = false
	check("…после обычного боя — 3", run.reward_card_count() == 3)

	meta.charms_chosen = ["charm_candle"] as Array[String]
	run.start_new_run(7)
	run.finish_battle(true, [0, 20] as Array[int])
	check("Свеча у колокола: павший встаёт с 5 HP", run.party[0].hp == 5)
	run.finish_battle(true, [0, 20] as Array[int])
	check("…второй раз — уже с 1 HP", run.party[0].hp == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(meta.save_path))
