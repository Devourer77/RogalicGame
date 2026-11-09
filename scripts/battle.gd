extends Node3D
# Сцена боя: связывает поле, камеру и фигурки, обрабатывает клики мышью

@onready var board: Board = $Board
@onready var camera: Camera3D = $Camera3D
@onready var hero: Unit = $Hero


func _ready() -> void:
	hero.board = board
	hero.place_at(hero.cell)


# Ловим клики мышью, которые не забрал интерфейс
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = _screen_to_cell(click.position)
		if board.is_inside(cell):
			hero.move_to(cell)


# Переводит точку на экране в клетку поля:
# пускаем луч из камеры через курсор и смотрим, где он пересёк пол (высота 0)
func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var ray_from: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	var floor_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = floor_plane.intersects_ray(ray_from, ray_dir)
	if hit == null:
		return Vector2i(-1, -1)  # луч ушёл в небо — клетки нет
	return board.world_to_grid(hit)
