extends SceneTree

# Экран награды после элиты (баг: реликвию нельзя было выбрать — она уезжала за низ окна 720 px).
# Проверяем: оба шага влезают по высоте, шаг 2 открывается после главной награды, реликвию можно взять.
# Запуск: godot --headless --path . -s tests/reward_elite.gd

const VIEW_H: float = 720.0   # высота окна игры (project.godot)

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
			for i in 4:
				await process_frame
			var scr: Node = current_scene
			var tag: String = "сид %d, %s" % [seed_value, "элита" if elite else "обычный бой"]
			var h1: float = _height(scr)
			check("%s: шаг 1 влезает (%d px)" % [tag, h1], h1 <= VIEW_H)
			if not elite:
				check("%s: реликвии нет" % tag, _button(scr, "Взять") == null)
				continue
			check("%s: реликвии на шаге 1 нет" % tag, _button(scr, "Взять") == null)
			var next: Button = _button(scr, "Дальше: награда элиты")
			check("%s: «Дальше» закрыт до выбора" % tag, next != null and next.disabled)
			_button(scr, "Пропустить (каждому +%d HP)" % run.SKIP_HEAL).pressed.emit()
			check("%s: «Дальше» открылся" % tag, not next.disabled)
			next.pressed.emit()
			for i in 4:
				await process_frame
			var h2: float = _height(scr)
			check("%s: шаг 2 влезает (%d px)" % [tag, h2], h2 <= VIEW_H)
			var take: Button = _button(scr, "Взять")
			var last: Button = _button(scr, "Дальше")
			check("%s: есть выбор реликвии" % tag, take != null and _button(scr, "Без реликвии") != null)
			check("%s: «Дальше» закрыт до реликвии" % tag, last != null and last.disabled)
			take.pressed.emit()
			check("%s: реликвия взята" % tag, run.corrupted_count() == 1)
			# Бесплатное улучшение — первая ветка первой предложенной карты
			var bonus: Array = scr.get("_bonus_buttons")
			if not bonus.is_empty():
				(bonus[0] as Button).pressed.emit()
			check("%s: после реликвии и улучшения «Дальше» открыт" % tag, not last.disabled)
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
