class_name KeywordTips
extends RefCounted
# Пояснения ключевых слов (словарь — scripts/data/keywords.gd).
# Как в Slay the Spire: рядом с картой под курсором — столбик коротких пояснений
# ко всем словам из её текста; если в пояснении есть другое слово из словаря — оно тоже объяснено ниже.

const WIDTH: float = 230.0
const MAX_ENTRIES: int = 6   # больше не показываем — столбик не должен закрывать поле


# Панель с пояснениями к словам из текста. Слов нет — null.
static func make_panel(text: String, width: float = WIDTH) -> PanelContainer:
	var entries: Array[Dictionary] = Keywords.find(text)
	if entries.is_empty():
		return null
	var panel: PanelContainer = UiKit.make_panel(Color(UiKit.PANEL, 0.96), Color(UiKit.BRASS_DARK, 0.9))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	for entry: Dictionary in entries.slice(0, MAX_ENTRIES):
		column.add_child(make_entry(entry, width - 24))
	return panel


# Одно пояснение: значок и слово латунью, под ним правило
static func make_entry(entry: Dictionary, width: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_name: String = entry.get("icon", "")
	if icon_name != "" and UiKit.has_icon(icon_name):
		box.add_child(UiKit.chip(icon_name, Loc.t(entry["word"]), UiKit.BRASS.lightened(0.2), "", 14, 14))
	else:
		box.add_child(UiKit.make_label(Loc.t(entry["word"]), 14, UiKit.BRASS.lightened(0.2), true))
	var rule: Label = UiKit.make_label(Loc.t(entry["text"]), 12, UiKit.TEXT)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size.x = width
	box.add_child(rule)
	return box
