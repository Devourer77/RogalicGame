extends SceneTree

# Журнал боёв (scripts/battle_journal.gd): файл user://battles.csv.
# Запуск: godot --headless --path . -s tests/journal.gd

var fails := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok: fails += 1


func _initialize() -> void:
	await process_frame
	DirAccess.remove_absolute(BattleJournal.full_path())
	BattleJournal.write({"row": 0, "kind": "бой", "squad": "Стая", "hp_lost": 9, "won": 1})
	BattleJournal.write({"row": 1, "kind": "элита", "squad": "Седой; вожак", "hp_lost": 21, "won": 0})
	var text: String = FileAccess.get_file_as_string(BattleJournal.PATH)
	var lines: PackedStringArray = text.strip_edges().split("\n")
	check("Файл создан: заголовок и 2 строки", lines.size() == 3)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(BattleJournal.PATH)
	check("В начале метка UTF-8 для Excel", bytes.size() > 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF)
	check("Заголовок — все столбцы", lines[0].trim_prefix(String.chr(0xFEFF)) == BattleJournal.SEP.join(BattleJournal.COLUMNS))
	var cols: int = BattleJournal.COLUMNS.size()
	check("В каждой строке столько же столбцов", lines[1].split(BattleJournal.SEP).size() == cols and lines[2].split(BattleJournal.SEP).size() == cols)
	var row2: PackedStringArray = lines[2].split(BattleJournal.SEP)
	check("Значения на своих местах (отряд, потеря HP)",
			row2[BattleJournal.COLUMNS.find("squad")] == "Седой, вожак" and row2[BattleJournal.COLUMNS.find("hp_lost")] == "21")
	check("Русские буквы читаются", row2[BattleJournal.COLUMNS.find("kind")] == "элита")
	DirAccess.remove_absolute(BattleJournal.full_path())
	await _real_battle()
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)


# Настоящая сцена боя: перебиваем врагов, бой кончается — в журнале появляется строка
func _real_battle() -> void:
	var run = root.get_node("Run")
	run.start_new_run(33)
	run.pending_enemies = run._make_encounter(0, false)
	run.pending_arena = "grove"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	for e in b.logic.living_enemies():
		b.logic._damage(e, 999)
	b.logic._check_end()
	await b._finish_battle()
	var lines: PackedStringArray = FileAccess.get_file_as_string(BattleJournal.PATH).strip_edges().split("\n")
	check("После боя в журнале строка", lines.size() == 2)
	if lines.size() < 2:
		return
	var row: PackedStringArray = lines[1].split(BattleJournal.SEP)
	var col := func(key: String) -> String: return row[BattleJournal.COLUMNS.find(key)]
	print("   ", lines[1])
	check("…бой выигран, отряд записан", col.call("won") == "1" and col.call("squad") == run.pending_encounter.title)
	check("…строй и число врагов записаны", col.call("formation") == BattleLogic.Formation.keys()[run.pending_encounter.formation].to_lower() and int(col.call("enemies")) >= 4)
	check("…HP героев в начале записано", int(col.call("mage_start")) > 0 and int(col.call("knight_start")) > 0)
	DirAccess.remove_absolute(BattleJournal.full_path())
