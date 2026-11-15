extends SceneTree

# «Рана» за павшего героя (claude/тз-сложность-боя.md, задача 4).
# Запуск: godot --headless --path . -s tests/wound.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(5)
	run.current = run.map[0]
	var a = run.party[0]
	var b = run.party[1]
	var deck_a: int = a.deck.size()
	var deck_b: int = b.deck.size()
	var hp_left: Array[int] = [0, 10]
	run.finish_battle(true, hp_left)
	check("Павший встаёт с 1 HP", a.hp == 1)
	check("Павшему — одна Рана, второму — ничего", a.deck.size() == deck_a + 1 and b.deck.size() == deck_b
			and run.wound_count(a) == 1 and run.wound_count(b) == 0)
	check("Экран награды знает, кто ранен", run.last_wounded.size() == 1 and run.last_wounded[0] == a.data.title)
	var both: Array[int] = [0, 0]
	run.current = run.map[0]
	run.finish_battle(true, both)
	check("Второе падение — вторая Рана, у обоих", run.wound_count(a) == 2 and run.wound_count(b) == 1)

	# В бою: Рану нельзя сыграть, сброс «в ноги» шагов не даёт
	var l := BattleLogic.new()
	var enemies: Array[EnemyData] = [load("res://resources/enemies/goblin.tres")]
	l.setup(12, 12, run.rng, run.party, enemies)
	l.start()
	var h: BattleUnit = l.heroes[0]
	var hand: Array[CardData] = [load(run.WOUND_CARD), h.hand[0]]
	h.hand = hand
	h.mana = 3
	check("Рану нельзя сыграть", not l.can_play(h, 0) and l.can_play(h, 1))
	check("Рану не выбрать целью", l.get_card_targets(h, 0).is_empty() or not l.can_play(h, 0))
	var moves: int = h.moves_left
	l.scrap_card(h, 0)
	check("Сброс Раны «в ноги» шагов не даёт", h.moves_left == moves and h.hand.size() == 1)

	# Привал: «Перевязка» убирает все Раны одного героя, без лечения
	var hp_a: int = a.hp
	var removed: int = run.bandage(a)
	check("Перевязка убрала 2 Раны", removed == 2 and run.wound_count(a) == 0 and a.hp == hp_a)
	check("У второго Рана осталась", run.wound_count(b) == 1)
	# Улучшить Рану нельзя, в наградах её нет
	var wound: CardData = load(run.WOUND_CARD)
	check("Рану нельзя улучшить", not run.can_upgrade(wound))
	var in_pool: bool = false
	for i in 50:
		for c in run.roll_cards(b, 3):
			in_pool = in_pool or c.unplayable
	check("Раны нет в наградах", not in_pool)
	# Экран привала: кнопка «Перевязка» есть только у раненого
	for i in 5: await process_frame   # переход на экран награды из finish_battle уже прошёл
	change_scene_to_file("res://ui/rest_screen.tscn")
	for i in 5: await process_frame
	var texts: Array = []
	_collect(current_scene, texts)
	check("На привале есть «Перевязка» Рыцаря/Мага с Раной", texts.any(func(t): return t.contains("Перевязка: %s" % b.data.title)))
	check("…и нет у героя без Ран", not texts.any(func(t): return t.contains("Перевязка: %s" % a.data.title)))
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _collect(n: Node, out: Array) -> void:
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_collect(c, out)
