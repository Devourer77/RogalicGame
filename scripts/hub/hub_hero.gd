class_name HubHero
extends CharacterBody3D
## Герой в хабе. Активный ходит по WASD относительно камеры, второй сам идёт к костру и садится.
## Облик — та же модель, что в бою (HeroData.model), с анимациями Idle и Walk; если модели нет —
## капсула-заглушка. CharacterBody3D — узел Godot для персонажа, которого двигает код:
## сам упирается в стены при move_and_slide().

const MOVE_SPEED: float = 3.5         # метров в секунду
const TURN_SPEED: float = 12.0        # чем больше, тем быстрее герой разворачивается
const BODY_HEIGHT: float = 1.6
const BODY_RADIUS: float = 0.4
const ARRIVE_DISTANCE: float = 0.25   # так близко к месту — считаем, что пришёл
const SIT_DROP: float = 0.4           # на сколько опускается сидящий герой
const STUCK_CHECK_TIME: float = 1.2   # раз в столько секунд проверяем, не застрял ли идущий к костру
const STUCK_MIN_PROGRESS: float = 0.15
# Во сколько раз ускорить анимацию ходьбы, чтобы шаги совпали со скоростью в хабе
# (в бою герой идёт быстрее, там ускорение 1,6).
const WALK_ANIM_SPEED: float = 1.0

signal arrived   # неактивный герой дошёл до места

@export var hero_id: String = "mage"  # "mage" или "knight"

var model_scene: PackedScene          # модель героя (из HeroData); задать до add_child
var camera: Camera3D                  # ходим относительно этой камеры
var can_move: bool = true             # false, пока открыта панель или камера перелетает
var is_active: bool = true            # под управлением игрока

var _mesh_root: Node3D
var _anim: AnimationPlayer            # анимации модели; null — у капсулы
var _walk_time: float = 0.0
var _goal: Vector3 = Vector3.ZERO
var _path: Array[Vector3] = []        # путь по точкам: идём к первой, потом к следующей
var _has_goal: bool = false
var _face_point: Vector3 = Vector3.ZERO
var _seated: bool = false
var _stuck_timer: float = 0.0
var _stuck_last_dist: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING   # без гравитации и «пола»: хаб плоский
	_build_body()


func _physics_process(delta: float) -> void:
	var dir: Vector3 = Vector3.ZERO
	if is_active:
		if can_move and camera != null:
			dir = _input_direction()
	elif _has_goal:
		dir = _goal_direction(delta)

	velocity = dir * MOVE_SPEED
	move_and_slide()

	if dir != Vector3.ZERO:
		_turn_to(dir, delta)
		var prev_step: int = int(_walk_time / PI)
		_walk_time += delta * 9.0
		if is_active and int(_walk_time / PI) > prev_step:
			Sfx.play("step", 0.1, -6.0)
		if _anim != null:
			_play_loop("Walk", WALK_ANIM_SPEED)
		else:
			_mesh_root.position.y = absf(sin(_walk_time)) * 0.06   # покачивание вместо анимации ходьбы
	elif not _seated:
		_walk_time = 0.0
		if _anim != null:
			_play_loop("Idle")
		else:
			_mesh_root.position.y = move_toward(_mesh_root.position.y, 0.0, delta)


# WASD относительно камеры, но по земле (без наклона вниз). По диагонали скорость та же.
func _input_direction() -> Vector3:
	var input: Vector2 = Input.get_vector("hub_left", "hub_right", "hub_up", "hub_down")
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return (right * input.x + forward * (-input.y)).normalized()   # get_vector: вверх даёт отрицательный y


# Куда идти неактивному герою. Пришёл — садится; застрял — просто останавливается.
func _goal_direction(delta: float) -> Vector3:
	var to_goal: Vector3 = _goal - global_position
	to_goal.y = 0.0
	var dist: float = to_goal.length()
	if dist < ARRIVE_DISTANCE:
		if _path.size() > 1:
			_path.pop_front()
			_goal = _path[0]
			_stuck_timer = 0.0
			_stuck_last_dist = 0.0
		else:
			_arrive()
		return Vector3.ZERO
	_stuck_timer += delta
	if _stuck_timer >= STUCK_CHECK_TIME:
		if _stuck_last_dist - dist < STUCK_MIN_PROGRESS and _stuck_last_dist > 0.0:
			_has_goal = false   # не пройти — стоим там, где остановились
			return Vector3.ZERO
		_stuck_last_dist = dist
		_stuck_timer = 0.0
	return to_goal.normalized()


