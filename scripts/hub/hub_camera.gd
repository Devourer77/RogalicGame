class_name HubCamera
extends Camera3D
## Камера хаба: плавно едет за героем, поворот Q/R (не больше ±30°), зум колесом мыши.
## Умеет перелететь к другому герою (Tab) и наехать на объект (когда открыта панель).

const PITCH_DEG: float = 40.0         # наклон камеры вниз (в бою 60°; ниже — больше видно вдаль)
const DIST_MIN: float = 7.0           # ближайший зум, метров от точки взгляда
const DIST_MAX: float = 12.0          # дальнейший зум
const DIST_START: float = 9.5
const YAW_LIMIT_DEG: float = 30.0     # на сколько градусов можно повернуть камеру в каждую сторону
const YAW_SPEED_DEG: float = 70.0     # скорость поворота, градусов в секунду
const ZOOM_STEP: float = 0.8
const FOLLOW_SPEED: float = 6.0       # чем больше, тем резче камера догоняет героя
const LOOK_HEIGHT: float = 0.8        # точка взгляда — на уровне пояса героя
const FLY_TIME: float = 0.4           # перелёт к другому герою / наезд на объект
const FOCUS_DIST: float = 6.0         # на каком расстоянии камера смотрит на объект

signal flight_finished

var target: Node3D                    # за кем едем (герой)
var _yaw_deg: float = 0.0
var _dist: float = DIST_START
var _look_point: Vector3 = Vector3.ZERO
var _tween: Tween
var _busy: bool = false               # идёт перелёт или камера «стоит» на объекте — за героем не едем
var _saved_dist: float = DIST_START


func _ready() -> void:
	fov = 60.0
	_build_backdrop()


func _process(delta: float) -> void:
	if target == null:
		return
	# Поворот: удерживаем Q или R.
	var turn: float = Input.get_axis("hub_turn_left", "hub_turn_right")
	_yaw_deg = clampf(_yaw_deg + turn * YAW_SPEED_DEG * delta, -YAW_LIMIT_DEG, YAW_LIMIT_DEG)
	# Плавное следование за героем (кроме перелётов и наезда на объект).
	if not _busy:
		var wanted: Vector3 = target.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0)
		_look_point = _look_point.lerp(wanted, 1.0 - exp(-FOLLOW_SPEED * delta))
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _busy:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = clampf(_dist - ZOOM_STEP, DIST_MIN, DIST_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = clampf(_dist + ZOOM_STEP, DIST_MIN, DIST_MAX)


## Сразу поставить камеру на героя, без плавного подъезда (при старте хаба).
func snap_to_target() -> void:
	if target == null:
		return
	_look_point = target.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0)
	_apply()


## Перелететь к другому герою за FLY_TIME секунд. Новый перелёт отменяет прошлый.
func fly_to(new_target: Node3D) -> void:
	_kill_tween()
	_busy = true
	target = new_target
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "_look_point", new_target.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0), FLY_TIME)
	_tween.finished.connect(_end_flight)


## Наехать на объект (открылась панель): смотрим на точку и приближаемся.
func focus_on(point: Vector3) -> void:
	_kill_tween()
	_busy = true
	_saved_dist = _dist
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	_tween.tween_property(self, "_look_point", point, FLY_TIME)
	_tween.tween_property(self, "_dist", minf(_dist, FOCUS_DIST), FLY_TIME)


## Вернуться к герою (панель закрыли).
func release_focus() -> void:
	if target == null:
		return
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	_tween.tween_property(self, "_look_point", target.global_position + Vector3(0.0, LOOK_HEIGHT, 0.0), FLY_TIME)
	_tween.tween_property(self, "_dist", _saved_dist, FLY_TIME)
	_tween.finished.connect(_end_flight)


func _end_flight() -> void:
	_busy = false
	flight_finished.emit()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _apply() -> void:
	var pitch: float = deg_to_rad(PITCH_DEG)
	var offset: Vector3 = Vector3(0.0, sin(pitch), cos(pitch)) * _dist
	offset = offset.rotated(Vector3.UP, deg_to_rad(_yaw_deg))
	global_position = _look_point + offset
	look_at(_look_point, Vector3.UP)


# Шпиль-заглушка. Камера смотрит вниз, и настоящий Шпиль на горизонте в кадр не попал бы,
# поэтому он прикреплён к камере и всегда виден вверху экрана, как задник.
func _build_backdrop() -> void:
	var spire := MeshInstance3D.new()
	spire.name = "SpireBackdrop"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 5.0
	cone.height = 34.0
	spire.mesh = cone
	spire.material_override = _flat_material(Color(0.14, 0.17, 0.19), 0.0)   # чуть светлее воды, иначе силуэт теряется
	# Правее колокола: над дальним краем заставы видна лишь узкая полоса воды, и там Шпиль не прячется за рамой
	spire.position = Vector3(9.0, 24.0, -70.0)
	add_child(spire)

	# Трещина в небе — тонкая бирюзовая полоса за Шпилем.
	var crack := MeshInstance3D.new()
	crack.name = "SkyCrack"
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 14.0, 0.1)
	crack.mesh = box
	crack.material_override = _flat_material(Color(0.35, 0.95, 0.85), 2.0)
	crack.position = Vector3(10.5, 36.0, -72.0)
	add_child(crack)


func _flat_material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.disable_fog = true   # задник далеко: в тумане он бы растворился полностью
	# Рисуется после воды (у неё render_priority 0), но перед ним остаются все постройки заставы
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 10
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
