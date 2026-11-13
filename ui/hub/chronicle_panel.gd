class_name ChroniclePanel
extends HubPanel
# Костёр: летопись последних забегов и реплика героя у огня.

const LINES: Dictionary = {
	"mage": "Огонь не греет, а просто напоминает, что мы ещё здесь. Пожалуй, этого достаточно.",
	"knight": "Сядем на минуту. Дорога от этого не станет короче, но руки перестанут дрожать.",
}


static func open(parent: Node, for_hero: String = "") -> HubPanel:
	var panel := ChroniclePanel.new()
	panel.hero_id = for_hero
	create(parent, panel, "Летопись", 700)
	panel._rebuild()
	return panel


func _rebuild() -> void:
	UiKit.clear(body)
	body.add_child(UiKit.make_text(LINES.get(hero_id, "Здесь можно посидеть. Недолго."), 16, UiKit.TEXT_DIM, 640))

	var best_rows: int = 0
	var complete_count: int = 0
	for e in Meta.history:
		best_rows = maxi(best_rows, e.get("rows", 0))
		if e.get("complete", false):
			complete_count += 1
	var tamed_kinds: int = 0
	for id in Run.ALL_SPIRIT_IDS:
		if Meta.is_spirit_tamed(id):
			tamed_kinds += 1
	var stats: Label = UiKit.make_label("Дальше всего: ряд %d  ·  Пройдено до конца: %d  ·  Обереги: %d / %d  ·  Духи: %d / %d" % [
			best_rows, complete_count, Meta.opened_count(), Meta.CHARMS.size(), tamed_kinds, Run.ALL_SPIRIT_IDS.size()], 15, UiKit.TEXT, true)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(stats)

	if Meta.history.is_empty():
		body.add_child(UiKit.make_text("Летопись пуста. Первая запись — за первым забегом.", 16, UiKit.TEXT_DIM, 600))
		return
	var shown: int = 0
	for i in range(Meta.history.size() - 1, -1, -1):
		if shown >= 10:
			break
		body.add_child(_make_row(Meta.history[i]))
		shown += 1


func _make_row(e: Dictionary) -> Control:
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL_LIGHT, 0.5), UiKit.LINE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var bell: HBoxContainer = UiKit.chip("bell", str(e.get("bell", 0)), UiKit.BRASS.lightened(0.1), "Звон", 16, 20)
	bell.custom_minimum_size.x = 50
	row.add_child(bell)
	var where: Label = UiKit.make_label(_where(e), 16, UiKit.TEXT)
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(where)
	# Духи, покорённые в этом забеге: только значки, имя — в подсказке
	for id in e.get("spirits", []):
		var sp: SpiritData = Run.spirit_data(str(id))
		if sp != null:
			var mark: TextureRect = ic(sp.icon, 20, sp.color.lightened(0.2))
			mark.tooltip_text = "Покорён: " + sp.title
			mark.mouse_filter = Control.MOUSE_FILTER_PASS
			row.add_child(mark)
	row.add_child(echo_cost(e.get("echoes", 0)))
	return panel


# Где кончился забег
func _where(e: Dictionary) -> String:
	if e.get("complete", false):
		return "Пройден до конца"
	if e.get("bosses", 0) > 0:
		return "Босс повержен"
	if e.get("elites", 0) > 0:
		return "Пал после элиты (ряд %d)" % e.get("rows", 0)
	return "Пал на ряду %d" % e.get("rows", 0)
