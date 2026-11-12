class_name HexMath
extends RefCounted
# «Геометрия» гексагональной сетки (соты). Все функции статические — вызываются
# по имени класса: HexMath.distance(a, b), HexMath.neighbors(cell) и так далее.
#
# Как хранятся клетки:
#  • клетка — Vector2i(q, r). Это «осевые» координаты (axial): q идёт вдоль ряда
#    вправо, r — номер ряда сверху вниз (как y раньше). Третья координата считается
#    сама: s = -q - r (вместе q + r + s всегда = 0). Её храним не нужно,
#    она нужна только в формулах расстояния и поворотов.
#  • Гексы «острым углом вверх» (pointy-top): рядом лежат клетки слева и справа
#    в одном ряду, а соседи сверху и снизу сдвинуты на пол-клетки.
#  • Поле остаётся прямоугольным: у ряда r клетки идут от q = -(r / 2) вправо,
#    поэтому ряды визуально выровнены (см. rect_cells / in_rect).
#
# «Прямо вверх» на экране (к врагам). Это не сосед, а направление между двумя соседями
# (вправо-вверх и влево-вверх): нужно, чтобы фигурка смотрела строго вперёд.
const FACE_UP: Vector2i = Vector2i(1, -2)

# Шесть направлений занумерованы по часовой стрелке (если смотреть сверху):
#   0 — вправо, 1 — вправо-вниз, 2 — влево-вниз, 3 — влево, 4 — влево-вверх, 5 — вправо-вверх.
# «Вниз» на экране — к героям (рост r), «вверх» — к врагам.

# Расстояние между центрами соседних клеток в метрах. Раньше клетка была 1 м,
# теперь на 15% крупнее — подкрутить размер поля можно одним числом здесь.
const CELL_STEP: float = 1.15
const SQRT3: float = 1.7320508075688772
# Радиус гекса от центра до угла (из CELL_STEP: расстояние между центрами = радиус × √3)
const HEX_SIZE: float = CELL_STEP / SQRT3

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1),
]


# ---------- Расстояния и соседи ----------

# Расстояние в шагах между клетками (по формуле для кубических координат)
static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


# Шесть соседних клеток (в порядке DIRS)
static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		result.append(cell + d)
	return result


# Клетки вплотную к cell — то же, что neighbors, но под старым именем «ближний бой»
static func adjacent(a: Vector2i, b: Vector2i) -> bool:
	return distance(a, b) == 1


# ---------- Направления ----------

# Поворот направления на steps шагов по 60° (положительное число — по часовой стрелке)
static func rotate_dir(dir: Vector2i, steps: int) -> Vector2i:
	var i: int = DIRS.find(dir)
	if i < 0:
		return Vector2i.ZERO
	return DIRS[posmod(i + steps, 6)]


# Противоположное направление
static func opposite(dir: Vector2i) -> Vector2i:
	return rotate_dir(dir, 3)


