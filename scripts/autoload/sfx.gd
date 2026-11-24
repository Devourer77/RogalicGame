extends Node
# Проигрыватель звуковых эффектов, фоновой музыки и атмосферы.
# Это autoload (синглтон): доступен из любого скрипта по имени Sfx.
#
# Всё лежит в res://assets/sounds/ (и подпапках music/, ambience/).
# Для частых звуков поддерживаются варианты имени (<имя>_1, <имя>_2, ...):
# каждый вызов играет случайный вариант, отличный от предыдущего.

signal settings_changed

var settings_path: String = "user://audio.cfg"   # var, чтобы тесты могли подменить путь
const SEARCH_DIRS: Array[String] = [
	"res://assets/sounds/",
	"res://assets/sounds/music/",
	"res://assets/sounds/ambience/",
]
const POOL_SIZE: int = 12          # сколько SFX могут играть одновременно без обрывов
const MIN_INTERVAL_MS: int = 35    # защита от дребезга: один и тот же звук не чаще раза в 35 мс
const MUSIC_FADE_SEC: float = 1.6  # плавный переход между музыкальными темами
const AMBIENCE_FADE_SEC: float = 1.4

# Отдельные шины громкости: Music, Ambience, SFX, UI → Master
const BUS_MUSIC: String = "Music"
const BUS_AMBIENCE: String = "Ambience"
const BUS_SFX: String = "SFX"
const BUS_UI: String = "UI"
const DEFAULT_VOLUMES: Dictionary[String, float] = {
	"Master": 1.0,
	"Music": 0.72,
	"Ambience": 0.70,
	"SFX": 0.90,
	"UI": 0.85,
}
const UI_EXACT: Array[String] = ["coin", "chain_up", "door", "bell"]

var muted: bool = false
var volume_db: float = 0.0         # совместимость: дополнительная поправка на SFX
var bus_volumes: Dictionary[String, float] = {}

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _loop_streams: Dictionary = {}
var _variants: Dictionary = {}
var _last_variant: Dictionary[String, String] = {}
var _last_played_ms: Dictionary[String, int] = {}
var _next_player: int = 0


func _init() -> void:
	for bus_name: String in DEFAULT_VOLUMES:
		bus_volumes[bus_name] = DEFAULT_VOLUMES[bus_name]

# Две пары плееров (A/B) для бесшовного перекрёстного перехода музыки и атмосферы
var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _music_blend: Array[float] = [0.0, 0.0]
var _music_track: String = ""
var _music_gain_db: float = 0.0

var _amb_players: Array[AudioStreamPlayer] = []
var _amb_active: int = 0
var _amb_blend: Array[float] = [0.0, 0.0]
var _amb_track: String = ""
var _amb_gain_db: float = 0.0

var _rain_player: AudioStreamPlayer
var _rain_blend: float = 0.0
var _rain_target: float = 0.0

# Краткое утихание музыки при звоне Колокола или фанфарах победы/поражения
var _duck_db: float = 0.0
var _duck_hold: float = 0.0
var _last_tick_ms: int = 0


func _ready() -> void:
	_setup_buses()
	_load_settings()
	_apply_buses()

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		player.bus = BUS_SFX
		add_child(player)
		_players.append(player)

	for i in 2:
		var mp := AudioStreamPlayer.new()
		mp.name = "MusicPlayer%d" % i
		mp.bus = BUS_MUSIC
		mp.volume_db = -80.0
		mp.finished.connect(_on_loop_player_finished.bind(mp))
		add_child(mp)
		_music_players.append(mp)

		var ap := AudioStreamPlayer.new()
		ap.name = "AmbiencePlayer%d" % i
		ap.bus = BUS_AMBIENCE
		ap.volume_db = -80.0
		ap.finished.connect(_on_loop_player_finished.bind(ap))
		add_child(ap)
		_amb_players.append(ap)

	_rain_player = AudioStreamPlayer.new()
	_rain_player.name = "RainPlayer"
	_rain_player.bus = BUS_AMBIENCE
	_rain_player.volume_db = -80.0
	_rain_player.finished.connect(_on_loop_player_finished.bind(_rain_player))
	add_child(_rain_player)
	_last_tick_ms = Time.get_ticks_msec()


