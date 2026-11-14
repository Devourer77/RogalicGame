extends SceneTree
# Снимки состояний на фигурках (этап 4 ТЗ claude/тз-эффекты.md): мокрый, яд, опутан, руна,
# провокация, раздувание и фитиль жабы. Состояния ставятся юнитам и рассылаются сигналом
# логики — так проверяется и обработчик в battle.gd. Нужно окно:
#   godot --path . --resolution 1280x720 -s tests/shots_vfx_status.gd
# Снимки — /tmp/claude-0/shots/vstat_*.png
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(5)
	var list: Array[EnemyData] = []
	for id in ["bloated_toad", "bloated_toad", "goblin"]:
		list.append(load("res://resources/enemies/%s.tres" % id))
	run.pending_enemies = list
	run.pending_arena = "gat"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/claude-0/shots")
	var logic = b.logic
	b.board.clear_layer("move")
	var mage = logic.heroes[0]
	var knight = logic.heroes[1]
	var toad1 = logic.enemies[0]
	var toad2 = logic.enemies[1]

	mage.wet = 2
	mage.poison = 2
	logic.status_changed.emit(mage, logic.snapshot(mage))
	knight.entangled = 1
	knight.rune = "storm"
	knight.rune_hits = 3
	knight.taunt = true
	logic.status_changed.emit(knight, logic.snapshot(knight))
	toad1.inflation = 2
	logic.status_changed.emit(toad1, logic.snapshot(toad1))
	toad2.fuse = 1
	logic.status_changed.emit(toad2, logic.snapshot(toad2))
	await b._play_queue()
	await create_timer(0.8).timeout
	await _shot(b, "vstat_heroes", b._views[mage].global_position * 0.5 + b._views[knight].global_position * 0.5)
	await _shot(b, "vstat_toad_inflate", b._views[toad1].global_position)
	await _shot(b, "vstat_toad_fuse", b._views[toad2].global_position)
	# Руна иначе и слабее, яд снят — эффекты должны смениться
	knight.rune = "fire"
	knight.rune_hits = 1
	knight.taunt = false
	knight.entangled = 0
	logic.status_changed.emit(knight, logic.snapshot(knight))
	mage.poison = 0
	logic.status_changed.emit(mage, logic.snapshot(mage))
	await b._play_queue()
	await create_timer(1.2).timeout
	await _shot(b, "vstat_heroes_after", b._views[mage].global_position * 0.5 + b._views[knight].global_position * 0.5)
	var holder: Node = b._views[knight].get_node_or_null("Auras")
	var names: Array[String] = []
	if holder != null:
		for c in holder.get_children():
			names.append(String(c.name))
	print("ауры рыцаря после: ", names)
	print("vfx status done")
	quit()


func _shot(b, name: String, focus: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / root.get_visible_rect().size.x
	var f: Vector2 = b.camera.unproject_position(focus + Vector3(0, 0.8, 0)) * k
	var size := Vector2i(420, 300)
	var at := Vector2i(clampi(int(f.x) - size.x / 2, 0, img.get_width() - size.x), clampi(int(f.y) - size.y / 2, 0, img.get_height() - size.y))
	img.get_region(Rect2i(at, size)).save_png("/tmp/claude-0/shots/%s.png" % name)
	print("shot ", name)
