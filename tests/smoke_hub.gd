extends Node
# Дымовой тест хаба: открывает меню и хаб как в игре (с Meta и Run), ходит героем,
# переключает героев, открывает все точки, покупает, выходит в забег и возвращается.
# Запуск (из папки проекта):
#   godot --headless --path . res://tests/smoke_hub.tscn
# Пишет в отдельное сохранение user://progress_smoke.cfg — настоящий прогресс не трогает.

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ок: ", what)
	else:
		_fails += 1
		print("ПРОВАЛ: ", what)


func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _ready() -> void:
	# Сам тест не должен быть «текущей сценой»: смена сцены его бы удалила.
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await _frames()
	get_tree().current_scene = dummy

	Meta.save_path = "user://progress_smoke.cfg"
	Meta.reset()
	await _run()
	print("Дымовой тест хаба: ", "всё хорошо" if _fails == 0 else "провалов: %d" % _fails)
	if FileAccess.file_exists(Meta.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Meta.save_path))
	get_tree().quit(_fails)


func _scene() -> Node:
	return get_tree().current_scene


func _goto(path: String) -> void:
	Run.goto(path)
	await _frames(4)


func _run() -> void:
	print("— Главное меню")
	await _goto(Run.MAIN_MENU_SCENE)
	_check(_find_button(_scene(), "Начать") != null, "без сохранения кнопка «Начать»")
	_check(_find_button(_scene(), "Новый прогресс") == null, "без сохранения нет «Нового прогресса»")
	_find_button(_scene(), "Начать").pressed.emit()
	await _frames(4)
	_check(_scene().scene_file_path == Run.HUB_SCENE, "«Начать» ведёт в хаб")

	var hub: Node = _scene()
	await _frames(5)
	print("— Хаб: герои и ходьба")
	_check(hub.heroes.size() == 2, "в хабе два героя")
	_check(hub.active.hero_id == "mage", "первым ходит маг")
	var start: Vector3 = hub.active.global_position
	Input.action_press("hub_up")
	await _physics(40)
	Input.action_release("hub_up")
	await _physics(2)
	_check(hub.active.global_position.z < start.z - 0.5, "W ведёт героя на север (от камеры)")
	Input.action_press("hub_up")
	Input.action_press("hub_right")
	await _physics(20)
	var v: Vector3 = hub.active.velocity
	Input.action_release("hub_up")
	Input.action_release("hub_right")
	_check(Vector2(v.x, v.z).length() <= 3.6, "по диагонали не быстрее (%.2f м/с)" % Vector2(v.x, v.z).length())

	# Стены: долго идём на запад — не выходим за площадку
	Input.action_press("hub_left")
	await _physics(240)
	Input.action_release("hub_left")
	_check(hub.active.global_position.x > -12.5, "стена не пускает в воду (x=%.2f)" % hub.active.global_position.x)

	print("— Tab")
	for i in 5:
		hub.switch_hero()
		await _frames(1)
	await _wait(0.8)
	_check(hub.active.hero_id == "knight", "пять нажатий Tab — активен рыцарь")
	_check(hub.active.can_move, "после перелёта камеры рыцарь снова ходит")
	await _wait(3.0)
	var mage: Node = hub.heroes[0]
	var to_fire: float = (mage.global_position - Vector3(-1.8, 0.0, 4.5)).length()   # скамья мага
	_check(to_fire < 1.5 or (mage.global_position - Vector3(-8.5, 0, 1.2)).length() < 3.0,
			"неактивный маг дошёл к костру или стоит у своей точки (до места %.2f м)" % to_fire)

	print("— Точки")
	Meta.echoes = 500
	Meta.save()
	for p in hub.POINTS:
		await _visit(hub, p)

	print("— Покупка зажигает фонарь")
	var lit_before: int = _lit_lanterns(hub)
	_check(Meta.buy("treasury"), "купить «Казну заставы»")
	await _frames(2)
	_check(_lit_lanterns(hub) == lit_before + 1, "зажёгся ещё один фонарь (%d → %d)" % [lit_before, _lit_lanterns(hub)])

	print("— Ворота → забег")
	_put(hub, hub.POINTS[2])
	await _frames(3)
	hub._use()
	await _frames(3)
	var go: Button = _find_button(hub.hud.panel_root, "Выступить")
	_check(go != null, "у Ворот есть «Выступить»")
	if go != null:
		go.pressed.emit()
		await _frames(6)
	_check(Run.is_active, "забег начался")
	_check(_scene().scene_file_path == Run.MAP_SCENE, "после Ворот — карта пути (%s)" % _scene().scene_file_path)
	_check(Run.gold >= Run.START_GOLD + 20, "«Казна» дала золото на старте (%d)" % Run.gold)

	print("— Гибель → хаб → «Итог пути»")
	var echoes_before: int = Meta.echoes
	Run.rows_passed = 4
	Run.add_spirit(Run.party[0], Run.spirit_data("tide"))
	Run.game_over(false)
	await _frames(4)
	_check(Meta.last_result.get("spirits", []) == ["tide"], "в «Итоге пути» записан покорённый Омутник")
	_check(Meta.is_spirit_tamed("tide"), "Святилище помнит Омутника")
	_check(Meta.echoes == echoes_before + 8, "4 ряда на Звоне 0 — +8 Отзвуков (%d)" % (Meta.echoes - echoes_before))
	_check(_scene().scene_file_path == Run.GAME_OVER_SCENE, "экран итога забега")
	var back: Button = _find_button(_scene(), "К колоколу")
	_check(back != null, "есть «К колоколу»")
	if back != null:
		back.pressed.emit()
		await _frames(4)
	hub = _scene()
	_check(hub.scene_file_path == Run.HUB_SCENE, "вернулись в хаб")
	await _wait(1.8)
	_check(hub.hud.panel_root.get_child_count() == 1, "открылся «Итог пути»")
	if hub.hud.panel_root.get_child_count() > 0:
		(hub.hud.panel_root.get_child(0) as HubPanel).close()
		await _frames(2)
	_check(Meta.last_result.is_empty(), "итог показан один раз")
	_check(hub.active.can_move, "после итога можно ходить")

	print("— Меню с сохранением")
	await _goto(Run.MAIN_MENU_SCENE)
	_check(_find_button(_scene(), "Продолжить") != null, "с сохранением кнопка «Продолжить»")
	_check(_find_button(_scene(), "Новый прогресс") != null, "с сохранением есть «Новый прогресс»")