# Переходы и утихание считаем в реальном времени, чтобы hitstop (time_scale = 0.05) не ломал музыку
func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	var dt: float = clampf((now - _last_tick_ms) * 0.001, 0.0, 0.1)
	_last_tick_ms = now
	if dt <= 0.0:
		return

	if _duck_hold > 0.0:
		_duck_hold = maxf(0.0, _duck_hold - dt)
	elif _duck_db < 0.0:
		_duck_db = move_toward(_duck_db, 0.0, dt * 4.5)

	var m_step: float = dt / MUSIC_FADE_SEC
	for i in 2:
		var target: float = 1.0 if (i == _music_active and _music_track != "") else 0.0
		_music_blend[i] = move_toward(_music_blend[i], target, m_step)
		var p: AudioStreamPlayer = _music_players[i]
		if target == 0.0 and _music_blend[i] <= 0.001:
			if p.playing:
				p.stop()
			p.volume_db = -80.0
		elif _music_blend[i] > 0.0:
			var curve: float = sin(_music_blend[i] * PI * 0.5)
			p.volume_db = linear_to_db(maxf(0.0001, curve)) + _music_gain_db + _duck_db

	var a_step: float = dt / AMBIENCE_FADE_SEC
	for i in 2:
		var target: float = 1.0 if (i == _amb_active and _amb_track != "") else 0.0
		_amb_blend[i] = move_toward(_amb_blend[i], target, a_step)
		var p: AudioStreamPlayer = _amb_players[i]
		if target == 0.0 and _amb_blend[i] <= 0.001:
			if p.playing:
				p.stop()
			p.volume_db = -80.0
		elif _amb_blend[i] > 0.0:
			var curve: float = sin(_amb_blend[i] * PI * 0.5)
			p.volume_db = linear_to_db(maxf(0.0001, curve)) + _amb_gain_db

	_rain_blend = move_toward(_rain_blend, _rain_target, a_step)
	if _rain_target == 0.0 and _rain_blend <= 0.001:
		if _rain_player.playing:
			_rain_player.stop()
		_rain_player.volume_db = -80.0
	elif _rain_blend > 0.0:
		_rain_player.volume_db = linear_to_db(maxf(0.0001, sin(_rain_blend * PI * 0.5))) - 2.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var key_ev := event as InputEventKey
		if key_ev.keycode == KEY_M and not key_ev.ctrl_pressed and not key_ev.alt_pressed:
			var focus: Control = get_viewport().gui_get_focus_owner()
			if focus is LineEdit or focus is TextEdit:
				return
			toggle_mute()
			get_viewport().set_input_as_handled()


# ---------- Проигрывание SFX ----------

# Проиграть звук (или случайный из вариантов <sound_name>_1..N).
func play(sound_name: String, pitch_spread: float = 0.06, extra_db: float = 0.0, base_pitch: float = 1.0) -> void:
	if muted or _players.is_empty() or sound_name == "":
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_played_ms.get(sound_name, -1000) < MIN_INTERVAL_MS:
		return
	var chosen: String = _pick_variant(sound_name)
	var stream: AudioStream = _get_stream(chosen)
	if stream == null:
		return
	_last_played_ms[sound_name] = now

	if chosen == "bell":
		duck_music(-4.5, 1.4)
	elif chosen == "victory" or chosen == "defeat":
		duck_music(-11.0, 1.8)

	var player: AudioStreamPlayer = _pick_player()
	player.bus = BUS_UI if _is_ui_sound(sound_name) else BUS_SFX
	player.stream = stream
	player.volume_db = volume_db + extra_db
	var spread: float = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread) if pitch_spread > 0.0 else 1.0
	player.pitch_scale = maxf(0.25, base_pitch * spread)
	player.play()


# Подключает звук клика к кнопке (безопасно вызывать повторно)
func bind_button(button: BaseButton, sound_name: String = "ui_click") -> void:
	if button == null:
		return
	var cb: Callable = play.bind(sound_name, 0.04)
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)


# ---------- Фоновая музыка и атмосфера локаций ----------

func _sim_headless() -> bool:
	var run_node: Node = get_node_or_null("/root/Run")
	return run_node != null and bool(run_node.get("sim_no_scenes"))


func set_music(track_name: String, gain_db: float = 0.0) -> void:
	if _sim_headless():
		return
	_music_gain_db = gain_db
	if track_name == _music_track:
		return
	_music_track = track_name
	if track_name == "":
		return
	var stream: AudioStream = _get_loop_stream(track_name)
	if stream == null:
		_music_track = ""
		return
	_music_active = 1 - _music_active
	var p: AudioStreamPlayer = _music_players[_music_active]
	p.stream = stream
	p.volume_db = -80.0
	p.play()


