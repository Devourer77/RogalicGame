extends SceneTree

# События: общий разбор наград (ui/event_screen.gd). Для каждого выбора с шагами «effects» проверяет,
# что HP, золото, колоды и Отзвуки меняются ровно так, как записано; подписи кнопок; блокировку
# по золоту; что цена в HP не убивает; что события не повторяются за забег.
# Запуск: godot --headless --path . -s tests/events.gd

var SCREEN: GDScript

var fails := 0
var run


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func _initialize() -> void:
	await process_frame
	run = root.get_node("Run")
	SCREEN = load("res://ui/event_screen.gd")
	_labels()
	await _all_options()
	_rules()
	await _removal_flow()
	await _cancel_flow()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _labels() -> void:
	print("--- Подписи ---")
	for e: Dictionary in SCREEN.EVENTS:
		for o: Dictionary in e["options"]:
			print("  [%s] %s" % [e["title"], SCREEN.option_label(o)])
	var o: Dictionary = SCREEN.EVENTS[7]["options"][0]
	check("Повозка: «Рыцарь −7 HP → Рыцарю редкая карта»", SCREEN.option_label(o).contains("Рыцарь −7 HP → Рыцарю редкая карта"))


# Новый экран события (сцена целиком), отряд с половиной HP — чтобы лечение было видно
func _screen() -> Control:
	var s: Control = load("res://ui/event_screen.tscn").instantiate()
	root.add_child(s)
	await process_frame
	return s


func _snapshot() -> Dictionary:
	var d: Dictionary = {"gold": run.gold, "echoes": run.event_echoes, "relics": run.relics.size()}
	for rh in run.party:
		d[rh.data.id + "_hp"] = rh.hp
		d[rh.data.id + "_deck"] = rh.deck.size()
	return d


func _all_options() -> void:
	print("--- Каждый выбор ---")
	for e: Dictionary in SCREEN.EVENTS:
		for o: Dictionary in e["options"]:
			if o.has("action"):
				continue
			run.start_new_run(7)
			run.gold = 100
			for rh in run.party:
				rh.hp = rh.data.max_hp / 2
			var s: Control = await _screen()
			var before: Dictionary = _snapshot()
			s._choose(o)
			var removed: int = 0
			while _overlay_open(s):
				# убрать карту: игрок нажал первую карту
				var rh_id: String = s._last_remove
				var old: Array = s.get_children().filter(func(c): return c is ColorRect)
				s._remove(s._hero(rh_id), 0)   # игрок нажал первую карту — окно закрывается
				for c in old:
					s.remove_child(c)
					c.free()
				removed += 1
				if removed > 5: break
			var after: Dictionary = _snapshot()
			var ok: bool = _matches(o, before, after, s)
			check("%s · %s" % [e["title"], o["label"]], ok)
			s.queue_free()
			await process_frame


func _overlay_open(s: Control) -> bool:
	for c in s.get_children():
		if c is ColorRect:
			return true
	return false


# Кто ждёт удаления карты (последний шаг remove перед паузой)
func _pending_remove(s: Control) -> String:
	var who: String = s._last_remove
	for c in s.get_children():
		if c is ColorRect:
			s.remove_child(c)   # окно выбора закрыто нажатием на карту
			c.free()
	return who


# Изменения совпадают с шагами (для случайного исхода — с одним из двух)
func _matches(o: Dictionary, before: Dictionary, after: Dictionary, s: Control) -> bool:
	var variants: Array = []
	if o.has("chance"):
		variants.append(o.get("effects", []) + o["win"].get("effects", []))
		variants.append(o.get("effects", []) + o["lose"].get("effects", []))
	else:
		variants.append(o.get("effects", []))
	for steps: Array in variants:
		var want: Dictionary = before.duplicate()
		for st: Dictionary in steps:
			if st.has("gold"):
				want["gold"] += int(st["gold"])
			if st.has("echoes"):
				want["echoes"] += int(st["echoes"])
			if st.has("relic"):
				want["relics"] += 1
			if st.has("card"):
				var who: String = st["card"] if st["card"] != "random" else s._random.data.id
				want[who + "_deck"] += 1
			if st.has("remove"):
				want[st["remove"] + "_deck"] -= 1
			if st.has("hp"):
				var ids: Array = ["knight", "mage"] if st["who"] == "all" else [st["who"] if st["who"] != "random" else s._random.data.id]
				for id: String in ids:
					want[id + "_hp"] = maxi(1, want[id + "_hp"] + int(st["hp"]))
		if want == after:
			return true
	print("    было %s\n    стало %s" % [before, after])
	return false


func _rules() -> void:
	print("--- Правила ---")
	run.start_new_run(8)
	run.gold = 5
	var lamp: Dictionary = SCREEN.EVENTS[8]["options"][1]
	check("Без золота «Чинить заслонку» не нажать", SCREEN.blocked_reason(lamp) != "")
	run.gold = 50
	check("С золотом — можно", SCREEN.blocked_reason(lamp) == "")
	var rh = run.party[0]
	rh.hp = 3
	rh.lose_hp(7)
	check("Цена в HP оставляет 1 HP", rh.hp == 1)
	run.start_new_run(9)
	var titles: Dictionary = {}
	var repeats: int = 0
	for i in 8:
		var s: Control = load("res://ui/event_screen.tscn").instantiate()
		root.add_child(s)
		var t: String = s._title
		if titles.has(t): repeats += 1
		titles[t] = true
		s.queue_free()
	check("8 событий подряд в забеге без повторов", repeats == 0)
	var rare: CardData = run.event_card(run.party[0], true)
	var normal: CardData = run.event_card(run.party[0], false)
	check("Редкая карта события — ★, обычная — не ★", rare.is_rare and not normal.is_rare)


func _removal_flow() -> void:
	print("--- Удаление карты ---")
	run.start_new_run(10)
	var mage = null
	for rh in run.party:
		if rh.data.id == "mage": mage = rh
	var s: Control = await _screen()
	var o: Dictionary = SCREEN.EVENTS[10]["options"][0]   # Круг грибов: Маг входит
	var deck_before: int = mage.deck.size()
	s._choose(o)
	check("Выбор ждёт, пока игрок уберёт карту", _overlay_open(s) and s._steps.size() == 1)
	var gone: String = mage.deck[2].title
	s._remove(mage, 2)
	check("Убрана выбранная карта, потом дана новая", mage.deck.size() == deck_before and s._lines.any(func(l): return l.contains(gone)))
	s.queue_free()
	while mage.deck.size() > run.MIN_DECK_SIZE:
		mage.deck.remove_at(0)
	s = await _screen()
	s._choose(o)
	check("Колода 5 карт — удаление пропускается", not _overlay_open(s) and s._steps.is_empty())
	s.queue_free()


# «Передумал»: окно закрыли без выбора — событие доходит до итога, карта не убрана
func _cancel_flow() -> void:
	print("--- Передумал ---")
	run.start_new_run(11)
	var s: Control = await _screen()
	var mage = s._hero("mage")
	var deck_before: int = mage.deck.size()
	s._choose(SCREEN.EVENTS[10]["options"][0])
	for c in s.get_children():
		if c is ColorRect:
			c.queue_free()
	await process_frame
	await process_frame
	check("Передумал: карта осталась, новая дана, событие закончилось", mage.deck.size() == deck_before + 1 \
			and s._lines.any(func(l): return l.contains("не убрали")))
	s.queue_free()
