class_name RunSummary
extends HubPanel
# «Итог пути»: что получено за только что закончившийся забег.


static func open(parent: Node, for_hero: String = "") -> HubPanel:
	var panel := RunSummary.new()
	panel.hero_id = for_hero
	create(parent, panel, "Итог пути", 560)
	panel._rebuild()
	return panel


func _rebuild() -> void:
	UiKit.clear(body)
	var r: Dictionary = Meta.last_result
	if r.is_empty():
		body.add_child(UiKit.make_text("Герои у Колокола. Путь ещё не пройден.", 16, UiKit.TEXT_DIM, 500))
		return
	var rows: int = r.get("rows", 0)
	body.add_child(_line("Пройдено рядов: %d" % rows, rows * Meta.ECHO_PER_ROW))
	if r.get("elites", 0) > 0:
		body.add_child(_line("Элита", r["elites"] * Meta.ECHO_ELITE))
	if r.get("bosses", 0) > 0:
		body.add_child(_line("Босс", r["bosses"] * Meta.ECHO_BOSS))
	if r.get("event_echoes", 0) > 0:
		body.add_child(_line("События", r["event_echoes"]))
	if r.get("trophy_echoes", 0) > 0:
		body.add_child(_line("Трофей", r["trophy_echoes"]))
	var bell: int = r.get("bell", 0)
	if bell > 0:
		var bonus: Label = UiKit.make_label("Звон %d  ·  +%d%%" % [bell, roundi(Meta.BELL_ECHO_BONUS * bell * 100.0)], 16, UiKit.BRASS.lightened(0.15))
		body.add_child(bonus)
	body.add_child(UiKit.make_divider(400))
	var total := HBoxContainer.new()
	total.alignment = BoxContainer.ALIGNMENT_CENTER
	total.add_child(UiKit.chip("echo", "+%d" % r.get("echoes", 0), UiKit.ECHO, "", 34, 36))
	body.add_child(total)
	if r.get("bell_opened", -1) >= 0:
		var opened: Label = UiKit.make_label("Открыт Звон %d" % r["bell_opened"], 20, UiKit.BRASS.lightened(0.3), true)
		opened.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(opened)


func _line(text: String, amount: int) -> Control:
	var row := HBoxContainer.new()
	var label: Label = UiKit.make_label(text, 17, UiKit.TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(UiKit.chip("echo", "+%d" % amount, UiKit.ECHO, "", 17, 18))
	return row
