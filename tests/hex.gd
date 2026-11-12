extends SceneTree
# Проверка ядра гексагональной сетки (HexMath): расстояния, соседи, кольца, линии,
# повороты, перевод клетка <-> мир, прямоугольное поле.
# Запуск: godot --headless --path . -s tests/hex.gd

var fails: int = 0
var checks: int = 0


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("ОШИБКА: ", what)


func _initialize() -> void:
	var o := Vector2i.ZERO

	# --- соседи и расстояние ---
	var n: Array[Vector2i] = HexMath.neighbors(o)
	ok(n.size() == 6, "6 соседей")
	for c in n:
		ok(HexMath.distance(o, c) == 1, "сосед на расстоянии 1: %s" % c)
	ok(HexMath.distance(Vector2i(2, -1), Vector2i(-1, 2)) == 3, "расстояние (2,-1)-(-1,2) = 3")
	ok(HexMath.distance(Vector2i(3, 0), Vector2i(0, 3)) == 3, "расстояние (3,0)-(0,3) = 3")
	ok(HexMath.distance(Vector2i(5, 5), Vector2i(5, 5)) == 0, "расстояние до себя = 0")
	# симметрия и неравенство треугольника на случайных клетках
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 500:
		var a := Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
		var b := Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
		var c := Vector2i(rng.randi_range(-8, 8), rng.randi_range(-8, 8))
		ok(HexMath.distance(a, b) == HexMath.distance(b, a), "симметрия расстояния")
		ok(HexMath.distance(a, c) <= HexMath.distance(a, b) + HexMath.distance(b, c), "неравенство треугольника")

	# --- кольца и круги ---
	for r in range(0, 6):
		var ring: Array[Vector2i] = HexMath.ring(o, r)
		ok(ring.size() == (1 if r == 0 else 6 * r), "размер кольца %d" % r)
		var seen: Dictionary = {}
		for c in ring:
			ok(HexMath.distance(o, c) == r, "клетка кольца %d на расстоянии %d: %s" % [r, r, c])
			ok(not seen.has(c), "в кольце нет повторов")
			seen[c] = true
		var disc: Array[Vector2i] = HexMath.in_range(o, r)
		ok(disc.size() == 3 * r * (r + 1) + 1, "размер круга %d" % r)
		for c in disc:
			ok(HexMath.distance(o, c) <= r, "клетка круга в пределах %d" % r)
	# кольцо идёт непрерывно: соседние клетки кольца — вплотную друг к другу
	var ring3: Array[Vector2i] = HexMath.ring(Vector2i(2, 1), 3)
	for i in ring3.size():
		ok(HexMath.distance(ring3[i], ring3[(i + 1) % ring3.size()]) == 1, "кольцо замкнуто без разрывов")
	ok(HexMath.cluster(Vector2i(4, 4)).size() == 7, "кластер из 7 клеток")

	# --- направления ---
	for d: Vector2i in HexMath.DIRS:
		ok(HexMath.rotate_dir(d, 6) == d, "поворот на 6 шагов = на месте")
		ok(HexMath.opposite(HexMath.opposite(d)) == d, "дважды противоположное = то же")
		ok(HexMath.opposite(d) == -d, "противоположное = минус: %s" % d)
		ok(HexMath.direction_to(o, d * 3) == d, "direction_to вдоль линии: %s" % d)
		ok(HexMath.straight_dir(o, d * 4) == d, "straight_dir вдоль линии: %s" % d)
	ok(HexMath.straight_dir(o, Vector2i(2, 1)) == Vector2i.ZERO, "не по линии — ZERO")
	ok(HexMath.straight_dir(o, Vector2i(1, 1)) == Vector2i.ZERO, "(1,1) — не соседняя линия")
	ok(HexMath.direction_to(o, Vector2i(2, -1)) == Vector2i(1, 0) or HexMath.direction_to(o, Vector2i(2, -1)) == Vector2i(1, -1),
			"direction_to выбирает одно из двух ближайших")

	# --- линия ---
	for i in 200:
		var a := Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		var b := Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		var line: Array[Vector2i] = HexMath.line_draw(a, b)
		ok(line.size() == HexMath.distance(a, b) + 1, "длина линии = расстояние + 1")
		ok(line[0] == a and line[line.size() - 1] == b, "линия от a до b")
		for k in line.size() - 1:
			ok(HexMath.distance(line[k], line[k + 1]) == 1, "линия без разрывов")
	var ray: Array[Vector2i] = HexMath.ray(o, Vector2i(1, 0), 3)
	ok(ray == [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], "луч вправо на 3")

	# --- дуга и стена ---
	for d: Vector2i in HexMath.DIRS:
		var arc: Array[Vector2i] = HexMath.arc(o, d)
		ok(arc.size() == 3, "дуга из 3 клеток")
		for c in arc:
			ok(HexMath.distance(o, c) == 1, "клетки дуги вплотную к герою")
		var wall: Array[Vector2i] = HexMath.wall(Vector2i(3, 0), d)
		ok(wall.size() == 3, "стена из 3 клеток")
		ok(HexMath.distance(wall[1], wall[2]) == 2, "стена: края через одну клетку (прямая)")

	# --- клетка <-> мир ---
	ok(HexMath.axial_to_world(o).is_zero_approx(), "клетка (0,0) — начало координат")
	for d: Vector2i in HexMath.DIRS:
		var w: Vector3 = HexMath.axial_to_world(d)
		ok(absf(w.length() - 1.0) < 0.0001, "соседи в 1 м друг от друга: %s" % d)
	for i in 400:
		var c := Vector2i(rng.randi_range(-15, 15), rng.randi_range(-15, 15))
		ok(HexMath.world_to_axial(HexMath.axial_to_world(c)) == c, "туда-обратно: %s" % c)
		# небольшой сдвиг внутри клетки не меняет клетку (радиус вписанной окружности = 0,5 м)
		var jitter := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
		ok(HexMath.world_to_axial(HexMath.axial_to_world(c) + jitter) == c, "точка внутри клетки: %s" % c)

	# --- прямоугольное поле 12×12 ---
	var field: Array[Vector2i] = HexMath.rect_cells(12, 12)
	ok(field.size() == 144, "поле 12×12 = 144 клетки")
	for c in field:
		ok(HexMath.in_rect(c, 12, 12), "клетка поля внутри поля")
		ok(HexMath.from_column(HexMath.column_of(c), c.y) == c, "колонка туда-обратно")
		var x: float = HexMath.axial_to_world(c).x
		# края поля в мире почти ровные: половина клетки допуска на сдвиг рядов
		ok(x >= -0.01 and x <= 11.5 + 0.01, "клетка в пределах ширины поля: %s" % c)
	ok(not HexMath.in_rect(Vector2i(-1, 0), 12, 12), "слева за краем")
	ok(not HexMath.in_rect(Vector2i(12, 0), 12, 12), "справа за краем")
	ok(not HexMath.in_rect(Vector2i(0, 12), 12, 12), "ниже поля")
	ok(not HexMath.in_rect(Vector2i(0, -1), 12, 12), "выше поля")
	# каждая внутренняя клетка поля имеет соседей по краям: у соседей-по-ряду колонки отличаются на 1
	var edge_total: int = 0
	for c in field:
		for nb in HexMath.neighbors(c):
			if HexMath.in_rect(nb, 12, 12):
				edge_total += 1
	ok(edge_total > 0 and edge_total % 2 == 0, "связи на поле парные (сосед — взаимно)")

	print("Проверок: %d, ошибок: %d" % [checks, fails])
	quit(1 if fails > 0 else 0)
