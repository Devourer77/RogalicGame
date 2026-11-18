extends SceneTree
# Пробное превью карточки арены для карты пути: снимок пустой арены + рамка карточки.
# Запуск с окном:
#   godot --path . --resolution 1280x720 -s tests/shot_arena_card.gd
# Переменная ARENA выбирает арену (по умолчанию reeds — Камышовая заводь).

const OUT_DIR: String = "/tmp/claude-0/shots/"
const CARD_SIZE := Vector2(300, 450)   # 2:3, как на образце Gemini
const PIC_HEIGHT: float = 276.0        # окошко с ареной — квадрат, как рисунки Gemini
const DANGER: int = 2                  # огоньки опасности (1–3)
# Цвета как в UiKit (в режиме -s UiKit не собирается из-за автозагрузки Sfx, поэтому копия).
const BG_COLOR := Color(0.05, 0.068, 0.068)
const BRASS := Color(0.84, 0.67, 0.34)
const BRASS_DARK := Color(0.4, 0.31, 0.15)
const TEXT := Color(0.88, 0.9, 0.86)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	await process_frame
	if OS.get_environment("CARDS") != "":
		await _shot_painted(OS.get_environment("CARDS"))
		quit()
		return
	var run = root.get_node("Run")
	var arena: String = OS.get_environment("ARENA")
	if arena == "":
		arena = "reeds"
	run.start_new_run(21)
	run.pending_enemies = run._make_encounter(4, false)
	run.pending_arena = arena
	change_scene_to_file(run.BATTLE_SCENE)
	for i in 40: await process_frame
	var b = current_scene
	while b._mode == 0: await process_frame
	await create_timer(0.6).timeout

	# Превью без людей: прячем фигурки и интерфейс боя.
	for view: Node3D in b._views.values():
		view.visible = false
	b.hud.visible = false
	# Убираем подсветку клеток, стрелки маршрутов и метки — на превью только место.
	for layer: String in b.board._layers.keys():
		b.board.clear_layer(layer)
	b.set_process(false)
	b.set_process_input(false)
	# Камера чуть ближе обычного: в маленьком окошке крупные детали читаются лучше.
	b._cam_dist = 10.0
	b._update_camera()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	shot.save_png(OUT_DIR + "arena_empty_%s.png" % arena)
	print("empty ok")

	# Вырезаем середину кадра под пропорции окошка карточки.
	var pic_w: float = CARD_SIZE.x - 24.0
	var aspect: float = pic_w / PIC_HEIGHT
	var crop_h: int = int(shot.get_height() * 0.9)
	var crop_w: int = int(crop_h * aspect)
	var crop := Rect2i((shot.get_width() - crop_w) / 2, int(shot.get_height() * 0.05), crop_w, crop_h)
	var pic: Image = shot.get_region(crop)
	var pic_tex := ImageTexture.create_from_image(pic)

	# Собираем карточку поверх тёмного фона.
	var layer := CanvasLayer.new()
	layer.layer = 100
	b.add_child(layer)
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(root.size)
	layer.add_child(bg)
	var card := _make_card(pic_tex, BattleLogic.ARENAS.get(arena, arena))
	card.position = (Vector2(root.size) - CARD_SIZE) / 2.0
	layer.add_child(card)
	print("card built")

	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var r := Rect2i(Vector2i(card.position) - Vector2i(30, 30), Vector2i(CARD_SIZE) + Vector2i(60, 60))
	img.get_region(r).save_png(OUT_DIR + "arena_card_%s.png" % arena)
	print("card ", arena)
	quit()


