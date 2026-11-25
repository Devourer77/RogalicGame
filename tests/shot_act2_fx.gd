extends SceneTree
# Снимки эффектов механик акта 2: замыкание, ржавчина, клеймо, пробуждение сферы и перелёт падальщика.
# xvfb-run godot --path . --resolution 1280x720 --rendering-driver opengl3 -s tests/shot_act2_fx.gd
var _dir: String = "user://shots"


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("shot ", name)


func _initialize() -> void:
	if OS.get_environment("SHOTS_DIR") != "":
		_dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(5)
	run.pending_enemies = [load("res://resources/enemies/sphere_walker_storm.tres"), load("res://resources/enemies/sphere_walker_fire.tres"),
			load("res://resources/enemies/sleeping_sphere.tres"), load("res://resources/enemies/ash_vulture.tres")] as Array[EnemyData]
	run.pending_arena = "assembly"
	change_scene_to_file("res://scenes/battle.tscn")
	await create_timer(6.0).timeout
	var b = current_scene
	var e: Array = b.logic.enemies
	# Состояния, чтобы появились постоянные эффекты
	e[0].stunned = 1
	e[1].rust = 1
	b.logic.heroes[1].brand = 1
	for u in [e[0], e[1], b.logic.heroes[1]]:
		b._on_status_changed(u, b.logic.snapshot(u))
	b._on_fx_hint("short", e[0], null)
	b._on_fx_hint("rust", e[1], null)
	b._on_fx_hint("brand", b.logic.heroes[1], null)
	b._on_fx_hint("wake", e[2], null)
	# Эффекты напрямую (в игре их зовёт очередь показа сцены)
	b.vfx.short_circuit(b._views[e[0]], b._unit_height(e[0]))
	b.vfx.rust_burst(b._views[e[1]], b._unit_height(e[1]))
	b.vfx.brand_mark(b._views[b.logic.heroes[1]], b._unit_height(b.logic.heroes[1]))
	b.vfx.wake_up(b._views[e[2]], b._unit_height(e[2]))
	# Камера поближе к врагам
	b.camera.size = b.camera.size * 0.55 if b.camera.projection == Camera3D.PROJECTION_ORTHOGONAL else b.camera.size
	b.camera.fov = b.camera.fov * 0.55
	b.camera.look_at(b.board.grid_to_world(e[1].cell))
	b.set_process(false)   # чтобы камера не вернулась к герою
	await create_timer(0.12).timeout
	await _shot("act2_fx_burst")
	await create_timer(1.5).timeout
	await _shot("act2_fx_loops")
	# Дым Пепельника на трёх клетках
	for c: Vector2i in [e[1].cell + Vector2i(1, 1), e[1].cell + Vector2i(2, 1), e[1].cell + Vector2i(1, 2)]:
		b.board.set_tile_effect(c, BattleLogic.Tile.SMOKE)
	await create_timer(1.8).timeout
	await _shot("act2_fx_smoke")
	# Перелёт падальщика через пол-поля
	var v = b._views[e[3]]
	var from: Vector2i = e[3].cell
	var path: Array[Vector2i] = [from, from + Vector2i(0, 1), from + Vector2i(0, 2), from + Vector2i(0, 3)]
	v.follow_path(path)
	await create_timer(0.3).timeout
	await _shot("act2_fx_flight")
	quit()
