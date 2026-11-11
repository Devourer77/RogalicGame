class_name SpellFx
extends RefCounted
# 3D-анимации заклинаний мага на поле боя.
# Создаёт временные светящиеся 3D-фигуры (снаряды, молнии, глыбы льда, волны, купола),
# анимирует их через Tween и автоматически удаляет после завершения.


# Запускает 3D-эффект карты и ждёт его завершения (через await)
static func play(board: Board, card: CardData, from_cell: Vector2i, cells: Array[Vector2i]) -> void:
	var fx := Node3D.new()
	fx.name = "SpellFx_" + card.id
	board.add_child(fx)

	var from_pos: Vector3 = board.grid_to_world(from_cell)
	var center_pos: Vector3 = _center_world(board, cells, from_pos)

	match card.id:
		"fireball":
			await _play_fireball(fx, board, from_pos, center_pos, cells)
		"meteor":
			await _play_meteor(fx, board, center_pos, cells)
		"ice_lance":
			await _play_ice_lance(fx, board, from_pos, cells)
		"lightning":
			await _play_lightning(fx, board, center_pos, cells)
		"wave":
			await _play_wave(fx, board, from_pos, center_pos, cells)
		"gust":
			await _play_gust(fx, board, from_pos, cells)
		"shove":
			await _play_shove(fx, from_pos, center_pos)
		"strike":
			await _play_arcane_strike(fx, from_pos, center_pos)
		"guard":
			await _play_magic_shield(fx, from_pos)
		"dash":
			await _play_dash_aura(fx, from_pos)
		_:
			# Запасной эффект по стихии для любых новых карт
			match card.element:
				CardData.Element.FIRE:
					await _play_fireball(fx, board, from_pos, center_pos, cells)
				CardData.Element.ICE:
					await _play_ice_lance(fx, board, from_pos, cells)
				CardData.Element.WATER:
					await _play_wave(fx, board, from_pos, center_pos, cells)
				CardData.Element.LIGHTNING:
					await _play_lightning(fx, board, center_pos, cells)
				_:
					await board.get_tree().create_timer(0.2).timeout

	fx.queue_free()


# ---------- 1. Огненный шар (fireball): полёт по дуге + взрыв крестом ----------

static func _play_fireball(fx: Node3D, board: Board, from_pos: Vector3, target_pos: Vector3, cells: Array[Vector2i]) -> void:
	var start: Vector3 = from_pos + Vector3(0.0, 1.35, 0.0)
	var end: Vector3 = target_pos + Vector3(0.0, 0.35, 0.0)
	var mid: Vector3 = (start + end) * 0.5 + Vector3(0.0, 1.4, 0.0)

	var orb := Node3D.new()
	orb.position = start
	fx.add_child(orb)

	var core_mat: StandardMaterial3D = _glow_mat(Color(1.0, 0.95, 0.6, 0.95), Color(1.0, 0.9, 0.4), 4.0)
	var fire_mat: StandardMaterial3D = _glow_mat(Color(1.0, 0.42, 0.08, 0.82), Color(1.0, 0.35, 0.05), 3.0)
	orb.add_child(_sphere(0.14, core_mat))
	orb.add_child(_sphere(0.24, fire_mat))

	# Полёт по параболе к центру креста
	var fly: Tween = fx.create_tween()
	fly.tween_method(func(t: float) -> void:
		var a: Vector3 = start.lerp(mid, t)
		var b: Vector3 = mid.lerp(end, t)
		orb.position = a.lerp(b, t)
		orb.scale = Vector3.ONE * (0.85 + 0.35 * sin(t * PI))
	, 0.0, 1.0, 0.28)
	await fly.finished
	orb.visible = false

	# Взрыв: огненные сферы и искры на всех задетых клетках
	var burst: Tween = fx.create_tween().set_parallel(true)
	for c: Vector2i in cells:
		var p: Vector3 = board.grid_to_world(c)
		var blast: MeshInstance3D = _sphere(0.18, fire_mat)
		blast.position = p + Vector3(0.0, 0.25, 0.0)
		fx.add_child(blast)
		burst.tween_property(blast, "scale", Vector3(2.4, 1.8, 2.4), 0.24).set_ease(Tween.EASE_OUT)
		burst.tween_property(blast, "position:y", 0.55, 0.24)

		var spark: MeshInstance3D = _box(Vector3(0.12, 0.32, 0.12), core_mat)
		spark.position = p + Vector3(0.0, 0.2, 0.0)
		fx.add_child(spark)
		burst.tween_property(spark, "position:y", 1.15, 0.24).set_ease(Tween.EASE_OUT)
		burst.tween_property(spark, "scale", Vector3(0.2, 1.4, 0.2), 0.24)
	await burst.finished


