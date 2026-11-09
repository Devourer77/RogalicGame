class_name Board
extends Node3D
# Игровое поле: хранит размер сетки и создаёт каменные плиты

const CELL_SIZE: float = 1.0       # размер одной клетки в метрах
const TILE_GAP: float = 0.97       # доля клетки, которую занимает плита (остальное — щель)
const TILE_THICKNESS: float = 0.2  # толщина плиты

# Варианты текстур плит — на каждую клетку берётся случайный
const TILE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/stone_tile_1.png"),
	preload("res://assets/textures/stone_tile_2.png"),
	preload("res://assets/textures/stone_tile_3.png"),
	preload("res://assets/textures/stone_tile_4.png"),
]

@export var width: int = 8   # клеток по горизонтали
@export var height: int = 8  # клеток в глубину
@export var layout_seed: int = 12345  # сид раскладки: одинаковый сид — одинаковое поле


func _ready() -> void:
	_build_cells()


# Переводит координаты клетки (x, y) в позицию в 3D-мире
func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)


# Обратное действие: из точки в 3D-мире получает клетку, в которую она попадает
func world_to_grid(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / CELL_SIZE), roundi(point.z / CELL_SIZE))


# Проверяет, что клетка лежит внутри поля
func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


# Создаёт материал для одного варианта текстуры.
# Triplanar — текстура «проецируется» на плиту сверху и с боков,
# поэтому не нужно настраивать развёртку (UV) у коробки.
func _make_material(texture: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.roughness = 0.9
	mat.uv1_triplanar = true
	var uv_scale: float = 1.0 / (CELL_SIZE * TILE_GAP)
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)  # одна текстура ровно на одну плиту
	mat.uv1_offset = Vector3(0.5, 0.5, 0.5)       # сдвиг, чтобы края текстуры совпали с краями плиты
	return mat


# Создаёт плиту для каждой клетки
func _build_cells() -> void:
	# Пока у раскладки свой генератор случайных чисел.
	# Когда появится общий генератор забега — перейдём на него.
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed

	var materials: Array[StandardMaterial3D] = []
	for tex in TILE_TEXTURES:
		materials.append(_make_material(tex))

	var box := BoxMesh.new()
	box.size = Vector3(CELL_SIZE * TILE_GAP, TILE_THICKNESS, CELL_SIZE * TILE_GAP)

	for x in width:
		for y in height:
			var tile := MeshInstance3D.new()
			tile.mesh = box
			tile.material_override = materials[rng.randi_range(0, materials.size() - 1)]
			tile.position = grid_to_world(Vector2i(x, y)) + Vector3(0.0, -TILE_THICKNESS / 2.0, 0.0)  # верх плиты на уровне 0
			tile.rotation.y = rng.randi_range(0, 3) * PI / 2.0  # поворот на 0/90/180/270° для разнообразия
			add_child(tile)