# Карточка: рамка латунь+кожа, окошко с ареной, значок типа, огоньки опасности, плашка с названием.
func _make_card(pic: Texture2D, title: String, symbol: String = "swords", danger: int = DANGER, horns: bool = false) -> Control:
	var card := Panel.new()
	card.size = CARD_SIZE
	var frame: StyleBoxFlat = _box(Color(0.2, 0.14, 0.09), BRASS_DARK, 3, 10)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 12
	card.add_theme_stylebox_override("panel", frame)

	# Окошко с ареной в тонкой латунной рамке.
	var pic_frame := Panel.new()
	pic_frame.position = Vector2(10, 10)
	pic_frame.size = Vector2(CARD_SIZE.x - 20, PIC_HEIGHT + 4)
	pic_frame.add_theme_stylebox_override("panel", _box(Color.BLACK, BRASS, 2, 6))
	card.add_child(pic_frame)
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.texture = pic
	tex.clip_contents = true
	tex.position = Vector2(12, 12)
	tex.size = Vector2(CARD_SIZE.x - 24, PIC_HEIGHT)
	card.add_child(tex)

	# Значок типа точки и огоньки опасности.
	var y: float = PIC_HEIGHT + 22.0
	var sym: TextureRect = _icon(symbol, 48, BRASS)
	sym.position = Vector2((CARD_SIZE.x - 48) / 2.0, y)
	card.add_child(sym)
	var flames := HBoxContainer.new()
	flames.add_theme_constant_override("separation", 4)
	for i in (3 if danger > 0 else 0):
		var lit: bool = i < danger
		flames.add_child(_icon("fire", 20, BRASS if lit else Color(BRASS_DARK, 0.5)))
	flames.position = Vector2((CARD_SIZE.x - 68) / 2.0, y + 54)
	card.add_child(flames)

	# Элита: латунные «рога» на верхних углах рамки.
	if horns:
		for side: float in [-1.0, 1.0]:
			var horn := Polygon2D.new()
			var x: float = 8.0 if side < 0 else CARD_SIZE.x - 8.0
			horn.polygon = PackedVector2Array([Vector2(x, 14), Vector2(x - side * 26, 4), Vector2(x - side * 4, -22)])
			horn.color = BRASS
			card.add_child(horn)

	# Плашка с названием арены.
	var bar := Panel.new()
	bar.position = Vector2(20, CARD_SIZE.y - 46)
	bar.size = Vector2(CARD_SIZE.x - 40, 32)
	bar.add_theme_stylebox_override("panel", _box(Color(0.08, 0.06, 0.04), BRASS_DARK, 1, 5))
	card.add_child(bar)
	var label: Label = _label(title, 17, TEXT)
	label.add_theme_font_override("font", load("res://assets/fonts/AlegreyaSC-Bold.ttf"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = bar.position
	label.size = bar.size
	card.add_child(label)
	return card


func _box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(border_width)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


func _icon(icon_name: String, size: float, color: Color) -> TextureRect:
	var r := TextureRect.new()
	var image: Image = (load("res://assets/icons/%s.svg" % icon_name) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	image.generate_mipmaps()
	r.texture = ImageTexture.create_from_image(image)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(size, size)
	r.size = Vector2(size, size)
	r.modulate = color
	return r


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


# Карточки с рисунками Gemini: CARDS="картинка:значок:опасность:название[:elite];…"
# Картинки — assets/textures/map_cards/card_<имя>.jpg.
func _shot_painted(spec: String) -> void:
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(root.size)
	layer.add_child(bg)
	var items: PackedStringArray = spec.split(";")
	var gap: float = 40.0
	var total: float = items.size() * CARD_SIZE.x + (items.size() - 1) * gap
	var x0: float = (root.size.x - total) / 2.0
	for i in items.size():
		var f: PackedStringArray = items[i].split(":")
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/map_cards/card_%s.jpg" % f[0]))
		var card := _make_card(ImageTexture.create_from_image(img), f[3], f[1], int(f[2]), f.size() > 4)
		card.position = Vector2(x0 + i * (CARD_SIZE.x + gap), (root.size.y - CARD_SIZE.y) / 2.0)
		layer.add_child(card)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_DIR + "painted_cards.png")
	print("painted ok")