# ---------- 2. Метеор (meteor): падение пылающей глыбы с неба + ударная волна 3×3 ----------

static func _play_meteor(fx: Node3D, board: Board, target_pos: Vector3, cells: Array[Vector2i]) -> void:
	var sky_start: Vector3 = target_pos + Vector3(-2.2, 7.5, -2.2)
	var impact: Vector3 = target_pos + Vector3(0.0, 0.35, 0.0)

	var meteor := Node3D.new()
	meteor.position = sky_start
	fx.add_child(meteor)

	var rock_mat: StandardMaterial3D = _glow_mat(Color(0.35, 0.15, 0.08, 1.0), Color(0.9, 0.25, 0.05), 2.2)
	var corona_mat: StandardMaterial3D = _glow_mat(Color(1.0, 0.45, 0.1, 0.78), Color(1.0, 0.4, 0.05), 3.8)
	var core_mat: StandardMaterial3D = _glow_mat(Color(1.0, 0.92, 0.55, 0.95), Color(1.0, 0.85, 0.35), 4.5)

	meteor.add_child(_sphere(0.45, rock_mat))
	meteor.add_child(_sphere(0.62, corona_mat))
	var tail: MeshInstance3D = _cone(0.05, 0.48, 1.8, corona_mat)
	tail.position = Vector3(-0.45, 0.75, -0.45)
	tail.rotation = Vector3(0.0, 0.0, -0.55)
	meteor.add_child(tail)

	var fall: Tween = fx.create_tween()
	fall.tween_property(meteor, "position", impact, 0.32).set_ease(Tween.EASE_IN)
	await fall.finished
	meteor.visible = false

	# Ударное огненное кольцо и столбы пламени на всех клетках 3×3
	var shock: MeshInstance3D = _disc(0.35, 0.08, core_mat)
	shock.position = target_pos + Vector3(0.0, 0.12, 0.0)
	fx.add_child(shock)

	var boom: Tween = fx.create_tween().set_parallel(true)
	boom.tween_property(shock, "scale", Vector3(4.8, 1.0, 4.8), 0.30).set_ease(Tween.EASE_OUT)
	for c: Vector2i in cells:
		var p: Vector3 = board.grid_to_world(c)
		var pillar: MeshInstance3D = _cone(0.08, 0.34, 0.95, corona_mat)
		pillar.position = p + Vector3(0.0, 0.05, 0.0)
		pillar.scale = Vector3(0.5, 0.1, 0.5)
		fx.add_child(pillar)
		boom.tween_property(pillar, "scale", Vector3(1.15, 1.25, 1.15), 0.28).set_ease(Tween.EASE_OUT)
		boom.tween_property(pillar, "position:y", 0.55, 0.28)
	await boom.finished


# ---------- 3. Ледяное копьё (ice_lance): полёт копья + вырастающие глыбы льда по линии ----------

