extends SceneTree
# Проверка звуковой системы, музыки 1 акта и эмбиентов:
#   godot --headless --path . -s tests/audio.gd
# Настройки игрока не трогает (подменяет Sfx.settings_path).

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("ПРОВАЛ: ", what)


func _initialize() -> void:
	await process_frame
	var sfx: Node = root.get_node("Sfx")
	var old_path: String = sfx.settings_path
	sfx.settings_path = "user://audio_test.cfg"

	# 1. Шины громкости
	for bus: String in ["Master", "Music", "Ambience", "SFX", "UI"]:
		_check(AudioServer.get_bus_index(bus) >= 0, "есть шина " + bus)

	# 2. Загрузка всей музыки и атмосфер 1 акта + настройка петли
	for track: String in [
		"music_hub", "music_map", "music_rest", "music_bog", "music_grove",
		"music_ruins", "music_cave", "music_elite", "music_boss",
		"amb_hub", "amb_swamp", "amb_grove", "amb_ruins", "amb_cave", "amb_rain",
	]:
		var st: AudioStream = sfx._get_loop_stream(track)
		_check(st != null, "загружается " + track)
		if st is AudioStreamWAV:
			_check((st as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "петля включена для " + track)
			_check((st as AudioStreamWAV).loop_end > 0, "loop_end > 0 для " + track)

	# 3. Загрузка и вариативность ключевых SFX
	for snd: String in [
		"ui_click", "ui_hover", "card_select", "card_cancel", "card_play",
		"card_keep", "card_scrap", "chain_up", "sword_swing", "sword_hit",
		"heavy_hit", "pincer_hit", "staff_hit", "block", "shield_break",
		"push", "bump", "tree_creak", "tree_crash", "barrel_creak",
		"barrel_roll", "wood_break", "reeds_burn", "explosion", "fire",
		"water", "ice", "ice_break", "lightning", "steam", "lava", "crust",
		"gas_cloud", "wind_gust", "bog_cast", "rune_cast", "rune_trap",
		"magic", "absorb_magic", "summon", "spirit_tame", "sink",
		"death", "death_hero", "turn", "heal", "coin", "bell", "door",
		"victory", "defeat", "enemy_bite", "enemy_club", "enemy_spit", "enemy_buff",
		"step_stone", "step_wood", "step_moss", "step_water", "step_swamp",
	]:
		var picked: String = sfx._pick_variant(snd)
		_check(sfx._get_stream(picked) != null, "загружается SFX " + snd)

	# 4. Выбор тем под все локации 1 акта
	sfx.enter_battle("gat", "normal", false)
	_check(sfx._music_track == "music_bog" and sfx._amb_track == "amb_swamp", "Старая гать → music_bog + amb_swamp")
	sfx.enter_battle("grove", "normal", true)
	_check(sfx._music_track == "music_grove" and sfx._amb_track == "amb_grove", "Мёртвая роща → music_grove + amb_grove")
	sfx.enter_battle("ruins", "normal", false)
	_check(sfx._music_track == "music_ruins" and sfx._amb_track == "amb_ruins", "Руины → music_ruins + amb_ruins")
	sfx.enter_battle("cave", "cave", false)
	_check(sfx._music_track == "music_cave" and sfx._amb_track == "amb_cave", "Пещера → music_cave + amb_cave")
	sfx.enter_battle("reeds", "boss", false)
	_check(sfx._music_track == "music_boss", "Босс → music_boss")
	sfx.enter_battle("grove", "elite", false)
	_check(sfx._music_track == "music_elite", "Элита → music_elite")

	# 5. Материалы шагов на доске
	var board := Board.new()
	board._ground[Vector2i(0, 0)] = BattleLogic.Ground.STONE
	board._ground[Vector2i(1, 0)] = BattleLogic.Ground.PLANKS
	board._ground[Vector2i(2, 0)] = BattleLogic.Ground.MOSS
	board._effect_kinds[Vector2i(2, 0)] = BattleLogic.Tile.WATER
	board._object_kinds[Vector2i(1, 0)] = BattleLogic.Obj.BOG
	_check(board.step_sound(Vector2i(0, 0)) == "step_stone", "плита → step_stone")
	_check(board.step_sound(Vector2i(1, 0)) == "step_swamp", "трясина важнее настила → step_swamp")
	_check(board.step_sound(Vector2i(2, 0)) == "step_water", "лужа важнее мха → step_water")
	board.free()

	if FileAccess.file_exists(sfx.settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sfx.settings_path))
	sfx.settings_path = old_path
	print("Тест звука: ", "всё хорошо" if _fails == 0 else "провалов: %d" % _fails)
	quit(_fails)
