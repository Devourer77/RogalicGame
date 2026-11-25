extends SceneTree
# Снимки эффектов акта 2 и доработок 25 ноября: клинок с руной, клеймо, замыкание, ржавчина,
# огонёк духа при Зове, карты духов акта 2, удар и смерть механизма, мародёра, твари вулкана,
# марево над лавой и атмосфера арены. Нужно окно:
#   godot --path . --resolution 1920x1080 -s tests/shots_vfx_act2.gd
#   ARENA=steamworks — другая арена (по умолчанию lava_beds), ONLY=status|calls|cards|deaths|wide
# Снимки — /tmp/claude-0/shots/va2_*.png (полосы кадров — слева направо по времени)

var CALLS: Array[String] = ["tide_call", "storm_call", "ash_call", "rust_call"]
var CARDS: Array[String] = ["ash_m1", "stone_m1", "magma_m1", "rust_m1", "steam_m1"]
var FRAMES: Array[float] = [0.1, 0.2, 0.3, 0.45, 0.65]


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(5)
	# Духи у плеча: у Мага Омутник, у Рыцаря Грозовик — их огоньки и полетят при Зове
	run.add_spirit(run.party[0], load("res://resources/spirits/tide.tres"))
	run.add_spirit(run.party[1], load("res://resources/spirits/storm.tres"))
	var list: Array[EnemyData] = []
	for id in ["sphere_walker_storm", "scav_crossbow", "ash_hound", "slag_golem"]:
		list.append(load("res://resources/enemies/%s.tres" % id))
	run.pending_enemies = list
	var arena: String = OS.get_environment("ARENA")
	run.pending_arena = arena if arena != "" else "lava_beds"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/claude-0/shots")
	b.board.clear_layer("move")
	var logic = b.logic
	for e in logic.enemies:
		e.max_hp = 999
		e.hp = 999
	var only: String = OS.get_environment("ONLY")
	if OS.get_environment("SLOW") != "":
		Engine.time_scale = float(OS.get_environment("SLOW"))   # SLOW=0.25 — короткие эффекты не проскакивают между кадрами

	if only == "" or only == "wide":
		await create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/claude-0/shots/va2_wide_%s.png" % run.pending_arena)
		print("shot wide")

	if only == "" or only == "status":
		var mage = logic.heroes[0]
		var knight = logic.heroes[1]
		knight.rune = "fire"
		knight.rune_hits = 3
		logic.status_changed.emit(knight, logic.snapshot(knight))
		mage.brand = 1
		logic.status_changed.emit(mage, logic.snapshot(mage))
		var machine = logic.enemies[0]
		machine.stunned = 1
		machine.wet = 1
		logic.status_changed.emit(machine, logic.snapshot(machine))
		var hound = logic.enemies[2]
		hound.rust = 1
		logic.status_changed.emit(hound, logic.snapshot(hound))
		await b._play_queue()
		await create_timer(1.0).timeout
		await _shot(b, "va2_knight_rune", b._views[knight].global_position)
		await _shot(b, "va2_mage_brand", b._views[mage].global_position)
		await _shot(b, "va2_machine_stunned", b._views[machine].global_position)
		await _shot(b, "va2_hound_rust", b._views[hound].global_position)
		# Клинок идёт за взмахом: кадры удара Рыцаря
		b._views[knight].play_attack(Vector2i(1, 0))
		await _strip(b, "va2_knight_swing", b._views[knight].global_position, [0.1, 0.2, 0.3, 0.45])
		# Руна снята — свечение должно погаснуть
		knight.rune = ""
		knight.rune_hits = 0
		logic.status_changed.emit(knight, logic.snapshot(knight))
		await b._play_queue()
		await create_timer(0.8).timeout
		await _shot(b, "va2_knight_norune", b._views[knight].global_position)

	if OS.get_environment("CARDS") != "":
		CARDS.assign(OS.get_environment("CARDS").split(","))
	if only == "" or only == "calls":
		for id in CALLS:
			await _play_card(b, id)
	if only == "" or only == "cards":
		for id in CARDS:
			await _play_card(b, id)

	if only == "" or only == "deaths":
		var vfx = b.vfx
		var hits: Array = [[logic.enemies[0], "metal"], [logic.enemies[2], "cinder"], [logic.enemies[3], "stone"]]
		for pair in hits:
			var view = b._views[pair[0]]
			vfx.hit(view, 1.4, {"dealt": 9, "material": pair[1]})
			await _strip(b, "va2_hit_" + pair[1], view.global_position, [0.05, 0.12, 0.25])
		for pair in [[logic.enemies[0], "machine"], [logic.enemies[1], "scav"], [logic.enemies[2], "cinder"]]:
			var view = b._views[pair[0]]
			vfx.death(view, 1.4, pair[1])
			await _strip(b, "va2_death_" + pair[1], view.global_position, [0.1, 0.3, 0.6, 0.9])

	print("vfx act2 done")
	quit()


