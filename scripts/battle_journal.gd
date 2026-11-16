class_name BattleJournal
extends RefCounted
# Журнал боёв: после каждого боя дописывает одну строку в user://battles.csv.
# Файл открывается в Excel или Google Таблицах (разделитель — точка с запятой).
# На Windows он лежит в %APPDATA%\Godot\app_userdata\Roguelike\battles.csv.
# По нему видно, сколько HP стоит каждый бой при живой игре, — сравниваем с ботом.

const PATH: String = "user://battles.csv"
const SEP: String = ";"

# Столбцы по порядку. Ключи словаря строки — те же имена.
const COLUMNS: Array[String] = [
	"date", "seed", "bell", "row", "kind", "squad", "arena", "objective", "formation",
	"enemies", "modifiers", "arrived", "rounds", "won", "seconds", "enemy_seconds",
	"mage_start", "mage_end", "knight_start", "knight_end", "hp_lost", "falls",
	"cards", "scraps",
]


# Дописывает строку; если файла ещё нет — сначала заголовок
static func write(row: Dictionary) -> void:
	var is_new: bool = not FileAccess.file_exists(PATH)
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ_WRITE if not is_new else FileAccess.WRITE)
	if f == null:
		push_warning("Журнал боёв: не удалось открыть %s" % PATH)
		return
	if is_new:
		f.store_string(String.chr(0xFEFF))   # метка UTF-8, чтобы Excel показал русские буквы
		f.store_line(SEP.join(COLUMNS))
	else:
		f.seek_end()
	var cells: PackedStringArray = []
	for key in COLUMNS:
		cells.append(str(row.get(key, "")).replace(SEP, ","))
	f.store_line(SEP.join(cells))
	f.close()


# Где файл на диске (для строки в Output)
static func full_path() -> String:
	return ProjectSettings.globalize_path(PATH)
