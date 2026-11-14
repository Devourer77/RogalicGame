class_name Unit
extends Node3D
# Фигурка на поле (герой или враг): знает свою клетку и умеет красиво
# двигаться, получать удар, бить и умирать. Правил не знает — это только «картинка».
# Каждая анимация — функция, которую можно дождаться через await.

signal move_finished  # срабатывает, когда фигурка дошла до новой клетки

const MOVE_TIME_PER_CELL: float = 0.2  # сколько секунд уходит на одну клетку пути
const PUSH_TIME_PER_CELL: float = 0.1

@export var cell: Vector2i = Vector2i.ZERO  # клетка, на которой стоит фигурка

var board: Board          # поле, на котором стоит фигурка (задаёт сцена боя)
var is_moving: bool = false
var _plate: UnitPlate     # плашка над головой: полоса HP, блок, намерение врага
var _plate_height: float = 2.0   # на какой высоте над клеткой она висит (в метрах)
var _idle_speed: float = 1.0   # личный темп анимации покоя
var _anim: AnimationPlayer  # анимации модели (есть у рыцаря; у моделей без них — простые Tween)

const WALK_SPEED: float = 1.6   # во сколько раз ускорить анимацию ходьбы, чтобы шаги совпали с движением


# Мгновенно ставит фигурку на клетку (используется при старте боя)
func place_at(new_cell: Vector2i) -> void:
	cell = new_cell
	position = board.grid_to_world(cell)


# Плавно ведёт фигурку на клетку по прямой и поворачивает её лицом по ходу движения
func move_to(new_cell: Vector2i) -> void:
	if is_moving or new_cell == cell:
		return

	var target: Vector3 = board.grid_to_world(new_cell)
	var direction: Vector3 = target - position
	rotation.y = atan2(direction.x, direction.z)  # модель смотрит вдоль +Z, поэтому так

	is_moving = true
	cell = new_cell
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target, MOVE_TIME_PER_CELL * direction.length())
	await tween.finished  # ждём, пока анимация движения закончится
	is_moving = false
	move_finished.emit()


# Ищет AnimationPlayer внутри модели. Вызывать после того, как модель добавлена.
# Idle и Walk зацикливаем, остальные анимации играют один раз.
func setup_animations() -> void:
	var players: Array[Node] = find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0] as AnimationPlayer
	for anim_name: String in ["Idle", "Walk"]:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play_loop("Idle")
	# Каждый начинает «дышать» со своего места и в своём темпе —
	# иначе все одинаковые враги качаются строем, как заводные.
	# (Это только вид, поэтому обычный randf, а не общий rng забега.)
	if has_anim("Idle"):
		_idle_speed = randf_range(0.88, 1.12)
		_anim.speed_scale = _idle_speed
		_anim.seek(randf() * _anim.get_animation("Idle").length, true)


func has_anim(anim_name: String) -> bool:
	return _anim != null and _anim.has_animation(anim_name)


# Идёт по пути клетка за клеткой (путь считает логика боя)
func follow_path(path: Array[Vector2i]) -> void:
	is_moving = true
	_play_loop("Walk", WALK_SPEED)
	for i in range(1, path.size()):
		face_dir(path[i] - path[i - 1])
		Sfx.play("step", 0.1)
		var tween: Tween = create_tween()
		tween.tween_property(self, "position", board.grid_to_world(path[i]), MOVE_TIME_PER_CELL)
		await tween.finished
	cell = path[path.size() - 1]
	is_moving = false
	_play_loop("Idle")
	move_finished.emit()


# Поворачивает фигурку в сторону направления на сетке
func face_dir(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var world: Vector3 = HexMath.axial_to_world(dir)   # направление на сетке -> вектор в мире
	rotation.y = atan2(world.x, world.z)


# Толчок: быстро «отлетает» по пути, а если врезался — трясётся
func play_push(path: Array[Vector2i], bumped: bool) -> void:
	if path.size() > 1:
		Sfx.play("push", 0.08)
		var tween: Tween = create_tween()
		tween.tween_property(self, "position", board.grid_to_world(path[path.size() - 1]),
				PUSH_TIME_PER_CELL * (path.size() - 1)).set_ease(Tween.EASE_OUT)
		await tween.finished
	cell = path[path.size() - 1]
	if bumped:
		Sfx.play("hit", 0.08)
		await _shake()


# Получил урон: анимация Hit, а если её нет — фигурка «подпрыгивает» в размере
func play_hit() -> void:
	if has_anim("Hit"):
		await _play_once("Hit", 0.25)   # ждём только начало, дальше анимация доиграет сама
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.25, 0.8, 1.25), 0.07)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12)
	await tween.finished