static func _play_ice_lance(fx: Node3D, board: Board, from_pos: Vector3, cells: Array[Vector2i]) -> void:
	var ice_mat: StandardMaterial3D = _glow_mat(Color(0.65, 0.92, 1.0, 0.88), Color(0.35, 0.82, 1.0), 2.8)
	var bright_mat: StandardMaterial3D = _glow_mat(Color(0.9, 0.98, 1.0, 0.95), Color(0.7, 0.95, 1.0), 3.6)

	var end_pos: Vector3 = _center_world(board, cells, from_pos)
	if not cells.is_empty():
		end_pos = board.grid_to_world(cells[cells.size() - 1])

	# Летящее ледяное копьё вдоль линии
	var spear := Node3D.new()
	spear.position = from_pos + Vector3(0.0, 1.05, 0.0)
	fx.add_child(spear)
	var dir_vec: Vector3 = (end_pos - from_pos).normalized()
	if dir_vec.length() > 0.01:
		spear.rotation.y = atan2(dir_vec.x, dir_vec.z)
	var tip: MeshInstance3D = _cone(0.02, 0.14, 0.85, bright_mat)
	tip.rotation.x = PI / 2.0
	spear.add_child(tip)

	var tween: Tween = fx.create_tween().set_parallel(true)
	tween.tween_property(spear, "position", end_pos + Vector3(0.0, 1.05, 0.0), 0.22)

	# Из каждой клетки линии по очереди вырастают острые ледяные кристаллы
	for i in cells.size():
		var p: Vector3 = board.grid_to_world(cells[i])
		var cluster := Node3D.new()
		cluster.position = p
		cluster.scale = Vector3(1.0, 0.05, 1.0)
		fx.add_child(cluster)

		var main_spike: MeshInstance3D = _cone(0.03, 0.24, 0.95, ice_mat)
		main_spike.position = Vector3(0.0, 0.45, 0.0)
		cluster.add_child(main_spike)

		var side_a: MeshInstance3D = _cone(0.02, 0.16, 0.65, bright_mat)
		side_a.position = Vector3(0.18, 0.30, -0.12)
		side_a.rotation.z = -0.28
		cluster.add_child(side_a)

		var side_b: MeshInstance3D = _cone(0.02, 0.15, 0.60, bright_mat)
		side_b.position = Vector3(-0.18, 0.28, 0.14)
		side_b.rotation.z = 0.28
		cluster.add_child(side_b)

		tween.tween_property(cluster, "scale", Vector3.ONE, 0.18).set_delay(i * 0.06).set_ease(Tween.EASE_OUT)

	await tween.finished
	await board.get_tree().create_timer(0.12).timeout


# ---------- 4. Молния (lightning): ломаный разряд с неба + электрические дуги по воде ----------

static func _play_lightning(fx: Node3D, board: Board, target_pos: Vector3, cells: Array[Vector2i]) -> void:
	var bolt_mat: StandardMaterial3D = _glow_mat(Color(1.0, 0.96, 0.55, 0.98), Color(1.0, 0.92, 0.35), 4.8)
	var arc_mat: StandardMaterial3D = _glow_mat(Color(0.45, 0.92, 1.0, 0.9), Color(0.35, 0.88, 1.0), 3.6)

	for c: Vector2i in cells:
		var p: Vector3 = board.grid_to_world(c)
		# Ломаный столб молнии из 4 колен сверху вниз
		var offsets: Array[Vector3] = [
			Vector3(0.0, 5.2, 0.0),
			Vector3(0.22, 3.8, -0.15),
			Vector3(-0.20, 2.4, 0.18),
			Vector3(0.14, 1.1, -0.08),
			Vector3(0.0, 0.05, 0.0),
		]
		for i in range(offsets.size() - 1):
			var seg: MeshInstance3D = _segment(p + offsets[i], p + offsets[i + 1], 0.065, bolt_mat)
			fx.add_child(seg)

		# Электрическое кольцо на земле
		var ring: MeshInstance3D = _disc(0.42, 0.05, arc_mat)
		ring.position = p + Vector3(0.0, 0.08, 0.0)
		fx.add_child(ring)

	# Мерцание разряда молнии
	for pulse in 2:
		fx.visible = true
		await board.get_tree().create_timer(0.07).timeout
		fx.visible = false
		await board.get_tree().create_timer(0.04).timeout
	fx.visible = true
	await board.get_tree().create_timer(0.10).timeout


# ---------- 5. Волна (wave): накатывающий гребень воды 3×3 с брызгами ----------