func _turn_to(dir: Vector3, delta: float) -> void:
	var target_yaw: float = atan2(-dir.x, -dir.z)   # лицом по -Z — «вперёд»
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-TURN_SPEED * delta))


# ---------- Управление из хаба ----------

func set_active(value: bool) -> void:
	is_active = value
	can_move = value
	if value:
		_has_goal = false
		_stand_up()


# Идти по точкам пути (последняя — место у костра) и сесть лицом к face_point.
# Промежуточные точки нужны, чтобы обойти постройки: герой идёт по прямой и сам обходить не умеет.
func go_to(points: Array[Vector3], face_point: Vector3) -> void:
	if points.is_empty():
		return
	_path = points.duplicate()
	_goal = _path[0]
	_face_point = face_point
	_has_goal = true
	_seated = false
	_stuck_timer = 0.0
	_stuck_last_dist = 0.0


# Повернуться лицом к точке (когда игрок открыл панель у объекта)
func face_toward(point: Vector3) -> void:
	var d: Vector3 = point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		var target: float = rotation.y + angle_difference(rotation.y, atan2(-d.x, -d.z))   # кратчайший поворот
		create_tween().tween_property(self, "rotation:y", target, 0.25)


func _arrive() -> void:
	_has_goal = false
	_sit()
	arrived.emit()


func _sit() -> void:
	_seated = true
	var d: Vector3 = _face_point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)
	if _anim != null:
		# Анимации «сидеть» у моделей пока нет: герой стоит у огня и «дышит»
		if _anim.has_animation("Sit"):
			_play_loop("Sit")
		else:
			_play_loop("Idle")
		return
	create_tween().tween_property(_mesh_root, "position:y", -SIT_DROP, 0.25)


func _stand_up() -> void:
	if _seated:
		_seated = false
		if _anim == null:
			create_tween().tween_property(_mesh_root, "position:y", 0.0, 0.2)


# Включает зацикленную анимацию, если она ещё не играет (плавный переход 0,15 с)
func _play_loop(anim_name: String, speed: float = 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.15, speed)
	else:
		_anim.speed_scale = speed


# ---------- Заглушка-тело ----------

func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	shape.shape = capsule
	shape.position.y = BODY_HEIGHT * 0.5
	add_child(shape)

	_mesh_root = Node3D.new()
	_mesh_root.name = "Visual"
	add_child(_mesh_root)

	if model_scene != null:
		_build_model()
		return

	# Цвета-якоря героев из мир.md: Маг — тёмно-синий, Рыцарь — тусклая сталь и тёмно-жёлтый.
	var body_color: Color = Color(0.16, 0.2, 0.42) if hero_id == "mage" else Color(0.5, 0.52, 0.55)
	var accent_color: Color = Color(0.45, 0.3, 0.7) if hero_id == "mage" else Color(0.65, 0.5, 0.15)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = BODY_RADIUS * 0.9
	body_mesh.height = BODY_HEIGHT
	body.mesh = body_mesh
	body.material_override = _material(body_color)
	body.position.y = BODY_HEIGHT * 0.5
	_mesh_root.add_child(body)

	# «Нос» — маленький кубик спереди, чтобы было видно, куда герой смотрит.
	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.2, 0.2, 0.3)
	nose.mesh = nose_mesh
	nose.material_override = _material(accent_color)
	nose.position = Vector3(0.0, BODY_HEIGHT * 0.8, -BODY_RADIUS)
	_mesh_root.add_child(nose)


# Модель из боя. Она смотрит на +Z, а в хабе «вперёд» — это −Z, поэтому разворачиваем её на 180°.
func _build_model() -> void:
	var model: Node3D = model_scene.instantiate()
	model.rotation.y = PI
	_mesh_root.add_child(model)
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0] as AnimationPlayer
	for anim_name: String in ["Idle", "Walk", "Sit"]:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_play_loop("Idle")


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material
