extends SceneTree
# Снимки эффектов боя (VfxPlayer, ТЗ claude/тз-эффекты.md): каждый эффект на живом поле,
# кадры через 0,1 и 0,3 секунды. Нужно окно:
#   godot --path . --resolution 1280x720 -s tests/shots_vfx.gd
# Снимки — в /tmp/claude-0/shots/vfx_*.png. Переменная ONLY=имя — снять один сценарий.
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
	var vfx = b.vfx
	var en: Array = b.logic.enemies
	var hero_k = b.logic.heroes[1]
	var hero_m = b.logic.heroes[0]
	var only: String = OS.get_environment("ONLY")

	var cases: Array = [
		["hit_goblin", func() -> void: vfx.hit(b._views[en[0]], 1.4, {"dealt": 5, "material": "sparks"})],
		["big_hit_goblin", func() -> void: vfx.hit(b._views[en[0]], 1.4, {"dealt": 12, "material": "sparks"})],
		["hit_stone", func() -> void: vfx.hit(b._views[en[1]], 1.3, {"dealt": 4, "material": "stone"})],
		["hit_wood", func() -> void: vfx.hit(b._views[en[4]], 2.1, {"dealt": 6, "material": "wood"})],
		["hit_water_lightning", func() -> void: vfx.hit(b._views[en[3]], 1.6, {"dealt": 9, "material": "water", "element": 4})],
		["block_knight", func() -> void: vfx.hit(b._views[hero_k], 1.65, {"dealt": 3, "absorbed": 5, "broke": true, "material": "block"})],
		["poison_mage", func() -> void: vfx.hit(b._views[hero_m], 1.65, {"dealt": 2, "source": "poison"})],
		["heal_mage", func() -> void: vfx.heal(b._views[hero_m], 1.65, 6)],
		["fire_tick", func() -> void: vfx.hit(b._views[en[0]], 1.4, {"dealt": 3, "source": "fire", "material": "sparks"})],
		["sink", func() -> void: vfx.sink(b._views[en[3]])],
		["rise", func() -> void: vfx.burst("rise", b._views[hero_k].global_position + Vector3(0, 0.1, 0), 1.0, 0, Color(0.95, 0.7, 0.3))],
		["lightning", func() -> void: vfx.lightning(b._views[en[1]].global_position + Vector3(0.3, 6, 0), b._views[en[1]].global_position + Vector3(0, 0.1, 0), Color(0.95, 0.95, 0.62), 0.08, 12)],
		["slash", func() -> void: vfx.slash(b._views[hero_k].global_position, Vector3.FORWARD, Color(0.78, 0.86, 0.96), 0.95, 140.0, 0.3)],
	]
	var targets: Dictionary = {"hit_goblin": en[0], "big_hit_goblin": en[0], "hit_stone": en[1],
		"hit_wood": en[4], "hit_water_lightning": en[3], "block_knight": hero_k, "poison_mage": hero_m,
		"heal_mage": hero_m, "fire_tick": en[0], "sink": en[3], "rise": hero_k, "lightning": en[1], "slash": hero_k}
	for c in cases:
		if only != "" and c[0] != only:
			continue
		_focus = b.camera.unproject_position(b._views[targets[c[0]]].global_position + Vector3(0, 0.9, 0))
		c[1].call()
		await _shot("vfx_%s_a" % c[0], 0.08)
		await _shot("vfx_%s_b" % c[0], 0.2)
		await create_timer(0.8).timeout
	# «Живой» прогон через сигналы логики: урон, блок, яд, лечение, смерть, утопление —
	# проверяет обработчики в battle.gd, а не только VfxPlayer
	if only == "" or only == "live":
		var logic = b.logic
		hero_k.block = 4
		logic._damage(hero_k, 7)
		logic._hint_damage(hero_m, 2, "poison", true)
		hero_m.hp -= 5
		logic.status_changed.emit(hero_m, logic.snapshot(hero_m))
		hero_m.hp += 5
		logic.status_changed.emit(hero_m, logic.snapshot(hero_m))
		logic._damage(en[1], 3)
		logic._damage(en[4], 99)
		await b._play_queue()
		await _shot("vfx_live", 0.1)
		print("live ok: knight hp %d, treant alive %s" % [hero_k.hp, en[4].is_alive()])
	# Смерти — последними: фигурки исчезают
	if only == "" or only == "death":
		_focus = b.camera.unproject_position(b._views[en[2]].global_position + Vector3(0, 0.9, 0))
		Engine.time_scale = 0.15   # замедляем, чтобы поймать середину растворения
		b._views[en[0]].start_death()
		vfx.death(b._views[en[0]], 1.4, "rift")
		vfx.death(b._views[en[2]], 1.7, "cult")
		await _shot("vfx_death_a", 0.25)
		await _shot("vfx_death_b", 0.35)
		await _shot("vfx_death_c", 0.6)
		Engine.time_scale = 1.0
	print("vfx shots done")
	quit()


var _focus: Vector2 = Vector2(640, 360)


func _shot(name: String, delay: float) -> void:
	await create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("/tmp/claude-0/shots/%s.png" % name)
	# Крупный план вокруг цели — так эффект видно лучше
	var size := Vector2i(420, 300)
	var k: float = float(img.get_width()) / root.get_visible_rect().size.x   # окно может быть меньше Full HD
	var f: Vector2 = _focus * k
	var at := Vector2i(clampi(int(f.x) - size.x / 2, 0, img.get_width() - size.x),
		clampi(int(f.y) - size.y / 2, 0, img.get_height() - size.y))
	img.get_region(Rect2i(at, size)).save_png("/tmp/claude-0/shots/%s_zoom.png" % name)
	print("shot ", name)