static func _play_wave(fx: Node3D, board: Board, from_pos: Vector3, center_pos: Vector3, cells: Array[Vector2i]) -> void:
	var water_mat: StandardMaterial3D = _glow_mat(Color(0.18, 0.58, 0.98, 0.78), Color(0.15, 0.50, 0.95), 2.0)
	var foam_mat: StandardMaterial3D = _glow_mat(Color(0.85, 0.96, 1.0, 0.92), Color(0.75, 0.92, 1.0), 2.8)

	var dir: Vector3 = (center_pos - from_pos)
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()

	var wave_root := Node3D.new()
	wave_root.position = center_pos - dir * 1.1
	wave_root.rotation.y = atan2(dir.x, dir.z)
	fx.add_child(wave_root)

	# Широкий вал воды + пенный гребень сверху
	var body: MeshInstance3D = _box(Vector3(2.7, 0.65, 0.55), water_mat)
	body.position = Vector3(0.0, 0.35, 0.0)
	wave_root.add_child(body)

	var crest: MeshInstance3D = _box(Vector3(2.75, 0.22, 0.38), foam_mat)
	crest.position = Vector3(0.0, 0.72, 0.10)
	wave_root.add_child(crest)

	var tween: Tween = fx.create_tween().set_parallel(true)
	tween.tween_property(wave_root, "position", center_pos + dir * 1.1, 0.30).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave_root, "scale:y", 0.35, 0.30).set_ease(Tween.EASE_IN)

	for c: Vector2i in cells:
		var drop: MeshInstance3D = _sphere(0.12, foam_mat)
		drop.position = board.grid_to_world(c) + Vector3(0.0, 0.15, 0.0)
		fx.add_child(drop)
		tween.tween_property(drop, "position:y", 0.75, 0.16).set_ease(Tween.EASE_OUT)
		tween.tween_property(drop, "scale", Vector3.ONE * 0.2, 0.30)

	await tween.finished


# ---------- 6. Порыв ветра (gust): воздушные вихри и дуги вдоль линии ----------

static func _play_gust(fx: Node3D, board: Board, from_pos: Vector3, cells: Array[Vector2i]) -> void:
	var wind_mat: StandardMaterial3D = _glow_mat(Color(0.82, 0.98, 0.92, 0.65), Color(0.65, 0.95, 0.85), 2.4)
	var end_pos: Vector3 = _center_world(board, cells, from_pos)
	if not cells.is_empty():
		end_pos = board.grid_to_world(cells[cells.size() - 1])

	var dir: Vector3 = (end_pos - from_pos)
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()

	var tween: Tween = fx.create_tween().set_parallel(true)
	for i in 3:
		var ring: MeshInstance3D = _disc(0.32 + i * 0.08, 0.04, wind_mat)
		ring.position = from_pos + Vector3(0.0, 0.65 + i * 0.15, 0.0)
		ring.rotation.x = PI / 2.0
		ring.rotation.y = atan2(dir.x, dir.z)
		fx.add_child(ring)
		tween.tween_property(ring, "position", end_pos + Vector3(0.0, 0.65 + i * 0.15, 0.0), 0.26).set_delay(i * 0.04)
		tween.tween_property(ring, "scale", Vector3(1.8, 1.0, 1.8), 0.26).set_delay(i * 0.04)
	await tween.finished


# ---------- 7. Толчок (shove): телекинетическая силовая волна ----------

static func _play_shove(fx: Node3D, from_pos: Vector3, target_pos: Vector3) -> void:
	var force_mat: StandardMaterial3D = _glow_mat(Color(0.55, 0.85, 1.0, 0.82), Color(0.35, 0.75, 1.0), 3.2)
	var pulse: MeshInstance3D = _disc(0.28, 0.08, force_mat)
	pulse.position = from_pos.lerp(target_pos, 0.35) + Vector3(0.0, 0.85, 0.0)
	var dir: Vector3 = (target_pos - from_pos).normalized()
	pulse.rotation.x = PI / 2.0
	pulse.rotation.y = atan2(dir.x, dir.z)
	fx.add_child(pulse)

	var tween: Tween = fx.create_tween().set_parallel(true)
	tween.tween_property(pulse, "position", target_pos + Vector3(0.0, 0.85, 0.0), 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse, "scale", Vector3(2.2, 1.0, 2.2), 0.18)
	await tween.finished


# ---------- 8. Удар посохом (strike): вспышка магической сферы на цели ----------

