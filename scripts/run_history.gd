class_name RunHistory
extends RefCounted
# История забегов: после каждого забега (победа, гибель, «сдаться») — одна запись в user://run_history.json.
# Хранятся последние MAX_RUNS. Показывает окно ui/run_history_screen.gd (главное меню, экран конца забега).
# Запись — словарь из Run.history_entry(): дата, победа, Звон, акт и ряд, итоги боёв, путь, колоды.

const PATH: String = "user://run_history.json"
const MAX_RUNS: int = 50


static func load_all() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var text: String = FileAccess.get_file_as_string(PATH)
	var data: Variant = JSON.parse_string(text)
	return data if data is Array else []


static func add(entry: Dictionary) -> void:
	var runs: Array = load_all()
	runs.append(entry)
	while runs.size() > MAX_RUNS:
		runs.pop_front()
	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("История забегов: не удалось записать %s" % PATH)
		return
	f.store_string(JSON.stringify(runs, "\t"))
	f.close()


# Последняя запись (только что законченный забег) — для экрана конца забега
static func last() -> Dictionary:
	var runs: Array = load_all()
	return runs.back() if not runs.is_empty() and runs.back() is Dictionary else {}
