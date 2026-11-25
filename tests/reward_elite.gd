extends SceneTree

# Экран награды: карта каждому герою по очереди (окно Мага, потом окно Рыцаря),
# после элиты — ещё шаг с бесплатным улучшением и реликвией. Каждый шаг влезает в окно по высоте.
# И «Закалка» на привале: улучшение карты вместо отдыха.
# Запуск: godot --headless --path . -s tests/reward_elite.gd

const VIEW_H: float = 1080.0   # высота окна игры (project.godot)

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func _find_buttons(n: Node, text: String, out: Array[Button]) -> void:
	if n is Button and (n as Button).text == text:
		out.append(n)
	for ch in n.get_children():
		_find_buttons(ch, text, out)


func _button(scr: Node, text: String) -> Button:
	var found: Array[Button] = []
	_find_buttons(scr, text, found)
	return found[0] if not found.is_empty() else null


# Высота содержимого экрана (колонка внутри CenterContainer)
func _height(scr: Node) -> float:
	return (scr.get("_column") as Control).get_combined_minimum_size().y


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	for seed_value in [21, 5, 77]:
		for elite in [true, false]:
			run.start_new_run(seed_value)
			run.current = run.available_nodes()[0]
			run.current.type = MapNode.Type.ELITE if elite else MapNode.Type.BATTLE
			run.last_gold_reward = 30
			change_scene_to_file(run.REWARD_SCENE)
			await _frames(4)
			var scr: Node = current_scene
			var tag: String = "сид %d, %s" % [seed_value, "элита" if elite else "обычный бой"]
			var mage: RunHero = run.party[0]
			var knight: RunHero = run.party[1]
			var mage_deck: int = mage.deck.size()
			var knight_deck: int = knight.deck.size()
			# Шаг 1: Маг
			check("%s: шаг Мага влезает (%d px)" % [tag, _height(scr)], _height(scr) <= VIEW_H)
			check("%s: улучшений в награде нет" % tag, (scr.get("_bonus_buttons") as Array).is_empty() and _button(scr, "Взять") == null)
			var cards1: Array = scr.get("_all_buttons")
			check("%s: Магу 3 карты и пропуск" % tag, cards1.size() == 4)
			var next1: Button = _button(scr, "Дальше: Рыцарь")
			check("%s: «Дальше: Рыцарь» закрыт до выбора" % tag, next1 != null and next1.disabled)
			(cards1[0] as Button).pressed.emit()
			check("%s: Маг взял карту" % tag, mage.deck.size() == mage_deck + 1 and knight.deck.size() == knight_deck)
			check("%s: «Дальше» открылся" % tag, not next1.disabled)
			next1.pressed.emit()
			await _frames(4)
			# Шаг 2: Рыцарь — пропускаем
			check("%s: шаг Рыцаря влезает (%d px)" % [tag, _height(scr)], _height(scr) <= VIEW_H)
			var knight_hp_before: int = knight.hp
			knight.hp = 10
			var skip: Button = _button(scr, "Пропустить (Рыцарь +%d HP)" % run.SKIP_HEAL)
			check("%s: есть пропуск Рыцаря" % tag, skip != null)
			var next2: Button = _button(scr, "Дальше: награда элиты" if elite else "Дальше")
			check("%s: последний «Дальше» закрыт" % tag, next2 != null and next2.disabled)
			skip.pressed.emit()
			check("%s: пропуск лечит только Рыцаря" % tag, knight.hp == 10 + run.SKIP_HEAL and knight.deck.size() == knight_deck)
			knight.hp = knight_hp_before
			check("%s: «Дальше» открылся после пропуска" % tag, not next2.disabled)
			if not elite:
				continue
			next2.pressed.emit()
			await _frames(4)
			var h2: float = _height(scr)
			check("%s: шаг элиты влезает (%d px)" % [tag, h2], h2 <= VIEW_H)
			var take: Button = _button(scr, "Взять")
			var last: Button = _button(scr, "Дальше")
			check("%s: есть выбор реликвии" % tag, take != null and _button(scr, "Без реликвии") != null)
			check("%s: «Дальше» закрыт до реликвии" % tag, last != null and last.disabled)
			take.pressed.emit()
			check("%s: реликвия взята" % tag, run.corrupted_count() == 1)
			var bonus: Array = scr.get("_bonus_buttons")
			if not bonus.is_empty():
				(bonus[0] as Button).pressed.emit()
			check("%s: после реликвии и улучшения «Дальше» открыт" % tag, not last.disabled)

	# «Закалка» на привале
	run.start_new_run(9)
	change_scene_to_file(run.REST_SCENE)
	await _frames(4)
	var rest: Node = current_scene
	var forge: Button = _button(rest, "Закалка  ·  улучшить карту (вместо отдыха)")
	check("Привал: есть «Закалка»", forge != null and not forge.disabled)
	var mage2: RunHero = run.party[0]
	mage2.hp = 5
	var first: CardData = mage2.deck[0]
	rest._forge(mage2, 0, 2)
	await _frames(2)
	check("Закалка: карта улучшена веткой II", mage2.deck[0] == first.upgrade_2)
	check("Закалка: лечения нет", mage2.hp == 5)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
