extends SceneTree
# Снимок «до / после» стилизации моделей: слева старая модель, справа новая,
# свет, туман и наклон камеры — как в бою.
#   BEFORE=res://.../old.glb AFTER=res://.../new.glb HEIGHT=1.2 NAME=goblin \
#   godot --path . --resolution 1200x700 -s tests/shots_stylize.gd
# Необязательно: ANIM=Idle (анимация и момент TIME), STATUS=wet|poison|bound (состояние на правой модели)
# Картинка: /tmp/claude-0/shots/stylize_<NAME>.png
func _initialize() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	var battle: Node = (load("res://scenes/battle.tscn") as PackedScene).instantiate()
	# из сцены боя берём только окружение и солнце (без логики)
	for node_name: String in ["WorldEnvironment", "Sun"]:
		var n: Node = battle.get_node(node_name)
		battle.remove_child(n)
		world.add_child(n)
	battle.free()

	var h: float = float(OS.get_environment("HEIGHT")) if OS.get_environment("HEIGHT") != "" else 1.2
	var gap: float = maxf(h * 0.95, 1.15)
	if OS.get_environment("NOFLOOR") == "":
		_floor(world, gap)
	var paths: Array[String] = [OS.get_environment("BEFORE"), OS.get_environment("AFTER")]
	var models: Array[Node3D] = []
	for i in paths.size():
		if paths[i] == "":
			continue
		var m: Node3D = (load(paths[i]) as PackedScene).instantiate()
		world.add_child(m)
		m.position = Vector3((i - 0.5) * gap * 2.0 if paths[0] != "" else 0.0, 0.0, 0.0)
		m.rotation.y = float(OS.get_environment("ROT")) if OS.get_environment("ROT") != "" else 0.35
		models.append(m)

	var anim: String = OS.get_environment("ANIM")
	var at: float = float(OS.get_environment("TIME")) if OS.get_environment("TIME") != "" else 0.3
	for m in models:
		var players: Array[Node] = m.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty() or anim == "REST":
			continue
		var p: AnimationPlayer = players[0]
		var a: String = anim if anim != "" and p.has_animation(anim) else ("Idle" if p.has_animation("Idle") else "")
		if a != "":
			p.play(a)
			p.seek(at, true)
			p.pause()

	var status: String = OS.get_environment("STATUS")
	if status != "" and not models.is_empty():
		var vfx: Node3D = load("res://scripts/vfx_player.gd").new()   # грузим здесь: автозагрузки к этому моменту готовы
		world.add_child(vfx)
		var target: Node3D = models[models.size() - 1]
		var state: Dictionary = {"wet": 2 if status.contains("wet") else 0,
				"poison": 3 if status.contains("poison") else 0,
				"entangled": 1 if status.contains("bound") else 0}
		vfx.set_auras(target, h, state)
		await create_timer(1.2).timeout

	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	# Наклон как у боевой камеры (~55° вниз), только ближе
	var dist: float = gap * 2.6 if models.size() > 1 else h * 3.2
	cam.position = Vector3(0.0, h * 0.5 + dist * 0.80, dist * 0.62)
	if OS.get_environment("CAM") == "low":   # ближе и ниже, как в хабе: видно детали
		cam.position = Vector3(0.0, h * 0.75 + dist * 0.25, dist * 0.85)
	cam.look_at(Vector3(0.0, h * 0.45, 0.0))
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/claude-0/shots")
	var file: String = "/tmp/claude-0/shots/stylize_%s.png" % OS.get_environment("NAME")
	root.get_texture().get_image().save_png(file)
	print("shot ", file)
	quit()


# Пол из каменных плит, как на поле
func _floor(world: Node3D, gap: float) -> void:
	var tile_mesh := CylinderMesh.new()
	tile_mesh.top_radius = HexMath.HEX_SIZE * 0.97
	tile_mesh.bottom_radius = tile_mesh.top_radius
	tile_mesh.height = 0.2
	tile_mesh.radial_segments = 6
	tile_mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.33, 0.33)
	mat.roughness = 0.95
	for q in range(-4, 5):
		for r in range(-4, 5):
			var t := MeshInstance3D.new()
			t.mesh = tile_mesh
			t.material_override = mat
			t.position = HexMath.axial_to_world(Vector2i(q, r)) + Vector3(0.0, -0.1, 0.0)
			world.add_child(t)
