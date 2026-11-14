extends SceneTree
# Снимки эффектов врагов и духов (этап 5 ТЗ claude/тз-эффекты.md): огоньки духов у плеча
# героев, призыв, круг ритуала, поглощение магии шаманом, сгоревшая броня корягача,
# наследие венца, покорение духа. События идут сигналами логики — так проверяются и
# обработчики в battle.gd. Нужно окно:
#   godot --path . --resolution 1920x1080 -s tests/shots_vfx_enemies.gd
# Снимки — /tmp/claude-0/shots/venemy_*.png
func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(5)
	# Магу — двух прирученных духов, Рыцарю — одного: должны летать огоньки у плеча
	run.party[0].spirits.assign([load("res://resources/spirits/tide.tres"), load("res://resources/spirits/storm.tres")])
	run.party[1].spirits.assign([load("res://resources/spirits/fire.tres")])
	var list: Array[EnemyData] = []
	for id in ["goblin_shaman", "cult_novice", "cultist", "mossy_treant", "spirit_tide"]:
		list.append(load("res://resources/enemies/%s.tres" % id))
	run.pending_enemies = list
	run.pending_arena = "gat"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/claude-0/shots")
	b.board.clear_layer("move")
	var logic = b.logic
	var mage = logic.heroes[0]
	var knight = logic.heroes[1]
	var shaman = logic.enemies[0]
	var novice = logic.enemies[1]
	var cultist = logic.enemies[2]
	var treant = logic.enemies[3]
	var spirit = logic.enemies[4]
	print("духи у героев: ", mage.spirits, " ", knight.spirits)
	await create_timer(0.6).timeout
	await _shot(b, "venemy_companions", b._views[mage].global_position * 0.5 + b._views[knight].global_position * 0.5)

	# Ритуал: культист ведёт, до призыва 1 раунд — круг почти полный
	logic.objective = 1   # BattleLogic.Objective.RITUAL
	logic.ritual_caster_id = cultist.id
	logic.ritual_timer = 1
	logic.objective_changed.emit()
	await b._play_queue()
	await create_timer(0.5).timeout
	await _shot(b, "venemy_ritual", b._views[cultist].global_position)

	# Призыв: два гоблина вокруг культиста
	logic._summon_around(cultist, load("res://resources/enemies/goblin.tres"), 2)
	b._play_queue()
	await _shot(b, "venemy_summon_a", b._views[cultist].global_position, 0.1)
	await _shot(b, "venemy_summon_b", b._views[cultist].global_position, 0.25)
	await create_timer(0.8).timeout

	var only: String = OS.get_environment("ONLY")
	var events: Array = [
		["absorb", shaman, func() -> void: logic.fx_hint.emit("absorb", shaman, mage)],
		["armor", treant, func() -> void: logic.fx_hint.emit("armor_burnt", treant, null)],
		["bequest", cultist, func() -> void: logic.fx_hint.emit("bequest", cultist, novice)],
		["tame", spirit, func() -> void:
			spirit.hp = 0
			logic.unit_died.emit(spirit)],
	]
	for ev in events:
		if only != "" and ev[0] != only:
			continue
		ev[2].call()
		b._play_queue()
		await _shot(b, "venemy_%s_a" % ev[0], b._views[ev[1]].global_position, 0.12)
		await _shot(b, "venemy_%s_b" % ev[0], b._views[ev[1]].global_position, 0.3)
		await create_timer(1.0).timeout
	print("ritual objective: ", logic.objective)
	print("vfx enemies done")
	quit()


func _shot(b, name: String, focus: Vector3, delay: float = 0.0) -> void:
	if delay > 0.0:
		await create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / root.get_visible_rect().size.x
	var f: Vector2 = b.camera.unproject_position(focus + Vector3(0, 0.8, 0)) * k
	var size := Vector2i(420, 300)
	var at := Vector2i(clampi(int(f.x) - size.x / 2, 0, img.get_width() - size.x), clampi(int(f.y) - size.y / 2, 0, img.get_height() - size.y))
	img.get_region(Rect2i(at, size)).save_png("/tmp/claude-0/shots/%s.png" % name)
	print("shot ", name)
