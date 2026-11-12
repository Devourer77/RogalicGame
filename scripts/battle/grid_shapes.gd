class_name GridShapes
extends RefCounted
# «Геометрия» сетки: направления, расстояния, формы областей.
# Все функции статические (static) — вызываются прямо по имени класса,
# например GridShapes.manhattan(a, b), без создания объекта.

# Четыре направления: вправо, влево, вниз (к игроку), вверх
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
# Четыре направления наискосок
const DIAG_DIRS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


# Расстояние «по клеткам», если ходить только по прямой (без диагоналей)
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# Главное из четырёх направлений от клетки from к клетке to
static func cardinal_dir(from: Vector2i, to: Vector2i) -> Vector2i:
	var d: Vector2i = to - from
	if d == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(d.x) >= absi(d.y):
		return Vector2i(signi(d.x), 0)
	return Vector2i(0, signi(d.y))


# Направление, повёрнутое на 90° (нужно для удара «по трём клеткам»)
static func perpendicular(dir: Vector2i) -> Vector2i:
	return Vector2i(-dir.y, dir.x)


# Крест: центр и 4 соседа
static func cross_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [center]
	for d: Vector2i in DIRS:
		cells.append(center + d)
	return cells


# Квадрат 3×3 вокруг центра
static func square_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			cells.append(center + Vector2i(dx, dy))
	return cells


# Косой крест: центр и 4 клетки наискосок от него
static func xcross_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [center]
	for d: Vector2i in DIAG_DIRS:
		cells.append(center + d)
	return cells