# Подойти к точке, проверить подсказку, нажать E, проверить панель, закрыть
func _visit(hub: Node, p: Dictionary) -> void:
	var only: String = p.get("hero_only", "")
	# не тем героем — отказ без панели
	if only != "":
		_make_active(hub, "knight" if only == "mage" else "mage")
		await _wait(0.6)
		_put(hub, p)
		await _frames(3)
		hub._use()
		await _frames(2)
		_check(hub.hud.panel_root.get_child_count() == 0, "%s: чужой герой — панель не открылась" % p["title"])
		_make_active(hub, only)
		await _wait(0.6)
	_put(hub, p)
	await _frames(3)
	_check(hub._near.get("id", "") == p["id"], "%s: подсказка у точки (ближайшая — %s)" % [p["title"], hub._near.get("id", "нет")])
	hub._use()
	await _frames(3)
	var n: int = hub.hud.panel_root.get_child_count()
	_check(n == 1, "%s: панель открылась" % p["title"])
	if n == 0:
		return
	var panel: HubPanel = hub.hud.panel_root.get_child(0)
	_check(not hub.active.can_move, "%s: пока панель открыта, герой стоит" % p["title"])
	await _poke(panel, p["id"])
	if is_instance_valid(panel):
		panel.close()
	await _frames(3)
	_check(hub.hud.panel_root.get_child_count() == 0 and not hub._panel_open, "%s: панель закрылась" % p["title"])
	await _wait(0.5)
	_check(hub.active.can_move, "%s: после панели снова ходим" % p["title"])


# Немного «понажимать» внутри панели
func _poke(panel: HubPanel, id: String) -> void:
	match id:
		"board", "mage_circle", "armory":
			var before: int = Meta.steps_bought()
			var b: Button = _find_button(panel, "Изучить")
			_check(b != null, "есть кнопка «Изучить»")
			if b != null:
				b.pressed.emit()
				await _frames(2)
				_check(Meta.steps_bought() == before + 1, "куплена ступень (%d → %d)" % [before, Meta.steps_bought()])
		"bell":
			_check(_count_buttons(panel) >= 6, "у колокола шесть звонов и «Отойти»")
		"shelf":
			var before_n: int = Meta.charms_chosen.size()
			for b in _all_buttons(panel):
				if b.text.contains("Кошель") or b.tooltip_text.contains("Кошель"):
					b.pressed.emit()
					break
			await _frames(2)
			print("    обереги выбраны: ", Meta.charms_chosen, " (было ", before_n, ")")
		"shrine":
			_check(_find_button(panel, "???") != null, "в Святилище неизвестные духи — «???»")
			var buy: Button = _find_button(panel, "Изучить")
			_check(buy != null, "в Святилище есть улучшения духов")
			if buy != null:
				buy.pressed.emit()
				await _frames(2)
			Meta.record_spirit_tamed("tide")   # как будто Омутника покорили в прошлом забеге
			await _frames(2)
			_check(_find_button(panel, "Омутник") != null, "покорённый Омутник виден по имени")
			var call: Button = _find_button(panel, "Звать в логово")
			_check(call != null, "с «Приманкой» Омутника можно позвать в логово")
			if call != null:
				call.pressed.emit()
				await _frames(2)
			_check(Meta.bait_spirit() == "tide", "логово зовёт Омутника")
		"barracks":
			_check(_count_buttons(panel) >= 2, "в Караульне есть кнопки")
			for b in _all_buttons(panel):
				if b.text == "Как было":
					b.pressed.emit()
					break
			await _frames(2)


func _make_active(hub: Node, hero_id: String) -> void:
	if hub.active.hero_id != hero_id:
		hub.switch_hero()


func _put(hub: Node, p: Dictionary) -> void:
	var pos: Vector3 = p["pos"]
	var r: float = float(p["radius"]) * 0.7
	# встаём с южной стороны точки — там свободно у всех построек
	hub.active.global_position = pos + Vector3(0.0, 0.0, r)
	hub.active.velocity = Vector3.ZERO


func _lit_lanterns(hub: Node) -> int:
	var n: int = 0
	for m in hub._lantern_mats:
		if m.emission_enabled:
			n += 1
	return n


func _all_buttons(node: Node) -> Array[Button]:
	var out: Array[Button] = []
	if node is Button:
		out.append(node)
	for c in node.get_children():
		out.append_array(_all_buttons(c))
	return out


func _count_buttons(node: Node) -> int:
	return _all_buttons(node).size()


func _find_button(node: Node, text: String) -> Button:
	for b in _all_buttons(node):
		if b.text.contains(text):
			return b
	return null