# Удар: анимация Attack или простой выпад в сторону направления и обратно.
# anim_name — особая анимация удара (например, Attack2 у корягача); нет такой — играем Attack.
func play_attack(dir: Vector2i, anim_name: String = "Attack") -> void:
	face_dir(dir)
	if not has_anim(anim_name):
		anim_name = "Attack"
	if has_anim(anim_name):
		await _play_once(anim_name, 0.4)   # к 0.4 сек меч уже опустился — можно показывать урон
		return
	var base: Vector3 = position
	var lunge: Vector3 = base + HexMath.axial_to_world(dir).normalized() * 0.35
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", lunge, 0.1)
	tween.tween_property(self, "position", base, 0.15)
	await tween.finished


# Блок щитом или магический купол (для карт защиты). Если анимации нет — ничего не делаем.
func play_block() -> void:
	if has_anim("Block"):
		await _play_once("Block", 0.2)


# Каст направленного заклинания (Огненный шар, Ледяное копьё, Волна, Порыв ветра, Толчок)
func play_cast(dir: Vector2i) -> void:
	face_dir(dir)
	if has_anim("Cast"):
		await _play_once("Cast", 0.35)   # к 0.35 сек посох уже направлен вперёд — вылетает заклинание
	elif has_anim("Attack"):
		await _play_once("Attack", 0.35)


# Призыв заклинания с небес или на себя (Метеор, Молния, Рывок)
func play_cast_sky(dir: Vector2i) -> void:
	face_dir(dir)
	if has_anim("CastSky"):
		await _play_once("CastSky", 0.45)  # к 0.45 сек посох воздет к небу и опускается
	elif has_anim("Cast"):
		await _play_once("Cast", 0.35)


# Утонул в трясине: медленно уходит вниз и исчезает
func play_sink() -> void:
	if _anim != null:
		_anim.stop()
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 1.6, 0.7).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false


# Смерть: анимация Death (тело остаётся лежать) или фигурка сжимается и исчезает
func play_death() -> void:
	if has_anim("Death"):
		_anim.play("Death")
		await _anim.animation_finished
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.3)
	await tween.finished
	visible = false


# Начать падение (анимация Death), не дожидаясь конца. Дальше фигурку растворяет VfxPlayer.
# Возвращает false, если анимации смерти у модели нет.
func start_death() -> bool:
	if not has_anim("Death"):
		return false
	_anim.play("Death")
	return true


# Создаёт плашку над головой. height — высота над клеткой в метрах.
# Плашка — 2D-узел (Control): он рисуется поверх 3D, а мы каждый кадр
# ставим его в ту точку экрана, где у фигурки «макушка».
func setup_label(height: float) -> void:
	_plate_height = height
	_plate = UnitPlate.new()
	add_child(_plate)
	_update_plate()


# info — что показать на плашке (собирает сцена боя, см. Battle._plate_info)
func set_status(info: Dictionary) -> void:
	if _plate != null:
		_plate.set_info(info)
		_plate.modulate.a = 1.0 if info["hp"] > 0 else 0.0   # у павших плашки нет


func _process(_delta: float) -> void:
	_update_plate()


# Переводит точку над головой из 3D в координаты экрана и ставит туда плашку
func _update_plate() -> void:
	if _plate == null:
		return
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var point: Vector3 = global_position + Vector3(0.0, _plate_height, 0.0)
	if camera == null or not visible or camera.is_position_behind(point):
		_plate.visible = false
		return
	_plate.visible = true
	var screen: Vector2 = camera.unproject_position(point)
	_plate.position = (screen - Vector2(UnitPlate.PLATE_SIZE.x / 2.0, UnitPlate.PLATE_SIZE.y)).round()
	_plate.position.y = maxf(_plate.position.y, 2.0)   # у высоких врагов в дальнем ряду плашка не уезжает за верх экрана


func _shake() -> void:
	var base: Vector3 = position
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", base + Vector3(0.08, 0.0, 0.0), 0.04)
	tween.tween_property(self, "position", base - Vector3(0.08, 0.0, 0.0), 0.08)
	tween.tween_property(self, "position", base, 0.04)
	await tween.finished


# Зацикленная анимация (покой, ходьба)
func _play_loop(anim_name: String, speed: float = 1.0) -> void:
	if has_anim(anim_name):
		_anim.play(anim_name, 0.15, speed)   # 0.15 сек — плавный переход из прошлой анимации


# Разовая анимация. Ждём wait_time секунд (момент удара), а когда она
# доиграет до конца — сама вернётся в Idle.
func _play_once(anim_name: String, wait_time: float) -> void:
	_anim.play(anim_name, 0.1)
	_anim.queue("Idle")
	await get_tree().create_timer(wait_time).timeout
