extends SceneTree
# Снимок всех знаков боссов акта 2 рядом (3 × 3: Исполин, Колосс, Сосуд). Нужно окно:
# xvfb-run godot --path . --resolution 1280x720 --rendering-driver opengl3 -s tests/shot_signs_act2.gd
const SIGNS: Array[String] = ["sign_giant_wheel", "sign_giant_rut", "sign_giant_barrel",
	"sign_colossus_gear", "sign_colossus_shards", "sign_colossus_bolt",
	"sign_vessel_chain", "sign_vessel_crown", "sign_vessel_bars"]


func _initialize() -> void:
	var dir: String = OS.get_environment("SHOTS_DIR") if OS.get_environment("SHOTS_DIR") != "" else "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.09, 0.08)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.5, 0.45)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.29, 0.28)
	ground.material_override = mat
	world.add_child(ground)
	for i in SIGNS.size():
		var node: Node3D = (load("res://assets/models/%s.glb" % SIGNS[i]) as PackedScene).instantiate()
		node.scale = Vector3(1.4, 1.4, 1.4)
		node.position = Vector3((i % 3 - 1) * 3.2, 0.0, (i / 3 - 1) * 3.0)
		world.add_child(node)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 9.5, 8.5)
	cam.rotation_degrees = Vector3(-48, 0, 0)
	cam.fov = 50
	world.add_child(cam)
	cam.make_current()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir + "/signs_act2.png")
	print("shot signs_act2")
	quit()
