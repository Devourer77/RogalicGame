extends Node
# Проигрыватель звуковых эффектов (SFX).
# Это autoload (синглтон): он живёт всё время игры и доступен
# из любого скрипта по имени Sfx (Проект → Настройки проекта → Глобальные).
#
# Все звуки лежат в assets/sounds/*.wav (собираются скриптом assets/sounds/src/build_sounds.py).
# Хочешь заменить любой звук на свой — просто положи файл с тем же именем (.wav или .ogg).

const SOUND_DIR: String = "res://assets/sounds/"
const POOL_SIZE: int = 8           # сколько звуков могут играть одновременно, не обрывая друг друга
const MIN_INTERVAL_MS: int = 35    # защита от дребезга: один и тот же звук не чаще раза в 35 мс

var muted: bool = false
var volume_db: float = 0.0         # общая поправка громкости в децибелах (0 — обычная, -6 — вдвое тише)

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary[String, AudioStream] = {}
var _last_played_ms: Dictionary[String, int] = {}
var _next_player: int = 0


func _ready() -> void:
	# Создаём пул проигрывателей заранее: когда в бою заклинание бьёт сразу нескольких врагов,
	# свободный проигрыватель берётся по кругу, и звуки не обрывают друг друга.
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % i
		add_child(player)
		_players.append(player)


# Проиграть звук по имени файла из assets/sounds/ (без расширения), например: Sfx.play("hit").
# pitch_spread — случайный разброс высоты тона, чтобы одинаковые шаги и удары звучали живее.
# extra_db — сделать конкретный вызов чуть тише (например -4.0) или громче.
func play(sound_name: String, pitch_spread: float = 0.06, extra_db: float = 0.0) -> void:
	if muted or _players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_played_ms.get(sound_name, -1000) < MIN_INTERVAL_MS:
		return
	var stream: AudioStream = _get_stream(sound_name)
	if stream == null:
		return
	_last_played_ms[sound_name] = now

	var player: AudioStreamPlayer = _pick_player()
	player.stream = stream
	player.volume_db = volume_db + extra_db
	player.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread) if pitch_spread > 0.0 else 1.0
	player.play()


# Подключает звук клика к кнопке (безопасно вызывать повторно — дважды не подключится)
func bind_button(button: BaseButton, sound_name: String = "ui_click") -> void:
	if button == null:
		return
	var cb: Callable = play.bind(sound_name, 0.04)
	if not button.pressed.is_connected(cb):
		button.pressed.connect(cb)


func _pick_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var idx: int = (_next_player + i) % POOL_SIZE
		if not _players[idx].playing:
			_next_player = (idx + 1) % POOL_SIZE
			return _players[idx]
	var fallback: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	return fallback


func _get_stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var stream: AudioStream = null
	for ext: String in [".ogg", ".wav"]:
		var path: String = SOUND_DIR + sound_name + ext
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			break
	if stream == null:
		var wav_path: String = SOUND_DIR + sound_name + ".wav"
		if FileAccess.file_exists(wav_path):
			stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(wav_path))
	if stream == null:
		push_warning("Нет звука: %s%s.wav" % [SOUND_DIR, sound_name])
	_streams[sound_name] = stream
	return stream