func set_ambience(amb_name: String, gain_db: float = 0.0) -> void:
	if _sim_headless():
		return
	_amb_gain_db = gain_db
	if amb_name == _amb_track:
		return
	_amb_track = amb_name
	if amb_name == "":
		return
	var stream: AudioStream = _get_loop_stream(amb_name)
	if stream == null:
		_amb_track = ""
		return
	_amb_active = 1 - _amb_active
	var p: AudioStreamPlayer = _amb_players[_amb_active]
	p.stream = stream
	p.volume_db = -80.0
	p.play()


func set_rain(enabled: bool) -> void:
	if _sim_headless():
		_rain_target = 0.0
		return
	_rain_target = 1.0 if enabled else 0.0
	if enabled and not _rain_player.playing:
		var stream: AudioStream = _get_loop_stream("amb_rain")
		if stream != null:
			_rain_player.stream = stream
			_rain_player.volume_db = -80.0
			_rain_player.play()


# Кратковременно приглушить музыку под громкий колокол или фанфару
func duck_music(target_db: float = -6.0, hold_sec: float = 1.2) -> void:
	_duck_db = minf(_duck_db, target_db)
	_duck_hold = maxf(_duck_hold, hold_sec)


# Подбирает тему при смене экрана игры (бой выставляет тему сам через enter_battle)
func sync_scene(scene_path: String) -> void:
	if _sim_headless() or scene_path == "":
		return
	var name_only: String = scene_path.get_file().get_basename()
	match name_only:
		"main_menu":
			set_rain(false)
			set_music("music_hub", -1.5)
			set_ambience("amb_hub", -6.0)
		"hub":
			set_rain(false)
			set_music("music_hub", 0.0)
			set_ambience("amb_hub", 0.0)
		"rest_screen":
			set_rain(false)
			set_music("music_rest", 0.0)
			set_ambience("amb_hub", -2.5)
		"start_pick", "map_screen", "event_screen", "shop_screen", "reward_screen", "trophy_screen":
			set_rain(false)
			set_music("music_map", -0.5)
			set_ambience("amb_swamp", -5.5)
		"game_over":
			set_rain(false)
			set_music("", 0.0)
			set_ambience("amb_hub", -4.0)


# Подбирает музыку и атмосферу конкретной боевой арены 1-го акта
func enter_battle(arena_id: String, battle_kind: String, rainy: bool) -> void:
	if _sim_headless():
		return
	var track: String = "music_bog"
	match battle_kind:
		"boss":
			track = "music_boss"
		"cave":
			track = "music_cave"
		"elite", "lair":
			track = "music_elite"
		_:
			match arena_id:
				"grove", "camp":
					track = "music_grove"
				"ruins":
					track = "music_ruins"
				"cave":
					track = "music_cave"
				"lair":
					track = "music_boss"
				_:
					track = "music_bog"

	var amb: String = "amb_swamp"
	match arena_id:
		"grove", "camp":
			amb = "amb_grove"
		"ruins":
			amb = "amb_ruins"
		"cave":
			amb = "amb_cave"
		_:
			amb = "amb_swamp"

	set_music(track, 0.0)
	set_ambience(amb, 0.0)
	set_rain(rainy)


# ---------- Шины и сохранение настроек громкости ----------

func get_bus_volume(bus_name: String) -> float:
	return clampf(float(bus_volumes.get(bus_name, 1.0)), 0.0, 1.0)


func set_bus_volume(bus_name: String, linear: float) -> void:
	bus_volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_buses()
	_save_settings()
	settings_changed.emit()


func set_muted(value: bool) -> void:
	muted = value
	_apply_buses()
	_save_settings()
	settings_changed.emit()


func toggle_mute() -> bool:
	set_muted(not muted)
	return muted


func _setup_buses() -> void:
	for bus_name: String in [BUS_MUSIC, BUS_AMBIENCE, BUS_SFX, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.get_bus_count()
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _apply_buses() -> void:
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		AudioServer.set_bus_mute(master_idx, muted)
	for bus_name: String in bus_volumes:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx == -1:
			continue
		var lin: float = clampf(float(bus_volumes[bus_name]), 0.0, 1.0)
		AudioServer.set_bus_mute(idx, lin <= 0.001 or (muted and bus_name == "Master"))
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, lin)))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	for bus_name: String in bus_volumes:
		cfg.set_value("audio", bus_name, bus_volumes[bus_name])
	cfg.save(settings_path)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	muted = bool(cfg.get_value("audio", "muted", false))
	for bus_name: String in DEFAULT_VOLUMES:
		bus_volumes[bus_name] = clampf(float(cfg.get_value("audio", bus_name, DEFAULT_VOLUMES[bus_name])), 0.0, 1.0)


