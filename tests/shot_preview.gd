extends SceneTree
# Снимки точного предпросмотра карты: ищет карту и клетку с самой длинной цепочкой
# (бочки, газ, разряды) и с уроном по своему герою, наводит на неё прицел и снимает экран.
# Запуск (нужно окно): godot --path . --resolution 1280x720 -s tests/shot_preview.gd
# ARENA=pump — своя арена. Картинки — в SHOTS_DIR (по умолчанию user://shots).
var _dir: String = "user://shots"


func _shot(name: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
	print("shot ", name)


func _initialize() -> void:
	if OS.get_environment("SHOTS_DIR") != "":
		_dir = OS.get_environment("SHOTS_DIR")
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	var run = root.get_node("Run")
	run.start_new_run(9)
	run.pending_enemies = run._make_encounter(3, false, false)
	run.pending_arena = OS.get_environment("ARENA") if OS.get_environment("ARENA") != "" else "ruins"
	change_scene_to_file("res://scenes/battle.tscn")
	await _idle()
	var b = current_scene
	# Все карты обоих героев: какая даст самую длинную цепочку, а какая — урон по своим
	var best: Array = []    # [очки, герой, карта, клетка]
	var self_hit: Array = []
	for h: BattleUnit in b.logic.living_heroes():
		h.mana = 9
		var cards: Array[CardData] = h.hero_data.card_pool.duplicate()
		for d in DirAccess.get_directories_at("res://resources/cards/spirits"):
			for f in DirAccess.get_files_at("res://resources/cards/spirits/" + d):
				var mark: String = "m" if h.hero_data.id == "mage" else "k"
				if f.ends_with(".tres") and f.get_basename().rsplit("_", true, 1)[-1].begins_with(mark):
					cards.append(load("res://resources/cards/spirits/%s/%s" % [d, f]))
		for card in cards:
			h.hand = [card] as Array[CardData]
			if not b.logic.can_play(h, 0) or card.shape == CardData.Shape.SELF:
				continue
			for t: Vector2i in b.logic.get_card_targets(h, 0):
				var p: Dictionary = b.logic.preview_card(h, 0, t)
				if not p["ok"]:
					continue
				var score: int = (p["chain"] as Array).size() * 10 + (p["units"] as Dictionary).size() + (p["reactions"] as Array).size()
				if best.is_empty() or score > best[0]:
					best = [score, h, card, t]
				for id: int in p["units"]:
					var info: Dictionary = p["units"][id]
					if info["is_hero"] and info["dealt"] > 0 and self_hit.is_empty():
						self_hit = [0, h, card, t]
	for pick: Array in [best, self_hit]:
		if pick.is_empty():
			continue
		var h: BattleUnit = pick[1]
		h.hand = [pick[2]] as Array[CardData]
		b._select_hero(h)
		b._enter_idle()
		b._on_card_pressed(0)
		b._on_hover(pick[3])
		print("карта ", pick[2].id, " в ", pick[3], ": ", b.hud._preview_box.get_child_count() - 1, " строк итога")
		await _shot("preview_%s_%s" % [run.pending_arena, "chain" if pick == best else "self"])
		b._cancel_card()
	quit()


func _idle() -> void:
	for f in 900:
		await process_frame
		var b = current_scene
		if b != null and "_mode" in b and b._mode == b.Mode.IDLE and b._anim_queue.is_empty() and f > 30:
			return
