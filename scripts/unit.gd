class_name Unit
extends Node3D
# Фигурка на поле (герой или враг): знает свою клетку и умеет плавно туда переходить

signal move_finished  # срабатывает, когда фигурка дошла до новой клетки

const MOVE_TIME_PER_CELL: float = 0.2  # сколько секунд уходит на одну клетку пути

@export var cell: Vector2i = Vector2i.ZERO  # клетка, на которой стоит фигурка

var board: Board          # поле, на котором стоит фигурка (задаёт сцена боя)
var is_moving: bool = false


# Мгновенно ставит фигурку на клетку (используется при старте боя)
func place_at(new_cell: Vector2i) -> void:
	cell = new_cell
	position = board.grid_to_world(cell)


# Плавно ведёт фигурку на клетку и поворачивает её лицом по ходу движения
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
