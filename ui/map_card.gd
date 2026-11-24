class_name MapCard
extends Control
# Карточка точки карты пути (тз-карточки-арен.md): рамка по типу точки, рисунок места (арены,
# логова, события, лавки, привала), значок типа, огоньки опасности (1–3) и название.
# Состав врагов не показывается. Рамки и рисунки — assets/textures/map_cards/, где в рамке окошко
# и плашка — frames.json (в точках исходной картинки рамки).

const DIR: String = "res://assets/textures/map_cards/"
const WIDTH: float = 150.0          # ширина карточки на экране (высота — по пропорциям рамки)
const TITLE_COLOR := Color(0.87, 0.71, 0.38)

static var _frames: Dictionary = {}


static func _frame_info() -> Dictionary:
	if _frames.is_empty():
		var f := FileAccess.open(DIR + "frames.json", FileAccess.READ)
		if f != null:
			_frames = JSON.parse_string(f.get_as_text())
	return _frames


# Какая рамка у точки
static func frame_for(n: MapNode) -> String:
	match n.type:
		MapNode.Type.ELITE:
			return "elite"
		MapNode.Type.BOSS:
			return "boss"
		MapNode.Type.LAIR:
			return "spirit"
		MapNode.Type.EVENT:
			return "event"
		MapNode.Type.SHOP, MapNode.Type.REST:
			return "calm"
	return "battle"


# Какой рисунок: у боёв — арена точки, у остальных — своё место
static func picture_for(n: MapNode) -> String:
	match n.type:
		MapNode.Type.LAIR:
			return "spirit"
		MapNode.Type.EVENT:
			return "event"
		MapNode.Type.SHOP:
			return "shop"
		MapNode.Type.REST:
			return "rest"
	return n.arena if n.arena != "" else "gat"


# Опасность: 0 — не бой; обычный бой 1–2 по ряду, логово 2, элита и босс 3
static func danger_for(n: MapNode) -> int:
	match n.type:
		MapNode.Type.BATTLE:
			return 1 if n.row <= 1 else 2
		MapNode.Type.LAIR:
			return 2
		MapNode.Type.ELITE, MapNode.Type.BOSS:
			return 3
	return 0


static func title_for(n: MapNode) -> String:
	match n.type:
		MapNode.Type.LAIR:
			return Loc.t("Логово духа")
		MapNode.Type.EVENT:
			return Loc.t("Событие")
		MapNode.Type.SHOP:
			return Loc.t("Лавка")
		MapNode.Type.REST:
			return Loc.t("Привал")
		MapNode.Type.BOSS:
			return Loc.t(Run.run_boss.title) if Run.run_boss != null else Loc.t("Босс")
	return BattleLogic.ARENAS.get(n.arena, n.type_name())


static func icon_for(n: MapNode) -> String:
	return {MapNode.Type.BATTLE: "map_battle", MapNode.Type.ELITE: "map_elite", MapNode.Type.BOSS: "map_boss",
			MapNode.Type.LAIR: "map_lair", MapNode.Type.EVENT: "map_event", MapNode.Type.SHOP: "map_shop",
			MapNode.Type.REST: "map_rest"}.get(n.type, "map_battle")


# Собрать карточку для точки
static func build(n: MapNode) -> MapCard:
	var card := MapCard.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fname: String = frame_for(n)
	var info: Dictionary = _frame_info().get(fname, {})
	var src: Vector2 = Vector2(info.get("size", [567, 865])[0], info.get("size", [567, 865])[1])
	var k: float = WIDTH / src.x
	card.size = src * k
	var rect := func(key: String) -> Rect2:
		var r: Array = info.get(key, [0, 0, 1, 1])
		return Rect2(Vector2(r[0], r[1]) * k, Vector2(r[2] - r[0], r[3] - r[1]) * k)
	var win: Rect2 = rect.call("window")
	var bar: Rect2 = rect.call("bar")
	# рисунок под рамкой: в окошко, с запасом на край
	var pic := TextureRect.new()
	var pic_path: String = DIR + "card_%s.jpg" % picture_for(n)
	if not ResourceLoader.exists(pic_path):
		# Рисунка арены ещё нет (акт 2: картинки Gemini у Ромы) — похожее место: Подземье — насосная, Тракт — застава
		pic_path = DIR + ("card_pump.jpg" if BattleLogic.arena_biome(n.arena) == "deep" else "card_camp.jpg")
	pic.texture = load(pic_path) as Texture2D
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.position = win.position - Vector2(3, 3)
	pic.size = win.size + Vector2(6, 6)
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pic)
	var frame := TextureRect.new()
	frame.texture = load(DIR + "frame_%s.png" % fname) as Texture2D
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = card.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	# значок и огоньки опасности — между окошком и плашкой
	var gap_top: float = win.end.y
	var gap: float = bar.position.y - gap_top
	var danger: int = danger_for(n)
	var icon_size: float = gap * (0.5 if danger > 0 else 0.62)
	var flame: float = icon_size * 0.36
	var block_h: float = icon_size + (flame + 4.0 if danger > 0 else 0.0)
	var y0: float = gap_top + (gap - block_h) / 2.0
	var cx: float = win.get_center().x
	var sym: TextureRect = UiKit.icon_rect(icon_for(n), icon_size, UiKit.BRASS.lightened(0.1))
	sym.position = Vector2(cx - icon_size / 2.0, y0)
	card.add_child(sym)
	if danger > 0:
		var step: float = flame * 1.15
		for i in 3:
			var f: TextureRect = UiKit.icon_rect("map_danger", flame, UiKit.BRASS if i < danger else Color(UiKit.BRASS_DARK, 0.55))
			f.position = Vector2(cx - step - flame / 2.0 + i * step, y0 + icon_size + 4.0)
			card.add_child(f)
	# название с «гравировкой»: тёмная тень и обводка под латунными буквами
	var title: Label = UiKit.make_label(title_for(n), maxi(11, int(bar.size.y * 0.62)), TITLE_COLOR)
	title.add_theme_font_override("font", UiKit.font_title())
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.position = bar.position
	title.size = bar.size
	card.add_child(title)
	return card
