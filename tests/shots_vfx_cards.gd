extends SceneTree
# Снимки эффектов карт (VfxCards, этап 2 ТЗ claude/тз-эффекты.md): карта по-настоящему
# разыгрывается в бою, снимаются 4 кадра крупным планом, все кадры карты — в одну полосу.
# Нужно окно:  godot --path . --resolution 1280x720 -s tests/shots_vfx_cards.gd
# Снимки — /tmp/claude-0/shots/vcard_<id>.png. CARDS=id,id — только эти карты.
const CARDS: Array[String] = [
	"kb_sword", "kb_sweep", "kb_whirl", "kb_boot", "kb_ram", "kb_leap", "kb_shield", "kb_warcry",
	"mb_staff", "mb_discharge", "mb_repulse", "mb_shield",
	"storm_m2", "storm_m3", "storm_k6", "storm_call",
	"tide_m2", "tide_m1", "tide_k2", "wind_m1", "wind_k3", "bog_m1", "bog_m2",
	"fire_m2", "fire_m3", "fire_m6", "fire_k6", "mix_fire_tide_m2",
]
var FRAMES: Array[float] = [0.25, 0.35, 0.45, 0.6]   # секунды от розыгрыша (FRAMES=0.1,0.2,…)


func _initialize() -> void:
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(5)
	var list: Array[EnemyData] = []
	for id in ["goblin", "rock_crawler", "cultist", "drowned_walker", "mossy_treant"]:
		list.append(load("res://resources/enemies/%s.tres" % id))
	run.pending_enemies = list
	run.pending_arena = "reeds"
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	DirAccess.make_dir_recursive_absolute("/tmp/claude-0/shots")
	var logic = b.logic
	for e in logic.enemies:
		e.max_hp = 999
		e.hp = 999   # чтобы враги не погибли, пока снимаем все карты
	var ids: Array[String] = CARDS
	if OS.get_environment("CARDS") != "":
		ids.assign(OS.get_environment("CARDS").split(","))
	var paths: Dictionary = _card_paths()
	if OS.get_environment("FRAMES") != "":
		FRAMES.clear()
		for v in OS.get_environment("FRAMES").split(","):
			FRAMES.append(float(v))
	for id in ids:
		if not paths.has(id):
			print("нет карты ", id)
			continue
		var card = load(paths[id])
		var h = logic.heroes[1] if card.owner_hero == "knight" else logic.heroes[0]
		if not h.is_alive():
			continue
		# Ближний бой — ставим героя вплотную к врагу, иначе бить некого
		if card.cast_range <= 1 and card.shape != 0:
			_stand_next_to_enemy(b, h)
		h.hand.insert(0, card)
		h.mana = 99
		var targets: Array = logic.get_card_targets(h, 0)
		var target: Vector2i = h.cell
		if not targets.is_empty():
			target = targets[0]
			# Ближе всего к какому-нибудь врагу — чтобы удар куда-то пришёлся
			var best: int = 999
			for t in targets:
				for e in logic.living_enemies():
					var d: int = HexMath.distance(t, e.cell)
					if d < best:
						best = d
						target = t
		var mid: Vector3 = b.board.grid_to_world(target) + Vector3(0, 0.8, 0)   # крупный план — на цель
		var picked = VfxCards_pick(card)
		b._do(func() -> void: logic.play_card(h, 0, target))
		var strip := Image.create(420 * FRAMES.size(), 300, false, Image.FORMAT_RGB8)
		var t0: float = 0.0
		for i in FRAMES.size():
			await create_timer(FRAMES[i] - t0).timeout
			t0 = FRAMES[i]
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			var k: float = float(img.get_width()) / root.get_visible_rect().size.x
			var f: Vector2 = b.camera.unproject_position(mid) * k
			var at := Vector2i(clampi(int(f.x) - 210, 0, img.get_width() - 420), clampi(int(f.y) - 150, 0, img.get_height() - 300))
			img.convert(Image.FORMAT_RGB8)
			strip.blit_rect(img, Rect2i(at, Vector2i(420, 300)), Vector2i(420 * i, 0))
		strip.save_png("/tmp/claude-0/shots/vcard_%s.png" % id)
		print("card %s → %s" % [id, picked])
		while b._mode == 0 and not logic.is_over:
			await process_frame
		await create_timer(0.6).timeout
		for e in logic.enemies:
			e.hp = maxi(e.hp, 500)
		for hh in logic.heroes:
			hh.hp = hh.max_hp
	print("vfx cards done")
	quit()


func _stand_next_to_enemy(b, h) -> void:
	var logic = b.logic
	for e in logic.living_enemies():
		for n in HexMath.neighbors(e.cell):
			if logic.is_inside(n) and not logic.is_blocked(n) and logic.unit_at(n) == null:
				h.cell = n
				b._views[h].place_at(n)
				b._views[h].face_dir(HexMath.direction_to(n, e.cell))
				return


# Форма и цвет эффекта карты — без прямой ссылки на класс (тест компилируется раньше автозагрузок)
func VfxCards_pick(card) -> Array:
	return load("res://scripts/vfx_cards.gd").pick(card)


func _card_paths() -> Dictionary:
	var out: Dictionary = {}
	var stack: Array[String] = ["res://resources/cards"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir_path):
			stack.append(dir_path + "/" + sub)
		for f in DirAccess.get_files_at(dir_path):
			if f.ends_with(".tres"):
				out[f.get_basename()] = dir_path + "/" + f
	return out
