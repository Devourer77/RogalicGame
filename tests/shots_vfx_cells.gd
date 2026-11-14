extends SceneTree
# Снимки эффектов клеток, объектов и реакций (этап 3 ТЗ claude/тз-эффекты.md).
# Сначала «живые» клетки (огонь, лужа, лёд, топь, газ, лава), потом разовые события через
# сигналы логики — так проверяются и обработчики в battle.gd. Нужно окно:
#   godot --path . --resolution 1280x720 -s tests/shots_vfx_cells.gd
# Снимки — /tmp/claude-0/shots/vcell_*.png (крупный план 420×300).
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(5)
	var list: Array[EnemyData] = [load("res://resources/enemies/goblin.tres")]
	run.pending_enemies = list
	run.pending_arena = "gat"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/claude-0/shots")
	var logic = b.logic
	var board = b.board
	# Ряд клеток посреди поля под разные стихии
	var row: Array[Vector2i] = []
	for q in range(2, 9):
		row.append(HexMath.from_column(q, 6))
	var tiles: Array = [1, 1, 2, 3, 4, 5]   # FIRE, FIRE, WATER, ICE, SWAMP, GAS (BattleLogic.Tile)
	for i in tiles.size():
		board.set_tile_effect(row[i], tiles[i])
	board.add_object(row[6], _lava_kind())
	await create_timer(0.6).timeout
	board.clear_layer("move")   # синяя подсветка ходов мешает разглядеть клетки
	await _shot(b, "vcell_tiles", board.grid_to_world(row[3]), Vector2i(900, 380))
	await _shot(b, "vcell_fire", board.grid_to_world(row[0]), Vector2i(420, 300))
	await _shot(b, "vcell_lava_gas", board.grid_to_world(row[5]) * 0.5 + board.grid_to_world(row[6]) * 0.5, Vector2i(420, 300))

	# Разовые события через сигналы логики
	var c: Vector2i = HexMath.from_column(5, 3)
	var around: Array[Vector2i] = [c]
	around.append_array(HexMath.neighbors(c))
	var events: Array = [
		["explosion", func() -> void: logic.effect_cells.emit(around, "explosion")],
		["tree", func() -> void:
			var line: Array[Vector2i] = [HexMath.from_column(3, 3), HexMath.from_column(4, 3), HexMath.from_column(5, 3)]
			logic.effect_cells.emit(line, "tree")],
		["steam", func() -> void: logic.reaction.emit(c, "steam")],
		["freeze", func() -> void: logic.reaction.emit(c, "freeze")],
		["shatter", func() -> void: logic.reaction.emit(c, "shatter")],
		["lava", func() -> void: logic.reaction.emit(c, "lava")],
		["gas", func() -> void: logic.effect_cells.emit(around, "gas")],
		["bump", func() -> void: b.vfx.bump(board.grid_to_world(c), true)],
		["reeds", func() -> void: b.vfx.object_broken(board.grid_to_world(c), "reeds")],
		["planks", func() -> void: b.vfx.object_broken(board.grid_to_world(c), "planks")],
	]
	for ev in events:
		ev[1].call()
		b._play_queue()
		await _shot(b, "vcell_ev_%s_a" % ev[0], board.grid_to_world(c), Vector2i(420, 300), 0.1)
		await _shot(b, "vcell_ev_%s_b" % ev[0], board.grid_to_world(c), Vector2i(420, 300), 0.25)
		await create_timer(1.0).timeout
	print("vfx cells done")
	quit()


func _lava_kind() -> int:
	return load("res://scripts/battle/battle_logic.gd").Obj.LAVA


func _shot(b, name: String, focus_world: Vector3, size: Vector2i, delay: float = 0.0) -> void:
	if delay > 0.0:
		await create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / root.get_visible_rect().size.x
	var f: Vector2 = b.camera.unproject_position(focus_world) * k
	var at := Vector2i(clampi(int(f.x) - size.x / 2, 0, img.get_width() - size.x), clampi(int(f.y) - size.y / 2, 0, img.get_height() - size.y))
	img.get_region(Rect2i(at, size)).save_png("/tmp/claude-0/shots/%s.png" % name)
	print("shot ", name)
