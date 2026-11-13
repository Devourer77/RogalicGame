extends SceneTree
# Лист поз модели: каждая анимация в нескольких моментах.
#   MODEL=res://assets/models/goblin.glb godot --path . --resolution 420x420 -s tests/shots_model.gd
# Картинки складывает в /tmp/claude-0/shots/model/<анимация>_<номер>.png
func _initialize() -> void:
	await process_frame
	var path: String = OS.get_environment("MODEL")
	var side: bool = OS.get_environment("VIEW") == "side"
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.2, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.68, 0.66)
	e.ambient_light_energy = 0.7
	e.glow_enabled = true
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6, 6)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.28, 0.31, 0.3)
	floor_mesh.material_override = fm
	world.add_child(floor_mesh)
	var model: Node3D = (load(path) as PackedScene).instantiate()
	world.add_child(model)
	var h: float = float(OS.get_environment("HEIGHT")) if OS.get_environment("HEIGHT") != "" else 1.1
	var cam := Camera3D.new()
	cam.fov = 35
	world.add_child(cam)
	var dist: float = h * 2.9
	cam.position = Vector3(-dist, h * 0.75, 0.15) if side else Vector3(dist * (-0.55 if OS.get_environment("VIEW") == "right" else 0.5), h * 1.1, dist * 0.82)
	if OS.get_environment("VIEW") == "back":   # как в игре: камера сзади-сверху
		cam.position = Vector3(dist * 0.25, h * 1.9, -dist * 0.75)
	cam.look_at(Vector3(0, h * 0.42, 0.15))
	var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	DirAccess.make_dir_recursive_absolute("/tmp/claude-0/shots/model")
	for anim: String in ["Idle", "Walk", "Attack", "Attack2", "Attack3", "Hit", "Death", "Block", "Cast", "CastSky"]:
		if not player.has_animation(anim): continue
		var length: float = player.get_animation(anim).length
		for i in 6:
			player.play(anim)
			player.seek(length * i / 6.0 if anim in ["Idle", "Walk"] else length * i / 5.0, true)
			player.pause()
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/claude-0/shots/model/%s_%d.png" % [anim, i])
	print("done ", player.get_animation_list())
	quit()
