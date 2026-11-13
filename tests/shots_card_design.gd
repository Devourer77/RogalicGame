extends Node
# Снимок всех карт игры в новом дизайне (лист 10 карт в ряд). Нужна отрисовка (не --headless).
# godot --path . res://tests/shots_card_design.tscn   → user://shots/card_design_*.png (или папка из SHOTS_DIR)

func _ready() -> void:
	var tree: SceneTree = get_tree()
	var root: Window = tree.root
	await tree.process_frame
	root.size = Vector2i(1700, 1300)
	var dir: String = OS.get_environment("SHOTS_DIR")
	if dir == "":
		dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	var paths: Array[String] = []
	for f: String in DirAccess.get_files_at("res://resources/cards/"):
		if f.ends_with(".tres"):
			paths.append("res://resources/cards/" + f)
	paths.sort()
	var mage_color := Color(0.35, 0.5, 1)
	var knight_color := Color(0.9, 0.62, 0.25)
	var page: int = 0
	var i: int = 0
	while i < paths.size():
		var bg := ColorRect.new()
		bg.color = UiKit.BG_COLOR
		bg.size = Vector2(root.size)
		bg.theme = UiKit.theme()
		add_child(bg)
		for n: int in 40:
			if i >= paths.size():
				break
			var card: CardData = load(paths[i])
			var mage: bool = paths[i].get_file().begins_with("m") or card.card_set in ["storm", "elements"] \
					or card.id in ["fireball", "lightning", "meteor", "gust", "ice_lance", "wave", "dash", "swamp_slime", "shove"]
			var b: Button = CardView.make_button(card, mage_color if mage else knight_color, card.cost - 1 if n == 3 else -1, 1 if n == 0 else 0)
			b.position = Vector2(20 + (n % 10) * 167, 26 + (n / 10) * 250)
			bg.add_child(b)
			i += 1
		for f: int in 6:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/card_design_%d.png" % [dir, page])
		print("shot ", page)
		page += 1
		bg.queue_free()
		await tree.process_frame
	tree.quit()