# ---------- Внутренние хелперы ----------

func _is_ui_sound(sound_name: String) -> bool:
	return sound_name.begins_with("ui_") or sound_name.begins_with("card_") or UI_EXACT.has(sound_name)


func _pick_variant(sound_name: String) -> String:
	if not _variants.has(sound_name):
		var list: Array[String] = []
		if _sound_exists(sound_name):
			list.append(sound_name)
		for i in range(1, 9):
			var candidate: String = "%s_%d" % [sound_name, i]
			if _sound_exists(candidate) and not list.has(candidate):
				list.append(candidate)
		_variants[sound_name] = list
	var variants: Array = _variants[sound_name]
	if variants.is_empty():
		return sound_name
	if variants.size() == 1:
		return variants[0]
	var prev: String = _last_variant.get(sound_name, "")
	var pick: String = variants[randi_range(0, variants.size() - 1)]
	if pick == prev:
		pick = variants[(variants.find(pick) + randi_range(1, variants.size() - 1)) % variants.size()]
	_last_variant[sound_name] = pick
	return pick


func _sound_exists(sound_name: String) -> bool:
	for dir: String in SEARCH_DIRS:
		for ext: String in [".ogg", ".wav"]:
			var path: String = dir + sound_name + ext
			if ResourceLoader.exists(path) or FileAccess.file_exists(path):
				return true
	return false


func _pick_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var idx: int = (_next_player + i) % POOL_SIZE
		if not _players[idx].playing:
			_next_player = (idx + 1) % POOL_SIZE
			return _players[idx]
	var fallback: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	return fallback


func _find_wav_path(sound_name: String) -> String:
	for dir: String in SEARCH_DIRS:
		var wav_path: String = dir + sound_name + ".wav"
		if FileAccess.file_exists(wav_path):
			return wav_path
	return ""


func _load_raw_wav(sound_name: String) -> AudioStreamWAV:
	var wav_path: String = _find_wav_path(sound_name)
	if wav_path == "":
		return null
	return AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(wav_path))


func _get_stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var stream: AudioStream = null
	for dir: String in SEARCH_DIRS:
		for ext: String in [".ogg", ".wav"]:
			var path: String = dir + sound_name + ext
			if ResourceLoader.exists(path):
				stream = load(path) as AudioStream
				break
		if stream != null:
			break
		var wav_path: String = dir + sound_name + ".wav"
		if FileAccess.file_exists(wav_path):
			stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(wav_path))
			break
	if stream == null:
		push_warning("Нет звука: %s" % sound_name)
	_streams[sound_name] = stream
	return stream


func _get_loop_stream(sound_name: String) -> AudioStream:
	if _loop_streams.has(sound_name):
		return _loop_streams[sound_name]
	var raw: AudioStream = _get_stream(sound_name)
	if raw == null:
		return null
	var result: AudioStream = raw
	if raw is AudioStreamWAV:
		var wav := raw as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			# Сжатый QOA/ADPCM нельзя безопасно зацикливать правкой loop_end на лету:
			# берём чистый PCM с диска либо перезапускаем поток через finished.
			if wav.format != AudioStreamWAV.FORMAT_8_BITS and wav.format != AudioStreamWAV.FORMAT_16_BITS:
				var pcm: AudioStreamWAV = _load_raw_wav(sound_name)
				if pcm != null:
					wav = pcm
				else:
					_loop_streams[sound_name] = raw
					return raw
			else:
				wav = wav.duplicate() as AudioStreamWAV
			var bytes_per_sample: int = 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var channels: int = 2 if wav.stereo else 1
			var frame_bytes: int = maxi(1, bytes_per_sample * channels)
			var frames: int = wav.data.size() / frame_bytes
			if frames > 0:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = frames
		result = wav
	_loop_streams[sound_name] = result
	return result


func _on_loop_player_finished(player: AudioStreamPlayer) -> void:
	# Страховка на случай, если поток окажется не WAV или остановился на границе
	if not is_instance_valid(player) or player.stream == null:
		return
	var should_loop: bool = false
	for i in 2:
		if _music_players[i] == player and i == _music_active and _music_track != "":
			should_loop = true
		if _amb_players[i] == player and i == _amb_active and _amb_track != "":
			should_loop = true
	if _rain_player == player and _rain_target > 0.5:
		should_loop = true
	var loops_natively: bool = player.stream is AudioStreamWAV and (player.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if should_loop and not loops_natively:
		player.play()