# Сыграть карту в бою и снять полосу кадров на цели
func _play_card(b, id: String) -> void:
	var logic = b.logic
	var path: String = _find_card(id)
	if path == "":
		print("нет карты ", id)
		return
	var card = load(path)
	var h = logic.heroes[1] if card.owner_hero == "knight" else logic.heroes[0]
	if not h.is_alive():
		return
	h.hand.insert(0, card)
	h.mana = 99
	var targets: Array = logic.get_card_targets(h, 0)
	var target: Vector2i = h.cell
	if not targets.is_empty():
		target = targets[0]
		var best: int = 999
		for t in targets:
			for e in logic.living_enemies():
				var d: int = HexMath.distance(t, e.cell)
				if d < best:
					best = d
					target = t
	var mid: Vector3 = b.board.grid_to_world(target) if OS.get_environment("ON_TARGET") != "" \
			else (b.board.grid_to_world(target) + b._views[h].global_position) * 0.5
	b._do(func() -> void: logic.play_card(h, 0, target))
	await _strip(b, "va2_card_" + id, mid, FRAMES, 640, 360)
	while b._mode == 0 and not logic.is_over:
		await process_frame
	await create_timer(0.6).timeout
	for e in logic.enemies:
		e.hp = maxi(e.hp, 500)
	for hh in logic.heroes:
		hh.hp = hh.max_hp
	print("card ", id)


func _strip(b, name: String, focus: Vector3, frames: Array, w: int = 420, h: int = 300) -> void:
	var strip := Image.create(w * frames.size(), h, false, Image.FORMAT_RGB8)
	var t0: float = 0.0
	for i in frames.size():
		await create_timer(frames[i] - t0).timeout
		t0 = frames[i]
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var k: float = float(img.get_width()) / root.get_visible_rect().size.x
		var f: Vector2 = b.camera.unproject_position(focus + Vector3(0, 0.8, 0)) * k
		var at := Vector2i(clampi(int(f.x) - w / 2, 0, img.get_width() - w), clampi(int(f.y) - h / 2, 0, img.get_height() - h))
		strip.blit_rect(img, Rect2i(at, Vector2i(w, h)), Vector2i(w * i, 0))
	strip.save_png("/tmp/claude-0/shots/%s.png" % name)
	print("shot ", name)


func _shot(b, name: String, focus: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / root.get_visible_rect().size.x
	var f: Vector2 = b.camera.unproject_position(focus + Vector3(0, 0.8, 0)) * k
	var size := Vector2i(420, 300)
	var at := Vector2i(clampi(int(f.x) - size.x / 2, 0, img.get_width() - size.x), clampi(int(f.y) - size.y / 2, 0, img.get_height() - size.y))
	img.get_region(Rect2i(at, size)).save_png("/tmp/claude-0/shots/%s.png" % name)
	print("shot ", name)


func _find_card(id: String) -> String:
	var stack: Array[String] = ["res://resources/cards"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir_path):
			stack.append(dir_path + "/" + sub)
		if FileAccess.file_exists(dir_path + "/" + id + ".tres"):
			return dir_path + "/" + id + ".tres"
	return ""