# Какое из шести направлений от from лучше всего «смотрит» на to.
# Если to лежит ровно между двумя направлениями, берётся то, что первое в списке DIRS.
# (Старый аналог — GridShapes.cardinal_dir.)
static func direction_to(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	var target: Vector3 = axial_to_world(to) - axial_to_world(from)
	var best: Vector2i = DIRS[0]
	var best_dot: float = -INF
	for d: Vector2i in DIRS:
		var w: Vector3 = axial_to_world(d)   # вектор направления (клетка (0,0) стоит в нуле)
		var dot: float = w.dot(target)
		if dot > best_dot + 0.0001:
			best_dot = dot
			best = d
	return best


# Если to лежит строго по одной из шести линий от from — возвращает это направление,
# иначе Vector2i.ZERO. Нужно картам и ударам «по прямой» (линия, таран, толчок).
static func straight_dir(from: Vector2i, to: Vector2i) -> Vector2i:
	if from == to:
		return Vector2i.ZERO
	var d: Vector2i = to - from
	var n: int = distance(from, to)
	if d.x % n != 0 or d.y % n != 0:
		return Vector2i.ZERO
	var unit: Vector2i = Vector2i(d.x / n, d.y / n)
	return unit if DIRS.has(unit) else Vector2i.ZERO


# ---------- Области ----------

# Кольцо: все клетки ровно на расстоянии radius от центра
static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius <= 0:
		if radius == 0:
			result.append(center)
		return result
	# Стартуем в углу «слева-вверху» и идём по шести сторонам кольца
	var cell: Vector2i = center + DIRS[4] * radius
	for side in 6:
		var step: Vector2i = DIRS[side]
		for i in radius:
			result.append(cell)
			cell += step
	return result


# Заполненный круг: центр и все клетки на расстоянии до radius включительно
static func in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			result.append(center + Vector2i(q, r))
	return result


# Кластер: центр и 6 соседей (7 клеток). Заменяет «крест» и «квадрат 3×3».
static func cluster(center: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [center]
	for d: Vector2i in DIRS:
		result.append(center + d)
	return result


# Линия клеток от a до b (включая обе). Идёт по прямой, учитывая «неровные» случаи
# микро-сдвигом, чтобы линия не прыгала на границе двух клеток.
static func line_draw(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n: int = distance(a, b)
	var result: Array[Vector2i] = []
	if n == 0:
		result.append(a)
		return result
	# Крошечный одинаковый сдвиг обоих концов: середина ребра между клетками
	# всегда округляется в одну и ту же сторону, линия не «дрожит»
	var ax: float = a.x + 0.000001
	var ay: float = a.y + 0.000001
	var bx: float = b.x + 0.000001
	var by: float = b.y + 0.000001
	for i in n + 1:
		var t: float = float(i) / float(n)
		result.append(_cube_round(lerpf(ax, bx, t), lerpf(ay, by, t)))
	return result


# Линия от from в сторону dir длиной length (без самой клетки from).
# Это основа «линейных» ударов и заклинаний — аналог старого from + dir * i.
static func ray(from: Vector2i, dir: Vector2i, length: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in range(1, length + 1):
		result.append(from + dir * i)
	return result


# Дуга (размах оружием): клетка front (стоит вплотную к from) и её соседи, что тоже
# лежат вплотную к from. Всегда 3 клетки. Если front не рядом с from — возвращает [front].
static func arc(from: Vector2i, front: Vector2i) -> Array[Vector2i]:
	var d: Vector2i = front - from
	var i: int = DIRS.find(d)
	var result: Array[Vector2i] = [front]
	if i < 0:
		return result
	result.append(from + DIRS[posmod(i - 1, 6)])
	result.append(from + DIRS[posmod(i + 1, 6)])
	return result


# Стена из 3 клеток «поперёк» направления: центр target и ещё две клетки, что лежат
# с ним на одной прямой. Ровно под 90° к dir в сотах линии нет (есть только под 60°),
# поэтому стена чуть наклонена — на 30° от «идеально поперёк». Это нормально для сот.
static func wall(target: Vector2i, dir: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = [target]
	var i: int = DIRS.find(dir)
	if i < 0:
		return result
	result.append(target + DIRS[posmod(i + 2, 6)])
	result.append(target + DIRS[posmod(i - 1, 6)])
	return result


# ---------- Координаты в мире ----------

# Клетка → точка в 3D-мире (центр клетки, высота 0). Клетка (0,0) — в начале координат.
static func axial_to_world(cell: Vector2i, size: float = HEX_SIZE) -> Vector3:
	var x: float = size * SQRT3 * (cell.x + cell.y * 0.5)
	var z: float = size * 1.5 * cell.y
	return Vector3(x, 0.0, z)


# Точка в 3D-мире → клетка, в которую она попадает
static func world_to_axial(point: Vector3, size: float = HEX_SIZE) -> Vector2i:
	var q: float = (SQRT3 / 3.0 * point.x - 1.0 / 3.0 * point.z) / size
	var r: float = (2.0 / 3.0 * point.z) / size
	return _cube_round(q, r)


# Округление дробных координат до ближайшей клетки (через кубические q, r, s)
static func _cube_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var rq: int = roundi(q)
	var rr: int = roundi(r)
	var rs: int = roundi(s)
	var dq: float = absf(rq - q)
	var dr: float = absf(rr - r)
	var ds: float = absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(rq, rr)


# ---------- Прямоугольное поле ----------
# Поле width × height клеток: ряд r (0 — верхний, враги) содержит клетки
# q от -(r / 2) до width - 1 - (r / 2). Так края поля на экране остаются ровными.

static func rect_first_q(r: int) -> int:
	return -(r / 2)


static func in_rect(cell: Vector2i, width: int, height: int) -> bool:
	if cell.y < 0 or cell.y >= height:
		return false
	var first: int = rect_first_q(cell.y)
	return cell.x >= first and cell.x < first + width


# Все клетки прямоугольного поля, ряд за рядом сверху вниз
static func rect_cells(width: int, height: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for r in height:
		var first: int = rect_first_q(r)
		for i in width:
			result.append(Vector2i(first + i, r))
	return result


# Номер клетки в ряду слева направо (0..width-1) — удобно для «колонки» в расстановке арен
static func column_of(cell: Vector2i) -> int:
	return cell.x - rect_first_q(cell.y)


# Клетка по номеру колонки и ряда
static func from_column(column: int, row: int) -> Vector2i:
	return Vector2i(rect_first_q(row) + column, row)
