extends SceneTree
# Готовность к переводу: подставляет «язык-заглушку» xx, где каждая строка каталога
# (locale/messages.pot) взята в скобки ⟦…⟧, открывает экраны и ищет на них текст,
# в котором остались русские буквы вне скобок, — такой текст переводчику не достанется.
# Запуск: godot --headless --path . -s tests/i18n.gd   (сначала python tools/i18n/extract_strings.py)
# LIMIT=0 — сколько остатков допустимо (по умолчанию тест только печатает список).

const OPEN := "⟦"
const CLOSE := "⟧"
var _left: Dictionary = {}   # остаток → где видели
var _screen: String = ""


func _initialize() -> void:
	await process_frame
	var tr := Translation.new()
	tr.locale = "xx"
	var count: int = 0
	for msg: String in _read_pot("res://locale/messages.pot"):
		tr.add_message(msg, OPEN + msg + CLOSE)
		count += 1
	TranslationServer.add_translation(tr)
	TranslationServer.set_locale("xx")
	print("строк в каталоге: ", count)

	var run = root.get_node("Run")
	run.get_node("/root/Meta").tutorial_done = true
	await _visit("main_menu", "res://ui/main_menu.tscn", 10)
	run.start_new_run(11)
	await _visit("map", "res://ui/map_screen.tscn", 20)
	run.pending_enemies = [load("res://resources/enemies/goblin_shaman.tres"), load("res://resources/enemies/bloated_toad.tres"), load("res://resources/enemies/goblin.tres")] as Array[EnemyData]
	run.pending_arena = "grove"
	await _visit("battle", "res://scenes/battle.tscn", 240)
	var b = current_scene
	b.hud.toggle_help()
	_scan(root, "battle_help")
	b.hud.toggle_help()
	b._on_hover(b.logic.enemies[0].cell)
	_scan(root, "battle_enemy_card")
	run.current = run.map[0]
	await _visit("reward", "res://ui/reward_screen.tscn", 30)
	await _visit("shop", "res://ui/shop_screen.tscn", 30)
	await _visit("rest", "res://ui/rest_screen.tscn", 30)
	await _visit("event", "res://ui/event_screen.tscn", 30)
	await _visit("hub", "res://scenes/hub.tscn", 60)
	await _visit("start_pick", "res://ui/start_pick.tscn", 20)
	var pause = load("res://ui/pause_menu.gd").open(current_scene)
	await process_frame
	_scan(root, "pause")
	load("res://ui/settings_screen.gd").open(pause)
	await process_frame
	_scan(root, "settings")
	paused = false
	run.start_new_run(12)
	await _visit("act", "res://ui/act_screen.tscn", 20)
	await _visit("trophy", "res://ui/trophy_screen.tscn", 20)
	run.game_over(false)
	for i in 30:
		await process_frame
	_scan(root, "game_over")

	var keys: Array = _left.keys()
	keys.sort()
	print("Остатки без перевода (%d):" % keys.size())
	for k: String in keys:
		print("  [%s] %s" % [_left[k], k.replace("\n", " ⏎ ")])
	var limit: int = int(OS.get_environment("LIMIT")) if OS.get_environment("LIMIT") != "" else -1
	quit(1 if limit >= 0 and keys.size() > limit else 0)


func _visit(name: String, path: String, frames: int) -> void:
	change_scene_to_file(path)
	for i in frames:
		await process_frame
	_scan(root, name)


# Обойти все узлы с текстом
func _scan(node: Node, screen: String) -> void:
	var text: String = ""
	if node is Label or node is Button or node is RichTextLabel or node is Label3D:
		if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
			text = ""
		elif node is RichTextLabel:
			text = (node as RichTextLabel).get_parsed_text()
		else:
			text = str(node.get("text"))
		# Подписи Control переводятся автоматически только при точном совпадении — проверяем, что видит игрок
		if node is Control and (node as Control).can_auto_translate():
			text = String(node.atr(text))
	if text != "":
		var rest: String = _strip(text)
		if _has_cyrillic(rest):
			if not _left.has(text):
				_left[text] = screen
	for child in node.get_children():
		_scan(child, screen)


func _strip(s: String) -> String:
	var out: String = ""
	var depth: int = 0
	for ch in s:
		if ch == OPEN:
			depth += 1
		elif ch == CLOSE:
			depth = maxi(0, depth - 1)
		elif depth == 0:
			out += ch
	return out


func _has_cyrillic(s: String) -> bool:
	for ch in s:
		var c: int = ch.unicode_at(0)
		if c >= 0x0400 and c <= 0x04FF:
			return true
	return false


# msgid из .pot (строки в виде литералов GDScript: \n, \" — раскрываем)
func _read_pot(path: String) -> Array[String]:
	var list: Array[String] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return list
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.begins_with("msgid \"") and line.length() > 9:
			list.append(line.substr(7, line.length() - 8).c_unescape())
	return list