static func _play_arcane_strike(fx: Node3D, from_pos: Vector3, target_pos: Vector3) -> void:
	var arc_mat: StandardMaterial3D = _glow_mat(Color(0.35, 0.88, 1.0, 0.9), Color(0.25, 0.82, 1.0), 3.8)
	var gold_mat: StandardMaterial3D = _glow_mat(Color(1.0, 0.88, 0.4, 0.95), Color(1.0, 0.8, 0.25), 3.5)

	var beam: MeshInstance3D = _segment(from_pos + Vector3(0.0, 1.15, 0.0), target_pos + Vector3(0.0, 0.85, 0.0), 0.055, arc_mat)
	fx.add_child(beam)

	var burst: MeshInstance3D = _sphere(0.18, gold_mat)
	burst.position = target_pos + Vector3(0.0, 0.85, 0.0)
	fx.add_child(burst)

	var tween: Tween = fx.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * 2.3, 0.18).set_ease(Tween.EASE_OUT)
	await tween.finished


# ---------- 9. Магический щит (guard): полупрозрачный рунический купол вокруг мага ----------

static func _play_magic_shield(fx: Node3D, hero_pos: Vector3) -> void:
	var dome_mat: StandardMaterial3D = _glow_mat(Color(0.25, 0.72, 1.0, 0.42), Color(0.20, 0.65, 1.0), 2.2)
	var ring_mat: StandardMaterial3D = _glow_mat(Color(0.55, 0.92, 1.0, 0.88), Color(0.45, 0.88, 1.0), 3.5)

	var dome: MeshInstance3D = _sphere(0.75, dome_mat)
	dome.position = hero_pos + Vector3(0.0, 0.85, 0.0)
	dome.scale = Vector3.ONE * 0.2
	fx.add_child(dome)

	var ring: MeshInstance3D = _disc(0.65, 0.05, ring_mat)
	ring.position = hero_pos + Vector3(0.0, 0.12, 0.0)
	fx.add_child(ring)

	var tween: Tween = fx.create_tween().set_parallel(true)
	tween.tween_property(dome, "scale", Vector3(1.05, 1.25, 1.05), 0.24).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "position:y", 1.35, 0.24).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", Vector3(1.2, 1.0, 1.2), 0.24)
	await tween.finished


# ---------- 10. Рывок (dash): вихрь ускорения вокруг мага ----------

static func _play_dash_aura(fx: Node3D, hero_pos: Vector3) -> void:
	var aura_mat: StandardMaterial3D = _glow_mat(Color(0.4, 0.95, 1.0, 0.78), Color(0.3, 0.9, 1.0), 3.2)
	var tween: Tween = fx.create_tween().set_parallel(true)
	for i in 3:
		var ring: MeshInstance3D = _disc(0.52 - i * 0.08, 0.04, aura_mat)
		ring.position = hero_pos + Vector3(0.0, 0.15 + i * 0.35, 0.0)
		fx.add_child(ring)
		tween.tween_property(ring, "position:y", 0.95 + i * 0.35, 0.22).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "scale", Vector3(1.45, 1.0, 1.45), 0.22)
	await tween.finished


# ---------- Вспомогательные примитивы ----------

static func _center_world(board: Board, cells: Array[Vector2i], fallback: Vector3) -> Vector3:
	if cells.is_empty():
		return fallback
	var sum := Vector3.ZERO
	for c: Vector2i in cells:
		sum += board.grid_to_world(c)
	return sum / float(cells.size())


static func _glow_mat(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = albedo
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.2
	return mat


static func _sphere(radius: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 10
	s.rings = 6
	m.mesh = s
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _box(size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _cone(top_r: float, bottom_r: float, h: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = 8
	m.mesh = c
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func _disc(radius: float, h: float, mat: StandardMaterial3D) -> MeshInstance3D:
	return _cone(radius, radius * 0.9, h, mat)


static func _segment(a: Vector3, b: Vector3, radius: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var d: Vector3 = b - a
	var m: MeshInstance3D = _cone(radius, radius, d.length(), mat)
	m.position = (a + b) * 0.5
	var up := Vector3.UP
	var dir: Vector3 = d.normalized()
	if absf(dir.dot(up)) < 0.999:
		var axis: Vector3 = up.cross(dir).normalized()
		var angle: float = acos(clampf(up.dot(dir), -1.0, 1.0))
		m.transform.basis = Basis(axis, angle)
	return m
